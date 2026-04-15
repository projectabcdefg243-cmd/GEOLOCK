import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:path_provider/path_provider.dart';
import 'location_service.dart';
import '../models/encryption_metadata.dart';

class EncryptionService {
  static const String _keyString = 'GeoLockSecretKey2024!@#';
  static Key? _key;
  static Encrypter? _encrypter;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final keyBytes = sha256.convert(utf8.encode(_keyString)).bytes;
      _key = Key(Uint8List.fromList(keyBytes));
      _encrypter = Encrypter(AES(_key!, mode: AESMode.cbc));
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize encryption service: $e');
    }
  }

  static Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  static Future<String> encryptPdfWithLocation(
    String pdfPath,
    double latitude,
    double longitude, {
    DateTime? validUntil,
    double radiusMeters = 100.0,
  }) async {
    try {
      
      await ensureInitialized();
      
      // Read the original PDF file
      final file = File(pdfPath);
      final pdfBytes = await file.readAsBytes();
      
      
      final metadata = EncryptionMetadata(
        latitude: latitude,
        longitude: longitude,
        encryptionTime: DateTime.now(),
        validUntil: validUntil,
        radiusMeters: radiusMeters,
        fileName: file.path.split('/').last,
        originalPath: pdfPath,
      );

   
      final encryptedPackage = await _createEncryptedPackage(pdfBytes, metadata);
      
      
      final encryptedPath = await _saveEncryptedFile(encryptedPackage, metadata.fileName);
      
      return encryptedPath;
    } catch (e) {
      throw Exception('Failed to encrypt PDF: $e');
    }
  }

  static Future<Uint8List> _createEncryptedPackage(
    Uint8List pdfBytes,
    EncryptionMetadata metadata,
  ) async {
    
    final metadataJson = jsonEncode(metadata.toJson());
    final metadataBytes = utf8.encode(metadataJson);
    
    
    final packageJson = jsonEncode({
      'metadata': base64Encode(metadataBytes),
      'pdfData': base64Encode(pdfBytes),
    });
    
    final packageBytes = utf8.encode(packageJson);
    final iv = IV.fromSecureRandom(16); 
    final encrypted = _encrypter!.encryptBytes(packageBytes, iv: iv);
    
    
    final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
    result.setRange(0, iv.bytes.length, iv.bytes);
    result.setRange(iv.bytes.length, result.length, encrypted.bytes);
    
    return result;
  }

  static Future<String> _saveEncryptedFile(Uint8List encryptedData, String originalFileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final encryptedDir = Directory('${directory.path}/encrypted');
    if (!await encryptedDir.exists()) {
      await encryptedDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final encryptedFileName = 'encrypted_${timestamp}_$originalFileName.geolock';
    final encryptedFile = File('${encryptedDir.path}/$encryptedFileName');
    
    await encryptedFile.writeAsBytes(encryptedData);
    return encryptedFile.path;
  }

  static Future<Map<String, dynamic>?> decryptPdfWithValidation(
    String encryptedPath,
  ) async {
    try {
      
      if (_encrypter == null) {
        await initialize();
      }
      
      
      final file = File(encryptedPath);
      final encryptedBytes = await file.readAsBytes();
      
     
      final iv = IV(encryptedBytes.sublist(0, 16));
      final encryptedData = encryptedBytes.sublist(16);
      
     
      final encrypted = Encrypted(encryptedData);
      final decryptedBytes = _encrypter!.decryptBytes(encrypted, iv: iv);
      final packageJson = jsonDecode(utf8.decode(decryptedBytes));
      
      
      final metadataBytes = base64Decode(packageJson['metadata']);
      final pdfBytes = base64Decode(packageJson['pdfData']);
      
      final metadataJson = jsonDecode(utf8.decode(metadataBytes));
      final metadata = EncryptionMetadata.fromJson(metadataJson);
      
      
      final validationResult = await _validateDecryptionConditions(metadata);
      
      if (!validationResult['isValid']) {
        throw Exception(validationResult['errorMessage']);
      }
      
      final decryptedPath = await _saveDecryptedFile(pdfBytes, metadata.fileName);
      
      return {
        'success': true,
        'decryptedPath': decryptedPath,
        'metadata': metadata,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> _validateDecryptionConditions(
    EncryptionMetadata metadata,
  ) async {
   
    final currentPosition = await LocationService.getCurrentLocation();
    if (currentPosition == null) {
      return {
        'isValid': false,
        'errorMessage': 'Unable to get current location. Please enable location services.',
      };
    }
    
   
    final now = DateTime.now();
    if (metadata.validUntil != null && now.isAfter(metadata.validUntil!)) {
      return {
        'isValid': false,
        'errorMessage': 'This file has expired and can no longer be decrypted.',
      };
    }
    
    final isWithinRadius = LocationService.isWithinRadius(
      metadata.latitude,
      metadata.longitude,
      currentPosition.latitude,
      currentPosition.longitude,
      metadata.radiusMeters,
    );
    
    if (!isWithinRadius) {
      final distance = LocationService.calculateDistance(
        metadata.latitude,
        metadata.longitude,
        currentPosition.latitude,
        currentPosition.longitude,
      );
      
      return {
        'isValid': false,
        'errorMessage': 'You are not at the required location. Required: ${LocationService.formatCoordinates(metadata.latitude, metadata.longitude)}, Current: ${LocationService.formatCoordinates(currentPosition.latitude, currentPosition.longitude)}, Distance: ${distance.toStringAsFixed(2)}m (max: ${metadata.radiusMeters}m)',
      };
    }
    
    return {
      'isValid': true,
      'errorMessage': null,
    };
  }

  static Future<String> _saveDecryptedFile(Uint8List pdfBytes, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final decryptedDir = Directory('${directory.path}/decrypted');
    if (!await decryptedDir.exists()) {
      await decryptedDir.create(recursive: true);
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final decryptedFileName = 'decrypted_${timestamp}_$fileName';
    final decryptedFile = File('${decryptedDir.path}/$decryptedFileName');
    
    await decryptedFile.writeAsBytes(pdfBytes);
    return decryptedFile.path;
  }

  static Future<List<String>> getEncryptedFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final encryptedDir = Directory('${directory.path}/encrypted');
      
      if (!await encryptedDir.exists()) {
        return [];
      }
      
      final files = await encryptedDir.list().toList();
      return files
          .where((file) => file.path.endsWith('.geolock'))
          .map((file) => file.path)
          .toList();
    } catch (e) {
      print('Error getting encrypted files: $e');
      return [];
    }
  }

  static Future<EncryptionMetadata?> getFileMetadata(String encryptedPath) async {
    try {
      // Ensure encryption service is initialized
      if (_encrypter == null) {
        await initialize();
      }
      
      final file = File(encryptedPath);
      final encryptedBytes = await file.readAsBytes();
      
      // Extract IV and encrypted data
      final iv = IV(encryptedBytes.sublist(0, 16));
      final encryptedData = encryptedBytes.sublist(16);
      
      final encrypted = Encrypted(encryptedData);
      final decryptedBytes = _encrypter!.decryptBytes(encrypted, iv: iv);
      final packageJson = jsonDecode(utf8.decode(decryptedBytes));
      
      final metadataBytes = base64Decode(packageJson['metadata']);
      final metadataJson = jsonDecode(utf8.decode(metadataBytes));
      
      return EncryptionMetadata.fromJson(metadataJson);
    } catch (e) {
      print('Error getting file metadata: $e');
      return null;
    }
  }
}
