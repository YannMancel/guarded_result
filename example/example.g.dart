// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: lines_longer_than_80_chars, use_super_parameters

part of 'example.dart';

// **************************************************************************
// ResultGenerator
// **************************************************************************

final class _$MyRepository extends MyRepository {
  const _$MyRepository(String defaultName) : super(defaultName);

  @override
  Future<Result<dynamic>> sayHello(String? name) async {
    return Result.guard(
      () async => super.sayHello(name),
      onError: MyRepository.onErrorWithStaticMethod,
    );
  }

  @override
  Future<Result<dynamic>> sayGoodBye(String? name) async {
    return Result.guard(
      () async => super.sayGoodBye(name),
      onError: onErrorWithTopLevelFunction,
    );
  }
}
