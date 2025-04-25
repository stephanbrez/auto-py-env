#!/usr/bin/env bash

# auto-py-env automatically activates a conda environment when
# entering a folder with an environment.yml file or /envs/ folder
#
# If the environment doesn't exist, auto-py-env creates and
# activates it for you.
#
# To install, add this line to your .bashrc or .bash-profile:
#
#       source /path/to/auto-py-env.sh
#

# ********** User settings ********** #

# TODO: add support for uv: https://docs.astral.sh/uv/ - test fully
# inspired by: https://treyhunner.com/2024/10/switching-from-virtualenvwrapper-to-direnv-starship-and-uv/

# Package manager to use: "conda" or "mamba"
PACKAGE_MANAGER="mamba"

# List of directories to check for environment.yml and its children
# Modify this to the directories you want to trigger the environment activation in
PROJECT_DIRECTORIES=(
    "/path/to/dir1"
    "/path/to/dir2"
    "/path/to/dir3"
  )

# Default conda enviroment paths.
# Set this to place all conda environments in a specific directory.
# If unset, the script will use the conda envs directories from conda info.
# Note: setting this will speed up the script and every new shell you open.
# CONDA_ENV_DIRS=()

# Strictness level for validation:
# 0 = Skip validation
# 1 = Run basic validation (yamllint, external commands check)
# 2 = Run full validation (yamllint, dangerous packages, untrusted channels, external commands)
STRICTNESS_LEVEL=1

# ********** Full validation settings ********** #
# Example dangerous packages
DANGEROUS_PACKAGES=("curl" "wget" "bash" "sh" "python-pip" "git")

# Example trusted channels
TRUSTED_CHANNELS=("conda-forge" "defaults")

# ********** End user settings ********** #

# Function to retrieve all the configured conda envs directories
function get_conda_envs_dirs() {
    local conda_info
    if ! conda_info=$(conda info); then
        echo "Error: Failed to get conda info" >&2
        return 1
    fi

    # Extract both the main line and the continuation line
    readarray -t CONDA_ENV_DIRS < <(echo "$conda_info" |
        grep -A1 "envs directories" | # Get the line and one after
        sed -n 's/.*envs directories : //p; /^[[:space:]]\+/p' | # Extract paths
        sed 's/^[[:space:]]\+//' | # Remove leading spaces
        grep -v '^$') # Remove empty lines

    for ENV_DIR in "${CONDA_ENV_DIRS[@]}"; do
        PROJECT_DIRECTORIES+=("$ENV_DIR")
    done
    echo "CONDA_ENV_DIRS: ${CONDA_ENV_DIRS[@]}"
}

# Function to check if the current directory is in one of the target directories or its subdirectories
function is_target_directory() {
  local current_dir
  current_dir=$(pwd)

  # Check if TARGET_DIRECTORIES is empty
  if [ ${#TARGET_DIRECTORIES[@]} -eq 0 ]; then
    echo "Error: TARGET_DIRECTORIES is empty." >&2
    return 1
  fi

  for target_dir in "${TARGET_DIRECTORIES[@]}"; do
    if [[ "$current_dir" == *"${target_dir}"* ]]; then
      return 0  # True, the current directory or its parent is one of the target directories
    fi
  done
  echo "Error: Not in any of the target directories or their subdirectories." >&2
  return 1  # False, not in any of the target directories or their subdirectories
}

# Function to check if current directory is inside conda envs
function is_conda_envs_dir() {
    local current_dir
    current_dir=$(pwd)
    for env_dir in "${CONDA_ENV_DIRS[@]}"; do
        if [[ "$current_dir" == "$env_dir"* ]]; then
            return 0  # True, we are in a conda envs directory
        fi
    done
    return 1  # False, we are not in any conda envs directory
}

# Function to check if a package manager is installed
function is_pkgmgr_installed() {
    local pkg_mgr="$1"
    if ! command -v "$pkg_mgr" >/dev/null 2>&1; then
        echo "Error: '$pkg_mgr' is not installed." >&2
        return 1
    fi
    return 0
}

# Function to get & set the active package manager
function get_conda_type() {
    # First ensure conda/mamba is initialized
    if [[ "$PACKAGE_MANAGER" == "mamba" ]]; then
        # Check if mamba exists in path
        if is_pkgmgr_installed "mamba"; then
            echo "mamba"
            return
        fi
    fi
    # Fall back to conda if mamba is not available
    echo "conda"
}

function check_dangerous_packages() {
  local line
  while read -r line; do
    # Extract the package names if the line starts with a dash (indicating a package entry)
    if [[ "$line" =~ ^\s*-\s*([a-zA-Z0-9\-]+) ]]; then
      local pkg="${BASH_REMATCH[1]}"
      for danger in "${DANGEROUS_PACKAGES[@]}"; do
        if [[ "$pkg" == "$danger" ]]; then
          echo "Warning: Dangerous package '$pkg' detected in environment.yml."
          exit 1
        fi
      done
    fi
  done < <(grep -E '^\s*- ' environment.yml)
}

function check_trusted_channels() {
    local channel_name
    while read -r line; do
        channel_name="${line##*-}"  # Remove everything up to last dash
        channel_name="${channel_name## }"  # Remove leading space
        if [[ ! " ${TRUSTED_CHANNELS[*]} " =~ ${channel_name} ]]; then
            echo "Warning: Untrusted channel '$channel_name' detected in environment.yml."
            exit 1
        fi
    done < <(sed -n '/^channels:/,/^[^-]/p' environment.yml | grep '^[[:space:]]*-')
}

# Function to validate the environment.yml file based on the STRICTNESS_LEVEL
function validate_environment_yml() {
  # If STRICTNESS_LEVEL is 0, skip all validation
  if [[ $STRICTNESS_LEVEL -eq 0 ]]; then
    echo "Validation skipped (STRICTNESS_LEVEL is 0)."
    return 0
  fi

  # LEVEL 1 and LEVEL 2 validation: Check for yamllint and external commands
  # Ensures LEVEL 2 includes validations from LEVEL 1
  if [[ $STRICTNESS_LEVEL -ge 1 ]]; then
    # Check if yamllint is installed
    if ! command -v yamllint &> /dev/null; then
      echo "Warning: 'yamllint' is not installed. YAML syntax validation will be skipped."
    else
      # Optionally use yamllint to validate syntax
      if ! yamllint environment.yml; then
        echo "Error: Invalid YAML syntax in environment.yml."
        exit 1
      fi
    fi

    # Check for external commands like 'curl', 'wget', 'bash', etc.
    if grep -E '(curl|wget|bash|sh|git)' environment.yml; then
      echo "Warning: External command invocation detected in environment.yml."
      echo "Potentially unsafe commands like 'curl', 'wget', or 'bash' found."
      exit 1
    fi
  fi

  # LEVEL 2 validation: Additional checks for dangerous packages and untrusted channels
  if [[ $STRICTNESS_LEVEL -ge 2 ]]; then
    # LEVEL 2 already includes LEVEL 1 validation due to structure
    check_dangerous_packages
    check_trusted_channels
  fi

  echo "environment.yml is valid and safe."
}


# Function to create environment based on specified type
function create_env() {
    local env_type="$1"
    local env_name="$2"
    local env_file="$3"
    local base_cmd=""

    echo "Creating new $env_type environment '$env_name'..."

    case "$env_type" in
        "conda"|"mamba")
            base_cmd="conda env create -q"
            if is_conda_envs_dir; then
                [[ -z "${env_file:-}" ]] && base_cmd+=" -n $env_name"
            else
                base_cmd+=" --prefix ./envs"
            fi

            # Add env file flag if specified
            [[ -n "${env_file:-}" ]] && base_cmd+=" -f $env_file"

            echo "Creating conda environment: $base_cmd"
            if ! $base_cmd; then
                echo "Error: Failed to create conda environment" >&2
                return 1
            fi
            ;;
        "venv")
            if ! python -m venv "./venv"; then
                echo "Error: Failed to create virtual environment" >&2
                return 1
            fi
            ;;
        "uv")
            # Check if uv is installed
            if ! is_pkgmgr_installed "uv"; then
                echo "Error: uv is not installed. Please install it first." >&2
                return 1
            fi

            # Create venv using uv
            if ! uv init; then
                echo "Error: Failed to create uv environment '$env_name'" >&2
                return 1
            fi

            # Initialize the environment
            # TODO: check if requirements.txt exists & use params_str
            if ! uv pip install -r requirements.txt 2>/dev/null; then
                echo "Warning: No requirements.txt found or failed to install requirements" >&2
                # Don't return error as this is optional
            fi
            ;;
        *)
            echo "Error: Unsupported environment type '$env_type'" >&2
            return 1
            ;;
    esac
    return 0
}


# Function to automatically activate the environment or create it if necessary
function activate_env() {
    local pkg_mgr env_name
    if [[ $PACKAGE_MANAGER == "conda" ]] || [[ $PACKAGE_MANAGER == "mamba" ]]; then
        pkg_mgr=$(get_conda_type)
    else
        pkg_mgr=$PACKAGE_MANAGER
    fi
    echo "pkg_mgr: $pkg_mgr"

    # Check if we're in a target directory before proceeding
    is_target_directory || return 0

    # Check if environment.yml exists and run validation
    if [[ -f "environment.yml" && -r "environment.yml" ]]; then
      echo "Found environment.yml..."
        if ! validate_environment_yml; then
            echo "Error: Environment validation failed" >&2
            return 1
        fi

        # Extract the environment name
        env_name=$(grep -m 1 '^[^#]*name:' environment.yml | awk '{print $2}')
        if [[ -z "$env_name" ]]; then
            echo "Error: Could not determine environment name from environment.yml" >&2
            return 1
        fi

        # Check if the environment is not already active
        if [[ "${CONDA_PREFIX##*/}" != "$env_name" ]]; then
            # Check if the environment exists
            if env_path=$(conda env list | awk -v env="^$env_name" '$1 ~ env {print $NF; exit}') && [[ -n "$env_path" ]]; then
                # Determine original package manager
                if echo "$env_path" | grep -q "mamba"; then
                    original_pkg_mgr="mamba"
                else
                    original_pkg_mgr="conda"
                fi
                # Activate existing environment
                echo "Activating existing $original_pkg_mgr environment '$env_name'..."
                if ! $original_pkg_mgr activate "$env_name"; then
                    echo "Error: Failed to activate environment '$env_name'" >&2
                    return 1
                fi
            else
                # Create new conda environment with environment.yml
                echo "$pkg_mgr environment '$env_name' doesn't exist. Creating..."
                if create_env "conda" "$env_name" "environment.yml"; then
                    echo "Activating newly created conda environment '$env_name'..."
                    if is_conda_envs_dir; then
                        if ! $pkg_mgr activate "$env_name"; then
                            echo "Error: Failed to activate newly created environment '$env_name'" >&2
                            return 1
                        fi
                    else
                        if ! $pkg_mgr activate "./envs"; then
                            echo "Error: Failed to activate newly created environment '$env_name'" >&2
                            return 1
                        fi
                    fi
                else
                    echo "Error: Failed to create environment" >&2
                    return 1
                fi
            fi
        fi
    # If environment.yml is not present, try activating other environment directories
    elif [[ -d "./envs" && -x "./envs" ]]; then
        echo "Attempting to activate ./envs..."
        $pkg_mgr activate "./envs" && return 0
    elif [[ -d "./venv" && -x "./venv" ]]; then
        echo "Attempting to activate ./venv..."
        source "./venv/bin/activate" && return 0
    elif [[ -d "./.venv" && -x "./.venv" ]]; then
        echo "Attempting to activate ./.venv..."
        source "./.venv/bin/activate" && return 0
    else
      # No environment.yml or directories found, ask user before creating a new environment
      echo "No environment.yml found. Would you like to create a new $pkg_mgr environment? (y/n)"
      read -r user_response

      # Convert response to lowercase
      user_response=$(echo "$user_response" | tr '[:upper:]' '[:lower:]')

      if [[ "$user_response" != "y" && "$user_response" != "yes" ]]; then
          echo "Environment creation cancelled by user."
          return 1
      fi

      case "$pkg_mgr" in
          conda|mamba)
              if create_env "$pkg_mgr" $(basename "$PWD"); then
                  echo "Activating $pkg_mgr environment..."
                  if ! $pkg_mgr activate "env"; then
                      echo "Error: Failed to activate $pkg_mgr environment" >&2
                      return 1
                  fi
              else
                  return 1
              fi
              ;;

          uv)
              if create_env "uv" "uv"; then
                  echo "Created uv environment..."
              else
                  return 1
              fi
              ;;

          venv)
              if create_env "venv" "venv"; then
                  echo "Activating virtual environment..."
                  if ! source "./venv/bin/activate"; then
                      echo "Error: Failed to activate virtual environment" >&2
                      return 1
                  fi
              else
                  return 1
              fi
              ;;

          *)
              echo "Error: Unsupported package manager: $pkg_mgr" >&2
              return 1
              ;;
      esac
    fi
}

# Main script logic that combines interactive shell and sourcing check
# Function to automatically setup environment auto-activation if interactive
function setup_auto_activation() {
    # Check if being executed directly
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo "Script is being executed directly"
        echo "This script is meant to be sourced and not executed directly."
        echo "Run 'source /path/to/auto-py-env.sh'."
        return 1
    else
        # Script is being sourced, set to user defined PROJECT_DIRECTORIES
        if [ -z "$CONDA_ENV_DIRS" ]; then
          CONDA_ENV_DIRS=()
          get_conda_envs_dirs
        fi
        TARGET_DIRECTORIES=("${PROJECT_DIRECTORIES[@]}")
    fi

    # Check if --init argument is provided
    local init_flag=0
    for arg in "$@"; do
        if [[ "$arg" == "--init" ]]; then
            init_flag=1
            break
        fi
    done

    # Set up auto-activation if --init flag is present
    if [[ $init_flag -eq 1 ]]; then
      echo "Initializing auto-activation"
      if [[ -z "$PROMPT_COMMAND" ]]; then
          echo "Setting PROMPT_COMMAND to auto_env"
          PROMPT_COMMAND="auto_env"
      elif [[ "$PROMPT_COMMAND" != *auto_env* ]]; then
          echo "Adding auto_env to existing PROMPT_COMMAND"
          PROMPT_COMMAND="auto_env; $PROMPT_COMMAND"
      fi
    fi

    # Run auto_env if shell is interactive
    if [[ $- == *i* ]]; then
      TARGET_DIRECTORIES=("$PWD")
      activate_env
    else
      if [[ $TEST_MODE -ne 1 ]]; then
        echo "Error: Shell is not interactive"
      fi
    fi
}
# Execute setup with all arguments passed to the script
setup_auto_activation "$@"
