import 'package:flutter/foundation.dart';
import 'package:expense_tracker/data/models/category.dart' as models;
import 'package:expense_tracker/database/database_helper.dart';

class CategoryProvider with ChangeNotifier {
  List<models.Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<models.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 根据类型筛选分类（支出/收入）
  List<models.Category> getExpenseCategories() {
    return _categories.where((cat) => cat.id.startsWith('cat_') && !cat.id.startsWith('cat_inc_')).toList();
  }

  List<models.Category> getIncomeCategories() {
    return _categories.where((cat) => cat.id.startsWith('cat_inc_')).toList();
  }

  CategoryProvider() {
    // 不在构造函数中加载数据，避免阻塞
  }

  Future<void> loadCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _categories = await DatabaseHelper.instance.getAllCategories();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  models.Category? getCategoryById(String id) {
    try {
      return _categories.firstWhere((cat) => cat.id == id);
    } catch (e) {
      return null;
    }
  }

  // 根据名称查找分类
  models.Category? getCategoryByName(String name) {
    try {
      return _categories.firstWhere((cat) => cat.name == name);
    } catch (e) {
      return null;
    }
  }

  // 获取父分类列表（支出）
  List<models.Category> getExpenseParentCategories() {
    final expenseCats = _categories.where((cat) => cat.id.startsWith('cat_') && !cat.id.startsWith('cat_inc_')).toList();
    return expenseCats.where((cat) => cat.parentId == null).toList();
  }

  // 获取父分类列表（收入）
  List<models.Category> getIncomeParentCategories() {
    final incomeCats = _categories.where((cat) => cat.id.startsWith('cat_inc_')).toList();
    return incomeCats.where((cat) => cat.parentId == null).toList();
  }

  // 获取子分类列表
  List<models.Category> getChildCategories(String parentId) {
    return _categories.where((cat) => cat.parentId == parentId).toList();
  }

  // 获取所有父分类（包括支出和收入）
  List<models.Category> getAllParentCategories() {
    return _categories.where((cat) => cat.parentId == null).toList();
  }

  // 判断是否为父分类
  bool isParentCategory(String categoryId) {
    final category = getCategoryById(categoryId);
    return category?.parentId == null;
  }

  // 获取父分类
  models.Category? getParentCategory(String categoryId) {
    final category = getCategoryById(categoryId);
    if (category?.parentId == null) {
      return null;
    }
    return getCategoryById(category!.parentId!);
  }
}
