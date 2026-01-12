# Vlinder Implementation Notes

## Architecture Overview

This implementation provides a Hetu script-based UI composition system for Flutter, integrated with Drift for data-aware widgets.

## Key Components

### 1. Widget Registry (`lib/vlinder/core/widget_registry.dart`)
- Centralized registry mapping widget names to Flutter widget builders
- Ensures only SDK widgets can be instantiated (App Store safety)
- Provides conversion utilities from Hetu HTValue to Dart types

### 2. YAML UI Parser (`lib/vlinder/parser/yaml_ui_parser.dart`)
- Parses `ui.yaml` files (YAML format)
- Extracts widget tree structure from YAML
- Converts YAML structure to parsed widget definitions
- Builds Flutter widget trees recursively

### 3. Drift Binding (`lib/vlinder/binding/drift_binding.dart`)
- `FormStateManager`: Manages form state and validation
- `EntitySchema`: Defines entity schemas with field types and constraints
- `FormStateProvider`: InheritedWidget for accessing form state
- Two-way data binding between widgets and form state

### 4. Widget SDK (Prototype)
- **Screen**: Container for navigable screens
- **Form**: Data capture container with entity binding
- **TextField**: Text input with schema-aware validation
- **NumberField**: Numeric input (integer/decimal) with validation
- **ActionButton**: Button that triggers Hetu script actions

### 5. Runtime Engine (`lib/vlinder/runtime/vlinder_runtime.dart`)
- Coordinates parser, factory, and binding layers
- Loads and parses `ui.yaml` files (YAML format)
- Registers all SDK widgets
- Provides error handling

## Usage Example

```dart
import 'package:vlinder/vlinder.dart';

final runtime = VlinderRuntime();
final uiWidget = runtime.loadUI(scriptContent, context);
```

## YAML UI Format

The `ui.yaml` file should define widgets using YAML syntax:

```yaml
screen:
  widgetType: Screen
  id: customer_form
  title: Customer Registration
  children:
    - widgetType: Form
      entity: Customer
      fields:
        - widgetType: TextField
          field: name
          label: Customer Name
          required: true
        - widgetType: NumberField
          field: age
          label: Age
          type: integer
    - widgetType: ActionButton
      label: Submit
      action: submit_customer
```

## Current Limitations

1. **Parser**: The YAML parser converts YAML structure to widget trees. All widgets must have a `widgetType` property.

2. **Schema Loading**: Schema definitions from `schema.yaml` (OpenAPI YAML format with `$ref` references) are integrated. Forms bind to entity schemas.

3. **Hetu Script Execution**: Action buttons execute Hetu scripts for actions via ActionHandler integration.

4. **Drift Integration**: The binding layer is integrated with Drift database tables created from schemas.

## Next Steps

1. Enhance YAML parser with additional validation and error messages
2. Add remaining widgets from the SDK (currently ~5 widgets implemented)
3. Enhance workflow engine capabilities
4. Expand rules engine functionality
5. Add UI preview/validation tools





