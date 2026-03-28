import 'package:build/build.dart' show Builder, BuilderOptions;
import 'package:guarded_result/src/result_generator.dart';
import 'package:source_gen/source_gen.dart' show SharedPartBuilder, Generator;

Builder generateResultBuilder(BuilderOptions _) {
  return SharedPartBuilder(<Generator>[ResultGenerator()], 'result_builder');
}
