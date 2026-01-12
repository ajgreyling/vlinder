# Hetu Script Cheat Sheet

A quick reference guide for Hetu Script syntax and features used in Vlinder.

## Table of Contents
- [Ternary Expressions](#ternary-expressions)
- [Type System](#type-system)
- [Null Safety Operators](#null-safety-operators)
- [Operators](#operators)
- [Control Flow](#control-flow)
- [Functions](#functions)
- [Data Structures](#data-structures)
- [Spread Syntax](#spread-syntax)
- [Type Checking](#type-checking)
- [Common Patterns](#common-patterns)

---

## Ternary Expressions

**YES, ternary expressions are fully supported in Hetu Script!**

### Basic Syntax
```hetu
condition ? true_value : false_value
```

### Examples

**Basic ternary:**
```hetu
final result = true ? "yes" : "no"  // Returns "yes"
final result = false ? "yes" : "no" // Returns "no"
```

**Type checking with ternary:**
```hetu
final ageValue = age is num ? age : null
final ageValue = age is num ? age : (age is str ? int.tryParse(age) : null)
```

**Nested ternary:**
```hetu
final result = 5 > 3 ? (2 > 1 ? "both true" : "first true") : "first false"
// Returns "both true"
```

**With logical operators:**
```hetu
final result = (5 > 3 && 2 < 4) ? "both conditions met" : "condition failed"
// Returns "both conditions met"
```

**Precedence example:**
```hetu
final result = 5 > 3 ? 10 + 2 : 5 + 1
// Evaluates as: (5 > 3) ? (10 + 2) : (5 + 1)
// Returns 12
```

### Precedence
- Ternary operator has **precedence 3** (right-associative)
- Lower precedence than comparison operators (`>`, `<`, `==`, etc.)
- Higher precedence than assignment operators (`=`, `+=`, etc.)

---

## Type System

### Hetu Types (in `.ht` files)
**CRITICAL**: Use Hetu types, NOT Dart types in Hetu scripts!

```hetu
// CORRECT - Hetu script types
final ageValue = age is num ? age : null
final name = value is str ? value : "default"
final isValid = value is bool ? value : false

// INCORRECT - Dart types don't work in Hetu scripts
final ageValue = age is int ? age : null        // WRONG
final name = value is String ? value : "default" // WRONG
```

### Type Keywords
- `num` - Numbers (both int and float)
- `str` - Strings
- `bool` - Booleans
- `List` - Lists/Arrays
- `null` - Null value

### Type Checking
```hetu
if (value is num) { ... }
if (value is str) { ... }
if (value is bool) { ... }
if (value is List) { ... }
if (value == null) { ... }
if (value is! num) { ... }  // Type negation
```

---

## Null Safety Operators

### Null Coalescing (`??`)
```hetu
final value = maybeNull ?? "default"
final formValues = actionContext.formValues ?? {}
final isValid = actionContext.isValid ?? false
```

### Null Coalescing Assignment (`??=`)
```hetu
var a = null
a ??= "assigned"  // a is now "assigned"

var b = "existing"
b ??= "not assigned"  // b remains "existing"
```

### Nullable Member Access (`?.`)
```hetu
var obj = null
final value = obj?.property  // Returns null, no error

var obj = { property: "value" }
final value = obj?.property  // Returns "value"
```

### Nullable Method Call (`?.()`)
```hetu
var obj = null
obj?.someMethod()  // Returns null, no error
```

### Nullable Chain
```hetu
var obj = null
final value = obj?.prop1?.prop2?.method()  // Returns null safely
```

---

## Operators

### Arithmetic Operators
```hetu
5 + 3   // Addition: 8
10 - 4  // Subtraction: 6
6 * 7   // Multiplication: 42
15 / 3  // Division: 5.0
17 % 5  // Modulo: 2
17 ~/ 5 // Integer division: 3
```

### Comparison Operators
```hetu
5 > 3   // Greater than: true
5 < 3   // Less than: false
5 >= 5  // Greater than or equal: true
5 <= 3  // Less than or equal: false
5 == 5  // Equality: true
5 != 3  // Inequality: true
```

### Logical Operators
```hetu
true && false  // Logical AND: false
true || false  // Logical OR: true
!true          // Logical NOT: false
```

### Assignment Operators
```hetu
var a = 10
a += 5   // a is now 15
a -= 3   // a is now 12
a *= 2   // a is now 24
a /= 4   // a is now 6
a ~/= 2  // a is now 3
```

### Increment/Decrement
```hetu
var a = 5
++a     // Pre-increment: a is 6
a++     // Post-increment: a is 6, then becomes 7
--a     // Pre-decrement: a is 6
a--     // Post-decrement: a is 6, then becomes 5
```

### Operator Precedence (highest to lowest)
1. Unary postfix: `e.`, `e?.`, `e++`, `e--`, `e1[e2]`, `e()`
2. Unary prefix: `-e`, `!e`, `++e`, `--e`, `await e`
3. Multiplicative: `*`, `/`, `~/`, `%`
4. Additive: `+`, `-`
5. Shift: `<<`, `>>`, `>>>`
6. Bitwise AND: `&`
7. Bitwise XOR: `^`
8. Bitwise OR: `|`
9. Relational: `<`, `>`, `<=`, `>=`, `as`, `is`, `is!`, `in`, `in!`
10. Equality: `==`, `!=`
11. Logical AND: `&&`
12. Logical OR: `||`
13. If null: `??`
14. **Ternary: `? :`** (right-associative)
15. Assignment: `=`, `*=`, `/=`, `~/=`, `+=`, `-=`, `??=`
16. Spread: `...`

---

## Control Flow

### If Statements
```hetu
if (condition) {
  // code
} else if (otherCondition) {
  // code
} else {
  // code
}
```

### While Loops
```hetu
var i = 0
while (i < 10) {
  print(i)
  i++
}
```

### For Loops
```hetu
for (var i = 0; i < 10; i++) {
  print(i)
}

// For range
for (final item in list) {
  print(item)
}
```

### Return Statements
```hetu
fun myFunction() {
  if (error) {
    return  // Early return
  }
  return result
}
```

---

## Functions

### Function Definition
```hetu
// Named parameters (REQUIRED for widget constructors)
fun Screen({id, title, children}) {
  return {
    widgetType: 'Screen',
    id: id,
    title: title,
    children: children ?? [],
  }
}

// Action functions (NO parameters - actionContext injected automatically)
fun submit_customer() {
  final formValues = actionContext.formValues ?? {}
  final isValid = actionContext.isValid ?? false
  // ... use formValues and isValid
}
```

### Function Call
```hetu
// Named arguments
Screen(id: 'x', title: 'y', children: [...])

// Positional arguments
myFunction(1, 2, 3)
```

---

## Data Structures

### Structs (Objects)
```hetu
var person = {
  name: "John",
  age: 30,
  active: true
}

// Access properties
final name = person.name
final age = person['age']

// Set properties
person.name = "Jane"
person['age'] = 31
```

### Lists (Arrays)
```hetu
var list = [1, 2, 3, 4, 5]

// Access elements
final first = list[0]

// Modify elements
list[0] = 10

// Iterate
for (final item in list) {
  print(item)
}
```

### Maps
```hetu
var map = {
  'key1': 'value1',
  'key2': 'value2'
}

// Access
final value = map['key1']

// Set
map['key3'] = 'value3'
```

---

## Spread Syntax

### Object Merging
```hetu
var obj1 = { a: 1, b: 2 }
var obj2 = { ...obj1, c: 3 }
// obj2 is { a: 1, b: 2, c: 3 }

// Merge multiple objects
var rules = {
  ...validationRules,
  ...businessRules,
}
```

### List Spreading
```hetu
var list1 = [1, 2, 3]
var list2 = [0, ...list1, 4]
// list2 is [0, 1, 2, 3, 4]
```

### Function Arguments
```hetu
fun myFunc(a, b, c) {
  return a + b + c
}

var args = [1, 2, 3]
myFunc(...args)  // Same as myFunc(1, 2, 3)
```

---

## Type Checking

### Type Tests
```hetu
if (value is num) { ... }
if (value is str) { ... }
if (value is bool) { ... }
if (value is List) { ... }
if (value is! num) { ... }  // Type negation
```

### Type Conversion
```hetu
// String to number
final num = int.tryParse(strValue)
final num = num.tryParse(strValue)

// Number to string
final str = num.toString()

// Boolean conversion
final boolValue = value is bool ? value : (value.toString().toLowerCase() == 'true')
```

---

## Common Patterns

### Form Value Access
```hetu
fun myAction() {
  // Access form values from actionContext (injected automatically)
  final formValues = actionContext.formValues ?? {}
  final isValid = actionContext.isValid ?? false
  
  // Access specific fields
  final firstName = formValues['firstName']
  final age = formValues['age']
  
  // Type checking with ternary
  final ageValue = age is num ? age : null
}
```

### Database Operations
```hetu
// Save operation (queued, returns operation ID)
final saveOpId = save('EntityName', formValues)

// Query operations (queued, returns operation ID)
final queryOpId = findAll('EntityName', {}, 'id DESC', 1)
final findOpId = findById('EntityName', id)

// Get results (after operation completes)
final result = getDbResult(queryOpId)
```

### Navigation
```hetu
// Navigate to screen by ID
navigate("screen_id")

// Screen IDs must match the 'id' field in UI YAML
```

### Logging
```hetu
log("General log message")
logInfo("Info message")
logWarning("Warning message")
logError("Error message")
```

### Conditional Field Visibility
```hetu
// In UI YAML - visibility expressions have access to form values
visible: "age > 16 && gender == 'Female'"
visible: "age is num && age > 50"
```

### Multi-Step Form Pattern
```hetu
// Start new form - clear accumulated values
fun start_registration() {
  _patientFormValues = {}
  navigate("first_screen")
}

// Next step - values automatically accumulated
fun next_step() {
  if (!actionContext.isValid) {
    logError("Validation failed")
    return
  }
  navigate("next_screen")
}

// Submit - all accumulated values available
fun submit() {
  final formValues = actionContext.formValues ?? {}
  // formValues contains all values from all screens
  save('Entity', formValues)
}
```

---

## Quick Reference

### Variable Declaration
```hetu
var mutable = 10
final immutable = 20
```

### String Interpolation
```hetu
final name = "John"
final message = "Hello, ${name}!"
final result = "Value: ${value.toString()}"
```

### Comments
```hetu
// Single line comment

/*
  Multi-line comment
*/
```

### Common Gotchas

1. **Use Hetu types in `.ht` files**: `num`, `str`, `bool` - NOT `int`, `String`, `bool`
2. **Widget constructors need named parameters**: `fun Widget({param1, param2})`
3. **Action functions have NO parameters**: `actionContext` is injected automatically
4. **Use spread syntax for merging**: `{...obj1, ...obj2}` - NOT `Object.assign()`
5. **Database operations are async**: Use `getDbResult(opId)` after operation completes
6. **Screen IDs must match**: `navigate("id")` must match `id` field in UI YAML

---

## Resources

- Hetu Script Documentation: See `hetu-script/docs/`
- Vlinder Rules: See `.cursorrules` for detailed API usage
- Sample Code: See `sample_app/assets/actions.ht` for real-world examples
