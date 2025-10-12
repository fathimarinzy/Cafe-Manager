import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/backup_service.dart';
import 'package:intl/intl.dart';
import '../utils/app_localization.dart';

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
  Future<void> _importBackupFromFile() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Use file_picker to select a backup file
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select Backup File'.tr(),
      );

      if (result == null || result.files.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final file = result.files.first;
      String? filePath;

      // Get the file path based on platform
      if (file.path != null) {
        filePath = file.path;
      } else if (file.bytes != null) {
        // For web or if path is null, save bytes to temp file
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/temp_backup.json');
        await tempFile.writeAsBytes(file.bytes!);
        filePath = tempFile.path;
      }

      if (filePath == null) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Could not read backup file'.tr());
        return;
      }

      setState(() {
        _isLoading = false;
      });

      // Show preview of backup before restoring
      await _showBackupPreview(filePath);

    } catch (e) {
      debugPrint('Error importing backup: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error importing backup file'.tr());
    }
  }
  Future<void> _showBackupPreview(String filePath) async {
  try {
    // Read and parse the backup file
    final file = File(filePath);
    final jsonData = await file.readAsString();
    final backupData = jsonDecode(jsonData) as Map<String, dynamic>;

    final timestamp = backupData['timestamp'] as String?;
    final version = backupData['version'] as String?;
    final platform = backupData['platform'] as String?;
    final hasDatabases = backupData.containsKey('databases');
    final hasPreferences = backupData.containsKey('preferences');

    if (!mounted) return;

    // Show preview dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Backup Preview'.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPreviewRow('Date:', timestamp != null 
                ? _formatBackupDate(timestamp) 
                : 'Unknown'.tr()),
              const SizedBox(height: 8),
              _buildPreviewRow('Version:', version ?? 'Unknown'.tr()),
              const SizedBox(height: 8),
              _buildPreviewRow('Platform:', platform ?? 'Unknown'.tr()),
              const SizedBox(height: 8),
              _buildPreviewRow('Contains:', 
                hasDatabases 
                  ? 'Full backup (Settings + Data)'.tr() 
                  : hasPreferences 
                    ? 'Settings only'.tr() 
                    : 'Unknown'.tr()),
              const Divider(height: 24),
              Text(
                'Restoring will overwrite all current data. This action cannot be undone.'.tr(),
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
            child: Text('Restore'.tr()),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _restoreBackup(filePath);
    }
  } catch (e) {
    debugPrint('Error previewing backup: $e');
    if (mounted) {
      _showErrorSnackBar('Invalid backup file'.tr());
    }
  }
}
Widget _buildPreviewRow(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 80,
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    ],
  );
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
      
      _showErrorSnackBar('Error loading backups'.tr());
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
        _showSuccessSnackBar('Backup created successfully'.tr());
        _loadBackups();
      } else {
        _showErrorSnackBar('Failed to create backup'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error creating backup'.tr());
    }
  }
  
  Future<void> _restoreBackup(String backupPath) async {
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Restore'.tr()),
        content: Text(
          'Restoring will overwrite all current data with the selected backup. This action cannot be undone. Are you sure you want to continue?'.tr()
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Restore'.tr()),
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
        _showSuccessSnackBar('Restore completed successfully'.tr());
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('Restart Required'.tr()),
              content: Text(
                'The app needs to be restarted to apply the restored settings. Please close and reopen the app.'.tr()
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'.tr()),
                ),
              ],
            ),
          );
        }
      } else {
        _showErrorSnackBar('Failed to restore backup'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error restoring backup'.tr());
    }
  }
  
  Future<void> _deleteBackup(String backupPath) async {
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'.tr()),
        content: Text(
          'Are you sure you want to delete this backup? This action cannot be undone.'.tr()
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Delete'.tr()),
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
        _showSuccessSnackBar('Backup deleted successfully'.tr());
        _loadBackups();
      } else {
        _showErrorSnackBar('Failed to delete backup'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error deleting backup'.tr());
    }
  }
  
  Future<void> _deleteOldBackups() async {
    final days = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Old Backups'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete backups older than:'.tr()),
            const SizedBox(height: 16),
            ListTile(
              title: Text('7 days'.tr()),
              onTap: () => Navigator.of(context).pop(7),
            ),
            ListTile(
              title: Text('30 days'.tr()),
              onTap: () => Navigator.of(context).pop(30),
            ),
            ListTile(
              title: Text('90 days'.tr()),
              onTap: () => Navigator.of(context).pop(90),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'.tr()),
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

      _showSuccessSnackBar('${'Deleted'.tr()} $deletedCount ${'old backup(s)'.tr()}');
      _loadBackups();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error deleting old backups'.tr());
    }
  }
  
  Future<void> _keepRecentBackups() async {
    final keepCount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Keep Recent Backups'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Keep only the most recent:'.tr()),
            const SizedBox(height: 16),
            ListTile(
              title: Text('3 backups'.tr()),
              onTap: () => Navigator.of(context).pop(3),
            ),
            ListTile(
              title: Text('5 backups'.tr()),
              onTap: () => Navigator.of(context).pop(5),
            ),
            ListTile(
              title: Text('10 backups'.tr()),
              onTap: () => Navigator.of(context).pop(10),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'.tr()),
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
      
      _showSuccessSnackBar('${'Kept'.tr()} $keepCount ${'recent backup(s), deleted'.tr()} $deletedCount');
      _loadBackups();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error managing backups'.tr());
    }
  }
  
  Future<void> _shareBackup(String backupPath) async {
    try {
      final success = await BackupService.shareBackup(backupPath);
      
      if (!success) {
        _showErrorSnackBar('Failed to share backup'.tr());
      }
    } catch (e) {
      _showErrorSnackBar('Error sharing backup'.tr());
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
        _showSuccessSnackBar('Backup exported to: $exportPath'.tr());
      } else {
        _showErrorSnackBar('Failed to export backup'.tr());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error exporting backup'.tr());
    }
  }
  
  Future<void> _exportBackupToGoogleDrive(String backupPath) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await BackupService.exportBackupToGoogleDrive(backupPath);
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success'] == true) {
        _showSuccessSnackBar('Backup exported to Google Drive'.tr());
      } else {
        final error = result['error'] ?? 'Unknown error';
        _showErrorSnackBar('Failed to export to Google Drive: $error'.tr());
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error exporting to Google Drive'.tr());
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
              title: Text('Restore from this backup'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _restoreBackup(backupPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text('Share backup'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _shareBackup(backupPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text('Export to Downloads folder'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _exportBackupToDownloads(backupPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: Text('Export to Google Drive'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _exportBackupToGoogleDrive(backupPath);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete backup'.tr(), style: const TextStyle(color: Colors.red)),
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
              title: Text('Delete old backups'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _deleteOldBackups();
              },
            ),
            ListTile(
              leading: const Icon(Icons.filter_list),
              title: Text('Keep only recent backups'.tr()),
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  
  String _formatBackupDate(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy - HH:mm').format(date);
    } catch (e) {
      return 'Unknown date'.tr();
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
  
  Future<void> _loadGoogleDriveBackups() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingDriveBackups = true;
    });
    
    try {
      final result = await BackupService.getGoogleDriveBackups();
      
      if (!mounted) return;
      
      setState(() {
        if (result['success'] == true) {
          _driveBackups = List<Map<String, dynamic>>.from(result['backups'] ?? []);
        } else {
          _driveBackups = [];
          final error = result['error'] ?? 'Unknown error';
          _showErrorSnackBar('Error loading Google Drive backups: $error'.tr());
        }
        _isLoadingDriveBackups = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingDriveBackups = false;
      });
      
      _showErrorSnackBar('Error loading Google Drive backups'.tr());
    }
  }
  
  Future<void> _restoreFromGoogleDrive(String fileId) async {
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Restore from Google Drive'.tr()),
        content: Text(
          'Restoring will download the backup from Google Drive and overwrite all current data. This action cannot be undone. Are you sure you want to continue?'.tr()
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Restore'.tr()),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed || !mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await BackupService.restoreFromGoogleDrive(fileId);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success'] == true) {
        _showSuccessSnackBar('Restore from Google Drive completed successfully'.tr());
        
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('Restart Required'.tr()),
              content: Text(
                'The app needs to be restarted to apply the restored settings. Please close and reopen the app.'.tr()
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('OK'.tr()),
                ),
              ],
            ),
          );
        }
      } else {
        final error = result['error'] ?? 'Unknown error';
        _showErrorSnackBar('Failed to restore from Google Drive: $error'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error restoring from Google Drive'.tr());
    }
  }

  void _showDriveBackupOptions(Map<String, dynamic> backup) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore),
              title: Text('Restore from this Google Drive backup'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _restoreFromGoogleDrive(backup['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text('Download to device'.tr()),
              onTap: () {
                Navigator.of(context).pop();
                _downloadDriveBackup(backup['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete from Google Drive'.tr(), style: const TextStyle(color: Colors.red)),
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
  
  Future<void> _deleteGoogleDriveBackup(String fileId) async {
    if (!mounted) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete'.tr()),
        content: Text(
          'Are you sure you want to delete this backup from Google Drive? This action cannot be undone.'.tr()
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    ) ?? false;
    
    if (!confirmed || !mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await BackupService.deleteBackupFromDrive(fileId);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success'] == true) {
        _showSuccessSnackBar('Backup deleted from Google Drive'.tr());
        _loadGoogleDriveBackups();
      } else {
        final error = result['error'] ?? 'Unknown error';
        _showErrorSnackBar('Failed to delete backup from Google Drive: $error'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error deleting backup'.tr());
    }
  }
  
  Future<void> _downloadDriveBackup(String fileId) async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final result = await BackupService.downloadBackupFromDrive(fileId);
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      if (result['success'] == true) {
        _showSuccessSnackBar('Backup downloaded from Google Drive'.tr());
        _loadBackups();
      } else {
        final error = result['error'] ?? 'Unknown error';
        _showErrorSnackBar('Failed to download backup from Google Drive: $error'.tr());
      }
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      _showErrorSnackBar('Error downloading backup'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Backup & Restore'.tr()),
        actions: [
          // Import button - now properly connected!
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import Backup'.tr(),
            onPressed: _importBackupFromFile,
          ),

          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showManageBackupsOptions,
          ),
        ],
      ),
      body: Column(
        children: [
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
                    child: Text('Device Backups'.tr()),
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
                    child: Text('Google Drive'.tr()),
                  ),
                ),
              ],
            ),
          ),
          
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

  Widget _buildDriveBackupsList() {
    if (_isLoadingDriveBackups) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_driveBackups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No backups found on Google Drive'.tr(),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text('Refresh'.tr()),
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

  Widget _buildLocalBackupsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_backups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backup, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No local backups found'.tr(),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create a backup'.tr(),
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      itemCount: _backups.length,
      itemBuilder: (context, index) {
        final backup = _backups[index];
        final path = backup['path'] as String;
        final timestamp = backup['timestamp'] as String;
        final version = backup['version'] as String? ?? 'Unknown';
        final platform = backup['platform'] as String? ?? 'Unknown';
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
                        hasDatabases ? Icons.storage : Icons.settings,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        hasDatabases
                            ? '${'Full backup'.tr()} (v$version)'
                            : '${'Settings only'.tr()} (v$version)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (platform != 'Unknown') ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            platform,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
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