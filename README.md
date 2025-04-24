# auto-py-env

auto-py-env is a tool that automatically activates conda environments when navigating to directories containing an `environment.yml` file or an `/envs` directory within a shell. It can also create an environment if it doesn't exist yet.

Inspired by [conda-auto-env](https://github.com/chdoig/conda-auto-env).

**Features**:

- Automatic terminal setup.
- Support for both conda and mamba package managers--works if you keep mamba environments separate from conda environments.
- Runs in specified directories only.
- Supports self contained projects not located in your conda base environment.
- Validation of `environment.yml` files to ensure they are safe to use.
- Direct activation of conda environments from the command line.

## Installation

For automatic operation, integrate the script into your shell configuration by adding the following line to your shell's rc file (e.g., `~/.bashrc`):

```sh
source /path/to/auto-py-env.sh --init
```

Replace `/path/to/auto-py-env.sh` with the actual path to the `auto-py-env.sh` script.

If using STRICTNESS_LEVEL 1 and above, if you want to use the optional linting feature, you'll need to install yamllint: `sudo
apt install yamllint` or `sudo pacman install yamllint` or `sudo dnf install yamllint` depending on your distribution.

:warning: This script will not work if you don't set the `ENV_DIRECTORIES` variable in the script. See the [Configuration](#configuration) section for more details.

## Usage

### Automatic Activation

Nothing to do, the script will automatically activate the environment when you enter a monitored directory with an `environment.yml` file or an `/envs` directory..

### Manual Activation

If you want to override the specified directories or not use automatic activation, you can manually run the script:

```sh
cd /desired/directory
source /path/to/auto-py-env.sh
```

### Environment Creation

When the script finds an environment.yml file, it will automatically create an environment if it doesn't exist yet. If
the current directory is in your default conda envs paths, it will create the environment there. Otherwise, it will create it in the ./envs directory of the current working directory.

E.g., if you have an `environment.yml` file in `/path/to/project`, the script will create an environment named `project` in `/path/to/project/envs`.
E.g., if your default conda envs path is `/path/to/envs`, the script will create an environment named `project` in `/path/to/envs`.

## Configuration

The script has two groups of configuration options:

1. **Mandatory**:
   - `ENV_DIRECTORIES`: Specifies which directories are monitored for conda activation.
2. **Optional**:

- `PACKAGE_MANAGER`: Specifies the package manager to use. Can be either `conda` or `mamba`. Defaults to `mamba`.
  - `STRICTNESS_LEVEL`: Controls the validation checks run on `environment.yml`. Defaults to `1`.
  - `DANGEROUS_PACKAGES`: List of dangerous packages to check for in `environment.yml`.
  - `TRUSTED_CHANNELS`: List of trusted channels to check for in `environment.yml`. Defaults to `conda-forge` and `defaults`.

### ENV_DIRECTORIES

List the directories where `auto-py-env` should look for `environment.yml` files or `/envs` directories. This is useful if you want to restrict automatic activation to certain parts of your file system.

Modify the list in `auto-py-env.sh`:

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

Set the level in `auto-py-env.sh`:

```bash
STRICTNESS_LEVEL=1
```

#### Validation Checks

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

- Conda/Mamba has to have been run before the script is sourced. If you're getting errors, make sure you have run `conda init bash` or `mamba init bash` at least once.
- Ensure the `yamllint` tool is installed if using validation levels 1 or 2.
- If an error occurs during activation or creation, check your `environment.yml` for syntax errors or invalid configurations.
- If the script does not seem to activate environments, verify that your `TARGET_DIRECTORIES` are correctly set and match the directories you are navigating.

## Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/stephanbrez/auto-py-env/issues) to get involved.
