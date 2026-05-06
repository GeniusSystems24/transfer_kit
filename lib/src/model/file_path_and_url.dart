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
  }) : data = {
          pathTag: path,
          urlTag: url,
          destinationPathTag: destinationPath,
          if (metadata != null) metadataTag: metadata.toMap(),
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
  FilePathAndURL.url({required String url, MediaMetadata? metadata})
      : data = {
          pathTag: url.toHashName().toCachedPath(),
          urlTag: url,
          if (metadata != null) metadataTag: metadata.toMap(),
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
  }) =>
      FilePathAndURL._(
        path: path,
        url: url ?? this.url,
        destinationPath: destinationPath ?? this.destinationPath,
        metadata: metadata ?? this.metadata,
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
