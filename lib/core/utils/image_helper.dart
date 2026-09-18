import 'dart:convert';
import 'dart:typed_data';

/// A utility class for handling intensive image operations.
/// It uses a static map to cache the decoded Base64 `Uint8List` bytes
/// so that the main UI thread doesn't stutter when rebuilding lists.
class ImageHelper {
  // Simple in-memory cache to store decoded images.
  // Using hash code of the string as the key to save memory instead of 
  // keeping huge Base64 strings alive in memory as keys.
  static final Map<int, Uint8List> _decodeCache = {};

  /// Decodes a base64 image string into Uint8List with an LRU-style cache
  static Uint8List? decodeBase64(String? imageBase64) {
    final raw = imageBase64?.trim();
    if (raw == null || raw.isEmpty) return null;

    final key = raw.hashCode;
    
    if (_decodeCache.containsKey(key)) {
      return _decodeCache[key];
    }

    try {
      final payload = raw.contains(',') ? raw.split(',').last : raw;
      final bytes = base64Decode(payload);
      
      // To prevent memory leak on very large catalogs, we limit the cache to 200 items.
      if (_decodeCache.length > 200) {
        _decodeCache.remove(_decodeCache.keys.first);
      }
      
      _decodeCache[key] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Clears the entire image decode cache. Useful on logout or when switching views.
  static void clearCache() {
    _decodeCache.clear();
  }
}
