import 'dart:async' show FutureOr;

import 'package:analyzer/dart/element/element.dart'
    show
        ClassElement,
        Element,
        ElementAnnotation,
        FormalParameterElement,
        MethodElement,
        TopLevelFunctionElement;
import 'package:build/build.dart' show BuildStep;
import 'package:collection/collection.dart' show IterableExtension;
import 'package:guarded_result/src/annotations/async_guard.dart';
import 'package:guarded_result/src/annotations/guard.dart';
import 'package:guarded_result/src/annotations/result_annotation.dart';
import 'package:guarded_result/src/constants.dart';
import 'package:guarded_result/src/logger.dart';
import 'package:guarded_result/src/result.dart';
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
    for (final constructor in _element.constructors) {
      if (constructor.name == kConstructorName) {
        final classModifiers = constructor.isConst ? 'const' : '';
        final argumentMap = _getArgumentMap(constructor.formalParameters);
        final arguments = argumentMap.keys.join(',');
        final argumentNames = argumentMap.values.join(',');
        final target = '$_className($argumentNames)';
        Logger.info('Constructor: $constructor', prefix: kConstructorName);
        _buffer.writeln('''
          $classModifiers _\$${_className}Proxy($arguments) : $_targetName = $target;
        ''');
      }
    }
    return this;
  }

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
        (annotation) {
          return _isMethodWithAsyncGuardAnnotation(method, annotation);
        },
      );

      if (asyncGuardAnnotation != null) {
        _generateMethodWithAsyncGuardAnnotation(method, asyncGuardAnnotation);
        continue;
      }

      final guardAnnotation = method.metadata.annotations.firstWhereOrNull((
        annotation,
      ) {
        return _isMethodWithGuardAnnotation(method, annotation);
      });

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

  bool _isMethodWithAsyncGuardAnnotation(
    MethodElement method,
    ElementAnnotation annotation,
  ) {
    return '${annotation.element?.displayName}' == '$AsyncGuard' &&
        method.returnType.isDartAsyncFuture;
  }

  void _generateMethodWithAsyncGuardAnnotation(
    MethodElement method,
    ElementAnnotation annotation,
  ) {
    if (!method.returnType.isDartAsyncFuture) {
      throw InvalidGenerationSourceError(
        'The returned type from ${method.name} is not corrects.',
        element: method,
        todo: 'Replace returned type By Future<Result<T>.',
      );
    }

    final argumentNames = _getArgumentMap(
      method.formalParameters,
    ).values.join(',');
    Logger.info('Public Method: $method', prefix: '@$AsyncGuard()');
    final onErrorArgument = _getOnErrorArgument(annotation);
    _buffer.writeln('''
      @override
      $method async {
        return Result.asyncGuard(
          () async => $_targetName.${method.name}($argumentNames),
          $onErrorArgument
        );
      }
    ''');
  }

  bool _isMethodWithGuardAnnotation(
    MethodElement method,
    ElementAnnotation annotation,
  ) {
    return '${annotation.element?.displayName}' == '$Guard' &&
        '${method.returnType}' == '$Result';
  }

  void _generateMethodWithGuardAnnotation(
    MethodElement method,
    ElementAnnotation annotation,
  ) {
    if ('${method.returnType}' != '$Result') {
      throw InvalidGenerationSourceError(
        'The returned type from ${method.name} is not corrects.',
        element: method,
        todo: 'Replace returned type By $Result.',
      );
    }

    final argumentNames = _getArgumentMap(
      method.formalParameters,
    ).values.join(',');
    Logger.info('Public Method: $method', prefix: '@$Guard()');
    final onErrorArgument = _getOnErrorArgument(annotation);
    _buffer.writeln('''
      @override
      $method {
        return Result.guard(
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
