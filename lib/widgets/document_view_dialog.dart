export 'document_view_stub.dart'
    if (dart.library.html) 'document_view_web.dart'
    if (dart.library.io) 'document_view_mobile.dart';
