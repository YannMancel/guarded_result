final class GuardedResultFuture {
  const GuardedResultFuture({this.onError});

  final void Function(Object cause, StackTrace)? onError;
}
