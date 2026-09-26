import 'package:flutter/material.dart';
import '../models/author.dart';
import '../models/book.dart';
import '../models/loan.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../services/ad_service.dart';
import 'book_form_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final String bookId;
  final VoidCallback? onBorrowed;
  const BookDetailScreen({super.key, required this.bookId, this.onBorrowed});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _authService = AuthService();
  final _adService = AdService();
  bool _isBorrowing = false;

  @override
  void initState() {
    super.initState();
    _adService.loadInterstitial();
  }

  Future<void> _borrowBook(Book book) async {
    setState(() => _isBorrowing = true);
    try {
      final loan = Loan(
        id: '',
        userId: _authService.currentUser!.uid,
        bookId: book.id,
        borrowedDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 14)),
      );
      await _firestoreService.createLoan(loan);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Book borrowed! Due in 14 days.')));
        // Interstitial shown after this completed action (Day 12 rule).
        _adService.showInterstitialIfReady();

        // Take the user straight to My Loans so they see the result
        // of borrowing immediately, instead of leaving them on the
        // book detail page.
        Navigator.pop(context);
        widget.onBorrowed?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not borrow: $e')));
      }
    } finally {
      if (mounted) setState(() => _isBorrowing = false);
    }
  }

  Future<void> _confirmDelete(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book?'),
        content: Text('This will permanently remove "${book.title}". This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // Clean up the cover image in Storage too, if one was uploaded.
      // Non-fatal: proceed with deleting the book even if this fails
      // (e.g. Storage not enabled, or image already gone).
      if (book.coverImageUrl.isNotEmpty) {
        try {
          await _storageService.deleteImage(book.coverImageUrl);
        } catch (_) {
          // Ignore — the book deletion below still proceeds.
        }
      }
      await _firestoreService.deleteBook(book.id);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Details')),
      body: FutureBuilder<Book?>(
        future: _firestoreService.getBook(widget.bookId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final book = snapshot.data;
          if (book == null) {
            return const Center(child: Text('Book not found.'));
          }

          final isOwner = book.ownerId == _authService.currentUser?.uid;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (book.coverImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(book.coverImageUrl, height: 220, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 16),
                Text(book.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                FutureBuilder<Author?>(
                  future: _firestoreService.getAuthor(book.authorId),
                  builder: (context, authorSnap) {
                    return Text('by ${authorSnap.data?.name ?? '...'}',
                        style: const TextStyle(fontSize: 16, color: Colors.grey));
                  },
                ),
                const SizedBox(height: 12),
                Text('Genre: ${book.genre}'),
                Text('ISBN: ${book.isbn}'),
                Text('Copies available: ${book.copiesAvailable}'),
                const SizedBox(height: 24),
                if (!isOwner)
                  FilledButton.icon(
                    onPressed: (book.copiesAvailable > 0 && !_isBorrowing)
                        ? () => _borrowBook(book)
                        : null,
                    icon: const Icon(Icons.bookmark_add),
                    label: Text(book.copiesAvailable > 0 ? 'Borrow this Book' : 'No copies available'),
                  ),
                if (isOwner) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => BookFormScreen(book: book)),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Book'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _confirmDelete(book),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Delete Book', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
