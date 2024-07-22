#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -g <resource-group> -p <registry-prefix> [-c <number>]"
    echo "  -g, --resource-group: The resource group containing the container registries."
    echo "  -p, --registry-prefix: The prefix of the container registries to delete."
    echo "  -c, --max-concurrent: Maximum number of concurrent deletions. Defaults to 1 if not specified."
    exit 1
}

# Function to handle interruption
cleanup() {
    echo "Script interrupted. Cleaning up..."
    exit 1
}

# Trap SIGINT (Ctrl+C) and call the cleanup function
trap cleanup SIGINT

# Default maximum concurrent deletions
MAX_CONCURRENT=1

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        -p|--registry-prefix)
            PREFIX="$2"
            shift 2
            ;;
        -c|--max-concurrent)
            MAX_CONCURRENT="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Check if both parameters are provided
if [[ -z "$RESOURCE_GROUP" || -z "$PREFIX" ]]; then
    usage
fi

# List container registries under the given resource group
registries=$(az acr list --resource-group "$RESOURCE_GROUP" --query "[?starts_with(name, '$PREFIX')].name" -o tsv)

# Check if there are any registries to delete
if [[ -z "$registries" ]]; then
    echo "No container registries found with the prefix '$PREFIX' in resource group '$RESOURCE_GROUP'."
    exit 0
fi

# Count the total number of registries
total_registries=$(echo "$registries" | wc -l)
echo "Total number of registries to delete: $total_registries"

# Function to delete a single registry
delete_registry() {
    local registry=$1
    echo "Deleting container registry: $registry"
    command="az acr delete --name \"$registry\" --resource-group \"$RESOURCE_GROUP\" --yes"
    echo "Executing command: $command"
    eval $command
    if [ $? -ne 0 ]; then
        echo "Failed to delete registry: $registry"
    else
        echo "Successfully deleted registry: $registry"
    fi
}

# Process each registry
process_registries() {
    local max_concurrent=$1
    local jobs=0

    for registry in $registries; do
        # Trim any extra whitespace and newlines
        registry=$(echo "$registry" | tr -d '[:space:]')
        if [[ -n "$registry" ]]; then
            while [[ $jobs -ge $max_concurrent ]]; do
                # Wait for any background job to complete
                wait -n
                ((jobs--))
            done
            delete_registry "$registry" &
            ((jobs++))
        else
            echo "Skipping empty registry name"
        fi
    done
    # Wait for all remaining background jobs to complete
    wait
}

# Execute the processing function with the specified maximum concurrent deletions
echo "Deleting registries with a maximum of $MAX_CONCURRENT concurrent deletions..."
process_registries $MAX_CONCURRENT

echo "Deletion process completed for registries with prefix '$PREFIX'."

