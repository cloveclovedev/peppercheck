import 'package:flutter_test/flutter_test.dart';
import 'package:peppercheck_flutter/features/payout/domain/payout_setup_status.dart';

void main() {
  group('PayoutSetupStatus', () {
    group('isPendingVerification', () {
      test('returns true when payoutsEnabled=false, currentlyDue empty, '
          'pendingVerification non-empty', () {
        final status = PayoutSetupStatus(
          chargesEnabled: true,
          payoutsEnabled: false,
          currentlyDue: [],
          pendingVerification: ['individual.verification.document'],
        );
        expect(status.isPendingVerification, true);
      });

      test('returns false when currentlyDue is non-empty '
          '(even if pendingVerification is also non-empty)', () {
        final status = PayoutSetupStatus(
          chargesEnabled: true,
          payoutsEnabled: false,
          currentlyDue: ['individual.address.city'],
          pendingVerification: ['individual.verification.document'],
        );
        expect(status.isPendingVerification, false);
      });

      test('returns false when payoutsEnabled=true', () {
        final status = PayoutSetupStatus(
          chargesEnabled: true,
          payoutsEnabled: true,
          pendingVerification: ['individual.verification.document'],
        );
        expect(status.isPendingVerification, false);
      });

      test('returns false when both currentlyDue and '
          'pendingVerification are empty', () {
        final status = PayoutSetupStatus(
          chargesEnabled: true,
          payoutsEnabled: false,
        );
        expect(status.isPendingVerification, false);
      });

      test('returns true even when chargesEnabled=false '
          '(isPendingVerification takes priority over isNotStarted)', () {
        final status = PayoutSetupStatus(
          chargesEnabled: false,
          payoutsEnabled: false,
          pendingVerification: ['individual.verification.document'],
        );
        expect(status.isPendingVerification, true);
        expect(status.isNotStarted, true);
      });
    });

    group('isInProgress excludes pending verification', () {
      test('returns false when isPendingVerification is true', () {
        final status = PayoutSetupStatus(
          chargesEnabled: true,
          payoutsEnabled: false,
          pendingVerification: ['individual.verification.document'],
        );
        expect(status.isInProgress, false);
      });

      test('returns true when chargesEnabled=true, payoutsEnabled=false, '
          'not pending verification', () {
        final status = PayoutSetupStatus(
          chargesEnabled: true,
          payoutsEnabled: false,
          currentlyDue: ['individual.address.city'],
        );
        expect(status.isInProgress, true);
      });
    });

    group('existing states unchanged', () {
      test('isComplete when payoutsEnabled=true', () {
        final status = PayoutSetupStatus(
          chargesEnabled: true,
          payoutsEnabled: true,
        );
        expect(status.isComplete, true);
        expect(status.isInProgress, false);
        expect(status.isNotStarted, false);
        expect(status.isPendingVerification, false);
      });

      test('isNotStarted when both disabled', () {
        final status = PayoutSetupStatus();
        expect(status.isNotStarted, true);
        expect(status.isComplete, false);
        expect(status.isInProgress, false);
        expect(status.isPendingVerification, false);
      });
    });
  });
}
