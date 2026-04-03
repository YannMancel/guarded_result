import 'package:meta/meta_meta.dart' show Target, TargetKind;

@Target({TargetKind.method})
final class GuardedResult {
  const GuardedResult({this.onError});

  final void Function(Object cause, StackTrace)? onError;
}
