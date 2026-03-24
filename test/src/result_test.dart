import 'dart:async';

import 'package:guarded_result/guarded_result.dart';
import 'package:test/test.dart';

void main() {
  group('equality', () {
    [
          // Between Success objects
          (
            left: Success<String>(value: 'foo'), // ⚠️ No const
            right: Success<String>(value: 'foo'), // ⚠️ No const
            isEqual: true,
          ),
          (
            left: const Success<String>(value: 'foo'),
            right: const Success<String>(value: 'bar'),
            isEqual: false,
          ),
          (
            left: const Success<int>(value: 42),
            right: const Success<String>(value: 'bar'),
            isEqual: false,
          ),
          (
            left: Success<List<int>>(value: [1, 2, 3]), // ⚠️ No const
            right: Success<List<int>>(value: [1, 2, 3]), // ⚠️ No const
            isEqual: true,
          ),
          (
            left: const Success<List<int>>(value: [1, 2, 3]),
            right: const Success<List<int>>(value: [3, 2, 1]),
            isEqual: false,
          ),
          (
            left: const Success<List<int>>(value: [1, 2, 3]),
            right: const Success<List<int>>(value: [42]),
            isEqual: false,
          ),
          // Between Success and Error objects
          (
            left: const Success<String>(value: 'foo'),
            right: Error(cause: Exception('fake')),
            isEqual: false,
          ),
          // Between Error objects
          (
            left: Error(cause: Exception('fake')),
            right: Error(cause: Exception('fake')),
            isEqual: false,
          ),
        ]
        .map(
          (config) => test('When equals method is called between 2 results, '
              'Then the result is equals to ${config.isEqual}', () {
            expect(config.left == config.right, equals(config.isEqual));
          }),
        )
        .toList();
  });

  group('guard', () {
    test('should returns a $Success', () async {
      const kResult = Success<String>(value: 'foo');
      final errorCompleter = Completer<void>();
      await expectLater(
        Result.guard<String>(
          () async => Future<Result<String>>.value(kResult),
          onError: (_, _) => errorCompleter.complete(),
        ),
        completion(equals(kResult)),
      );
      expect(errorCompleter.isCompleted, isFalse);
    });

    test('Given async callback throws an exception '
        'Then should returns an $Error', () async {
      final exception = Exception('fake');
      final errorCompleter = Completer<void>();
      await expectLater(
        Result.guard<String>(
          () async => throw exception,
          onError: (_, _) => errorCompleter.complete(),
        ),
        completion(
          isA<Error<String>>().having(
            (e) => e.cause,
            'cause',
            isA<Exception>().having(
              (e) => e.toString(),
              "exception's message",
              equals('Exception: fake'),
            ),
          ),
        ),
      );
      expect(errorCompleter.isCompleted, isTrue);
    });
  });
}
