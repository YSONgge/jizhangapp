import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/database/database_helper.dart';

class OwnersScreen extends StatefulWidget {
  const OwnersScreen({super.key});

  @override
  State<OwnersScreen> createState() => _OwnersScreenState();
}

class _OwnersScreenState extends State<OwnersScreen> {
  List<Map<String, dynamic>> _owners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOwners();
  }

  Future<void> _loadOwners() async {
    setState(() => _isLoading = true);
    final owners = await DatabaseHelper.instance.getAllOwners();
    setState(() {
      _owners = owners;
      _isLoading = false;
    });
  }

  void _showAddEditDialog([Map<String, dynamic>? owner]) {
    final nameController = TextEditingController(text: owner?['name'] ?? '');
    final isEditing = owner != null;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? '编辑归属人' : '添加归属人'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '请输入归属人名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              if (isEditing) {
                await DatabaseHelper.instance.updateOwner(owner['id'], {'name': name});
              } else {
                await DatabaseHelper.instance.insertOwner({
                  'name': name,
                  'sort_order': _owners.length,
                });
              }
              if (mounted) {
                Navigator.pop(context);
                _loadOwners();
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> owner) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除归属人"${owner['name']}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.deleteOwner(owner['id']);
              if (mounted) {
                Navigator.pop(context);
                _loadOwners();
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('归属人管理'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _owners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_outline, size: 80.w, color: Colors.grey[200]),
                      SizedBox(height: 16.h),
                      Text('暂无归属人', style: TextStyle(fontSize: 16.sp, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(16.w),
                  itemCount: _owners.length,
                  itemBuilder: (context, index) {
                    final owner = _owners[index];

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
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(22.w),
                          ),
                          child: Icon(
                            Icons.person,
                            color: const Color(0xFF2196F3),
                            size: 24.w,
                          ),
                        ),
                        title: Text(
                          owner['name'],
                          style: TextStyle(fontSize: 16.sp),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 20.w),
                              onPressed: () => _showAddEditDialog(owner),
                            ),
                            if (_owners.length > 1)
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 20.w, color: Colors.red[400]),
                                onPressed: () => _showDeleteDialog(owner),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
