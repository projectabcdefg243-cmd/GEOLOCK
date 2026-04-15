import 'package:flutter/material.dart';
import 'dart:io';
import 'pdf_viewer_screen.dart';
import '../services/file_service.dart';

class SavedFilesScreen extends StatefulWidget {
  const SavedFilesScreen({super.key});

  @override
  State<SavedFilesScreen> createState() => _SavedFilesScreenState();
}

class _SavedFilesScreenState extends State<SavedFilesScreen> {
  List<String> _savedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedFiles();
  }

  Future<void> _loadSavedFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final files = await FileService.getSavedFiles();
      setState(() {
        _savedFiles = files;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load saved files: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Files'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedFiles,
            tooltip: 'Refresh files',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedFiles.isEmpty
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
              'No Saved Files',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Decrypt files and save them here for quick access.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList() {
    return RefreshIndicator(
      onRefresh: _loadSavedFiles,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _savedFiles.length,
        itemBuilder: (context, index) {
          final filePath = _savedFiles[index];
          final fileName = filePath.split('/').last;
          final file = File(filePath);

          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: Text(fileName),
              subtitle: FutureBuilder<String>(
                future: _getFileInfo(file),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(snapshot.data!);
                  }
                  return const Text('Loading file info...');
                },
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _handleAction(value, filePath, fileName),
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem(
                    value: 'open',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new),
                        SizedBox(width: 8),
                        Text('Open'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share),
                        SizedBox(width: 8),
                        Text('Share'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
              ),
              onTap: () => _openFile(filePath, fileName),
            ),
          );
        },
      ),
    );
  }

  Future<String> _getFileInfo(File file) async {
    try {
      final stat = await file.stat();
      final size = await _formatFileSize(stat.size);
      final modified = _formatDate(stat.modified);
      return 'Size: $size • Modified: $modified';
    } catch (e) {
      return 'Error getting file info';
    }
  }

  Future<String> _formatFileSize(int bytes) async {
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size > 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _handleAction(String action, String filePath, String fileName) async {
    switch (action) {
      case 'open':
        _openFile(filePath, fileName);
        break;
      case 'share':
        await FileService.shareFile(filePath);
        break;
      case 'delete':
        _deleteFile(filePath);
        break;
    }
  }

  void _openFile(String filePath, String fileName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          pdfPath: filePath,
          fileName: fileName,
        ),
      ),
    );
  }

  Future<void> _deleteFile(String filePath) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: const Text('Are you sure you want to delete this file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await File(filePath).delete();
        _showSuccess('File deleted successfully');
        _loadSavedFiles();
      } catch (e) {
        _showError('Failed to delete file: $e');
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}