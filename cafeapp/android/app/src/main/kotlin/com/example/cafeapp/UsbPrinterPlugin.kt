package com.example.cafeapp

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * In-app replacement for the abandoned `flutter_usb_printer` plugin.
 *
 * That plugin built its permission PendingIntent with legacy flags, which throws on API 31+
 * and left it handing a null PendingIntent to the system USB permission service — crashing
 * SystemUI and relocking the device. Everything here is written against the current
 * PendingIntent / registerReceiver / bulk-transfer rules.
 */
class UsbPrinterPlugin : FlutterPlugin, MethodCallHandler {

    companion object {
        private const val TAG = "UsbPrinterPlugin"
        private const val CHANNEL = "com.sims.cafeapp/usb_printer"
        private const val ACTION_USB_PERMISSION = "com.example.cafeapp.USB_PERMISSION"

        /**
         * Chunk size is derived from the endpoint's own wMaxPacketSize rather than
         * hardcoded. A full-speed printer reports 64, so a fixed 16 KB request is 256
         * packets in one URB and usbfs rejects it outright with EINVAL — which Android
         * surfaces as an indistinguishable -1. 64 packets per chunk gives 4 KB on a
         * full-speed endpoint and 32 KB on high speed, hence the ceiling below.
         */
        private const val PACKETS_PER_CHUNK = 64
        private const val MAX_CHUNK_BYTES = 8192

        /** Per-chunk transfer timeout. */
        private const val CHUNK_TIMEOUT_MS = 5000

        /** Lets a slow printer drain its buffer between chunks. */
        private const val INTER_CHUNK_DELAY_MS = 10L

        /** Failed-chunk retries before giving up, and the pause between them. */
        private const val MAX_CHUNK_RETRIES = 4
        private const val RETRY_BACKOFF_MS = 60L

        /** How long we wait for the user to answer the system permission dialog. */
        private const val PERMISSION_TIMEOUT_MS = 60_000L

        // USB standard CLEAR_FEATURE(ENDPOINT_HALT); UsbDeviceConnection has no clearHalt().
        private const val REQ_TYPE_ENDPOINT_OUT = 0x02
        private const val REQ_CLEAR_FEATURE = 0x01
        private const val FEATURE_ENDPOINT_HALT = 0x00
    }

    private lateinit var channel: MethodChannel
    private var appContext: Context? = null
    private var usbManager: UsbManager? = null

    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()

    /** Pending connect() replies, keyed by "vendorId:productId". */
    private val pendingConnects = HashMap<String, PendingConnect>()

    private var device: UsbDevice? = null
    private var connection: UsbDeviceConnection? = null
    private var usbInterface: UsbInterface? = null
    private var endpoint: UsbEndpoint? = null

    private var permissionReceiver: BroadcastReceiver? = null
    private var detachReceiver: BroadcastReceiver? = null

    private class PendingConnect(val result: Result) {
        val replied = AtomicBoolean(false)
        var timeout: Runnable? = null
    }

    // ---------------------------------------------------------------- lifecycle

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)

        // Deliberately the application context: this plugin is not ActivityAware, so it
        // neither leaks the Activity nor gets torn down across configuration changes.
        val ctx = binding.applicationContext
        appContext = ctx

        usbManager = try {
            ctx.getSystemService(Context.USB_SERVICE) as? UsbManager
        } catch (e: Exception) {
            Log.e(TAG, "USB service unavailable", e)
            null
        }

        // Deliberately separate: enumeration only needs the UsbManager. If receiver
        // registration fails we lose permission callbacks, but listing devices must
        // still work — otherwise a receiver problem masquerades as "no printer found".
        try {
            registerReceivers(ctx)
        } catch (e: Exception) {
            Log.e(TAG, "USB broadcast receiver registration failed", e)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        appContext?.let { ctx ->
            permissionReceiver?.let { runCatching { ctx.unregisterReceiver(it) } }
            detachReceiver?.let { runCatching { ctx.unregisterReceiver(it) } }
        }
        permissionReceiver = null
        detachReceiver = null
        failAllPending("engine_detached", "Flutter engine detached")
        closeConnection()
        appContext = null
        usbManager = null
    }

    private fun registerReceivers(ctx: Context) {
        // Two receivers, because the two actions need opposite export flags on API 33+:
        // ACTION_USB_PERMISSION is broadcast under our own uid via the PendingIntent, so it
        // must NOT be exported; ACTION_USB_DEVICE_DETACHED comes from the system, so it must.
        permissionReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != ACTION_USB_PERMISSION) return
                val dev = extractDevice(intent)
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                onPermissionResult(dev, granted)
            }
        }
        detachReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != UsbManager.ACTION_USB_DEVICE_DETACHED) return
                val dev = extractDevice(intent)
                if (dev != null && device != null && dev.deviceId == device!!.deviceId) {
                    Log.i(TAG, "USB printer detached; closing connection")
                    closeConnection()
                }
            }
        }
        registerReceiverCompat(ctx, permissionReceiver!!, IntentFilter(ACTION_USB_PERMISSION), false)
        registerReceiverCompat(
            ctx,
            detachReceiver!!,
            IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED),
            true,
        )
    }

    private fun registerReceiverCompat(
        ctx: Context,
        receiver: BroadcastReceiver,
        filter: IntentFilter,
        exported: Boolean,
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val flag = if (exported) Context.RECEIVER_EXPORTED else Context.RECEIVER_NOT_EXPORTED
            ctx.registerReceiver(receiver, filter, flag)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            ctx.registerReceiver(receiver, filter)
        }
    }

    @Suppress("DEPRECATION")
    private fun extractDevice(intent: Intent): UsbDevice? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
        } else {
            intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
        }

    // ---------------------------------------------------------------- channel

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "list" -> listDevices(result)
            "connect" -> {
                val vendorId = call.argument<Int>("vendorId")
                val productId = call.argument<Int>("productId")
                if (vendorId == null || productId == null) {
                    result.error("bad_args", "vendorId and productId are required", null)
                } else {
                    connect(vendorId, productId, result)
                }
            }
            "write" -> {
                val data = call.argument<ByteArray>("data")
                if (data == null) {
                    result.error("bad_args", "data is required", null)
                } else {
                    write(data, result)
                }
            }
            "close" -> {
                closeConnection()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun listDevices(result: Result) {
        val manager = usbManager
        if (manager == null) {
            result.error("unavailable", "USB service is not available on this device", null)
            return
        }
        val attached = manager.deviceList.values
        // No class filter: an empty result means Android's USB host stack enumerated
        // nothing at all, which points at OTG/cable/power rather than at this app.
        Log.i(TAG, "USB host enumeration: ${attached.size} device(s)")
        val list = ArrayList<HashMap<String, String?>>()
        for (dev in attached) {
            Log.i(TAG, "  ${dev.deviceName} vid=${dev.vendorId} pid=${dev.productId} class=${dev.deviceClass}")
            list.add(
                hashMapOf(
                    "deviceName" to dev.deviceName,
                    "manufacturer" to dev.manufacturerName,
                    "productName" to dev.productName,
                    // Strings, to stay wire-compatible with the "<vendorId>_<productId>"
                    // identity keys already persisted in SharedPreferences.
                    "deviceId" to dev.deviceId.toString(),
                    "vendorId" to dev.vendorId.toString(),
                    "productId" to dev.productId.toString(),
                )
            )
        }
        result.success(list)
    }

    private fun connect(vendorId: Int, productId: Int, result: Result) {
        val manager = usbManager
        val ctx = appContext
        if (manager == null || ctx == null) {
            result.error("unavailable", "USB service is not available on this device", null)
            return
        }

        val target = manager.deviceList.values.firstOrNull {
            it.vendorId == vendorId && it.productId == productId
        }
        if (target == null) {
            result.error("not_found", "USB printer $vendorId:$productId is not connected", null)
            return
        }

        if (manager.hasPermission(target)) {
            openAndReply(target, result)
            return
        }

        val key = "$vendorId:$productId"
        pendingConnects.remove(key)?.let { stale ->
            stale.timeout?.let { main.removeCallbacks(it) }
            if (stale.replied.compareAndSet(false, true)) {
                stale.result.error("superseded", "Replaced by a newer connect request", null)
            }
        }

        val pending = PendingConnect(result)
        pendingConnects[key] = pending
        val timeout = Runnable {
            pendingConnects.remove(key)
            if (pending.replied.compareAndSet(false, true)) {
                pending.result.error(
                    "permission_timeout",
                    "Timed out waiting for USB permission to be granted",
                    null,
                )
            }
        }
        pending.timeout = timeout
        main.postDelayed(timeout, PERMISSION_TIMEOUT_MS)

        try {
            manager.requestPermission(target, permissionIntent(ctx))
        } catch (e: Exception) {
            main.removeCallbacks(timeout)
            pendingConnects.remove(key)
            if (pending.replied.compareAndSet(false, true)) {
                pending.result.error("permission_failed", e.message ?: "requestPermission failed", null)
            }
        }
    }

    private fun permissionIntent(ctx: Context): PendingIntent {
        // setPackage makes the Intent explicit — Android 14 rejects FLAG_MUTABLE on an
        // implicit Intent. FLAG_MUTABLE itself is required because the system fills in
        // EXTRA_DEVICE / EXTRA_PERMISSION_GRANTED before sending.
        val intent = Intent(ACTION_USB_PERMISSION).setPackage(ctx.packageName)
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getBroadcast(ctx, 0, intent, flags)
    }

    private fun onPermissionResult(dev: UsbDevice?, granted: Boolean) {
        if (dev == null) {
            failAllPending("permission_denied", "USB permission response had no device")
            return
        }
        val key = "${dev.vendorId}:${dev.productId}"
        val pending = pendingConnects.remove(key) ?: return
        pending.timeout?.let { main.removeCallbacks(it) }
        if (!pending.replied.compareAndSet(false, true)) return

        if (granted) {
            openAndReply(dev, pending.result)
        } else {
            pending.result.error("permission_denied", "USB permission was denied by the user", null)
        }
    }

    private fun failAllPending(code: String, message: String) {
        val entries = pendingConnects.values.toList()
        pendingConnects.clear()
        for (pending in entries) {
            pending.timeout?.let { main.removeCallbacks(it) }
            if (pending.replied.compareAndSet(false, true)) {
                pending.result.error(code, message, null)
            }
        }
    }

    // ---------------------------------------------------------------- transport

    private fun openAndReply(target: UsbDevice, result: Result) {
        try {
            if (openConnection(target)) {
                result.success(true)
            } else {
                result.error("open_failed", "Could not open a bulk OUT channel to the printer", null)
            }
        } catch (e: Exception) {
            Log.e(TAG, "openConnection failed", e)
            result.error("open_failed", e.message ?: "Could not open the USB printer", null)
        }
    }

    private fun openConnection(target: UsbDevice): Boolean {
        val manager = usbManager ?: return false

        if (connection != null && device?.deviceId == target.deviceId && endpoint != null) {
            return true
        }
        closeConnection()

        // Don't assume interface 0 — pick whichever interface actually exposes a bulk OUT
        // endpoint, preferring the USB printer class (7) when the device offers several.
        val candidates = (0 until target.interfaceCount)
            .map { target.getInterface(it) }
            .sortedByDescending { if (it.interfaceClass == UsbConstants.USB_CLASS_PRINTER) 1 else 0 }

        for (iface in candidates) {
            val out = (0 until iface.endpointCount)
                .map { iface.getEndpoint(it) }
                .firstOrNull {
                    it.type == UsbConstants.USB_ENDPOINT_XFER_BULK &&
                        it.direction == UsbConstants.USB_DIR_OUT
                }
                ?: continue

            val conn = manager.openDevice(target)
            if (conn == null) {
                Log.e(TAG, "openDevice returned null for ${target.deviceName}")
                return false
            }
            if (!conn.claimInterface(iface, true)) {
                Log.e(TAG, "claimInterface failed for ${target.deviceName}")
                conn.close()
                return false
            }
            device = target
            connection = conn
            usbInterface = iface
            endpoint = out
            Log.i(
                TAG,
                "USB printer opened: ${target.deviceName} " +
                    "iface=${iface.id}/${iface.interfaceClass}.${iface.interfaceSubclass}." +
                    "${iface.interfaceProtocol} " +
                    "epOut=0x${Integer.toHexString(out.address)} maxPacket=${out.maxPacketSize}",
            )
            return true
        }

        Log.e(TAG, "No bulk OUT endpoint found on ${target.deviceName}")
        return false
    }

    private fun write(data: ByteArray, result: Result) {
        val conn = connection
        val ep = endpoint
        if (conn == null || ep == null) {
            result.error("not_connected", "Not connected to a USB printer", null)
            return
        }
        io.execute {
            val started = System.currentTimeMillis()
            val error = try {
                writeBlocking(conn, ep, data)
            } catch (e: Exception) {
                "bulkTransfer threw ${e.javaClass.simpleName}: ${e.message}"
            }
            val elapsed = System.currentTimeMillis() - started
            main.post {
                if (error != null) {
                    Log.e(TAG, "USB write failed after ${elapsed}ms: $error")
                    result.error("write_failed", error, null)
                } else {
                    Log.i(TAG, "USB write complete: ${data.size} bytes in ${elapsed}ms")
                    result.success(true)
                }
            }
        }
    }

    /**
     * Writes [data] to the bulk OUT endpoint, returning null on success or a
     * diagnostic string on failure.
     *
     * Chunks are sized from the endpoint's wMaxPacketSize and halve on failure down
     * to a single packet, so an unfamiliar printer with a stricter transfer limit
     * self-tunes instead of failing the whole job.
     */
    private fun writeBlocking(conn: UsbDeviceConnection, ep: UsbEndpoint, data: ByteArray): String? {
        val maxPacket = if (ep.maxPacketSize > 0) ep.maxPacketSize else 64
        var chunk = (maxPacket * PACKETS_PER_CHUNK).coerceIn(maxPacket, MAX_CHUNK_BYTES)
        var sent = 0
        var retries = 0

        while (sent < data.size) {
            val len = minOf(chunk, data.size - sent)
            val transferred = conn.bulkTransfer(ep, data, sent, len, CHUNK_TIMEOUT_MS)

            if (transferred > 0) {
                sent += transferred
                retries = 0
                if (sent < data.size) Thread.sleep(INTER_CHUNK_DELAY_MS)
                continue
            }

            retries++
            if (retries > MAX_CHUNK_RETRIES) {
                return "bulkTransfer returned $transferred after $sent/${data.size} bytes " +
                    "(chunk=$len, maxPacket=$maxPacket, ep=0x${Integer.toHexString(ep.address)})"
            }

            if (chunk > maxPacket) {
                // Most likely an oversized request. Back off before touching the
                // endpoint state — a data-toggle reset on a healthy endpoint would
                // silently desynchronise the transfer.
                chunk = (chunk / 2).coerceAtLeast(maxPacket)
                Log.w(TAG, "bulkTransfer failed at $sent/${data.size}; retrying with chunk=$chunk")
            } else {
                // Already down to one packet, so treat it as a stalled endpoint.
                clearHalt(conn, ep)
                Thread.sleep(RETRY_BACKOFF_MS)
            }
        }
        return null
    }

    private fun clearHalt(conn: UsbDeviceConnection, ep: UsbEndpoint) {
        val r = conn.controlTransfer(
            REQ_TYPE_ENDPOINT_OUT,
            REQ_CLEAR_FEATURE,
            FEATURE_ENDPOINT_HALT,
            ep.address,
            null,
            0,
            1000,
        )
        Log.w(TAG, "clearHalt(ep=0x${Integer.toHexString(ep.address)}) -> $r")
    }

    private fun closeConnection() {
        val conn = connection
        val iface = usbInterface
        if (conn != null) {
            runCatching { if (iface != null) conn.releaseInterface(iface) }
            runCatching { conn.close() }
        }
        connection = null
        usbInterface = null
        endpoint = null
        device = null
    }
}
