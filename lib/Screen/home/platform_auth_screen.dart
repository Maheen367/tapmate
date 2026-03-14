// lib/Screen/home/platform_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tapmate/Screen/services/platform_auth_service.dart';
import 'package:tapmate/Screen/services/platform_downloader.dart';
import 'platform_content_screen.dart';
import 'platform_forgot_password_screen.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

class PlatformAuthScreen extends StatefulWidget {
  final String platformName;
  final String platformId;
  final Color platformColor;
  final IconData platformIcon;

  const PlatformAuthScreen({
    super.key,
    required this.platformName,
    required this.platformId,
    required this.platformColor,
    required this.platformIcon,
  });

  @override
  State<PlatformAuthScreen> createState() => _PlatformAuthScreenState();
}

class _PlatformAuthScreenState extends State<PlatformAuthScreen> with SingleTickerProviderStateMixin {
  bool _isSignIn = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _checkSavedCredentials();
  }

  Future<void> _checkSavedCredentials() async {
    final service = PlatformAuthService();
    final session = await service.getSession(widget.platformId);

    if (session != null && !session.isExpired) {
      // Auto-login if session exists
      _navigateToContent(session);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _navigateToContent(PlatformSession session) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PlatformContentScreen(
          platformName: widget.platformName,
          platformId: widget.platformId,
          platformColor: widget.platformColor,
          platformIcon: widget.platformIcon,
          platformSession: session,
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 🔐 PLATFORM-SPECIFIC AUTHENTICATION
        // This is where you implement actual platform login APIs

        // For YouTube:
        if (widget.platformId == 'youtube') {
          await _authenticateYouTube();
        }
        // For Instagram:
        else if (widget.platformId == 'instagram') {
          await _authenticateInstagram();
        }
        // For TikTok:
        else if (widget.platformId == 'tiktok') {
          await _authenticateTikTok();
        }
        // For others:
        else {
          await _authenticateGeneric();
        }

      } catch (e) {
        _showErrorSnackBar('Authentication failed: ${e.toString()}');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // 🎯 YouTube Authentication
  Future<void> _authenticateYouTube() async {
    // TODO: Implement YouTube OAuth2
    // Use google_sign_in package

    // For now, simulate:
    await Future.delayed(const Duration(seconds: 2));

    final session = PlatformSession(
      platformId: widget.platformId,
      accessToken: 'mock_youtube_token_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'mock_refresh_token',
      userId: 'user_123',
      userName: _usernameController.text.isNotEmpty
          ? _usernameController.text
          : _emailController.text.split('@').first,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      userData: {'email': _emailController.text},
    );

    await PlatformAuthService().saveSession(widget.platformId, session);

    if (_rememberMe) {
      // Save for auto-login
    }

    _showSuccessSnackBar('✅ Successfully signed in to YouTube!');
    _navigateToContent(session);
  }

  // 🎯 Instagram Authentication
  Future<void> _authenticateInstagram() async {
    // TODO: Implement Instagram OAuth
    await Future.delayed(const Duration(seconds: 2));

    final session = PlatformSession(
      platformId: widget.platformId,
      accessToken: 'mock_instagram_token',
      refreshToken: 'mock_refresh_token',
      userId: 'insta_user_123',
      userName: _usernameController.text.isNotEmpty
          ? _usernameController.text
          : _emailController.text.split('@').first,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      userData: {'email': _emailController.text},
    );

    await PlatformAuthService().saveSession(widget.platformId, session);
    _showSuccessSnackBar('✅ Successfully signed in to Instagram!');
    _navigateToContent(session);
  }

  // 🎯 TikTok Authentication
  Future<void> _authenticateTikTok() async {
    // TODO: Implement TikTok OAuth
    await Future.delayed(const Duration(seconds: 2));

    final session = PlatformSession(
      platformId: widget.platformId,
      accessToken: 'mock_tiktok_token',
      refreshToken: 'mock_refresh_token',
      userId: 'tiktok_user_123',
      userName: _usernameController.text.isNotEmpty
          ? _usernameController.text
          : _emailController.text.split('@').first,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      userData: {'email': _emailController.text},
    );

    await PlatformAuthService().saveSession(widget.platformId, session);
    _showSuccessSnackBar('✅ Successfully signed in to TikTok!');
    _navigateToContent(session);
  }

  // 🎯 Generic Authentication (for other platforms)
  Future<void> _authenticateGeneric() async {
    await Future.delayed(const Duration(seconds: 2));

    final session = PlatformSession(
      platformId: widget.platformId,
      accessToken: 'mock_token_${widget.platformId}',
      refreshToken: 'mock_refresh_token',
      userId: '${widget.platformId}_user_123',
      userName: _usernameController.text.isNotEmpty
          ? _usernameController.text
          : _emailController.text.split('@').first,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      userData: {'email': _emailController.text},
    );

    await PlatformAuthService().saveSession(widget.platformId, session);
    _showSuccessSnackBar('✅ Successfully signed in to ${widget.platformName}!');
    _navigateToContent(session);
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightSurface,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Gradient Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.secondary, AppColors.primary],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(35),
                  bottomRight: Radius.circular(35),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Platform Icon with Animation
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 3,
                              ),
                            ),
                            child: Icon(
                              widget.platformIcon,
                              color: Colors.white,
                              size: 45,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 15),
                    Text(
                      _isSignIn
                          ? 'Sign in to ${widget.platformName}'
                          : 'Create ${widget.platformName} Account',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isSignIn
                          ? 'Enter your credentials to continue'
                          : 'Create a new account to get started',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      // Username Field (for sign up)
                      if (!_isSignIn) ...[
                        const Text(
                          'Username',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.person_outline, color: widget.platformColor),
                            hintText: 'Choose a username',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: widget.platformColor.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: widget.platformColor, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (!_isSignIn && (value == null || value.isEmpty)) {
                              return 'Username is required';
                            }
                            if (value != null && value.length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email Field
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.email_outlined, color: widget.platformColor),
                          hintText: 'Enter your email',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: widget.platformColor.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: widget.platformColor, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Email cannot be empty';
                          }
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Invalid email format';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock_outline, color: widget.platformColor),
                          hintText: 'Enter your password',
                          filled: true,
                          fillColor: Colors.grey[50],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: widget.platformColor.withOpacity(0.2)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: widget.platformColor, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: widget.platformColor,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password cannot be empty';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),

                      // Confirm Password (for sign up)
                      if (!_isSignIn) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Confirm Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline, color: widget.platformColor),
                            hintText: 'Re-enter your password',
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: widget.platformColor.withOpacity(0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: widget.platformColor, width: 2),
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: widget.platformColor,
                              ),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Remember Me & Forgot Password
                      if (_isSignIn) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                  activeColor: widget.platformColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const Text(
                                  'Remember me',
                                  style: TextStyle(color: AppColors.accent),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlatformForgotPasswordScreen(
                                      platformName: widget.platformName,
                                      platformId: widget.platformId,
                                      platformColor: widget.platformColor,
                                      platformIcon: widget.platformIcon,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: widget.platformColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Sign In / Sign Up Button
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.platformColor,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: widget.platformColor.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : Text(
                            _isSignIn ? 'Sign In' : 'Create Account',
                            style: const TextStyle(
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
                              'or',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[300])),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Toggle Sign In / Sign Up
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isSignIn ? "Don't have an account? " : 'Already have an account? ',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isSignIn = !_isSignIn;
                                  _emailController.clear();
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                  _usernameController.clear();
                                });
                              },
                              child: Text(
                                _isSignIn ? 'Sign Up' : 'Sign In',
                                style: TextStyle(
                                  color: widget.platformColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}