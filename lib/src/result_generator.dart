import 'dart:async' show FutureOr;

import 'package:analyzer/dart/element/element.dart'
    show
        ClassElement,
        Element,
        ElementAnnotation,
        FormalParameterElement,
        MethodElement,
        TopLevelFunctionElement;
import 'package:analyzer/dart/element/type.dart' show InterfaceType;
import 'package:build/build.dart' show BuildStep;
import 'package:collection/collection.dart' show IterableExtension;
import 'package:guarded_result/src/annotations/async_guard.dart';
import 'package:guarded_result/src/annotations/guard.dart';
import 'package:guarded_result/src/annotations/result_annotation.dart';
import 'package:guarded_result/src/logger.dart';
import 'package:source_gen/source_gen.dart'
    show ConstantReader, GeneratorForAnnotation, InvalidGenerationSourceError;

final class ResultGenerator extends GeneratorForAnnotation<ResultAnnotation> {
  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement) return '';
    return _ResultBufferBuilder(element)
        .generateClassStart()
        .generateConstructor()
        .generatePrivateFields()
        .generateGetters()
        .generateSetters()
        .generateMethods()
        .generateClassEnd()
        .build();
  }
}

final class _ResultBufferBuilder {
  final ClassElement _element;
  final StringBuffer _buffer;

  _ResultBufferBuilder(ClassElement element)
    : _element = element,
      _buffer = StringBuffer();

  _ResultBufferBuilder generateClassStart() {
    Logger.info('Class: $_className', prefix: '@$ResultAnnotation()');
    _buffer.writeln('''
    final class _\$${_className}Proxy implements $_className {
    ''');
    return this;
  }

  String get _className => _element.name ?? 'Unknown';

  _ResultBufferBuilder generateConstructor() {
    final proxyFactory = _element.constructors.firstWhereOrNull(
      (constructor) => constructor.name == _proxyConstructorName,
    );

    if (proxyFactory == null) {
      throw InvalidGenerationSourceError(
        'The $_proxyConstructorName factory is not found in $_className class.',
        element: _element,
      );
    }

    final classModifiers = proxyFactory.isConst ? 'const' : '';
    final argumentMap = _getArgumentMap(proxyFactory.formalParameters);
    final arguments = argumentMap.keys.join(',');
    final argumentNames = argumentMap.values.join(',');
    final target = '$_className($argumentNames)';
    Logger.info('Constructor: $proxyFactory', prefix: _proxyConstructorName);
    _buffer.writeln('''
      $classModifiers _\$${_className}Proxy($arguments) : $_targetName = $target;
    ''');

    return this;
  }

  String get _proxyConstructorName => 'proxy';

  String get _targetName => '_target';

  Map<FormalParameterElement, String> _getArgumentMap(
    List<FormalParameterElement> formalParameters,
  ) {
    return <FormalParameterElement, String>{
      for (final formalParameter in formalParameters)
        formalParameter: formalParameter.displayName,
    };
  }

  _ResultBufferBuilder generatePrivateFields() {
    _buffer.writeln('''
      final $_className $_targetName;
    ''');
    return this;
  }

  _ResultBufferBuilder generateGetters() {
    for (final getter in _element.getters) {
      if (getter.isStatic) continue;

      if (getter.isPrivate) {
        _buffer.writeln('''
          @override
          $getter => throw UnimplementedError();
        ''');
        continue;
      }

      _buffer.writeln('''
        @override
        $getter => $_targetName.${getter.name};
      ''');
    }

    return this;
  }

  _ResultBufferBuilder generateSetters() {
    for (final setter in _element.setters) {
      if (setter.isStatic) continue;

      if (setter.isPrivate) {
        _buffer.writeln('''
          @override
          $setter => throw UnimplementedError();
        ''');
        continue;
      }

      final argumentName = _getArgumentMap(
        setter.formalParameters,
      ).values.first;
      _buffer.writeln('''
        @override
        $setter => $_targetName.${setter.name} = $argumentName;
      ''');
    }

    return this;
  }

  _ResultBufferBuilder generateMethods() {
    for (final method in _element.methods) {
      if (method.isStatic) continue;

      if (method.isPrivate) {
        _buffer.writeln('''
          @override
          $method => throw UnimplementedError();
        ''');
        continue;
      }

      final asyncGuardAnnotation = method.metadata.annotations.firstWhereOrNull(
        (annotation) => '${annotation.element?.displayName}' == '$AsyncGuard',
      );
      if (asyncGuardAnnotation != null) {
        _generateMethodWithAsyncGuardAnnotation(method, asyncGuardAnnotation);
        continue;
      }

      final guardAnnotation = method.metadata.annotations.firstWhereOrNull(
        (annotation) => '${annotation.element?.displayName}' == '$Guard',
      );
      if (guardAnnotation != null) {
        _generateMethodWithGuardAnnotation(method, guardAnnotation);
        continue;
      }

      final argumentNames = _getArgumentMap(
        method.formalParameters,
      ).values.join(',');
      _buffer.writeln('''
        @override
        $method => $_targetName.${method.name}($argumentNames);
      ''');
    }

    return this;
  }

  void _generateMethodWithAsyncGuardAnnotation(
    MethodElement method,
    ElementAnnotation annotation,
  ) {
    if (!RegExp(r'^Future<Result<.*>>$').hasMatch('${method.returnType}')) {
      throw InvalidGenerationSourceError(
        'In $_className class, the returned type of ${method.name} method is '
        '${method.returnType}. It must be a Future<Result<T>>.',
        element: method,
      );
    }

    final argumentNames = _getArgumentMap(
      method.formalParameters,
    ).values.join(',');
    Logger.info('Public Method: $method', prefix: '@$AsyncGuard()');
    final result = (method.returnType as InterfaceType).typeArguments.first;
    final type = (result as InterfaceType).typeArguments.first;
    final onErrorArgument = _getOnErrorArgument(annotation);
    _buffer.writeln('''
      @override
      $method async {
        return Result.asyncGuard<$type>(
          () async => $_targetName.${method.name}($argumentNames),
          $onErrorArgument
        );
      }
    ''');
  }

  void _generateMethodWithGuardAnnotation(
    MethodElement method,
    ElementAnnotation annotation,
  ) {
    if (!RegExp(r'^Result<.*>$').hasMatch('${method.returnType}')) {
      throw InvalidGenerationSourceError(
        'In $_className class, the returned type of ${method.name} method is '
        '${method.returnType}. It must be a Result<T>.',
        element: method,
      );
    }

    final argumentNames = _getArgumentMap(
      method.formalParameters,
    ).values.join(',');
    Logger.info('Public Method: $method', prefix: '@$Guard()');
    final type = (method.returnType as InterfaceType).typeArguments.first;
    final onErrorArgument = _getOnErrorArgument(annotation);
    _buffer.writeln('''
      @override
      $method {
        return Result.guard<$type>(
          () => $_targetName.${method.name}($argumentNames),
          $onErrorArgument
        );
      }
    ''');
  }

  String _getOnErrorArgument(ElementAnnotation annotation) {
    final onError = annotation
        .computeConstantValue()
        ?.getField('onError')
        ?.toFunctionValue();
    if (onError == null) {
      Logger.info('No onError', prefix: 'onError');
      return '';
    }
    if (onError is TopLevelFunctionElement) {
      Logger.info('${onError.name}', prefix: 'onError:TopLevelFunction');
      return 'onError: ${onError.name},';
    }
    if (onError.isStatic && onError is MethodElement) {
      Logger.info(
        '${onError.enclosingElement?.name}.${onError.name}',
        prefix: 'onError:Static Method',
      );
      return 'onError: ${onError.enclosingElement?.name}.${onError.name},';
    }
    Logger.info('Unknown', prefix: 'onError: Unknown Type');
    return '';
  }

  _ResultBufferBuilder generateClassEnd() {
    _buffer.writeln('}');
    return this;
  }

  String build() => _buffer.toString();
}
