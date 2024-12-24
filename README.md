# conda-auto-activate

conda-auto-activate is a tool that automatically activates conda environments when navigating to directories containing an `environment.yml` file or an `/envs` directory within a shell. It can also create an environment if it doesn't exist yet.

Inspired by [conda-auto-env](https://github.com/chdoig/conda-auto-env).

## Installation

For automatic operation, integrate the script into your shell configuration by adding the following line to your shell's rc file (e.g., `~/.bashrc`):

```sh
source /path/to/conda-auto-activate.sh
```

Replace `/path/to/conda-auto-activate.sh` with the actual path to the `conda-auto-activate.sh` script.

## Usage

1. **Automatic Activation**: When configured, the script activates an environment upon entering a monitored directory with an `environment.yml` file or an `/envs` directory.
2. **Environment Creation**: If the specified environment in `environment.yml` does not exist, the script will create it automatically.

### Manual Activation

If you prefer manual operation:

```sh
cd /desired/directory
bash /path/to/conda-auto-activate.sh
```

## Configuration

The script can be customized via two main configuration options:

1. **ENV_DIRECTORIES**: Specifies which directories are monitored for conda activation.
2. **STRICTNESS_LEVEL**: Controls the validation checks run on `environment.yml`.

### ENV_DIRECTORIES

List the directories where `conda-auto-activate` should look for `environment.yml` files or `/envs` directories. This is useful if you want to restrict automatic activation to certain parts of your file system.

Modify the list in `conda-auto-activate.sh`:

```bash
ENV_DIRECTORIES=(
  "/path/to/dir1"
  "/path/to/dir2"
  "/path/to/dir3"
)
```
%% TODO: Add an example for how to allow all env directories %%

### STRICTNESS_LEVEL

Defines the level of validation applied to `environment.yml` files:

- `0`: Skip validation.
- `1`: Basic validation with `yamllint` and external command checks.
- `2`: Full validation with additional checks for dangerous packages and untrusted channels.

Set the level in `conda-auto-activate.sh`:

```bash
STRICTNESS_LEVEL=1
```

#### Validation Checks:

- **No VALIDATION (Level 0)**: No validation checks are performed.
- **Basic Validation (Level 1)**: Checks for valid YAML syntax using `yamllint` and warns about potential dangerous command invocations like `curl`, `wget`, etc.
- **Full Validation (Level 2)**:
  - Performs validation checks at Level 1.
  - Checks for dangerous packages listed in `environment.yml` using the `DANGEROUS_PACKAGES` array.
  - Validates the trust level of channels specified in `environment.yml` using the `TRUSTED_CHANNELS` array.

To customize these checks, modify:

```bash
DANGEROUS_PACKAGES=("curl" "wget" "bash" "sh" "python-pip" "git")
TRUSTED_CHANNELS=("conda-forge" "defaults")
```

### Troubleshooting

- Ensure the `yamllint` tool is installed if using validation levels 1 or 2.
- If an error occurs during activation or creation, check your `environment.yml` for syntax errors or invalid configurations.
- If the script does not seem to activate environments, verify that your `TARGET_DIRECTORIES` are correctly set and match the directories you are navigating.

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/stephanbrez/conda-auto-activate/issues) to get involved.
