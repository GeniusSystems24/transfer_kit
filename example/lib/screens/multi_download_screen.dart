import 'dart:io';

import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';
import 'package:file_picker/file_picker.dart';

import 'sample_urls.dart';

/// Screen demonstrating multi-file download with progress list and batch management
class MultiDownloadScreen extends StatefulWidget {
  const MultiDownloadScreen({super.key});

  @override
  State<MultiDownloadScreen> createState() => _MultiDownloadScreenState();
}

class _MultiDownloadScreenState extends State<MultiDownloadScreen> {
  // Predefined downloadable resources using real URLs
  final List<DownloadableResource> _resources = [
    DownloadableResource(
      category: 'Images',
      items: [
        DownloadItem(
          name: 'Operation Image (Firebase)',
          url: SampleUrls.image,
          size: '245 KB',
          type: 'PNG',
        ),
        DownloadItem(
          name: 'Mountain Landscape',
          url: 'https://picsum.photos/seed/mountain/1920/1080',
          size: '~2.5 MB',
          type: 'JPEG',
        ),
        DownloadItem(
          name: 'City Skyline',
          url: 'https://picsum.photos/seed/citysky/1920/1080',
          size: '~2.1 MB',
          type: 'JPEG',
        ),
        DownloadItem(
          name: 'Ocean Waves',
          url: 'https://picsum.photos/seed/oceanwaves/1920/1080',
          size: '~1.8 MB',
          type: 'JPEG',
        ),
      ],
      icon: Icons.image,
      color: Colors.blue,
    ),
    DownloadableResource(
      category: 'Documents',
      items: [
        DownloadItem(
          name: 'Science Textbook (Firebase)',
          url: SampleUrls.pdf,
          size: '8.5 MB',
          type: 'PDF',
        ),
        DownloadItem(
          name: 'Sample PDF',
          url:
              'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
          size: '15 KB',
          type: 'PDF',
        ),
      ],
      icon: Icons.description,
      color: Colors.orange,
    ),
    DownloadableResource(
      category: 'Media',
      items: [
        DownloadItem(
          name: 'What Are Chatbots? (Firebase)',
          url: SampleUrls.video,
          size: '12.5 MB',
          type: 'MP4',
        ),
        DownloadItem(
          name: 'Voice Note (Firebase)',
          url: SampleUrls.audio,
          size: '256 KB',
          type: 'MP3',
        ),
      ],
      icon: Icons.video_library,
      color: Colors.red,
    ),
  ];

  final Set<DownloadItem> _selectedItems = {};
  final _urlController = TextEditingController();
  String _downloadKey = 'multi_download_1';
  final List<File> _downloadedFiles = [];
  bool _isSequential = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _toggleItem(DownloadItem item) {
    setState(() {
      if (_selectedItems.contains(item)) {
        _selectedItems.remove(item);
      } else {
        _selectedItems.add(item);
      }
    });
  }

  void _selectAll(DownloadableResource resource) {
    setState(() {
      _selectedItems.addAll(resource.items);
    });
  }

  void _deselectAll(DownloadableResource resource) {
    setState(() {
      _selectedItems.removeAll(resource.items);
    });
  }

  void _addCustomUrl() {
    if (_urlController.text.isNotEmpty) {
      final url = _urlController.text;
      final fileName = url.split('/').last.split('?').first;

      setState(() {
        // Add to first resource category or create custom
        _resources[0].items.add(DownloadItem(
              name: fileName.isEmpty ? 'Custom File' : fileName,
              url: url,
              size: 'Unknown',
              type: fileName.split('.').last.toUpperCase(),
            ));
        _selectedItems.add(_resources[0].items.last);
        _urlController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added: $fileName'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _importUrlsFromFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        final file = File(result.files.first.path!);
        final content = await file.readAsString();
        final urls = content
            .split('\n')
            .where((line) =>
                line.trim().isNotEmpty &&
                (line.startsWith('http://') || line.startsWith('https://')))
            .toList();

        if (urls.isNotEmpty) {
          int addedCount = 0;
          for (var url in urls) {
            final fileName = url.split('/').last.split('?').first;
            _resources[0].items.add(DownloadItem(
                  name: fileName.isEmpty ? 'File ${addedCount + 1}' : fileName,
                  url: url.trim(),
                  size: 'Unknown',
                  type: fileName.split('.').last.toUpperCase(),
                ));
            addedCount++;
          }

          setState(() {});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Imported $addedCount URLs'),
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
            content: Text('Error importing file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startDownload() {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select files to download'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _downloadKey = 'multi_download_${DateTime.now().millisecondsSinceEpoch}';
      _downloadedFiles.clear();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-File Download'),
        actions: [
          if (_selectedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear Selection',
              onPressed: _clearSelection,
            ),
          IconButton(
            icon: const Icon(Icons.play_arrow),
            tooltip: 'Start Download',
            onPressed: _selectedItems.isNotEmpty ? _startDownload : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats and Options
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats Row
                  Row(
                    children: [
                      _buildStatBadge(
                        context,
                        icon: Icons.check_circle_outline,
                        label: 'Selected',
                        value: '${_selectedItems.length}',
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildStatBadge(
                        context,
                        icon: Icons.folder,
                        label: 'Available',
                        value:
                            '${_resources.fold<int>(0, (sum, r) => sum + r.items.length)}',
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      _buildStatBadge(
                        context,
                        icon: Icons.download_done,
                        label: 'Downloaded',
                        value: '${_downloadedFiles.length}',
                        color: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Options
                  Row(
                    children: [
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('Sequential Download'),
                          subtitle: Text(
                            _isSequential ? 'One at a time' : 'Parallel',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          value: _isSequential,
                          onChanged: (value) =>
                              setState(() => _isSequential = value),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Custom URL Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: InputDecoration(
                            hintText: 'Add custom URL',
                            border: const OutlineInputBorder(),
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.folder),
                              tooltip: 'Import from file',
                              onPressed: _importUrlsFromFile,
                            ),
                          ),
                          onSubmitted: (_) => _addCustomUrl(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addCustomUrl,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Download Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _selectedItems.isNotEmpty ? _startDownload : null,
                      icon: const Icon(Icons.download),
                      label: Text('Download ${_selectedItems.length} Files'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Resource Categories & Download Progress
          Expanded(
            child: _selectedItems.isEmpty || _downloadedFiles.isNotEmpty
                ? _buildResourceList()
                : _buildDownloadProgress(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
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

  Widget _buildResourceList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _resources.length,
      itemBuilder: (context, index) {
        final resource = _resources[index];
        final selectedInCategory = resource.items
            .where((item) => _selectedItems.contains(item))
            .length;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: resource.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(resource.icon, color: resource.color),
            ),
            title: Text(
              resource.category,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${resource.items.length} items • $selectedInCategory selected',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedInCategory < resource.items.length)
                  TextButton(
                    onPressed: () => _selectAll(resource),
                    child: const Text('All'),
                  )
                else
                  TextButton(
                    onPressed: () => _deselectAll(resource),
                    child: const Text('None'),
                  ),
              ],
            ),
            children: resource.items.map((item) {
              final isSelected = _selectedItems.contains(item);
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? resource.color.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    resource.icon,
                    color: isSelected ? resource.color : Colors.grey,
                    size: 20,
                  ),
                ),
                title: Text(item.name),
                subtitle: Text('${item.type} • ${item.size}'),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleItem(item),
                  activeColor: resource.color,
                ),
                onTap: () => _toggleItem(item),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildDownloadProgress() {
    final urls = _selectedItems.map((item) => item.url).toSet();

    return MultiFileLoadingCard(
      key: ValueKey(_downloadKey),
      urls: urls,
      isSequential: _isSequential,
      onAllFilesLoaded: (files) {
        setState(() {
          _downloadedFiles.clear();
          _downloadedFiles.addAll(files);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All ${files.length} files downloaded!'),
            backgroundColor: Colors.green,
          ),
        );
      },
      onFileLoaded: (file, index) {
        debugPrint('File $index downloaded: ${file.path}');
      },
      onLoaded: (files) {
        return _buildDownloadedFilesGrid(files);
      },
      downloadingWidget: (context, progress) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Progress Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              value: progress.overallProgressPercentage / 100,
                              strokeWidth: 6,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          Text(
                            '${progress.overallProgressPercentage.toStringAsFixed(0)}%',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Downloading ${progress.fileStatuses.length} files',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${progress.fileStatuses.where((s) => s.isComplete).length} of ${progress.fileStatuses.length} complete',
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // File Progress List
              Expanded(
                child: ListView.builder(
                  itemCount: progress.fileStatuses.length,
                  itemBuilder: (context, index) {
                    final status = progress.fileStatuses[index];
                    final item = _selectedItems.elementAt(index);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: status.isComplete
                                ? Colors.green.withValues(alpha: 0.2)
                                : Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: status.isComplete
                              ? const Icon(Icons.check, color: Colors.green)
                              : Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    ),
                                  ),
                                ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: status.progressPercentage / 100,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        ),
                        trailing: Text(
                          status.isComplete
                              ? '✓'
                              : '${status.progressPercentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: status.isComplete
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      onError: (error) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startDownload,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadedFilesGrid(List<File> files) {
    return Column(
      children: [
        // Success Header
        Card(
          margin: const EdgeInsets.all(16),
          color: Colors.green.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download Complete!',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                      ),
                      Text(
                        '${files.length} files downloaded successfully',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _clearSelection,
                  child: const Text('New Download'),
                ),
              ],
            ),
          ),
        ),

        // Files Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              final ext = file.path.split('.').last.toLowerCase();
              final isImage =
                  ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);

              return Card(
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isImage)
                      Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFileIcon(ext),
                      )
                    else
                      _buildFileIcon(ext),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.black54,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'File ${index + 1}',
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileIcon(String ext) {
    IconData icon;
    Color color;

    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        color = Colors.blue;
        break;
      case 'mp3':
      case 'wav':
        icon = Icons.audiotrack;
        color = Colors.purple;
        break;
      case 'mp4':
      case 'mov':
        icon = Icons.video_file;
        color = Colors.red;
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Colors.grey;
    }

    return Container(
      color: color.withValues(alpha: 0.1),
      child: Center(
        child: Icon(icon, size: 48, color: color),
      ),
    );
  }
}

class DownloadableResource {
  final String category;
  final List<DownloadItem> items;
  final IconData icon;
  final Color color;

  DownloadableResource({
    required this.category,
    required this.items,
    required this.icon,
    required this.color,
  });
}

class DownloadItem {
  final String name;
  final String url;
  final String size;
  final String type;

  DownloadItem({
    required this.name,
    required this.url,
    required this.size,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadItem &&
          runtimeType == other.runtimeType &&
          url == other.url;

  @override
  int get hashCode => url.hashCode;
}
