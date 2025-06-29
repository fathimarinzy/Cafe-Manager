import 'package:flutter/material.dart';
import '../services/backup_service.dart';
import 'package:intl/intl.dart';

class BackupManagerWidget extends StatefulWidget {
  const BackupManagerWidget({super.key});

  @override
  State<BackupManagerWidget> createState() => _BackupManagerWidgetState();
}

class _BackupManagerWidgetState extends State<BackupManagerWidget> {
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = false;
  bool _isLoadingDriveBackups = false;
List<Map<String, dynamic>> _driveBackups = [];
bool _showDriveBackups = false;
  
  @override
  void initState() {
    super.initState();
    _loadBackups();
  }
  
  Future<void> _loadBackups() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final backups = await BackupService.getAvailableBackups();
      
      if (!mounted) return;
      
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error loading backups: $e');
    }
  }
  
  Future<void> _createBackup() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final backupPath = await BackupService.backupData();
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (backupPath != null) {
        _showSuccessSnackBar('Backup created successfully');
        _loadBackups(); // Refresh the list
      } else {
        _showErrorSnackBar('Failed to create backup');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error creating backup: $e');
    }
  }
  
  Future<void> _restoreBackup(String backupPath) async {
    if (!mounted) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Restore'),
        content: const Text(
          'Restoring will overwrite all current data with the selected backup.\n '
          'This action cannot be undone. Are you sure you want to continue?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed || !mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await BackupService.restoreData(backupPath);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        _showSuccessSnackBar('Restore completed successfully');
        
        // Show restart app dialog
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Restart Required'),
              content: const Text(
                'The app needs to be restarted to apply the restored settings.\n'
                'Please close and reopen the app.'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        _showErrorSnackBar('Failed to restore backup');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error restoring backup: $e');
    }
  }
  
  Future<void> _deleteBackup(String backupPath) async {
    if (!mounted) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text(
          'Are you sure you want to delete this backup? \n'
          'This action cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed || !mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await BackupService.deleteBackup(backupPath);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        _showSuccessSnackBar('Backup deleted successfully');
        _loadBackups(); // Refresh the list
      } else {
        _showErrorSnackBar('Failed to delete backup');
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error deleting backup: $e');
    }
  }
  
  Future<void> _deleteOldBackups() async {
    // Show confirmation dialog with options
    final days = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Old Backups'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delete backups older than:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('7 days'),
              onTap: () => Navigator.of(context).pop(7),
            ),
            ListTile(
              title: const Text('30 days'),
              onTap: () => Navigator.of(context).pop(30),
            ),
            ListTile(
              title: const Text('90 days'),
              onTap: () => Navigator.of(context).pop(90),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (days == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final deletedCount = await BackupService.deleteOldBackups(olderThanDays: days);
      
      setState(() {
        _isLoading = false;
      });
      
      _showSuccessSnackBar('Deleted $deletedCount old backup(s)');
      _loadBackups(); // Refresh the list
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error deleting old backups: $e');
    }
  }
  
  Future<void> _keepRecentBackups() async {
    // Show dialog to select how many recent backups to keep
    final keepCount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep Recent Backups'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Keep only the most recent:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('3 backups'),
              onTap: () => Navigator.of(context).pop(3),
            ),
            ListTile(
              title: const Text('5 backups'),
              onTap: () => Navigator.of(context).pop(5),
            ),
            ListTile(
              title: const Text('10 backups'),
              onTap: () => Navigator.of(context).pop(10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (keepCount == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final deletedCount = await BackupService.keepRecentBackups(keepCount);
      
      setState(() {
        _isLoading = false;
      });
      
      _showSuccessSnackBar('Kept $keepCount recent backup(s), deleted $deletedCount');
      _loadBackups(); // Refresh the list
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error managing backups: $e');
    }
  }
  
  Future<void> _shareBackup(String backupPath) async {
    try {
      final success = await BackupService.shareBackup(backupPath);
      
      if (!success) {
        _showErrorSnackBar('Failed to share backup');
      }
    } catch (e) {
      _showErrorSnackBar('Error sharing backup: $e');
    }
  }
  
  Future<void> _exportBackupToDownloads(String backupPath) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final exportPath = await BackupService.exportBackupToDownloads(backupPath);
      
      setState(() {
        _isLoading = false;
      });
      
      if (exportPath != null) {
        _showSuccessSnackBar('Backup exported to Downloads folder');
      } else {
        _showErrorSnackBar('Failed to export backup');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error exporting backup: $e');
    }
  }
  
  Future<void> _exportBackupToGoogleDrive(String backupPath) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final success = await BackupService.exportBackupToGoogleDrive(backupPath);
      
      setState(() {
        _isLoading = false;
      });
      
      if (success) {
        _showSuccessSnackBar('Backup exported to Google Drive');
      } else {
        _showErrorSnackBar(
          'Failed to export to Google Drive.\n'
          'Note: Google Drive export requires additional setup.'
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error exporting to Google Drive: $e');
    }
  }
  
  void _showBackupOptions(String backupPath) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore from this backup'),
              onTap: () {
                Navigator.of(context).pop();
                _restoreBackup(backupPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share backup'),
              onTap: () {
                Navigator.of(context).pop();
                _shareBackup(backupPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Export to Downloads folder'),
              onTap: () {
                Navigator.of(context).pop();
                _exportBackupToDownloads(backupPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Export to Google Drive'),
              onTap: () {
                Navigator.of(context).pop();
                _exportBackupToGoogleDrive(backupPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete backup', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _deleteBackup(backupPath);
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showManageBackupsOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('Delete old backups'),
              onTap: () {
                Navigator.of(context).pop();
                _deleteOldBackups();
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_list),
              title: const Text('Keep only recent backups'),
              onTap: () {
                Navigator.of(context).pop();
                _keepRecentBackups();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  String _formatBackupDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy - HH:mm').format(date);
    } catch (e) {
      return 'Unknown date';
    }
  }
  
  String _formatBackupSize(int size) {
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
  // Add this method to load Google Drive backups
Future<void> _loadGoogleDriveBackups() async {
  if (!mounted) return;
  
  setState(() {
    _isLoadingDriveBackups = true;
  });
  
  try {
    final backups = await BackupService.getGoogleDriveBackups();
    
    if (!mounted) return;
    
    setState(() {
      _driveBackups = backups;
      _isLoadingDriveBackups = false;
    });
  } catch (e) {
    if (!mounted) return;
    
    setState(() {
      _isLoadingDriveBackups = false;
    });
    
    _showErrorSnackBar('Error loading Google Drive backups: $e');
  }
}
// Add this method to restore from Google Drive
Future<void> _restoreFromGoogleDrive(String fileId) async {
  if (!mounted) return;
  
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Restore from Google Drive'),
      content: const Text(
        'Restoring will download the backup from Google Drive and '
        'overwrite all current data. This action cannot be undone.\n'
        'Are you sure you want to continue?'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('Restore'),
        ),
      ],
    ),
  ) ?? false;
  
  if (!confirmed || !mounted) return;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    final success = await BackupService.restoreFromGoogleDrive(fileId);
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
    
    if (success) {
      _showSuccessSnackBar('Restore from Google Drive completed successfully');
      
      // Show restart app dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Restart Required'),
            content: const Text(
              'The app needs to be restarted to apply the restored settings.\n '
              'Please close and reopen the app.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } else {
      _showErrorSnackBar('Failed to restore from Google Drive');
    }
  } catch (e) {
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
    
    _showErrorSnackBar('Error restoring from Google Drive: $e');
  }
}


// Add this method to show Drive backup options
void _showDriveBackupOptions(Map<String, dynamic> backup) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore from this Google Drive backup'),
            onTap: () {
              Navigator.of(context).pop();
              _restoreFromGoogleDrive(backup['id']);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download to device'),
            onTap: () {
              Navigator.of(context).pop();
              _downloadDriveBackup(backup['id']);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete from Google Drive', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.of(context).pop();
              _deleteGoogleDriveBackup(backup['id']);
            },
          ),
        ],
      ),
    ),
  );
}
// Add this method to delete a backup from Google Drive
Future<void> _deleteGoogleDriveBackup(String fileId) async {
  if (!mounted) return;
  
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirm Delete'),
      content: const Text(
        'Are you sure you want to delete this backup from Google Drive?\n '
        'This action cannot be undone.'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  ) ?? false;
  
  if (!confirmed || !mounted) return;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    final success = await BackupService.deleteBackupFromDrive(fileId);
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
    
    if (success) {
      _showSuccessSnackBar('Backup deleted from Google Drive');
      _loadGoogleDriveBackups(); // Refresh the Drive backups list
    } else {
      _showErrorSnackBar('Failed to delete backup from Google Drive');
    }
  } catch (e) {
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
    
    _showErrorSnackBar('Error deleting backup: $e');
  }
}
// Add this method to download a backup from Drive
Future<void> _downloadDriveBackup(String fileId) async {
  if (!mounted) return;
  
  setState(() {
    _isLoading = true;
  });
  
  try {
    final localPath = await BackupService.downloadBackupFromDrive(fileId);
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
    
    if (localPath != null) {
      _showSuccessSnackBar('Backup downloaded from Google Drive');
      _loadBackups(); // Refresh local backup list
    } else {
      _showErrorSnackBar('Failed to download backup from Google Drive');
    }
  } catch (e) {
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });
    
    _showErrorSnackBar('Error downloading backup: $e');
  }
}
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Backup & Restore'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showManageBackupsOptions,
        ),
      ],
    ),
    body: Column(
      children: [
        // Add toggle buttons for local/drive backups
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showDriveBackups = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_showDriveBackups ? Colors.blue : Colors.grey.shade300,
                    foregroundColor: !_showDriveBackups ? Colors.white : Colors.black87,
                  ),
                  child: const Text('Device Backups'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showDriveBackups = true;
                      if (_driveBackups.isEmpty) {
                        _loadGoogleDriveBackups();
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showDriveBackups ? Colors.blue : Colors.grey.shade300,
                    foregroundColor: _showDriveBackups ? Colors.white : Colors.black87,
                  ),
                  child: const Text('Google Drive'),
                ),
              ),
            ],
          ),
        ),
        
        // Show appropriate backup list based on toggle
        Expanded(
          child: _showDriveBackups
              ? _buildDriveBackupsList()
              : _buildLocalBackupsList(),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _createBackup,
      child: const Icon(Icons.backup),
    ),
  );
}

// Add this method to build the Drive backups list
Widget _buildDriveBackupsList() {
  if (_isLoadingDriveBackups) {
    return const Center(child: CircularProgressIndicator());
  }
  
  if (_driveBackups.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('No backups found on Google Drive'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            onPressed: _loadGoogleDriveBackups,
          ),
        ],
      ),
    );
  }
  
  return ListView.builder(
    itemCount: _driveBackups.length,
    itemBuilder: (context, index) {
      final backup = _driveBackups[index];
      final id = backup['id'] as String; // Use 'id' instead of 'fileId'
      final name = backup['name'] as String;
      final timestamp = backup['timestamp'] as String;
      final size = backup['size'] as int? ?? 0;
      
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: () => _showDriveBackupOptions(backup),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatBackupDate(timestamp),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _formatBackupSize(size),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.cloud,
                      size: 16,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Rename the existing backup list method to _buildLocalBackupsList
Widget _buildLocalBackupsList() {
  if (_backups.isEmpty) {
    return Center(
      child: _isLoading
          ? const CircularProgressIndicator()
          : const Text('No local backups found'),
    );
  }
  
  return ListView.builder(
    itemCount: _backups.length,
    itemBuilder: (context, index) {
      final backup = _backups[index];
      final path = backup['path'] as String;
      final timestamp = backup['timestamp'] as String;
      final version = backup['version'] as String? ?? 'Unknown';
      final hasDatabases = backup['has_databases'] as bool? ?? false;
      final size = backup['size'] as int? ?? 0;
      
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: () => _showBackupOptions(path),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatBackupDate(timestamp),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      _formatBackupSize(size),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      hasDatabases
                          ? Icons.storage
                          : Icons.settings,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasDatabases
                          ? 'Full backup (v$version)'
                          : 'Settings only (v$version)',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
  
}