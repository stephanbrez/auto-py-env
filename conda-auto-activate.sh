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
  TARGET_DIRECTORIES=$ENV_DIRECTORIES
fi

# Function to check if the current directory is in one of the target directories or its subdirectories
function is_target_directory() {
  current_dir=$(pwd)
  for target_dir in "${TARGET_DIRECTORIES[@]}"; do
    if [[ "$current_dir" == *"$target_dir"* ]]; then
      return 0  # True, the current directory or its parent is one of the target directories
    fi
  done
  return 1  # False, not in any of the target directories or their subdirectories
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
  local line
  while read -r line; do
    for channel in $line; do
      if [[ "$channel" =~ "channel" ]]; then
        # Extract the channel name following the colon
        local channel_name=$(echo "$channel" | sed 's/^[^:]*:\s*//')
        if [[ ! " ${TRUSTED_CHANNELS[@]} " =~ " ${channel_name} " ]]; then
          echo "Warning: Untrusted channel '$channel_name' detected in environment.yml."
          exit 1
        fi
      fi
    done
  done < <(grep "channel" environment.yml)
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
    if grep -E '(curl|wget|bash|sh|python|git)' environment.yml; then
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
function conda_auto_env() {
  # Only check if we are in a directory that matches one of the target directories
  if ! is_target_directory; then
    return 0  # Not in a target directory, skip further processing
  fi

  # Check if environment.yml exists and run validation only if it does
  if [ -e "environment.yml" ]; then
    # Run the validation function first
    validate_environment_yml || return 1

    # Extract the environment name by finding the first non-comment line with 'name:' and taking the value after it
    ENV=$(grep -m 1 '^[^#]*name:' environment.yml | awk '{print $2}')

    # Check if the environment is already active
    if [[ $PATH != *$ENV* ]]; then
      # Check if the environment exists
      if conda env list | grep -q "$ENV"; then
        # If the environment exists, activate it
        echo "Activating existing conda environment '$ENV'..."
        conda activate $ENV
      else
        # If the environment doesn't exist, create it and activate
        echo "Conda environment '$ENV' doesn't exist. Creating and activating..."
        conda env create -f environment.yml -q
        if [ $? -eq 0 ]; then
          conda activate $ENV
        else
          echo "Error: Failed to create conda environment '$ENV'."
          return 1
        fi
      fi
    fi
  elif [ -d "./envs" ]; then
    # If environment.yml is not present, check for an ./envs directory
    echo "Environment.yml not found, attempting to activate ./envs..."
    # If the ./envs directory exists, activate it
    conda activate ./envs
    if [ $? -ne 0 ]; then
      echo "Error: Failed to activate ./envs. Ensure it is a valid conda environment."
      return 1
    fi
  fi
}

# Main script logic that combines interactive shell and sourcing check
# Function to automatically setup environment auto-activation if interactive
function setup_auto_environment_activation() {
  if [[ "${BASH_SOURCE[0]}" != "${0}" && $- == *i* ]]; then
    # Shell is interactive and script is being sourced

    # Ensure conda_auto_env is included in the PROMPT_COMMAND for interactive shells
    if [[ "$PROMPT_COMMAND" != *conda_auto_env* ]]; then
      PROMPT_COMMAND="conda_auto_env; $PROMPT_COMMAND"
    fi

    # Call the function initially to handle the current directory
    conda_auto_env
  elif [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly, run single conda setup check
    TARGET_DIRECTORIES=("$PWD")
    conda_auto_env
  fi
}
# Execute setup 
setup_auto_environment_activation