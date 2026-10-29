/// Tests for the Tasks flow: the requests the service sends, the view model's
/// filters and actions, and the default due time for the next follow-up.
///
/// The fake server records each request, so a test can check the exact path,
/// query and JSON body that the backend would receive.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/services/tasks_service.dart';
import 'package:ogera_crm_mobile/view_models/tasks_view_model.dart';
import 'package:ogera_crm_mobile/views/tasks/task_detail_sheet.dart';
import 'package:ogera_crm_mobile/views/tasks/task_followup_sheets.dart';
import 'package:provider/provider.dart';

/// Records requests and answers by "METHOD /path". Unknown routes return 404.
class _FakeServer {
  final calls = <http.Request>[];
  final routes = <String, http.Response Function(http.Request)>{};

  late final ApiClient api = ApiClient(
    baseUrl: 'https://crm.test',
    client: MockClient((request) async {
      calls.add(request);
      final route = routes['${request.method} ${request.url.path}'];
      return route == null
          ? _json({'detail': 'No route'}, 404)
          : route(request);
    }),
  )..currentUserId = 5;

  /// The last request sent to [method] [path], or null.
  http.Request? last(String method, String path) {
    final matches = calls.where(
      (c) => c.method == method && c.url.path == path,
    );
    return matches.isEmpty ? null : matches.last;
  }

  Map<String, dynamic> bodyOf(String method, String path) =>
      jsonDecode(last(method, path)!.body) as Map<String, dynamic>;
}

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status);

/// One task as GET /tasks returns it.
Map<String, dynamic> _taskJson({int id = 1, int? contactId = 9}) => {
  'id': id,
  'title': 'Call back',
  'type': 'phone_call',
  'notes': null,
  'status': 'pending',
  'priority': 'high',
  'scheduled_date': '2026-10-24',
  'scheduled_time': '10:30:00',
  'task_state': 'due_today',
  'overdue_days': 0,
  'contact_id': contactId,
  'contact_name': 'Asha',
  'contact_phone': '9999999999',
  'contact_type': 'consumer',
  'assigned_to': 5,
  'created_at': '2026-10-20T09:00:00',
};

Map<String, dynamic> _listJson(List<Map<String, dynamic>> items) => {
  'items': items,
  'total': items.length,
  'summary': {'overdue': 0, 'today': items.length, 'upcoming': 0, 'done': 0},
};

void main() {
  group('TasksService requests', () {
    test('list is always filtered to the signed-in employee', () async {
      final server = _FakeServer()
        ..routes['GET /tasks'] = (_) => _json(_listJson([]));
      await TasksService(server.api).list(statusFilter: 'todo');

      final query = server.last('GET', '/tasks')!.url.queryParameters;
      expect(query['assigned_to'], '5');
      expect(query['status'], 'todo');
    });

    test('list refuses to run when nobody is signed in', () async {
      final server = _FakeServer();
      server.api.currentUserId = null;

      await expectLater(
        TasksService(server.api).list(),
        throwsA(isA<ApiException>()),
      );
      expect(server.calls, isEmpty, reason: 'no request may go out');
    });

    test(
      'completing a contact task uses the contact route with the backend outcome',
      () async {
        final server = _FakeServer()
          ..routes['PATCH /contacts/9/followups/1'] = (_) => _json({});
        await TasksService(server.api).complete(
          Task.fromJson(_taskJson()),
          outcome: TaskOutcome.notNow,
          notes: '  Asked to call Monday  ',
          activityType: 'phone_call',
        );

        final body = server.bodyOf('PATCH', '/contacts/9/followups/1');
        expect(body['status'], 'completed');
        expect(body['outcome'], 'not_now');
        expect(body['notes'], 'Asked to call Monday', reason: 'trimmed');
        // phone_call is stored as "call"; sending the stored name avoids a false edit log.
        expect(body['actual_channel'], 'call');
      },
    );

    test('completing a standalone task uses the /tasks route', () async {
      final server = _FakeServer()..routes['PATCH /tasks/1'] = (_) => _json({});
      await TasksService(server.api).complete(
        Task.fromJson(_taskJson(contactId: null)),
        outcome: TaskOutcome.done,
        notes: 'Done',
        activityType: 'whatsapp',
      );

      final body = server.bodyOf('PATCH', '/tasks/1');
      expect(body['outcome'], 'done');
      expect(body['actual_channel'], 'whatsapp');
    });

    test('scheduleNextFollowup sends the type, time and assignee', () async {
      final server = _FakeServer()
        ..routes['POST /contacts/9/followups'] = (_) => _json({});
      await TasksService(server.api).scheduleNextFollowup(
        contactId: 9,
        activityType: 'phone_call',
        dueAt: DateTime(2026, 10, 25, 23, 59),
      );

      final body = server.bodyOf('POST', '/contacts/9/followups');
      expect(body['channel'], 'phone_call');
      expect(body['due_at'], '2026-10-25T23:59:00');
      expect(body['assigned_to'], 5);
    });

    test('taskTypes leaves out internal notes', () async {
      final server = _FakeServer()
        ..routes['GET /settings/enums/activity_type'] = (_) => _json([
          {'value': 'phone_call', 'label': 'Phone call'},
          {'value': 'internal_note', 'label': 'Internal note'},
        ]);

      final types = await TasksService(server.api).taskTypes();
      expect(types.keys, ['phone_call']);
    });
  });

  group('TasksViewModel', () {
    test(
      'a status filter sends its API value and includes overdue only for open filters',
      () async {
        final server = _FakeServer()
          ..routes['GET /tasks'] = (_) => _json(_listJson([]));
        final vm = TasksViewModel(TasksService(server.api));

        await vm.setStatusFilter(TaskStatusFilter.completed);
        expect(
          server.last('GET', '/tasks')!.url.queryParameters['status'],
          'completed',
        );
        expect(
          server
              .last('GET', '/tasks')!
              .url
              .queryParameters
              .containsKey('include_overdue'),
          isFalse,
        );

        await vm.setStatusFilter(TaskStatusFilter.all);
        final openQuery = server.last('GET', '/tasks')!.url.queryParameters;
        expect(openQuery['status'], 'open');
        expect(openQuery['include_overdue'], 'true');
        vm.dispose();
      },
    );

    test('a successful completion removes the task from the list', () async {
      final server = _FakeServer();
      server.routes['GET /tasks'] = (_) => _json(_listJson([_taskJson()]));
      server.routes['PATCH /contacts/9/followups/1'] = (_) => _json({});
      final vm = TasksViewModel(TasksService(server.api));
      await vm.load();
      expect(vm.tasks, hasLength(1));

      final error = await vm.complete(
        vm.tasks.single,
        outcome: TaskOutcome.done,
        notes: 'Done',
        activityType: 'phone_call',
      );
      expect(error, isNull);
      expect(vm.tasks, isEmpty);
      vm.dispose();
    });

    test('a failed completion returns a message and keeps the list', () async {
      final server = _FakeServer();
      server.routes['GET /tasks'] = (_) => _json(_listJson([_taskJson()]));
      server.routes['PATCH /contacts/9/followups/1'] = (_) =>
          _json({'detail': 'Task is already completed'}, 409);
      final vm = TasksViewModel(TasksService(server.api));
      await vm.load();

      final error = await vm.complete(
        vm.tasks.single,
        outcome: TaskOutcome.done,
        notes: 'Done',
        activityType: 'phone_call',
      );
      expect(error, isNotNull);
      expect(
        vm.tasks,
        hasLength(1),
        reason: 'a failed action must not hide the list',
      );
      expect(vm.error, isNull, reason: 'an action failure is not a load error');
      vm.dispose();
    });
  });

  group('task detail flow', () {
    testWidgets(
      'completing a contact task asks for the next follow-up, and Skip ends the flow',
      (tester) async {
        final server = _FakeServer();
        server.routes['GET /settings/enums/activity_type'] = (_) => _json([
          {'value': 'phone_call', 'label': 'Phone call'},
          {'value': 'field_visit', 'label': 'Field visit'},
        ]);
        server.routes['GET /tasks'] = (_) => _json(_listJson([]));
        server.routes['PATCH /contacts/9/followups/1'] = (_) => _json({});
        final vm = TasksViewModel(TasksService(server.api));
        final task = Task.fromJson(_taskJson());

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: vm,
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => openTaskDetail(context, task),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        // Choosing Completed in the status control reveals the completion fields.
        await tester.tap(find.text('Completed'));
        await tester.pumpAndSettle();
        expect(find.text('Mark as completed'), findsOneWidget);

        // Nothing chosen yet: both required fields explain themselves.
        await tester.ensureVisible(find.text('Mark completed'));
        await tester.tap(find.text('Mark completed'));
        await tester.pump();
        expect(find.text('Pick what happened.'), findsOneWidget);
        expect(find.text('Write what was done.'), findsOneWidget);

        await tester.ensureVisible(find.text('Not now'));
        await tester.tap(find.text('Not now'));
        await tester.enterText(find.byType(TextField), 'Asked to call Monday');
        await tester.pump();
        await tester.ensureVisible(find.text('Mark completed'));
        await tester.tap(find.text('Mark completed'));
        await tester.pumpAndSettle();

        // The task was saved with the backend outcome and the note.
        final body = server.bodyOf('PATCH', '/contacts/9/followups/1');
        expect(body['outcome'], 'not_now');
        expect(body['notes'], 'Asked to call Monday');

        // The follow-up prompt appears, and Skip closes it with nothing after.
        expect(find.text('Yes, schedule'), findsOneWidget);
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(find.text('Schedule follow-up'), findsNothing);
        expect(find.text('Yes, schedule'), findsNothing);
      },
    );
  });

  group('defaultNextFollowupDue', () {
    test('is tomorrow at 23:59', () {
      expect(
        defaultNextFollowupDue(DateTime(2026, 10, 24, 15)),
        DateTime(2026, 10, 25, 23, 59),
      );
    });

    test('rolls over the end of the month', () {
      expect(
        defaultNextFollowupDue(DateTime(2026, 10, 31, 9)),
        DateTime(2026, 11, 1, 23, 59),
      );
    });
  });
}
