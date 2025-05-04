import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:flutter/services.dart'; // Unused
import '../config/app_config.dart';
import '../models/user.dart';
// import '../lib/utils/logger.dart'; // Commented out logger import

class AuthService {
  final String baseUrl;
  String? _token;
  User? _user;
  final ValueNotifier<bool> isAuthenticated = ValueNotifier<bool>(false);
  // final _logger = Logger('AuthService'); // Commented out logger initialization

  AuthService({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.cloudBaseUrl;

  // Get the current user
  User? getUser() => _user;

  // Get the authentication token
  String? getToken() => _token;

  // For backward compatibility
  String? get token => _token;

  // Initialize the auth service
  Future<void> initialize() async {
    await _loadStoredAuth();
  }

  // Load stored token and user data
  Future<void> _loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    final userJson = prefs.getString('user_data');
    if (_token != null && userJson != null) {
      _user = User.fromJson(jsonDecode(userJson));
      isAuthenticated.value = true;
    } else {
      isAuthenticated.value = false;
    }
  }

  // Save token and user data
  Future<void> _saveAuth(String token, User user) async {
    _token = token;
    _user = user;
    isAuthenticated.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_data', jsonEncode(user.toJson()));
  }

  // Clear stored token and user data
  Future<void> _clearAuth() async {
    _token = null;
    _user = null;
    isAuthenticated.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
  }

  // Login with Auth0
  Future<void> loginWithAuth0() async {
    debugPrint("Auth0 login not implemented yet."); // Use debugPrint
    // Placeholder logic
    await Future.delayed(const Duration(seconds: 1));
    // Simulate successful login for testing
    // final dummyUser = User(id: 'auth0|12345', name: 'Auth0 User', email: 'auth0@example.com');
    // await _saveAuth('dummy-auth0-token', dummyUser);
  }

  // Login with username and password
  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final user = User.fromJson(data['user']);

        await _saveAuth(token, user);
        return true;
      } else {
        // _logger.warning('Login failed: ${response.statusCode} ${response.body}'); // Use logger
        debugPrint(
            'Login failed: ${response.statusCode} ${response.body}'); // Temporary print
        return false;
      }
    } catch (e) {
      // _logger.error('Login error: $e'); // Use logger
      debugPrint('Login error: $e'); // Temporary print
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      if (_token != null) {
        // Call logout API if needed
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        );
      }
    } catch (e) {
      // _logger.warning('Error during API logout: $e'); // Log logout API error
      debugPrint('Error during API logout: $e'); // Temporary print
    } finally {
      await _clearAuth();
    }
  }

  // Check if the token is valid
  Future<bool> validateToken() async {
    if (_token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/validate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Register a new user
  Future<bool> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 201) {
        return true; // Registration successful
      } else {
        // _logger.warning('Registration failed: ${response.statusCode} ${response.body}'); // Use logger
        debugPrint(
            'Registration failed: ${response.statusCode} ${response.body}'); // Temporary print
        return false;
      }
    } catch (e) {
      // _logger.error('Registration error: $e'); // Use logger
      debugPrint('Registration error: $e'); // Temporary print
      return false;
    }
  }
}
