import 'api_client.dart';

/// Safety stop for a server that keeps handing back a cursor. The lists this
/// helper serves are bounded active lists, so reaching this means a bug, not a
/// big page count — hence the throw rather than a silently short list.
const _maxPages = 100;

/// Walks a cursor-paged list endpoint and returns every page's items.
///
/// [itemsKey] is the response envelope's array key (`tasks`, `assignments`, …);
/// paging follows the sibling `nextCursor` until the server stops returning
/// one. The cursor is **opaque** — it is always URI-encoded rather than
/// concatenated raw, so a base64 cursor containing `+` or `/` survives the
/// round trip.
Future<List<Map<String, dynamic>>> fetchAllPages(
  ApiClient api,
  String path, {
  required String itemsKey,
}) async {
  final items = <Map<String, dynamic>>[];
  String? cursor;
  var pages = 0;

  do {
    final json = await api.getJson(_withCursor(path, cursor));
    final page = json[itemsKey];
    if (page is List) {
      for (final item in page) {
        items.add(Map<String, dynamic>.from(item as Map));
      }
    }
    cursor = json['nextCursor'] as String?;
    pages++;
  } while (cursor != null && pages < _maxPages);

  if (cursor != null) {
    // Returning what we have would look like a complete list to every caller.
    throw StateError('paging did not finish for $path after $_maxPages pages');
  }

  return items;
}

String _withCursor(String path, String? cursor) {
  if (cursor == null) return path;
  final separator = path.contains('?') ? '&' : '?';
  return '$path${separator}cursor=${Uri.encodeQueryComponent(cursor)}';
}
