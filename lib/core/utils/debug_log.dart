import 'package:flutter/foundation.dart';

void debugLog(String message, [Object? error, StackTrace? stackTrace]) {
  if (!kDebugMode) return;
  debugPrint('[ApexCamera] $message${error == null ? '' : ': $error'}');
  if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
}
