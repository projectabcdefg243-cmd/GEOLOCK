
import 'package:flutter/material.dart';
import '../services/background_service.dart';
import '../services/location_service.dart';
import '../services/file_service.dart';
import '../models/encryption_metadata.dart';
import 'pdf_viewer_screen.dart';

class DecryptScreen extends StatefulWidget {
  const DecryptScreen({super.key});

  @override
  State<DecryptScreen> createState() => _DecryptScreenState();
}

class _DecryptScreenState extends State<DecryptScreen> {
  List<String> _encryptedFiles = [];
  bool _isLoading = true;
  bool _isDecrypting = false;

  final ValueNotifier<List<String>> _filesNotifier = ValueNotifier<List<String>>([]);
  final ValueNotifier<bool> _loadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _decryptingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _loadEncryptedFiles();
  }

  @override
  void dispose() {
    _filesNotifier.dispose();
    _loadingNotifier.dispose();
    _decryptingNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadEncryptedFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await BackgroundService.instance.getEncryptedFiles();
      setState(() {
        _encryptedFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load encrypted files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decrypt PDF'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEncryptedFiles,
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
              'No encrypted PDF files found. Encrypt some files first to see them here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/encrypt');
              },
              icon: const Icon(Icons.lock),
              label: const Text('Encrypt Files'),
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
      child: FutureBuilder<EncryptionMetadata?>(
        future: FileService.getFileMetadata(filePath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Loading...'),
            );
          }

          final metadata = snapshot.data;
          if (metadata == null) {
            return ListTile(
              leading: const Icon(Icons.error, color: Colors.red),
              title: const Text('Invalid File'),
              subtitle: const Text('Unable to read file metadata'),
            );
          }

          return ExpansionTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: Text(
              metadata.fileName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Encrypted: ${_formatDate(metadata.encryptionTime)}'),
                if (metadata.validUntil != null)
                  Text('Expires: ${_formatDate(metadata.validUntil!)}'),
                Text('Location: ${LocationService.formatCoordinates(metadata.latitude, metadata.longitude)}'),
                Text('Radius: ${metadata.radiusMeters.toStringAsFixed(0)}m'),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildLocationInfo(metadata),
                    const SizedBox(height: 16),
                    _buildDecryptButton(filePath, metadata),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLocationInfo(EncryptionMetadata metadata) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Decryption Requirements:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text('• Must be within ${metadata.radiusMeters.toStringAsFixed(0)}m of encryption location'),
          Text('• Current location: ${LocationService.currentPosition != null ? LocationService.formatCoordinates(LocationService.currentPosition!.latitude, LocationService.currentPosition!.longitude) : 'Unknown'}'),
          if (metadata.validUntil != null)
            Text('• Must decrypt before ${_formatDate(metadata.validUntil!)}'),
        ],
      ),
    );
  }

  Widget _buildDecryptButton(String filePath, EncryptionMetadata metadata) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isDecrypting ? null : () => _decryptFile(filePath),
        icon: _isDecrypting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock_open),
        label: Text(_isDecrypting ? 'Decrypting...' : 'Decrypt PDF'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _decryptFile(String filePath) async {
    setState(() {
      _isDecrypting = true;
    });

    try {
      // Use background service for decryption
      final service = BackgroundService.instance;
      final result = await service.decryptPdf(filePath);
      
      setState(() {
        _isDecrypting = false;
      });

      if (result['success']) {
        _showSuccess('PDF decrypted successfully!');
        _showDecryptedFileDialog(result['decryptedPath']);
      } else {
        _showError(result['error'] ?? 'Failed to decrypt PDF');
      }
    } catch (e) {
      setState(() {
        _isDecrypting = false;
      });
      _showError('Failed to decrypt PDF: $e');
    }
  }

  void _showDecryptedFileDialog(String decryptedPath) {
    final fileName = decryptedPath.split('/').last;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decryption Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The PDF has been decrypted and saved to:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                decryptedPath,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                // First save the file to the library
                await FileService.savePdfFile(decryptedPath, fileName);
                _showSuccess('PDF saved to library');
                Navigator.pop(context);
               
              } catch (e) {
                _showError('Failed to save PDF: $e');
              }
            },
            icon: const Icon(Icons.save),
            label: const Text('Save the PDF'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                // First save the file to the library
               
                Navigator.pop(context);
                
                // Then open it from the saved location
                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PdfViewerScreen(
                      pdfPath: decryptedPath,
                      fileName: fileName,
                      isQuickView: false, // This is now a permanent file
                    ),
                  ),
                );
              } catch (e) {
                _showError('Failed to save PDF: $e');
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open the PDF'),
          ),
        ],
      ),
    );
  }

  // void _openPdfInApp(String pdfPath, String fileName) async {
  //   try {
  //     // Verify file exists and is readable
  //     final file = File(pdfPath);
  //     if (!await file.exists()) {
  //       _showError('PDF file not found');
  //       return;
  //     }

  //     final size = await file.length();
  //     if (size == 0) {
  //       _showError('PDF file is empty');
  //       return;
  //     }
      
  //     // Verify file is actually a PDF
  //     final bytes = await file.openRead(0, 4).toList();
  //     final header = bytes.isNotEmpty ? bytes[0] : [];
  //     if (header.length < 4 || 
  //         header[0] != 0x25 || // %
  //         header[1] != 0x50 || // P
  //         header[2] != 0x44 || // D
  //         header[3] != 0x46) { // F
  //       _showError('Invalid PDF file format');
  //       return;
  //     }

  //     if (!mounted) return;

  //     // Always save the PDF before viewing
  //     final savedPath = await FileService.savePdfFile(pdfPath, fileName);
      
  //     if (!mounted) return;
  //     await Navigator.push(
  //       context,
  //       MaterialPageRoute(
  //         builder: (context) => PdfViewerScreen(
  //           pdfPath: savedPath,
  //           fileName: fileName,
  //           isQuickView: false, // This is a permanent file
  //         ),
  //       ),
  //     );
  //   } catch (e) {
  //     _showError('Error opening PDF: $e');
  //   }
  // }

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
