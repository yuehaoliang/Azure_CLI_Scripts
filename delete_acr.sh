#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 --resource-group <resource-group> --prefix <registry-name-prefix>"
    exit 1
}

# Function to handle interruption
cleanup() {
    echo "Script interrupted. Cleaning up..."
    exit 1
}

# Trap SIGINT (Ctrl+C) and call the cleanup function
trap cleanup SIGINT

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --resource-group)
            RESOURCE_GROUP="$2"
            shift 2
            ;;
        --prefix)
            PREFIX="$2"
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

# Delete each registry
for registry in $registries; do
    # Trim any extra whitespace
    registry=$(echo "$registry" | tr -d '[:space:]')
    if [[ -n "$registry" ]]; then
        echo "Deleting container registry: $registry"
        command="az acr delete --name \"$registry\" --resource-group \"$RESOURCE_GROUP\" --yes"
        echo "Executing command: $command"
        eval $command
        if [ $? -ne 0 ]; then
            echo "Failed to delete registry: $registry"
            exit 1  # Exit if a deletion fails
        else
            echo "Successfully deleted registry: $registry"
        fi
    else
        echo "Skipping empty registry name"
    fi
done

echo "Deletion process completed for registries with prefix '$PREFIX'."

