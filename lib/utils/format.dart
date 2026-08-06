// 金额格式化辅助函数
//
// 从账单页、统计页、AI 记账页提炼的公共纯函数，统一金额字符串拼接格式，
// 保持各页面原有的显示样式（货币符号位置、正负号、说明前缀）。

/// 格式化金额字符串
///
/// [amount] 金额数值；[currency] 货币符号（如 ¥、$）。
/// [sign] 可选的金额前缀符号（如 '+'、'-'），由调用方根据收支类型传入；
/// [prefix] 可选的说明文字前缀（如"收入 "、"支出 "）。
String formatMoney(
  double amount,
  String currency, {
  String? sign,
  String? prefix,
}) {
  // 可选参数为 null 时用空字符串，避免拼接出字面量 "null"
  return '${prefix ?? ''}${sign ?? ''}$currency${amount.toStringAsFixed(2)}';
}
