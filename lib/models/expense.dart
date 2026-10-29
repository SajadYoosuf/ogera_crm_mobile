/// Expense status values — mirrors the backend EXPENSE_STATUSES tuple.
enum ExpenseStatus {
  pending('pending', 'Pending'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected');

  const ExpenseStatus(this.value, this.label);
  final String value;
  final String label;

  static ExpenseStatus fromValue(String value) {
    return ExpenseStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => ExpenseStatus.pending,
    );
  }
}

/// Expense category values — mirrors the backend EXPENSE_CATEGORIES tuple.
enum ExpenseCategory {
  petrol('petrol', 'Petrol'),
  food('food', 'Food'),
  maintenance('maintenance', 'Maintenance'),
  accommodation('accommodation', 'Accommodation'),
  other('other', 'Other');

  const ExpenseCategory(this.value, this.label);
  final String value;
  final String label;

  static ExpenseCategory fromValue(String value) {
    return ExpenseCategory.values.firstWhere(
      (c) => c.value == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}

/// A single staff expense claim.
///
/// Maps to the backend `Expense` model at GET /expenses/*.
/// [amount] is immutable — it is set at creation and never changes.
class Expense {
  const Expense({
    required this.id,
    required this.employeeId,
    this.employeeName,
    required this.title,
    required this.category,
    required this.amount,
    this.billPhotoUrl,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    required this.createdAt,
  });

  final int id;
  final int employeeId;
  final String? employeeName;
  final String title;
  final ExpenseCategory category;
  final double amount;
  final String? billPhotoUrl;
  final ExpenseStatus status;
  final String? rejectionReason;
  final int? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final DateTime createdAt;

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as int,
      employeeId: json['employee_id'] as int,
      employeeName: json['employee_name'] as String?,
      title: json['title'] as String,
      category: ExpenseCategory.fromValue(json['category'] as String? ?? 'other'),
      amount: parseExpenseAmount(json['amount']),
      billPhotoUrl: json['bill_photo_url'] as String?,
      status: ExpenseStatus.fromValue(json['status'] as String? ?? 'pending'),
      rejectionReason: json['rejection_reason'] as String?,
      reviewedBy: json['reviewed_by'] as int?,
      reviewedByName: json['reviewed_by_name'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Reads a money amount from the API.
///
/// WHY: the backend stores amounts as Decimal (exact cents) and Pydantic sends
/// them as JSON strings, e.g. "250.00". A plain `as num` cast crashes on that
/// string, so this accepts either a number or a numeric string.
///
/// Input: the raw JSON value. Output: the amount as a double.
/// Throws a FormatException if the value is neither a number nor a numeric string.
double parseExpenseAmount(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid expense amount: $value');
}

/// Payload for creating a new expense.
class ExpenseDraft {
  const ExpenseDraft({
    required this.title,
    required this.category,
    required this.amount,
  });

  final String title;
  final ExpenseCategory category;
  final double amount;

  Map<String, dynamic> toJson() => {
    'title': title,
    'category': category.value,
    'amount': amount,
  };
}
