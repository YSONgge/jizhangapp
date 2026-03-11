import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/services/backup_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isBackupEnabled = false;
  BackupFrequency _frequency = BackupFrequency.daily;
  int _maxBackupCount = 10;
  DateTime? _lastBackupTime;
  List<Map<String, dynamic>> _backupHistory = [];
  bool _isLoading = true;
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final backupService = BackupService.instance;
    
    final enabled = await backupService.isBackupEnabled();
    final freq = await backupService.getBackupFrequency();
    final maxCount = await backupService.getMaxBackupCount();
    final lastBackup = await backupService.getLastBackupTime();
    final history = await backupService.getBackupHistory();

    setState(() {
      _isBackupEnabled = enabled;
      _frequency = freq;
      _maxBackupCount = maxCount;
      _lastBackupTime = lastBackup;
      _backupHistory = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('自动备份'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.all(24.w),
              children: [
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '备份设置',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '开启自动备份',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                '每天/每周/每月自动备份数据',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isBackupEnabled,
                            onChanged: (value) async {
                              await BackupService.instance.setBackupEnabled(value);
                              setState(() {
                                _isBackupEnabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_isBackupEnabled) ...[
                        Divider(height: 32.h),
                        Text(
                          '备份频率',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _buildFrequencyOption(BackupFrequency.daily, '每天', '每天凌晨自动备份'),
                        _buildFrequencyOption(BackupFrequency.weekly, '每周', '每周一凌晨自动备份'),
                        _buildFrequencyOption(BackupFrequency.monthly, '每月', '每月1号凌晨自动备份'),
                        Divider(height: 32.h),
                        Text(
                          '保留备份数量',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _maxBackupCount.toDouble(),
                                min: 5,
                                max: 30,
                                divisions: 5,
                                label: '$_maxBackupCount 份',
                                onChanged: (value) async {
                                  final count = value.toInt();
                                  await BackupService.instance.setMaxBackupCount(count);
                                  setState(() {
                                    _maxBackupCount = count;
                                  });
                                },
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              '$_maxBackupCount 份',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '超过数量限制后将自动删除最旧的备份',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '立即备份',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          if (_lastBackupTime != null)
                            Text(
                              '上次: ${_formatDate(_lastBackupTime!)}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isBackingUp ? null : _performManualBackup,
                          icon: _isBackingUp
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.backup),
                          label: Text(_isBackingUp ? '备份中...' : '立即备份'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '备份历史',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      if (_backupHistory.isEmpty)
                        Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.h),
                            child: Column(
                              children: [
                                Icon(Icons.history, size: 48, color: Colors.grey[300]),
                                SizedBox(height: 12.h),
                                Text(
                                  '暂无备份记录',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...List.generate(_backupHistory.length, (index) {
                          final record = _backupHistory[index];
                          return _buildBackupHistoryItem(record);
                        }),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFrequencyOption(BackupFrequency freq, String title, String subtitle) {
    final isSelected = _frequency == freq;
    return InkWell(
      onTap: () async {
        await BackupService.instance.setBackupFrequency(freq);
        setState(() {
          _frequency = freq;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey[400],
              size: 20,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupHistoryItem(Map<String, dynamic> record) {
    final createdAt = DateTime.parse(record['created_at'] as String);
    final isAuto = record['backup_type'] == 'auto';
    
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: isAuto ? Colors.blue[50] : Colors.green[50],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(
              isAuto ? Icons.autorenew : Icons.backup,
              color: isAuto ? Colors.blue[600] : Colors.green[600],
              size: 20,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record['file_name'] as String,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${record['record_count']} 条记录 • ${_formatDate(createdAt)}',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey[400], size: 20),
            onPressed: () => _deleteBackup(record['id'] as String),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _performManualBackup() async {
    setState(() {
      _isBackingUp = true;
    });

    try {
      final file = await BackupService.instance.performBackup();
      
      if (file != null) {
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份成功')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('备份失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('备份失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isBackingUp = false;
      });
    }
  }

  Future<void> _deleteBackup(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条备份记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BackupService.instance.deleteBackup(id);
      await _loadSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('备份已删除')),
        );
      }
    }
  }
}
