import 'package:flutter/material.dart';
import '../binding/drift_binding.dart';
import '../core/interpreter_provider.dart';
import 'package:hetu_script/hetu_script.dart';
import 'package:hetu_script/values.dart';

/// SingleSelectField widget - Single-select dropdown bound to Drift field
/// 
/// Properties:
/// - field: String - Name of the schema field
/// - label: String? - Label text for the field
/// - required: bool? - Whether the field is required
/// - placeholder: String? - Placeholder text
/// - readOnly: bool? - Whether the field is read-only
/// - visible: String? - Optional Hetu expression for conditional visibility
/// - options: List<dynamic> - List of options. Can be:
///   - List of strings: ['Male', 'Female', 'Other'] (value = label)
///   - List of maps: [{value: 'M', label: 'Male'}, ...] (explicit value/label)
class VlinderSingleSelectField extends StatefulWidget {
  final String field;
  final String? label;
  final bool? required;
  final String? placeholder;
  final bool? readOnly;
  final String? visible; // Hetu expression for conditional visibility
  final List<dynamic>? options;

  const VlinderSingleSelectField({
    super.key,
    required this.field,
    this.label,
    this.required,
    this.placeholder,
    this.readOnly,
    this.visible,
    this.options,
  });

  @override
  State<VlinderSingleSelectField> createState() => _VlinderSingleSelectFieldState();

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
    final readOnly = properties['readOnly'] as bool?;
    final visible = properties['visible'] as String?;
    final options = properties['options'] as List<dynamic>?;

    return VlinderSingleSelectField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      readOnly: readOnly,
      visible: visible,
      options: options,
    );
  }
}

class _VlinderSingleSelectFieldState extends State<VlinderSingleSelectField> {
  FormStateManager? _formState;
  bool _listenerAdded = false;
  String? _value;

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
        _value = value.toString();
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
    super.dispose();
  }

  void _onFormStateChanged() {
    final formState = FormStateProvider.of(context);
    if (formState != null) {
      final value = formState.getValue(widget.field);
      final stringValue = value?.toString();
      if (_value != stringValue) {
        setState(() {
          _value = stringValue;
        });
      }
    }
  }

  void _onChanged(String? value) {
    final formState = FormStateProvider.of(context);
    if (formState != null) {
      formState.setValue(widget.field, value);
      setState(() {
        _value = value;
      });
    }
  }

  /// Parse options into a list of DropdownMenuItem<String>
  List<DropdownMenuItem<String>> _buildDropdownItems() {
    if (widget.options == null || widget.options!.isEmpty) {
      return [];
    }

    final items = <DropdownMenuItem<String>>[];
    
    for (final option in widget.options!) {
      String value;
      String label;
      
      if (option is String) {
        // Simple string option: value = label
        value = option;
        label = option;
      } else if (option is Map) {
        // Map option with explicit value and label
        value = option['value']?.toString() ?? option['label']?.toString() ?? '';
        label = option['label']?.toString() ?? option['value']?.toString() ?? '';
      } else {
        // Fallback: convert to string
        value = option.toString();
        label = option.toString();
      }
      
      if (value.isNotEmpty) {
        items.add(DropdownMenuItem<String>(
          value: value,
          child: Text(label),
        ));
      }
    }
    
    return items;
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
      debugPrint('[VlinderSingleSelectField] WARNING: HetuInterpreterProvider not found, defaulting to visible');
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
      debugPrint('[VlinderSingleSelectField] Error evaluating visibility expression "${widget.visible}": $e');
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
    final isReadOnly = widget.readOnly ?? false;
    final dropdownItems = _buildDropdownItems();

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label ?? widget.field,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  if (isRequired)
                    const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        '*',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _value,
                      decoration: InputDecoration(
                        hintText: widget.placeholder ?? 'Select',
                        border: const OutlineInputBorder(),
                        errorText: error,
                      ),
                      items: dropdownItems,
                      onChanged: isReadOnly ? null : _onChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
