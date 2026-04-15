import 'package:flutter/material.dart';
import '../services/background_service.dart';
import '../models/encryption_metadata.dart';

class FileCardWidget extends StatefulWidget {
  final String filePath;
  final Map<String, EncryptionMetadata?> metadataCache;
  final Map<String, String> fileSizeCache;
  final Function(EncryptionMetadata?) onMetadataLoaded;
  final Function(String) onFileSizeLoaded;
  final Function(String, EncryptionMetadata?) onAction;

  const FileCardWidget({
    required this.filePath,
    required this.metadataCache,
    required this.fileSizeCache,
    required this.onMetadataLoaded,
    required this.onFileSizeLoaded,
    required this.onAction,
  });

  @override
  State<FileCardWidget> createState() => _FileCardWidgetState();
}

class _FileCardWidgetState extends State<FileCardWidget> {
  bool _isLoadingMetadata = false;
  bool _isLoadingSize = false;

  @override
  void initState() {
    super.initState();
    _loadMetadataIfNeeded();
    _loadFileSizeIfNeeded();
  }

  void _loadMetadataIfNeeded() {
    if (!widget.metadataCache.containsKey(widget.filePath) && !_isLoadingMetadata) {
      setState(() {
        _isLoadingMetadata = true;
      });
      
      BackgroundService.instance.getFileMetadata(widget.filePath).then((metadata) {
        if (metadata == null) return;
        if (mounted) {
          widget.onMetadataLoaded(metadata);
          setState(() {
            _isLoadingMetadata = false;
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _isLoadingMetadata = false;
          });
        }
      });
    }
  }

  void _loadFileSizeIfNeeded() {
    if (!widget.fileSizeCache.containsKey(widget.filePath) && !_isLoadingSize) {
      setState(() {
        _isLoadingSize = true;
      });
      
      BackgroundService.instance.getFileSize(widget.filePath).then((size) {
        if (mounted) {
          widget.onFileSizeLoaded(size);
          setState(() {
            _isLoadingSize = false;
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _isLoadingSize = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = widget.metadataCache[widget.filePath];
    final fileSize = widget.fileSizeCache[widget.filePath];

    if (_isLoadingMetadata || metadata == null) {
      return ListTile(
        leading: _isLoadingMetadata 
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.error, color: Colors.red),
        title: const Text('Loading...'),
        subtitle: const Text('Loading file information...'),
        trailing: !_isLoadingMetadata ? IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => widget.onAction('delete', null),
        ) : null,
      );
    }



    return ListTile(
      leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
      title: Text(
        metadata.fileName,
        style: const TextStyle(fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 4),
          Text(
            'Encrypted: ${_formatDate(metadata.encryptionTime)}',
            style: const TextStyle(fontSize: 12),
          ),
          if (metadata.validUntil != null)
            Text(
              'Expires: ${_formatDate(metadata.validUntil!)}',
              style: const TextStyle(fontSize: 12),
            ),
          Text(
            'Location: ${_formatCoordinates(metadata.latitude, metadata.longitude)}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Radius: ${metadata.radiusMeters.toStringAsFixed(0)}m',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            'Size: ${fileSize ?? (_isLoadingSize ? 'Loading...' : 'Unknown')}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => widget.onAction(value, metadata),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'decrypt',
            child: Row(
              children: [
                Icon(Icons.lock_open),
                SizedBox(width: 8),
                Text('Decrypt'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'quick_view',
            child: Row(
              children: [
                Icon(Icons.visibility),
                SizedBox(width: 8),
                Text('Quick View'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'info',
            child: Row(
              children: [
                Icon(Icons.info),
                SizedBox(width: 8),
                Text('Details'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'share',
            child: Row(
              children: [
                Icon(Icons.share, color: Colors.blue),
                SizedBox(width: 8),
                Text('Share', style: TextStyle(color: Colors.blue)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }
}
