import 'dart:io';

import '../core/extension/map_extension.dart';
import '../repository/file_path_and_url_repository.dart';
import 'package:flutter/foundation.dart';

import '../core/extension/file_path_extension.dart';
import '../core/get_storage_repository.dart';
import 'media_metadata.dart';

class FilePathAndURL extends GetStorageMethods {
  final Map<String, dynamic> data;

  FilePathAndURL._({
    required String path,
    String? url,
    String? destinationPath,
    MediaMetadata? metadata,
    String? cacheKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    DateTime? expiresAt,
  }) : data = {
         pathTag: path,
         urlTag: url,
         destinationPathTag: destinationPath,
         if (metadata != null) metadataTag: metadata.toMap(),
         if (cacheKey != null) cacheKeyTag: cacheKey,
         if (createdAt != null) createdAtTag: createdAt.toIso8601String(),
         if (updatedAt != null) updatedAtTag: updatedAt.toIso8601String(),
         if (lastAccessedAt != null)
           lastAccessedAtTag: lastAccessedAt.toIso8601String(),
         if (expiresAt != null) expiresAtTag: expiresAt.toIso8601String(),
       };

  /// Creates a FilePathAndURL for a local file to be uploaded.
  ///
  /// ## Parameters
  /// - [path]: The local file path
  /// - [destinationPath]: The Firebase Storage destination path
  /// - [metadata]: Optional metadata for the file
  ///
  /// ## Example
  /// ```dart
  /// final file = FilePathAndURL.local(
  ///   path: '/path/to/file.jpg',
  ///   destinationPath: 'uploads/file.jpg',
  ///   metadata: MediaMetadata(mimeType: 'image/jpeg'),
  /// );
  /// ```
  FilePathAndURL.local({
    required String path,
    required String destinationPath,
    MediaMetadata? metadata,
  }) : data = {
         pathTag: path,
         destinationPathTag: destinationPath,
         if (metadata != null) metadataTag: metadata.toMap(),
       };

  /// Creates a FilePathAndURL for a remote file to be downloaded.
  ///
  /// ## Parameters
  /// - [url]: The Firebase Storage URL
  /// - [metadata]: Optional metadata for the file (e.g., from API response)
  ///
  /// ## Example
  /// ```dart
  /// final file = FilePathAndURL.url(
  ///   url: 'https://firebasestorage.googleapis.com/.../image.jpg',
  ///   metadata: MediaMetadata(
  ///     mimeType: 'image/jpeg',
  ///     width: 1920,
  ///     height: 1080,
  ///   ),
  /// );
  /// ```
  FilePathAndURL.url({
    required String url,
    MediaMetadata? metadata,
    String? cacheKey,
    DateTime? expiresAt,
  }) : data = {
         pathTag: (cacheKey ?? url).toHashName().toCachedPath(),
         urlTag: url,
         if (metadata != null) metadataTag: metadata.toMap(),
         if (cacheKey != null) cacheKeyTag: cacheKey,
         if (expiresAt != null) expiresAtTag: expiresAt.toIso8601String(),
       };

  FilePathAndURL.fromMap(this.data);

  /// The path of the file
  String get path => data.getString(pathTag)!;
  set path(String value) => data[pathTag] = value;
  static const String pathTag = 'path';

  /// The url of the file
  String? get url => data.getString(urlTag);
  set url(String? value) => data[urlTag] = value;
  static const String urlTag = 'url';

  /// The Firebase Storage path of the file
  String? get destinationPath => data.getString(destinationPathTag);
  set destinationPath(String? value) => data[destinationPathTag] = value;
  static const String destinationPathTag = 'destinationPath';

  /// Media metadata for the file (dimensions, duration, etc.)
  ///
  /// This metadata is automatically cached with the file and can be used
  /// for display purposes without needing to extract it again.
  MediaMetadata? get metadata {
    final metadataMap = data[metadataTag] as Map<String, dynamic>?;
    return metadataMap != null ? MediaMetadata.fromMap(metadataMap) : null;
  }

  set metadata(MediaMetadata? value) {
    if (value != null) {
      data[metadataTag] = value.toMap();
    } else {
      data.remove(metadataTag);
    }
  }

  static const String metadataTag = 'metadata';

  /// Explicit stable cache key used instead of the URL as the hash input.
  String? get cacheKey => data.getString(cacheKeyTag);
  set cacheKey(String? value) => data[cacheKeyTag] = value;
  static const String cacheKeyTag = 'cacheKey';

  /// When this cache entry was first created.
  DateTime? get createdAt => data.getDateTime(createdAtTag);
  set createdAt(DateTime? value) =>
      data[createdAtTag] = value?.toIso8601String();
  static const String createdAtTag = 'createdAt';

  /// When this cache entry was last updated (download completed or entry modified).
  DateTime? get updatedAt => data.getDateTime(updatedAtTag);
  set updatedAt(DateTime? value) =>
      data[updatedAtTag] = value?.toIso8601String();
  static const String updatedAtTag = 'updatedAt';

  /// When this cached file was last served to a caller.
  DateTime? get lastAccessedAt => data.getDateTime(lastAccessedAtTag);
  set lastAccessedAt(DateTime? value) =>
      data[lastAccessedAtTag] = value?.toIso8601String();
  static const String lastAccessedAtTag = 'lastAccessedAt';

  /// Optional expiry; entry is treated as a cache miss after this time.
  DateTime? get expiresAt => data.getDateTime(expiresAtTag);
  set expiresAt(DateTime? value) =>
      data[expiresAtTag] = value?.toIso8601String();
  static const String expiresAtTag = 'expiresAt';

  String get fileName => url?.extractFileName() ?? path.fileName;

  File? _file;
  File get file {
    assert(_file != null, 'You must call ensureFileExists first');
    return _file!;
  }

  /// Returns the file name as the hash
  Future<bool> ensureFileExists() async {
    if (_file != null) return true;
    final file = File(path);

    if (!await file.exists()) return false;

    _file = file;
    return true;
  }

  Map<String, dynamic> toMap() => data;

  @override
  int get hashCode => path.hashCode;

  @override
  bool operator ==(Object other) =>
      other is FilePathAndURL && other.hashCode == hashCode;

  /// Creates a copy of this FilePathAndURL with the specified fields replaced.
  FilePathAndURL copyWith({
    String? url,
    String? destinationPath,
    MediaMetadata? metadata,
    String? cacheKey,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastAccessedAt,
    DateTime? expiresAt,
  }) => FilePathAndURL._(
    path: path,
    url: url ?? this.url,
    destinationPath: destinationPath ?? this.destinationPath,
    metadata: metadata ?? this.metadata,
    cacheKey: cacheKey ?? this.cacheKey,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    expiresAt: expiresAt ?? this.expiresAt,
  );

  /// Creates a copy with merged metadata from another source.
  ///
  /// This is useful when combining metadata from different sources
  /// (e.g., API response + local extraction).
  ///
  /// ## Example
  /// ```dart
  /// // Original from API
  /// final fromApi = FilePathAndURL.url(
  ///   url: imageUrl,
  ///   metadata: MediaMetadata(mimeType: 'image/jpeg', fileSize: 1024),
  /// );
  ///
  /// // After local extraction
  /// final localMetadata = MediaMetadata(width: 1920, height: 1080);
  /// final merged = fromApi.copyWithMergedMetadata(localMetadata);
  /// // merged.metadata now has: mimeType, fileSize, width, height
  /// ```
  FilePathAndURL copyWithMergedMetadata(MediaMetadata? newMetadata) {
    if (newMetadata == null) return this;

    return FilePathAndURL._(
      path: path,
      url: url,
      destinationPath: destinationPath,
      metadata: metadata?.mergeWith(newMetadata) ?? newMetadata,
      cacheKey: cacheKey,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastAccessedAt: lastAccessedAt,
      expiresAt: expiresAt,
    );
  }

  /// if there are changes in the data.
  ///
  /// Returns true if path is the same and data is different, otherwise false.
  /// that is means that data has been changed.
  @override
  bool operator ^(covariant FilePathAndURL other) {
    if (other.hashCode != hashCode) return false;

    if (identical(this, other)) return false;

    final thisData = Map<String, dynamic>.from(data);
    final otherData = Map<String, dynamic>.from(other.data);

    /// compare the data
    return !mapEquals(thisData, otherData);
  }

  @override
  void update(Object item) {
    if (item is! FilePathAndURL) return;
    data.updateAll((key, value) => item.data[key]);
  }

  @override
  String toString() =>
      'FilePathAndURL(path: $path, url: $url, destinationPath: $destinationPath, hasMetadata: ${metadata != null})';
}

extension FilePathAndURLX on String {
  FilePathAndURL? get realFilePathAndUrl =>
      FilePathAndURLRepository.instance.getByPathOrUrl(path: this, url: this);
}
