/**
 * Firebase Realtime Database Setup Script
 * 
 * This script sets up the database rules and initial schema for the E-Wallet app.
 * 
 * Prerequisites:
 * 1. Install Firebase CLI: npm install -g firebase-tools
 * 2. Login: firebase login
 * 3. Initialize (if not done): firebase init
 * 
 * Run this script: node firebase_setup.js
 * 
 * After running, you still need to:
 * 1. Enable Authentication in Firebase Console
 * 2. Enable Email/Password sign-in method
 * 3. Enable Google sign-in (optional)
 */

const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json'); // Download this from Firebase Console

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://ewallet-2d1f1-default-rtdb.firebaseio.com/' // Replace with your DB URL
});

const db = admin.database();

/**
 * Database Schema Structure:
 * 
 * users/
 *   {userId}/
 *     wallet/
 *       total_balance: 0
 *       total_income: 0
 *       total_expense: 0
 *       monthly_income: 0
 *       monthly_expense: 0
 *     accounts/
 *       {accountId}/
 *         name: string
 *         balance: number
 *         type: string (Bank, Cash, UPI, Credit Card)
 *         icon: string?
 *         color: string?
 *     transactions/
 *       {transactionId}/
 *         type: string (credit, debit)
 *         amount: number
 *         description: string
 *         category: string
 *         account: string
 *         date: string (ISO 8601)
 *         note: string?
 *     goals/
 *       {goalId}/
 *         name: string
 *         target_amount: number
 *         monthly_income: number
 *         monthly_expense: number
 *         time_period: number (months)
 *         saved_so_far: number
 *         created_date: string (ISO 8601)
 *         target_date: string? (ISO 8601)
 *     settings/
 *       notifications: boolean
 *       dark_mode: boolean
 *       currency: string
 *       bank_details/
 *         account_number: string
 *         ifsc: string
 *         bank_name: string
 *       card_details/
 *         card_number: string
 *         expiry: string
 *         card_type: string
 *       expense_types: string[]
 *       profile/
 *         name: string
 *         email: string
 *         phone: string?
 *         avatar: string?
 */

async function setupDatabaseRules() {
  console.log('📝 Setting up database rules...');

  const rules = {
    rules: {
      users: {
        $uid: {
          ".read": "$uid === auth.uid",
          ".write": "$uid === auth.uid",
        }
      }
    }
  };

  // Note: In CLI, use: firebase database:rules:set database.rules.json
  console.log('Database rules:');
  console.log(JSON.stringify(rules, null, 2));
  console.log('✅ Rules configuration ready!');
  console.log('📌 Apply rules manually in Firebase Console or via CLI');
}

function createSchemaTemplate() {
  console.log('\n📋 Creating schema template...');

  const schema = {
    users: {
      '{userId}': {
        wallet: {
          total_balance: 0,
          total_income: 0,
          total_expense: 0,
          monthly_income: 0,
          monthly_expense: 0
        },
        accounts: {
          '{accountId}': {
            name: 'Bank Account',
            balance: 0,
            type: 'Bank',
            icon: null,
            color: null
          }
        },
        transactions: {
          '{transactionId}': {
            type: 'credit',
            amount: 0,
            description: 'Sample Transaction',
            category: 'Income',
            account: 'Bank Account',
            date: new Date().toISOString(),
            note: null
          }
        },
        goals: {
          '{goalId}': {
            name: 'Sample Goal',
            target_amount: 10000,
            monthly_income: 5000,
            monthly_expense: 3000,
            time_period: 6,
            saved_so_far: 0,
            created_date: new Date().toISOString(),
            target_date: null
          }
        },
        settings: {
          notifications: true,
          dark_mode: false,
          currency: '₹',
          bank_details: {
            account_number: '',
            ifsc: '',
            bank_name: ''
          },
          card_details: {
            card_number: '',
            expiry: '',
            card_type: 'Debit'
          },
          expense_types: [
            'Food',
            'Bills',
            'Shopping',
            'Travel',
            'Entertainment',
            'Health',
            'Other'
          ],
          profile: {
            name: '',
            email: '',
            phone: null,
            avatar: null
          }
        }
      }
    }
  };

  fs.writeFileSync('database_schema.json', JSON.stringify(schema, null, 2));
  console.log('✅ Schema template created: database_schema.json');
}

function createRulesFile() {
  console.log('\n📝 Creating database rules file...');

  const rules = {
    rules: {
      users: {
        $uid: {
          ".read": "$uid === auth.uid",
          ".write": "$uid === auth.uid",
        }
      }
    }
  };

  fs.writeFileSync('database.rules.json', JSON.stringify(rules, null, 2));
  console.log('✅ Rules file created: database.rules.json');
  console.log('📌 Deploy with: firebase deploy --only database');
}

async function initializeUserData(userId) {
  console.log(`\n👤 Initializing data for user: ${userId}...`);

  const userRef = db.ref(`users/${userId}`);

  const initialData = {
    wallet: {
      total_balance: 0,
      total_income: 0,
      total_expense: 0,
      monthly_income: 0,
      monthly_expense: 0
    },
    settings: {
      notifications: true,
      dark_mode: false,
      currency: '₹',
      expense_types: [
        'Food',
        'Bills',
        'Shopping',
        'Travel',
        'Entertainment',
        'Health',
        'Other'
      ],
      profile: {
        name: '',
        email: '',
        phone: null,
        avatar: null
      }
    }
  };

  try {
    await userRef.set(initialData);
    console.log('✅ User data initialized successfully!');
  } catch (error) {
    console.error('❌ Error initializing user data:', error);
  }
}

// Main execution
async function main() {
  console.log('🔥 Firebase Realtime Database Setup\n');
  console.log('=====================================\n');

  try {
    // Create files for manual setup
    await setupDatabaseRules();
    createSchemaTemplate();
    createRulesFile();

    console.log('\n📌 Manual Steps Required:');
    console.log('1. Enable Authentication in Firebase Console');
    console.log('2. Enable Email/Password sign-in method');
    console.log('3. Enable Google sign-in (optional)');
    console.log('4. Deploy rules: firebase deploy --only database');
    console.log('\n✅ Setup complete!');

    // Uncomment to initialize a specific user
    // initializeUserData('YOUR_USER_ID_HERE');

  } catch (error) {
    console.error('❌ Error during setup:', error);
  } finally {
    process.exit(0);
  }
}

main();

