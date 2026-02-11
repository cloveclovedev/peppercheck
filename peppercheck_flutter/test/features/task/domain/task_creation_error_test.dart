import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/task/domain/task_creation_error.dart';

void main() {
  group('TaskCreationError.parse', () {
    group('Insufficient Points Error', () {
      test('parses valid message correctly', () {
        final error = TaskCreationError.parse(
          'Insufficient points. Balance: 100, Locked: 50, Required: 200',
        );

        expect(error.type, TaskCreationErrorType.insufficientPoints);
        expect(error.balance, 100);
        expect(error.locked, 50);
        expect(error.required, 200);
        expect(error.message, contains('Insufficient points'));
      });

      test('handles zero values', () {
        final error = TaskCreationError.parse(
          'Insufficient points. Balance: 0, Locked: 0, Required: 100',
        );

        expect(error.type, TaskCreationErrorType.insufficientPoints);
        expect(error.balance, 0);
        expect(error.locked, 0);
        expect(error.required, 100);
      });

      test('handles large numbers', () {
        final error = TaskCreationError.parse(
          'Insufficient points. Balance: 999999, Locked: 500000, Required: 1000000',
        );

        expect(error.type, TaskCreationErrorType.insufficientPoints);
        expect(error.balance, 999999);
        expect(error.locked, 500000);
        expect(error.required, 1000000);
      });

      test('returns unknown for malformed message format', () {
        final error = TaskCreationError.parse(
          'Insufficient points. Balance: abc, Locked: 50, Required: 200',
        );

        // Since regex requires \d+, malformed numbers won't match the pattern
        expect(error.type, TaskCreationErrorType.unknown);
        expect(error.message, contains('Insufficient points'));
      });

      test('returns unknown for incomplete message', () {
        final error = TaskCreationError.parse(
          'Insufficient points. Balance: 100',
        );

        expect(error.type, TaskCreationErrorType.unknown);
        expect(error.message, contains('Insufficient points'));
      });
    });

    group('Due Date Error', () {
      test('parses valid message correctly', () {
        final error = TaskCreationError.parse(
          'Due date must be at least 24 hours from now',
        );

        expect(error.type, TaskCreationErrorType.dueDateTooSoon);
        expect(error.minHours, 24);
        expect(error.message, contains('Due date must be at least'));
      });

      test('handles different hour values', () {
        final error = TaskCreationError.parse(
          'Due date must be at least 48 hours from now',
        );

        expect(error.type, TaskCreationErrorType.dueDateTooSoon);
        expect(error.minHours, 48);
      });

      test('handles single digit hours', () {
        final error = TaskCreationError.parse(
          'Due date must be at least 1 hours from now',
        );

        expect(error.type, TaskCreationErrorType.dueDateTooSoon);
        expect(error.minHours, 1);
      });

      test('returns unknown for malformed hour value', () {
        final error = TaskCreationError.parse(
          'Due date must be at least abc hours from now',
        );

        expect(error.type, TaskCreationErrorType.unknown);
        expect(error.message, contains('Due date must be at least'));
      });
    });

    group('Wallet Not Found Error', () {
      test('detects wallet not found message', () {
        final error = TaskCreationError.parse('Point wallet not found for user');

        expect(error.type, TaskCreationErrorType.walletNotFound);
        expect(error.message, 'Point wallet not found for user');
      });

      test('detects wallet not found with different text', () {
        final error = TaskCreationError.parse(
          'Error: Point wallet not found. Please create one first.',
        );

        expect(error.type, TaskCreationErrorType.walletNotFound);
        expect(error.message, contains('Point wallet not found'));
      });
    });

    group('Unknown Error', () {
      test('returns unknown for unrecognized error', () {
        final error = TaskCreationError.parse('Some random error message');

        expect(error.type, TaskCreationErrorType.unknown);
        expect(error.message, 'Some random error message');
      });

      test('handles empty string', () {
        final error = TaskCreationError.parse('');

        expect(error.type, TaskCreationErrorType.unknown);
        expect(error.message, '');
      });

      test('handles generic database errors', () {
        final error = TaskCreationError.parse('Database connection failed');

        expect(error.type, TaskCreationErrorType.unknown);
        expect(error.message, 'Database connection failed');
      });

      test('handles network errors', () {
        final error = TaskCreationError.parse('Network request timed out');

        expect(error.type, TaskCreationErrorType.unknown);
        expect(error.message, 'Network request timed out');
      });
    });

    group('Edge Cases', () {
      test('handles message with extra whitespace', () {
        final error = TaskCreationError.parse(
          '  Insufficient points. Balance: 100, Locked: 50, Required: 200  ',
        );

        // Regex should still match despite leading/trailing whitespace
        expect(error.type, TaskCreationErrorType.insufficientPoints);
        expect(error.balance, 100);
      });

      test('handles case sensitivity for wallet error', () {
        final error = TaskCreationError.parse('point wallet not found');

        // Current implementation is case-sensitive
        expect(error.type, TaskCreationErrorType.unknown);
      });

      test('ensures balance/locked/required are null for non-points errors', () {
        final error = TaskCreationError.parse(
          'Due date must be at least 24 hours from now',
        );

        expect(error.balance, isNull);
        expect(error.locked, isNull);
        expect(error.required, isNull);
      });

      test('ensures minHours is null for non-due-date errors', () {
        final error = TaskCreationError.parse(
          'Insufficient points. Balance: 100, Locked: 50, Required: 200',
        );

        expect(error.minHours, isNull);
      });
    });
  });
}
