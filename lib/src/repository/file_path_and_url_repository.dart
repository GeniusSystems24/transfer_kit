import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../core/extension/string_extension.dart';
import '../core/file_management_config.dart';
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

  /// Get a file path and url by explicit cache key.
  /// Returns the first entry where [FilePathAndURL.cacheKey] == [cacheKey].
  FilePathAndURL? getByKey(String cacheKey) =>
      value.firstWhereOrNull((element) => element.cacheKey == cacheKey);

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

  /// Returns the cached [FilePathAndURL] for [url] (or [cacheKey]) after
  /// validating that the local file still exists.
  ///
  /// Lookup order: [cacheKey] → [url]. On any validation failure (missing file,
  /// expired entry) the stale index entry is removed and null is returned so
  /// the caller triggers a fresh download.
  Future<FilePathAndURL?> getCachedDownloadFilePathAndURL({
    required String url,
    String? cacheKey,
  }) async {
    final entry =
        (cacheKey != null ? getByKey(cacheKey) : null) ?? getByUrl(url);
    if (entry == null) return null;

    // Expiry check
    if (entry.expiresAt != null && entry.expiresAt!.isBefore(DateTime.now())) {
      remove(entry);
      return null;
    }

    // File existence check (stale detection)
    if (!await File(entry.path).exists()) {
      remove(entry);
      return null;
    }

    // SHA-256 verification (opt-in)
    if (TransferKitConfig.instance.autoExtractSha256) {
      final storedHash = entry.metadata?.sha256;
      if (storedHash != null) {
        final bytes = await File(entry.path).readAsBytes();
        final computedHash = sha256.convert(bytes).toString();
        if (computedHash != storedHash) {
          remove(entry);
          return null;
        }
      }
    }

    final updated = entry.copyWith(lastAccessedAt: DateTime.now());
    addOrUpdate(updated);
    return updated;
  }

  /// Removes index entries where the local file no longer exists on disk.
  /// Returns the count of stale entries repaired. No remote operations.
  Future<int> repairStaleEntries() async {
    final stale = <FilePathAndURL>[];
    for (final entry in value.toList()) {
      if (!await File(entry.path).exists()) stale.add(entry);
    }
    if (stale.isEmpty) return 0;
    removeAll(stale.toSet());
    return stale.length;
  }

  /// Deletes local files and removes index entries where [expiresAt] has passed.
  /// Returns the count of entries removed. No remote operations.
  Future<int> clearExpiredEntries() async {
    final now = DateTime.now();
    final expired = value
        .where((e) => e.expiresAt != null && e.expiresAt!.isBefore(now))
        .toList();
    if (expired.isEmpty) return 0;
    for (final entry in expired) {
      final file = File(entry.path);
      if (await file.exists()) await file.delete();
    }
    removeAll(expired.toSet());
    return expired.length;
  }
}
