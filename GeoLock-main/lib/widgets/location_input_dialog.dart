import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'map_picker_widget.dart';

class LocationInputDialog extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const LocationInputDialog({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<LocationInputDialog> createState() => _LocationInputDialogState();
}

class _LocationInputDialogState extends State<LocationInputDialog> {
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _latitudeController.text = widget.initialLatitude!.toString();
      _longitudeController.text = widget.initialLongitude!.toString();
      _getAddressFromCoordinates();
    }
  }

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Decryption Location'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the coordinates where this file can be decrypted:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _latitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Latitude',
                      hintText: 'e.g., 40.7128',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _longitudeController,
                    decoration: const InputDecoration(
                      labelText: 'Longitude',
                      hintText: 'e.g., -74.0060',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
                hintText: 'e.g., Vit,Pune or 16.7128, -73.0060',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _getCoordinatesFromAddress(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _getCoordinatesFromAddress,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_isLoading ? 'Searching...' : 'Search Address'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.map),
                  label: const Text('Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Tips:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• You can enter coordinates manually\n'
                    '• Or search for an address to get coordinates\n'
                    '• The file can only be decrypted within the specified radius of this location',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _validateAndSubmit,
          child: const Text('Set Location'),
        ),
      ],
    );
  }

  Future<void> _getCoordinatesFromAddress() async {
    if (_addressController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an address to search';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final locations = await locationFromAddress(_addressController.text.trim());
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _latitudeController.text = location.latitude.toString();
          _longitudeController.text = location.longitude.toString();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'No location found for this address';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to find location: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerWidget(
          initialLatitude: _latitudeController.text.isNotEmpty 
              ? double.tryParse(_latitudeController.text) 
              : null,
          initialLongitude: _longitudeController.text.isNotEmpty 
              ? double.tryParse(_longitudeController.text) 
              : null,
          initialAddress: _addressController.text.isNotEmpty 
              ? _addressController.text 
              : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latitudeController.text = result['latitude'].toString();
        _longitudeController.text = result['longitude'].toString();
        _addressController.text = result['address'] ?? '';
        _errorMessage = null;
      });
    }
  }

  Future<void> _getAddressFromCoordinates() async {
    if (_latitudeController.text.trim().isEmpty || _longitudeController.text.trim().isEmpty) {
      return;
    }

    try {
      final latitude = double.parse(_latitudeController.text.trim());
      final longitude = double.parse(_longitudeController.text.trim());
      
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.locality,
          placemark.administrativeArea,
          placemark.country,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
        
        if (address.isNotEmpty) {
          _addressController.text = address;
        }
      }
    } catch (e) {
      // Ignore errors when getting address from coordinates
    }
  }

  void _validateAndSubmit() {
    final latitudeText = _latitudeController.text.trim();
    final longitudeText = _longitudeController.text.trim();

    if (latitudeText.isEmpty || longitudeText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both latitude and longitude';
      });
      return;
    }

    try {
      final latitude = double.parse(latitudeText);
      final longitude = double.parse(longitudeText);

      // Validate latitude range
      if (latitude < -90 || latitude > 90) {
        setState(() {
          _errorMessage = 'Latitude must be between -90 and 90';
        });
        return;
      }

      // Validate longitude range
      if (longitude < -180 || longitude > 180) {
        setState(() {
          _errorMessage = 'Longitude must be between -180 and 180';
        });
        return;
      }

      Navigator.pop(context, {
        'latitude': latitude,
        'longitude': longitude,
        'address': _addressController.text.trim(),
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Please enter valid numbers for coordinates';
      });
    }
  }
}
