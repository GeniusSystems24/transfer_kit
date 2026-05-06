import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../core/extension/file_path_extension.dart';
import '../core/extension/num_extension.dart';
import '../core/utils/file_utils.dart';
import '../transfer_kit.dart';
import '../model/file_task.dart';

/// A widget that displays a detailed file task item with controls and progress information.
///
/// Usage example:
/// ```dart
/// FileTaskItem(
///   task: fileTask, // FileTask instance from TransferKit
///   showProgressPercentage: true,
///   showFileSize: true,
///   onTaskCompleted: () {
///     // Handle task completion
///     print('Task completed: ${fileTask.fileName}');
///   },
///   onTaskRemoved: () {
///     // Handle task removal
///     print('Task removed: ${fileTask.fileName}');
///   },
/// )
/// ```
///
/// More complete example with customization:
/// ```dart
/// FileTaskItem(
///   task: fileTask,
///   margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
///   padding: EdgeInsets.all(12),
///   iconBuilder: (context, task) => CustomFileIcon(task),
///   statusBadgeBuilder: (context, task) => CustomStatusBadge(task),
///   progressBuilder: (context, task) => CustomProgressIndicator(task),
///   actionsBuilder: (context, task) => [
///     CustomActionButton(task),
///     AnotherActionButton(task),
///   ],
///   hideActions: false,
///   dateFormat: 'MMM d, yyyy • h:mm a',
/// )
/// ```
class FileTaskItem extends StatefulWidget {
  /// The file task to display
  final FileTask task;

  /// Callback when task is completed
  final VoidCallback? onTaskCompleted;

  /// Callback when task is removed
  final VoidCallback? onTaskRemoved;

  /// Custom builder for file icon
  final Widget Function(BuildContext context, FileTask task)? iconBuilder;

  /// Custom builder for task status badge
  final Widget Function(BuildContext context, FileTask task)?
      statusBadgeBuilder;

  /// Custom builder for progress indicator
  final Widget Function(BuildContext context, FileTask task)? progressBuilder;

  /// Custom builder for action buttons
  final List<Widget> Function(BuildContext context, FileTask task)?
      actionsBuilder;

  /// Control margin of the card
  final EdgeInsetsGeometry? margin;

  /// Control padding inside the card
  final EdgeInsetsGeometry padding;

  /// Whether to show the progress percentage
  final bool showProgressPercentage;

  /// Whether to show the file size information
  final bool showFileSize;

  /// Whether to hide action buttons
  final bool hideActions;

  /// Date format for creation time display
  final String? dateFormat;

  /// Custom card decoration
  final BoxDecoration? decoration;

  const FileTaskItem({
    super.key,
    required this.task,
    this.onTaskCompleted,
    this.onTaskRemoved,
    this.iconBuilder,
    this.statusBadgeBuilder,
    this.progressBuilder,
    this.actionsBuilder,
    this.margin,
    this.padding = const EdgeInsets.all(16.0),
    this.showProgressPercentage = true,
    this.showFileSize = true,
    this.hideActions = false,
    this.dateFormat,
    this.decoration,
  });

  @override
  State<FileTaskItem> createState() => _FileTaskItemState();
}

class _FileTaskItemState extends State<FileTaskItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  late TransferKit _fileController;

  @override
  void initState() {
    super.initState();
    _fileController = TransferKit.instance;

    // Initialize animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Initialize with the current progress
    _progressAnimation = Tween<double>(
      begin: 0,
      end: widget.task.progressPercentage / 100,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();

    // Check if task completed and trigger callback
    if (widget.task.isComplete && widget.onTaskCompleted != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTaskCompleted!();
      });
    }
  }

  @override
  void didUpdateWidget(FileTaskItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate progress changes
    if (oldWidget.task.progressPercentage != widget.task.progressPercentage) {
      _progressAnimation = Tween<double>(
        begin: oldWidget.task.progressPercentage / 100,
        end: widget.task.progressPercentage / 100,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: widget.margin ??
          const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      decoration: widget.decoration ??
          BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).cardColor,
                Theme.of(context).cardColor.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _getTaskStatusColor(context).withValues(alpha: 0.1),
                blurRadius: 12,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _getTaskStatusColor(context).withValues(alpha: 0.15),
              width: 1,
            ),
          ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              // Optional tap action - could expand details in future
            },
            splashColor: _getTaskStatusColor(context).withValues(alpha: 0.1),
            highlightColor: _getTaskStatusColor(
              context,
            ).withValues(alpha: 0.05),
            child: Padding(
              padding: widget.padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File name and type row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Use custom icon builder or default
                      widget.iconBuilder != null
                          ? widget.iconBuilder!(context, widget.task)
                          : _buildFileIcon()
                              .animate()
                              .scale(
                                duration: 400.ms,
                                curve: Curves.easeOutBack,
                              )
                              .fadeIn(duration: 300.ms),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getFileName(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            )
                                .animate()
                                .fadeIn(duration: 300.ms)
                                .slideX(begin: -0.1, end: 0),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  widget.task.type == FileTaskType.upload
                                      ? Icons.upload_rounded
                                      : Icons.download_rounded,
                                  size: 14,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .secondary
                                      .withValues(alpha: 0.7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${widget.task.type.name} • ${_formatDateTime(widget.task.createdAt)}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color
                                            ?.withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            )
                                .animate()
                                .fadeIn(delay: 100.ms, duration: 300.ms)
                                .slideX(begin: -0.1, end: 0),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Progress indicator with animated value
                  widget.progressBuilder != null
                      ? widget.progressBuilder!(context, widget.task)
                      : AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    children: [
                                      // Background gradient for progress bar
                                      Container(
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      // Animated progress bar with gradient
                                      FractionallySizedBox(
                                        widthFactor: _progressAnimation.value,
                                        child: Container(
                                          height: 10,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                _getProgressColor(context),
                                                _getProgressColor(
                                                  context,
                                                ).withValues(alpha: 0.7),
                                              ],
                                              begin: Alignment.centerLeft,
                                              end: Alignment.centerRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Pulse effect for running tasks
                                      if (widget.task.isRunning)
                                        FractionallySizedBox(
                                          widthFactor: _progressAnimation.value,
                                          child: Container(
                                            height: 10,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.3,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0,
                                                  ),
                                                ],
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        )
                                            .animate(
                                              onPlay: (controller) =>
                                                  controller.repeat(),
                                            )
                                            .shimmer(
                                                duration: 1500.ms, angle: 0),
                                    ],
                                  ),
                                ),
                                if (widget.showProgressPercentage ||
                                    widget.showFileSize) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          if (widget.showProgressPercentage)
                                            Text(
                                              '${widget.task.progressPercentage.toStringAsFixed(1)}%',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: _getProgressColor(
                                                      context,
                                                    ),
                                                  ),
                                            )
                                                .animate(
                                                  autoPlay: widget.task
                                                          .progressPercentage >
                                                      0,
                                                )
                                                .fadeIn(duration: 300.ms)
                                                .scaleXY(
                                                  begin: 0.9,
                                                  end: 1,
                                                  duration: 300.ms,
                                                ),
                                          const SizedBox(width: 8),
                                          // Status badge next to progress percentage
                                          widget.statusBadgeBuilder != null
                                              ? widget.statusBadgeBuilder!(
                                                  context,
                                                  widget.task,
                                                )
                                              : _buildStatusBadge(context),
                                        ],
                                      ),
                                      if (widget.showFileSize)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withValues(alpha: 0.6),
                                                Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHigh
                                                    .withValues(alpha: 0.4),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.storage_rounded,
                                                size: 14,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 4),
                                              RichText(
                                                text: TextSpan(
                                                  style: Theme.of(
                                                    context,
                                                  )
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                  children: [
                                                    TextSpan(
                                                      text: widget
                                                          .task
                                                          .bytesTransferred
                                                          .formatBytes,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: widget
                                                            .task.state.color,
                                                      ),
                                                    ),
                                                    const TextSpan(text: '/'),
                                                    TextSpan(
                                                      text: widget
                                                          .task
                                                          .totalBytes
                                                          .formatBytes,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ).animate().fadeIn(
                                              delay: 200.ms,
                                              duration: 400.ms,
                                            ),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                  // Only show actions if not hidden
                  if (!widget.hideActions && _shouldShowActionButtons()) ...[
                    const SizedBox(height: 20),
                    // Control buttons - use custom actions builder or default
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.end,
                          children: widget.actionsBuilder != null
                              ? widget.actionsBuilder!(
                                  context,
                                  widget.task,
                                )
                              : _buildDefaultActions(
                                  context,
                                  _fileController,
                                ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms)
                        .slideY(begin: 0.2, end: 0),
                  ],

                  // Error message
                  if (widget.task.isError && widget.task.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.15),
                              Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.error,
                              size: 18,
                            )
                                .animate(
                                  onPlay: (controller) => controller.repeat(
                                    reverse: true,
                                    period: const Duration(seconds: 4),
                                  ),
                                )
                                .fadeIn(duration: 300.ms)
                                .then()
                                .fadeOut(delay: 2000.ms, duration: 700.ms),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.task.errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.98, 0.98), duration: 400.ms);
  }

  bool _shouldShowActionButtons() {
    return widget.task.isWaiting ||
        widget.task.isRunning ||
        widget.task.isPaused ||
        widget.task.isError ||
        widget.task.isComplete ||
        widget.task.isCached ||
        widget.task.isCancelled;
  }

  List<Widget> _buildDefaultActions(
    BuildContext context,
    TransferKit controller,
  ) {
    final actionsList = <Widget>[];

    // Primary action button based on task state
    if (widget.task.isWaiting) {
      actionsList.add(
        _buildControlButton(
          context: context,
          icon: Icons.play_arrow_rounded,
          label: 'Start',
          onPressed: () async {
            await controller.startTask(widget.task.id);
          },
          color: Colors.green,
          isPrimary: true,
        ),
      );
    } else if (widget.task.isRunning) {
      actionsList.add(
        _buildControlButton(
          context: context,
          icon: Icons.pause_rounded,
          label: 'Pause',
          onPressed: () async {
            await controller.pauseTask(widget.task.id);
          },
          color: Colors.amber,
          isPrimary: true,
        ),
      );
    } else if (widget.task.isPaused) {
      actionsList.add(
        _buildControlButton(
          context: context,
          icon: Icons.play_arrow_rounded,
          label: 'Resume',
          onPressed: () async {
            await controller.resumeTask(widget.task.id);
          },
          color: Colors.green,
          isPrimary: true,
        ),
      );
    } else if (widget.task.isError) {
      actionsList.add(
        _buildControlButton(
          context: context,
          icon: Icons.refresh_rounded,
          label: 'Retry',
          onPressed: () async {
            await controller.retryTask(widget.task.id);
          },
          color: Theme.of(context).colorScheme.primary,
          isPrimary: true,
        ),
      );
    }

    // Secondary actions
    if (!widget.task.isComplete &&
        !widget.task.isCached &&
        !widget.task.isCancelled) {
      actionsList.add(
        _buildControlButton(
          context: context,
          icon: Icons.cancel_rounded,
          label: 'Cancel',
          onPressed: () async {
            _showConfirmationDialog(
              context: context,
              title: 'Cancel',
              content: 'Are you sure you want to cancel this task?',
              confirmAction: () async {
                await controller.cancelTask(widget.task.id);
              },
            );
          },
          color: Colors.grey.shade600,
          isPrimary: false,
        ),
      );
    }

    if (widget.task.isComplete ||
        widget.task.isCached ||
        widget.task.isCancelled ||
        widget.task.isError) {
      actionsList.add(
        _buildControlButton(
          context: context,
          icon: Icons.delete_rounded,
          label: 'Remove',
          onPressed: () async {
            _showConfirmationDialog(
              context: context,
              title: 'Remove Task?',
              content: 'Are you sure you want to remove this task?',
              confirmAction: () async {
                await controller.removeTask(widget.task.id);
                if (widget.onTaskRemoved != null) {
                  widget.onTaskRemoved!();
                }
              },
            );
          },
          color: Theme.of(context).colorScheme.error,
          isPrimary: false,
        ),
      );
    }

    return actionsList;
  }

  Future<void> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback confirmAction,
  }) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: title.toLowerCase().contains('remove')
                    ? Theme.of(context).colorScheme.error
                    : null,
                foregroundColor: title.toLowerCase().contains('remove')
                    ? Colors.white
                    : null,
              ),
              child: const Text('Confirm'),
              onPressed: () {
                confirmAction();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildFileIcon() {
    final fileName = _getFileName();
    final fileTypeInfo = FileUtils.getFileTypeInfo(fileName);
    final iconData = fileTypeInfo.icon;
    final iconColor = fileTypeInfo.color;
    final backgroundColor = iconColor.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundColor, backgroundColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(iconData, color: iconColor, size: 28),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    String label;
    Color color;
    IconData? icon;

    if (widget.task.state == FileTaskState.cached) {
      label = 'From Cache';
      color = Colors.teal;
      icon = Icons.cached;
    } else if (widget.task.isComplete) {
      label = 'Completed';
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (widget.task.isRunning) {
      label = 'Running';
      color = Colors.blue;
      icon = Icons.play_arrow;
    } else if (widget.task.isPaused) {
      label = 'Paused';
      color = Colors.amber;
      icon = Icons.pause;
    } else if (widget.task.isWaiting) {
      label = 'Waiting';
      color = Colors.grey;
      icon = Icons.hourglass_empty;
    } else if (widget.task.isCancelled) {
      label = 'Cancelled';
      color = Colors.grey;
      icon = Icons.cancel;
    } else if (widget.task.isError) {
      label = 'Error';
      color = Colors.red;
      icon = Icons.error_outline;
    } else {
      label = 'Unknown';
      color = Colors.grey;
      icon = null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
    required bool isPrimary,
  }) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 150),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          foregroundColor: isPrimary ? Colors.white : color,
          backgroundColor: isPrimary ? color : color.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: color.withValues(alpha: 0.5), width: 1),
          ),
          elevation: isPrimary ? 2 : 0,
          shadowColor: color.withValues(alpha: 0.4),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>((
            Set<WidgetState> states,
          ) {
            if (states.contains(WidgetState.pressed)) {
              return isPrimary
                  ? Colors.white.withValues(alpha: 0.2)
                  : color.withValues(alpha: 0.2);
            }
            return null;
          }),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18)
                .animate(onPlay: (controller) => controller.loop(count: 3))
                .shakeX(amount: 0.5, hz: 10, curve: Curves.easeInOut)
                .then()
                .shimmer(
                  delay: 300.ms,
                  duration: 1800.ms,
                  color:
                      isPrimary ? Colors.white24 : color.withValues(alpha: 0.3),
                ),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }

  Color _getProgressColor(BuildContext context) {
    if (widget.task.state == FileTaskState.cached) {
      return Colors.teal;
    } else if (widget.task.isComplete) {
      return Colors.green;
    } else if (widget.task.isError) {
      return Theme.of(context).colorScheme.error;
    } else if (widget.task.isPaused) {
      return Colors.amber;
    } else if (widget.task.isCancelled) {
      return Colors.grey;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Color _getTaskStatusColor(BuildContext context) {
    if (widget.task.state == FileTaskState.cached) {
      return Colors.teal;
    } else if (widget.task.isComplete) {
      return Colors.green;
    } else if (widget.task.isError) {
      return Theme.of(context).colorScheme.error;
    } else if (widget.task.isPaused) {
      return Colors.amber;
    } else if (widget.task.isRunning) {
      return Colors.blue;
    } else if (widget.task.isCancelled) {
      return Colors.grey;
    } else if (widget.task.isWaiting) {
      return Colors.grey;
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _getFileName() {
    if (widget.task.type == FileTaskType.upload) {
      return widget.task.filePath.fileName;
    } else {
      // For download tasks, try to extract filename from destination path
      return widget.task.destinationPath?.fileName ?? '';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat(widget.dateFormat ?? 'MMM d, y - HH:mm').format(dateTime);
  }
}
