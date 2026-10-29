/// Tests for the pipeline lead screen: the models, the owner rule in the view
/// model, and which buttons the screen shows to the owner and to everyone else.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ogera_crm_mobile/core/network/api_client.dart';
import 'package:ogera_crm_mobile/models/lead_work.dart';
import 'package:ogera_crm_mobile/services/crm_services.dart';
import 'package:ogera_crm_mobile/services/lead_work_service.dart';
import 'package:ogera_crm_mobile/services/pipeline_service.dart';
import 'package:ogera_crm_mobile/view_models/lead_work_view_model.dart';
import 'package:ogera_crm_mobile/views/pipeline/pipeline_lead_detail_screen.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

const _ownerId = 5;
const _otherId = 8;
const _adminId = 1;

/// A lead owned by [_ownerId] ("Asha"), with one activity, one overdue
/// follow-up and one stage move, as the backend would return them.
final _activityRows = <Map<String, dynamic>>[
  {
    'id': 1,
    'contact_id': 9,
    'done_by': _ownerId,
    'done_by_name': 'Asha',
    'title': null,
    'activity_type': 'phone_call',
    'outcome': 'done',
    'notes': 'Asked for a quote',
    'followup_id': null,
    'logged_at': '2026-10-24T10:00:00',
  },
];

final _followupRows = <Map<String, dynamic>>[
  {
    'id': 3,
    'contact_id': 9,
    'assigned_to': _ownerId,
    'assigned_to_name': 'Asha',
    'title': 'Call back',
    'due_at': '2026-10-20T23:59:00',
    'status': 'todo',
    'priority': 'medium',
    'channel': 'phone_call',
    'notes': null,
    'created_at': '2026-10-19T09:00:00',
    'task_state': 'overdue',
    'overdue_days': 4,
  },
];

final _historyRows = <Map<String, dynamic>>[
  {
    'event_type': 'stage',
    'timestamp': '2026-10-22T09:00:00',
    'actor_name': 'Asha',
    'stage_name': 'Interested',
    'previous_stage_name': 'New Lead',
    'notes': null,
  },
];

const _lead = PipelineContact(
  id: 9,
  phone: '9000000009',
  contactType: 'consumer',
  name: 'Ravi Kumar',
  stageName: 'Interested',
  district: 'Kozhikode',
  assignedToName: 'Asha',
  assignedToId: _ownerId,
);

/// An [ApiClient] that records every request, so tests can check method and body.
class _Recorder {
  final requests = <http.Request>[];

  ApiClient api({int? currentUserId = _ownerId}) {
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      final body = switch (path) {
        '/contacts/9/activities' => _activityRows,
        '/contacts/9/followups' => _followupRows,
        '/contacts/9/history' => _historyRows,
        _ => null,
      };
      return http.Response(jsonEncode(body), 200);
    });
    final api = ApiClient(baseUrl: 'https://crm.test', client: client);
    api.currentUserId = currentUserId;
    return api;
  }

  /// Requests that change data (anything but GET).
  List<http.Request> get writes =>
      requests.where((request) => request.method != 'GET').toList();
}

void main() {
  group('models', () {
    test('parse the backend activity, follow-up and history rows', () {
      final activity = ActivityEntry.fromJson(_activityRows.first);
      final followup = FollowupEntry.fromJson(_followupRows.first);
      final history = LeadHistoryEntry.fromJson(_historyRows.first);

      expect(activity.activityType, 'phone_call');
      expect(activity.doneByName, 'Asha');
      expect(activity.notes, 'Asked for a quote');
      expect(followup.isOpen, isTrue);
      expect(followup.taskState, 'overdue');
      expect(followup.overdueDays, 4);
      expect(followup.assignedTo, _ownerId);
      expect(history.summary, 'Stage moved to Interested from New Lead');
    });

    test('a completed follow-up is not open', () {
      final done = FollowupEntry.fromJson({
        ..._followupRows.first,
        'status': 'completed',
        'task_state': 'completed',
      });

      expect(done.isOpen, isFalse);
    });

    test('FollowupDraft sends a naive local due time and skips blank text', () {
      final draft = FollowupDraft(
        channel: 'phone_call',
        dueAt: DateTime(2026, 10, 25, 23, 59),
        assignedTo: _ownerId,
        title: '   ',
        notes: '',
      );

      expect(draft.toJson(), {
        'channel': 'phone_call',
        'due_at': '2026-10-25T23:59:00',
        'assigned_to': _ownerId,
        'priority': 'medium',
      });
    });
  });

  group('LeadWorkViewModel owner rule', () {
    test('a non-owner is refused before any request is sent', () async {
      final recorder = _Recorder();
      final viewModel = LeadWorkViewModel(
        service: LeadWorkService(recorder.api(currentUserId: _otherId)),
        contactId: 9,
        ownerId: _ownerId,
        currentUserId: _otherId,
      );
      await viewModel.load();

      final message = await viewModel.scheduleFollowup(
        FollowupDraft(
          channel: 'phone_call',
          dueAt: DateTime(2030, 1, 1, 10),
          assignedTo: _otherId,
        ),
      );

      expect(viewModel.canWrite, isFalse);
      expect(
        message,
        'Only an admin, a manager or the assigned employee can add to this lead.',
      );
      expect(recorder.writes, isEmpty);
    });

    test('an admin may book on a lead owned by someone else', () async {
      final recorder = _Recorder();
      final viewModel = LeadWorkViewModel(
        service: LeadWorkService(recorder.api(currentUserId: _adminId)),
        contactId: 9,
        ownerId: _ownerId,
        currentUserId: _adminId,
        isHead: true,
      );
      await viewModel.load();

      final message = await viewModel.scheduleFollowup(
        FollowupDraft(
          channel: 'phone_call',
          dueAt: DateTime(2030, 1, 1, 10),
          assignedTo: _adminId,
        ),
      );

      expect(viewModel.canWrite, isTrue);
      expect(viewModel.isOwner, isFalse);
      expect(message, isNull);
      expect(recorder.writes.single.method, 'POST');
    });

    test(
      'an employee cannot reschedule a follow-up assigned to someone else',
      () async {
        final recorder = _Recorder();
        final viewModel = LeadWorkViewModel(
          service: LeadWorkService(recorder.api(currentUserId: _otherId)),
          contactId: 9,
          ownerId: _otherId,
          currentUserId: _otherId,
        );
        await viewModel.load();
        recorder.requests.clear();

        // The follow-up on this lead is assigned to Asha (5), not to Anu (8).
        final message = await viewModel.rescheduleFollowup(
          viewModel.followups!.single,
          DateTime(2030, 1, 1, 23, 59),
        );

        expect(
          message,
          'Only the assignee, an admin or a manager can change this follow-up.',
        );
        expect(recorder.writes, isEmpty);
      },
    );

    test('the assignee reschedules: a PATCH with the new due time', () async {
      final recorder = _Recorder();
      final viewModel = LeadWorkViewModel(
        service: LeadWorkService(recorder.api()),
        contactId: 9,
        ownerId: _ownerId,
        currentUserId: _ownerId,
      );
      await viewModel.load();
      recorder.requests.clear();

      final message = await viewModel.rescheduleFollowup(
        viewModel.followups!.single,
        DateTime(2030, 1, 2, 23, 59),
      );

      expect(message, isNull);
      final write = recorder.writes.single;
      expect(write.method, 'PATCH');
      expect(write.url.path, '/contacts/9/followups/3');
      expect(jsonDecode(write.body), {'due_at': '2030-01-02T23:59:00'});
    });

    test(
      'the owner books a follow-up and only the follow-up list reloads',
      () async {
        final recorder = _Recorder();
        final viewModel = LeadWorkViewModel(
          service: LeadWorkService(recorder.api()),
          contactId: 9,
          ownerId: _ownerId,
          currentUserId: _ownerId,
        );
        await viewModel.load();
        recorder.requests.clear();

        final message = await viewModel.scheduleFollowup(
          FollowupDraft(
            channel: 'phone_call',
            dueAt: DateTime(2030, 1, 1, 10),
            assignedTo: _ownerId,
          ),
        );

        expect(message, isNull);
        expect(recorder.writes.single.method, 'POST');
        expect(recorder.writes.single.url.path, '/contacts/9/followups');
        final reads = recorder.requests.map((r) => r.url.path).toList();
        // After the POST, follow-ups and history are read again. The activity log is not.
        expect(reads, contains('/contacts/9/followups'));
        expect(reads, contains('/contacts/9/history'));
        expect(reads, isNot(contains('/contacts/9/activities')));
      },
    );

    test('marking done sends the outcome and notes to the follow-up', () async {
      final recorder = _Recorder();
      final viewModel = LeadWorkViewModel(
        service: LeadWorkService(recorder.api()),
        contactId: 9,
        ownerId: _ownerId,
        currentUserId: _ownerId,
      );
      await viewModel.load();
      recorder.requests.clear();

      final message = await viewModel.completeFollowup(
        viewModel.followups!.single,
        outcome: 'not_now',
        notes: '  Wants to wait till Diwali  ',
      );

      expect(message, isNull);
      final write = recorder.writes.single;
      expect(write.method, 'PATCH');
      expect(write.url.path, '/contacts/9/followups/3');
      expect(jsonDecode(write.body), {
        'status': 'completed',
        'outcome': 'not_now',
        'notes': 'Wants to wait till Diwali',
      });
    });
  });

  group('legacy timeline (FollowupsService.remarks)', () {
    test(
      'reads /history and keeps notes, follow-ups and stage moves apart',
      () async {
        final api = fakeApiClient({
          '/contacts/9/history': (_) => [
            {
              'event_type': 'activity',
              'timestamp': '2026-10-24T10:00:00',
              'actor_id': _ownerId,
              'actor_name': 'Asha',
              'activity_type': 'phone_call',
              'notes': 'Asked for a quote',
            },
            {
              'event_type': 'followup',
              'timestamp': '2026-10-23T09:00:00',
              'actor_id': _ownerId,
              'actor_name': 'Asha',
              'title': 'Call back',
              'due_at': '2030-01-05T23:59:00',
              'followup_status': 'todo',
            },
            {
              'event_type': 'stage',
              'timestamp': '2026-10-22T09:00:00',
              'actor_name': 'Asha',
              'stage_name': 'Interested',
              'previous_stage_name': 'New Lead',
            },
          ],
        });

        final remarks = await FollowupsService(api).remarks(9);

        expect(remarks.map((r) => r.remark), [
          'Asked for a quote',
          'Follow-up scheduled: Call back · due 05 Jan',
          'Stage moved to Interested from New Lead',
        ]);
        expect(remarks[0].isSystem, isFalse);
        expect(remarks[1].isFollowup, isTrue);
        expect(remarks[1].author, 'Asha');
        expect(remarks[2].isSystem, isTrue);
        expect(remarks[2].isFollowup, isFalse);
      },
    );
  });

  group('legacy Follow-ups board due date', () {
    test(
      'moves the open follow-up with the follow-up endpoint, not the activity one',
      () async {
        final recorder = _Recorder();
        await FollowupsService(
          recorder.api(),
        ).updateLead(9, dueDate: '2030-01-05');

        final write = recorder.writes.single;
        expect(write.method, 'PATCH');
        expect(write.url.path, '/contacts/9/followups/3');
        expect(jsonDecode(write.body), {'due_at': '2030-01-05T23:59:00'});
        expect(
          recorder.requests.any((r) => r.url.path.endsWith('/activities')),
          isFalse,
        );
      },
    );
  });

  group('PipelineLeadDetailScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      required int currentUserId,
      bool isHead = false,
    }) async {
      final api = _Recorder().api(currentUserId: currentUserId);
      await tester.pumpWidget(
        Provider<ApiClient>.value(
          value: api,
          child: MaterialApp(
            home: PipelineLeadDetailScreen(contact: _lead, isHead: isHead),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'an admin with head access can add to a lead owned by someone else',
      (tester) async {
        await pumpScreen(tester, currentUserId: _adminId, isHead: true);

        expect(find.text('Asha · head access'), findsOneWidget);
        expect(
          find.widgetWithText(FilledButton, 'Log activity'),
          findsOneWidget,
        );

        await tester.tap(find.text('Follow-ups (1)'));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(FilledButton, 'Schedule follow-up'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Reschedule'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(OutlinedButton, 'Mark done'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'an employee sees Reschedule and Mark done only on follow-ups assigned to them',
      (tester) async {
        // Anu (8) is not the assignee of the follow-up, which belongs to Asha (5).
        await pumpScreen(tester, currentUserId: _otherId);

        await tester.tap(find.text('Follow-ups (1)'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(OutlinedButton, 'Reschedule'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Mark done'), findsNothing);
      },
    );

    testWidgets('the owner sees the Log activity button on the first tab', (
      tester,
    ) async {
      await pumpScreen(tester, currentUserId: _ownerId);

      expect(find.text('Yours'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Log activity'), findsOneWidget);
      expect(find.text('No activity logged yet'), findsNothing);
      expect(find.textContaining('Asked for a quote'), findsOneWidget);
    });

    testWidgets('the owner sees Schedule follow-up on the follow-ups tab', (
      tester,
    ) async {
      await pumpScreen(tester, currentUserId: _ownerId);

      await tester.tap(find.text('Follow-ups (1)'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(FilledButton, 'Schedule follow-up'),
        findsOneWidget,
      );
      expect(find.text('Overdue 4d'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Mark done'), findsOneWidget);
    });

    testWidgets(
      'the history tab never shows an add button, even to the owner',
      (tester) async {
        await pumpScreen(tester, currentUserId: _ownerId);

        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        expect(find.widgetWithText(FilledButton, 'Log activity'), findsNothing);
        expect(
          find.widgetWithText(FilledButton, 'Schedule follow-up'),
          findsNothing,
        );
        expect(
          find.text('Stage moved to Interested from New Lead'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'someone else sees the lead read-only: no add buttons, no Mark done',
      (tester) async {
        await pumpScreen(tester, currentUserId: _otherId);

        expect(find.text('Asha · view only'), findsOneWidget);
        expect(find.widgetWithText(FilledButton, 'Log activity'), findsNothing);

        await tester.tap(find.text('Follow-ups (1)'));
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(FilledButton, 'Schedule follow-up'),
          findsNothing,
        );
        expect(find.widgetWithText(OutlinedButton, 'Mark done'), findsNothing);
        // They can still see the follow-up itself.
        expect(find.text('Call back'), findsOneWidget);
      },
    );
  });
}
