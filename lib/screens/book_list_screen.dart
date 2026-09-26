import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'book_detail_screen.dart';

class BookListScreen extends StatefulWidget {
  final VoidCallback? onBorrowedNavigateToLoans;
  const BookListScreen({super.key, this.onBorrowedNavigateToLoans});

  @override
  State<BookListScreen> createState() => _BookListScreenState();
}

class _BookListScreenState extends State<BookListScreen> {
  final _firestoreService = FirestoreService();
  final _authService = AuthService();
  bool _showMineOnly = false;

  late final Stream<List<Book>> _allBooksStream;
  late final Stream<List<Book>> _myBooksStream;

  @override
  void initState() {
    super.initState();
    _allBooksStream = _firestoreService.streamAllBooks();
    _myBooksStream = _firestoreService.streamMyBooks(_authService.currentUser!.uid);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('All Books'), icon: Icon(Icons.public)),
              ButtonSegment(value: true, label: Text('My Books'), icon: Icon(Icons.person)),
            ],
            selected: {_showMineOnly},
            onSelectionChanged: (selection) {
              setState(() => _showMineOnly = selection.first);
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Book>>(
            stream: _showMineOnly ? _myBooksStream : _allBooksStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final books = snapshot.data ?? [];
              if (books.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _showMineOnly
                          ? "You haven't added any books yet. Tap + to add one."
                          : 'No books yet. Tap + to add the first one.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: books.length,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Card(
                    child: ListTile(
                      leading: book.coverImageUrl.isNotEmpty
                          ? CircleAvatar(backgroundImage: NetworkImage(book.coverImageUrl))
                          : const CircleAvatar(child: Icon(Icons.book)),
                      title: Text(book.title),
                      subtitle: Text('${book.genre} · ${book.copiesAvailable} available'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookDetailScreen(
                              bookId: book.id,
                              onBorrowed: widget.onBorrowedNavigateToLoans,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
