import 'package:flutter/material.dart';

/// Constants for image display widgets
class ImageBubbleConstants {
  /// Spacing between error icon and text
  static const double errorSpacing = 8.0;

  /// Default border radius for images
  static const double borderRadius = 12.0;

  /// Default padding for image containers
  static const double padding = 8.0;

  /// Minimum size for thumbnails
  static const double minThumbnailSize = 48.0;

  /// Maximum size for thumbnails
  static const double maxThumbnailSize = 200.0;

  /// Default aspect ratio
  static const double defaultAspectRatio = 1.0;

  ImageBubbleConstants._();
}

/// Constants for video display widgets
class VideoBubbleConstants {
  /// Play button icon size
  static const double playButtonSize = 48.0;

  /// Play icon size inside button
  static const double playIconSize = 28.0;

  /// Play button background opacity
  static const double playButtonOpacity = 0.7;

  /// Default video aspect ratio (16:9)
  static const double defaultAspectRatio = 16 / 9;

  /// Border radius for video containers
  static const double borderRadius = 12.0;

  /// Padding for duration badge
  static const double durationPadding = 8.0;

  /// Vertical padding for duration badge
  static const double durationVerticalPadding = 4.0;

  /// Border radius for duration badge
  static const double durationBorderRadius = 4.0;

  /// Font size for duration text
  static const double durationFontSize = 12.0;

  VideoBubbleConstants._();
}

/// Constants for document display widgets
class DocumentConstants {
  /// Default icon size for document icons
  static const double iconSize = 48.0;

  /// Border radius for document cards
  static const double borderRadius = 8.0;

  /// Padding for document cards
  static const double padding = 16.0;

  DocumentConstants._();
}

/// Theme configuration for media widgets
class MediaWidgetTheme {
  /// Primary color for progress indicators
  final Color primaryColor;

  /// Background color for progress indicators
  final Color progressBackgroundColor;

  /// Error color
  final Color errorColor;

  /// Success/complete color
  final Color successColor;

  /// Border radius for cards
  final double cardBorderRadius;

  /// Creates a MediaWidgetTheme
  const MediaWidgetTheme({
    this.primaryColor = const Color(0xFF6750A4),
    this.progressBackgroundColor = const Color(0xFFE0E0E0),
    this.errorColor = const Color(0xFFB00020),
    this.successColor = const Color(0xFF4CAF50),
    this.cardBorderRadius = 12.0,
  });

  /// Creates theme from BuildContext
  factory MediaWidgetTheme.fromContext(BuildContext context) {
    final theme = Theme.of(context);
    return MediaWidgetTheme(
      primaryColor: theme.colorScheme.primary,
      progressBackgroundColor: theme.colorScheme.surfaceContainerHighest,
      errorColor: theme.colorScheme.error,
      successColor: Colors.green,
      cardBorderRadius: 12.0,
    );
  }

  /// Default theme instance
  static const MediaWidgetTheme defaultTheme = MediaWidgetTheme();
}

/// Icon and color mapping for file types
class FileTypeIcons {
  /// Gets icon and color for a file extension
  static (IconData, Color) getIconAndColor(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '');

    if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'].contains(ext)) {
      return (Icons.image, Colors.blue);
    } else if (ext == 'pdf') {
      return (Icons.picture_as_pdf, Colors.red);
    } else if (['doc', 'docx', 'odt', 'rtf', 'txt'].contains(ext)) {
      return (Icons.description, Colors.blue);
    } else if (['xls', 'xlsx', 'csv'].contains(ext)) {
      return (Icons.table_chart, Colors.green);
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'].contains(ext)) {
      return (Icons.video_file, Colors.purple);
    } else if (['mp3', 'wav', 'ogg', 'flac', 'm4a'].contains(ext)) {
      return (Icons.audio_file, Colors.amber);
    } else if (['zip', 'rar', '7z', 'tar', 'gz'].contains(ext)) {
      return (Icons.folder_zip, Colors.brown);
    } else {
      return (Icons.insert_drive_file, Colors.grey);
    }
  }

  FileTypeIcons._();
}
