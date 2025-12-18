# Vlinder Implementation Notes

## Architecture Overview

This implementation provides a Hetu script-based UI composition system for Flutter, integrated with Drift for data-aware widgets.

## Key Components

### 1. Widget Registry (`lib/vlinder/core/widget_registry.dart`)
- Centralized registry mapping widget names to Flutter widget builders
- Ensures only SDK widgets can be instantiated (App Store safety)
- Provides conversion utilities from Hetu HTValue to Dart types

### 2. Hetu Parser (`lib/vlinder/parser/ui_parser.dart`)
- Parses `ui.ht` files using Hetu interpreter
- Extracts widget tree structure from Hetu script
- Converts Hetu values to parsed widget definitions
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
- Loads and executes `ui.ht` files
- Registers all SDK widgets
- Provides error handling

## Usage Example

```dart
import 'package:vlinder/vlinder.dart';

final runtime = VlinderRuntime();
final uiWidget = runtime.loadUI(scriptContent, context);
```

## Hetu Script Format

The `ui.ht` file should define widgets using Hetu's function call syntax:

```hetu
final screen = Screen(
  id: 'customer_form',
  title: 'Customer Registration',
  children: [
    Form(
      entity: 'Customer',
      fields: [
        TextField(
          field: 'name',
          label: 'Customer Name',
          required: true,
        ),
        NumberField(
          field: 'age',
          label: 'Age',
          type: 'integer',
        ),
      ],
    ),
    ActionButton(
      label: 'Submit',
      action: 'submit_customer',
    ),
  ],
);
```

## Current Limitations

1. **Parser**: The current parser uses a simplified approach. A full implementation would parse Hetu's AST to extract widget types more accurately.

2. **Schema Loading**: Schema definitions from `schema.ht` are not yet integrated. Forms currently use empty schemas.

3. **Hetu Script Execution**: Action buttons don't yet execute Hetu scripts for actions. This requires integration with Hetu's function calling mechanism.

4. **Drift Integration**: While the binding layer is in place, actual Drift database tables are not yet created or used.

## Next Steps

1. Improve Hetu parser to use AST for accurate widget type detection
2. Implement schema loader for `schema.ht` files
3. Integrate Hetu script execution for action handlers
4. Create Drift table definitions from schemas
5. Add remaining 27 widgets from the SDK
6. Implement workflow engine (`workflows.ht` parser)
7. Add rules engine (`rules.ht` parser)

