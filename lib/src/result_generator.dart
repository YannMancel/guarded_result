import 'dart:async' show FutureOr;

import 'package:analyzer/dart/element/element.dart'
    show
        ClassElement,
        ConstructorElement,
        Element,
        ElementAnnotation,
        FormalParameterElement,
        MethodElement,
        TopLevelFunctionElement;
import 'package:build/build.dart' show BuildStep;
import 'package:guarded_result/src/annotations/guarded_result_future.dart';
import 'package:guarded_result/src/annotations/result_annotation.dart';
import 'package:guarded_result/src/constants.dart';
import 'package:guarded_result/src/logger.dart';
import 'package:source_gen/source_gen.dart'
    show ConstantReader, GeneratorForAnnotation;

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
        .generatePublicMethods()
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
    final class _\$$_className extends $_className {
    ''');
    return this;
  }

  String get _className => _element.name ?? 'Unknown';

  _ResultBufferBuilder generateConstructor() {
    for (final constructor in _constructors) {
      if (_isConstructorOfResultPackage(constructor)) {
        final classModifiers = constructor.isConst ? 'const' : '';
        final argumentMap = _getArgumentMap(
          formalParameters: constructor.formalParameters,
        );
        final arguments = argumentMap.keys.join(',');
        final superIfNeed = argumentMap.isNotEmpty
            ? ' : super(${argumentMap.values.join(',')})'
            : '';
        Logger.info('Constructor: $constructor', prefix: kConstructorName);
        _buffer.writeln('''
          $classModifiers _\$$_className($arguments)$superIfNeed;
        ''');
      }
    }
    return this;
  }

  List<ConstructorElement> get _constructors => _element.constructors;

  bool _isConstructorOfResultPackage(ConstructorElement constructor) {
    return constructor.name == kConstructorName;
  }

  Map<FormalParameterElement, String> _getArgumentMap({
    required List<FormalParameterElement> formalParameters,
  }) {
    return <FormalParameterElement, String>{
      for (final formalParameter in formalParameters)
        formalParameter: formalParameter.displayName,
    };
  }

  _ResultBufferBuilder generatePublicMethods() {
    for (final publicMethod in _publicMethods) {
      final annotations = _getMethodAnnotations(publicMethod);
      for (final annotation in annotations) {
        if (_isMethodWithGuardedResultFutureAnnotation(
          publicMethod,
          annotation,
        )) {
          _generateMethodWithGuardedResultFutureAnnotation(
            publicMethod,
            annotation,
          );
        }
      }
    }
    return this;
  }

  Iterable<MethodElement> get _publicMethods {
    return _element.methods.where((method) => method.isPublic);
  }

  List<ElementAnnotation> _getMethodAnnotations(MethodElement method) {
    return method.metadata.annotations;
  }

  bool _isMethodWithGuardedResultFutureAnnotation(
    MethodElement method,
    ElementAnnotation annotation,
  ) {
    return '${annotation.element?.displayName}' == '$GuardedResultFuture' &&
        (method.returnType.isDartAsyncFuture);
  }

  void _generateMethodWithGuardedResultFutureAnnotation(
    MethodElement method,
    ElementAnnotation annotation,
  ) {
    final methodName = method.name;
    final argumentMap = _getArgumentMap(
      formalParameters: method.formalParameters,
    );
    final arguments = argumentMap.keys.join(',');
    final argumentNames = argumentMap.values.join(',');
    final methodSignature = '${method.returnType} $methodName($arguments)';
    Logger.info(
      'Public Method: $methodSignature',
      prefix: '@$GuardedResultFuture()',
    );
    final onErrorArgument = _generateOnErrorArgument(annotation);
    _buffer.writeln('''
      @override
      $methodSignature async {
        return Result.guard(
          () async => super.${method.name}($argumentNames),
          $onErrorArgument
        );
      }
    ''');
  }

  String _generateOnErrorArgument(ElementAnnotation annotation) {
    final onError = annotation
        .computeConstantValue()
        ?.getField('onError')
        ?.toFunctionValue();
    final hasOnErrorArgument = onError != null;
    if (!hasOnErrorArgument) {
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
