import 'package:shared_preferences/shared_preferences.dart';

class GuideManager {
  static const String _guideSeenPrefix = 'onboarding_seen_';

  // ✅ NEW METHOD ADD KARO:
  static Future<bool> hasUserCompletedGuide(String userId) async {
    if (userId.isEmpty || userId == 'guest') return true;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_guideSeenPrefix$userId';
    return prefs.getBool(key) ?? false;
  }

  /// Decide whether guide should be shown
  static Future<bool> shouldShowGuide({
    required String userId,
    required bool isGuest,
    required bool isNewSignUp,
  }) async {
    // Guests never see guide
    if (isGuest || userId.isEmpty || userId == 'guest') {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final key = '$_guideSeenPrefix$userId';

    final hasSeenGuide = prefs.getBool(key) ?? false;

    // Show guide if:
    // 1) New signup
    // 2) OR guide not seen before
    if (isNewSignUp) return true;

    return !hasSeenGuide;
  }

  /// Mark guide as completed for this user
  static Future<void> completeGuideForUser(String userId) async {
    if (userId.isEmpty || userId == 'guest') return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_guideSeenPrefix$userId';

    await prefs.setBool(key, true);
  }

  /// Reset guide (useful for testing/debug)
  static Future<void> resetGuideForUser(String userId) async {
    if (userId.isEmpty || userId == 'guest') return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_guideSeenPrefix$userId';

    await prefs.remove(key);
  }
}

