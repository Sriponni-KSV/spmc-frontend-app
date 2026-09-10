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
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
      }
    } catch (e) {
      debugPrint('Error launching document URL: $e');
    }
  }
}

/// Mobile implementation: shows a modal dialog with interactive image zoom or PDF launcher.
void showDocumentViewer(
  BuildContext context,
  String url,
  String title, {
  List<int>? bytes,
  String? fileName,
}) {
  final isImage = _isImage(url: url, fileName: fileName);
  final isLocal = bytes != null && bytes.isNotEmpty;

  showDialog(
    context: context,
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SizedBox(
          width: media.size.width * 0.95,
          height: media.size.height * 0.75,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F5A8E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (url.isNotEmpty)
                      IconButton(
                        tooltip: 'Open in browser',
                        icon: const Icon(Icons.open_in_new, color: Color(0xFF0F5A8E), size: 20),
                        onPressed: () => openDocumentInNewTab(url, title),
                      ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Body
              Expanded(
                child: Container(
                  color: Colors.black.withOpacity(0.03),
                  child: isImage
                      ? InteractiveViewer(
                          panEnabled: true,
                          minScale: 0.8,
                          maxScale: 4.0,
                          child: Center(
                            child: isLocal
                                ? Image.memory(
                                    Uint8List.fromList(bytes),
                                    fit: BoxFit.contain,
                                  )
                                : Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  (loadingProgress.expectedTotalBytes ?? 1)
                                              : null,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(24.0),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Could not display image inline.',
                                                style: TextStyle(color: Colors.black54, fontSize: 13),
                                              ),
                                              if (url.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                ElevatedButton.icon(
                                                  onPressed: () => openDocumentInNewTab(url, title),
                                                  icon: const Icon(Icons.open_in_new, size: 16),
                                                  label: const Text('Open Externally'),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.picture_as_pdf,
                                    size: 56,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  fileName ?? title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'PDF / Document File',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 20),
                                if (url.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () => openDocumentInNewTab(url, title),
                                    icon: const Icon(Icons.open_in_new, size: 18),
                                    label: const Text('Open Document in PDF Viewer'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0F5A8E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
  if (target.endsWith('.jpg') ||
      target.endsWith('.jpeg') ||
      target.endsWith('.png') ||
      target.endsWith('.gif') ||
      target.endsWith('.webp') ||
      target.endsWith('.bmp')) {
    return true;
  }
  // If Cloudinary URL contains /image/upload/ and does not end in .pdf
  if (target.contains('/image/upload/') && !target.contains('.pdf')) {
    return true;
  }
  return false;
}
