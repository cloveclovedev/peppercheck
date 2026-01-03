import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/profile/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'profile_repository.g.dart';

class ProfileRepository {
  final SupabaseClient _supabase;
  final Logger _logger;

  ProfileRepository(this._supabase, this._logger);

  Future<Profile> fetchProfile(String userId) async {
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return Profile.fromJson(data);
    } catch (e, st) {
      _logger.e('Fetch profile failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateTimezone(String userId, String timezone) async {
    try {
      await _supabase
          .from('profiles')
          .update({'timezone': timezone})
          .eq('id', userId);
    } catch (e, st) {
      _logger.e('Update timezone failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(Supabase.instance.client, ref.watch(loggerProvider));
}
