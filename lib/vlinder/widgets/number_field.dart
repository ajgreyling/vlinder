import 'package:flutter/material.dart';
import '../binding/drift_binding.dart';
import '../core/interpreter_provider.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';

/// NumberField widget - Numeric input (integer / decimal) bound to Drift field
/// 
/// Properties:
/// - field: String - Name of the schema field
/// - label: String? - Label text for the field
/// - required: bool? - Whether the field is required
/// - placeholder: String? - Placeholder text
/// - type: String? - Number type ('integer' or 'decimal', default 'decimal')
/// - readOnly: bool? - Whether the field is read-only
/// - visible: String? - Optional Hetu expression for conditional visibility
class VlinderNumberField extends StatefulWidget {
  final String field;
  final String? label;
  final bool? required;
  final String? placeholder;
  final String? type; // 'integer' or 'decimal'
  final bool? readOnly;
  final String? visible; // Hetu expression for conditional visibility

  const VlinderNumberField({
    super.key,
    required this.field,
    this.label,
    this.required,
    this.placeholder,
    this.type,
    this.readOnly,
    this.visible,
  });

  @override
  State<VlinderNumberField> createState() => _VlinderNumberFieldState();
}

class _VlinderNumberFieldState extends State<VlinderNumberField> {
  late final TextEditingController _controller;
  FormStateManager? _formState;
  bool _listenerAdded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Access FormStateProvider here (after initState completes)
    final formState = FormStateProvider.of(context);
    if (formState != null && !_listenerAdded) {
      _formState = formState;
      
      // Load initial value from form state if available
      final value = formState.getValue(widget.field);
      if (value != null) {
        _controller.text = value.toString();
      }
      
      // Listen to form state changes
      formState.valueNotifier.addListener(_onFormStateChanged);
      _listenerAdded = true;
    }
  }

  @override
  void dispose() {
    if (_formState != null && _listenerAdded) {
      _formState!.valueNotifier.removeListener(_onFormStateChanged);
    }
    _controller.dispose();
    super.dispose();
  }

  void _onFormStateChanged() {
    final formState = FormStateProvider.of(context);
    if (formState != null) {
      final value = formState.getValue(widget.field);
      if (_controller.text != value?.toString()) {
        _controller.text = value?.toString() ?? '';
      }
    }
  }

  void _onChanged(String value) {
    final formState = FormStateProvider.of(context);
    if (formState != null) {
      if (value.isEmpty) {
        formState.setValue(widget.field, null);
        return;
      }

      // Try to parse as number
      try {
        if (widget.type == 'integer') {
          final intValue = int.parse(value);
          formState.setValue(widget.field, intValue);
        } else {
          final doubleValue = double.parse(value);
          formState.setValue(widget.field, doubleValue);
        }
      } catch (e) {
        // Invalid number - let validation handle it
        formState.setValue(widget.field, value);
      }
    }
  }

  /// Evaluate visibility expression using Hetu interpreter
  bool _evaluateVisibility() {
    if (widget.visible == null || widget.visible!.isEmpty) {
      return true; // Always visible if no expression provided
    }

    final formState = FormStateProvider.of(context);
    if (formState == null) {
      return true; // Default to visible if no form state
    }

    final interpreter = HetuInterpreterProvider.of(context);
    if (interpreter == null) {
      debugPrint('[VlinderNumberField] WARNING: HetuInterpreterProvider not found, defaulting to visible');
      return true;
    }

    try {
      // Get accumulated form values from Hetu interpreter (for multi-step forms)
      Map<String, dynamic> accumulatedValues = {};
      try {
        final accumulated = interpreter.fetch('_patientFormValues');
        if (accumulated is Map) {
          accumulatedValues = Map<String, dynamic>.from(accumulated);
        } else if (accumulated is HTStruct) {
          // Convert HTStruct to Map
          for (final key in accumulated.keys) {
            accumulatedValues[key.toString()] = accumulated[key];
          }
        }
      } catch (_) {
        // No accumulated values, continue with current form values only
      }
      
      // Merge accumulated values with current form values (current takes precedence)
      final mergedValues = <String, dynamic>{...accumulatedValues, ...formState.values};
      
      // Inject merged form values as context variables for visibility evaluation
      for (final entry in mergedValues.entries) {
        final varName = entry.key;
        final varValue = entry.value;
        try {
          interpreter.eval('final $varName = ${_valueToHetuLiteral(varValue)}');
        } catch (e) {
          // Skip if variable already exists or can't be set
        }
      }

      // Evaluate visibility expression
      final expressionScript = 'final _visible = ${widget.visible}';
      interpreter.eval(expressionScript);
      final result = interpreter.fetch('_visible');
      
      if (result is bool) {
        return result;
      }
      
      return true; // Default to visible if expression doesn't return bool
    } catch (e) {
      debugPrint('[VlinderNumberField] Error evaluating visibility expression "${widget.visible}": $e');
      return true; // Default to visible on error
    }
  }

  /// Convert Dart value to Hetu literal string
  String _valueToHetuLiteral(dynamic value) {
    if (value == null) {
      return 'null';
    } else if (value is String) {
      return "'$value'";
    } else if (value is bool) {
      return value.toString();
    } else if (value is num) {
      return value.toString();
    } else {
      return "'${value.toString()}'";
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = FormStateProvider.of(context);
    final error = formState?.getError(widget.field);
    final isRequired = widget.required ?? false;
    final isInteger = widget.type == 'integer';
    final isReadOnly = widget.readOnly ?? false;

    // Evaluate visibility reactively
    return ValueListenableBuilder<Map<String, dynamic>>(
      valueListenable: formState?.valueNotifier ?? ValueNotifier<Map<String, dynamic>>({}),
      builder: (context, values, child) {
        final isVisible = _evaluateVisibility();
        
        if (!isVisible) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: TextField(
            controller: _controller,
            readOnly: isReadOnly,
            enabled: !isReadOnly,
            keyboardType: isInteger
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: widget.label ?? widget.field,
              hintText: widget.placeholder,
              border: const OutlineInputBorder(),
              errorText: error,
              suffixIcon: isRequired
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        '*',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    )
                  : null,
            ),
            onChanged: isReadOnly ? null : _onChanged,
          ),
        );
      },
    );
  }

  /// Create from properties map (used by widget registry)
  static Widget fromProperties(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final field = properties['field'] as String? ?? 'field';
    final label = properties['label'] as String?;
    final required = properties['required'] as bool?;
    final placeholder = properties['placeholder'] as String?;
    final type = properties['type'] as String?;
    final readOnly = properties['readOnly'] as bool?;
    final visible = properties['visible'] as String?;

    return VlinderNumberField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      type: type,
      readOnly: readOnly,
      visible: visible,
    );
  }
}

