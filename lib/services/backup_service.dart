import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/services/export_service.dart';

enum BackupFrequency { daily, weekly, monthly }

class BackupService {
  static final BackupService instance = BackupService._();
  BackupService._();

  final _db = DatabaseHelper.instance;

  static const String _backupEnabledKey = 'backup_enabled';
  static const String _backupFrequencyKey = 'backup_frequency';
  static const String _lastBackupTimeKey = 'last_backup_time';
  static const String _maxBackupCountKey = 'max_backup_count';

  static const int defaultMaxBackupCount = 10;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    if (!prefs.containsKey(_backupEnabledKey)) {
      await prefs.setBool(_backupEnabledKey, false);
    }
    if (!prefs.containsKey(_backupFrequencyKey)) {
      await prefs.setString(_backupFrequencyKey, BackupFrequency.daily.name);
    }
    if (!prefs.containsKey(_maxBackupCountKey)) {
      await prefs.setInt(_maxBackupCountKey, defaultMaxBackupCount);
    }
  }

  Future<bool> isBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backupEnabledKey) ?? false;
  }

  Future<void> setBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupEnabledKey, enabled);
  }

  Future<BackupFrequency> getBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final frequencyStr = prefs.getString(_backupFrequencyKey) ?? BackupFrequency.daily.name;
    return BackupFrequency.values.firstWhere(
      (f) => f.name == frequencyStr,
      orElse: () => BackupFrequency.daily,
    );
  }

  Future<void> setBackupFrequency(BackupFrequency frequency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backupFrequencyKey, frequency.name);
  }

  Future<int> getMaxBackupCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_maxBackupCountKey) ?? defaultMaxBackupCount;
  }

  Future<void> setMaxBackupCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_maxBackupCountKey, count);
  }

  Future<DateTime?> getLastBackupTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastBackupTimeKey);
    if (timeStr != null) {
      return DateTime.parse(timeStr);
    }
    return null;
  }

  Future<void> setLastBackupTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupTimeKey, time.toIso8601String());
  }

  Future<bool> shouldAutoBackup() async {
    if (!await isBackupEnabled()) return false;

    final lastBackup = await getLastBackupTime();
    if (lastBackup == null) return true;

    final frequency = await getBackupFrequency();
    final now = DateTime.now();

    switch (frequency) {
      case BackupFrequency.daily:
        return now.difference(lastBackup).inDays >= 1;
      case BackupFrequency.weekly:
        return now.difference(lastBackup).inDays >= 7;
      case BackupFrequency.monthly:
        return now.month != lastBackup.month || now.year != lastBackup.year;
    }
  }

  Future<File?> performBackup({bool isAuto = false}) async {
    try {
      final exportService = ExportService.instance;
      final jsonString = await exportService.exportAllData();
      
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

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final fileName = 'backup_$timestamp.json';
      final file = File('${exportDir.path}/$fileName');
      await file.writeAsString(jsonString);

      final stats = await file.stat();
      final transactions = await _db.getAllTransactions();

      await _db.insertBackupRecord({
        'file_path': file.path,
        'file_name': fileName,
        'file_size': stats.size,
        'record_count': transactions.length,
        'backup_type': isAuto ? 'auto' : 'manual',
      });

      await setLastBackupTime(DateTime.now());

      await _cleanupOldBackups();

      return file;
    } catch (e) {
      return null;
    }
  }

  Future<void> _cleanupOldBackups() async {
    final maxCount = await getMaxBackupCount();
    final records = await _db.getAllBackupRecords();

    if (records.length > maxCount) {
      final toDelete = records.skip(maxCount).toList();
      for (var record in toDelete) {
        try {
          final file = File(record['file_path'] as String);
          if (await file.exists()) {
            await file.delete();
          }
          await _db.deleteBackupRecord(record['id'] as String);
        } catch (e) {
          // Ignore delete errors
        }
      }
    }
  }

  Future<List<Map<String, dynamic>>> getBackupHistory() async {
    return await _db.getAllBackupRecords();
  }

  Future<bool> deleteBackup(String id) async {
    try {
      final records = await _db.getAllBackupRecords();
      final record = records.firstWhere(
        (r) => r['id'] == id,
        orElse: () => throw Exception('备份记录不存在'),
      );
      
      final file = File(record['file_path'] as String);
      if (await file.exists()) {
        await file.delete();
      }
      
      await _db.deleteBackupRecord(id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<File?> restoreFromBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> checkAndPerformAutoBackup() async {
    if (await shouldAutoBackup()) {
      await performBackup(isAuto: true);
    }
  }
}
