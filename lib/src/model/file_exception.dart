/// Base class for all file operation exceptions.
///
/// Provides common functionality for error chaining and stack trace preservation.
///
/// ## Error Chaining Example
///
/// ```dart
/// try {
///   await uploadFile();
/// } catch (e, stackTrace) {
///   throw FileUploadException(
///     'Failed to upload file',
///     cause: e,
///     stackTrace: stackTrace,
///   );
/// }
/// ```
abstract class FileException implements Exception {
  /// Human-readable error message describing what went wrong.
  final String message;

  /// The original exception that caused this error (for error chaining).
  final Object? cause;

  /// The stack trace from where the original error occurred.
  final StackTrace? stackTrace;

  /// Creates a new [FileException] with the given [message].
  ///
  /// Optionally accepts a [cause] (the original exception) and [stackTrace]
  /// for proper error chaining and debugging.
  const FileException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (cause != null) {
      buffer.write('\nCaused by: $cause');
    }
    return buffer.toString();
  }
}

/// Exception thrown when a file deletion operation fails.
///
/// ## Example
///
/// ```dart
/// try {
///   await file.delete();
/// } catch (e, stackTrace) {
///   throw FileDeleteException(
///     'Failed to delete cached file',
///     cause: e,
///     stackTrace: stackTrace,
///   );
/// }
/// ```
class FileDeleteException extends FileException {
  /// Creates a new [FileDeleteException] with the given [message].
  const FileDeleteException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Exception thrown when a file upload operation fails.
///
/// ## Example
///
/// ```dart
/// try {
///   await uploadTask.snapshot;
/// } catch (e, stackTrace) {
///   throw FileUploadException(
///     'Upload failed for file: ${file.name}',
///     cause: e,
///     stackTrace: stackTrace,
///   );
/// }
/// ```
class FileUploadException extends FileException {
  /// Creates a new [FileUploadException] with the given [message].
  const FileUploadException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Exception thrown when a file download operation fails.
///
/// ## Example
///
/// ```dart
/// try {
///   await downloadTask.snapshot;
/// } catch (e, stackTrace) {
///   throw FileDownloadException(
///     'Download failed for URL: $url',
///     cause: e,
///     stackTrace: stackTrace,
///   );
/// }
/// ```
class FileDownloadException extends FileException {
  /// Creates a new [FileDownloadException] with the given [message].
  const FileDownloadException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Exception thrown when a file cache operation fails.
///
/// ## Example
///
/// ```dart
/// try {
///   await cacheFile(file);
/// } catch (e, stackTrace) {
///   throw FileCacheException(
///     'Failed to cache file',
///     cause: e,
///     stackTrace: stackTrace,
///   );
/// }
/// ```
class FileCacheException extends FileException {
  /// Creates a new [FileCacheException] with the given [message].
  const FileCacheException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Exception thrown when a file task operation fails.
///
/// This is a general exception for task-related failures such as
/// pause, resume, cancel, or retry operations.
///
/// ## Example
///
/// ```dart
/// try {
///   await task.pause();
/// } catch (e, stackTrace) {
///   throw FileTaskException(
///     'Failed to pause task',
///     cause: e,
///     stackTrace: stackTrace,
///   );
/// }
/// ```
class FileTaskException extends FileException {
  /// Creates a new [FileTaskException] with the given [message].
  const FileTaskException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}
