import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';

import 'sample_urls.dart';
import 'file_viewer_screen.dart';

/// Screen demonstrating media-specific widgets with live demos
class MediaWidgetsScreen extends StatefulWidget {
  const MediaWidgetsScreen({super.key});

  @override
  State<MediaWidgetsScreen> createState() => _MediaWidgetsScreenState();
}

class _MediaWidgetsScreenState extends State<MediaWidgetsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Media Widgets'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Images', icon: Icon(Icons.image)),
            Tab(text: 'Videos', icon: Icon(Icons.video_library)),
            Tab(text: 'Slider', icon: Icon(Icons.view_carousel)),
            Tab(text: 'Documents', icon: Icon(Icons.description)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ImageWidgetsDemo(),
          _VideoWidgetsDemo(),
          _SliderWidgetsDemo(),
          _DocumentWidgetsDemo(),
        ],
      ),
    );
  }
}

/// Demo for DownloadImageWidget
class _ImageWidgetsDemo extends StatelessWidget {
  const _ImageWidgetsDemo();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info Card
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.image,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DownloadImageWidget',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Automatically downloads and caches images with progress indicator. '
                  'Tap any image to open full-screen viewer with zoom.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Live Image Grid
        Text(
          'Live Examples (Real Firebase Images)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: SampleUrls.images.length,
          itemBuilder: (context, index) {
            return Card(
              clipBehavior: Clip.antiAlias,
              child: DownloadImageWidget(
                file: FileModel.remote(url: SampleUrls.images[index]),
                autoStart: true,
                fit: BoxFit.cover,
                showActionButton: true,
                heroTag: 'image_$index',
                onTap: (context, filePath) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Image path: $filePath')),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Code Example
        _buildCodeExample(
          context,
          title: 'Usage',
          code: '''DownloadImageWidget(
  file: FileModel.remote(
    url: '${SampleUrls.image}',
  ),
  autoStart: true,
  fit: BoxFit.cover,
  heroTag: 'image_1',
  onTap: (context, filePath) {
    // File downloaded at filePath
  },
)''',
        ),
      ],
    );
  }
}

/// Demo for DownloadVideoWidget
class _VideoWidgetsDemo extends StatelessWidget {
  const _VideoWidgetsDemo();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info Card
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
                      Icons.video_library,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DownloadVideoWidget',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                  'Downloads video with progress and displays thumbnail preview. '
                  'Shows duration badge and play button overlay.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Live Video Demo
        Text(
          'Live Example (Real Firebase Video)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: DownloadVideoWidget(
            file: FileModel.remote(
              url: SampleUrls.video,
              durationInSeconds: 65,
              size: 12500000,
            ),
            keyController: 'video_demo_1',
            autoStart: false,
            onTap: (context, filePath) {
              _showVideoInfo(context, filePath);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Multiple Videos Grid
        Text(
          'Multiple Videos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 16 / 9,
          children: List.generate(4, (index) {
            return Card(
              clipBehavior: Clip.antiAlias,
              child: DownloadVideoWidget(
                file: FileModel.remote(
                  url: SampleUrls.video,
                  durationInSeconds: 65 + (index * 30),
                  size: 12500000 + (index * 1000000),
                ),
                keyController: 'video_grid_$index',
                autoStart: false,
                onTap: (context, filePath) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Video ${index + 1}: $filePath')),
                  );
                },
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // Code Example
        _buildCodeExample(
          context,
          title: 'Usage',
          code: '''DownloadVideoWidget(
  file: FileModel.remote(
    url: '${SampleUrls.video}',
    durationInSeconds: 65,
    size: 12500000,
  ),
  keyController: 'video_1',
  autoStart: true,
  onTap: (context, filePath) {
    // Play video from filePath
  },
)''',
        ),
      ],
    );
  }

  void _showVideoInfo(BuildContext context, String filePath) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Video Downloaded',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('File Path'),
              subtitle: Text(
                filePath,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Action'),
              subtitle: const Text('Tap to play video'),
              trailing: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  FileViewer.openFile(context, filePath, mimeType: 'video/mp4');
                },
                child: const Text('Play'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Demo for DownloadImageSliderWidget
class _SliderWidgetsDemo extends StatelessWidget {
  const _SliderWidgetsDemo();

  @override
  Widget build(BuildContext context) {
    // Use real images for slider
    final sliderImages = SampleUrls.images
        .map((url) => FileModel.remote(url: url, width: 1200, height: 800))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info Card
        Card(
          color: Theme.of(context).colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.view_carousel,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DownloadImageSliderWidget',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onTertiaryContainer,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Displays multiple images in a carousel with download support for each image. '
                  'Includes auto-play, indicators, and smooth transitions.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onTertiaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Live Slider Demo
        Text(
          'Live Example (Auto-play)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: DownloadImageSliderWidget(
            imageFiles: sliderImages,
            autoStart: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 3),
            defaultAspectRatio: 16 / 9,
            radius: 12,
            onImageTap: (file) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tapped: ${file.url}')),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Static Slider Demo
        Text(
          'Manual Navigation',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: DownloadImageSliderWidget(
            imageFiles: sliderImages.reversed.toList(),
            autoStart: true,
            autoPlay: false,
            defaultAspectRatio: 4 / 3,
            radius: 12,
          ),
        ),
        const SizedBox(height: 24),

        // Code Example
        _buildCodeExample(
          context,
          title: 'Usage',
          code: '''DownloadImageSliderWidget(
  imageFiles: [
    FileModel.remote(url: '${SampleUrls.image}'),
    FileModel.remote(url: 'https://example.com/2.jpg'),
    FileModel.remote(url: 'https://example.com/3.jpg'),
  ],
  autoStart: true,
  autoPlay: true,
  autoPlayInterval: Duration(seconds: 4),
  defaultAspectRatio: 16 / 9,
  onImageTap: (file) {
    // Handle image tap
  },
)''',
        ),
      ],
    );
  }
}

/// Demo for DocumentDownloadCard
class _DocumentWidgetsDemo extends StatefulWidget {
  const _DocumentWidgetsDemo();

  @override
  State<_DocumentWidgetsDemo> createState() => _DocumentWidgetsDemoState();
}

class _DocumentWidgetsDemoState extends State<_DocumentWidgetsDemo> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info Card
        Card(
          color: Theme.of(context)
              .colorScheme
              .errorContainer
              .withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Document & Audio Downloads',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Download various file types with progress indicator. '
                  'Supports pause, resume, cancel, and retry operations.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // PDF Document
        Text(
          'PDF Document (Real Firebase)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          context,
          name: 'Science Textbook - Grade 1',
          url: SampleUrls.pdf,
          size: 8500000,
          type: 'PDF',
          icon: Icons.picture_as_pdf,
          color: Colors.red,
        ),
        const SizedBox(height: 16),

        // Audio File
        Text(
          'Audio File (Real Firebase)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _buildDocumentCard(
          context,
          name: 'Voice Note - WhatsApp',
          url: SampleUrls.audio,
          size: 256000,
          type: 'MP3',
          icon: Icons.audiotrack,
          color: Colors.purple,
        ),
        const SizedBox(height: 24),

        // All files list
        Text(
          'All Sample Files',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...SampleUrls.allFiles.map((file) {
          IconData icon;
          Color color;
          switch (file['type']) {
            case 'Image':
              icon = Icons.image;
              color = Colors.blue;
              break;
            case 'Video':
              icon = Icons.video_file;
              color = Colors.red;
              break;
            case 'PDF':
              icon = Icons.picture_as_pdf;
              color = Colors.orange;
              break;
            case 'Audio':
              icon = Icons.audiotrack;
              color = Colors.purple;
              break;
            default:
              icon = Icons.insert_drive_file;
              color = Colors.grey;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDocumentCard(
              context,
              name: file['name'] as String,
              url: file['url'] as String,
              size: file['size'] as int,
              type: file['type'] as String,
              icon: icon,
              color: color,
            ),
          );
        }),
        const SizedBox(height: 24),

        // FileTaskController Info
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
                      Icons.lightbulb,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FileTaskController',
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
                  'All media widgets use FileTaskController internally for:\n'
                  '• Task queue management\n'
                  '• Download progress tracking\n'
                  '• Pause/Resume/Cancel operations\n'
                  '• Automatic retry on failure\n'
                  '• Memory-efficient caching',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Code Example
        _buildCodeExample(
          context,
          title: 'Usage with FileLoadingCard',
          code: '''FileLoadingCard(
  url: '${SampleUrls.pdf}',
  useStream: true,
  checkCacheFirst: true,
  useTaskControl: true,
  onLoaded: (task) {
    return OpenDocumentButton(filePath: task.filePath);
  },
  onError: (error) => Text('Error: \$error'),
)''',
        ),
      ],
    );
  }

  Widget _buildDocumentCard(
    BuildContext context, {
    required String name,
    required String url,
    required int size,
    required String type,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$type • ${FileUtils.formatSize(size)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: FileLoadingCard(
                url: url,
                useStream: true,
                checkCacheFirst: true,
                useTaskControl: true,
                onLoaded: (task) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text('Downloaded'),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            final mime = type == 'MP3' || type == 'Audio'
                                ? 'audio/mpeg'
                                : null;
                            FileViewer.openFile(context, task.filePath,
                                mimeType: mime);
                          },
                          child: const Text('Open'),
                        ),
                      ],
                    ),
                  );
                },
                onError: (error) => Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Error: $error')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildCodeExample(
  BuildContext context, {
  required String title,
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
          Icons.code,
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
