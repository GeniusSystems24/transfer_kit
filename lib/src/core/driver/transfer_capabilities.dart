import 'package:flutter/foundation.dart';

/// Declares which operations a [TransferDriver] supports.
///
/// All flags default to `false`. Drivers declare only what they support.
///
/// ## Invariants
///
/// - [supportsResume] MUST NOT be `true` when [supportsPause] is `false`.
/// - [supportsBackgroundTransfer] is a reserved extension point. No built-in
///   driver declares it `true` in version 3.0.0.
@immutable
class TransferCapabilities {
  const TransferCapabilities({
    this.supportsUpload = false,
    this.supportsDownload = false,
    this.supportsPause = false,
    this.supportsResume = false,
    this.supportsCancel = false,
    this.supportsProgress = false,
    this.supportsBackgroundTransfer = false,
    this.supportsRetry = false,
  }) : assert(
         !supportsResume || supportsPause,
         'supportsResume requires supportsPause to be true',
       );

  final bool supportsUpload;
  final bool supportsDownload;
  final bool supportsPause;
  final bool supportsResume;
  final bool supportsCancel;

  /// Whether the driver emits [TransferProgressUpdate] events.
  final bool supportsProgress;

  /// Reserved for OS-level background transfer (WorkManager / NSURLSession).
  /// No built-in driver declares this `true` in version 3.0.0.
  /// Custom drivers that implement background transfer may set this to `true`.
  final bool supportsBackgroundTransfer;

  final bool supportsRetry;
}
