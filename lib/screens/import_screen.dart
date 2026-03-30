import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/services/import_service.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  File? _selectedFile;
  Map<String, dynamic>? _previewData;
  ImportMode _selectedMode = ImportMode.merge;
  bool _isImporting = false;
  ImportResult? _importResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('导入数据'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
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
                        '选择导入文件',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      InkWell(
                        onTap: _pickFile,
                        child: Container(
                          padding: EdgeInsets.all(24.w),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_upload_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 12.h),
                              Text(
                                _selectedFile == null
                                    ? '点击选择 JSON 备份文件'
                                    : _selectedFile!.path.split('/').last,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: _selectedFile != null
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[600],
                                ),
                              ),
                              if (_selectedFile == null) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  '支持 .json 格式的备份文件',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_previewData != null && _previewData!['valid'] == true) ...[
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
                          '文件预览',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _buildPreviewRow('交易记录', _previewData!['transaction_count'] ?? 0),
                        _buildPreviewRow('分类', _previewData!['category_count'] ?? 0),
                        _buildPreviewRow('账户', _previewData!['account_count'] ?? 0),
                        _buildPreviewRow('商家', _previewData!['merchant_count'] ?? 0),
                        _buildPreviewRow('归属人', _previewData!['owner_count'] ?? 0),
                        Divider(height: 24.h),
                        _buildPreviewRow('总计', _previewData!['total_records'] ?? 0, isTotal: true),
                        if (_previewData!['earliest_date'] != null) ...[
                          SizedBox(height: 12.h),
                          Text(
                            '数据时间范围: ${_previewData!['earliest_date'].toString().split('T')[0]} ~ ${_previewData!['latest_date'].toString().split('T')[0]}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey[600],
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
                        Text(
                          '导入模式',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        _buildImportModeOption(
                          ImportMode.merge,
                          '合并',
                          '保留现有数据，追加导入数据（推荐）',
                        ),
                        _buildImportModeOption(
                          ImportMode.replace,
                          '覆盖',
                          '清空现有数据，导入全部数据（⚠️ 风险较高）',
                          isDanger: true,
                        ),
                        _buildImportModeOption(
                          ImportMode.skipExisting,
                          '跳过重复',
                          '仅导入不存在的记录',
                        ),
                      ],
                    ),
                  ),
                ],
                if (_importResult != null) ...[
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: _importResult!.failCount > 0 ? Colors.orange[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: _importResult!.failCount > 0 ? Colors.orange[200]! : Colors.green[200]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _importResult!.failCount > 0 ? Icons.warning_amber : Icons.check_circle,
                              color: _importResult!.failCount > 0 ? Colors.orange[600] : Colors.green[600],
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              _importResult!.failCount > 0 ? '导入完成（部分失败）' : '导入成功',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: _importResult!.failCount > 0 ? Colors.orange[800] : Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          '总计: ${_importResult!.totalRecords} 条, 成功: ${_importResult!.successCount} 条, 失败: ${_importResult!.failCount} 条',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (_importResult!.errors.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          Text(
                            '错误信息:',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[800],
                            ),
                          ),
                          ..._importResult!.errors.take(5).map((e) => Padding(
                            padding: EdgeInsets.only(top: 4.h),
                            child: Text(
                              '• $e',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _previewData != null && !_isImporting ? _performImport : null,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('开始导入'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, int count, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              color: isTotal ? Colors.black87 : Colors.grey[600],
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Text(
            '$count 条',
            style: TextStyle(
              fontSize: 14.sp,
              color: isTotal ? Theme.of(context).primaryColor : Colors.black87,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportModeOption(ImportMode mode, String title, String subtitle, {bool isDanger = false}) {
    final isSelected = _selectedMode == mode;
    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 12.w),
        margin: EdgeInsets.only(bottom: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDanger ? Colors.red[50] : Theme.of(context).primaryColor.withValues(alpha: 0.1))
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected
                ? (isDanger ? Colors.red[300]! : Theme.of(context).primaryColor)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected
                  ? (isDanger ? Colors.red[400] : Theme.of(context).primaryColor)
                  : Colors.grey[400],
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
                      color: isSelected
                          ? (isDanger ? Colors.red[700] : Theme.of(context).primaryColor)
                          : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDanger && isSelected ? Colors.red[400] : Colors.grey[600],
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

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        
        final preview = await ImportService.instance.parseImportFile(content);
        
        setState(() {
          _selectedFile = file;
          _previewData = preview;
          _importResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _performImport() async {
    if (_previewData == null || _selectedFile == null) return;

    setState(() {
      _isImporting = true;
    });

    try {
      final importService = ImportService.instance;
      final rawData = _previewData!['raw_data'] as Map<String, dynamic>;
      
      final result = await importService.importData(rawData, _selectedMode);
      
      await importService.recordImport(
        _selectedFile!.path.split('/').last,
        'file',
        _selectedMode,
        result,
      );

      await context.read<TransactionProvider>().loadTransactions();
      await context.read<AccountProvider>().loadAccounts();
      await context.read<CategoryProvider>().loadCategories();

      setState(() {
        _importResult = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入完成: 成功 ${result.successCount} 条')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }
}
