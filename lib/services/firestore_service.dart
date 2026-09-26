import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/author.dart';
import '../models/book.dart';
import '../models/loan.dart';

/// Central Firestore service. Every read/write for every entity goes
/// through here so screens stay thin.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- USER ----------------

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id, doc.data()!);
  }

  Future<void> updateUser(AppUser user) {
    return _db.collection('users').doc(user.uid).update(user.toMap());
  }

  // ---------------- AUTHOR ----------------

  Stream<List<Author>> streamAuthors() {
    return _db.collection('authors').orderBy('name').snapshots().map(
          (snap) => snap.docs.map((d) => Author.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<Author?> getAuthor(String id) async {
    final doc = await _db.collection('authors').doc(id).get();
    if (!doc.exists) return null;
    return Author.fromMap(doc.id, doc.data()!);
  }

  Future<String> addAuthor(Author author) async {
    final ref = await _db.collection('authors').add(author.toMap());
    return ref.id;
  }

  Future<void> updateAuthor(Author author) {
    return _db.collection('authors').doc(author.id).update(author.toMap());
  }

  Future<void> deleteAuthor(String id) {
    return _db.collection('authors').doc(id).delete();
  }

  // ---------------- BOOK ----------------

  /// Real-time feed of ALL books (home/library feed).
  Stream<List<Book>> streamAllBooks() {
    return _db
        .collection('books')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Book.fromMap(d.id, d.data())).toList());
  }

  /// Real-time feed of only the books the current user owns ("My Books").
  /// Sorted client-side (not via .orderBy()) so this doesn't require a
  /// Firestore composite index.
  Stream<List<Book>> streamMyBooks(String ownerId) {
    return _db
        .collection('books')
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snap) {
      final books = snap.docs.map((d) => Book.fromMap(d.id, d.data())).toList();
      books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return books;
    });
  }

  Future<Book?> getBook(String id) async {
    final doc = await _db.collection('books').doc(id).get();
    if (!doc.exists) return null;
    return Book.fromMap(doc.id, doc.data()!);
  }

  Future<String> addBook(Book book) async {
    final ref = await _db.collection('books').add(book.toMap());
    return ref.id;
  }

  Future<void> updateBook(Book book) {
    return _db.collection('books').doc(book.id).update(book.toMap());
  }

  Future<void> deleteBook(String id) {
    return _db.collection('books').doc(id).delete();
  }

  // ---------------- LOAN ----------------

  /// Sorted client-side (not via .orderBy()) so this doesn't require a
  /// Firestore composite index.
  Stream<List<Loan>> streamMyLoans(String userId) {
    return _db
        .collection('loans')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final loans = snap.docs.map((d) => Loan.fromMap(d.id, d.data())).toList();
      loans.sort((a, b) => b.borrowedDate.compareTo(a.borrowedDate));
      return loans;
    });
  }

  Future<String> createLoan(Loan loan) async {
    final loanRef = _db.collection('loans').doc();
    final bookRef = _db.collection('books').doc(loan.bookId);

    final batch = _db.batch();
    batch.set(loanRef, loan.toMap());
    batch.update(bookRef, {'copiesAvailable': FieldValue.increment(-1)});
    await batch.commit();

    return loanRef.id;
  }

  Future<void> returnLoan(Loan loan) async {
    final loanRef = _db.collection('loans').doc(loan.id);
    final bookRef = _db.collection('books').doc(loan.bookId);

    final batch = _db.batch();
    batch.update(loanRef, {
      'status': LoanStatus.returned.name,
      'returnedDate': Timestamp.fromDate(DateTime.now()),
    });
    batch.update(bookRef, {'copiesAvailable': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> deleteLoan(String id) {
    return _db.collection('loans').doc(id).delete();
  }
}
