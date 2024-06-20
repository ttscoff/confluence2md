# Confluence to Markdown

This script is designed to run on a batch HTML export from Confluence to output a folder full of Markdown files.

## Requirements

- Ruby 3.x
- Pandoc installed in $PATH (see [Installing docs](https://pandoc.org/installing.html))

## Usage

Run in a folder full of HTML files, or pass a single HTML file as argument"

```console
Usage: confluence_to_md.rb [OPTIONS] [FILE]

Options:
    -c, --clean                      Clear output directories before converting
    -s, --strip-meta                 Strip Confluence metadata (default false)
    -e, --[no-]strip-emoji           Strip emoji (default true)
        --[no-]update-links          Update links to local files (default true)
        --[no-]source                Include an HTML comment with name of original HTML file
```
