# 🚀 E-Wallet App - Setup Guide

Welcome to the E-Wallet & Expense Management App! This guide will help you set up and run the new modern version of the application.

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Firebase Setup](#firebase-setup)
4. [Running the App](#running-the-app)
5. [Project Structure](#project-structure)
6. [Features Overview](#features-overview)
7. [Troubleshooting](#troubleshooting)

## ✅ Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.16 or higher)
  ```bash
  flutter --version
  ```
- **Dart SDK** (comes with Flutter)
- **Android Studio** or **VS Code** with Flutter extensions
- **Git**
- **Firebase CLI** (optional, for advanced Firebase operations)

## 📥 Installation

### 1. Clone the Repository
```bash
git clone <your-repo-url>
cd wallet_app
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Verify Installation
```bash
flutter doctor
```
Make sure all checkmarks are green (especially Flutter, Android toolchain, and your IDE).

## 🔥 Firebase Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add Project"
3. Enter project name: "E-Wallet App" (or your preferred name)
4. Follow the setup wizard

### Step 2: Enable Firebase Services

#### A. Firebase Authentication
1. In Firebase Console, go to **Authentication**
2. Click "Get Started"
3. Enable **Email/Password** sign-in method
4. Enable **Google** sign-in method (optional but recommended)

#### B. Firebase Realtime Database
1. In Firebase Console, go to **Realtime Database**
2. Click "Create Database"
3. Choose location closest to your users
4. Start in **Test Mode** (we'll update rules later)

#### C. Firebase Storage (Optional)
1. In Firebase Console, go to **Storage**
2. Click "Get Started"
3. Follow the setup wizard

### Step 3: Configure Firebase for Android

1. In Firebase Console, click "Add App" → Android icon
2. Enter Android package name: `com.aniket.ewallet` (check in `android/app/build.gradle`)
3. Download `google-services.json`
4. Place it in `android/app/` directory

### Step 4: Configure Firebase for iOS (if building for iOS)

1. In Firebase Console, click "Add App" → iOS icon
2. Enter iOS bundle ID (check in Xcode or `ios/Runner.xcodeproj`)
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/` directory

### Step 5: Update Firebase Rules

#### Realtime Database Rules
In Firebase Console → Realtime Database → Rules, paste:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    }
  }
}
```

#### Firestore Rules (if using Firestore)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() { return request.auth != null; }
    function isOwner(uid) { return isSignedIn() && request.auth.uid == uid; }

    match /users/{uid} {
      allow read, write: if isOwner(uid);

      match /{sub=**}/{doc} {
        allow read, write: if isOwner(uid);
      }
    }
  }
}
```

### Step 6: Firebase Options (Already Configured)

The `firebase_options.dart` file should already be configured. If you need to regenerate it:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Configure FlutterFire
flutterfire configure
```

## 🏃 Running the App

### Run the New Modern Version

```bash
# Run on connected device/emulator
flutter run -t lib/main_new.dart

# Or run in debug mode
flutter run lib/main_new.dart

# Run on specific device
flutter run -t lib/main_new.dart -d <device-id>
```

### Build for Production

```bash
# Android APK
flutter build apk --release -t lib/main_new.dart

# Android App Bundle (for Play Store)
flutter build appbundle --release -t lib/main_new.dart

# iOS (on macOS only)
flutter build ios --release -t lib/main_new.dart
```

## 📁 Project Structure

```
lib/
├── data/                       # Data Layer
│   ├── models/                 # Data models (Wallet, Account, Transaction, etc.)
│   ├── services/               # Firebase services
│   └── repositories/           # Data repositories
├── logic/                      # Business Logic Layer
│   └── cubits/                 # BLoC/Cubit state management
├── presentation/               # Presentation Layer
│   ├── screens/                # App screens
│   ├── widgets/                # Reusable widgets
│   └── theme/                  # App theming
├── features/                   # Feature-specific modules
│   └── auth/                   # Authentication screens
├── routes/                     # Navigation and routing
├── main_new.dart              # New app entry point ⭐
└── view/                       # Legacy views
```

## 🎯 Features Overview

### 1. **Dashboard** 📊
- Real-time balance overview
- Income vs Expense charts
- Monthly summary
- Animated cards and transitions

### 2. **Accounts** 💳
- Manage multiple accounts (Bank, Cash, UPI, Credit Card)
- Add/Edit/Delete accounts
- Quick transaction entry via FAB

### 3. **Smart Savings** 💰
- Create savings goals
- Track progress with visual indicators
- Calculate required monthly savings
- Update progress as you save

### 4. **Expense Tracker** 📈
- View all transactions
- Filter by date (Today, Week, Month, All)
- Category-wise expense breakdown
- Interactive pie charts

### 5. **Settings** ⚙️
- Profile management
- Bank and card details
- Manage expense categories
- Dark/Light mode toggle
- Notification preferences

## 🐛 Troubleshooting

### Common Issues

#### 1. Firebase Connection Error
```
Error: FirebaseException: [core/no-app]
```
**Solution**: Make sure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in the correct directories.

#### 2. Build Errors
```bash
# Clean build
flutter clean
flutter pub get
flutter run -t lib/main_new.dart
```

#### 3. Gradle Build Failed (Android)
- Check `android/app/build.gradle` compileSdkVersion (should be 34 or higher)
- Update Gradle wrapper if needed:
  ```bash
  cd android
  ./gradlew wrapper --gradle-version 8.0
  ```

#### 4. Firebase Database Permission Denied
- Check Firebase Realtime Database Rules
- Ensure user is authenticated
- Verify user ID matches database path

#### 5. Hot Reload Not Working
```bash
# Restart the app
r (in terminal)

# Or hot restart
R (in terminal)
```

### Debug Mode

Enable verbose logging:
```bash
flutter run -t lib/main_new.dart --verbose
```

View logs:
```bash
# Android
adb logcat

# iOS
flutter logs
```

## 📱 Test Credentials

For testing, you can create a test account:
1. Run the app
2. Click "Create Account" on login screen
3. Enter:
   - Name: Test User
   - Email: test@example.com
   - Password: test123

## 🔐 Security Notes

1. **Never commit** Firebase config files to public repositories
2. Update Firebase rules before production deployment
3. Enable **App Check** for production apps
4. Use **environment variables** for sensitive data

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [BLoC Pattern](https://bloclibrary.dev/)
- [Material Design 3](https://m3.material.io/)

## 🤝 Support

If you encounter any issues:
1. Check this guide first
2. Search existing issues in the repository
3. Create a new issue with details:
   - Flutter version (`flutter --version`)
   - Error messages
   - Steps to reproduce

## 🎉 Success!

If you see the splash screen followed by the login page, congratulations! You've successfully set up the E-Wallet app.

### Next Steps:
1. Create an account
2. Add your first account (Bank/Cash)
3. Record a transaction
4. Create a savings goal
5. Explore the expense tracker

---

**Happy Coding! 💙**

Made with ❤️ using Flutter

