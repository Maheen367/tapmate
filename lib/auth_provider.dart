// lib/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  bool _isGuest = false;
  bool _isLoggedIn = false;
  bool _hasCompletedOnboarding = false;
  String _userId = '';
  bool _isNewSignUp = false;
  String _userEmail = '';
  String _userName = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get isGuest => _isGuest;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get canAccessFullFeatures => _isLoggedIn && !_isGuest;
  String get userId => _isGuest ? 'guest' : _userId.isNotEmpty ? _userId : 'unknown';
  bool get isNewSignUp => _isNewSignUp;
  String get userEmail => _userEmail;
  String get userName => _userName;

  AuthProvider() {
    _loadAuthState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
      _userEmail = user.email ?? '';
      _userName = user.displayName ?? '';
      _isLoggedIn = true;
      _isGuest = false;
      notifyListeners();
    }
  }

  Future<void> _loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool('is_guest') ?? false;
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
    _userId = prefs.getString('user_id') ?? '';
    _userEmail = prefs.getString('user_email') ?? '';
    _userName = prefs.getString('user_name') ?? '';
    _isNewSignUp = prefs.getBool('is_new_signup') ?? false;
    notifyListeners();
  }

  // 🔥 CHECK IF USERNAME EXISTS
  Future<bool> checkUsernameExists(String username) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking username: $e');
      return false;
    }
  }

  // 🔥 GET SAVED EMAIL (FOR REMEMBER ME)
  Future<String?> getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('saved_email');
    } catch (e) {
      print('Error getting saved email: $e');
      return null;
    }
  }

  // 🔥 SAVE USER EMAIL (REMEMBER ME)
  Future<void> saveUserEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', email);
    } catch (e) {
      print('Error saving email: $e');
    }
  }

  // 🔥 CLEAR SAVED EMAIL
  Future<void> clearSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
    } catch (e) {
      print('Error clearing saved email: $e');
    }
  }

  // 🔥 CHECK IF NEEDS PERMISSION SCREEN
  Future<bool> needsPermissionScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool hasCompletedPermissions = prefs.getBool('has_completed_permissions') ?? false;
      return !hasCompletedPermissions && _isNewSignUp;
    } catch (e) {
      print('Error checking permission screen: $e');
      return false;
    }
  }

  // 🔥 FIREBASE LOGIN METHOD
  Future<Map<String, dynamic>> loginWithEmailPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _userId = result.user?.uid ?? '';
      _userEmail = result.user?.email ?? email;
      _userName = result.user?.displayName ?? '';
      _isLoggedIn = true;
      _isGuest = false;
      _isNewSignUp = false;

      // Check if user is new (first time login)
      bool isNewUser = false;
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        isNewUser = data['isNewUser'] ?? false;

        // Update last login
        await _firestore.collection('users').doc(_userId).update({
          'lastLogin': FieldValue.serverTimestamp(),
          'loginCount': FieldValue.increment(1),
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _userId);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);
      await prefs.setBool('is_new_signup', false);

      notifyListeners();

      return {
        'success': true,
        'message': 'Login successful',
        'user': result.user,
        'isNewUser': isNewUser
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        message = 'Invalid email or password';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Try again later.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      } else if (e.code == 'network-request-failed') {
        message = 'Network error. Check your connection.';
      }
      return {'success': false, 'message': message, 'isNewUser': false};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred. Please try again.', 'isNewUser': false};
    }
  }

  // 🔥 FIREBASE SIGNUP METHOD
  Future<Map<String, dynamic>> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
    DateTime? dob,
    String? gender,
    String? username,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (result.user != null) {
        await result.user!.updateDisplayName(name);
        await result.user!.sendEmailVerification();

        await _firestore.collection('users').doc(result.user!.uid).set({
          'name': name,
          'email': email.trim(),
          'username': username ?? name.toLowerCase().replaceAll(' ', ''),
          'phone': phone ?? '',
          'dob': dob?.toIso8601String(),
          'gender': gender ?? '',
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
          'emailVerified': false,
          'isNewUser': true,  // Mark as new user
          'loginCount': 1,
        });
      }

      _userId = result.user?.uid ?? '';
      _userEmail = result.user?.email ?? email;
      _userName = name;
      _isLoggedIn = true;
      _isGuest = false;
      _isNewSignUp = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _userId);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);
      await prefs.setBool('is_new_signup', true);

      notifyListeners();

      return {
        'success': true,
        'message': 'Account created successfully',
        'user': result.user,
        'isNewUser': true
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      if (e.code == 'email-already-in-use') {
        message = 'This email is already registered';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Email/password accounts are not enabled';
      }
      return {'success': false, 'message': message, 'isNewUser': false};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred. Please try again.', 'isNewUser': false};
    }
  }

  // 🔥 GOOGLE SIGN IN
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // TODO: Implement actual Google Sign In
      await Future.delayed(const Duration(seconds: 1));

      String mockUid = 'google_${DateTime.now().millisecondsSinceEpoch}';
      bool isNewUser = true; // In real implementation, check if user exists

      _userId = mockUid;
      _userEmail = 'user@gmail.com';
      _userName = 'Google User';
      _isLoggedIn = true;
      _isGuest = false;
      _isNewSignUp = isNewUser;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _userId);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);
      await prefs.setBool('is_new_signup', isNewUser);

      notifyListeners();

      return {
        'success': true,
        'message': 'Google sign in successful',
        'isNewUser': isNewUser
      };
    } catch (e) {
      return {'success': false, 'message': 'Google sign in failed', 'isNewUser': false};
    }
  }

  // 🔥 FACEBOOK SIGN IN
  Future<Map<String, dynamic>> signInWithFacebook() async {
    try {
      // TODO: Implement actual Facebook Sign In
      await Future.delayed(const Duration(seconds: 1));

      String mockUid = 'facebook_${DateTime.now().millisecondsSinceEpoch}';
      bool isNewUser = true;

      _userId = mockUid;
      _userEmail = 'user@facebook.com';
      _userName = 'Facebook User';
      _isLoggedIn = true;
      _isGuest = false;
      _isNewSignUp = isNewUser;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _userId);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);
      await prefs.setBool('is_new_signup', isNewUser);

      notifyListeners();

      return {
        'success': true,
        'message': 'Facebook sign in successful',
        'isNewUser': isNewUser
      };
    } catch (e) {
      return {'success': false, 'message': 'Facebook sign in failed', 'isNewUser': false};
    }
  }

  // 🔥 SOCIAL LOGIN (General)
  Future<void> socialLogin(String platform) async {
    await Future.delayed(const Duration(seconds: 2));

    _userId = 'social_${platform.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';
    _userEmail = 'user@$platform.com';
    _userName = platform;
    _isLoggedIn = true;
    _isGuest = false;
    _isNewSignUp = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', _userId);
    await prefs.setString('user_email', _userEmail);
    await prefs.setString('user_name', _userName);
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('is_guest', false);
    await prefs.setBool('is_new_signup', true);

    notifyListeners();
  }

  // 🔥 VERIFY EMAIL (for OTP verification)
  Future<Map<String, dynamic>> verifyEmail(String otp) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }

      // Reload user to get latest email verification status
      await user.reload();
      user = _auth.currentUser;

      if (user?.emailVerified == true) {
        // Update Firestore
        await _firestore.collection('users').doc(user!.uid).update({
          'emailVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        return {'success': true, 'message': 'Email verified successfully'};
      } else {
        // In a real app, you'd verify OTP here
        // For demo, we'll simulate success after 1 second
        await Future.delayed(const Duration(seconds: 1));

        await _firestore.collection('users').doc(user!.uid).update({
          'emailVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });

        return {'success': true, 'message': 'Email verified successfully'};
      }
    } catch (e) {
      print('Error verifying email: $e');
      return {'success': false, 'message': 'Verification failed'};
    }
  }

  // 🔥 RESEND OTP
  Future<Map<String, dynamic>> resendOtp(String email) async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        return {'success': true, 'message': 'Verification email sent'};
      }
      return {'success': false, 'message': 'No user logged in'};
    } catch (e) {
      print('Error resending OTP: $e');
      return {'success': false, 'message': 'Failed to resend OTP'};
    }
  }

  // 🔥 FIREBASE LOGOUT
  Future<void> logout() async {
    await _auth.signOut();

    _isGuest = false;
    _isLoggedIn = false;
    _userId = '';
    _userEmail = '';
    _userName = '';
    _isNewSignUp = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', false);
    await prefs.setBool('is_logged_in', false);
    await prefs.setString('user_id', '');
    await prefs.setString('user_email', '');
    await prefs.setString('user_name', '');
    await prefs.setBool('is_new_signup', false);
    await prefs.remove('saved_email');  // Clear saved email on logout

    notifyListeners();
  }

  // 🔥 RESET PASSWORD
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return {'success': true, 'message': 'Password reset email sent'};
    } on FirebaseAuthException catch (e) {
      String message = 'Failed to send reset email';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  // SET USER INFO
  Future<void> setUserInfo({required String userId, required String email, String? name}) async {
    _userId = userId;
    _userEmail = email;
    _userName = name ?? '';
    _isGuest = false;
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', userId);
    await prefs.setString('user_email', email);
    if (name != null) await prefs.setString('user_name', name);
    await prefs.setBool('is_guest', false);
    await prefs.setBool('is_logged_in', true);

    notifyListeners();
  }

  Future<void> markAsNewSignUp() async {
    _isNewSignUp = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_new_signup', true);
    notifyListeners();
  }

  Future<void> clearNewSignUpFlag() async {
    _isNewSignUp = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_new_signup', false);
    notifyListeners();
  }

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

  static String generateUserIdFromEmail(String email) {
    if (email.isEmpty) return 'unknown';
    return email.split('@').first + '_' + DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<bool> hasUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id')?.isNotEmpty ?? false;
  }
}