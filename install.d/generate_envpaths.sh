#!/usr/bin/env bash

# Only enable strict mode if not being sourced
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && set -euo pipefail

export BASK_PATH="$(realpath -m "$(dirname "$PWD")")"

# Array of package names and their relative default paths
declare -A PKG_PATHS=(
    [CESM]="CESM"
    [MODEL2OBS]="model2obs"
    [CROCODASH]="CrocoDash"
    [CUPID]="CUPiD"
    [DART]="DART"
)

# Initialize flags to 0 and paths to empty
for PKG in "${!PKG_PATHS[@]}"; do
    declare "${PKG}=0"
    export "${PKG}_PATH="
done
DEFAULT=0
FORCE=0
SSH_GITHUB=0
ENV_PREFIX=''
NOTEBOOKS=0

# Register what packages need to be installed from CLI flags
UNKNOWN_ARGS=()
for ((i=1; i<=$#; i++)); do
    arg="${!i}"

    case "$arg" in
        --envname|-e)
            ((i++))
            if [[ "$i" -gt "$#" ]]; then
                echo "Error: $arg requires a value" >&2
                exit 1
            fi
            ENV_PREFIX="${!i}"
            ;;
        --all)
            for PKG in "${!PKG_PATHS[@]}"; do
                declare "${PKG}=1"
            done
            NOTEBOOKS=1
            ;;
        --notebooks) NOTEBOOKS=1 ;;
        --workshop)
            for PKG in "${!PKG_PATHS[@]}"; do
                if [[ "$PKG" != "CUPID" ]]; then
                    declare "${PKG}=1"
                fi
            done
            NOTEBOOKS=1
            ;;
        -d|--default) DEFAULT=1 ;;
        -f|--force) FORCE=1 ;;
        -s|--ssh-github) SSH_GITHUB=1 ;;
        *)
            upper="${arg#--}"
            upper="${upper^^}"
            if [[ -v PKG_PATHS[$upper] ]]; then
                declare "${upper}=1"
            else
                UNKNOWN_ARGS+=("$arg")
            fi
            ;;
    esac
done

if [[ "${#UNKNOWN_ARGS[@]}" -gt 0 ]]; then
    echo "Error: unrecognized argument(s): ${UNKNOWN_ARGS[*]}" >&2
    exit 1
fi

# --notebooks needs the CrocoDash env (for the crocogallery CLI); pull it in.
if [[ "$NOTEBOOKS" -eq 1 && "$CROCODASH" -eq 0 ]]; then
    CROCODASH=1
fi

# Assign paths
if [[ "$DEFAULT" -eq 1 ]]; then
    for PKG in "${!PKG_PATHS[@]}"; do
        export "${PKG}_PATH"="$(realpath -m "$BASK_PATH/${PKG_PATHS[$PKG]}")"
        echo "$PKG root path set to $(eval echo \${${PKG}_PATH})"
    done
elif [ -t 0 ]; then
    for PKG in "${!PKG_PATHS[@]}"; do
        DEF="$BASK_PATH/${PKG_PATHS[$PKG]}"
        printf "Please provide %s root path (default: %s): " "$PKG" "$DEF"
        read -r input_path
        if [ -n "$input_path" ]; then
            export "${PKG}_PATH"="$(realpath -m "$input_path")"
        else
            export "${PKG}_PATH"="$(realpath -m "$DEF")"
        fi
        echo "$PKG root path set to $(eval echo \${${PKG}_PATH})"
    done
fi

# Where the rendered gallery notebooks put their CESM cases and their MOM6
# input files. These are not packages -- nothing is installed into them -- but
# the notebooks need real directories, so they are resolved here alongside the
# package paths and injected at render time. On GLADE they belong on scratch:
# a single case's forcing runs to tens of GB, which does not belong in the
# quota'd, backed-up work filesystem that holds the Bask tree.
if [[ -d "/glade/derecho/scratch/$USER" ]]; then
    CROC_DATA_ROOT="/glade/derecho/scratch/$USER"
else
    CROC_DATA_ROOT="$BASK_PATH"
fi
export CASES_PATH="$(realpath -m "${CASES_PATH:-$CROC_DATA_ROOT/croc_cases}")"
export INPUT_PATH="$(realpath -m "${INPUT_PATH:-$CROC_DATA_ROOT/croc_input}")"

# Write all paths to envpaths.sh
ENV_FILE="envpaths.sh"
: > "$ENV_FILE"  # Truncate file

echo "export BASK_PATH=\"${BASK_PATH}\"" >> "$ENV_FILE"
for PKG in "${!PKG_PATHS[@]}"; do
    # Use eval to expand the actual value of the variable
    VAL=$(eval echo "\${${PKG}_PATH}")
    echo "export ${PKG}_PATH=\"$VAL\"" >> "$ENV_FILE"
done
for PKG in "${!PKG_PATHS[@]}"; do
    # Use eval to expand the actual value of the variable
    VAL=$(eval echo "\${${PKG}}")
    echo "export INSTALL_${PKG}=\"$VAL\"" >> "$ENV_FILE"
done
echo "export FORCE=\"$FORCE\"" >> "$ENV_FILE"
echo "export SSH_GITHUB=\"$SSH_GITHUB\"" >> "$ENV_FILE"
echo "export ENV_PREFIX=\"$ENV_PREFIX\"" >> "$ENV_FILE"
echo "export INSTALL_NOTEBOOKS=\"$NOTEBOOKS\"" >> "$ENV_FILE"
echo "export CASES_PATH=\"$CASES_PATH\"" >> "$ENV_FILE"
echo "export INPUT_PATH=\"$INPUT_PATH\"" >> "$ENV_FILE"
