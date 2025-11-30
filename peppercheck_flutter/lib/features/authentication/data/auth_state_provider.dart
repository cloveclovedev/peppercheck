import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_state_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<AuthState> authStateChanges(Ref ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
}

@Riverpod(keepAlive: true)
User? currentUser(Ref ref) {
  final authState = ref.watch(authStateChangesProvider);
  return authState.value?.session?.user;
}
