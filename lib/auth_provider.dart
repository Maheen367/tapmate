// lib/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isGuest = false;
  bool _isLoggedIn = false;
  bool _hasCompletedOnboarding = false;
  String _userId = '';
  bool _isNewSignUp = false;
  String _userEmail = '';

  bool get isGuest => _isGuest;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get canAccessFullFeatures => _isLoggedIn && !_isGuest;

  // NEW GETTERS
  String get userId => _isGuest ? 'guest' : _userId.isNotEmpty ? _userId : 'unknown';
  bool? get isNewSignUp => _isNewSignUp;
  String get userEmail => _userEmail;

  AuthProvider() {
    _loadAuthState();
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool('is_guest') ?? false;
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
    _userId = prefs.getString('user_id') ?? '';
    _userEmail = prefs.getString('user_email') ?? '';
    _isNewSignUp = prefs.getBool('is_new_signup') ?? false;
    notifyListeners();
  }

  // NEW: Set user ID and email (call this after login/signup)
  Future<void> setUserInfo({required String userId, required String email}) async {
    _userId = userId;
    _userEmail = email;
    _isGuest = false;
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_email', email);
    await prefs.setBool('is_guest', false);
    await prefs.setBool('is_logged_in', true);

    notifyListeners();
  }

  // NEW: Mark as new sign-up (call this after sign-up)
  Future<void> markAsNewSignUp() async {
    _isNewSignUp = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_new_signup', true);
    notifyListeners();
  }

  // NEW: Clear new sign-up flag (after guide shown)
  Future<void> clearNewSignUpFlag() async {
    _isNewSignUp = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_new_signup', false);
    notifyListeners();
  }

  // UPDATED: Guest mode
  Future<void> setGuestMode(bool isGuest) async {
    _isGuest = isGuest;
    _isLoggedIn = !isGuest;
    _userId = isGuest ? 'guest' : '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', isGuest);
    await prefs.setBool('is_logged_in', !isGuest);
    await prefs.setString('user_id', isGuest ? 'guest' : '');

    if (isGuest) {
      await prefs.setBool('is_new_signup', false);
      _isNewSignUp = false;
    }

    notifyListeners();
  }

  // UPDATED: Logged in
  Future<void> setLoggedIn(bool loggedIn) async {
    _isLoggedIn = loggedIn;
    _isGuest = !loggedIn;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', loggedIn);
    await prefs.setBool('is_guest', !loggedIn);

    if (!loggedIn) {
      _userId = '';
      await prefs.setString('user_id', '');
    }

    notifyListeners();
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    _hasCompletedOnboarding = completed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', completed);
    notifyListeners();
  }

  Future<void> logout() async {
    _isGuest = false;
    _isLoggedIn = false;
    _userId = '';
    _userEmail = '';
    _isNewSignUp = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', false);
    await prefs.setBool('is_logged_in', false);
    await prefs.setString('user_id', '');
    await prefs.setString('user_email', '');
    await prefs.setBool('is_new_signup', false);

    notifyListeners();
  }

  // NEW: Generate a simple user ID from email
  static String generateUserIdFromEmail(String email) {
    if (email.isEmpty) return 'unknown';
    return email.split('@').first + '_' + DateTime.now().millisecondsSinceEpoch.toString();
  }

  // NEW: Check if user exists (for debugging)
  Future<bool> hasUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id')?.isNotEmpty ?? false;
  }
}




