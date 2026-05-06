import '../model/file_path_and_url.dart';
import '../model/multi_upload_file_task.dart';
import 'package:flutter/material.dart';

import '../transfer_kit.dart';

/// A widget that handles uploading multiple files and displays their progress.
///
/// Usage example:
/// ```dart
/// MultiFileUploadCard(
///   filePathsAndUrls: {
///     FilePathAndURL(
///       path: '/path/to/file1.jpg',
///       destinationPath: 'uploads/file1.jpg'
///     ),
///     FilePathAndURL(
///       path: '/path/to/file2.jpg',
///       destinationPath: 'uploads/file2.jpg'
///     ),
///   },
///   isSequential: false, // Upload in parallel
///   onUploaded: (downloadUrls) {
///     return Column(
///       children: [
///         for (final url in downloadUrls) Image.network(url),
///       ],
///     );
///   },
///   onAllFilesUploaded: (downloadUrls) {
///     // All files are uploaded
///     print('All ${downloadUrls.length} files uploaded');
///   },
///   onFileUploaded: (downloadUrl, index) {
///     // Individual file uploaded
///     print('File $index uploaded: $downloadUrl');
///   },
/// )
/// ```
///
/// This widget is useful for gallery uploads or multi-file upload scenarios where
/// you need to track and display the progress of multiple uploads simultaneously.
class MultiFileUploadCard extends StatefulWidget {
  final Set<FilePathAndURL> filePathsAndUrls;
  final bool isSequential;
  final Widget Function(List<String> downloadUrls)? onUploaded;
  final Widget? placeholder;
  final Widget Function(String error)? onError;

  /// Widget to display while uploading
  final Widget? Function(BuildContext context, MultiUploadFileTask progress)?
      uploadingWidget;

  /// Custom controller to use instead of creating a new one
  /// If not provided, a new one will be created
  final TransferKit? controller;

  /// Callback when all files are successfully uploaded
  final Function(List<String> downloadUrls)? onAllFilesUploaded;

  /// Callback when an individual file is uploaded
  final Function(String downloadUrl, int index)? onFileUploaded;

  final BoxConstraints? constraints;

  const MultiFileUploadCard({
    super.key,
    required this.filePathsAndUrls,
    this.isSequential = true,
    this.onUploaded,
    this.placeholder,
    this.onError,
    this.uploadingWidget,
    this.constraints,
    this.controller,
    this.onAllFilesUploaded,
    this.onFileUploaded,
  });

  @override
  State<MultiFileUploadCard> createState() => _MultiFileUploadCardState();
}

class _MultiFileUploadCardState extends State<MultiFileUploadCard> {
  late final TransferKit _fileController;
  final Set<int> _reportedFileIndices = {};
  bool _allFilesReported = false;

  @override
  void initState() {
    super.initState();
    _fileController = widget.controller ?? TransferKit.instance;
  }

  void _handleProgressUpdate(MultiUploadFileTask progress) {
    // Check for newly completed files to trigger onFileUploaded callback
    if (widget.onFileUploaded != null) {
      for (int i = 0; i < progress.tasks.length; i++) {
        final task = progress.tasks[i];
        if (task.isComplete && task.downloadUrl != null && !_reportedFileIndices.contains(i)) {
          _reportedFileIndices.add(i);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onFileUploaded!(task.downloadUrl!, i);
          });
        }
      }
    }

    // Check for all files completed to trigger onAllFilesUploaded callback
    if (progress.isComplete && widget.onAllFilesUploaded != null && !_allFilesReported) {
      _allFilesReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final downloadUrls = progress.tasks
            .where((task) => task.downloadUrl != null)
            .map((task) => task.downloadUrl!)
            .toList();
        widget.onAllFilesUploaded!(downloadUrls);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: widget.constraints,
      child: StreamBuilder<MultiUploadFileTask>(
        stream: _fileController.uploadTasksParallelStream(
            filePathsAndUrls: widget.filePathsAndUrls),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error.toString();
            if (error.contains('Too many attempts')) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Authentication error',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Please try again in a few minutes',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              );
            }
            return widget.onError?.call(error) ?? Text('Error: $error');
          }

          if (!snapshot.hasData) {
            return Center(
                child: widget.placeholder ?? const CircularProgressIndicator());
          }

          final progress = snapshot.data!;

          // Handle callbacks for completed files (only once per file)
          _handleProgressUpdate(progress);

          if (!progress.isComplete) {
            return widget.uploadingWidget?.call(context, progress) ??
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                        value: progress.overallProgressPercentage / 100),
                    const SizedBox(height: 16),
                    Text(
                        '${progress.overallProgressPercentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyLarge),
                    Text(
                      'Uploaded ${_getCompletedCount(progress)}/${progress.tasks.length} files',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${(progress.totalBytesUploaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
          }

          // Collect all download URLs from completed tasks
          final downloadUrls = progress.tasks
              .where((task) => task.downloadUrl != null)
              .map((task) => task.downloadUrl!)
              .toList();

          return widget.onUploaded?.call(downloadUrls) ??
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    Text('Successfully uploaded ${progress.tasks.length} files',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              );
        },
      ),
    );
  }

  int _getCompletedCount(MultiUploadFileTask progress) {
    return progress.tasks.where((task) => task.isComplete).length;
  }
}
