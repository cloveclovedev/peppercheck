import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/matching_repository.dart';
import '../domain/matching_config.dart';

part 'matching_config_provider.g.dart';

/// The server-owned matching config, fetched once per app run. Kept alive
/// because several screens (the publish referee-count selector, the referee
/// withdraw cutoff) read it and it changes only on a server deploy.
@Riverpod(keepAlive: true)
Future<MatchingConfig> matchingConfig(Ref ref) =>
    ref.watch(matchingRepositoryProvider).fetchConfig();
