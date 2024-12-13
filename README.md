# Confluence to Markdown

This script is designed to run on a batch HTML export from
Confluence to output a folder full of Markdown files.

This folder also contains standalone scripts for table cleanup and paragraph unwrapping.

## Requirements

- Ruby 2.6+
- Pandoc installed in $PATH (see [Installation](https://pandoc.org/installing.html))
- [Nokogiri gem installed in current Ruby](#nokogiri)

For easy installation of Ruby and Pandoc on macOS, check out
[Homebrew](https://brew.sh). With Homebrew installation is
as easy as `brew install ruby` and `brew install pandoc`.

## Usage

Run in a folder full of HTML files, or pass a single HTML
file as argument. If passing a single HTML file, optionally
specify an output file as second argument.

Run `confluence_to_md.rb -h` to see available options.

```console
Usage: confluence_to_md.rb [OPTIONS] [FILE [OUTPUT_FILE]]

Options:
    -c, --clean                      Clear output directories before converting
    -e, --[no-]strip-emoji           Strip emoji (default true)
    -f, --[no-]fix-headers           Bump all headers except first h1 (default true)
    -o, --[no-]fix-hierarchy         Fix header nesting order (default true)
    -s, --strip-meta                 Strip Confluence metadata (default false)
    -t, --[no-]convert-tables        Convert tables to Markdown (default false)
        --clean-tables               Format converted tables, only valid with --convert-tables
        --max-table-width WIDTH      If using --clean-tables, define a maximum table width
        --max-cell-width WIDTH       If using --clean-tables, define a maximum cell width. Overriden by --max_table_width
        --[no-]flatten-images        Flatten attachments folder and update links (default true)
        --[no-]rename                Rename output files based on page title (default true)
        --[no-]source                Include an HTML comment with name of original HTML file (default false)
        --stdout                     When operating on single file, output to STDOUT instead of filename
        --[no-]update-links          Update links to local files (default true)

CLI
        --color WHEN                 Colorize terminal output, "always, never, auto?"
        --[no-]colorize              Colorize command line messages with ANSI escape codes
    -d, --debug                      Display debugging info
    -h, --help                       Display help
    -v, --version                    Display version number
```

### Nokogiri

To install Nokogiri in the current gem, use:

    gem install --user-install nokogiri

If you're using a ruby version manager (asdf, rvm, rbenv,
etc.) you probably have access to install gems without
`--user-install` and can just use `gem install nokogiri`.

If these commands cause an error or the script generates an
error regarding nokogiri not being found, you may have to
install using `sudo`. This isn't recommended but will
probably solve the issue, especially if you're not running a
Ruby version manager.

    sudo gem install nokogiri

Your system password will be required.

## Standalone Scripts

### Table cleanup

```
Run with file arguments (Markdown containing tables). Cleaned output will be saved to
[FILENAME]-cleaned.md unless -o option is provided.

Usage: tablecleaner.rb [OPTIONS] [FILE [FILE]]

Options:
    -o, --output FILENAME            Save output to specified file
    -t, --max-table-width WIDTH      Define a maximum table width
    -c, --max-cell-width WIDTH       Define a maximum cell width. Overriden by --max_table_width
        --stdout                     When operating on single file, output to STDOUT instead of filename
    -h, --help                       Display help
    -v, --version                    Display version number
```

### Paragraph unwrapping

This script takes filenames as arguments or input passed on STDIN and unwraps hard-wrapped lines, respecting list items. Do not run it on Markdown containing code blocks.

```
Usage: unwrap.rb [options] [file1 file2 ...]
Pass input via stdin or as file argument(s).
Options:
    -o, --overwrite                  Write unwrapped output to files in place (otherwise creates a separate *.unwrapped[.ext] file)
    -s, --stdout                     Write unwrapped output to stdout, even when passing file arguments
    -h, --help                       Display this screen
```
