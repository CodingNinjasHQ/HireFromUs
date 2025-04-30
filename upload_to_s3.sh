#!/bin/bash

# Check if bucket name is provided
if [ -z "$1" ]; then
    echo "Usage: ./upload_to_s3.sh <bucket-name> [prefix]"
    exit 1
fi

BUCKET_NAME=$1
PREFIX=${2:-""}

# Function to check if a file should be ignored
should_ignore() {
    local file=$1
    
    # Common patterns to ignore
    local ignore_patterns=(
        ".git"
        ".gitignore"
        ".DS_Store"
        "__pycache__"
        "*.pyc"
        "*.pyo"
        "*.pyd"
        ".pytest_cache"
        "venv"
        "env"
        ".env"
        "node_modules"
        "*.log"
        "*.txt"
        "*.sh"
    )
    
    for pattern in "${ignore_patterns[@]}"; do
        if [[ $file == *$pattern* ]]; then
            return 0
        fi
    done
    
    # Check .gitignore if it exists
    if [ -f .gitignore ]; then
        while IFS= read -r pattern; do
            # Skip empty lines and comments
            [[ -z $pattern || $pattern =~ ^# ]] && continue
            # Remove leading slash if present
            pattern=${pattern#/}
            if [[ $file == *$pattern* ]]; then
                return 0
            fi
        done < .gitignore
    fi
    
    return 1
}

# Upload files recursively
upload_files() {
    local dir=$1
    local current_prefix=$2
    
    for file in "$dir"/*; do
        if [ -d "$file" ]; then
            # Skip hidden directories
            if [[ $(basename "$file") != .* ]]; then
                upload_files "$file" "$current_prefix"
            fi
        else
            local relative_path=${file#./}
            if ! should_ignore "$relative_path"; then
                # Construct S3 key without duplicating the path
                local s3_key="$PREFIX/$relative_path"
                s3_key=${s3_key#/}  # Remove leading slash
                
                echo "Uploading: $relative_path to s3://$BUCKET_NAME/$s3_key"
                aws s3 cp "$file" "s3://$BUCKET_NAME/$s3_key" || echo "Failed to upload: $relative_path"
            fi
        fi
    done
}

# Start upload from current directory
echo "Starting upload to s3://$BUCKET_NAME/$PREFIX"
upload_files "." "$PREFIX"
echo "Upload complete!" 