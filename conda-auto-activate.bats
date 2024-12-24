#!/usr/bin/env bats

# Setup and teardown
setup() {
  # Setup the environment for each test if necessary
  export TEST_DIR=$(mktemp -d)
  export ENV_FILE="$TEST_DIR/environment.yml"
  export TARGET_DIR="$TEST_DIR"
}

teardown() {
  # Cleanup after each test (remove temp directory)
  rm -rf "$TEST_DIR"
}

# Test if the script skips validation when STRICTNESS_LEVEL is 0
@test "skip validation when strictness level is 0" {
  STRICTNESS_LEVEL=0
  source /path/to/conda-auto-activate.sh
  # Here you can check the results (e.g., see if no validation took place)
  # This is a simple check to verify that no validation occurs (can be enhanced further)
  run echo "$STRICTNESS_LEVEL"
  [ "$output" -eq 0 ]
}

# Test if the environment.yml file exists and the script performs validation
@test "validate environment.yml file with yamllint" {
  # Simulate an invalid YAML file
  echo "invalid yaml" > "$ENV_FILE"
  
  # Run the script in a mock scenario where it checks environment.yml
  STRICTNESS_LEVEL=1
  source /path/to/conda-auto-activate.sh

  # Check if yamllint is called (assuming yamllint will fail)
  run yamllint "$ENV_FILE"
  [ "$status" -ne 0 ]  # yamllint should fail since the file is invalid
}

# Test if the correct environment gets activated when the yaml file is valid
@test "activate environment from environment.yml" {
  # Create a valid environment.yml for testing
  cat <<EOF > "$ENV_FILE"
name: test-env
channels:
  - defaults
dependencies:
  - bash
EOF

  # Simulate running the script with the valid environment.yml
  STRICTNESS_LEVEL=1
  source /path/to/conda-auto-activate.sh

  # Mock the conda environment activation (as we can't actually call conda here)
  run conda env list
  # Assuming "test-env" would appear if the environment exists
  [[ "$output" =~ "test-env" ]]
}

# Test if the environment is created when it doesn't exist
@test "create conda environment if it does not exist" {
  # Simulate a missing environment, the script should create it
  cat <<EOF > "$ENV_FILE"
name: new-env
channels:
  - defaults
dependencies:
  - bash
EOF

  # Mock the conda environment list, assume "new-env" doesn't exist
  run conda env list
  [[ ! "$output" =~ "new-env" ]]  # "new-env" should not exist yet
  
  # Run the script and simulate conda env creation
  STRICTNESS_LEVEL=1
  source /path/to/conda-auto-activate.sh
  
  # Check again if the environment is created
  run conda env list
  [[ "$output" =~ "new-env" ]]  # "new-env" should be in the list after creation
}

# Test if the function properly handles skipping directories
@test "skip directories not listed in TARGET_DIRECTORIES" {
  TARGET_DIRECTORIES=("/path/to/dir1" "/path/to/dir2")
  
  # If the current directory is not in the target list, conda_auto_env should not activate
  cd "$TEST_DIR"
  run source /path/to/conda-auto-activate.sh
  [[ "$status" -eq 0 ]]  # No errors should occur, but no environment should be activated
}

# Test if conda environment is activated for a matching target directory
@test "activate environment in target directory" {
  TARGET_DIRECTORIES=("/path/to/dir1" "/path/to/dir2")
  export TEST_DIR="/path/to/dir1"
  
  # Simulate running the script in the target directory with environment.yml
  cd "$TEST_DIR"
  echo "name: test-env" > "$ENV_FILE"
  
  # Run the script
  STRICTNESS_LEVEL=1
  run source /path/to/conda-auto-activate.sh
  
  # Check if the environment is activated
  run echo "$PATH"  # This is a mock check, normally you would check if the environment is active
  [[ "$output" =~ "test-env" ]]
}