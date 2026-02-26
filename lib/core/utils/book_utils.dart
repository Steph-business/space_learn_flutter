// Utility helpers for handling book objects with inconsistent ID keys.
// The backend sometimes returns different key names (id, ID, livre_id, bookId, etc.).
// This helper centralizes extraction logic and is intentionally defensive.

String? getBookIdFromMap(Map<String, dynamic>? book) {
  if (book == null) return null;

  // Common ID key candidates (checked first for speed)
  final candidates = [
    'id', 'ID', 'Id',
    'livre_id', 'livreId',
    'book_id', 'bookId',
    '_id', 'uuid'
  ];

  for (final key in candidates) {
    final v = book[key];
    if (v != null) return v.toString();
  }

  // Handle nested structures where the book map may contain another map
  // (e.g. {'Livre': {...}} or {'data': {...}})
  final nestedKeys = ['Livre', 'livre', 'book', 'data', 'attributes'];
  for (final nk in nestedKeys) {
    final nested = book[nk];
    if (nested is Map<String, dynamic>) {
      final id = getBookIdFromMap(nested);
      if (id != null) return id;
    }
  }

  // As a last resort, if the map contains exactly one key with a scalar value
  // that looks like an id, return it. This is conservative and avoids false positives.
  for (final entry in book.entries) {
    final value = entry.value;
    if (value is String || value is num) {
      final s = value.toString();
      if (s.isNotEmpty && s.length >= 6) {
        // Heuristic: IDs are typically longer than short strings like 'ok'
        return s;
      }
    }
  }

  return null;
}
