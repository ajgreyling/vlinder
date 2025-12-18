import 'package:flutter/material.dart';
import '../binding/drift_binding.dart';

/// NumberField widget - Numeric input (integer / decimal) bound to Drift field
/// 
/// Properties:
/// - field: String - Name of the schema field
/// - label: String? - Label text for the field
/// - required: bool? - Whether the field is required
/// - placeholder: String? - Placeholder text
/// - type: String? - Number type ('integer' or 'decimal', default 'decimal')
class VlinderNumberField extends StatefulWidget {
  final String field;
  final String? label;
  final bool? required;
  final String? placeholder;
  final String? type; // 'integer' or 'decimal'

  const VlinderNumberField({
    super.key,
    required this.field,
    this.label,
    this.required,
    this.placeholder,
    this.type,
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

  @override
  Widget build(BuildContext context) {
    final formState = FormStateProvider.of(context);
    final error = formState?.getError(widget.field);
    final isRequired = widget.required ?? false;
    final isInteger = widget.type == 'integer';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _controller,
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
        onChanged: _onChanged,
      ),
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

    return VlinderNumberField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
      type: type,
    );
  }
}

