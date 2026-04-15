import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong2;
import 'package:geocoding/geocoding.dart';
import '../services/location_service.dart';

class MapPickerWidget extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialAddress;
  final bool enableRadiusSelection; // New feature: allow radius selection

  const MapPickerWidget({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAddress,
    this.enableRadiusSelection = true,
  });

  @override
  State<MapPickerWidget> createState() => _MapPickerWidgetState();
}

class _MapPickerWidgetState extends State<MapPickerWidget> {
  late MapController _mapController;
  latlong2.LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;
  List<Marker> _markers = [];
  double _radius = 100.0; // Default radius in meters
  final List<CircleMarker> _circleMarkers = [];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    // If initial location is provided, use it
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation = latlong2.LatLng(
        widget.initialLatitude!,
        widget.initialLongitude!,
      );
      _selectedAddress = widget.initialAddress;
      _updateMarkers();
      _updateCircleMarkers();
      
      // Move map to initial location
      _mapController.move(_selectedLocation!, 15.0);
      
      // If no address provided, fetch it
      if (widget.initialAddress == null) {
        await _getAddressFromLocation(_selectedLocation!);
      }
    } else {
      // No initial location, try to get current location
      await _goToCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_selectedLocation != null)
            TextButton(
              onPressed: _confirmLocation,
              child: const Text(
                'CONFIRM',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Radius selector (if enabled)
          if (widget.enableRadiusSelection && _selectedLocation != null)
            _buildRadiusSelector(),
          
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedLocation ?? const latlong2.LatLng(18.4636, 73.8682),
                    initialZoom: 15.0,
                    onTap: (tapPosition, point) => _onMapTapped(point),
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        // User is manually moving the map, don't update location
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.geolock',
                      // Add fallback URLs for better reliability
                      // urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      // subdomains: const ['a', 'b', 'c'],
                    ),
                    MarkerLayer(markers: _markers),
                    CircleLayer(circles: _circleMarkers),
                  ],
                ),
                if (_isLoadingLocation)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
          _buildLocationInfo(),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _goToCurrentLocation,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.my_location, color: Colors.white),
            tooltip: 'Current Location',
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _goToSearchLocation,
            backgroundColor: Colors.green,
            child: const Icon(Icons.search, color: Colors.white),
            tooltip: 'Search Location',
          ),
          if (widget.enableRadiusSelection) ...[
            const SizedBox(height: 8),
            FloatingActionButton(
              onPressed: _showRadiusInfo,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.radar, color: Colors.white),
              tooltip: 'Radius Info',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadiusSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.radar, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Geofence Radius:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Text(
                '${_radius.toInt()} meters',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          Slider(
            value: _radius,
            min: 10.0,
            max: 1000.0,
            divisions: 99,
            label: '${_radius.toInt()} meters',
            onChanged: (value) {
              setState(() {
                _radius = value;
                _updateCircleMarkers();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Location:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedLocation != null) ...[
            Text(
              '${_selectedLocation!.latitude.toStringAsFixed(6)}, ${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            if (_isLoadingAddress)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Loading address...'),
                ],
              )
            else if (_selectedAddress != null) ...[
              Text(
                _selectedAddress!,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ] else ...[
              const Text(
                'Address not available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ] else ...[
            const Text(
              'Tap on the map to select a location',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedLocation != null ? _confirmLocation : null,
              icon: const Icon(Icons.check),
              label: const Text('Confirm Location'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapTapped(latlong2.LatLng point) {
    setState(() {
      _selectedLocation = point;
      _isLoadingAddress = true;
    });
    _updateMarkers();
    _updateCircleMarkers();
    _getAddressFromLocation(point);
  }

  void _updateMarkers() {
    if (_selectedLocation != null) {
      setState(() {
        _markers = [
          Marker(
            point: _selectedLocation!,
            width: 0,
            height: 0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Transform.translate(
                  offset: const Offset(-24, -48),
                  child: const Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                if (_selectedAddress != null && !_isLoadingAddress)
                  Positioned(
                    top: 45,
                    left: -75,
                    width: 150,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        _selectedAddress!,
                        style: const TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ];
      });
    } else {
      setState(() {
        _markers = [];
      });
    }
  }

  void _updateCircleMarkers() {
    if (_selectedLocation != null && widget.enableRadiusSelection) {
      setState(() {
        _circleMarkers.clear();
        _circleMarkers.add(
          CircleMarker(
            point: _selectedLocation!,
            color: Colors.blue.withOpacity(0.2),
            borderColor: Colors.blue.withOpacity(0.5),
            borderStrokeWidth: 2,
            useRadiusInMeter: true,
            radius: _radius, // meters
          ),
        );
      });
    }
  }

  Future<void> _getAddressFromLocation(latlong2.LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.subLocality,
          placemark.locality,
          placemark.administrativeArea,
          placemark.postalCode,
          placemark.country,
        ].where((part) => part != null && part.isNotEmpty).join(', ');
        
        setState(() {
          _selectedAddress = address.isNotEmpty ? address : 'Address not available';
          _isLoadingAddress = false;
        });
        _updateMarkers();
      } else {
        setState(() {
          _selectedAddress = 'Address not found';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      setState(() {
        _selectedAddress = 'Error loading address';
        _isLoadingAddress = false;
      });
      debugPrint('Geocoding error: $e');
    }
  }

  Future<void> _goToCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        _showError('Could not get current location. Please check location permissions and settings.');
        return;
      }

      final location = latlong2.LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = location;
        _isLoadingAddress = true;
      });
      
      _updateMarkers();
      _updateCircleMarkers();
      _mapController.move(location, 15.0);
      await _getAddressFromLocation(location);
    } catch (e) {
      _showError('Unable to get current location: $e');
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  void _goToSearchLocation() {
    _showLocationSearchDialog();
  }

  void _showLocationSearchDialog() {
    final addressController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Enter address or coordinates',
                hintText: 'e.g., Vit,Kondhwa,Pune or 16.7128, -73.0060',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                Navigator.pop(context);
                _searchLocation(value);
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: You can enter coordinates in decimal format (lat,lng)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchLocation(addressController.text);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoadingAddress = true;
      _isLoadingLocation = true;
    });

    try {
      // Check if it's coordinates
      final coordinateMatch = RegExp(r'^(-?\d+\.?\d*)\s*,\s*(-?\d+\.?\d*)$').firstMatch(query.trim());
      if (coordinateMatch != null) {
        final lat = double.tryParse(coordinateMatch.group(1)!);
        final lng = double.tryParse(coordinateMatch.group(2)!);
        
        if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
          final location = latlong2.LatLng(lat, lng);
          setState(() {
            _selectedLocation = location;
          });
          _updateMarkers();
          _updateCircleMarkers();
          _mapController.move(location, 15.0);
          await _getAddressFromLocation(location);
          return;
        }
      }

      // Search by address
      final locations = await locationFromAddress(query.trim());
      if (locations.isNotEmpty) {
        final location = latlong2.LatLng(locations.first.latitude, locations.first.longitude);
        setState(() {
          _selectedLocation = location;
        });
        _updateMarkers();
        _updateCircleMarkers();
        _mapController.move(location, 15.0);
        await _getAddressFromLocation(location);
      } else {
        _showError('No location found for "$query"');
        setState(() {
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      _showError('Search failed: ${e.toString()}');
      setState(() {
        _isLoadingAddress = false;
      });
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  void _showRadiusInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geofence Radius'),
        content: Text(
          'The selected radius (${_radius.toInt()} meters) defines the area where '
          'the encrypted file can be decrypted. Users must be within this distance '
          'from the selected location to access the file content.',
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

  void _confirmLocation() {
    if (_selectedLocation != null) {
      final result = {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'address': _selectedAddress,
        if (widget.enableRadiusSelection) 'radius': _radius,
      };
      Navigator.pop(context, result);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}