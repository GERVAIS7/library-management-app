import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

/// Handles uploading Book cover images to Cloud Storage and returning
/// the download URL to be saved on the Book document in Firestore.
///
/// Uses raw bytes (Uint8List) rather than dart:io File so this works
/// identically on web (Chrome) and on Android/iOS.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads under: book_covers/{ownerId}/{uuid}.jpg
  /// Matches storage.rules, which restrict writes to the owner's own folder.
  Future<String> uploadBookCover({
    required Uint8List bytes,
    required String ownerId,
  }) async {
    final fileName = '${const Uuid().v4()}.jpg';
    final ref = _storage.ref().child('book_covers/$ownerId/$fileName');

    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }

  Future<void> deleteImage(String downloadUrl) async {
    try {
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
    } catch (_) {
      // Non-fatal: if the image is already gone, ignore it.
    }
  }
}
