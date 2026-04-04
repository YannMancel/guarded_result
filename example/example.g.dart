// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lines_longer_than_80_chars, use_super_parameters, unused_element

part of 'example.dart';

// **************************************************************************
// ResultGenerator
// **************************************************************************

final class _$MyRepositoryProxy implements MyRepository {
  _$MyRepositoryProxy(String defaultName) : _target = MyRepository(defaultName);

  final MyRepository _target;

  @override
  String get _defaultName => throw UnimplementedError();

  @override
  Result<String> sayHi(String? name) {
    return Result.guard<String>(
      () => _target.sayHi(name),
      onError: MyRepository.onErrorWithStaticMethod,
    );
  }

  @override
  Future<Result<String>> sayHello(String? name) async {
    return Result.asyncGuard<String>(
      () async => _target.sayHello(name),
      onError: MyRepository.onErrorWithStaticMethod,
    );
  }

  @override
  Future<Result<String>> sayGoodBye(String? name) async {
    return Result.asyncGuard<String>(
      () async => _target.sayGoodBye(name),
      onError: onErrorWithTopLevelFunction,
    );
  }
}
