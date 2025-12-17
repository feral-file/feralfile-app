#!/bin/bash

# Script to query the current build number from Google Play Store
# The bumping logic is handled in the GitHub Actions workflow for transparency
# Requires: jq, curl, and GOOGLE_PLAY_SERVICE_ACCOUNT environment variable

set -e

# Configuration
PACKAGE_NAME="com.feralfile.app"  # Update this to your app's package name
TRACK="production"  # Can be: production, beta, alpha, internal

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if required tools are installed
check_dependencies() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Install it with: brew install jq (macOS) or apt-get install jq (Linux)"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed"
        exit 1
    fi
}

# Get OAuth2 access token from service account
get_access_token() {
    local service_account_json="$1"
    
    # Parse service account JSON
    local client_email=$(echo "$service_account_json" | jq -r '.client_email')
    local private_key=$(echo "$service_account_json" | jq -r '.private_key')
    local token_uri=$(echo "$service_account_json" | jq -r '.token_uri')
    
    if [ -z "$client_email" ] || [ -z "$private_key" ] || [ "$client_email" == "null" ]; then
        log_error "Invalid service account JSON"
        return 1
    fi
    
    # Create JWT header
    local header='{"alg":"RS256","typ":"JWT"}'
    local header_b64=$(echo -n "$header" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    
    # Create JWT claim set
    local now=$(date +%s)
    local exp=$((now + 3600))
    local claim=$(cat <<EOF
{
    "iss": "$client_email",
    "scope": "https://www.googleapis.com/auth/androidpublisher",
    "aud": "$token_uri",
    "exp": $exp,
    "iat": $now
}
EOF
)
    local claim_b64=$(echo -n "$claim" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    
    # Create signature
    local jwt_unsigned="${header_b64}.${claim_b64}"
    local signature=$(echo -n "$jwt_unsigned" | openssl dgst -sha256 -sign <(echo -n "$private_key") | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
    
    # Complete JWT
    local jwt="${jwt_unsigned}.${signature}"
    
    # Exchange JWT for access token
    local response=$(curl -s -X POST "$token_uri" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=$jwt")
    
    local access_token=$(echo "$response" | jq -r '.access_token')
    
    if [ -z "$access_token" ] || [ "$access_token" == "null" ]; then
        log_error "Failed to get access token"
        log_error "Response: $response"
        return 1
    fi
    
    echo "$access_token"
}

# Create an edit session
create_edit() {
    local package_name="$1"
    local access_token="$2"
    
    local response=$(curl -s -X POST \
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package_name/edits" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json")
    
    local edit_id=$(echo "$response" | jq -r '.id')
    
    if [ -z "$edit_id" ] || [ "$edit_id" == "null" ]; then
        log_error "Failed to create edit session"
        log_error "Response: $response"
        return 1
    fi
    
    echo "$edit_id"
}

# Get track information
get_track_info() {
    local package_name="$1"
    local edit_id="$2"
    local track="$3"
    local access_token="$4"
    
    local response=$(curl -s -X GET \
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package_name/edits/$edit_id/tracks/$track" \
        -H "Authorization: Bearer $access_token")
    
    echo "$response"
}

# Delete edit session (cleanup)
delete_edit() {
    local package_name="$1"
    local edit_id="$2"
    local access_token="$3"
    
    curl -s -X DELETE \
        "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/$package_name/edits/$edit_id" \
        -H "Authorization: Bearer $access_token" > /dev/null
}

# Extract highest version code from track info
get_highest_version_code() {
    local track_info="$1"
    
    # Get all version codes from all releases in the track
    local version_codes=$(echo "$track_info" | jq -r '.releases[]?.versionCodes[]?' 2>/dev/null)
    
    if [ -z "$version_codes" ]; then
        log_warning "No version codes found in track"
        echo "0"
        return
    fi
    
    # Find the highest version code
    local highest=0
    while IFS= read -r code; do
        if [ "$code" -gt "$highest" ]; then
            highest=$code
        fi
    done <<< "$version_codes"
    
    echo "$highest"
}

# Main function
main() {
    log_info "Starting Google Play Store version query and bump script"
    
    # Check dependencies
    check_dependencies
    
    # Check if service account credentials are provided
    if [ -z "$GOOGLE_PLAY_SERVICE_ACCOUNT" ]; then
        log_error "GOOGLE_PLAY_SERVICE_ACCOUNT environment variable is not set"
        exit 1
    fi
    
    log_info "Getting OAuth2 access token..."
    ACCESS_TOKEN=$(get_access_token "$GOOGLE_PLAY_SERVICE_ACCOUNT")
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get access token"
        exit 1
    fi
    
    log_info "Creating edit session..."
    EDIT_ID=$(create_edit "$PACKAGE_NAME" "$ACCESS_TOKEN")
    
    if [ $? -ne 0 ]; then
        log_error "Failed to create edit session"
        exit 1
    fi
    
    log_info "Edit session created: $EDIT_ID"
    
    log_info "Fetching track information for '$TRACK' track..."
    TRACK_INFO=$(get_track_info "$PACKAGE_NAME" "$EDIT_ID" "$TRACK" "$ACCESS_TOKEN")
    
    # Extract version codes
    CURRENT_BUILD_NUMBER=$(get_highest_version_code "$TRACK_INFO")
    
    # Clean up edit session
    log_info "Cleaning up edit session..."
    delete_edit "$PACKAGE_NAME" "$EDIT_ID" "$ACCESS_TOKEN"
    
    # Output results
    echo ""
    log_info "========================================="
    log_info "Current build number: $CURRENT_BUILD_NUMBER"
    log_info "========================================="
    echo ""
    
    # Export for GitHub Actions
    if [ -n "$GITHUB_OUTPUT" ]; then
        echo "current_build_number=$CURRENT_BUILD_NUMBER" >> "$GITHUB_OUTPUT"
    fi
    
    # Also export as environment variable
    export CURRENT_BUILD_NUMBER
    
    log_info "Successfully retrieved build number from Play Store!"
}

# Run main function
main
