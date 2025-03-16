import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Replace with your actual Django backend URL
  final String baseUrl = 'http://192.168.50.23:8000/api';

  // Storage keys for token, email, points and completed forms count
  static const String _tokenKey = 'auth_token';
  static const String _emailKey = 'user_email';
  static const String _pointsKey = 'user_points';
  static const String _completedFormsCountKey = 'completed_forms_count';

  // ------------------- Authentication Methods -------------------

  // Sign up with email and password
  Future<Map<String, dynamic>> signUp(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
          'points': 0, // Initialize with zero points
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        // Save token, email and initial points on successful signup
        await _saveToken(responseData['token']);
        await _saveEmail(email);
        await _savePoints(responseData['points'] ?? 0);
        await _saveCompletedFormsCount(0); // Initialize completed forms count to 0
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Sign up failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signin/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        await _saveToken(responseData['token']);
        await _saveEmail(email);
        if (responseData.containsKey('points')) {
          await _savePoints(responseData['points']);
        }
        // Fetch and save completed forms count after successful login
        await getCompletedFormsCount();
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Sign in failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Fetch user profile including points
  Future<Map<String, dynamic>> fetchUserProfile() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/user-profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        if (responseData.containsKey('points')) {
          await _savePoints(responseData['points']);
        }
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to fetch profile'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // --------------------- Forms & Points Methods ---------------------

  // Fetch completed forms count directly using the dedicated endpoint
  Future<Map<String, dynamic>> getCompletedFormsCount() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/count_forms_submitted/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        int completedFormsCount = responseData['forms_submitted'];
        await _saveCompletedFormsCount(completedFormsCount);
        return {
          'success': true,
          'data': {'completed_forms_count': completedFormsCount}
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ??
              'Failed to fetch completed forms count'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Update user points
  Future<Map<String, dynamic>> updatePoints(int points) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/update-points/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({'points': points}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        await _savePoints(responseData['points']);
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to update points'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // Mark a form as completed
  Future<Map<String, dynamic>> markFormCompleted(String formTitle) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/mark_form_completed/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({'form_title': formTitle}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Update both the forms count and points in local storage
        int currentCount = await getCompletedFormsCountFromStorage();
        int newCount = currentCount + 1;
        await _saveCompletedFormsCount(newCount);

        // Update points if returned in the response
        if (responseData.containsKey('points')) {
          await _savePoints(responseData['points']);
        }

        return {
          'success': true,
          'message': 'Form marked as completed',
          'data': {
            'points': responseData['points'] ?? await getUserPoints(),
            'completed_forms_count': newCount
          }
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to mark form as completed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // ---------------- Reward Redemption Functions ----------------

  /// Sends a reward redemption request.
  /// Note: This action does NOT immediately deduct points. The deduction occurs only after admin approval.
  Future<Map<String, dynamic>> requestRewardRedemption(String rewardName, int rewardPoints) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/redeem_reward/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'reward_name': rewardName,
          'reward_points': rewardPoints,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // The redemption request has been successfully submitted.
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to request reward redemption'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Approves a reward redemption request (Admin-only).
  /// This endpoint deducts points once the reward is approved.
  Future<Map<String, dynamic>> approveRewardRedemption(String redemptionRequestId) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/approve_reward/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'redemption_request_id': redemptionRequestId,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // The admin has approved the reward redemption and points have been deducted accordingly.
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to approve reward redemption'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  /// Fetches all redemption requests for the current user.
  Future<Map<String, dynamic>> fetchRedemptionRequests() async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/redemption_requests/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        // Expecting a JSON structure with a 'requests' key containing a list of redemption requests.
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to fetch redemption requests'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // ------------------- Image Upload Function -------------------

  // Upload achievement image to backend and AWS S3
  Future<Map<String, dynamic>> uploadAchievementImage(String imagePath) async {
    try {
      final token = await _getToken();
      if (token == null) {
        return {'success': false, 'message': 'Not authenticated'};
      }

      // Prepare multipart request for file upload
      var uri = Uri.parse('$baseUrl/upload_achievement_image/');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Token $token';

      // Attach image file with field key 'image'
      request.files.add(await http.MultipartFile.fromPath('image', imagePath));

      // Send request and parse response
      var streamedResponse = await request.send();
      var responseString = await streamedResponse.stream.bytesToString();
      final responseData = json.decode(responseString);

      if (streamedResponse.statusCode == 201) {
        return {'success': true, 'data': responseData};
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Achievement image upload failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: ${e.toString()}'};
    }
  }

  // ------------------- Local Storage Functions -------------------

  // Save completed forms count
  Future<void> _saveCompletedFormsCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_completedFormsCountKey, count);
  }

  // Retrieve completed forms count from local storage
  Future<int> getCompletedFormsCountFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_completedFormsCountKey) ?? 0;
  }

  // Sign out - clear stored token, email, points, and completed forms count
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_pointsKey);
    await prefs.remove(_completedFormsCountKey);
  }

  // Check if user is signed in
  Future<bool> isSignedIn() async {
    final token = await _getToken();
    return token != null;
  }

  // Get current auth token
  Future<String?> getToken() async {
    return _getToken();
  }

  // Save auth token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Retrieve auth token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Save user email
  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  // Retrieve user email
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  // Save user points
  Future<void> _savePoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey, points);
  }

  // Retrieve user points
  Future<int> getUserPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }
}
