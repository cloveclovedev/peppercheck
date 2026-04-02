import 'package:flutter/material.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/account/data/account_repository.dart';
import 'package:peppercheck_flutter/features/account/domain/account_deletable_status.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'account_deletion_controller.g.dart';

@riverpod
class AccountDeletionController extends _$AccountDeletionController {
  @override
  FutureOr<AccountDeletableStatus> build() async {
    return ref.read(accountRepositoryProvider).checkDeletable();
  }

  Future<void> executeDelete({
    bool force = false,
    required VoidCallback onSuccess,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(accountRepositoryProvider).deleteAccount(force: force);
      onSuccess();
      // Return a dummy status — user will be signed out
      return const AccountDeletableStatus(deletable: false);
    });
    if (state.hasError) {
      ref
          .read(loggerProvider)
          .e(
            'Account deletion error',
            error: state.error,
            stackTrace: state.stackTrace,
          );
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref.read(accountRepositoryProvider).checkDeletable();
    });
  }
}
