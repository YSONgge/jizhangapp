import 'package:flutter/foundation.dart';
import 'package:expense_tracker/data/models/transaction.dart' as models;
import 'package:expense_tracker/data/models/transaction_type.dart';
import 'package:expense_tracker/database/database_helper.dart';

class TransactionProvider with ChangeNotifier {
  List<models.Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<models.Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  TransactionProvider() {
    // 不在构造函数中加载数据，避免阻塞
  }

  Future<void> loadTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = await DatabaseHelper.instance.getAllTransactions();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(models.Transaction transaction) async {
    try {
      await DatabaseHelper.instance.insertTransaction(transaction);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateTransaction(models.Transaction transaction) async {
    try {
      await DatabaseHelper.instance.updateTransaction(transaction);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String id) async {
    try {
      await DatabaseHelper.instance.deleteTransaction(id);
      await loadTransactions();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // 获取今日支出
  double getTodayExpense() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.isAfter(startOfDay) &&
            t.date.isBefore(endOfDay))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取本月支出
  double getMonthExpense() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    final start = DateTime(startOfMonth.year, startOfMonth.month, startOfMonth.day);

    return _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.isAfter(start) &&
            t.date.isBefore(endOfMonth))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取今日收入
  double getTodayIncome() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return _transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.isAfter(startOfDay) &&
            t.date.isBefore(endOfDay))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取本月收入
  double getMonthIncome() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);
    final start = DateTime(startOfMonth.year, startOfMonth.month, startOfMonth.day);

    return _transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.isAfter(start) &&
            t.date.isBefore(endOfMonth))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取本季度支出
  double getQuarterExpense() {
    final now = DateTime.now();
    final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final startOfQuarter = DateTime(now.year, quarterStartMonth, 1);
    final endOfQuarter = DateTime(now.year, quarterStartMonth + 3, 1);

    return _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.isAfter(startOfQuarter) &&
            t.date.isBefore(endOfQuarter))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取本季度收入
  double getQuarterIncome() {
    final now = DateTime.now();
    final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    final startOfQuarter = DateTime(now.year, quarterStartMonth, 1);
    final endOfQuarter = DateTime(now.year, quarterStartMonth + 3, 1);

    return _transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.isAfter(startOfQuarter) &&
            t.date.isBefore(endOfQuarter))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取本年度支出
  double getYearExpense() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year + 1, 1, 1);

    return _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.isAfter(startOfYear) &&
            t.date.isBefore(endOfYear))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取本年度收入
  double getYearIncome() {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year + 1, 1, 1);

    return _transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.date.isAfter(startOfYear) &&
            t.date.isBefore(endOfYear))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 按日期分组交易记录
  Map<String, List<models.Transaction>> getTransactionsByDate() {
    final Map<String, List<models.Transaction>> grouped = {};
    for (var transaction in _transactions) {
      final dateKey = _formatDateKey(transaction.date);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(transaction);
    }
    return grouped;
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final transactionDate = DateTime(date.year, date.month, date.day);

    if (transactionDate == today) {
      return '今天';
    } else if (transactionDate == yesterday) {
      return '昨天';
    } else {
      return '${date.month}月${date.day}日';
    }
  }

  DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // 按归属人统计（支持时间范围筛选）
  Map<String, double> getExpenseByOwner(DateTime start, DateTime end) {
    final Map<String, double> result = {};

    for (var t in _transactions) {
      if (t.type == TransactionType.expense &&
          t.date.isAfter(start) &&
          t.date.isBefore(end) &&
          t.owner != null) {
        final owner = t.owner!;
        result[owner] = (result[owner] ?? 0.0) + t.amount;
      }
    }

    return result;
  }

  // 按归属人统计收入
  Map<String, double> getIncomeByOwner(DateTime start, DateTime end) {
    final Map<String, double> result = {};

    for (var t in _transactions) {
      if (t.type == TransactionType.income &&
          t.date.isAfter(start) &&
          t.date.isBefore(end) &&
          t.owner != null) {
        final owner = t.owner!;
        result[owner] = (result[owner] ?? 0.0) + t.amount;
      }
    }

    return result;
  }

  // 获取某个归属人的支出
  double getOwnerExpense(String owner, DateTime start, DateTime end) {
    return _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.owner == owner &&
            t.date.isAfter(start) &&
            t.date.isBefore(end))
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  // 获取某个归属人的收入
  double getOwnerIncome(String owner, DateTime start, DateTime end) {
    return _transactions
        .where((t) =>
            t.type == TransactionType.income &&
            t.owner == owner &&
            t.date.isAfter(start) &&
            t.date.isBefore(end))
        .fold(0.0, (sum, t) => sum + t.amount);
  }
}
