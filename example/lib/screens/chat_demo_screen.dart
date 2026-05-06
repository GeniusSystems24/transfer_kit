import 'dart:io';
import 'package:flutter/material.dart';
import 'package:transfer_kit/transfer_kit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'file_viewer_screen.dart';

class ChatDemoScreen extends StatefulWidget {
  const ChatDemoScreen({super.key});

  @override
  State<ChatDemoScreen> createState() => _ChatDemoScreenState();
}

class _ChatDemoScreenState extends State<ChatDemoScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadInitialMessages();
  }

  void _loadInitialMessages() {
    _messages.addAll([
      ChatMessage(
        id: '1',
        senderId: 'other',
        text: 'Welcome to the File Management System Chat Demo!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: '2',
        senderId: 'other',
        text:
            'You can send single files, multiple images, videos, or documents.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 29)),
      ),
      ChatMessage(
        id: '3',
        senderId: 'other',
        attachment: ChatAttachment(
          type: AttachmentType.image,
          url: 'https://picsum.photos/seed/demo1/400/300',
          size: 500000,
        ),
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      ChatMessage(
        id: '4',
        senderId: 'me',
        text: 'I can also send image sliders!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
      ChatMessage(
        id: '5',
        senderId: 'me',
        attachment: ChatAttachment(
          type: AttachmentType.imageSlider,
          urls: [
            'https://picsum.photos/seed/slide1/800/600',
            'https://picsum.photos/seed/slide2/800/600',
            'https://picsum.photos/seed/slide3/800/600',
          ],
          url: '', // Required param
          size: 1500000,
        ),
        timestamp: DateTime.now().subtract(const Duration(minutes: 19)),
      ),
    ]);
  }

  void _sendMessage() {
    if (_textController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        senderId: 'me',
        text: _textController.text.trim(),
        timestamp: DateTime.now(),
      ));
      _textController.clear();
    });
    _scrollToBottom();
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- Attachment Pickers ---

  Future<void> _showAttachmentPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Share Content',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  _buildPickerOption(
                    icon: Icons.image,
                    color: Colors.purple,
                    label: 'Gallery',
                    onTap: _pickImages,
                  ),
                  _buildPickerOption(
                    icon: Icons.camera_alt,
                    color: Colors.blue,
                    label: 'Camera',
                    onTap: _pickCameraImage,
                  ),
                  _buildPickerOption(
                    icon: Icons.collections,
                    color: Colors.orange,
                    label: 'Slider',
                    onTap: _pickMultiImages, // Specifically for slider demo
                  ),
                  _buildPickerOption(
                    icon: Icons.videocam,
                    color: Colors.red,
                    label: 'Video',
                    onTap: _pickVideo,
                  ),
                  _buildPickerOption(
                    icon: Icons.audiotrack,
                    color: Colors.teal,
                    label: 'Audio',
                    onTap: _pickAudio,
                  ),
                  _buildPickerOption(
                    icon: Icons.insert_drive_file,
                    color: Colors.indigo,
                    label: 'File',
                    onTap: _pickFile,
                  ),
                  _buildPickerOption(
                    icon: Icons.cloud_upload,
                    color: Colors.green,
                    label: 'Multi-Up',
                    onTap: _pickMultiFiles, // For MultiFileUploadCard demo
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  // --- File Picking Logic ---

  Future<void> _pickImages() async {
    final XFile? image =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null) {
      _startUpload(File(image.path), AttachmentType.image);
    }
  }

  Future<void> _pickCameraImage() async {
    final XFile? image =
        await ImagePicker().pickImage(source: ImageSource.camera);
    if (image != null) {
      _startUpload(File(image.path), AttachmentType.image);
    }
  }

  Future<void> _pickMultiImages() async {
    final List<XFile> images = await ImagePicker().pickMultiImage();
    if (images.length > 1) {
      // Use MultiFileUploadCard for uploading
      _startMultiUpload(
        images.map((e) => File(e.path)).toList(),
        AttachmentType.imageSlider,
      );
    } else if (images.isNotEmpty) {
      _startUpload(File(images.first.path), AttachmentType.image);
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video =
        await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video != null) {
      _startUpload(File(video.path), AttachmentType.video);
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      _startUpload(File(result.files.single.path!), AttachmentType.audio);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      _startUpload(File(result.files.single.path!), AttachmentType.document);
    }
  }

  Future<void> _pickMultiFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && result.paths.isNotEmpty) {
      final files =
          result.paths.where((p) => p != null).map((p) => File(p!)).toList();
      _startMultiUpload(files, AttachmentType.document);
    }
  }

  // --- Upload Logic ---

  void _startUpload(File file, AttachmentType type) {
    // Generate a unique destination path
    final fileName = file.path.split('/').last;
    final destination =
        'chat_uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'me',
      timestamp: DateTime.now(),
      attachment: ChatAttachment(
        type: type,
        localPath: file.path,
        url: '', // Will be filled after upload
        size: file.lengthSync(),
        isUploading: true,
        destinationPath: destination,
      ),
    ));
  }

  void _startMultiUpload(List<File> files, AttachmentType type) {
    // We treat multi-upload as a single message bubble initially containing MultiFileUploadCard
    final uploads = files.map((file) {
      final fileName = file.path.split('/').last;
      return {
        'file': file,
        'destination':
            'chat_uploads/${DateTime.now().millisecondsSinceEpoch}_$fileName'
      };
    }).toList();

    _addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'me',
      timestamp: DateTime.now(),
      attachment: ChatAttachment(
        type: type, // imageSlider or document (as group)
        localPath: '', // Not used for multi
        url: '',
        size: 0,
        isUploading: true,
        multiUploads: uploads,
      ),
    ));
  }

  // --- UI Building ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Uses real File Management System widgets!')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message.senderId == 'me';
                return Align(
                  alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: _buildMessageBubble(context, message, isMe),
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      BuildContext context, ChatMessage message, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      constraints:
          BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                bottomRight: isMe ? Radius.zero : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      message.text!,
                      style: TextStyle(
                        color: isMe
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (message.attachment != null) ...[
                  _buildAttachmentContent(context, message, isMe),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              timeago.format(message.timestamp),
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentContent(
      BuildContext context, ChatMessage message, bool isMe) {
    final attachment = message.attachment!;

    // 1. Uploading State
    if (attachment.isUploading) {
      if (attachment.multiUploads != null) {
        // Multi-File Upload Widget
        return Container(
          width: 250,
          padding: const EdgeInsets.all(8),
          child: MultiFileUploadCard(
            filePathsAndUrls: attachment.multiUploads!
                .map((u) => FilePathAndURL.local(
                    path: (u['file'] as File).path,
                    destinationPath: u['destination'] as String))
                .toSet(),
            // onUploaded: (uploadedUrls) {
            //   // Returns list of URLs
            //   setState(() {
            //     attachment.isUploading = false;
            //     if (attachment.type == AttachmentType.imageSlider) {
            //       attachment.urls = uploadedUrls;
            //     } else {
            //       // For general docs, maybe just show "Attached X files" or keep urls
            //       attachment.urls = uploadedUrls;
            //     }
            //   });
            // },
          ),
        );
      } else {
        // Single File Upload Widget
        return Container(
          width: 200,
          padding: const EdgeInsets.all(8),
          child: FileUploadCard(
            filePath: attachment.localPath!,
            destinationPath: attachment.destinationPath!,
            // onUploaded: (task) {
            //   setState(() {
            //     attachment.isUploading = false;
            //     attachment.url = task.downloadUrl ?? '';
            //   });
            // },
          ),
        );
      }
    }

    // 2. Display State (Uploaded)

    // Image Slider
    if (attachment.type == AttachmentType.imageSlider &&
        attachment.urls != null) {
      if (attachment.urls!.isEmpty) return const Text('Upload failed');
      return SizedBox(
        height: 200,
        child: DownloadImageSliderWidget(
          imageFiles: attachment.urls!
              .map((url) => FileModel.remote(url: url))
              .toList(),
          autoStart: true,
          radius: 12,
          onImageTap: (model) => FileViewer.openFile(context, model.url ?? ''),
        ),
      );
    }

    // Single Image
    if (attachment.type == AttachmentType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DownloadImageWidget(
          file: FileModel.remote(url: attachment.url),
          fit: BoxFit.cover,
          onTap: (ctx, path) =>
              FileViewer.openFile(context, path, mimeType: 'image/jpeg'),
        ),
      );
    }

    // Single Video
    if (attachment.type == AttachmentType.video) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 220,
          child: DownloadVideoWidget(
            file: FileModel.remote(url: attachment.url),
            keyController:
                attachment.url, // Unique ID for controller management
            autoStart: false,
            onTap: (ctx, path) =>
                FileViewer.openFile(context, path, mimeType: 'video/mp4'),
          ),
        ),
      );
    }

    // Default: Audio or Document
    final icon = attachment.type == AttachmentType.audio
        ? Icons.audiotrack
        : Icons.description;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(4),
      child: FileLoadingCard(
        url: attachment.url,
        useStream: true,
        checkCacheFirst: true,
        onLoaded: (task) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            title: Text(
              attachment.type == AttachmentType.audio
                  ? 'Audio Clip'
                  : 'Document',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(FileUtils.formatSize(task.totalBytes)),
            onTap: () {
              final mime =
                  attachment.type == AttachmentType.audio ? 'audio/mpeg' : null;
              FileViewer.openFile(context, task.filePath, mimeType: mime);
            },
          );
        },
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -4),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _showAttachmentPicker,
              color: Theme.of(context).colorScheme.primary,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _sendMessage,
              elevation: 0,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String? text;
  final ChatAttachment? attachment;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.text,
    this.attachment,
    required this.timestamp,
  });
}

class ChatAttachment {
  final AttachmentType type;
  String url;
  final String? localPath;
  final String? destinationPath;
  final int size;
  bool isUploading;

  // For multi-upload
  List<Map<String, dynamic>>? multiUploads;
  List<String>? urls;

  ChatAttachment({
    required this.type,
    required this.url,
    this.localPath,
    this.destinationPath,
    required this.size,
    this.isUploading = false,
    this.multiUploads,
    this.urls,
  });
}

enum AttachmentType { image, video, audio, document, imageSlider }
