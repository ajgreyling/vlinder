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

- `schema.ht`
- `workflows.ht`
- `ui.ht`
- `rules.ht`

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

#### 3️⃣ Input Fields (10)

Schema-aware, validated, event-emitting fields.

- **TextField** — Free-form text input
- **NumberField** — Numeric input (integer / decimal)
- **DateField** — Date selection
- **TimeField** — Time selection
- **BooleanField** — Yes / No input
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

- Schemas are defined declaratively (`schema.ht`)
- Stored locally using **Drift / SQLite**
- Synced via **Posduif** to PostgreSQL

Widgets bind directly to schema fields, enabling:
- Validation
- Conflict-aware sync
- Efficient diffs

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

Vlinder parsers use Hetu Script to load and parse `.ht` files:

- **SchemaLoader** - Parses `schema.ht` files into `EntitySchema` objects
- **UIParser** - Parses `ui.ht` files into widget trees
- **WorkflowParser** - Parses `workflows.ht` files into workflow definitions
- **RulesParser** - Parses `rules.ht` files into rule definitions

All parsers:
- Require Hetu interpreter to be initialized (`hetu.init()`)
- Use `interpreter.fetch()` to get variables after `eval()`
- Iterate HTStruct using `for (final key in struct.keys)`
- Return Dart native types, not Hetu wrapper types
- **Check for existing functions before defining them** to prevent "already defined" errors
- Define constructor functions once in the constructor, not in `load*()` methods

### Database Integration

Vlinder uses **Drift** for SQLite ORM and **sqlite3** for custom SQL execution:

- **Drift** (`LazyDatabase`, `NativeDatabase`) - For ORM operations and table definitions
- **sqlite3** - For runtime custom SQL execution (CREATE TABLE, etc.)
- Custom SQL execution uses `sqlite3.open()` directly, not `NativeDatabase.executor`
- Add `sqlite3: ^2.4.0` to dependencies for custom SQL support

### Debug Logging

Vlinder includes comprehensive debug logging throughout:

- Use `debugPrint()` with component prefixes: `[ComponentName] Message`
- Examples: `[VlinderDatabase]`, `[ContainerAppShell]`, `[UIParser]`, `[SchemaLoader]`
- Logs include initialization steps, SQL execution, schema loading, and error details
- All logs are prefixed for easy filtering in Flutter console

### Runtime Engine

`VlinderRuntime` coordinates all components:
- Automatically initializes Hetu interpreter
- Registers SDK widgets with `WidgetRegistry`
- Provides `loadUI()` to parse and build widget trees
- Handles errors gracefully with fallback UI
- Includes debug logging for troubleshooting

---
