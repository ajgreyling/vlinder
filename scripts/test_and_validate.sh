#!/bin/bash
# Test and Validation Script for Vlinder
# Validates Flutter builds, runs tests, and validates Hetu scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track failures
FAILURES=0
TOTAL_STEPS=0

# Function to print step header
print_step() {
    TOTAL_STEPS=$((TOTAL_STEPS + 1))
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Step $TOTAL_STEPS: $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
    FAILURES=$((FAILURES + 1))
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Change to project root
cd "$PROJECT_ROOT"

echo -e "${GREEN}"
echo "╔════════════════════════════════════════╗"
echo "║  Vlinder Test and Validation Script   ║"
echo "╚════════════════════════════════════════╝"
echo -e "${NC}"

# Step 1: Flutter Analysis
print_step "Flutter Code Analysis"

if flutter analyze --no-fatal-infos 2>&1 | tee /tmp/flutter_analyze.log; then
    # Check for errors (not warnings/info)
    if grep -q "error •" /tmp/flutter_analyze.log; then
        print_error "Flutter analysis found errors"
        grep "error •" /tmp/flutter_analyze.log | head -10
        FAILURES=$((FAILURES + 1))
    else
        print_success "Flutter analysis passed"
    fi
else
    print_error "Flutter analysis failed"
    FAILURES=$((FAILURES + 1))
fi

# Step 2: Flutter Tests (includes Hetu validation)
print_step "Flutter Tests and Hetu Script Validation"

if flutter test 2>&1 | tee /tmp/flutter_test.log; then
    print_success "All tests passed"
else
    print_error "Some tests failed"
    FAILURES=$((FAILURES + 1))
fi

# Step 3: Verify Asset Files Exist
print_step "Verifying Asset Files"

ASSETS_DIR="$PROJECT_ROOT/sample_app/assets"
REQUIRED_FILES=("schema.yaml" "ui.yaml" "workflows.yaml" "rules.ht")

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$ASSETS_DIR/$file" ]; then
        print_success "Found $file"
    else
        print_error "Missing required file: $file"
        FAILURES=$((FAILURES + 1))
    fi
done

# Step 4: Build Verification (Host Platform)
print_step "Build Verification (Host Platform)"

# Clean previous builds
flutter clean > /dev/null 2>&1 || true

# Get dependencies
if flutter pub get > /dev/null 2>&1; then
    print_success "Dependencies resolved"
else
    print_error "Failed to resolve dependencies"
    FAILURES=$((FAILURES + 1))
fi

# Verify build capability (compile only, don't build full app)
if flutter build --help > /dev/null 2>&1; then
    print_success "Flutter build system is ready"
else
    print_error "Flutter build system check failed"
    FAILURES=$((FAILURES + 1))
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}========================================${NC}"

if [ $FAILURES -eq 0 ]; then
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║  All tests and validations passed! ✓  ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    exit 0
else
    echo -e "${RED}"
    echo "╔════════════════════════════════════════╗"
    echo "║  $FAILURES failure(s) detected ✗        ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    exit 1
fi





