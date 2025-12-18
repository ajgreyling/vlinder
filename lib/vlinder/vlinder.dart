/// Vlinder - Lightweight, mobile runtime for Project Posduif
/// 
/// This library provides a scriptable Flutter app framework that:
/// - Parses Hetu script files (ui.ht) to build UI
/// - Integrates with Drift for data-aware widgets
/// - Provides a fixed widget SDK for App Store safety
library vlinder;

export 'core/widget_registry.dart';
export 'core/interpreter_provider.dart';
export 'core/database_provider.dart';
export 'parser/ui_parser.dart';
export 'binding/drift_binding.dart';
export 'runtime/vlinder_runtime.dart';
export 'runtime/action_handler.dart';
export 'schema/schema_loader.dart';
export 'workflow/workflow_parser.dart';
export 'workflow/workflow_engine.dart';
export 'rules/rules_parser.dart';
export 'rules/rules_engine.dart';
export 'drift/table_generator.dart';
export 'drift/database.dart';
export 'drift/database_api.dart';
export 'widgets/screen.dart';
export 'widgets/form.dart';
export 'widgets/text_field.dart';
export 'widgets/number_field.dart';
export 'widgets/action_button.dart';

