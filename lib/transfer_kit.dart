/// A comprehensive file management solution for Flutter with Firebase Storage.
///
/// This package provides:
/// - File upload/download with progress tracking
/// - Intelligent file caching
/// - Task management (pause, resume, cancel, retry)
/// - Batch operations for multiple files
/// - Beautiful pre-built UI widgets
/// - Background transfer support
///
/// ## Getting Started
///
/// ```dart
/// import 'package:transfer_kit/transfer_kit.dart';
///
/// // Initialize app directories (required)
/// await FilePathExtension.initAppDirectory();
///
/// // Get the file manager
/// final fileManager = FileManagementSystem();
///
/// // Download a file
/// final task = await fileManager.downloadTask(
///   filePathAndUrl: FilePathAndURL.url(url: 'https://example.com/file.pdf'),
///   taskId: 'download_001',
/// );
/// ```
library;

// Get Storage
export 'package:get_storage/get_storage.dart';

// Core extensions
export 'src/core/extension/file_path_extension.dart';
export 'src/core/extension/num_extension.dart';
export 'src/core/extension/string_extension.dart';
export 'src/core/extension/map_extension.dart';
export 'src/core/extension/date_time_extension.dart';
export 'src/core/extension/dynamic_extension.dart';
export 'src/core/extension/geo_point_extension.dart';
export 'src/core/extension/list_extension.dart';

// Core utilities
export 'src/core/file_management_config.dart';
export 'src/core/get_storage_repository.dart';
export 'src/core/get_storage_value_notifier.dart';
export 'src/core/utils/file_utils.dart';

// Models
export 'src/model/file_model.dart';
export 'src/model/file_task.dart';
export 'src/model/file_path_and_url.dart';
export 'src/model/file_task_extensions.dart';
export 'src/model/multi_upload_file_task.dart';
export 'src/model/multi_download_file_task.dart';
export 'src/model/file_exception.dart';
export 'src/model/media_metadata.dart';

// Main controller
export 'src/transfer_kit.dart';

// Repositories
export 'src/repository/file_task_repository.dart';
export 'src/repository/file_path_and_url_repository.dart';
export 'src/repository/background_task_repository.dart';

// Services
export 'src/service/task_management_service.dart';
export 'src/service/background_transfer_service.dart';
export 'src/service/metadata_extraction_service.dart';

// Widgets
export 'src/widget/file_loading_card.dart';
export 'src/widget/file_upload_card.dart';
export 'src/widget/file_task_item.dart';
export 'src/widget/file_task_card.dart';
export 'src/widget/file_task_tile.dart';
export 'src/widget/file_task_list.dart';
export 'src/widget/multi_file_loading_card.dart';
export 'src/widget/multi_file_upload_card.dart';
export 'src/widget/multi_upload_progress_list_view.dart';
export 'src/widget/multi_upload_progress_indicator.dart';
export 'src/widget/file_download_progress_list_view.dart';
export 'src/widget/file_download_progress_indicator.dart';
export 'src/widget/file_upload_progress_indicator.dart';
export 'src/widget/download_file_widget.dart';

// Media Widgets (download image/video/document with progress)
export 'src/media_widgets/media_widgets.dart';


