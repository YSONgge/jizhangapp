import 'package:flutter/foundation.dart';
import 'package:expense_tracker/data/models/account.dart';
import 'package:expense_tracker/database/database_helper.dart';

class AccountProvider with ChangeNotifier {
  List<Account> _accounts = [];
  bool _isLoading = false;
  String? _error;

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalAssets {
    return _accounts
        .where((acc) => acc.type != 'credit' && acc.type != 'receivable')
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get totalDebts {
    return _accounts
        .where((acc) => acc.type == 'credit' || acc.type == 'receivable')
        .fold(0.0, (sum, acc) => sum + acc.balance);
  }

  double get netAssets => totalAssets - totalDebts;

  AccountProvider() {}

  Future<void> loadAccounts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _accounts = await DatabaseHelper.instance.getAllAccounts();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('账户加载失败: $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Account? getAccountById(String id) {
    try {
      return _accounts.firstWhere((acc) => acc.id == id);
    } catch (e) {
      return null;
    }
  }

  Account? getAccountByName(String name) {
    try {
      return _accounts.firstWhere((acc) => acc.name == name);
    } catch (e) {
      return null;
    }
  }

  Future<void> updateAccountBalance(String accountId, double amountChange) async {
    await DatabaseHelper.instance.updateAccountBalance(accountId, amountChange);

    final accountIndex = _accounts.indexWhere((acc) => acc.id == accountId);
    if (accountIndex != -1) {
      final updatedAccount = _accounts[accountIndex].copyWith(
        balance: _accounts[accountIndex].balance + amountChange,
      );
      _accounts[accountIndex] = updatedAccount;
      notifyListeners();
    }
  }

  Future<void> updateTwoAccountsBalance(String fromAccountId, String toAccountId, double amount) async {
    await updateAccountBalance(fromAccountId, -amount);
    await updateAccountBalance(toAccountId, amount);
  }

  Future<void> recalculateBalances() async {
    for (var account in _accounts) {
      final balance = await DatabaseHelper.instance.calculateAccountBalance(account.id);
      final index = _accounts.indexWhere((acc) => acc.id == account.id);
      if (index != -1) {
        _accounts[index] = account.copyWith(balance: balance);
      }
    }
    notifyListeners();
  }
}
