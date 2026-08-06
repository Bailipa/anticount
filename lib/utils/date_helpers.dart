// 日期辅助函数
//
// 从账单页、统计页提炼的公共纯函数，供周期切换相关计算使用。

/// 计算指定日期所在周的周一（ISO 周一为一周开始）
DateTime mondayOf(DateTime date) {
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

/// 指定月份的第 1 天（0 点）
DateTime monthStart(DateTime month) {
  return DateTime(month.year, month.month, 1);
}

/// 指定月份的结束（月末 23:59:59.999）
DateTime monthEnd(DateTime month) {
  return DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
}

/// 指定月份的天数
int monthDays(DateTime month) {
  return DateTime(month.year, month.month + 1, 0).day;
}
