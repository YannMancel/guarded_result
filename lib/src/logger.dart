final class Logger {
  const Logger({String? base}) : _base = base;

  final String? _base;

  void info(String message, {String? prefix}) {
    final buffer = StringBuffer();
    if (_base != null) buffer.write('[$_base]');
    if (prefix != null) buffer.write('[$prefix]');
    buffer.write(' $message');
    print('\x1B[36m $buffer \x1B[0m');
  }
}
