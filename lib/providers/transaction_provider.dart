import 'package:flutter/foundation.dart';

import '../models/transaction.dart';
import '../services/transaction_service.dart';

/// 账单/记账状态
class TransactionProvider extends ChangeNotifier {
  TransactionProvider(this._service);

  final TransactionService _service;

  String? _error;

  String? get error => _error;

  /// 刷新状态：清空错误并通知界面
  ///
  /// 数据获取由调用方通过 queryByRange 等接口完成，这里仅同步状态。
  /// 内部仍被 add/update/delete 调用，用于写入后通知界面刷新。
  Future<void> refresh({int? userId}) async {
    if (userId == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> add(Transaction tx) async {
    try {
      _error = null;
      await _service.add(tx);
      await refresh(userId: tx.userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(Transaction tx) async {
    try {
      _error = null;
      await _service.update(tx);
      await refresh(userId: tx.userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id, int userId) async {
    try {
      _error = null;
      await _service.delete(id, userId);
      await refresh(userId: userId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// 按时间范围查询交易列表（不影响当前 filter 状态）
  ///
  /// 供账单页按月/周/日查询使用。
  Future<List<Transaction>> queryByRange({
    required int userId,
    DateTime? start,
    DateTime? end,
    TransactionType? type,
  }) {
    return _service.query(
      userId: userId,
      start: start,
      end: end,
      type: type,
    );
  }

  /// 按时间范围统计收支（不影响当前 filter 状态）
  Future<({double income, double expense})> summaryByRange({
    required int userId,
    DateTime? start,
    DateTime? end,
  }) {
    return _service.summary(
      userId: userId,
      start: start,
      end: end,
    );
  }

  /// 按时间范围统计交易笔数（不影响当前 filter 状态）
  Future<int> countByRange({
    required int userId,
    DateTime? start,
    DateTime? end,
  }) {
    return _service.count(
      userId: userId,
      start: start,
      end: end,
    );
  }
}
