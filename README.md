# conda-auto-activate

Automatically activate conda environments when navigating to them in a shell.

conda-auto-activate will additionally create an environment from an environment.yml file if it doesn't already exist.

Inspired by [conda-auto-env](https://github.com/chdoig/conda-auto-env)

## Installation

For automatic operation, add the following line to your shell's rc file (e.g. ~/.bashrc):

```
source /path/to/conda-auto-activate
```

## Usage

The script will automatically activate the environment when you navigate into a
directory in a shell. For detecting environments, it will look for an **environment.yml** file
or a **/envs** directory in the current directory.

If you don't want it running automatically, skip the install step and run `conda-auto-activate` manually from the command line:

```
cd /path/to/conda/environment
bash /path/to/conda-auto-activate
```

## Configuration

There are two main configuration options:

1. TARGET_DIRECTORIES
1. STRICTNESS_LEVEL

### TARGET_DIRECTORIES

The list of directories that will be checked for environment files.
Add directories to the list as quoted strings, e.g.:

```
"/path/to/dir1"
"/path/to/dir2"
"/path/to/dir3"
```

### STRICTNESS_LEVEL

Defines how strict the script should be when validating environment files.
Set the value to one of the following:

- 0 = Skip validation
- 1 = Run basic validation (yamllint, external commands check)
- 2 = Run full validation (yamllint, dangerous packages, untrusted channels, external commands)
