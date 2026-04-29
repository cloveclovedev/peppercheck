import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/evidence/presentation/controllers/evidence_submission_state.dart';

void main() {
  group('EvidenceSubmissionState.isLoading', () {
    test('idle is not loading', () {
      expect(const EvidenceSubmissionState.idle().isLoading, isFalse);
    });
    test('preparing is loading', () {
      expect(
        const EvidenceSubmissionState.preparing(current: 1, total: 3).isLoading,
        isTrue,
      );
    });
    test('uploading is loading', () {
      expect(
        const EvidenceSubmissionState.uploading(current: 2, total: 3).isLoading,
        isTrue,
      );
    });
  });

  group('EvidenceSubmissionState discriminators', () {
    test('isPreparing flags only the preparing variant', () {
      expect(const EvidenceSubmissionState.idle().isPreparing, isFalse);
      expect(
        const EvidenceSubmissionState.preparing(
          current: 1,
          total: 1,
        ).isPreparing,
        isTrue,
      );
      expect(
        const EvidenceSubmissionState.uploading(
          current: 1,
          total: 1,
        ).isPreparing,
        isFalse,
      );
    });

    test('isUploading flags only the uploading variant', () {
      expect(const EvidenceSubmissionState.idle().isUploading, isFalse);
      expect(
        const EvidenceSubmissionState.preparing(
          current: 1,
          total: 1,
        ).isUploading,
        isFalse,
      );
      expect(
        const EvidenceSubmissionState.uploading(
          current: 1,
          total: 1,
        ).isUploading,
        isTrue,
      );
    });
  });

  group('EvidenceSubmissionState.progress', () {
    test('idle returns null', () {
      expect(const EvidenceSubmissionState.idle().progress, isNull);
    });
    test('preparing returns current/total record', () {
      final p = const EvidenceSubmissionState.preparing(
        current: 2,
        total: 5,
      ).progress;
      expect(p?.current, equals(2));
      expect(p?.total, equals(5));
    });
    test('uploading returns current/total record', () {
      final p = const EvidenceSubmissionState.uploading(
        current: 3,
        total: 5,
      ).progress;
      expect(p?.current, equals(3));
      expect(p?.total, equals(5));
    });
  });
}
