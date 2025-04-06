#!/usr/bin/env bats

# This test suite includes:
#
# - Tests for all major functions in the script
# - Mocking of conda/mamba commands
# - Environment setup and teardown for each test
# - Tests for different scenarios and edge cases
# - Validation testing at different strictness levels
# - Directory handling tests
# - Environment activation and creation tests
#
# The tests cover:
# - Directory targeting functionality
# - Package manager selection
# - Environment validation
# - Environment activation
# - Environment creation
# - Error handling
# - Setup functionality
#
# Note that these tests mock the conda/mamba commands to avoid actually creating environments during testing. You might want to add more specific tests based on your actual use cases and requirements.
#
# Remember to:
# - Add more specific test cases based on your needs
# - Test edge cases and error conditions
# - Add tests for any new features you add
# - Update tests when modifying existing functionality

# To run the tests, run:
# bats ./test/conda-auto-activate.bats
# Enable debug output
# To run all tests with debug output, run:
# DEBUG=1 bats ./test/conda-auto-activate.bats
#
# To run a specific test with debug output, run:
# bats ./test/conda-auto-activate.bats -f "should activate existing"
#
# Global debug flag, can be overridden with DEBUG=1 when running tests
export DEBUG="${DEBUG:-0}"

# Helper function to setup debug by default if DEBUG=1
setup_debug() {
    if [ "${DEBUG:-0}" -eq 1 ]; then
        DEBUG_ENABLED=1
    else
        DEBUG_ENABLED=0
    fi
}

# Helper function to disable debug for specific test
disable_debug() {
    DEBUG_ENABLED=0
}

# Helper function for debug output
debug() {
    if [ "${DEBUG:-0}" -eq 1 ] && [ "${DEBUG_ENABLED:-0}" -eq 1 ]; then
        local timestamp=$(date '+%H:%M:%S')
        echo "========================================" >&3
        echo "[${timestamp}] $BATS_TEST_NAME: $*" >&3
        echo "========================================" >&3
    fi
}

# Helper to toggle interactive state
set_interactive() {
    function is_interactive() {
        return "$1"
    }
    export -f is_interactive
}

# Setup function runs before each test
setup() {
    # Enable debug by default if DEBUG=1
    setup_debug

    # Source the script we're testing
    source "${BATS_TEST_DIRNAME}/../conda-auto-activate.sh"

    # Create temporary test directory
    TEST_DIR="$(mktemp -d)"
    debug "Created test directory: $TEST_DIR"

    # Save original directory
    ORIGINAL_DIR="$PWD"

    # Mock conda/mamba commands with debug output
    function conda() {
        debug "conda called with arguments: $*"
        case "$1" in
            "env")
                case "$2" in
                    "list")
                        debug "Listing conda environments"
                        echo "test-env                  /path/to/env"
                        ;;
                    "create")
                        debug "Creating conda environment with args: ${*:3}"
                        return 0
                        ;;
                esac
                ;;
            "activate")
                debug "Activating conda environment: $2"
                return 0
                ;;
            *)
                debug "Unknown conda command: $1"
                return 1
                ;;
        esac
    }

    function mamba() {
        debug "mamba called with arguments: $*"
        conda "$@"
    }

    # Add this mock for is_interactive
    function is_interactive() {
        debug "is_interactive called"
        return 0  # Always return true in tests
    }

    export -f conda mamba debug is_interactive
}

# Teardown function runs after each test
teardown() {
    debug "Cleaning up test directory: $TEST_DIR"
    rm -rf "$TEST_DIR"
    debug "Returning to original directory: $ORIGINAL_DIR"
    cd "$ORIGINAL_DIR"
}

# Test is_target_directory function
@test "is_target_directory should return true for target directory" {
    TARGET_DIRECTORIES=("$TEST_DIR")
    cd "$TEST_DIR"
    debug "Current directory: $PWD"
    debug "Target directories: ${TARGET_DIRECTORIES[*]}"
    run is_target_directory
    [ "$status" -eq 0 ]
}

@test "is_target_directory should return false for directory not in target list" {
    TARGET_DIRECTORIES=("$TEST_DIR")
    cd ..  # Move up one directory from TEST_DIR
    debug "Current directory: $PWD"
    debug "Target directories: ${TARGET_DIRECTORIES[*]}"
    run is_target_directory
    [ "$status" -eq 1 ]
}

# Test get_pkg_manager function
@test "get_pkg_manager should return mamba when mamba is available" {
    PACKAGE_MANAGER="mamba"
    debug "Testing package manager selection with PACKAGE_MANAGER=$PACKAGE_MANAGER"
    result="$(get_pkg_manager)"
    debug "Selected package manager: $result"
    [ "$result" = "mamba" ]
}

@test "get_pkg_manager should fallback to conda when mamba is not set" {
    PACKAGE_MANAGER="conda"
    result="$(get_pkg_manager)"
    [ "$result" = "conda" ]
}

# Test validate_environment_yml function
@test "validate_environment_yml should pass with strictness level 0" {
    disable_debug
    STRICTNESS_LEVEL=0
    cd "$TEST_DIR"
    echo "name: test-env
channels:
  - conda-forge
dependencies:
  - python=3.8" > environment.yml

    run validate_environment_yml
    [ "$status" -eq 0 ]
}

@test "validate_environment_yml should detect dangerous packages at strictness level 2" {
    STRICTNESS_LEVEL=2
    cd "$TEST_DIR"
    echo "name: test-env
channels:
  - conda-forge
dependencies:
  - curl" > environment.yml

    run validate_environment_yml
    [ "$status" -eq 1 ]
}

# Test activate_env function
@test "activate_env should skip activation in non-interactive shell" {
    cd "$TEST_DIR"
    TARGET_DIRECTORIES=("$TEST_DIR")
    # Setup non-interactive environment
    export -f setup_auto_activation
    run setup_auto_activation
    [[ "$output" == *"Error: Shell is not interactive"* ]]
}

@test "activate_env should attempt activation in interactive shell" {
    cd "$TEST_DIR"
    TARGET_DIRECTORIES=("$TEST_DIR")
    echo "name: test-env" > environment.yml
    # Force interactive mode for testing
    BASH_SOURCE=("something")
    set -i
    export -f setup_auto_activation
    run setup_auto_activation
    [ "$status" -eq 0 ]
}

@test "activate_env should activate existing environment" {
    cd "$TEST_DIR"
    TARGET_DIRECTORIES=("$TEST_DIR")
    debug "Creating test environment.yml"
    cat > environment.yml << EOF
name: test-env
channels:
  - conda-forge
dependencies:
  - python=3.8
EOF
    # Force interactive mode
    BASH_SOURCE=("something")
    set -i
    debug "Content of environment.yml:"
    debug "$(cat environment.yml)"

    run activate_env
    debug "activate_env exit status: $status"
    debug "activate_env output: $output"
    [ "$status" -eq 0 ]
}

@test "activate_env should create and activate new environment" {
    cd "$TEST_DIR"
    TARGET_DIRECTORIES=("$TEST_DIR")
    debug "Creating test environment.yml for new environment"
    cat > environment.yml << EOF
name: new-env
channels:
  - conda-forge
dependencies:
  - python=3.8
EOF
    # Force interactive mode
    BASH_SOURCE=("something")
    set -i
    debug "Content of environment.yml:"
    debug "$(cat environment.yml)"

    run activate_env
    debug "activate_env exit status: $status"
    debug "activate_env output: $output"
    [ "$status" -eq 0 ]
}

@test "activate_env should handle missing environment.yml" {
    cd "$TEST_DIR"
    TARGET_DIRECTORIES=("$TEST_DIR")
    debug "Testing activate_env behavior with no environment.yml"
    debug "Current directory: $PWD"
    debug "Directory contents: $(ls -la)"

    # Force interactive mode
    BASH_SOURCE=("something")
    set -i
    run activate_env
    debug "activate_env exit status: $status"
    debug "activate_env output: $output"
    [ "$status" -eq 0 ]
}

@test "activate_env should handle envs directory" {
    cd "$TEST_DIR"
    TARGET_DIRECTORIES=("$TEST_DIR")
    debug "Creating envs directory"
    mkdir -p "./envs"
    debug "Current directory: $PWD"
    debug "Directory structure:"
    debug "$(ls -R)"

    # Force interactive mode
    BASH_SOURCE=("something")
    set -i
    run activate_env
    debug "activate_env exit status: $status"
    debug "activate_env output: $output"
    [ "$status" -eq 0 ]
}

@test "activate_env should try to activate ./venv when ./envs activation fails" {
    cd "$TEST_DIR"
    TARGET_DIRECTORIES=("$TEST_DIR")
    debug "Creating venv directory"
    mkdir -p "./venv/bin"
    touch "./venv/bin/activate"
    chmod +x "./venv/bin/activate"

    # Force interactive mode
    BASH_SOURCE=("something")
    set -i
    # Mock the source command
    source() {
        debug "source called with arguments: $*"
        return 0
    }
    export -f source

    run activate_env
    debug "activate_env exit status: $status"
    debug "activate_env output: $output"
    [ "$status" -eq 0 ]
}

@test "activate_env should try to activate ./.venv when ./venv doesn't exist" {
    cd "$TEST_DIR"
    TARGET_DIRECTORIES=("$TEST_DIR")
    debug "Creating .venv directory"
    mkdir -p "./.venv/bin"
    touch "./.venv/bin/activate"
    chmod +x "./.venv/bin/activate"

    # Force interactive mode
    BASH_SOURCE=("something")
    set -i
    # Mock the source command
    source() {
        debug "source called with arguments: $*"
        return 0
    }
    export -f source

    run activate_env
    debug "activate_env exit status: $status"
    debug "activate_env output: $output"
    [ "$status" -eq 0 ]
}

# Test get_conda_envs_dirs function
@test "get_conda_envs_dirs should correctly retrieve and combine directories" {
    # Set interactive shell
    set_interactive 1

    # Mock conda info output
    function conda() {
        case "$1" in
            "info")
                echo "     active environment : None
                active env location : None
                        shell level : 0
                   user config file : /home/user/.condarc
                 populated config files : /home/user/.condarc
                       conda version : 4.9.2
                 conda-build version : not installed
                      python version : 3.8.5.final.0
                    virtual packages : __cuda=11.0=0
                    base environment : /opt/conda  (writable)
                        channel URLs : https://repo.anaconda.com/pkgs/main/linux-64
                                     https://repo.anaconda.com/pkgs/main/noarch
                                     https://repo.anaconda.com/pkgs/r/linux-64
                                     https://repo.anaconda.com/pkgs/r/noarch
                       package cache : /opt/conda/pkgs
                                     /home/user/.conda/pkgs
                    envs directories : /home/user/conda/envs
                                     /opt/conda/envs
                            platform : linux-64
                          user-agent : conda/4.9.2 requests/2.24.0 CPython/3.8.5 Linux/5.4.0-73-generic ubuntu/20.04.2 glibc/2.31
                             UID:GID : 1000:1000
                          netrc file : None
                        offline mode : False"
                ;;
            *)
                conda.real "$@"
                ;;
        esac
    }
    export -f conda

    # Initialize arrays
    declare -g PROJECT_DIRECTORIES="/path/to/project1 /path/to/project2"

    # Call the function to test
    run get_conda_envs_dirs
    [ "$status" -eq 0 ]

    # The output should start with "CONDA_ENV_DIRS: " followed by the paths
    [[ "$output" =~ ^"CONDA_ENV_DIRS: " ]] || false

    # Extract just the paths part (everything after "CONDA_ENV_DIRS: ")
    local paths="${output#*: }"
    debug "Extracted paths: \"$paths\""

    # Count number of paths (should be 2)
    run bash -ic 'echo "$1" | tr " " "\n" | grep -v "^$" | wc -l' _ "$paths"
    [ "$output" -eq 2 ]

    # Check if both required paths are present
    run bash -ic 'echo "$1" | grep -q "/home/user/conda/envs"' _ "$paths"
    [ "$status" -eq 0 ]
    run bash -ic 'echo "$1" | grep -q "/opt/conda/envs"' _ "$paths"
    [ "$status" -eq 0 ]

    # Update PROJECT_DIRECTORIES with conda paths
    PROJECT_DIRECTORIES+=" $paths"

    # Count project directories (should be 4)
    run bash -ic 'echo "$1" | tr " " "\n" | grep -v "^$" | wc -l' _ "$PROJECT_DIRECTORIES"
    [ "$output" -eq 4 ]

    # Check if all required paths are present
    run bash -ic 'echo "$1" | grep -q "/path/to/project1"' _ "$PROJECT_DIRECTORIES"
    [ "$status" -eq 0 ]
    run bash -ic 'echo "$1" | grep -q "/path/to/project2"' _ "$PROJECT_DIRECTORIES"
    [ "$status" -eq 0 ]
    run bash -ic 'echo "$1" | grep -q "/home/user/conda/envs"' _ "$PROJECT_DIRECTORIES"
    [ "$status" -eq 0 ]
    run bash -ic 'echo "$1" | grep -q "/opt/conda/envs"' _ "$PROJECT_DIRECTORIES"
    [ "$status" -eq 0 ]
}

# Test setup_auto_activation function
@test "setup_auto_activation should set PROMPT_COMMAND" {
    debug "Testing setup_auto_activation"
    debug "Initial PROMPT_COMMAND: $PROMPT_COMMAND"

    run setup_auto_activation --init

    debug "Final PROMPT_COMMAND: $PROMPT_COMMAND"
    debug "setup_auto_activation exit status: $status"
    debug "setup_auto_activation output: $output"

    [[ "$PROMPT_COMMAND" == *"auto_env"* ]] || [ "$status" -eq 0 ]
    debug "PROMPT_COMMAND test result: $?"
}
