import 'package:meta/meta.dart';

@immutable
class Place {
  final String id;
  final String userId; // owner
  final String title;
  final String description; // target 20–30 words (validated in UI)
  final String imageUrl; // public URL in Supabase Storage
  final String mapUrl; // Google Maps link
  final DateTime createdAt;
  final bool
  isFavorite; // computed per current user (via favorites table); default false

  const Place({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.mapUrl,
    required this.createdAt,
    this.isFavorite = false,
  });

  Place copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? imageUrl,
    String? mapUrl,
    DateTime? createdAt,
    bool? isFavorite,
  }) => Place(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    description: description ?? this.description,
    imageUrl: imageUrl ?? this.imageUrl,
    mapUrl: mapUrl ?? this.mapUrl,
    createdAt: createdAt ?? this.createdAt,
    isFavorite: isFavorite ?? this.isFavorite,
  );

  factory Place.fromRow(Map<String, dynamic> row, {bool isFavorite = false}) {
    return Place(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      description: row['description'] as String,
      imageUrl: row['image_url'] as String,
      mapUrl: row['map_url'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
      isFavorite: isFavorite,
    );
  }

  Map<String, dynamic> toInsert() => {
    'title': title,
    'description': description,
    'image_url': imageUrl,
    'map_url': mapUrl,
  };
}
