// lib/providers/settings_provider.dart
import 'package:flutter/material.dart';
import '../Screen/models/settings_user_model.dart';
import '../Screen/services/settings_service.dart';



class SettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  UserModel? _userSettings;
  List<Map<String, dynamic>> _followRequests = [];
  Map<String, double> _storageUsage = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  UserModel? get userSettings => _userSettings;
  List<Map<String, dynamic>> get followRequests => _followRequests;
  Map<String, double> get storageUsage => _storageUsage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingRequestsCount => _followRequests.length;

  // Load user settings
  void loadUserSettings() {
    _settingsService.getUserSettings().listen((user) {
      _userSettings = user as UserModel?;
      notifyListeners();
    }, onError: (error) {
      _error = error.toString();
      notifyListeners();
    });
  }

  // Load follow requests
  void loadFollowRequests() {
    _settingsService.getFollowRequests().listen((requests) {
      _followRequests = requests;
      notifyListeners();
    }, onError: (error) {
      _error = error.toString();
      notifyListeners();
    });
  }

  // Load storage usage
  Future<void> loadStorageUsage() async {
    _isLoading = true;
    notifyListeners();

    try {
      _storageUsage = await _settingsService.getStorageUsage();
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Update settings
  Future<bool> updateSettings(Map<String, dynamic> updates) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.updateUserSettings(updates);
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

  // Toggle private account
  Future<void> togglePrivateAccount(bool isPrivate) async {
    await _settingsService.togglePrivateAccount(isPrivate);
    // Update will come through stream
  }

  // Perform backup
  Future<bool> performBackup() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.performBackup();
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

  // Clear cache
  Future<bool> clearCache() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _settingsService.clearCache();
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

  // Accept follow request
  Future<void> acceptRequest(String requestId, String fromUserId) async {
    await _settingsService.acceptFollowRequest(requestId, fromUserId);
    // Will update through stream
  }

  // Reject follow request
  Future<void> rejectRequest(String requestId) async {
    await _settingsService.rejectFollowRequest(requestId);
    // Will update through stream
  }

  // Reset all settings
  Future<bool> resetSettings() async {
    Map<String, dynamic> defaultSettings = {
      'notificationsEnabled': true,
      'darkMode': false,
      'dataSaver': false,
      'language': 'English',
      'downloadQuality': '720p',
      'storageLocation': 'Phone Storage',
      'isPrivate': false,
      'showOnlineStatus': true,
      'allowTagging': true,
      'allowComments': true,
      'showActivity': true,
    };

    return await updateSettings(defaultSettings);
  }

  @override
  void dispose() {
    super.dispose();
  }
}