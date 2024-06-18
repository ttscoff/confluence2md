# Confluence to Markdown

This script is designed to run on a batch HTML export from Confluence to output a folder full of Markdown files.

## Requirements

- Ruby 3.x
- Pandoc installed in $PATH (see [Installing docs](https://pandoc.org/installing.html))

## Usage

Run the script from within the directory of a batch export of HTML files.

Run with `-s` to strip Confluence-related metadata and fix H1 title.

