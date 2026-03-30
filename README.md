# 智能记账

一款支持智能文字识别的记账应用

## 功能特性

✅ **智能文字识别**
- 支持自然语言输入记账
- 自动识别金额、分类、账户、商家等信息
- 例如："中午用招行卡付了30块钱，吃的盒马的盒饭"

✅ **快速记账**
- 支持支出、收入、转账三种类型
- 预设常用分类和账户
- 一键保存，简单快捷

✅ **数据统计**
- 日/周/月统计报表
- 饼图展示分类占比
- 分类排行榜

✅ **账户管理**
- 多账户支持（银行卡、支付宝、微信等）
- 实时余额显示
- 自动计算账户余额

✅ **分类管理**
- 预设常用分类
- 支持自定义分类
- 多级分类（后期扩展）

## 技术栈

- **Flutter 3.16+** - 跨平台框架
- **Provider** - 状态管理
- **SQLite** - 本地数据库
- **fl_chart** - 图表组件
- **flutter_screenutil** - 屏幕适配

## 安装步骤

### 前置要求

1. 安装 Flutter SDK
   - 下载：https://flutter.dev/docs/get-started/install/windows
   - 配置环境变量：将 `flutter/bin` 添加到 PATH
   - 验证安装：运行 `flutter doctor`

2. 安装 Android Studio
   - 下载：https://developer.android.com/studio
   - 安装 Android SDK 和模拟器



## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── data/
│   └── models/                  # 数据模型
│       ├── transaction.dart      # 交易记录
│       ├── category.dart        # 分类
│       ├── account.dart         # 账户
│       └── transaction_type.dart # 交易类型
├── services/
│   └── text_parser.dart         # 文本解析引擎
├── database/
│   └── database_helper.dart     # 数据库帮助类
├── providers/                   # 状态管理
│   ├── transaction_provider.dart
│   ├── category_provider.dart
│   └── account_provider.dart
├── screens/                     # 页面
│   ├── home_screen.dart         # 首页
│   ├── add_transaction_screen.dart  # 添加记账
│   ├── statistics_screen.dart   # 统计报表
│   ├── settings_screen.dart     # 设置
│   ├── accounts_screen.dart     # 账户管理
│   └── categories_screen.dart  # 分类管理
└── widgets/                     # 组件
    └── transaction_list_item.dart
```

## 使用说明

### 智能文字记账

在记账页面输入类似以下内容：

```
中午用招行卡付了30块钱，吃的盒马的盒饭
```

系统会自动识别：
- 类型：支出
- 金额：30元
- 分类：餐饮
- 账户：招商银行
- 商家：盒马
- 归属人：本人
- 项目：日常

### 支持的关键词

**分类关键词：**
- 餐饮：盒饭、外卖、午餐、晚餐、奶茶、咖啡、餐厅
- 交通：打车、地铁、公交、油费、停车
- 购物：超市、淘宝、京东、购物、买衣服
- 生活必须：水费、电费、话费、宽带、房租
- 娱乐：电影、游戏、KTV、旅游
- 医疗：药店、医院、看病、药品

**账户别名：**
- 招行卡 → 招商银行
- 支付宝 → 支付宝
- 微信 → 微信
- 现金 → 现金
- 花呗 → 花呗

**商家品牌：**
- 盒马、美团、饿了么、星巴克、喜茶、瑞幸、京东、淘宝、拼多多



## 开发环境

- Flutter 3.16+
- Dart 3.0+
- Android SDK 21+
- Gradle 8.0+

## 许可证

MIT License
