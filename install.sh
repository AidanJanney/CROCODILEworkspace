#!/usr/bin/env bash

set -euo pipefail

show_help() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Package Selection:
  --cesm            Install CESM model
  --model2obs       Install model2obs diagnostics tools
  --crocodash       Install CrocoDash model components
  --cupid           Install CUPiD diagnostics framework
  --dart            Install DART data assimilation system
  --notebooks       Render CrocoGallery notebooks listed in install.d/notebooks.txt
                    into <BASK_PATH>/workspace/ (implies --crocodash)
  --all             Install all packages (includes --notebooks)
  --workshop        Install all packages except CUPiD (includes --notebooks)

Installation Options:
  -d, --default     Use default paths for all packages (non-interactive)
  -f, --force       Remove and reinstall selected packages if they already exist
  -s, --ssh-github  Use SSH URLs instead of HTTPS for GitHub clones (requires SSH key)
  -e, --envname     Specify prefix for conda environment names (default: none)
  -h, --help        Display this help message

Examples:
  ./install.sh --crocodash --model2obs -d
  ./install.sh --all --default
  ./install.sh --cesm -d -f
  ./install.sh --crocodash --cupid -d -s
  ./install.sh --crocodash --notebooks -d

Notes:
  - Multiple flags can be combined
  - Without -d/--default, the script will prompt for custom paths
  - If a package already exists, it will be skipped unless -f/--force is used
  - Edit install.d/notebooks.txt to change which gallery notebooks --notebooks renders
EOF
}

is_ncar_hpc_host() {
    hostname_value=$(hostname -s 2>/dev/null || hostname)
    hostname_value=$(printf '%s' "$hostname_value" | tr '[:upper:]' '[:lower:]')
    case "$hostname_value" in
        dec*|derecho*|crlogin*|crht*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if is_ncar_hpc_host; then
    module load conda/latest
fi


# Check for help flag
SHOW_HELP="0"
if [ "$#" -eq 0 ]; then
    SHOW_HELP="1"
    echo "One or more packages need to be specified"
    echo ""
fi
for arg in "$@"; do
    if [[ "$arg" == "-h" || "$arg" == "--help" ]]; then
        SHOW_HELP="1"
    fi
done
if [[ "$SHOW_HELP" -eq 1 ]]; then
    show_help
    exit 0
fi

# generate environmental variables
INSTALL_DIR="$PWD/install.d"
cd $INSTALL_DIR
if ! ./generate_envpaths.sh "$@"; then # pass all flags
    echo ""
    show_help
    exit 1
fi

# clean already installed submodules
source ./envpaths.sh
if [[ "$FORCE" -eq 1 ]]; then
    ./clean.sh
fi

# download submodules
./init.sh

# install submodules

# Source helper function
source ./setup_conda_env.sh

NBS_PATH=$BASK_PATH"/workspace/"
mkdir -p $NBS_PATH
if [[ -n ${ENV_PREFIX:-} ]]; then
    ENV_PREFIX="${ENV_PREFIX}-"
fi
# CrocoDash
if [[ "$INSTALL_CROCODASH" -eq 1 ]]; then
    echo "Installing CrocoDash environment..."
    cd "$CROCODASH_PATH"
    CROCODASH_SHA=$(git rev-parse HEAD)
    cd "$INSTALL_DIR"
    ENV_NAME=$(awk -F ": " '/^name:/ {print $2}' "$CROCODASH_PATH/environment.yml")
    CROCODASH_ENV_NAME="${ENV_PREFIX}${ENV_NAME}"
    mamba env create -f "$CROCODASH_PATH"/environment.yml --name ${CROCODASH_ENV_NAME} --yes
    add_env_vars_to_conda "$CROCODASH_ENV_NAME"
    echo "CrocoDash environment installed."
fi

# CrocoGallery notebooks
RENDERED_NOTEBOOKS=()
if [[ "$INSTALL_NOTEBOOKS" -eq 1 ]]; then
    NOTEBOOKS_LIST="$INSTALL_DIR/notebooks.txt"
    if [[ ! -f "$NOTEBOOKS_LIST" ]]; then
        echo "WARNING: --notebooks passed but $NOTEBOOKS_LIST is missing; skipping."
    elif [[ -z "${CROCODASH_ENV_NAME:-}" ]]; then
        echo "WARNING: --notebooks requires the CrocoDash env; skipping notebook rendering."
    else
        mkdir -p "$CASES_PATH" "$INPUT_PATH"

        # The gallery's shared dataset paths (GEBCO, TPXO, ...) are GLADE
        # locations, so only ask for them when we are actually on GLADE;
        # elsewhere the notebooks keep their <KEY> placeholders for the user
        # to fill in. The three paths Bask itself owns are always injected,
        # since the installer is the only thing that knows where they landed.
        TEMPLATE_ARGS=()
        # if [[ -d /glade/campaign/cesm/cesmdata/inputdata ]]; then
        #     TEMPLATE_ARGS+=(--machine glade)
        # fi
        TEMPLATE_ARGS+=(--set "casedir=$CASES_PATH" --set "inputdir=$INPUT_PATH")
        if [[ -n "${CESM_PATH:-}" ]]; then
            TEMPLATE_ARGS+=(--set "CESM=$CESM_PATH")
        fi

        echo "Rendering CrocoGallery notebooks into $NBS_PATH..."
        echo "  cases -> $CASES_PATH"
        echo "  input -> $INPUT_PATH"
        while IFS= read -r NB || [[ -n "$NB" ]]; do
            NB="${NB%%#*}"
            NB="${NB//[[:space:]]/}"
            [[ -z "$NB" ]] && continue
            OUTPUT="${NBS_PATH}${NB}.ipynb"
            echo "  - $NB -> $OUTPUT"
            conda run -n "$CROCODASH_ENV_NAME" crocogallery template \
                "${TEMPLATE_ARGS[@]}" \
                --notebook "$NB" \
                --output "$OUTPUT"
            RENDERED_NOTEBOOKS+=("$NB")
        done < "$NOTEBOOKS_LIST"
        echo "CrocoGallery notebooks rendered."
    fi
fi

# model2obs
if [[ "$INSTALL_MODEL2OBS" -eq 1 ]]; then
    echo "Installing model2obs environment..."
    cd "$MODEL2OBS_PATH"/install
    MODEL2OBS_SHA=$(git rev-parse HEAD)
    cp envpaths_NCAR.sh envpaths.sh
    MODEL2OBS_ENV_NAME="${ENV_PREFIX}""model2obs"
    DART_ROOT_PATH=${DART_PATH} CONDA_ENV_NAME=${MODEL2OBS_ENV_NAME} ./install_NCAR.sh --tutorial
    cd "$INSTALL_DIR"
    echo "model2obs environment installed."
    cp "$MODEL2OBS_PATH"/tutorials/tutorial1_MOM6-CL-comparison.ipynb "$NBS_PATH"
    cp "$MODEL2OBS_PATH"/tutorials/config_tutorial_1.yaml "$NBS_PATH"
fi

# CUPiD
if [[ "$INSTALL_CUPID" -eq 1 ]]; then
    echo "Installing CUPiD environments..."

    cd "$CUPID_PATH"
    CUPID_SHA=$(git rev-parse HEAD)
    cd "$INSTALL_DIR"

    ENV_NAME=$(awk -F ": " '/^name:/ {print $2}' "$CUPID_PATH"/environments/cupid-infrastructure.yml)
    CUPID_ENV1_NAME="${ENV_PREFIX}${ENV_NAME}"
    mamba env create -f "$CUPID_PATH"/environments/cupid-infrastructure.yml --name ${CUPID_ENV1_NAME} --yes
    add_env_vars_to_conda "$CUPID_ENV1_NAME"

    ENV_NAME=$(awk -F ": " '/^name:/ {print $2}' "$CUPID_PATH"/environments/cupid-analysis.yml)
    CUPID_ENV2_NAME="${ENV_PREFIX}${ENV_NAME}"
    mamba env create -f "$CUPID_PATH"/environments/cupid-analysis.yml --name ${CUPID_ENV2_NAME} --yes
    add_env_vars_to_conda "$CUPID_ENV2_NAME"

    echo "CUPiD environments installed."
fi

# CESM
if [[ "$INSTALL_CESM" -eq 1 ]]; then
    echo "Installing CESM..."
    cd "$CESM_PATH"
    CESM_SHA=$(git rev-parse HEAD)
    ./bin/git-fleximod update --path "$CESM_PATH"
    cd "$INSTALL_DIR"
    echo "CESM installed."
fi

echo ""
echo "------------------------------------------------------------------"
echo "Install complete."
echo "Components, environments and paths installed:"

DATETIME=$(date "+%Y-%m-%d_%H-%M-%S")
INSTALL_RECORD="installed_${DATETIME}.txt"
touch $INSTALL_RECORD

if [[ "$INSTALL_CROCODASH" -eq 1 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
CrocoDash:
    path:   $CROCODASH_PATH
    commit: $CROCODASH_SHA
    conda environment: $CROCODASH_ENV_NAME
EOF
fi
if [[ "$INSTALL_NOTEBOOKS" -eq 1 && "${#RENDERED_NOTEBOOKS[@]}" -gt 0 ]]; then
    {
        echo "CrocoGallery notebooks:"
        echo "    workspace: $NBS_PATH"
        echo "    case directory: $CASES_PATH"
        echo "    input directory: $INPUT_PATH"
        for NB in "${RENDERED_NOTEBOOKS[@]}"; do
            echo "    - $NB"
        done
    } | tee -a $INSTALL_RECORD
fi
if [[ "$INSTALL_CESM" -eq 1 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
CESM:
    path:   $CESM_PATH
    commit: $CESM_SHA
EOF
fi
if [[ "$INSTALL_MODEL2OBS" -eq 1 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
MODEL2OBS:
    path:   $MODEL2OBS_PATH
    commit: $MODEL2OBS_SHA
    conda environment: $MODEL2OBS_ENV_NAME
EOF
fi
if [[ "$INSTALL_CUPID" -eq 1 ]]; then
    cat <<EOF | tee -a $INSTALL_RECORD
CUPiD:
    path:   $CUPID_PATH
    commit: $CUPID_SHA
    conda environments: $CUPID_ENV1_NAME
                        $CUPID_ENV2_NAME
EOF
fi

echo ""
echo "To activate an environment:"
echo "conda activate <environment-name>"
echo "Example:"
echo "conda activate CrocoDash"
echo "If you specified a prefix for environment names:"
echo "conda activate <prefix>-CrocoDash"
