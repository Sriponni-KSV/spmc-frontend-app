import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:typed_data';
import 'package:flutter/material.dart';

int _pdfViewCounter = 0;

/// Opens a document (URL or local blob) directly in a new browser tab.
void openDocumentInNewTab(
  String url,
  String title, {
  List<int>? bytes,
  String? fileName,
}) {
  final isImage = _isImage(url: url, fileName: fileName);
  final isPdf = _isPdf(url: url, fileName: fileName);

  String? targetUrl;
  if (bytes != null && bytes.isNotEmpty) {
    try {
      String mimeType = 'application/octet-stream';
      if (isPdf) {
        mimeType = 'application/pdf';
      } else if (isImage) {
        final ext = (fileName ?? '').split('.').last.toLowerCase();
        mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      }
      final blob = html.Blob([bytes], mimeType);
      targetUrl = html.Url.createObjectUrlFromBlob(blob);
    } catch (_) {}
  } else if (url.isNotEmpty) {
    targetUrl = url;
  }

  if (targetUrl != null && targetUrl.isNotEmpty) {
    html.window.open(targetUrl, '_blank');
  }
}

/// Web implementation: opens images inline and renders PDFs in embedded browser iframe or new tab.
void showDocumentViewer(
  BuildContext context,
  String url,
  String title, {
  List<int>? bytes,
  String? fileName,
}) {
  final isImage = _isImage(url: url, fileName: fileName);
  final isPdf = _isPdf(url: url, fileName: fileName);

  String? pdfUrl;
  if (bytes != null && bytes.isNotEmpty) {
    try {
      final blob = html.Blob([bytes], isPdf ? 'application/pdf' : 'application/octet-stream');
      pdfUrl = html.Url.createObjectUrlFromBlob(blob);
    } catch (_) {}
  } else if (url.isNotEmpty && url.startsWith('http')) {
    pdfUrl = url;
  }

  String? viewType;
  if (pdfUrl != null && !isImage) {
    _pdfViewCounter++;
    viewType = 'pdf-iframe-$_pdfViewCounter';
    final targetUrl = pdfUrl;
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src = targetUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    });
  }

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                color: const Color(0xFFF8FAFC),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F5A8E),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (pdfUrl != null)
                      IconButton(
                        tooltip: 'Open in new tab',
                        icon: const Icon(Icons.open_in_new, color: Color(0xFF0F5A8E), size: 20),
                        onPressed: () {
                          html.window.open(pdfUrl!, '_blank');
                        },
                      ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 22),
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
                        child: Center(
                          child: bytes != null && bytes.isNotEmpty
                              ? Image.memory(
                                  Uint8List.fromList(bytes),
                                  fit: BoxFit.contain,
                                )
                              : Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(child: CircularProgressIndicator());
                                  },
                                ),
                        ),
                      )
                    : (viewType != null
                        ? HtmlElementView(viewType: viewType)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(
                                  title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                if (pdfUrl != null)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      html.window.open(pdfUrl!, '_blank');
                                    },
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open PDF'),
                                  ),
                              ],
                            ),
                          )),
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

bool _isPdf({String? url, String? fileName}) {
  final target = (fileName ?? url ?? '').split('?').first.toLowerCase();
  return target.endsWith('.pdf');
}
