import 'package:guarded_result/guarded_result.dart'
    show GuardedResultFuture, Result, ResultAnnotation, Success;

// Include the file that the builder will generate.
part 'example.g.dart';

void onErrorWithTopLevelFunction(Object cause, StackTrace stackTrace) {
  print('Error $cause');
}

// Activate builder.
@ResultAnnotation()
class MyRepository {
  final String defaultName;

  const MyRepository(this.defaultName);

  // Wire up the generated constructor in `example.g.dart`.
  const factory MyRepository.guard(String defaultName) = _$MyRepository;

  // Activate method overloading in `example.g.dart`.
  @GuardedResultFuture(onError: onErrorWithStaticMethod)
  Future<Result> sayHello(String? name) async {
    await Future.delayed(const Duration(seconds: 3));
    return Success<String>(value: 'Hello ${name ?? defaultName}!');
  }

  // Activate method overloading in `example.g.dart`.
  @GuardedResultFuture(onError: onErrorWithTopLevelFunction)
  Future<Result> sayGoodBye(String? name) async {
    await Future.delayed(const Duration(seconds: 3));
    return Success<String>(value: 'Good Bye ${name ?? defaultName}!');
  }

  static void onErrorWithStaticMethod(Object cause, StackTrace stackTrace) {
    print('Error $cause');
  }
}
