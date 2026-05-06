import 'dart:io';

import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'sample_urls.dart';

/// Screen demonstrating image gallery with download functionality and media picking
class ImageGalleryScreen extends StatefulWidget {
  const ImageGalleryScreen({super.key});

  @override
  State<ImageGalleryScreen> createState() => _ImageGalleryScreenState();
}

class _ImageGalleryScreenState extends State<ImageGalleryScreen>
    with SingleTickerProviderStateMixin {
  final ImagePicker _imagePicker = ImagePicker();
  late TabController _tabController;

  // Online images (stock photos)
  late final List<GalleryImage> _onlineImages = [
    // Real Firebase Image
    GalleryImage(
      url: SampleUrls.image,
      title: 'Operation Image',
      photographer: 'System Admin',
      likes: 1024,
      isOnline: true,
    ),
    // Generated based on SampleUrls.images (skipping the first one as it's the real one)
    ...List.generate(
      SampleUrls.images.length - 1,
      (index) => GalleryImage(
        url: SampleUrls.images[index + 1],
        title: 'Gallery Photo ${index + 1}',
        photographer: [
          'Alex Chen',
          'Maria Silva',
          'John Doe',
          'Emma Wilson'
        ][index % 4],
        likes: (index + 1) * 127 + (index * 23),
        isOnline: true,
      ),
    ),
    // Add more generated ones to fill the grid if needed
    ...List.generate(
      6,
      (index) => GalleryImage(
        url: 'https://picsum.photos/seed/gallery_extra_$index/800/600',
        title: 'Extra Photo ${index + 1}',
        photographer: 'Stock Photo',
        likes: 50 + (index * 10),
        isOnline: true,
      ),
    ),
  ];

  // Local images picked from device
  final List<GalleryImage> _localImages = [];

  int _selectedIndex = -1;
  bool _isGridView = true;

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

  Future<void> _pickImagesFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (images.isNotEmpty) {
        for (var image in images) {
          final file = File(image.path);
          final size = await file.length();

          setState(() {
            _localImages.add(GalleryImage(
              url: image.path,
              title: image.name,
              photographer: 'Local',
              likes: 0,
              isOnline: false,
              fileSize: size,
            ));
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${images.length} image(s) added to gallery'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error picking images: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (photo != null) {
        final file = File(photo.path);
        final size = await file.length();

        setState(() {
          _localImages.add(GalleryImage(
            url: photo.path,
            title:
                'Camera Photo ${DateTime.now().toIso8601String().split('T')[0]}',
            photographer: 'You',
            likes: 0,
            isOnline: false,
            fileSize: size,
          ));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo captured and added to gallery'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error capturing photo: $e');
    }
  }

  Future<void> _pickImagesFromFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (var file in result.files) {
          if (file.path != null) {
            setState(() {
              _localImages.add(GalleryImage(
                url: file.path!,
                title: file.name,
                photographer: 'Files',
                likes: 0,
                isOnline: false,
                fileSize: file.size,
              ));
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${result.files.length} image(s) added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showError('Error picking files: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _refreshOnlineGallery() {
    setState(() {
      _onlineImages.clear();
      _onlineImages.addAll(List.generate(
        12,
        (index) => GalleryImage(
          url:
              'https://picsum.photos/seed/gallery${DateTime.now().millisecondsSinceEpoch + index}/800/600',
          title: 'Photo ${index + 1}',
          photographer: [
            'Alex Chen',
            'Maria Silva',
            'John Doe',
            'Emma Wilson'
          ][index % 4],
          likes: (index + 1) * 127 + (index * 23),
          isOnline: true,
        ),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Gallery'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Online Gallery', icon: Icon(Icons.cloud)),
            Tab(text: 'My Photos', icon: Icon(Icons.photo_library)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip: _isGridView ? 'List View' : 'Grid View',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _refreshOnlineGallery();
                  break;
                case 'pick_gallery':
                  _pickImagesFromGallery();
                  break;
                case 'take_photo':
                  _takePhoto();
                  break;
                case 'pick_files':
                  _pickImagesFromFiles();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh Online'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'pick_gallery',
                child: ListTile(
                  leading: Icon(Icons.photo_library),
                  title: Text('Pick from Gallery'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'take_photo',
                child: ListTile(
                  leading: Icon(Icons.camera_alt),
                  title: Text('Take Photo'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'pick_files',
                child: ListTile(
                  leading: Icon(Icons.folder),
                  title: Text('Browse Files'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOnlineGalleryTab(),
          _buildLocalGalleryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPhotoOptions,
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  void _showAddPhotoOptions() {
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
                'Add Photos',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: const Text('Choose from Gallery'),
                subtitle: const Text('Select multiple images'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImagesFromGallery();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.green),
                ),
                title: const Text('Take a Photo'),
                subtitle: const Text('Capture with camera'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder, color: Colors.orange),
                ),
                title: const Text('Browse Files'),
                subtitle: const Text('Select from file manager'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImagesFromFiles();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineGalleryTab() {
    return Column(
      children: [
        // Gallery Grid
        Expanded(
          child: _isGridView
              ? GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _onlineImages.length,
                  itemBuilder: (context, index) => _buildOnlineImageTile(index),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _onlineImages.length,
                  itemBuilder: (context, index) =>
                      _buildOnlineImageListTile(index),
                ),
        ),

        // Selected Image Preview
        if (_selectedIndex >= 0 && _selectedIndex < _onlineImages.length)
          _buildSelectedImagePreview(_onlineImages[_selectedIndex]),
      ],
    );
  }

  Widget _buildLocalGalleryTab() {
    if (_localImages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 80,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No Local Photos',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add photos from gallery or camera',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImagesFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                OutlinedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Stats Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(Icons.photo, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '${_localImages.length} Photos',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  setState(() => _localImages.clear());
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear All'),
              ),
            ],
          ),
        ),

        // Local Images Grid
        Expanded(
          child: _isGridView
              ? GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _localImages.length,
                  itemBuilder: (context, index) => _buildLocalImageTile(index),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _localImages.length,
                  itemBuilder: (context, index) =>
                      _buildLocalImageListTile(index),
                ),
        ),
      ],
    );
  }

  Widget _buildOnlineImageTile(int index) {
    final image = _onlineImages[index];
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isSelected ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : BorderSide.none,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FileLoadingCard(
              url: image.url,
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
                return const Center(child: Icon(Icons.image));
              },
              onError: (error) => Container(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Icon(
                  Icons.broken_image,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineImageListTile(int index) {
    final image = _onlineImages[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SizedBox(
          width: 60,
          height: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FileLoadingCard(
              url: image.url,
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
                return const Center(child: Icon(Icons.image));
              },
              onError: (error) => const Icon(Icons.broken_image),
            ),
          ),
        ),
        title: Text(image.title),
        subtitle: Text('by ${image.photographer}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 16),
            const SizedBox(width: 4),
            Text('${image.likes}'),
          ],
        ),
        onTap: () => _openFullScreen(context, _onlineImages, index, true),
      ),
    );
  }

  Widget _buildLocalImageTile(int index) {
    final image = _localImages[index];

    return GestureDetector(
      onTap: () => _openFullScreen(context, _localImages, index, false),
      onLongPress: () => _showImageOptions(index),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(image.url),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Icon(Icons.broken_image),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  image.fileSize != null
                      ? FileUtils.formatSize(image.fileSize!)
                      : '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalImageListTile(int index) {
    final image = _localImages[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SizedBox(
          width: 60,
          height: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(image.url),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image),
            ),
          ),
        ),
        title: Text(
          image.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          image.fileSize != null
              ? FileUtils.formatSize(image.fileSize!)
              : 'Local file',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () {
            setState(() {
              _localImages.removeAt(index);
            });
          },
        ),
        onTap: () => _openFullScreen(context, _localImages, index, false),
      ),
    );
  }

  void _showImageOptions(int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('View Full Screen'),
              onTap: () {
                Navigator.pop(context);
                _openFullScreen(context, _localImages, index, false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share feature')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _localImages.removeAt(index);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview(GalleryImage image) {
    return Container(
      height: 250,
      margin: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FileLoadingCard(
              url: image.url,
              useStream: true,
              checkCacheFirst: true,
              onLoaded: (task) {
                final filePath = task.filePath;
                if (filePath.isNotEmpty) {
                  return Image.file(
                    File(filePath),
                    fit: BoxFit.contain,
                  );
                }
                return const Center(child: Icon(Icons.image, size: 64));
              },
              onError: (error) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error,
                        color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 8),
                    const Text('Error loading image'),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.fullscreen),
                    onPressed: () => _openFullScreen(
                        context, _onlineImages, _selectedIndex, true),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _selectedIndex = -1),
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
                child: Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: _selectedIndex > 0
                          ? () => setState(() => _selectedIndex--)
                          : null,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            image.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'by ${image.photographer}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios,
                          color: Colors.white),
                      onPressed: _selectedIndex < _onlineImages.length - 1
                          ? () => setState(() => _selectedIndex++)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreen(BuildContext context, List<GalleryImage> images,
      int initialIndex, bool isOnline) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          images: images,
          initialIndex: initialIndex,
          isOnline: isOnline,
        ),
      ),
    );
  }
}

/// Full screen image viewer with swipe navigation
class FullScreenImageViewer extends StatefulWidget {
  final List<GalleryImage> images;
  final int initialIndex;
  final bool isOnline;

  const FullScreenImageViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
    this.isOnline = true,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = widget.images[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentImage.title,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              '${_currentIndex + 1} / ${widget.images.length}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share image')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image already downloaded')),
              );
            },
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            child: Center(
              child: widget.isOnline
                  ? FileLoadingCard(
                      url: image.url,
                      useStream: true,
                      checkCacheFirst: true,
                      onLoaded: (task) {
                        final filePath = task.filePath;
                        if (filePath.isNotEmpty) {
                          return Image.file(
                            File(filePath),
                            fit: BoxFit.contain,
                          );
                        }
                        return const Center(
                          child: Icon(Icons.image,
                              color: Colors.white54, size: 64),
                        );
                      },
                      onError: (error) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error,
                                color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading image',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Image.file(
                      File(image.url),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                        child: Icon(Icons.broken_image,
                            color: Colors.white54, size: 64),
                      ),
                    ),
            ),
          );
        },
      ),
      bottomNavigationBar: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (currentImage.isOnline) ...[
              const Icon(Icons.favorite, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                '${currentImage.likes} likes',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(width: 24),
            ],
            Text(
              'by ${currentImage.photographer}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class GalleryImage {
  final String url;
  final String title;
  final String photographer;
  final int likes;
  final bool isOnline;
  final int? fileSize;

  GalleryImage({
    required this.url,
    required this.title,
    required this.photographer,
    required this.likes,
    required this.isOnline,
    this.fileSize,
  });
}
