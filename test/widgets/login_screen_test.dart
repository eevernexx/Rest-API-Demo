// test/widgets/login_screen_test.dart
// Widget test untuk Login Screen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rest_api_demo/providers/task_provider.dart';
import 'package:rest_api_demo/screens/login_screen.dart';

// Mock TaskProvider
class MockTaskProvider extends Mock implements TaskProvider {}

void main() {
  group('LoginScreen Widget Tests', () {
    late MockTaskProvider mockProvider;

    setUp(() {
      mockProvider = MockTaskProvider();

      // Setup default mocks
      when(() => mockProvider.isLoading).thenReturn(false);
      when(() => mockProvider.isAuthLoading).thenReturn(false);
      when(() => mockProvider.errorMessage).thenReturn(null);
    });

    Widget createLoginScreen() {
      return MaterialApp(
        home: ChangeNotifierProvider<TaskProvider>.value(
          value: mockProvider,
          child: LoginScreen(),
        ),
      );
    }

    group('UI Elements Tests', () {
      testWidgets('should display email and password fields', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginScreen());

        // Assert
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      });

      testWidgets('should display Login button by default', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginScreen());

        // Assert
        expect(find.text('Login'), findsNWidgets(2)); // Title + Button
        expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
      });

      testWidgets('should display toggle button for register mode', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginScreen());

        // Assert
        expect(find.text('Belum punya akun? Register'), findsOneWidget);
      });

      testWidgets('should toggle between login and register mode', (tester) async {
        // Arrange
        await tester.pumpWidget(createLoginScreen());

        // Act - Tap toggle button
        await tester.tap(find.text('Belum punya akun? Register'));
        await tester.pump();

        // Assert
        expect(find.text('Register'), findsNWidgets(2)); // Title + Button
        expect(find.text('Sudah punya akun? Login'), findsOneWidget);
      });

      testWidgets('should toggle password visibility', (tester) async {
        // Arrange
        await tester.pumpWidget(createLoginScreen());

        final visibilityButton = find.byIcon(Icons.visibility);

        // Initially should show visibility icon (password is obscured)
        expect(visibilityButton, findsOneWidget);

        // Act - Tap visibility toggle
        await tester.tap(visibilityButton);
        await tester.pump();

        // Assert - Should show visibility_off icon now (password is visible)
        expect(find.byIcon(Icons.visibility_off), findsOneWidget);
        expect(find.byIcon(Icons.visibility), findsNothing);
      });
    });

    group('Form Validation Tests', () {
      testWidgets('should show error when email is empty', (tester) async {
        // Arrange
        when(() => mockProvider.login(any(), any())).thenAnswer((_) async => true);

        await tester.pumpWidget(createLoginScreen());

        // Act - Submit without filling email
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump();

        // Assert
        expect(find.text('Email harus diisi'), findsOneWidget);
      });

      testWidgets('should show error when email is invalid', (tester) async {
        // Arrange
        await tester.pumpWidget(createLoginScreen());

        // Act - Enter invalid email
        await tester.enterText(find.byType(TextFormField).first, 'invalidemail');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump();

        // Assert
        expect(find.text('Email tidak valid'), findsOneWidget);
      });

      testWidgets('should show error when password is empty', (tester) async {
        // Arrange
        await tester.pumpWidget(createLoginScreen());

        // Act - Fill email but not password
        await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump();

        // Assert
        expect(find.text('Password harus diisi'), findsOneWidget);
      });

      testWidgets('should show error when password is too short', (tester) async {
        // Arrange
        await tester.pumpWidget(createLoginScreen());

        // Act - Enter short password
        await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
        await tester.enterText(find.byType(TextFormField).at(1), '12345');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump();

        // Assert
        expect(find.text('Password minimal 6 karakter'), findsOneWidget);
      });

      testWidgets('should not show error with valid inputs', (tester) async {
        // Arrange
        when(() => mockProvider.login(any(), any())).thenAnswer((_) async => true);

        await tester.pumpWidget(createLoginScreen());

        // Act - Enter valid credentials
        await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump();

        // Assert - No validation errors
        expect(find.text('Email harus diisi'), findsNothing);
        expect(find.text('Email tidak valid'), findsNothing);
        expect(find.text('Password harus diisi'), findsNothing);
        expect(find.text('Password minimal 6 karakter'), findsNothing);
      });
    });

    group('Login Functionality Tests', () {
      testWidgets('should call login with correct credentials', (tester) async {
        // Arrange
        when(() => mockProvider.login(any(), any())).thenAnswer((_) async => true);

        await tester.pumpWidget(createLoginScreen());

        // Act - Enter credentials and submit
        await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump();

        // Assert
        verify(() => mockProvider.login('test@example.com', 'password123')).called(1);
      });

      testWidgets('should call register in register mode', (tester) async {
        // Arrange
        when(() => mockProvider.register(any(), any())).thenAnswer((_) async => true);

        await tester.pumpWidget(createLoginScreen());

        // Switch to register mode
        await tester.tap(find.text('Belum punya akun? Register'));
        await tester.pump();

        // Act - Enter credentials and submit
        await tester.enterText(find.byType(TextFormField).first, 'new@example.com');
        await tester.enterText(find.byType(TextFormField).at(1), 'newpass123');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Register'));
        await tester.pump();

        // Assert
        verify(() => mockProvider.register('new@example.com', 'newpass123')).called(1);
      });
    });

    group('Loading State Tests', () {
      testWidgets('should show loading indicator when isLoading is true', (tester) async {
        // Arrange
        when(() => mockProvider.isLoading).thenReturn(true);

        // Act
        await tester.pumpWidget(createLoginScreen());

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Login'), findsNothing);
      });

      testWidgets('should hide loading indicator when not loading', (tester) async {
        // Arrange
        when(() => mockProvider.isLoading).thenReturn(false);

        // Act
        await tester.pumpWidget(createLoginScreen());

        // Assert
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
      });
    });

    group('Error Display Tests', () {
      testWidgets('should show error snackbar on login failure', (tester) async {
        // Arrange
        when(() => mockProvider.login(any(), any())).thenAnswer((_) async => false);
        when(() => mockProvider.errorMessage).thenReturn('Login gagal');

        await tester.pumpWidget(createLoginScreen());

        // Act - Submit login
        await tester.enterText(find.byType(TextFormField).first, 'wrong@example.com');
        await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump(); // Trigger login
        await tester.pump(); // Rebuild after login completes

        // Assert
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Login gagal'), findsOneWidget);
      });

      testWidgets('should show default error message when errorMessage is null', (tester) async {
        // Arrange
        when(() => mockProvider.login(any(), any())).thenAnswer((_) async => false);
        when(() => mockProvider.errorMessage).thenReturn(null);

        await tester.pumpWidget(createLoginScreen());

        // Act
        await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
        await tester.pump();
        await tester.pump();

        // Assert
        expect(find.text('Terjadi kesalahan'), findsOneWidget);
      });
    });

    group('Accessibility Tests', () {
      testWidgets('should have email and password input fields', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(createLoginScreen());

        // Assert - Verify email and password fields exist
        expect(find.byType(TextFormField), findsNWidgets(2));
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Password'), findsOneWidget);
      });
    });
  });
}
