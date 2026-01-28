#!/usr/bin/env bash
# validate-rules.sh - Validates x-devsecops repository structure and rules compliance
# Usage: ./scripts/validate-rules.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

errors=0
warnings=0

log_error() {
    echo -e "${RED}ERROR:${NC} $1"
    ((errors++))
}

log_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
    ((warnings++))
}

log_success() {
    echo -e "${GREEN}OK:${NC} $1"
}

echo "=========================================="
echo "x-devsecops Repository Validation"
echo "=========================================="
echo ""

# Check 1: .claude/rules.md exists
echo "Checking .claude/rules.md..."
if [[ -f "$REPO_ROOT/.claude/rules.md" ]]; then
    log_success ".claude/rules.md exists"
else
    log_error ".claude/rules.md is missing"
fi

# Check 2: Valid category structure
echo ""
echo "Checking category structure..."
valid_categories=("security" "quality" "code" "delivery" "operations" "meta" "data")

if [[ -d "$REPO_ROOT/skills" ]]; then
    for category_dir in "$REPO_ROOT/skills"/*/; do
        if [[ -d "$category_dir" ]]; then
            category_name=$(basename "$category_dir")
            if [[ " ${valid_categories[*]} " =~ " ${category_name} " ]]; then
                log_success "skills/$category_name is a valid category"
            else
                log_warning "skills/$category_name is not a standard category"
            fi

            # Check skills within category
            for skill_dir in "$category_dir"*/; do
                if [[ -d "$skill_dir" ]]; then
                    skill_name=$(basename "$skill_dir")
                    if [[ -f "${skill_dir}SKILL.md" ]]; then
                        log_success "skills/$category_name/$skill_name has SKILL.md"
                    else
                        log_error "skills/$category_name/$skill_name is missing SKILL.md"
                    fi
                fi
            done
        fi
    done
else
    log_warning "skills/ directory not found"
fi

# Check 3: No forbidden dependencies
echo ""
echo "Checking for forbidden dependencies..."
if grep -rE "(ccsetup|x-workflows)" "$REPO_ROOT/skills" 2>/dev/null | grep -v "^Binary"; then
    log_error "Found references to ccsetup or x-workflows (forbidden dependency)"
else
    log_success "No ccsetup/x-workflows dependencies found"
fi

# Check 4: Security content has no real credentials
echo ""
echo "Checking for potential credential leaks..."
if [[ -d "$REPO_ROOT/skills/security" ]]; then
    # Look for potential API keys (long alphanumeric strings)
    if grep -rE '[A-Za-z0-9]{32,}' "$REPO_ROOT/skills/security" 2>/dev/null | grep -v "placeholder\|example\|<.*>\|\${\|your-" | head -5; then
        log_warning "Potential credentials found in security skills (review manually)"
    else
        log_success "No obvious credential patterns found"
    fi
fi

# Check 5: No execution steps (HOW) in knowledge skills
echo ""
echo "Checking for execution steps in knowledge skills..."
# Look for step-by-step patterns that indicate execution logic
step_patterns="Step [0-9]|Phase [0-9]|First,.*Then,|1\.|2\.|3\."
if grep -rE "$step_patterns" "$REPO_ROOT/skills" 2>/dev/null | grep -v "references\|examples" | head -3; then
    log_warning "Possible execution steps found (should be in x-workflows)"
else
    log_success "No obvious execution patterns found"
fi

# Summary
echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "Errors:   ${RED}$errors${NC}"
echo -e "Warnings: ${YELLOW}$warnings${NC}"
echo ""

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}Validation FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}Validation PASSED${NC}"
    exit 0
fi
