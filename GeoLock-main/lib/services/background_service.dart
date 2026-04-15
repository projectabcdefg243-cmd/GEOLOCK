import 'dart:io';
import 'encryption_service.dart';
import 'file_service.dart';
import '../models/encryption_metadata.dart';


class BackgroundService {
  BackgroundService._();

  static BackgroundService? _instance;
  static bool _isInitialized = false;

 
  static BackgroundService get instance {
    _instance ??= BackgroundService._();
    return _instance!;
  }

  
  Future<void> initialize() async {
    if (!_isInitialized) {
      await EncryptionService.initialize();
      _isInitialized = true;
    }
  }

  
  Future<List<String>> getEncryptedFiles() async {
    try {
      await initialize();
      return await EncryptionService.getEncryptedFiles();
    } catch (e) {
      return [];
    }
  }

 
  Future<Map<String, dynamic>> encryptPdf({
    required String pdfPath,
    required double latitude,
    required double longitude,
    DateTime? validUntil,
    double radiusMeters = 100.0,
  }) async {
    try {
      await initialize();
      
      final encryptedPath = await EncryptionService.encryptPdfWithLocation(
        pdfPath,
        latitude,
        longitude,
        validUntil: validUntil,
        radiusMeters: radiusMeters,
      );

      return {
        'success': true,
        'encryptedPath': encryptedPath,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  
  Future<Map<String, dynamic>> decryptPdf(String encryptedPath) async {
    try {
      await initialize();
      return await EncryptionService.decryptPdfWithValidation(encryptedPath) ?? {
        'success': false,
        'error': 'Failed to decrypt PDF: Unknown error',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }


  Future<EncryptionMetadata?> getFileMetadata(String filePath) async {
    try {
      await initialize();
      return await FileService.getFileMetadata(filePath);
    } catch (e) {
      return null;
    }
  }

  
  Future<bool> deleteFile(String filePath) async {
    try {
      return await FileService.deleteFile(filePath);
    } catch (e) {
      return false;
    }
  }

  
  Future<String> getFileSize(String filePath) async {
    try {
      return await FileService.getFileSize(filePath);
    } catch (e) {
      return 'Unknown';
    }
  }


  Future<Map<String, dynamic>> validateAndImportFile(String filePath) async {
    try {
      await initialize();
      final metadata = await FileService.getFileMetadata(filePath);
      if (metadata == null) {
        return {
          'success': false,
          'error': 'Invalid encrypted file format.',
        };
      }

      if (metadata.validUntil != null && DateTime.now().isAfter(metadata.validUntil!)) {
        return {
          'success': false,
          'error': 'This encrypted file has expired.',
        };
      }

      final encryptedFilesDir = await FileService.getEncryptedFilesDirectory();
      final fileName = filePath.split('/').last;
      final newFilePath = '$encryptedFilesDir/$fileName';
      
      await File(filePath).copy(newFilePath);
      
      return {
        'success': true,
        'message': 'File imported successfully.',
        'filePath': newFilePath,
        'metadata': metadata,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Failed to import file: $e',
      };
    }
  }
}