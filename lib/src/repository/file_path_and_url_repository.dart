import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../core/extension/string_extension.dart';
import '../core/get_storage_repository.dart';
import '../model/file_path_and_url.dart';

class FilePathAndURLRepository extends GetStorageRepository<FilePathAndURL> {
  static const String _storageKey = 'file_path_url';
  static final FilePathAndURLRepository instance =
      FilePathAndURLRepository._internal();

  FilePathAndURLRepository._internal() : super(_storageKey, {});

  factory FilePathAndURLRepository() => instance;

  @override
  @protected
  String inputConverter(Set<FilePathAndURL> val) {
    return json.encode(val.map((value) => value.toMap()).toList());
  }

  @override
  @protected
  Set<FilePathAndURL> outputConverter(String? value) =>
      value
          ?.toListMap()
          .map((value) => FilePathAndURL.fromMap(value))
          .toSet() ??
      <FilePathAndURL>{};

  // FilePath and URL getters

  /// Get a file path and url by its path
  /// Returns the first [FilePathAndURL] that matches the path or null if not found
  FilePathAndURL? getByPath(String path) =>
      value.firstWhereOrNull((element) => element.path == path);

  /// Get a file path and url by its url
  /// Returns the first [FilePathAndURL] that matches the url or null if not found
  FilePathAndURL? getByUrl(String url) =>
      value.firstWhereOrNull((element) => element.url == url);

  /// Get a file path and url by its path or url
  /// Returns the first [FilePathAndURL] that matches the path or url or null if not found
  FilePathAndURL? getByPathOrUrl({String? path, String? url}) {
    if (path == null && url == null) return null;
    if (path == null) return getByUrl(url!);
    if (url == null) return getByPath(path);

    return value.firstWhereOrNull(
      (element) => element.path == path || element.url == url,
    );
  }

  /// Get a file path and url by its path or url
  /// Returns the first [FilePathAndURL] that matches the path or url or null if not found
  Future<FilePathAndURL?> getUploadFilePathAndURL({
    required String path,
    required String destinationPath,
  }) async {
    final filePathAndUrl = FilePathAndURL.local(
      path: path,
      destinationPath: destinationPath,
    );
    final cachedFilePathAndUrl = FilePathAndURLRepository.instance.getByPath(
      filePathAndUrl.path,
    );

    // Check if the file is already uploaded
    if (cachedFilePathAndUrl != null &&
        await cachedFilePathAndUrl.ensureFileExists()) {
      return cachedFilePathAndUrl;
    } else {
      if (await filePathAndUrl.ensureFileExists()) return filePathAndUrl;
    }

    return null;
  }

  /// Get a file path and url by its url
  /// Returns the first [FilePathAndURL] that matches the url or null if not found
  Future<FilePathAndURL?> getCachedDownloadFilePathAndURL({
    required String url,
  }) async {
    final cachedFilePathAndUrl = FilePathAndURLRepository.instance.getByUrl(url);

    // Check if the file is already uploaded
    if (cachedFilePathAndUrl != null &&
        await cachedFilePathAndUrl.ensureFileExists()) {
      return cachedFilePathAndUrl;
    }

    return null;
  }
}
