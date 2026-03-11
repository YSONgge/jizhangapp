import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:expense_tracker/providers/transaction_provider.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/providers/owner_provider.dart';
import 'package:expense_tracker/providers/merchant_provider.dart';
import 'package:expense_tracker/screens/home_screen.dart';
import 'package:expense_tracker/database/database_helper.dart';
import 'package:expense_tracker/services/text_parser.dart';
import 'package:expense_tracker/services/backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  OwnerProvider? ownerProvider;
  MerchantProvider? merchantProvider;

  try {
    await DatabaseHelper.instance.database;
    
    await BackupService.instance.init();
    await BackupService.instance.checkAndPerformAutoBackup();
    
    ownerProvider = OwnerProvider();
    await ownerProvider.loadOwners();
    
    merchantProvider = MerchantProvider();
    await merchantProvider.loadMerchants();
    
    await _initTextParser(ownerProvider, merchantProvider);
  } catch (e) {
    debugPrint('数据库初始化失败: $e');
  }

  runApp(MyApp(ownerProvider: ownerProvider, merchantProvider: merchantProvider));
}

Future<void> _initTextParser(OwnerProvider ownerProvider, MerchantProvider merchantProvider) async {
  try {
    final accounts = await DatabaseHelper.instance.getAllAccounts();
    TextParser.updateUserData(
      accounts: accounts.map((a) => {'name': a.name, 'type': a.type, 'category': a.category}).toList(),
      owners: ownerProvider.ownerNames,
      merchants: merchantProvider.merchantNames,
    );
  } catch (e) {
    debugPrint('TextParser初始化失败: $e');
  }
}

class MyApp extends StatelessWidget {
  final OwnerProvider? ownerProvider;
  final MerchantProvider? merchantProvider;

  const MyApp({super.key, this.ownerProvider, this.merchantProvider});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone X 设计尺寸
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => CategoryProvider(),
            ),
            ChangeNotifierProvider(
              create: (_) => AccountProvider(),
            ),
            ChangeNotifierProvider(
              create: (_) => TransactionProvider(),
            ),
            ChangeNotifierProvider(
              create: (_) => ownerProvider ?? OwnerProvider(),
            ),
            ChangeNotifierProvider(
              create: (_) => merchantProvider ?? MerchantProvider(),
            ),
          ],
          child: MaterialApp(
            title: '智能记账',
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh', 'CN'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('zh', 'CN'),
            ],
            theme: ThemeData(
              primaryColor: const Color(0xFF2196F3),
              primarySwatch: Colors.blue,
              useMaterial3: false,
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF2196F3),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Color(0xFF2196F3),
                unselectedItemColor: Color(0xFF9E9E9E),
                elevation: 0,
              ),
            ),
            home: const HomeScreen(),
          ),
        );
      },
    );
  }
}
