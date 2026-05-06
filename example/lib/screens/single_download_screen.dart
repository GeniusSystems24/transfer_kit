import 'dart:io';

import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';
import 'package:file_picker/file_picker.dart';

import 'sample_urls.dart';

/// Screen demonstrating single file download with various options and file picking
class SingleDownloadScreen extends StatefulWidget {
  const SingleDownloadScreen({super.key});

  @override
  State<SingleDownloadScreen> createState() => _SingleDownloadScreenState();
}

class _SingleDownloadScreenState extends State<SingleDownloadScreen> {
  final _urlController = TextEditingController();

  bool _useStream = true;
  bool _checkCache = true;
  bool _useTaskControl = false;
  String _downloadKey = 'download_1';

  // Predefined file categories with real sample URLs
  final List<FileCategory> _categories = [
    FileCategory(
      name: 'Images',
      icon: Icons.image,
      color: Colors.blue,
      files: [
        SampleFile(
          name: 'Operation Image',
          url: SampleUrls.image,
          size: '245 KB',
          type: 'PNG',
        ),
        SampleFile(
          name: 'Landscape Photo',
          url: 'https://picsum.photos/seed/landscape/1920/1080',
          size: '~2.5 MB',
          type: 'JPEG',
        ),
        SampleFile(
          name: 'Nature Photography',
          url: 'https://picsum.photos/seed/nature/1920/1080',
          size: '~3.1 MB',
          type: 'JPEG',
        ),
      ],
    ),
    FileCategory(
      name: 'Documents',
      icon: Icons.description,
      color: Colors.orange,
      files: [
        SampleFile(
          name: 'Science Textbook - Grade 1',
          url: SampleUrls.pdf,
          size: '8.5 MB',
          type: 'PDF',
        ),
        SampleFile(
          name: 'Sample PDF',
          url:
              'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          size: '15 KB',
          type: 'PDF',
        ),
      ],
    ),
    FileCategory(
      name: 'Audio',
      icon: Icons.audiotrack,
      color: Colors.purple,
      files: [
        SampleFile(
          name: 'Voice Note - WhatsApp',
          url: SampleUrls.audio,
          size: '256 KB',
          type: 'MP3',
        ),
      ],
    ),
    FileCategory(
      name: 'Videos',
      icon: Icons.video_library,
      color: Colors.red,
      files: [
        SampleFile(
          name: 'What Are Chatbots?',
          url: SampleUrls.video,
          size: '12.5 MB',
          type: 'MP4',
        ),
      ],
    ),
  ];

  int _selectedCategoryIndex = 0;
  SampleFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    // Set initial file
    if (_categories.isNotEmpty && _categories[0].files.isNotEmpty) {
      _selectedFile = _categories[0].files[0];
      _urlController.text = _selectedFile!.url;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _refreshDownload() {
    setState(() {
      _downloadKey = 'download_${DateTime.now().millisecondsSinceEpoch}';
    });
  }

  Future<void> _pickLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path != null) {
          setState(() {
            _urlController.text = file.path!;
            _selectedFile = SampleFile(
              name: file.name,
              url: file.path!,
              size: FileUtils.formatSize(file.size),
              type: file.extension?.toUpperCase() ?? 'FILE',
            );
          });
          _refreshDownload();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected: ${file.name}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCategory = _categories[_selectedCategoryIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Single File Download'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Pick Local File',
            onPressed: _pickLocalFile,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Download',
            onPressed: _refreshDownload,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Category Selector
          Text(
            'Select Category',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = index == _selectedCategoryIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
                      if (category.files.isNotEmpty) {
                        _selectedFile = category.files[0];
                        _urlController.text = _selectedFile!.url;
                        _refreshDownload();
                      }
                    });
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? category.color.withValues(alpha: 0.2)
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: category.color, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          color: isSelected
                              ? category.color
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? category.color
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // Files in Category
          Text(
            'Select File',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...currentCategory.files.map((file) {
            final isSelected = _selectedFile == file;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isSelected
                  ? currentCategory.color.withValues(alpha: 0.1)
                  : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: isSelected
                    ? BorderSide(color: currentCategory.color, width: 2)
                    : BorderSide.none,
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: currentCategory.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    currentCategory.icon,
                    color: currentCategory.color,
                  ),
                ),
                title: Text(
                  file.name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${file.type} • ${file.size}'),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: currentCategory.color)
                    : const Icon(Icons.radio_button_off),
                onTap: () {
                  setState(() {
                    _selectedFile = file;
                    _urlController.text = file.url;
                    _refreshDownload();
                  });
                },
              ),
            );
          }),
          const SizedBox(height: 16),

          // Custom URL Input Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.link,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Custom URL',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'File URL or Path',
                      hintText: 'https://example.com/file.jpg',
                      border: const OutlineInputBorder(),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.folder),
                            onPressed: _pickLocalFile,
                            tooltip: 'Browse Files',
                          ),
                          IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => _urlController.clear(),
                            tooltip: 'Clear',
                          ),
                        ],
                      ),
                    ),
                    onSubmitted: (_) => _refreshDownload(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _refreshDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('Start Download'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Options Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.settings,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Download Options',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Use Stream'),
                    subtitle: const Text('Real-time progress updates'),
                    value: _useStream,
                    onChanged: (value) => setState(() => _useStream = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Check Cache First'),
                    subtitle: const Text('Skip download if file exists'),
                    value: _checkCache,
                    onChanged: (value) => setState(() => _checkCache = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    title: const Text('Use Task Control'),
                    subtitle: const Text('Show pause/resume controls'),
                    value: _useTaskControl,
                    onChanged: (value) =>
                        setState(() => _useTaskControl = value),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Preview Card
          Text(
            'File Preview',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 300,
              child: _urlController.text.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_download,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Enter a URL to preview',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : FileLoadingCard(
                      key: ValueKey(_downloadKey),
                      url: _urlController.text,
                      useStream: _useStream,
                      checkCacheFirst: _checkCache,
                      useTaskControl: _useTaskControl,
                      onLoaded: (task) {
                        final filePath = task.filePath;
                        if (filePath.isNotEmpty) {
                          // Check if it's an image
                          final ext = filePath.split('.').last.toLowerCase();
                          final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp']
                              .contains(ext);

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              if (isImage)
                                Image.file(
                                  File(filePath),
                                  fit: BoxFit.cover,
                                )
                              else
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getFileIcon(ext),
                                        size: 64,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        task.fileName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Download Complete',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        task.fileName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(color: Colors.white70),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        return const Center(child: Text('File downloaded'));
                      },
                      onError: (error) => _buildErrorWidget(error),
                      onTaskCompleted: (task) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Downloaded: ${task.fileName}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Code Example
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.code,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Usage Example',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      '''// Download from real Firebase URL
FileLoadingCard(
  url: '${SampleUrls.image}',
  useStream: true,
  checkCacheFirst: true,
  useTaskControl: true,
  onLoaded: (task) {
    return YourWidget(filePath: task.filePath!);
  },
  onTaskCompleted: (task) {
    print('Downloaded: \${task.fileName}');
  },
)''',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'mp3':
      case 'wav':
      case 'aac':
        return Icons.audiotrack;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Download Failed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshDownload,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class FileCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<SampleFile> files;

  FileCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.files,
  });
}

class SampleFile {
  final String name;
  final String url;
  final String size;
  final String type;

  SampleFile({
    required this.name,
    required this.url,
    required this.size,
    required this.type,
  });
}
