import 'package:flutter/foundation.dart';
import '../data/models/transaction_type.dart';
import '../database/database_helper.dart';

class ParseResult {
  final TransactionType type;
  final double? amount;
  final String? account;  // 转出账户（转账时）
  final String? targetAccount;  // 转入账户（转账时）
  final String? category;
  final String? merchant;
  final String? owner;
  final String? project;
  final DateTime? date;
  final String remark;
  final double confidence;
  final List<ParseResult>? multipleResults; // 多笔记录

  ParseResult({
    required this.type,
    this.amount,
    this.account,
    this.targetAccount,
    this.category,
    this.merchant,
    this.owner,
    this.project,
    this.date,
    this.remark = '',
    this.confidence = 0.0,
    this.multipleResults,
  });

  @override
  String toString() {
    return 'ParseResult(type: $type, amount: $amount, account: $account, targetAccount: $targetAccount, '
           'category: $category, merchant: $merchant, owner: $owner, '
           'project: $project, date: $date, confidence: $confidence, '
           'multipleResults: ${multipleResults?.length ?? 0})';
  }
}

class TextParser {
  static List<String> _userOwners = [];
  static List<String> _userMerchants = [];
  static List<Map<String, dynamic>> _userAccounts = [];
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final owners = await DatabaseHelper.instance.getAllOwners();
      _userOwners = owners.map((o) => o['name'] as String).toList();
      
      final merchants = await DatabaseHelper.instance.getAllMerchants();
      _userMerchants = merchants.map((m) => m['name'] as String).toList();
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('TextParser初始化失败: $e');
    }
  }

  static void updateUserData({
    List<String>? owners,
    List<String>? merchants,
    List<Map<String, dynamic>>? accounts,
  }) {
    if (owners != null) _userOwners = owners;
    if (merchants != null) _userMerchants = merchants;
    if (accounts != null) _userAccounts = accounts;
    _isInitialized = true;
  }

  // 支出分类关键词映射（对应二级分类名称）
  static const Map<String, List<String>> expenseCategoryKeywords = {
    // 1. 食品酒水 - 买菜（优先匹配）
    '买菜': [
      '买菜', '买菜钱', '菜钱', '超市买菜', '买菜回来', '买了菜', 
      '买食材', '买食品', '买吃的东西',
      '蔬菜', '青菜', '白菜', '萝卜', '土豆', '西红柿', '黄瓜', '茄子',
      '豆角', '洋葱', '大蒜', '生姜', '辣椒', '芹菜', '菠菜', '生菜',
      '猪肉', '牛肉', '羊肉', '鸡肉', '鸭肉', '排骨', '五花肉', '瘦肉',
      '豆腐', '豆芽', '腐竹', '木耳', '香菇', '金针菇', '平菇',
      '肉', '鱼', '虾', '海鲜',
    ],
    // 1. 食品酒水 - 柴米油盐
    '柴米油盐': [
      '柴米油盐', '盐', '酱油', '醋', '米', '面粉', '调料', '味精', '鸡精',
    ],
    // 1. 食品酒水 - 早餐
    '早餐': [
      '早餐', '吃早餐', '早饭', '早茶',
      '包子', '馒头', '豆浆', '油条', '鸡蛋', '粥', '肠粉', '煎饼',
    ],
    // 1. 食品酒水 - 午餐
    '午餐': [
      '午餐', '中饭', '吃午饭', '午饭', '工作餐',
    ],
    // 1. 食品酒水 - 晚餐
    '晚餐': [
      '晚餐', '晚饭', '吃晚饭', '夜宵', '宵夜',
    ],
    // 1. 食品酒水 - 水果
    '水果': [
      '水果', '苹果', '香蕉', '橙子', '西瓜', '葡萄', '梨', '桃子', '芒果',
      '草莓', '蓝莓', '火龙果', '猕猴桃', '柚子', '桔子', '荔枝', '龙眼',
    ],
    // 1. 食品酒水 - 零食
    '零食': [
      '零食', '小吃', '薯片', '饼干', '糖果', '巧克力', '瓜子', '花生', '坚果',
      '果干', '肉干', '泡面', '方便面', '雪糕', '冰淇淋', '酸奶',
    ],
    // 1. 食品酒水 - 饮料酒水
    '饮料酒水': [
      '奶茶', '咖啡', '茶', '饮料', '果汁', '可乐', '雪碧', '啤酒', '白酒', '酒',
      '矿泉水', '水', '牛奶', '酸奶', '红牛', '王老吉', '加多宝',
    ],
    // 1. 食品酒水 - 外出美食
    '外出美食': [
      '外卖', '餐厅', '吃饭', '食堂', '快餐', '路边摊', '大排档', '吃面',
      '火锅', '烧烤', '烤肉', '麻辣烫', '酸辣粉', '面条', '米粉', '米饭',
      '盒饭', '炒菜', '烧菜', '做菜', '肯德基', '麦当劳', '汉堡', '披萨', '炸鸡',
    ],
    // 2. 居家生活 - 房租
    '房租': [
      '房租', '租金', '住房', '房租费', '租房子',
    ],
    // 2. 居家生活 - 物业费
    '物业费': [
      '物业费', '物业管理费', '物业',
    ],
    // 2. 居家生活 - 电费
    '电费': [
      '电费', '电表', '电钱', '电费单',
    ],
    // 2. 居家生活 - 水费
    '水费': [
      '水费', '水表', '水钱', '水费单', '自来水费',
    ],
    // 2. 居家生活 - 燃气费
    '燃气费': [
      '燃气费', '煤气费', '天然气费', '燃气', '煤气',
    ],
    // 2. 居家生活 - 电视费
    '电视费': [
      '电视费', '有线电视费', '收视费', '有线费',
    ],
    // 2. 居家生活 - 维修费
    '维修费': [
      '维修费', '修理费', '修东西', '维修', '修理', '装维修',
    ],
    // 2. 居家生活 - 快递费
    '快递费': [
      '快递费', '运费', '寄快递', '寄件', '物流', '邮政',
    ],
    // 3. 交流通讯 - 手机话费
    '手机话费': [
      '手机话费', '话费', '充话费', '充值', '月租', '套餐',
      '移动', '联通', '电信', '手机费',
    ],
    // 3. 交流通讯 - 网费
    '网费': [
      '网费', '宽带费', '宽带', 'wifi', '无线网', '网络费', '上网费',
    ],
    // 3. 交流通讯 - 座机费
    '座机费': [
      '座机费', '电话费', '固定电话费',
    ],
    // 4. 休闲娱乐 - 彩票
    '彩票': [
      '彩票', '体彩', '福彩', '足彩', '双色球', '大乐透', '刮刮乐', '买彩票',
    ],
    // 4. 休闲娱乐 - 棋牌
    '棋牌': [
      '棋牌', '打牌', '扑克', '纸牌',
    ],
    // 4. 休闲娱乐 - 麻将
    '麻将': [
      '麻将', '打麻将', '搓麻将',
    ],
    // 4. 休闲娱乐 - K歌
    'K歌': [
      'K歌', '唱歌', '唱K', 'KTV', '卡拉OK', '欢唱',
    ],
    // 4. 休闲娱乐 - 网游
    '网游': [
      '网游', '游戏', '玩游戏', '游戏点卡', '手游', '网络游戏',
    ],
    // 4. 休闲娱乐 - 运动
    '运动': [
      '运动', '健身', '健身房', '游泳', '瑜伽', '打球', '羽毛球', '乒乓球', '网球',
    ],
    // 4. 休闲娱乐 - 电影
    '电影': [
      '电影', '看电影', '影院', 'imax', '票', '电影票',
    ],
    // 4. 休闲娱乐 - 演唱会
    '演唱会': [
      '演唱会', '音乐会', '演出', '话剧', '戏剧', '音乐会', '门票',
    ],
    // 4. 休闲娱乐 - 聚会
    '聚会': [
      '聚会', '聚餐', '团建', '同学会', '朋友聚会',
    ],
    // 5. 人情费用 - 红包
    '红包': [
      '红包', '发红包', '给红包', '收红包', '领红包', '随礼',
    ],
    // 5. 人情费用 - 孝敬长辈
    '孝敬长辈': [
      '孝敬', '给父母', '给爸妈', '孝顺', '给老人', '长辈',
    ],
    // 5. 人情费用 - 请客
    '请客': [
      '请客', '我请', '我买单', '请吃饭',
    ],
    // 6. 宝宝费用 - 宝宝用品
    '宝宝用品': [
      '尿不湿', '尿布', '奶粉', '奶瓶', '婴儿床', '婴儿车', '宝宝用品', '童装', '童鞋',
    ],
    // 6. 宝宝费用 - 宝宝食品
    '宝宝食品': [
      '宝宝奶粉', '辅食', '宝宝零食', '婴儿食品',
    ],
    // 6. 宝宝费用 - 宝宝教育
    '宝宝教育': [
      '早教', '培训', '学费', '幼儿园', '托儿所', '宝宝教育',
    ],
    // 6. 宝宝费用 - 医疗护理
    '医疗护理': [
      '宝宝看病', '宝宝发烧', '婴儿体检', '疫苗', '宝宝医疗',
    ],
    // 7. 行车交通 - 地铁
    '地铁': [
      '地铁', '坐地铁', '地铁票',
    ],
    // 7. 行车交通 - 公交
    '公交': [
      '公交', '公交车', '坐公交', '巴士',
    ],
    // 7. 行车交通 - 打车
    '打车': [
      '打车', '滴滴', '网约车', '的士', '出租车', '叫车',
    ],
    // 7. 行车交通 - 加油
    '加油': [
      '加油', '油费', '汽油', '柴油', '加油费', '油钱',
    ],
    // 7. 行车交通 - 停车
    '停车': [
      '停车', '停车费', '停车钱', '停车場',
    ],
    // 7. 行车交通 - 保养
    '保养': [
      '保养', '汽车保养', '保养费',
    ],
    // 7. 行车交通 - 维修
    '维修': [
      '修车', '汽车维修', '车维修', '修车费',
    ],
    // 7. 行车交通 - 汽车保险
    '汽车保险': [
      '车险', '汽车保险', '保险费', '交强险', '商业险',
    ],
    // 7. 行车交通 - 违章罚款
    '违章罚款': [
      '罚款', '违章', '罚单', '扣分',
    ],
    // 8. 购物消费 - 日常用品
    '日常用品': [
      '日常用品', '生活用品', '日用品', '必需品',
    ],
    // 8. 购物消费 - 超市购物
    '超市购物': [
      '超市', '超市购物', '逛超市', '去超市', '大润发', '沃尔玛', '永辉', '盒马',
      '小象超市', '物美', '华润', '世纪联华',
    ],
    // 8. 购物消费 - 美妆护肤
    '美妆护肤': [
      '化妆品', '护肤品', '口红', '面膜', '洗面奶', '防晒', '美妆', '美容',
    ],
    // 8. 购物消费 - 衣裤鞋帽
    '衣裤鞋帽': [
      '衣服', '裤子', '裙子', '鞋子', '帽子', '衣服', '裤', '裙', '鞋', '帽',
      'T恤', '衬衫', '外套', '羽绒服', '毛衣', '内衣', '袜子',
    ],
    // 8. 购物消费 - 电子数码
    '电子数码': [
      '手机', '电脑', '平板', '笔记本', '耳机', '充电宝', '数据线', '数码',
    ],
    // 8. 购物消费 - 洗护用品
    '洗护用品': [
      '洗发水', '沐浴露', '护发素', '洗手液', '洗衣液', '洗衣粉', '洗护',
    ],
    // 8. 购物消费 - 图书杂志
    '书报杂志': [
      '书', '书籍', '杂志', '报纸', '图书', '课外书',
    ],
    // 9. 医疗教育 - 药品费
    '药品费': [
      '药', '买药', '药品', '感冒药', '退烧药', '消炎药', '维生素', '钙片',
    ],
    // 9. 医疗教育 - 治疗费
    '治疗费': [
      '治疗费', '诊疗费', '挂号费', '门诊费', '手术费',
    ],
    // 9. 医疗教育 - 住院费
    '住院费': [
      '住院费', '住院', '病房费', '床位费',
    ],
  };
  
  // 收入分类关键词（增强版口语化）
  static const Map<String, List<String>> incomeCategoryKeywords = {
    '工资': [
      // 正式薪资
      '工资', '薪水', '月薪', '年薪', '底薪',
      // 口语表达
      '发工资', '工资到账', '发薪水', '工资条',
      '基本工资', '绩效工资', '加班费',
    ],
    '兼职': [
      '兼职', '副业', '外包', '私活',
      '兼职费', '外包费', '私活钱',
      '代工', '代工费',
      '兼职收入', '兼职定金', '兼职酬劳',
    ],
    '投资': [
      // 投资产品
      '理财', '投资', '基金', '股票', '债券', '黄金', '外汇',
      // 投资收益
      '分红', '利息', '收益', '获利', '回报',
      '理财收益', '基金收益', '股票收益', '分红款',
      '定投', '理财到账',
      '投资收益', '利息到账',
    ],
    '奖金': [
      // 奖励
      '奖金', '红包', '补贴',
      // 提成
      '提成', '绩效', '绩效奖', '销售提成',
      // 其他
      '年终奖', '过节费', '季度奖', '项目奖', '奖励',
      '红包', '微信红包', '支付宝红包', '领红包', '抢红包', '收红包',
      '家长红包', '节日红包', '抢到大红包',
    ],
    '其他收入': [
      // 退款
      '退款', '退费', '退货退款', '退款到账', '收到退款',
      // 报销
      '报销', '报销款', '报销费', '收到报销',
      // 赔偿
      '赔偿', '补偿',
      // 礼金
      '收礼金', '礼金',
      // 出售
      '卖废品', '卖二手收入', '卖闲置', '卖旧书', '卖旧手机',
      '货款', '收到货款',
      // 租金
      '收房租', '收租金',
      // 服务费
      '收服务费',
      // 其他
      '借入', '收钱', '收款', '转账入',
      '收定金', '收押金',
      '收小费',
      '收稿费',
      '收代买差价',
      '收到还款',
      '收会员费',
      '收拼车分摊',
      '收停车返现',
    ],
  };

  // 账户别名映射（增强版口语化）
  static const Map<String, String> accountAliases = {
    // 银行卡
    '招行卡': '招商银行', '招商': '招商银行', '招行': '招商银行',
    '建行卡': '建设银行', '建设': '建设银行', '建行': '建设银行',
    '工行卡': '工商银行', '工商': '工商银行', '工行': '工商银行',
    '农行卡': '农业银行', '农业': '农业银行', '农行': '农业银行',
    '中行卡': '中国银行', '中国银行': '中国银行', '中行': '中国银行',
    '交通卡': '交通银行', '交通': '交通银行', '交行': '交通银行',
    '邮政卡': '邮政储蓄', '邮储': '邮政储蓄', '邮政': '邮政储蓄',
    // 信用卡
    '招行信用卡': '招行信用卡', '招商银行信用卡': '招行信用卡', '招商信用卡': '招行信用卡',
    '建行信用卡': '建行信用卡', '建设银行信用卡': '建行信用卡', '建设信用卡': '建行信用卡',
    '工行信用卡': '工行信用卡', '工商银行信用卡': '工行信用卡', '工商信用卡': '工行信用卡',
    '农行信用卡': '农行信用卡', '农业银行信用卡': '农行信用卡', '农业信用卡': '农行信用卡',
    '交行信用卡': '交行信用卡', '交通银行信用卡': '交行信用卡', '交通信用卡': '交行信用卡',
    '信用卡': '信用卡', '贷记卡': '信用卡',
    // 支付平台
    '支付宝': '支付宝', '支付宝余额': '支付宝', '支付宝花呗': '花呗',
    '微信': '微信', '微信余额': '微信', '微信支付': '微信', '微信信用卡': '微信',
    '余额': '支付宝',
    // 贷款类
    '花呗': '花呗', '借呗': '借呗', '白条': '京东白条',
    // 其他
    '现金': '现金', '现金钱': '现金', '现钱': '现金',
    '零钱': '零钱', '零花钱': '零钱',
  };

  // 商家品牌列表（增强版）
  static const List<String> knownMerchants = [
    // 超市便利
    '小象超市', '永辉', '大润发', '盒马', '盒马鲜生', '盒马X',
    '沃尔玛', '家乐福', '世纪联华', '华润万家', '物美', '麦德龙', '山姆', '永旺',
    // 餐饮
    '饭店', '餐厅', '食堂', '快餐', '小吃', '大排档', '路边摊',
    '肯德基', '麦当劳', '汉堡王', '德克士', '必胜客', '达美乐',
    '海底捞', '呷哺呷哺', '小龙坎', '大龙燚', '蜀大侠', '巴奴',
    // 奶茶咖啡
    '星巴克', '喜茶', '瑞幸', '蜜雪冰城', '奈雪的茶', '霸王茶姬', '一点点',
    '茶百道', '古茗', '书亦烧仙草', '沪上阿姨', '茶颜悦色',
    // 电影娱乐
    '万达影城', 'CGV', '卢米埃', '横店影城', '金逸影城',
    '猫眼', '淘票票', '腾讯视频', '爱奇艺', '优酷', 'B站', '哔哩哔哩',
    // 生活服务
    '健身房', '游泳馆', '瑜伽', '美容', '美发', '理发', '干洗',
    '药店', '药房', '诊所', '医院', '卫生院',
    '快递', '物流', '菜鸟', '顺丰', '京东快递',
    '修鞋', '修手机', '修手表',
    '宠物店', '宠物医院', '花店', '鲜花',
    // 出行
    '滴滴', '高德', '曹操出行', 'T3出行', '携程', '去哪儿', '飞猪',
    // 购物平台
    '京东', '淘宝', '天猫', '拼多多', '苏宁', '国美', '唯品会',
    // 便利店
    '7-11', '全家', '罗森', '便利蜂', '好邻居',
  ];

  // 项目类型（增强版口语化）
  static const Map<String, List<String>> projectKeywords = {
    '生活必须': ['生活', '日常', '必需', '日常生活', '日常开销', '日常消费'],
    '工作支出': ['工作', '公司', '出差', '工作餐', '办公', '商务', '公事', '公款'],
    '娱乐休闲': ['娱乐', '休闲', '玩', '聚会', '约会', '玩乐', '放松'],
    '学习成长': ['学习', '教育', '培训', '成长', '提升', '进修', '文具'],
    '家庭支出': ['家庭', '家', '家用', '家事', '家庭开支', '家庭开销'],
    '人情往来': ['人情', '礼金', '送礼', '红包', '请客', '聚会', '发红包'],
  };

  ParseResult parse(String text) {
    // 特殊处理：检测是否包含多日期+多金额的情况
    final multipleResults = _extractMultipleDateAmounts(text);
    if (multipleResults != null && multipleResults.isNotEmpty) {
      // 返回一个包含多笔记录的结果
      return ParseResult(
        type: TransactionType.expense,
        remark: text,
        confidence: 0.9,
        multipleResults: multipleResults,
      );
    }

    double confidence = 0.0;
    TransactionType type = TransactionType.expense;
    double? amount;
    String? account;
    String? category;
    String? merchant;
    String owner = '本人';
    String? project = '日常';
    DateTime? date;

    // 1. 识别收支类型
    type = _detectType(text);
    // 特殊处理：如果包含"赔"、"亏损"、"亏了"等词，强制识别为支出
    if (text.contains('赔') || text.contains('亏') || text.contains('亏损') || text.contains('亏了')) {
      type = TransactionType.expense;
    }
    confidence += 0.2;

    // 2. 提取金额
    amount = _extractAmount(text);
    if (amount != null) {
      confidence += 0.3;
    }

    // 3. 提取日期
    date = _extractDate(text);
    if (date != null) {
      confidence += 0.05;
    }

    // 4. 匹配账户
    String? targetAccount;
    // 如果是转账类型，还需要匹配目标账户
    if (type == TransactionType.transfer) {
      targetAccount = _matchAccount(text, isTransfer: true, isTarget: true);
      account = _matchAccount(text, isTransfer: true, isSource: true);
    } else {
      account = _matchAccount(text);
    }
    if (account != null) {
      confidence += 0.1;
    }

    // 5. 提取商家（转账类型不提取商家，避免与账户混淆）
    if (type != TransactionType.transfer) {
      merchant = _extractMerchant(text, account: account);
      if (merchant != null) {
        confidence += 0.1;
      }
    }

    // 6. 提取归属人（必须在分类识别之前，用于联动判断）
    owner = _extractOwner(text);

    // 7. 智能分类（包含归属人+物品联动判断）
    category = _smartMatchCategory(text, type, owner);
    if (category != null) {
      confidence += 0.2;
    }

    // 8. 提取项目
    project = _matchProject(text);

    return ParseResult(
      type: type,
      amount: amount,
      account: account,
      targetAccount: targetAccount,
      category: category,
      merchant: merchant,
      owner: owner,
      project: project,
      date: date,
      remark: text,
      confidence: confidence > 1.0 ? 1.0 : confidence,
    );
  }

  TransactionType _detectType(String text) {
    if (text.contains('发红包') || text.contains('给红包')) {
      return TransactionType.expense;
    }
    
    // "收红包"或"领红包"是收入（收到钱）
    if (text.contains('收红包') || text.contains('领红包') || text.contains('抢红包')) {
      return TransactionType.income;
    }
    
    // 收入关键词（增强版口语化）
    final incomeKeywords = [
      '收入', '进账', '到账', '入账', '入',
      '赚', '赚了', '赚钱', '挣', '挣钱', '挣了',
      '工资', '薪水', '月薪', '发工资', '工资到账',
      '奖金', '拿奖金',
      '分红', '利息', '收益', '获利',
      '报销', '报销款', '报销费',
      '退款', '退费', '退货退款',
      '中奖', '奖品', '收', '收到',
      '兼职', '副业', '外包', '私活',
      '货款', '租金', '服务费', '定金', '押金',
      '小费', '稿费', '礼金', '还款',
      '卖废品', '卖二手', '卖闲置', '卖旧',
      '返现', '差价', '会员费',
      '房租', '租金到账', '收租金',
    ];
    
    // 转账关键词（增强版口语化）
    final transferKeywords = [
      '转账', '转给', '转到', '转到账户', '转出',
      '转账给', '转走', '转出去', '转出钱',
      '存入', '存钱', '存到',
      '提现', '取现', '取钱', '拿出',
      '划转', '划账', '转到微信', '转到支付宝',
      '从', '从卡里', '从账户',
    ];
    
    // 支出关键词（用于排除和二次确认）
    final expenseKeywords = [
      '花了', '消费', '购买', '付', '支付', '买单',
      '吃饭', '买', '花了', '用了', '消费了',
      '付钱', '付了', '花了', '开销', '支出',
    ];

    // 特殊处理：发红包/给红包/转红包 是支出，不是转账
    if (text.contains('红包')) {
      return TransactionType.expense;
    }

    // 特殊处理：给家人打钱（生活费、赡养费等）是支出，不是转账
    if (text.contains('生活费') || text.contains('赡养费') || 
        text.contains('打钱') || text.contains('给钱') || text.contains('零花钱')) {
      return TransactionType.expense;
    }

    // 优先检测转账
    for (var keyword in transferKeywords) {
      if (text.contains(keyword)) {
        // 转账关键词中包含"从XX到YY"的情况处理
        if ((text.contains('从') && text.contains('到')) || 
            (text.contains('转出') && text.contains('到'))) {
          return TransactionType.transfer;
        }
        // 简单的"存入"是收入，简单的"取现"是转账
        if (keyword == '存入' || keyword == '存钱' || keyword == '存到') {
          continue; // 存入可能是收入
        }
        return TransactionType.transfer;
      }
    }

    // 检测收入
    for (var keyword in incomeKeywords) {
      if (text.contains(keyword)) {
        return TransactionType.income;
      }
    }

    for (var keyword in expenseKeywords) {
      if (text.contains(keyword)) {
        return TransactionType.expense;
      }
    }

    return TransactionType.expense;
  }

  double? _extractAmount(String text) {
    // 优先级-2：多个金额单位连写
    // 支持：5元9毛8分、5角7分、6块3分、5元8分、30块9毛8分、30块9毛、30块8分等
    
    // 模式1：元/块 + 角/毛 + 分（如5元9毛8分、30块9毛8分）
    final pattern1 = RegExp(
      r'(\d+\.?\d*)\s*(?:元|块|块钱)\s*(\d+)\s*(?:角|毛)\s*(\d+)\s*分',
    );
    var match = pattern1.firstMatch(text);
    if (match != null) {
      double amount = double.parse(match.group(1)!);
      amount += double.parse(match.group(2)!) * 0.1;
      amount += double.parse(match.group(3)!) * 0.01;
      return amount;
    }
    
    // 模式2：元/块 + 角/毛（如5元9毛、30块9毛、20元3毛、9块8毛3、3元2毛3）
    // 逻辑：
    // - 如果没有"分"字，匹配"X元Y角"或"X元Y角Z"
    // - 如果有"分"字但模式1不匹配，也匹配
    // 注意："9块8毛3"和"3元2毛3"会被匹配为X.8X或X.2X
    if (!text.contains('分') || (text.contains('分') && match == null)) {
      final pattern2 = RegExp(
        r'(\d+)\s*(?:元|块|块钱)\s*(\d+)\s*(?:角|毛)\s*(\d+)?',
      );
      match = pattern2.firstMatch(text);
      if (match != null) {
        double amount = double.parse(match.group(1)!);
        amount += double.parse(match.group(2)!) * 0.1;
        if (match.group(3) != null) {
          amount += double.parse(match.group(3)!) * 0.01;
        }
        return amount;
      }
    }
    
    // 模式2.5：元/块 + 单独数字（如3元2、3块2，表示X元X角）
    // 排除已经有角/分的情况
    final pattern2_5 = RegExp(
      r'(\d+)\s*(?:元|块|块钱)\s*(\d+)(?!\s*(?:角|毛|分|元|块))',
    );
    match = pattern2_5.firstMatch(text);
    if (match != null) {
      double amount = double.parse(match.group(1)!);
      amount += double.parse(match.group(2)!) * 0.1;
      return amount;
    }
    
    // 模式3：元/块 + 分（如5元8分、6块3分、30块8分）
    // 注意：只有没有"角/毛"时才匹配这个
    final pattern3 = RegExp(
      r'(\d+)\s*(?:元|块|块钱)\s*(\d+)\s*分(?!\s*(?:角|毛|元|块))',
    );
    match = pattern3.firstMatch(text);
    if (match != null) {
      double amount = double.parse(match.group(1)!);
      amount += double.parse(match.group(2)!) * 0.01;
      return amount;
    }
    
    // 模式4：角/毛 + 分（如5角7分）
    final pattern4 = RegExp(
      r'(\d+)\s*(?:角|毛)\s*(\d+)\s*分',
    );
    match = pattern4.firstMatch(text);
    if (match != null) {
      double amount = double.parse(match.group(1)!) * 0.1;
      amount += double.parse(match.group(2)!) * 0.01;
      return amount;
    }
    
    // 模式5：角/毛单独（如5角、9毛）
    final pattern5 = RegExp(
      r'(\d+)\s*(?:角|毛)(?!\s*\d)',
    );
    match = pattern5.firstMatch(text);
    if (match != null) {
      return double.parse(match.group(1)!) * 0.1;
    }

    // 优先级-1：多个金额相加（如"50加38加62"）
    final addPattern = RegExp(r'(\d+\.?\d*)\s*[加加加]\s*(\d+\.?\d*)(?:\s*[加加加]\s*(\d+\.?\d*))?');
    final addMatch = addPattern.firstMatch(text);

    if (addMatch != null) {
      double total = double.parse(addMatch.group(1)!);
      if (addMatch.group(2) != null) {
        total += double.parse(addMatch.group(2)!);
      }
      if (addMatch.group(3) != null) {
        total += double.parse(addMatch.group(3)!);
      }
      return total;
    }

    // 优先级0：计算表达式（数量 × 单价）

    // 计算模式1："一共15瓶每瓶3.8元" 或 "总共15瓶每瓶3.8元"（直接相邻）
    final calcPattern1 = RegExp(
      r'(?:一共|总共|买了)(\d+\.?\d*)\s*(?:个|件|瓶|杯|斤|kg|kg|克|米|本|盒|包|袋|张|套)\s*(?:每|单价|每瓶|每个|每杯|每斤|每包)(\d+\.?\d*)',
    );
    final calcMatch1 = calcPattern1.firstMatch(text);

    if (calcMatch1 != null) {
      double quantity = double.parse(calcMatch1.group(1)!);
      double unitPrice = double.parse(calcMatch1.group(2)!);
      return quantity * unitPrice;
    }

    // 计算模式2：简写版 "15瓶×3.8元" 或 "15瓶x3.8元" 或 "15瓶*3.8元"
    final calcPattern2 = RegExp(
      r'(\d+\.?\d*)\s*(?:个|件|瓶|杯|斤|kg|kg|克|米|本|盒|包|袋|张|套)\s*[×xX*]\s*(\d+\.?\d*)\s*(?:元|块钱|块)?',
    );
    final calcMatch2 = calcPattern2.firstMatch(text);

    if (calcMatch2 != null) {
      double quantity = double.parse(calcMatch2.group(1)!);
      double unitPrice = double.parse(calcMatch2.group(2)!);
      return quantity * unitPrice;
    }

    // 计算模式3："每瓶3.8元，15瓶"
    final calcPattern3 = RegExp(
      r'(?:每|每瓶|每个|每杯|每斤|每包)(\d+\.?\d*)\s*(?:元|块钱|块)?[，,、]\s*(?:一共|总共)(\d+\.?\d*)\s*(?:个|件|瓶|杯|斤|kg|kg|克|米|本|盒|包|袋|张|套)',
    );
    final calcMatch3 = calcPattern3.firstMatch(text);

    if (calcMatch3 != null) {
      double unitPrice = double.parse(calcMatch3.group(1)!);
      double quantity = double.parse(calcMatch3.group(2)!);
      return quantity * unitPrice;
    }

    // 计算模式4：数量在前，单价在后，带单位 "20杯咖啡每杯18元"
    final calcPattern4 = RegExp(
      r'(\d+\.?\d*)\s*(?:个|件|瓶|杯|斤|kg|kg|克|米|本|盒|包|袋|张|套)\s*(?:\S+?)\s*(?:每|单价|每瓶|每个|每杯|每斤|每包)(\d+\.?\d*)\s*(?:元|块钱|块)',
    );
    final calcMatch4 = calcPattern4.firstMatch(text);

    if (calcMatch4 != null) {
      double quantity = double.parse(calcMatch4.group(1)!);
      double unitPrice = double.parse(calcMatch4.group(2)!);
      return quantity * unitPrice;
    }

    // 方法1：优先匹配带单位的金额（如9毛、3.5元、100块）
    // 匹配：9毛、3.5元、100块、30万、3.5k 等
    final withUnitPattern = RegExp(
      r'(\d+\.?\d*)\s*(元|块钱|块|rmb|RMB|万|千|百|毛|角|分|k|K|m|M)',
      caseSensitive: false,
    );
    final withUnitMatch = withUnitPattern.firstMatch(text);

    if (withUnitMatch != null) {
      double amount = double.parse(withUnitMatch.group(1)!);
      String unit = withUnitMatch.group(2)!;

      // 处理单位
      if (unit.contains('万')) {
        amount = amount * 10000;
      } else if (unit.contains('千')) {
        amount = amount * 1000;
      } else if (unit.contains('百')) {
        amount = amount * 100;
      } else if (unit.toLowerCase().contains('k')) {
        amount = amount * 1000;
      } else if (unit.toLowerCase().contains('m')) {
        amount = amount * 1000000;
      } else if (unit.contains('毛') || unit.contains('角')) {
        amount = amount * 0.1;
      } else if (unit.contains('分')) {
        amount = amount * 0.01;
      }

      return amount;
    }

    // 方法2：纯数字（无单位，默认是元）
    // 只有在没有匹配到带单位的金额时才使用
    final noUnitPattern = RegExp(r'(\d+\.?\d*)');
    final noUnitMatch = noUnitPattern.firstMatch(text);

    if (noUnitMatch != null) {
      return double.parse(noUnitMatch.group(1)!);
    }

    // 方法3：中文数字（完整版，包括"两万三"、"三十"、"五万四"等）
    // 匹配中文数字模式：两万三、三十、五百、三千、五万四等
    final chinesePattern = RegExp(
      r'([零一两二三四五六七八九十百千万]+)(元|块钱|块)?',
    );
    final chineseMatch = chinesePattern.firstMatch(text);

    if (chineseMatch != null) {
      String chineseNumber = chineseMatch.group(1)!;
      double value = _parseChineseNumber(chineseNumber);
      if (value > 0) {
        return value;
      }
    }

    return null;
  }

  String? _matchAccount(String text, {bool isTransfer = false, bool isTarget = false, bool isSource = false}) {
    if (isTransfer) {
      if (isTarget) {
        // 匹配目标账户（转入）- 正则模式优先
        final targetPatterns = [
          RegExp(r'向(\S{2,10})(?:转账|转入|转至|转给)'),
          RegExp(r'向(银行卡|信用卡|储蓄卡|余额宝|微信|支付宝)'),
          RegExp(r'给(\S{2,10})(?:转|卡|账户|钱包|里|号)'),
          RegExp(r'给(银行卡|信用卡|储蓄卡|余额宝|微信|支付宝)'),
          RegExp(r'转到(\S{2,10})'),
          RegExp(r'到(\S{2,10})(?:卡|户|账户|钱包|里|号)'),
          RegExp(r'到(银行卡|信用卡|储蓄卡|余额宝|微信|支付宝)'),
          RegExp(r'转给(\S{2,10})'),
          RegExp(r'转入(\S{2,10})'),
          RegExp(r'转至(\S{2,10})'),
        ];
        
        for (var pattern in targetPatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            final targetName = match.group(1)!;
            return targetName;
          }
        }
        
        // 用户自定义账户
        for (var account in _userAccounts) {
          final accountName = account['name'] as String;
          if (text.contains('给$accountName') || 
              text.contains('转到$accountName') ||
              text.contains('转给$accountName') ||
              text.contains('转入$accountName') ||
              text.contains('向$accountName')) {
            return accountName;
          }
        }
        
        // 系统预设账户别名
        final sortedEntries = accountAliases.entries.toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));
        for (var entry in sortedEntries) {
          if (text.contains('给${entry.key}') || 
              text.contains('转到${entry.key}') || 
              text.contains('转给${entry.key}') ||
              text.contains('转入${entry.key}')) {
            return entry.value;
          }
        }
        
        return null;
      } else if (isSource) {
        // 匹配转出账户 - 正则模式优先
        final sourcePatterns = [
          RegExp(r'从([^向]{2,10})(?:转|取|扣)'),
          RegExp(r'用(\S{2,10})(?:转|付)'),
          RegExp(r'从(\S{2,10})(?:卡|账户|钱包)'),
        ];
        
        for (var pattern in sourcePatterns) {
          final match = pattern.firstMatch(text);
          if (match != null) {
            final sourceName = match.group(1)!;
            return sourceName;
          }
        }
        
        
        // 用户自定义账户
        for (var account in _userAccounts) {
          final accountName = account['name'] as String;
          if (text.contains('用$accountName') || 
              text.contains('从$accountName')) {
            return accountName;
          }
        }
        
        // 系统预设账户别名
        final sortedEntries = accountAliases.entries.toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));
        for (var entry in sortedEntries) {
          if (text.contains('用${entry.key}') || text.contains('从${entry.key}')) {
            return entry.value;
          }
        }
        
        return null;
      }
    }
    
    // 非转账类型 - 用户自定义优先
    for (var account in _userAccounts) {
      final accountName = account['name'] as String;
      if (text.contains(accountName)) {
        return accountName;
      }
    }
    
    final sortedEntries = accountAliases.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (var entry in sortedEntries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  String? _matchCategory(String text, TransactionType type) {
    Map<String, List<String>> keywords = type == TransactionType.income
        ? incomeCategoryKeywords
        : expenseCategoryKeywords;

    for (var entry in keywords.entries) {
      for (var keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  String? _matchCategoryByProject(String project, TransactionType type) {
    // 彩票类项目映射
    final lotteryMap = {
      '体彩': '娱乐',
      '福彩': '娱乐',
      '足彩': '娱乐',
      '双色球': '娱乐',
      '大乐透': '娱乐',
      '刮刮乐': '娱乐',
      '彩票': '娱乐',
    };

    if (lotteryMap.containsKey(project)) {
      return lotteryMap[project];
    }

    // 尝试通过关键词匹配
    return _matchCategory(project, type);
  }

  String? _smartMatchCategory(String text, TransactionType type, String owner) {
    if (text.contains('发红包') || text.contains('给红包')) {
      return '红包';
    }

    if (type == TransactionType.income) {
      if (text.contains('基本工资') || text.contains('底薪')) {
        return '基本工资';
      }
      if (text.contains('绩效工资')) {
        return '基本工资';
      }
      if (text.contains('加班费')) {
        return '加班费';
      }
      if (text.contains('补贴') || text.contains('餐补') || text.contains('交通补贴') || text.contains('话补') || text.contains('住房补贴')) {
        return '补贴';
      }
      if (text.contains('奖金') || text.contains('年终奖')) {
        return '奖金';
      }
      if (text.contains('绩效') || text.contains('提成')) {
        return '奖金';
      }
      if (text.contains('兼职') || text.contains('副业') || text.contains('外包') || text.contains('私活')) {
        return '兼职副业';
      }
      if (text.contains('理财') || text.contains('利息') || text.contains('分红') || text.contains('投资收益')) {
        return '投资收益';
      }
      if (text.contains('退款') || text.contains('退钱') || text.contains('还钱')) {
        return '退款返还';
      }
      if (text.contains('工资') || text.contains('薪水') || text.contains('月薪')) {
        return '基本工资';
      }
      return '其他收入';
    }

    final linkedCategory = _matchOwnerItemCategory(text, owner);
    if (linkedCategory != null) {
      return linkedCategory;
    }

    if (type == TransactionType.expense) {
      // 午餐默认规则（只有明确说"午餐"、"中饭"、"午饭"才识别为午餐）
      // 注意：不能匹配"中午"，那是时间词
      if (text.contains('午餐') || text.contains('中饭') || text.contains('午饭')) {
        return '午餐';
      }
      // 早餐默认规则（只有在明确表示"吃早餐"时才识别为早餐）
      // "早晨买蔬菜"是时间，不是早餐；"早晨吃包子"才是早餐
      if (text.contains('早餐')) {
        return '早餐';
      }
      // 早晨/早上只有在配合吃、早餐等词时才识别为早餐
      if ((text.contains('早晨') || text.contains('早上')) && 
          (text.contains('吃') || text.contains('早餐') || text.contains('包子') || text.contains('馒头') || text.contains('豆浆') || text.contains('油条') || text.contains('鸡蛋'))) {
        return '早餐';
      }
      // 晚餐默认规则（晚上、晚饭、夜宵、宵夜都识别为晚餐）
      if (text.contains('晚餐') || text.contains('晚上') || text.contains('晚饭') || text.contains('夜宵') || text.contains('宵夜')) {
        return '晚餐';
      }
      // 如果只是说"吃饭"，默认为伙食费
      if (text.contains('吃饭')) {
        return '伙食费';
      }
    }

    // 优先级3: 关键词匹配
    return _matchCategory(text, type);
  }

  /// 归属人+物品联动判断
  /// 例如：给妈妈买了双鞋 → 孝敬长辈
  String? _matchOwnerItemCategory(String text, String owner) {
    // 孝敬长辈类目（父分类: 人情费用）
    final elderlyItems = [
      '鞋', '衣服', '外套', '裤子', '帽子', '围巾', '手套',
      '保健品', '药', '补品', '营养品', '燕窝', '人参', '枸杞',
      '按摩', '理疗', '体检', '看病', '住院',
      '家电', '冰箱', '洗衣机', '电视', '空调',
      '家具', '沙发', '床', '桌子', '椅子',
    ];

    // 宝宝费用类目（父分类: 宝宝费用）
    final babyItems = [
      '玩具', '奶粉', '尿布', '纸尿裤', '奶瓶', '围嘴',
      '童车', '婴儿车', '安全座椅',
      '绘本', '故事书', '早教', '幼儿园', '培训班',
      '宝宝衣服', '童装', '童鞋',
    ];

    // 归属人称谓映射
    final elderlyRelations = ['妈妈', '父亲', '爸', '妈', '爷爷', '奶奶', '外公', '外婆', '父母', '爸妈', '岳父', '岳母', '公公', '婆婆'];
    final babyRelations = ['儿子', '女儿', '孩子', '宝宝', '小宝', '大宝'];

    // 检查是否是孝敬长辈
    for (var relation in elderlyRelations) {
      if (text.contains(relation)) {
        for (var item in elderlyItems) {
          if (text.contains(item)) {
            return '孝敬长辈';
          }
        }
        // 如果只是提到长辈但没有具体物品，判断为孝敬长辈
        final actionKeywords = ['给', '帮', '替', '买', '付', '充值', '孝敬', '照顾'];
        for (var action in actionKeywords) {
          if (text.contains(action + relation) || text.contains(relation + action)) {
            return '孝敬长辈';
          }
        }
      }
    }

    // 检查是否是宝宝费用
    for (var relation in babyRelations) {
      if (text.contains(relation)) {
        for (var item in babyItems) {
          if (text.contains(item)) {
            return '宝宝用品';
          }
        }
        // 教育相关
        if (text.contains('学费') || text.contains('培训') || text.contains('幼儿园') || text.contains('早教')) {
          return '宝宝教育';
        }
      }
    }

    return null;
  }

  String? _extractMerchant(String text, {String? account}) {
    // 优先匹配用户创建的商家（按长度排序，长的先匹配，确保"小象超市"优先于"超市"）
    final sortedUserMerchants = List<String>.from(_userMerchants)
      ..sort((a, b) => b.length.compareTo(a.length));
    
    for (var merchant in sortedUserMerchants) {
      if (_matchMerchantWithBoundary(text, merchant, account)) {
        return merchant;
      }
    }
    
    // 备选：使用已知商家品牌列表（按长度排序）
    final sortedKnownMerchants = List<String>.from(knownMerchants)
      ..sort((a, b) => b.length.compareTo(a.length));
    for (var merchant in sortedKnownMerchants) {
      if (_matchMerchantWithBoundary(text, merchant, account)) {
        return merchant;
      }
    }
    return null;
  }

  bool _matchMerchantWithBoundary(String text, String merchant, String? account) {
    // 如果商家是账户名称的子串，需要更智能地判断
    if (account != null && account.contains(merchant)) {
      // 查找账户在文本中的位置
      int accountIndex = text.indexOf(account);
      if (accountIndex >= 0) {
        int accountEndIndex = accountIndex + account.length;
        
        // 在账户范围之后查找商家
        String textAfterAccount = text.substring(accountEndIndex);
        int indexAfterAccount = textAfterAccount.indexOf(merchant);
        
        if (indexAfterAccount >= 0) {
          // 商家在账户后面出现了，可以识别为商家
          return true;
        }
        
        // 商家只在账户范围内出现（是账户名称的一部分），不识别为商家
        return false;
      }
    }
    // 如果不是账户的子串，直接检查是否包含
    return text.contains(merchant);
  }

  String _extractOwner(String text) {
    // 优先匹配用户创建的归属人
    for (var ownerName in _userOwners) {
      if (text.contains(ownerName)) {
        return ownerName;
      }
    }

    // 归属人关键词（只保留明确表示"为他人"的关键词）
    // 无主语时默认归属人"本人"
    final ownerKeywords = [
      '给', '帮', '替', '代', // 帮助类
      '请', '请客', '请吃饭', // 请客类
      '送', '送给', '赠', // 赠送类
      '充值', '充', // 充值类
      '代付', '垫付', // 代付类
    ];

    // 亲属称谓映射（标准化）
    final relationMap = {
      // 爱人相关
      '媳妇': '爱人', '老婆': '爱人', '太太': '夫人', '夫人': '夫人',
      '老公': '爱人', '先生': '先生', '对象': '爱人', '女朋友': '爱人', '男朋友': '爱人',
      '爸妈': '父母', '父亲': '父母', '妈妈': '父母', '爸': '父母', '妈': '父母',
      '儿子': '儿子', '女儿': '儿子', '孩子': '孩子', '宝宝': '宝宝', '小宝': '宝宝', '大宝': '宝宝',
      '爷爷': '爷爷', '奶奶': '爷爷', '外公': '外公', '外婆': '外公',
      '同事': '同事', '朋友': '朋友', '室友': '同事', '邻居': '朋友',
      '同学': '同学', '老师': '老师', '学生': '学生',
      '家里': '家庭', '家庭': '家庭', '家用': '家庭', '家': '家庭',
    };

    // 先检测直接的人名或称谓
    for (var relation in relationMap.keys) {
      if (text.contains(relation)) {
        return relationMap[relation]!;
      }
    }

    // 使用关键词提取归属人
    for (var keyword in ownerKeywords) {
      if (text.contains(keyword)) {
        int keywordIndex = text.indexOf(keyword);
        String afterKeyword = text.substring(keywordIndex + keyword.length);

        // 尝试提取归属人名称（2-6个字的中文人名或称谓）
        final ownerMatch = RegExp(r'([\u4e00-\u9fa5]{2,6})').firstMatch(afterKeyword);
        if (ownerMatch != null) {
          String owner = ownerMatch.group(1)!.trim();
          // 过滤掉常见非人名词
          final nonPersonWords = [
            '钱', '块钱', '元', '圆', '金', '金额', '费用', '费', '费钱',
            '话费', '饭', '饭钱', '吃饭', '喝水', '饮料', '东西', '礼物', '商品',
            '物', '物品', '产品', '服务',
            '车', '房', '房子', '家',
          ];
          if (!nonPersonWords.contains(owner)) {
            return owner;
          }
        }
      }
    }
    return '本人';
  }

  String _matchProject(String text) {
    for (var entry in projectKeywords.entries) {
      for (var keyword in entry.value) {
        if (text.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return '日常';
  }

  /// 提取日期（支持中文口语表达）
  DateTime? _extractDate(String text) {
    DateTime now = DateTime.now();

    final timeKeywordMap = {
      '凌晨': {'hour': 3, 'minute': 0},
      '早晨': {'hour': 7, 'minute': 0},
      '早上': {'hour': 8, 'minute': 0},
      '上午': {'hour': 9, 'minute': 0},
      '中午': {'hour': 12, 'minute': 0},
      '下午': {'hour': 15, 'minute': 0},
      '傍晚': {'hour': 18, 'minute': 0},
      '晚上': {'hour': 20, 'minute': 0},
      '深夜': {'hour': 22, 'minute': 0},
      '半夜': {'hour': 23, 'minute': 0},
    };

    // 查找匹配的时间关键词
    int? inferredHour;
    int? inferredMinute;
    for (var entry in timeKeywordMap.entries) {
      if (text.contains(entry.key)) {
        inferredHour = entry.value['hour'];
        inferredMinute = entry.value['minute'];
        break;
      }
    }

    // 具体时间匹配：20点、20:30、晚上8点等（优先级最高）
    final timeMatch = RegExp(r'(?:中午|下午|晚上|凌晨|早晨|早上|上午)?\s*(\d{1,2})[点:](\d{0,2})').firstMatch(text);
    if (timeMatch != null) {
      int hour = int.parse(timeMatch.group(1)!);
      int minute = timeMatch.group(2) != null && timeMatch.group(2)!.isNotEmpty
          ? int.tryParse(timeMatch.group(2)!) ?? 0
          : 0;
      // 处理"晚上8点"等情况
      if (timeMatch.group(0)!.contains('晚上') && hour < 12) {
        hour += 12;
      }
      if (timeMatch.group(0)!.contains('下午') && hour < 12) {
        hour += 12;
      }
      if (inferredHour != null && hour == inferredHour) {
        inferredHour = hour;
        inferredMinute = minute;
      } else {
        inferredHour = hour;
        inferredMinute = minute;
      }
    }

    DateTime baseDate = now;
    String? matchedDateKeyword;

    if (text.contains('现在') || text.contains('刚才') || text.contains('此刻') || text.contains('当下')) {
      baseDate = DateTime(now.year, now.month, now.day);
      matchedDateKeyword = '今天';
    }
    else if (text.contains('今天')) {
      baseDate = DateTime(now.year, now.month, now.day);
      matchedDateKeyword = '今天';
    }
    else if (text.contains('昨天')) {
      baseDate = DateTime(now.year, now.month, now.day - 1);
      matchedDateKeyword = '昨天';
    }
    // 前天相关
    else if (text.contains('前天')) {
      baseDate = DateTime(now.year, now.month, now.day - 2);
      matchedDateKeyword = '前天';
    }
    // 大前天
    else if (text.contains('大前天')) {
      baseDate = DateTime(now.year, now.month, now.day - 3);
      matchedDateKeyword = '大前天';
    }
    // 明天相关
    else if (text.contains('明天')) {
      baseDate = DateTime(now.year, now.month, now.day + 1);
      matchedDateKeyword = '明天';
    }
    // 后天相关
    else if (text.contains('后天')) {
      baseDate = DateTime(now.year, now.month, now.day + 2);
      matchedDateKeyword = '后天';
    }
    // X天前
    else {
      final daysBeforeMatch = RegExp(r'(\d+)\s*天前').firstMatch(text);
      if (daysBeforeMatch != null) {
        int days = int.parse(daysBeforeMatch.group(1)!);
        baseDate = DateTime(now.year, now.month, now.day - days);
        matchedDateKeyword = '$days天前';
      }
      // X天后
      else {
        final daysAfterMatch = RegExp(r'(\d+)\s*天后').firstMatch(text);
        if (daysAfterMatch != null) {
          int days = int.parse(daysAfterMatch.group(1)!);
          baseDate = DateTime(now.year, now.month, now.day + days);
          matchedDateKeyword = '$days天后';
        }
        // 上周、下周
        else if (text.contains('上周') || text.contains('上礼拜')) {
          baseDate = DateTime(now.year, now.month, now.day - 7);
          matchedDateKeyword = '上周';
        }
        else if (text.contains('下周') || text.contains('下礼拜')) {
          baseDate = DateTime(now.year, now.month, now.day + 7);
          matchedDateKeyword = '下周';
        }
        // 上月、下月（先提取具体日期，再计算月份）
        if (text.contains('上个月') || text.contains('上月')) {
          int targetMonth = now.month - 1;
          int targetYear = now.year;
          if (targetMonth < 1) {
            targetMonth = 12;
            targetYear -= 1;
          }
          // 检查是否有具体日期
          final dayMatch = RegExp(r'(\d{1,2})(?:号|日)').firstMatch(text);
          if (dayMatch != null) {
            int day = int.parse(dayMatch.group(1)!);
            if (day >= 1 && day <= 31) {
              baseDate = DateTime(targetYear, targetMonth, day);
              matchedDateKeyword = '上个月${day}日';
            }
          } else {
            baseDate = DateTime(targetYear, targetMonth, now.day);
            matchedDateKeyword = '上个月';
          }
          return baseDate;
        }
        if (text.contains('下个月') || text.contains('下月')) {
          int targetMonth = now.month + 1;
          int targetYear = now.year;
          if (targetMonth > 12) {
            targetMonth = 1;
            targetYear += 1;
          }
          final dayMatch = RegExp(r'(\d{1,2})(?:号|日)').firstMatch(text);
          if (dayMatch != null) {
            int day = int.parse(dayMatch.group(1)!);
            if (day >= 1 && day <= 31) {
              baseDate = DateTime(targetYear, targetMonth, day);
              matchedDateKeyword = '下个月${day}日';
            }
          } else {
            baseDate = DateTime(targetYear, targetMonth, now.day);
            matchedDateKeyword = '下个月';
          }
          return baseDate;
        }
        // 具体日期匹配：X月X日、X/X、X-X等（月份必须在1-12之间，日期必须合理）
        else {
          final dateMatch = RegExp(r'(\d{1,2})[月/.-](\d{1,2})(?:日|号)?').firstMatch(text);
          if (dateMatch != null) {
            int month = int.parse(dateMatch.group(1)!);
            int day = int.parse(dateMatch.group(2)!);
            // 简单的合理性检查：月份1-12，日期1-31
            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              int year = now.year;
              if (month > now.month) {
                // 可能是去年
              }
              baseDate = DateTime(year, month, day);
              matchedDateKeyword = '$month月$day日';
            }
          }
          // 完整日期匹配：X年X月X日
          else {
            final fullDateMatch = RegExp(r'(\d{4})年(\d{1,2})月(\d{1,2})日').firstMatch(text);
            if (fullDateMatch != null) {
              int year = int.parse(fullDateMatch.group(1)!);
              int month = int.parse(fullDateMatch.group(2)!);
              int day = int.parse(fullDateMatch.group(3)!);
              baseDate = DateTime(year, month, day);
              matchedDateKeyword = '$year年$month月$day日';
            }
          }
        }
      }
    }

    // 如果没有匹配到任何日期关键词，但有时间关键词，返回今天
    if (matchedDateKeyword == null) {
      final timeKeywords = ['上午', '早上', '早晨', '下午', '晚上', '中午', '凌晨', '傍晚', '深夜', '半夜', '现在'];
      bool hasTimeKeyword = timeKeywords.any((t) => text.contains(t));
      if (hasTimeKeyword) {
        baseDate = DateTime(now.year, now.month, now.day);
        matchedDateKeyword = '今天';
      }
    }

    if (matchedDateKeyword == null && inferredHour == null) {
      DateTime result = DateTime(now.year, now.month, now.day, now.hour, now.minute);
      return result;
    }

    if (matchedDateKeyword != null || inferredHour != null) {
      int finalHour = inferredHour ?? 8;
      int finalMinute = inferredMinute ?? 0;
      
      DateTime result = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        finalHour,
        finalMinute,
      );
      
      return result;
    }

    return null;
  }

  /// 提取多日期+多金额的情况
  List<ParseResult>? _extractMultipleDateAmounts(String text) {
    // 优先检测：连续多笔记录（如"体彩30，福彩40，足彩34"）
    // 模式：项目名+数字，项目名+数字，项目名+数字...
    // 使用更简单的方式：提取所有"中文名词+数字"的组合
    final results = <ParseResult>[];
    DateTime now = DateTime.now();

    // 提取共同的分类和商家
    String? account = _matchAccount(text);
    String? merchant = _extractMerchant(text, account: account);

    // 匹配模式：中文项目名后跟数字
    // 改进：只匹配2个字的彩票/项目名称，避免匹配到"花了"、"刮了"等
    final itemPattern = RegExp(r'(体彩|福彩|足彩|刮刮乐|双色球|大乐透)(\d+\.?\d*)');
    final matches = itemPattern.allMatches(text).toList();

    if (matches.length >= 2) {
      String? firstCategory;

      for (int i = 0; i < matches.length && i < 5; i++) {
        String project = matches[i].group(1)!;
        double amount = double.parse(matches[i].group(2)!);

        String? category = _matchCategoryByProject(project, TransactionType.expense);
        category ??= firstCategory;
        firstCategory ??= category;

        results.add(ParseResult(
          type: TransactionType.expense,
          amount: amount,
          category: category,
          merchant: merchant,
          account: account,
          date: now,
          remark: '$project $amount',
          confidence: 0.9,
        ));
      }

      if (results.length >= 2) {
        return results;
      }
    }

    // 检测模式：X号和Y号...分别是...和...
    final multiDatePattern = RegExp(
      r'(\d{1,2})[日号]\s*[和,，、]\s*(\d{1,2})[日号].*?(?:分别是|各|分别是)\s*(\d+\.?\d*)\s*(?:元|块钱|块)?\s*[和,，、]\s*(\d+\.?\d*)\s*(?:元|块钱|块)?',
    );

    final match = multiDatePattern.firstMatch(text);
    if (match != null) {
      DateTime now2 = DateTime.now();
      int day1 = int.parse(match.group(1)!);
      int day2 = int.parse(match.group(2)!);
      double amount1 = double.parse(match.group(3)!);
      double amount2 = double.parse(match.group(4)!);

      // 确定月份和年份
      int year = now2.year;
      int month = now.month;

      // 提取分类和账户、商家
      String? account = _matchAccount(text);
      String? category = _smartMatchCategory(text, TransactionType.expense, '本人');
      String? merchant = _extractMerchant(text, account: account);

      // 创建两笔记录
      return [
        ParseResult(
          type: TransactionType.expense,
          amount: amount1,
          category: category,
          merchant: merchant,
          date: DateTime(year, month, day1),
          remark: text,
          confidence: 0.9,
        ),
        ParseResult(
          type: TransactionType.expense,
          amount: amount2,
          category: category,
          merchant: merchant,
          date: DateTime(year, month, day2),
          remark: text,
          confidence: 0.9,
        ),
      ];
    }

    // 检测模式：X号和Y号，A元和B元
    final multiDatePattern2 = RegExp(
      r'(\d{1,2})[日号]\s*[和,，、]\s*(\d{1,2})[日号].*?(\d+\.?\d*)\s*(?:元|块钱|块)?\s*[和,，、]\s*(\d+\.?\d*)\s*(?:元|块钱|块)?',
    );

    final match2 = multiDatePattern2.firstMatch(text);
    if (match2 != null) {
      DateTime now = DateTime.now();
      int day1 = int.parse(match2.group(1)!);
      int day2 = int.parse(match2.group(2)!);
      double amount1 = double.parse(match2.group(3)!);
      double amount2 = double.parse(match2.group(4)!);

      int year = now.year;
      int month = now.month;

      String? account = _matchAccount(text);
      String? category = _smartMatchCategory(text, TransactionType.expense, '本人');
      String? merchant = _extractMerchant(text, account: account);

      return [
        ParseResult(
          type: TransactionType.expense,
          amount: amount1,
          category: category,
          merchant: merchant,
          date: DateTime(year, month, day1),
          remark: text,
          confidence: 0.9,
        ),
        ParseResult(
          type: TransactionType.expense,
          amount: amount2,
          category: category,
          merchant: merchant,
          date: DateTime(year, month, day2),
          remark: text,
          confidence: 0.9,
        ),
      ];
    }

    return null;
  }

  /// 解析中文数字（完整版，支持各种口语化表达）
  ///
  /// 支持格式：
  /// - 简单：三十、五十、三百、五千
  /// - 组合：两万三（23000）、五万四千（54000）、三千八（3800）
  /// - 复杂：两万三千八百（23800）、五十六（56）
  double _parseChineseNumber(String chineseNumber) {
    final numMap = {
      '零': 0, '一': 1, '二': 2, '三': 3, '四': 4,
      '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
      '两': 2,
    };

    final unitMap = {
      '十': 10, '百': 100, '千': 1000, '万': 10000,
    };

    int result = 0;
    int temp = 0;
    int? lastUnit;

    for (int i = 0; i < chineseNumber.length; i++) {
      String char = chineseNumber[i];

      if (numMap.containsKey(char)) {
        // 0-9的数字
        int digit = numMap[char]!;

        if (lastUnit == null) {
          temp = digit;
        } else if (lastUnit == 10) {
          // 十位后的数字（如"三十五"中的"五"）
          temp += digit;
        } else if (lastUnit == 100) {
          // 百位后的数字（如"三十五"中的"五"，实际是十位）
          temp += digit * 10;
        } else if (lastUnit == 1000) {
          // 千位后的数字（如"三千五"中的"五"，实际是百位）
          temp += digit * 100;
        } else if (lastUnit == 10000) {
          // 万位后的数字（如"两万三"中的"三"，实际是千位）
          temp += digit * 1000;
        }
      } else if (unitMap.containsKey(char)) {
        int unit = unitMap[char]!;

        if (temp == 0) {
          // 单位前没有数字，默认为1（如"十"=10）
          temp = 1;
        }

        temp *= unit;

        if (unit == 10000) {
          // 万是最大的单位，累计到结果并重置
          result += temp;
          temp = 0;
          lastUnit = 10000;
        } else {
          lastUnit = unit;
        }
      }
    }

    return (result + temp).toDouble();
  }
}
