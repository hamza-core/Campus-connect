import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';

enum ViewState { idle, loading, success, empty, error }

abstract class BaseController extends ChangeNotifier {
  ViewState _state = ViewState.idle;
  String? _errorMessage;
  bool _disposed = false;
  int _request = 0;

  ViewState get state => _state;
  String? get errorMessage => _errorMessage;

  void safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> run<T>(
    Future<T> Function() action, {
    required void Function(T) onSuccess,
    bool Function(T)? isEmpty,
  }) async {
    if (_disposed) return;
    final request = ++_request;
    _state = ViewState.loading;
    _errorMessage = null;
    safeNotify();

    try {
      final result = await action();
      if (_disposed || request != _request) return;
      _state = isEmpty?.call(result) == true
          ? ViewState.empty
          : ViewState.success;
      onSuccess(result);
    } on AppException catch (error) {
      if (_disposed || request != _request) return;
      _state = ViewState.error;
      _errorMessage = error.message;
    } catch (error, stackTrace) {
      if (_disposed || request != _request) return;
      _state = ViewState.error;
      _errorMessage = 'Something went wrong. Try again.';
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (request == _request) safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
