#!/bin/bash

# AWS CUR CloudFormation Deployment Script
# This script deploys the CUR CloudFormation template with proper validation

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/cur-template.yaml"
DEFAULT_REGION="us-east-1"

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

Deploy AWS Cost and Usage Report (CUR) CloudFormation template

OPTIONS:
    -s, --stack-name STACK_NAME     CloudFormation stack name (required)
    -p, --parameters FILE           Parameters file path (JSON format)
    -r, --region REGION             AWS region (default: us-east-1)
    -b, --bucket-name BUCKET        S3 bucket name (required if no parameters file)
    -n, --report-name REPORT        CUR report name (default: cost-and-usage-report)
    --enable-kms                    Enable KMS encryption
    --enable-coh                    Enable Cost Optimization Hub
    --enable-replication            Enable cross-account replication
    --dry-run                       Validate template without deployment
    -h, --help                      Show this help message

EXAMPLES:
    # Deploy with basic configuration
    $0 -s my-cur-stack -b my-company-cur-reports

    # Deploy with parameters file
    $0 -s my-cur-stack -p examples/basic-parameters.json

    # Deploy with advanced features
    $0 -s enterprise-cur --enable-kms --enable-coh -b enterprise-cur-reports

    # Validate template only
    $0 --dry-run -s test-stack -b test-bucket

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

    # Check if AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured. Please run 'aws configure'."
        exit 1
    fi

    # Check if template file exists
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        print_error "CloudFormation template not found: $TEMPLATE_FILE"
        exit 1
    fi

    # Validate region (CUR must be created in us-east-1)
    if [[ "$REGION" != "us-east-1" ]]; then
        print_warning "CUR reports can only be created in us-east-1 region. Switching to us-east-1."
        REGION="us-east-1"
    fi

    print_success "Prerequisites validated"
}

# Function to validate template
validate_template() {
    print_info "Validating CloudFormation template..."
    
    if aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION" &> /dev/null; then
        print_success "Template validation passed"
    else
        print_error "Template validation failed"
        aws cloudformation validate-template --template-body "file://$TEMPLATE_FILE" --region "$REGION"
        exit 1
    fi
}

# Function to check if stack exists
stack_exists() {
    aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &> /dev/null
}

# Function to build parameters array
build_parameters() {
    local params=()
    
    if [[ -n "$PARAMETERS_FILE" ]]; then
        if [[ ! -f "$PARAMETERS_FILE" ]]; then
            print_error "Parameters file not found: $PARAMETERS_FILE"
            exit 1
        fi
        params+=("--parameters" "file://$PARAMETERS_FILE")
    else
        # Build parameters from command line options
        if [[ -n "$BUCKET_NAME" ]]; then
            params+=("--parameters" "ParameterKey=S3BucketName,ParameterValue=$BUCKET_NAME")
        else
            print_error "S3 bucket name is required (use -b or --bucket-name)"
            exit 1
        fi
        
        if [[ -n "$REPORT_NAME" ]]; then
            params+=("ParameterKey=ReportName,ParameterValue=$REPORT_NAME")
        fi
        
        if [[ "$ENABLE_KMS" == "true" ]]; then
            params+=("ParameterKey=EnableKMSEncryption,ParameterValue=true")
        fi
        
        if [[ "$ENABLE_COH" == "true" ]]; then
            params+=("ParameterKey=EnableCostOptimizationHub,ParameterValue=true")
        fi
        
        if [[ "$ENABLE_REPLICATION" == "true" ]]; then
            params+=("ParameterKey=EnableReplication,ParameterValue=true")
        fi
    fi
    
    echo "${params[@]}"
}

# Function to deploy stack
deploy_stack() {
    local operation
    local params
    
    params=($(build_parameters))
    
    if stack_exists; then
        operation="update-stack"
        print_info "Updating existing stack: $STACK_NAME"
    else
        operation="create-stack"
        print_info "Creating new stack: $STACK_NAME"
    fi
    
    print_info "Deploying CloudFormation stack..."
    
    local deploy_cmd=(
        aws cloudformation "$operation"
        --stack-name "$STACK_NAME"
        --template-body "file://$TEMPLATE_FILE"
        --capabilities CAPABILITY_IAM
        --region "$REGION"
    )
    
    if [[ ${#params[@]} -gt 0 ]]; then
        deploy_cmd+=("${params[@]}")
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "DRY RUN: Would execute the following command:"
        echo "${deploy_cmd[@]}"
        return 0
    fi
    
    # Execute deployment
    if "${deploy_cmd[@]}"; then
        print_success "Stack deployment initiated successfully"
        
        # Wait for stack operation to complete
        print_info "Waiting for stack operation to complete..."
        if aws cloudformation wait "stack-${operation%-stack}-complete" --stack-name "$STACK_NAME" --region "$REGION"; then
            print_success "Stack $operation completed successfully"
            
            # Show stack outputs
            print_info "Stack outputs:"
            aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" \
                --query 'Stacks[0].Outputs[?OutputKey].{Key:OutputKey,Value:OutputValue}' \
                --output table
        else
            print_error "Stack $operation failed or timed out"
            print_info "Check CloudFormation console for details"
            exit 1
        fi
    else
        print_error "Failed to initiate stack deployment"
        exit 1
    fi
}

# Main function
main() {
    # Default values
    STACK_NAME=""
    PARAMETERS_FILE=""
    REGION="$DEFAULT_REGION"
    BUCKET_NAME=""
    REPORT_NAME="cost-and-usage-report"
    ENABLE_KMS="false"
    ENABLE_COH="false"
    ENABLE_REPLICATION="false"
    DRY_RUN="false"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--stack-name)
                STACK_NAME="$2"
                shift 2
                ;;
            -p|--parameters)
                PARAMETERS_FILE="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -b|--bucket-name)
                BUCKET_NAME="$2"
                shift 2
                ;;
            -n|--report-name)
                REPORT_NAME="$2"
                shift 2
                ;;
            --enable-kms)
                ENABLE_KMS="true"
                shift
                ;;
            --enable-coh)
                ENABLE_COH="true"
                shift
                ;;
            --enable-replication)
                ENABLE_REPLICATION="true"
                shift
                ;;
            --dry-run)
                DRY_RUN="true"
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
    
    # Validate required parameters
    if [[ -z "$STACK_NAME" ]]; then
        print_error "Stack name is required (use -s or --stack-name)"
        show_usage
        exit 1
    fi
    
    # Execute deployment
    validate_prerequisites
    validate_template
    deploy_stack
    
    if [[ "$DRY_RUN" != "true" ]]; then
        print_success "CUR CloudFormation deployment completed successfully!"
        print_info "Stack name: $STACK_NAME"
        print_info "Region: $REGION"
        print_info "You can view the stack in the AWS CloudFormation console."
    fi
}

# Run main function
main "$@" 