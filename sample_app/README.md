# Vlinder Sample App

This directory contains a complete sample application demonstrating Vlinder's capabilities. The sample app showcases a **Patient Registration** workflow with validation, multi-step forms, conditional field visibility, branching logic, and business rules.

## Overview

The sample app demonstrates:

- **Schema Definition** - Entity schemas with all primitive types (string, integer, number/decimal, boolean, date-time)
- **UI Definition** - Multi-screen form-based UI with conditional field visibility
- **Workflow Management** - Multi-step workflows with conditional transitions
- **Business Rules** - Validation rules and conditional logic
- **Branching Logic** - Age and gender-based conditional fields and screens

## File Structure

```
sample_app/
└── assets/
    ├── schema.yaml    # Entity schema definitions (OpenAPI format)
    ├── ui.yaml        # UI layout and widget definitions (YAML format)
    ├── workflows.yaml # Workflow definitions and transitions (YAML format)
    ├── rules.ht       # Business rules and validation logic
    └── actions.ht     # Action handlers for navigation and form submission
```

## Files Explained

### `schema.yaml` - OpenAPI Schema Definitions

Defines the data model for the Patient Registration application using **OpenAPI YAML format** with JSON Schema component definitions. This file demonstrates:

- **OpenAPI Structure** - Uses OpenAPI 3.0 specification format
- **JSON Schema Components** - Entity schemas defined in `components/schemas` section
- **Patient Entity** - Comprehensive patient information with all primitive types:
  - `string`: firstName, lastName, gender, email, phone
  - `integer`: id, age
  - `number` (decimal): weight, height
  - `boolean`: pregnant, prostateHealthy
  - `date-time`: dateOfBirth, createdAt
- **Field Types** - All JSON Schema primitive types demonstrated
- **Constraints** - `maxLength`, `minimum`, `maximum`, `pattern` (JSON Schema constraints)
- **Required Fields** - Field-level validation requirements

**Example:**
```yaml
openapi: 3.0.0
info:
  title: Vlinder Schema Definitions
  version: 1.0.0

components:
  schemas:
    Patient:
      type: object
      properties:
        id:
          type: integer
          format: int64
        firstName:
          type: string
          maxLength: 100
        age:
          type: integer
          minimum: 0
          maximum: 150
        weight:
          type: number
          format: decimal
          minimum: 0
        pregnant:
          type: boolean
        dateOfBirth:
          type: string
          format: date-time
```

### `ui.yaml` - User Interface Definition

Defines the visual layout and user interactions across multiple screens in YAML format. This file demonstrates:

- **Multiple Screens** - Landing, Basic Info, Health Info, Senior Screening
- **Screen Widget** - Top-level container with title and navigation
- **Form Widget** - Data capture container bound to entity schema
- **Input Fields** - `TextField`, `NumberField`, `BooleanField` with labels and placeholders
- **Conditional Visibility** - Fields shown/hidden based on form values using `visible` property
- **Action Buttons** - Primary and secondary actions for navigation and submission
- **Text Display** - Headline text with styling options

**Example with Conditional Visibility:**
```yaml
patientHealthInfo:
  widgetType: Screen
  id: patient_health_info
  title: Health Information
  children:
    - widgetType: Form
      entity: Patient
      fields:
        - widgetType: BooleanField
          field: pregnant
          label: Pregnant?
          required: true
          visible: "age > 16 && gender == 'Female'"
```

**Key Features:**
- **Conditional Visibility**: Use `visible` property with Hetu expressions to show/hide fields
- **Multi-Screen Forms**: Forms span multiple screens, maintaining state across navigation
- **Branching Logic**: Different screens shown based on patient age and gender

### `workflows.yaml` - Workflow Definitions

Defines multi-step workflows and conditional transitions in YAML format. This file demonstrates:

- **Workflow Structure** - Workflow ID, label, initial step
- **Step Definitions** - Step ID, label, associated screen, next steps
- **Conditional Transitions** - Steps shown based on conditions (e.g., age > 50)
- **Workflow Transitions** - Step-to-step navigation paths

**Example:**
```yaml
workflows:
  patient_registration:
    id: patient_registration
    label: Patient Registration
    initialStep: landing
    steps:
      health_info:
        id: health_info
        label: Health Information
        screenId: patient_health_info
        nextSteps:
          - senior_screening
          - complete
        conditions:
          senior_screening: "age > 50"
          complete: "age <= 50"
```

### `rules.ht` - Business Rules and Validation

Defines validation rules and conditional business logic. This file demonstrates:

- **Validation Rules** - Field-level validation (required fields, age range, email format)
- **Conditional Validation** - Rules that apply based on other field values
- **Business Rules** - Conditional logic (age calculation, phone formatting)
- **Rule Structure** - Rule ID, name, condition expression, action expression
- **Rule Grouping** - Organized into `validationRules` and `businessRules` maps

**Example:**
```hetu
final validationRules = {
  pregnant_required_female_over_16: {
    ruleType: 'Rule',
    id: 'pregnant_required_female_over_16',
    name: 'Pregnant Required for Females Over 16',
    condition: 'context.field == "pregnant" && context.formValues["age"] != null && context.formValues["age"] > 16 && context.formValues["gender"] == "Female" && context.value == null',
    action: 'showError("Pregnant status is required for females over 16")',
  },
};
```

### `actions.ht` - Action Handlers

Defines action functions for navigation and form submission. This file demonstrates:

- **Navigation Actions** - Multi-step form navigation with validation
- **Conditional Navigation** - Skip steps based on patient age
- **Form Submission** - Save patient data to database
- **Validation** - Field validation before navigation/submission

**Example:**
```hetu
fun next_to_senior_screening() {
  final formValues = actionContext.formValues ?? {}
  final age = formValues['age']
  final ageValue = age is num ? age : (age is String ? int.tryParse(age) : null)
  
  if (ageValue != null && ageValue > 50) {
    // Navigate to senior screening
  } else {
    // Skip and submit directly
    submit_patient()
  }
}
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
   This script automatically copies all files from `sample_app/assets` to `server/assets`.

2. **Configure the container app** to fetch assets from the development server

3. **Launch the container app** - It will automatically:
   - Fetch `schema.yaml`, `ui.yaml`, `workflows.yaml`, `rules.ht`, and `actions.ht` from the server
   - Parse schemas (OpenAPI format) and create database tables
   - Load workflows (YAML format) and rules into the interpreter
   - Parse UI and render the patient registration screens

### Expected Behavior

When the app loads, you should see:

1. **Loading Screen** - Progress indicators for each initialization step:
   - Fetching assets
   - Loading schemas
   - Initializing database
   - Loading workflows
   - Loading rules
   - Loading actions
   - Loading UI

2. **Landing Screen** - Welcome screen with "Capture New Patient" button

3. **Basic Information Screen** - Form with:
   - First Name (required)
   - Last Name (required)
   - Date of Birth
   - Age (required, integer)
   - Gender (required)
   - Email Address
   - Phone Number
   - "Next" button

4. **Health Information Screen** - Form with:
   - Weight (decimal)
   - Height (decimal)
   - Pregnant? (boolean, required, **only visible if age > 16 and gender == 'Female'**)
   - "Next" button

5. **Senior Screening Screen** (conditional) - **Only shown if age > 50**:
   - Prostate Healthy? (boolean, required, **only visible if age > 50 and gender == 'Male'**)
   - "Submit Patient" button

## Key Concepts Demonstrated

### 1. Conditional Field Visibility

Fields can be shown or hidden based on form values using the `visible` property with Hetu expressions:

```yaml
- widgetType: BooleanField
  field: pregnant
  label: Pregnant?
  required: true
  visible: "age > 16 && gender == 'Female'"
```

The visibility expression is evaluated reactively as form values change, using `ValueListenableBuilder` to update the UI.

### 2. Multi-Screen Forms

Forms can span multiple screens while maintaining state. The same `entity: Patient` is used across screens, and form state persists as users navigate between screens.

### 3. Branching Logic

The workflow demonstrates conditional navigation:
- Patients over 50 see the Senior Screening screen
- Patients 50 or under skip directly to completion
- Gender-specific fields appear based on age and gender values

### 4. All Primitive Types

The Patient schema demonstrates all JSON Schema primitive types:
- **string**: firstName, lastName, gender, email, phone
- **integer**: id, age
- **number** (decimal): weight, height
- **boolean**: pregnant, prostateHealthy
- **date-time**: dateOfBirth, createdAt

### 5. Conditional Required Fields

Fields can be conditionally required:
- `pregnant` is required for females over 16
- `prostateHealthy` is required for males over 50

This is enforced both in validation rules and in action handlers.

## Extending the Sample App

### Adding a New Conditional Field

1. **Update `schema.yaml`** to add the field to the Patient schema

2. **Update `ui.yaml`** to add the field with conditional visibility:
   ```yaml
   - widgetType: BooleanField
     field: newField
     label: New Field
     required: true
     visible: "age > 18 && gender == 'Male'"
   ```

3. **Update `rules.ht`** to add validation rules if needed

### Adding a New Screen

1. **Add screen definition to `ui.yaml`**:
   ```yaml
   newScreen:
     widgetType: Screen
     id: new_screen
     title: New Screen
     children:
       # ... widgets ...
   ```

2. **Update `workflows.yaml`** to add the step:
   ```yaml
   new_step:
     id: new_step
     label: New Step
     screenId: new_screen
     nextSteps:
       - complete
   ```

3. **Add navigation action to `actions.ht`** if needed

## Troubleshooting

### Conditional Fields Not Showing/Hiding

- Verify the `visible` expression syntax is correct Hetu script
- Check that form values are being set correctly (age, gender, etc.)
- Ensure `HetuInterpreterProvider` is available in the widget tree
- Check Flutter console for visibility evaluation errors

### Multi-Screen Form State Lost

- Ensure all screens use the same `entity: Patient`
- Verify form state is being passed between screens
- Check that navigation actions preserve form state

### Validation Rules Not Firing

- Verify rules are loaded into the interpreter (check logs)
- Ensure rule conditions are valid Hetu expressions
- Check that form context is properly injected
- Verify conditional required fields match the visibility conditions

## Related Documentation

- [Main README](../README.md) - Vlinder architecture and design philosophy
- [.cursorrules](../.cursorrules) - Development guidelines and patterns
- [HETU_API_ANALYSIS.md](../HETU_API_ANALYSIS.md) - Hetu Script API reference

## Next Steps

- Explore conditional visibility patterns for complex forms
- Review workflow engine capabilities for branching logic
- Study rule evaluation patterns for conditional validation
- Experiment with different field types and constraints
- Build your own custom workflows with conditional transitions
