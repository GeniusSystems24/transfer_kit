import '../core/extension/num_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../model/file_task.dart';
import '../model/multi_upload_file_task.dart';
import 'file_task_card.dart';

/// A widget that displays a list view of upload progress for multiple files
///
/// Usage example:
/// ```dart
/// MultiUploadProgressListView(
///   progress: multiUploadTask, // MultiUploadTask from TransferKit
///   onFileUploaded: (task, index) {
///     // Handle individual file upload completion
///     print('File uploaded: ${task.fileName}');
///   },
///   onAllFilesUploaded: (tasks) {
///     // Handle all files uploaded
///     print('All ${tasks.length} files uploaded');
///   },
///   showFileSize: true,
///   showDetailedInfo: true,
///   useCompactLayout: false,
///   onItemTap: (context, task, index) {
///     // Handle tap on individual task
///     showDialog(
///       context: context,
///       builder: (context) => TaskDetailsDialog(task: task),
///     );
///   },
/// )
/// ```
///
/// This widget provides a comprehensive UI for displaying upload progress of multiple files,
/// with customizable headers, footers, and item display, along with callbacks for tracking
/// individual and overall upload completion.
class MultiUploadProgressListView extends StatefulWidget {
  /// The MultiUploadProgress object containing upload progress information
  final MultiUploadFileTask progress;

  /// Callback when a file upload is completed
  final Function(FileTask task, int index)? onFileUploaded;

  /// Callback when all files are successfully uploaded
  final Function(List<FileTask> tasks)? onAllFilesUploaded;

  /// Custom builder for file item title
  final Widget Function(BuildContext context, FileTask task, int index)?
  titleBuilder;

  /// Custom builder for file item subtitle
  final Widget Function(BuildContext context, FileTask task, int index)?
  subtitleBuilder;

  /// Custom builder for file item trailing widget
  final Widget Function(BuildContext context, FileTask task, int index)?
  trailingBuilder;

  /// Custom builder for file item leading widget
  final Widget Function(BuildContext context, FileTask task, int index)?
  leadingBuilder;

  /// Custom progress indicator builder
  final Widget Function(BuildContext context, FileTask task, int index)?
  progressBuilder;

  /// Custom builder for the header widget displayed above the list
  final Widget Function(BuildContext context, MultiUploadFileTask progress)?
  headerBuilder;

  /// Custom builder for the footer widget displayed below the list
  final Widget Function(BuildContext context, MultiUploadFileTask progress)?
  footerBuilder;

  /// Custom item padding
  final EdgeInsetsGeometry itemPadding;

  /// Whether to show file size information
  final bool showFileSize;

  /// Callback when a list item is tapped
  final Function(BuildContext context, FileTask task, int index)? onItemTap;

  /// Animation duration for progress changes
  final Duration animationDuration;

  /// Whether to show detailed file information
  final bool showDetailedInfo;

  /// Whether to use a compact layout
  final bool useCompactLayout;

  const MultiUploadProgressListView({
    super.key,
    required this.progress,
    this.onFileUploaded,
    this.onAllFilesUploaded,
    this.titleBuilder,
    this.subtitleBuilder,
    this.trailingBuilder,
    this.leadingBuilder,
    this.progressBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.showFileSize = true,
    this.onItemTap,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showDetailedInfo = false,
    this.useCompactLayout = false,
  });

  @override
  State<MultiUploadProgressListView> createState() =>
      _MultiUploadProgressListViewState();
}

class _MultiUploadProgressListViewState
    extends State<MultiUploadProgressListView> {
  final Set<int> _reportedFileIndices = {};
  bool _allFilesReported = false;

  void _handleCallbacks() {
    // Check for completed files to trigger callback (only once per file)
    if (widget.onFileUploaded != null) {
      for (int i = 0; i < widget.progress.tasks.length; i++) {
        final task = widget.progress.tasks[i];
        if (task.isComplete &&
            task.downloadUrl != null &&
            !_reportedFileIndices.contains(i)) {
          _reportedFileIndices.add(i);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onFileUploaded!(task, i);
          });
        }
      }
    }

    // Check if all files are completed to trigger onAllFilesUploaded callback (only once)
    if (widget.onAllFilesUploaded != null &&
        widget.progress.isComplete &&
        !_allFilesReported) {
      _allFilesReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final completedTasks = widget.progress.tasks
            .where((task) => task.isComplete && task.downloadUrl != null)
            .toList();
        widget.onAllFilesUploaded!(completedTasks);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _handleCallbacks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        if (widget.headerBuilder != null)
          widget.headerBuilder!(context, widget.progress)
        else
          _buildDefaultHeader(context),

        // File list
        Expanded(
          child: widget.progress.tasks.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  itemCount: widget.progress.tasks.length,
                  itemBuilder: (context, index) {
                    final task = widget.progress.tasks[index];
                    return FileTaskCard(
                      task: task,
                      index: index,
                      onItemTap: (context, task, _) =>
                          widget.onItemTap?.call(context, task, index),
                      itemPadding: widget.itemPadding,
                      leadingBuilder: widget.leadingBuilder == null
                          ? null
                          : (context, task, _) => widget.leadingBuilder!.call(
                              context,
                              task,
                              index,
                            ),
                      titleBuilder: widget.titleBuilder == null
                          ? null
                          : (context, task, _) =>
                                widget.titleBuilder!.call(context, task, index),
                      subtitleBuilder: widget.subtitleBuilder == null
                          ? null
                          : (context, task, _) => widget.subtitleBuilder!.call(
                              context,
                              task,
                              index,
                            ),
                      trailingBuilder: widget.trailingBuilder == null
                          ? null
                          : (context, task, _) => widget.trailingBuilder!.call(
                              context,
                              task,
                              index,
                            ),
                      progressBuilder: widget.progressBuilder == null
                          ? null
                          : (context, task, _) => widget.progressBuilder!.call(
                              context,
                              task,
                              index,
                            ),
                      animationDuration: widget.animationDuration,
                      showDetailedInfo: widget.showDetailedInfo,
                      useCompactLayout: widget.useCompactLayout,
                      showFileSize: widget.showFileSize,
                    ).animate().fadeIn(
                      duration: const Duration(milliseconds: 300),
                      delay: Duration(milliseconds: 50 * index),
                    );
                  },
                ),
        ),

        // Footer
        if (widget.footerBuilder != null)
          widget.footerBuilder!(context, widget.progress)
        else
          _buildDefaultFooter(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No files to upload',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Uploading ${widget.progress.tasks.length} ${widget.progress.tasks.length == 1 ? 'file' : 'files'}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              // _buildUploadSpeedWidget(context),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 0,
              end: widget.progress.overallProgressPercentage / 100,
            ),
            duration: widget.animationDuration,
            builder: (context, value, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${widget.progress.overallProgressPercentage.toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      Text(
                        '${widget.progress.totalBytesUploaded.formatBytes} / ${widget.progress.totalBytes.formatBytes}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ).animate().slideY(
      begin: -0.2,
      end: 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuad,
    );
  }

  Widget _buildDefaultFooter(BuildContext context) {
    final completedFiles = widget.progress.tasks
        .where((task) => task.isComplete)
        .length;
    final completionPercent = widget.progress.tasks.isEmpty
        ? 0.0
        : completedFiles / widget.progress.tasks.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      context,
                      completionPercent,
                    ).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: widget.progress.isComplete
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        )
                      : SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            value:
                                widget.progress.overallProgressPercentage / 100,
                            color: _getStatusColor(context, completionPercent),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.progress.isComplete
                            ? 'All uploads completed'
                            : 'Completed: $completedFiles/${widget.progress.tasks.length}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!widget.progress.isComplete &&
                          widget.progress.tasks.isNotEmpty)
                        Text(
                          _getEstimatedTimeRemaining(context),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.progress.isComplete)
            Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Complete',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 300))
                .scale(
                  begin: const Offset(0.9, 0.9),
                  duration: const Duration(milliseconds: 300),
                ),
        ],
      ),
    ).animate().slideY(
      begin: 0.2,
      end: 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutQuad,
    );
  }

  String _getEstimatedTimeRemaining(BuildContext context) {
    // This is a placeholder - implement actual time calculation based on upload speed
    return 'About 2 minutes remaining';
  }

  Color _getStatusColor(BuildContext context, double completionPercent) {
    if (completionPercent >= 0.99) {
      return Colors.green;
    } else if (completionPercent >= 0.5) {
      return Colors.orange;
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }
}
