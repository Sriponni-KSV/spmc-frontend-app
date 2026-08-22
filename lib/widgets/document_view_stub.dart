import 'package:flutter/material.dart';

void openDocumentInNewTab(
  String url,
  String title, {
  List<int>? bytes,
  String? fileName,
}) {}

void showDocumentViewer(
  BuildContext context,
  String url,
  String title, {
  List<int>? bytes,
  String? fileName,
}) {
  throw UnsupportedError('Cannot view document on this platform');
}
