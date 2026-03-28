import 'package:build/build.dart' show log;

abstract class Logger {
  static void info(String message, {String? prefix}) {
    final buffer = StringBuffer()..write('[guarded_result]');
    if (prefix != null) buffer.write('[${prefix.padRight(24, ' ')}]');
    buffer.write(' $message');
    log.info('\x1B[36m$buffer\x1B[0m');
  }
}
