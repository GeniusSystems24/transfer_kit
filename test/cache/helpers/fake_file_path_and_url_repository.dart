import 'dart:io';

import 'package:get_storage/get_storage.dart';
import 'package:transfer_kit/src/model/file_path_and_url.dart';
import 'package:transfer_kit/src/repository/file_path_and_url_repository.dart';

/// Initializes GetStorage so FilePathAndURLRepository works in tests.
/// Call once in setUpAll.
Future<void> initCacheTestStorage() async {
  await GetStorage.init();
}

/// Clears FilePathAndURLRepository between tests. Call in setUp.
void resetCacheRepository() {
  FilePathAndURLRepository.instance.clear(notify: false);
}

/// Creates a temporary file with [content] bytes and returns its path.
/// The caller is responsible for deleting it in tearDown.
Future<File> createTempFile({List<int>? content}) async {
  final tmp = await Directory.systemTemp.createTemp('cache_test_');
  final file = File('${tmp.path}/file.bin');
  await file.writeAsBytes(content ?? [1, 2, 3, 4, 5]);
  return file;
}

/// Adds a [FilePathAndURL] entry to the real repository pointing at [file].
///
/// The entry's `path` is set to [file.path] so existence checks pass.
FilePathAndURL addCacheEntry({
  required String url,
  required File file,
  String? cacheKey,
  DateTime? expiresAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final entry =
      FilePathAndURL.url(
        url: url,
        cacheKey: cacheKey,
        expiresAt: expiresAt,
      ).copyWith(
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: updatedAt ?? DateTime.now(),
      );

  // Override path to point at the real temp file
  entry.data[FilePathAndURL.pathTag] = file.path;

  FilePathAndURLRepository.instance.addOrUpdate(entry);
  return entry;
}
