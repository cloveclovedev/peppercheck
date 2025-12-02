import 'package:logger/logger.dart';
import 'package:peppercheck_flutter/features/currency/domain/currency.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'currency_repository.g.dart';

@Riverpod(keepAlive: true)
CurrencyRepository currencyRepository(Ref ref) {
  return CurrencyRepository(Supabase.instance.client);
}

class CurrencyRepository {
  final SupabaseClient _supabase;
  final _logger = Logger();

  // Simple in-memory cache
  final Map<String, Currency> _cache = {};

  CurrencyRepository(this._supabase);

  Future<Currency> getCurrency(String code) async {
    if (_cache.containsKey(code)) {
      return _cache[code]!;
    }

    try {
      final data = await _supabase
          .from('currencies')
          .select()
          .eq('code', code)
          .single();

      final currency = Currency.fromJson(data);
      _cache[code] = currency;
      return currency;
    } catch (e, stack) {
      _logger.e('Failed to fetch currency: $code', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
