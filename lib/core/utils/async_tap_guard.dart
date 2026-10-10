import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Result of a guarded async tap.
enum AsyncTapOutcome { completed, cancelled, ignored }

/// App-wide double-tap / multi-tap protection.
///
/// - First tap starts the action (optionally with a [CancelToken]).
/// - Another tap on the **same** key cancels immediately.
/// - Taps on a **different** key while busy are ignored (one action at a time).
class AsyncTapGuard extends ChangeNotifier {
  AsyncTapGuard._();
  static final AsyncTapGuard instance = AsyncTapGuard._();

  String? _busyKey;
  CancelToken? _token;
  int _generation = 0;

  String? get busyKey => _busyKey;
  bool get isBusy => _busyKey != null;
  bool isBusyKey(String key) => _busyKey == key;

  /// Cancel whatever is in flight (no-op if idle).
  void cancel({String reason = 'cancelled'}) {
    _token?.cancel(reason);
    _token = null;
    _busyKey = null;
    _generation++;
    notifyListeners();
  }

  /// Run [action]. Retap same [key] cancels; other keys ignored while busy.
  Future<AsyncTapOutcome> run(
    String key,
    Future<void> Function(CancelToken cancelToken) action,
  ) async {
    if (_busyKey != null) {
      if (_busyKey == key) {
        cancel(reason: 'retap');
        return AsyncTapOutcome.cancelled;
      }
      return AsyncTapOutcome.ignored;
    }

    final gen = ++_generation;
    final token = CancelToken();
    _token = token;
    _busyKey = key;
    notifyListeners();

    try {
      await action(token);
      if (gen != _generation || token.isCancelled) {
        return AsyncTapOutcome.cancelled;
      }
      return AsyncTapOutcome.completed;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || token.isCancelled || gen != _generation) {
        return AsyncTapOutcome.cancelled;
      }
      rethrow;
    } catch (e) {
      if (token.isCancelled || gen != _generation) {
        return AsyncTapOutcome.cancelled;
      }
      // Treat custom cancel signals
      if (e is _AsyncTapCancelled) return AsyncTapOutcome.cancelled;
      rethrow;
    } finally {
      if (gen == _generation) {
        _token = null;
        _busyKey = null;
        notifyListeners();
      }
    }
  }

  /// Throw from inside [run] to abort without error UI.
  static Never abort() => throw _AsyncTapCancelled();
}

class _AsyncTapCancelled implements Exception {}

/// True when [error] is a user cancel / retap cancel.
bool isAsyncTapCancel(Object error) {
  if (error is _AsyncTapCancelled) return true;
  if (error is DioException && CancelToken.isCancel(error)) return true;
  return false;
}
