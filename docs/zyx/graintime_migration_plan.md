# graintime migration plan

migrate teamshine05/graintime → teamcarry11/graintime

## overview

move graintime from teamshine05 organization to teamcarry11 organization, following the same pattern used for grainmirror and grainorder migrations.

## steps

### 1. prepare local copy
- [ ] clone teamshine05/graintime to ~/github/teamcarry11/graintime
- [ ] verify all files are present

### 2. update organization references
- [ ] change "teamshine05" to "teamcarry11" in readme.md
- [ ] update team section: change "teamshine05" to "teamcarry11"
- [ ] update any URLs or references to old organization
- [ ] change "triple licensed" to "Multi-licensed" in readme.md and license files

### 3. update code references (if any)
- [ ] search for "teamshine05" in all source files
- [ ] update any organization-specific references
- [ ] verify no hardcoded paths or org names

### 4. create github repository
- [ ] use `gh repo create teamcarry11/graintime --public`
- [ ] set remote origin to new repository
- [ ] verify repository created successfully

### 5. commit and push
- [ ] commit all changes with message: "Migrate from teamshine05 to teamcarry11 organization"
- [ ] push to main branch: `git push -u origin main`
- [ ] set main as default branch: `gh api repos/teamcarry11/graintime -X PATCH -f default_branch=main`

### 6. update grainstore
- [ ] reverse-mirror updated code from ~/github/teamcarry11/graintime to grainstore/github/teamcarry11/graintime
- [ ] remove old grainstore/github/teamshine05/graintime (or keep as archive)
- [ ] verify no .git folders in grainstore copy

### 7. update xy-mathematics references
- [ ] search for "teamshine05/graintime" in xy-mathematics codebase
- [ ] update to "teamcarry11/graintime" where referenced
- [ ] update any import paths or documentation

## verification checklist

- [ ] repository exists at https://github.com/teamcarry11/graintime
- [ ] main branch is default
- [ ] all code pushed successfully
- [ ] grainstore copy updated (no .git folders)
- [ ] all organization references updated
- [ ] license text updated to "Multi-licensed"
- [ ] tests pass (if applicable)

## notes

- graintime is a temporal awareness tool for grain network
- formats grainbranch names with astronomical context
- similar structure to grainmirror/grainorder (Zig modules)
- no external dependencies needed (standalone tool)

