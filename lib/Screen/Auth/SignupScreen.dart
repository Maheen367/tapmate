import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/Auth/permissionscreen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/auth_provider.dart';
import 'dart:ui';

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
  final TextEditingController _recoveryEmailController = TextEditingController();

  // Error messages
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  String? _usernameError;
  String? _phoneError;
  String? _dobError;
  String? _recoveryEmailError;

  // Variables
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  bool _agreeToMarketing = false;
  DateTime? _selectedDate;
  String? _selectedGender;

  // Validation
  bool _isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  bool _isValidPhone(String phone) {
    return RegExp(r"^[0-9]{10,15}$").hasMatch(phone.replaceAll(RegExp(r'[^0-9]'), ''));
  }

  void _validateInputs() {
    setState(() {
      // Name validation
      _nameError = _nameController.text.trim().isEmpty ? "Full Name is required" : null;

      // Email validation
      if (_emailController.text.trim().isEmpty) {
        _emailError = "Email is required";
      } else if (!_isValidEmail(_emailController.text.trim())) {
        _emailError = "Enter a valid email";
      } else {
        _emailError = null;
      }

      // Username validation
      if (_usernameController.text.trim().isEmpty) {
        _usernameError = "Username is required";
      } else if (_usernameController.text.length < 3) {
        _usernameError = "Username must be at least 3 characters";
      } else if (_usernameController.text.contains(' ')) {
        _usernameError = "Username cannot contain spaces";
      } else {
        _usernameError = null;
      }

      // Password validation
      if (_passwordController.text.isEmpty) {
        _passwordError = "Password is required";
      } else if (_passwordController.text.length < 8) {
        _passwordError = "Password must be at least 8 characters";
      } else if (!RegExp(r'[A-Z]').hasMatch(_passwordController.text)) {
        _passwordError = "Must contain uppercase letter";
      } else if (!RegExp(r'[a-z]').hasMatch(_passwordController.text)) {
        _passwordError = "Must contain lowercase letter";
      } else if (!RegExp(r'[0-9]').hasMatch(_passwordController.text)) {
        _passwordError = "Must contain number";
      } else if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_passwordController.text)) {
        _passwordError = "Must contain special character";
      } else {
        _passwordError = null;
      }

      // Confirm password validation
      if (_confirmPasswordController.text.isEmpty) {
        _confirmPasswordError = "Please confirm your password";
      } else if (_confirmPasswordController.text != _passwordController.text) {
        _confirmPasswordError = "Passwords don't match";
      } else {
        _confirmPasswordError = null;
      }

      // Phone validation (optional)
      if (_phoneController.text.trim().isNotEmpty && !_isValidPhone(_phoneController.text)) {
        _phoneError = "Enter a valid phone number";
      } else {
        _phoneError = null;
      }

      // Date of birth validation
      _dobError = _selectedDate == null ? "Date of birth is required" : null;

      // Recovery email validation
      if (_recoveryEmailController.text.trim().isNotEmpty &&
          !_isValidEmail(_recoveryEmailController.text.trim())) {
        _recoveryEmailError = "Invalid recovery email";
      } else {
        _recoveryEmailError = null;
      }
    });
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
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
            Text("• At least one special character"),
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Terms & Conditions"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "By creating an account, you agree to:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text("• Terms of Service"),
              const Text("• Privacy Policy"),
              const Text("• Cookie Policy"),
              const Text("• Community Guidelines"),
              const SizedBox(height: 10),
              const Text(
                "Please review our policies before proceeding.",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _signUp() {
    _validateInputs();

    if (_nameError == null &&
        _emailError == null &&
        _usernameError == null &&
        _passwordError == null &&
        _confirmPasswordError == null &&
        _dobError == null &&
        _agreeToTerms) {

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      String userId = AuthProvider.generateUserIdFromEmail(_emailController.text);

      // Save user info - یہاں صرف وہی parameters pass کریں جو آپ کے auth_provider میں موجود ہیں
      authProvider.setUserInfo(
        userId: userId,
        email: _emailController.text,
      );

      // Additional info کو بعد میں save کریں یا auth_provider میں update کریں
      authProvider.markAsNewSignUp();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PermissionScreen()),
      );
    } else if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please agree to Terms & Conditions"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),

              const SizedBox(height: 20),

              // Logo/Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:  AppColors.primary.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.person_add_alt_1, color: Colors.white, size: 40),
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
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 16,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Full Name
              _inputField(
                controller: _nameController,
                icon: Icons.person_outline,
                hint: "Full Name",
                error: _nameError,
                onChange: _validateInputs,
              ),

              const SizedBox(height: 15),

              // Email
              _inputField(
                controller: _emailController,
                icon: Icons.email_outlined,
                hint: "Email Address",
                error: _emailError,
                keyboardType: TextInputType.emailAddress,
                onChange: _validateInputs,
              ),

              const SizedBox(height: 15),

              // Username
              _inputField(
                controller: _usernameController,
                icon: Icons.alternate_email,
                hint: "Username",
                error: _usernameError,
                onChange: _validateInputs,
              ),

              const SizedBox(height: 15),

              // Password with requirements
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          onChanged: (_) => _validateInputs(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                            hintText: "Password",
                            filled: true,
                            fillColor: const Color(0xFFF0F0F0),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: Colors.black54,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                        onPressed: _showPasswordRequirements,
                      ),
                    ],
                  ),
                  if (_passwordError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        _passwordError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // Confirm Password
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    onChanged: (_) => _validateInputs(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                      hintText: "Confirm Password",
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black54,
                        ),
                        onPressed: () {
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                        },
                      ),
                    ),
                  ),
                  if (_confirmPasswordError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        _confirmPasswordError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // Phone Number
              _inputField(
                controller: _phoneController,
                icon: Icons.phone_outlined,
                hint: "Phone Number (Optional)",
                error: _phoneError,
                keyboardType: TextInputType.phone,
                onChange: _validateInputs,
              ),

              const SizedBox(height: 15),

              // Date of Birth
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: AbsorbPointer(
                      child: TextField(
                        controller: _dobController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_today, color: Colors.black54),
                          hintText: "Date of Birth",
                          filled: true,
                          fillColor: const Color(0xFFF0F0F0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                        ),
                      ),
                    ),
                  ),
                  if (_dobError != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        _dobError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // Gender Selection
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text("Gender (Optional)", style: TextStyle(color: Colors.black54)),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _genderButton("Male", Icons.male),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _genderButton("Female", Icons.female),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _genderButton("Other", Icons.transgender),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 15),

              // Recovery Email
              _inputField(
                controller: _recoveryEmailController,
                icon: Icons.email,
                hint: "Recovery Email (Optional)",
                error: _recoveryEmailError,
                keyboardType: TextInputType.emailAddress,
                onChange: _validateInputs,
              ),

              const SizedBox(height: 20),

              // Terms & Conditions
              Column(
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
                              style: TextStyle(color: Colors.black87),
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
                  Row(
                    children: [
                      Checkbox(
                        value: _agreeToMarketing,
                        onChanged: (value) {
                          setState(() => _agreeToMarketing = value ?? false);
                        },
                        activeColor: AppColors.primary,
                      ),
                      const Expanded(
                        child: Text(
                          "Receive marketing emails and updates",
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:  AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
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
              ),

              const SizedBox(height: 20),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "Or sign up with",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),

              const SizedBox(height: 20),

              // Social Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(
                    icon: Icons.g_translate,
                    color: Colors.red,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Google sign up tapped"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _socialButton(
                    icon: Icons.facebook,
                    color: Colors.blue,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Facebook sign up tapped"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _socialButton(
                    icon: Icons.apple,
                    color: Colors.black,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Apple sign up tapped"),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // Sign In Link
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(color: Colors.black87),
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
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? error,
    TextInputType keyboardType = TextInputType.text,
    required Function onChange,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: (_) => onChange(),
          keyboardType: keyboardType,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.black54),
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF0F0F0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: Text(
              error,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _genderButton(String gender, IconData icon) {
    bool isSelected = _selectedGender == gender;
    return OutlinedButton(
      onPressed: () {
        setState(() => _selectedGender = gender);
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ?  AppColors.primary.withOpacity(0.1) : null,
        side: BorderSide(
          color: isSelected ?  AppColors.primary : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isSelected ?  AppColors.primary : Colors.grey[600], size: 20),
          const SizedBox(width: 8),
          Text(
            gender,
            style: TextStyle(
              color: isSelected ?  AppColors.primary : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}

