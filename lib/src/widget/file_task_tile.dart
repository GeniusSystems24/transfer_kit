import 'dart:io';
import '../core/utils/file_utils.dart';
import '../transfer_kit.dart';
import '../model/file_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

class FileTaskTile extends StatelessWidget {
  const FileTaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.showDetails = false,
    this.showControls = true,
    this.showBottomBorder = true,
    this.compact = false,
    this.showThumbnail = true,
    this.controller,
  });

  final FileTask task;
  final VoidCallback? onTap;
  final bool showDetails;
  final bool showControls;
  final bool showBottomBorder;
  final bool compact;
  final bool showThumbnail;

  /// Optional controller for task actions. Uses [TransferKit.instance] if not provided.
  final TransferKit? controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isImage = _isImageFile(task.fileName);

    // Determine status color
    final Color statusColor = _getStatusColor(theme);

    // Calculate progress
    final progressPercentage = task.progressPercentage;
    final progress = progressPercentage / 100;

    // Animated card
    return Card(
          elevation: 1,
          margin: EdgeInsets.symmetric(
            vertical: compact ? 2.0 : 4.0,
            horizontal: compact ? 4.0 : 8.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: statusColor.withValues(alpha: 0.5),
              width: task.isError ? 1.0 : 0.0,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main content
                Padding(
                  padding: EdgeInsets.all(compact ? 8.0 : 12.0),
                  child: Row(
                    children: [
                      // File thumbnail or icon (conditionally shown)
                      if (showThumbnail) ...[
                        Container(
                          width: compact ? 50 : 60,
                          height: compact ? 50 : 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: isImage && task.filePath.isNotEmpty
                              ? _buildImageThumbnail(task.filePath)
                              : _buildFileTypeIcon(theme),
                        ),
                        SizedBox(width: compact ? 8 : 12),
                      ],

                      // File details and progress
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Filename and status badge row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Filename
                                Expanded(
                                  child: Text(
                                    task.fileName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: compact ? 12 : 14,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                // Status badge for completed/error/paused
                                if (task.isComplete ||
                                    task.isError ||
                                    task.isPaused)
                                  _buildStatusBadge(theme),
                              ],
                            ),

                            // Timestamp (creation time)
                            if (!compact)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  'Created ${_getTimeAgo(task.createdAt)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),

                            // Size info with error message if applicable
                            Padding(
                              padding: EdgeInsets.only(top: compact ? 4 : 6),
                              child: Row(
                                children: [
                                  Text(
                                    '${_formatFileSize(task.bytesTransferred)} of ${_formatFileSize(task.totalBytes)}',
                                    style: TextStyle(
                                      fontSize: compact ? 10 : 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  if (task.isError)
                                    Expanded(
                                      child: Text(
                                        ' • ${task.errorMessage ?? "Error"}',
                                        style: TextStyle(
                                          fontSize: compact ? 10 : 12,
                                          color: theme.colorScheme.error,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Progress bar with percentage
                            Padding(
                              padding: EdgeInsets.only(top: compact ? 4 : 8),
                              child: Row(
                                children: [
                                  // Progress bar with animation
                                  Expanded(
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: 0,
                                        end: progress,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      builder: (context, value, _) {
                                        return ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: value,
                                            backgroundColor: theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  statusColor,
                                                ),
                                            minHeight: compact ? 4 : 6,
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  // Percentage display
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    child: Text(
                                      '${progressPercentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: compact ? 10 : 12,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Action button (conditionally shown)
                      if (showControls) _buildTaskAction(theme),
                    ],
                  ),
                ),

                // Additional details section (conditionally shown)
                if (showDetails &&
                    (task.destinationPath != null || task.url != null))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (task.destinationPath != null &&
                            task.destinationPath!.isNotEmpty)
                          _buildDetailRow(
                            'Storage Path',
                            task.destinationPath!,
                            theme,
                          ),
                        if (task.url != null && task.url!.isNotEmpty)
                          _buildDetailRow('URL', task.url!, theme),
                        if (task.groupId != null && task.groupId!.isNotEmpty)
                          _buildDetailRow('Batch', task.groupId!, theme),
                        if (task.lastUpdatedAt != null)
                          _buildDetailRow(
                            'Last Updated',
                            DateFormat(
                              'MMM d, h:mm a',
                            ).format(task.lastUpdatedAt!),
                            theme,
                          ),
                      ],
                    ),
                  ),

                // Bottom border (conditionally shown)
                if (showBottomBorder && !showDetails)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.2,
                    ),
                  ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 300))
        .slideY(
          begin: 0.05,
          end: 0,
          duration: const Duration(milliseconds: 200),
        );
  }

  bool _isImageFile(String fileName) {
    return FileUtils.isImageFile(fileName);
  }

  Widget _buildImageThumbnail(String path) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Builder(
        builder: (context) {
          try {
            return Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.broken_image, size: 30);
              },
            );
          } catch (e) {
            return const Icon(Icons.broken_image, size: 30);
          }
        },
      ),
    );
  }

  Widget _buildFileTypeIcon(ThemeData theme) {
    final fileTypeInfo = FileUtils.getFileTypeInfo(task.fileName);
    final iconData = fileTypeInfo.icon;
    final iconColor = fileTypeInfo.color;

    return Center(
      child: Icon(iconData, size: compact ? 24 : 30, color: iconColor),
    );
  }

  Widget _buildStatusBadge(ThemeData theme) {
    if (task.isComplete) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: compact ? 12 : 14,
              color: Colors.green,
            ),
            SizedBox(width: compact ? 2 : 4),
            Text(
              'Complete',
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (task.isError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: compact ? 12 : 14,
              color: theme.colorScheme.error,
            ),
            SizedBox(width: compact ? 2 : 4),
            Text(
              'Failed',
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (task.isPaused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pause_circle_outline,
              size: compact ? 12 : 14,
              color: Colors.amber,
            ),
            SizedBox(width: compact ? 2 : 4),
            Text(
              'Paused',
              style: TextStyle(
                fontSize: compact ? 9 : 10,
                color: Colors.amber.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    return FileUtils.formatSize(bytes);
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildTaskAction(ThemeData theme) {
    final fileController = controller ?? TransferKit.instance;

    if (task.isRunning) {
      return IconButton(
            icon: const Icon(Icons.pause),
            tooltip: 'Pause',
            color: theme.colorScheme.primary,
            onPressed: () => fileController.pauseTask(task.id),
            iconSize: compact ? 20 : 24,
            visualDensity: VisualDensity.compact,
          )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.1, 1.1),
            duration: const Duration(seconds: 2),
          );
    } else if (task.isPaused || task.isWaiting) {
      return IconButton(
        icon: const Icon(Icons.play_arrow),
        tooltip: 'Resume',
        color: Colors.green,
        onPressed: () => fileController.resumeTask(task.id),
        iconSize: compact ? 20 : 24,
        visualDensity: VisualDensity.compact,
      );
    } else if (task.isError || task.isCancelled) {
      return IconButton(
        icon: const Icon(Icons.refresh),
        tooltip: 'Retry',
        color: theme.colorScheme.primary,
        onPressed: () => fileController.retryTask(task.id),
        iconSize: compact ? 20 : 24,
        visualDensity: VisualDensity.compact,
      );
    } else if (task.isComplete) {
      return IconButton(
        icon: const Icon(Icons.check_circle),
        tooltip: 'Completed',
        color: Colors.green,
        onPressed: null,
        iconSize: compact ? 20 : 24,
        visualDensity: VisualDensity.compact,
      );
    } else {
      return SizedBox(width: compact ? 32 : 40);
    }
  }

  Color _getStatusColor(ThemeData theme) {
    if (task.isError) return theme.colorScheme.error;
    if (task.isComplete || task.isCached) return Colors.green;
    if (task.isPaused) return Colors.amber;
    if (task.isCancelled) return Colors.grey;

    // Default for running/waiting
    return theme.colorScheme.primary;
  }
}
