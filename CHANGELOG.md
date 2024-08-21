### 1.0.26

2024-08-21 10:37

#### CHANGED

- `--clean-tables` defaults to true and can be disabled with `--no-clean-tables`

#### IMPROVED

- Better table cleanup
- Add missing header row to tables lacking one
- Bold `<th>` elements in rows other than header row

### 1.0.25

2024-08-16 14:22

#### NEW

- Tablecleaner.rb script for cleaning individual markdown files containing tables.

#### IMPROVED

- Refactoring for manageability
- Better table cleanup

confluence2md 1.0.24
-------------------------

#### NEW

- Table formatting for cleaner tables (see `--clean-tables` and `--max-table-width`)
- Table formatting for cleaner tables (see `--clean-tables` and `--max-table-width`)

#### IMPROVED

- Major code refactoring and separation to multiple files that are merged into final script
- Major code refactoring and separation to multiple files that are merged into final script

confluence2md 1.0.23
-------------------------

#### IMPROVED

- Show all info lines when run with `--debug`

#### FIXED

- Delete errant images/images folder after processing (contains icons and emoji, not needed)

confluence2md 1.0.22
-------------------------

#### CHANGED

- Switch flag from `--color` to `--colorize` and add hidden `--color=WHEN` flag for compatibility with other CLIs (so `--color=never` and `--color=always` will work)

#### IMPROVED

- Cleaner output with colorization (disable with --no-color)
- Code cleanup
- `--debug` will show additional info and error output

confluence2md 1.0.21
-------------------------

#### CHANGED

- Revert STDERR output CHANGED

#### FIXED

- Handle `images/attachments` paths when rewriting urls so you don't end up with images/images/IMAGE paths

confluence2md 1.0.20
-------------------------

#### FIXED

- The system cannot find specified file error

confluence2md 1.0.19
-------------------------

#### FIXED

- Table conversion when body rows contain TH elements

confluence2md 1.0.18
-------------------------

#### IMPROVED

- Help output (-h) sorted alphabetically
- If not flattening attachments (--no-flatten-images), then copy the entire images/attachments folder into the markdown folder

confluence2md 1.0.17
-------------------------

#### IMPROVED

- Attachment flattening can be disabled with --no-flatten-images

confluence2md 1.0.16
-------------------------

#### IMPROVED

- Convert all attachments/[..]/[image] references to point to /images folder

confluence2md 1.0.15
-------------------------

#### FIXED

- Tables containing links get an extra newline before link definitions
- Handle /attachements in addition to /images/attachments

confluence2md 1.0.14
-------------------------

#### FIXED

- Attachments path

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


