# 🚨 SIGAP Admin - Emergency Communication Administrative Dashboard

An Android application for government and emergency coordinators to manage emergency incidents and coordinate field operations. Part of the SIGAP (Sistem Informasi Gawat Darurat - Emergency Information System) ecosystem for emergency communication.

## 📋 Overview

SIGAP Admin is the administrative hub for emergency response coordination that enables:
- **Incident Management**: Create, track, and manage emergency incidents
- **Field Operations**: Coordinate response teams and field device deployments
- **User Management**: Manage admin accounts, field operators, and emergency response personnel
- **Device Oversight**: Monitor and manage field devices running SIGAP firmware
- **Real-time Coordination**: Track emergency communications and response status
- **Data Analytics**: View emergency patterns and response metrics

## 🏗️ System Architecture

SIGAP is a complete emergency communication system consisting of three main components:

### 1. **[Android_sigapUser](https://github.com/Nfx1z/Android_sigapUser)** 
- End-user mobile application for emergency messaging
- Built with Flutter/Dart
- Uses BLE for message transmission to field devices
- Integrated GPS for location tracking
- Works as alternative communication when networks are down
- **For**: Victims, general public, emergency reporters

### 2. **Android_sigapAdmin** (This Repository)
- Administrative dashboard for government and emergency coordinators
- Manages emergency incidents and field operations
- Central coordination hub for emergency response
- User and field device management
- Real-time monitoring and analytics
- **For**: Government agencies, emergency coordinators, incident commanders

### 3. **[sigap-arduino](https://github.com/Nfx1z/sigap-arduino)**
- Field device firmware (Arduino/ESP32 based)
- Receives BLE messages from mobile apps
- Processes and relays emergency alerts
- May include additional sensors and communication modules
- **For**: Emergency response field devices, relay stations

## 🚀 Features

### Admin Dashboard
- **Incident Tracking**: Create and monitor active emergency incidents
- **Real-time Updates**: Live status of emergency communications
- **Field Device Management**: Register, configure, and monitor field devices
- **User Management**: Add/remove authorized admin and field staff
- **Report Generation**: Comprehensive emergency response reports
- **Message Relay**: View and manage emergency messages between users and field devices
- **Location Visualization**: Track incident locations and affected areas
- **Multi-incident Support**: Handle multiple simultaneous emergencies

### Communication Management
- **BLE Message Monitoring**: Track messages sent via Bluetooth Low Energy
- **Message History**: Searchable archive of all emergency communications
- **Device Status**: Monitor field device connectivity and status
- **Alert Distribution**: Manage emergency alerts to field devices

### Emergency Categories
- Fire Emergency
- Medical Emergency
- Police/Security
- Natural Disaster
- Infrastructure Damage
- Public Health Emergency
- Custom Categories

## 📱 Technology Stack

- **Language**: Dart
- **Framework**: Flutter
- **Platform**: Android
- **Backend**: Firebase (Firestore, Realtime Database, Cloud Functions)
- **Authentication**: Firebase Authentication
- **Architecture**: Clean Architecture with state management

## ⚙️ Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio or VS Code with Flutter extensions
- Android device or emulator (API level 21+)
- Firebase project with Firestore and Realtime Database
- Internet connection for admin operations (BLE communication handled by field devices)

## 🔧 Installation

### 1. Clone the repository
```bash
git clone https://github.com/Nfx1z/Android_sigapAdmin.git
cd Android_sigapAdmin
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
- Copy the example configuration:
  ```bash
  cp lib/config.dart.example lib/config.dart
  ```
- Add your Firebase database URL and credentials in `lib/config.dart`
- Ensure Firebase project has Firestore and Realtime Database enabled

### 4. Build and run
```bash
flutter run
```

## 📝 Configuration

### Firebase Setup
1. Create a Firebase project
2. Enable Firestore Database
3. Enable Realtime Database
4. Set up Firebase Authentication
5. Update `lib/config.dart` with your database URL:
   ```dart
   class Config {
     static const String firebaseUrl = 'your-firebase-database-url';
     static const String firestoreProjectId = 'your-project-id';
   }
   ```

### User Roles
- **Admin**: Full access to all functions
- **Coordinator**: Can manage incidents and view reports
- **Operator**: Can monitor devices and view communications

## 🔐 Security

- Firebase authentication for admin access
- Role-based access control (RBAC)
- Encrypted communication with field devices
- Audit logs for all administrative actions

## 📊 Database Schema

### Main Collections
- **incidents**: Active and historical emergency incidents
- **users**: Admin and coordinator user accounts
- **devices**: Registered field devices
- **messages**: Emergency communications log
- **locations**: GPS coordinates and incident locations

## 🌐 Integration with SIGAP Ecosystem

### Data Flow
```
Citizens/Users (sigapUser App)
    ↓ (BLE Messages)
Field Devices (Arduino/ESP32)
    ↓ (Relay/Sync)
SIGAP Admin Dashboard
    ↓ (Coordination)
Government Agencies & Emergency Services
```

### Workflow
1. Users report emergencies via **sigapUser** mobile app
2. Emergency messages transmitted via **BLE to field devices**
3. Field devices receive and process alerts (**sigap-arduino**)
4. Admin dashboard displays incident overview (**Android_sigapAdmin**)
5. Emergency coordinators manage response and dispatch resources

## 📞 Related Repositories

- **[Android_sigapUser](https://github.com/Nfx1z/Android_sigapUser)** - User emergency reporting app
- **[sigap-arduino](https://github.com/Nfx1z/sigap-arduino)** - Field device firmware

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is part of the SIGAP emergency communication system.

## ⚠️ Important Notes

- This application is designed for official emergency response coordination
- Ensure proper authorization and authentication before deployment
- Regular testing required to ensure BLE connectivity between systems
- Field devices must be registered and configured before use
- Keep Firebase credentials secure and never commit to version control

## 📚 Documentation

For more information about the SIGAP system architecture and integration, refer to:
- Individual repository documentation
- System architecture diagrams
- Integration guides

## 🆘 Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

**Part of the SIGAP Emergency Communication System** 🚨
