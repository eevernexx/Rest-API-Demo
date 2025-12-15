// test/services/task_local_db_test.dart
// Unit test untuk TaskLocalDb (SQLite operations)

import 'package:flutter_test/flutter_test.dart';
import 'package:rest_api_demo/local/task_local_db.dart';
import 'package:rest_api_demo/models/task.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Setup sqflite_ffi untuk testing di desktop
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TaskLocalDb Tests', () {
    late TaskLocalDb db;

    setUp(() async {
      // Gunakan in-memory database untuk testing
      db = TaskLocalDb();
    });

    tearDown(() async {
      // Clean up setelah setiap test
      await db.clearAll();
    });

    group('Insert & Read Tests', () {
      test('insertTask should add task to database', () async {
        // Arrange
        final task = Task(
          title: 'Test Task',
          description: 'Test Description',
          userId: 'user1',
          completed: false,
        );

        // Act
        final localId = await db.insertTask(task);

        // Assert
        expect(localId, greaterThan(0)); // Should return auto-increment ID
      });

      test('getAllTasks should return all tasks', () async {
        // Arrange
        final task1 = Task(title: 'Task 1', userId: 'user1');
        final task2 = Task(title: 'Task 2', userId: 'user1');

        await db.insertTask(task1);
        await db.insertTask(task2);

        // Act
        final tasks = await db.getAllTasks();

        // Assert
        expect(tasks.length, 2);
        expect(tasks[0].title, 'Task 2'); // DESC order by created_at
        expect(tasks[1].title, 'Task 1');
      });

      test('getAllTasks should return empty list when no tasks', () async {
        // Act
        final tasks = await db.getAllTasks();

        // Assert
        expect(tasks, isEmpty);
      });
    });

    group('Update Tests', () {
      test('updateTask should modify existing task', () async {
        // Arrange
        final task = Task(
          title: 'Original Title',
          description: 'Original Desc',
          userId: 'user1',
          completed: false,
        );

        final localId = await db.insertTask(task);
        final insertedTask = task.copyWith(localId: localId);

        // Act
        final updatedTask = insertedTask.copyWith(
          title: 'Updated Title',
          completed: true,
        );
        final rowsAffected = await db.updateTask(updatedTask);

        // Assert
        expect(rowsAffected, 1);

        final tasks = await db.getAllTasks();
        expect(tasks.first.title, 'Updated Title');
        expect(tasks.first.completed, true);
      });

      test('updateTask should return 0 when localId is null', () async {
        // Arrange
        final task = Task(title: 'No local ID', userId: 'user1');

        // Act
        final rowsAffected = await db.updateTask(task);

        // Assert
        expect(rowsAffected, 0);
      });
    });

    group('Delete Tests', () {
      test('deleteTask should remove task from database', () async {
        // Arrange
        final task = Task(title: 'Task to delete', userId: 'user1');
        final localId = await db.insertTask(task);

        // Act
        final rowsDeleted = await db.deleteTask(localId);

        // Assert
        expect(rowsDeleted, 1);

        final tasks = await db.getAllTasks();
        expect(tasks, isEmpty);
      });

      test('deleteTask should return 0 for non-existent ID', () async {
        // Act
        final rowsDeleted = await db.deleteTask(9999);

        // Assert
        expect(rowsDeleted, 0);
      });
    });

    group('Unsynced Tasks Tests', () {
      test('getUnsyncedTasks should return only unsynced tasks', () async {
        // Arrange
        final syncedTask = Task(
          title: 'Synced Task',
          userId: 'user1',
          isSynced: true,
        );

        final unsyncedTask = Task(
          title: 'Unsynced Task',
          userId: 'user1',
          isSynced: false,
        );

        await db.insertTask(syncedTask);
        await db.insertTask(unsyncedTask);

        // Act
        final unsynced = await db.getUnsyncedTasks();

        // Assert
        expect(unsynced.length, 1);
        expect(unsynced.first.title, 'Unsynced Task');
        expect(unsynced.first.isSynced, false);
      });
    });

    group('Replace All Tasks Tests', () {
      test('replaceAllTasks should clear and insert new tasks', () async {
        // Arrange - Add some local tasks
        await db.insertTask(Task(title: 'Local Task 1', userId: 'user1'));
        await db.insertTask(Task(title: 'Local Task 2', userId: 'user1'));

        // New tasks from server
        final serverTasks = [
          Task(serverId: 1, title: 'Server Task 1', userId: 'user1'),
          Task(serverId: 2, title: 'Server Task 2', userId: 'user1'),
          Task(serverId: 3, title: 'Server Task 3', userId: 'user1'),
        ];

        // Act
        await db.replaceAllTasks(serverTasks);

        // Assert
        final tasks = await db.getAllTasks();
        expect(tasks.length, 3);
        expect(tasks.every((t) => t.isSynced == true), true);
        expect(tasks.any((t) => t.title == 'Local Task 1'), false);
      });
    });

    group('Clear All Tests', () {
      test('clearAll should remove all tasks', () async {
        // Arrange
        await db.insertTask(Task(title: 'Task 1', userId: 'user1'));
        await db.insertTask(Task(title: 'Task 2', userId: 'user1'));
        await db.insertTask(Task(title: 'Task 3', userId: 'user1'));

        // Act
        await db.clearAll();

        // Assert
        final tasks = await db.getAllTasks();
        expect(tasks, isEmpty);
      });
    });

    group('Data Integrity Tests', () {
      test('should preserve all task fields after insert and read', () async {
        // Arrange
        final originalTask = Task(
          serverId: 123,
          title: 'Complete Task',
          description: 'Full Description',
          completed: true,
          userId: 'user123',
          createdAt: DateTime(2025, 1, 15, 10, 30),
          isSynced: true,
        );

        // Act
        final localId = await db.insertTask(originalTask);
        final tasks = await db.getAllTasks();
        final retrievedTask = tasks.first;

        // Assert
        expect(retrievedTask.localId, localId);
        expect(retrievedTask.serverId, 123);
        expect(retrievedTask.title, 'Complete Task');
        expect(retrievedTask.description, 'Full Description');
        expect(retrievedTask.completed, true);
        expect(retrievedTask.userId, 'user123');
        expect(retrievedTask.isSynced, true);
        expect(retrievedTask.createdAt, isNotNull);
      });

      test('should handle tasks with missing optional fields', () async {
        // Arrange
        final minimalTask = Task(
          title: 'Minimal Task',
          userId: 'user1',
        );

        // Act
        await db.insertTask(minimalTask);
        final tasks = await db.getAllTasks();
        final retrieved = tasks.first;

        // Assert
        expect(retrieved.title, 'Minimal Task');
        expect(retrieved.description, '');
        expect(retrieved.completed, false);
        expect(retrieved.isSynced, false);
        expect(retrieved.serverId, isNull);
      });
    });
  });
}
