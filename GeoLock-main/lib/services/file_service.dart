import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../models/encryption_metadata.dart';
import 'encryption_service.dart';
import 'location_service.dart';
import 'permission_service.dart';

class FileService {
  static Future<Directory> _getSavedFilesDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/saved_pdfs');
  }

  static Future<List<String>> getSavedFiles() async {
    try {
      final savedFilesDir = await _getSavedFilesDirectory();
      if (!await savedFilesDir.exists()) {
        return [];
      }

      final files = await savedFilesDir.list().toList();
      return files
          .where((file) => file.path.toLowerCase().endsWith('.pdf'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      print('Error getting saved files: $e');
      return [];
    }
  }

  static Future<String> savePdfFile(String sourcePath, String fileName) async {
    try {
      final savedFilesDir = await _getSavedFilesDirectory();
      if (!await savedFilesDir.exists()) {
        await savedFilesDir.create(recursive: true);
      }

      final targetPath = '${savedFilesDir.path}/$fileName';
      await File(sourcePath).copy(targetPath);
      return targetPath;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  static Future<void> shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }
      await Share.shareXFiles([XFile(filePath)], text: 'Sharing PDF file');
    } catch (e) {
      throw Exception('Failed to share file: $e');
    }
  }
  static Future<String?> pickPdfFile() async {
    try {
      // Check storage permission
      if (!await PermissionService.hasStoragePermission()) {
        bool granted = await PermissionService.requestStoragePermission();
        if (!granted) {
          throw Exception('Storage permission is required to select files. Please grant permission in app settings.');
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.first.path;
      }
      return null;
    } catch (e) {
      print('Error picking file: $e');
      return null;
    }
  }

  static Future<String?> pickEncryptedFile() async {
    try {
      // Check storage permission
      if (!await PermissionService.hasStoragePermission()) {
        bool granted = await PermissionService.requestStoragePermission();
        if (!granted) {
          throw Exception('Storage permission is required to select files. Please grant permission in app settings.');
        }
      }

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        return result.files.first.path;
      }
      return null;
    } catch (e) {
      print('Error picking encrypted file: $e');
      return null;
    }
  }

  static Future<String> encryptPdfFile(
    String pdfPath, {
    DateTime? validUntil,
    double radiusMeters = 100.0,
  }) async {
    try {
      // Get current location
      final currentPosition = await LocationService.getCurrentLocation();
      if (currentPosition == null) {
        throw Exception('Unable to get current location. Please enable location services.');
      }

      // Encrypt the PDF with location and time constraints
      final encryptedPath = await EncryptionService.encryptPdfWithLocation(
        pdfPath,
        currentPosition.latitude,
        currentPosition.longitude,
        validUntil: validUntil,
        radiusMeters: radiusMeters,
      );

      return encryptedPath;
    } catch (e) {
      throw Exception('Failed to encrypt PDF: $e');
    }
  }

  static Future<String> encryptPdfFileWithLocation(
    String pdfPath, {
    required double latitude,
    required double longitude,
    DateTime? validUntil,
    double radiusMeters = 100.0,
  }) async {
    try {
      // Encrypt the PDF with specified location and time constraints
      final encryptedPath = await EncryptionService.encryptPdfWithLocation(
        pdfPath,
        latitude,
        longitude,
        validUntil: validUntil,
        radiusMeters: radiusMeters,
      );

      return encryptedPath;
    } catch (e) {
      throw Exception('Failed to encrypt PDF: $e');
    }
  }

  static Future<Map<String, dynamic>> decryptPdfFile(String encryptedPath) async {
    try {
      final result = await EncryptionService.decryptPdfWithValidation(encryptedPath);
      return result ?? {
        'success': false,
        'error': 'Failed to decrypt PDF: Unknown error',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to decrypt PDF: $e',
      };
    }
  }

  static Future<List<String>> getEncryptedFiles() async {
    return await EncryptionService.getEncryptedFiles();
  }

  static Future<EncryptionMetadata?> getFileMetadata(String encryptedPath) async {
    return await EncryptionService.getFileMetadata(encryptedPath);
  }

  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  static Future<String> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < 1024) {
          return '$bytes B';
        } else if (bytes < 1024 * 1024) {
          return '${(bytes / 1024).toStringAsFixed(1)} KB';
        } else {
          return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  static Future<DateTime> getFileModifiedDate(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.modified;
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  static String getFileName(String filePath) {
    return filePath.split('/').last;
  }

  static String getFileExtension(String filePath) {
    return filePath.split('.').last.toLowerCase();
  }

  static Future<bool> isPdfFile(String filePath) async {
    final extension = getFileExtension(filePath);
    return extension == 'pdf';
  }

  static Future<String> getEncryptedFilesDirectory() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final encryptedDir = Directory('${directory.path}/encrypted');
      if (!await encryptedDir.exists()) {
        await encryptedDir.create(recursive: true);
      }
      return encryptedDir.path;
    } catch (e) {
      throw Exception('Failed to get encrypted files directory: $e');
    }
  }
}
