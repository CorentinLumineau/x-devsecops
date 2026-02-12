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

# Check 1: .claude/rules/ directory exists with rule files
echo "Checking .claude/rules/..."
if [[ -d "$REPO_ROOT/.claude/rules" ]]; then
    rule_count=$(find "$REPO_ROOT/.claude/rules" -name '*.md' | wc -l)
    if [[ "$rule_count" -gt 0 ]]; then
        log_success ".claude/rules/ exists with $rule_count rule file(s)"
    else
        log_error ".claude/rules/ exists but contains no .md files"
    fi
else
    log_error ".claude/rules/ directory is missing"
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
if grep -rE "(ccsetup|x-workflows)" "$REPO_ROOT/skills" 2>/dev/null | grep -v "^Binary" | grep -v "author: ccsetup contributors"; then
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

# Check 6: Frontmatter contract for knowledge skills
echo ""
echo "Checking frontmatter contract for knowledge skills..."
for category_dir in "$REPO_ROOT/skills"/*/; do
    if [[ -d "$category_dir" ]]; then
        category_name=$(basename "$category_dir")
        for skill_dir in "$category_dir"*/; do
            if [[ -d "$skill_dir" ]]; then
                skill_name=$(basename "$skill_dir")
                skill_file="${skill_dir}SKILL.md"

                if [[ ! -f "$skill_file" ]]; then
                    continue  # Already caught by Check 2
                fi

                # Extract frontmatter (content between first two --- lines)
                frontmatter=$(sed -n '/^---$/,/^---$/p' "$skill_file" | sed '1d;$d')

                if [[ -z "$frontmatter" ]]; then
                    log_error "skills/$category_name/$skill_name/SKILL.md has no YAML frontmatter"
                    continue
                fi

                # Check: name matches directory name (NOT category-prefixed)
                fm_name=$(echo "$frontmatter" | grep -E '^name:' | head -1 | sed 's/^name:[[:space:]]*//')
                if [[ "$fm_name" == "$skill_name" ]]; then
                    log_success "skills/$category_name/$skill_name frontmatter name matches directory"
                else
                    log_error "skills/$category_name/$skill_name frontmatter name '$fm_name' does not match directory name '$skill_name'"
                fi

                # Check: category in frontmatter matches parent directory
                fm_category=$(echo "$frontmatter" | grep -E '^[[:space:]]*category:' | head -1 | sed 's/^[[:space:]]*category:[[:space:]]*//')
                if [[ "$fm_category" == "$category_name" ]]; then
                    log_success "skills/$category_name/$skill_name frontmatter category matches directory"
                else
                    log_error "skills/$category_name/$skill_name frontmatter category '$fm_category' does not match directory '$category_name'"
                fi

                # Check: description exists and is single-line
                fm_desc_line=$(echo "$frontmatter" | grep -E '^description:' | head -1)
                if [[ -n "$fm_desc_line" ]]; then
                    fm_desc_value=$(echo "$fm_desc_line" | sed 's/^description:[[:space:]]*//')
                    if [[ "$fm_desc_value" == "|" || "$fm_desc_value" == ">" || "$fm_desc_value" == "|+" || "$fm_desc_value" == ">-" ]]; then
                        log_error "skills/$category_name/$skill_name description must be single-line"
                    else
                        log_success "skills/$category_name/$skill_name has single-line description"
                    fi

                    # Check: Description length (budget optimization)
                    desc_len=${#fm_desc_value}
                    if [[ $desc_len -gt 120 ]]; then
                        log_warning "skills/$category_name/$skill_name description is $desc_len chars (recommended: ≤120)"
                    fi

                    # Check: Description is YAML-safe (no unquoted colon-space that breaks parsing)
                    if echo "$fm_desc_value" | grep -qE ': [a-z]' && ! echo "$fm_desc_line" | grep -qE '^description: ["\x27]'; then
                        log_warning "skills/$category_name/$skill_name description contains ': ' — should be quoted to avoid YAML parse errors"
                    fi
                else
                    log_error "skills/$category_name/$skill_name is missing description field"
                fi

                # Check: name does NOT start with x-
                if [[ "$fm_name" == x-* ]]; then
                    log_error "skills/$category_name/$skill_name name '$fm_name' must NOT start with x- (knowledge skills)"
                fi

                # Check: allowed-tools is read-only (warn on Write/Edit)
                fm_tools=$(echo "$frontmatter" | grep -E '^allowed-tools:' | head -1 | sed 's/^allowed-tools:[[:space:]]*//')
                if [[ -n "$fm_tools" ]]; then
                    if echo "$fm_tools" | grep -qE '(Write|Edit)'; then
                        log_warning "skills/$category_name/$skill_name has write tools in allowed-tools (knowledge skills should be read-only)"
                    fi
                fi

                # Check: license is Apache-2.0
                fm_license=$(echo "$frontmatter" | grep -E '^license:' | head -1 | sed 's/^license:[[:space:]]*//')
                if [[ "$fm_license" == "Apache-2.0" ]]; then
                    log_success "skills/$category_name/$skill_name has license: Apache-2.0"
                else
                    log_error "skills/$category_name/$skill_name missing or incorrect license (expected 'Apache-2.0', got '$fm_license')"
                fi
            fi
        done
    fi
done

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
