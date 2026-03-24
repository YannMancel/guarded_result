import 'example.dart';

Future<void> main() async {
  final repository = MyRepository.guard('berserk');
  final result = await repository.sayHello('Yann');
  final message = result.when<String>(
    success: (message) => message,
    error: (cause, _) => '$cause',
  );
  print(message);
}
