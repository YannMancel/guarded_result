import 'package:guarded_result/guarded_result.dart'
    show GuardedResultFuture, Result, ResultAnnotation, Success, GuardedResult;

// Include the file that the builder will generate.
part 'example.g.dart';

void onErrorWithTopLevelFunction(Object cause, StackTrace stackTrace) {
  print('Error $cause');
}

// Activate builder.
@ResultAnnotation()
class MyRepository {
  const MyRepository(String defaultName) : _defaultName = defaultName;

  final String _defaultName;

  // Wire up the generated constructor in `example.g.dart`.
  factory MyRepository.proxy(String defaultName) {
    return _$MyRepositoryProxy(defaultName);
  }

  // Activate method overloading in `example.g.dart`.
  @GuardedResult(onError: onErrorWithTopLevelFunction)
  Result sayHi(String? name) {
    return Success<String>(value: 'Hi ${name ?? _defaultName}!');
  }

  // Activate method overloading in `example.g.dart`.
  @GuardedResultFuture(onError: onErrorWithStaticMethod)
  Future<Result> sayHello(String? name) async {
    await Future.delayed(const Duration(seconds: 3));
    return Success<String>(value: 'Hello ${name ?? _defaultName}!');
  }

  // Activate method overloading in `example.g.dart`.
  @GuardedResultFuture(onError: onErrorWithTopLevelFunction)
  Future<Result> sayGoodBye(String? name) async {
    await Future.delayed(const Duration(seconds: 3));
    return Success<String>(value: 'Good Bye ${name ?? _defaultName}!');
  }

  static void onErrorWithStaticMethod(Object cause, StackTrace stackTrace) {
    print('Error $cause');
  }
}
