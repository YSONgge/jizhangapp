import 'transaction_type.dart';

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String? categoryId; // 转账时可以为空
  final String accountId;
  final String? targetAccountId;
  final String? merchant;
  final String? owner;
  final String? project;
  final String remark;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? inputRaw;
  final bool userCorrected;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    required this.accountId,
    this.targetAccountId,
    this.merchant,
    this.owner,
    this.project,
    this.remark = '',
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.inputRaw,
    this.userCorrected = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category_id': categoryId,
      'account_id': accountId,
      'target_account_id': targetAccountId,
      'merchant': merchant,
      'owner': owner,
      'project': project,
      'remark': remark,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'input_raw': inputRaw,
      'user_corrected': userCorrected ? 1 : 0,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'],
      type: _parseType(map['type']),
      amount: map['amount'],
      categoryId: map['category_id'],
      accountId: map['account_id'],
      targetAccountId: map['target_account_id'],
      merchant: map['merchant'],
      owner: map['owner'],
      project: map['project'],
      remark: map['remark'] ?? '',
      date: DateTime.parse(map['date']),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      inputRaw: map['input_raw'],
      userCorrected: map['user_corrected'] == 1,
    );
  }

  static TransactionType _parseType(String typeStr) {
    return TransactionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => TransactionType.expense,
    );
  }

  Transaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? categoryId,
    String? accountId,
    String? targetAccountId,
    String? merchant,
    String? owner,
    String? project,
    String? remark,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? inputRaw,
    bool? userCorrected,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      targetAccountId: targetAccountId ?? this.targetAccountId,
      merchant: merchant ?? this.merchant,
      owner: owner ?? this.owner,
      project: project ?? this.project,
      remark: remark ?? this.remark,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      inputRaw: inputRaw ?? this.inputRaw,
      userCorrected: userCorrected ?? this.userCorrected,
    );
  }
}
