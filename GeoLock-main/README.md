# GeoLock - Location-Based PDF Encryption

GeoLock is a Flutter application that provides secure PDF encryption with location and time-based access controls. Files encrypted with GeoLock can only be decrypted at specific geographical locations and within specified time windows.

## Features

- **Location-Based Encryption**: Encrypt PDF files with GPS coordinates
- **Time-Based Access Control**: Set expiration dates for encrypted files
- **Radius-Based Decryption**: Configure decryption radius (10m to 1000m)
- **Secure Encryption**: Uses AES encryption with SHA-256 key derivation
- **Cross-Platform**: Works on both Android and iOS
- **User-Friendly Interface**: Intuitive UI for file management

## How It Works

1. **Encryption Process**:
   - Select a PDF file from your device
   - The app captures your current GPS location
   - Set optional expiration time and decryption radius
   - File is encrypted with location and time metadata
   - Encrypted file is saved with `.geolock` extension

2. **Decryption Process**:
   - Select an encrypted `.geolock` file
   - App verifies current location matches encryption location (within radius)
   - App checks if file hasn't expired (if expiration was set)
   - If validation passes, file is decrypted and saved

## Installation

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Android Studio / Xcode
- Android device with location services enabled
- iOS device with location services enabled

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd geolock
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Permissions

### Android
- `ACCESS_FINE_LOCATION`: Required for precise GPS location
- `ACCESS_COARSE_LOCATION`: Required for approximate location
- `READ_EXTERNAL_STORAGE`: Required for file access
- `WRITE_EXTERNAL_STORAGE`: Required for file operations

### iOS
- `NSLocationWhenInUseUsageDescription`: Required for location access
- `NSLocationAlwaysAndWhenInUseUsageDescription`: Required for location access

## Usage

### Encrypting a PDF

1. Open the app and ensure location services are enabled
2. Tap "Encrypt PDF" or use the bottom navigation
3. Select a PDF file from your device
4. Configure encryption options:
   - **Decryption Radius**: Set how close you need to be to decrypt (10m-1000m)
   - **Expiration Time**: Optionally set when the file expires
5. Tap "Encrypt PDF" to encrypt the file

### Decrypting a PDF

1. Go to "Decrypt PDF" or "Files" section
2. Select an encrypted `.geolock` file
3. Ensure you're at the correct location (within the specified radius)
4. Ensure the file hasn't expired (if expiration was set)
5. Tap "Decrypt PDF" to decrypt the file

### Managing Files

- View all encrypted files in the "Files" section
- See file details including location, expiration, and radius
- Delete unwanted encrypted files
- Refresh the file list

## Technical Details

### Encryption Algorithm
- **Symmetric Encryption**: AES-256
- **Key Derivation**: SHA-256 hash of master key
- **Metadata Storage**: JSON-encoded location and time data

### File Structure
```
encrypted_file.geolock:
├── Encrypted Package
    ├── Metadata (JSON)
    │   ├── Latitude
    │   ├── Longitude
    │   ├── Encryption Time
    │   ├── Expiration Time (optional)
    │   ├── Radius (meters)
    │   └── Original File Info
    └── PDF Data (Base64 encoded)
```

### Location Validation
- Uses Haversine formula for distance calculation
- Validates current location against encryption location
- Checks if current location is within specified radius

## Security Considerations

- **Location Privacy**: Location data is stored locally and encrypted
- **Key Management**: Encryption keys are derived from a master key
- **File Access**: Only accessible through the app with proper location validation
- **Time Validation**: Expired files cannot be decrypted

## Troubleshooting

### Common Issues

1. **Location Not Available**
   - Ensure location services are enabled
   - Check app permissions
   - Try refreshing location

2. **Decryption Failed**
   - Verify you're at the correct location
   - Check if file has expired
   - Ensure you're within the specified radius

3. **File Not Found**
   - Check if file exists in the encrypted files list
   - Try refreshing the file list

### Debug Mode

Enable debug mode to see detailed error messages:
```bash
flutter run --debug
```

## Development

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── encryption_options.dart
├── screens/
│   ├── home_screen.dart
│   ├── encrypt_screen.dart
│   ├── decrypt_screen.dart
│   └── files_screen.dart
└── services/
    ├── location_service.dart
    ├── encryption_service.dart
    ├── file_service.dart
    └── permission_service.dart
```

### Adding New Features

1. New service classes in `lib/services/`
2. Add new screens in `lib/screens/`
3. Update navigation in `main.dart`
4. Add new models in `lib/models/`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Check the troubleshooting section
- Review the Flutter documentation

## Changelog

### Version 1.0.0
- Initial release
- Location-based PDF encryption
- Time-based access control
- Cross-platform support
- User-friendly interface
