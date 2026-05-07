import '../repository/file_task_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../transfer_kit.dart';
import '../model/file_task.dart';
import 'file_task_item.dart';

/// A widget that displays a list of file tasks with filtering, sorting, and batch controls.
///
/// Usage example:
/// ```dart
/// FileTaskList(
///   title: 'Upload Tasks',
///   showUploadTasks: true,
///   showDownloadTasks: false,
///   onTaskCompleted: (task) {
///     // Handle task completion
///     print('Task completed: ${task.fileName}');
///   },
///   onTaskRemoved: (task) {
///     // Handle task removal
///     print('Task removed: ${task.fileName}');
///   },
/// )
/// ```
///
/// Example with custom controller and list builders:
/// ```dart
/// FileTaskList(
///   title: 'All Tasks',
///   controller: fileManagementSystem, // Use existing controller
///   headerListBuilder: (context, tasks) => CustomHeaderWidget(tasks),
///   footerListBuilder: (context, tasks) => CustomFooterWidget(tasks),
///   itemBuilder: (context, task) => CustomTaskItem(task),
/// )
/// ```
///
/// This widget provides batch controls for starting, pausing, and canceling
/// multiple tasks at once, along with a summary of task statistics.
class FileTaskList extends StatefulWidget {
  final String title;
  final bool showUploadTasks;
  final bool showDownloadTasks;
  final bool showEmptyMessage;

  /// Builder function to customize how each task item is rendered
  final Widget Function(BuildContext context, FileTask task)? itemBuilder;

  /// Builder function to add a custom header to the list
  final Widget Function(BuildContext context, List<FileTask> tasks)?
  headerListBuilder;

  /// Builder function to add a custom footer to the list
  final Widget Function(BuildContext context, List<FileTask> tasks)?
  footerListBuilder;

  /// Custom file controller to use instead of creating a new one
  /// If not provided, a new one will be created and initialized
  final TransferKit? controller;

  /// Whether to automatically initialize the controller in initState
  /// Set to false if you need to handle initialization yourself
  final bool autoInitializeController;

  /// Callback when a task is completed
  final Function(FileTask task)? onTaskCompleted;

  /// Callback when a task is removed
  final Function(FileTask task)? onTaskRemoved;

  const FileTaskList({
    super.key,
    this.title = 'File Tasks',
    this.showUploadTasks = true,
    this.showDownloadTasks = true,
    this.showEmptyMessage = true,
    this.itemBuilder,
    this.headerListBuilder,
    this.footerListBuilder,
    this.controller,
    this.autoInitializeController = true,
    this.onTaskCompleted,
    this.onTaskRemoved,
  });

  @override
  State<FileTaskList> createState() => _FileTaskListState();
}

class _FileTaskListState extends State<FileTaskList>
    with SingleTickerProviderStateMixin {
  late final TransferKit _controller;
  late final AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Use provided controller or create a new one
    _controller = widget.controller ?? TransferKit.instance;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Start animation after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surfaceContainerLowest,
          ],
          stops: const [0.0, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and batch action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Row(
              children: [
                Expanded(
                  child:
                      Text(
                            widget.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          )
                          .animate(controller: _animationController)
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.1, end: 0),
                ),
                _buildBatchControlButton(
                      context: context,
                      icon: Icons.play_arrow_rounded,
                      label: 'Start All',
                      onPressed: () async {
                        await _controller.startAllWaitingTasks();
                      },
                      color: Colors.green,
                    )
                    .animate(controller: _animationController)
                    .fadeIn(delay: 100.ms, duration: 400.ms),
                const SizedBox(width: 8),
                _buildBatchControlButton(
                      context: context,
                      icon: Icons.pause_rounded,
                      label: 'Pause All',
                      onPressed: () async {
                        await _controller.pauseAllRunningTasks();
                      },
                      color: Colors.amber,
                    )
                    .animate(controller: _animationController)
                    .fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(width: 8),
                _buildBatchControlButton(
                      context: context,
                      icon: Icons.cancel_rounded,
                      label: 'Cancel All',
                      onPressed: () async {
                        await _showCancelConfirmation(context);
                      },
                      color: Colors.red.shade400,
                    )
                    .animate(controller: _animationController)
                    .fadeIn(delay: 300.ms, duration: 400.ms),
              ],
            ),
          ),

          // Task count summary
          StreamBuilder<Set<FileTask>>(
            initialData: FileTaskRepository.instance.value,
            stream: FileTaskRepository.instance.stream,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                final tasks = snapshot.data!;
                final uploadCount = tasks
                    .where((task) => task.type == FileTaskType.upload)
                    .length;
                final downloadCount = tasks
                    .where((task) => task.type == FileTaskType.download)
                    .length;
                final completedCount = tasks
                    .where((task) => task.isComplete)
                    .length;
                final activeCount = tasks
                    .where((task) => task.isRunning)
                    .length;

                return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTaskStatusChip(
                            label: 'Total: ${tasks.length}',
                            icon: Icons.folder,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          if (uploadCount > 0)
                            _buildTaskStatusChip(
                              label: 'Uploads: $uploadCount',
                              icon: Icons.upload_rounded,
                              backgroundColor: Colors.blue.withValues(
                                alpha: 0.1,
                              ),
                              textColor: Colors.blue,
                              iconColor: Colors.blue,
                            ),
                          if (downloadCount > 0)
                            _buildTaskStatusChip(
                              label: 'Downloads: $downloadCount',
                              icon: Icons.download_rounded,
                              backgroundColor: Colors.indigo.withValues(
                                alpha: 0.1,
                              ),
                              textColor: Colors.indigo,
                              iconColor: Colors.indigo,
                            ),
                          if (completedCount > 0)
                            _buildTaskStatusChip(
                              label: 'Completed: $completedCount',
                              icon: Icons.check_circle_outline,
                              backgroundColor: Colors.green.withValues(
                                alpha: 0.1,
                              ),
                              textColor: Colors.green,
                              iconColor: Colors.green,
                            ),
                          if (activeCount > 0)
                            _buildTaskStatusChip(
                              label: 'Active: $activeCount',
                              icon: Icons.sync,
                              backgroundColor: Colors.amber.withValues(
                                alpha: 0.1,
                              ),
                              textColor: Colors.amber.shade800,
                              iconColor: Colors.amber.shade800,
                            ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0);
              }
              return const SizedBox.shrink();
            },
          ),

          // Task list
          Expanded(
            child: StreamBuilder<Set<FileTask>>(
              initialData: FileTaskRepository.instance.value,
              stream: FileTaskRepository.instance.stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator()
                            .animate(
                              onPlay: (controller) => controller.repeat(),
                            )
                            .shimmer(
                              duration: 1200.ms,
                              color: Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.4),
                            ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading tasks...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ).animate().fadeIn(duration: 600.ms),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 48,
                        ).animate().scale(
                          duration: 400.ms,
                          curve: Curves.easeOutBack,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading tasks',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            snapshot.error.toString(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final tasks = snapshot.data ?? {};
                final filteredTasks = tasks
                    .where(
                      (task) =>
                          (widget.showUploadTasks &&
                              task.type == FileTaskType.upload) ||
                          (widget.showDownloadTasks &&
                              task.type == FileTaskType.download),
                    )
                    .toList();

                if (filteredTasks.isEmpty) {
                  if (widget.showEmptyMessage) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                                Icons.file_copy,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withValues(alpha: 0.5),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(
                                duration: 600.ms,
                                curve: Curves.easeOutBack,
                              ),
                          const SizedBox(height: 16),
                          Text(
                            'No tasks available',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Use the file upload or download functions to create tasks',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                        ],
                      ),
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                }

                return Column(
                  children: [
                    // Custom header if provided
                    if (widget.headerListBuilder != null)
                      widget.headerListBuilder!(context, filteredTasks),

                    // Task list
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        thickness: 6,
                        radius: const Radius.circular(8),
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: filteredTasks.length,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) {
                            final task = filteredTasks[index];
                            // Use custom item builder if provided, otherwise use default
                            return widget.itemBuilder?.call(context, task) ??
                                FileTaskItem(
                                  task: task,
                                  onTaskCompleted:
                                      widget.onTaskCompleted != null
                                      ? () => widget.onTaskCompleted!(task)
                                      : null,
                                  onTaskRemoved: widget.onTaskRemoved != null
                                      ? () => widget.onTaskRemoved!(task)
                                      : null,
                                );
                          },
                        ),
                      ),
                    ),

                    // Custom footer if provided
                    if (widget.footerListBuilder != null)
                      widget.footerListBuilder!(context, filteredTasks),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskStatusChip({
    required String label,
    required IconData icon,
    Color backgroundColor = Colors.grey,
    Color textColor = Colors.black87,
    Color iconColor = Colors.black87,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchControlButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = Colors.blue,
  }) {
    return ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16),
          label: Text(label),
          style:
              ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: color,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                elevation: 2,
                shadowColor: color.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ).copyWith(
                overlayColor: WidgetStateProperty.resolveWith<Color?>((
                  Set<WidgetState> states,
                ) {
                  if (states.contains(WidgetState.pressed)) {
                    return Colors.white.withValues(alpha: 0.2);
                  }
                  return null;
                }),
              ),
        )
        .animate(
          onPlay: (controller) =>
              controller.repeat(period: const Duration(seconds: 20)),
        )
        .shimmer(delay: 5000.ms, duration: 1800.ms, color: Colors.white24);
  }

  Future<void> _showCancelConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 12),
              Text('Cancel All Tasks'),
            ],
          ),
          content: const Text(
            'Are you sure you want to cancel all active tasks? '
            'This action cannot be undone.',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('No, Keep Tasks'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Yes, Cancel All'),
              onPressed: () {
                _controller.cancelAllActiveTasks();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
