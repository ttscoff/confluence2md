# confluence2md

Convert Confluence HTML to Markdown

## File Structure

Everything is currently in confluence2md.rb. The script is designed to run standalone without many requirements, other than Ruby and Pandoc.

## Changelog

As long as VERSION is up-to-date, you can `changelog -u` to update from git commits.

@run(changelog -u)

## Development

@run(subl .)

Be sure to bump the version with `rake bump` before committing changes. Use changelog formatting in Git commits to allow changelog updates.

## Deploy

All version bumping and changelog updating handled by script below. Steps are basically:

1. Compile script
1. Bump version
1. Update changelog
1. commit and push
1. use hub to create release based on VERSION

```run
#!/usr/local/bin/fish

rake merge
rake bump
set VER (rake ver)

changelog -u
git ar
git commit --amend --no-edit
git push
echo $VER > current_changes.md
echo >> current_changes.md
changelog >> current_changes.md
hub release create $VER -F current_changes.md
git pull
gh release upload $VER confluence_to_md.rb
gh release upload $VER tablecleaner.rb
rm current_changes.md
```

## Testing

@run(cd test && ../confluence_to_md.rb -s -c --source)

## Documentation

Keep README.md up-to-date with changes to functionality and new command line switches/flags.

Use YARD commenting in script and run Yard to update docs.

@run(rake yard)
