confluence2md 1.0.13
-------------------------

#### IMPROVED

- Flatten attachments folder to images folder if it exists

confluence2md 1.0.12
-------------------------

#### FIXED

- Admonition regex was too greedy

confluence2md 1.0.11
-------------------------

#### IMPROVED

- Preserve checkmark symbol when stripping emoji

confluence2md 1.0.10
-------------------------

#### NEW

- Handle admonitions (Note:, Tip:, etc.) by emphasizing tip indicator

#### IMPROVED

- Tables retain emphasis and line breaks
- Code refactoring

confluence2md 1.0.9
-------------------------

#### NEW

- Table conversion with `-t` flag

#### IMPROVED

- Fix <br></strong> errors in conversion

confluence2md 1.0.8
-------------------------

#### NEW

- Option to fix headers so there's only 1 H1
- Option to fix header hierarchy so that there's no jump > 1 between header levels
- Add -v (which will only work if the script is run from the repo directory containing the VERSION file)

#### FIXED

- Link regex updated to clean more attributes from links, allowing all links to be converted to Markdown

confluence2md 1.0.7
-------------------------

#### IMPROVED

- URL encoded image paths in replaced images

#### FIXED

- Markdownify_images running too soon, being escaped by Pandoc

confluence2md 1.0.6
-------------------------

#### IMPROVED

- Code refactoring

#### FIXED

- Image rescue missing images
- --clean not removing directories
- --source results being renamed when updating links

confluence2md 1.0.5
-------------------------

#### NEW

- File renaming is optional with `--no-rename`. Defaults to renaming output files as slug based on title.

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


