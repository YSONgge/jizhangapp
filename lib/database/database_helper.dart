import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:expense_tracker/data/models/transaction.dart' as models;
import 'package:expense_tracker/data/models/category.dart' as models;
import 'package:expense_tracker/data/models/account.dart' as models;
import 'package:expense_tracker/data/models/transaction_type.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  final Uuid _uuid = const Uuid();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) {
      await _ensureColumnsExist(_database!);
      return _database!;
    }
    _database = await _initDB('expense_tracker.db');
    await _ensureColumnsExist(_database!);
    return _database!;
  }

  Future<void> _ensureColumnsExist(Database db) async {
    try {
      final result = await db.rawQuery(
        "PRAGMA table_info(transactions)"
      );
      final columns = result.map((r) => r['name'] as String).toList();
      if (columns.contains('target_account_id')) {
        return;
      }
      await db.execute("ALTER TABLE transactions ADD COLUMN target_account_id TEXT");
    } catch (e) {
      // 列可能已存在，忽略错误
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 交易记录表
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id TEXT NOT NULL,
        account_id TEXT NOT NULL,
        target_account_id TEXT,
        merchant TEXT,
        owner TEXT,
        project TEXT,
        remark TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        input_raw TEXT,
        user_corrected INTEGER DEFAULT 0
      )
    ''');

    await db.execute('CREATE INDEX idx_transactions_date ON transactions(date)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');

    // 分类表
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        parent_id TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_categories_parent ON categories(parent_id)');

    // 账户表
    await db.execute('''
      CREATE TABLE accounts (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        balance REAL DEFAULT 0,
        icon TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0
      )
    ''');

    // 商家表
    await db.execute('''
      CREATE TABLE merchants (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        icon TEXT,
        sort_order INTEGER DEFAULT 0,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 归属人表
    await db.execute('''
      CREATE TABLE owners (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE NOT NULL,
        icon TEXT,
        sort_order INTEGER DEFAULT 0,
        is_default INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // 余额变更记录表
    await db.execute('''
      CREATE TABLE balance_changes (
        id TEXT PRIMARY KEY,
        account_id TEXT NOT NULL,
        old_balance REAL NOT NULL,
        new_balance REAL NOT NULL,
        change_amount REAL NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (account_id) REFERENCES accounts(id)
      )
    ''');

    await db.execute('CREATE INDEX idx_balance_changes_account ON balance_changes(account_id)');
    await db.execute('CREATE INDEX idx_balance_changes_date ON balance_changes(created_at)');

    // 应用配置表
    await db.execute('''
      CREATE TABLE app_config (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // 备份记录表
    await db.execute('''
      CREATE TABLE backup_records (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        record_count INTEGER NOT NULL,
        backup_type TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 导入记录表
    await db.execute('''
      CREATE TABLE import_records (
        id TEXT PRIMARY KEY,
        file_name TEXT NOT NULL,
        source_type TEXT NOT NULL,
        total_records INTEGER NOT NULL,
        success_count INTEGER NOT NULL,
        fail_count INTEGER NOT NULL,
        import_mode TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 初始化默认数据
    await _initDefaultData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 从版本1升级到版本2: 添加category列,删除旧账户数据,重新初始化
    if (oldVersion < 2) {
      try {
        await db.execute("ALTER TABLE accounts ADD COLUMN category TEXT NOT NULL DEFAULT '现金'");
      } catch (e) {
        // 列可能已存在,忽略错误
      }
      await db.delete('accounts'); // 删除所有旧账户
      await _initDefaultAccounts(db); // 重新初始化账户
    } else {
      // 如果不是从版本1升级，检查账户是否为空，如果是则初始化
      final accounts = await db.query('accounts');
      if (accounts.isEmpty) {
        await _initDefaultAccounts(db);
      }
    }

    // 从版本2升级到版本3: 添加商家表、归属人表和余额变更记录表
    if (oldVersion < 3) {
      // 删除旧的商家表（如果存在），重建新表
      await db.execute('DROP TABLE IF EXISTS merchants');
      await db.execute('''
        CREATE TABLE merchants (
          id TEXT PRIMARY KEY,
          name TEXT UNIQUE NOT NULL,
          icon TEXT,
          sort_order INTEGER DEFAULT 0,
          is_default INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      // 创建归属人表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS owners (
          id TEXT PRIMARY KEY,
          name TEXT UNIQUE NOT NULL,
          icon TEXT,
          sort_order INTEGER DEFAULT 0,
          is_default INTEGER DEFAULT 0,
          created_at TEXT NOT NULL
        )
      ''');

      // 创建余额变更记录表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS balance_changes (
          id TEXT PRIMARY KEY,
          account_id TEXT NOT NULL,
          old_balance REAL NOT NULL,
          new_balance REAL NOT NULL,
          change_amount REAL NOT NULL,
          reason TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (account_id) REFERENCES accounts(id)
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_balance_changes_account ON balance_changes(account_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_balance_changes_date ON balance_changes(created_at)');
    }

    // 每次升级都重新初始化默认归属人（确保新增的默认归属人被添加）
    await _initDefaultOwners(db);

    // 从版本3升级到版本4: 添加备份记录表和导入记录表
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS backup_records (
          id TEXT PRIMARY KEY,
          file_path TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_size INTEGER NOT NULL,
          record_count INTEGER NOT NULL,
          backup_type TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS import_records (
          id TEXT PRIMARY KEY,
          file_name TEXT NOT NULL,
          source_type TEXT NOT NULL,
          total_records INTEGER NOT NULL,
          success_count INTEGER NOT NULL,
          fail_count INTEGER NOT NULL,
          import_mode TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }

    // 从版本4升级到版本5: 添加转账字段
    if (oldVersion < 5) {
      try {
        await db.execute("ALTER TABLE transactions ADD COLUMN target_account_id TEXT");
      } catch (e) {
        // 列可能已存在，忽略错误
      }
    }

    // 从版本5升级到版本6: 确保 import_records 表存在（兼容旧版本数据库）
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS import_records (
            id TEXT PRIMARY KEY,
            file_name TEXT NOT NULL,
            source_type TEXT NOT NULL,
            total_records INTEGER NOT NULL,
            success_count INTEGER NOT NULL,
            fail_count INTEGER NOT NULL,
            import_mode TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (e) {
        // 表已存在，忽略错误
      }
    }
  }

  Future<void> _initDefaultData(Database db) async {
    // ==================== 初始化父分类（PRD规范） ====================
    final expenseParentCategories = [
      {'id': 'cat_food', 'name': '食品酒水', 'icon': 'restaurant', 'color': '#FF6B6B', 'sort': 0},
      {'id': 'cat_home', 'name': '居家生活', 'icon': 'home', 'color': '#4ECDC4', 'sort': 1},
      {'id': 'cat_comm', 'name': '交流通讯', 'icon': 'phone', 'color': '#95E1D3', 'sort': 2},
      {'id': 'cat_ent', 'name': '休闲娱乐', 'icon': 'sports_esports', 'color': '#AA96DA', 'sort': 3},
      {'id': 'cat_social', 'name': '人情费用', 'icon': 'card_giftcard', 'color': '#FCBAD3', 'sort': 4},
      {'id': 'cat_baby', 'name': '宝宝费用', 'icon': 'child_care', 'color': '#FFD93D', 'sort': 5},
      {'id': 'cat_travel', 'name': '出差旅游', 'icon': 'flight', 'color': '#6BCB77', 'sort': 6},
      {'id': 'cat_traffic', 'name': '行车交通', 'icon': 'directions_car', 'color': '#4D96FF', 'sort': 7},
      {'id': 'cat_shop', 'name': '购物消费', 'icon': 'shopping_cart', 'color': '#FF6B6B', 'sort': 8},
      {'id': 'cat_medical', 'name': '医疗教育', 'icon': 'medical_services', 'color': '#4ECDC4', 'sort': 9},
      {'id': 'cat_other', 'name': '其他杂项', 'icon': 'more_horiz', 'color': '#95E1D3', 'sort': 10},
      {'id': 'cat_finance', 'name': '金融保险', 'icon': 'account_balance', 'color': '#AA96DA', 'sort': 11},
    ];

    for (var cat in expenseParentCategories) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO categories (id, name, icon, color, sort_order, parent_id)
        VALUES (?, ?, ?, ?, ?, NULL)
      ''', [cat['id'], cat['name'], cat['icon'], cat['color'], cat['sort']]);
    }

    final incomeParentCategories = [
      {'id': 'cat_inc_wage', 'name': '工资收入', 'icon': 'payments', 'color': '#FFD93D', 'sort': 0},
      {'id': 'cat_inc_bus', 'name': '经营收入', 'icon': 'store', 'color': '#6BCB77', 'sort': 1},
      {'id': 'cat_inv', 'name': '投资收益', 'icon': 'trending_up', 'color': '#4D96FF', 'sort': 2},
      {'id': 'cat_inc_pt', 'name': '兼职副业', 'icon': 'work', 'color': '#FF6B6B', 'sort': 3},
      {'id': 'cat_inc_refund', 'name': '退款返还', 'icon': 'refund', 'color': '#4ECDC4', 'sort': 4},
      {'id': 'cat_inc_other', 'name': '其他收入', 'icon': 'attach_money', 'color': '#95E1D3', 'sort': 5},
    ];

    for (var cat in incomeParentCategories) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO categories (id, name, icon, color, sort_order, parent_id)
        VALUES (?, ?, ?, ?, ?, NULL)
      ''', [cat['id'], cat['name'], cat['icon'], cat['color'], cat['sort']]);
    }

    // ==================== 初始化支出子分类（PRD规范） ====================
    // 使用 PRD 中的完整两级分类体系

    // 1. 食品酒水
    final foodDrinkCategories = [
      {'id': 'cat_food_001', 'name': '伙食费', 'icon': 'restaurant', 'color': '#FF6B6B', 'sort': 9, 'parent': 'cat_food'},
      {'id': 'cat_food_002', 'name': '早餐', 'icon': 'restaurant', 'color': '#FF8787', 'sort': 1, 'parent': 'cat_food'},
      {'id': 'cat_food_003', 'name': '午餐', 'icon': 'restaurant', 'color': '#FFA3A3', 'sort': 2, 'parent': 'cat_food'},
      {'id': 'cat_food_004', 'name': '晚餐', 'icon': 'restaurant', 'color': '#FFBFBF', 'sort': 3, 'parent': 'cat_food'},
      {'id': 'cat_food_005', 'name': '水果', 'icon': 'restaurant', 'color': '#FFDBDB', 'sort': 4, 'parent': 'cat_food'},
      {'id': 'cat_food_006', 'name': '零食', 'icon': 'restaurant', 'color': '#FFF7F7', 'sort': 5, 'parent': 'cat_food'},
      {'id': 'cat_food_007', 'name': '买菜', 'icon': 'shopping_cart', 'color': '#4ECDC4', 'sort': 6, 'parent': 'cat_food'},
      {'id': 'cat_food_008', 'name': '柴米油盐', 'icon': 'home', 'color': '#95E1D3', 'sort': 7, 'parent': 'cat_food'},
      {'id': 'cat_food_009', 'name': '饮料酒水', 'icon': 'restaurant', 'color': '#AA96DA', 'sort': 8, 'parent': 'cat_food'},
      {'id': 'cat_food_010', 'name': '外出美食', 'icon': 'restaurant', 'color': '#FCBAD3', 'sort': 9, 'parent': 'cat_food'},
    ];

    // 2. 居家生活
    final homeLivingCategories = [
      {'id': 'cat_home_001', 'name': '房租', 'icon': 'home', 'color': '#F38181', 'sort': 0, 'parent': 'cat_home'},
      {'id': 'cat_home_002', 'name': '物业费', 'icon': 'home', 'color': '#F7A3A3', 'sort': 1, 'parent': 'cat_home'},
      {'id': 'cat_home_003', 'name': '电费', 'icon': 'home', 'color': '#FBC5C5', 'sort': 2, 'parent': 'cat_home'},
      {'id': 'cat_home_004', 'name': '水费', 'icon': 'home', 'color': '#FFE7E7', 'sort': 3, 'parent': 'cat_home'},
      {'id': 'cat_home_005', 'name': '燃气费', 'icon': 'home', 'color': '#FFF9F9', 'sort': 4, 'parent': 'cat_home'},
      {'id': 'cat_home_006', 'name': '电视费', 'icon': 'tv', 'color': '#A8D8EA', 'sort': 5, 'parent': 'cat_home'},
      {'id': 'cat_home_007', 'name': '维修费', 'icon': 'home', 'color': '#AA96DA', 'sort': 6, 'parent': 'cat_home'},
      {'id': 'cat_home_008', 'name': '快递费', 'icon': 'local_shipping', 'color': '#FCBAD3', 'sort': 7, 'parent': 'cat_home'},
    ];

    // 3. 交流通讯
    final commCategories = [
      {'id': 'cat_comm_001', 'name': '手机话费', 'icon': 'phone', 'color': '#FFD93D', 'sort': 0, 'parent': 'cat_comm'},
      {'id': 'cat_comm_002', 'name': '网费', 'icon': 'wifi', 'color': '#6BCB77', 'sort': 1, 'parent': 'cat_comm'},
      {'id': 'cat_comm_003', 'name': '座机费', 'icon': 'phone', 'color': '#4D96FF', 'sort': 2, 'parent': 'cat_comm'},
    ];

    // 4. 休闲娱乐
    final entertainmentCategories = [
      {'id': 'cat_ent_001', 'name': '彩票', 'icon': 'casino', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_ent'},
      {'id': 'cat_ent_002', 'name': '棋牌', 'icon': 'casino', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_ent'},
      {'id': 'cat_ent_003', 'name': '麻将', 'icon': 'casino', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_ent'},
      {'id': 'cat_ent_004', 'name': '话剧', 'icon': 'theater_comedy', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_ent'},
      {'id': 'cat_ent_005', 'name': 'K歌', 'icon': 'mic', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_ent'},
      {'id': 'cat_ent_006', 'name': '网游', 'icon': 'sports_esports', 'color': '#FFD93D', 'sort': 5, 'parent': 'cat_ent'},
      {'id': 'cat_ent_007', 'name': '运动', 'icon': 'sports', 'color': '#6BCB77', 'sort': 6, 'parent': 'cat_ent'},
      {'id': 'cat_ent_008', 'name': '电影', 'icon': 'movie', 'color': '#4D96FF', 'sort': 7, 'parent': 'cat_ent'},
      {'id': 'cat_ent_009', 'name': '演唱会', 'icon': 'music_note', 'color': '#FF6B6B', 'sort': 8, 'parent': 'cat_ent'},
      {'id': 'cat_ent_010', 'name': '聚会', 'icon': 'celebration', 'color': '#4ECDC4', 'sort': 9, 'parent': 'cat_ent'},
      {'id': 'cat_ent_011', 'name': '其他娱乐', 'icon': 'sports_esports', 'color': '#95E1D3', 'sort': 10, 'parent': 'cat_ent'},
    ];

    // 5. 人情费用
    final socialCategories = [
      {'id': 'cat_social_001', 'name': '红包', 'icon': 'card_giftcard', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_social'},
      {'id': 'cat_social_002', 'name': '白事', 'icon': 'event', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_social'},
      {'id': 'cat_social_003', 'name': '升学', 'icon': 'school', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_social'},
      {'id': 'cat_social_004', 'name': '满月', 'icon': 'child_care', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_social'},
      {'id': 'cat_social_005', 'name': '寿辰', 'icon': 'cake', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_social'},
      {'id': 'cat_social_006', 'name': '婚嫁', 'icon': 'favorite', 'color': '#FFD93D', 'sort': 5, 'parent': 'cat_social'},
      {'id': 'cat_social_007', 'name': '乔迁', 'icon': 'home', 'color': '#6BCB77', 'sort': 6, 'parent': 'cat_social'},
      {'id': 'cat_social_008', 'name': '孝敬长辈', 'icon': 'elderly', 'color': '#4D96FF', 'sort': 7, 'parent': 'cat_social'},
      {'id': 'cat_social_009', 'name': '请客', 'icon': 'restaurant', 'color': '#FF6B6B', 'sort': 8, 'parent': 'cat_social'},
    ];

    // 6. 宝宝费用
    final babyCategories = [
      {'id': 'cat_baby_001', 'name': '妈妈用品', 'icon': 'pregnant_woman', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_baby'},
      {'id': 'cat_baby_002', 'name': '医疗护理', 'icon': 'medical_services', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_baby'},
      {'id': 'cat_baby_003', 'name': '宝宝用品', 'icon': 'child_care', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_baby'},
      {'id': 'cat_baby_004', 'name': '宝宝教育', 'icon': 'school', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_baby'},
      {'id': 'cat_baby_005', 'name': '宝宝食品', 'icon': 'restaurant', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_baby'},
      {'id': 'cat_baby_006', 'name': '宝宝其他', 'icon': 'child_care', 'color': '#FFD93D', 'sort': 5, 'parent': 'cat_baby'},
    ];

    // 7. 出差旅游
    final travelCategories = [
      {'id': 'cat_travel_001', 'name': '餐饮费', 'icon': 'restaurant', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_travel'},
      {'id': 'cat_travel_002', 'name': '交通费', 'icon': 'directions_car', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_travel'},
      {'id': 'cat_travel_003', 'name': '住宿费', 'icon': 'hotel', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_travel'},
      {'id': 'cat_travel_004', 'name': '娱乐费', 'icon': 'sports_esports', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_travel'},
      {'id': 'cat_travel_005', 'name': '出行用品', 'icon': 'luggage', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_travel'},
      {'id': 'cat_travel_006', 'name': '其他消费', 'icon': 'shopping_bag', 'color': '#FFD93D', 'sort': 5, 'parent': 'cat_travel'},
    ];

    // 8. 行车交通
    final trafficCategories = [
      {'id': 'cat_traffic_001', 'name': '地铁', 'icon': 'subway', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_002', 'name': '公交', 'icon': 'directions_bus', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_003', 'name': '保养', 'icon': 'directions_car', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_004', 'name': '汽车保险', 'icon': 'directions_car', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_005', 'name': '违章罚款', 'icon': 'local_police', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_006', 'name': '停车', 'icon': 'local_parking', 'color': '#FFD93D', 'sort': 5, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_007', 'name': '维修', 'icon': 'build', 'color': '#6BCB77', 'sort': 6, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_008', 'name': '驾照', 'icon': 'badge', 'color': '#4D96FF', 'sort': 7, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_009', 'name': '自行车', 'icon': 'pedal_bike', 'color': '#FF6B6B', 'sort': 8, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_010', 'name': '加油', 'icon': 'local_gas_station', 'color': '#4ECDC4', 'sort': 9, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_011', 'name': '租车', 'icon': 'directions_car', 'color': '#95E1D3', 'sort': 10, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_012', 'name': '飞机', 'icon': 'flight', 'color': '#AA96DA', 'sort': 11, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_013', 'name': '火车', 'icon': 'train', 'color': '#FCBAD3', 'sort': 12, 'parent': 'cat_traffic'},
      {'id': 'cat_traffic_014', 'name': '打车', 'icon': 'local_taxi', 'color': '#FFD93D', 'sort': 13, 'parent': 'cat_traffic'},
    ];

    // 9. 购物消费
    final shoppingCategories = [
      {'id': 'cat_shop_001', 'name': '日常用品', 'icon': 'shopping_cart', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_shop'},
      {'id': 'cat_shop_002', 'name': '电子数码', 'icon': 'devices', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_shop'},
      {'id': 'cat_shop_003', 'name': '美妆护肤', 'icon': 'face', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_shop'},
      {'id': 'cat_shop_004', 'name': '洗护用品', 'icon': 'soap', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_shop'},
      {'id': 'cat_shop_005', 'name': '衣裤鞋帽', 'icon': 'checkroom', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_shop'},
      {'id': 'cat_shop_006', 'name': '超市购物', 'icon': 'local_mall', 'color': '#FFD93D', 'sort': 5, 'parent': 'cat_shop'},
      {'id': 'cat_shop_007', 'name': '书报杂志', 'icon': 'menu_book', 'color': '#6BCB77', 'sort': 6, 'parent': 'cat_shop'},
      {'id': 'cat_shop_008', 'name': '运动器械', 'icon': 'sports', 'color': '#4D96FF', 'sort': 7, 'parent': 'cat_shop'},
      {'id': 'cat_shop_009', 'name': '厨房用品', 'icon': 'kitchen', 'color': '#FF6B6B', 'sort': 8, 'parent': 'cat_shop'},
      {'id': 'cat_shop_010', 'name': '家居饰品', 'icon': 'home', 'color': '#4ECDC4', 'sort': 9, 'parent': 'cat_shop'},
      {'id': 'cat_shop_011', 'name': '珠宝首饰', 'icon': 'diamond', 'color': '#95E1D3', 'sort': 10, 'parent': 'cat_shop'},
      {'id': 'cat_shop_012', 'name': '宠物支出', 'icon': 'pets', 'color': '#AA96DA', 'sort': 11, 'parent': 'cat_shop'},
      {'id': 'cat_shop_013', 'name': '办公用品', 'icon': 'work', 'color': '#FCBAD3', 'sort': 12, 'parent': 'cat_shop'},
      {'id': 'cat_shop_014', 'name': '家具家电', 'icon': 'chair', 'color': '#FFD93D', 'sort': 13, 'parent': 'cat_shop'},
      {'id': 'cat_shop_015', 'name': '清洁用品', 'icon': 'cleaning_services', 'color': '#6BCB77', 'sort': 14, 'parent': 'cat_shop'},
      {'id': 'cat_shop_016', 'name': '汽车用品', 'icon': 'directions_car', 'color': '#4D96FF', 'sort': 15, 'parent': 'cat_shop'},
      {'id': 'cat_shop_017', 'name': '家用纺织', 'icon': 'bed', 'color': '#FF6B6B', 'sort': 16, 'parent': 'cat_shop'},
    ];

    // 10. 医疗教育
    final medicalEduCategories = [
      {'id': 'cat_medical_001', 'name': '治疗费', 'icon': 'medical_services', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_medical'},
      {'id': 'cat_medical_002', 'name': '药品费', 'icon': 'medication', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_medical'},
      {'id': 'cat_medical_003', 'name': '住院费', 'icon': 'local_hospital', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_medical'},
      {'id': 'cat_medical_004', 'name': '护理费', 'icon': 'health_and_safety', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_medical'},
    ];

    // 11. 其他杂项
    final otherCategories = [
      {'id': 'cat_other_001', 'name': '烂账损失', 'icon': 'money_off', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_other'},
      {'id': 'cat_other_002', 'name': '意外丢失', 'icon': 'report_problem', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_other'},
      {'id': 'cat_other_003', 'name': '其他支出', 'icon': 'more_horiz', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_other'},
    ];

    // 12. 金融保险
    final financeCategories = [
      {'id': 'cat_finance_001', 'name': '车贷手续', 'icon': 'account_balance', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_finance'},
      {'id': 'cat_finance_002', 'name': '汽车首付', 'icon': 'directions_car', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_finance'},
      {'id': 'cat_finance_003', 'name': '车贷', 'icon': 'directions_car', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_finance'},
      {'id': 'cat_finance_004', 'name': '投资亏损', 'icon': 'trending_down', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_finance'},
      {'id': 'cat_finance_005', 'name': '人身保险', 'icon': 'security', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_finance'},
      {'id': 'cat_finance_006', 'name': '按揭还款', 'icon': 'home', 'color': '#FFD93D', 'sort': 5, 'parent': 'cat_finance'},
      {'id': 'cat_finance_007', 'name': '银行手续', 'icon': 'account_balance', 'color': '#6BCB77', 'sort': 6, 'parent': 'cat_finance'},
      {'id': 'cat_finance_008', 'name': '利息支出', 'icon': 'percent', 'color': '#4D96FF', 'sort': 7, 'parent': 'cat_finance'},
      {'id': 'cat_finance_009', 'name': '房屋首付', 'icon': 'home', 'color': '#FF6B6B', 'sort': 8, 'parent': 'cat_finance'},
      {'id': 'cat_finance_010', 'name': '房贷', 'icon': 'home', 'color': '#4ECDC4', 'sort': 9, 'parent': 'cat_finance'},
      {'id': 'cat_finance_011', 'name': '房贷手续', 'icon': 'description', 'color': '#95E1D3', 'sort': 10, 'parent': 'cat_finance'},
      {'id': 'cat_finance_012', 'name': '税费', 'icon': 'receipt', 'color': '#AA96DA', 'sort': 11, 'parent': 'cat_finance'},
      {'id': 'cat_finance_013', 'name': '赔偿罚款', 'icon': 'gavel', 'color': '#FCBAD3', 'sort': 12, 'parent': 'cat_finance'},
      {'id': 'cat_finance_014', 'name': '消费税收', 'icon': 'account_balance_wallet', 'color': '#FFD93D', 'sort': 13, 'parent': 'cat_finance'},
    ];

    // 合并所有支出类目
    final allExpenseCategories = [
      ...foodDrinkCategories,
      ...homeLivingCategories,
      ...commCategories,
      ...entertainmentCategories,
      ...socialCategories,
      ...babyCategories,
      ...travelCategories,
      ...trafficCategories,
      ...shoppingCategories,
      ...medicalEduCategories,
      ...otherCategories,
      ...financeCategories,
    ];

    for (var cat in allExpenseCategories) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO categories (id, name, icon, color, sort_order, parent_id)
        VALUES (?, ?, ?, ?, ?, ?)
      ''', [cat['id'], cat['name'], cat['icon'], cat['color'], cat['sort'], cat['parent']]);
    }

    // ==================== 初始化收入类目（PRD规范） ====================
    
    // 1. 工资收入
    final wageIncomeCategories = [
      {'id': 'cat_inc_wage_001', 'name': '基本工资', 'icon': 'payments', 'color': '#FFD93D', 'sort': 0, 'parent': 'cat_inc_wage'},
      {'id': 'cat_inc_wage_002', 'name': '奖金', 'icon': 'card_giftcard', 'color': '#FF6B6B', 'sort': 1, 'parent': 'cat_inc_wage'},
      {'id': 'cat_inc_wage_003', 'name': '补贴', 'icon': 'payments', 'color': '#6BCB77', 'sort': 2, 'parent': 'cat_inc_wage'},
      {'id': 'cat_inc_wage_004', 'name': '加班费', 'icon': 'schedule', 'color': '#4D96FF', 'sort': 3, 'parent': 'cat_inc_wage'},
      {'id': 'cat_inc_wage_005', 'name': '年终奖', 'icon': 'celebration', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_inc_wage'},
    ];

    // 2. 经营收入
    final businessIncomeCategories = [
      {'id': 'cat_inc_bus_001', 'name': '生意收入', 'icon': 'store', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_inc_bus'},
      {'id': 'cat_inc_bus_002', 'name': '项目收入', 'icon': 'work', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_inc_bus'},
      {'id': 'cat_inc_bus_003', 'name': '服务费', 'icon': 'support_agent', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_inc_bus'},
      {'id': 'cat_inc_bus_004', 'name': '咨询费', 'icon': 'chat', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_inc_bus'},
    ];

    // 3. 投资收益
    final investmentIncomeCategories = [
      {'id': 'cat_inv_001', 'name': '利息', 'icon': 'percent', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_inv'},
      {'id': 'cat_inv_002', 'name': '分红', 'icon': 'account_balance', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_inv'},
      {'id': 'cat_inv_003', 'name': '基金收益', 'icon': 'show_chart', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_inv'},
      {'id': 'cat_inv_004', 'name': '股票收益', 'icon': 'candlestick_chart', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_inv'},
      {'id': 'cat_inv_005', 'name': '理财收益', 'icon': 'account_balance_wallet', 'color': '#FCBAD3', 'sort': 4, 'parent': 'cat_inv'},
    ];

    // 4. 兼职副业
    final partTimeIncomeCategories = [
      {'id': 'cat_inc_pt_001', 'name': '兼职收入', 'icon': 'work', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_inc_pt'},
      {'id': 'cat_inc_pt_002', 'name': '外快', 'icon': 'monetization_on', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_inc_pt'},
      {'id': 'cat_inc_pt_003', 'name': '平台收入', 'icon': 'smartphone', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_inc_pt'},
      {'id': 'cat_inc_pt_004', 'name': '稿费', 'icon': 'edit_note', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_inc_pt'},
    ];

    // 5. 退款返还
    final refundIncomeCategories = [
      {'id': 'cat_inc_refund_001', 'name': '退款', 'icon': 'refund', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_inc_refund'},
      {'id': 'cat_inc_refund_002', 'name': '报销', 'icon': 'receipt_long', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_inc_refund'},
      {'id': 'cat_inc_refund_003', 'name': '赔偿', 'icon': 'gavel', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_inc_refund'},
    ];

    // 6. 其他收入
    final otherIncomeCategories = [
      {'id': 'cat_inc_other_001', 'name': '红包', 'icon': 'card_giftcard', 'color': '#FF6B6B', 'sort': 0, 'parent': 'cat_inc_other'},
      {'id': 'cat_inc_other_002', 'name': '礼金', 'icon': 'redeem', 'color': '#4ECDC4', 'sort': 1, 'parent': 'cat_inc_other'},
      {'id': 'cat_inc_other_003', 'name': '意外所得', 'icon': 'auto_awesome', 'color': '#95E1D3', 'sort': 2, 'parent': 'cat_inc_other'},
      {'id': 'cat_inc_other_004', 'name': '其他收入', 'icon': 'attach_money', 'color': '#AA96DA', 'sort': 3, 'parent': 'cat_inc_other'},
    ];

    // 合并所有收入类目
    final allIncomeCategories = [
      ...wageIncomeCategories,
      ...businessIncomeCategories,
      ...investmentIncomeCategories,
      ...partTimeIncomeCategories,
      ...refundIncomeCategories,
      ...otherIncomeCategories,
    ];

    for (var cat in allIncomeCategories) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO categories (id, name, icon, color, sort_order, parent_id)
        VALUES (?, ?, ?, ?, ?, ?)
      ''', [cat['id'], cat['name'], cat['icon'], cat['color'], cat['sort'], cat['parent']]);
    }

    // 初始化默认账户 - 只创建最基本的几个账户
    // 用户可以根据需要添加更多账户
    await _initDefaultAccounts(db);

    // 初始化默认商家
    await _initDefaultMerchants(db);

    // 初始化默认归属人
    await _initDefaultOwners(db);

    // 初始化默认配置
    await db.rawInsert('''
      INSERT OR IGNORE INTO app_config (key, value) VALUES (?, ?)
    ''', ['default_account', 'acc_online_001']);

    await db.rawInsert('''
      INSERT OR IGNORE INTO app_config (key, value) VALUES (?, ?)
    ''', ['default_owner', '本人']);

    await db.rawInsert('''
      INSERT OR IGNORE INTO app_config (key, value) VALUES (?, ?)
    ''', ['default_project', '日常']);
  }

  Future<void> _initDefaultAccounts(Database db) async {
    // 1. 现金
    final cashAccounts = [
      {'id': 'acc_cash_001', 'name': '现金', 'type': 'cash', 'category': '现金', 'icon': 'payments', 'sort': 0},
    ];

    // 2. 储蓄卡/银行卡
    final bankAccounts = [
      {'id': 'acc_bank_001', 'name': '银行卡', 'type': 'bank', 'category': '金融', 'icon': 'account_balance', 'sort': 0},
    ];

    // 3. 网络支付
    final onlineAccounts = [
      {'id': 'acc_online_001', 'name': '支付宝', 'type': 'alipay', 'category': '虚拟', 'icon': 'smartphone', 'sort': 0},
      {'id': 'acc_online_002', 'name': '微信', 'type': 'wechat', 'category': '虚拟', 'icon': 'chat', 'sort': 1},
    ];

    // 4. 信用卡
    final creditAccounts = [
      {'id': 'acc_credit_001', 'name': '信用卡', 'type': 'credit', 'category': '信用卡', 'icon': 'credit_card', 'sort': 0},
    ];

    // 5. 充值/预付卡 - 用户可自行添加
    final prepaidAccounts = <Map<String, dynamic>>[];

    // 6. 投资账户 - 用户可自行添加
    final investAccounts = <Map<String, dynamic>>[];

    // 7. 应收（别人欠我） - 用户可自行添加
    final receivableAccounts = <Map<String, dynamic>>[];

    // 8. 应付（我欠别人） - 用户可自行添加
    final payableAccounts = <Map<String, dynamic>>[];

    // 合并所有账户
    final allAccounts = [
      ...cashAccounts,
      ...bankAccounts,
      ...onlineAccounts,
      ...creditAccounts,
      ...prepaidAccounts,
      ...investAccounts,
      ...receivableAccounts,
      ...payableAccounts,
    ];

    for (var acc in allAccounts) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO accounts (id, name, type, category, balance, icon, sort_order)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [
        acc['id'],
        acc['name'],
        acc['type'],
        acc['category'],
        0,
        acc['icon'],
        acc['sort'],
      ]);
    }
  }

  Future<void> _initDefaultMerchants(Database db) async {
    final defaultMerchants = [
      {'id': 'merchant_001', 'name': '超市', 'icon': 'local_grocery_store', 'sort': 0, 'is_default': 1},
      {'id': 'merchant_002', 'name': '食堂', 'icon': 'restaurant', 'sort': 1, 'is_default': 1},
      {'id': 'merchant_003', 'name': '健身房', 'icon': 'fitness_center', 'sort': 2, 'is_default': 1},
      {'id': 'merchant_004', 'name': '便利店', 'icon': 'store', 'sort': 3, 'is_default': 1},
      {'id': 'merchant_005', 'name': '药店', 'icon': 'local_pharmacy', 'sort': 4, 'is_default': 1},
    ];

    for (var merchant in defaultMerchants) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO merchants (id, name, icon, sort_order, is_default, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      ''', [
        merchant['id'],
        merchant['name'],
        merchant['icon'],
        merchant['sort'],
        merchant['is_default'],
        DateTime.now().toIso8601String(),
      ]);
    }
  }

  Future<void> _initDefaultOwners(Database db) async {
    final defaultOwners = [
      {'id': 'owner_001', 'name': '本人', 'icon': 'person', 'sort': 0, 'is_default': 1},
      {'id': 'owner_002', 'name': '爱人', 'icon': 'favorite', 'sort': 1, 'is_default': 1},
      {'id': 'owner_003', 'name': '家庭', 'icon': 'family_restroom', 'sort': 2, 'is_default': 1},
      {'id': 'owner_004', 'name': '宝宝', 'icon': 'child_care', 'sort': 3, 'is_default': 1},
      {'id': 'owner_005', 'name': '儿子', 'icon': 'face', 'sort': 4, 'is_default': 1},
      {'id': 'owner_006', 'name': '女儿', 'icon': 'face', 'sort': 5, 'is_default': 1},
      {'id': 'owner_007', 'name': '父母', 'icon': 'elderly', 'sort': 6, 'is_default': 1},
    ];

    for (var owner in defaultOwners) {
      await db.rawInsert('''
        INSERT OR IGNORE INTO owners (id, name, icon, sort_order, is_default, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
      ''', [
        owner['id'],
        owner['name'],
        owner['icon'],
        owner['sort'],
        owner['is_default'],
        DateTime.now().toIso8601String(),
      ]);
    }
  }

  // ==================== 商家操作 ====================

  Future<List<Map<String, dynamic>>> getAllMerchants() async {
    final db = await instance.database;
    return await db.query('merchants', orderBy: 'sort_order ASC');
  }

  Future<int> insertMerchant(Map<String, dynamic> merchant) async {
    final db = await instance.database;
    final name = merchant['name'];
    
    // 检查是否已存在
    final existing = await db.query('merchants', where: 'name = ?', whereArgs: [name]);
    if (existing.isNotEmpty) {
      // 已存在则更新
      return await db.update(
        'merchants',
        {
          'icon': merchant['icon'] ?? 'store',
          'sort_order': merchant['sort_order'] ?? 0,
        },
        where: 'name = ?',
        whereArgs: [name],
      );
    }
    
    // 不存在则插入
    return await db.insert('merchants', {
      'id': merchant['id'] ?? _uuid.v4(),
      'name': merchant['name'],
      'icon': merchant['icon'] ?? 'store',
      'sort_order': merchant['sort_order'] ?? 0,
      'is_default': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateMerchant(String id, Map<String, dynamic> merchant) async {
    final db = await instance.database;
    return await db.update(
      'merchants',
      merchant,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMerchant(String id) async {
    final db = await instance.database;
    return await db.delete('merchants', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 归属人操作 ====================

  Future<List<Map<String, dynamic>>> getAllOwners() async {
    final db = await instance.database;
    return await db.query('owners', orderBy: 'sort_order ASC');
  }

  Future<int> insertOwner(Map<String, dynamic> owner) async {
    final db = await instance.database;
    return await db.insert('owners', {
      'id': owner['id'] ?? _uuid.v4(),
      'name': owner['name'],
      'icon': owner['icon'] ?? 'person',
      'sort_order': owner['sort_order'] ?? 0,
      'is_default': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> updateOwner(String id, Map<String, dynamic> owner) async {
    final db = await instance.database;
    return await db.update(
      'owners',
      owner,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteOwner(String id) async {
    final db = await instance.database;
    return await db.delete('owners', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 余额变更记录操作 ====================

  Future<int> insertBalanceChange({
    required String accountId,
    required double oldBalance,
    required double newBalance,
    String? reason,
  }) async {
    final db = await instance.database;
    return await db.insert('balance_changes', {
      'id': _uuid.v4(),
      'account_id': accountId,
      'old_balance': oldBalance,
      'new_balance': newBalance,
      'change_amount': newBalance - oldBalance,
      'reason': reason ?? '余额调整',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<int> insertBalanceChangeRaw(Map<String, dynamic> balanceChange) async {
    final db = await instance.database;
    return await db.insert('balance_changes', {
      'id': balanceChange['id'] ?? _uuid.v4(),
      'account_id': balanceChange['account_id'],
      'old_balance': balanceChange['old_balance'],
      'new_balance': balanceChange['new_balance'],
      'change_amount': balanceChange['change_amount'],
      'reason': balanceChange['reason'] ?? '余额调整',
      'created_at': balanceChange['created_at'] ?? DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getBalanceChanges(String accountId) async {
    final db = await instance.database;
    return await db.query(
      'balance_changes',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllBalanceChanges() async {
    final db = await instance.database;
    return await db.query(
      'balance_changes',
      orderBy: 'created_at DESC',
    );
  }

  // ==================== 交易记录操作 ====================

  Future<int> insertTransaction(models.Transaction transaction) async {
    final db = await instance.database;
    
    // 更新账户余额（调整类型不更新余额，因为是直接设置余额）
    if (transaction.type == TransactionType.expense) {
      await updateAccountBalance(transaction.accountId, -transaction.amount);
    } else if (transaction.type == TransactionType.income) {
      await updateAccountBalance(transaction.accountId, transaction.amount);
    } else if (transaction.type == TransactionType.transfer && transaction.targetAccountId != null) {
      await updateAccountBalance(transaction.accountId, -transaction.amount);
      await updateAccountBalance(transaction.targetAccountId!, transaction.amount);
    }
    
    return await db.insert('transactions', transaction.toMap());
  }

  Future<int> insertTransactionWithoutBalanceUpdate(models.Transaction transaction) async {
    final db = await instance.database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<models.Transaction>> getAllTransactions() async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      orderBy: 'date DESC, created_at DESC',
    );
    return result.map((map) => models.Transaction.fromMap(map)).toList();
  }

  Future<List<models.Transaction>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC, created_at DESC',
    );
    return result.map((map) => models.Transaction.fromMap(map)).toList();
  }

  Future<models.Transaction?> getTransactionById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return models.Transaction.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateTransaction(models.Transaction transaction) async {
    final db = await instance.database;
    
    // 获取旧记录以更新账户余额
    final oldTransaction = await getTransactionById(transaction.id);
    if (oldTransaction != null) {
      // 回退旧余额
      if (oldTransaction.type == TransactionType.expense) {
        await updateAccountBalance(oldTransaction.accountId, oldTransaction.amount);
      } else if (oldTransaction.type == TransactionType.income) {
        await updateAccountBalance(oldTransaction.accountId, -oldTransaction.amount);
      }

      // 更新新余额
      if (transaction.type == TransactionType.expense) {
        await updateAccountBalance(transaction.accountId, -transaction.amount);
      } else if (transaction.type == TransactionType.income) {
        await updateAccountBalance(transaction.accountId, transaction.amount);
      }
    }
    
    return await db.update(
      'transactions',
      transaction.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(String id) async {
    final db = await instance.database;
    
    // 获取交易记录以更新账户余额
    final transaction = await getTransactionById(id);
    if (transaction != null) {
      // 回退账户余额
      if (transaction.type == TransactionType.expense) {
        await updateAccountBalance(transaction.accountId, transaction.amount);
      } else if (transaction.type == TransactionType.income) {
        await updateAccountBalance(transaction.accountId, -transaction.amount);
      } else if (transaction.type == TransactionType.transfer && transaction.targetAccountId != null) {
        await updateAccountBalance(transaction.accountId, transaction.amount);
        await updateAccountBalance(transaction.targetAccountId!, -transaction.amount);
      }
    }
    
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== 分类操作 ====================

  Future<List<models.Category>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query(
      'categories',
      orderBy: 'sort_order ASC',
    );
    return result.map((map) => models.Category.fromMap(map)).toList();
  }

  Future<models.Category?> getCategoryById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return models.Category.fromMap(result.first);
    }
    return null;
  }

  Future<int> insertCategory(models.Category category) async {
    final db = await instance.database;
    return await db.insert('categories', category.toMap());
  }

  // ==================== 账户操作 ====================

  Future<List<models.Account>> getAllAccounts() async {
    final db = await instance.database;
    final result = await db.query(
      'accounts',
      orderBy: 'sort_order ASC',
    );
    return result.map((map) => models.Account.fromMap(map)).toList();
  }

  Future<models.Account?> getAccountById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return models.Account.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateAccountBalance(String accountId, double amount) async {
    final db = await instance.database;
    
    final accountResult = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    );
    
    if (accountResult.isEmpty) {
      return 0;
    }
    
    final accountType = accountResult.first['type'] as String;
    final isDebtAccount = accountType == 'credit' || accountType == 'receivable' || accountType == 'payable';
    
    double actualAmount = amount;
    if (isDebtAccount) {
      actualAmount = -amount;
    }
    
    await db.rawUpdate('''
      UPDATE accounts 
      SET balance = balance + ? 
      WHERE id = ?
    ''', [actualAmount, accountId]);
    
    return amount.toInt();
  }

  Future<int> updateAccountBalanceDirect(String accountId, double newBalance) async {
    final db = await instance.database;
    await db.rawUpdate('''
      UPDATE accounts 
      SET balance = ? 
      WHERE id = ?
    ''', [newBalance, accountId]);
    
    return 1;
  }

  Future<double> calculateAccountBalance(String accountId) async {
    final db = await instance.database;
    
    // 从0开始计算（不依赖账户当前余额）
    double balance = 0;
    
    // 计算所有交易的影响
    final transactions = await db.query(
      'transactions',
      where: 'account_id = ? OR target_account_id = ?',
      whereArgs: [accountId, accountId],
    );
    
    for (var t in transactions) {
      final type = t['type'] as String;
      final amount = t['amount'] as double? ?? 0;
      final accountIdInTx = t['account_id'] as String;
      final targetAccountId = t['target_account_id'] as String?;
      
      if (type == 'expense') {
        balance -= amount;
      } else if (type == 'income') {
        balance += amount;
      } else if (type == 'transfer') {
        if (accountIdInTx == accountId) {
          balance -= amount; // 转出
        } else if (targetAccountId == accountId) {
          balance += amount; // 转入
        }
      }
    }
    
    return balance;
  }

  Future<int> updateAccount(models.Account account) async {
    final db = await instance.database;
    return await db.update(
      'accounts',
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(String id) async {
    final db = await instance.database;
    return await db.delete(
      'accounts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertAccount(models.Account account) async {
    final db = await instance.database;
    return await db.insert('accounts', account.toMap());
  }

  Future<List<models.Transaction>> getTransactionsByAccount(String accountId) async {
    final db = await instance.database;
    final result = await db.query(
      'transactions',
      where: 'account_id = ? OR target_account_id = ?',
      whereArgs: [accountId, accountId],
      orderBy: 'date DESC',
    );
    return result.map((map) => models.Transaction.fromMap(map)).toList();
  }

  // ==================== 统计操作 ====================

  Future<Map<String, double>> getExpenseByCategory(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense' 
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY c.name
      ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<String, double> map = {};
    for (var row in result) {
      map[row['name'] as String] = row['total'] as double;
    }
    return map;
  }

  Future<Map<String, double>> getIncomeByCategory(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT c.name, SUM(t.amount) as total
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'income' 
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY c.name
      ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<String, double> map = {};
    for (var row in result) {
      map[row['name'] as String] = row['total'] as double;
    }
    return map;
  }

  Future<double> getTotalExpense(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE type = 'expense' 
        AND date >= ? 
        AND date <= ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return result.first['total'] as double? ?? 0.0;
  }

  Future<double> getTotalIncome(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT SUM(amount) as total
      FROM transactions
      WHERE type = 'income' 
        AND date >= ? 
        AND date <= ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return result.first['total'] as double? ?? 0.0;
  }

  Future<Map<String, double>> getDailyExpense(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT date(date) as day, SUM(amount) as total
      FROM transactions
      WHERE type = 'expense' 
        AND date >= ? 
        AND date <= ?
      GROUP BY date(date)
      ORDER BY day ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<String, double> map = {};
    for (var row in result) {
      map[row['day'] as String] = row['total'] as double;
    }
    return map;
  }

  Future<Map<String, double>> getDailyIncome(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT date(date) as day, SUM(amount) as total
      FROM transactions
      WHERE type = 'income' 
        AND date >= ? 
        AND date <= ?
      GROUP BY date(date)
      ORDER BY day ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<String, double> map = {};
    for (var row in result) {
      map[row['day'] as String] = row['total'] as double;
    }
    return map;
  }

  Future<Map<String, double>> getExpenseByAccount(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT a.name, SUM(t.amount) as total
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      WHERE t.type = 'expense' 
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY a.name
      ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<String, double> map = {};
    for (var row in result) {
      map[row['name'] as String] = row['total'] as double;
    }
    return map;
  }

  Future<Map<String, double>> getIncomeByAccount(DateTime start, DateTime end) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT a.name, SUM(t.amount) as total
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      WHERE t.type = 'income' 
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY a.name
      ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<String, double> map = {};
    for (var row in result) {
      map[row['name'] as String] = row['total'] as double;
    }
    return map;
  }

  Future<List<Map<String, dynamic>>> getExpenseDetailsByOwner({
    required DateTime start,
    required DateTime end,
    String? owner,
  }) async {
    final db = await instance.database;
    String whereClause = "t.type = 'expense' AND t.date >= ? AND t.date <= ?";
    List<dynamic> args = [start.toIso8601String(), end.toIso8601String()];
    
    if (owner != null && owner.isNotEmpty) {
      whereClause += " AND t.owner = ?";
      args.add(owner);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        t.id, t.amount, t.date, t.remark, t.merchant,
        c.name as category_name, c.icon as category_icon, c.color as category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE $whereClause
      ORDER BY t.date DESC
    ''', args);
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getIncomeDetailsByOwner({
    required DateTime start,
    required DateTime end,
    String? owner,
  }) async {
    final db = await instance.database;
    String whereClause = "t.type = 'income' AND t.date >= ? AND t.date <= ?";
    List<dynamic> args = [start.toIso8601String(), end.toIso8601String()];
    
    if (owner != null && owner.isNotEmpty) {
      whereClause += " AND t.owner = ?";
      args.add(owner);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        t.id, t.amount, t.date, t.remark, t.merchant,
        c.name as category_name, c.icon as category_icon, c.color as category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE $whereClause
      ORDER BY t.date DESC
    ''', args);
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getIncomeDetailsByAccount({
    required DateTime start,
    required DateTime end,
    String? accountName,
  }) async {
    final db = await instance.database;
    String whereClause = "t.type = 'income' AND t.date >= ? AND t.date <= ?";
    List<dynamic> args = [start.toIso8601String(), end.toIso8601String()];
    
    if (accountName != null && accountName.isNotEmpty) {
      whereClause += " AND a.name = ?";
      args.add(accountName);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        t.id, t.amount, t.date, t.remark, t.merchant,
        c.name as category_name, c.icon as category_icon, c.color as category_color,
        a.name as account_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      JOIN accounts a ON t.account_id = a.id
      WHERE $whereClause
      ORDER BY t.date DESC
    ''', args);
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getExpenseDetailsByAccount({
    required DateTime start,
    required DateTime end,
    String? accountName,
  }) async {
    final db = await instance.database;
    String whereClause = "t.type = 'expense' AND t.date >= ? AND t.date <= ?";
    List<dynamic> args = [start.toIso8601String(), end.toIso8601String()];
    
    if (accountName != null && accountName.isNotEmpty) {
      whereClause += " AND a.name = ?";
      args.add(accountName);
    }
    
    final result = await db.rawQuery('''
      SELECT 
        t.id, t.amount, t.date, t.remark, t.merchant,
        c.name as category_name, c.icon as category_icon, c.color as category_color,
        a.name as account_name
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      JOIN accounts a ON t.account_id = a.id
      WHERE $whereClause
      ORDER BY t.date DESC
    ''', args);
    
    return result;
  }

  // ==================== TopN 消费排行 ====================

  Future<List<Map<String, dynamic>>> getExpenseTopNByCategory({
    required DateTime start,
    required DateTime end,
    int limit = 10,
  }) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT c.id, c.name, c.icon, c.color, SUM(t.amount) as total, COUNT(*) as count
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense' 
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY c.id
      ORDER BY total DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);
  }

  Future<List<Map<String, dynamic>>> getExpenseTopNByMerchant({
    required DateTime start,
    required DateTime end,
    int limit = 10,
  }) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT t.merchant, SUM(t.amount) as total, COUNT(*) as count
      FROM transactions t
      WHERE t.type = 'expense' 
        AND t.merchant IS NOT NULL
        AND t.merchant != ''
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY t.merchant
      ORDER BY total DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);
  }

  Future<List<Map<String, dynamic>>> getExpenseTopNByProject({
    required DateTime start,
    required DateTime end,
    int limit = 10,
  }) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT t.project, SUM(t.amount) as total, COUNT(*) as count
      FROM transactions t
      WHERE t.type = 'expense' 
        AND t.project IS NOT NULL
        AND t.project != ''
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY t.project
      ORDER BY total DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);
  }

  Future<List<Map<String, dynamic>>> getExpenseTopNByAccount({
    required DateTime start,
    required DateTime end,
    int limit = 10,
  }) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT a.id, a.name, a.icon, a.type, SUM(t.amount) as total, COUNT(*) as count
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      WHERE t.type = 'expense' 
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY a.id
      ORDER BY total DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);
  }

  // ==================== 商家消费分析 ====================

  Future<List<Map<String, dynamic>>> getMerchantExpenseDetail({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        t.merchant,
        SUM(t.amount) as total,
        COUNT(*) as count,
        AVG(t.amount) as avg_amount,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color
      FROM transactions t
      LEFT JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense' 
        AND t.merchant IS NOT NULL
        AND t.merchant != ''
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY t.merchant
      ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  Future<Map<String, double>> getMerchantMonthlyTrend({
    required String merchant,
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT strftime('%Y-%m', t.date) as month, SUM(t.amount) as total
      FROM transactions t
      WHERE t.type = 'expense' 
        AND t.merchant = ?
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY strftime('%Y-%m', t.date)
      ORDER BY month ASC
    ''', [merchant, start.toIso8601String(), end.toIso8601String()]);

    Map<String, double> map = {};
    for (var row in result) {
      map[row['month'] as String] = row['total'] as double;
    }
    return map;
  }

  // ==================== 转账记录报告 ====================

  Future<List<Map<String, dynamic>>> getTransferRecords({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT 
        t.id,
        t.amount,
        t.date,
        t.remark,
        a1.name as from_account,
        a2.name as to_account,
        a1.icon as from_icon,
        a2.icon as to_icon
      FROM transactions t
      JOIN accounts a1 ON t.account_id = a1.id
      JOIN accounts a2 ON t.target_account_id = a2.id
      WHERE t.type = 'transfer'
        AND t.date >= ? 
        AND t.date <= ?
      ORDER BY t.date DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  Future<Map<String, dynamic>> getTransferSummary({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await instance.database;
    
    final totalResult = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(amount), 0) as total,
        COUNT(*) as count
      FROM transactions
      WHERE type = 'transfer'
        AND date >= ? 
        AND date <= ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final fromResult = await db.rawQuery('''
      SELECT a.name, a.icon, SUM(t.amount) as total
      FROM transactions t
      JOIN accounts a ON t.account_id = a.id
      WHERE t.type = 'transfer'
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY a.name
      ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final toResult = await db.rawQuery('''
      SELECT a.name, a.icon, SUM(t.amount) as total
      FROM transactions t
      JOIN accounts a ON t.target_account_id = a.id
      WHERE t.type = 'transfer'
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY a.name
      ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return {
      'total': totalResult.first['total'] ?? 0.0,
      'count': totalResult.first['count'] ?? 0,
      'fromAccounts': fromResult,
      'toAccounts': toResult,
    };
  }

  // ==================== 消费热力图 ====================

  Future<Map<int, double>> getExpenseByDayOfWeek({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        CAST(strftime('%w', date) AS INTEGER) as day_of_week,
        SUM(amount) as total
      FROM transactions
      WHERE type = 'expense'
        AND date >= ? 
        AND date <= ?
      GROUP BY strftime('%w', date)
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<int, double> map = {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
    for (var row in result) {
      map[row['day_of_week'] as int] = row['total'] as double;
    }
    return map;
  }

  Future<Map<int, double>> getExpenseByDayOfMonth({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        CAST(strftime('%d', date) AS INTEGER) as day,
        SUM(amount) as total
      FROM transactions
      WHERE type = 'expense'
        AND date >= ? 
        AND date <= ?
      GROUP BY strftime('%d', date)
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<int, double> map = {};
    for (var row in result) {
      map[row['day'] as int] = row['total'] as double;
    }
    return map;
  }

  Future<Map<String, double>> getExpenseByDate({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT 
        date(date) as day,
        SUM(amount) as total
      FROM transactions
      WHERE type = 'expense'
        AND date >= ? 
        AND date <= ?
      GROUP BY date(date)
    ''', [start.toIso8601String(), end.toIso8601String()]);

    Map<String, double> map = {};
    for (var row in result) {
      map[row['day'] as String] = row['total'] as double;
    }
    return map;
  }

  // ==================== 周期性支出分析 ====================

  Future<List<Map<String, dynamic>>> getRecurringExpenses({
    required DateTime start,
    required DateTime end,
  }) async {
    final db = await instance.database;
    
    return await db.rawQuery('''
      SELECT 
        category_id,
        c.name as category_name,
        c.icon as category_icon,
        c.color as category_color,
        merchant,
        project,
        AVG(amount) as avg_amount,
        COUNT(*) as count,
        MIN(amount) as min_amount,
        MAX(amount) as max_amount
      FROM transactions t
      JOIN categories c ON t.category_id = c.id
      WHERE t.type = 'expense'
        AND t.date >= ? 
        AND t.date <= ?
      GROUP BY category_id, COALESCE(merchant, ''), COALESCE(project, '')
      HAVING count >= 3
      ORDER BY avg_amount DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
  }

  // ==================== 商家学习 ====================

  Future<void> learnMerchant(String name, String? category) async {
    final db = await instance.database;
    
    // 检查商家是否存在
    final result = await db.query(
      'merchants',
      where: 'name = ?',
      whereArgs: [name],
    );

    if (result.isNotEmpty) {
      // 更新商家记录
      await db.update(
        'merchants',
        {
          'user_category': category,
          'count': (result.first['count'] as int) + 1,
          'last_used_at': DateTime.now().toIso8601String(),
        },
        where: 'name = ?',
        whereArgs: [name],
      );
    } else {
      // 插入新商家
      await db.insert('merchants', {
        'id': _uuid.v4(),
        'name': name,
        'suggested_category': category,
        'user_category': category,
        'count': 1,
        'last_used_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ==================== 配置操作 ====================

  Future<String?> getConfig(String key) async {
    final db = await instance.database;
    final result = await db.query(
      'app_config',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  Future<void> setConfig(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'app_config',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ==================== 清空数据 ====================

  Future<void> clearAllData() async {
    final db = await instance.database;
    
    // 关闭当前数据库连接
    await db.close();
    _database = null;
    
    // 删除数据库文件
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'expense_tracker.db');
    await deleteDatabase(path);
    
    // 重新初始化数据库
    _database = await _initDB('expense_tracker.db');
    final newDb = _database!;
    
    // 重新初始化默认数据
    await _initDefaultAccounts(newDb);
    await _initDefaultOwners(newDb);
    await _initDefaultData(newDb);
  }

  // ==================== 备份记录操作 ====================

  Future<int> insertBackupRecord(Map<String, dynamic> backupRecord) async {
    final db = await instance.database;
    return await db.insert('backup_records', {
      'id': backupRecord['id'] ?? _uuid.v4(),
      'file_path': backupRecord['file_path'],
      'file_name': backupRecord['file_name'],
      'file_size': backupRecord['file_size'],
      'record_count': backupRecord['record_count'],
      'backup_type': backupRecord['backup_type'] ?? 'manual',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllBackupRecords() async {
    final db = await instance.database;
    return await db.query('backup_records', orderBy: 'created_at DESC');
  }

  Future<int> deleteBackupRecord(String id) async {
    final db = await instance.database;
    return await db.delete('backup_records', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== 导入记录操作 ====================

  Future<int> insertImportRecord(Map<String, dynamic> importRecord) async {
    final db = await instance.database;
    return await db.insert('import_records', {
      'id': importRecord['id'] ?? _uuid.v4(),
      'file_name': importRecord['file_name'],
      'source_type': importRecord['source_type'],
      'total_records': importRecord['total_records'],
      'success_count': importRecord['success_count'],
      'fail_count': importRecord['fail_count'],
      'import_mode': importRecord['import_mode'] ?? 'merge',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllImportRecords() async {
    final db = await instance.database;
    return await db.query('import_records', orderBy: 'created_at DESC');
  }

  Future<int> deleteImportRecord(String id) async {
    final db = await instance.database;
    return await db.delete('import_records', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
