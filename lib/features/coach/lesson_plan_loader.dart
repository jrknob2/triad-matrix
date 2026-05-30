import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'lesson_plan.dart';

class LessonPlanLoader {
  static const String flowFoundationsAssetPath =
      'assets/lessons/flow_foundations.yaml';

  const LessonPlanLoader._();

  static Future<LessonPlan> loadFlowFoundations({AssetBundle? bundle}) {
    return loadAsset(flowFoundationsAssetPath, bundle: bundle);
  }

  static Future<LessonPlan> loadAsset(
    String assetPath, {
    AssetBundle? bundle,
  }) async {
    final String yamlSource = await (bundle ?? rootBundle).loadString(
      assetPath,
    );
    return parse(yamlSource, sourceDescription: assetPath);
  }

  static LessonPlan parse(
    String yamlSource, {
    String sourceDescription = 'lesson YAML',
  }) {
    final Object? decoded;
    try {
      decoded = loadYaml(yamlSource);
    } on Object catch (error) {
      throw LessonPlanLoadException(
        '$sourceDescription could not be parsed as YAML: $error',
      );
    }

    try {
      return LessonPlan.fromYaml(decoded);
    } on LessonPlanLoadException {
      rethrow;
    } on Object catch (error) {
      throw LessonPlanLoadException(
        '$sourceDescription has an invalid lesson plan shape: $error',
      );
    }
  }
}
