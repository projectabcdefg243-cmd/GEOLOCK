import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/encrypt_screen.dart';
import 'screens/decrypt_screen.dart';
import 'screens/files_screen.dart';
import 'services/location_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GeoLockApp());
}

class GeoLockApp extends StatefulWidget {
  const GeoLockApp({super.key});

  @override
  State<GeoLockApp> createState() => _GeoLockAppState();
}

class _GeoLockAppState extends State<GeoLockApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        LocationService.resumeLocationUpdates();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        LocationService.pauseLocationUpdates();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoLock',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/encrypt': (context) => const EncryptScreen(),
        '/decrypt': (context) => const DecryptScreen(),
        '/files': (context) => const FilesScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
