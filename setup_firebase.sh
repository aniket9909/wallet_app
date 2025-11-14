#!/bin/bash

# ============================================================================
# Firebase Realtime Database Setup Script for E-Wallet App
# ============================================================================
# 
# This script helps you set up Firebase Realtime Database for the E-Wallet app.
# 
# Prerequisites:
# 1. Node.js installed
# 2. Firebase CLI installed: npm install -g firebase-tools
# 3. Logged in to Firebase: firebase login
# ============================================================================

set -e

echo ""
echo "============================================================================"
echo "🔥  Firebase Realtime Database Setup for E-Wallet App"
echo "============================================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI is not installed!${NC}"
    echo ""
    echo "Install it with:"
    echo "  npm install -g firebase-tools"
    exit 1
fi

echo -e "${GREEN}✅ Firebase CLI found${NC}"
echo ""

# Check if logged in
if ! firebase projects:list &> /dev/null; then
    echo -e "${YELLOW}⚠️  Not logged in to Firebase${NC}"
    echo "Logging in..."
    firebase login
fi

echo -e "${GREEN}✅ Firebase authentication OK${NC}"
echo ""

# Check if database.rules.json exists
if [ ! -f "database.rules.json" ]; then
    echo -e "${RED}❌ database.rules.json not found!${NC}"
    echo "Creating it..."
    
    cat > database.rules.json << 'EOF'
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
EOF
    
    echo -e "${GREEN}✅ database.rules.json created${NC}"
fi

echo ""
echo "============================================================================"
echo "📋  Next Steps (Manual Actions Required)"
echo "============================================================================"
echo ""
echo -e "${BLUE}1. Open Firebase Console and complete these steps:${NC}"
echo ""
echo "   A. Enable Authentication:"
echo "      → https://console.firebase.google.com/project/ewallet-2d1f1/authentication"
echo "      → Click 'Get Started'"
echo "      → Go to 'Sign-in method' tab"
echo "      → Enable 'Email/Password'"
echo "      → Enable 'Google' (optional)"
echo "      → Click 'Save'"
echo ""
echo "   B. Create Realtime Database:"
echo "      → https://console.firebase.google.com/project/ewallet-2d1f1/database"
echo "      → Click 'Create Database'"
echo "      → Select 'Start in test mode'"
echo "      → Choose location (e.g., us-central1)"
echo "      → Click 'Enable'"
echo ""
echo "   C. Update Database Rules:"
echo "      → Go to 'Rules' tab"
echo "      → Copy the content from database.rules.json"
echo "      → Paste in the rules editor"
echo "      → Click 'Publish'"
echo ""
echo "============================================================================"
echo ""
echo -e "${GREEN}✅ Setup files are ready!${NC}"
echo ""
echo "📁 Created files:"
echo "   • database.rules.json - Database security rules"
echo "   • database_schema.json - Database structure reference"
echo ""
echo "🚀 After completing the manual steps above, your app will work!"
echo ""
echo "============================================================================"
echo ""

