# Bask

A template repository for regional ocean modeling workflows using tools developed in the NSF-funded [CROCODILE](https://github.com/CROCODILE-CESM?view_as=public) project.

## Usage

This repository is a GitHub template. Click **Use this template** to create your own repository (e.g., `MyRegionalCase`), then run the installation script to set up packages there, where you can commit and track your work. BaskTemplate itself remains lightweight by not committing submodules; each run records the exact commit of every installed package in `install.d/installed_<timestamp>.txt`.

## Installation

> **Note:** for the time being, Bask supports installation on NCAR infrastructure (Derecho, Casper) only.

Requires `conda` >= 23.10.

From the repository root, run:

```bash
./install.sh [flags]
```

### Available Flags

#### Package Selection
- `--crocodash`: Install CrocoDash model components
- `--model2obs`: Install model2obs diagnostics tools
- `--cupid`: Install CUPiD diagnostics framework
- `--cesm`: Install CESM model
- `--dart`: Currently a no-op on its own — DART is not yet installed as a standalone submodule/environment. It only sets the `DART_PATH` used by the model2obs installer. Standalone DART installation may be added in a future release.
- `--notebooks`: Render the CrocoGallery notebooks listed in `install.d/notebooks.txt` into `workspace/` (implies `--crocodash`)
- `--all`: Install all packages (includes `--notebooks`)
- `--workshop`: Install packages used during the CROCODILE workshop (includes `--notebooks`)

#### Installation Options
- `-d, --default`: Use default paths for all packages (non-interactive)
- `-f, --force`: Remove and reinstall selected packages if they already exist
- `-s, --ssh-github`: Use SSH URLs instead of HTTPS for GitHub submodules (requires SSH key setup)
- `-e, --envname`: Specify prefix for conda environment names (default: no prefix, e.g. the CrocoDash environment is named `CrocoDash`; with `--envname bask` it becomes `bask-CrocoDash`)
- `-h, --help`: Display usage information and exit


You can combine multiple flags. If no `-d` or `--default` flag is provided, the script will prompt for custom paths for each package.

### Examples

```bash
# Install CrocoDash and model2obs with default paths
./install.sh --crocodash --model2obs -d

# Install all packages with default paths
./install.sh --all --default

# Install packages for CROCODILE workshop with default paths
./install.sh --workshop --default

# Install all packages with default paths and custom environment prefix
./install.sh --all --default --envname myBask

# Reinstall CESM (force reinstall if already exists)
./install.sh --cesm -d -f

# Install using SSH URLs (requires GitHub SSH key)
./install.sh --crocodash --cupid -d -s
```

### Behavior

If a package already exists at the target path, the script will skip installation and print a message. Use the `-f` or `--force` flag to remove and reinstall existing packages.

## Subpackages

- **CrocoDash**: CESM-MOM6 regional cases set up management
- **model2obs**: Diagnostics and analysis tools for MOM6 (and soon ROMS) model output
- **CUPiD**: NCAR's unified framework for running analysis and diagnostics on climate model output
- **CESM**: Community Earth System Model for climate simulations
- **DART**: Data Assimilation Research Testbed for ensemble data assimilation

## Workspace

The installer creates a `workspace/` folder at the repository root. Some packages copy their tutorial notebooks and configurations there.

With `--notebooks` (included in `--all` and `--workshop`), the installer also renders the CrocoGallery notebooks listed in `install.d/notebooks.txt` into `workspace/`. Edit that file to change which notebooks are rendered; list the available IDs with `crocogallery template --list-notebooks`.

Rendering fills in the paths the installer knows about: the CESM checkout, plus a case directory and an input directory (`croc_cases/` and `croc_input/`, placed under `/glade/derecho/scratch/$USER` when installing on GLADE and under the Bask root otherwise). Export `CASES_PATH` or `INPUT_PATH` before running the installer to put them somewhere else. Shared dataset paths (GEBCO, TPXO, ...) are filled in only when installing on GLADE; elsewhere the notebooks keep their `<KEY>` placeholders for you to edit by hand.
