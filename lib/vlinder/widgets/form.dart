import 'package:flutter/material.dart';
import '../binding/drift_binding.dart';

/// Form widget - Primary data capture container with Drift entity binding
/// 
/// Properties:
/// - entity: String - Name of the Drift entity/table
/// - children: List<Widget> - Form fields and other widgets
class VlinderForm extends StatelessWidget {
  final String entity;
  final List<Widget> children;
  final FormStateManager? formState;

  const VlinderForm({
    super.key,
    required this.entity,
    required this.children,
    this.formState,
  });

  @override
  Widget build(BuildContext context) {
    // If formState is provided, wrap children in FormStateProvider
    Widget formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    if (formState != null) {
      formContent = FormStateProvider(
        formState: formState!,
        child: formContent,
      );
    }

    return formContent;
  }

  /// Create from properties map (used by widget registry)
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
    
    // In a real implementation, you'd load the schema from schema.ht
    // For now, create a basic schema
    final schema = EntitySchema(
      name: entity,
      fields: {},
    );
    
    final formState = FormStateManager(schema: schema);

    return VlinderForm(
      entity: entity,
      children: childrenList,
      formState: formState,
    );
  }
}

