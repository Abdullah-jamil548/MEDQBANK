import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App-private book cache (not the phone Downloads folder).
class BookCache {
  final Map<String, Uint8List> _memory = {};

  Future<Directory?> _root() async {
    if (kIsWeb) return null;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'medqbank_books'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> pathFor(String bookId) async {
    final root = await _root();
    if (root == null) return null;
    return p.join(root.path, '$bookId.pdf');
  }

  Future<bool> isDownloaded(String bookId) async {
    if (kIsWeb) {
      return _memory.containsKey(bookId) && _memory[bookId]!.isNotEmpty;
    }
    final path = await pathFor(bookId);
    if (path == null) return false;
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0;
  }

  Future<File?> localFile(String bookId) async {
    if (kIsWeb) return null;
    final path = await pathFor(bookId);
    if (path == null) return null;
    final file = File(path);
    if (await file.exists() && await file.length() > 0) return file;
    return null;
  }

  Future<Uint8List?> memoryBytes(String bookId) async => _memory[bookId];

  Future<void> saveBytes(String bookId, Uint8List bytes) async {
    if (kIsWeb) {
      _memory[bookId] = bytes;
      return;
    }
    final path = await pathFor(bookId);
    if (path == null) return;
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<void> delete(String bookId) async {
    _memory.remove(bookId);
    if (kIsWeb) return;
    final path = await pathFor(bookId);
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
