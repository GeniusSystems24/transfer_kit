import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';

/// Screen demonstrating task management functionality
class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({super.key});

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _controller = TransferKit.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Tasks', icon: Icon(Icons.list)),
            Tab(text: 'Downloads', icon: Icon(Icons.download)),
            Tab(text: 'Uploads', icon: Icon(Icons.upload)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pause_all',
                child: ListTile(
                  leading: Icon(Icons.pause),
                  title: Text('Pause All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'resume_all',
                child: ListTile(
                  leading: Icon(Icons.play_arrow),
                  title: Text('Resume All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'cancel_all',
                child: ListTile(
                  leading: Icon(Icons.cancel),
                  title: Text('Cancel All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'clear_completed',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep),
                  title: Text('Clear Completed'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'FileTaskList provides a real-time view of all active file operations with progress tracking and controls.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Task List
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All Tasks Tab
                _buildTaskList(null),

                // Downloads Tab
                _buildTaskList(FileTaskType.download),

                // Uploads Tab
                _buildTaskList(FileTaskType.upload),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Task'),
      ),
    );
  }

  Widget _buildTaskList(FileTaskType? filterType) {
    return StreamBuilder<Set<FileTask>>(
      stream: _controller.taskStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        var tasks = snapshot.data!.toList();

        // Filter by type if specified
        if (filterType != null) {
          tasks = tasks.where((t) => t.type == filterType).toList();
        }

        if (tasks.isEmpty) {
          return _buildEmptyState(filterType);
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildTaskCard(task);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(FileTaskType? filterType) {
    String message;
    IconData icon;

    switch (filterType) {
      case FileTaskType.download:
        message = 'No downloads in progress';
        icon = Icons.download_done;
        break;
      case FileTaskType.upload:
        message = 'No uploads in progress';
        icon = Icons.cloud_done;
        break;
      default:
        message = 'No active tasks';
        icon = Icons.task_alt;
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks will appear here when started',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(FileTask task) {
    final isDownload = task.type == FileTaskType.download;
    final stateColor = _getStateColor(task.state);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDownload
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDownload ? Icons.download : Icons.upload,
                    color: isDownload ? Colors.blue : Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${FileUtils.formatSize(task.bytesTransferred)} / ${FileUtils.formatSize(task.totalBytes)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stateColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.state.name.toUpperCase(),
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: task.progressPercentage / 100,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      task.isComplete ? Colors.green : stateColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 45,
                  child: Text(
                    '${task.progressPercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: stateColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.isRunning)
                  IconButton(
                    icon: const Icon(Icons.pause),
                    tooltip: 'Pause',
                    onPressed: () => _controller.pauseTask(task.id),
                  ),
                if (task.state == FileTaskState.paused)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Resume',
                    onPressed: () => _controller.resumeTask(task.id),
                  ),
                if (!task.isComplete)
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    tooltip: 'Cancel',
                    onPressed: () => _controller.cancelTask(task.id),
                  ),
                if (task.isComplete || task.state == FileTaskState.error)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Remove',
                    onPressed: () => _controller.removeTask(task.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStateColor(FileTaskState state) {
    switch (state) {
      case FileTaskState.running:
        return Colors.blue;
      case FileTaskState.paused:
        return Colors.orange;
      case FileTaskState.completed:
      case FileTaskState.cached:
        return Colors.green;
      case FileTaskState.error:
        return Colors.red;
      case FileTaskState.cancelled:
        return Colors.grey;
      case FileTaskState.waiting:
        return Colors.grey;
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'pause_all':
        _controller.pauseAllRunningTasks();
        _showSnackBar('All tasks paused');
        break;
      case 'resume_all':
        _controller.startAllWaitingTasks();
        _showSnackBar('All tasks resumed');
        break;
      case 'cancel_all':
        _showCancelConfirmation();
        break;
      case 'clear_completed':
        _controller.clearCompletedTasks();
        _showSnackBar('Completed tasks cleared');
        break;
    }
  }

  void _showCancelConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel All Tasks?'),
        content: const Text(
          'This will cancel all running downloads and uploads. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.cancelAllActiveTasks();
              _showSnackBar('All tasks cancelled');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel All'),
          ),
        ],
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final urlController = TextEditingController();
    var isDownload = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Download'),
                    icon: Icon(Icons.download),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Upload'),
                    icon: Icon(Icons.upload),
                  ),
                ],
                selected: {isDownload},
                onSelectionChanged: (value) {
                  setDialogState(() => isDownload = value.first);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: isDownload ? 'Download URL' : 'File Path',
                  hintText: isDownload
                      ? 'https://example.com/file.jpg'
                      : '/path/to/file.jpg',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (isDownload && urlController.text.isNotEmpty) {
                  _controller.downloadTaskStream(
                    filePathAndUrl: FilePathAndURL.url(url: urlController.text),
                    taskId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
                  );
                  _showSnackBar('Download started');
                } else {
                  _showSnackBar('Upload requires Firebase configuration');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
