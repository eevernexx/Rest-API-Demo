// test/services/task_api_test.dart
// Unit test untuk TaskApiService - Session Management

import 'package:flutter_test/flutter_test.dart';
import 'package:rest_api_demo/api/task_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TaskApiService - Session Management Tests', () {
    late TaskApiService apiService;

    setUp(() {
      apiService = TaskApiService();
      // Initialize SharedPreferences dengan mock values
      SharedPreferences.setMockInitialValues({});
    });

    group('Session Tests', () {
      test('loadSession should return saved session when exists', () async {
        // Arrange - Setup mock saved session
        SharedPreferences.setMockInitialValues({
          'access_token': 'saved_token_123',
          'user_id': 'user789',
          'user_email': 'saved@example.com',
        });

        // Act
        final session = await apiService.loadSession();

        // Assert
        expect(session, isNotNull);
        expect(session!['token'], 'saved_token_123');
        expect(session['userId'], 'user789');
        expect(session['email'], 'saved@example.com');
      });

      test('loadSession should return null when no session exists', () async {
        // Arrange - No saved session
        SharedPreferences.setMockInitialValues({});

        // Act
        final session = await apiService.loadSession();

        // Assert
        expect(session, isNull);
      });

      test('loadSession should return null when session is incomplete', () async {
        // Arrange - Only partial session data
        SharedPreferences.setMockInitialValues({
          'access_token': 'token_only',
          // Missing user_id and user_email
        });

        // Act
        final session = await apiService.loadSession();

        // Assert
        expect(session, isNull);
      });

      test('logout should clear all session data', () async {
        // Arrange - Setup session data
        SharedPreferences.setMockInitialValues({
          'access_token': 'token_to_remove',
          'user_id': 'user123',
          'user_email': 'test@example.com',
        });

        // Act
        await apiService.logout();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('access_token'), isNull);
        expect(prefs.getString('user_id'), isNull);
        expect(prefs.getString('user_email'), isNull);
      });

      test('logout should handle when no session exists', () async {
        // Arrange - No session data
        SharedPreferences.setMockInitialValues({});

        // Act - Should not throw error
        await apiService.logout();

        // Assert
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('access_token'), isNull);
      });
    });
  });
}
