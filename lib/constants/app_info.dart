/// 应用信息常量
///
/// 集中管理版本号等应用信息，方便统一修改。
/// 修改版本号时只需修改此文件，并同步更新 pubspec.yaml。
class AppInfo {
  AppInfo._();

  /// 应用名称
  static const String name = 'Anticount';

  /// 版本号（格式：x.y.z）
  /// x：大版本号（需用户确认）
  /// y：次版本号（新增功能时增加）
  /// z：修订版本号（修复 bug 或完善功能时增加）
  static const String version = '1.5.0';

  /// 版权信息
  static const String copyright = '© 2026 Anticraft';
}
