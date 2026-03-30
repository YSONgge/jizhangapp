import 'package:flutter/foundation.dart';
import 'package:expense_tracker/database/database_helper.dart';

class OwnerProvider with ChangeNotifier {
  List<Map<String, dynamic>> _owners = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get owners => _owners;
  bool get isLoading => _isLoading;

  List<String> get ownerNames => _owners.map((o) => o['name'] as String).toList();

  String get defaultOwner {
    final defaultOwner = _owners.firstWhere(
      (o) => o['is_default'] == 1,
      orElse: () => {'name': '本人'},
    );
    return defaultOwner['name'] as String;
  }

  Future<void> loadOwners() async {
    _isLoading = true;
    notifyListeners();

    try {
      _owners = await DatabaseHelper.instance.getAllOwners();
    } catch (e) {
      debugPrint('归属人加载失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOwner(String name) async {
    await DatabaseHelper.instance.insertOwner({
      'name': name,
      'sort_order': _owners.length,
    });
    await loadOwners();
  }

  Future<void> updateOwner(String id, String name) async {
    await DatabaseHelper.instance.updateOwner(id, {'name': name});
    await loadOwners();
  }

  Future<void> deleteOwner(String id) async {
    final account = _owners.firstWhere(
      (o) => o['id'] == id,
      orElse: () => throw Exception('归属人不存在'),
    );
    if (account['is_default'] == 1) {
      throw Exception('默认归属人不能删除');
    }
    await DatabaseHelper.instance.deleteOwner(id);
    await loadOwners();
  }
}
