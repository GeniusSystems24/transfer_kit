import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../core/extension/file_path_extension.dart';
import '../core/extension/map_extension.dart';
import '../core/extension/list_extension.dart';
import 'file_path_and_url.dart';

/// Model for storing file thumbnail and metadata information.
///
/// This class encapsulates metadata about a file's visual representation
/// including dimensions, duration (for audio/video), and thumbnail data.
///
/// ## Usage
/// ```dart
/// final thumbnail = FileThumbnailModel(
///   size: 1024,
///   width: 640,
///   height: 480,
///   thumbnail: imageBytes,
///   durationInSeconds: 120,
/// );
/// ```
class FileThumbnailModel {
  final Map<String, dynamic> data;

  /// Creates a FileThumbnailModel from a map.
  FileThumbnailModel.fromMap(this.data);

  /// Converts the model to a map (excludes null values).
  Map<String, dynamic> toMap() => data.withoutNullValues();

  /// Creates a new FileThumbnailModel with the specified properties.
  FileThumbnailModel({
    int? size,
    int? width,
    int? height,
    Uint8List? thumbnail,
    int? durationInSeconds,
    Map<String, dynamic>? mimeType,
  }) : data = {
         sizeTag: size,
         widthTag: width,
         heightTag: height,
         thumbnailTag: thumbnail?.toList().toJson(),
         durationInSecondsTag: durationInSeconds,
         mimeTypeTag: mimeType,
       };

  /// File size in bytes.
  int? get size => data.getInt(sizeTag);
  set size(int? value) => data[sizeTag] = value;
  static const String sizeTag = 'size';

  /// Width in pixels.
  int? get width => data.getInt(widthTag);
  set width(int? value) => data[widthTag] = value;
  static const String widthTag = 'width';

  /// Height in pixels.
  int? get height => data.getInt(heightTag);
  set height(int? value) => data[heightTag] = value;
  static const String heightTag = 'height';

  /// Aspect ratio (width / height).
  double? get aspectRatio =>
      width == null || height == null || height == 0 ? null : width! / height!;

  /// Thumbnail image data as bytes.
  Uint8List? get thumbnail => data.getUint8List(thumbnailTag);
  set thumbnail(Uint8List? value) =>
      data[thumbnailTag] = value?.toList().toJson();
  static const String thumbnailTag = 'thumbnail';

  /// Duration in seconds (for audio/video files).
  int? get durationInSeconds => data.getInt(durationInSecondsTag);
  set durationInSeconds(int? value) => data[durationInSecondsTag] = value;
  static const String durationInSecondsTag = 'durationInSeconds';

  /// MIME type information.
  Map<String, dynamic>? get mimeType => data.getMap(mimeTypeTag);
  set mimeType(Map<String, dynamic>? value) => data[mimeTypeTag] = value;
  static const String mimeTypeTag = 'mimeType';

  /// Creates a copy with updated properties.
  FileThumbnailModel copyWith({
    int? size,
    int? width,
    int? height,
    Uint8List? thumbnail,
    int? durationInSeconds,
    Map<String, dynamic>? mimeType,
  }) => FileThumbnailModel(
    size: size ?? this.size,
    width: width ?? this.width,
    height: height ?? this.height,
    thumbnail: thumbnail ?? this.thumbnail,
    durationInSeconds: durationInSeconds ?? this.durationInSeconds,
    mimeType: mimeType ?? this.mimeType,
  );

  @override
  String toString() {
    return 'FileThumbnailModel(size: $size, width: $width, height: $height, thumbnail: $thumbnail, durationInSeconds: $durationInSeconds, mimeType: $mimeType)';
  }
}

/// Comprehensive file model with metadata for uploads/downloads.
///
/// This model represents a file with both local and remote information,
/// including paths, URLs, metadata, and thumbnail information.
///
/// ## Usage
/// ```dart
/// // Create a local file model for upload
/// final localFile = FileModel.local(
///   localPath: '/path/to/file.jpg',
///   destinationPath: 'uploads/images/',
/// );
///
/// // Create a remote file model for download
/// final remoteFile = FileModel.remote(
///   url: 'https://firebase.storage/file.jpg',
/// );
/// ```
class FileModel {
  /// Creates a FileModel from a map.
  FileModel.fromMap(this.data);

  /// Converts the model to a map.
  Map<String, dynamic> toMap() {
    final map = data.withoutNullValues();
    return map;
  }

  FileModel._({
    String? url,
    String? localPath,
    String? destinationPath,
    int? size,
    int? width,
    int? height,
    Uint8List? thumbnail,
    int? durationInSeconds,
    Map<String, dynamic>? mimeType,
    String? fileName,
  }) : data = {
         fileNameTag: fileName,
         urlTag: url,
         localPathTag: localPath,
         destinationPathTag: destinationPath,
         sizeTag: size,
         widthTag: width,
         heightTag: height,
         thumbnailTag: thumbnail?.toList().toJson(),
         durationInSecondsTag: durationInSeconds,
         mimeTypeTag: mimeType,
       };

  /// Creates a FileModel for a local file.
  ///
  /// ## Parameters
  /// * [localPath] - Path to the local file
  /// * [destinationPath] - Optional Firebase Storage destination path
  FileModel.local({
    required String localPath,
    String? fileName,
    String? destinationPath,
    int? size,
    int? width,
    int? height,
    Uint8List? thumbnail,
    int? durationInSeconds,
    Map<String, dynamic>? mimeType,
  }) : this._(
         fileName: fileName ?? localPath.fileName,
         localPath: localPath,
         destinationPath:
             destinationPath == null
                 ? null
                 : destinationPath.contains('.')
                 ? destinationPath
                 : '$destinationPath/${localPath.fileName}'.replaceAll(
                   '//',
                   '/',
                 ),
         size: size,
         width: width,
         height: height,
         thumbnail: thumbnail,
         durationInSeconds: durationInSeconds,
         mimeType: mimeType,
       );

  /// Creates a FileModel for a remote file.
  ///
  /// ## Parameters
  /// * [url] - Firebase Storage download URL
  FileModel.remote({
    required String url,
    String? fileName,
    String? destinationPath,
    int? size,
    int? width,
    int? height,
    Uint8List? thumbnail,
    int? durationInSeconds,
    Map<String, dynamic>? mimeType,
  }) : this._(
         fileName: fileName ?? url.extractFileName(),
         url: url,
         destinationPath: destinationPath,
         size: size,
         width: width,
         height: height,
         thumbnail: thumbnail,
         durationInSeconds: durationInSeconds,
         mimeType: mimeType,
       );

  final Map<String, dynamic> data;

  /// Local file path.
  String? get localPath => data.getString(localPathTag);
  set localPath(String? value) => data[localPathTag] = value;
  static const String localPathTag = 'localPath';

  /// Firebase Storage destination path.
  String? get destinationPath => data.getString(destinationPathTag);
  set destinationPath(String? value) => data[destinationPathTag] = value;
  static const String destinationPathTag = 'destinationPath';

  /// Remote download URL.
  String? get url => data.getString(urlTag);
  set url(String? value) => data[urlTag] = value;
  static const String urlTag = 'url';

  /// File size in bytes.
  int? get size => data.getInt(sizeTag);
  set size(int? value) => data[sizeTag] = value;
  static const String sizeTag = 'size';

  /// Width in pixels.
  int? get width => data.getInt(widthTag);
  set width(int? value) => data[widthTag] = value;
  static const String widthTag = 'width';

  /// Height in pixels.
  int? get height => data.getInt(heightTag);
  set height(int? value) => data[heightTag] = value;
  static const String heightTag = 'height';

  /// Aspect ratio (width / height).
  double? get aspectRatio =>
      width == null || height == null || height == 0 ? null : width! / height!;

  /// Thumbnail data.
  Uint8List? get thumbnail => data.getUint8List(thumbnailTag);
  set thumbnail(Uint8List? value) =>
      data[thumbnailTag] = value?.toList().toJson();
  static const String thumbnailTag = 'thumbnail';

  /// Waveform data for audio files.
  List<double>? get waveform => thumbnail?.toList().map((e) => e / 1).toList();

  /// Duration in seconds.
  int? get durationInSeconds => data.getInt(durationInSecondsTag);
  set durationInSeconds(int? value) => data[durationInSecondsTag] = value;
  static const String durationInSecondsTag = 'durationInSeconds';

  /// MIME type information.
  Map<String, dynamic>? get mimeType => data.getMap(mimeTypeTag);
  set mimeType(Map<String, dynamic>? value) => data[mimeTypeTag] = value;
  static const String mimeTypeTag = 'mimeType';

  /// File name.
  String? get fileName {
    var name =
        data.getString(fileNameTag) ??
        (localPath?.fileName ?? url?.extractFileName());
    return name;
  }

  set fileName(String? value) => data[fileNameTag] = value;
  static const String fileNameTag = 'fileName';

  /// Page count (for PDF documents).
  int? get pageCount => data.getInt(pageCountTag);
  set pageCount(int? value) => data[pageCountTag] = value;
  static const String pageCountTag = 'pageCount';

  /// File type based on extension.
  FileTypeEnum get fileType => fileName?.getFileType() ?? FileTypeEnum.file;

  /// Returns a FilePathAndURL for upload operations.
  FilePathAndURL? get fileUploadPathAndUrl =>
      localPath == null
          ? null
          : FilePathAndURL.local(
            path: localPath!,
            destinationPath: destinationPath!,
          );

  /// Returns a FilePathAndURL for download operations.
  FilePathAndURL? get fileDownloadPathAndUrl =>
      url == null ? null : FilePathAndURL.url(url: url!);

  @override
  int get hashCode => Object.hash(url, localPath);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileModel &&
          runtimeType == other.runtimeType &&
          localPath == other.localPath &&
          url == other.url;

  /// Creates a copy with updated properties.
  FileModel copyWith({
    String? url,
    String? localPath,
    String? destinationPath,
    int? size,
    int? width,
    int? height,
    Uint8List? thumbnail,
    int? durationInSeconds,
    Map<String, dynamic>? mimeType,
  }) => FileModel._(
    url: url ?? this.url!,
    localPath: localPath ?? this.localPath,
    destinationPath: destinationPath ?? this.destinationPath,
    size: size ?? this.size,
    width: width ?? this.width,
    height: height ?? this.height,
    thumbnail: thumbnail ?? this.thumbnail,
    durationInSeconds: durationInSeconds ?? this.durationInSeconds,
    mimeType: mimeType ?? this.mimeType,
  );

  /// Returns the thumbnail model.
  FileThumbnailModel get fileThumbnail => FileThumbnailModel.fromMap(data);

  @override
  String toString() {
    return 'FileModel(url: $url, localPath: $localPath, destinationPath: $destinationPath, size: $size, width: $width, height: $height, thumbnail: $thumbnail, durationInSeconds: $durationInSeconds, mimeType: $mimeType)';
  }
}

/// Enum representing different file types based on extensions.
///
/// Used for determining file handling and display strategies.
enum FileTypeEnum {
  /// Image files (png, jpg, jpeg, gif, bmp, webp).
  image(0, 'image', 'Pictures', {'png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'}),

  /// Video files (mp4, avi, mkv, mov, wmv).
  video(1, 'video', 'Movies', {'mp4', 'avi', 'mkv', 'mov', 'wmv'}),

  /// Audio files (mp3, wav, aac, flac, ogg, m4a).
  audio(3, 'audio', 'Audios', {'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a'}),

  /// Document files (pdf, doc, docx, etc.).
  file(2, 'document', 'Documents', {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
  });

  /// Numeric value for storage.
  final int value;

  /// Tag name for identification.
  final String tag;

  /// Directory name for organization.
  final String fileName;

  /// Supported file extensions.
  final Set<String> extensions;

  const FileTypeEnum(this.value, this.tag, this.fileName, this.extensions);

  /// Gets FileTypeEnum by numeric value.
  static FileTypeEnum? getOf(int? value) =>
      values.firstWhereOrNull((element) => element.value == value);

  /// Gets FileTypeEnum by name.
  static FileTypeEnum? getOfName(String? name) =>
      values.firstWhereOrNull((element) => element.name == name);
}
