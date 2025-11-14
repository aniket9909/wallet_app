# 🔥 Firebase Realtime Database Setup Guide

This guide will help you set up Firebase Realtime Database for the E-Wallet app.

## 📁 Setup Files Created

- ✅ `database.rules.json` - Database security rules
- ✅ `database_schema.json` - Database structure reference  
- ✅ `setup_firebase.sh` - Automated setup script
- ✅ `firebase_setup.js` - Node.js setup script (advanced)

---

## 🚀 Quick Setup (Recommended)

### **Option 1: Automated Script**

```bash
# Run the setup script
./setup_firebase.sh
```

The script will guide you through the process!

### **Option 2: Manual Setup**

Follow the steps below:

---

## 📋 Manual Setup Steps

### **Step 1: Enable Authentication** ⚡ REQUIRED

1. Go to [Firebase Console - Authentication](https://console.firebase.google.com/project/ewallet-2d1f1/authentication)
2. Click **"Get Started"** button
3. Click **"Sign-in method"** tab
4. Find **"Email/Password"** → Click → **Enable** → **Save**
5. Find **"Google"** → Click → **Enable** → **Save** (optional but recommended)

### **Step 2: Create Realtime Database** ⚡ REQUIRED

1. Go to [Firebase Console - Database](https://console.firebase.google.com/project/ewallet-2d1f1/database)
2. Click **"Create Database"** button
3. Choose **"Start in test mode"**
4. Select location: **us-central1** (or closest to your users)
5. Click **"Enable"**

### **Step 3: Update Database Rules** ⚡ REQUIRED

1. In Firebase Console → **Realtime Database** → **Rules** tab
2. Copy this content:

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

3. **Paste** it in the rules editor
4. Click **"Publish"**

---

## 🏗️ Database Schema

The database structure will be automatically created when users register. Here's the reference:

```
users/
  {userId}/
    ├── wallet/                          # Wallet summary
    │   ├── total_balance: 0
    │   ├── total_income: 0
    │   ├── total_expense: 0
    │   ├── monthly_income: 0
    │   └── monthly_expense: 0
    │
    ├── accounts/                        # User accounts
    │   {accountId}/
    │       ├── name: "Bank Account"
    │       ├── balance: 10000
    │       ├── type: "Bank" / "Cash" / "UPI" / "Credit Card"
    │       ├── icon: null
    │       └── color: null
    │
    ├── transactions/                    # All transactions
    │   {transactionId}/
    │       ├── type: "credit" / "debit"
    │       ├── amount: 2000
    │       ├── description: "Salary"
    │       ├── category: "Income"
    │       ├── account: "Bank Account"
    │       ├── date: "2025-05-11T12:00:00.000Z"
    │       └── note: null
    │
    ├── goals/                          # Savings goals
    │   {goalId}/
    │       ├── name: "New Laptop"
    │       ├── target_amount: 80000
    │       ├── monthly_income: 40000
    │       ├── monthly_expense: 30000
    │       ├── time_period: 12
    │       ├── saved_so_far: 15000
    │       ├── created_date: "2025-05-11T12:00:00.000Z"
    │       └── target_date: null
    │
    └── settings/                       # User settings
        ├── notifications: true
        ├── dark_mode: false
        ├── currency: "₹"
        ├── bank_details/
        │   ├── account_number: ""
        │   ├── ifsc: ""
        │   └── bank_name: ""
        ├── card_details/
        │   ├── card_number: ""
        │   ├── expiry: ""
        │   └── card_type: "Debit"
        ├── expense_types: ["Food", "Bills", "Shopping", ...]
        └── profile/
            ├── name: ""
            ├── email: ""
            ├── phone: null
            └── avatar: null
```

---

## 🔧 Advanced: Using Firebase CLI

### **Install Firebase CLI**

```bash
# Install
npm install -g firebase-tools

# Login
firebase login

# Initialize (if not already done)
firebase init
```

### **Deploy Database Rules**

```bash
# Using the rules file
firebase deploy --only database

# Or specify the rules file
firebase deploy --only database:rules --rules database.rules.json
```

---

## ✅ Verification

After setup, verify by:

1. **Running the app**:
   ```bash
   flutter run -t lib/main.dart
   ```

2. **Register a new user** in the app

3. **Check Firebase Console** → Realtime Database → You should see `users/{userId}/` structure

---

## 🐛 Troubleshooting

### **Error: CONFIGURATION_NOT_FOUND**

❌ **Problem**: Authentication not enabled  
✅ **Solution**: Complete Step 1 (Enable Authentication)

### **Error: Permission denied**

❌ **Problem**: Database rules not configured  
✅ **Solution**: Complete Step 3 (Update Database Rules)

### **No data in database**

❌ **Problem**: App working but no data  
✅ **Solution**: This is normal - data is created when users register/use the app

---

## 📚 Additional Resources

- [Firebase Realtime Database Docs](https://firebase.google.com/docs/database)
- [Firebase Auth Docs](https://firebase.google.com/docs/auth)
- [Firebase CLI Reference](https://firebase.google.com/docs/cli)

---

## 🎉 Setup Complete!

Once you've completed all 3 manual steps:
1. ✅ Authentication enabled
2. ✅ Realtime Database created
3. ✅ Rules published

Your app will work perfectly! 🚀

---

**Need help?** Check the troubleshooting section or create an issue in the repository.

