import 'package:flutter/material.dart';
import 'package:tapmate/Screen/constants/app_colors.dart';

class TourScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const TourScreen({super.key, required this.onComplete});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  int _currentStep = 0;

  final List<Map<String, dynamic>> _steps = [
    {
      'title': '👤 Profile',
      'description': 'Tap here to edit your profile, view downloads, and customize settings',
      'icon': Icons.person,
      'color': AppColors.primary,
    },
    {
      'title': '📊 Download Dashboard',
      'description': 'Check your download status and readiness here',
      'icon': Icons.download_done,
      'color': AppColors.secondary,
    },
    {
      'title': '📈 Your Stats',
      'description': 'Track your downloads, storage usage, and cloud uploads',
      'icon': Icons.analytics,
      'color': AppColors.accent,
    },
    {
      'title': '📁 Library',
      'description': 'Access and manage all your downloaded videos',
      'icon': Icons.video_library,
      'color': AppColors.primary,
    },
    {
      'title': '⚙️ Settings',
      'description': 'Customize app preferences, theme, and more',
      'icon': Icons.settings,
      'color': AppColors.secondary,
    },
    {
      'title': '⬇️ Download Button',
      'description': 'Tap here to download videos from 10+ platforms',
      'icon': Icons.download,
      'color': AppColors.accent,
    },
    {
      'title': '📍 Navigation',
      'description': 'Switch between Home, Discover, Feed, Messages, and Profile',
      'icon': Icons.menu,
      'color': AppColors.primary,
    },
  ];

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      widget.onComplete();
    }
  }

  void _skipTour() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7),
      body: Stack(
        children: [
          // Semi-transparent background
          Container(
            color: Colors.transparent,
          ),

          // Highlight circle (simulating focus on UI elements)
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: step['color'].withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  step['icon'],
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Tour card at bottom
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress indicator
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_currentStep + 1) / _steps.length,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(step['color']),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_currentStep + 1}/${_steps.length}',
                        style: TextStyle(
                          color: step['color'],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    step['title'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: step['color'],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    step['description'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: _skipTour,
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _nextStep,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: step['color'],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentStep == _steps.length - 1 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}