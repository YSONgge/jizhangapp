class Category {
  final String id;
  final String name;
  final String icon;
  final String color;
  final int sortOrder;
  final String? parentId;
  final bool isCustom;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
    this.parentId,
    this.isCustom = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'sort_order': sortOrder,
      'parent_id': parentId,
      'is_custom': isCustom ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      icon: map['icon'],
      color: map['color'],
      sortOrder: map['sort_order'] ?? 0,
      parentId: map['parent_id'],
      isCustom: map['is_custom'] == 1,
    );
  }

  Category copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    int? sortOrder,
    String? parentId,
    bool? isCustom,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId ?? this.parentId,
      isCustom: isCustom ?? this.isCustom,
    );
  }
}
