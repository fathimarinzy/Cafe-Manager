import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/menu_item.dart';
import '../models/order_history.dart';
import 'bill_service.dart';

/// Everything needed to print or PDF one receipt, captured while the tender
/// screen is still alive.
///
/// This exists because printing moved off the payment critical path. The screen
/// is disposed by `pushAndRemoveUntil` as soon as the cashier dismisses the
/// balance dialog, so a background print cannot reach back into widget state.
/// Nothing here touches BuildContext or the widget tree — the snapshot is
/// self-contained and stays valid after the screen is gone.
///
/// Field sources deliberately mirror the previous inline code exactly:
///   * [printOrder] is what `printThermalBill` used to be handed (`widget.order`)
///   * the PDF fields come from `_updatedOrder ?? widget.order`, as the old
///     `_generateReceipt()` did
/// The two differ, and that difference is preserved rather than "tidied", so
/// this change alters latency and nothing else.
class ReceiptJob {
  /// 'bank' | 'cash' | 'split' — used for the trace label only.
  final String label;

  final OrderHistory printOrder;
  final bool isEdited;
  final double? taxRate;
  final double discount;

  // Pre-resolved PDF inputs.
  final List<MenuItem> pdfItems;
  final String serviceType;
  final String orderNumber;

  /// Customer name on the PDF. Null for ordinary payments, which is what the
  /// three original paths passed; credit completions carry the customer whose
  /// balance was settled.
  final String? personName;
  final double subtotal;
  final double tax;
  final double total;
  final double? depositAmount;
  final double? deliveryCharge;

  const ReceiptJob({
    required this.label,
    required this.printOrder,
    required this.isEdited,
    required this.taxRate,
    required this.discount,
    required this.pdfItems,
    required this.serviceType,
    required this.orderNumber,
    this.personName,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.depositAmount,
    required this.deliveryCharge,
  });

  /// Attempts the thermal print. Returns false rather than throwing.
  Future<bool> print() => BillService.printThermalBill(
        printOrder,
        isEdited: isEdited,
        taxRate: taxRate,
        discount: discount,
      );

  /// Builds the fallback PDF. Only called when the cashier asks for it.
  Future<pw.Document> buildPdf() => BillService.generateBill(
        items: pdfItems,
        serviceType: serviceType,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        personName: personName,
        tableInfo: serviceType.contains('Table') ? serviceType : null,
        isEdited: isEdited,
        orderNumber: orderNumber,
        taxRate: taxRate,
        depositAmount: depositAmount,
        deliveryCharge: deliveryCharge,
      );

  String suggestedFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'SIMS_receipt_${printOrder.orderNumber}_$timestamp.pdf';
  }
}
