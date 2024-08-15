# Confluence to Markdown

This script is designed to run on a batch HTML export from Confluence to output a folder full of Markdown files.

## Requirements

- Ruby 3.x
- Pandoc installed in $PATH (see [Installation](https://pandoc.org/installing.html))

## Usage

Run in a folder full of HTML files, or pass a single HTML file as argument.
If passing a single HTML file, optionally specify an output file as second argument.

Run `confluence_to_md.rb -h` to see available options.

```console
Usage: confluence_to_md.rb [OPTIONS] [FILE [OUTPUT_FILE]]

Options:
    -c, --clean                      Clear output directories before converting
    -e, --[no-]strip-emoji           Strip emoji (default true)
    -f, --[no-]fix-headers           Bump all headers except first h1 (default true)
    -o, --[no-]fix-hierarchy         Fix header nesting order (default true)
    -s, --strip-meta                 Strip Confluence metadata (default false)
    -t, --[no-]fix-tables            Convert tables to Markdown (default false)
        --[no-]flatten-images        Flatten attachments folder and update links (default true)
        --[no-]rename                Rename output files based on page title (default true)
        --[no-]source                Include an HTML comment with name of original HTML file (default false)
        --stdout                     When operating on single file, output to STDOUT instead of filename
        --[no-]update-links          Update links to local files (default true)
    -h, --help                       Display help
    -v, --version                    Display version number
```
