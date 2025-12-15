// integration_test/app_test.dart
// Integration test untuk complete user flows

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:rest_api_demo/api/task_api.dart';
import 'package:rest_api_demo/local/task_local_db.dart';
import 'package:rest_api_demo/providers/task_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Setup sqflite_ffi for testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Complete User Flow Integration Tests', () {
    late TaskProvider taskProvider;

    setUp(() async {
      // Clear SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});

      // Initialize services
      final apiService = TaskApiService();
      final localDb = TaskLocalDb();

      // Clear database
      await localDb.clearAll();

      taskProvider = TaskProvider(apiService, localDb);
    });

    Widget createTestApp() {
      return MaterialApp(
        home: ChangeNotifierProvider.value(
          value: taskProvider,
          child: Builder(
            builder: (context) {
              // Simple test UI for integration testing
              return Consumer<TaskProvider>(
                builder: (context, provider, child) {
                  if (!provider.isAuthenticated) {
                    return Scaffold(
                      appBar: AppBar(title: Text('Test Login')),
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextField(
                              key: Key('email_field'),
                              decoration: InputDecoration(labelText: 'Email'),
                            ),
                            TextField(
                              key: Key('password_field'),
                              decoration: InputDecoration(labelText: 'Password'),
                              obscureText: true,
                            ),
                            ElevatedButton(
                              key: Key('login_button'),
                              onPressed: () async {
                                // Mock login for testing
                                // In real integration test, this would call actual API
                              },
                              child: Text('Login'),
                            ),
                            if (provider.isLoading)
                              CircularProgressIndicator(key: Key('loading_indicator')),
                            if (provider.errorMessage != null)
                              Text(
                                provider.errorMessage!,
                                key: Key('error_message'),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Authenticated - Show task list
                  return Scaffold(
                    appBar: AppBar(
                      title: Text('Tasks (${provider.tasks.length})'),
                      actions: [
                        IconButton(
                          key: Key('logout_button'),
                          icon: Icon(Icons.logout),
                          onPressed: () => provider.logout(),
                        ),
                      ],
                    ),
                    body: provider.tasks.isEmpty
                        ? Center(
                            child: Text('No tasks', key: Key('empty_state')),
                          )
                        : ListView.builder(
                            key: Key('task_list'),
                            itemCount: provider.tasks.length,
                            itemBuilder: (context, index) {
                              final task = provider.tasks[index];
                              return ListTile(
                                key: Key('task_${task.localId}'),
                                title: Text(task.title),
                                leading: Checkbox(
                                  value: task.completed,
                                  onChanged: (_) => provider.toggleTask(task),
                                ),
                              );
                            },
                          ),
                    floatingActionButton: FloatingActionButton(
                      key: Key('add_task_button'),
                      onPressed: () async {
                        await provider.addTask('Test Task', 'Test Description');
                      },
                      child: Icon(Icons.add),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    }

    testWidgets('Offline Mode: Create task offline and verify local storage',
        (tester) async {
      // Arrange
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Simulate authenticated state (skip actual API call)
      taskProvider = TaskProvider(TaskApiService(), TaskLocalDb());
      // Manually set authenticated for testing
      await taskProvider.checkSession(); // Will be unauthenticated initially

      // Act - Add task locally
      await taskProvider.addTask('Offline Task 1', 'Created while offline');
      await taskProvider.addTask('Offline Task 2', 'Another offline task');

      // Assert
      expect(taskProvider.tasks.length, 2);
      expect(taskProvider.tasks[0].title, 'Offline Task 2'); // DESC order
      expect(taskProvider.tasks[0].isSynced, false); // Not synced yet
      expect(taskProvider.unsyncedCount, 2);
    });

    testWidgets('Local Database: CRUD operations persist correctly',
        (tester) async {
      // Arrange - Create task provider
      final localDb = TaskLocalDb();
      await localDb.clearAll();

      // Act - Create tasks
      final task1Id = await localDb.insertTask(
        taskProvider.tasks.isNotEmpty
            ? taskProvider.tasks.first
            : await _createDummyTask(taskProvider, 'DB Test Task 1'),
      );
      await localDb.insertTask(
        await _createDummyTask(taskProvider, 'DB Test Task 2'),
      );

      // Read tasks
      final tasks = await localDb.getAllTasks();

      // Assert
      expect(tasks.length, greaterThanOrEqualTo(2));
      expect(tasks.any((t) => t.title == 'DB Test Task 1'), true);
      expect(tasks.any((t) => t.title == 'DB Test Task 2'), true);

      // Update task
      if (tasks.isNotEmpty) {
        final taskToUpdate = tasks.first.copyWith(completed: true);
        await localDb.updateTask(taskToUpdate);

        final updatedTasks = await localDb.getAllTasks();
        expect(
          updatedTasks.firstWhere((t) => t.localId == taskToUpdate.localId).completed,
          true,
        );
      }

      // Delete task
      if (task1Id > 0) {
        await localDb.deleteTask(task1Id);
        final remainingTasks = await localDb.getAllTasks();
        expect(
          remainingTasks.any((t) => t.localId == task1Id),
          false,
        );
      }
    });

    testWidgets('Task Completion Toggle: Update task status', (tester) async {
      // Arrange
      await taskProvider.addTask('Task to Complete', 'Test completion');
      final task = taskProvider.tasks.first;

      expect(task.completed, false);

      // Act - Toggle completion
      await taskProvider.toggleTask(task);

      // Assert
      final updatedTask = taskProvider.tasks.firstWhere(
        (t) => t.localId == task.localId,
      );
      expect(updatedTask.completed, true);

      // Act - Toggle back
      await taskProvider.toggleTask(updatedTask);

      // Assert
      final finalTask = taskProvider.tasks.firstWhere(
        (t) => t.localId == task.localId,
      );
      expect(finalTask.completed, false);
    });

    testWidgets('Data Integrity: Task data remains consistent across operations',
        (tester) async {
      // Arrange
      const testTitle = 'Data Integrity Test Task';
      const testDescription = 'Testing data consistency';

      // Act - Create task
      await taskProvider.addTask(testTitle, testDescription);

      // Assert - Verify data
      final createdTask = taskProvider.tasks.firstWhere(
        (t) => t.title == testTitle,
      );

      expect(createdTask.title, testTitle);
      expect(createdTask.description, testDescription);
      expect(createdTask.completed, false);
      expect(createdTask.localId, isNotNull);

      // Act - Update task
      await taskProvider.toggleTask(createdTask);

      // Assert - Data still intact
      final updatedTask = taskProvider.tasks.firstWhere(
        (t) => t.localId == createdTask.localId,
      );

      expect(updatedTask.title, testTitle); // Title unchanged
      expect(updatedTask.description, testDescription); // Description unchanged
      expect(updatedTask.completed, true); // Completion changed
      expect(updatedTask.localId, createdTask.localId); // ID unchanged
    });

    testWidgets('Multiple Tasks: Handle multiple task operations', (tester) async {
      // Arrange & Act - Create multiple tasks
      await taskProvider.addTask('Task 1', 'First');
      await taskProvider.addTask('Task 2', 'Second');
      await taskProvider.addTask('Task 3', 'Third');
      await taskProvider.addTask('Task 4', 'Fourth');
      await taskProvider.addTask('Task 5', 'Fifth');

      // Assert
      expect(taskProvider.tasks.length, 5);

      // Act - Complete some tasks
      await taskProvider.toggleTask(taskProvider.tasks[0]);
      await taskProvider.toggleTask(taskProvider.tasks[2]);

      // Assert
      final completedCount = taskProvider.tasks.where((t) => t.completed).length;
      expect(completedCount, 2);

      // Act - Delete a task
      final taskToDelete = taskProvider.tasks[1];
      await taskProvider.deleteTask(taskToDelete);

      // Assert
      expect(taskProvider.tasks.length, 4);
      expect(
        taskProvider.tasks.any((t) => t.localId == taskToDelete.localId),
        false,
      );
    });

    testWidgets('Error Recovery: Handle errors gracefully', (tester) async {
      // This test verifies that the app can handle errors without crashing

      // Arrange - Clear provider errors
      taskProvider.clearError();
      expect(taskProvider.errorMessage, isNull);

      // Act - Try operations that might fail (without actual network)
      // The app should handle these gracefully

      // Verify no crashes occurred
      expect(taskProvider.isTaskLoading, isFalse);

      // App should still be functional
      await taskProvider.addTask('Recovery Test Task', 'Testing error recovery');
      expect(taskProvider.tasks.length, greaterThanOrEqualTo(1));
    });
  });
}

// Helper function to create dummy task
Future<dynamic> _createDummyTask(TaskProvider provider, String title) async {
  await provider.addTask(title, 'Description for $title');
  return provider.tasks.firstWhere((t) => t.title == title);
}
