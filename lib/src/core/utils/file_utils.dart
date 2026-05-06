import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Utility class for file-related operations used across widgets
class FileUtils {
  FileUtils._();

  /// Formats bytes into human-readable size string (B, KB, MB, GB, TB)
  static String formatSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes <= 0) return '0 B';

    final i = (math.log(bytes) / math.log(1024)).floor();
    final index = i.clamp(0, suffixes.length - 1);
    return '${(bytes / math.pow(1024, index)).toStringAsFixed(1)} ${suffixes[index]}';
  }

  /// Gets file type information (icon and color) based on file extension
  static FileTypeInfo getFileTypeInfo(String fileName) {
    final fileExtension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';

    return _extensionMap[fileExtension] ?? FileTypeInfo.defaultInfo;
  }

  /// Checks if a file is an image based on extension
  static bool isImageFile(String fileName) {
    final lowerCase = fileName.toLowerCase();
    return _imageExtensions.any((ext) => lowerCase.endsWith('.$ext'));
  }

  /// Checks if a file is a video based on extension
  static bool isVideoFile(String fileName) {
    final lowerCase = fileName.toLowerCase();
    return _videoExtensions.any((ext) => lowerCase.endsWith('.$ext'));
  }

  /// Checks if a file is an audio based on extension
  static bool isAudioFile(String fileName) {
    final lowerCase = fileName.toLowerCase();
    return _audioExtensions.any((ext) => lowerCase.endsWith('.$ext'));
  }

  /// Checks if a file is a document based on extension
  static bool isDocumentFile(String fileName) {
    final lowerCase = fileName.toLowerCase();
    return _documentExtensions.any((ext) => lowerCase.endsWith('.$ext'));
  }

  // Extension sets
  static const _imageExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp', 'ico', 'tiff', 'tif'
  ];
  static const _videoExtensions = [
    'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv', 'm4v', '3gp'
  ];
  static const _audioExtensions = [
    'mp3', 'wav', 'ogg', 'flac', 'm4a', 'aac', 'wma', 'opus'
  ];
  static const _documentExtensions = [
    'doc', 'docx', 'odt', 'rtf', 'txt', 'md'
  ];
  static const _spreadsheetExtensions = ['xls', 'xlsx', 'csv', 'ods'];
  static const _archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz', 'bz2'];

  // Extension to FileTypeInfo mapping
  static final Map<String, FileTypeInfo> _extensionMap = {
    // Images
    for (final ext in _imageExtensions)
      ext: const FileTypeInfo(Icons.image, Colors.blue),

    // PDF
    'pdf': const FileTypeInfo(Icons.picture_as_pdf, Colors.red),

    // Documents
    for (final ext in _documentExtensions)
      ext: const FileTypeInfo(Icons.description, Colors.blue),

    // Spreadsheets
    for (final ext in _spreadsheetExtensions)
      ext: const FileTypeInfo(Icons.table_chart, Colors.green),

    // Videos
    for (final ext in _videoExtensions)
      ext: const FileTypeInfo(Icons.video_file, Colors.purple),

    // Audio
    for (final ext in _audioExtensions)
      ext: const FileTypeInfo(Icons.audio_file, Colors.amber),

    // Archives
    for (final ext in _archiveExtensions)
      ext: const FileTypeInfo(Icons.folder_zip, Colors.brown),

    // Code files
    'dart': const FileTypeInfo(Icons.code, Colors.teal),
    'js': const FileTypeInfo(Icons.code, Colors.yellow),
    'ts': const FileTypeInfo(Icons.code, Colors.blue),
    'py': const FileTypeInfo(Icons.code, Colors.green),
    'java': const FileTypeInfo(Icons.code, Colors.orange),
    'json': const FileTypeInfo(Icons.data_object, Colors.grey),
    'xml': const FileTypeInfo(Icons.code, Colors.orange),
    'html': const FileTypeInfo(Icons.html, Colors.orange),
    'css': const FileTypeInfo(Icons.css, Colors.blue),
  };
}

/// Holds icon and color information for a file type
class FileTypeInfo {
  final IconData icon;
  final Color color;

  const FileTypeInfo(this.icon, this.color);

  /// Default file type info for unknown extensions
  static const defaultInfo = FileTypeInfo(Icons.insert_drive_file, Colors.grey);

  /// Get info for download tasks
  static const downloadInfo = FileTypeInfo(Icons.file_download, Colors.grey);

  /// Get info for upload tasks
  static const uploadInfo = FileTypeInfo(Icons.file_upload, Colors.grey);
}

/// Extension on int for easy byte formatting
extension ByteFormatExtension on int {
  /// Formats bytes to human-readable string
  String get formattedSize => FileUtils.formatSize(this);
}
