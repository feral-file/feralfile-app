import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/no_magic_number_rule.dart';

PluginBase createPlugin() => _CustomLintsPlugin();

class _CustomLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => [
        NoMagicNumberRule(),
      ];
}

