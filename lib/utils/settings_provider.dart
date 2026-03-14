// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import '../Screen/models/settings_user_model.dart';
import '../Screen/services/settings_service.dart';


class SettingsProvider extends ChangeNotifier {
  // 🔥 IMPORTANT: _settingsService ko public kar diya
  final SettingsService settingsService = SettingsService();

  UserModel? _userSettings;
  List<Map<String, dynamic>> _followRequests = [];
  List<Map<String, dynamic>> _blockedUsers = [];
  Map<String, double> _storageUsage = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  UserModel? get userSettings => _userSettings;
  List<Map<String, dynamic>> get followRequests => _followRequests;
  List<Map<String, dynamic>> get blockedUsers => _blockedUsers;
  Map<String, double> get storageUsage => _storageUsage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingRequestsCount => _followRequests.length;
  int get blockedUsersCount => _blockedUsers.length;

  void init() {
    loadUserSettings();
    loadFollowRequests();
    loadBlockedUsers();
    loadStorageUsage();
  }

  void loadUserSettings() {
    settingsService.getUserSettingsStream().listen(
          (user) {
        _userSettings = user;
        _error = null;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  void loadFollowRequests() {
    settingsService.getFollowRequests().listen(
          (requests) {
        _followRequests = requests;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  void loadBlockedUsers() {
    settingsService.getBlockedUsersStream().listen(
          (users) {
        _blockedUsers = users;
        notifyListeners();
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  Future<void> loadStorageUsage() async {
    _isLoading = true;
    notifyListeners();
    try {
      _storageUsage = await settingsService.getStorageUsage();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateSettings(Map<String, dynamic> updates) async {
    _isLoading = true;
    notifyListeners();
    try {
      await settingsService.updateUserSettings(updates);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> togglePrivateAccount(bool isPrivate) async {
    try {
      await settingsService.togglePrivateAccount(isPrivate);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> performBackup() async {
    _isLoading = true;
    notifyListeners();
    try {
      await settingsService.performBackup();
      await loadStorageUsage();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> clearCache() async {
    _isLoading = true;
    notifyListeners();
    try {
      await settingsService.clearCache();
      await loadStorageUsage();
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> acceptRequest(String requestId, String fromUserId) async {
    try {
      await settingsService.acceptFollowRequest(requestId, fromUserId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> rejectRequest(String requestId) async {
    try {
      await settingsService.rejectFollowRequest(requestId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await settingsService.unblockUser(userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> submitBugReport({required String subject, required String description}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await settingsService.submitBugReport(subject: subject, description: description);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> submitSupportRequest({required String email, required String message}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await settingsService.submitSupportRequest(email: email, message: message);
      _error = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetSettings() async {
    Map<String, dynamic> defaultSettings = {
      'notificationsEnabled': true,
      'darkMode': false,
      'dataSaver': false,
      'language': 'English',
      'downloadQuality': '720p',
      'storageLocation': 'Phone Storage',
      'isPrivateAccount': false,
      'showOnlineStatus': true,
      'allowTagging': true,
      'allowComments': true,
      'showActivity': true,
      'emailNotifications': true,
      'marketingEmails': false,
    };
    return await updateSettings(defaultSettings);
  }

  @override
  void dispose() {
    super.dispose();
  }
}