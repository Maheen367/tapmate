import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🔥 ADD THIS IMPORT
import 'package:tapmate/Screen/Auth/permissionscreen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';
import 'package:tapmate/Screen/Auth/SignupScreen.dart';
import 'package:tapmate/Screen/Auth/resetpasswordScreen.dart';
import 'package:tapmate/Screen/home/home_screen.dart';
import 'package:tapmate/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final savedEmail = await authProvider.getSavedEmail();
      if (savedEmail != null && savedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved email: $e');
    }
  }

  // 🔥 UPDATED Login Handler with Flag Save
  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);

        final result = await authProvider.loginWithEmailPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (result['success'] == true) {
          // 🔥🔥🔥 SAVE LOGIN FLAG HERE 🔥🔥🔥
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);

          // Check if user is new (first time login)
          bool isFirstTimeLogin = result['isFirstTime'] ?? true;
          if (isFirstTimeLogin) {
            await prefs.setBool('isNewUser', true);
          }

          if (_rememberMe) {
            await authProvider.saveUserEmail(_emailController.text.trim());
          } else {
            await authProvider.clearSavedEmail();
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
              ),
            );

            // Check if permission screen is needed
            bool needsPermission = await authProvider.needsPermissionScreen();

            if (needsPermission) {
              // New user - go to permission screen
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const PermissionScreen()),
              );
            } else {
              // Existing user - go to home
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            }
          }
        } else {
          setState(() {
            _errorMessage = result['message'];
          });
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'An unexpected error occurred';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // 🔥 Google Login Handler with Flag Save
  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.signInWithGoogle();

      if (result['success'] == true) {
        // 🔥🔥🔥 SAVE LOGIN FLAG HERE 🔥🔥🔥
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google sign in successful!'),
              backgroundColor: Colors.green,
            ),
          );

          // Check if permission screen is needed for new Google users
          bool isNewUser = result['isNewUser'] ?? false;

          if (isNewUser) {
            await prefs.setBool('isNewUser', true);
            // New user - go to permission screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PermissionScreen()),
            );
          } else {
            // Existing user - go to home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Google sign in failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 🔥 Facebook Login Handler with Flag Save
  Future<void> _handleFacebookLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await authProvider.signInWithFacebook();

      if (result['success'] == true) {
        // 🔥🔥🔥 SAVE LOGIN FLAG HERE 🔥🔥🔥
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Facebook sign in successful!'),
              backgroundColor: Colors.green,
            ),
          );

          // Check if permission screen is needed for new Facebook users
          bool isNewUser = result['isNewUser'] ?? false;

          if (isNewUser) {
            await prefs.setBool('isNewUser', true);
            // New user - go to permission screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const PermissionScreen()),
            );
          } else {
            // Existing user - go to home
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        }
      } else {
        setState(() {
          _errorMessage = result['message'];
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Facebook sign in failed';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Guest Login Handler
  void _handleGuestLogin() {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.setGuestMode(true);
      authProvider.setOnboardingCompleted(true);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      debugPrint('Guest login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.rosePink,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),

                // Back Button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28, color: AppColors.textMain),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                const SizedBox(height: 10),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary,
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_open, color: AppColors.lightSurface, size: 40),
                  ),
                ),

                const SizedBox(height: 20),

                // Title
                const Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  "Sign in to your account",
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 30),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMain),
                    hintText: "Email Address",
                    filled: true,
                    fillColor: AppColors.lightSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Email is required";
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return "Invalid email format";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 15),

                // Password Field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textMain),
                    hintText: "Password",
                    filled: true,
                    fillColor: AppColors.lightSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: AppColors.textMain,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Password is required";
                    }
                    if (value.length < 6) {
                      return "Password must be at least 6 characters";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 10),

                // Remember Me & Forgot Password Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Remember Me
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) => setState(() => _rememberMe = value ?? false),
                          activeColor: AppColors.primary,
                        ),
                        const Text(
                          "Remember me",
                          style: TextStyle(color: AppColors.textMain),
                        ),
                      ],
                    ),

                    // Forgot Password
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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
                      "Sign In",
                      style: TextStyle(
                        color: AppColors.lightSurface,
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
                    Expanded(
                      child: Divider(color: Colors.grey[300]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        "Or continue with",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey[300]),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Social Login Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialButton(
                      icon: Icons.g_translate,
                      color: Colors.red,
                      onTap: _handleGoogleLogin,
                    ),
                    const SizedBox(width: 20),
                    _socialButton(
                      icon: Icons.facebook,
                      color: Colors.blue,
                      onTap: _handleFacebookLogin,
                    ),
                    const SizedBox(width: 20),
                    // _socialButton(
                    //   icon: Icons.apple,
                    //   color: AppColors.textMain,
                    //   onTap: () {
                    //     ScaffoldMessenger.of(context).showSnackBar(
                    //       const SnackBar(
                    //         content: Text("Apple login coming soon!"),
                    //         duration: Duration(seconds: 1),
                    //       ),
                    //     );
                    //   },
                    // ),
                  ],
                ),

                const SizedBox(height: 25),

                // Sign Up Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(color: AppColors.textMain),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // Guest Login
                TextButton(
                  onPressed: _handleGuestLogin,
                  child: const Text(
                    "Continue as Guest",
                    style: TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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