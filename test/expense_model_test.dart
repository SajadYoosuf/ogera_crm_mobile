// Tests for the Expense model's JSON parsing.
//
// WHY: the backend sends `amount` as a string ("250.00") because it is a
// Decimal. These tests make sure both string and number amounts still parse,
// so the Expenses list and the create flow don't break again.

import 'package:flutter_test/flutter_test.dart';
import 'package:ogera_crm_mobile/models/expense.dart';

Map<String, dynamic> _expenseJson({required Object amount}) => {
  'id': 7,
  'employee_id': 3,
  'employee_name': 'Asha',
  'title': 'Fuel to site',
  'category': 'petrol',
  'amount': amount,
  'bill_photo_url': null,
  'status': 'pending',
  'rejection_reason': null,
  'reviewed_by': null,
  'reviewed_by_name': null,
  'reviewed_at': null,
  'created_at': '2026-10-24T10:00:00',
};

void main() {
  group('Expense.fromJson amount', () {
    test('parses a decimal string from the backend', () {
      final expense = Expense.fromJson(_expenseJson(amount: '250.00'));
      expect(expense.amount, 250.0);
    });

    test('parses a plain JSON number', () {
      final expense = Expense.fromJson(_expenseJson(amount: 99.5));
      expect(expense.amount, 99.5);
    });

    test('throws a FormatException for a non-numeric string', () {
      expect(
        () => Expense.fromJson(_expenseJson(amount: 'abc')),
        throwsFormatException,
      );
    });
  });
}
