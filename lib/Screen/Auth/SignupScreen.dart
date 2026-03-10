// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/Auth/permissionscreen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/auth_provider.dart';
import 'dart:async';
import 'email_otp_screen.dart';
import 'package:tapmate/auth_wrapper.dart';  // 🔥 YEH IMPORT HONA CHAHIYE

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Controllers - ALL FIELDS (all are now required)
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _recoveryEmailController = TextEditingController();

  // Error messages for ALL fields
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _usernameError;
  String? _phoneError;
  String? _dobError;
  String? _recoveryEmailError;
  String? _genderError;
  String? _signupError;

  // Variables
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  DateTime? _selectedDate;
  String? _selectedGender;

  // Username checking debouncer
  Timer? _usernameDebounce;

  // ============= VALIDATION METHODS =============

  // FULL NAME - Only alphabets and spaces
  bool _isValidName(String name) {
    if (name.isEmpty) return false;
    final trimmedName = name.trim();
    final nameWithoutSpaces = trimmedName.replaceAll(' ', '');
    final nameRegex = RegExp(r'^[a-zA-Z\s]+$');
    return nameWithoutSpaces.length >= 2 &&
        trimmedName.length <= 50 &&
        nameRegex.hasMatch(trimmedName);
  }

  // EMAIL - Professional format
  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  // USERNAME - Letters, numbers, underscore only
  bool _isValidUsername(String username) {
    if (username.isEmpty) return false;
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username);
  }

  // Phone validation - REQUIRED
  bool _isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length >= 10 && digitsOnly.length <= 15;
  }

  // Recovery Email validation - REQUIRED (same as email)
  bool _isValidRecoveryEmail(String email) {
    return _isValidEmail(email);
  }

  // 🔥 PASSWORD VALIDATION - With conditions
  bool _isValidPassword(String password) {
    if (password.isEmpty) return false;
    return RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    ).hasMatch(password);
  }

  // 🔥 CONFIRM PASSWORD VALIDATION - Check if matches
  bool _doPasswordsMatch() {
    return _passwordController.text == _confirmPasswordController.text;
  }

  // Check if username exists in Firestore
  Future<bool> _checkUsernameExists(String username) async {
    if (username.isEmpty) return false;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return await authProvider.checkUsernameExists(username);
    } catch (e) {
      debugPrint('Error checking username: $e');
      return false;
    }
  }

  // 🔥 UPDATED: Validate inputs - ALL FIELDS REQUIRED including Gender
  Future<void> _validateInputs() async {
    setState(() {
      _signupError = null;

      // ===== NAME VALIDATION =====
      final name = _nameController.text.trim();
      String cleanName = name.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
      cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (name != cleanName) {
        _nameController.text = cleanName;
        _nameController.selection = TextSelection.collapsed(
          offset: cleanName.length,
        );
      }

      if (cleanName.isEmpty) {
        _nameError = "⚠️ Full Name is required";
      } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(cleanName)) {
        _nameError = "⚠️ Only letters and spaces allowed";
      } else {
        _nameError = null;
      }

      // ===== EMAIL VALIDATION =====
      final email = _emailController.text.trim().toLowerCase();
      final cleanEmail = email.replaceAll(' ', '');

      if (email != cleanEmail) {
        _emailController.text = cleanEmail;
        _emailController.selection = TextSelection.collapsed(
          offset: cleanEmail.length,
        );
      }

      if (cleanEmail.isEmpty) {
        _emailError = "⚠️ Email is required";
      } else if (cleanEmail.contains(' ')) {
        _emailError = "⚠️ Email cannot contain spaces";
      } else if (!cleanEmail.contains('@')) {
        _emailError = "⚠️ Email must contain @ symbol";
      } else if (!cleanEmail.contains('.')) {
        _emailError = "⚠️ Email must contain domain (e.g., .com, .org)";
      } else if (cleanEmail.startsWith('@')) {
        _emailError = "⚠️ Email must have name before @";
      } else if (cleanEmail.endsWith('.')) {
        _emailError = "⚠️ Email cannot end with dot";
      } else if (cleanEmail.contains('..')) {
        _emailError = "⚠️ Email cannot contain consecutive dots";
      } else if (!_isValidEmail(cleanEmail)) {
        _emailError = "⚠️ Enter a valid email address";
      } else {
        _emailError = null;
      }

      // ===== USERNAME VALIDATION =====
      final username = _usernameController.text.trim().toLowerCase();
      _usernameController.text = username;

      if (username.isEmpty) {
        _usernameError = "⚠️ Username is required";
      } else if (username.length < 3) {
        _usernameError = "⚠️ Username must be at least 3 characters";
      } else if (username.length > 20) {
        _usernameError = "⚠️ Username must be less than 20 characters";
      } else if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        _usernameError = "⚠️ Only letters, numbers, and underscores allowed";
      } else {
        _usernameError = null;
      }

      // ===== 🔥 PASSWORD VALIDATION =====
      final password = _passwordController.text;

      if (password.isEmpty) {
        _passwordError = "⚠️ Password is required";
      } else if (password.length < 8) {
        _passwordError = "⚠️ Password must be at least 8 characters";
      } else if (!RegExp(r'(?=.*[a-z])').hasMatch(password)) {
        _passwordError = "⚠️ Password must contain at least one lowercase letter";
      } else if (!RegExp(r'(?=.*[A-Z])').hasMatch(password)) {
        _passwordError = "⚠️ Password must contain at least one uppercase letter";
      } else if (!RegExp(r'(?=.*\d)').hasMatch(password)) {
        _passwordError = "⚠️ Password must contain at least one number";
      } else if (!RegExp(r'(?=.*[@$!%*?&])').hasMatch(password)) {
        _passwordError = "⚠️ Password must contain at least one special character (@, !, #, \$, %, etc.)";
      } else {
        _passwordError = null;
      }

      // ===== 🔥 CONFIRM PASSWORD VALIDATION =====
      final confirmPassword = _confirmPasswordController.text;

      if (confirmPassword.isEmpty) {
        _confirmPasswordError = "⚠️ Please confirm your password";
      } else if (password != confirmPassword) {
        _confirmPasswordError = "⚠️ Passwords do not match";
      } else {
        _confirmPasswordError = null;
      }

      // ===== PHONE VALIDATION - REQUIRED =====
      final phone = _phoneController.text.trim();
      final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');

      if (phone.isEmpty) {
        _phoneError = "⚠️ Phone number is required";
      } else if (digitsOnly.length < 11) {
        _phoneError = "⚠️ Phone number must be at least 11 digits";
      } else {
        _phoneError = null;
      }

      // ===== DOB VALIDATION =====
      if (_selectedDate == null) {
        _dobError = "⚠️ Date of Birth is required";
      } else {
        _dobError = null;
      }

      // ===== GENDER VALIDATION - NOW REQUIRED =====
      if (_selectedGender == null || _selectedGender!.isEmpty) {
        _genderError = "⚠️ Please select your gender";
      } else {
        _genderError = null;
      }

      // ===== RECOVERY EMAIL VALIDATION - REQUIRED (same as email) =====
      final recoveryEmail = _recoveryEmailController.text.trim().toLowerCase();
      final cleanRecoveryEmail = recoveryEmail.replaceAll(' ', '');

      if (recoveryEmail != cleanRecoveryEmail) {
        _recoveryEmailController.text = cleanRecoveryEmail;
        _recoveryEmailController.selection = TextSelection.collapsed(
          offset: cleanRecoveryEmail.length,
        );
      }

      if (cleanRecoveryEmail.isEmpty) {
        _recoveryEmailError = "⚠️ Recovery Email is required";
      } else if (cleanRecoveryEmail.contains(' ')) {
        _recoveryEmailError = "⚠️ Recovery Email cannot contain spaces";
      } else if (!cleanRecoveryEmail.contains('@')) {
        _recoveryEmailError = "⚠️ Recovery Email must contain @ symbol";
      } else if (!cleanRecoveryEmail.contains('.')) {
        _recoveryEmailError = "⚠️ Recovery Email must contain domain (e.g., .com, .org)";
      } else if (cleanRecoveryEmail.startsWith('@')) {
        _recoveryEmailError = "⚠️ Recovery Email must have name before @";
      } else if (cleanRecoveryEmail.endsWith('.')) {
        _recoveryEmailError = "⚠️ Recovery Email cannot end with dot";
      } else if (cleanRecoveryEmail.contains('..')) {
        _recoveryEmailError = "⚠️ Recovery Email cannot contain consecutive dots";
      } else if (!_isValidRecoveryEmail(cleanRecoveryEmail)) {
        _recoveryEmailError = "⚠️ Enter a valid recovery email address";
      } else {
        _recoveryEmailError = null;
      }
    });

    // Check username uniqueness asynchronously
    if (_usernameError == null && _usernameController.text.trim().isNotEmpty) {
      final username = _usernameController.text.trim().toLowerCase();
      final exists = await _checkUsernameExists(username);
      if (exists) {
        setState(() {
          _usernameError = "⚠️ This username is already taken. Please choose another.";
        });
      }
    }
  }

  // Debounced username validation
  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () {
      _validateInputs();
    });
  }

  String _capitalizeName(String name) {
    if (name.isEmpty) return name;
    final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
    final singleSpaceName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();
    return singleSpaceName
        .split(' ')
        .map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    })
        .join(' ');
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text =
        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
      _validateInputs();
    }
  }

  void _showPasswordRequirements() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Password Requirements"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("• At least 8 characters"),
            Text("• At least one uppercase letter"),
            Text("• At least one lowercase letter"),
            Text("• At least one number"),
            Text("• At least one special character (@, !, #, \$, %, etc.)"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // Snackbar methods
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============= 🔥🔥🔥 UPDATED SIGN UP METHOD =============
  void _signUp() async {
    await _validateInputs();

    if (!_agreeToTerms) {
      _showErrorSnackBar("Please agree to Terms & Conditions");
      return;
    }

    // 🔥 Check for any validation errors - ALL FIELDS INCLUDED
    if (_nameError != null ||
        _emailError != null ||
        _usernameError != null ||
        _passwordError != null ||
        _confirmPasswordError != null ||
        _phoneError != null ||
        _dobError != null ||
        _genderError != null ||
        _recoveryEmailError != null) {

      if (_nameError != null) _showErrorSnackBar(_nameError!);
      else if (_emailError != null) _showErrorSnackBar(_emailError!);
      else if (_usernameError != null) _showErrorSnackBar(_usernameError!);
      else if (_passwordError != null) _showErrorSnackBar(_passwordError!);
      else if (_confirmPasswordError != null) _showErrorSnackBar(_confirmPasswordError!);
      else if (_phoneError != null) _showErrorSnackBar(_phoneError!);
      else if (_dobError != null) _showErrorSnackBar(_dobError!);
      else if (_genderError != null) _showErrorSnackBar(_genderError!);
      else if (_recoveryEmailError != null) _showErrorSnackBar(_recoveryEmailError!);
      return;
    }

    setState(() {
      _isLoading = true;
      _signupError = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _showInfoSnackBar("Creating account...");

      final formattedName = _capitalizeName(_nameController.text.trim());
      final formattedEmail = _emailController.text.trim().toLowerCase();
      final formattedUsername = _usernameController.text.trim().toLowerCase();
      final formattedPhone = _phoneController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final formattedRecoveryEmail = _recoveryEmailController.text.trim().toLowerCase();

      final result = await authProvider.signUpWithEmailPassword(
        name: formattedName,
        email: formattedEmail,
        password: _passwordController.text,
        phone: formattedPhone,
        dob: _selectedDate,
        gender: _selectedGender ?? '',
        username: formattedUsername,
        recoveryEmail: formattedRecoveryEmail,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() => _signupError = null);
          _showSuccessSnackBar('✅ Account created! Please verify your email.');

          // Clear password fields for security
          _passwordController.clear();
          _confirmPasswordController.clear();

          // Navigate to email verification screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(
                email: formattedEmail,
              ),
            ),
          );
        }
      } else {
        setState(() => _signupError = result['message']);
        _showErrorSnackBar('❌ ${result['message']}');

        if (result['message']?.contains('username') == true) {
          FocusScope.of(context).requestFocus(FocusNode());
        }
      }
    } catch (e) {
      setState(() => _signupError = 'Error: ${e.toString()}');
      _showErrorSnackBar('❌ ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    setState(() {
      _isLoading = true;
      _signupError = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.signInWithGoogle();

      if (result['success'] == true) {
        if (mounted) {
          _showSuccessSnackBar('✅ Google sign up successful!');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PermissionScreen()),
          );
        }
      } else {
        setState(() => _signupError = result['message']);
        _showErrorSnackBar('❌ ${result['message']}');
      }
    } catch (e) {
      setState(() => _signupError = 'Google sign up failed');
      _showErrorSnackBar('❌ Google sign up failed');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    super.dispose();
  }

  // 🔥 NEW: Check if form is valid for button visibility - ALL FIELDS INCLUDED
  bool _isFormValid() {
    return _nameError == null && _nameController.text.isNotEmpty &&
        _emailError == null && _emailController.text.isNotEmpty &&
        _usernameError == null && _usernameController.text.isNotEmpty &&
        _passwordError == null && _passwordController.text.isNotEmpty &&
        _confirmPasswordError == null && _confirmPasswordController.text.isNotEmpty &&
        _phoneError == null && _phoneController.text.isNotEmpty &&
        _dobError == null && _selectedDate != null &&
        _genderError == null && _selectedGender != null && _selectedGender!.isNotEmpty &&
        _recoveryEmailError == null && _recoveryEmailController.text.isNotEmpty &&
        _agreeToTerms;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              // Error Message
              if (_signupError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Signup Failed:',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _signupError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 10),

              // ===== NEW LOGO WITH GRADIENT =====
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.secondary, AppColors.primary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.download_for_offline_rounded,
                      color: AppColors.lightSurface,
                      size: 50,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Title
              const Center(
                child: Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Center(
                child: Text(
                  "Join our community today",
                  style: TextStyle(color: AppColors.textMain, fontSize: 16),
                ),
              ),

              const SizedBox(height: 30),

              // ===== FULL NAME =====
              _buildNameField(),

              const SizedBox(height: 15),

              // ===== EMAIL =====
              _buildEmailField(),

              const SizedBox(height: 15),

              // ===== USERNAME =====
              _buildUsernameField(),

              const SizedBox(height: 15),

              // ===== 🔥 PASSWORD FIELD WITH REQUIREMENTS =====
              _buildPasswordField(),

              const SizedBox(height: 15),

              // ===== 🔥 CONFIRM PASSWORD FIELD =====
              _buildConfirmPasswordField(),

              const SizedBox(height: 15),

              // ===== PHONE NUMBER - REQUIRED =====
              _buildPhoneField(),

              const SizedBox(height: 15),

              // ===== DATE OF BIRTH =====
              _buildDateOfBirthField(),

              const SizedBox(height: 15),

              // ===== GENDER SELECTION - NOW REQUIRED =====
              _buildGenderSection(),

              const SizedBox(height: 15),

              // ===== RECOVERY EMAIL - REQUIRED =====
              _buildRecoveryEmailField(),

              const SizedBox(height: 20),

              // ===== TERMS & CONDITIONS =====
              _buildTermsSection(),

              const SizedBox(height: 25),

              // ===== SIGN UP BUTTON (Visible only when form is valid) =====
              if (_isFormValid())
                _buildSignUpButton()
              else
                _buildDisabledButton(),

              const SizedBox(height: 20),

              // ===== DIVIDER =====
              _buildDivider(),

              const SizedBox(height: 20),

              // ===== GOOGLE SIGN IN BUTTON ONLY =====
              _buildGoogleSignInButton(),

              const SizedBox(height: 25),

              // ===== SIGN IN LINK =====
              _buildSignInLink(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ===== HELPER METHODS =====

  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _nameError != null ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: TextField(
        controller: _nameController,
        onChanged: (value) {
          String cleanName = value.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
          cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ');
          if (value != cleanName) {
            _nameController.value = TextEditingValue(
              text: cleanName,
              selection: TextSelection.collapsed(offset: cleanName.length),
            );
          }
          _validateInputs();
        },
        textCapitalization: TextCapitalization.words,
        keyboardType: TextInputType.name,
        style: const TextStyle(color: AppColors.textMain, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMain),
          hintText: "Full Name",
          hintStyle: const TextStyle(color: Colors.grey),
          errorText: _nameError,
          errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _emailError != null ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: TextField(
        controller: _emailController,
        onChanged: (value) {
          final cleanEmail = value.toLowerCase().replaceAll(' ', '');
          if (value != cleanEmail) {
            _emailController.value = TextEditingValue(
              text: cleanEmail,
              selection: TextSelection.collapsed(offset: cleanEmail.length),
            );
          }
          _validateInputs();
        },
        keyboardType: TextInputType.emailAddress,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: AppColors.textMain, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMain),
          hintText: "Email Address",
          hintStyle: const TextStyle(color: Colors.grey),
          errorText: _emailError,
          errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildUsernameField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _usernameError != null ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: TextField(
        controller: _usernameController,
        onChanged: (value) {
          String cleanUsername = value.toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9_]'),
            '',
          );
          if (value != cleanUsername) {
            _usernameController.value = TextEditingValue(
              text: cleanUsername,
              selection: TextSelection.collapsed(
                offset: cleanUsername.length,
              ),
            );
          }
          _onUsernameChanged(cleanUsername);
        },
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: AppColors.textMain, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.alternate_email, color: AppColors.textMain),
          hintText: "Username",
          hintStyle: const TextStyle(color: Colors.grey),
          errorText: _usernameError,
          errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
          suffixIcon: _usernameController.text.isNotEmpty && _usernameError == null
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _passwordError != null
            ? Border.all(color: Colors.red, width: 1.5)
            : (_passwordController.text.isNotEmpty && _passwordError == null
            ? Border.all(color: Colors.green, width: 1.0)
            : null),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              onChanged: (_) => _validateInputs(),
              style: const TextStyle(color: AppColors.textMain, fontSize: 16),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMain),
                hintText: "Password",
                hintStyle: const TextStyle(color: Colors.grey),
                errorText: _passwordError,
                errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _passwordController.text.isNotEmpty && _passwordError == null
                    ? const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textMain,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.blue),
            onPressed: _showPasswordRequirements,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmPasswordField() {
    bool passwordsMatch = _doPasswordsMatch() && _confirmPasswordController.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _confirmPasswordError != null
            ? Border.all(color: Colors.red, width: 1.5)
            : (passwordsMatch
            ? Border.all(color: Colors.green, width: 1.0)
            : null),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              onChanged: (_) => _validateInputs(),
              style: const TextStyle(color: AppColors.textMain, fontSize: 16),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMain),
                hintText: "Confirm Password",
                hintStyle: const TextStyle(color: Colors.grey),
                errorText: _confirmPasswordError,
                errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: passwordsMatch
                    ? const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.check_circle, color: Colors.green, size: 18),
                )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textMain,
            ),
            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _phoneError != null ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: TextField(
        controller: _phoneController,
        onChanged: (value) {
          final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
          if (value != digitsOnly) {
            _phoneController.value = TextEditingValue(
              text: digitsOnly,
              selection: TextSelection.collapsed(offset: digitsOnly.length),
            );
          }
          _validateInputs();
        },
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: AppColors.textMain, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textMain),
          hintText: "Phone Number",
          hintStyle: const TextStyle(color: Colors.grey),
          errorText: _phoneError,
          errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDateOfBirthField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _dobError != null ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: GestureDetector(
        onTap: () => _selectDate(context),
        child: AbsorbPointer(
          child: TextField(
            controller: _dobController,
            style: const TextStyle(color: AppColors.textMain, fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.calendar_today, color: AppColors.textMain),
              hintText: "Date of Birth",
              hintStyle: const TextStyle(color: Colors.grey),
              errorText: _dobError,
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
              filled: true,
              fillColor: Colors.transparent,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: const Icon(Icons.arrow_drop_down, color: AppColors.textMain),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 8),
          child: Text(
            "Gender",
            style: TextStyle(
              color: AppColors.textMain,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (_genderError != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              _genderError!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        Row(
          children: [
            Expanded(child: _genderButton("Male", Icons.male)),
            const SizedBox(width: 10),
            Expanded(child: _genderButton("Female", Icons.female)),
            const SizedBox(width: 10),
            Expanded(child: _genderButton("Other", Icons.transgender)),
          ],
        ),
      ],
    );
  }

  Widget _genderButton(String gender, IconData icon) {
    bool isSelected = _selectedGender == gender;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _selectedGender = gender;
          _genderError = null;
        });
        _validateInputs();
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.primary.withOpacity(0.1) : null,
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ? AppColors.primary : Colors.grey[600], size: 20),
          const SizedBox(width: 8),
          Text(
            gender,
            style: TextStyle(
              color: isSelected ? AppColors.primary : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryEmailField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _recoveryEmailError != null ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: TextField(
        controller: _recoveryEmailController,
        onChanged: (value) {
          final cleanEmail = value.toLowerCase().replaceAll(' ', '');
          if (value != cleanEmail) {
            _recoveryEmailController.value = TextEditingValue(
              text: cleanEmail,
              selection: TextSelection.collapsed(offset: cleanEmail.length),
            );
          }
          _validateInputs();
        },
        keyboardType: TextInputType.emailAddress,
        textCapitalization: TextCapitalization.none,
        style: const TextStyle(color: AppColors.textMain, fontSize: 16),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.email, color: AppColors.textMain),
          hintText: "Recovery Email",
          hintStyle: const TextStyle(color: Colors.grey),
          errorText: _recoveryEmailError,
          errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildTermsSection() {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: _agreeToTerms,
              onChanged: (value) {
                setState(() => _agreeToTerms = value ?? false);
                _validateInputs();
              },
              activeColor: AppColors.primary,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _agreeToTerms = !_agreeToTerms);
                  _validateInputs();
                },
                child: const Text.rich(
                  TextSpan(
                    style: TextStyle(color: AppColors.textMain),
                    children: [
                      TextSpan(text: "I agree to the "),
                      TextSpan(
                        text: "Terms & Conditions",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: " and "),
                      TextSpan(
                        text: "Privacy Policy",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.lightSurface,
          ),
        )
            : const Text(
          "Create Account",
          style: TextStyle(
            color: AppColors.lightSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDisabledButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[400],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          "Create Account",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGoogleSignUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/google_logo.png',
              height: 24,
              width: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_translate, color: Colors.red),
            ),
            const SizedBox(width: 10),
            const Text(
              "Sign up with Google",
              style: TextStyle(
                color: AppColors.textMain,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey[300])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            "Or",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey[300])),
      ],
    );
  }

  Widget _buildSignInLink() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: "Already have an account? ",
                style: TextStyle(color: AppColors.textMain),
              ),
              TextSpan(
                text: "Sign In",
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}