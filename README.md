# Vlinder

**Vlinder** (Afrikaans for *butterfly*) is the lightweight, mobile runtime of **Project Posduif**.

Like a butterfly, Vlinder is:
- **Light** — minimal footprint, minimal data usage
- **Adaptive** — behaviour changes without redeploying the app
- **Resilient** — designed to keep working where connectivity is poor or expensive

Vlinder is a **Free and Open Source Software (FOSS)** project intended for **enterprise-grade mobile applications**, especially in environments such as **Africa**, where:
- Mobile data is costly
- Connectivity is intermittent
- Offline-first operation is essential

---

## Relationship to Project Posduif

Project **Posduif** (carrier pigeon) is concerned with **reliable data synchronisation** between:

- **On-device SQLite** (via **Drift**) and
- **Backend PostgreSQL**

Posduif focuses on:
- Compression of data during sync (both directions)
- Conflict resolution
- Incremental, resumable sync using constrained networks

**Vlinder** is the **mobile execution layer** that:
- Captures data
- Executes workflows
- Enforces business rules
- Presents a stable UI

Vlinder does **not** care *how* data syncs — it assumes Posduif will deliver consistency.

---

## Core Design Philosophy

### 1. Container App, Not a Business App

The app published to the App Store / Play Store is a **container**:

- No tenant-specific business logic
- No fixed schema
- No workflows
- No UI definitions

All business behaviour is delivered *after installation*.

---

### 2. Standard Widget SDK (Not Remote Widgets)

Vlinder embeds a **fixed, versioned Widget SDK** into the app.

Key properties:
- Widgets are **precompiled Flutter widgets**
- The SDK is **small (~30 widgets)**
- Widgets are **high-level and opinionated**
- Flutter layout primitives are *not* exposed

This gives:
- Strong compile-time guarantees
- Predictable performance
- App Store safety
- Long-term compatibility

Flutter widgets are an **implementation detail**, not part of the public contract.

---

### 3. Scripted Behaviour, Not Scripted UI

Vlinder uses **Hetu Script** (or a constrained fork) to control:

- Business rules
- Validation
- Workflow transitions
- Navigation
- Conditional behaviour

Scripts:
- Cannot create arbitrary widgets
- Cannot access native APIs directly
- Cannot perform network calls

They operate strictly within a **sandboxed API surface**.

---

### 4. Declarative Runtime Assets

Only the following files are delivered to the device when behaviour changes:

- `schema.yaml` - Entity schemas defined in OpenAPI format with JSON Schema component definitions and `$ref` references for relationships
- `workflows.yaml` - Workflow definitions and step transitions (YAML format)
- `ui.yaml` - UI screen and widget definitions (YAML format)
- `rules.ht` - Business rules and validation logic
- `actions.ht` - Action handler functions (required)

For a new feature release:
- **No app update is required**
- **No Dart code is downloaded**
- Only these small, compressed files are synced

This drastically reduces:
- Data usage
- Deployment friction
- Risk of runtime failure

---

### 5. Offline-First by Default

Vlinder assumes:
- The device will often be offline
- Sync may be delayed or partial

Therefore:
- All widgets are data-aware
- All actions are recorded locally
- All workflows can proceed offline
- Sync is eventual, not immediate

The UI and logic are **deterministic without connectivity**.

---

### 6. Strong Design-Time Validation

Before runtime assets are deployed:

- Scripts are parsed and validated
- Widget usage is checked against the SDK
- Schema references are verified
- Workflow transitions are validated

The guiding rule:

> *If it validates at design time, it must run on-device.*

This is critical for enterprise trust.

---

## Widget SDK Overview

Vlinder exposes a **minimal but powerful widget set (~32 widgets)**, organized into 7 categories:

### Vlinder Standard Widget SDK (32 Widgets)

#### 1️⃣ App & Navigation (5)

These define application structure and navigation, not layout.

- **AppShell** — Global application frame (theme, roles, navigation policy)
- **Screen** — A navigable unit of UI and logic
- **Section** — Logical grouping of content within a screen
- **Step** — Workflow step (wizard, checklist, guided flow)
- **Modal** — Dialog or overlay interaction

#### 2️⃣ Form Containers (4)

Core building blocks for enterprise data capture.

- **Form** — Primary data capture container
- **FieldGroup** — Logical grouping of related fields
- **Repeater** — Repeatable sub-form for collections
- **ReadOnlyView** — Display-only view bound to schema data

#### 3️⃣ Input Fields (11)

Schema-aware, validated, event-emitting fields.

- **TextField** — Free-form text input
- **NumberField** — Numeric input (integer / decimal)
- **DateField** — Date selection
- **TimeField** — Time selection
- **BooleanField** — Yes / No input
- **SingleSelectField** — Single-choice dropdown selection
- **ChoiceField** — Single-choice (enum)
- **MultiChoiceField** — Multiple-choice selection
- **LookupField** — Reference to another entity
- **EmailField** — Email input with validation
- **PhoneField** — Phone number input

#### 4️⃣ Media & Sensors (5)

Mobile-native capabilities, offline-safe.

- **PhotoCapture** — Capture photos using device camera
- **PhotoGallery** — View captured images
- **QRCodeScanner** — Scan QR codes (registration, assets, workflows)
- **SignatureCapture** — Capture handwritten signatures
- **LocationField** — Capture GPS location

#### 5️⃣ Data Display (4)

Read-only data representation.

- **DataList** — List of records bound to schema
- **DataTable** — Tabular data view
- **KeyValueView** — Label–value data presentation
- **StatusBadge** — State / status indicator

#### 6️⃣ Actions & Feedback (3)

User intent and system feedback.

- **ActionButton** — Primary or secondary action trigger
- **Notification** — Toasts, alerts, error messages
- **ProgressIndicator** — Loading, syncing, background activity

#### 7️⃣ Spatial (1)

High-leverage, domain-safe spatial interaction.

- **MapView** — Interactive map with:
  - Multiple layers
  - Points, polylines, polygons
  - Selection and editing
  - Offline geometry storage

### Why this list works

✔ Small enough to reason about  
✔ Powerful enough for real enterprise workflows  
✔ Stable for years of backward compatibility  
✔ Safe for App Store review  
✔ Perfectly aligned with Hetu scripting

### Mapping Support

`MapView` provides:
- Multiple layers
- Points, polylines, and polygons
- Feature selection and editing
- Offline geometry storage

Map engine details (Mapbox, MapLibre, Google Maps) are **hidden from scripts**.

---

## Data Model Integration

- Schemas are defined in **OpenAPI YAML format** (`schema.yaml`) with JSON Schema component definitions and **`$ref` references** for relationships between entities
- Stored locally using **Drift / SQLite**
- Synced via **Posduif** to PostgreSQL

Widgets bind directly to schema fields, enabling:
- Validation
- Conflict-aware sync
- Efficient diffs

### Schema Format

Schemas use the **OpenAPI YAML format** with JSON Schema for component definitions. **Relationships between entities are defined using `$ref` references**, allowing entities to reference each other. Foreign key relationships are specified using the `x-foreign-key` extension for database-level constraints.

**Example:**
```yaml
openapi: 3.0.0
info:
  title: Vlinder Schema Definitions
  version: 1.0.0

components:
  schemas:
    Customer:
      type: object
      properties:
        id:
          type: integer
          format: int64
        name:
          type: string
          maxLength: 100
        email:
          type: string
          format: email
        orders:
          type: array
          items:
            $ref: '#/components/schemas/Order'
      required:
        - id
        - name
        - email
    
    Order:
      type: object
      properties:
        id:
          type: integer
          format: int64
        customerId:
          type: integer
          format: int64
          x-foreign-key: Customer.id
        customer:
          $ref: '#/components/schemas/Customer'
        total:
          type: number
          format: decimal
          minimum: 0
      required:
        - id
        - customerId
        - total
```

This format supports:
- **Relationships**: Use `$ref` to reference other schemas
- **Foreign Keys**: Use `x-foreign-key` extension for database relationships
- **Dual Database Support**: Works for both PostgreSQL and SQLite/Drift
- **Industry Standard**: Uses OpenAPI 3.0 and JSON Schema specifications

---

## Security & Compliance

Vlinder is designed to pass:
- App Store review
- Enterprise security audits

Key properties:
- No downloaded executable code
- No runtime native access
- Sandboxed scripting
- Deterministic behaviour

---

## Target Use Cases

Vlinder is ideal for:

- Field service applications
- Inspections and audits
- Asset tracking
- Data collection in rural areas
- SME enterprise workflows

Especially where:
- Bandwidth is limited
- Latency is high
- Reliability matters more than visual experimentation

---

## Summary

Vlinder is:

- A **lightweight, scriptable mobile runtime**
- Built on **Flutter**, **Drift**, and **Hetu**
- Designed for **offline-first enterprise apps**
- Optimised for **low data usage** and **high reliability**
- Fully **open source**

Together with **Project Posduif**, it enables robust mobile applications that work where traditional cloud-first apps fail.

---

## Development & Testing

### Hetu Script API (0.4.2+1)

Vlinder uses Hetu Script version 0.4.2+1 for runtime scripting. Key API patterns:

**Initialization:**
```dart
final hetu = Hetu();
hetu.init(); // REQUIRED - must be called before use
```

**Variable Access:**
```dart
final value = hetu.fetch('variableName'); // NOT getType()
```

**Function Invocation:**
```dart
final result = hetu.invoke('functionName', positionalArgs: [1, 2]); // NOT call()
```

**Type Handling:**
- Hetu returns Dart native types (`String`, `int`, `bool`, `List`) - not `HTString`, `HTInt`, etc.
- Only `HTStruct` exists as a wrapper type (import from `package:hetu_script/values.dart`)
- Access HTStruct values: `struct[key]` or iterate with `for (final key in struct.keys)`
- **CRITICAL**: HTStruct uses **string keys** for member access
  - When storing data: convert numeric keys to strings: `"${key}"`
  - When accessing data: use string keys: `struct["1"]` not `struct[1]`
- **CRITICAL**: Always convert HTStruct to Dart types before passing to Dart APIs
  - Use `_convertHetuValueToDart()` helper that handles HTStruct → Map conversion
  - Database operations from Hetu scripts are HTStruct, must convert before processing

**Hetu Script Syntax:**
- Widget constructor functions **must use named parameters** `{param1, param2}` to match UI script calls
- UI scripts call widgets with named syntax: `Screen(id: 'x', title: 'y', children: [...])`
- Constructor functions must be: `fun Screen({id, title, children})` not `fun Screen(id, title, children)`
- Use **spread syntax** `{...obj1, ...obj2}` to merge objects, NOT `Object.assign()` (not available in Hetu runtime)
- **Ternary expressions**: Work for simple conditions, but **avoid ternaries with type checks** (`is num`, `is str`, etc.) - use explicit if-else instead
- Example:
```hetu
// Correct widget constructor
fun Screen({id, title, children}) {
  final result = {
    widgetType: 'Screen',
    id: id,
    title: title,
    children: children ?? [],
  }
  return result
}

// Correct object merging
final rules = {
  ...validationRules,
  ...businessRules,
}
```

**Preventing Function Redefinition:**
When creating parsers that define Hetu functions, always check if they exist first:
```dart
void _initializeConstructors() {
  try {
    interpreter.fetch('defineSchema'); // Check if function exists
    return; // Already defined, skip
  } catch (_) {
    // Function doesn't exist, define it
  }
  interpreter.eval(constructorScript);
}
```

See [HETU_API_ANALYSIS.md](HETU_API_ANALYSIS.md) for complete API documentation.

### Testing & Validation

Vlinder includes comprehensive testing and validation:

**Run All Tests:**
```bash
./scripts/test_and_validate.sh
```

This script:
1. **Flutter Analysis** - Validates Dart code compiles and passes static analysis
2. **Flutter Tests** - Runs unit and integration tests including Hetu script validation
3. **Hetu Script Validation** - Runtime validation of `.ht` files using actual parsers
4. **Build Verification** - Confirms Flutter build system is ready

**Hetu Script Validation:**
- Validates syntax and structure of all `.ht` files
- Checks cross-file references (e.g., Form entities match Schema names)
- Verifies workflow step references are valid
- Tests rule condition syntax can be evaluated

**Test Files:**
- `test/hetu_validator.dart` - Validates individual `.ht` file types
- `test/integration_test.dart` - End-to-end app startup simulation

### Development Scripts

**Build Container App:**
```bash
./scripts/build_container.sh <ngrok_url> [android|ios]
```

**Start Development Server:**
```bash
./scripts/start_dev_server.sh
```

**Test & Validate:**
```bash
./scripts/test_and_validate.sh
```

---

## Architecture Notes

### Hetu Script Integration

Vlinder parsers use Hetu Script to load and parse `.ht` files, and YAML parsing for schemas, UI, and workflows:

- **SchemaLoader** - Parses `schema.yaml` files (OpenAPI 3.0 format) into `EntitySchema` objects using YAML parsing (no Hetu interpreter required)
- **YAMLUIParser** - Parses `ui.yaml` files (YAML format) into widget trees (no Hetu interpreter required)
- **WorkflowParser** - Parses `workflows.yaml` files (YAML format) into workflow definitions (no Hetu interpreter required)
- **RulesParser** - Parses `rules.ht` files into rule definitions (requires Hetu interpreter)

Hetu-based parsers (RulesParser):
- Require Hetu interpreter to be initialized (`hetu.init()`)
- Use `interpreter.fetch()` to get variables after `eval()`
- Iterate HTStruct using `for (final key in struct.keys)`
- Return Dart native types, not Hetu wrapper types
- **Check for existing functions before defining them** to prevent "already defined" errors
- Define constructor functions once in the constructor, not in `load*()` methods
- **Use named parameters** in constructor functions to match UI script syntax

YAML-based parsers (SchemaLoader, YAMLUIParser, WorkflowParser):
- Use `package:yaml` to parse YAML content
- Parse OpenAPI 3.0 format for schemas with `$ref` references for relationships
- Form widgets use `fields` array (automatically converted to children), empty `children` arrays are skipped

### Database Integration

Vlinder uses **Drift** for SQLite ORM and **sqlite3** for custom SQL execution:

- **Drift** (`LazyDatabase`, `NativeDatabase`) - For ORM operations and table definitions
- **sqlite3** - For runtime custom SQL execution (CREATE TABLE, etc.)
- Custom SQL execution uses `sqlite3.open()` directly, not `NativeDatabase.executor`
- Add `sqlite3: ^2.4.0` to dependencies for custom SQL support

**CRITICAL Database Operation Patterns:**

1. **HTStruct Handling**: Operations queued from Hetu scripts are `HTStruct`, not `Map`
   - Check for both types: `if (operation is Map || operation is HTStruct)`
   - Convert HTStruct data using `_convertHetuValueToDart()` before passing to database API

2. **Column Name Extraction**: Use explicit column names from schema, NOT `SELECT *`
   - `SELECT *` causes generic column names (`column0`, `column1`, etc.)
   - Build column list from schema: `schema.fields.keys.toList()`
   - Use: `SELECT ${columnNames.join(', ')} FROM $tableName`

3. **List Results**: `findAll()` returns a `List`, not a single item
   - Extract first item if needed: `if (result is List && result.isNotEmpty) { result = result[0]; }`

4. **String Keys**: Store database results with string keys in HTStruct
   - Convert numeric operation IDs to strings: `"${entry.key}"`
   - Access with string keys: `getDbResult(opId.toString())`

#### Database API in Hetu Scripts

Vlinder exposes a database API to Hetu scripts, allowing `.ht` files to interact with the SQLite database. Database functions are **automatically registered** in the Hetu interpreter during app initialization and are available in all `.ht` files (actions.ht, rules.ht, etc.).

**Important:** Database operations use an **async queue pattern** - they are queued during script execution and processed asynchronously by `ActionHandler` after action completion.

**CRITICAL:** Database functions must **always** be registered in the interpreter, regardless of `databaseAPI` availability. In `ActionHandler.executeAction()`, `_ensureDatabaseFunctionsAvailable()` must be called unconditionally before action execution, because actions may reference database functions even if they don't process database operations. Database operation processing (not registration) is conditional on `databaseAPI != null`.

**Available Database Functions:**

All database functions are registered automatically and available in Hetu scripts:

```hetu
// Raw SQL execution (INSERT, UPDATE, DELETE)
final opId = executeSQL("INSERT INTO customer (name, email) VALUES (?, ?)", ["John", "john@example.com"])

// SELECT queries with results
final queryOpId = query("SELECT * FROM customer WHERE age > ?", [18])

// CRUD convenience methods
final saveOpId = save('Customer', {name: 'John', email: 'john@example.com'})
final findOpId = findById('Customer', 1)
final findAllOpId = findAll('Customer', {age: {gt: 18}}, 'name', 10)
final updateOpId = update('Customer', 1, {name: 'Jane'})
final deleteOpId = delete('Customer', 1)

// Get results (after operations are processed)
final result = getDbResult(opId)

// Clear results
clearDbResults()
```

**Function Calling Pattern:**

1. **Call database function** - Returns an operation ID immediately (operation is queued)
2. **Action completes** - ActionHandler automatically processes all queued operations
3. **Get results** - Use `getDbResult(opId)` to retrieve results (in subsequent actions or function calls)

**Example Action Function (actions.ht):**

```hetu
// Define action function with NO parameters (ActionHandler injects actionContext)
fun submit_customer() {
  // Access form values from actionContext (injected by ActionHandler)
  final formValues = actionContext.formValues ?? {}
  final isValid = actionContext.isValid ?? false
  
  // Validate before saving
  if (!isValid) {
    logError("Form validation failed")
    return
  }
  
  // Queue database save operation
  // Returns operation ID immediately, operation is processed after function completes
  final saveOpId = save('Customer', formValues)
  
  logInfo("Save operation queued with ID: ${saveOpId}")
  
  // Note: Results are available via getDbResult(saveOpId) AFTER ActionHandler
  // processes the operations. You cannot get results synchronously within the same function.
}
```

**Key Points:**

- Database functions (`save()`, `query()`, etc.) are **automatically available** - no import needed
- **CRITICAL**: Functions must **always** be registered in the interpreter, even if `databaseAPI` is null
  - `ActionHandler._ensureDatabaseFunctionsAvailable()` is called unconditionally in `executeAction()`
  - Functions exist for actions to reference, even if operations won't be processed
  - Only database operation processing is conditional on `databaseAPI != null`
- Functions **queue operations** and return operation IDs immediately
- Operations are **processed asynchronously** after the action function completes
- Use `getDbResult(opId)` to retrieve results in **subsequent actions or function calls**
- All functions use the **same interpreter instance** that registered them (via HetuInterpreterProvider)

**Form Auto-Save:**

If a form has an `entity` property and no custom action handles submission, `ActionHandler` will automatically save form data to the database:

```hetu
Form(
  entity: 'Customer',
  fields: [
    TextField(field: 'name', label: 'Name'),
    TextField(field: 'email', label: 'Email'),
  ],
)
ActionButton(
  label: 'Save',
  action: 'submit', // Uses default form save behavior
)
```

**Parameter Binding:**

All SQL operations use parameter binding with `?` placeholders to prevent SQL injection:

```hetu
// CORRECT - Parameter binding
query("SELECT * FROM customer WHERE age > ? AND name LIKE ?", [18, "%John%"])

// INCORRECT - String concatenation (vulnerable to SQL injection)
query("SELECT * FROM customer WHERE age > " + age) // WRONG
```

**Result Format:**

- Single row queries return: `{id: 1, name: "John", email: "john@example.com"}`
- Multiple row queries (`findAll`) return: `[{id: 1, name: "John"}, {id: 2, name: "Jane"}]`
- CRUD operations return the affected entity or operation status
- **Important**: `findAll()` always returns a List, even with `limit: 1` - extract first item if needed

**Error Handling:**

Database errors are caught and stored in results with an `error` field:

```hetu
final opId = save('InvalidEntity', {name: 'Test'})
final result = getDbResult(opId)
if (result.error != null) {
  logError("Database error: ${result.error}")
}
```

#### Action Functions (actions.ht)

Action functions are Hetu script functions defined in `actions.ht` that handle user interactions (button clicks, form submissions, etc.). The `actions.ht` file is **required** and must be present for the app to initialize.

**Action Function Definition:**

```hetu
// actions.ht - Define action functions
fun submit_customer() {
  // Access form values from actionContext (injected by ActionHandler)
  final formValues = actionContext.formValues ?? {}
  final isValid = actionContext.isValid ?? false
  
  // Validate form
  if (!isValid) {
    logError("Form validation failed")
    return
  }
  
  // Use database API functions
  final saveOpId = save('Customer', formValues)
  logInfo("Customer save queued: ${saveOpId}")
}
```

**Key Requirements:**

1. **No parameters** - Action functions must be defined with NO parameters: `fun submit_customer()` not `fun submit_customer(params)`
2. **Access actionContext** - Form values and validation state are available via `actionContext.formValues` and `actionContext.isValid`
3. **Database functions available** - All database functions (`save()`, `query()`, etc.) are automatically available
4. **Logging functions available** - Use `log()`, `logInfo()`, `logWarning()`, `logError()` for debugging
5. **Type checking** - When checking types (`is num`, `is str`, etc.), use explicit if-else instead of ternary expressions:
```hetu
// PROBLEMATIC - Ternary with type check may evaluate incorrectly
final ageValue = age is num ? age : null  // May return boolean instead of number

// RECOMMENDED - Use explicit if-else for type checks
var ageValue = null
if (age is num) {
  ageValue = age
}
```

**Action Invocation:**

Actions are invoked when buttons are clicked:

```yaml
# ui.yaml
- widgetType: ActionButton
  label: Register
  action: submit_customer  # Calls submit_customer() function from actions.ht
  style: primary
```

**Action Execution Flow:**

1. User clicks button with `action: 'submit_customer'`
2. ActionHandler checks if `submit_customer` function exists in interpreter
3. If found, injects `actionContext` with form values and validation state
4. Invokes the Hetu function: `interpreter.invoke('submit_customer')`
5. Function executes and queues database operations
6. After function completes, ActionHandler processes queued database operations
7. Results are stored in `_dbResults` and accessible via `getDbResult(opId)`

**Screen Navigation:**

Vlinder supports dynamic screen navigation using the `navigate(screenId)` function. Screens are loaded from UI YAML by matching the `id` field:

```hetu
fun start_registration() {
  // Clear accumulated form values for new registration
  _patientFormValues = {}
  // Navigate to basic info screen
  navigate("patient_basic_info")
}

fun next_to_health_info() {
  // Validate form first
  if (!actionContext.isValid) {
    logError("Form validation failed")
    return
  }
  // Navigate to next screen
  navigate("patient_health_info")
}
```

**Key Points:**
- Navigation function `navigate(screenId)` is automatically registered in Hetu interpreter
- Screen IDs must match the `id` field in UI YAML screen definitions
- Navigation requests are processed **after** action execution completes
- Screens are loaded dynamically from UI YAML and wrapped with necessary providers
- Navigation is asynchronous - don't expect immediate screen change

**Multi-Step Forms:**

For forms spanning multiple screens, form values are automatically accumulated:

```hetu
fun start_registration() {
  // Clear accumulated values when starting new registration
  _patientFormValues = {}
  navigate("patient_basic_info")
}

fun next_to_senior_screening() {
  // actionContext.formValues includes:
  // - All values from Basic Info screen (firstName, lastName, age, etc.)
  // - All values from Health Info screen (weight, height, pregnant)
  final age = actionContext.formValues['age'] // Available from Basic Info!
  if (age > 50) {
    navigate("patient_senior_screening")
  } else {
    submit_patient()
  }
}
```

**How It Works:**
- `_patientFormValues` stores accumulated form values across screens
- Action context merges accumulated + current form values (current takes precedence)
- Form values are automatically saved to accumulated values before navigation
- All screens using the same entity share accumulated form values
- Always clear `_patientFormValues = {}` when starting a new multi-step form

**Fallback to String-Based Actions:**

If a Hetu function is not found, ActionHandler falls back to string-based actions:
- `submit` or `submit_*` - Form submission
- `navigate_*` - Navigation (legacy, prefer `navigate()` function)
- `cancel` - Cancel action

**Best Practices:**

- Define all custom actions in `actions.ht` (required file)
- Use `navigate(screenId)` for screen navigation, not string-based handlers
- Use database API functions for data persistence
- Validate form data before saving
- Clear `_patientFormValues` when starting new multi-step forms
- Use logging functions for debugging
- Handle errors gracefully with try-catch if needed

### Debug Logging

Vlinder includes comprehensive debug logging throughout:

- Use `debugPrint()` with component prefixes: `[ComponentName] Message`
- Examples: `[VlinderDatabase]`, `[ContainerAppShell]`, `[UIParser]`, `[SchemaLoader]`
- Logs include initialization steps, SQL execution, schema loading, and error details
- All logs are prefixed for easy filtering in Flutter console

### Runtime Engine

`VlinderRuntime` coordinates all components:
- Accepts optional Hetu interpreter instance (shares with ContainerAppShell)
- Registers SDK widgets with `WidgetRegistry`
- Provides `loadUI()` to parse and build widget trees
- Provides `loadScreenById()` to load specific screens by ID from UI YAML
- Handles errors gracefully with fallback UI
- Includes debug logging for troubleshooting

**Screen Loading:**

Screens can be loaded dynamically by ID:
```dart
// Load entire UI (first screen found)
final widget = runtime.loadUI(yamlContent, context);

// Load specific screen by ID
final screenWidget = runtime.loadScreenById(yamlContent, "patient_basic_info", context);
```

Screens are loaded from UI YAML by matching the `id` field in screen definitions. Loaded screens must be wrapped with providers (`HetuInterpreterProvider`, `DatabaseAPIProvider`, `UIYAMLProvider`) to function correctly.

### Interpreter Instance Sharing

Vlinder uses a **single Hetu interpreter instance** shared across all components:

1. **ContainerAppShell** creates the interpreter and:
   - Registers database functions (`save()`, `query()`, etc.)
   - Registers logging functions (`log()`, `logInfo()`, etc.)
   - Registers navigation function (`navigate()`)
   - Initializes `_patientFormValues` for multi-step forms
   - Loads schemas, workflows, rules, and actions
   - Stores UI YAML content for screen navigation
2. **VlinderRuntime** receives the shared interpreter (via constructor parameter)
3. **Providers** wrap the UI to make resources available:
   - `HetuInterpreterProvider` - Makes interpreter available to widgets
   - `DatabaseAPIProvider` - Makes database API available
   - `UIYAMLProvider` - Makes UI YAML content available for navigation
4. **Widgets** access resources via provider `of(context)` methods

This pattern ensures:
- UI scripts can reference schemas, workflows, and rules
- Action handlers have access to all loaded data and database functions
- Database functions are available in all `.ht` files (actions.ht, rules.ht, etc.)
- Navigation can load screens dynamically from UI YAML
- Form values accumulate across multi-step forms
- Single source of truth for Hetu script state
- No state isolation between parsers and runtime

**Flutter Widget Patterns:**

**InheritedWidget Access:**
- Never access InheritedWidgets (like `FormStateProvider`, `HetuInterpreterProvider`) in `initState()`
- Access InheritedWidgets in `build()` or `didChangeDependencies()` only
- `didChangeDependencies()` is called after `initState()` and whenever dependencies change
- This prevents "dependOnInheritedWidgetOfExactType was called before initState() completed" errors

**Form Widgets:**
- Form widgets use `fields` array for child widgets, not `children`
- The parser automatically converts `fields` to children widgets
- Empty `children` arrays on Form widgets are automatically skipped
- **CRITICAL**: Form widgets must wrap **themselves** with `FormStateProvider`, not just their children
  - This makes form state available to sibling widgets (like ActionButton)
  - Wrap form content in `build()` method, not just children
- **CRITICAL**: Avoid `setState()` during build phase
  - Use `WidgetsBinding.instance.addPostFrameCallback()` to defer setState calls
  - Prevents "setState() or markNeedsBuild() called during build" errors

**Example:**
```dart
// Create interpreter once
final interpreter = Hetu();
interpreter.init();

// Share with runtime
final runtime = VlinderRuntime(interpreter: interpreter);

// Wrap UI with provider
HetuInterpreterProvider(
  interpreter: interpreter,
  child: loadedUI,
)

// Access in widgets
final interpreter = HetuInterpreterProvider.of(context);
```

See `sample_app/README.md` for a complete example.

---
