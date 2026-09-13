#!/usr/bin/env bash

set -euo pipefail

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
        cat << EOF
Usage: ./install.sh [OPTIONS]

Package Selection:
  --cesm            Install CESM model
  --model2obs       Install model2obs diagnostics tools
  --crocodash       Install CrocoDash model components
  --cupid           Install CUPiD diagnostics framework
  --dart            Install DART data assimilation system
  --all             Install all packages

Installation Options:
  -d, --default     Use default paths for all packages (non-interactive)
  -f, --force       Remove and reinstall selected packages if they already exist
  -s, --ssh-github  Use SSH URLs instead of HTTPS for GitHub submodules (requires SSH key)
  -e, --envname     Specify prefix for conda environment names (default: 'bask')
  -h, --help        Display this help message

Examples:
  ./install.sh --crocodash --model2obs -d
  ./install.sh --all --default
  ./install.sh --cesm -d -f
  ./install.sh --crocodash --cupid -d -s

Notes:
  - Multiple flags can be combined
  - Without -d/--default, the script will prompt for custom paths
  - If a package already exists, it will be skipped unless -f/--force is used
EOF
        exit 0
fi

# generate environmental variables
INSTALL_DIR="$PWD/install.d"
cd $INSTALL_DIR
./generate_envpaths.sh "$@" # pass all flags

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
    conda env create -f "$CROCODASH_PATH"/environment.yml --name ${CROCODASH_ENV_NAME} --yes
    add_env_vars_to_conda "$CROCODASH_ENV_NAME"
    echo "CrocoDash environment installed."
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
    conda env create -f "$CUPID_PATH"/environments/cupid-infrastructure.yml --name ${CUPID_ENV1_NAME} --yes
    add_env_vars_to_conda "$CUPID_ENV1_NAME"

    ENV_NAME=$(awk -F ": " '/^name:/ {print $2}' "$CUPID_PATH"/environments/cupid-analysis.yml)
    CUPID_ENV2_NAME="${ENV_PREFIX}${ENV_NAME}"
    conda env create -f "$CUPID_PATH"/environments/cupid-analysis.yml --name ${CUPID_ENV2_NAME} --yes
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
