// dart
import 'package:flutter/material.dart';
import 'permissionscreen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _recoveryEmailController = TextEditingController();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _recoveryEmailError;

  bool _isValidEmail(String email) {
    return RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email);
  }

  void _validateInputs() {
    setState(() {
      if (_nameController.text.trim().isEmpty) {
        _nameError = "Full Name is required";
      } else {
        _nameError = null;
      }

      if (_emailController.text.trim().isEmpty) {
        _emailError = "Email is required";
      } else if (!_isValidEmail(_emailController.text.trim())) {
        _emailError = "Enter a valid email";
      } else {
        _emailError = null;
      }

      if (_passwordController.text.isEmpty) {
        _passwordError = "Password is required";
      } else if (_passwordController.text.length < 6) {
        _passwordError = "Password must be at least 6 characters";
      } else {
        _passwordError = null;
      }

      if (_recoveryEmailController.text.trim().isNotEmpty &&
          !_isValidEmail(_recoveryEmailController.text.trim())) {
        _recoveryEmailError = "Invalid recovery email";
      } else {
        _recoveryEmailError = null;
      }
    });
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),

              // Back Button
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Gradient Logo
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFA64D79),
                      Color(0xFF6A1E55),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.download, color: Colors.white, size: 40),
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Create Account",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A1E55),
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                "Sign up to get started",
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 25),

              // Full Name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    onChanged: (_) => _validateInputs(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.person_outline, color: Colors.black54),
                      hintText: "Full Name",
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_nameError != null)
                    Text(
                      _nameError!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // Email
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _emailController,
                    onChanged: (_) => _validateInputs(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.black54),
                      hintText: "Email Address",
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_emailError != null)
                    Text(
                      _emailError!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // Password
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (_) => _validateInputs(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, color: Colors.black54),
                      hintText: "Password",
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_passwordError != null)
                    Text(
                      _passwordError!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),

              const SizedBox(height: 15),

              // Recovery Email
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _recoveryEmailController,
                    onChanged: (_) => _validateInputs(),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email, color: Colors.black54),
                      hintText: "Recovery Email (Optional)",
                      filled: true,
                      fillColor: const Color(0xFFF0F0F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (_recoveryEmailError != null)
                    Text(
                      _recoveryEmailError!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                ],
              ),

              const SizedBox(height: 20),

              // Create Account Button with gradient
              SizedBox(
                width: double.infinity,
                height: 55,
                child: TextButton(
                  onPressed: () {
                    _validateInputs();

                    if (_nameError == null &&
                        _emailError == null &&
                        _passwordError == null &&
                        _recoveryEmailError == null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => PermissionScreen()),
                      );
                    }
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6A1E55), Color(0xFFA64D79)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        "Create Account",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Sign In Redirect
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ", style: TextStyle(fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Sign In",
                      style: TextStyle(color: Color(0xFFA64D79), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Social Buttons (PNG logos)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButtonImage("Google", 'assets/icons/google_logo.png', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Google button tapped"),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }),
                  const SizedBox(width: 20),
                  _socialButtonImage("Facebook", 'assets/icons/facebook_logo.png', () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Facebook button tapped"),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }),
                ],
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Social button using PNG image
  Widget _socialButtonImage(String title, String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.black12),
          color: const Color(0xFFF0F0F0),
        ),
        child: Row(
          children: [
            Image.asset(assetPath, width: 24, height: 24),
            const SizedBox(width: 5),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
