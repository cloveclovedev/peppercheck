import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:logger/logger.dart';
import 'package:mime/mime.dart';
import 'package:peppercheck_flutter/app/app_logger.dart';
import 'package:peppercheck_flutter/features/profile/data/profile_errors.dart';
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

  Future<void> updateUsername(String userId, String username) async {
    try {
      await _supabase
          .from('profiles')
          .update({'username': username})
          .eq('id', userId);
    } on PostgrestException catch (e, st) {
      if (e.code == '23505') {
        throw const UsernameAlreadyTakenException();
      }
      _logger.e('Update username failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _logger.e('Update username failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<String> updateAvatar(String userId, CroppedFile cropped) async {
    try {
      final length = await File(cropped.path).length();
      final filename = cropped.path.split('/').last;
      final mimeType = lookupMimeType(cropped.path) ?? 'image/jpeg';

      // 1. Get presigned upload URL
      final response = await _supabase.functions.invoke(
        'generate-upload-url',
        body: {
          'filename': filename,
          'content_type': mimeType,
          'file_size_bytes': length,
          'kind': 'avatar',
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to get avatar upload URL: ${response.data}');
      }

      final uploadUrl = response.data['upload_url'] as String;
      final publicUrl = response.data['public_url'] as String;

      // 2. PUT the bytes to R2
      final bytes = await cropped.readAsBytes();
      final dio = Dio();
      await dio.put(
        uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {'Content-Type': mimeType, 'Content-Length': length},
        ),
      );

      // 3. Update avatar_url in DB
      await _supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', userId);

      return publicUrl;
    } catch (e, st) {
      _logger.e('Update avatar failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepository(Supabase.instance.client, ref.watch(loggerProvider));
}
