import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanStatus { borrowed, returned, overdue }

LoanStatus loanStatusFromString(String s) {
  return LoanStatus.values.firstWhere(
    (e) => e.name == s,
    orElse: () => LoanStatus.borrowed,
  );
}

/// Entity 4: Loan — the join entity linking a User and a Book
/// (loan.userId == user.uid, loan.bookId == book.id).
class Loan {
  final String id;
  final String userId;
  final String bookId;
  final DateTime borrowedDate;
  final DateTime dueDate;
  final DateTime? returnedDate;
  final LoanStatus status;

  Loan({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.borrowedDate,
    required this.dueDate,
    this.returnedDate,
    this.status = LoanStatus.borrowed,
  });

  factory Loan.fromMap(String id, Map<String, dynamic> data) {
    return Loan(
      id: id,
      userId: data['userId'] ?? '',
      bookId: data['bookId'] ?? '',
      borrowedDate: (data['borrowedDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      returnedDate: (data['returnedDate'] as Timestamp?)?.toDate(),
      status: loanStatusFromString(data['status'] ?? 'borrowed'),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bookId': bookId,
      'borrowedDate': Timestamp.fromDate(borrowedDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'returnedDate': returnedDate != null ? Timestamp.fromDate(returnedDate!) : null,
      'status': status.name,
    };
  }
}
