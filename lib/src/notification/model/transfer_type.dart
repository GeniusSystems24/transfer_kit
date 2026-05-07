/// Direction of a transfer for the purposes of notification routing.
///
/// Mirrors `FileTaskType` but is exposed as a stable, notification-only enum
/// so the notification surface is independent of internal transfer types.
enum TransferType { upload, download }
