import 'package:dashed_circular_progress_bar/dashed_circular_progress_bar.dart';
import 'package:flutter/material.dart';

import 'file_task_controller.dart';

/// Widget to display a document download item with progress.
///
/// Displays the file name, size, progress with modern design.
/// Supports pause, resume, cancel, retry, and open actions.
class DocumentDownloadCard extends StatelessWidget {
  final TaskItem? item;
  final String? fileName;
  final int? fileSize;
  final VoidCallback? onStart;
  final void Function(TaskItem item)? onPause;
  final void Function(TaskItem item)? onResume;
  final void Function(TaskItem item)? onCancel;
  final void Function(TaskItem item)? onRetry;
  final void Function(TaskItem item)? onOpen;
  final void Function(TaskItem item)? onRemove;
  final Widget Function(BuildContext context, TaskItem item) completedBuilder;
  final Widget Function(BuildContext context, TaskItem? item) loadingBuilder;
  final Widget Function(BuildContext context, TaskItem? item, Exception? error)?
  errorBuilder;

  /// Icon color for action buttons
  final Color? iconColor;

  const DocumentDownloadCard({
    super.key,
    required this.completedBuilder,
    required this.loadingBuilder,
    this.item,
    this.fileName,
    this.fileSize,
    this.onStart,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onRetry,
    this.onOpen,
    this.onRemove,
    this.errorBuilder,
    this.iconColor,
  });

  VoidCallback? _getMainAction() {
    switch (item?.status) {
      case TaskStatus.running:
        return (item?.allowPause ?? false)
            ? onPause == null
                  ? null
                  : () => onPause?.call(item!)
            : null;
      case TaskStatus.paused:
        return onResume == null ? null : () => onResume?.call(item!);
      case TaskStatus.failed:
        return onRetry == null ? null : () => onRetry?.call(item!);
      case TaskStatus.complete:
        return onOpen == null ? null : () => onOpen?.call(item!);
      default:
        return onStart;
    }
  }

  Widget _playAndPauseButton(
    BuildContext context,
    TaskItem? taskItem,
    Color foregroundColor,
    Color backgroundColor,
  ) {
    final theme = Theme.of(context);

    final progressPercentage = (taskItem?.progress ?? 0) * 100;

    if (taskItem?.status != TaskStatus.running) {
      return DashedCircularProgressBar.square(
        dimensions: 40,
        progress: progressPercentage,
        maxProgress: 100,
        backgroundStrokeWidth: 3,
        foregroundStrokeWidth: 3,
        foregroundColor: theme.colorScheme.secondary,
        backgroundColor: foregroundColor.withValues(
          alpha: taskItem == null ? 0.0 : 0.3,
        ),
        child: Icon(Icons.cloud_download, color: foregroundColor, size: 25),
      );
    }

    return DashedCircularProgressBar.square(
      dimensions: 40,
      progress: progressPercentage,
      maxProgress: 100,
      backgroundStrokeWidth: 3,
      foregroundStrokeWidth: 3,
      foregroundColor: theme.colorScheme.primary,
      backgroundColor: foregroundColor.withValues(alpha: 0.4),
      child: Icon(Icons.close, color: foregroundColor, size: 25),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (item?.status == TaskStatus.complete) {
      return completedBuilder(context, item!);
    }
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          // Action button
          if (item?.status != TaskStatus.complete)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(1000),
                onTap: _getMainAction(),
                child: _playAndPauseButton(
                  context,
                  item,
                  effectiveIconColor,
                  theme.colorScheme.surface,
                ),
              ),
            ),

          const SizedBox(width: 12),

          // Error message
          if (item?.status == TaskStatus.failed || item?.exception != null)
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item!.exception?.description ?? 'Download failed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(child: loadingBuilder(context, item)),
        ],
      ),
    );
  }
}
