import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/data/models/transaction.dart' as models;
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/widgets/transaction_list_item.dart';
import 'package:expense_tracker/widgets/category_picker_sheet.dart';
import 'package:expense_tracker/screens/full_screen_editor_screen.dart';
import 'package:intl/intl.dart';

class SearchTransactionsScreen extends StatefulWidget {
  const SearchTransactionsScreen({super.key});

  @override
  State<SearchTransactionsScreen> createState() => _SearchTransactionsScreenState();
}

class _SearchTransactionsScreenState extends State<SearchTransactionsScreen> {
  String? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _keywordController = TextEditingController();
  List<models.Transaction> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _isSearching = true);

    final results = await DatabaseHelper.instance.searchTransactions(
      categoryId: _selectedCategoryId,
      startDate: _startDate,
      endDate: _endDate,
      keyword: _keywordController.text.isNotEmpty ? _keywordController.text : null,
    );

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _startDate = date);
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() => _endDate = date);
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryPickerSheet(
        selectedCategoryId: _selectedCategoryId,
        onCategorySelected: (categoryId) {
          setState(() {
            _selectedCategoryId = categoryId.isEmpty ? null : categoryId;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final selectedCategory = _selectedCategoryId != null 
        ? categoryProvider.getCategoryById(_selectedCategoryId!) 
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2196F3),
        elevation: 0,
        title: const Text('搜索交易', style: TextStyle(color: Colors.white, fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('搜索条件', style: TextStyle(fontSize: 14.sp, color: Colors.grey[600])),
                SizedBox(height: 12.h),
                GestureDetector(
                  onTap: _showCategoryPicker,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.category, size: 18.sp, color: Colors.grey[600]),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            selectedCategory?.name ?? '请选择分类',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: selectedCategory != null ? Colors.black87 : Colors.grey[400],
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectStartDate,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range, size: 18.sp, color: Colors.grey[600]),
                              SizedBox(width: 8.w),
                              Text(
                                _startDate != null 
                                    ? DateFormat('yyyy-MM-dd').format(_startDate!) 
                                    : '开始日期',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: _startDate != null ? Colors.black87 : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Text('—', style: TextStyle(color: Colors.grey[400])),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectEndDate,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.date_range, size: 18.sp, color: Colors.grey[600]),
                              SizedBox(width: 8.w),
                              Text(
                                _endDate != null 
                                    ? DateFormat('yyyy-MM-dd').format(_endDate!) 
                                    : '结束日期',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: _endDate != null ? Colors.black87 : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: _keywordController,
                  decoration: InputDecoration(
                    hintText: '关键字（备注/商家）',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.r),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                  ),
                ),
                SizedBox(height: 16.h),
                SizedBox(
                  width: double.infinity,
                  height: 44.h,
                  child: ElevatedButton(
                    onPressed: _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                    ),
                    child: Text('搜索', style: TextStyle(color: Colors.white, fontSize: 16.sp)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Text('搜索结果', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                SizedBox(width: 8.w),
                Text('(${_searchResults.length}条)', style: TextStyle(fontSize: 12.sp, color: Colors.grey[500])),
              ],
            ),
          ),
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(child: Text('暂无结果', style: TextStyle(color: Colors.grey[400])))
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final transaction = _searchResults[index];
                          return TransactionListItem(
                            transaction: transaction,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenEditorScreen(
                                    transactionToEdit: transaction,
                                  ),
                                ),
                              ).then((_) => _search());
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
