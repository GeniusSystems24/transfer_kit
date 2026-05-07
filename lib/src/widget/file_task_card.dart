import '../core/extension/num_extension.dart';
import '../core/utils/file_utils.dart';
import '../model/file_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A card widget that displays information and progress for a single file task.
///
/// Usage example:
/// ```dart
/// FileTaskCard(
///   task: fileTask, // A FileTask instance from TransferKit
///   showDetailedInfo: true,
///   showFileSize: true,
///   onItemTap: (context, task, index) {
///     // Handle tap on the task card
///     Navigator.push(context,
///       MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task))
///     );
///   },
///   onCompletedTask: (context, task, index) {
///     // Handle task completion
///     showSnackBar('Task completed: ${task.fileName}');
///   },
/// )
/// ```
///
/// This widget can be customized with different builders for each part:
/// ```dart
/// FileTaskCard(
///   task: fileTask,
///   leadingBuilder: (context, task, index) => CustomLeadingWidget(task),
///   titleBuilder: (context, task, index) => Text(task.fileName),
///   progressBuilder: (context, task, index) => CustomProgressBar(task),
/// )
/// ```
class FileTaskCard extends StatelessWidget {
  final FileTask task;
  final int? index;
  final EdgeInsetsGeometry itemPadding;
  final Widget Function(BuildContext context, FileTask task, int? index)?
  leadingBuilder;
  final Widget Function(BuildContext context, FileTask task, int? index)?
  titleBuilder;
  final Widget Function(BuildContext context, FileTask task, int? index)?
  subtitleBuilder;
  final Widget Function(BuildContext context, FileTask task, int? index)?
  trailingBuilder;
  final Duration animationDuration;
  final bool showDetailedInfo;
  final bool useCompactLayout;
  final bool showFileSize;
  final void Function(BuildContext context, FileTask task, int? index)?
  onItemTap;
  final Widget Function(BuildContext context, FileTask task, int? index)?
  progressBuilder;
  final void Function(BuildContext context, FileTask task, int? index)?
  onCompletedTask;

  const FileTaskCard({
    super.key,
    required this.task,
    this.index,
    this.itemPadding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.leadingBuilder,
    this.titleBuilder,
    this.subtitleBuilder,
    this.trailingBuilder,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showDetailedInfo = false,
    this.useCompactLayout = false,
    this.showFileSize = true,
    this.onItemTap,
    this.progressBuilder,
    this.onCompletedTask,
  });

  @override
  Widget build(BuildContext context) {
    if (task.isComplete && onCompletedTask != null) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        onCompletedTask!(context, task, index);
      });
    }
    return Card(
      // margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.state.color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onItemTap != null
            ? () => onItemTap!(context, task, index)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: itemPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading:
                    leadingBuilder?.call(context, task, index) ??
                    _buildDefaultLeading(context, task, index),
                title:
                    titleBuilder?.call(context, task, index) ??
                    _buildDefaultTitle(context, task, index),
                subtitle:
                    subtitleBuilder?.call(context, task, index) ??
                    _buildDefaultSubtitle(context, task, index),
                trailing:
                    trailingBuilder?.call(context, task, index) ??
                    _buildDefaultTrailing(context, task, index),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              progressBuilder?.call(context, task, index) ??
                  _buildDefaultProgress(context, task, index),

              // Show detailed info if enabled
              if (showDetailedInfo && !useCompactLayout)
                _buildDetailedInfo(context, task, index),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLeading(BuildContext context, FileTask task, int? index) {
    final fileName = task.fileName;
    final fileTypeInfo = FileUtils.getFileTypeInfo(fileName);
    final iconData = fileTypeInfo.icon;
    final iconColor = fileTypeInfo.color;

    var isComplete = task.isComplete;
    var isRunning = task.state == FileTaskState.running;
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
            if (isComplete)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: task.state.color,
                    size: 14,
                  ),
                ),
              ),
          ],
        )
        .animate(target: isRunning ? 1 : 0)
        .shimmer(duration: const Duration(seconds: 2));
  }

  Widget _buildDefaultTitle(BuildContext context, FileTask task, int? index) {
    // Extract filename from path
    final fileName = task.fileName;
    return Text(
      fileName,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.bold,
        color: task.isComplete
            ? task.state.color
            : Theme.of(context).colorScheme.onSurface,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDefaultSubtitle(
    BuildContext context,
    FileTask task,
    int? index,
  ) {
    if (showFileSize) {
      return Text(
        '${task.bytesTransferred.formatBytes} / ${task.totalBytes.formatBytes}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildDefaultTrailing(
    BuildContext context,
    FileTask task,
    int? index,
  ) {
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
      icon = Icons.cloud_upload;
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
        .animate(target: task.isRunning ? 1 : 0)
        .shimmer(duration: const Duration(seconds: 1));
  }

  Widget _buildDefaultProgress(
    BuildContext context,
    FileTask task,
    int? index,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: task.progressPercentage / 100),
      duration: animationDuration,
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
            )
            .animate(target: task.isRunning ? 1 : 0)
            .shimmer(duration: const Duration(seconds: 1));
      },
    );
  }

  Widget _buildDetailedInfo(BuildContext context, FileTask task, int? index) {
    // Get estimated time based on progress
    final estimatedTime = task.progressPercentage > 0
        ? 'Est. ${(100 - task.progressPercentage) ~/ 10} min remaining'
        : 'Calculating...';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      // padding: const EdgeInsets.all(8),
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
          if (task.downloadUrl != null)
            Row(
              children: [
                Icon(
                  Icons.link,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'URL: ${task.downloadUrl}',
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
}
