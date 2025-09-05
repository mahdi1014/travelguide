import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/place.dart';
import '../services/supabase_service.dart';

class PlaceRepository {
  static const _places = 'places';
  static const _favorites = 'favorites';
  static const _bucket = 'place-photos';

  SupabaseClient get _db => supa.client;

Future<List<Place>> fetchPlaces({
  required String? search,
  DateTime? before,
  int limit = 20,
  String? currentUserId,
}) async {
  // v2.x: no generics on select()
  final builder = _db.from(_places).select();

  // 🔎 Search across title OR description (case-insensitive)
  if (search != null) {
    final term = search.trim();
    if (term.isNotEmpty) {
      // postgrest OR syntax: column.op.value , column.op.value
      // %term% pattern for substring
      builder.or('title.ilike.%$term%,description.ilike.%$term%');
    }
  }

  // Pagination (newest first)
  builder.order('created_at', ascending: false).limit(limit);
  if (before != null) {
    builder.lt('created_at', before.toIso8601String());
  }

  final List<Map<String, dynamic>> rows = await builder;

  // Favorites map (optional)
  Map<String, bool> favMap = {};
  if (currentUserId != null && rows.isNotEmpty) {
    final ids = rows.map((r) => r['id'] as String).toList();
    final inList = '(${ids.map((e) => '"$e"').join(',')})';
    final List<Map<String, dynamic>> favRows = await _db
        .from(_favorites)
        .select()
        .eq('user_id', currentUserId)
        .filter('place_id', 'in', inList);
    for (final r in favRows) {
      favMap[r['place_id'] as String] = true;
    }
  }

  return rows
      .map((r) => Place.fromRow(r, isFavorite: favMap[r['id']] ?? false))
      .toList();
}

  Future<Place> createPlace({
    required String title,
    required String description,
    required String mapUrl,
    required PlatformFile imageFile,
    required String userId,
  }) async {
    // Upload to Storage
    final path =
        '${userId}_${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
    await _db.storage
        .from(_bucket)
        .uploadBinary(
          path,
          imageFile.bytes!,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
    final publicUrl = _db.storage.from(_bucket).getPublicUrl(path);

    // Insert row WITH owner
    final Map<String, dynamic> inserted = await _db
        .from(_places)
        .insert({
          'user_id': userId, // <-- important
          'title': title,
          'description': description,
          'image_url': publicUrl,
          'map_url': mapUrl,
        })
        .select()
        .single();

    return Place.fromRow(inserted);
  }

  Future<Place> updatePlace({
    required String id,
    String? title,
    String? description,
    String? mapUrl,
    PlatformFile? imageFile,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (mapUrl != null) data['map_url'] = mapUrl;

    if (imageFile != null) {
      final userId = _db.auth.currentUser!.id;
      final path =
          '${userId}_${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      await _db.storage
          .from(_bucket)
          .uploadBinary(
            path,
            imageFile.bytes!,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      final publicUrl = _db.storage.from(_bucket).getPublicUrl(path);
      data['image_url'] = publicUrl;
    }

    final Map<String, dynamic> row = await _db
        .from(_places)
        .update(data)
        .eq('id', id)
        .select()
        .single();

    return Place.fromRow(row);
  }

  /// Deletes only if current user owns the row.
  // Future<bool> deletePlace(String id) async {
  //   final uid = Supabase.instance.client.auth.currentUser?.id;
  //   if (uid == null) throw AuthException('Not authenticated');

  //   // If you have user ownership, verify first:
  //   final row = await Supabase.instance.client
  //       .from('places')
  //       .select('id,user_id')
  //       .eq('id', id)
  //       .maybeSingle();

  //   if (row == null) return false; // no such row
  //   if (row['user_id'] != uid) return false; // not owner -> RLS blocks

  //   // Delete guarded by id + owner to avoid PGRST116
  //   await Supabase.instance.client.from('places').delete().match({
  //     'id': id,
  //     'user_id': uid,
  //   });

  //   return true;
  // }
  Future<bool> deletePlace(String id) async {
  final Map<String, dynamic>? deleted = await supa.client
      .from('places')
      .delete()
      .eq('id', id)
      .select('id')
      .maybeSingle();      // returns null if 0 rows (no throw)

  return deleted != null;
}

  Future<bool> toggleFavorite({
    required String placeId,
    required String userId,
    required bool makeFavorite,
  }) async {
    if (makeFavorite) {
      await _db.from(_favorites).upsert({
        'user_id': userId,
        'place_id': placeId,
      });
      return true;
    } else {
      await _db.from(_favorites).delete().match({
        'user_id': userId,
        'place_id': placeId,
      });
      return false;
    }
  }
}
