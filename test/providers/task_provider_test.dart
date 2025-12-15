// test/providers/task_provider_test.dart
// Unit test untuk TaskProvider (State Management)

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rest_api_demo/api/task_api.dart';
import 'package:rest_api_demo/local/task_local_db.dart';
import 'package:rest_api_demo/models/task.dart';
import 'package:rest_api_demo/providers/task_provider.dart';

// Mock classes
class MockTaskApiService extends Mock implements TaskApiService {}
class MockTaskLocalDb extends Mock implements TaskLocalDb {}

void main() {
  group('TaskProvider Tests', () {
    late TaskProvider provider;
    late MockTaskApiService mockApi;
    late MockTaskLocalDb mockDb;

    setUp(() {
      mockApi = MockTaskApiService();
      mockDb = MockTaskLocalDb();
      provider = TaskProvider(mockApi, mockDb);

      // Register fallback values
      registerFallbackValue(Task(title: 'Fallback', userId: 'user1'));
    });

    group('Authentication State Tests', () {
      test('initial state should be unauthenticated and loading', () {
        // Assert
        expect(provider.isAuthenticated, false);
        expect(provider.isAuthLoading, true);
        expect(provider.userId, isNull);
        expect(provider.email, isNull);
      });

      test('checkSession should set authenticated when session exists', () async {
        // Arrange
        when(() => mockApi.loadSession()).thenAnswer(
          (_) async => {
            'token': 'test_token',
            'userId': 'user123',
            'email': 'test@example.com',
          },
        );
        when(() => mockDb.getAllTasks()).thenAnswer((_) async => []);
        when(() => mockApi.getTasks()).thenAnswer((_) async => []);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});

        // Act
        await provider.checkSession();

        // Assert
        expect(provider.isAuthenticated, true);
        expect(provider.userId, 'user123');
        expect(provider.email, 'test@example.com');
        expect(provider.isAuthLoading, false);
      });

      test('checkSession should remain unauthenticated when no session', () async {
        // Arrange
        when(() => mockApi.loadSession()).thenAnswer((_) async => null);

        // Act
        await provider.checkSession();

        // Assert
        expect(provider.isAuthenticated, false);
        expect(provider.isAuthLoading, false);
      });

      test('login should set authenticated state on success', () async {
        // Arrange
        when(() => mockApi.login(any(), any())).thenAnswer(
          (_) async => {
            'access_token': 'new_token',
            'user': {
              'id': 'user456',
              'email': 'login@example.com',
            },
          },
        );
        when(() => mockDb.getAllTasks()).thenAnswer((_) async => []);
        when(() => mockApi.getTasks()).thenAnswer((_) async => []);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});

        // Act
        final success = await provider.login('login@example.com', 'password123');

        // Assert
        expect(success, true);
        expect(provider.isAuthenticated, true);
        expect(provider.email, 'login@example.com');
        expect(provider.userId, 'user456');
      });

      test('login should set error message on failure', () async {
        // Arrange
        when(() => mockApi.login(any(), any())).thenAnswer((_) async => null);

        // Act
        final success = await provider.login('wrong@example.com', 'wrongpass');

        // Assert
        expect(success, false);
        expect(provider.isAuthenticated, false);
        expect(provider.errorMessage, isNotNull);
      });

      test('register should set authenticated state on success', () async {
        // Arrange
        when(() => mockApi.register(any(), any())).thenAnswer(
          (_) async => {
            'access_token': 'reg_token',
            'user': {
              'id': 'newuser789',
              'email': 'new@example.com',
            },
          },
        );
        when(() => mockDb.getAllTasks()).thenAnswer((_) async => []);
        when(() => mockApi.getTasks()).thenAnswer((_) async => []);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});

        // Act
        final success = await provider.register('new@example.com', 'newpass123');

        // Assert
        expect(success, true);
        expect(provider.isAuthenticated, true);
        expect(provider.email, 'new@example.com');
      });

      test('logout should clear authentication state', () async {
        // Arrange - Set authenticated first
        when(() => mockApi.login(any(), any())).thenAnswer(
          (_) async => {
            'access_token': 'token',
            'user': {'id': 'user1', 'email': 'test@example.com'},
          },
        );
        when(() => mockDb.getAllTasks()).thenAnswer((_) async => []);
        when(() => mockApi.getTasks()).thenAnswer((_) async => []);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});
        await provider.login('test@example.com', 'pass');

        when(() => mockApi.logout()).thenAnswer((_) async => {});
        when(() => mockDb.clearAll()).thenAnswer((_) async => {});

        // Act
        await provider.logout();

        // Assert
        expect(provider.isAuthenticated, false);
        expect(provider.email, isNull);
        expect(provider.userId, isNull);
        expect(provider.tasks, isEmpty);
      });
    });

    group('Task Loading Tests', () {
      test('loadTasksOfflineFirst should load from local DB first', () async {
        // Arrange
        final localTasks = [
          Task(localId: 1, title: 'Local Task 1', userId: 'user1'),
          Task(localId: 2, title: 'Local Task 2', userId: 'user1'),
        ];

        when(() => mockDb.getAllTasks()).thenAnswer((_) async => localTasks);
        when(() => mockApi.getTasks()).thenAnswer((_) async => []);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});

        // Simulate authenticated user
        provider = TaskProvider(mockApi, mockDb);
        when(() => mockApi.loadSession()).thenAnswer(
          (_) async => {
            'token': 'token',
            'userId': 'user1',
            'email': 'test@example.com',
          },
        );
        await provider.checkSession();

        // Reset getAllTasks mock for loadTasksOfflineFirst
        when(() => mockDb.getAllTasks()).thenAnswer((_) async => localTasks);

        // Act
        await provider.loadTasksOfflineFirst();

        // Assert
        expect(provider.tasks.length, 2);
        expect(provider.tasks[0].title, 'Local Task 1');
        verify(() => mockDb.getAllTasks()).called(greaterThan(0));
      });

      test('loadTasksOfflineFirst should sync with server', () async {
        // Arrange
        final serverTasks = [
          Task(serverId: 1, title: 'Server Task', userId: 'user1'),
        ];

        when(() => mockDb.getAllTasks()).thenAnswer((_) async => []);
        when(() => mockApi.getTasks()).thenAnswer((_) async => serverTasks);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});

        // Simulate authenticated user
        provider = TaskProvider(mockApi, mockDb);
        when(() => mockApi.loadSession()).thenAnswer(
          (_) async => {
            'token': 'token',
            'userId': 'user1',
            'email': 'test@example.com',
          },
        );
        await provider.checkSession();

        // Act - Already called during checkSession, verify behavior
        verify(() => mockApi.getTasks()).called(greaterThan(0));
        verify(() => mockDb.replaceAllTasks(any())).called(greaterThan(0));
      });

      test('loadTasksOfflineFirst should handle network error gracefully', () async {
        // Arrange
        final localTasks = [
          Task(localId: 1, title: 'Local Task', userId: 'user1'),
        ];

        when(() => mockDb.getAllTasks()).thenAnswer((_) async => localTasks);
        when(() => mockApi.getTasks()).thenThrow(Exception('Network error'));

        // Simulate authenticated user
        provider = TaskProvider(mockApi, mockDb);
        when(() => mockApi.loadSession()).thenAnswer(
          (_) async => {
            'token': 'token',
            'userId': 'user1',
            'email': 'test@example.com',
          },
        );

        // Act
        await provider.checkSession();

        // Assert - Should still have local tasks
        expect(provider.tasks.length, 1);
        expect(provider.errorMessage, isNotNull);
      });
    });

    group('Task CRUD Operations Tests', () {
      setUp(() async {
        // Setup authenticated provider for CRUD tests
        when(() => mockApi.loadSession()).thenAnswer(
          (_) async => {
            'token': 'token',
            'userId': 'user1',
            'email': 'test@example.com',
          },
        );
        when(() => mockDb.getAllTasks()).thenAnswer((_) async => []);
        when(() => mockApi.getTasks()).thenAnswer((_) async => []);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});
        await provider.checkSession();
      });

      test('addTask should add task locally and sync to server', () async {
        // Arrange
        when(() => mockDb.insertTask(any())).thenAnswer((_) async => 1);
        when(() => mockApi.createTask(any())).thenAnswer(
          (_) async => Task(
            serverId: 100,
            title: 'New Task',
            userId: 'user1',
            isSynced: true,
          ),
        );
        when(() => mockDb.updateTask(any())).thenAnswer((_) async => 1);

        // Act
        final success = await provider.addTask('New Task', 'Description');

        // Assert
        expect(success, true);
        expect(provider.tasks.length, 1);
        verify(() => mockDb.insertTask(any())).called(1);
        verify(() => mockApi.createTask(any())).called(1);
      });

      test('addTask should work in offline mode', () async {
        // Arrange
        when(() => mockDb.insertTask(any())).thenAnswer((_) async => 1);
        when(() => mockApi.createTask(any())).thenThrow(Exception('Offline'));

        // Act
        final success = await provider.addTask('Offline Task', 'Desc');

        // Assert
        expect(success, true); // Should still succeed locally
        expect(provider.tasks.length, 1);
        expect(provider.tasks.first.isSynced, false);
      });

      test('toggleTask should update task completion status', () async {
        // Arrange - Add task first
        when(() => mockDb.insertTask(any())).thenAnswer((_) async => 1);
        when(() => mockApi.createTask(any())).thenAnswer(
          (_) async => Task(
            serverId: 100,
            localId: 1,
            title: 'Task',
            userId: 'user1',
            completed: false,
          ),
        );
        when(() => mockDb.updateTask(any())).thenAnswer((_) async => 1);

        await provider.addTask('Task', 'Desc');
        final task = provider.tasks.first;

        when(() => mockApi.updateTask(any())).thenAnswer((_) async => true);

        // Act
        final success = await provider.toggleTask(task);

        // Assert
        expect(success, true);
        expect(provider.tasks.first.completed, true);
      });

      test('deleteTask should remove task from list', () async {
        // Arrange - Add task first
        when(() => mockDb.insertTask(any())).thenAnswer((_) async => 1);
        when(() => mockApi.createTask(any())).thenAnswer(
          (_) async => Task(
            serverId: 100,
            localId: 1,
            title: 'Task to delete',
            userId: 'user1',
          ),
        );
        when(() => mockDb.updateTask(any())).thenAnswer((_) async => 1);

        await provider.addTask('Task to delete', 'Desc');
        final task = provider.tasks.first;

        when(() => mockDb.deleteTask(any())).thenAnswer((_) async => 1);
        when(() => mockApi.deleteTask(any())).thenAnswer((_) async => true);

        // Act
        final success = await provider.deleteTask(task);

        // Assert
        expect(success, true);
        expect(provider.tasks, isEmpty);
      });
    });

    group('Error Handling Tests', () {
      test('clearError should clear error message', () async {
        // Arrange - Trigger an error
        when(() => mockApi.login(any(), any())).thenAnswer((_) async => null);
        await provider.login('wrong@test.com', 'wrong');

        expect(provider.errorMessage, isNotNull);

        // Act
        provider.clearError();

        // Assert
        expect(provider.errorMessage, isNull);
      });
    });

    group('Loading State Tests', () {
      test('isAuthLoading should be true during login', () async {
        // Arrange
        when(() => mockApi.login(any(), any())).thenAnswer(
          (_) async {
            // Check loading state during async operation
            expect(provider.isAuthLoading, true);
            return {
              'access_token': 'token',
              'user': {'id': 'user1', 'email': 'test@example.com'},
            };
          },
        );
        when(() => mockDb.getAllTasks()).thenAnswer((_) async => []);
        when(() => mockApi.getTasks()).thenAnswer((_) async => []);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});

        // Act
        await provider.login('test@example.com', 'pass');

        // Assert - Should be false after completion
        expect(provider.isAuthLoading, false);
      });
    });

    group('Unsynced Count Tests', () {
      test('unsyncedCount should return correct count', () async {
        // Arrange - Setup authenticated user
        when(() => mockApi.loadSession()).thenAnswer(
          (_) async => {
            'token': 'token',
            'userId': 'user1',
            'email': 'test@example.com',
          },
        );

        final mixedTasks = [
          Task(localId: 1, title: 'Synced', userId: 'user1', isSynced: true),
          Task(localId: 2, title: 'Unsynced 1', userId: 'user1', isSynced: false),
          Task(localId: 3, title: 'Unsynced 2', userId: 'user1', isSynced: false),
        ];

        when(() => mockDb.getAllTasks()).thenAnswer((_) async => mixedTasks);
        when(() => mockApi.getTasks()).thenAnswer((_) async => []);
        when(() => mockDb.replaceAllTasks(any())).thenAnswer((_) async => {});

        await provider.checkSession();

        // Act & Assert
        expect(provider.unsyncedCount, 2);
      });
    });
  });
}
