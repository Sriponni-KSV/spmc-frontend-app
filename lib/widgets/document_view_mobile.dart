import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a document in external application / browser tab on mobile/desktop.
Future<void> openDocumentInNewTab(
  String url,
  String title, {
  List<int>? bytes,
  String? fileName,
}) async {
  if (url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

void showDocumentViewer(
  BuildContext context,
  String url,
  String title, {
  List<int>? bytes,
  String? fileName,
}) {
  final isImage = _isImage(url: url, fileName: fileName);

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F5A8E)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body
              Expanded(
                child: isImage
                    ? InteractiveViewer(
                        child: bytes != null && bytes.isNotEmpty
                            ? Image.memory(Uint8List.fromList(bytes), fit: BoxFit.contain)
                            : Image.network(
                                url,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                              ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            if (url.isNotEmpty)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(url);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('Open Document'),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

bool _isImage({String? url, String? fileName}) {
  final target = (fileName ?? url ?? '').split('?').first.toLowerCase();
  return target.endsWith('.jpg') ||
      target.endsWith('.jpeg') ||
      target.endsWith('.png') ||
      target.endsWith('.gif') ||
      target.endsWith('.webp');
}
