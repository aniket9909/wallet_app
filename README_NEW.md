# 🪙 E-Wallet & Expense Management App

A modern, fully-featured Flutter E-Wallet and Expense Management application with Firebase Realtime Database backend, BLoC architecture, and beautiful UI animations.

## ✨ Features

### 📱 Core Features
- **Dashboard**: Real-time balance overview with animated cards and charts
- **Accounts Management**: Manage multiple accounts (Bank, Cash, UPI, Credit Card)
- **Smart Savings**: Set and track savings goals with progress visualization
- **Expense Tracker**: Detailed expense analysis with category breakdowns and charts
- **Settings**: Manage profile, bank details, expense categories, and preferences

### 🎨 Modern UI/UX
- **Material 3 Design** with custom theming
- **Dark/Light Mode** support
- **Smooth Animations** using flutter_animate
- **Glassmorphism** and gradient effects
- **Interactive Charts** with fl_chart
- **Bottom Navigation** with smooth transitions

### 🏗️ Technical Architecture
- **Clean Architecture** with separation of concerns
- **BLoC Pattern** for state management
- **Repository Pattern** for data layer
- **Firebase Realtime Database** for backend
- **Firebase Authentication** for user management
- **Real-time Data Sync** across devices

## 📂 Project Structure

```
lib/
├── data/
│   ├── models/                 # Data models
│   │   ├── wallet_data_model.dart
│   │   ├── account_model.dart
│   │   ├── transaction_model_new.dart
│   │   ├── savings_goal_model.dart
│   │   └── settings_model.dart
│   ├── services/               # Firebase services
│   │   └── firebase_realtime_service.dart
│   └── repositories/           # Data repositories
│       ├── wallet_repository.dart
│       ├── account_repository.dart
│       ├── transaction_repository.dart
│       ├── savings_goal_repository.dart
│       └── settings_repository.dart
├── logic/
│   └── cubits/                 # BLoC/Cubit state management
│       ├── wallet_cubit.dart
│       ├── account_cubit.dart
│       ├── transaction_cubit.dart
│       ├── savings_goal_cubit.dart
│       └── settings_cubit.dart
├── presentation/
│   ├── screens/                # App screens
│   │   ├── dashboard_screen.dart
│   │   ├── accounts_screen.dart
│   │   ├── savings_screen.dart
│   │   ├── expense_tracker_screen.dart
│   │   ├── settings_screen.dart
│   │   └── main_navigation_screen.dart
│   ├── widgets/                # Reusable widgets
│   │   ├── balance_card.dart
│   │   ├── income_expense_chart.dart
│   │   ├── monthly_summary_card.dart
│   │   ├── add_transaction_modal.dart
│   │   ├── add_account_modal.dart
│   │   ├── goal_progress_card.dart
│   │   ├── add_goal_modal.dart
│   │   ├── transaction_list_item.dart
│   │   ├── category_chart.dart
│   │   └── settings_section.dart
│   └── theme/
│       └── app_theme.dart
├── features/
│   └── auth/                   # Authentication screens
│       ├── login_page.dart
│       ├── register_page.dart
│       └── forgot_password_page.dart
├── routes/
│   ├── app_routes.dart
│   └── app_pages_new.dart
├── main_new.dart               # New app entry point
└── view/
    └── splash_screen_new.dart
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.16+)
- Firebase project with Realtime Database enabled
- Android Studio / VS Code with Flutter extensions

### Installation

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd wallet_app
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Firebase**
- Add your `google-services.json` to `android/app/`
- Add your `GoogleService-Info.plist` to `ios/Runner/`
- Update `firebase_options.dart` with your Firebase configuration

4. **Run the app**
```bash
flutter run lib/main_new.dart
```

## 📊 Firebase Database Structure

```json
{
  "users": {
    "{userId}": {
      "wallet": {
        "total_balance": 15000,
        "total_income": 40000,
        "total_expense": 25000,
        "monthly_income": 20000,
        "monthly_expense": 15000
      },
      "accounts": {
        "{accountId}": {
          "name": "Bank Account",
          "balance": 10000,
          "type": "Bank",
          "icon": null,
          "color": null
        }
      },
      "transactions": {
        "{transactionId}": {
          "type": "credit",
          "amount": 2000,
          "description": "Freelance Work",
          "category": "Income",
          "account": "Bank Account",
          "date": "2025-10-13",
          "note": null
        }
      },
      "goals": {
        "{goalId}": {
          "name": "New Bike",
          "target_amount": 80000,
          "monthly_income": 40000,
          "monthly_expense": 30000,
          "time_period": 12,
          "saved_so_far": 15000,
          "created_date": "2025-10-12",
          "target_date": null
        }
      },
      "settings": {
        "notifications": true,
        "dark_mode": false,
        "currency": "₹",
        "bank_details": {
          "account_number": "XXXX1234",
          "ifsc": "ABC12345",
          "bank_name": "HDFC Bank"
        },
        "card_details": {
          "card_number": "XXXX XXXX XXXX 4321",
          "expiry": "12/28",
          "card_type": "Debit"
        },
        "expense_types": ["Food", "Bills", "Shopping", "Travel", "Entertainment", "Health", "Other"],
        "profile": {
          "name": "Aniket Tekawade",
          "email": "aniket@example.com",
          "phone": "+91 9876543210",
          "avatar": null
        }
      }
    }
  }
}
```

## 📦 Dependencies

### Core
- `flutter_bloc: ^8.1.6` - State management
- `firebase_core: ^3.13.0` - Firebase core
- `firebase_database: ^11.2.0` - Realtime Database
- `firebase_auth: ^5.3.5` - Authentication
- `equatable: ^2.0.7` - Value equality

### UI & Animations
- `flutter_animate: ^4.5.0` - Animations
- `fl_chart: ^0.69.2` - Charts
- `syncfusion_flutter_charts: ^27.2.5` - Advanced charts
- `shimmer: ^3.0.0` - Shimmer effects
- `flutter_slidable: ^3.1.1` - Slidable widgets

### Utilities
- `intl: ^0.19.0` - Internationalization
- `uuid: ^4.5.1` - UUID generation

## 🎯 Key Features Explained

### 1. Dashboard
- Animated balance card with gradient design
- Income vs Expense pie chart
- Monthly summary with profit/loss indicator
- Real-time balance updates

### 2. Accounts
- Multiple account types support
- Visual account cards with gradients
- Quick transaction modal
- Account balance tracking

### 3. Smart Savings
- Goal creation with step-by-step planning
- Progress visualization with animated rings
- Monthly savings calculation
- Goal completion tracking

### 4. Expense Tracker
- Category-wise expense breakdown
- Interactive pie charts
- Date range filters (Today, This Week, This Month, All)
- Transaction history with details

### 5. Settings
- Profile management
- Bank and card details
- Expense category management
- Dark/Light mode toggle
- Notification preferences

## 🔐 Firebase Security Rules

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

## 🛠️ Development

### Running with new architecture
```bash
flutter run lib/main_new.dart
```

### Build for production
```bash
flutter build apk --release -t lib/main_new.dart
```

### Running tests
```bash
flutter test
```

## 📱 Screenshots

*(Add your app screenshots here)*

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.

## 👨‍💻 Author

**Aniket Tekawade**

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for the backend infrastructure
- fl_chart for beautiful charts
- All open-source contributors

---

**Note**: This is the new modern architecture. The old files are preserved for compatibility. To use the new app, run `flutter run lib/main_new.dart`

