enum TransactionType {
  expense,   // 支出
  income,    // 收入
  transfer,  // 转账
  adjust,    // 余额调整
}

extension TransactionTypeExtension on TransactionType {
  String get displayName {
    switch (this) {
      case TransactionType.expense:
        return '支出';
      case TransactionType.income:
        return '收入';
      case TransactionType.transfer:
        return '转账';
      case TransactionType.adjust:
        return '调整';
    }
  }

  String get value {
    switch (this) {
      case TransactionType.expense:
        return 'expense';
      case TransactionType.income:
        return 'income';
      case TransactionType.transfer:
        return 'transfer';
      case TransactionType.adjust:
        return 'adjust';
    }
  }
}
