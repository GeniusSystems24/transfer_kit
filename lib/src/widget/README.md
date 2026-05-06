# File Management System Widgets

This directory contains widgets for handling file uploads, downloads, and task management in Flutter applications.

## Table of Contents

- [File Management System Widgets](#file-management-system-widgets)
  - [Table of Contents](#table-of-contents)
  - [Common Features Across All Widgets](#common-features-across-all-widgets)
    - [Controller Injection](#controller-injection)
    - [Initialization Control](#initialization-control)
    - [Event Callbacks](#event-callbacks)
    - [Path-Based File Handling](#path-based-file-handling)
  - [FileDownloadProgressIndicator](#filedownloadprogressindicator)
    - [Example Usage](#example-usage)
  - [FileLoadingCard](#fileloadingcard)
    - [Key Features](#key-features)
    - [Basic Usage](#basic-usage)
    - [Advanced Example](#advanced-example)
    - [Task-Controlled Loading](#task-controlled-loading)
    - [Using Custom Controller](#using-custom-controller)
  - [FileTaskItem](#filetaskitem)
    - [Basic Usage example](#basic-usage-example)
    - [Customized Example](#customized-example)
  - [FileTaskList](#filetasklist)
    - [FileTaskList Basic Usage example](#filetasklist-basic-usage-example)
    - [FileTaskList Customized Example](#filetasklist-customized-example)
    - [FileTaskList with Custom Controller](#filetasklist-with-custom-controller)
  - [FileUploadCard](#fileuploadcard)
    - [FileUploadCard Key Features](#fileuploadcard-key-features)
    - [FileUploadCard Basic Usage](#fileuploadcard-basic-usage)
    - [FileUploadCard Advanced Example](#fileuploadcard-advanced-example)
    - [FileUploadCard Task-Controlled Upload](#fileuploadcard-task-controlled-upload)
    - [FileUploadCard with Custom Controller](#fileuploadcard-with-custom-controller)
  - [FileUploadProgressIndicator](#fileuploadprogressindicator)
    - [FileUploadProgressIndicator Example Usage](#fileuploadprogressindicator-example-usage)
  - [MultiFileLoadingCard](#multifileloadingcard)
    - [MultiFileLoadingCard Basic Usage](#multifileloadingcard-basic-usage)
    - [MultiFileLoadingCard Advanced Example](#multifileloadingcard-advanced-example)
    - [MultiFileLoadingCard with Custom Controller and Callbacks](#multifileloadingcard-with-custom-controller-and-callbacks)
  - [MultiFileUploadCard](#multifileuploadcard)
    - [MultiFileUploadCard Basic Usage](#multifileuploadcard-basic-usage)
    - [MultiFileUploadCard Advanced Example](#multifileuploadcard-advanced-example)
    - [MultiFileUploadCard with Custom Controller and Callbacks](#multifileuploadcard-with-custom-controller-and-callbacks)
  - [MultiUploadProgressIndicator](#multiuploadprogressindicator)
    - [MultiUploadProgressIndicator Example Usage](#multiuploadprogressindicator-example-usage)
    - [MultiUploadProgressIndicator Example in Bottom Sheet](#multiuploadprogressindicator-example-in-bottom-sheet)
  - [Architecture Notes](#architecture-notes)

## Common Features Across All Widgets

All the file management widgets have been enhanced with the following common features:

### Controller Injection

All widgets now support optional injection of a custom `CachedFileController`:

```dart
// Create a shared controller for reuse
final sharedController = CachedFileController();

// Use in any file management widget
FileLoadingCard(
  url: 'https://example.com/file.pdf',
  onLoaded: (file) => PDFView(file: file),
  controller: sharedController, // Inject the shared controller
);
```

### Initialization Control

The widgets provide flexibility in controller initialization:

```dart
FileLoadingCard(
  url: 'https://example.com/file.pdf',
  onLoaded: (file) => PDFView(file: file),
  controller: customController,
  autoInitializeController: false, // Don't auto-initialize
);

// Later, manually initialize
await customController.initialize();
```

### Event Callbacks

Enhanced callback system to react to important events:

```dart
FileTaskList(
  onTaskCompleted: (task) {
    // Handle completed task
    showNotification('File ${task.path} completed');
  },
  onTaskRemoved: (task) {
    // Handle removed task
    updateTaskCounter();
  },
);
```

### Path-Based File Handling

All widgets now use string file paths instead of File objects for greater flexibility and easier serialization:

```dart
// Before: Using File objects
FileUploadCard(
  file: File('/path/to/file.jpg'),
  destinationPath: 'uploads/image.jpg',
)

// After: Using string file paths
FileUploadCard(
  filePath: '/path/to/file.jpg',
  destinationPath: 'uploads/image.jpg',
)
```

The path-based approach offers several key benefits:

1. **Easier Serialization**: String paths can be easily stored in databases, shared preferences, and passed between components
2. **Reduced Memory Footprint**: File objects are only created when actually needed for file operations
3. **Better State Management**: Path strings work seamlessly with state management solutions without serialization issues
4. **Flexibility**: Paths can be manipulated, combined, and processed without creating File objects
5. **Duplicate Prevention**: Using Sets instead of Lists for collections of files automatically prevents duplicates

```dart
// Using Sets for unique collection of file paths
final Set<String> imagePaths = {
  '/path/to/image1.jpg',
  '/path/to/image2.jpg',
  '/path/to/image1.jpg' // Duplicate automatically ignored in a Set
};

// Use the Set directly with file management widgets
MultiFileUploadCard(
  filePaths: imagePaths,
  destinationPaths: {'uploads/image1.jpg', 'uploads/image2.jpg'},
  onUploaded: (urls) => saveUrlsToDatabase(urls),
);
```

When needed, the path can be easily converted to a File object:

```dart
// Create File object only when needed for operations
String filePath = '/path/to/file.jpg';
File fileObject = File(filePath);

// FileTask model provides a convenience method to get File when needed
FileTask task = await controller.createUploadTask(filePath, destinationPath);
File fileFromTask = task.fileObject; // Only creates File object when accessed
```

## FileDownloadProgressIndicator

A widget that displays download progress information with a circular progress indicator and size details.

### Example Usage

```dart
StreamBuilder<DownloadProgress>(
  stream: CachedFileController().streamFile(fileUrl),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return FileDownloadProgressIndicator(
        progress: snapshot.data!,
      );
    }
    return const CircularProgressIndicator();
  },
)
```

## FileLoadingCard

A card widget that handles loading files from a URL with progress indication.

### Key Features

- Cached file loading
- Real-time progress tracking
- Error handling
- Task control capabilities
- Custom controller support

### Basic Usage

```dart
FileLoadingCard(
  url: 'https://example.com/document.pdf',
  onLoaded: (file) => PDFView(file: file),
  useStream: true,
  checkCacheFirst: true,
)
```

### Advanced Example

```dart
FileLoadingCard(
  url: 'https://example.com/image.jpg',
  onLoaded: (file) => Image.file(file),
  useStream: true,
  downloadingWidget: (context, progress) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          value: progress.progressPercentage / 100,
        ),
        const SizedBox(height: 16),
        Text(
          '${progress.progressPercentage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          '${progress.downloadedSizeMB.toStringAsFixed(1)} MB / ${progress.totalSizeMB.toStringAsFixed(1)} MB',
        ),
      ],
    ),
  ),
  onError: (error) => Text('Error: $error'),
  placeholder: const Center(child: CircularProgressIndicator()),
)
```

### Task-Controlled Loading

```dart
FileLoadingCard(
  url: 'https://example.com/large-file.zip',
  onLoaded: (file) => Text('File loaded: ${file.path}'),
  useTaskControl: true,
  autoStart: false,
  taskControlWidget: (context, task) => CustomTaskWidget(task: task),
)
```

### Using Custom Controller

```dart
// Create a shared controller that can be used across the app
final fileController = CachedFileController();

// Later in your widget
FileLoadingCard(
  url: 'https://example.com/large-file.zip',
  onLoaded: (file) => Text('File loaded: ${file.path}'),
  controller: fileController,
  onTaskCompleted: (task) {
    // Handle task completion
    showCompletionNotification();
  },
  onTaskRemoved: (task) {
    // Handle task removal
    cleanupResources();
  },
)
```

## FileTaskItem

A widget to display and manage a single file task (upload or download) with detailed progress information and controls.

### Basic Usage example

```dart
StreamBuilder<List<FileTask>>(
  stream: CachedFileController().taskStream,
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
      return FileTaskItem(
        task: snapshot.data!.first,
        onTaskCompleted: () => print('Task completed'),
        onTaskRemoved: () => print('Task removed'),
      );
    }
    return const SizedBox.shrink();
  },
)
```

### Customized Example

```dart
FileTaskItem(
  task: fileTask,
  iconBuilder: (context, task) => CustomIconWidget(task: task),
  statusBadgeBuilder: (context, task) => CustomStatusWidget(task: task),
  progressBuilder: (context, task) => CustomProgressBar(task: task),
  actionsBuilder: (context, task) => [
    ElevatedButton(
      onPressed: () => handleTask(task),
      child: const Text('Custom Action'),
    ),
  ],
  margin: const EdgeInsets.all(8),
  padding: const EdgeInsets.all(12),
  showProgressPercentage: true,
  showFileSize: true,
  hideActions: false,
  dateFormat: 'yyyy-MM-dd HH:mm',
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withValues(alpha:0.2),
        blurRadius: 10,
        spreadRadius: 2,
      ),
    ],
  ),
)
```

## FileTaskList

A widget that displays a list of file tasks with filtering capabilities.

### FileTaskList Basic Usage example

```dart
FileTaskList(
  title: 'Downloads',
  showUploadTasks: false,
  showDownloadTasks: true,
  showEmptyMessage: true,
)
```

### FileTaskList Customized Example

```dart
FileTaskList(
  title: 'File Transfers',
  showUploadTasks: true,
  showDownloadTasks: true,
  itemBuilder: (context, task) => CustomTaskItem(task: task),
  headerListBuilder: (context, tasks) => Text('Total tasks: ${tasks.length}'),
  footerListBuilder: (context, tasks) => Text(
    'Total size: ${(tasks.fold<int>(0, (sum, task) => sum + task.totalBytes) / (1024 * 1024)).toStringAsFixed(2)} MB',
  ),
)
```

### FileTaskList with Custom Controller

```dart
// Create a shared controller for reuse
final sharedController = CachedFileController();

// Initialize the controller with specific options if needed
await sharedController.initialize(customOptions: true);

// Use in FileTaskList
FileTaskList(
  title: 'File Transfers',
  controller: sharedController,
  onTaskCompleted: (task) {
    // Handle task completion events
    logCompletedTask(task);
  },
  onTaskRemoved: (task) {
    // Handle task removal events
    updateTasksCounter();
  },
)
```

## FileUploadCard

A card widget that handles file uploads with progress indication.

### FileUploadCard Key Features

- Real-time progress tracking
- Error handling
- Task control capabilities
- Custom controller support
- Path-based file handling

### FileUploadCard Basic Usage

```dart
FileUploadCard(
  filePath: '/path/to/local/file.jpg',
  destinationPath: 'uploads/images/file.jpg',
  onUploaded: (url) => Text('File uploaded to: $url'),
  useStream: true,
)
```

### FileUploadCard Advanced Example

```dart
FileUploadCard(
  filePath: '/path/to/profile_image.jpg',
  destinationPath: 'users/$userId/profile.jpg',
  storagePath: 'profiles/$userId.jpg', // For Firebase Storage
  useStream: true,
  uploadingWidget: (context, progress) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          value: progress.progressPercentage / 100,
        ),
        const SizedBox(height: 16),
        Text(
          '${progress.progressPercentage.toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          '${progress.uploadedSizeMB.toStringAsFixed(1)} MB / ${progress.totalSizeMB.toStringAsFixed(1)} MB',
        ),
      ],
    ),
  ),
  onError: (error) => Text('Upload failed: $error'),
  placeholder: const Center(child: CircularProgressIndicator()),
)
```

### FileUploadCard Task-Controlled Upload

```dart
FileUploadCard(
  filePath: '/path/to/document.pdf',
  destinationPath: 'documents/$fileName',
  useTaskControl: true,
  autoStart: false,
  taskControlWidget: (context, task) => CustomUploadTaskWidget(task: task),
  onUploaded: (url) => saveUrlToDatabase(url),
)
```

### FileUploadCard with Custom Controller

```dart
// Create a controller that can be used across the app
final uploadController = CachedFileController();

// Later in your widget
FileUploadCard(
  filePath: '/path/to/document.pdf',
  destinationPath: 'documents/$fileName',
  controller: uploadController, // Use the shared controller
  autoInitializeController: true, // Auto-initialize the controller
  onTaskCompleted: (task) {
    // Handle completed upload
    saveFileReference(task.downloadUrl);
  },
  onTaskRemoved: (task) {
    // Clean up after task removal
    removeTemporaryFiles();
  },
)
```

## FileUploadProgressIndicator

A widget that displays upload progress information with a circular progress indicator and size details.

### FileUploadProgressIndicator Example Usage

```dart
StreamBuilder<UploadProgress>(
  stream: CachedFileController().streamUpload(filePath, destinationPath),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return FileUploadProgressIndicator(
        progress: snapshot.data!,
      );
    }
    return const CircularProgressIndicator();
  },
)
```

## MultiFileLoadingCard

A card widget that handles loading multiple files from URLs with combined progress indication.

### MultiFileLoadingCard Basic Usage

```dart
MultiFileLoadingCard(
  urls: {'https://example.com/file1.pdf', 'https://example.com/file2.jpg'}, // Set of URLs
  isSequential: true, // Download files one after another
  onLoaded: (files) => ListView.builder(
    itemCount: files.length,
    itemBuilder: (context, index) => FilePreview(file: files[index]),
  ),
)
```

### MultiFileLoadingCard Advanced Example

```dart
MultiFileLoadingCard(
  urls: fileUrls, // Set of URLs
  isSequential: false, // Download files in parallel
  downloadingWidget: (context, progress) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircularProgressIndicator(
        value: progress.overallProgressPercentage / 100,
      ),
      const SizedBox(height: 16),
      Text('Completed: ${progress.fileStatuses.where((s) => s.isComplete).length}/${progress.fileStatuses.length}'),
      Text('${(progress.totalBytesDownloaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'),
    ],
  ),
  onError: (error) => ErrorDisplay(message: error),
  placeholder: const LoadingIndicator(),
)
```

### MultiFileLoadingCard with Custom Controller and Callbacks

```dart
// Create a custom controller
final downloadController = CachedFileController();

// Configure download widget
MultiFileLoadingCard(
  urls: documentUrls, // Set of URLs
  controller: downloadController, // Use shared controller
  isSequential: true,
  onAllFilesLoaded: (files) {
    // All files have been downloaded
    processDocuments(files);
  },
  onFileLoaded: (file, index) {
    // Individual file completed
    updateProgressIndicator(index, documentUrls.length);
  },
)
```

## MultiFileUploadCard

A card widget that handles uploading multiple files with combined progress indication.

### MultiFileUploadCard Basic Usage

```dart
MultiFileUploadCard(
  filePaths: {'/path/to/file1.jpg', '/path/to/file2.pdf'}, // Set of file paths
  destinationPaths: {'uploads/images/file1.jpg', 'uploads/documents/file2.pdf'}, // Set of destination paths
  isSequential: true, // Upload files one after another
  onUploaded: (urls) => saveUrlsToDatabase(urls),
)
```

### MultiFileUploadCard Advanced Example

```dart
MultiFileUploadCard(
  filePaths: selectedFilePaths, // Set of file paths
  destinationPaths: selectedFilePaths.map((path) => 'users/$userId/files/${path.split('/').last}').toSet(), // Set of destination paths
  isSequential: false, // Upload files in parallel
  uploadingWidget: (context, progress) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircularProgressIndicator(
        value: progress.overallProgressPercentage / 100,
      ),
      const SizedBox(height: 16),
      Text('Completed: ${progress.fileStatuses.where((s) => s.isComplete).length}/${progress.fileStatuses.length}'),
      Text('${(progress.totalBytesUploaded / (1024 * 1024)).toStringAsFixed(1)} MB / ${(progress.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB'),
    ],
  ),
  onError: (error) => ErrorDisplay(message: error),
  placeholder: const LoadingIndicator(),
)
```

### MultiFileUploadCard with Custom Controller and Callbacks

```dart
// Create a shared controller
final uploadController = CachedFileController();

// Use in widget
MultiFileUploadCard(
  filePaths: photoFilePaths, // Set of file paths
  destinationPaths: photoDestinationPaths, // Set of destination paths
  controller: uploadController, // Use shared controller
  isSequential: false, // Upload in parallel
  onAllFilesUploaded: (downloadUrls) {
    // All files uploaded successfully
    saveGalleryUrls(downloadUrls);
  },
  onFileUploaded: (downloadUrl, index) {
    // Individual file uploaded
    updateUploadProgress(index, photoFilePaths.length);
    // Show preview of uploaded file
    showImagePreview(downloadUrl);
  },
)
```

## MultiUploadProgressIndicator

A widget that displays multiple file upload progress information with a circular progress indicator and size details.

### MultiUploadProgressIndicator Example Usage

```dart
StreamBuilder<MultiUploadProgress>(
  stream: CachedFileController().streamUploadParallel(filePaths, destinationPaths),
  builder: (context, snapshot) {
    if (snapshot.hasData) {
      return MultiUploadProgressIndicator(
        progress: snapshot.data!,
      );
    }
    return const CircularProgressIndicator();
  },
)
```

### MultiUploadProgressIndicator Example in Bottom Sheet

```dart
void showUploadProgress(BuildContext context, MultiUploadProgress progress) {
  showModalBottomSheet(
    context: context,
    builder: (context) => Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Uploading Files'),
          const SizedBox(height: 16),
          MultiUploadProgressIndicator(progress: progress),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hide'),
          ),
        ],
      ),
    ),
  );
}
```

## Architecture Notes

These widgets interact with the `CachedFileController` which manages file operations and caching. They use the following models from the repository:

- `DownloadProgress`: Tracks download progress for a single file
- `UploadProgress`: Tracks upload progress for a single file
- `MultiDownloadProgress`: Tracks download progress for multiple files
- `MultiUploadProgress`: Tracks upload progress for multiple files
- `FileTask`: Represents a file operation task with state information

The widgets are designed to be:

- **Reusable**: All widgets accept optional controllers for better resource management
- **Flexible**: Configure initialization, events, and UI aspects
- **Composable**: Can be customized extensively through builder functions
- **Efficient**: Share controllers to reduce redundant instantiations
- **Path-Based**: All file handling uses string paths rather than File objects for greater flexibility
