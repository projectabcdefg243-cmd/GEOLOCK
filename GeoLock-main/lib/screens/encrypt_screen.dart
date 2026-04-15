import 'package:flutter/material.dart';
import '../services/file_service.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';
import '../services/background_service.dart';
import '../models/encryption_options.dart';
import '../widgets/location_input_dialog.dart';

class EncryptScreen extends StatefulWidget {
  const EncryptScreen({super.key});

  @override
  State<EncryptScreen> createState() => _EncryptScreenState();
}

class _EncryptScreenState extends State<EncryptScreen> {
  String? _selectedFilePath;
  bool _isEncrypting = false;
  EncryptionOptions _options = EncryptionOptions();
  bool _useManualLocation = false;
  double? _manualLatitude;
  double? _manualLongitude;
  String? _manualAddress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Encrypt PDF'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFileSelectionCard(),
            const SizedBox(height: 24),
            _buildLocationCard(),
            const SizedBox(height: 24),
            _buildOptionsCard(),
            const SizedBox(height: 24),
            _buildEncryptButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelectionCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select PDF File',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedFilePath == null)
              _buildFilePicker()
            else
              _buildSelectedFile(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _selectFile,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_upload,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select PDF file',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFile() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: Colors.red.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FileService.getFileName(_selectedFilePath!),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                FutureBuilder<String>(
                  future: FileService.getFileSize(_selectedFilePath!),
                  builder: (context, snapshot) {
                    return Text(
                      'Size: ${snapshot.data ?? 'Unknown'}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedFilePath = null;
              });
            },
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Decryption Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _useManualLocation,
                  onChanged: (value) {
                    setState(() {
                      _useManualLocation = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _useManualLocation ? 'Manual Location' : 'Current GPS Location',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            if (_useManualLocation) ...[
              _buildManualLocationSection(),
            ] else ...[
              _buildCurrentLocationSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationSection() {
    if (LocationService.currentPosition != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocationService.formatCoordinates(
              LocationService.currentPosition!.latitude,
              LocationService.currentPosition!.longitude,
            ),
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
          if (LocationService.currentAddress != null) ...[
            const SizedBox(height: 4),
            Text(
              LocationService.currentAddress!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      );
    } else {
      return const Text(
        'Location not available',
        style: TextStyle(
          fontSize: 14,
          color: Colors.red,
        ),
      );
    }
  }

  Widget _buildManualLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_manualLatitude != null && _manualLongitude != null) ...[
          Text(
            '${_manualLatitude!.toStringAsFixed(6)}, ${_manualLongitude!.toStringAsFixed(6)}',
            style: const TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
            ),
          ),
          if (_manualAddress != null && _manualAddress!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _manualAddress!,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _openLocationInputDialog,
            icon: const Icon(Icons.edit_location),
            label: Text(_manualLatitude != null ? 'Change Location' : 'Set Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Encryption Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildRadiusSlider(),
            const SizedBox(height: 16),
            _buildExpirationToggle(),
            if (_options.hasExpiration) ...[
              const SizedBox(height: 16),
              _buildExpirationDatePicker(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Decryption Radius: ${_options.radiusMeters.toStringAsFixed(0)} meters',
          style: const TextStyle(fontSize: 16),
        ),
        Slider(
          value: _options.radiusMeters,
          min: 10,
          max: 1000,
          divisions: 99,
          onChanged: (value) {
            setState(() {
              _options.radiusMeters = value;
            });
          },
        ),
        Text(
          'The file can only be decrypted within this radius of the encryption location.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildExpirationToggle() {
    return SwitchListTile(
      title: const Text('Set the Time Window'),
      subtitle: const Text('File will expire after this time'),
      value: _options.hasExpiration,
      onChanged: (value) {
        setState(() {
          _options.hasExpiration = value;
          if (!value) {
            _options.expirationDate = null;
          } else {
            _options.expirationDate = DateTime.now().add(const Duration(days: 7));
          }
        });
      },
    );
  }

  Widget _buildExpirationDatePicker() {
    return InkWell(
      onTap: _selectExpirationDate,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today),
            const SizedBox(width: 12),
            Text(
              _options.expirationDate != null
                  ? 'Expires: ${_formatDate(_options.expirationDate!)}'
                  : 'Select expiration date',
              style: const TextStyle(fontSize: 16),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildEncryptButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isEncrypting || _selectedFilePath == null ? null : _encryptFile,
        icon: _isEncrypting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.lock),
        label: Text(_isEncrypting ? 'Encrypting...' : 'Encrypt PDF'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Future<void> _selectFile() async {
    try {
      // Check storage permission first
      if (!await PermissionService.hasStoragePermission()) {
        bool granted = await PermissionService.requestStoragePermission();
        if (!granted) {
          _showError('Storage permission is required to select files. Please grant permission in app settings.');
          return;
        }
      }
      
      final filePath = await FileService.pickPdfFile();
      if (filePath != null) {
        setState(() {
          _selectedFilePath = filePath;
        });
      }
    } catch (e) {
      _showError('Failed to select file: $e');
    }
  }

  Future<void> _selectExpirationDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _options.expirationDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _options.expirationDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _openLocationInputDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LocationInputDialog(
        initialLatitude: _manualLatitude,
        initialLongitude: _manualLongitude,
      ),
    );

    if (result != null) {
      setState(() {
        _manualLatitude = result['latitude'];
        _manualLongitude = result['longitude'];
        _manualAddress = result['address'];
      });
    }
  }

  Future<void> _encryptFile() async {
    if (_selectedFilePath == null) return;

    // Validate location
    if (_useManualLocation && (_manualLatitude == null || _manualLongitude == null)) {
      _showError('Please set a manual location or switch to GPS location');
      return;
    }

    if (!_useManualLocation) {
      // Check if we have current location
      if (LocationService.currentPosition == null) {
        _showError('GPS location not available. Please enable location services or use manual location');
        return;
      }

      // Validate that the location is recent
      try {
        final position = await LocationService.getCurrentLocation();
        if (position == null) {
          _showError('Could not get current location. Please try again or use manual location');
          return;
        }
      } catch (e) {
        _showError('Error getting current location: $e');
        return;
      }
    }

    setState(() {
      _isEncrypting = true;
    });

    try {
      double latitude, longitude;
      
      if (_useManualLocation) {
        latitude = _manualLatitude!;
        longitude = _manualLongitude!;
      } else {
        latitude = LocationService.currentPosition!.latitude;
        longitude = LocationService.currentPosition!.longitude;
      }

      // Use background service for encryption
      final service = BackgroundService.instance;
      final result = await service.encryptPdf(
        pdfPath: _selectedFilePath!,
        latitude: latitude,
        longitude: longitude,
        validUntil: _options.expirationDate,
        radiusMeters: _options.radiusMeters,
      );

      setState(() {
        _isEncrypting = false;
      });

      if (result['success'] == true) {
        _showSuccess('PDF encrypted successfully!');
        
        // Reset form
        setState(() {
          _selectedFilePath = null;
          _options = EncryptionOptions();
          _useManualLocation = false;
          _manualLatitude = null;
          _manualLongitude = null;
          _manualAddress = null;
        });
      } else {
        _showError('Failed to encrypt PDF: ${result['error']}');
      }
    } catch (e) {
      setState(() {
        _isEncrypting = false;
      });
      _showError('Failed to encrypt PDF: $e');
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
