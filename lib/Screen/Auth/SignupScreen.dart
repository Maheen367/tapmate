// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/Auth/LoginScreen.dart';
import 'package:tapmate/Screen/Auth/permissionscreen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/auth_provider.dart';
import 'dart:async';
import 'email_otp_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  // Focus Nodes
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _usernameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();
  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _dobFocusNode = FocusNode();

  // Error messages
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _usernameError;
  String? _phoneError;
  String? _dobError;
  String? _genderError;
  String? _signupError;

  // Track which fields are touched
  final Map<String, bool> _fieldTouched = {
    'name': false,
    'email': false,
    'username': false,
    'password': false,
    'confirmPassword': false,
    'phone': false,
    'dob': false,
    'gender': false,
  };

  // Variables
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  DateTime? _selectedDate;
  String? _selectedGender;

  // Username checking debouncer
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && _fieldTouched['name']!) {
        _validateOnBlur('name');
      }
    });
    _emailFocusNode.addListener(() {
      if (!_emailFocusNode.hasFocus && _fieldTouched['email']!) {
        _validateOnBlur('email');
      }
    });
    _usernameFocusNode.addListener(() {
      if (!_usernameFocusNode.hasFocus && _fieldTouched['username']!) {
        _validateOnBlur('username');
      }
    });
    _passwordFocusNode.addListener(() {
      if (!_passwordFocusNode.hasFocus && _fieldTouched['password']!) {
        _validateOnBlur('password');
      }
    });
    _confirmPasswordFocusNode.addListener(() {
      if (!_confirmPasswordFocusNode.hasFocus && _fieldTouched['confirmPassword']!) {
        _validateOnBlur('confirmPassword');
      }
    });
    _phoneFocusNode.addListener(() {
      if (!_phoneFocusNode.hasFocus && _fieldTouched['phone']!) {
        _validateOnBlur('phone');
      }
    });
  }

  void _validateOnBlur(String field) {
    setState(() {
      switch (field) {
        case 'name':
          final name = _nameController.text.trim();
          if (name.isEmpty) {
            _nameError = "*";
          } else {
            _nameError = null;
          }
          break;
        case 'email':
          final email = _emailController.text.trim();
          if (email.isEmpty) {
            _emailError = "*";
          } else {
            _emailError = null;
          }
          break;
        case 'username':
          final username = _usernameController.text.trim();
          if (username.isEmpty) {
            _usernameError = "*";
          } else {
            _usernameError = null;
          }
          break;
        case 'password':
          if (_passwordController.text.isEmpty) {
            _passwordError = "*";
          } else {
            _passwordError = null;
          }
          break;
        case 'confirmPassword':
          if (_confirmPasswordController.text.isEmpty) {
            _confirmPasswordError = "*";
          } else {
            _confirmPasswordError = null;
          }
          break;
        case 'phone':
          if (_phoneController.text.isEmpty) {
            _phoneError = "*";
          } else {
            _phoneError = null;
          }
          break;
      }
    });
  }

  bool _isValidEmail(String email) {
    if (email.isEmpty) return false;
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  bool _isValidUsername(String username) {
    if (username.isEmpty) return false;
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username);
  }

  bool _isValidPhone(String phone) {
    if (phone.isEmpty) return false;
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length >= 10 && digitsOnly.length <= 15;
  }

  bool _isValidPassword(String password) {
    if (password.isEmpty) return false;
    return RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
    ).hasMatch(password);
  }

  bool _doPasswordsMatch() {
    return _passwordController.text == _confirmPasswordController.text;
  }

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

  void _onUsernameChanged(String value) {
    _fieldTouched['username'] = true;
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () {
      if (_usernameController.text.isNotEmpty) {
        _checkUsernameExists(value).then((exists) {
          if (exists && mounted) {
            setState(() {
              _usernameError = "* This username is already taken";
            });
          }
        });
      }
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
        _fieldTouched['dob'] = true;
        _dobError = null;
      });
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

  // ============= FIXED SIGN UP METHOD =============
  void _signUp() async {
    // Mark all fields as touched
    setState(() {
      _fieldTouched.updateAll((key, value) => true);
    });

    // 🔥 VALIDATE ALL FIELDS ON SUBMIT
    bool hasError = false;

    // Name validation
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = "*");
      hasError = true;
    } else {
      setState(() => _nameError = null);
    }

    // Email validation
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = "*");
      hasError = true;
    } else if (!_isValidEmail(email)) {
      setState(() => _emailError = "* Invalid email format");
      hasError = true;
    } else {
      setState(() => _emailError = null);
    }

    // Username validation
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _usernameError = "*");
      hasError = true;
    } else if (!_isValidUsername(username)) {
      setState(() => _usernameError = "* Username must be 3-20 chars (letters, numbers, _)");
      hasError = true;
    } else {
      setState(() => _usernameError = null);
    }

    // Password validation
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _passwordError = "*");
      hasError = true;
    } else if (!_isValidPassword(password)) {
      setState(() => _passwordError = "* Password must have: 8+ chars, upper, lower, number, special");
      hasError = true;
    } else {
      setState(() => _passwordError = null);
    }

    // Confirm password validation
    final confirmPassword = _confirmPasswordController.text;
    if (confirmPassword.isEmpty) {
      setState(() => _confirmPasswordError = "*");
      hasError = true;
    } else if (password != confirmPassword) {
      setState(() => _confirmPasswordError = "* Passwords do not match");
      hasError = true;
    } else {
      setState(() => _confirmPasswordError = null);
    }

    // Phone validation
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _phoneError = "*");
      hasError = true;
    } else if (!_isValidPhone(phone)) {
      setState(() => _phoneError = "* Invalid phone number (10-15 digits)");
      hasError = true;
    } else {
      setState(() => _phoneError = null);
    }

    // DOB validation
    if (_selectedDate == null) {
      setState(() => _dobError = "*");
      hasError = true;
    } else {
      setState(() => _dobError = null);
    }

    // Gender validation
    if (_selectedGender == null) {
      setState(() => _genderError = "*");
      hasError = true;
    } else {
      setState(() => _genderError = null);
    }

    // Terms validation
    if (!_agreeToTerms) {
      _showErrorSnackBar("Please agree to Terms & Conditions");
      return;
    }

    // Agar koi error hai to return
    if (hasError) {
      _showErrorSnackBar("Please fill all fields correctly");
      return;
    }

    // Check username exists
    final usernameExists = await _checkUsernameExists(username);
    if (usernameExists) {
      setState(() => _usernameError = "* This username is already taken");
      _showErrorSnackBar("Username already taken");
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

      final result = await authProvider.signUpWithEmailPassword(
        name: formattedName,
        email: formattedEmail,
        password: _passwordController.text,
        phone: formattedPhone,
        dob: _selectedDate,
        gender: _selectedGender ?? '',
        username: formattedUsername,
        recoveryEmail: formattedEmail,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() => _signupError = null);
          _showSuccessSnackBar('✅ Account created! Please verify your email.');

          _passwordController.clear();
          _confirmPasswordController.clear();

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
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _phoneFocusNode.dispose();
    _dobFocusNode.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _nameController.text.isNotEmpty &&
        _emailController.text.isNotEmpty &&
        _usernameController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty &&
        _phoneController.text.isNotEmpty &&
        _selectedDate != null &&
        _selectedGender != null &&
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
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

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

              _buildNameField(),
              const SizedBox(height: 15),
              _buildEmailField(),
              const SizedBox(height: 15),
              _buildUsernameField(),
              const SizedBox(height: 15),
              _buildPasswordField(),
              const SizedBox(height: 15),
              _buildConfirmPasswordField(),
              const SizedBox(height: 15),
              _buildPhoneField(),
              const SizedBox(height: 15),
              _buildDateOfBirthField(),
              const SizedBox(height: 15),
              _buildGenderSection(),
              const SizedBox(height: 20),
              _buildTermsSection(),
              const SizedBox(height: 25),

              if (_isFormValid())
                _buildSignUpButton()
              else
                _buildDisabledButton(),

              const SizedBox(height: 20),
              _buildDivider(),
              const SizedBox(height: 20),
              _buildGoogleSignInButton(),
              const SizedBox(height: 25),
              _buildSignInLink(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(12),
        border: _nameError != null ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: TextField(
        controller: _nameController,
        focusNode: _nameFocusNode,
        onChanged: (value) {
          String cleanName = value.replaceAll(RegExp(r'[^a-zA-Z\s]'), '');
          cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ');
          if (value != cleanName) {
            _nameController.value = TextEditingValue(
              text: cleanName,
              selection: TextSelection.collapsed(offset: cleanName.length),
            );
          }
          _fieldTouched['name'] = true;
          if (_nameError == "*") {
            setState(() => _nameError = null);
          }
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
        focusNode: _emailFocusNode,
        onChanged: (value) {
          final cleanEmail = value.toLowerCase().replaceAll(' ', '');
          if (value != cleanEmail) {
            _emailController.value = TextEditingValue(
              text: cleanEmail,
              selection: TextSelection.collapsed(offset: cleanEmail.length),
            );
          }
          _fieldTouched['email'] = true;
          if (_emailError == "*") {
            setState(() => _emailError = null);
          }
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
        focusNode: _usernameFocusNode,
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
          if (_usernameError == "*") {
            setState(() => _usernameError = null);
          }
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
              focusNode: _passwordFocusNode,
              obscureText: _obscurePassword,
              onChanged: (_) {
                _fieldTouched['password'] = true;
                if (_passwordError == "*") {
                  setState(() => _passwordError = null);
                }
              },
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
              focusNode: _confirmPasswordFocusNode,
              obscureText: _obscureConfirmPassword,
              onChanged: (_) {
                _fieldTouched['confirmPassword'] = true;
                if (_confirmPasswordError == "*") {
                  setState(() => _confirmPasswordError = null);
                }
              },
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
        focusNode: _phoneFocusNode,
        onChanged: (value) {
          final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
          if (value != digitsOnly) {
            _phoneController.value = TextEditingValue(
              text: digitsOnly,
              selection: TextSelection.collapsed(offset: digitsOnly.length),
            );
          }
          _fieldTouched['phone'] = true;
          if (_phoneError == "*") {
            setState(() => _phoneError = null);
          }
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
          _fieldTouched['gender'] = true;
          _genderError = null;
        });
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

  Widget _buildTermsSection() {
    return Column(
      children: [
        Row(
          children: [
            Checkbox(
              value: _agreeToTerms,
              onChanged: (value) {
                setState(() => _agreeToTerms = value ?? false);
              },
              activeColor: AppColors.primary,
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _agreeToTerms = !_agreeToTerms);
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