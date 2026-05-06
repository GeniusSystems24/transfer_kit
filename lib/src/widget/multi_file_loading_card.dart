import 'dart:io';

import 'package:flutter/material.dart';

import '../transfer_kit.dart';
import '../model/file_path_and_url.dart';
import '../model/multi_download_file_task.dart';

/// A widget that handles downloading multiple files and displays their progress.
///
/// Usage example:
/// ```dart
/// MultiFileLoadingCard(
///   urls: {'https://example.com/file1.jpg', 'https://example.com/file2.jpg'},
///   isSequential: false, // Download in parallel
///   onLoaded: (files) {
///     return Column(
///       children: [
///         for (final file in files) Image.file(file),
///       ],
///     );
///   },
///   onAllFilesLoaded: (files) {
///     // All files are downloaded
///     print('All ${files.length} files downloaded');
///   },
///   onFileLoaded: (file, index) {
///     // Individual file downloaded
///     print('File $index downloaded: ${file.path}');
///   },
/// )
/// ```
///
/// This widget is useful for gallery or multi-file download scenarios where you need
/// to track and display the progress of multiple downloads simultaneously.
class MultiFileLoadingCard extends StatefulWidget {
  final Set<String> urls;
  final bool isSequential;
  final Widget Function(List<File> files)? onLoaded;
  final Widget? placeholder;
  final Widget Function(String error)? onError;

  /// Widget to display while downloading
  final Widget? Function(BuildContext context, MultiDownloadFileTask progress)?
      downloadingWidget;

  /// Custom controller to use instead of creating a new one
  /// If not provided, a new one will be created
  final TransferKit? controller;

  /// Callback when all files are completely downloaded
  final Function(List<File> files)? onAllFilesLoaded;

  /// Callback when an individual file is downloaded
  final Function(File file, int index)? onFileLoaded;

  final BoxConstraints? constraints;

  const MultiFileLoadingCard({
    super.key,
    required this.urls,
    this.isSequential = true,
    this.onLoaded,
    this.placeholder,
    this.onError,
    this.downloadingWidget,
    this.constraints,
    this.controller,
    this.onAllFilesLoaded,
    this.onFileLoaded,
  });

  @override
  State<MultiFileLoadingCard> createState() => _MultiFileLoadingCardState();
}

class _MultiFileLoadingCardState extends State<MultiFileLoadingCard> {
  late final TransferKit _fileController;
  final Set<int> _reportedFileIndices = {};
  bool _allFilesReported = false;

  @override
  void initState() {
    super.initState();
    _fileController = widget.controller ?? TransferKit.instance;
  }

  void _handleProgressUpdate(MultiDownloadFileTask progress) {
    // Check for newly completed files to trigger onFileLoaded callback
    if (widget.onFileLoaded != null) {
      for (int i = 0; i < progress.fileStatuses.length; i++) {
        final status = progress.fileStatuses[i];
        if (status.isComplete && !_reportedFileIndices.contains(i)) {
          _reportedFileIndices.add(i);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onFileLoaded!(File(status.filePath), i);
          });
        }
      }
    }

    // Check for all files completed to trigger onAllFilesLoaded callback
    if (progress.isComplete && widget.onAllFilesLoaded != null && !_allFilesReported) {
      _allFilesReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final files = progress.fileStatuses
            .where((status) => status.isComplete)
            .map((status) => File(status.filePath))
            .toList();
        widget.onAllFilesLoaded!(files);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: widget.constraints,
      child: StreamBuilder<MultiDownloadFileTask>(
        stream: _fileController.downloadTasksParallelStream(
          filePathsAndUrls: {
            for (final url in widget.urls) FilePathAndURL.url(url: url)
          },
        ),
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
            return widget.downloadingWidget?.call(context, progress) ??
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
                      'Downloaded ${_getCompletedCount(progress)}/${progress.fileStatuses.length} files',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '${(progress.totalBytesDownloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
          }

          // Convert file statuses to File objects
          final files = progress.fileStatuses
              .where((status) => status.isComplete)
              .map((status) => File(status.filePath))
              .toList();

          return widget.onLoaded?.call(files) ??
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.green, size: 48),
                    const SizedBox(height: 16),
                    Text('Successfully downloaded ${progress.fileStatuses.length} files',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              );
        },
      ),
    );
  }

  int _getCompletedCount(MultiDownloadFileTask progress) {
    return progress.fileStatuses.where((status) => status.isComplete).length;
  }
}

/// Widget to display download progress for multiple files
class MultiDownloadProgressIndicator extends StatelessWidget {
  final MultiDownloadFileTask progress;

  const MultiDownloadProgressIndicator({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Overall progress indicator
        LinearProgressIndicator(
            value: progress.overallProgressPercentage / 100, minHeight: 10),
        const SizedBox(height: 8),
        Text(
            'Overall: ${progress.overallProgressPercentage.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),

        // Individual file progress indicators
        ...progress.fileStatuses.map((status) {
          final fileName =
              status.isComplete ? status.filePath.split('/').last : 'File';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(fileName,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis)),
                    Text(
                        '${status.progress.progressPercentage.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 4),
                AspectRatio(
                  aspectRatio: 1,
                  child: SizedBox(
                      width: 25,
                      child: LinearProgressIndicator(
                          value: status.progress.progressPercentage / 100,
                          minHeight: 6)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
