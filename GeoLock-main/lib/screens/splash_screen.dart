import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  final ValueNotifier<String> _statusNotifier = ValueNotifier<String>('Initializing...');

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _initializeApp();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat(reverse: true);
  }

  Future<void> _initializeApp() async {
    try {
      // Check permissions
      _statusNotifier.value = 'Checking permissions...';
      await _checkPermissions();

      // Initialize location service
      _statusNotifier.value = 'Getting location...';
      await LocationService.initialize();

      // Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      _statusNotifier.value = 'Error: $e';
    }
  }

  Future<void> _checkPermissions() async {
    // Check location permission
    if (!await PermissionService.hasLocationPermission()) {
      await PermissionService.requestLocationPermission();
    }

    // Check storage permission
    if (!await PermissionService.hasStoragePermission()) {
      await PermissionService.requestStoragePermission();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _statusNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: const Icon(
                Icons.lock_outline,
                size: 100,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'GeoLock',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: _statusNotifier,
              builder: (context, status, child) {
                return Text(
                  status,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
