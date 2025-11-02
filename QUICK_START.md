# ⚡ Quick Start Guide

## 🎯 Get Up and Running in 5 Minutes

### Step 1: Install Dependencies (1 min)
```bash
cd /home/aniket/codes/personal/wallet_app
flutter pub get
```

### Step 2: Configure Firebase (2 mins)

#### Your `google-services.json` is already in place ✅
Located at: `android/app/google-services.json`

#### Update Firebase Realtime Database Rules:
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Realtime Database** → **Rules**
4. Paste this and publish:

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

#### Enable Authentication:
1. In Firebase Console → **Authentication**
2. Click **Get Started**
3. Enable **Email/Password** method
4. Click **Save**

### Step 3: Run the App! (2 mins)

#### Option A: Using Terminal
```bash
# Connect your device or start emulator, then:
flutter run -t lib/main_new.dart
```

#### Option B: Using VS Code
1. Open Command Palette (`Ctrl+Shift+P` or `Cmd+Shift+P`)
2. Type "Flutter: Launch Emulator"
3. Select an emulator
4. Press `F5` and select `lib/main_new.dart`

#### Option C: Using Android Studio
1. Select device/emulator
2. Right-click on `lib/main_new.dart`
3. Click "Run 'main_new.dart'"

### Step 4: Test the App

1. **Splash Screen** (3 seconds)
   - You'll see an animated wallet icon

2. **Login Screen**
   - Click "Create Account"

3. **Register**
   - Name: Test User
   - Email: test@example.com
   - Password: test123
   - Click "Create Account"

4. **Dashboard** (Main Screen)
   - You'll see the dashboard with balance cards
   - Navigate between tabs:
     - 📊 Dashboard
     - 💳 Accounts
     - 💰 Savings
     - 📈 Expenses
     - ⚙️ Settings

5. **Add Your First Account**
   - Go to "Accounts" tab
   - Click "+" icon (top right)
   - Enter: Name: "Bank Account", Balance: 10000, Type: Bank
   - Click "Add Account"

6. **Add Your First Transaction**
   - Click the "Transaction" FAB button
   - Select: Credit
   - Amount: 5000
   - Description: "Salary"
   - Category: Income
   - Account: Bank Account
   - Click "Add Transaction"

7. **Create a Savings Goal**
   - Go to "Savings" tab
   - Click "New Goal" FAB
   - Fill in the details:
     - Goal Name: "New Laptop"
     - Target Amount: 50000
     - Monthly Income: 30000
     - Monthly Expense: 20000
     - Time Period: 6 months
   - Click "Create Goal"

8. **View Expenses**
   - Go to "Expenses" tab
   - Add some debit transactions
   - See the category chart and breakdown

9. **Configure Settings**
   - Go to "Settings" tab
   - Toggle dark mode
   - Add bank details
   - Manage expense categories

## 🎉 You're All Set!

Your E-Wallet app is now running with:
- ✅ Real-time Firebase sync
- ✅ Beautiful modern UI
- ✅ All features working
- ✅ Dark/Light mode
- ✅ Smooth animations

## 🔧 Common Commands

```bash
# Run in debug mode
flutter run -t lib/main_new.dart

# Run with hot reload
flutter run -t lib/main_new.dart --hot

# Build release APK
flutter build apk --release -t lib/main_new.dart

# Clear cache and rebuild
flutter clean && flutter pub get && flutter run -t lib/main_new.dart

# Check for issues
flutter doctor

# View logs
flutter logs
```

## 📱 Device Requirements

- **Android**: API 21+ (Android 5.0 Lollipop or higher)
- **iOS**: iOS 12.0 or higher
- **RAM**: 2GB minimum, 4GB recommended
- **Storage**: 100MB for app

## 🆘 Quick Troubleshooting

### App won't start?
```bash
flutter clean
flutter pub get
flutter run -t lib/main_new.dart
```

### Firebase error?
- Check internet connection
- Verify `google-services.json` is in `android/app/`
- Ensure Firebase rules are published
- Verify Email/Password auth is enabled

### Build error?
```bash
cd android
./gradlew clean
cd ..
flutter run -t lib/main_new.dart
```

### Hot reload not working?
- Press `r` in terminal for hot reload
- Press `R` in terminal for hot restart

## 📚 Next Steps

1. Read **SETUP_GUIDE.md** for detailed setup
2. Read **README_NEW.md** for full documentation
3. Read **IMPLEMENTATION_SUMMARY.md** for technical details
4. Explore the code in `lib/presentation/screens/`
5. Customize the theme in `lib/presentation/theme/app_theme.dart`

## 🎨 Customization Quick Tips

### Change App Colors
Edit `lib/presentation/theme/app_theme.dart`:
```dart
seedColor: const Color(0xFF6366F1), // Change this!
```

### Change App Name
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
android:label="Your App Name"
```

### Change App Icon
Place your icon in `assets/logo/` and run:
```bash
flutter pub run flutter_launcher_icons
```

## 💡 Pro Tips

1. **Use Hot Reload** (`r` key) for instant UI updates
2. **Enable logging** to see Firebase operations
3. **Use Redux DevTools** to inspect BLoC state
4. **Test on real device** for better performance feel
5. **Keep Firebase rules updated** before production

## 🚀 Performance Tips

- App should launch in < 3 seconds
- Animations should be smooth (60 fps)
- Navigation should be instant
- Data should sync in real-time
- If slow, try:
  ```bash
  flutter build apk --release -t lib/main_new.dart
  ```

---

**🎊 Enjoy your new E-Wallet app!**

Need help? Check the documentation or create an issue.

**Run Command**: `flutter run -t lib/main_new.dart`

