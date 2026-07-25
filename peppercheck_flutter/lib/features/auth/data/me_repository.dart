import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/api_client_provider.dart';
import '../../../core/network/api_client.dart';
import '../domain/app_user.dart';
import 'me_dto.dart';

part 'me_repository.g.dart';

/// Resolves the internal user via `GET /api/v1/me` and maps the DTO to domain.
class MeRepository {
  MeRepository(this._api);

  final ApiClient _api;

  Future<AppUser> fetchMe() async {
    final json = await _api.getJson('/api/v1/me');
    return MeResponse.fromJson(json).toDomain();
  }
}

@riverpod
MeRepository meRepository(Ref ref) =>
    MeRepository(ref.watch(apiClientProvider));
