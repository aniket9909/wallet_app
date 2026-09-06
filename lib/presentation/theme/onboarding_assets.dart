class OnboardingAssets {
  OnboardingAssets._();

  static const accounts = 'assets/images/onboarding/onboarding_accounts.png';
  static const budget = 'assets/images/onboarding/onboarding_budget.png';
  static const home = 'assets/images/onboarding/onboarding_home.png';
  static const permissions = 'assets/images/onboarding/onboarding_permissions.png';

  static const accountBank = 'assets/images/accounts/account_bank.png';
  static const accountCash = 'assets/images/accounts/account_cash.png';
  static const accountUpi = 'assets/images/accounts/account_upi.png';
  static const accountCreditCard = 'assets/images/accounts/account_credit_card.png';

  static String accountTypeIcon(String type) {
    switch (type) {
      case 'Bank':
        return accountBank;
      case 'Cash':
        return accountCash;
      case 'UPI':
        return accountUpi;
      case 'Credit Card':
        return accountCreditCard;
      default:
        return accountBank;
    }
  }
}
