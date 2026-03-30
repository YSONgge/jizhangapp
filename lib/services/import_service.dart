import 'dart:convert';
import 'package:expense_tracker/data/models/transaction.dart';
import 'package:expense_tracker/data/models/category.dart';
import 'package:expense_tracker/data/models/account.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:uuid/uuid.dart';

enum ImportMode { merge, replace, skipExisting }

class ImportResult {
  final int totalRecords;
  final int successCount;
  final int failCount;
  final List<String> errors;

  ImportResult({
    required this.totalRecords,
    required this.successCount,
    required this.failCount,
    required this.errors,
  });
}

class ImportService {
  static final ImportService instance = ImportService._();
  ImportService._();
  
  final _uuid = const Uuid();
  final _db = DatabaseHelper.instance;

  Future<Map<String, dynamic>> parseImportFile(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      
      if (!data.containsKey('version') || !data.containsKey('data')) {
        return {
          'valid': false,
          'error': '无效的备份文件格式',
        };
      }

      final exportData = data['data'] as Map<String, dynamic>;
      
      int transactionCount = 0;
      int categoryCount = 0;
      int accountCount = 0;
      int merchantCount = 0;
      int ownerCount = 0;

      String? earliestDate;
      String? latestDate;

      if (exportData.containsKey('transactions')) {
        final transactions = exportData['transactions'] as List;
        transactionCount = transactions.length;
        if (transactions.isNotEmpty) {
          final dates = transactions.map((t) => t['date'] as String).toList()..sort();
          earliestDate = dates.first;
          latestDate = dates.last;
        }
      }
      if (exportData.containsKey('categories')) {
        categoryCount = (exportData['categories'] as List).length;
      }
      if (exportData.containsKey('accounts')) {
        accountCount = (exportData['accounts'] as List).length;
      }
      if (exportData.containsKey('merchants')) {
        merchantCount = (exportData['merchants'] as List).length;
      }
      if (exportData.containsKey('owners')) {
        ownerCount = (exportData['owners'] as List).length;
      }

      return {
        'valid': true,
        'transaction_count': transactionCount,
        'category_count': categoryCount,
        'account_count': accountCount,
        'merchant_count': merchantCount,
        'owner_count': ownerCount,
        'total_records': transactionCount + categoryCount + accountCount + merchantCount + ownerCount,
        'earliest_date': earliestDate,
        'latest_date': latestDate,
        'exported_at': data['exported_at'],
        'raw_data': exportData,
      };
    } catch (e) {
      return {
        'valid': false,
        'error': '解析文件失败: ${e.toString()}',
      };
    }
  }

  Future<ImportResult> importData(
    Map<String, dynamic> exportData,
    ImportMode mode,
  ) async {
    final errors = <String>[];
    int totalRecords = 0;
    int successCount = 0;
    int failCount = 0;

    if (mode == ImportMode.replace) {
      await _db.clearAllData();
    }

    if (exportData.containsKey('categories')) {
      final result = await _importCategories(exportData['categories'] as List, mode, errors);
      totalRecords += result['total'] ?? 0;
      successCount += result['success'] ?? 0;
      failCount += result['fail'] ?? 0;
    }

    if (exportData.containsKey('accounts')) {
      final result = await _importAccounts(exportData['accounts'] as List, mode, errors);
      totalRecords += result['total'] ?? 0;
      successCount += result['success'] ?? 0;
      failCount += result['fail'] ?? 0;
    }

    if (exportData.containsKey('transactions')) {
      final result = await _importTransactions(exportData['transactions'] as List, mode, errors);
      totalRecords += result['total'] ?? 0;
      successCount += result['success'] ?? 0;
      failCount += result['fail'] ?? 0;
    }

    if (exportData.containsKey('merchants')) {
      final result = await _importMerchants(exportData['merchants'] as List, mode, errors);
      totalRecords += result['total'] ?? 0;
      successCount += result['success'] ?? 0;
      failCount += result['fail'] ?? 0;
    }

    if (exportData.containsKey('owners')) {
      final result = await _importOwners(exportData['owners'] as List, mode, errors);
      totalRecords += result['total'] ?? 0;
      successCount += result['success'] ?? 0;
      failCount += result['fail'] ?? 0;
    }

    if (exportData.containsKey('balance_changes')) {
      final result = await _importBalanceChanges(exportData['balance_changes'] as List, mode, errors);
      totalRecords += result['total'] ?? 0;
      successCount += result['success'] ?? 0;
      failCount += result['fail'] ?? 0;
    }

    return ImportResult(
      totalRecords: totalRecords,
      successCount: successCount,
      failCount: failCount,
      errors: errors,
    );
  }

  Future<Map<String, int>> _importCategories(
    List categories,
    ImportMode mode,
    List<String> errors,
  ) async {
    int total = 0;
    int success = 0;
    int fail = 0;

    for (var cat in categories) {
      total++;
      try {
        if (mode == ImportMode.skipExisting || mode == ImportMode.merge) {
          final existing = await _db.getCategoryById(cat['id']);
          if (existing != null) continue;
        }

        await _db.insertCategory(Category.fromMap(cat));
        success++;
      } catch (e) {
        fail++;
        errors.add('分类导入失败: ${cat['name'] ?? cat['id']} - $e');
      }
    }

    return {'total': total, 'success': success, 'fail': fail};
  }

  Future<Map<String, int>> _importAccounts(
    List accounts,
    ImportMode mode,
    List<String> errors,
  ) async {
    int total = 0;
    int success = 0;
    int fail = 0;

    for (var acc in accounts) {
      total++;
      try {
        // 检查账户是否已存在（所有模式都需要检查）
        final existing = await _db.getAccountById(acc['id']);
        
        if (existing != null) {
          // 合并模式或覆盖模式：更新账户信息
          if (mode == ImportMode.merge || mode == ImportMode.replace) {
            final updatedAccount = Account(
              id: acc['id'],
              name: acc['name'] ?? existing.name,
              type: acc['type'] ?? existing.type,
              category: acc['category'] ?? existing.category,
              balance: acc['balance'] ?? existing.balance,
              icon: acc['icon'] ?? existing.icon,
              sortOrder: acc['sort_order'] ?? existing.sortOrder,
            );
            await _db.updateAccount(updatedAccount);
          }
          // skipExisting 模式：保留现有账户
          success++;
          continue;
        }

        // 插入新账户
        await _db.insertAccount(Account.fromMap(acc));
        success++;
      } catch (e) {
        fail++;
        errors.add('账户导入失败: ${acc['name'] ?? acc['id']} - $e');
      }
    }

    return {'total': total, 'success': success, 'fail': fail};
  }

  Future<Map<String, int>> _importTransactions(
    List transactions,
    ImportMode mode,
    List<String> errors,
  ) async {
    int total = 0;
    int success = 0;
    int fail = 0;

    for (var trans in transactions) {
      total++;
      try {
        if (mode == ImportMode.skipExisting || mode == ImportMode.merge) {
          final existing = await _db.getTransactionById(trans['id']);
          if (existing != null) continue;
        }

        await _db.insertTransactionWithoutBalanceUpdate(Transaction.fromMap(trans));
        success++;
      } catch (e) {
        fail++;
        errors.add('交易导入失败: ${trans['id']} - $e');
      }
    }

    return {'total': total, 'success': success, 'fail': fail};
  }

  Future<Map<String, int>> _importMerchants(
    List merchants,
    ImportMode mode,
    List<String> errors,
  ) async {
    int total = 0;
    int success = 0;
    int fail = 0;

    for (var merchant in merchants) {
      total++;
      try {
        final merchantMap = Map<String, dynamic>.from(merchant);
        if (!merchantMap.containsKey('id')) {
          merchantMap['id'] = _uuid.v4();
        }
        if (!merchantMap.containsKey('created_at')) {
          merchantMap['created_at'] = DateTime.now().toIso8601String();
        }
        
        if (mode == ImportMode.skipExisting) {
          final existingMerchants = await _db.getAllMerchants();
          final exists = existingMerchants.any((m) => m['name'] == merchantMap['name']);
          if (exists) {
            success++;
            continue;
          }
        }
        
        if (mode == ImportMode.merge || mode == ImportMode.replace) {
          final existingMerchants = await _db.getAllMerchants();
          final existingById = existingMerchants.any((m) => m['id'] == merchantMap['id']);
          final existingByName = existingMerchants.any((m) => m['name'] == merchantMap['name']);
          
          if (existingById) {
            await _db.updateMerchant(merchantMap['id'], merchantMap);
            success++;
            continue;
          } else if (existingByName) {
            final existingMerchant = existingMerchants.firstWhere((m) => m['name'] == merchantMap['name']);
            await _db.updateMerchant(existingMerchant['id'], merchantMap);
            success++;
            continue;
          }
        }
        
        await _db.insertMerchant(merchantMap);
        success++;
      } catch (e) {
        fail++;
        errors.add('商家导入失败: ${merchant['name'] ?? merchant['id']} - $e');
      }
    }

    return {'total': total, 'success': success, 'fail': fail};
  }

  Future<Map<String, int>> _importOwners(
    List owners,
    ImportMode mode,
    List<String> errors,
  ) async {
    int total = 0;
    int success = 0;
    int fail = 0;

    for (var owner in owners) {
      total++;
      try {
        final ownerMap = Map<String, dynamic>.from(owner);
        if (!ownerMap.containsKey('id')) {
          ownerMap['id'] = _uuid.v4();
        }
        if (!ownerMap.containsKey('created_at')) {
          ownerMap['created_at'] = DateTime.now().toIso8601String();
        }
        
        if (mode == ImportMode.skipExisting) {
          final existingOwners = await _db.getAllOwners();
          final exists = existingOwners.any((o) => o['name'] == ownerMap['name']);
          if (exists) {
            success++;
            continue;
          }
        }
        
        if (mode == ImportMode.merge || mode == ImportMode.replace) {
          final existingOwners = await _db.getAllOwners();
          final existingById = existingOwners.any((o) => o['id'] == ownerMap['id']);
          final existingByName = existingOwners.any((o) => o['name'] == ownerMap['name']);
          
          if (existingById) {
            await _db.updateOwner(ownerMap['id'], ownerMap);
            success++;
            continue;
          } else if (existingByName) {
            final existingOwner = existingOwners.firstWhere((o) => o['name'] == ownerMap['name']);
            await _db.updateOwner(existingOwner['id'], ownerMap);
            success++;
            continue;
          }
        }
        
        await _db.insertOwner(ownerMap);
        success++;
      } catch (e) {
        fail++;
        errors.add('归属人导入失败: ${owner['name'] ?? owner['id']} - $e');
      }
    }

    return {'total': total, 'success': success, 'fail': fail};
  }

  Future<Map<String, int>> _importBalanceChanges(
    List balanceChanges,
    ImportMode mode,
    List<String> errors,
  ) async {
    int total = 0;
    int success = 0;
    int fail = 0;

    for (var change in balanceChanges) {
      total++;
      try {
        final changeMap = Map<String, dynamic>.from(change);
        if (!changeMap.containsKey('id')) {
          changeMap['id'] = _uuid.v4();
        }
        if (!changeMap.containsKey('created_at')) {
          changeMap['created_at'] = DateTime.now().toIso8601String();
        }
        
        await _db.insertBalanceChangeRaw(changeMap);
        success++;
      } catch (e) {
        fail++;
        errors.add('余额变更导入失败: ${change['id']} - $e');
      }
    }

    return {'total': total, 'success': success, 'fail': fail};
  }

  Future<void> recordImport(
    String fileName,
    String sourceType,
    ImportMode mode,
    ImportResult result,
  ) async {
    await _db.insertImportRecord({
      'file_name': fileName,
      'source_type': sourceType,
      'total_records': result.totalRecords,
      'success_count': result.successCount,
      'fail_count': result.failCount,
      'import_mode': mode.name,
    });
  }

  Future<List<Map<String, dynamic>>> getImportHistory() async {
    return await _db.getAllImportRecords();
  }
}
