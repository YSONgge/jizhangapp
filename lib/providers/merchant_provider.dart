import 'package:flutter/foundation.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/services/text_parser.dart';

class MerchantProvider with ChangeNotifier {
  List<Map<String, dynamic>> _merchants = [];
  bool _isLoading = false;

  List<Map<String, dynamic>> get merchants => _merchants;
  bool get isLoading => _isLoading;

  List<String> get merchantNames => _merchants.map((m) => m['name'] as String).toList();

  Future<void> loadMerchants() async {
    _isLoading = true;
    notifyListeners();

    try {
      _merchants = await DatabaseHelper.instance.getAllMerchants();
      TextParser.updateUserData(merchants: merchantNames);
    } catch (e) {
      debugPrint('商家加载失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addMerchant(String name) async {
    await DatabaseHelper.instance.insertMerchant({
      'name': name,
      'sort_order': _merchants.length,
    });
    await loadMerchants();
  }

  Future<void> updateMerchant(String id, String name) async {
    await DatabaseHelper.instance.updateMerchant(id, {'name': name});
    await loadMerchants();
  }

  Future<void> deleteMerchant(String id) async {
    final merchant = _merchants.firstWhere((m) => m['id'] == id);
    if (merchant['is_default'] == 1 && _merchants.length <= 1) {
      throw Exception('至少需要保留1个商家');
    }
    await DatabaseHelper.instance.deleteMerchant(id);
    await loadMerchants();
  }
}
