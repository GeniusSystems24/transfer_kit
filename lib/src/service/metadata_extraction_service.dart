// ignore_for_file: unused_local_variable

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:just_audio/just_audio.dart';
import 'package:just_waveform/just_waveform.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../core/file_management_config.dart';
import '../model/media_metadata.dart';

/// Service for extracting metadata from local files.
///
/// This service provides comprehensive metadata extraction for various file types:
/// - **Images**: Dimensions, EXIF data, orientation, thumbnails
/// - **Videos**: Duration, dimensions, thumbnails
/// - **Audio**: Duration, waveform data
/// - **Documents**: Page count, title, author (PDF)
///
/// ## Example
/// ```dart
/// final service = MetadataExtractionService();
/// final metadata = await service.extractMetadata(File('/path/to/image.jpg'));
/// print('Dimensions: ${metadata.width}x${metadata.height}');
/// print('SHA-256: ${metadata.sha256}');
/// ```
///
/// ## Configuration
/// Extraction behavior can be controlled via [FileManagementConfig]:
/// ```dart
/// FileManagementConfig.init(
///   autoExtractMetadata: true,
///   autoExtractSha256: true,
///   autoExtractThumbnail: true,
///   thumbnailMaxWidth: 200,
///   thumbnailMaxHeight: 200,
/// );
/// ```
class MetadataExtractionService {
  static final MetadataExtractionService _instance =
      MetadataExtractionService._internal();
  MetadataExtractionService._internal();
  factory MetadataExtractionService() => _instance;

  /// Audio player for extracting audio metadata (reused for efficiency)
  AudioPlayer? _audioPlayer;

  /// Extracts metadata from a local file.
  ///
  /// This method detects the file type and extracts appropriate metadata.
  /// Extraction behavior is controlled by [FileManagementConfig] settings.
  ///
  /// ## Parameters
  /// - [file]: The local file to extract metadata from
  /// - [existingMetadata]: Optional existing metadata to merge with
  ///
  /// ## Returns
  /// [MediaMetadata] containing extracted information merged with existing data
  Future<MediaMetadata> extractMetadata(
    File file, {
    MediaMetadata? existingMetadata,
  }) async {
    final config = FileManagementConfig.instance;

    // Check if metadata extraction is enabled
    if (!config.autoExtractMetadata) {
      return existingMetadata ?? const MediaMetadata();
    }

    if (!await file.exists()) {
      return existingMetadata ?? const MediaMetadata();
    }

    try {
      final stat = await file.stat();
      final fileName = file.path.split(Platform.pathSeparator).last;
      final extension = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : null;

      // Use mime package for accurate MIME type detection
      final mimeType = lookupMimeType(file.path) ?? _fallbackMimeType(extension);

      // Base metadata from file system
      var metadata = MediaMetadata(
        fileSize: stat.size,
        fileName: fileName,
        fileExtension: extension,
        mimeType: mimeType,
        createdAt: stat.changed,
        modifiedAt: stat.modified,
        source: MetadataSource.local,
      );

      // Extract SHA-256 if enabled
      if (config.autoExtractSha256) {
        final hash = await computeFileSha256(file);
        if (hash != null) {
          metadata = metadata.copyWith(sha256: hash);
        }
      }

      // Extract type-specific metadata
      if (_isImage(mimeType)) {
        final imageMetadata = await _extractImageMetadata(file, config);
        if (imageMetadata != null) {
          metadata = metadata.mergeWith(imageMetadata);
        }
      } else if (_isVideo(mimeType)) {
        final videoMetadata = await _extractVideoMetadata(file, config);
        if (videoMetadata != null) {
          metadata = metadata.mergeWith(videoMetadata);
        }
      } else if (_isAudio(mimeType)) {
        final audioMetadata = await _extractAudioMetadata(file, config);
        if (audioMetadata != null) {
          metadata = metadata.mergeWith(audioMetadata);
        }
      } else if (_isPdf(mimeType)) {
        final pdfMetadata = await _extractPdfMetadata(file, config);
        if (pdfMetadata != null) {
          metadata = metadata.mergeWith(pdfMetadata);
        }
      }

      // Merge with existing metadata (existing takes precedence)
      if (existingMetadata != null) {
        metadata = existingMetadata.mergeWith(
          metadata.copyWith(source: existingMetadata.source ?? MetadataSource.local),
        );
      }

      return metadata;
    } catch (e) {
      if (config.enableLogging) {
        print('MetadataExtractionService: Error extracting metadata: $e');
      }
      return existingMetadata ?? const MediaMetadata();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHA-256 HASH
  // ═══════════════════════════════════════════════════════════════════════════

  /// Computes SHA-256 hash of file content.
  ///
  /// Uses the crypto package for proper cryptographic hash computation.
  Future<String?> computeFileSha256(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      if (FileManagementConfig.instance.enableLogging) {
        print('MetadataExtractionService: Error computing SHA-256: $e');
      }
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // IMAGE METADATA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extracts metadata from image files using the image package.
  Future<MediaMetadata?> _extractImageMetadata(
    File file,
    FileManagementConfig config,
  ) async {
    try {
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      ThumbnailData? thumbnail;
      if (config.autoExtractThumbnail) {
        thumbnail = await _createImageThumbnail(
          image,
          config.thumbnailMaxWidth,
          config.thumbnailMaxHeight,
        );
      }

      // Extract EXIF orientation if available
      int? orientation;
      try {
        final exifData = image.exif;
        if (exifData.exifIfd.data.containsKey(0x0112)) {
          // 0x0112 is the EXIF orientation tag
          orientation = exifData.exifIfd.data[0x0112]?.toInt();
        }
      } catch (_) {
        // EXIF data not available or invalid
      }

      return MediaMetadata(
        width: image.width,
        height: image.height,
        orientation: orientation,
        hasAlpha: image.hasAlpha,
        bitDepth: image.bitsPerChannel,
        thumbnail: thumbnail,
      );
    } catch (e) {
      if (config.enableLogging) {
        print('MetadataExtractionService: Error extracting image metadata: $e');
      }
      // Fallback to header-based extraction
      return _extractImageMetadataFromHeader(file);
    }
  }

  /// Creates a thumbnail from an image.
  Future<ThumbnailData?> _createImageThumbnail(
    img.Image image,
    int maxWidth,
    int maxHeight,
  ) async {
    try {
      // Calculate thumbnail size maintaining aspect ratio
      final aspectRatio = image.width / image.height;
      int thumbWidth, thumbHeight;

      if (aspectRatio > 1) {
        thumbWidth = maxWidth;
        thumbHeight = (maxWidth / aspectRatio).round();
      } else {
        thumbHeight = maxHeight;
        thumbWidth = (maxHeight * aspectRatio).round();
      }

      // Resize image
      final thumbnail = img.copyResize(
        image,
        width: thumbWidth,
        height: thumbHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode to JPEG
      final jpegBytes = img.encodeJpg(thumbnail, quality: 80);
      final base64Data = base64Encode(jpegBytes);

      return ThumbnailData(
        bytes: Uint8List.fromList(jpegBytes),
        base64: base64Data,
        width: thumbWidth,
        height: thumbHeight,
        mimeType: 'image/jpeg',
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Fallback: Extract image dimensions from file header.
  Future<MediaMetadata?> _extractImageMetadataFromHeader(File file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length < 24) return null;

      final dimensions = _getImageDimensionsFromHeader(bytes);
      if (dimensions == null) return null;

      return MediaMetadata(
        width: dimensions.$1,
        height: dimensions.$2,
      );
    } catch (e) {
      return null;
    }
  }

  /// Gets image dimensions by reading file header bytes.
  (int, int)? _getImageDimensionsFromHeader(Uint8List bytes) {
    // PNG
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      return (width, height);
    }

    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return _getJpegDimensions(bytes);
    }

    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      final width = bytes[6] | (bytes[7] << 8);
      final height = bytes[8] | (bytes[9] << 8);
      return (width, height);
    }

    return null;
  }

  (int, int)? _getJpegDimensions(Uint8List bytes) {
    var offset = 2;
    while (offset < bytes.length - 9) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }
      final marker = bytes[offset + 1];
      if ((marker >= 0xC0 && marker <= 0xC3) ||
          (marker >= 0xC5 && marker <= 0xC7) ||
          (marker >= 0xC9 && marker <= 0xCB) ||
          (marker >= 0xCD && marker <= 0xCF)) {
        final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
        final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
        return (width, height);
      }
      if (marker == 0xD8 || marker == 0xD9) {
        offset += 2;
      } else if (marker >= 0xD0 && marker <= 0xD7) {
        offset += 2;
      } else {
        final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += length + 2;
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIDEO METADATA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extracts metadata from video files.
  Future<MediaMetadata?> _extractVideoMetadata(
    File file,
    FileManagementConfig config,
  ) async {
    try {
      ThumbnailData? thumbnail;

      if (config.autoExtractThumbnail) {
        // Generate thumbnail using video_thumbnail package
        final thumbBytes = await VideoThumbnail.thumbnailData(
          video: file.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: config.thumbnailMaxWidth,
          maxHeight: config.thumbnailMaxHeight,
          quality: 80,
        );

        if (thumbBytes != null) {
          // Decode to get actual dimensions
          final thumbImage = img.decodeImage(thumbBytes);
          thumbnail = ThumbnailData(
            bytes: thumbBytes,
            base64: base64Encode(thumbBytes),
            width: thumbImage?.width,
            height: thumbImage?.height,
            mimeType: 'image/jpeg',
            generatedAt: DateTime.now(),
          );
        }
      }

      // Note: video_thumbnail doesn't provide duration/dimensions
      // For that, you'd need ffmpeg_kit_flutter or similar
      return MediaMetadata(
        thumbnail: thumbnail,
      );
    } catch (e) {
      if (config.enableLogging) {
        print('MetadataExtractionService: Error extracting video metadata: $e');
      }
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUDIO METADATA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extracts metadata from audio files using just_audio.
  Future<MediaMetadata?> _extractAudioMetadata(
    File file,
    FileManagementConfig config,
  ) async {
    try {
      // Create or reuse audio player
      _audioPlayer ??= AudioPlayer();

      // Load the audio file
      final duration = await _audioPlayer!.setFilePath(file.path);

      if (duration == null) return null;

      // Extract waveform if enabled
      WaveformData? waveformData;
      if (config.autoExtractWaveform) {
        waveformData = await _extractWaveform(
          file,
          duration,
          config.waveformSamplesPerSecond,
        );
      }

      return MediaMetadata(
        durationInSeconds: duration.inMilliseconds / 1000.0,
        waveform: waveformData,
      );
    } catch (e) {
      if (config.enableLogging) {
        print('MetadataExtractionService: Error extracting audio metadata: $e');
      }
      return null;
    } finally {
      // Stop playback but don't dispose (reuse player)
      await _audioPlayer?.stop();
    }
  }

  /// Extracts waveform data from an audio file using just_waveform.
  Future<WaveformData?> _extractWaveform(
    File audioFile,
    Duration duration,
    int samplesPerSecond,
  ) async {
    try {
      // Create a temporary file for the waveform data
      final tempDir = await getTemporaryDirectory();
      final waveformFile = File('${tempDir.path}/waveform_${DateTime.now().millisecondsSinceEpoch}.wave');

      // Calculate total samples based on duration
      final totalSamples = (duration.inSeconds * samplesPerSecond).clamp(10, 10000);

      // Extract waveform using just_waveform
      final progressStream = JustWaveform.extract(
        audioInFile: audioFile,
        waveOutFile: waveformFile,
        zoom: WaveformZoom.pixelsPerSecond(samplesPerSecond),
      );

      // Wait for extraction to complete
      Waveform? waveform;
      await for (final progress in progressStream) {
        if (progress.waveform != null) {
          waveform = progress.waveform;
        }
      }

      if (waveform == null) return null;

      // Convert waveform data to normalized samples (0.0 to 1.0)
      final samples = <double>[];
      final frameCount = waveform.length;

      // Calculate peak value for normalization
      int maxAmplitude = 1;
      for (int i = 0; i < frameCount; i++) {
        final amplitude = waveform[i];
        final absValue = amplitude.abs();
        if (absValue > maxAmplitude) maxAmplitude = absValue;
            }

      // Extract normalized samples
      for (int i = 0; i < frameCount; i++) {
        final amplitude = waveform[i];
        // Normalize amplitude to 0.0-1.0
        samples.add(amplitude.abs() / maxAmplitude);
            }

      // Clean up temp file
      if (await waveformFile.exists()) {
        await waveformFile.delete();
      }

      // Calculate statistics
      double peakAmplitude = 0;
      double sumAmplitude = 0;
      for (final sample in samples) {
        if (sample > peakAmplitude) peakAmplitude = sample;
        sumAmplitude += sample;
      }
      final averageAmplitude = samples.isNotEmpty ? sumAmplitude / samples.length : 0.0;

      // Determine channels from waveform flags (bit 0: 0=mono, 1=stereo)
      final channels = (waveform.flags & 0x1) == 1 ? 2 : 1;

      return WaveformData(
        samples: samples,
        sampleRate: samplesPerSecond,
        channels: channels,
        peakAmplitude: peakAmplitude,
        averageAmplitude: averageAmplitude,
      );
    } catch (e) {
      if (FileManagementConfig.instance.enableLogging) {
        print('MetadataExtractionService: Error extracting waveform: $e');
      }
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PDF METADATA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extracts metadata from PDF files using pdfx.
  ///
  /// Extracts page count and optionally renders the first page as a thumbnail.
  Future<MediaMetadata?> _extractPdfMetadata(
    File file,
    FileManagementConfig config,
  ) async {
    try {
      final document = await PdfDocument.openFile(file.path);

      final pageCount = document.pagesCount;

      ThumbnailData? thumbnail;

      // Extract thumbnail from first page if enabled
      if (config.autoExtractThumbnail && pageCount > 0) {
        thumbnail = await _extractPdfThumbnail(
          document,
          config.thumbnailMaxWidth,
          config.thumbnailMaxHeight,
        );
      }

      // Close document to free resources
      await document.close();

      return MediaMetadata(
        pageCount: pageCount,
        thumbnail: thumbnail,
      );
    } catch (e) {
      if (FileManagementConfig.instance.enableLogging) {
        print('MetadataExtractionService: Error extracting PDF metadata: $e');
      }
      return null;
    }
  }

  /// Extracts a thumbnail from the first page of a PDF document.
  Future<ThumbnailData?> _extractPdfThumbnail(
    PdfDocument document,
    int maxWidth,
    int maxHeight,
  ) async {
    try {
      // Get the first page
      final page = await document.getPage(1);

      // Calculate render size maintaining aspect ratio
      final pageWidth = page.width;
      final pageHeight = page.height;
      final aspectRatio = pageWidth / pageHeight;

      double renderWidth, renderHeight;
      if (aspectRatio > 1) {
        // Landscape
        renderWidth = maxWidth.toDouble();
        renderHeight = maxWidth / aspectRatio;
      } else {
        // Portrait
        renderHeight = maxHeight.toDouble();
        renderWidth = maxHeight * aspectRatio;
      }

      // Render the page to an image
      final pageImage = await page.render(
        width: renderWidth,
        height: renderHeight,
        format: PdfPageImageFormat.jpeg,
        quality: 80,
      );

      await page.close();

      if (pageImage == null) return null;

      final bytes = pageImage.bytes;
      final base64Data = base64Encode(bytes);

      return ThumbnailData(
        bytes: bytes,
        base64: base64Data,
        width: renderWidth.round(),
        height: renderHeight.round(),
        mimeType: 'image/jpeg',
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      if (FileManagementConfig.instance.enableLogging) {
        print('MetadataExtractionService: Error extracting PDF thumbnail: $e');
      }
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isImage(String? mimeType) => mimeType?.startsWith('image/') == true;
  bool _isVideo(String? mimeType) => mimeType?.startsWith('video/') == true;
  bool _isAudio(String? mimeType) => mimeType?.startsWith('audio/') == true;
  bool _isPdf(String? mimeType) => mimeType == 'application/pdf';

  /// Fallback MIME type detection from extension.
  String? _fallbackMimeType(String? extension) {
    if (extension == null) return null;
    return switch (extension.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      'svg' => 'image/svg+xml',
      'mp4' => 'video/mp4',
      'webm' => 'video/webm',
      'avi' => 'video/x-msvideo',
      'mov' => 'video/quicktime',
      'mkv' => 'video/x-matroska',
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'aac' => 'audio/aac',
      'flac' => 'audio/flac',
      'm4a' => 'audio/mp4',
      'pdf' => 'application/pdf',
      _ => null,
    };
  }

  /// Disposes resources used by the service.
  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
