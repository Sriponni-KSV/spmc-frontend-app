import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'document_view_dialog.dart';

class ConsultationDocumentsView extends StatelessWidget {
  final dynamic documents;
  final bool isCompact;

  const ConsultationDocumentsView({
    super.key,
    required this.documents,
    this.isCompact = false,
  });

  /// Parses documents from various possible formats (List, JSON String, etc.)
  static List<Map<String, dynamic>> parseDocuments(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Checks if any valid documents exist in the raw data
  static bool hasDocuments(dynamic raw) {
    return parseDocuments(raw).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final docsList = parseDocuments(documents);
    if (docsList.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < docsList.length; i++)
          _buildDocumentCard(context, docsList[i], i),
      ],
    );
  }

  Widget _buildDocumentCard(
    BuildContext context,
    Map<String, dynamic> doc,
    int index,
  ) {
    final title = (doc['title']?.toString().trim().isNotEmpty ?? false)
        ? doc['title'].toString().trim()
        : (doc['file_name']?.toString().trim().isNotEmpty ?? false)
            ? doc['file_name'].toString().trim()
            : 'Document ${index + 1}';

    final fileName = doc['file_name']?.toString().trim() ?? '';
    final fileUrl = doc['file_url']?.toString().trim() ?? '';
    final fileSize = doc['file_size']?.toString().trim() ?? '';
    final date = doc['date']?.toString().trim() ?? '';

    final lowerName = fileName.toLowerCase();
    final lowerUrl = fileUrl.toLowerCase();
    final isPdf = lowerName.endsWith('.pdf') || lowerUrl.endsWith('.pdf') || lowerUrl.contains('.pdf?');
    final isImage = lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.png') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.gif') ||
        lowerUrl.contains('/image/upload/');

    final Color badgeColor = isPdf
        ? AppTheme.dangerColor
        : isImage
            ? AppTheme.primaryColor
            : AppTheme.secondaryColor;

    final IconData badgeIcon = isPdf
        ? Icons.picture_as_pdf_rounded
        : isImage
            ? Icons.image_rounded
            : Icons.insert_drive_file_rounded;

    // Subtitle composition
    final List<String> subtitleParts = [];
    if (fileName.isNotEmpty && fileName != title) {
      subtitleParts.add(fileName);
    }
    if (fileSize.isNotEmpty) {
      subtitleParts.add(fileSize);
    }
    if (date.isNotEmpty) {
      subtitleParts.add('Attached: $date');
    }
    final subtitle = subtitleParts.join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDocument(context, title, fileName, fileUrl),
          hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
          splashColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Icon badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      badgeIcon,
                      size: 20,
                      color: badgeColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Action View Button
                OutlinedButton.icon(
                  onPressed: () => _openDocument(context, title, fileName, fileUrl),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 15,
                  ),
                  label: const Text(
                    'View',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(60, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    backgroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDocument(
    BuildContext context,
    String title,
    String fileName,
    String fileUrl,
  ) {
    if (fileUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Document "$title" has no viewable file attached.'),
          backgroundColor: AppTheme.warningColor,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    showDocumentViewer(
      context,
      fileUrl,
      title,
      fileName: fileName.isNotEmpty ? fileName : null,
    );
  }
}
