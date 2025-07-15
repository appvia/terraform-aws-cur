#!/bin/bash

# CI CloudFormation Template Validation Script
# This script validates the CUR CloudFormation template in CI/CD environments

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/cur-template.yaml"
REGION="us-east-1"
EXIT_CODE=0

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

Validate AWS CUR CloudFormation template for CI/CD pipelines

OPTIONS:
    -r, --region REGION             AWS region (default: us-east-1)
    -t, --template FILE             Path to CloudFormation template (default: cur-template.yaml)
    -v, --verbose                   Verbose output
    -h, --help                      Show this help message
    --fail-on-warnings              Fail if warnings are found
    --skip-aws-validation           Skip AWS CloudFormation validation (useful for offline CI)

EXAMPLES:
    # Basic validation
    $0

    # Verbose validation with fail on warnings
    $0 --verbose --fail-on-warnings

    # Validate specific template in different region
    $0 --template /path/to/template.yaml --region us-west-2

    # Skip AWS validation (offline mode)
    $0 --skip-aws-validation

EOF
}

# Function to validate prerequisites
validate_prerequisites() {
    print_info "Validating prerequisites..."

    # Check if template file exists
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        print_error "CloudFormation template not found: $TEMPLATE_FILE"
        exit 1
    fi

    # Check if AWS CLI is installed (only if not skipping AWS validation)
    if [[ "$SKIP_AWS_VALIDATION" != "true" ]]; then
        if ! command -v aws &> /dev/null; then
            print_error "AWS CLI is not installed. Please install it first or use --skip-aws-validation"
            exit 1
        fi
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
            EXIT_CODE=1
            return 1
        fi
    elif command -v python3 &> /dev/null; then
        # Fallback to Python yaml module
        if python3 -c "import yaml; yaml.safe_load(open('$TEMPLATE_FILE'))" 2>/dev/null; then
            print_success "YAML syntax is valid (validated with Python)"
        else
            print_error "YAML syntax validation failed"
            EXIT_CODE=1
            return 1
        fi
    else
        print_warning "Neither yq nor python3 found, skipping YAML syntax validation"
        if [[ "$FAIL_ON_WARNINGS" == "true" ]]; then
            EXIT_CODE=1
        fi
    fi
}

# Function to validate CloudFormation template
validate_cloudformation() {
    if [[ "$SKIP_AWS_VALIDATION" == "true" ]]; then
        print_info "Skipping AWS CloudFormation validation (--skip-aws-validation flag set)"
        return 0
    fi

    print_info "Validating CloudFormation template with AWS..."
    
    # Check if AWS credentials are available
    if ! aws sts get-caller-identity &> /dev/null; then
        print_warning "AWS credentials not available, skipping CloudFormation validation"
        if [[ "$FAIL_ON_WARNINGS" == "true" ]]; then
            EXIT_CODE=1
        fi
        return 0
    fi
    
    # Validate template
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "Template validation output:"
        if aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION"; then
            print_success "CloudFormation template validation passed"
        else
            print_error "CloudFormation template validation failed"
            EXIT_CODE=1
        fi
    else
        if aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION" &> /dev/null; then
            print_success "CloudFormation template validation passed"
        else
            print_error "CloudFormation template validation failed"
            print_info "Running validation with verbose output..."
            aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION"
            EXIT_CODE=1
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
        print_error "✗ AWSTemplateFormatVersion is missing"
        EXIT_CODE=1
    fi
    
    # Check 2: Template has Parameters section
    if grep -q "Parameters:" "$TEMPLATE_FILE"; then
        print_success "✓ Parameters section is present"
        ((checks_passed++))
    else
        print_warning "✗ Parameters section is missing"
        if [[ "$FAIL_ON_WARNINGS" == "true" ]]; then
            EXIT_CODE=1
        fi
    fi
    
    # Check 3: Template has Resources section
    if grep -q "Resources:" "$TEMPLATE_FILE"; then
        print_success "✓ Resources section is present"
        ((checks_passed++))
    else
        print_error "✗ Resources section is missing"
        EXIT_CODE=1
    fi
    
    # Check 4: Template has Outputs section
    if grep -q "Outputs:" "$TEMPLATE_FILE"; then
        print_success "✓ Outputs section is present"
        ((checks_passed++))
    else
        print_warning "✗ Outputs section is missing"
        if [[ "$FAIL_ON_WARNINGS" == "true" ]]; then
            EXIT_CODE=1
        fi
    fi
    
    # Check 5: Template has Conditions section
    if grep -q "Conditions:" "$TEMPLATE_FILE"; then
        print_success "✓ Conditions section is present"
        ((checks_passed++))
    else
        print_warning "✗ Conditions section is missing"
        if [[ "$FAIL_ON_WARNINGS" == "true" ]]; then
            EXIT_CODE=1
        fi
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
    
    # Check for hardcoded account IDs or regions (except in comments)
    if grep -v '^[[:space:]]*#' "$TEMPLATE_FILE" | grep -E '[0-9]{12}' > /dev/null; then
        if ! grep -v '^[[:space:]]*#' "$TEMPLATE_FILE" | grep -E '\$\{AWS::AccountId\}' > /dev/null; then
            print_warning "Potential hardcoded account ID found (use AWS::AccountId instead)"
            ((issues_found++))
        fi
    fi
    
    # Check for hardcoded regions (except in specific contexts)
    if grep -v '^[[:space:]]*#' "$TEMPLATE_FILE" | grep -E 'us-east-1|us-west-2|eu-west-1' > /dev/null; then
        if ! grep -v '^[[:space:]]*#' "$TEMPLATE_FILE" | grep -E '\$\{AWS::Region\}' > /dev/null; then
            print_warning "Potential hardcoded region found (consider using AWS::Region)"
            ((issues_found++))
        fi
    fi
    
    # Check for missing Description in template
    if ! grep -q "Description:" "$TEMPLATE_FILE"; then
        print_warning "Template description is missing"
        ((issues_found++))
    fi
    
    # Check for resources without explicit DependsOn when needed
    if grep -q "DependsOn:" "$TEMPLATE_FILE"; then
        print_success "✓ DependsOn relationships are explicitly defined"
    else
        print_info "Consider adding explicit DependsOn relationships for complex dependencies"
    fi
    
    if [[ $issues_found -eq 0 ]]; then
        print_success "No common issues detected"
    else
        print_warning "$issues_found potential issues found"
        if [[ "$FAIL_ON_WARNINGS" == "true" ]]; then
            EXIT_CODE=1
        fi
    fi
}

# Function to estimate template size
check_template_size() {
    print_info "Checking template size..."
    
    local size
    size=$(wc -c < "$TEMPLATE_FILE")
    local size_kb=$((size / 1024))
    
    if [[ $size -gt 460800 ]]; then  # 450KB (CloudFormation limit is 460KB)
        print_error "Template size ($size_kb KB) exceeds CloudFormation limit (450KB)"
        EXIT_CODE=1
    elif [[ $size -gt 409600 ]]; then  # 400KB
        print_warning "Template size ($size_kb KB) is approaching CloudFormation limit (450KB)"
        if [[ "$FAIL_ON_WARNINGS" == "true" ]]; then
            EXIT_CODE=1
        fi
    elif [[ $size -gt 51200 ]]; then  # 50KB
        print_info "Template size: $size_kb KB (consider using nested stacks for large templates)"
    else
        print_success "Template size: $size_kb KB (within reasonable limits)"
    fi
}

# Function to check for security best practices
check_security_practices() {
    print_info "Checking security best practices..."
    
    local security_issues=0
    
    # Check for hardcoded credentials (basic check)
    if grep -i -E '(password|secret|key|credential).*[=:].*[a-zA-Z0-9]{8,}' "$TEMPLATE_FILE" > /dev/null; then
        print_warning "Potential hardcoded credentials found"
        ((security_issues++))
    fi
    
    # Check for overly permissive IAM policies
    if grep -A 5 -B 5 '"Resource": "\*"' "$TEMPLATE_FILE" > /dev/null; then
        print_warning "IAM policies with wildcard resources found - review for least privilege"
        ((security_issues++))
    fi
    
    # Check for missing encryption configuration
    if grep -q "S3Bucket" "$TEMPLATE_FILE" && ! grep -q "BucketEncryption" "$TEMPLATE_FILE"; then
        print_warning "S3 bucket without encryption configuration found"
        ((security_issues++))
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        print_success "No obvious security issues detected"
    else
        print_warning "$security_issues potential security issues found"
        if [[ "$FAIL_ON_WARNINGS" == "true" ]]; then
            EXIT_CODE=1
        fi
    fi
}

# Function to generate validation report
generate_report() {
    if [[ "$VERBOSE" == "true" ]]; then
        print_info "Generating validation report..."
        
        cat << EOF

=== CloudFormation Template Validation Report ===
Template: $TEMPLATE_FILE
Region: $REGION
Timestamp: $(date)

Template Size: $(wc -c < "$TEMPLATE_FILE") bytes ($(( $(wc -c < "$TEMPLATE_FILE") / 1024 )) KB)
Lines: $(wc -l < "$TEMPLATE_FILE")

Sections Found:
- AWSTemplateFormatVersion: $(grep -q "AWSTemplateFormatVersion" "$TEMPLATE_FILE" && echo "✓" || echo "✗")
- Description: $(grep -q "Description:" "$TEMPLATE_FILE" && echo "✓" || echo "✗")
- Parameters: $(grep -q "Parameters:" "$TEMPLATE_FILE" && echo "✓" || echo "✗")
- Conditions: $(grep -q "Conditions:" "$TEMPLATE_FILE" && echo "✓" || echo "✗")
- Resources: $(grep -q "Resources:" "$TEMPLATE_FILE" && echo "✓" || echo "✗")
- Outputs: $(grep -q "Outputs:" "$TEMPLATE_FILE" && echo "✓" || echo "✗")

Resource Count: $(grep -c "^  [A-Za-z].*:" "$TEMPLATE_FILE" || echo "0")
Parameter Count: $(grep -A 1000 "Parameters:" "$TEMPLATE_FILE" | grep -c "^  [A-Za-z].*:" || echo "0")
Output Count: $(grep -A 1000 "Outputs:" "$TEMPLATE_FILE" | grep -c "^  [A-Za-z].*:" || echo "0")

=== End of Report ===

EOF
    fi
}

# Main function
main() {
    # Default values
    REGION="us-east-1"
    TEMPLATE_FILE="$SCRIPT_DIR/cur-template.yaml"
    VERBOSE="false"
    FAIL_ON_WARNINGS="false"
    SKIP_AWS_VALIDATION="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -t|--template)
                TEMPLATE_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --fail-on-warnings)
                FAIL_ON_WARNINGS="true"
                shift
                ;;
            --skip-aws-validation)
                SKIP_AWS_VALIDATION="true"
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
    
    print_info "Starting CloudFormation template validation for CI/CD..."
    print_info "Template: $TEMPLATE_FILE"
    print_info "Region: $REGION"
    print_info "Fail on warnings: $FAIL_ON_WARNINGS"
    print_info "Skip AWS validation: $SKIP_AWS_VALIDATION"
    echo
    
    # Run all validation checks
    validate_prerequisites
    validate_yaml_syntax
    check_template_structure
    check_template_size
    check_common_issues
    check_security_practices
    validate_cloudformation
    generate_report
    
    echo
    if [[ $EXIT_CODE -eq 0 ]]; then
        print_success "Template validation completed successfully!"
        print_info "The template is ready for deployment."
    else
        print_error "Template validation failed with errors."
        print_info "Please fix the issues above before deploying."
    fi
    
    exit $EXIT_CODE
}

# Run main function
main "$@"