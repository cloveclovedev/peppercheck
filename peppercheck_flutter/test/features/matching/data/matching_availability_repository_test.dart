import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:peppercheck_flutter/core/network/api_client.dart';
import 'package:peppercheck_flutter/features/matching/data/matching_repository.dart';

import 'matching_availability_repository_test.mocks.dart';

const _slotsPath = '/api/v1/me/availability/time-slots';
const _blockedPath = '/api/v1/me/availability/blocked-dates';

Map<String, dynamic> _slotJson({String id = 's1', bool isActive = true}) => {
  'id': id,
  'dow': 1,
  'startMin': 540,
  'endMin': 720,
  'isActive': isActive,
};

Map<String, dynamic> _blockedJson({String id = 'b1', String? reason}) => {
  'id': id,
  'startDate': '2026-08-01',
  'endDate': '2026-08-03',
  'reason': reason,
};

@GenerateNiceMocks([MockSpec<ApiClient>()])
void main() {
  late MockApiClient api;
  late MatchingRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = MatchingRepository(api);
  });

  group('time slots', () {
    test('fetchTimeSlots maps the timeSlots envelope', () async {
      when(api.getJson(_slotsPath)).thenAnswer(
        (_) async => {
          'timeSlots': [_slotJson(), _slotJson(id: 's2', isActive: false)],
        },
      );

      final slots = await repo.fetchTimeSlots();

      expect(slots.map((s) => s.id), ['s1', 's2']);
      expect(slots.first.dow, 1);
      expect(slots.first.startMin, 540);
      expect(slots.first.endMin, 720);
      expect(slots.first.isActive, true);
      expect(slots.last.isActive, false);
    });

    test('fetchTimeSlots tolerates an empty envelope', () async {
      when(
        api.getJson(_slotsPath),
      ).thenAnswer((_) async => <String, dynamic>{});

      expect(await repo.fetchTimeSlots(), isEmpty);
    });

    test('createTimeSlot posts the slot and returns it', () async {
      when(
        api.postJson(
          _slotsPath,
          body: {'dow': 1, 'startMin': 540, 'endMin': 720, 'isActive': true},
        ),
      ).thenAnswer((_) async => _slotJson());

      final slot = await repo.createTimeSlot(
        dow: 1,
        startMin: 540,
        endMin: 720,
      );

      expect(slot.id, 's1');
    });

    test('updateTimeSlot puts to the slot path and returns it', () async {
      when(
        api.putJsonObject(
          '$_slotsPath/s1',
          body: {'dow': 2, 'startMin': 600, 'endMin': 660, 'isActive': true},
        ),
      ).thenAnswer((_) async => _slotJson());

      final slot = await repo.updateTimeSlot(
        id: 's1',
        dow: 2,
        startMin: 600,
        endMin: 660,
      );

      expect(slot.id, 's1');
    });

    test('deleteTimeSlot deletes the slot path', () async {
      await repo.deleteTimeSlot('s1');
      verify(api.deleteJson('$_slotsPath/s1')).called(1);
    });
  });

  group('blocked dates', () {
    test('fetchBlockedDates maps the blockedDates envelope', () async {
      when(api.getJson(_blockedPath)).thenAnswer(
        (_) async => {
          'blockedDates': [_blockedJson(reason: 'trip')],
        },
      );

      final dates = await repo.fetchBlockedDates();

      expect(dates.single.id, 'b1');
      expect(dates.single.startDate, DateTime(2026, 8, 1));
      expect(dates.single.endDate, DateTime(2026, 8, 3));
      expect(dates.single.reason, 'trip');
    });

    test('createBlockedDate sends calendar days, not instants', () async {
      when(
        api.postJson(
          _blockedPath,
          body: {
            'startDate': '2026-08-01',
            'endDate': '2026-08-03',
            'reason': null,
          },
        ),
      ).thenAnswer((_) async => _blockedJson());

      final blocked = await repo.createBlockedDate(
        startDate: DateTime(2026, 8, 1, 9, 30),
        endDate: DateTime(2026, 8, 3, 22, 15),
      );

      expect(blocked.id, 'b1');
    });

    test('updateBlockedDate puts to the blocked date path', () async {
      when(
        api.putJsonObject(
          '$_blockedPath/b1',
          body: {
            'startDate': '2026-08-01',
            'endDate': '2026-08-03',
            'reason': 'trip',
          },
        ),
      ).thenAnswer((_) async => _blockedJson(reason: 'trip'));

      final blocked = await repo.updateBlockedDate(
        id: 'b1',
        startDate: DateTime(2026, 8, 1),
        endDate: DateTime(2026, 8, 3),
        reason: 'trip',
      );

      expect(blocked.reason, 'trip');
    });

    test('deleteBlockedDate deletes the blocked date path', () async {
      await repo.deleteBlockedDate('b1');
      verify(api.deleteJson('$_blockedPath/b1')).called(1);
    });
  });
}
