/// Entity 3: Author — referenced by Book (book.authorId == author.id),
/// but NOT owned by any single user. Any authenticated user can read it;
/// writes can be restricted or open depending on your rules design.
class Author {
  final String id;
  final String name;
  final String bio;
  final int birthYear;
  final String nationality;
  final String photoUrl;

  Author({
    required this.id,
    required this.name,
    this.bio = '',
    required this.birthYear,
    this.nationality = '',
    this.photoUrl = '',
  });

  factory Author.fromMap(String id, Map<String, dynamic> data) {
    return Author(
      id: id,
      name: data['name'] ?? '',
      bio: data['bio'] ?? '',
      birthYear: data['birthYear'] ?? 0,
      nationality: data['nationality'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'bio': bio,
      'birthYear': birthYear,
      'nationality': nationality,
      'photoUrl': photoUrl,
    };
  }
}
