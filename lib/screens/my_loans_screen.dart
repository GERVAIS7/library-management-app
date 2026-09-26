import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/loan.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class MyLoansScreen extends StatelessWidget {
  const MyLoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final authService = AuthService();
    final uid = authService.currentUser!.uid;

    return StreamBuilder<List<Loan>>(
      stream: firestoreService.streamMyLoans(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final loans = snapshot.data ?? [];
        if (loans.isEmpty) {
          return const Center(child: Text('You have no loans yet.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            return FutureBuilder<Book?>(
              future: firestoreService.getBook(loan.bookId),
              builder: (context, bookSnap) {
                final book = bookSnap.data;
                final isReturned = loan.status == LoanStatus.returned;
                final isOverdue = !isReturned && DateTime.now().isAfter(loan.dueDate);

                IconData statusIcon;
                Color statusColor;
                String statusLabel;
                if (isReturned) {
                  statusIcon = Icons.check_circle;
                  statusColor = Colors.green;
                  statusLabel = 'Returned';
                } else if (isOverdue) {
                  statusIcon = Icons.warning_amber_rounded;
                  statusColor = Colors.red;
                  statusLabel = 'Overdue';
                } else {
                  statusIcon = Icons.schedule;
                  statusColor = Colors.orange;
                  statusLabel = 'Borrowed';
                }

                return Card(
                  child: ListTile(
                    leading: Icon(statusIcon, color: statusColor),
                    title: Text(book?.title ?? 'Loading...'),
                    subtitle: Text(
                      'Due: ${DateFormat.yMMMd().format(loan.dueDate)} · $statusLabel',
                      style: isOverdue ? const TextStyle(color: Colors.red) : null,
                    ),
                    trailing: !isReturned
                        ? TextButton(
                            onPressed: () => firestoreService.returnLoan(loan),
                            child: const Text('Return'),
                          )
                        : null,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
