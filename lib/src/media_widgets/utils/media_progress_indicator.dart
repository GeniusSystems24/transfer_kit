import 'package:flutter/material.dart';

/// A customizable circular progress indicator for media downloads.
class MediaProgressIndicator extends StatelessWidget {
  /// Current progress value (0.0 to 1.0)
  final double progress;

  /// Size of the indicator
  final double size;

  /// Stroke width of the progress arc
  final double strokeWidth;

  /// Color of the progress arc
  final Color? progressColor;

  /// Color of the background circle
  final Color? backgroundColor;

  /// Widget to display in the center (e.g., percentage text)
  final Widget? center;

  /// Whether to show a spinning animation when progress is indeterminate
  final bool indeterminate;

  /// Creates a MediaProgressIndicator
  const MediaProgressIndicator({
    super.key,
    this.progress = 0.0,
    this.size = 48.0,
    this.strokeWidth = 4.0,
    this.progressColor,
    this.backgroundColor,
    this.center,
    this.indeterminate = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveProgressColor = progressColor ?? theme.colorScheme.primary;
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    if (indeterminate) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(effectiveProgressColor),
          backgroundColor: effectiveBackgroundColor,
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: strokeWidth,
            valueColor: AlwaysStoppedAnimation<Color>(effectiveProgressColor),
            backgroundColor: effectiveBackgroundColor,
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

/// A progress indicator with percentage text
class MediaProgressWithPercentage extends StatelessWidget {
  /// Current progress value (0.0 to 1.0)
  final double progress;

  /// Size of the indicator
  final double size;

  /// Stroke width
  final double strokeWidth;

  /// Progress color
  final Color? progressColor;

  /// Text style for the percentage
  final TextStyle? textStyle;

  /// Creates a MediaProgressWithPercentage
  const MediaProgressWithPercentage({
    super.key,
    required this.progress,
    this.size = 56.0,
    this.strokeWidth = 4.0,
    this.progressColor,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (progress * 100).toInt();
    final theme = Theme.of(context);

    return MediaProgressIndicator(
      progress: progress,
      size: size,
      strokeWidth: strokeWidth,
      progressColor: progressColor,
      center: Text(
        '$percentage%',
        style:
            textStyle ??
            theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// A linear progress indicator for media downloads
class MediaLinearProgress extends StatelessWidget {
  /// Current progress value (0.0 to 1.0)
  final double progress;

  /// Height of the progress bar
  final double height;

  /// Border radius of the progress bar
  final double borderRadius;

  /// Progress color
  final Color? progressColor;

  /// Background color
  final Color? backgroundColor;

  /// Whether to show percentage text
  final bool showPercentage;

  /// Creates a MediaLinearProgress
  const MediaLinearProgress({
    super.key,
    required this.progress,
    this.height = 8.0,
    this.borderRadius = 4.0,
    this.progressColor,
    this.backgroundColor,
    this.showPercentage = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveProgressColor = progressColor ?? theme.colorScheme.primary;
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.surfaceContainerHighest;

    Widget progressBar = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: height,
        valueColor: AlwaysStoppedAnimation<Color>(effectiveProgressColor),
        backgroundColor: effectiveBackgroundColor,
      ),
    );

    if (showPercentage) {
      final percentage = (progress * 100).toInt();
      return Row(
        children: [
          Expanded(child: progressBar),
          const SizedBox(width: 8),
          Text('$percentage%', style: theme.textTheme.labelSmall),
        ],
      );
    }

    return progressBar;
  }
}
