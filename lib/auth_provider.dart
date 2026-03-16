import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthProvider extends ChangeNotifier {
  // ============= PRIVATE VARIABLES =============
  bool _isGuest = false;
  bool _isLoggedIn = false;
  bool _hasCompletedOnboarding = false;
  String _userId = '';
  bool _isNewSignUp = false;
  String _userEmail = '';
  String _userName = '';
  Map<String, dynamic> _userData = {};

  // ============= FIREBASE INSTANCES =============
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FacebookAuth _facebookAuth = FacebookAuth.instance;

  // ============= PUBLIC GETTERS =============
  bool get isGuest => _isGuest;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  bool get canAccessFullFeatures => _isLoggedIn && !_isGuest;
  String get userId => _isGuest ? 'guest' : _userId.isNotEmpty ? _userId : 'unknown';
  bool get isNewSignUp => _isNewSignUp;
  String get userEmail => _userEmail;
  String get userName => _userName;
  User? get currentUser => _auth.currentUser;
  Map<String, dynamic> get userData => _userData;

  // ============= 🔥 NEW: Email verification status =============
  bool get isEmailVerified {
    final user = _auth.currentUser;
    return user?.emailVerified ?? false;
  }

  // ============= CONSTRUCTOR =============
  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    await _loadAuthState();
    _checkCurrentUser();
  }

  // ============= CHECK CURRENT USER =============
  Future<void> _checkCurrentUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _userId = user.uid;
      _userEmail = user.email ?? '';
      _userName = user.displayName ?? '';
      _isLoggedIn = true;
      _isGuest = false;

      await _loadUserDataFromFirestore(user.uid);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _userId);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);

      notifyListeners();
    }
  }

  // ============= LOAD USER DATA FROM FIRESTORE =============
  Future<void> _loadUserDataFromFirestore(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        _userData = doc.data() as Map<String, dynamic>;
        _userName = _userData['name'] ?? _userName;
        _userEmail = _userData['email'] ?? _userEmail;
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // ============= LOAD AUTH STATE =============
  Future<void> _loadAuthState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isGuest = prefs.getBool('is_guest') ?? false;
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      _hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;
      _userId = prefs.getString('user_id') ?? '';
      _userEmail = prefs.getString('user_email') ?? '';
      _userName = prefs.getString('user_name') ?? '';
      _isNewSignUp = prefs.getBool('is_new_signup') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading auth state: $e');
    }
  }

  // ============= 🔥 CHECK IF USERNAME EXISTS =============
  Future<bool> checkUsernameExists(String username) async {
    try {
      debugPrint('🔍 Checking username: $username');

      if (username.isEmpty) return false;

      final querySnapshot = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      final exists = querySnapshot.docs.isNotEmpty;
      debugPrint('✅ Username exists: $exists');
      return exists;

    } catch (e) {
      debugPrint('❌ Error checking username: $e');
      return false;
    }
  }

  // ============= 🔥🔥🔥 SIGN UP WITH EMAIL & PASSWORD (UPDATED WITH RECOVERY EMAIL) =============
  Future<Map<String, dynamic>> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
    required String phone,  // Now required
    DateTime? dob,
    required String gender,  // Now required
    required String username,
    required String recoveryEmail,  // NEW required parameter
  }) async {
    try {
      debugPrint('\n🔵🔵🔵=== STARTING SIGNUP PROCESS ===🔵🔵🔵');
      debugPrint('📧 Email: $email');
      debugPrint('👤 Name: $name');
      debugPrint('👤 Username: $username');
      debugPrint('📱 Phone: $phone');
      debugPrint('📧 Recovery Email: $recoveryEmail');

      // ===== STEP 1: CHECK IF USERNAME ALREADY EXISTS =====
      final usernameExists = await checkUsernameExists(username);
      if (usernameExists) {
        debugPrint('❌ Username already taken: $username');
        return {
          'success': false,
          'message': 'This username is already taken. Please choose another.'
        };
      }

      // ===== STEP 2: CREATE USER IN FIREBASE AUTH =====
      debugPrint('🟡 Creating user in Firebase Auth...');
      UserCredential result;

      try {
        result = await _auth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        debugPrint('✅✅✅ USER CREATED SUCCESSFULLY!');
        debugPrint('📱 UID: ${result.user!.uid}');
        debugPrint('📧 Email: ${result.user!.email}');
      } on FirebaseAuthException catch (e) {
        debugPrint('\n❌❌❌ FIREBASE AUTH ERROR: ${e.code}');
        debugPrint('📝 Message: ${e.message}');

        String message = '';
        switch (e.code) {
          case 'email-already-in-use':
            message = 'This email is already registered. Please login.';
            break;
          case 'weak-password':
            message = 'Password is too weak. Must be at least 6 characters.';
            break;
          case 'invalid-email':
            message = 'Invalid email address.';
            break;
          case 'network-request-failed':
            message = 'Network error. Check your internet connection.';
            break;
          case 'too-many-requests':
            message = 'Too many attempts. Try again later.';
            break;
          case 'operation-not-allowed':
            message = 'Email/password signup is not enabled in Firebase Console.';
            break;
          default:
            message = 'Signup failed: ${e.message}';
        }
        return {'success': false, 'message': message};
      }

      // ===== STEP 3: UPDATE DISPLAY NAME =====
      try {
        await result.user!.updateDisplayName(name);
        await result.user!.reload();
        debugPrint('✅ Display name updated to: $name');
      } catch (e) {
        debugPrint('⚠️ Display name update failed: $e');
      }

      // ===== 🔥🔥🔥 STEP 4: SEND EMAIL VERIFICATION =====
      try {
        await result.user!.sendEmailVerification();
        debugPrint('✅✅✅ VERIFICATION EMAIL SENT TO: $email');
      } catch (e) {
        debugPrint('⚠️ Could not send verification email: $e');
        // Continue anyway - user can request verification later
      }

      // ===== STEP 5: PREPARE USER DATA =====
      String finalPhone = phone.trim();
      String finalRecoveryEmail = recoveryEmail.trim().toLowerCase();

      Map<String, dynamic> userData = {
        // Personal Information
        'uid': result.user!.uid,
        'name': name,
        'email': email.trim(),
        'username': username.toLowerCase(),
        'phone': finalPhone,
        'recoveryEmail': finalRecoveryEmail,  // Added recovery email
        'dob': dob?.toIso8601String() ?? '',
        'gender': gender,
        'photoURL': '',

        // Account Status
        'isActive': true,
        'isVerified': false, // Will be true after email verification
        'emailVerified': false,
        'accountType': 'user',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),

        // Device Info
        'platform': defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'web',

        // Statistics
        'totalLogins': 1,

        // Preferences
        'preferences': {
          'language': 'en',
          'theme': 'system',
          'notifications': true,
          'marketing': false,
        },
      };

      // ===== STEP 6: SAVE TO FIRESTORE =====
      try {
        debugPrint('🟡 Saving user data to Firestore...');
        await _firestore.collection('users').doc(result.user!.uid).set(userData);
        debugPrint('✅✅✅ USER DATA SAVED TO FIRESTORE!');
      } catch (e) {
        debugPrint('\n❌❌❌ FIRESTORE ERROR: $e');
        debugPrint('⚠️ User created in Auth but Firestore save failed!');
        return {
          'success': true,
          'needsVerification': true,
          'message': 'Account created but profile data could not be saved. Please check verification email.'
        };
      }

      // ===== STEP 7: UPDATE LOCAL STATE =====
      _userId = result.user?.uid ?? '';
      _userEmail = result.user?.email ?? email;
      _userName = name;
      _userData = userData;
      _isLoggedIn = true; // User is logged in but not verified
      _isGuest = false;
      _isNewSignUp = true;

      // ===== STEP 8: SAVE TO SHAREDPREFERENCES =====
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _userId);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);
      await prefs.setBool('is_new_signup', true);

      notifyListeners();
      debugPrint('\n🎉🎉🎉=== SIGNUP COMPLETE ===🎉🎉🎉');
      debugPrint('✅ User ID: $_userId');
      debugPrint('✅ User Email: $_userEmail');
      debugPrint('✅ User Name: $_userName');
      debugPrint('✅ Username: $username');
      debugPrint('✅ Recovery Email: $finalRecoveryEmail\n');

      return {
        'success': true,
        'needsVerification': true,
        'message': 'Account created successfully! Please verify your email.'
      };

    } catch (e) {
      debugPrint('\n❌❌❌ UNEXPECTED ERROR: $e');
      debugPrint('📝 Error type: ${e.runtimeType}');
      return {'success': false, 'message': 'An unexpected error occurred. Please try again.'};
    }
  }

  // ============= 🔥 NEW: Send verification email =============
  Future<Map<String, dynamic>> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {'success': false, 'message': 'No user logged in'};
      }

      await user.sendEmailVerification();
      debugPrint('✅ Verification email sent to ${user.email}');
      return {
        'success': true,
        'message': 'Verification email sent! Please check your inbox.'
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error sending verification: ${e.code}');
      String message = 'Failed to send verification email';
      switch (e.code) {
        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your connection.';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  // ============= 🔥 NEW: Check email verification status =============
  Future<bool> checkEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await user.reload();
      final updatedUser = _auth.currentUser;
      final isVerified = updatedUser?.emailVerified ?? false;

      if (isVerified) {
        // Update Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'emailVerified': true,
          'isVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update local data
        if (_userData.isNotEmpty) {
          _userData['emailVerified'] = true;
          _userData['isVerified'] = true;
        }

        notifyListeners();
      }

      return isVerified;
    } catch (e) {
      debugPrint('Error checking verification: $e');
      return false;
    }
  }

  // ============= 🔥 NEW: Sign out unverified user =============
  Future<void> signOutUnverified() async {
    try {
      await _auth.signOut();
      _isLoggedIn = false;
      _userId = '';
      _userEmail = '';
      _userName = '';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', false);
      await prefs.setString('user_id', '');
      await prefs.setString('user_email', '');
      await prefs.setString('user_name', '');

      notifyListeners();
    } catch (e) {
      debugPrint('Error signing out unverified user: $e');
    }
  }

  // ============= 🔥🔥🔥 UPDATED: LOGIN WITH EMAIL & PASSWORD =============
  Future<Map<String, dynamic>> loginWithEmailPassword(String email, String password) async {
    try {
      debugPrint('\n🟢🟢🟢=== STARTING LOGIN PROCESS ===🟢🟢🟢');
      debugPrint('📧 Email: $email');

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('✅ User logged in: ${result.user!.uid}');

      // ===== 🔥🔥🔥 CHECK EMAIL VERIFICATION =====
      await result.user!.reload();
      final isVerified = result.user!.emailVerified;

      if (!isVerified) {
        debugPrint('⚠️ Email not verified!');
        await _auth.signOut();
        return {
          'success': false,
          'needsVerification': true,
          'email': email,
          'message': 'Please verify your email before logging in.'
        };
      }

      // Get user data from Firestore
      DocumentReference userRef = _firestore.collection('users').doc(result.user!.uid);
      DocumentSnapshot userDoc = await userRef.get();

      if (userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;
        _userName = _userData['name'] ?? result.user?.displayName ?? '';
        _userEmail = _userData['email'] ?? result.user?.email ?? email;

        // Update login statistics
        await userRef.update({
          'lastLogin': FieldValue.serverTimestamp(),
          'totalLogins': FieldValue.increment(1),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'emailVerified': true,
        });
        debugPrint('✅ Login stats updated');
      } else {
        // Create user document if it doesn't exist
        Map<String, dynamic> newUserData = {
          'uid': result.user!.uid,
          'name': result.user?.displayName ?? '',
          'email': result.user?.email ?? email,
          'username': email.split('@')[0].toLowerCase(),
          'phone': '',
          'recoveryEmail': '',
          'dob': '',
          'gender': '',
          'photoURL': result.user?.photoURL ?? '',
          'isActive': true,
          'isVerified': true,
          'emailVerified': true,
          'accountType': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform == TargetPlatform.android ? 'android' :
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'web',
          'totalLogins': 1,
          'preferences': {
            'language': 'en',
            'theme': 'system',
            'notifications': true,
            'marketing': false,
          },
        };
        await userRef.set(newUserData);
        _userData = newUserData;
        debugPrint('✅ New user document created');
      }

      _userId = result.user?.uid ?? '';
      _isLoggedIn = true;
      _isGuest = false;
      _isNewSignUp = false;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', _userId);
      await prefs.setString('user_email', _userEmail);
      await prefs.setString('user_name', _userName);
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('is_guest', false);
      await prefs.setBool('is_new_signup', false);

      notifyListeners();
      debugPrint('=== Login Successful ===\n');

      return {'success': true, 'message': 'Login successful!'};

    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code}');
      String message = 'Login failed';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email. Please sign up.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Invalid email format.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        default:
          message = 'Login failed: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {'success': false, 'message': 'An error occurred. Please try again.'};
    }
  }



  // ============= 🔥 RESET PASSWORD =============
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      debugPrint('\n🟡🟡🟡=== STARTING PASSWORD RESET ===🟡🟡🟡');
      debugPrint('📧 Email: $email');

      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('✅ Password reset email sent');

      return {
        'success': true,
        'message': 'Password reset email sent! Check your inbox.'
      };

    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuthException: ${e.code}');
      String message = 'Failed to send reset email';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'invalid-email':
          message = 'Invalid email address.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        default:
          message = 'Error: ${e.message}';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  // ============= 🔥 GOOGLE SIGN IN =============
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      debugPrint('\n🔴🔴🔴=== STARTING GOOGLE SIGN IN ===🔴🔴🔴');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('❌ Google sign in cancelled');
        return {'success': false, 'message': 'Google sign in cancelled'};
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      debugPrint('✅ Google sign in successful: ${userCredential.user!.uid}');

      // Google emails are verified
      final isVerified = userCredential.user!.emailVerified;

      DocumentReference userRef = _firestore.collection('users').doc(userCredential.user!.uid);
      DocumentSnapshot userDoc = await userRef.get();

      bool isNewUser = !userDoc.exists;

      if (isNewUser) {
        String baseUsername = userCredential.user!.email?.split('@')[0] ?? 'user';
        String finalUsername = baseUsername.toLowerCase();

        int counter = 1;
        while (await checkUsernameExists(finalUsername)) {
          finalUsername = '${baseUsername.toLowerCase()}$counter';
          counter++;
        }

        Map<String, dynamic> userData = {
          'uid': userCredential.user!.uid,
          'name': userCredential.user!.displayName ?? '',
          'email': userCredential.user!.email ?? '',
          'username': finalUsername,
          'phone': '',
          'recoveryEmail': '',
          'dob': '',
          'gender': '',
          'photoURL': userCredential.user!.photoURL ?? '',
          'isActive': true,
          'isVerified': isVerified,
          'emailVerified': isVerified,
          'accountType': 'user',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'platform': defaultTargetPlatform == TargetPlatform.android ? 'android' :
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'web',
          'totalLogins': 1,
          'preferences': {
            'language': 'en',
            'theme': 'system',
            'notifications': true,
            'marketing': false,
          },
        };

        await userRef.set(userData);
        _userData = userData;
        debugPrint('✅ New user document created with username: $finalUsername');
      } else {
        _userData = userDoc.data() as Map<String, dynamic>;
        await userRef.update({
          'lastLogin': FieldValue.serverTimestamp(),
          'totalLogins': FieldValue.increment(1),
          'lastActiveAt': FieldValue.serverTimestamp(),
          'photoURL': userCredential.user!.photoURL ?? _userData['photoURL'],
          'emailVerified': isVerified,
        });
        debugPrint('✅ Existing user updated');
      }

      _userId = userCredential.user?.uid ?? '';
      _userEmail = userCredential.user?.email ?? '';
      _userName = userCredential.user?.displayName ?? '';
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
      debugPrint('=== Google Sign In Complete ===\n');

      return {
        'success': true,
        'message': 'Google sign in successful!',
        'isNewUser': isNewUser
      };

    } catch (e) {
      debugPrint('❌ Google sign in error: $e');
      return {'success': false, 'message': 'An error occurred with Google sign in'};
    }
  }

  // ============= 🔥🔥🔥 UPDATED: LOGOUT WITH REMEMBER ME CLEAR =============
  Future<void> logout() async {
    try {
      debugPrint('\n🟠🟠🟠=== LOGGING OUT ===🟠🟠🟠');

      await _auth.signOut();
      await _googleSignIn.signOut();


      _isGuest = false;
      _isLoggedIn = false;
      _userId = '';
      _userEmail = '';
      _userName = '';
      _isNewSignUp = false;
      _userData = {};

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false);
      await prefs.setBool('is_logged_in', false);
      await prefs.setString('user_id', '');
      await prefs.setString('user_email', '');
      await prefs.setString('user_name', '');
      await prefs.setBool('is_new_signup', false);

      notifyListeners();
      debugPrint('✅ Logout successful\n');

    } catch (e) {
      debugPrint('❌ Logout error: $e');
    }
  }

  // ============= 🔥🔥🔥 REMEMBER ME FUNCTIONS =============

  /// Save user email for remember me functionality
  Future<void> saveUserEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_email', email);
      await prefs.setBool('remember_me', true);
      debugPrint('✅ Email saved for remember me: $email');
    } catch (e) {
      debugPrint('❌ Error saving email: $e');
    }
  }

  /// Get saved email for remember me
  Future<String?> getSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bool rememberMe = prefs.getBool('remember_me') ?? false;
      if (rememberMe) {
        String? email = prefs.getString('saved_email');
        debugPrint('✅ Retrieved saved email: $email');
        return email;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting saved email: $e');
      return null;
    }
  }

  /// Clear saved email (when user unchecks remember me)
  Future<void> clearSavedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_email');
      await prefs.setBool('remember_me', false);
      debugPrint('✅ Cleared saved email');
    } catch (e) {
      debugPrint('❌ Error clearing saved email: $e');
    }
  }

  /// Check if remember me is enabled
  Future<bool> isRememberMeEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('remember_me') ?? false;
    } catch (e) {
      debugPrint('❌ Error checking remember me: $e');
      return false;
    }
  }

  // ============= SOCIAL LOGIN HANDLER =============
  Future<Map<String, dynamic>> socialLogin(String platform) async {
    if (platform == 'Google') {
      return await signInWithGoogle();

    } else {
      return {'success': false, 'message': '$platform login coming soon!'};
    }
  }

  // ============= SET LOGGED IN STATUS =============
  Future<void> setLoggedIn(bool loggedIn) async {
    _isLoggedIn = loggedIn;
    _isGuest = !loggedIn;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', loggedIn);
    await prefs.setBool('is_guest', !loggedIn);

    if (!loggedIn) {
      _userId = '';
      _userEmail = '';
      _userName = '';
      await prefs.setString('user_id', '');
      await prefs.setString('user_email', '');
      await prefs.setString('user_name', '');
    }

    notifyListeners();
  }

  // ============= GUEST MODE =============
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

  // ============= ONBOARDING =============
  Future<void> setOnboardingCompleted(bool completed) async {
    _hasCompletedOnboarding = completed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', completed);
    notifyListeners();
  }

  // ============= SET USER INFO =============
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

  // ============= MARK AS NEW SIGNUP =============
  Future<void> markAsNewSignUp() async {
    _isNewSignUp = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_new_signup', true);
    notifyListeners();
  }

  // ============= CLEAR NEW SIGNUP FLAG =============
  Future<void> clearNewSignUpFlag() async {
    _isNewSignUp = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_new_signup', false);
    notifyListeners();
  }

  // ============= HAS USER DATA =============
  Future<bool> hasUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id')?.isNotEmpty ?? false;
  }

  // ============= GENERATE USER ID FROM EMAIL =============
  static String generateUserIdFromEmail(String email) {
    if (email.isEmpty) return 'unknown';
    return email.split('@').first + '_' + DateTime.now().millisecondsSinceEpoch.toString();
  }

  // ============= GET USER DATA FROM FIRESTORE =============
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
    }
    return null;
  }

  // ============= UPDATE USER PROFILE =============
  Future<bool> updateUserProfile({
    String? name,
    String? phone,
    String? gender,
    DateTime? dob,
    String? photoURL,
  }) async {
    try {
      if (_auth.currentUser == null) return false;

      Map<String, dynamic> updateData = {};

      if (name != null) {
        updateData['name'] = name;
        await _auth.currentUser!.updateDisplayName(name);
        _userName = name;
      }

      if (phone != null && phone.trim().isNotEmpty) {
        updateData['phone'] = phone.trim();
      }

      if (gender != null && gender.trim().isNotEmpty) {
        updateData['gender'] = gender;
      }

      if (dob != null) {
        updateData['dob'] = dob.toIso8601String();
      }

      if (photoURL != null && photoURL.trim().isNotEmpty) {
        updateData['photoURL'] = photoURL;
        await _auth.currentUser!.updatePhotoURL(photoURL);
      }

      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection('users').doc(_auth.currentUser!.uid).update(updateData);

      _userData.addAll(updateData);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', _userName);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating profile: $e');
      return false;
    }
  }

  // ============= PERMISSIONS MANAGEMENT =============
  // Save user permissions to Firestore
  Future<void> saveUserPermissions(Map<String, bool> permissions) async {
    try {
      if (_userId.isEmpty || _userId == 'guest') {
        debugPrint('⚠️ Cannot save permissions: No user logged in');
        return;
      }

      final userRef = _firestore.collection('users').doc(_userId);

      // Permissions object banao
      Map<String, dynamic> permissionsData = {
        'overlay': permissions['overlay'] ?? false,
        'accessibility': permissions['accessibility'] ?? false,
        'storage': permissions['storage'] ?? false,
        'notifications': permissions['notifications'] ?? false,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // User document mein permissions field update karo
      await userRef.set({
        'permissions': permissionsData,
        'permissionsGrantedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Local userData bhi update karo
      if (_userData.isNotEmpty) {
        _userData['permissions'] = permissionsData;
      }

      debugPrint('✅ Permissions saved to Firestore: $permissionsData');
    } catch (e) {
      debugPrint('❌ Error saving permissions: $e');
    }
  }

  // Load user permissions from Firestore
  Future<Map<String, bool>> loadUserPermissions() async {
    try {
      if (_userId.isEmpty || _userId == 'guest') {
        return {
          'overlay': false,
          'accessibility': false,
          'storage': false,
          'notifications': false,
        };
      }

      final userDoc = await _firestore.collection('users').doc(_userId).get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final permissions = data['permissions'] as Map<String, dynamic>?;

        if (permissions != null) {
          debugPrint('✅ Permissions loaded from Firestore: $permissions');
          return {
            'overlay': permissions['overlay'] ?? false,
            'accessibility': permissions['accessibility'] ?? false,
            'storage': permissions['storage'] ?? false,
            'notifications': permissions['notifications'] ?? false,
          };
        }
      }

      return {
        'overlay': false,
        'accessibility': false,
        'storage': false,
        'notifications': false,
      };
    } catch (e) {
      debugPrint('❌ Error loading permissions: $e');
      return {
        'overlay': false,
        'accessibility': false,
        'storage': false,
        'notifications': false,
      };
    }
  }

  // Check if user needs to see permission screen
  Future<bool> needsPermissionScreen() async {
    try {
      // Guest user ko permission screen nahi dikhani
      if (_isGuest) {
        debugPrint('👤 Guest user - No permission screen needed');
        return false;
      }

      // Agar user logged in hai to permissions check karo
      if (_isLoggedIn && _userId.isNotEmpty) {
        final userDoc = await _firestore.collection('users').doc(_userId).get();

        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;

          // Check if permissions already exist
          final permissions = data['permissions'] as Map<String, dynamic>?;

          if (permissions != null) {
            // Agar permissions already hain to screen mat dikhao
            debugPrint('✅ Permissions already exist - No permission screen needed');
            return false;
          } else {
            // Naye user ko permission screen dikhao
            debugPrint('🆕 New user - Permission screen needed');
            return true;
          }
        }
      }

      // Default case - permission screen dikhao
      debugPrint('⚠️ Default case - Showing permission screen');
      return true;

    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return true; // Error ki surat mein safe side par raho
    }
  }
}