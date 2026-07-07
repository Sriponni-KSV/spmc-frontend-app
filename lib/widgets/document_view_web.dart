import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

void showDocumentViewer(BuildContext context, String url, String title) {
  final isImage = _isImageUrl(url);
  
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.8,
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
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(child: CircularProgressIndicator());
                          },
                        ),
                      )
                    : _WebIframeView(url: url),
              ),
            ],
          ),
        ),
      );
    },
  );
}

bool _isImageUrl(String url) {
  final cleanUrl = url.split('?').first.toLowerCase();
  return cleanUrl.endsWith('.jpg') ||
      cleanUrl.endsWith('.jpeg') ||
      cleanUrl.endsWith('.png') ||
      cleanUrl.endsWith('.gif') ||
      cleanUrl.endsWith('.webp');
}

class _WebIframeView extends StatefulWidget {
  final String url;
  const _WebIframeView({Key? key, required this.url}) : super(key: key);

  @override
  State<_WebIframeView> createState() => _WebIframeViewState();
}

class _WebIframeViewState extends State<_WebIframeView> {
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    // Generate a unique view ID based on the url hash
    _viewId = 'iframe-${widget.url.hashCode}';
    
    // Register the iframe view factory
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%',
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
