class EncryptionOptions {
  double radiusMeters;
  bool hasExpiration;
  DateTime? expirationDate;

  EncryptionOptions({
    this.radiusMeters = 50.0,
    this.hasExpiration = false,
    this.expirationDate,
  });
}
