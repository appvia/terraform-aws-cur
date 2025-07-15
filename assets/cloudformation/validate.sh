#!/bin/bash

# CloudFormation Template Validation Script
# This script validates the CUR CloudFormation template for syntax and common issues

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/cur-template.yaml"
REGION="us-east-1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Validate AWS CUR CloudFormation template

OPTIONS:
    -r, --region REGION             AWS region (default: us-east-1)
    -v, --verbose                   Verbose output
    -h, --help                      Show this help message

EXAMPLES:
    # Basic validation
    $0

    # Verbose validation
    $0 --verbose

    # Validate in specific region
    $0 --region us-west-2

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
    print_info "Validating prerequisites..."

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi

    # Check if template file exists
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        print_error "CloudFormation template not found: $TEMPLATE_FILE"
        exit 1
    fi

    print_success "Prerequisites validated"
}

# Function to validate YAML syntax
validate_yaml_syntax() {
    print_info "Validating YAML syntax..."
    
    # Check if yq is available for YAML validation
    if command -v yq &> /dev/null; then
        if yq eval '.' "$TEMPLATE_FILE" > /dev/null 2>&1; then
            print_success "YAML syntax is valid"
        else
            print_error "YAML syntax validation failed"
            exit 1
        fi
    else
        print_warning "yq not found, skipping YAML syntax validation"
        print_info "Install yq for YAML syntax validation: https://github.com/mikefarah/yq"
    fi
}

# Function to validate CloudFormation template
validate_cloudformation() {
    print_info "Validating CloudFormation template..."
    
    # Try to validate without AWS credentials first (offline validation)
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "Template validation output:"
        aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION"
    else
        if aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION" &> /dev/null; then
            print_success "CloudFormation template validation passed"
        else
            print_error "CloudFormation template validation failed"
            print_info "Running validation with verbose output..."
            aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION"
            exit 1
        fi
    fi
}

# Function to perform basic template checks
check_template_structure() {
    print_info "Performing basic template structure checks..."
    
    local checks_passed=0
    local total_checks=5
    
    # Check 1: Template has required sections
    if grep -q "AWSTemplateFormatVersion" "$TEMPLATE_FILE"; then
        print_success "✓ AWSTemplateFormatVersion is present"
        ((checks_passed++))
    else
        print_warning "✗ AWSTemplateFormatVersion is missing"
    fi
    
    # Check 2: Template has Parameters section
    if grep -q "Parameters:" "$TEMPLATE_FILE"; then
        print_success "✓ Parameters section is present"
        ((checks_passed++))
    else
        print_warning "✗ Parameters section is missing"
    fi
    
    # Check 3: Template has Resources section
    if grep -q "Resources:" "$TEMPLATE_FILE"; then
        print_success "✓ Resources section is present"
        ((checks_passed++))
    else
        print_error "✗ Resources section is missing"
    fi
    
    # Check 4: Template has Outputs section
    if grep -q "Outputs:" "$TEMPLATE_FILE"; then
        print_success "✓ Outputs section is present"
        ((checks_passed++))
    else
        print_warning "✗ Outputs section is missing"
    fi
    
    # Check 5: Template has Conditions section
    if grep -q "Conditions:" "$TEMPLATE_FILE"; then
        print_success "✓ Conditions section is present"
        ((checks_passed++))
    else
        print_warning "✗ Conditions section is missing"
    fi
    
    print_info "Basic structure checks: $checks_passed/$total_checks passed"
}

# Function to check for common issues
check_common_issues() {
    print_info "Checking for common CloudFormation issues..."
    
    local issues_found=0
    
    # Check for long logical names (>255 characters)
    if grep -E '^  [A-Za-z0-9]{255,}:' "$TEMPLATE_FILE" > /dev/null; then
        print_warning "Found potentially long logical resource names (>255 characters)"
        ((issues_found++))
    fi
    
    # Check for potential circular dependencies in conditions
    # Look for condition definitions that use !Condition to reference other conditions
    # This is more accurate than the original broad regex
    if grep -q "^Conditions:" "$TEMPLATE_FILE"; then
        # Look for conditions that use !Condition within the Conditions section
        local conditions_section
        conditions_section=$(sed -n '/^Conditions:/,/^Resources:/p' "$TEMPLATE_FILE" | grep -v "^Resources:")
        
        if echo "$conditions_section" | grep -q "!Condition"; then
            print_warning "Potential circular condition dependencies detected"
            ((issues_found++))
        fi
    fi
    
    # Check for hardcoded account IDs or regions (except in comments)
    if grep -v '^[[:space:]]*#' "$TEMPLATE_FILE" | grep -E '[0-9]{12}' > /dev/null; then
        if ! grep -v '^[[:space:]]*#' "$TEMPLATE_FILE" | grep -E '\$\{AWS::AccountId\}' > /dev/null; then
            print_warning "Potential hardcoded account ID found (use AWS::AccountId instead)"
            ((issues_found++))
        fi
    fi
    
    if [[ $issues_found -eq 0 ]]; then
        print_success "No common issues detected"
    else
        print_warning "$issues_found potential issues found"
    fi
}

# Function to estimate template size
check_template_size() {
    print_info "Checking template size..."
    
    local size
    size=$(wc -c < "$TEMPLATE_FILE")
    local size_kb=$((size / 1024))
    
    if [[ $size -gt 460800 ]]; then  # 450KB (CloudFormation limit is 460KB)
        print_warning "Template size ($size_kb KB) is approaching CloudFormation limit (450KB)"
    elif [[ $size -gt 51200 ]]; then  # 50KB
        print_info "Template size: $size_kb KB (consider using nested stacks for large templates)"
    else
        print_success "Template size: $size_kb KB (within reasonable limits)"
    fi
}

# Main function
main() {
    # Default values
    REGION="us-east-1"
    VERBOSE="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_info "Starting CloudFormation template validation..."
    print_info "Template: $TEMPLATE_FILE"
    print_info "Region: $REGION"
    echo
    
    # Run all validation checks
    validate_prerequisites
    validate_yaml_syntax
    check_template_structure
    check_template_size
    check_common_issues
    validate_cloudformation
    
    echo
    print_success "Template validation completed successfully!"
    print_info "The template is ready for deployment."
}

# Run main function
main "$@" 