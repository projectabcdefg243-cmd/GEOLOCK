import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

import 'saved_files_screen.dart';


class PdfViewerScreen extends StatefulWidget {
  final String pdfPath;
  final String fileName;
  final bool isQuickView;

  const PdfViewerScreen({
    super.key,
    required this.pdfPath,
    required this.fileName,
    this.isQuickView = false,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

// ignore_for_file: use_build_context_synchronously
class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _currentPage = 0;
  int _totalPages = 0;
  PDFViewController? _pdfController;
  bool _isDisposed = false;
  bool _isFileSaved = false;

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<String> _getTargetFilePath() async {
    final savedFilesDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${savedFilesDir.path}/saved_pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }
    return '${pdfDir.path}/${widget.fileName}';
  }

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  @override
  void dispose() {
    _isDisposed = true;
    try {
      // First dispose of the controller to release platform view resources
      _pdfController?.dispose();
      
      // Schedule cleanup for after dispose if needed
      if (widget.isQuickView || !_isFileSaved) {
        // Use a delayed future to ensure cleanup happens after disposal
        Future.delayed(Duration.zero, () async {
          await _cleanupTempFile();
        });
      }
    } catch (e) {
      debugPrint('Error in dispose: $e');
    } finally {
      super.dispose();
    }
  }

  Future<void> _savePdfToLibrary() async {
    try {
      if (!mounted) return;

      final file = File(widget.pdfPath);
      if (!await file.exists()) {
        _showError('Cannot save: Source file not found');
        return;
      }

      final targetPath = await _getTargetFilePath();
      
      // Check if we're already using the target path
      if (widget.pdfPath == targetPath) {
        setState(() => _isFileSaved = true);
        _showSuccess('File is already saved in library');
        return;
      }

      final savedPath = targetPath;

      // Check if file already exists in the saved directory
      if (await File(savedPath).exists()) {
        final shouldOverwrite = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('File Already Exists'),
            content: Text('A file named "${widget.fileName}" already exists. Do you want to replace it?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        );

        if (shouldOverwrite != true) return;
      }

      // Copy the file to saved directory
      await file.copy(savedPath);
      
      if (!mounted) return;
      setState(() => _isFileSaved = true);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PDF saved to library'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SavedFilesScreen()),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Error saving file: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _cleanupTempFile() async {
    try {
      final targetPath = await _getTargetFilePath();
      final currentFile = File(widget.pdfPath);
      
      // Don't delete if:
      // 1. File is already in saved_pdfs directory
      // 2. File has been saved (_isFileSaved is true)
      // 3. Current path matches target save path
      if (!_isFileSaved && 
          widget.pdfPath != targetPath &&
          await currentFile.exists()) {
        await currentFile.delete();
        debugPrint('Cleaned up temp file: ${widget.pdfPath}');
      }
    } catch (e) {
      debugPrint('Error cleaning up temp file: $e');
    }
  }

  Future<void> _initPdf() async {
    if (_isDisposed) return;

    try {
      final file = File(widget.pdfPath);
      if (!await file.exists()) {
        _setError('PDF file not found');
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _setError('PDF file is empty');
        return;
      }

      // Check if it's a valid PDF by looking at the header
      if (bytes.length < 5 || 
          bytes[0] != 0x25 || // %
          bytes[1] != 0x50 || // P
          bytes[2] != 0x44 || // D
          bytes[3] != 0x46) { // F
        _setError('Invalid PDF file format');
        return;
      }

      if (!_isDisposed) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _setError('Error loading PDF: $e');
    }
  }

  void _setError(String message) {
    if (!_isDisposed) {
      setState(() {
        _hasError = true;
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  void _onPdfViewCreated(PDFViewController controller) {
    if (!_isDisposed) {
      setState(() {
        _pdfController = controller;
      });
    }
  }

  void _onPdfRender(int? total) {
    if (!_isDisposed) {
      setState(() {
        _totalPages = total ?? 0;
        _isLoading = false;
      });
    }
  }

  void _onPageChanged(int? page, int? total) {
    if (!_isDisposed) {
      setState(() {
        _currentPage = page ?? 0;
        if (total != null) {
          _totalPages = total;
        }
      });
    }
  }

  void _onPdfError(dynamic error) {
    _setError('Error loading PDF: $error');
  }

  void _onPageError(int? page, dynamic error) {
    debugPrint('Error on page ${page ?? 'unknown'}: $error');
  }

  Future<void> _shareFile() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.pdfPath)],
        subject: widget.fileName,
      );
    } catch (e) {
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing file: $e')),
        );
      }
    }
  }

  Future<void> _deleteFile() async {
    try {
      final file = File(widget.pdfPath);
      if (await file.exists()) {
        await file.delete();
        if (!_isDisposed) {
          Navigator.of(context).pop(true); // Return true to indicate deletion
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting file: $e')),
        );
      }
    }
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading PDF...'),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading PDF',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            if (!widget.isQuickView)
              ElevatedButton(
                onPressed: _initPdf,
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageInfo() {
    if (_totalPages <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Page ${_currentPage + 1} of $_totalPages',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        centerTitle: true,
        actions: [
          
          if (!widget.isQuickView) ...[
            IconButton(
            onPressed: _shareFile,
            icon: const Icon(Icons.share),
            tooltip: 'Share file',
          ),
            IconButton(
              onPressed: _isFileSaved ? null : _savePdfToLibrary,
              icon: Icon(_isFileSaved ? Icons.save : Icons.save_outlined),
              tooltip: _isFileSaved ? 'Saved to library' : 'Save to library',
            ),
            IconButton(
              onPressed: _deleteFile,
              icon: const Icon(Icons.delete),
              tooltip: 'Delete file',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return _buildErrorWidget();
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        RepaintBoundary(
          child: PDFView(
            filePath: widget.pdfPath,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false, // Disable auto spacing to reduce memory usage
            pageFling: true,
            defaultPage: _currentPage,
            fitPolicy: FitPolicy.BOTH, // Use BOTH to prevent excessive scaling
            preventLinkNavigation: true,
            onRender: _onPdfRender,
            onViewCreated: _onPdfViewCreated,
            onPageChanged: _onPageChanged,
            onError: _onPdfError,
            onPageError: _onPageError,
            gestureRecognizers: const {},
            key: ValueKey(widget.pdfPath),
            pageSnap: true
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.white,
            child: _buildLoadingWidget(),
          ),
        if (!_isLoading && !_hasError)
          Positioned(
            bottom: 16,
            child: _buildPageInfo(),
          ),
      ],
    );
  }
}