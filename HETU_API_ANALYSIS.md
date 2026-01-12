# Hetu Script 0.4.2+1 API Analysis

## Summary

This document identifies the correct API methods and types for Hetu Script version 0.4.2+1 based on examination of the package source code.

## Correct API Methods

### Hetu Class Methods:

1. **`hetu.init()`** - **REQUIRED**: Must be called after creating a `Hetu()` instance and before using any other methods.

2. **`hetu.eval(String script)`** - Evaluates a script string and returns the result.

3. **`hetu.fetch(String varName, {String? moduleName})`** - Gets a top-level variable value from the interpreter.
   - **NOT** `getType()` - this method doesn't exist
   - Returns `dynamic` - can be `HTStruct`, `HTFunction`, or Dart primitive types

4. **`hetu.invoke(String funcName, {List<dynamic> positionalArgs, Map<String, dynamic> namedArgs, List<HTType> typeArgs})`** - Invokes a top-level function.
   - **NOT** `call()` - this method doesn't exist
   - Returns `dynamic`

5. **`hetu.assign(String varName, dynamic value, {String? moduleName})`** - Assigns a value to a top-level variable.

## Correct Types

### Exported Types (from `package:hetu_script/hetu_script.dart`):

- **`HTStruct`** - For struct/object values. This type exists and is correctly exported.
- **`HTEntity`** - Base interface for Hetu entities.
- **`HTFunction`** - For function values.
- **`HTNamespace`** - For namespace values.

### Primitive Types:

Hetu Script returns **Dart native types** for primitive values:
- **`String`** (NOT `HTString` - this type doesn't exist)
- **`int`** (NOT `HTInt` - this type doesn't exist)
- **`double`** (NOT `HTFloat` - this type doesn't exist)
- **`bool`** (NOT `HTBool` - this type doesn't exist)
- **`null`** (NOT `HTNull` - this type doesn't exist, use `HTEntity.nullValue` constant if needed)
- **`List<dynamic>`** (NOT `HTList` - this type doesn't exist)

### HTStruct Value Access:

When accessing values from `HTStruct`:
- Use `struct[key]` or `struct.memberGet(key)` to get values
- Values stored in HTStruct are returned as Dart native types (String, int, double, bool, null, List)
- Only the struct container itself is of type `HTStruct`

## Key Changes Required

### 1. Replace `getType()` with `fetch()`

**Incorrect:**
```dart
final value = interpreter.getType('variableName');
```

**Correct:**
```dart
final value = interpreter.fetch('variableName');
```

### 2. Replace `call()` with `invoke()`

**Incorrect:**
```dart
final result = interpreter.call('functionName', positionalArgs: []);
```

**Correct:**
```dart
final result = interpreter.invoke('functionName', positionalArgs: []);
```

### 3. Remove Non-Existent Type Checks

**Incorrect:**
```dart
if (value is HTString) { ... }
if (value is HTInt) { ... }
if (value is HTFloat) { ... }
if (value is HTBool) { ... }
if (value is HTNull) { ... }
if (value is HTList) { ... }
```

**Correct:**
```dart
if (value is String) { ... }
if (value is int) { ... }
if (value is double) { ... }
if (value is bool) { ... }
if (value == null) { ... }
if (value is List) { ... }
```

### 4. Keep HTStruct Type Checks

**Correct:**
```dart
if (value is HTStruct) {
  final name = value['name']; // Returns String (Dart type)
  final numValue = value['value']; // Returns int (Dart type)
}
```

### 5. Ensure `init()` is Called

**Required:**
```dart
final hetu = Hetu();
hetu.init(); // MUST be called before using hetu
```

## Example Correct Usage

```dart
import 'package:hetu_script/hetu_script.dart';

void main() {
  // Create and initialize Hetu
  final hetu = Hetu();
  hetu.init(); // REQUIRED
  
  // Evaluate script
  hetu.eval('''
    final myVar = {
      name: "test",
      value: 42,
      active: true
    }
  ''');
  
  // Fetch variable (NOT getType)
  final value = hetu.fetch('myVar');
  if (value is HTStruct) {
    // Access struct members - returns Dart native types
    final name = value['name']; // String
    final numValue = value['value']; // int
    final active = value['active']; // bool
    
    print('Name: $name'); // Name: test
    print('Value: $numValue'); // Value: 42
    print('Active: $active'); // Active: true
  }
  
  // Invoke function (NOT call)
  hetu.eval('fun add(a, b) { return a + b; }');
  final result = hetu.invoke('add', positionalArgs: [5, 3]);
  print('Result: $result'); // Result: 8
}
```

## Files That Need Updates

Based on the analysis, the following files need API updates:

1. **Parser files:**
   - `lib/vlinder/parser/ui_parser.dart` - Replace `getType()` with `fetch()`
   - `lib/vlinder/schema/schema_loader.dart` - Replace `getType()` with `fetch()`
   - `lib/vlinder/workflow/workflow_parser.dart` - Replace `getType()` with `fetch()`
   - `lib/vlinder/rules/rules_parser.dart` - Replace `getType()` with `fetch()`

2. **Runtime files:**
   - `lib/vlinder/runtime/vlinder_runtime.dart` - Replace `getType()` with `fetch()`
   - `lib/vlinder/runtime/action_handler.dart` - Replace `call()` with `invoke()`
   - `lib/vlinder/rules/rules_engine.dart` - Replace `getType()` with `fetch()`

3. **Core files:**
   - `lib/vlinder/core/widget_registry.dart` - Fix type checks (remove HTString, HTInt, etc., use Dart types)

4. **All files using Hetu:**
   - Ensure `hetu.init()` is called after creating Hetu instances

## Verification

To verify the API:
1. Check package source: `~/.pub-cache/hosted/pub.dev/hetu_script-0.4.2+1/lib/`
2. Main exports: `lib/hetu_script.dart`
3. Hetu class: `lib/hetu/hetu.dart`
4. Interpreter: `lib/interpreter/interpreter.dart`
5. Value types: `lib/value/struct/struct.dart`





