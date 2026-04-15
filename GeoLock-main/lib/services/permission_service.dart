import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<void> initialize() async {
    try {
      // Request storage permission first
      final storageGranted = await requestStoragePermission();
      if (!storageGranted) {
        print('Storage permission was denied');
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
    // Location permission will be handled when needed by LocationService
  }

  static Future<bool> requestLocationPermission() async {
    try {
      var status = await Permission.location.status;
      if (status.isDenied) {
        status = await Permission.location.request();
        // Handle the case when user cancels the permission request
        if (status.isPermanentlyDenied) {
          print('Location permission is permanently denied');
          return false;
        }
      }
      return status.isGranted;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  static Future<bool> requestStoragePermission() async {
    // For Android 13+ (API 33+), use the new media permissions
    try {
      var photosStatus = await Permission.photos.status;
      if (photosStatus.isDenied) {
        photosStatus = await Permission.photos.request();
      }
      if (photosStatus.isGranted) return true;
    } catch (e) {
      // Photos permission not supported on this device
    }
    
    // For older Android versions, use storage permission
    var storageStatus = await Permission.storage.status;
    if (storageStatus.isDenied) {
      storageStatus = await Permission.storage.request();
    }
    
    return storageStatus.isGranted;
  }

  static Future<bool> requestManageExternalStoragePermission() async {
    var status = await Permission.manageExternalStorage.status;
    if (status.isDenied) {
      status = await Permission.manageExternalStorage.request();
    }
    return status.isGranted;
  }

  static Future<bool> hasLocationPermission() async {
    return await Permission.location.isGranted;
  }

  static Future<bool> hasStoragePermission() async {
    // Check both old and new storage permissions
    bool hasOldStorage = await Permission.storage.isGranted;
    bool hasNewStorage = true;
    
    try {
      hasNewStorage = await Permission.photos.isGranted;
    } catch (e) {
      // Photos permission not supported on this device
      hasNewStorage = false;
    }
    
    return hasOldStorage || hasNewStorage;
  }

  static Future<bool> hasManageExternalStoragePermission() async {
    return await Permission.manageExternalStorage.isGranted;
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
