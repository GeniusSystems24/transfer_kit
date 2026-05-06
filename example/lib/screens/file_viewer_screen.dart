import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:open_filex/open_filex.dart';

class FileViewer {
  static void openFile(BuildContext context, String filePath,
      {String? mimeType}) {
    // Detect type
    final type = mimeType ?? _guessMimeType(filePath);

    if (type.startsWith('video/')) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
                filePath: filePath, isUrl: filePath.startsWith('http'))),
      );
    } else if (type.startsWith('audio/')) {
      showModalBottomSheet(
        context: context,
        builder: (_) => AudioPlayerSheet(filePath: filePath),
      );
    } else {
      // Use system viewer
      OpenFilex.open(filePath);
    }
  }

  static String _guessMimeType(String path) {
    String cleanPath = path;
    if (cleanPath.contains('?')) {
      cleanPath = cleanPath.split('?').first;
    }
    final ext = cleanPath.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv', 'webm', 'wmv'].contains(ext)) {
      return 'video/mp4';
    }
    if (['mp3', 'wav', 'aac', 'm4a', 'flac', 'ogg'].contains(ext)) {
      return 'audio/mpeg';
    }
    if (['jpg', 'jpeg', 'png', 'gif'].contains(ext)) return 'image/jpeg';
    if (ext == 'pdf') return 'application/pdf';
    return 'application/octet-stream';
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String filePath;
  final bool isUrl;

  const VideoPlayerScreen(
      {super.key, required this.filePath, this.isUrl = false});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (widget.isUrl) {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(widget.filePath));
    } else {
      _videoPlayerController =
          VideoPlayerController.file(File(widget.filePath));
    }

    try {
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: true,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.filePath.split('/').last),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      body: Center(
        child: _chewieController != null &&
                _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(controller: _chewieController!)
            : const CircularProgressIndicator(),
      ),
    );
  }
}

class AudioPlayerSheet extends StatefulWidget {
  final String filePath;

  const AudioPlayerSheet({super.key, required this.filePath});

  @override
  State<AudioPlayerSheet> createState() => _AudioPlayerSheetState();
}

class _AudioPlayerSheetState extends State<AudioPlayerSheet> {
  final _player = ja.AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _player.setFilePath(widget.filePath);
      _duration = _player.duration ?? Duration.zero;

      _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
          });
        }
      });

      _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      });

      if (mounted) setState(() {});
      _player.play();
    } catch (e) {
      debugPrint('Error loading audio: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          Slider(
            value: _position.inSeconds
                .toDouble()
                .clamp(0, _duration.inSeconds.toDouble()),
            max: _duration.inSeconds.toDouble(),
            onChanged: (value) {
              _player.seek(Duration(seconds: value.toInt()));
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position)),
                Text(_formatDuration(_duration)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          IconButton(
            iconSize: 48,
            icon: Icon(_isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled),
            color: Colors.blue,
            onPressed: () {
              if (_isPlaying) {
                _player.pause();
              } else {
                _player.play();
              }
            },
          ),
        ],
      ),
    );
  }
}
