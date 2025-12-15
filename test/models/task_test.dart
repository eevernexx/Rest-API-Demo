// test/models/task_test.dart
// Unit test untuk Task model

import 'package:flutter_test/flutter_test.dart';
import 'package:rest_api_demo/models/task.dart';

void main() {
  group('Task Model Tests', () {

    // ===== JSON SERIALIZATION & DESERIALIZATION =====

    test('fromJson should create Task from JSON', () {
      // Data JSON dari API
      final json = {
        'id': 123,
        'title': 'Belajar Flutter',
        'description': 'Belajar testing',
        'completed': true,
        'user_id': 'user123',
        'created_at': '2025-01-15T10:30:00.000Z',
      };

      // Convert JSON jadi Task object
      final task = Task.fromJson(json);

      // Check apakah datanya benar
      expect(task.serverId, 123);
      expect(task.title, 'Belajar Flutter');
      expect(task.completed, true);
      expect(task.isSynced, true); // Data dari server = synced
    });

    test('toJson should create JSON from Task', () {
      // Buat Task object
      final task = Task(
        serverId: 456,
        title: 'Mengerjakan tugas',
        description: 'Testing project',
        completed: false,
        userId: 'user456',
      );

      // Convert ke JSON
      final json = task.toJson();

      // Check apakah JSON nya benar
      expect(json['id'], 456);
      expect(json['title'], 'Mengerjakan tugas');
      expect(json['completed'], false);
    });

    // ===== NULL/MISSING FIELD HANDLING =====

    test('fromJson should handle missing description field', () {
      final json = {
        'id': 1,
        'title': 'Task tanpa description',
        'completed': false,
        'user_id': 'user1',
      };

      final task = Task.fromJson(json);

      expect(task.description, ''); // Default empty string
    });

    test('fromJson should handle missing created_at field', () {
      final json = {
        'id': 1,
        'title': 'Task tanpa tanggal',
        'completed': false,
        'user_id': 'user1',
      };

      final task = Task.fromJson(json);

      expect(task.createdAt, isNull);
    });

    test('fromJson should handle invalid date format', () {
      final json = {
        'id': 1,
        'title': 'Test',
        'completed': false,
        'user_id': 'user1',
        'created_at': 'tanggal-salah-format',
      };

      final task = Task.fromJson(json);

      expect(task.createdAt, isNull); // Invalid date = null
    });

    // ===== SQLITE CONVERSION =====

    test('toMap should convert Task to SQLite Map', () {
      final task = Task(
        localId: 1,
        serverId: 100,
        title: 'Test Task',
        description: 'Test Desc',
        completed: true,
        userId: 'user1',
        isSynced: true,
      );

      final map = task.toMap();

      expect(map['local_id'], 1);
      expect(map['server_id'], 100);
      expect(map['completed'], 1); // boolean -> int
      expect(map['is_synced'], 1); // boolean -> int
    });

    test('fromMap should convert SQLite Map to Task', () {
      final map = {
        'local_id': 5,
        'server_id': 50,
        'title': 'From SQLite',
        'description': 'Testing',
        'completed': 1,
        'user_id': 'user5',
        'is_synced': 0,
      };

      final task = Task.fromMap(map);

      expect(task.localId, 5);
      expect(task.serverId, 50);
      expect(task.completed, true); // int -> boolean
      expect(task.isSynced, false); // int -> boolean
    });

    // ===== COPYWITH METHOD =====

    test('copyWith should update only specified fields', () {
      final original = Task(
        localId: 1,
        title: 'Original',
        description: 'Desc',
        completed: false,
        userId: 'user1',
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        completed: true,
      );

      expect(updated.title, 'Updated Title');
      expect(updated.completed, true);
      expect(updated.description, 'Desc'); // Unchanged
      expect(updated.localId, 1); // Unchanged
    });

    test('copyWith should allow syncing task from local to server', () {
      // Simulate: task baru di local
      final localTask = Task(
        localId: 10,
        title: 'New Local Task',
        userId: 'user1',
        isSynced: false,
      );

      // Setelah sukses upload ke server, update serverId
      final syncedTask = localTask.copyWith(
        serverId: 999,
        isSynced: true,
      );

      expect(syncedTask.serverId, 999);
      expect(syncedTask.isSynced, true);
      expect(syncedTask.localId, 10); // Local ID tetap ada
    });

    // ===== EDGE CASES =====

    test('should handle empty string title', () {
      final task = Task(
        title: '',
        userId: 'user1',
      );

      expect(task.title, '');
    });

    test('should handle special characters', () {
      final task = Task(
        title: 'Task "test" & <special> chars',
        description: 'Line 1\nLine 2',
        userId: 'user@test.com',
      );

      final json = task.toJson();
      expect(json['title'], contains('test'));
      expect(json['description'], contains('\n'));
    });

    // ===== DATA CONVERSION TEST =====

    test('should convert correctly from server JSON to SQLite and back', () {
      // Simulate: Data dari server -> SQLite -> Server
      final serverJson = {
        'id': 777,
        'title': 'Server Task',
        'description': 'From API',
        'completed': true,
        'user_id': 'user777',
        'created_at': '2025-01-15T10:30:00.000Z',
      };

      // Step 1: Parse dari server
      final taskFromServer = Task.fromJson(serverJson);

      // Step 2: Simpan ke SQLite
      final sqliteMap = taskFromServer.toMap();

      // Step 3: Baca dari SQLite
      final taskFromSQLite = Task.fromMap(sqliteMap);

      // Step 4: Kirim kembali ke server
      final backToServerJson = taskFromSQLite.toJson();

      // Verify data tetap konsisten
      expect(taskFromSQLite.serverId, 777);
      expect(taskFromSQLite.title, 'Server Task');
      expect(backToServerJson['title'], 'Server Task');
    });

  });
}
