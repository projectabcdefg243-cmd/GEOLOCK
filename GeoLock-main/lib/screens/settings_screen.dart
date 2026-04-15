import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<Permission, bool> _permissionStatus = {
    Permission.location: false,
    Permission.storage: true,
    Permission.photos: false,
    Permission.manageExternalStorage: false,
  };

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final Map<Permission, bool> statusMap = {};
    
    for (var permission in _permissionStatus.keys) {
      statusMap[permission] = await permission.isGranted;
    }

    if (mounted) {
      setState(() {
        _permissionStatus = statusMap;
      });
    }
  }

  Future<void> _requestPermission(Permission permission) async {
    try {
      if (await permission.isGranted) {
        // Already granted, open app settings instead
        await openAppSettings();
        return;
      }

      if (await permission.isPermanentlyDenied) {
        // Permission is permanently denied, open settings
        await openAppSettings();
        return;
      }

      final status = await permission.request();
      if (mounted) {
        setState(() {
          _permissionStatus[permission] = status.isGranted;
        });
      }
    } catch (e) {
      print('Error requesting permission: $e');
      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Error'),
            content: Text('Could not request permission: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  String _getPermissionTitle(Permission permission) {
    switch (permission) {
      case Permission.location:
        return 'Location';
      case Permission.storage:
        return 'Storage';
      case Permission.photos:
        return 'Photos';
      case Permission.manageExternalStorage:
        return 'Manage Storage';
      default:
        return 'Unknown';
    }
  }

  String _getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.location:
        return 'Required for geo-locking files to specific locations';
      case Permission.storage:
        return 'Required for accessing and managing files';
      case Permission.photos:
        return 'Required for accessing media files on Android 13+';
      case Permission.manageExternalStorage:
        return 'Required for advanced file management';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Permissions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._permissionStatus.entries.map((entry) {
            final permission = entry.key;
            final isGranted = entry.value;

            return ListTile(
              title: Text(_getPermissionTitle(permission)),
              subtitle: Text(_getPermissionDescription(permission)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isGranted ? Icons.check_circle : Icons.error_outline,
                    color: isGranted ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () async {
                      if (!isGranted) {
                        await _requestPermission(permission);
                      } else {
                        // Open app settings if permission is already granted
                        await openAppSettings();
                      }
                    },
                    child: Text(isGranted ? 'Settings' : 'Grant'),
                  ),
                ],
              ),
            );
          }).toList(),
          const Divider(),
          // Add more settings sections here
        ],
      ),
    );
  }
}