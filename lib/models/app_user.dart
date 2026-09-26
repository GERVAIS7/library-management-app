import 'package:cloud_firestore/cloud_firestore.dart';

/// Entity 1: User — the authenticated Firebase user's profile document,
/// keyed by UID. This is the "owner" entity referenced by Book and Loan.
class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String bio;
  final String photoUrl;
  final DateTime memberSince;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.bio = '',
    this.photoUrl = '',
    required this.memberSince,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      memberSince: (data['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'photoUrl': photoUrl,
      'memberSince': Timestamp.fromDate(memberSince),
    };
  }
}
