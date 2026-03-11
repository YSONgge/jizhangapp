import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/merchant_provider.dart';

class MerchantsScreen extends StatelessWidget {
  const MerchantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('商家管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: Consumer<MerchantProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final merchants = provider.merchants;

          if (merchants.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_outlined, size: 80.w, color: Colors.grey[200]),
                  SizedBox(height: 16.h),
                  Text('暂无商家', style: TextStyle(fontSize: 16.sp, color: Colors.grey[400])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: merchants.length,
            itemBuilder: (context, index) {
              final merchant = merchants[index];
              final isDefault = merchant['is_default'] == 1;

              return Container(
                margin: EdgeInsets.only(bottom: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: ListTile(
                  leading: Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(22.w),
                    ),
                    child: Icon(
                      Icons.store,
                      color: const Color(0xFF4CAF50),
                      size: 24.w,
                    ),
                  ),
                  title: Text(
                    merchant['name'],
                    style: TextStyle(fontSize: 16.sp),
                  ),
                  subtitle: isDefault ? Text('预设', style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 20.w),
                        onPressed: () => _showEditDialog(context, provider, merchant),
                      ),
                      if (!isDefault)
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 20.w, color: Colors.red[400]),
                          onPressed: () => _showDeleteDialog(context, provider, merchant),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static void _showAddDialog(BuildContext context) {
    final nameController = TextEditingController();
    final merchantProvider = context.read<MerchantProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加商家'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '请输入商家名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              await merchantProvider.addMerchant(name);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  static void _showEditDialog(BuildContext context, MerchantProvider provider, Map<String, dynamic> merchant) {
    final nameController = TextEditingController(text: merchant['name']);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('编辑商家'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '请输入商家名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              await provider.updateMerchant(merchant['id'], name);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  static void _showDeleteDialog(BuildContext context, MerchantProvider provider, Map<String, dynamic> merchant) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除商家"${merchant['name']}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await provider.deleteMerchant(merchant['id']);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
