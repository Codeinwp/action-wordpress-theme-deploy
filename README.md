# WordPress.org Theme Deploy

> Deploy your theme to the WordPress.org repository using GitHub Actions. A fork of [10up/action-wordpress-plugin-deploy](https://github.com/10up/action-wordpress-plugin-deploy)

This Action commits the contents of your Git tag to the WordPress.org themes repository using the same tag name. It can exclude files as defined in either `.distignore` or `.gitattributes`.

## Configuration

### Required secrets
* `SVN_USERNAME`
* `SVN_PASSWORD`

[Secrets are set in your repository settings](https://help.github.com/en/actions/automating-your-workflow-with-github-actions/creating-and-using-encrypted-secrets). They cannot be viewed once stored.

### Optional environment variables
* `SLUG` - defaults to the repository name, customizable in case your WordPress repository has a different slug or is capitalized differently.
* `VERSION` - defaults to the tag name; do not recommend setting this except for testing purposes.
* `BUILD_DIR` - defaults to `false`. Set this flag to the directory where you build your theme files into, then the action will copy and deploy files from that directory. Both absolute and relative paths are supported. The relative path if provided will be concatenated with the repository root directory. All files and folders in the build directory will be deployed, `.disignore` or `.gitattributes` will be ignored.

## Excluding files from deployment
If there are files or directories to be excluded from deployment, such as tests or editor config files, they can be specified in either a `.distignore` file or a `.gitattributes` file using the `export-ignore` directive. If a `.distignore` file is present, it will be used; if not, the Action will look for a `.gitattributes` file and barring that, will write a basic temporary `.gitattributes` into place before proceeding so that no Git/GitHub-specific files are included.

`.distignore` is useful particularly when there are built files that are in `.gitignore`, and is a file that is used in [WP-CLI](https://wp-cli.org/). For modern theme setups with a build step and no built files committed to the repository, this is the way forward. `.gitattributes` is useful for theme that don't run a build step as a part of the Actions workflow and also allows for GitHub's generated ZIP files to contain the same contents as what is committed to WordPress.org. If you would like to attach a ZIP file with the proper contents that decompresses to a folder name without version number as WordPress generally expects, you can add steps to your workflow that generate the ZIP and attach it to the GitHub release (concrete examples to come).

### Sample baseline files

#### `.distignore`

**Notes:** `.distignore` is for files to be ignored **only**; it does not currently allow negation like `.gitignore`. This comes from its current expected syntax in WP-CLI's [`wp dist-archive` command](https://github.com/wp-cli/dist-archive-command/). It is possible that this Action will allow for includes via something like a `.distinclude` file in the future, or that WP-CLI itself makes a change that this Action will reflect for consistency. It also will need to contain more than `.gitattributes` because that method **also** respects `.gitignore`.

```
/.wordpress-org
/.git
/.github
/node_modules

.distignore
.gitignore
```

#### `.gitattributes`

```gitattributes
# Directories
/.wordpress-org export-ignore
/.github export-ignore

# Files
/.gitattributes export-ignore
/.gitignore export-ignore
```


## Example Workflow Files

To get started, you will want to copy the contents of one of these examples into `.github/workflows/deploy.yml` and push that to your repository. You are welcome to name the file something else, but it must be in that directory. The usage of `ubuntu-latest` is recommended for compatibility with required dependencies in this Action.

### Deploy on pushing a new tag

```yml
name: Deploy to WordPress.org
on:
  push:
    tags:
    - "*"
jobs:
  tag:
    name: New tag
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@master
    - name: Build # Remove or modify this step as needed
      run: |
        npm install
        npm run build
    - name: WordPress Theme Deploy
      uses: HardeepAsrani/action-wordpress-theme-deploy@primary
      env:
        SVN_PASSWORD: ${{ secrets.SVN_PASSWORD }}
        SVN_USERNAME: ${{ secrets.SVN_USERNAME }}
        SLUG: my-theme # optional, remove if GitHub repo name matches SVN slug, including capitalization
```
