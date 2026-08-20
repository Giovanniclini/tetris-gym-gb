# Vendored disassembly — provenance

This directory is a **verbatim copy** of the `disasm/` subtree of an upstream
Game Boy Tetris disassembly. It is vendored, **not forked**.

| | |
| --- | --- |
| Upstream | <https://github.com/vinheim3/tetris-gb-disasm> |
| Pinned commit | `af54544fe292464055dc1d32490e48c4f998c9d9` (2023-01-19) |
| Licence | MIT — Copyright © 2023 Daniel Jianoran (see `LICENSE`) |
| Target ROM | Tetris (World) (Rev A), "v1.1" |
| SHA-1 | `74591cc9501af93873f9a5d3eb12da12c0723bbc` |
| MD5 | `982ed5d2b12a0377eb14bcdc4123744e` |
| Coverage | 100 % — upstream `coverage.txt` reports 0 bytes remaining |

Note that the upstream MIT licence covers the author's annotation and
organisation work. It cannot grant rights over the underlying game content,
which remains copyrighted. See `docs/research.md` §7.

## Local deviations from upstream

Two, both minimal. `build.py --original` still reproduces the stock ROM byte-exactly.

Only three categories of deviation are ever permitted, and every one must be
listed in the table below with a justification (see `docs/architecture.md` §3.1):

1. **Toolchain migration** — syntax required by the pinned RGBDS version.
   Must not change a single output byte.
2. **Section splitting** — e.g. splitting the monolithic `include/wram.s` into
   named per-purpose sections so the linker reports real free space.
   Must not change a single output byte.
3. **Hook insertion points** — declared in `src/hooks/hooks.inc`. These *do*
   change bytes, and each is enumerated and counted by `tests/`.

| # | File | Change | Category | Why | Bytes changed |
| --- | --- | --- | --- | --- | --- |
| 1 | `code/bank_000.s` | `IF GYM` include of `hooks/trampoline.inc` immediately before `ds $100-@, $ff` | 3 (hook) | The entry-point padding at `$00DA-$00FF` is the only free space in bank 0. The far-call trampoline must live in bank 0 because the caller may execute from any bank. | 22 of 38 available, `$00DA-$00EF`. Zero when `GYM=0`. |
| 2 | `include/wram.s` | Split the monolithic `$C000-$DFFC` section, starting a new `"WRAM Audio"` section at `$DF70` | 2 (section split) | Upstream declares all of WRAM as one section, so the linker cannot see the 2062-byte gap at `$D762-$DF6F` that the game never touches. No label moves. | **0** — WRAM is not in the ROM image |

## What was not vendored

Upstream's `web/` visualiser, `tools/`, `coverage.txt` and `README.md` are not
needed to build and were left out. Fetch them from upstream if useful — the
visualiser in particular is a handy reference for screen layouts and sprites.
