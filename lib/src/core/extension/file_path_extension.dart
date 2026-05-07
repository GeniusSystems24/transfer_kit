import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../model/file_model.dart';
import 'file_path_extension.dart';

export 'package:cross_file/cross_file.dart';

/// Application directory manager for cached and temporary files.
///
/// This singleton class manages directory paths for caching files
/// and generating temporary storage locations.
///
/// ## Usage
/// ```dart
/// // Initialize the app directory (call once at app startup)
/// await AppDirectory.init();
///
/// // Access cached directory path
/// final cachedPath = AppDirectory.instance.cachedDir?.path;
/// ```
class AppDirectory {
  static bool isInitialized = false;

  /// The singleton instance of AppDirectory.
  ///
  /// Must call [init] before accessing this property.
  static late final AppDirectory instance;

  /// Initializes the AppDirectory singleton.
  ///
  /// This must be called once at application startup before using
  /// any file management features.
  ///
  /// Returns the initialized [AppDirectory] instance.
  static Future<AppDirectory> init({String? cacheDirectory}) async {
    if (isInitialized) return instance;
    instance = AppDirectory._();
    await instance._getApplicationDocumentsDirectory();
    await instance._getApplicationSupportDirectory();
    await instance._getRootDirectory();
    await instance._getTemporaryDirectory();
    await instance._getCachedDirectory(overridePath: cacheDirectory);
    await instance._getThumbDirectory();
    isInitialized = true;
    return instance;
  }

  AppDirectory._();

  Directory? applicationDocumentsDirectory;
  Future<Directory> _getApplicationDocumentsDirectory() async {
    return (applicationDocumentsDirectory ??=
        await getApplicationDocumentsDirectory());
  }

  Directory? applicationSupportDirectory;
  Future<Directory> _getApplicationSupportDirectory() async {
    return (applicationSupportDirectory ??=
        await getApplicationSupportDirectory());
  }

  Directory? rootDirectory;
  Future<Directory> _getRootDirectory() async {
    return (rootDirectory ??= await getApplicationDocumentsDirectory());
  }

  Directory? temporaryDirectory;
  Future<Directory> _getTemporaryDirectory() async {
    return (temporaryDirectory ??= await getTemporaryDirectory());
  }

  Directory? cachedDir;
  Future<void> _getCachedDirectory({String? overridePath}) async {
    if (cachedDir != null) return;

    final dirPath =
        overridePath ??
        '${(await _getApplicationSupportDirectory()).path}/cached';
    cachedDir = Directory(dirPath);

    if (!cachedDir!.existsSync()) {
      cachedDir!.createSync(recursive: true);
    }
  }

  Directory? systemTemp;
  Future<void> _getThumbDirectory() async {
    systemTemp ??= await Directory.systemTemp.createTemp();
    final thumbDir = Directory('${systemTemp!.path}/thumb');

    if (!thumbDir.existsSync()) {
      thumbDir.createSync(recursive: true);
    }
  }
}

/// Extension methods for file path string manipulation.
///
/// Provides utilities for extracting file information, determining file types,
/// and generating cached file paths from URLs or local paths.
///
/// ## Usage
/// ```dart
/// final url = 'https://example.com/files/document.pdf';
///
/// // Get file name
/// print(url.extractFileName()); // 'document.pdf'
///
/// // Get file type
/// print(url.getFileType()); // FileTypeEnum.file
///
/// // Generate hashed cache name
/// print(url.toHashName()); // 'abc123...def.pdf'
///
/// // Get cached path
/// print(url.toCachedPath()); // '/path/to/cache/abc123...def.pdf'
/// ```
extension FilePathExtension on String {
  /// Extracts the file name from a file path or URL.
  ///
  /// Removes query parameters and returns only the base file name.
  ///
  /// Example:
  /// ```dart
  /// final path = '/data/files/document.pdf?token=abc';
  /// print(path.extractFileName()); // 'document.pdf'
  /// ```
  String extractFileName() {
    return path.basename(this).split('?')[0];
  }

  /// Determines the file type based on file extension.
  ///
  /// Returns the appropriate [FileTypeEnum] based on the file extension:
  /// - `image` for png, jpg, jpeg, gif, bmp, webp
  /// - `video` for mp4, avi, mkv, mov, wmv
  /// - `audio` for mp3, wav, aac, flac, ogg, m4a
  /// - `file` for documents and other files
  ///
  /// Returns `null` if the path is empty or has no extension.
  ///
  /// Example:
  /// ```dart
  /// print('photo.jpg'.getFileType()); // FileTypeEnum.image
  /// print('song.mp3'.getFileType()); // FileTypeEnum.audio
  /// print('document.pdf'.getFileType()); // FileTypeEnum.file
  /// ```
  FileTypeEnum? getFileType() {
    if (isEmpty) return null;

    String extension = path.extension(this).replaceAll('.', '').toLowerCase();

    if (extension.isEmpty) return null;

    if (FileTypeEnum.image.extensions.contains(extension)) {
      return FileTypeEnum.image;
    } else if (FileTypeEnum.video.extensions.contains(extension)) {
      return FileTypeEnum.video;
    } else if (FileTypeEnum.audio.extensions.contains(extension)) {
      return FileTypeEnum.audio;
    } else {
      return FileTypeEnum.file;
    }
  }

  /// Returns the file name from a path.
  ///
  /// Example:
  /// ```dart
  /// print('path/to/file.jpg'.fileName); // 'file.jpg'
  /// ```
  String get fileName => path.basename(this);

  /// Returns the file extension including the dot.
  ///
  /// Example:
  /// ```dart
  /// print('document.pdf'.fileExtension); // '.pdf'
  /// ```
  String get fileExtension => path.extension(split('?').first);

  /// Generates a unique hashed file name from a URL or path.
  ///
  /// Uses SHA-256 to create a unique hash of the input string,
  /// preserving the original file extension.
  ///
  /// Example:
  /// ```dart
  /// final url = 'https://example.com/image.jpg';
  /// print(url.toHashName()); // 'a1b2c3d4...xyz.jpg'
  /// ```
  String toHashName() {
    final bytes = utf8.encode(this);
    final hash = sha256.convert(bytes).toString();
    final extension = fileExtension;
    return '$hash$extension';
  }

  /// Generates a cached file path for this file name.
  ///
  /// Combines the app's cache directory with the file name.
  /// Uses only the base file name to prevent path traversal.
  ///
  /// Example:
  /// ```dart
  /// final name = 'image.jpg';
  /// print(name.toCachedPath()); // '/app/cache/image.jpg'
  /// ```
  String toCachedPath() {
    // Security: Use only the base name to prevent path traversal
    final safeName = path.basename(this);
    return path.join(AppDirectory.instance.cachedDir!.path, safeName);
  }

  /// Generates a thumbnail file path for this file name.
  ///
  /// Uses only the base file name to prevent path traversal.
  ///
  /// Example:
  /// ```dart
  /// final name = 'image.jpg';
  /// print(name.toThumbPath()); // '/temp/thumb/image.jpg'
  /// ```
  String toThumbPath() {
    // Security: Use only the base name to prevent path traversal
    final safeName = path.basename(this);
    return path.join(AppDirectory.instance.systemTemp!.path, safeName);
  }

  /// Generates a cached path from a URL.
  ///
  /// Combines [toHashName] and [toCachedPath] for convenience.
  ///
  /// Example:
  /// ```dart
  /// final url = 'https://example.com/image.jpg';
  /// print(url.urlToCachedPath()); // '/cache/abc123...xyz.jpg'
  /// ```
  String urlToCachedPath() => toHashName().toCachedPath();

  /// Generates a thumbnail path from a URL.
  String urlToThumbPath() => toHashName().toThumbPath();

  /// Returns a File if it exists at this path in the documents directory.
  ///
  /// Returns `null` if the file does not exist or if path traversal is detected.
  ///
  /// **Security:** This method validates that the resolved path stays within
  /// the application documents directory to prevent path traversal attacks.
  Future<File?> fileOrNull() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = path.normalize(path.join(appDir.path, this));

      // Security: Prevent path traversal attacks
      if (!filePath.startsWith(appDir.path)) {
        return null;
      }

      final file = File(filePath);
      return await file.exists() ? file : null;
    } catch (e) {
      return null;
    }
  }

  /// Returns an icon and color appropriate for this file type.
  ///
  /// Uses the file extension to determine the icon.
  ///
  /// Example:
  /// ```dart
  /// final (icon, color) = 'document.pdf'.iconAndColor;
  /// // icon = Icons.picture_as_pdf, color = Colors.red
  /// ```
  (IconData, Color) get iconAndColor {
    if (!contains('.')) return (Icons.insert_drive_file, Colors.grey);

    final fileExtension = split('.').last.toLowerCase();

    if ([
      'jpg',
      'jpeg',
      'png',
      'gif',
      'webp',
      'svg',
      'bmp',
    ].contains(fileExtension)) {
      return (Icons.image, Colors.blue);
    } else if (fileExtension == 'pdf') {
      return (Icons.picture_as_pdf, Colors.red);
    } else if (['doc', 'docx', 'odt', 'rtf', 'txt'].contains(fileExtension)) {
      return (Icons.description, Colors.blue);
    } else if (['xls', 'xlsx', 'csv'].contains(fileExtension)) {
      return (Icons.table_chart, Colors.green);
    } else if ([
      'mp4',
      'mov',
      'avi',
      'mkv',
      'webm',
      'flv',
    ].contains(fileExtension)) {
      return (Icons.video_file, Colors.purple);
    } else if (['mp3', 'wav', 'ogg', 'flac', 'm4a'].contains(fileExtension)) {
      return (Icons.audio_file, Colors.amber);
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(fileExtension)) {
      return (Icons.folder_zip, Colors.brown);
    } else {
      return (Icons.insert_drive_file, Colors.grey);
    }
  }
}

/// Extension methods for [File] operations.
extension FileExtension on File {
  /// Copies the file to the app's cache directory.
  Future<File> copyToCache() async => copy(this.path.fileName.toCachedPath());
}

/// Extension methods for [XFile] operations.
extension XFileExtension on XFile {
  /// Copies the XFile to the app's cache directory.
  Future<File> copyToCache() async {
    final targetPath = name.toCachedPath();
    try {
      await saveTo(targetPath);
      return File(targetPath);
    } catch (e) {
      final fileBytes = await readAsBytes();
      final newFile = File(targetPath);
      await newFile.writeAsBytes(fileBytes);
      return newFile;
    }
  }
}
