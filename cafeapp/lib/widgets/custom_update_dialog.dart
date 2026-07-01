import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../utils/app_localization.dart';

class CustomUpdateDialog extends StatefulWidget {
  final String version;
  final String releaseNotes;
  final String downloadUrl;

  const CustomUpdateDialog({
    super.key,
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
  });

  @override
  State<CustomUpdateDialog> createState() => _CustomUpdateDialogState();
}

class _CustomUpdateDialogState extends State<CustomUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _statusMessage = 'Downloading update...'.tr();
      _progress = 0.0;
    });

    try {
      final request = http.Request('GET', Uri.parse(widget.downloadUrl));
      final response = await http.Client().send(request);
      
      final contentLength = response.contentLength;
      
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}\\sims_cafe_update.exe';
      final file = File(savePath);
      
      final sink = file.openWrite();
      int downloadedBytes = 0;
      
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloadedBytes += chunk.length;
        if (contentLength != null) {
          setState(() {
            _progress = downloadedBytes / contentLength;
          });
        }
      });
      
      await sink.close();
      
      setState(() {
        _statusMessage = 'Installing update...'.tr();
        _progress = 1.0;
      });
      
      // Launch the installer and exit
      await Process.start(savePath, []);
      exit(0);

    } catch (e) {
      setState(() {
        _isDownloading = false;
        _statusMessage = 'Download failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.system_update, color: Colors.blue, size: 28),
          const SizedBox(width: 12),
          Text('Update Available'.tr()),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${'A new version is available:'.tr()} ${widget.version}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            // const SizedBox(height: 16),
            // const Text('Release Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
            // const SizedBox(height: 8),
            // Container(
            //   padding: const EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: Colors.grey.shade100,
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(color: Colors.grey.shade300),
            //   ),
            //   // We strip out the <ul> and <li> from the CDATA for simple display
            //   child: Text(
            //     widget.releaseNotes
            //         .replaceAll(RegExp(r'<ul>|</ul>'), '')
            //         .replaceAll('<li>', '• ')
            //         .replaceAll('</li>', '\n')
            //         .trim(),
            //     style: const TextStyle(fontSize: 14),
            //   ),
            // ),
            const SizedBox(height: 24),
            if (_isDownloading) ...[
              Text(_statusMessage, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress > 0 ? _progress : null),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${(_progress * 100).toStringAsFixed(1)}%'),
              ),
            ]
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Remind me later'.tr(), style: const TextStyle(color: Colors.grey)),
          ),
        if (!_isDownloading)
          ElevatedButton.icon(
            onPressed: _startDownload,
            // icon: const Icon(Icons.download),
            label: Text('Download & Install'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
      ],
    );
  }
}
