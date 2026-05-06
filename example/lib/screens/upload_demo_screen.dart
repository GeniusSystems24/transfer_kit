import 'dart:io';

import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// Screen demonstrating file upload functionality with real file picking
class UploadDemoScreen extends StatefulWidget {
  const UploadDemoScreen({super.key});

  @override
  State<UploadDemoScreen> createState() => _UploadDemoScreenState();
}

class _UploadDemoScreenState extends State<UploadDemoScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedFile;
  String? _fileName;
  int _fileSize = 0;
  String _fileType = '';

  double _progress = 0;
  bool _isUploading = false;
  bool _isComplete = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _controller.addListener(() {
      setState(() {
        _progress = _controller.value;
        if (_progress >= 1.0) {
          _isComplete = true;
          _isUploading = false;
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final size = await file.length();

        setState(() {
          _selectedFile = file;
          _fileName = image.name;
          _fileSize = size;
          _fileType = 'Image';
          _resetProgress();
        });
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        final file = File(photo.path);
        final size = await file.length();

        setState(() {
          _selectedFile = file;
          _fileName =
              'Photo_${DateTime.now().toIso8601String().replaceAll(':', '-')}.jpg';
          _fileSize = size;
          _fileType = 'Photo';
          _resetProgress();
        });
      }
    } catch (e) {
      _showError('Error capturing photo: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video =
          await _imagePicker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        final file = File(video.path);
        final size = await file.length();

        setState(() {
          _selectedFile = file;
          _fileName = video.name;
          _fileSize = size;
          _fileType = 'Video';
          _resetProgress();
        });
      }
    } catch (e) {
      _showError('Error picking video: $e');
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt'
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _selectedFile = File(file.path!);
            _fileName = file.name;
            _fileSize = file.size;
            _fileType = 'Document';
            _resetProgress();
          });
        }
      }
    } catch (e) {
      _showError('Error picking document: $e');
    }
  }

  Future<void> _pickAnyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          final ext = file.extension?.toLowerCase() ?? '';
          String type;

          if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
            type = 'Image';
          } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
            type = 'Video';
          } else if (['mp3', 'wav', 'aac', 'flac'].contains(ext)) {
            type = 'Audio';
          } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx']
              .contains(ext)) {
            type = 'Document';
          } else {
            type = 'File';
          }

          setState(() {
            _selectedFile = File(file.path!);
            _fileName = file.name;
            _fileSize = file.size;
            _fileType = type;
            _resetProgress();
          });
        }
      }
    } catch (e) {
      _showError('Error picking file: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _resetProgress() {
    _isUploading = false;
    _isComplete = false;
    _progress = 0;
    _controller.reset();
  }

  void _startUpload() {
    if (_selectedFile == null) {
      _showError('Please select a file first');
      return;
    }

    setState(() {
      _isUploading = true;
      _isComplete = false;
      _progress = 0;
    });
    _controller.forward(from: 0);
  }

  void _resetUpload() {
    setState(() {
      _isUploading = false;
      _isComplete = false;
      _progress = 0;
      _selectedFile = null;
      _fileName = null;
      _fileSize = 0;
      _fileType = '';
    });
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Demo'),
        actions: [
          if (_selectedFile != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear Selection',
              onPressed: _resetUpload,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // File Selection Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _selectedFile != null
                        ? _getFileTypeIcon(_fileType)
                        : Icons.cloud_upload_outlined,
                    size: 64,
                    color: _isComplete
                        ? Colors.green
                        : Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.7),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedFile != null
                        ? _fileName ?? 'Selected File'
                        : 'Select a File to Upload',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (_selectedFile != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getFileTypeColor(_fileType)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _fileType,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _getFileTypeColor(_fileType),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          FileUtils.formatSize(_fileSize),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ] else
                    Text(
                      'Choose from gallery, camera, or files',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // File Picker Buttons
          Text(
            'Select File',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPickerButton(
                icon: Icons.photo_library,
                label: 'Image',
                color: Colors.blue,
                onTap: _isUploading ? null : _pickImage,
              ),
              _buildPickerButton(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: Colors.green,
                onTap: _isUploading ? null : _takePhoto,
              ),
              _buildPickerButton(
                icon: Icons.video_library,
                label: 'Video',
                color: Colors.red,
                onTap: _isUploading ? null : _pickVideo,
              ),
              _buildPickerButton(
                icon: Icons.description,
                label: 'Document',
                color: Colors.orange,
                onTap: _isUploading ? null : _pickDocument,
              ),
              _buildPickerButton(
                icon: Icons.folder,
                label: 'Any File',
                color: Colors.purple,
                onTap: _isUploading ? null : _pickAnyFile,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Upload Progress Section
          if (_selectedFile != null) ...[
            Text(
              'Upload Progress',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isComplete
                              ? Icons.check_circle
                              : _isUploading
                                  ? Icons.cloud_upload
                                  : Icons.cloud_upload_outlined,
                          color: _isComplete
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isComplete
                                    ? 'Upload Complete!'
                                    : _isUploading
                                        ? 'Uploading...'
                                        : 'Ready to Upload',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _isComplete
                                    ? 'File uploaded successfully'
                                    : _isUploading
                                        ? '${(_progress * 100).toStringAsFixed(0)}% complete'
                                        : 'Tap Upload to start',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(_progress * 100).toStringAsFixed(0)}%',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _isComplete
                                        ? Colors.green
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isComplete
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_isComplete || _isUploading)
                          TextButton(
                            onPressed: _isUploading ? null : _resetProgress,
                            child: const Text('Reset'),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isUploading ? null : _startUpload,
                          icon:
                              Icon(_isComplete ? Icons.refresh : Icons.upload),
                          label: Text(
                              _isComplete ? 'Upload Again' : 'Start Upload'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Firebase Configuration Note
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Firebase Upload (Real)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To perform real uploads, configure Firebase Storage:\n'
                    '1. Set up Firebase project\n'
                    '2. Initialize FirebaseFileHandler\n'
                    '3. Use FileUploadCard or uploadTask API',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Code Examples
          Text(
            'Usage Examples',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          _buildCodeCard(
            context,
            title: 'Pick Image with image_picker',
            icon: Icons.image,
            code: '''// Pick image from gallery
final XFile? image = await ImagePicker().pickImage(
  source: ImageSource.gallery,
  imageQuality: 85,
);

// Capture from camera
final XFile? photo = await ImagePicker().pickImage(
  source: ImageSource.camera,
);

if (image != null) {
  final file = File(image.path);
  // Upload file...
}''',
          ),
          const SizedBox(height: 12),

          _buildCodeCard(
            context,
            title: 'Pick Files with file_picker',
            icon: Icons.folder,
            code: '''// Pick any file
final result = await FilePicker.platform.pickFiles();

// Pick specific types
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['pdf', 'doc', 'docx'],
  allowMultiple: true,
);

if (result != null) {
  for (var file in result.files) {
    print('File: \${file.name}, Size: \${file.size}');
  }
}''',
          ),
          const SizedBox(height: 12),

          _buildCodeCard(
            context,
            title: 'Upload to Firebase',
            icon: Icons.cloud_upload,
            code: '''// Using FileUploadCard widget
FileUploadCard(
  filePath: selectedFile.path,
  destinationPath: 'uploads/\${fileName}',
  useStream: true,
  onUploaded: (task) {
    final url = task.downloadUrl;
    return Text('Uploaded: \$url');
  },
)

// Using TransferKit API
final controller = TransferKit.instance;
controller.uploadTaskStream(
  filePathAndUrl: FilePathAndURL.local(
    path: localFilePath,
    destinationPath: 'uploads/\${fileName}',
  ),
).listen((task) {
  print('Progress: \${task.progressPercentage}%');
});''',
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
      ),
    );
  }

  Widget _buildCodeCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String code,
  }) {
    return Card(
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileTypeIcon(String type) {
    switch (type) {
      case 'Image':
      case 'Photo':
        return Icons.image;
      case 'Video':
        return Icons.video_file;
      case 'Audio':
        return Icons.audiotrack;
      case 'Document':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor(String type) {
    switch (type) {
      case 'Image':
      case 'Photo':
        return Colors.blue;
      case 'Video':
        return Colors.red;
      case 'Audio':
        return Colors.purple;
      case 'Document':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
