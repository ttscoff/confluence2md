confluence2md 1.0.4
------------------------

#### NEW

- Update local HTML file links to markdown slug names (converted to .html extension). Can be disabled with `--no-update-links`.

confluence2md 1.0.3
-------------------------

#### NEW

- `--source` flag will include an HTML comment showing the original

confluence2md 1.0.2
-------------------------

#### IMPROVED

- Convert embedded images (which can't be retrieved) to `%image: FILENAME` syntax for possible replacement in the future

#### FIXED

- Remove unneccesary variable assignment
- Page title was not properly removing parent title

confluence2md 1.0.1
-------------------------

- Option (--clean) to remove directories from previous run
- New command line flag to skip emoji stripping (--no-strip-emoji)
- Add YARD comments to script
- Switch from .markdown to .md
- Attempt to clean up empty spans in output


