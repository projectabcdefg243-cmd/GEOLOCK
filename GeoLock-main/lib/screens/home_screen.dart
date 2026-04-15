import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'encrypt_screen.dart';
import 'decrypt_screen.dart';
import 'files_screen.dart';
import 'saved_files_screen.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await _checkPermissions();
    await LocationService.getCurrentLocation();
  }



  Future<void> _checkPermissions() async {
    // Check location permission
    if (!await PermissionService.hasLocationPermission()) {
      _showLocationError();
      return;
    }

    // Check storage permission
    if (!await PermissionService.hasStoragePermission()) {
      _showStoragePermissionError();
      return;
    }
  }

  void _showStoragePermissionError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
          'GeoLock needs storage permission to access and encrypt PDF files. Please grant permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PermissionService.requestStoragePermission();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Unable to get location. Please enable location services.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationCard(),
          const SizedBox(height: 24),
          _buildActionCards(),
          const SizedBox(height: 24),
          _buildInfoCard(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: const Text('GeoLock'),
        
        shadowColor: const Color.fromARGB(255, 0, 0, 0),
        backgroundColor: const Color.fromARGB(255, 19, 168, 226),
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    if (_selectedIndex == 1) {
      return const SettingsScreen();
    }

    return ValueListenableBuilder<bool>(
      valueListenable: LocationService.isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return ValueListenableBuilder<Position?>(
          valueListenable: LocationService.currentPositionNotifier,
          builder: (context, position, child) {
            if (position == null) {
              return _buildLocationError();
            }
            return _buildMainContent();
          },
        );
      },
    );
  }

  Widget _buildLocationError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Location Access Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'GeoLock needs access to your location to encrypt files with location data.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => LocationService.getCurrentLocation(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          
          style: TextStyle(
            fontSize: 20,       
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.lock,
          title: 'Encrypt File',
          subtitle: 'Secure your PDF with location',
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EncryptScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.lock_open,
          title: 'Decrypt File',
          subtitle: 'Access your encrypted PDFs',
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DecryptScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.folder,
          title: 'Manage Files',
          subtitle: 'View files',
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FilesScreen()),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildActionCard(
          icon: Icons.library_books,
          title: 'Saved Files',
          subtitle: 'View decrypted PDFs',
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SavedFilesScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationCard(),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildInfoCard(),
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
            const Row(
              children: [
                Icon(Icons.location_on, color: Color.fromARGB(255, 34, 126, 0)),
                SizedBox(width: 8),
                Text(
                  'Current Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<Position?>(
              valueListenable: LocationService.currentPositionNotifier,
              builder: (context, position, child) {
                if (position == null) return const SizedBox.shrink();
                return Text(
                  LocationService.formatCoordinates(
                    position.latitude,
                    position.longitude,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'monospace',
                  ),
                );
              },
            ),
            ValueListenableBuilder<String?>(
              valueListenable: LocationService.currentAddressNotifier,
              builder: (context, address, child) {
                if (address == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    address,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            color: Color.fromARGB(255, 0, 0, 0),
      
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.lock,
                title: 'Encrypt PDF',
                subtitle: 'Add location & time lock',
                color: const Color.fromARGB(255, 224, 14, 14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EncryptScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.lock_open,
                title: 'Decrypt PDF',
                subtitle: 'Unlock with location',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DecryptScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.library_books,
                title: 'PDF Library',
                subtitle: 'View saved PDFs',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SavedFilesScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.folder,
                title: 'Manage Files',
                subtitle: 'View All files',
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const FilesScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 10,
      color: Colors.blue.shade50,
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'How it works',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '• Encrypt PDFs with your current location and time\n'
              '• Files can only be decrypted at the specified location\n'
              '• Set expiration times for additional security\n'
              '• Perfect for sensitive documents that need location-based access',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
