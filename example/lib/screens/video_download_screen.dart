import 'dart:io';

import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'sample_urls.dart';
import 'file_viewer_screen.dart';

/// Screen demonstrating video download with thumbnail preview and media picking
class VideoDownloadScreen extends StatefulWidget {
  const VideoDownloadScreen({super.key});

  @override
  State<VideoDownloadScreen> createState() => _VideoDownloadScreenState();
}

class _VideoDownloadScreenState extends State<VideoDownloadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _imagePicker = ImagePicker();

  // Real video files from online sources (publicly available sample videos)
  final List<VideoItem> _onlineVideos = [
    VideoItem(
      title: 'Introduction to Chatbots',
      description:
          'Learn the basics of Chatbots in this quick tutorial. Understanding how AI interacts with users.',
      thumbnailUrl:
          SampleUrls.image, // Using the operation image as thumbnail for demo
      videoUrl: SampleUrls.video,
      duration: const Duration(minutes: 1, seconds: 5),
      size: '12.5 MB',
      category: 'Tutorial',
    ),
    VideoItem(
      title: 'AI & Machine Learning Overview',
      description:
          'Explore the fundamentals of AI and ML technologies in this comprehensive guide.',
      thumbnailUrl: 'https://picsum.photos/seed/ai_ml/800/450',
      videoUrl: SampleUrls.video, // Using the same video for demo purposes
      duration: const Duration(minutes: 5, seconds: 30),
      size: '42.8 MB',
      category: 'Education',
    ),
    VideoItem(
      title: 'Nature Documentary: Ocean Life',
      description:
          'Stunning underwater footage from the Pacific Ocean demonstrating video clarity.',
      thumbnailUrl: 'https://picsum.photos/seed/ocean/800/450',
      videoUrl: SampleUrls.video,
      duration: const Duration(minutes: 15, seconds: 20),
      size: '128.5 MB',
      category: 'Documentary',
    ),
    VideoItem(
      title: 'Flutter Animation Guide',
      description:
          'Master complex animations in Flutter with this step-by-step example.',
      thumbnailUrl: 'https://picsum.photos/seed/animation/800/450',
      videoUrl: SampleUrls.video,
      duration: const Duration(minutes: 8, seconds: 45),
      size: '65.2 MB',
      category: 'Coding',
    ),
  ];

  // Videos picked from device
  final List<VideoItem> _localVideos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (video != null) {
        final file = File(video.path);
        final fileSize = await file.length();

        setState(() {
          _localVideos.add(VideoItem(
            title: video.name,
            description: 'Video from gallery',
            thumbnailUrl: '',
            videoUrl: video.path,
            duration: const Duration(
                seconds: 0), // Would need video_player to get duration
            size: FileUtils.formatSize(fileSize),
            category: 'Local',
            isLocal: true,
          ));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video added: ${video.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickVideoFromCamera() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
        preferredCameraDevice: CameraDevice.rear,
      );

      if (video != null) {
        final file = File(video.path);
        final fileSize = await file.length();

        setState(() {
          _localVideos.add(VideoItem(
            title:
                'Camera Recording ${DateTime.now().toLocal().toString().split('.')[0]}',
            description: 'Recorded from camera',
            thumbnailUrl: '',
            videoUrl: video.path,
            duration: const Duration(seconds: 0),
            size: FileUtils.formatSize(fileSize),
            category: 'Camera',
            isLocal: true,
          ));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video recorded and added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickMultipleVideos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
        withData: false,
        withReadStream: false,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            setState(() {
              _localVideos.add(VideoItem(
                title: file.name,
                description: 'Video from files',
                thumbnailUrl: '',
                videoUrl: file.path!,
                duration: const Duration(seconds: 0),
                size: FileUtils.formatSize(file.size),
                category: 'Files',
                isLocal: true,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking videos: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Online Videos', icon: Icon(Icons.cloud_download)),
            Tab(text: 'Local Videos', icon: Icon(Icons.folder)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOnlineVideosTab(),
          _buildLocalVideosTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPickerOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Video'),
      ),
    );
  }

  Widget _buildOnlineVideosTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Info Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.video_library,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Online Video Library',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Download videos from cloud storage with progress tracking',
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
          ),
        ),
        const SizedBox(height: 16),

        // Video List
        ...List.generate(_onlineVideos.length, (index) {
          final video = _onlineVideos[index];
          return _buildVideoCard(context, video, index);
        }),

        const SizedBox(height: 24),

        // Code Example
        _buildCodeExample(context),
      ],
    );
  }

  Widget _buildLocalVideosTab() {
    if (_localVideos.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 80,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No Local Videos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick videos from gallery, camera, or files',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickVideoFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickVideoFromCamera,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Camera'),
                ),
                OutlinedButton.icon(
                  onPressed: _pickMultipleVideos,
                  icon: const Icon(Icons.folder),
                  label: const Text('Files'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stats Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatItem(
                  context,
                  icon: Icons.video_file,
                  label: 'Videos',
                  value: '${_localVideos.length}',
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  context,
                  icon: Icons.storage,
                  label: 'Total Size',
                  value: _calculateTotalSize(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Local Videos List
        ...List.generate(_localVideos.length, (index) {
          final video = _localVideos[index];
          return _buildLocalVideoCard(context, video, index);
        }),
      ],
    );
  }

  String _calculateTotalSize() {
    // For demo purposes, just show count
    return '${_localVideos.length} files';
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Video',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select video from your gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideoFromGallery();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam),
                ),
                title: const Text('Record Video'),
                subtitle: const Text('Capture new video with camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideoFromCamera();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder),
                ),
                title: const Text('Browse Files'),
                subtitle: const Text('Select multiple videos from storage'),
                onTap: () {
                  Navigator.pop(context);
                  _pickMultipleVideos();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, VideoItem video, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Video Thumbnail with Play Button
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Thumbnail using FileLoadingCard
                FileLoadingCard(
                  url: video.thumbnailUrl.isNotEmpty
                      ? video.thumbnailUrl
                      : 'https://picsum.photos/seed/video$index/400/225',
                  useStream: true,
                  checkCacheFirst: true,
                  onLoaded: (task) {
                    final filePath = task.filePath;
                    if (filePath.isNotEmpty) {
                      return Image.file(
                        File(filePath),
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.video_file, size: 48),
                      ),
                    );
                  },
                  onError: (error) => Container(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 48),
                    ),
                  ),
                ),

                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                ),

                // Play Button
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.9),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.play_arrow, size: 32),
                      color: Colors.white,
                      onPressed: () => _playVideo(context, video),
                    ),
                  ),
                ),

                // Category Badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Duration Badge
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _formatDuration(video.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Video Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  video.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.storage,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      video.size,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _downloadVideo(context, video),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () => _shareVideo(context, video),
                      icon: const Icon(Icons.share, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocalVideoCard(
      BuildContext context, VideoItem video, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.video_file,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          video.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${video.category} • ${video.size}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _playLocalVideo(context, video),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                setState(() {
                  _localVideos.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeExample(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usage Example',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const SelectableText(
                '''// Pick video from gallery
final video = await ImagePicker().pickVideo(
  source: ImageSource.gallery,
);

// Pick multiple videos from files
final result = await FilePicker.platform.pickFiles(
  type: FileType.video,
  allowMultiple: true,
);

// Download video with progress
DownloadVideoWidget(
  file: FileModel(
    url: 'https://example.com/video.mp4',
    thumbnail: thumbnailBytes,
    durationInSeconds: 120,
  ),
  keyController: 'video_1',
  autoStart: true,
  onTap: (context, filePath) {
    // Play video
  },
)''',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _playVideo(BuildContext context, VideoItem video) {
    // Play video directly using FileViewer (Online URL)
    FileViewer.openFile(context, video.videoUrl, mimeType: 'video/mp4');
  }

  void _playLocalVideo(BuildContext context, VideoItem video) {
    if (File(video.videoUrl).existsSync()) {
      FileViewer.openFile(context, video.videoUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File not found: ${video.videoUrl}')),
      );
    }
  }

  void _downloadVideo(BuildContext context, VideoItem video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading: ${video.title}'),
        action: SnackBarAction(
          label: 'Cancel',
          onPressed: () {},
        ),
      ),
    );
  }

  void _shareVideo(BuildContext context, VideoItem video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share: ${video.title}')),
    );
  }
}

class VideoItem {
  final String title;
  final String description;
  final String thumbnailUrl;
  final String videoUrl;
  final Duration duration;
  final String size;
  final String category;
  final bool isLocal;

  VideoItem({
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.duration,
    required this.size,
    required this.category,
    this.isLocal = false,
  });
}
