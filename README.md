# guarded_result

The `guarded_result` package is a Dart library designed to simplify result handling by encapsulating either a success or an error, whilst automating exception handling through code generation.

**Warning:** The `guarded_result` package has several limitations.
1. For the `.proxy()` factory constructor and methods, the named or optional arguments are not taken into account.
2. The `@GuardedResult()` and `@GuardedResultFuture()` annotations must be on public method.

## Features

### Type-Safe Result Structure (`Result<T>`)

The package provides a sealed class `Result<T>` which can take two forms:
1. `Success<T>`: Contains the return value in the event of success.
2. `Error<T>`: Contains the error object (cause) and potentially the stack trace.


### Pattern matching with `when<R>`

The `Result` class provides a `when<R>` method that allows both cases (success or error) to be handled comprehensively and safely:

```dart
final message = result.when<String>(
  success: (value) => 'success: $value',
  error: (cause, stackTrace) => 'Error: $cause',
);
```

### Automated Code Generation (via [build_runner](https://pub.dev/packages/build_runner))

By using annotations, it automatically generates ‘wrapper’ classes that handle the try-catch blocks for you.
1. `@ResultAnnotation()`: Applied to a class (e.g. a Repository) to trigger the generation of a private class (prefixed with `_$` and suffixed with `Proxy`) which implements the class' interface.
2. `.proxy()` factory constructor: Allows you to instantiate the ‘secure’ version of your class.
3. `@GuardedResult()`: Applied to a method returning a `Result<T>`. The generated code overrides this method to execute it in a secure environment that automatically catches exceptions.
4. `@GuardedResultFuture()`: Applied to a method returning a `Future<Result<T>>`. The generated code overrides this method to execute it in a secure environment that automatically catches exceptions.

### Custom Error Handling (onError)

The `@GuardedResult()` and `@GuardedResultFuture()` annotations accept an `onError` parameter. 
This allows you to specify a function (static or top-level) that will be called automatically if an exception is thrown whilst the method is being executed.

```dart
@GuardedResult(onError: myErrorHandler)
Result<String> getData() {
  // ...
}

@GuardedResultFuture(onError: myErrorHandler)
Future<Result<String>> fetchData() async { 
  // ...
}
```

### Result.guard Utility Method

For manual use without code generation, a static `Result.guard<T>` method is available.
It allows you to execute a function and automatically convert any exception thrown into an `Error<T>`.

```dart
Result.guard<String>(
  () {
    // ...
    return Success<String>(value: ...);
  }
  onError: (cause, stackTrace) {
    // ...
  },
),
```

### Result.asyncGuard Utility Method

For manual use without code generation, a static `Result.asyncGuard<T>` method is available.
It allows you to execute an asynchronous function and automatically convert any exception thrown into an `Error<T>`.

```dart
await Result.asyncGuard<String>(
  () async {
    // ...
    return Success<String>(value: ...);
  }
  onError: (cause, stackTrace) {
    // ...
  },
),
```

## Getting started

In your `pubspec.yaml` file, add these dependencies in your dependencies.

```yaml
# pubspec.yaml

dependencies:
  guarded_result: ^1.0.0

dev_dependencies:
  build_runner: ^2.13.1
```

## Usage

### Step 1: Mark the class

```dart
// example.dart

import 'package:guarded_result/guarded_result.dart'
    show GuardedResultFuture, Result, ResultAnnotation, Success;

// Include the file that the builder will generate.
part 'example.g.dart';

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

  static void onErrorWithStaticMethod(Object cause, StackTrace stackTrace) {
    print('Error $cause');
  }
}
```

### Step 2: Run build_runner

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Info:** Add `--verbose` to have logs. 

### Step 3: Access the additional features

```dart
// main.dart

Future<void> main() async {
  final repository = MyRepository.proxy('berserk');
  final result = await repository.sayHello('Yann');
  final message = result.when<String>(
    success: (message) => message,
    error: (cause, _) => '$cause',
  );
  print(message);
}
```

## Debugging builds

To debug the build process, note that build_runner spawns a child process to run the build.
So, the args that turn on debugging must be passed through build_runner to the child process using --dart-jit-vm-arg, for example:

```bash
rm -Rf .dart_tool
dart pub get
dart run build_runner build \
  --dart-jit-vm-arg=--observe \
  --dart-jit-vm-arg=--pause-isolates-on-start
```

The args in the example will cause the child process to output a URL for debugging:

```bash
vm-service: isolate(8890848354266475) 'main' has no debugger attached and is paused at start.  Connect to the Dart VM service to debug.
The Dart VM service is listening on http://127.0.0.1:8181/9oKC96xlfC4=/
The Dart DevTools debugger and profiler is available at: http://127.0.0.1:8181/9oKC96xlfC4=/devtools/?uri=ws://127.0.0.1:8181/9oKC96xlfC4=/ws
```

To use your IDE to debug, launch a "remote debug" session.
For example in VSCode the remote debug action is called "Debug: Attach to Dart Process". 
It will ask for the URL to connect to: paste in the one that was printed.
