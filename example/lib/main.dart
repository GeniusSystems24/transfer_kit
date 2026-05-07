import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';

import 'screens/single_download_screen.dart';
import 'screens/multi_download_screen.dart';
import 'screens/image_gallery_screen.dart';
import 'screens/video_download_screen.dart';
import 'screens/upload_demo_screen.dart';
import 'screens/multi_upload_screen.dart';
import 'screens/task_manager_screen.dart';
import 'screens/media_widgets_screen.dart';
import 'screens/chat_demo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable all settings for TransferKit
  await TransferKitConfig.init(
    driver: LocalFileCopyDriver(),
    maxConcurrentDownloads: 5,
    maxConcurrentUploads: 3,
    streamCleanupDelay: const Duration(seconds: 3),
    defaultAutoStart: true,
    enableLogging: true, // Enabled for debugging
    retryAttempts: 3,
    retryDelay: const Duration(seconds: 2),
    cacheEnabled: true,
    maxCacheSize: 500 * 1024 * 1024, // 500 MB
    cacheExpiration: const Duration(days: 7),
    // Metadata settings
    autoExtractMetadata: true,
    autoExtractSha256: true,
    autoExtractThumbnail: true,
    autoExtractWaveform: true,
    thumbnailMaxWidth: 200,
    thumbnailMaxHeight: 200,
    waveformSamplesPerSecond: 30,
  );

  runApp(const FileManagementExampleApp());
}

class FileManagementExampleApp extends StatelessWidget {
  const FileManagementExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Management System Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Management System'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),

          // Downloads Section
          _buildSectionTitle(context, 'Downloads'),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Single File Download',
            subtitle: 'Download a single file with progress tracking',
            icon: Icons.download,
            color: Colors.blue,
            onTap: () => _navigateTo(context, const SingleDownloadScreen()),
          ),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Multi-File Download',
            subtitle: 'Download multiple files simultaneously',
            icon: Icons.download_for_offline,
            color: Colors.indigo,
            onTap: () => _navigateTo(context, const MultiDownloadScreen()),
          ),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Image Gallery',
            subtitle: 'Download and display image gallery',
            icon: Icons.photo_library,
            color: Colors.teal,
            onTap: () => _navigateTo(context, const ImageGalleryScreen()),
          ),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Video Download',
            subtitle: 'Download video with thumbnail preview',
            icon: Icons.video_library,
            color: Colors.purple,
            onTap: () => _navigateTo(context, const VideoDownloadScreen()),
          ),

          const SizedBox(height: 24),

          // Uploads Section
          _buildSectionTitle(context, 'Uploads'),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Single File Upload',
            subtitle: 'Upload a single file with progress',
            icon: Icons.upload,
            color: Colors.green,
            onTap: () => _navigateTo(context, const UploadDemoScreen()),
          ),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Multi-File Upload',
            subtitle: 'Upload multiple files at once',
            icon: Icons.cloud_upload,
            color: Colors.lightGreen,
            onTap: () => _navigateTo(context, const MultiUploadScreen()),
          ),

          const SizedBox(height: 24),

          // Management Section
          _buildSectionTitle(context, 'Management'),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Task Manager',
            subtitle: 'View and manage all file tasks',
            icon: Icons.list_alt,
            color: Colors.orange,
            onTap: () => _navigateTo(context, const TaskManagerScreen()),
          ),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Media Widgets',
            subtitle: 'Explore media download widgets',
            icon: Icons.widgets,
            color: Colors.pink,
            onTap: () => _navigateTo(context, const MediaWidgetsScreen()),
          ),
          const SizedBox(height: 8),
          _buildDemoCard(
            context,
            title: 'Chat Demo',
            subtitle: 'Full chat interface with media attachments',
            icon: Icons.chat,
            color: Colors.deepPurple,
            onTap: () => _navigateTo(context, const ChatDemoScreen()),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.folder_copy,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'File Management System',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'A comprehensive solution for file uploads, downloads, and task management with Firebase Storage',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildDemoCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
