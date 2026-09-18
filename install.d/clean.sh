#!/usr/bin/env bash

set -euo pipefail

# Check for help flag only if arguments are provided
if [[ $# -gt 0 ]]; then
    for arg in "$@"; do
        if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
            cat << EOF
Usage: ./clean.sh [OPTIONS]

Package Selection:
  --cesm            Remove CESM model
  --cesm_da         Remove CESM_DA DART-enabled CESM checkout
  --model2obs       Remove model2obs diagnostics tools
  --crocodash       Remove CrocoDash model components
  --mom6-tools      Remove mom6-tools diagnostics framework
  --all             Remove all packages

Options:
  -h, --help        Display this help message

Examples:
  ./clean.sh --crocodash
  ./clean.sh --all
  ./clean.sh --cesm --model2obs

Notes:
  - Multiple flags can be combined
  - Without flags, uses envpaths.sh if it exists
EOF
            exit 0
        fi
    done
fi

# If no arguments provided, use envpaths.sh (preserves original behavior when called from install.sh)
PKGS=(CESM CESM_DA MODEL2OBS CROCODASH MOM6TOOLS DART)

# The flag a user types for each package, declared rather than derived from the
# name, so a package's name does not have to be a legal shell variable name.
declare -A PKG_FLAGS=(
    [--cesm]=CESM
    [--cesm_da]=CESM_DA
    [--model2obs]=MODEL2OBS
    [--crocodash]=CROCODASH
    [--mom6-tools]=MOM6TOOLS
    [--dart]=DART
)
source ./envpaths.sh

if [[ $# -eq 0 ]]; then
    # Export CLEAN_* variables
    for PKG in "${PKGS[@]}"; do
        export "CLEAN_${PKG}"="$(eval echo \${INSTALL_${PKG}})"
    done
else
    # Initialize all packages to 0
    for PKG in "${PKGS[@]}"; do
        export "CLEAN_${PKG}=0"
    done
    
    # Parse arguments
    for ((i=1; i<=$#; i++)); do
        arg="${!i}"
        
        case "$arg" in
            --all)
                for PKG in "${PKGS[@]}"; do
                    export "CLEAN_${PKG}=1"
                done
                ;;
            *)
                if [[ -v PKG_FLAGS[$arg] ]]; then
                    export "CLEAN_${PKG_FLAGS[$arg]}=1"
                fi
                ;;
        esac
    done
fi

echo "Cleaning selected components..."

# CrocoDash
if [ "$CLEAN_CROCODASH" -eq 1 ] && [ -e "$CROCODASH_PATH" ]; then
    echo "Removing CrocoDash..."
    cd "$BASK_PATH"
    rm -rf "$CROCODASH_PATH"
    echo "CrocoDash removed."
fi

# model2obs
if [ "$CLEAN_MODEL2OBS" -eq 1 ] && [ -n "$MODEL2OBS_PATH" ]; then
    echo "Removing model2obs..."
    cd "$BASK_PATH"
    rm -rf "$MODEL2OBS_PATH"
    echo "model2obs removed."
fi

# mom6-tools
if [ "$CLEAN_MOM6TOOLS" -eq 1 ] && [ -n "$MOM6TOOLS_PATH" ]; then
    echo "Removing mom6-tools..."
    cd "$BASK_PATH"
    rm -rf "$MOM6TOOLS_PATH"
    echo "mom6-tools removed."
fi

# CESM
if [ "$CLEAN_CESM" -eq 1 ] && [ -n "$CESM_PATH" ]; then
    echo "Removing CESM..."
    cd "$BASK_PATH"
    rm -rf "$CESM_PATH"
    echo "CESM removed."
fi

# CESM_DA
if [ "$CLEAN_CESM_DA" -eq 1 ] && [ -n "$CESM_DA_PATH" ]; then
    echo "Removing CESM_DA..."
    cd "$BASK_PATH"
    rm -rf "$CESM_DA_PATH"
    echo "CESM_DA removed."
fi

echo "Cleanup complete."
