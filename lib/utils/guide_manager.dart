import 'package:shared_preferences/shared_preferences.dart';

/// Centralized GuideManager
/// - User-scoped guide completion tracking
/// - Backward-compatible global methods
/// - Guide versioning to force resets on updates
class GuideManager {
  static const String _globalGuideKey = 'onboarding_guide_completed';
  static const String _globalGuideVersionKey = 'onboarding_guide_version';
  static const int _currentGuideVersion = 1;

  static String _userGuideKey(String userId) => 'guide_completed_\$userId';
  static String _userFirstTimeKey(String userId) => 'first_time_user_\$userId';
  static String _firstDownloadShownKey(String userId) => 'first_download_shown_\$userId';

  // ================== GLOBAL (backwards compatible) ==================
  static Future<bool> hasCompletedGuide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_globalGuideKey) ?? false;
      final version = prefs.getInt(_globalGuideVersionKey) ?? 0;
      if (version < _currentGuideVersion) {
        await resetGuide();
        return false;
      }
      return completed;
    } catch (e) {
      return false;
    }
  }

  static Future<void> completeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalGuideKey, true);
    await prefs.setInt(_globalGuideVersionKey, _currentGuideVersion);
  }

  static Future<void> resetGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_globalGuideKey, false);
    await prefs.setInt(_globalGuideVersionKey, _currentGuideVersion);
  }

  // ================== USER-SCOPED METHODS ==================
  static Future<bool> hasUserCompletedGuide(String userId) async {
    if (userId.isEmpty || userId == 'guest') return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userGuideKey(userId)) ?? false;
  }

  static Future<void> completeGuideForUser(String userId) async {
    if (userId.isEmpty || userId == 'guest') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userGuideKey(userId), true);
    await prefs.setBool(_userFirstTimeKey(userId), false);
    await prefs.setInt(_globalGuideVersionKey, _currentGuideVersion);
  }

  static Future<void> resetGuideForUser(String userId) async {
    if (userId.isEmpty || userId == 'guest') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userGuideKey(userId), false);
    await prefs.setBool(_userFirstTimeKey(userId), true);
  }

  static Future<bool> isFirstTimeUser(String userId) async {
    if (userId.isEmpty || userId == 'guest') return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userFirstTimeKey(userId)) ?? true;
  }

  static Future<void> markUserAsReturning(String userId) async {
    if (userId.isEmpty || userId == 'guest') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userFirstTimeKey(userId), false);
  }

  /// Decide whether to show guide for a user
  /// - guests: false
  /// - newSignUp: true
  /// - otherwise based on per-user flag
  static Future<bool> shouldShowGuide({
    required String userId,
    required bool isGuest,
    bool isNewSignUp = false,
  }) async {
    if (isGuest) return false;
    if (isNewSignUp) return true;
    final completed = await hasUserCompletedGuide(userId);
    return !completed;
  }

  // ================== First-download celebratory flag ==================
  static Future<bool> hasShownFirstDownload(String userId) async {
    if (userId.isEmpty || userId == 'guest') return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstDownloadShownKey(userId)) ?? false;
  }

  static Future<void> markFirstDownloadShown(String userId) async {
    if (userId.isEmpty || userId == 'guest') return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstDownloadShownKey(userId), true);
  }
}





