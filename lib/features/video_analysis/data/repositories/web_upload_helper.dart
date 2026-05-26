import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Legge i bytes di un file blob-URL usando XHR nativo del browser.
/// Evita di allocare il buffer nel heap Dart durante la lettura.
Future<Uint8List> readBlobUrl(String blobUrl) async {
  final completer = Completer<Uint8List>();
  final xhr = html.HttpRequest();
  xhr.open('GET', blobUrl, async: true);
  xhr.responseType = 'arraybuffer';
  xhr.onLoad.listen((_) {
    if (xhr.status == 200) {
      final buffer = xhr.response as ByteBuffer;
      completer.complete(buffer.asUint8List());
    } else {
      completer.completeError(Exception('XHR status: ${xhr.status}'));
    }
  });
  xhr.onError.listen((_) {
    completer.completeError(Exception('XHR network error'));
  });
  xhr.send();
  return completer.future;
}
