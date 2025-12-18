import 'package:flutter/material.dart';
import '../runtime/action_handler.dart';
import '../binding/drift_binding.dart';
import '../core/interpreter_provider.dart';
import '../core/database_provider.dart';
import 'package:hetu_script/hetu_script.dart';

/// ActionButton widget - Primary or secondary action trigger
/// 
/// Properties:
/// - label: String - Button text
/// - action: String? - Action identifier (e.g., 'submit_customer', 'navigate_to_list')
/// - style: String? - Button style ('primary' or 'secondary')
/// - onPressed: Function? - Optional callback (typically handled by Hetu script)
class VlinderActionButton extends StatelessWidget {
  final String label;
  final String? action;
  final String? style;
  final VoidCallback? onPressed;
  final Hetu? interpreter;

  const VlinderActionButton({
    super.key,
    required this.label,
    this.action,
    this.style,
    this.onPressed,
    this.interpreter,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = style != 'secondary';
    
    Widget button = isPrimary
        ? ElevatedButton(
            onPressed: onPressed ?? () => _handleAction(context),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed ?? () => _handleAction(context),
            child: Text(label),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        width: double.infinity,
        child: button,
      ),
    );
  }

  void _handleAction(BuildContext context) {
    if (onPressed != null) {
      onPressed!();
      return;
    }

    if (action == null) {
      return;
    }

    // Get form state from context if available
    final formState = FormStateProvider.of(context);
    if (formState != null) {
      debugPrint('[VlinderActionButton] Found FormStateProvider: isValid=${formState.isValid}, values=${formState.values}');
    } else {
      debugPrint('[VlinderActionButton] WARNING: FormStateProvider not found in context');
    }
    
    // Get interpreter from context provider, fallback to instance variable, or create new one
    final hetuInstance = HetuInterpreterProvider.of(context) ?? interpreter ?? (() {
      debugPrint('[VlinderActionButton] WARNING: No interpreter found in context, creating new instance. '
          'This interpreter will not have access to loaded schemas/workflows/rules.');
      final h = Hetu();
      h.init();
      return h;
    })();
    
    // Get database API from context provider
    final databaseAPI = DatabaseAPIProvider.of(context);
    
    final handler = ActionHandler(
      interpreter: hetuInstance,
      context: context,
      formState: formState,
      databaseAPI: databaseAPI,
    );

    // Execute action
    handler.executeAction(action!);
  }

  /// Create from properties map (used by widget registry)
  static Widget fromProperties(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final label = properties['label'] as String? ?? 'Button';
    final action = properties['action'] as String?;
    final style = properties['style'] as String?;
    
    // Get interpreter from context provider
    // This ensures the action handler has access to loaded schemas/workflows/rules
    final interpreter = HetuInterpreterProvider.of(context);
    if (interpreter == null) {
      debugPrint('[VlinderActionButton] WARNING: No HetuInterpreterProvider found in context. '
          'Action handlers will not have access to loaded schemas/workflows/rules.');
    }

    return VlinderActionButton(
      label: label,
      action: action,
      style: style,
      interpreter: interpreter,
    );
  }
}

