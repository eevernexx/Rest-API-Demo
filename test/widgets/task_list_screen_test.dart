// test/widgets/task_list_screen_test.dart
// Widget test untuk Task List Screen

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:rest_api_demo/models/task.dart';
import 'package:rest_api_demo/providers/task_provider.dart';
import 'package:rest_api_demo/screens/task_list_screen.dart';

// Mock TaskProvider
class MockTaskProvider extends Mock implements TaskProvider {}

void main() {
  // Register fallback values
  setUpAll(() {
    registerFallbackValue(Task(title: 'Fallback', userId: 'user1'));
  });

  group('TaskListScreen Widget Tests', () {
    late MockTaskProvider mockProvider;

    setUp(() {
      mockProvider = MockTaskProvider();

      // Setup default mocks
      when(() => mockProvider.tasks).thenReturn([]);
      when(() => mockProvider.isTaskLoading).thenReturn(false);
      when(() => mockProvider.isSyncing).thenReturn(false);
      when(() => mockProvider.unsyncedCount).thenReturn(0);
      when(() => mockProvider.errorMessage).thenReturn(null);
      when(() => mockProvider.loadTasksOfflineFirst()).thenAnswer((_) async => {});
      when(() => mockProvider.logout()).thenAnswer((_) async => {});
    });

    Widget createTaskListScreen() {
      return MaterialApp(
        home: ChangeNotifierProvider<TaskProvider>.value(
          value: mockProvider,
          child: TaskListScreen(),
        ),
      );
    }

    group('UI Elements Tests', () {
      testWidgets('should display app bar with title', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('My Tasks (0)'), findsOneWidget);
      });

      testWidgets('should display task count in title', (tester) async {
        // Arrange
        when(() => mockProvider.tasks).thenReturn([
          Task(localId: 1, title: 'Task 1', userId: 'user1'),
          Task(localId: 2, title: 'Task 2', userId: 'user1'),
        ]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('My Tasks (2)'), findsOneWidget);
      });

      testWidgets('should display FAB for adding tasks', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.add), findsOneWidget);
      });

      testWidgets('should display refresh button', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.refresh), findsOneWidget);
      });

      testWidgets('should display logout menu', (tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert - At least one PopupMenuButton exists
        expect(find.byIcon(Icons.more_vert), findsAtLeastNWidgets(1));
      });
    });

    group('Empty State Tests', () {
      testWidgets('should show empty state when no tasks', (tester) async {
        // Arrange
        when(() => mockProvider.tasks).thenReturn([]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Belum ada tasks'), findsOneWidget);
        expect(find.text('Tap + untuk menambah task pertama'), findsOneWidget);
        expect(find.byIcon(Icons.task_alt), findsOneWidget);
      });

      testWidgets('should not show empty state when tasks exist', (tester) async {
        // Arrange
        when(() => mockProvider.tasks).thenReturn([
          Task(localId: 1, title: 'Task 1', userId: 'user1'),
        ]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Belum ada tasks'), findsNothing);
      });
    });

    group('Loading State Tests', () {
      testWidgets('should show loading indicator when loading and no tasks', (tester) async {
        // Arrange
        when(() => mockProvider.isTaskLoading).thenReturn(true);
        when(() => mockProvider.tasks).thenReturn([]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pump(); // Use pump instead of pumpAndSettle

        // Assert
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('should show sync status in subtitle', (tester) async {
        // Arrange
        when(() => mockProvider.isSyncing).thenReturn(true);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Sinkronisasi dengan server...'), findsOneWidget);
      });

      testWidgets('should show unsynced count when tasks not synced', (tester) async {
        // Arrange
        when(() => mockProvider.unsyncedCount).thenReturn(3);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('3 task belum tersinkron'), findsOneWidget);
      });

      testWidgets('should show all synced message when synced', (tester) async {
        // Arrange
        when(() => mockProvider.unsyncedCount).thenReturn(0);
        when(() => mockProvider.isSyncing).thenReturn(false);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Semua data tersinkron'), findsOneWidget);
      });
    });

    group('Error State Tests', () {
      testWidgets('should show error message when error occurs', (tester) async {
        // Arrange
        when(() => mockProvider.errorMessage).thenReturn('Network error');
        when(() => mockProvider.tasks).thenReturn([]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Network error'), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Coba Lagi'), findsOneWidget);
      });

      testWidgets('should call loadTasksOfflineFirst on retry', (tester) async {
        // Arrange
        when(() => mockProvider.errorMessage).thenReturn('Error');
        when(() => mockProvider.tasks).thenReturn([]);

        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.text('Coba Lagi'));
        await tester.pump();

        // Assert
        verify(() => mockProvider.loadTasksOfflineFirst()).called(greaterThan(0));
      });
    });

    group('Task List Display Tests', () {
      testWidgets('should display tasks in list', (tester) async {
        // Arrange
        when(() => mockProvider.tasks).thenReturn([
          Task(localId: 1, title: 'Task 1', description: 'Desc 1', userId: 'user1'),
          Task(localId: 2, title: 'Task 2', description: 'Desc 2', userId: 'user1'),
        ]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Task 1'), findsOneWidget);
        expect(find.text('Task 2'), findsOneWidget);
        expect(find.byType(TaskCard), findsNWidgets(2));
      });

      testWidgets('should display task with checkbox', (tester) async {
        // Arrange
        when(() => mockProvider.tasks).thenReturn([
          Task(localId: 1, title: 'Test Task', userId: 'user1', completed: false),
        ]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('should show completed task with strikethrough', (tester) async {
        // Arrange
        when(() => mockProvider.tasks).thenReturn([
          Task(localId: 1, title: 'Completed Task', userId: 'user1', completed: true),
        ]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });

      testWidgets('should show offline indicator for unsynced tasks', (tester) async {
        // Arrange
        when(() => mockProvider.tasks).thenReturn([
          Task(localId: 1, title: 'Unsynced Task', userId: 'user1', isSynced: false),
        ]);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Belum terkirim ke server'), findsOneWidget);
        expect(find.byIcon(Icons.offline_bolt), findsOneWidget);
      });
    });

    group('Sync Status Icons Tests', () {
      testWidgets('should show sync icon when syncing', (tester) async {
        // Arrange
        when(() => mockProvider.isSyncing).thenReturn(true);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.sync), findsOneWidget);
      });

      testWidgets('should show cloud_off icon when has unsynced tasks', (tester) async {
        // Arrange
        when(() => mockProvider.isSyncing).thenReturn(false);
        when(() => mockProvider.unsyncedCount).thenReturn(2);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      });

      testWidgets('should show cloud_done icon when all synced', (tester) async {
        // Arrange
        when(() => mockProvider.isSyncing).thenReturn(false);
        when(() => mockProvider.unsyncedCount).thenReturn(0);

        // Act
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.cloud_done), findsOneWidget);
      });
    });

    group('Task Actions Tests', () {
      testWidgets('should call toggleTask on checkbox tap', (tester) async {
        // Arrange
        final task = Task(localId: 1, title: 'Test Task', userId: 'user1');
        when(() => mockProvider.tasks).thenReturn([task]);
        when(() => mockProvider.toggleTask(any())).thenAnswer((_) async => true);

        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        // Assert
        verify(() => mockProvider.toggleTask(any())).called(1);
      });

      testWidgets('should show delete confirmation dialog', (tester) async {
        // Arrange
        final task = Task(localId: 1, title: 'Test Task', userId: 'user1');
        when(() => mockProvider.tasks).thenReturn([task]);

        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Act - Find PopupMenuButton within TaskCard
        final popupMenu = find.descendant(
          of: find.byType(TaskCard),
          matching: find.byIcon(Icons.more_vert),
        );

        await tester.tap(popupMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Hapus Task'), findsOneWidget);
        expect(find.text('Yakin ingin menghapus task ini?'), findsOneWidget);
        expect(find.text('Batal'), findsOneWidget);
      });

      testWidgets('should call deleteTask on confirmation', (tester) async {
        // Arrange
        final task = Task(localId: 1, title: 'Test Task', userId: 'user1');
        when(() => mockProvider.tasks).thenReturn([task]);
        when(() => mockProvider.deleteTask(any())).thenAnswer((_) async => true);

        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Act - Find PopupMenuButton within TaskCard
        final popupMenu = find.descendant(
          of: find.byType(TaskCard),
          matching: find.byIcon(Icons.more_vert),
        );

        await tester.tap(popupMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hapus').last);
        await tester.pumpAndSettle();

        // Assert
        verify(() => mockProvider.deleteTask(any())).called(1);
      });
    });

    group('Refresh Tests', () {
      testWidgets('should call loadTasksOfflineFirst on refresh button tap', (tester) async {
        // Arrange
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pump();

        // Assert
        verify(() => mockProvider.loadTasksOfflineFirst()).called(greaterThan(0));
      });

      testWidgets('should support pull-to-refresh', (tester) async {
        // Arrange
        when(() => mockProvider.tasks).thenReturn([
          Task(localId: 1, title: 'Task 1', userId: 'user1'),
        ]);

        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Assert - RefreshIndicator exists
        expect(find.byType(RefreshIndicator), findsOneWidget);
      });
    });

    group('Logout Tests', () {
      testWidgets('should call logout when logout menu tapped', (tester) async {
        // Arrange
        await tester.pumpWidget(createTaskListScreen());
        await tester.pumpAndSettle();

        // Act - Find logout menu in AppBar
        final appBarMenu = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.more_vert),
        );

        await tester.tap(appBarMenu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Logout'));
        await tester.pumpAndSettle();

        // Assert
        verify(() => mockProvider.logout()).called(1);
      });
    });
  });
}
