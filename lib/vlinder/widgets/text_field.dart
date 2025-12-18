import 'package:flutter/material.dart';
import '../binding/drift_binding.dart';

/// TextField widget - Free-form text input bound to Drift field
/// 
/// Properties:
/// - field: String - Name of the schema field
/// - label: String? - Label text for the field
/// - required: bool? - Whether the field is required
/// - placeholder: String? - Placeholder text
class VlinderTextField extends StatefulWidget {
  final String field;
  final String? label;
  final bool? required;
  final String? placeholder;

  const VlinderTextField({
    super.key,
    required this.field,
    this.label,
    this.required,
    this.placeholder,
  });

  @override
  State<VlinderTextField> createState() => _VlinderTextFieldState();
}

class _VlinderTextFieldState extends State<VlinderTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    
    // Load initial value from form state if available
    final formState = FormStateProvider.of(context);
    if (formState != null) {
      final value = formState.getValue(widget.field);
      if (value != null) {
        _controller.text = value.toString();
      }
      
      // Listen to form state changes
      formState.valueNotifier.addListener(_onFormStateChanged);
    }
  }

  @override
  void dispose() {
    final formState = FormStateProvider.of(context);
    if (formState != null) {
      formState.valueNotifier.removeListener(_onFormStateChanged);
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
      formState.setValue(widget.field, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formState = FormStateProvider.of(context);
    final error = formState?.getError(widget.field);
    final isRequired = widget.required ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: _controller,
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

    return VlinderTextField(
      field: field,
      label: label,
      required: required,
      placeholder: placeholder,
    );
  }
}

