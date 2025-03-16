import 'package:flutter/foundation.dart';
import 'services/auth_service.dart';

class PointsNotifier extends ChangeNotifier {
  int _points = 0;
  int _completedFormsCount = 0;
  final AuthService _authService;
  bool _isLoading = true;

  // Constructor takes initialPoints and completedFormsCount as parameters
  PointsNotifier({
    int initialPoints = 0,
    int initialCompletedFormsCount = 0,
    AuthService? authService
  })  : _points = initialPoints,
        _completedFormsCount = initialCompletedFormsCount,
        _authService = authService ?? AuthService() {
    _initData();
  }

  // Initialize both points and forms count
  Future<void> _initData() async {
    _isLoading = true;
    notifyListeners();

    // First load from local storage for immediate display
    _points = await _authService.getUserPoints();
    _completedFormsCount = await _authService.getCompletedFormsCountFromStorage();
    _isLoading = false;
    notifyListeners();

    // Then fetch the latest from server
    await refreshDataFromServer();
  }

  // Getter for points
  int get points => _points;

  // Getter for completed forms count
  int get completedFormsCount => _completedFormsCount;

  // Getter for loading state
  bool get isLoading => _isLoading;

  // Refresh both points and forms count from server
  Future<void> refreshDataFromServer() async {
    try {
      // Fetch user profile for points
      final profileResult = await _authService.fetchUserProfile();
      if (profileResult['success']) {
        _points = profileResult['data']['points'];
      }

      // Fetch completed forms count
      final formsResult = await _authService.getCompletedFormsCount();
      if (formsResult['success']) {
        _completedFormsCount = formsResult['data']['completed_forms_count'];
      }

      notifyListeners();
    } catch (error) {
      // Handle error gracefully, log if necessary
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add points and update server
  Future<bool> addPoints(int amount) async {
    if (amount <= 0) {
      return false;
    }

    final updatedPoints = _points + amount;
    final result = await _authService.updatePoints(updatedPoints);

    if (result['success']) {
      _points = result['data']['points'];
      notifyListeners();
      return true;
    }
    return false;
  }

  // Deduct points and update server
  Future<bool> deductPoints(int amount) async {
    if (amount <= 0 || _points < amount) {
      return false;
    }

    final updatedPoints = _points - amount;
    final result = await _authService.updatePoints(updatedPoints);

    if (result['success']) {
      _points = result['data']['points'];
      notifyListeners();
      return true;
    }
    return false;
  }

  // Mark a form as completed
  Future<bool> markFormCompleted(String formTitle) async {
    final result = await _authService.markFormCompleted(formTitle);

    if (result['success']) {
      // Update both points and completed forms count if provided in response
      if (result.containsKey('data')) {
        if (result['data'].containsKey('points')) {
          _points = result['data']['points'];
        }
        if (result['data'].containsKey('completed_forms_count')) {
          _completedFormsCount = result['data']['completed_forms_count'];
        }
      } else {
        // If data not provided, increment form count and refresh from server
        _completedFormsCount += 1;
        await refreshDataFromServer();
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  // Get list of completed forms
  Future<List<String>> getCompletedFormsList() async {
    final result = await _authService.getCompletedFormsCount();
    if (result['success'] && result['data'].containsKey('completed_forms')) {
      return List<String>.from(result['data']['completed_forms']);
    }
    return [];
  }

  // Set points directly (for initialization or sync)
  void setPoints(int newPoints) {
    _points = newPoints;
    notifyListeners();
  }

  // Set completed forms count directly
  void setCompletedFormsCount(int count) {
    _completedFormsCount = count;
    notifyListeners();
  }

  // Reset both points and forms count (for logout)
  void reset() {
    _points = 0;
    _completedFormsCount = 0;
    notifyListeners();
  }
}