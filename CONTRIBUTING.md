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
