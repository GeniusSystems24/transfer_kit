import 'dart:io';

import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'file_viewer_screen.dart';

/// Screen demonstrating multi-file upload functionality with real file picking
class MultiUploadScreen extends StatefulWidget {
  const MultiUploadScreen({super.key});

  @override
  State<MultiUploadScreen> createState() => _MultiUploadScreenState();
}

class _MultiUploadScreenState extends State<MultiUploadScreen>
    with TickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  final List<SelectedFile> _selectedFiles = [];
  bool _isUploading = false;
  double _overallProgress = 0;

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (images.isNotEmpty) {
        for (var image in images) {
          final file = File(image.path);
          final size = await file.length();

          setState(() {
            _selectedFiles.add(SelectedFile(
              name: image.name,
              path: image.path,
              size: size,
              type: UploadFileType.image,
              progress: 0,
              isComplete: false,
            ));
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${images.length} image(s) added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error picking images: $e');
    }
  }

  Future<void> _pickVideos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            setState(() {
              _selectedFiles.add(SelectedFile(
                name: file.name,
                path: file.path!,
                size: file.size,
                type: UploadFileType.video,
                progress: 0,
                isComplete: false,
              ));
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} video(s) added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error picking videos: $e');
    }
  }

  Future<void> _pickDocuments() async {
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
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            setState(() {
              _selectedFiles.add(SelectedFile(
                name: file.name,
                path: file.path!,
                size: file.size,
                type: UploadFileType.document,
                progress: 0,
                isComplete: false,
              ));
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} document(s) added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error picking documents: $e');
    }
  }

  Future<void> _pickAnyFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            final ext = file.extension?.toLowerCase() ?? '';
            UploadFileType type;

            if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
              type = UploadFileType.image;
            } else if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) {
              type = UploadFileType.video;
            } else if (['mp3', 'wav', 'aac', 'flac'].contains(ext)) {
              type = UploadFileType.audio;
            } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx']
                .contains(ext)) {
              type = UploadFileType.document;
            } else {
              type = UploadFileType.other;
            }

            setState(() {
              _selectedFiles.add(SelectedFile(
                name: file.name,
                path: file.path!,
                size: file.size,
                type: type,
                progress: 0,
                isComplete: false,
              ));
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} file(s) added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error picking files: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        final file = File(photo.path);
        final size = await file.length();

        setState(() {
          _selectedFiles.add(SelectedFile(
            name:
                'Photo_${DateTime.now().toIso8601String().replaceAll(':', '-')}.jpg',
            path: photo.path,
            size: size,
            type: UploadFileType.image,
            progress: 0,
            isComplete: false,
          ));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error capturing photo: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _startUpload() {
    if (_selectedFiles.isEmpty) {
      _showError('No files selected');
      return;
    }

    setState(() {
      _isUploading = true;
      for (var file in _selectedFiles) {
        file.progress = 0;
        file.isComplete = false;
      }
    });

    // Simulate uploads with different speeds
    for (int i = 0; i < _selectedFiles.length; i++) {
      _simulateFileUpload(i, Duration(milliseconds: 1000 + (i * 500)));
    }
  }

  void _simulateFileUpload(int index, Duration duration) async {
    final steps = 20;
    final stepDuration = duration ~/ steps;

    for (int step = 1; step <= steps; step++) {
      await Future.delayed(stepDuration);
      if (!mounted) return;
      setState(() {
        _selectedFiles[index].progress = step / steps;
        if (step == steps) {
          _selectedFiles[index].isComplete = true;
        }

        // Calculate overall progress
        _overallProgress =
            _selectedFiles.map((f) => f.progress).reduce((a, b) => a + b) /
                _selectedFiles.length;

        // Check if all complete
        if (_selectedFiles.every((f) => f.isComplete)) {
          _isUploading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All files uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
      if (_selectedFiles.isEmpty) {
        _overallProgress = 0;
      } else {
        _overallProgress =
            _selectedFiles.map((f) => f.progress).reduce((a, b) => a + b) /
                _selectedFiles.length;
      }
    });
  }

  void _clearAll() {
    setState(() {
      _selectedFiles.clear();
      _isUploading = false;
      _overallProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _selectedFiles.where((f) => f.isComplete).length;
    final allComplete =
        _selectedFiles.isNotEmpty && _selectedFiles.every((f) => f.isComplete);
    final totalSize = _selectedFiles.fold<int>(0, (sum, f) => sum + f.size);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-File Upload'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear All',
              onPressed: _isUploading ? null : _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Header Stats Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildStatCard(
                        context,
                        icon: Icons.file_copy,
                        label: 'Files',
                        value: '${_selectedFiles.length}',
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        context,
                        icon: Icons.storage,
                        label: 'Total Size',
                        value: FileUtils.formatSize(totalSize),
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        context,
                        icon: Icons.check_circle,
                        label: 'Uploaded',
                        value: '$completedCount',
                        color: Colors.green,
                      ),
                    ],
                  ),
                  if (_selectedFiles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: _overallProgress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        allComplete
                            ? Colors.green
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      allComplete
                          ? 'All files uploaded!'
                          : _isUploading
                              ? 'Uploading... ${(_overallProgress * 100).toStringAsFixed(0)}%'
                              : 'Ready to upload',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: allComplete ? Colors.green : null,
                            fontWeight: allComplete ? FontWeight.bold : null,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // File Picker Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPickerChip(
                    context,
                    icon: Icons.photo_library,
                    label: 'Images',
                    onTap: _isUploading ? null : _pickImages,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildPickerChip(
                    context,
                    icon: Icons.videocam,
                    label: 'Videos',
                    onTap: _isUploading ? null : _pickVideos,
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _buildPickerChip(
                    context,
                    icon: Icons.description,
                    label: 'Documents',
                    onTap: _isUploading ? null : _pickDocuments,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildPickerChip(
                    context,
                    icon: Icons.folder,
                    label: 'Any Files',
                    onTap: _isUploading ? null : _pickAnyFiles,
                    color: Colors.purple,
                  ),
                  const SizedBox(width: 8),
                  _buildPickerChip(
                    context,
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: _isUploading ? null : _takePhoto,
                    color: Colors.teal,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // File List
          Expanded(
            child: _selectedFiles.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedFiles.length,
                    itemBuilder: (context, index) {
                      final file = _selectedFiles[index];
                      return _buildFileCard(context, file, index);
                    },
                  ),
          ),

          // Upload Button
          if (_selectedFiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isUploading || allComplete ? null : _startUpload,
                  icon: Icon(allComplete ? Icons.check : Icons.cloud_upload),
                  label: Text(
                    allComplete
                        ? 'Upload Complete'
                        : _isUploading
                            ? 'Uploading...'
                            : 'Upload ${_selectedFiles.length} Files',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: allComplete ? Colors.green : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: onTap == null ? Colors.grey : color),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: onTap == null ? null : color.withValues(alpha: 0.1),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'No Files Selected',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the buttons above to select files',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick Images'),
              ),
              OutlinedButton.icon(
                onPressed: _pickAnyFiles,
                icon: const Icon(Icons.folder),
                label: const Text('Browse Files'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(BuildContext context, SelectedFile file, int index) {
    final color = _getFileTypeColor(file.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          String? mime;
          switch (file.type) {
            case UploadFileType.video:
              mime = 'video/mp4';
              break;
            case UploadFileType.audio:
              mime = 'audio/mpeg';
              break;
            case UploadFileType.image:
              mime = 'image/jpeg';
              break;
            case UploadFileType.document:
              mime = 'application/pdf';
              break;
            default:
              mime = null;
          }
          FileViewer.openFile(context, file.path, mimeType: mime);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // File Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: file.isComplete
                      ? Colors.green.withValues(alpha: 0.1)
                      : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  file.isComplete ? Icons.check : _getFileTypeIcon(file.type),
                  color: file.isComplete ? Colors.green : color,
                ),
              ),
              const SizedBox(width: 12),

              // File Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          FileUtils.formatSize(file.size),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            file.type.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_isUploading || file.progress > 0) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: file.progress,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          file.isComplete ? Colors.green : color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Progress/Remove
              SizedBox(
                width: 48,
                child: file.isComplete
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : _isUploading
                        ? Text(
                            '${(file.progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeFile(index),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileTypeIcon(UploadFileType type) {
    switch (type) {
      case UploadFileType.image:
        return Icons.image;
      case UploadFileType.video:
        return Icons.video_file;
      case UploadFileType.audio:
        return Icons.audiotrack;
      case UploadFileType.document:
        return Icons.description;
      case UploadFileType.other:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileTypeColor(UploadFileType type) {
    switch (type) {
      case UploadFileType.image:
        return Colors.blue;
      case UploadFileType.video:
        return Colors.red;
      case UploadFileType.audio:
        return Colors.purple;
      case UploadFileType.document:
        return Colors.orange;
      case UploadFileType.other:
        return Colors.grey;
    }
  }
}

enum UploadFileType { image, video, audio, document, other }

class SelectedFile {
  final String name;
  final String path;
  final int size;
  final UploadFileType type;
  double progress;
  bool isComplete;

  SelectedFile({
    required this.name,
    required this.path,
    required this.size,
    required this.type,
    required this.progress,
    required this.isComplete,
  });
}
