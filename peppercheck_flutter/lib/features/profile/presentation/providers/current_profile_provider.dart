import 'package:peppercheck_flutter/features/authentication/data/auth_state_provider.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_repository.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'current_profile_provider.g.dart';

@Riverpod(keepAlive: true)
class CurrentProfile extends _$CurrentProfile {
  @override
  FutureOr<Profile?> build() async {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return null;
    }

    return ref.watch(profileRepositoryProvider).fetchProfile(user.id);
  }
}
