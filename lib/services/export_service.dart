import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:expense_tracker/database/database_helper.dart';

class ExportService {
  static final ExportService instance = ExportService._();
  ExportService._();

  Future<String> exportAllData() async {
    final db = DatabaseHelper.instance;
    
    final transactions = await db.getAllTransactions();
    final categories = await db.getAllCategories();
    final accounts = await db.getAllAccounts();
    final merchants = await db.getAllMerchants();
    final owners = await db.getAllOwners();
    final balanceChanges = await db.getAllBalanceChanges();

    final exportData = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'transactions': transactions.map((t) => t.toMap()).toList(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'accounts': accounts.map((a) => a.toMap()).toList(),
        'merchants': merchants,
        'owners': owners,
        'balance_changes': balanceChanges,
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    return jsonString;
  }

  Future<String> exportTransactions() async {
    final db = DatabaseHelper.instance;
    final transactions = await db.getAllTransactions();

    final exportData = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'transactions': transactions.map((t) => t.toMap()).toList(),
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    return jsonString;
  }

  Future<String> exportAccounts() async {
    final db = DatabaseHelper.instance;
    final accounts = await db.getAllAccounts();

    final exportData = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'accounts': accounts.map((a) => a.toMap()).toList(),
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    return jsonString;
  }

  Future<String> exportCategories() async {
    final db = DatabaseHelper.instance;
    final categories = await db.getAllCategories();

    final exportData = {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        'categories': categories.map((c) => c.toMap()).toList(),
      },
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
    return jsonString;
  }

  Future<File> saveExportToFile(String jsonString, String exportType) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final fileName = 'jizhang_${exportType}_$timestamp.json';
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(jsonString);
    return file;
  }

  Future<File> saveExportToDownloads(String jsonString, String exportType) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final fileName = 'jizhang_${exportType}_$timestamp.json';
    
    Directory? directory;
    
    try {
      directory = await getExternalStorageDirectory();
    } catch (e) {
      directory = null;
    }
    
    if (directory == null) {
      directory = await getApplicationDocumentsDirectory();
    }
    
    final exportDir = Directory('${directory.path}/exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    
    final file = File('${exportDir.path}/$fileName');
    await file.writeAsString(jsonString);
    return file;
  }

  Future<void> shareExportFile(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: '记账数据导出');
  }

  Future<Map<String, dynamic>> getExportPreview(String jsonString) async {
    try {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      final exportData = data['data'] as Map<String, dynamic>;
      
      int transactionCount = 0;
      int categoryCount = 0;
      int accountCount = 0;
      int merchantCount = 0;
      int ownerCount = 0;
      int balanceChangeCount = 0;

      if (exportData.containsKey('transactions')) {
        transactionCount = (exportData['transactions'] as List).length;
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
      if (exportData.containsKey('balance_changes')) {
        balanceChangeCount = (exportData['balance_changes'] as List).length;
      }

      return {
        'valid': true,
        'transaction_count': transactionCount,
        'category_count': categoryCount,
        'account_count': accountCount,
        'merchant_count': merchantCount,
        'owner_count': ownerCount,
        'balance_change_count': balanceChangeCount,
        'total_records': transactionCount + categoryCount + accountCount + merchantCount + ownerCount + balanceChangeCount,
        'exported_at': data['exported_at'],
      };
    } catch (e) {
      return {
        'valid': false,
        'error': e.toString(),
      };
    }
  }
}
