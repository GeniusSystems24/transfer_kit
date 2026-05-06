
import 'package:flutter/foundation.dart';

/// Represents waveform data for audio files.
///
/// This class stores amplitude samples that can be used to render
/// audio waveform visualizations.
///
/// ## Example
/// ```dart
/// final waveform = WaveformData(
///   samples: [0.1, 0.5, 0.8, 0.3, ...],
///   sampleRate: 44100,
///   channels: 2,
/// );
/// ```
class WaveformData {
  /// Normalized amplitude samples (0.0 to 1.0)
  final List<double> samples;

  /// Sample rate in Hz (e.g., 44100)
  final int? sampleRate;

  /// Number of audio channels (1 = mono, 2 = stereo)
  final int? channels;

  /// Peak amplitude value
  final double? peakAmplitude;

  /// Average amplitude value
  final double? averageAmplitude;

  const WaveformData({
    required this.samples,
    this.sampleRate,
    this.channels,
    this.peakAmplitude,
    this.averageAmplitude,
  });

  /// Creates WaveformData from a JSON map.
  factory WaveformData.fromMap(Map<String, dynamic> map) {
    return WaveformData(
      samples: (map['samples'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      sampleRate: map['sampleRate'] as int?,
      channels: map['channels'] as int?,
      peakAmplitude: (map['peakAmplitude'] as num?)?.toDouble(),
      averageAmplitude: (map['averageAmplitude'] as num?)?.toDouble(),
    );
  }

  /// Converts this WaveformData to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      'samples': samples,
      if (sampleRate != null) 'sampleRate': sampleRate,
      if (channels != null) 'channels': channels,
      if (peakAmplitude != null) 'peakAmplitude': peakAmplitude,
      if (averageAmplitude != null) 'averageAmplitude': averageAmplitude,
    };
  }

  /// Creates a copy with merged data from another WaveformData.
  /// Non-null values from [other] take precedence.
  WaveformData mergeWith(WaveformData? other) {
    if (other == null) return this;
    return WaveformData(
      samples: other.samples.isNotEmpty ? other.samples : samples,
      sampleRate: other.sampleRate ?? sampleRate,
      channels: other.channels ?? channels,
      peakAmplitude: other.peakAmplitude ?? peakAmplitude,
      averageAmplitude: other.averageAmplitude ?? averageAmplitude,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WaveformData &&
          listEquals(samples, other.samples) &&
          sampleRate == other.sampleRate &&
          channels == other.channels;

  @override
  int get hashCode => Object.hash(samples, sampleRate, channels);

  @override
  String toString() =>
      'WaveformData(samples: ${samples.length}, sampleRate: $sampleRate, channels: $channels)';
}

/// Represents thumbnail data for images, videos, or documents.
///
/// Thumbnails can be stored as raw bytes or as a base64 encoded string.
///
/// ## Example
/// ```dart
/// final thumbnail = ThumbnailData(
///   bytes: thumbnailBytes,
///   width: 200,
///   height: 150,
///   mimeType: 'image/jpeg',
/// );
/// ```
class ThumbnailData {
  /// Raw thumbnail image bytes.
  /// Note: This is not persisted to cache, use [base64] for persistence.
  final Uint8List? bytes;

  /// Base64 encoded thumbnail data (for persistence)
  final String? base64;

  /// Thumbnail width in pixels
  final int? width;

  /// Thumbnail height in pixels
  final int? height;

  /// MIME type of the thumbnail (e.g., 'image/jpeg')
  final String? mimeType;

  /// Timestamp when thumbnail was generated
  final DateTime? generatedAt;

  const ThumbnailData({
    this.bytes,
    this.base64,
    this.width,
    this.height,
    this.mimeType,
    this.generatedAt,
  });

  /// Creates ThumbnailData from a JSON map.
  factory ThumbnailData.fromMap(Map<String, dynamic> map) {
    return ThumbnailData(
      base64: map['base64'] as String?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      mimeType: map['mimeType'] as String?,
      generatedAt: map['generatedAt'] != null
          ? DateTime.tryParse(map['generatedAt'] as String)
          : null,
    );
  }

  /// Converts this ThumbnailData to a JSON map.
  /// Note: [bytes] is not included, only [base64] for persistence.
  Map<String, dynamic> toMap() {
    return {
      if (base64 != null) 'base64': base64,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (mimeType != null) 'mimeType': mimeType,
      if (generatedAt != null) 'generatedAt': generatedAt!.toIso8601String(),
    };
  }

  /// Returns true if thumbnail data is available (either bytes or base64)
  bool get hasData => bytes != null || base64 != null;

  /// Creates a copy with merged data from another ThumbnailData.
  /// Non-null values from [other] take precedence.
  ThumbnailData mergeWith(ThumbnailData? other) {
    if (other == null) return this;
    return ThumbnailData(
      bytes: other.bytes ?? bytes,
      base64: other.base64 ?? base64,
      width: other.width ?? width,
      height: other.height ?? height,
      mimeType: other.mimeType ?? mimeType,
      generatedAt: other.generatedAt ?? generatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ThumbnailData &&
          base64 == other.base64 &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(base64, width, height);

  @override
  String toString() =>
      'ThumbnailData(width: $width, height: $height, mimeType: $mimeType, hasData: $hasData)';
}

/// Comprehensive metadata for media files.
///
/// This class stores metadata for various file types including:
/// - Images: dimensions, orientation, color profile
/// - Videos: dimensions, duration, frame rate, codec
/// - Audio: duration, bitrate, waveform data
/// - Documents: page count, title, author
///
/// ## Example
/// ```dart
/// final metadata = MediaMetadata(
///   mimeType: 'image/jpeg',
///   fileSize: 1024000,
///   width: 1920,
///   height: 1080,
///   createdAt: DateTime.now(),
/// );
/// ```
class MediaMetadata {
  // ═══════════════════════════════════════════════════════════════════════════
  // Common Properties
  // ═══════════════════════════════════════════════════════════════════════════

  /// MIME type of the file (e.g., 'image/jpeg', 'video/mp4')
  final String? mimeType;

  /// File size in bytes
  final int? fileSize;

  /// SHA-256 hash of the file content
  final String? sha256;

  /// Original file name
  final String? fileName;

  /// File extension without dot (e.g., 'jpg', 'mp4')
  final String? fileExtension;

  /// When the file was created
  final DateTime? createdAt;

  /// When the file was last modified
  final DateTime? modifiedAt;

  /// Source of the metadata (api, firebase, cache, local)
  final MetadataSource? source;

  // ═══════════════════════════════════════════════════════════════════════════
  // Image & Video Properties
  // ═══════════════════════════════════════════════════════════════════════════

  /// Width in pixels (for images and videos)
  final int? width;

  /// Height in pixels (for images and videos)
  final int? height;

  /// Aspect ratio (width / height)
  double? get aspectRatio =>
      (width != null && height != null && height! > 0)
          ? width! / height!
          : null;

  /// Image orientation from EXIF (1-8)
  final int? orientation;

  /// Color space (e.g., 'sRGB', 'Adobe RGB')
  final String? colorSpace;

  /// Bits per pixel/sample
  final int? bitDepth;

  /// Whether the image/video has alpha channel
  final bool? hasAlpha;

  // ═══════════════════════════════════════════════════════════════════════════
  // Video & Audio Properties
  // ═══════════════════════════════════════════════════════════════════════════

  /// Duration in seconds (for video and audio)
  final double? durationInSeconds;

  /// Duration as Duration object
  Duration? get duration => durationInSeconds != null
      ? Duration(milliseconds: (durationInSeconds! * 1000).round())
      : null;

  /// Video frame rate (fps)
  final double? frameRate;

  /// Video codec (e.g., 'h264', 'hevc', 'vp9')
  final String? videoCodec;

  /// Audio codec (e.g., 'aac', 'mp3', 'opus')
  final String? audioCodec;

  /// Audio bitrate in bits per second
  final int? audioBitrate;

  /// Video bitrate in bits per second
  final int? videoBitrate;

  /// Audio sample rate in Hz
  final int? audioSampleRate;

  /// Number of audio channels
  final int? audioChannels;

  /// Waveform data for audio visualization
  final WaveformData? waveform;

  // ═══════════════════════════════════════════════════════════════════════════
  // Document Properties
  // ═══════════════════════════════════════════════════════════════════════════

  /// Number of pages (for PDF and documents)
  final int? pageCount;

  /// Document title
  final String? title;

  /// Document author
  final String? author;

  /// Document subject/description
  final String? subject;

  /// Keywords/tags
  final List<String>? keywords;

  // ═══════════════════════════════════════════════════════════════════════════
  // Thumbnail
  // ═══════════════════════════════════════════════════════════════════════════

  /// Thumbnail data for preview
  final ThumbnailData? thumbnail;

  // ═══════════════════════════════════════════════════════════════════════════
  // Custom Properties
  // ═══════════════════════════════════════════════════════════════════════════

  /// Additional custom metadata
  final Map<String, dynamic>? customData;

  const MediaMetadata({
    // Common
    this.mimeType,
    this.fileSize,
    this.sha256,
    this.fileName,
    this.fileExtension,
    this.createdAt,
    this.modifiedAt,
    this.source,
    // Image & Video
    this.width,
    this.height,
    this.orientation,
    this.colorSpace,
    this.bitDepth,
    this.hasAlpha,
    // Video & Audio
    this.durationInSeconds,
    this.frameRate,
    this.videoCodec,
    this.audioCodec,
    this.audioBitrate,
    this.videoBitrate,
    this.audioSampleRate,
    this.audioChannels,
    this.waveform,
    // Document
    this.pageCount,
    this.title,
    this.author,
    this.subject,
    this.keywords,
    // Thumbnail
    this.thumbnail,
    // Custom
    this.customData,
  });

  /// Creates MediaMetadata from a JSON map.
  factory MediaMetadata.fromMap(Map<String, dynamic> map) {
    return MediaMetadata(
      // Common
      mimeType: map['mimeType'] as String?,
      fileSize: map['fileSize'] as int?,
      sha256: map['sha256'] as String?,
      fileName: map['fileName'] as String?,
      fileExtension: map['fileExtension'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
      modifiedAt: map['modifiedAt'] != null
          ? DateTime.tryParse(map['modifiedAt'] as String)
          : null,
      source: map['source'] != null
          ? MetadataSource.values.firstWhere(
              (e) => e.name == map['source'],
              orElse: () => MetadataSource.unknown,
            )
          : null,
      // Image & Video
      width: map['width'] as int?,
      height: map['height'] as int?,
      orientation: map['orientation'] as int?,
      colorSpace: map['colorSpace'] as String?,
      bitDepth: map['bitDepth'] as int?,
      hasAlpha: map['hasAlpha'] as bool?,
      // Video & Audio
      durationInSeconds: (map['durationInSeconds'] as num?)?.toDouble(),
      frameRate: (map['frameRate'] as num?)?.toDouble(),
      videoCodec: map['videoCodec'] as String?,
      audioCodec: map['audioCodec'] as String?,
      audioBitrate: map['audioBitrate'] as int?,
      videoBitrate: map['videoBitrate'] as int?,
      audioSampleRate: map['audioSampleRate'] as int?,
      audioChannels: map['audioChannels'] as int?,
      waveform: map['waveform'] != null
          ? WaveformData.fromMap(map['waveform'] as Map<String, dynamic>)
          : null,
      // Document
      pageCount: map['pageCount'] as int?,
      title: map['title'] as String?,
      author: map['author'] as String?,
      subject: map['subject'] as String?,
      keywords: (map['keywords'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      // Thumbnail
      thumbnail: map['thumbnail'] != null
          ? ThumbnailData.fromMap(map['thumbnail'] as Map<String, dynamic>)
          : null,
      // Custom
      customData: map['customData'] as Map<String, dynamic>?,
    );
  }

  /// Converts this MediaMetadata to a JSON map.
  Map<String, dynamic> toMap() {
    return {
      // Common
      if (mimeType != null) 'mimeType': mimeType,
      if (fileSize != null) 'fileSize': fileSize,
      if (sha256 != null) 'sha256': sha256,
      if (fileName != null) 'fileName': fileName,
      if (fileExtension != null) 'fileExtension': fileExtension,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
      if (source != null) 'source': source!.name,
      // Image & Video
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (orientation != null) 'orientation': orientation,
      if (colorSpace != null) 'colorSpace': colorSpace,
      if (bitDepth != null) 'bitDepth': bitDepth,
      if (hasAlpha != null) 'hasAlpha': hasAlpha,
      // Video & Audio
      if (durationInSeconds != null) 'durationInSeconds': durationInSeconds,
      if (frameRate != null) 'frameRate': frameRate,
      if (videoCodec != null) 'videoCodec': videoCodec,
      if (audioCodec != null) 'audioCodec': audioCodec,
      if (audioBitrate != null) 'audioBitrate': audioBitrate,
      if (videoBitrate != null) 'videoBitrate': videoBitrate,
      if (audioSampleRate != null) 'audioSampleRate': audioSampleRate,
      if (audioChannels != null) 'audioChannels': audioChannels,
      if (waveform != null) 'waveform': waveform!.toMap(),
      // Document
      if (pageCount != null) 'pageCount': pageCount,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (subject != null) 'subject': subject,
      if (keywords != null) 'keywords': keywords,
      // Thumbnail
      if (thumbnail != null) 'thumbnail': thumbnail!.toMap(),
      // Custom
      if (customData != null) 'customData': customData,
    };
  }

  /// Returns true if this metadata has any meaningful data.
  bool get hasData =>
      mimeType != null ||
      fileSize != null ||
      width != null ||
      height != null ||
      durationInSeconds != null;

  /// Returns true if this is image metadata.
  bool get isImage =>
      mimeType?.startsWith('image/') == true ||
      (width != null && height != null && durationInSeconds == null);

  /// Returns true if this is video metadata.
  bool get isVideo =>
      mimeType?.startsWith('video/') == true ||
      (width != null && height != null && durationInSeconds != null);

  /// Returns true if this is audio metadata.
  bool get isAudio =>
      mimeType?.startsWith('audio/') == true ||
      (durationInSeconds != null && width == null);

  /// Returns true if this is document metadata.
  bool get isDocument =>
      mimeType?.startsWith('application/pdf') == true ||
      mimeType?.contains('document') == true ||
      pageCount != null;

  /// Creates a copy with merged data from another MediaMetadata.
  ///
  /// Non-null values from [other] take precedence over this instance's values.
  /// This is useful for combining metadata from different sources.
  ///
  /// ## Example
  /// ```dart
  /// final apiMetadata = MediaMetadata(mimeType: 'image/jpeg', fileSize: 1024);
  /// final localMetadata = MediaMetadata(width: 1920, height: 1080);
  /// final merged = apiMetadata.mergeWith(localMetadata);
  /// // merged now has all four properties
  /// ```
  MediaMetadata mergeWith(MediaMetadata? other) {
    if (other == null) return this;

    return MediaMetadata(
      // Common - prefer other's values if not null
      mimeType: other.mimeType ?? mimeType,
      fileSize: other.fileSize ?? fileSize,
      sha256: other.sha256 ?? sha256,
      fileName: other.fileName ?? fileName,
      fileExtension: other.fileExtension ?? fileExtension,
      createdAt: other.createdAt ?? createdAt,
      modifiedAt: other.modifiedAt ?? modifiedAt,
      source: other.source ?? source,
      // Image & Video
      width: other.width ?? width,
      height: other.height ?? height,
      orientation: other.orientation ?? orientation,
      colorSpace: other.colorSpace ?? colorSpace,
      bitDepth: other.bitDepth ?? bitDepth,
      hasAlpha: other.hasAlpha ?? hasAlpha,
      // Video & Audio
      durationInSeconds: other.durationInSeconds ?? durationInSeconds,
      frameRate: other.frameRate ?? frameRate,
      videoCodec: other.videoCodec ?? videoCodec,
      audioCodec: other.audioCodec ?? audioCodec,
      audioBitrate: other.audioBitrate ?? audioBitrate,
      videoBitrate: other.videoBitrate ?? videoBitrate,
      audioSampleRate: other.audioSampleRate ?? audioSampleRate,
      audioChannels: other.audioChannels ?? audioChannels,
      waveform: waveform?.mergeWith(other.waveform) ?? other.waveform,
      // Document
      pageCount: other.pageCount ?? pageCount,
      title: other.title ?? title,
      author: other.author ?? author,
      subject: other.subject ?? subject,
      keywords: other.keywords ?? keywords,
      // Thumbnail
      thumbnail: thumbnail?.mergeWith(other.thumbnail) ?? other.thumbnail,
      // Custom - merge maps
      customData: _mergeMaps(customData, other.customData),
    );
  }

  /// Helper to merge two maps
  static Map<String, dynamic>? _mergeMaps(
    Map<String, dynamic>? base,
    Map<String, dynamic>? override,
  ) {
    if (base == null && override == null) return null;
    if (base == null) return override;
    if (override == null) return base;
    return {...base, ...override};
  }

  /// Creates a copy with the specified fields replaced.
  MediaMetadata copyWith({
    String? mimeType,
    int? fileSize,
    String? sha256,
    String? fileName,
    String? fileExtension,
    DateTime? createdAt,
    DateTime? modifiedAt,
    MetadataSource? source,
    int? width,
    int? height,
    int? orientation,
    String? colorSpace,
    int? bitDepth,
    bool? hasAlpha,
    double? durationInSeconds,
    double? frameRate,
    String? videoCodec,
    String? audioCodec,
    int? audioBitrate,
    int? videoBitrate,
    int? audioSampleRate,
    int? audioChannels,
    WaveformData? waveform,
    int? pageCount,
    String? title,
    String? author,
    String? subject,
    List<String>? keywords,
    ThumbnailData? thumbnail,
    Map<String, dynamic>? customData,
  }) {
    return MediaMetadata(
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      sha256: sha256 ?? this.sha256,
      fileName: fileName ?? this.fileName,
      fileExtension: fileExtension ?? this.fileExtension,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      source: source ?? this.source,
      width: width ?? this.width,
      height: height ?? this.height,
      orientation: orientation ?? this.orientation,
      colorSpace: colorSpace ?? this.colorSpace,
      bitDepth: bitDepth ?? this.bitDepth,
      hasAlpha: hasAlpha ?? this.hasAlpha,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      frameRate: frameRate ?? this.frameRate,
      videoCodec: videoCodec ?? this.videoCodec,
      audioCodec: audioCodec ?? this.audioCodec,
      audioBitrate: audioBitrate ?? this.audioBitrate,
      videoBitrate: videoBitrate ?? this.videoBitrate,
      audioSampleRate: audioSampleRate ?? this.audioSampleRate,
      audioChannels: audioChannels ?? this.audioChannels,
      waveform: waveform ?? this.waveform,
      pageCount: pageCount ?? this.pageCount,
      title: title ?? this.title,
      author: author ?? this.author,
      subject: subject ?? this.subject,
      keywords: keywords ?? this.keywords,
      thumbnail: thumbnail ?? this.thumbnail,
      customData: customData ?? this.customData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaMetadata &&
          mimeType == other.mimeType &&
          fileSize == other.fileSize &&
          width == other.width &&
          height == other.height &&
          durationInSeconds == other.durationInSeconds;

  @override
  int get hashCode =>
      Object.hash(mimeType, fileSize, width, height, durationInSeconds);

  @override
  String toString() {
    final parts = <String>[];
    if (mimeType != null) parts.add('mimeType: $mimeType');
    if (fileSize != null) parts.add('fileSize: $fileSize');
    if (width != null && height != null) parts.add('dimensions: ${width}x$height');
    if (durationInSeconds != null) parts.add('duration: ${durationInSeconds}s');
    return 'MediaMetadata(${parts.join(', ')})';
  }
}

/// Source of metadata information.
enum MetadataSource {
  /// Metadata received from API response
  api,

  /// Metadata retrieved from Firebase Storage
  firebase,

  /// Metadata loaded from local cache
  cache,

  /// Metadata extracted from local file
  local,

  /// Unknown source
  unknown,
}
