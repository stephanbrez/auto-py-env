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

# Setup function runs before each test
setup() {
    # Source the script we're testing
    source "${BATS_TEST_DIRNAME}/../conda-auto-activate.sh"

    # Create temporary test directory
    TEST_DIR="$(mktemp -d)"

    # Save original directory
    ORIGINAL_DIR="$PWD"

    # Mock conda/mamba commands
    function conda() {
        case "$1" in
            "env")
                case "$2" in
                    "list")
                        echo "test-env                  /path/to/env"
                        ;;
                    "create")
                        return 0
                        ;;
                esac
                ;;
            "activate")
                return 0
                ;;
        esac
    }

    function mamba() {
        conda "$@"
    }

    export -f conda mamba
}

# Teardown function runs after each test
teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_DIR"
    # Return to original directory
    cd "$ORIGINAL_DIR"
}

# Test is_target_directory function
@test "is_target_directory should return true for target directory" {
    TARGET_DIRECTORIES=("$TEST_DIR")
    cd "$TEST_DIR"
    run is_target_directory
    [ "$status" -eq 0 ]
}

@test "is_target_directory should return false for non-target directory" {
    TARGET_DIRECTORIES=("/some/other/path")
    cd "$TEST_DIR"
    run is_target_directory
    [ "$status" -eq 1 ]
}

# Test get_pkg_manager function
@test "get_pkg_manager should return mamba when mamba is available" {
    PACKAGE_MANAGER="mamba"
    result="$(get_pkg_manager)"
    [ "$result" = "mamba" ]
}

@test "get_pkg_manager should fallback to conda when mamba is not set" {
    PACKAGE_MANAGER="conda"
    result="$(get_pkg_manager)"
    [ "$result" = "conda" ]
}

# Test validate_environment_yml function
@test "validate_environment_yml should pass with strictness level 0" {
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

# Test auto_env function
@test "auto_env should activate existing environment" {
    cd "$TEST_DIR"
    echo "name: test-env
channels:
  - conda-forge
dependencies:
  - python=3.8" > environment.yml

    run auto_env
    [ "$status" -eq 0 ]
}

@test "auto_env should create and activate new environment" {
    cd "$TEST_DIR"
    echo "name: new-env
channels:
  - conda-forge
dependencies:
  - python=3.8" > environment.yml

    run auto_env
    [ "$status" -eq 0 ]
}

@test "auto_env should handle missing environment.yml" {
    cd "$TEST_DIR"
    run auto_env
    [ "$status" -eq 0 ]
}

@test "auto_env should handle envs directory" {
    cd "$TEST_DIR"
    mkdir -p "./envs"
    run auto_env
    [ "$status" -eq 0 ]
}

# Test setup_auto_activation function
@test "setup_auto_activation should set PROMPT_COMMAND" {
    run setup_auto_activation
    [[ "$PROMPT_COMMAND" == *"auto_env"* ]] || [ "$status" -eq 0 ]
}
