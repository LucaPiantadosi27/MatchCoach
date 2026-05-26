import 'dart:typed_data';

/// Stub per piattaforme non-web: non viene mai chiamato perché
/// ai_analysis_repository usa kIsWeb prima di chiamare readBlobUrl.
Future<Uint8List> readBlobUrl(String blobUrl) {
  throw UnsupportedError('readBlobUrl è disponibile solo su web');
}
