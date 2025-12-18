# Vlinder Sample App

This directory contains a complete sample application demonstrating Vlinder's capabilities. The sample app showcases a **Customer Registration** workflow with validation, multi-step forms, and business rules.

## Overview

The sample app demonstrates:

- **Schema Definition** - Entity schemas with field types, constraints, and validation
- **UI Definition** - Form-based UI with multiple input fields and actions
- **Workflow Management** - Multi-step workflows with transitions
- **Business Rules** - Validation rules and conditional logic

## File Structure

```
sample_app/
└── assets/
    ├── schema.ht      # Entity schema definitions
    ├── ui.ht          # UI layout and widget definitions
    ├── workflows.ht    # Workflow definitions and transitions
    └── rules.ht        # Business rules and validation logic
```

## Files Explained

### `schema.ht` - Entity Schema Definitions

Defines the data model for the application. This file demonstrates:

- **Customer Entity** - Personal information fields (name, email, age, phone)
- **Product Entity** - Product catalog fields (name, price, description)
- **Field Types** - `integer`, `text`, `decimal`, `date`
- **Constraints** - `maxLength`, `min`, `max`, `pattern` (regex)
- **Required Fields** - Field-level validation requirements
- **Default Values** - Automatic value assignment

**Example:**
```hetu
final customerSchema = {
  name: 'Customer',
  primaryKey: 'id',
  fields: {
    name: {
      type: 'text',
      required: true,
      constraints: {
        maxLength: 100,
      },
    },
    email: {
      type: 'text',
      required: true,
      constraints: {
        pattern: '^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}\$',
      },
    },
  },
};
```

### `ui.ht` - User Interface Definition

Defines the visual layout and user interactions. This file demonstrates:

- **Screen Widget** - Top-level container with title and navigation
- **Form Widget** - Data capture container bound to entity schema
- **Input Fields** - `TextField`, `NumberField` with labels and placeholders
- **Action Buttons** - Primary and secondary actions (`submit_customer`, `cancel`)
- **Text Display** - Headline text with styling options
- **Logging** - Debug logging using `log()` and `logInfo()`

**Example:**
```hetu
final screen = Screen(
  id: 'customer_registration',
  title: 'Customer Registration',
  children: [
    Text(
      text: 'Customer Registration Sample App',
      style: 'headline',
      align: 'center',
    ),
    Form(
      entity: 'Customer',
      fields: [
        TextField(
          field: 'name',
          label: 'Full Name',
          required: true,
        ),
      ],
    ),
  ],
);
```

### `workflows.ht` - Workflow Definitions

Defines multi-step workflows and transitions. This file demonstrates:

- **Workflow Structure** - Workflow ID, label, initial step
- **Step Definitions** - Step ID, label, associated screen, next steps
- **Workflow Transitions** - Step-to-step navigation paths
- **Multiple Workflows** - Customer registration and inspection workflows

**Example:**
```hetu
final customerRegistrationWorkflow = {
  workflowType: 'Workflow',
  id: 'customer_registration',
  label: 'Customer Registration',
  initialStep: 'personal_info',
  steps: {
    personal_info: {
      stepType: 'WorkflowStep',
      id: 'personal_info',
      label: 'Personal Information',
      screenId: 'customer_registration',
      nextSteps: ['review'],
    },
  },
};
```

### `rules.ht` - Business Rules and Validation

Defines validation rules and conditional business logic. This file demonstrates:

- **Validation Rules** - Field-level validation (email required, age range, email format)
- **Business Rules** - Conditional logic (phone formatting, discount calculation)
- **Rule Structure** - Rule ID, name, condition expression, action expression
- **Rule Grouping** - Organized into `validationRules` and `businessRules` maps

**Example:**
```hetu
final validationRules = {
  email_required: {
    ruleType: 'Rule',
    id: 'email_required',
    name: 'Email Required',
    condition: 'context.field == "email" && context.value == null',
    action: 'showError("Email is required")',
  },
};
```

## Running the Sample App

### Prerequisites

- Flutter SDK installed
- Vlinder container app built and running
- Development server running (see `scripts/start_dev_server.sh`)

### Loading the Sample App

1. **Start the development server:**
   ```bash
   ./scripts/start_dev_server.sh
   ```

2. **Configure the container app** to fetch assets from the development server

3. **Launch the container app** - It will automatically:
   - Fetch `schema.ht`, `ui.ht`, `workflows.ht`, and `rules.ht` from the server
   - Parse schemas and create database tables
   - Load workflows and rules into the interpreter
   - Parse UI and render the customer registration form

### Expected Behavior

When the app loads, you should see:

1. **Loading Screen** - Progress indicators for each initialization step:
   - Fetching assets
   - Loading schemas
   - Initializing database
   - Loading workflows
   - Loading rules
   - Loading UI

2. **Customer Registration Form** - A form with:
   - Headline text: "Customer Registration Sample App"
   - Form fields:
     - Full Name (required)
     - Email Address (required)
     - Age (integer, optional)
     - Phone Number (optional)
   - Action buttons:
     - Register (primary)
     - Cancel (secondary)

## Key Concepts Demonstrated

### 1. Schema-Driven UI

The UI is automatically generated from the schema definition. Fields in `schema.ht` correspond to form fields in `ui.ht`. The `Form` widget's `entity: 'Customer'` property binds to the `customerSchema` definition.

### 2. Interpreter State Sharing

All `.ht` files are loaded into the **same Hetu interpreter instance**, allowing:

- UI scripts to reference schemas
- Action handlers to access workflows and rules
- Rules to evaluate against form context
- Workflows to transition between screens

This is achieved through:
- `ContainerAppShell` creates a single interpreter
- `VlinderRuntime` receives the shared interpreter
- `HetuInterpreterProvider` makes the interpreter available to widgets
- Action handlers access the interpreter from context

### 3. Logging Integration

The sample app demonstrates debug logging:

- `log()` - DEBUG level logging
- `logInfo()` - INFO level logging
- `logWarning()` - WARNING level logging
- `logError()` - ERROR level logging

Logs are captured during script evaluation and sent to the debug logger, which can forward them to a remote log server.

### 4. Widget Function Calls

Widget constructors (`Screen`, `Form`, `TextField`, etc.) are defined as Hetu functions that return structs. The UI parser:

1. Evaluates the Hetu script
2. Fetches the `screen` variable
3. Parses the HTStruct into a `ParsedWidget` tree
4. Builds Flutter widgets using the `WidgetRegistry`

### 5. Validation and Rules

Validation rules are defined declaratively in `rules.ht`:

- Conditions are Hetu expressions evaluated at runtime
- Actions are Hetu function calls or expressions
- Rules can access form context (`context.field`, `context.value`)
- Rules are evaluated when form fields change

## Extending the Sample App

### Adding a New Field

1. **Update `schema.ht`:**
   ```hetu
   fields: {
     // ... existing fields ...
     newField: {
       type: 'text',
       required: false,
       constraints: {
         maxLength: 50,
       },
     },
   }
   ```

2. **Update `ui.ht`:**
   ```hetu
   Form(
     entity: 'Customer',
     fields: [
       // ... existing fields ...
       TextField(
         field: 'newField',
         label: 'New Field',
         placeholder: 'Enter value',
       ),
     ],
   )
   ```

### Adding a New Validation Rule

1. **Update `rules.ht`:**
   ```hetu
   final validationRules = {
     // ... existing rules ...
     newField_validation: {
       ruleType: 'Rule',
       id: 'newField_validation',
       name: 'New Field Validation',
       condition: 'context.field == "newField" && context.value.length < 3',
       action: 'showError("Field must be at least 3 characters")',
     },
   };
   ```

### Adding a New Workflow Step

1. **Update `workflows.ht`:**
   ```hetu
   steps: {
     // ... existing steps ...
     new_step: {
       stepType: 'WorkflowStep',
       id: 'new_step',
       label: 'New Step',
       screenId: 'new_screen',
       nextSteps: ['complete'],
     },
   }
   ```

2. **Create corresponding UI in `ui.ht`** with `id: 'new_screen'`

## Troubleshooting

### UI Not Loading

- Check that all `.ht` files are present in `assets/` directory
- Verify the development server is running and serving files
- Check Flutter console for parsing errors
- Ensure schemas are loaded before UI parsing

### Validation Rules Not Firing

- Verify rules are loaded into the interpreter (check logs)
- Ensure rule conditions are valid Hetu expressions
- Check that form context is properly injected
- Verify action handlers have access to the interpreter

### Database Errors

- Ensure schemas are loaded before database initialization
- Check that field types match Drift-supported types
- Verify primary key is defined correctly
- Check for table name conflicts

## Related Documentation

- [Main README](../README.md) - Vlinder architecture and design philosophy
- [.cursorrules](../.cursorrules) - Development guidelines and patterns
- [HETU_API_ANALYSIS.md](../HETU_API_ANALYSIS.md) - Hetu Script API reference

## Next Steps

- Explore the Vlinder Widget SDK to see available widgets
- Review workflow engine capabilities
- Study rule evaluation patterns
- Experiment with different field types and constraints
- Build your own custom workflows and rules


