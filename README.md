# AntiCount 智能记账

一款基于 Flutter 开发的个人智能记账应用，支持 AI 图像/文字识别记账、多厂商模型配置、账单分组查看等功能。

## 功能特性

### 记账管理
- 手动记账：支持收入/支出分类管理
- 账单查看：按日/周/月分组展示，月收支汇总
- 分类管理：自定义收支分类
- 重复检测：自动识别重复账单并提示确认
- 账单导入：支持 CSV / Excel 文件导入，系统格式直接解析，非标准格式可由 AI 识别
- 账单导出：将账单导出为 CSV 文件分享

### AI 智能记账
- 多照片识别：支持一次拍摄多张票据同时识别
- 多厂商支持：DeepSeek、Kimi、通义千问、智谱、OpenAI、Google、Anthropic
- 双模式识别：文字识别 + 图像识别（多模态）
- 自动保存：识别后可自动保存（带确认弹窗）
- API Key 验证：保存前自动验证 API Key 有效性
- 历史账单参考：识别/对话时参考已记录账单，保持分类一致、辅助判断重复

### 用户系统
- 注册/登录/重置密码
- 头像上传（相机/相册）
- 昵称编辑
- 退出登录（可选保留数据）
- 账户注销

### 统计总结
- 收支汇总：按月/按年查看收入、支出、结余
- 分类饼图：支出/收入分类占比可视化
- 收支柱状图：按日/按周查看趋势，左右滑动切换时间窗口
- AI 分析：基于当前周期数据生成收支总结与理财建议

### 设置
- 主题色：蓝色主题
- 货币单位切换
- 账户安全（修改密码/注销账户）
- AI 自动保存开关
- 导入设置：AI 导入处理、导入后自动处理
- Android 桌面卡片：显示月度账单概览
- 中文本地化

## 技术栈

| 技术 | 说明 |
|------|------|
| Flutter | 跨平台 UI 框架 |
| Dart | 编程语言 |
| Provider | 状态管理 |
| sqflite | 本地 SQLite 数据库 |
| shared_preferences | 轻量级本地存储 |
| http | AI API 网络请求 |
| image_picker | 图片选择（相机/相册） |
| url_launcher | 打开外部链接（厂商开放平台） |
| file_picker | 文件选择（导入账单） |
| excel | Excel 文件读取 |
| csv | CSV 导入/导出 |
| share_plus | 文件分享 |
| fl_chart | 图表（饼图/柱状图） |
| home_widget | Android 桌面卡片 |
| crypto | 密码加密 |

## 项目结构

```
lib/
├── main.dart                    # 应用入口
├── config/
│   └── env.dart                 # 环境配置
├── constants/
│   └── app_info.dart            # 应用信息（版本号等）
├── models/
│   ├── transaction.dart         # 交易模型
│   └── user.dart                # 用户模型
├── providers/
│   ├── ai_provider.dart         # AI 配置状态管理
│   ├── auth_provider.dart       # 认证状态管理
│   ├── settings_provider.dart   # 设置状态管理
│   └── transaction_provider.dart # 交易状态管理
├── screens/
│   ├── accounting/              # 手动记账
│   ├── ai/                      # AI 记账 + 配置
│   ├── auth/                    # 登录/注册/重置密码
│   ├── bills/                   # 账单查看
│   ├── home/                    # 主页
│   ├── profile/                 # 个人中心
│   ├── settings/                # 设置（导入/导出/分类管理）
│   └── statistics/              # 统计总结
├── services/
│   ├── ai_service.dart          # AI 服务（7 厂商 + 双 API 格式）
│   ├── auth_service.dart        # 认证服务
│   ├── database_service.dart    # 数据库服务
│   ├── export_service.dart      # 账单导出服务
│   ├── import_service.dart      # 账单导入服务
│   ├── settings_service.dart    # 设置服务
│   ├── transaction_service.dart # 交易服务
│   └── widget_service.dart      # 桌面卡片数据服务
├── utils/
│   ├── date_helpers.dart        # 日期助手（周首/月初/月末）
│   ├── format.dart              # 金额格式化
│   ├── duplicate_check.dart     # 重复账单检测
│   ├── image_picker_helper.dart # 图片多选 + base64
│   ├── ai_result_saver.dart     # AI 结果保存
│   └── recent_transactions_context.dart # AI 历史账单上下文
└── widgets/
    ├── animated_dialog.dart     # 动画/确认/输入对话框
    ├── app_button.dart          # 通用按钮
    ├── app_text_field.dart      # 通用输入框
    ├── slide_transition_switcher.dart # 滑动切换动画
    ├── period_switcher.dart     # 周期切换器（月/周）
    ├── overlay_dropdown.dart    # 通用浮层下拉
    ├── empty_state.dart         # 空状态占位
    └── tag_badge.dart           # 标签徽章
```

## 开发环境

- Flutter SDK: ^3.9.2
- Dart SDK: ^3.9.2
- 最低 Android 版本: API 21+

## 构建与运行

### 环境准备

```bash
flutter doctor
flutter pub get
```

### 开发运行

```bash
# 查看可用设备
flutter devices

# 运行到 Android 模拟器/真机
flutter run

# 运行到指定设备
flutter run -d <device_id>
```

### 构建 APK

```bash
# Release APK
flutter build apk --release

# 输出路径：build/app/outputs/flutter-apk/app-release.apk
```

### 代码分析

```bash
flutter analyze
```

## 应用图标

图标设计参考 Anticraft 品牌风格：
- 紫色圆角矩形背景 (#6C5CE7)
- 白色 N 字母
- 青色对角斜线 (#00CEC9)

## 版本历史

- v1.5.0 - AI 记账参考历史账单（识别/对话时参考已记录账单）
- v1.4.4 - 修复金额排版、记账实时刷新、AI 配置按用户隔离、退出登录跳转
- v1.4.3 - 死代码清理 + 通用组件复用 + AI 服务收敛
- v1.4.2 - 修复月份/周切换动画方向并抽象为 _PeriodSwitcher 组件
- v1.4.1 - 统计页柱状图左右滑动切换 + 月份切换动画抽象
- v1.4.0 - 账单导入（CSV/Excel + AI 解析）
- v1.3.0 - 统计总结（饼图、柱状图、AI 分析）+ 账单导出 + Android 桌面卡片
- v1.1.14 - AI记账界面精简 + 厂商开放平台跳转 + 配置菜单优化
- v1.1.13 - 年月切换动画移除 + 月份切换同步更新周 + AI识别底部留白
- v1.1.12 - 图标改为圆角矩形
- v1.1.11 - 直接使用网站图标设计
- v1.1.10 - 参考网站风格设计记账主题图标
- v1.1.9 - 艺术字 A + 存钱罐投币口图标
- v1.1.8 - 白色主题 + 存钱罐图标
- v1.1.7 - 创建应用图标
- v1.1.6 - 删除周收支模块
- v1.1.5 - 重复账单检测 + 自动保存确认
- v1.1.4 - _dependents.isEmpty bug 修复
- v1.1.3 - 周切换动画 + 卷帘门下拉 + 版本号抽象
- v1.1.2 - 账单页重构（月份切换 + 周切换 + 每日列表）
- v1.1.0 - 中文化 + 5 个新 AI 厂商 + 多照片 + 账单分组
- v1.0.1 - temperature 400 错误修复 + AI 配置分组
- v1.0.0 - 初始版本

## License

© 2026 Anticraft. All rights reserved.
