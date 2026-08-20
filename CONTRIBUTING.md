# Contributing

## Workflow

`main` is protected. Work happens on a branch and lands through a pull request
once CI is green.

```
git checkout -b short-description
# ... work, commit ...
git push -u origin short-description
gh pr create        # or open the PR in the browser
```

CI must pass before merging. What it checks:

| Check | Why it matters |
| --- | --- |
| `build.py --original` reproduces SHA-1 `74591cc9…` | **The project's ground truth.** If the stock ROM no longer rebuilds byte for byte, the change is wrong regardless of how it looks. |
| Banks 0-1 differ only at declared hooks | Catches accidental drift into original gameplay code |
| Byte-level tests | Gravity table, DAS constants, cartridge header |
| Behavioural tests | Drives the ROM in an emulator: level picker, instant restart, timings |
| No ROM data tracked | We ship patches, never ROM data |

macOS is checked weekly rather than per push - it costs 10x the CI minutes on a
private repo and queues badly.

## Branch protection (applied)

`main` requires a green CI run before anything merges:

- a pull request is required
- **`build and test`** must pass
- the branch must be up to date with `main` before merging
- force pushes and deletions are blocked

Admin enforcement is deliberately off and no approving review is required, so a
solo maintainer can still merge their own PRs - but nothing lands red.

Recorded here in case it ever needs re-applying. The settings are under
**Settings → Branches**, or:

**Settings → Branches → Add branch ruleset**, target `main`:

- Require a pull request before merging
- Require status checks to pass, and add **`build and test`** (the job name in
  `.github/workflows/ci.yml`; it only becomes selectable after the workflow has
  run once)
- Require branches to be up to date before merging

Leave "required approving reviews" at 0 and admin enforcement off while the
project is one person: you can still merge your own PRs, but nothing lands red.

The same thing with the GitHub CLI, once `gh auth login` has been done:

```
gh api -X PUT repos/Giovanniclini/tetris-gym-gb/branches/main/protection \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=build and test' \
  -F 'enforce_admins=false' \
  -F 'required_pull_request_reviews[required_approving_review_count]=0' \
  -F 'restrictions=null'
```

## Running it locally

```
python3 build.py --original     # must print the byte-exact match
python3 build.py                # the Gym ROM
python3 tests/test_original.py
python3 tests/test_expansion.py
```

The behavioural tests need PyBoy, a test-only dependency:

```
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements-dev.txt
.venv/bin/python tests/test_behaviour.py
.venv/bin/python tests/test_menu.py
.venv/bin/python tests/test_restart.py
```

The whole suite takes about 15 seconds.

## Before you write code

Read [`CLAUDE.md`](CLAUDE.md), then [`docs/decisions/`](docs/decisions/). The
ADRs record constraints found the hard way - bank switching, why hooks redirect
rather than insert, and the ordering traps in the level select and instant
restart. They will save you more time than they take to read.

**If a change adds a hook into the original banks**, declare it in
`src/hooks/hooks.inc`, mirror it in `tests/test_expansion.py`, and say why in
the PR. Those get extra review.
