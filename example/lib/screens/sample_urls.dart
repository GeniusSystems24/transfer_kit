/// Real sample URLs from Firebase Storage for demo purposes
class SampleUrls {
  SampleUrls._();

  /// Real image URL (PNG)
  static const String image =
      'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/operation.png?alt=media&token=6e1d3457-f2f3-43db-bcf3-70332e19d298';

  /// Real video URL (MP4)
  static const String video =
      'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/What%20are%20Chatbots-.mp4?alt=media&token=68b7385c-8394-48d3-9ac3-2b26b22abb1d';

  /// Real PDF document URL
  static const String pdf =
      'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/0106%D8%B9%D9%84%D9%88%D9%85%20%D8%B5%D9%81%20%D8%A7%D9%88%D9%84%20%D8%AC%D8%B2%D8%A1%201.pdf?alt=media&token=9c0c552c-bc33-4bd9-9c5b-3a287ef7794d';

  /// Real audio URL (MP3)
  static const String audio =
      'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/WhatsApp%20Ptt%202026-01-06%20at%2019.11.56.mp3?alt=media&token=8bc5b4c3-d4d1-4fb5-a207-63f0744079b1';

  /// Sample images list (mix of real and generated)
  static const List<String> images = [
    image, // Real image
    'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/operation.png?alt=media&token=6e1d3457-f2f3-43db-bcf3-70332e19d298',
    'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/operation.png?alt=media&token=6e1d3457-f2f3-43db-bcf3-70332e19d298',
    'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/operation.png?alt=media&token=6e1d3457-f2f3-43db-bcf3-70332e19d298',
    'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/operation.png?alt=media&token=6e1d3457-f2f3-43db-bcf3-70332e19d298',
    'https://firebasestorage.googleapis.com/v0/b/skycachefiles.appspot.com/o/operation.png?alt=media&token=6e1d3457-f2f3-43db-bcf3-70332e19d298',
  ];

  /// All sample files for mixed examples
  static const List<Map<String, dynamic>> allFiles = [
    {
      'name': 'Operation Image',
      'url': image,
      'type': 'Image',
      'size': 245000,
    },
    {
      'name': 'What Are Chatbots?',
      'url': video,
      'type': 'Video',
      'size': 12500000,
      'duration': 65,
    },
    {
      'name': 'Science Textbook - Grade 1',
      'url': pdf,
      'type': 'PDF',
      'size': 8500000,
    },
    {
      'name': 'Voice Note',
      'url': audio,
      'type': 'Audio',
      'size': 256000,
    },
  ];
}
