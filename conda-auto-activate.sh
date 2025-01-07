#!/usr/bin/env bash

# conda-auto-activate automatically activates a conda environment when
# entering a folder with an environment.yml file or /envs/ folder
#
# If the environment doesn't exist, conda-auto-activate creates and
# activates it for you.
#
# To install, add this line to your .bashrc or .bash-profile:
#
#       source /path/to/conda-auto-activate.sh
#

# ********** User settings ********** #

# TODO: Set the target directory to current directory if running directly
# Package manager to use: "conda" or "mamba"
PACKAGE_MANAGER="mamba"

# List of directories to check for environment.yml and its children
# Modify this to the directories you want to trigger the environment activation in
ENV_DIRECTORIES=(
    "/path/to/dir1"
    "/path/to/dir2"
    "/path/to/dir3"
  )

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

# Script is being sourced, set to user defined ENV_DIRECTORIES
if [ -z "$TARGET_DIRECTORIES" ]; then
  TARGET_DIRECTORIES=("${ENV_DIRECTORIES[@]}")
fi

# Function to check if the current directory is in one of the target directories or its subdirectories
function is_target_directory() {
  current_dir=$(pwd)
  for target_dir in "${TARGET_DIRECTORIES[@]}"; do
    if [[ "$current_dir" == *"$target_dir"* ]]; then
      return 0  # True, the current directory or its parent is one of the target directories
    fi
  done
  echo "Error: Not in any of the target directories or their subdirectories." >&2
  return 1  # False, not in any of the target directories or their subdirectories
}

# Function to get & set the active package manager
function get_pkg_manager() {
    # First ensure conda/mamba is initialized
    if [[ "$PACKAGE_MANAGER" == "mamba" ]]; then
        # Check if mamba exists in path
        if command -v mamba >/dev/null 2>&1; then
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
    check_trusted_channel
  fi

  echo "environment.yml is valid and safe."
}

# Function to automatically activate the conda environment or create it if necessary


# Function to automatically activate the conda environment or create it if necessary
function auto_env() {
  local pkg_mgr env_name
  pkg_mgr=$(get_pkg_manager)

  # Check if we're in a target directory before proceeding
  is_target_directory || return 0

  # Check if environment.yml exists and run validation
  if [[ -f "environment.yml" && -r "environment.yml" ]]; then
    if ! validate_environment_yml; then
        echo "Error: Environment validation failed" >&2
        return 1
    fi

    # Extract the environment name by finding the first non-comment line with 'name:' and taking the value after it
    env_name=$(grep -m 1 '^[^#]*name:' environment.yml | awk '{print $2}')
    # Validate environment name
    if [[ -z "$env_name" ]]; then
        echo "Error: Could not determine environment name from environment.yml" >&2
        return 1
    fi

    # Check if the environment is not already active
    if [[ "${CONDA_PREFIX##*/}" != "$env_name" ]]; then
      # Check if the environment exists
      if env_path=$(conda env list | awk -v env="$env_name" '$0 ~ env {print $NF; exit}') && [[ -n "$env_path" ]]; then

        # Check if 'mamba' exists in the path to determine package manager
        if echo "$env_path" | grep -q "mamba"; then
            original_pkg_mgr="mamba"
        else
            original_pkg_mgr="conda"
        fi
        # If the environment exists, activate it
        echo "Activating existing $original_pkg_mgr environment '$env_name'..."
        if ! $original_pkg_mgr activate "$env_name"; then
          echo "Error: Failed to activate environment '$env_name'" >&2
          return 1
        fi
      else
        # If the environment doesn't exist, create it and activate
        echo "$pkg_mgr environment '$env_name' doesn't exist. Creating and activating..."
        if ! $pkg_mgr env create -f environment.yml -q; then
          echo "Error: Failed to create environment '$env_name'" >&2
          return 1
        fi
        if ! $pkg_mgr activate "$env_name"; then
          echo "Error: Failed to activate newly created environment '$env_name'" >&2
          return 1
        fi
      fi
    fi
  elif [[ -d "./envs" && -x "./envs" ]]; then
    # If environment.yml is not present, check for an ./envs directory
    echo "Environment.yml not found, attempting to activate ./envs..."
    if ! $pkg_mgr activate "./envs"; then
      echo "Error: Failed to activate ./envs directory." >&2
      return 1
    fi
  fi
}

# Main script logic that combines interactive shell and sourcing check
# Function to automatically setup environment auto-activation if interactive
function setup_auto_activation() {
    # Check if being executed directly
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo "Script is being executed directly"
        echo "This script is meant to be sourced and not executed directly."
        echo "Run 'source /path/to/conda-auto-activate.sh'."
        return 1
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
        auto_env
    else
        echo "Error: Shell is not interactive"
    fi
}
# Execute setup with all arguments passed to the script
setup_auto_activation "$@"
