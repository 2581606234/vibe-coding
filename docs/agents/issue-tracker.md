# Issue tracker: GitHub

Issues and specifications for this repository live in GitHub Issues at `2581606234/vibe-coding`. Use the `gh` CLI for all operations.

## Conventions

- Create: `gh issue create --title "..." --body "..."`
- Read: `gh issue view <number> --comments`
- List: `gh issue list --state open --json number,title,body,labels,comments`
- Comment: `gh issue comment <number> --body "..."`
- Close: `gh issue close <number> --comment "..."`

Infer the repository from `git remote -v`. Pull requests are not treated as a triage request surface.

## Publishing and fetching

When a skill says to publish a specification or ticket, create a GitHub Issue. When it asks for a ticket, fetch the referenced GitHub Issue and its comments.

