class EncryptionMetadata {
  final String fileName;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final DateTime encryptionTime;
  final DateTime? validUntil;
  final String? originalPath;

  EncryptionMetadata({
    required this.fileName,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.encryptionTime,
    this.validUntil,
    this.originalPath,
  });

  factory EncryptionMetadata.fromJson(Map<String, dynamic> json) {
    return EncryptionMetadata(
      fileName: json['fileName'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      radiusMeters: (json['radiusMeters'] as num).toDouble(),
      encryptionTime: DateTime.parse(json['encryptionTime']),
      validUntil: json['validUntil'] != null ? DateTime.parse(json['validUntil']) : null,
      originalPath: json['originalPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'encryptionTime': encryptionTime.toIso8601String(),
      'validUntil': validUntil?.toIso8601String(),
      'originalPath': originalPath,
    };
  }
}