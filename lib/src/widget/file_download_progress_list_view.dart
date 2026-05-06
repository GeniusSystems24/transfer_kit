import '../core/extension/num_extension.dart';
import '../core/utils/file_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../model/file_task.dart';
import '../model/multi_download_file_task.dart';

/// A widget that displays a list view of download progress for multiple files
///
/// Usage example:
/// ```dart
/// FileDownloadProgressListView(
///   progress: multiDownloadTask, // MultiDownloadTask from TransferKit
///   onFileDownloaded: (task, index) {
///     // Handle individual file download completion
///     print('File downloaded: ${task.fileName}');
///   },
///   onAllFilesDownloaded: (files) {
///     // Handle all files downloaded
///     print('All ${files.length} files downloaded');
///   },
///   showFileSize: true,
///   useCompactLayout: false,
/// )
/// ```
///
/// This widget is ideal for displaying progress when downloading multiple files
/// simultaneously, with callbacks for individual and overall completion.
class FileDownloadProgressListView extends StatefulWidget {
  /// The MultiDownloadProgress object containing download progress information
  final MultiDownloadFileTask progress;

  /// Callback when a file download is completed
  final Function(FileTask task, int index)? onFileDownloaded;

  /// Callback when all files are successfully downloaded
  final Function(List<FileTask> files)? onAllFilesDownloaded;

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
  final Widget Function(BuildContext context, MultiDownloadFileTask progress)?
      headerBuilder;

  /// Custom builder for the footer widget displayed below the list
  final Widget Function(BuildContext context, MultiDownloadFileTask progress)?
      footerBuilder;

  /// Custom item padding
  final EdgeInsetsGeometry itemPadding;

  /// Whether to show file size information
  final bool showFileSize;

  /// Callback when a list item is tapped
  final Function(FileTask task, int index)? onItemTap;

  /// Animation duration for progress changes
  final Duration animationDuration;

  /// Whether to show detailed file information
  final bool showDetailedInfo;

  /// Whether to use a compact layout
  final bool useCompactLayout;

  const FileDownloadProgressListView({
    super.key,
    required this.progress,
    this.onFileDownloaded,
    this.onAllFilesDownloaded,
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
  State<FileDownloadProgressListView> createState() => _FileDownloadProgressListViewState();
}

class _FileDownloadProgressListViewState extends State<FileDownloadProgressListView> {
  final Set<int> _reportedFileIndices = {};
  bool _allFilesReported = false;

  void _handleCallbacks() {
    // Check for completed files to trigger callback (only once per file)
    if (widget.onFileDownloaded != null) {
      for (int i = 0; i < widget.progress.tasks.length; i++) {
        final task = widget.progress.tasks[i];
        if (task.isComplete && !_reportedFileIndices.contains(i)) {
          _reportedFileIndices.add(i);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onFileDownloaded!(task, i);
          });
        }
      }
    }

    // Check if all files are completed to trigger onAllFilesDownloaded callback (only once)
    if (widget.onAllFilesDownloaded != null && widget.progress.isComplete && !_allFilesReported) {
      _allFilesReported = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final files = widget.progress.tasks.where((task) => task.isComplete).toList();
        widget.onAllFilesDownloaded!(files);
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
                    return _buildFileItem(
                      context,
                      task,
                      index,
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
            Icons.cloud_download,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No files to download',
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
                'Downloading ${widget.progress.tasks.length} ${widget.progress.tasks.length == 1 ? 'file' : 'files'}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              _buildDownloadSpeedWidget(context),
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
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ),
                      Text(
                        '${widget.progress.totalBytesDownloaded.formatBytes} / ${widget.progress.totalBytes.formatBytes}',
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

  Widget _buildDownloadSpeedWidget(BuildContext context) {
    // This is a placeholder - you'd need to calculate actual speed from your task data
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.speed,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '2.5 MB/s', // Replace with actual calculated speed
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultFooter(BuildContext context) {
    final completedFiles =
        widget.progress.tasks.where((task) => task.isComplete).length;
    final completionPercent =
        widget.progress.tasks.isEmpty ? 0.0 : completedFiles / widget.progress.tasks.length;

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
                            value: widget.progress.overallProgressPercentage / 100,
                            color: _getStatusColor(
                              context,
                              completionPercent,
                            ),
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
                            ? 'All downloads completed'
                            : 'Completed: $completedFiles/${widget.progress.tasks.length}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (!widget.progress.isComplete && widget.progress.tasks.isNotEmpty)
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
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
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
    // This is a placeholder - implement actual time calculation based on download speed
    return 'About 3 minutes remaining';
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

  Widget _buildFileItem(BuildContext context, FileTask task, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isComplete
              ? Colors.green.withValues(alpha: 0.3)
              : Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onItemTap != null ? () => widget.onItemTap!(task, index) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: widget.itemPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: widget.leadingBuilder != null
                    ? widget.leadingBuilder!(context, task, index)
                    : _buildDefaultLeading(context, task, index),
                title: widget.titleBuilder != null
                    ? widget.titleBuilder!(context, task, index)
                    : _buildDefaultTitle(context, task, index),
                subtitle: widget.subtitleBuilder != null
                    ? widget.subtitleBuilder!(context, task, index)
                    : _buildDefaultSubtitle(context, task, index),
                trailing: widget.trailingBuilder != null
                    ? widget.trailingBuilder!(context, task, index)
                    : _buildDefaultTrailing(context, task, index),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              widget.progressBuilder != null
                  ? widget.progressBuilder!(context, task, index)
                  : _buildDefaultProgress(context, task, index),

              // Show detailed info if enabled
              if (widget.showDetailedInfo && !widget.useCompactLayout)
                _buildDetailedInfo(context, task, index),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedInfo(BuildContext context, FileTask task, int index) {
    // Get estimated time based on progress
    final estimatedTime = task.progressPercentage > 0
        ? 'Est. ${(100 - task.progressPercentage) ~/ 10} min remaining'
        : 'Calculating...';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Added: Today',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    estimatedTime,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (task.destinationPath != null && task.destinationPath!.isNotEmpty)
            Row(
              children: [
                Icon(
                  Icons.folder,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Path: ${task.destinationPath}',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDefaultLeading(BuildContext context, FileTask task, int index) {
    final fileName = task.fileName;
    final fileTypeInfo = FileUtils.getFileTypeInfo(fileName);
    final iconData = fileTypeInfo.icon;
    final iconColor = fileTypeInfo.color;

    return Stack(
      children: [
        Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(iconData, color: iconColor, size: 24),
        ),
        if (task.isComplete)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 14,
              ),
            ),
          ),
      ],
    )
        .animate(
          // Only animate if the task is running
          target: task.state == FileTaskState.running ? 1 : 0,
        )
        .shimmer(duration: const Duration(seconds: 2));
  }

  Widget _buildDefaultTitle(BuildContext context, FileTask task, int index) {
    // Extract filename from URL
    final fileName = task.fileName;
    return Text(
      fileName,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: task.isComplete
                ? Colors.black87
                : Theme.of(context).colorScheme.onSurface,
          ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDefaultSubtitle(BuildContext context, FileTask task, int index) {
    if (widget.showFileSize) {
      final transferRate = task.state == FileTaskState.running
          ? ' • ${(task.bytesTransferred / 10000).round() / 100} MB/s'
          : '';

      return Text(
        '${task.bytesTransferred.formatBytes} / ${task.totalBytes.formatBytes}$transferRate',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildDefaultTrailing(BuildContext context, FileTask task, int index) {
    String text;
    Color color;
    IconData icon;

    if (task.isComplete) {
      text = 'Complete';
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (task.state == FileTaskState.completed) {
      text = 'Processing';
      color = Colors.blue;
      icon = Icons.hourglass_top;
    } else if (task.state == FileTaskState.running) {
      text = '${task.progressPercentage.toStringAsFixed(0)}%';
      color = Colors.blue;
      icon = Icons.cloud_download;
    } else if (task.state == FileTaskState.error) {
      text = 'Failed';
      color = Colors.red;
      icon = Icons.error;
    } else if (task.state == FileTaskState.paused) {
      text = 'Paused';
      color = Colors.orange;
      icon = Icons.pause;
    } else {
      text = 'Waiting';
      color = Colors.grey;
      icon = Icons.hourglass_empty;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, color: color, size: 14),
        ],
      ),
    )
        .animate(target: task.state == FileTaskState.running ? 1 : 0)
        .shimmer(duration: const Duration(seconds: 1));
  }

  Widget _buildDefaultProgress(BuildContext context, FileTask task, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: task.progressPercentage / 100),
      duration: widget.animationDuration,
      builder: (context, value, _) {
        return LinearProgressIndicator(
          value: value,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(
            task.isComplete
                ? Colors.green
                : task.state == FileTaskState.error
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );
  }
}
