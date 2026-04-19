import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/judgement/domain/judgement.dart';
import 'package:peppercheck_flutter/features/matching/domain/referee_request.dart';
import 'package:peppercheck_flutter/features/task/domain/task.dart';

const _taskerId = 'tasker-001';
const _refereeId1 = 'referee-001';
const _refereeId2 = 'referee-002';
const _now = '2026-04-19T00:00:00Z';

Task _makeTask({
  String status = 'open',
  List<RefereeRequest> refereeRequests = const [],
}) {
  return Task(
    id: 'task-001',
    taskerId: _taskerId,
    title: 'Test Task',
    status: status,
    refereeRequests: refereeRequests,
  );
}

RefereeRequest _makeRequest({
  String id = 'req-001',
  String status = 'pending',
  String? matchedRefereeId,
  Judgement? judgement,
}) {
  return RefereeRequest(
    id: id,
    taskId: 'task-001',
    matchingStrategy: 'standard',
    status: status,
    matchedRefereeId: matchedRefereeId,
    createdAt: _now,
  ).copyWith(judgement: judgement);
}

Judgement _makeJudgement({
  String id = 'req-001',
  String status = 'awaiting_evidence',
}) {
  return Judgement(id: id, status: status, createdAt: _now, updatedAt: _now);
}

void main() {
  group('Task.getDetailedStatuses - Tasker view', () {
    test('draft task returns [draft]', () {
      final task = _makeTask(status: 'draft');
      expect(task.getDetailedStatuses(_taskerId), ['draft']);
    });

    test('closed task returns [closed]', () {
      final task = _makeTask(status: 'closed');
      expect(task.getDetailedStatuses(_taskerId), ['closed']);
    });

    test('all requests expired returns [matching_failed]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(id: 'r1', status: 'expired'),
          _makeRequest(id: 'r2', status: 'expired'),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['matching_failed']);
    });

    test('any request pending returns [matching]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1'),
          ),
          _makeRequest(id: 'r2', status: 'pending'),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['matching']);
    });

    test('any request matched returns [matching]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'matched',
            matchedRefereeId: _refereeId1,
          ),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['matching']);
    });

    test(
      'all accepted + all awaiting_evidence returns [matching_complete]',
      () {
        final task = _makeTask(
          refereeRequests: [
            _makeRequest(
              id: 'r1',
              status: 'accepted',
              matchedRefereeId: _refereeId1,
              judgement: _makeJudgement(id: 'r1'),
            ),
            _makeRequest(
              id: 'r2',
              status: 'accepted',
              matchedRefereeId: _refereeId2,
              judgement: _makeJudgement(id: 'r2'),
            ),
          ],
        );
        expect(task.getDetailedStatuses(_taskerId), ['matching_complete']);
      },
    );

    test('any judgement evidence_timeout returns [evidence_timeout]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'evidence_timeout'),
          ),
          _makeRequest(
            id: 'r2',
            status: 'accepted',
            matchedRefereeId: _refereeId2,
            judgement: _makeJudgement(id: 'r2', status: 'evidence_timeout'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['evidence_timeout']);
    });

    test('judgement phase returns per-referee statuses', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'in_review'),
          ),
          _makeRequest(
            id: 'r2',
            status: 'accepted',
            matchedRefereeId: _refereeId2,
            judgement: _makeJudgement(id: 'r2', status: 'approved'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['in_review', 'approved']);
    });

    test('single referee in judgement phase returns single status', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'rejected'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['rejected']);
    });

    test('payment_processing returns per-referee statuses', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'payment_processing',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'approved'),
          ),
          _makeRequest(
            id: 'r2',
            status: 'closed',
            matchedRefereeId: _refereeId2,
            judgement: _makeJudgement(id: 'r2', status: 'approved'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), [
        'payment_processing',
        'closed',
      ]);
    });

    test('all requests closed returns [closed]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'closed',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'approved'),
          ),
          _makeRequest(
            id: 'r2',
            status: 'closed',
            matchedRefereeId: _refereeId2,
            judgement: _makeJudgement(id: 'r2', status: 'approved'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['closed']);
    });

    test('declined/cancelled requests are filtered out', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1'),
          ),
          _makeRequest(id: 'r2', status: 'declined'),
          _makeRequest(id: 'r3', status: 'cancelled'),
          _makeRequest(id: 'r4', status: 'pending'),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['matching']);
    });

    test('accepted + expired (no pending) returns [matching_complete]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1'),
          ),
          _makeRequest(id: 'r2', status: 'expired'),
        ],
      );
      expect(task.getDetailedStatuses(_taskerId), ['matching_complete']);
    });

    test('no referee requests returns [matching]', () {
      final task = _makeTask(refereeRequests: []);
      expect(task.getDetailedStatuses(_taskerId), ['matching']);
    });
  });

  group('Task.getDetailedStatuses - Referee view', () {
    test('awaiting_evidence returns [awaiting_evidence]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['awaiting_evidence']);
    });

    test('in_review returns [in_review]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'in_review'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['in_review']);
    });

    test('approved returns [approved]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'approved'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['approved']);
    });

    test('rejected returns [rejected]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'rejected'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['rejected']);
    });

    test('evidence_timeout returns [evidence_timeout]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'evidence_timeout'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['evidence_timeout']);
    });

    test('review_timeout returns [review_timeout]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'review_timeout'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['review_timeout']);
    });

    test('payment_processing returns [payment_processing]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'payment_processing',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'approved'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['payment_processing']);
    });

    test('closed returns [closed]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'closed',
            matchedRefereeId: _refereeId1,
            judgement: _makeJudgement(id: 'r1', status: 'approved'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['closed']);
    });

    test('no matching request returns [matching]', () {
      final task = _makeTask(
        refereeRequests: [
          _makeRequest(
            id: 'r1',
            status: 'accepted',
            matchedRefereeId: _refereeId2,
            judgement: _makeJudgement(id: 'r1'),
          ),
        ],
      );
      expect(task.getDetailedStatuses(_refereeId1), ['matching']);
    });
  });
}
