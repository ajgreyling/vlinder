import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../binding/drift_binding.dart';
import '../core/interpreter_provider.dart';
import 'package:hetu_script/values.dart';

/// DateField widget - Date selection with calendar picker bound to Drift field
/// 
/// Properties:
/// - field: String - Name of the schema field
/// - label: String? - Label text for the field
/// - required: bool? - Whether the field is required
/// - placeholder: String? - Placeholder text
/// - readOnly: bool? - Whether the field is read-only
/// - visible: String? - Optional Hetu expression for conditional visibility
class VlinderDateField extends StatefulWidget {
  final String field;
  final String? label;
  final bool? required;
  final String? placeholder;
  final bool? readOnly;
  final String? visible; // Hetu expression for conditional visibility

  const VlinderDateField({
    super.key,
    required this.field,
    this.label,
    this.required,
    this.placeholder,
    this.readOnly,
    this.visible,
  });

  @override
  State<VlinderDateField> createState() => _VlinderDateFieldState();

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

    return VlinderDateField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      readOnly: readOnly,
      visible: visible,
    );
  }
}

class _VlinderDateFieldState extends State<VlinderDateField> {
  late final TextEditingController _controller;
  FormStateManager? _formState;
  bool _listenerAdded = false;
  DateTime? _selectedDate;

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
        _parseAndSetDate(value);
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
      if (value != null) {
        _parseAndSetDate(value);
      } else {
        setState(() {
          _selectedDate = null;
          _controller.text = '';
        });
      }
    }
  }

  void _parseAndSetDate(dynamic value) {
    DateTime? parsedDate;
    
    if (value is DateTime) {
      parsedDate = value;
    } else if (value is String) {
      // Try parsing ISO format (YYYY-MM-DD)
      try {
        parsedDate = DateTime.parse(value);
      } catch (_) {
        // Try other common formats
        try {
          parsedDate = DateFormat('yyyy-MM-dd').parse(value);
        } catch (_) {
          // If parsing fails, leave as null
        }
      }
    }
    
    if (parsedDate != null && _selectedDate != parsedDate) {
      final date = parsedDate; // Assign to non-nullable variable for flow analysis
      setState(() {
        _selectedDate = date;
        _controller.text = DateFormat('yyyy-MM-dd').format(date);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    if (widget.readOnly == true) {
      return;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: widget.label ?? 'Select date',
    );

    if (!mounted || picked == null || picked == _selectedDate) {
      return;
    }
    
    setState(() {
      _selectedDate = picked;
      _controller.text = DateFormat('yyyy-MM-dd').format(picked);
    });
    
    // Store as ISO string (YYYY-MM-DD) in form state
    // Use context from widget tree after mounted check
    final formState = FormStateProvider.of(this.context);
    if (formState != null) {
      formState.setValue(widget.field, DateFormat('yyyy-MM-dd').format(picked));
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
      debugPrint('[VlinderDateField] WARNING: HetuInterpreterProvider not found, defaulting to visible');
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
      debugPrint('[VlinderDateField] Error evaluating visibility expression "${widget.visible}": $e');
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
              TextField(
                controller: _controller,
                readOnly: true, // Always read-only, user must use date picker
                enabled: !isReadOnly,
                decoration: InputDecoration(
                  hintText: widget.placeholder ?? 'Select date',
                  border: const OutlineInputBorder(),
                  errorText: error,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: isReadOnly ? null : () => _selectDate(context),
                    tooltip: 'Select date',
                  ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
                onTap: isReadOnly ? null : () => _selectDate(context),
              ),
            ],
          ),
        );
      },
    );
  }
}
