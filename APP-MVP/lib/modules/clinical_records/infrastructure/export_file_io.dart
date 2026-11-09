import 'dart:io';
import 'dart:typed_data';

Future<void> writeExportFile(String? path, Uint8List bytes) async {
  if (path != null) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
}
