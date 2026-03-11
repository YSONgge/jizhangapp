class Account {
  final String id;
  final String name;
  final String type;
  final String category;
  final double balance;
  final String icon;
  final int sortOrder;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.category,
    this.balance = 0,
    required this.icon,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'category': category,
      'balance': balance,
      'icon': icon,
      'sort_order': sortOrder,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      category: map['category'] ?? '现金',
      balance: map['balance']?.toDouble() ?? 0.0,
      icon: map['icon'],
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  Account copyWith({
    String? id,
    String? name,
    String? type,
    String? category,
    double? balance,
    String? icon,
    int? sortOrder,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      category: category ?? this.category,
      balance: balance ?? this.balance,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
