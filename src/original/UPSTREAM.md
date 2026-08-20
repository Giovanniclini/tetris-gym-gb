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

**None.** The tree builds byte-exactly as vendored.

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
| — | — | — | — | — | — |

## What was not vendored

Upstream's `web/` visualiser, `tools/`, `coverage.txt` and `README.md` are not
needed to build and were left out. Fetch them from upstream if useful — the
visualiser in particular is a handy reference for screen layouts and sprites.
