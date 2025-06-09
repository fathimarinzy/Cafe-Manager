/// Enum to represent the status of a sync operation
enum SyncStatus {
  idle,       // No sync in progress
  syncing,    // Sync is currently in progress
  completed,  // Sync completed successfully
  error,      // Sync encountered an error
}

// Extension methods to get readable status strings
extension SyncStatusExtension on SyncStatus {
  String get displayName {
    switch (this) {
      case SyncStatus.idle:
        return 'Idle';
      case SyncStatus.syncing:
        return 'Syncing';
      case SyncStatus.completed:
        return 'Completed';
      case SyncStatus.error:
        return 'Error';
    }
  }
}