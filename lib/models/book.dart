import 'package:cloud_firestore/cloud_firestore.dart';

/// Entity 2: Book — owned by the user who catalogued it (ownerId == uid),
/// references an Author by ID, and carries the cover image uploaded to
/// Cloud Storage. This is the entity enforced by ownership security rules.
class Book {
  final String id;
  final String title;
  final String authorId;
  final String isbn;
  final String genre;
  final String coverImageUrl;
  final int copiesAvailable;
  final String ownerId;
  final DateTime createdAt;

  Book({
    required this.id,
    required this.title,
    required this.authorId,
    required this.isbn,
    required this.genre,
    this.coverImageUrl = '',
    required this.copiesAvailable,
    required this.ownerId,
    required this.createdAt,
  });

  factory Book.fromMap(String id, Map<String, dynamic> data) {
    return Book(
      id: id,
      title: data['title'] ?? '',
      authorId: data['authorId'] ?? '',
      isbn: data['isbn'] ?? '',
      genre: data['genre'] ?? '',
      coverImageUrl: data['coverImageUrl'] ?? '',
      copiesAvailable: data['copiesAvailable'] ?? 0,
      ownerId: data['ownerId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'authorId': authorId,
      'isbn': isbn,
      'genre': genre,
      'coverImageUrl': coverImageUrl,
      'copiesAvailable': copiesAvailable,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Book copyWith({
    String? title,
    String? authorId,
    String? isbn,
    String? genre,
    String? coverImageUrl,
    int? copiesAvailable,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      authorId: authorId ?? this.authorId,
      isbn: isbn ?? this.isbn,
      genre: genre ?? this.genre,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      copiesAvailable: copiesAvailable ?? this.copiesAvailable,
      ownerId: ownerId,
      createdAt: createdAt,
    );
  }
}
