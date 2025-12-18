import 'package:flutter/material.dart';
import '../binding/drift_binding.dart';
import '../core/database_provider.dart';

/// Form widget - Primary data capture container with Drift entity binding
/// 
/// Properties:
/// - entity: String - Name of the Drift entity/table
/// - children: List<Widget> - Form fields and other widgets
class VlinderForm extends StatefulWidget {
  final String entity;
  final List<Widget> children;
  final FormStateManager? formState;
  final void Function(FormStateManager)? onFormStateReady;

  const VlinderForm({
    super.key,
    required this.entity,
    required this.children,
    this.formState,
    this.onFormStateReady,
  });

  @override
  State<VlinderForm> createState() => _VlinderFormState();

  /// Create from properties map (used by widget registry)
  /// Note: This is called during UI parsing, before the widget tree is built.
  /// The formState will be created in didChangeDependencies() when the widget
  /// is actually inserted into the tree and can access DatabaseAPIProvider.
  static Widget fromProperties(
    BuildContext context,
    Map<String, dynamic> properties,
    List<Widget>? children,
  ) {
    final entity = properties['entity'] as String? ?? 'Entity';
    final childrenList = children ?? [];
    
    if (childrenList.isEmpty) {
      debugPrint('[VlinderForm] WARNING: Form has no children!');
    }
    
    // Don't create formState here - it will be created in didChangeDependencies()
    // when the widget is inserted into the tree and can access DatabaseAPIProvider
    return VlinderForm(
      entity: entity,
      children: childrenList,
      formState: null, // Will be created in didChangeDependencies()
    );
  }
}

class _VlinderFormState extends State<VlinderForm> {
  FormStateManager? _formState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // If formState wasn't provided, try to get schema from DatabaseAPIProvider
    if (_formState == null && widget.formState == null) {
      final databaseAPI = DatabaseAPIProvider.of(context);
      if (databaseAPI != null) {
        final schema = databaseAPI.getSchema(widget.entity);
        if (schema != null) {
          debugPrint('[VlinderForm] Using loaded schema for entity: ${widget.entity}');
          final newFormState = FormStateManager(schema: schema);
          setState(() {
            _formState = newFormState;
          });
          // Notify parent (Screen) that form state is ready
          widget.onFormStateReady?.call(newFormState);
        } else {
          debugPrint('[VlinderForm] WARNING: Schema not found for entity "${widget.entity}", creating empty schema');
          final newFormState = FormStateManager(
            schema: EntitySchema(
              name: widget.entity,
              fields: {},
            ),
          );
          setState(() {
            _formState = newFormState;
          });
          // Notify parent (Screen) that form state is ready
          widget.onFormStateReady?.call(newFormState);
        }
      } else {
        debugPrint('[VlinderForm] WARNING: DatabaseAPIProvider not found in context, creating empty schema');
        final newFormState = FormStateManager(
          schema: EntitySchema(
            name: widget.entity,
            fields: {},
          ),
        );
        setState(() {
          _formState = newFormState;
        });
        // Notify parent (Screen) that form state is ready
        widget.onFormStateReady?.call(newFormState);
      }
    } else if (widget.formState != null && _formState != widget.formState) {
      setState(() {
        _formState = widget.formState;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use provided formState or the one we created
    final formStateToUse = widget.formState ?? _formState;
    
    if (formStateToUse != null) {
      debugPrint('[VlinderForm] build() - Providing FormStateProvider: isValid=${formStateToUse.isValid}, values=${formStateToUse.values}');
    } else {
      debugPrint('[VlinderForm] build() - WARNING: formStateToUse is null, FormStateProvider not provided');
    }
    
    // Build the form content
    Widget formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.children,
    );

    // Wrap the entire Form widget with FormStateProvider so:
    // 1. Form fields (children) can access it
    // 2. Siblings (like ActionButton) can access it via FormStateProvider.of(context)
    if (formStateToUse != null) {
      return FormStateProvider(
        formState: formStateToUse,
        child: formContent,
      );
    }

    return formContent;
  }
}

