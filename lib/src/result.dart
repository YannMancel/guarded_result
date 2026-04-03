import 'package:collection/collection.dart' show DeepCollectionEquality;
import 'package:meta/meta.dart' show immutable;

typedef ValueGetter<T> = T Function();
typedef AsyncValueGetter<T> = Future<T> Function();

@immutable
sealed class Result<T> {
  const Result();

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is Result<T>;
  }

  @override
  int get hashCode => Object.hashAll(const <Object?>[]);

  R when<R>({
    required R Function(T value) success,
    required R Function(Object cause, StackTrace?) error,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      Error<T>(:final cause, :final stackTrace) => error(cause, stackTrace),
    };
  }

  static Result<T> guard<T>(
    ValueGetter<Result<T>> callback, {
    void Function(Object cause, StackTrace)? onError,
  }) {
    try {
      return callback();
    } catch (cause, stackTrace) {
      onError?.call(cause, stackTrace);
      return Error<T>(cause: cause, stackTrace: stackTrace);
    }
  }

  static Future<Result<T>> asyncGuard<T>(
    AsyncValueGetter<Result<T>> asyncCallback, {
    void Function(Object cause, StackTrace)? onError,
  }) async {
    try {
      final result = await asyncCallback();
      return result;
    } catch (cause, stackTrace) {
      onError?.call(cause, stackTrace);
      return Error<T>(cause: cause, stackTrace: stackTrace);
    }
  }
}

@immutable
final class Success<T> extends Result<T> {
  const Success({required this.value});

  final T value;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Success<T> &&
            (value is Iterable
                ? const DeepCollectionEquality().equals(value, other.value)
                : value == other.value));
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[value]);
}

@immutable
final class Error<T> extends Result<T> {
  const Error({required this.cause, this.stackTrace});

  final Object cause;
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is Error<T> &&
            cause == other.cause &&
            stackTrace == other.stackTrace);
  }

  @override
  int get hashCode {
    return Object.hashAll(<Object?>[cause, stackTrace]);
  }
}
