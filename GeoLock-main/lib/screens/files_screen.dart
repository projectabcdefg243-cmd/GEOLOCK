import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/background_service.dart';
import '../services/permission_service.dart';
import '../services/file_service.dart';
import '../models/encryption_metadata.dart';
import '../widgets/file_card_widget.dart';
import 'pdf_viewer_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<String> _encryptedFiles = [];
  bool _isLoading = true;
  bool _isDecrypting = false; // Added missing variable
  final Map<String, EncryptionMetadata?> _metadataCache = {};
  final Map<String, String> _fileSizeCache = {};

  @override
  void initState() {
    super.initState();
    _loadEncryptedFiles();
  }

  Future<void> _loadEncryptedFiles() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await BackgroundService.instance.getEncryptedFiles();
      
      if (!mounted) return;
      
      setState(() {
        _encryptedFiles = files;
        _isLoading = false;
      });

      _preloadMetadata();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load encrypted files: $e');
    }
  }

  Future<void> _preloadMetadata() async {
    final filesToPreload = _encryptedFiles.take(5).toList();
    
    for (final filePath in filesToPreload) {
      if (!_metadataCache.containsKey(filePath)) {
        try {
          final service = BackgroundService.instance;
          final metadata = await service.getFileMetadata(filePath);
          if (mounted) {
            setState(() {
              _metadataCache[filePath] = metadata;
            });
          }
        } catch (e) {
          // Ignore individual file errors
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Files'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: _importEncryptedFile,
            tooltip: 'Import encrypted file',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEncryptedFiles,
            tooltip: 'Refresh files',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _encryptedFiles.isEmpty
              ? _buildEmptyState()
              : _buildFilesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Encrypted Files',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Encrypt your first PDF or import an encrypted file',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/encrypt');
                  },
                  icon: const Icon(Icons.lock),
                  label: const Text('Encrypt PDF'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _importEncryptedFile,
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'How to import encrypted files:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Tap "Import File" to select an encrypted file\n'
                    '2. The file will be validated for location and time constraints\n'
                    '3. You can only decrypt it at the specified location and time\n'
                    '4. Files can be shared via any method (WhatsApp, Email, etc.)',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList() {
    return RefreshIndicator(
      onRefresh: _loadEncryptedFiles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _encryptedFiles.length,
        itemBuilder: (context, index) {
          final filePath = _encryptedFiles[index];
          return _buildFileCard(filePath);
        },
      ),
    );
  }

  Widget _buildFileCard(String filePath) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: FileCardWidget(
        filePath: filePath,
        metadataCache: _metadataCache,
        fileSizeCache: _fileSizeCache,
        onMetadataLoaded: (metadata) {
          // Fixed: Remove the incorrect cast and use the parameter properly
          if (mounted) {
            setState(() {
              _metadataCache[filePath] = metadata;
            });
          }
        },
        onFileSizeLoaded: (size) {
          if (mounted) {
            setState(() {
              _fileSizeCache[filePath] = size;
            });
          }
        },
        onAction: (action, metadata) {
          switch (action) {
            case 'decrypt':
              _navigateToDecrypt();
              break;
            case 'quick_view':
              if (metadata is EncryptionMetadata) {
                _quickDecryptAndView(filePath, metadata);
              }
              break;
            case 'info':
              if (metadata is EncryptionMetadata) {
                _showFileInfo(metadata);
              }
              break;
            case 'share':
              if (metadata is EncryptionMetadata) {
                _shareFile(filePath, metadata);
              }
              break;
            case 'delete':
              _deleteFile(filePath);
              break;
          }
        },
      ),
    );
  }

  void _navigateToDecrypt() {
    Navigator.pushNamed(context, '/decrypt');
  }

  Future<void> _importEncryptedFile() async {
    try {
      if (!await PermissionService.hasStoragePermission()) {
        bool granted = await PermissionService.requestStoragePermission();
        if (!granted) {
          _showError('Storage permission is required to import files. Please grant permission in app settings.');
          return;
        }
      }

      final filePath = await FileService.pickEncryptedFile();
      if (filePath != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Importing encrypted file...'),
              ],
            ),
          ),
        );

        final result = await BackgroundService.instance.validateAndImportFile(filePath);
        
        Navigator.pop(context);

        if (result['success'] == true) {
          _showSuccess('File imported successfully!');
          _loadEncryptedFiles();
        } else {
          _showError('Failed to import file: ${result['error']}');
        }
      }
    } catch (e) {
      // Close dialog if it's still open
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showError('Failed to import file: $e');
    }
  }

  // Fixed: Moved all the methods to the correct place in the class

  Future<void> _quickDecryptAndView(String filePath, EncryptionMetadata metadata) async {
    if (_isDecrypting) return;
    
    setState(() => _isDecrypting = true);
    late BuildContext dialogContext;
    
    try {
      // Show decryption dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          dialogContext = context;
          return _buildDecryptionDialog(metadata.fileName);
        },
      );

      if (!mounted) {
        _isDecrypting = false;
        return;
      }

      // Use background service for decryption
      final result = await BackgroundService.instance.decryptPdf(filePath);
      
      // Close the dialog
      _safePopDialog(dialogContext);

      if (!mounted) {
        setState(() => _isDecrypting = false);
        return;
      }

      if (result['success'] == true) {
        final decryptedPath = result['decryptedPath'];
        final fileName = metadata.fileName;
        
        if (!mounted) {
          setState(() => _isDecrypting = false);
          return;
        }
        
        // Navigate to PDF viewer with quick view mode
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              pdfPath: decryptedPath,
              fileName: fileName,
              isQuickView: true, // Set quick view mode
            ),
          ),
        );
      } else {
        _showError(result['error'] ?? 'Failed to decrypt PDF');
      }
    } catch (e, stackTrace) {
      debugPrint('Quick decrypt error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      _safePopDialog(dialogContext);
      
      if (mounted) {
        _showError(_getUserFriendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isDecrypting = false);
      }
    }
  }

  Widget _buildDecryptionDialog(String fileName) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Decrypting PDF...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            fileName,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'This may take a few moments',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _safePopDialog(BuildContext dialogContext) {
    if (dialogContext.mounted && Navigator.of(dialogContext).mounted) {
      Navigator.of(dialogContext).pop();
    }
  }

  String _getUserFriendlyError(dynamic error) {
    final errorString = error.toString();
    
    if (errorString.contains('FileNotFoundException') || 
        errorString.contains('No such file')) {
      return 'Encrypted file not found. It may have been moved or deleted.';
    } else if (errorString.contains('Invalid key') || 
               errorString.contains('decryption')) {
      return 'Failed to decrypt the file. The encryption key may be invalid.';
    } else if (errorString.contains('Permission denied')) {
      return 'Permission denied. Please check storage permissions.';
    } else if (errorString.contains('timeout') || 
               errorString.contains('TimeoutException')) {
      return 'Decryption timed out. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  void _showFileInfo(EncryptionMetadata metadata) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text('File Information'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('File Name', metadata.fileName, Icons.description),
              _buildInfoRow('Original Path', metadata.originalPath ?? 'Unknown', Icons.folder),
              _buildInfoRow('Encryption Time', _formatDate(metadata.encryptionTime), Icons.access_time),
              if (metadata.validUntil != null)
                _buildInfoRow('Expires', _formatDate(metadata.validUntil!), Icons.timer_off),
              _buildInfoRow('Location', _formatCoordinates(metadata.latitude, metadata.longitude), Icons.location_on),
              _buildInfoRow('Radius', '${metadata.radiusMeters.toStringAsFixed(0)} meters', Icons.radar),
              
              
              const SizedBox(height: 16),
              _buildLocationStatus(metadata),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (metadata.validUntil != null && DateTime.now().isAfter(metadata.validUntil!))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showExpiredWarning();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
              child: const Text('Expired Info'),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStatus(EncryptionMetadata metadata) {
    final isAtLocation = false; // Replace with actual location check
    final isWithinTime = metadata.validUntil == null || 
                        DateTime.now().isBefore(metadata.validUntil!);

    Color getStatusColor() {
      
      if (!isAtLocation && isWithinTime) return Colors.orange;
      return Colors.red;
    }

    String getStatusText() {
      if (isAtLocation && isWithinTime) return 'Ready to decrypt';
      if (!isAtLocation && isWithinTime) return 'Move to required location';
      if (!isWithinTime) return 'Decryption period expired';
      return 'Cannot decrypt';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getStatusColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            (!isAtLocation || !isWithinTime) ? Icons.info : Icons.check_circle,
            color: getStatusColor(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              getStatusText(),
              style: TextStyle(
                color: getStatusColor(),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }


  void _showExpiredWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('File Expired'),
          ],
        ),
        content: const Text(
          'This file can no longer be decrypted because the valid time period has expired. '
          'The file remains encrypted for security.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Fixed: Removed duplicate _formatCoordinates method and kept only this one
  String _formatCoordinates(double lat, double lng) {
    final latDirection = lat >= 0 ? 'N' : 'S';
    final lngDirection = lng >= 0 ? 'E' : 'W';
    return '${lat.abs().toStringAsFixed(6)}°$latDirection, ${lng.abs().toStringAsFixed(6)}°$lngDirection';
  }

  Future<void> _shareFile(String filePath, EncryptionMetadata metadata) async {
    try {
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Check out this encrypted PDF file: "${metadata.fileName}"\n\n'
              'This file can only be decrypted using the GeoLock app at the specified location and time:\n'
              '• Location: ${_formatCoordinates(metadata.latitude, metadata.longitude)}\n'
              '• Radius: ${metadata.radiusMeters.toStringAsFixed(0)} meters\n'
              '• Encrypted: ${_formatDate(metadata.encryptionTime)}\n'
              '${metadata.validUntil != null ? '• Expires: ${_formatDate(metadata.validUntil!)}\n' : ''}'
              '\nDownload GeoLock app to decrypt this file!',
      );
    } catch (e) {
      _showError('Failed to share file: $e');
    }
  }

  Future<void> _deleteFile(String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: const Text('Are you sure you want to delete this encrypted file? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await BackgroundService.instance.deleteFile(filePath);
        if (success) {
          _showSuccess('File deleted successfully');
          _loadEncryptedFiles();
        } else {
          _showError('Failed to delete file');
        }
      } catch (e) {
        _showError('Failed to delete file: $e');
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}