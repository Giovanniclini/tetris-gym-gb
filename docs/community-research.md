# Community Research — What Game Boy Tetris Players Actually Need

**Status:** Kickoff research, 2026-08-20.
**Scope:** Phase 6 and Phase 7 of the project kickoff.

> **Read this caveat first.** Public, searchable discussion of Game Boy Tetris practice is **thin**.
> The scene's day-to-day conversation happens in a Discord server that is not publicly indexable,
> and Reddit is not accessible to the tooling used for this research. What *is* publicly verifiable
> is **structural**: tournament series, their formats, their participant counts, and leaderboard
> data. That structural evidence turns out to be far more informative than opinion threads would
> have been, because **a tournament format is a statement of what the community trains for.**
> Every claim below is tagged with its evidence strength.

---

## 1. Sources searched

**Searched and productive**

| Source | What it yielded |
| --- | --- |
| [Liquipedia Tetris](https://liquipedia.net/tetris/) (MediaWiki API) | The CTWC Game Boy series, CTWC France Game Boy side events, formats, participant counts, prize pools |
| [speedrun.com `tetrisgb`](https://www.speedrun.com/tetrisgb) (public API) | Categories, subcategory variables, run counts, submission recency |
| [kirjavascript/TetrisGYM](https://github.com/kirjavascript/TetrisGYM) issues + CHANGELOG | Which NES trainers were built first, and what people still ask for |
| [Hard Drop Wiki](https://harddrop.com/wiki/Tetris_(Game_Boy)), [TetrisWiki](https://tetris.wiki/Tetris_(Game_Boy)) | Mechanics that determine what is trainable |
| [TCRF](https://tcrf.net/Tetris_(Game_Boy)) | Version differences that affect competitive fairness |
| [romhacking.net](https://www.romhacking.net/games/2622/) GB Tetris hacks | What the modding scene has already built (and hasn't) |
| [tetrisconcept.net](https://tetrisconcept.net/) | Historical maxout discussion (low volume, 2009-era) |
| Twin Galaxies / Guinness / Cyberscore | Score-attack leaderboard existence |

**Searched and unproductive**

* **Reddit** — `reddit.com` is blocked to this session's search agent and its JSON API refused
  requests. **This is a real gap.** r/Tetris and r/classictetris should be searched manually before
  final feature lock. Recorded as an open action in §7.
* **The GBTetris Discord** — the actual centre of the community. Not publicly indexable.
  **The single highest-value next research action is to join it and ask.** See §7.
* `gameboytetr.is` — the community's own domain, but the root is an unconfigured nginx page; only
  tournament bracket sub-pages are served.
* Generic "Tetris practice/training" searches — dominated by modern guideline Tetris (TETR.IO,
  Jstris, four-tris, T4B). **Almost none of it transfers**; those tools assume hold, hard drop, SRS,
  7-bag and 20-row fields, none of which exist here.

---

## 2. The finding that reframes the whole project

**There is an organised, ongoing, international competitive Game Boy Tetris scene, and its
competitive formats are fundamentally different from NES Tetris's.**

**[STRONG EVIDENCE — structural, multi-year, independently documented]**

* **Classic Tetris World Championship — Game Boy (CTWCGB)** is an annual online world championship
  run by the **GBTetris Discord Server**. 2025 was the **third** installment. Qualifiers run ~2
  months; the top 16 play out live; the round of 16 streams on the GBTetris Twitch channel and the
  **top 8 streams on the main CTWC channel**. 2024 had **27 qualifying players from around the
  world**.
  — [CTWCGB/2024](https://liquipedia.net/tetris/CTWCGB/2024), [CTWCGB/2025](https://liquipedia.net/tetris/CTWCGB/2025)
* **Game Boy side events run at physical CTWC regionals.** *CTWC France 2026 — Game Boy*, Montpellier,
  1–3 May 2026: **offline, 24 players, prize pool, Liquipedia tier 3**, with a documented
  predecessor (2025) and successor (2027) page. CTWC UK 2025 also ran a Game Boy side tournament.
  — [CTWC France/2026/Game Boy](https://liquipedia.net/tetris/CTWC_France/2026/Game_Boy)
* **The GBTetris Discord runs tournaments roughly every two months.**

### 2.1 The formats — this is the key insight

**CTWC France 2026 — Game Boy:**

```
Qualification  (May 1-3)  : 40 Lines Sprint — best time
Tournament     (May 3)    : Single elimination, Game Boy VS, first-to-4
                            Grand Finals: Bo3 of FT4
```

Recorded qualifying times ranged from **1:45.53** (M-J) to **8:33.44**, with the top 16 all under
2:51. **[STRONG — 24 individual timed results published]**

**speedrun.com/tetrisgb** categories and their run counts:

| Category | Runs | Notes |
| --- | --- | --- |
| 100 Lines, Level 0 Start | **87** | "no `<3` cheat" — heart levels explicitly banned |
| 100 Lines | **59** | Any start level 0–9, heart levels allowed |
| 300,000 Points | **14** | Score attack |

Plus a global subcategory variable **`Start level` with values `0`–`9` and `0♥`–`9♥`** — the game's
hidden high-speed "heart levels" are a **first-class competitive concept** on the Game Boy, with
their own ladder positions. Submissions are ongoing (most recent verified run at time of research:
2026-07-17; ~20 submissions in the preceding 12 months).
**[STRONG — leaderboard data pulled from the public API]**

### 2.2 What this means

| NES Tetris trains for… | Game Boy Tetris trains for… |
| --- | --- |
| A-Type endless survival from level 18/19 | **40-line sprint speed** |
| Maxout / transition / killscreen | **Head-to-head link-cable VS** |
| Score at 230 lines, "pace" | 100 lines fast; 300 k points; 999 999 cap |
| Hypertapping / rolling to beat 16-frame DAS | 23-frame DAS; **heart levels** for raw speed |
| Level 29 killscreen wall | **Level 20 cap** (+10 effective with hearts) |

**Consequence: we must not simply port TetrisGYM's trainer list.** TetrisGYM is optimised for a
game whose competitive question is *"how long can you survive at level 19?"*. The Game Boy's
competitive questions are *"how fast can you clear 40 lines?"* and *"can you beat this person over
the link cable?"*. Those need **timers, sprint modes, seeded VS-equivalent sequences and garbage
practice** — several of which TetrisGYM does not prioritise and one of which (a frame-accurate
timer) it does not have at all.

---

## 3. Recurring needs vs. anecdote

### 3.1 Recurring / structurally evidenced

| # | Need | Evidence | Strength |
| --- | --- | --- | --- |
| R1 | **Practise a 40-line sprint with an accurate timer** | It is the qualification format of the largest offline GB event; 24 published times | **Strong** |
| R2 | **Practise VS / digging garbage** | The entire bracket phase of CTWC France GB is head-to-head VS, FT4 | **Strong** |
| R3 | **Start on an arbitrary level including heart levels** | speedrun.com has a 20-value start-level variable spanning 0–9 and 0♥–9♥; heart levels are explicitly regulated (banned in one category) | **Strong** |
| R4 | **Reach and practise high-speed play directly** | Heart levels are "level + 10" speed; level 20♥ is the ceiling. Reaching level 20 legitimately takes hundreds of lines | **Strong** (mechanics) + **Medium** (inferred need) |
| R5 | **Repeatable, identical piece sequences** | The original game already gives both VS players the same sequence; TetrisGYM shipped a Seed trainer in v3 explicitly "for VS battles (or practise)" | **Strong** |
| R6 | **Reduce friction between attempts** | Every TetrisGYM trainer removes the rocket/curtain/wait screens; it was the very first thing built (v1 "Tetris" trainer) | **Strong** (by analogy) |
| R7 | **Set up a specific board and repeat it** | Block Tool (v1) + savestates (v2) were TetrisGYM's 1st and 2nd structural features; savestates are called out as "effective for practising specific scenarios" | **Strong** (by analogy) |
| R8 | **See real score past the display cap** | GB caps at 999 999; a 300 000-point speedrun category exists; maxout runs are a known achievement | **Medium–Strong** |
| R9 | **Control / train DAS** | TetrisGYM's most-discussed open issue is [#134 "Mode for training maintaining and gaining DAS"](https://github.com/kirjavascript/TetrisGYM/issues/134) (9 comments — the most engagement on any open issue); it also shipped a DAS delay modifier (v4) and a whole DAS Only mode (v5) for a CTWC event | **Medium–Strong** |
| R10 | **Persist settings and saved boards across power-off** | TetrisGYM stores highscores and savestates in SRAM and explicitly documents Everdrive/MiSTer support | **Medium** (by analogy) |

### 3.2 Anecdotal — interesting but not evidence of demand

* Individual maxout (999 999) posts on tetrisconcept.net (2009) and YouTube. Establishes that the
  goal exists; a handful of posts is not a demand signal.
* A Facebook retro group thread on B-Type Level 9 High 5 scores; Cyberscore and Twin Galaxies have
  charts for it. Real but low-volume.
* Guinness/Twin Galaxies record for GB Tetris (752 668 pts, Alex Holbrook, 2017). Historical colour.
* Individual TetrisGYM feature requests with 0 👍 and 0–1 comments (zen mode, misdrop simulator,
  colour checker). **Treat as ideas, not demand.**

### 3.3 What the GB modding scene has already built — and the gap

**[STRONG — romhacking.net catalogue]**

| Existing GB Tetris hack | What it does | Relationship to us |
| --- | --- | --- |
| **Tetris — Rosy Retrospection** (+ DX) | Adds SRS, ghost piece, 3-piece preview, hold via SELECT | **The opposite of our project.** It modernises away the thing we want to preserve. Well received ("Definitive Way to Play Tetris on Game Boy"). It already serves the "I want modern Tetris on GB" audience — **we should not compete for it.** |
| **Tetris — Max Speed** | Demonstrates maximum possible fall speeds; TAS/informational | Adjacent; shows speed-modification hacks are accepted |
| **Tetris highscore save** | Adds SRAM persistence | Precedent for our SRAM plan |
| **itris** | All pieces are I-pieces | Joke hack |
| Mega Duck patch | Port to a clone console | Unrelated |

> **There is no Game Boy Tetris training/practice ROM.** Searches for one returned only TetrisGYM
> (NES) and Rosy Retrospection (modernisation). **The gap this project fills is real and unoccupied,
> and it has an identified, organised, tournament-running audience.**

---

## 3.4 First-hand practitioner evidence (GBTetris Discord, 2026-08-20)

**[MEDIUM-STRONG — n = 1, but a named practitioner describing their own routine and naming
specific features. Weighted above forum anecdote, below structural evidence. Needs corroboration.]**

First contact with the GBTetris Discord produced more usable signal than all the desk research in
§1–§3. Recorded verbatim in substance:

* **No GB training ROM exists.** Confirms §3.3. The hack currently in general use *"unlocks more
  level starts, adds a digit to the score counter, and skips the rocket screen"* — i.e. the
  community has already hand-rolled precisely the three cheapest items on our list (matrix rows 2,
  9 and the practice-loop half of 1). **Strong validation of the ranking's top end.** Other ROMs
  exist, including speedrunning ones; there is a dedicated Discord channel cataloguing them.
  **ACTION: catalogue that channel before building anything (§7 A7).**
* **Stated practice routine:** *"L starts for pushing my tap skills, then I practice level 20, then
  I go to my 9 starts. The most annoying thing is definitely grinding 9 starts."*
* **Explicitly wanted, unprompted:** floor mode, **low stack**, **transition trainer**, **a hz
  counter**, and above all a **standardised SPS**.
* **SPS = "Same Piece Set"** — deterministic, shared piece sequences. (Same concept as TetrisGYM's
  Seed trainer, *"provides same piece sets for VS battles (or practise)"*, and its `tests/src/sps.rs`.)
  *"There's an imperfect one out there"*, but the community's few romhackers are capacity-limited.
* **Distribution plan:** *"once there is a solid, tested rom with SPS + extended level select +
  whatever else, we could get resources together to have a bunch of carts cheaply made and sent
  out."* One member (Gunter) has investigated the hardware.

### 3.4.1 Corrections this forces to §5

Two matrix rows were **wrong**, both because they were reasoned from mechanics rather than from
practice:

| Row | Was | Now | Why it was wrong |
| --- | --- | --- | --- |
| **26 Transition trainer** | **DROP** — *"GB has no level-19/29 transition wall"* | **MUST** | The framing was NES-shaped. Game Boy's transition is the level-up threshold, and for a level-9 start that is **100 lines** — which is exactly the *"grinding 9 starts"* the practitioner named as their single biggest annoyance. A GB transition trainer = drop in near the end of that grind. This was the highest-value feature in the matrix and it was in the bin. |
| **20 Hz / tap-rate meter** | **NICE**, *"low value on GB"* | **SHOULD** | Reasoned from GB's 23-frame DAS making tapping less decisive than NES's 16. But players do train tap skill (*"L starts for pushing my tap skills"*) and asked for the counter directly. Over-reading mechanics is not a substitute for asking. |
| **17 Low stack** | NICE (bundled) | **SHOULD**, unbundled | Named explicitly and separately. |
| **4 Seeded sequences** | MUST | **MUST — co-headline** | Renamed **SPS**. Named as the blocker for a physical cart run. Our position is unusually strong: `docs/research.md` §3.5 shows the deterministic path already exists in the ROM. |

**Unresolved:** the practitioner did **not** mention a timer or 40-line sprint — our §6 #1, which
rests on the CTWC France qualification format. One person's routine is not the scene's; do not
demote it on n = 1, but **ask explicitly** (§7 A4/A8).

**Unresolved:** *"L starts"* could not be decoded. The level display is a single tile with a
sequential charmap, so levels 10–20 render as **A–K** and `$15` = "L" would be **level 21**, which
vanilla clamps out (`cp $14 / ret z`). Either their hack reaches it or the term means something
else. **ACTION: ask (§7 A9).**

### 3.4.2 A bug class worth flagging to the community

**[VERIFIED LOCALLY]** The gravity table at `$1B06` (v1.1) has **exactly 21 entries** (levels 0–20)
and is immediately followed by the code of `PopulateDemoBTypeScreenWithBlocks` at `$1B1B`. Any hack
that permits a start level above 20 **without extending the table** indexes into executable code and
reads opcodes as gravity values:

| Level | Byte | Resulting speed |
| --- | --- | --- |
| 21 ("L") | `$21` | 34 frames/row — **slower than level 5** |
| 22 ("M") | `$C2` | 195 frames/row |
| 23 ("N") | `$99` | 154 frames/row |
| 24 ("O") | `$11` | 18 frames/row |

Relevant to the existing "unlocks more level starts" hack. Our own extended level select must either
clamp at 20 or ship a deliberately extended table.

### 3.4.3 Consequences for hardware strategy

The cart-production plan **inverts** the framing in `docs/architecture.md` §7. Rather than "users
must own a flash cart", the cartridge becomes a **design input we can influence**. Therefore:

* **Ask Gunter what board is cheap to produce** before finalising D5 (MBC1 vs MBC5 — MBC5 is often
  more common on modern repro boards).
* **Make battery SRAM optional at build time**, as TetrisGYM does with its `-s` flag. Batteries add
  BOM cost and eventually die. Savestates and persisted config must degrade gracefully to
  session-only when SRAM is absent, and the ROM must not require it to boot.
* **Keep the ROM small enough to be cheap.** 128 KB is already conservative; do not grow casually.

## 3.5 Channel archaeology — GBTetris Discord, 2021-11 to 2026-08

**[STRONG — many named participants, recurring over ~5 years, with cross-checkable technical
detail. This supersedes the n = 1 caveats in §3.4.]**

A keyword sweep of the community's romhack channel produced the most decisive evidence in this
document. It **resolves five open questions, decodes "L start", and reverses one of the §3.4.1
corrections.**

### 3.5.1 The existing ROM landscape (this is what we must be a superset of)

Inventory assembled by *Tolstoj* (2022) and updated through 2026:

| ROM | Author(s) | What it does | Status |
| --- | --- | --- | --- |
| **KLM romhack** | Ospin, Tolstoj, Pascal, Hepps lineage | **Level K/L/M starts (20/21/22)** — L and M are *faster than any level in the original* — plus **score uncap** | **The de-facto standard practice ROM.** *"Most popular and useful"* (M-J) |
| **40-line sprint / qual ROM** | Pascal, Tolstoj | 40 lines, fixed settings, **built-in frame timer** | **In active tournament use.** Also *"most popular and useful"* (M-J) |
| "Score Uncap" | Kirjava | Score past 999 999 | Folded into KLM |
| "Rocket skip / acceleration" | nitro2k01 | Removes rocket screen friction | Folded into KLM |
| "Extended level select" | Ospin | Level 20 starts | Superseded by KLM |
| "10 lines 0 to level 20" | Hepps | Level 20 trainer (2021) | Superseded by KLM |
| SPS ROM | unnamed | *"Technically there is a rom with SPS but it only has basic level starts"* (nells) | **Unfinished, not standard** |
| Transition trainer patch | mathmaster13 | In progress as of 2026-05 | **Someone is already on this — coordinate, do not duplicate** |
| Hz counter | — | **Does not exist.** *"I don't know of a Hz counter romhack for GB"* (Hepta) | Wanted |

### 3.5.1a Availability: the competition ROMs are not public

**[VERIFIED 2026-08-20 — searched, not found]**

| Searched | Result |
| --- | --- |
| GitHub repos and code search | **0 results** for KLM / Game Boy Tetris trainer ROMs |
| [romhacking.net GB Tetris hacks](https://www.romhacking.net/games/2622/) | Rosy Retrospection (+DX), Max Speed, highscore save, [Colorization](https://www.romhacking.net/hacks/8240/), [Cross](https://www.romhacking.net/hacks/7471/), 1984, Ospin's "Classic Harddrop". **No KLM, no sprint ROM.** |
| Internet Archive | Only Rosy Retrospection DX |
| `gameboytetr.is` | Tournament brackets only; `/roms`, `/patches`, `/downloads` all 404 |

**KLM and the 40-line sprint ROM are distributed solely as pinned attachments in the GBTetris
Discord's `#romhacks-modify` channel** — consistent with §3.5.8, where Tolstoj says he still *plans*
a public KLM repo.

**This sharpens the project's value proposition.** The community's two most-used ROMs have no public
source, no version control, and no distribution outside one Discord channel. That is the gap, and it
is a stronger pitch to Tolstoj than "I would like to build a gym".

**Consequence for Milestone 1.** Levels 10–20 (A–K) are fully derivable from the 21-entry gravity
table at `$1B06` in the ROM we already build byte-exactly. **L (21) and M (22) are not** — the only
figure we have for L is a chat message (*"2 frames/row vs level 20's 3"*), and for M we have
nothing. Ship A–K from the ROM's own table, and extend to L–M only once KLM can be matched directly.
Inventing timings that silently differ from what people compete on would be worse than shipping
less. See §7 A7.

### 3.5.2 "L start" — decoded

**KLM = levels K, L, M = 20, 21, 22.** Level is a single tile with a sequential charmap, so 10–20
render as A–K and 21/22 render as L/M (`docs/research.md` §3.7). L and M are **deliberate
extensions past the original's ceiling**, not accidents:

* *"level K (20) starts and also level L and M starts, which are faster than in original game"* — M-J
* Level L scores **26 400 per Tetris** (M-J) — exactly `(21 + 1) × 1200`, confirming L = level 21 and
  that the score multiplier was extended coherently.
* L runs at **2 frames/row vs level 20's 3** (M-J), so the gravity table was genuinely extended.

**This means KLM extended the gravity table properly.** The `docs/research.md` §3.4.2 warning about
indexing past the table applies only to a *naive* hack, not to KLM — worth stating accurately if we
raise it publicly.

**L starts have their own competitive scene**: a PB-submission bot, a `personal-bests` channel, and
active record chasing (MarkTris, seb, Hepta, Zircon through 2026-08). League matches use arbitrary
starts including **F (15) and heart levels** (nells).

### 3.5.3 SPS — the community's stated #1, over five years

**SPS = "same piece sequence"** (Muf). *Terminology corrected from §3.4.*

> *"if I was to influence someone into making something, a competition rom with **A-M starts and
> SPS** would be the top of the list"* — nells, 2026-05

> *"SPS in GB Tetris has been a thing for years. It just didn't make it to any KLM ROM yet."* — Tolstoj
> *"Score uncap and faster levels. The SPS was never finished."* — Tolstoj
> *"We don't have a standard SPS rom yet."* — nells
> *"Hopefully we'll have an sps rom for next season as well, I'd really love to play sps"* — Gunter
> *"there's no SPS rom, or any other modes like there are in TetrisGYM on NES"* — seb

**Technical corroboration of `docs/research.md` §3.5** from *Tolstoj*: *"In GB Tetris the randomness
comes from the DIV register rather than the LFSR. Both NES and GB then have secondary checks
(redraw) in place to ensure a 'better' distribution."* — independently matches our reading of the
ROM.

*Muf* notes SPS would also enable **automatically synchronised seeds** between players.

**This is the product definition, stated by the community, unprompted, repeatedly, for years.**

### 3.5.4 REVERSAL: the 40-line sprint timer

**§3.4.1 provisionally demoted the sprint timer to #8 on n = 1 evidence. That was wrong.**

* A **40-line sprint ROM with a built-in frame timer already exists** (Pascal, Tolstoj) and is named
  by M-J as one of the two most popular and useful ROMs, alongside KLM.
* It is the **qualification format** for live 2-player tournaments.
* History (*-JJ_TerhoA*): a 30-line speedrun was invented as 2-player qualification because
  1-player score attack correlated poorly with VS ability; extended to 40 lines for comparability
  with other Tetris 40L modes. Known downside: the fastest 40L method is "tree strats", which don't
  represent 2-player play.
* *Pascal*'s design notes on the qual ROM are a specification worth copying verbatim:
  > *"This ROM tries to keep it as simple as possible and tries to reduce friction for organizers,
  > referees and players. You can still see your result, even if you press start after you finish
  > your game. You directly start into the menu screen. This ensures a fast start after a reset.
  > You cannot change any setting. It is always 40 lines, always speed 1, always timed, always high 0.
  > This ensures that everyone plays with the same settings. This reduces wrong starts and games not
  > counting. You only need to press one button (start or a) to start your next game."*

**Lesson: §3.4 was a single practitioner's routine, and I let it override structural evidence.
Restore the sprint timer — but note the feature already exists, so our job is integration and
standardisation, not invention.**

A known bug in the older timer ROM: the frame counter displayed hex and ran to `$3C` (60) instead of
wrapping at 60, so old and new ROM times differ by ~1.7 s (Tolstoj). Any timer we ship must define
its start/stop frames precisely — Tolstoj: *"The ROM ends the game prematurely and stops the timer
one frame after the piece locks."*

### 3.5.5 Hz counter — wanted, but genuinely less central than on NES

Requested (*"is there a hz counter rom like in tetris gym"* — Tale), and absent. *Tolstoj* proposed
translating [TetrisGYM's `hz.asm`](https://github.com/kirjavascript/TetrisGYM/blob/master/src/modes/hz.asm)
to GB assembly, noting the frame rates are close enough to carry over, but *"I'm honestly not super
motivated to push it forward right now."*

**However — the §3.4.1 promotion should not go further than SHOULD**, because two independent
statements say tapping rate matters *less* on Game Boy:

> *"It's not that much about the hz of the tap as on NES, timing becomes more important on GB"* — M-J
> *"It's not only about the hz of the tapping, it's the thing how quickly can you be ready for the
> next tap"* — M-J

**Cross-validation of our own measurement:** the community independently quotes DAS auto-repeat as
**6.636666667 Hz** (Tolstoj) / *"6.7 Hz"* (Hepta). Our ROM reading gives **9 frames at 59.727 Hz =
6.636 Hz**. Exact match — a strong check on `docs/research.md` §8 #1.

### 3.5.6 ROM version — A3 RESOLVED

**v1.1 (World Rev A) is the community standard.** D2 confirmed.

> *"it should patch with the 1.1 (Rev A / Rev 1)"* — Tolstoj
> *"Most gb tetris carts are version 1.1"* — M-J
> *"We always use V1.1 but many ROM hackers start with V1.0"* — Tolstoj
> *"Where did you even find v1.0? I intentionally looked for it and I couldn't find anything other
> than 1.1"* — seb

Note the second Tolstoj remark: **hackers often start from v1.0 while players use v1.1** — a
mismatch our v1.1-first choice avoids.

### 3.5.7 Hardware — a correction and a solved pipeline

**CORRECTION to `docs/research.md` §4.2 and the README.** I stated that no modified ROM can run on a
retail cartridge because it is mask ROM. **A Game Boy Game Genie patches cart reads at runtime**, so
small hacks *can* run on a genuine unmodified cartridge — limited to **three codes**:

> *"yeah im trying to keep everything within 3 GG codes so it works on hardware"* — mathmaster13
> *"because we already used two of our three game genie codes, it's very likely you can't do this on
> original hardware with a game genie"* — mathmaster13
> *"With your NES game genie carts you are also patching the rom, just at runtime"* — Muf

This matters because the community places real weight on original hardware — *"Only (or as close as
possible to) OG Nintendo hardware is allowed"* (Pascal, on CTWC GB rules) — and nells's **"SOG,
Spirit Of Gameboy"** ("sogginess"). A Gym cannot fit in 3 Game Genie codes, so this is not a route
for us; but we must **not claim it is impossible**, and we should expect the trade-off to be
debated.

**Cart production is already a working pipeline, not an aspiration.** Carts were manufactured and
sold at CTUK 2026 (*Tolstoj* providing them, proceeds to a charity fund); players own "qual carts"
and "tourney carts". *Hepta*: cheap AliExpress flashcarts work for Tetris; EZ-Flash and EverDrive
are the traditional but pricier options. **D9's premise is confirmed — the cartridge is a design
input we can influence.**

There is an unresolved legality debate in the community (*mathmaster13*: *"Gym carts are very
obviously not legal to produce imo"*; *Muf* counters that CTEC's stock of legitimate carts offsets
it). **Stay out of it. Ship patches, never ROMs, never carts** — consistent with `docs/research.md` §7.

Related community hardware: [GB Interceptor](https://github.com/Staacks/gbinterceptor) (capture
between cart and console) and [GBLink-Firmware](https://github.com/starlarkus/GBLink-Firmware)
(online play on original hardware).

### 3.5.8 The opening — Tolstoj is asking for a maintainer

> *"I do still plan on making a public repo for the KLM ROM so people can collaborate. **Last time I
> tried restructuring/optimizing the code and the file structure, I ended up breaking the whole
> project. If anyone else wants to host the code, let me know.** Pascal should also have at least the
> same knowledge as me."* — Tolstoj, 2026-01

There were also historical efforts toward a **"shiftable disassembly"** (Tolstoj, 2022) — a base
where inserting code relocates everything cleanly — and *nitro2k01* said of a gym/trainer:
*"For a gym/trainer, absolutely."*

**This is the strategic opening.** The failure Tolstoj describes — restructuring broke the
project — is *exactly* what Milestone 0 prevents: a byte-exact reference build plus a regression
test that fails the moment a refactor changes behaviour. We bring a maintainable, tested,
buildable foundation; the community brings five years of feature knowledge, a cart pipeline and
tournaments. **See §7 A12.**

## 4. Game Boy-specific findings (things that make GB ≠ NES)

These come from the mechanics research in `docs/research.md` and directly change feature design.

1. **DAS is 23 frames initial / 9 frames autorepeat** (verified in ROM at `$2517`, `$2525`).
   NES is 16/6. GB DAS is *much* slower, so **hypertapping and rolling are far less central** than
   on NES. Porting TetrisGYM's tap/quicktap/roll/Hz suite wholesale would be misallocating effort.
2. **The playfield is 10×18, not 10×20.** Less room to recover; "high stack" arrives sooner.
3. **The top two rows are never checked for line clears.** A genuine, documented original quirk.
4. **Max level is 20; heart levels add +10 effective speed but no score bonus.** The "killscreen"
   concept does not exist in the NES sense. Level ceiling practice means level 20 / 20♥.
5. **The randomizer is a biased OR-rejection filter on `rDIV`** — L appears 10.7 %, J/I/Z 13.7 %,
   O/S/T 16.1 %. **I-piece drought is structurally different from NES.** A drought trainer is still
   valuable but must be built on GB's actual distribution.
6. **There is no hold, no hard drop, no ghost piece, 1 next piece.** Preserve this. Rosy
   Retrospection exists for people who want otherwise.
7. **Score caps at 999 999**, and the level-up sound/rocket thresholds differ between v1.0 and v1.1.
8. **VS garbage is a single aligned hole, identical for both players**; 1 line for a double, 2 for a
   triple, 4 for a Tetris; clearing 30 lines auto-wins the round. **This is a precise, implementable
   spec for a solo VS-garbage trainer.**
9. **The game has no timer of any kind.** For a scene whose flagship qualifier is a timed 40-line
   sprint, **adding a frame-accurate timer is the single most obviously missing feature.**
10. **`A+B+Select+Start` already soft-resets**, and dormant demo/input-recording code already exists.

---

## 5. Feature matrix (Phase 7)

Priority = **user value × technical feasibility**, judged against *Game Boy* evidence, not against
what TetrisGYM happens to contain.

Difficulty key: **XS** trivial (one constant) · **S** small (state setup, no new UI) ·
**M** medium (new UI or per-frame rendering) · **L** large (new subsystem).

| # | Feature | Training need | TetrisGYM equivalent | Community demand | Feasibility | Diff. | Training value | GB adaptation | Priority |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Instant restart of current scenario** | Remove friction; more reps per session | implicit in all trainers | R6 strong | Trivial — soft reset already exists at `A+B+Select+Start` | XS | Very high | Retarget existing reset to "restart trainer" | **MUST** |
| 2 | **Start on any level 0–20, heart on/off** | Practise the speed you actually compete at | Level Menu / any level | R3, R4 strong | Trivial — write `hATypeLevel`, gravity reload from table at `$1B06` | XS | Very high | GB caps at 20; hearts are a separate flag, not a level | **MUST** |
| 3 | **Frame-accurate timer + 40-line sprint mode** | *The* CTWC-GB qualification format | **none** | R1 strong | Easy logic; needs 5–6 HUD tiles per frame | M | Very high | **GB-specific. The flagship feature.** | **MUST** |
| 4 | **Seeded / repeatable piece sequence** | Compare attempts; match VS conditions; fair practice | Seed trainer (v3) | R5 strong | **Very easy** — force the existing `.predefined` path and fill the 256-byte `wRandomness` table | S | Very high | Mechanism already ships in the ROM for 2P | **MUST** |
| 5 | **Preset boards + garbage/floor setup at start** | Reproduce the situation you fail at | Floor, B-Type, Setups, Crunch | R7 strong | Tilemap writes at `LOAD_PLAYFIELD` time — no gameplay code touched | S | High | Use GB's own B-Type garbage generator as the base | **MUST** |
| 6 | **VS-style garbage / dig trainer** | The bracket format is head-to-head VS | Garbage trainer (v2) | R2 strong | Original 2P garbage spec is fully documented and already implemented in-ROM | M | Very high | **GB-specific rules**: single aligned hole, 1/2/4 lines, 30-line auto-win | **MUST** |
| 7 | **Savestates (SRAM-backed slots)** | Repeat one scenario many times | Savestates (v2) | R7, R10 medium–strong | Board snapshot is 180 B; ~4.5 KB WRAM free; needs MBC1+RAM+BAT | M | High | Requires cartridge-type change (already required for ROM space) | **SHOULD** |
| 8 | **Board editor ("Block Tool")** | Author an exact board | Block Tool / Level Editor | R7 medium (by analogy) | Cursor + tile writes; needs input handling and a HUD | M | High | 10×18 field; simpler than NES | **SHOULD** |
| 9 | **Uncapped / extended score + line counter** | See real performance past 999 999 | Scoring modes (v5) | R8 medium–strong | Score is BCD in WRAM; needs extra digits and render slots | M | High | Cap is 999 999 on GB, not 1.6 M | **SHOULD** |
| 10 | **DAS trainer + DAS charge indicator** | Learn/maintain shift charge | DAS Delay (v4), DAS Only (v5), open issue #134 | R9 medium–strong | Delay is **one byte** (`$17`/`$09`); indicator costs HUD tiles | XS / M | High | GB's 23+9 timing differs from NES; retune the whole concept | **SHOULD** |
| 11 | **Fixed-speed "marathon" (no level-ups)** | Endurance at one difficulty | Marathon (v6) | R4 medium | Freeze `hATypeLinesThresholdToPassForNextLevel` | XS | Medium–high | GB's threshold formula differs between v1.0/v1.1 | **SHOULD** |
| 12 | **Piece statistics / drought counter** | Understand your distribution; recognise drought | Drought (v1), stats via TAUS | Medium | Count in the spawn hook; render on demand | S / M | Medium–high | GB's distribution is *biased* (10.7–16.1 %), unlike NES | **SHOULD** |
| 13 | **Drought / piece-bias injection** | Survive without your crutch piece | Drought (v1) | Medium | **Free** once #4 exists — just generate a biased table | XS | Medium–high | Built on GB's real distribution | **SHOULD** |
| 14 | **Input display** | Self-review, streaming, coaching | Input display (v2) | Medium | 6–8 sprites; cheap in OAM, costs no VBlank | S | Medium | 8 buttons | **NICE** |
| 15 | **Line-clear delay skip / configurable ARE** | More reps per minute when drilling | (removed spawn delays, v5) | Low–medium | Constants (2 / 93 frames) | XS | Medium | GB's 93-frame line-clear delay is long | **NICE** |
| 16 | **Replay / input record + playback** | Review a run; share a scenario | (none — TetrisGYM has no replay) | Low public, high latent | **Dormant code already exists** (`RecordDemo`, `$FFE9`); needs redirected buffers | M | Medium–high | GB-specific opportunity | **NICE** |
| 17 | **Invisible / low-stack / crunch challenges** | Board memory; discipline | Invisible (v4), Low Stack, Crunch (v6) | Low | Straightforward once the mode framework exists | S | Medium | 18 rows makes low-stack harsher | **NICE** |
| 18 | **Pace indicator vs. a target score** | Know if you're on 300 k / maxout pace | Pace (v3) | Medium | Arithmetic + HUD | M | Medium | Targets are 300 k / 999 999, not 1.5 M | **NICE** |
| 19 | **B-Type Lv9/High5 drill (incl. Buran)** | A real GB leaderboard category | B-Type trainer (v4) | Low–medium | The mode already exists; just skip menu navigation | S | Medium | **GB-specific** (dancers/Buran ending) | **NICE** |
| 20 | **Tap/roll Hz meter & speed tester** | Input-rate training | Hz display, speed tester (v4) | Low for GB | Cheap logic, costly HUD | M | **Low on GB** | GB's 23/9 DAS makes tapping much less decisive than on NES | **NICE** |
| 21 | **Hard drop / sonic drop** | — | Hard Drop (v4) | — | Easy | S | — | **Breaks authenticity.** Rosy Retrospection already serves this audience | **DROP** |
| 22 | **Hold piece, ghost piece, SRS, 3-piece preview** | — | — | — | — | — | — | Turns the project into a worse Rosy Retrospection | **DROP** |
| 23 | **PAL/NTSC region modes** | — | PAL Mode | — | — | — | — | **Meaningless on Game Boy** — one timing domain, 59.727 Hz | **DROP** |
| 24 | **Crash-bug recreation modes** | — | Crash Modes (v6) | — | — | — | — | NES-specific bug; GB has different quirks (see #25) | **DROP** |
| 25 | **T-Spin trainer** | — | T-Spins (v1) | None found | Possible | M | Low | GB uses left-handed NRS with no wall kicks and **no T-spin scoring**. The technique barely exists here | **DROP** |
| 26 | **Transition trainer (NES sense)** | — | Transition (v4) | — | — | — | — | GB has no level-19/29 transition wall; superseded by #2 and #11 | **DROP** |
| 27 | **Dark mode / palette themes** | Comfort | Dark Mode (v6) | None | Easy on DMG (4 shades) | S | Very low | Little to theme on a 4-shade screen | **DROP** |

---

## 6. TOP 10 MOST VALUABLE FEATURES FOR A GAME BOY TETRIS GYM — SUPERSEDED by §6.2

Ranked by (Game Boy) community evidence × training value × feasibility.

1. **Frame-accurate timer and a 40-line sprint mode.**
   The qualification format of the largest offline Game Boy Tetris tournament, and the original game
   has no timer whatsoever. Highest-value, most obviously missing, entirely Game Boy-specific.

2. **Start on any level 0–20 with heart levels toggleable.**
   The competitive start-level space is 20 values wide (0–9, 0♥–9♥) and level 20♥ is the game's
   speed ceiling that is otherwise hundreds of lines away. Costs almost nothing to implement.

3. **Instant restart of the current scenario.**
   The multiplier on every other feature: it converts one 5-minute attempt into twenty 15-second
   drills. The soft-reset input already exists in the original code.

4. **Seeded / repeatable piece sequences.**
   Makes attempts comparable, reproduces VS conditions, and is the substrate for drought and
   scripted drills. The original ROM already contains the entire mechanism for link-cable play.

5. **VS-style garbage and dig practice.**
   The bracket phase of Game Boy CTWC events is head-to-head VS, and the original's garbage rules
   (single aligned hole, 1/2/4 lines, 30-line auto-win) are a precise, already-implemented spec.

6. **Preset board / floor / garbage-height setup at game start.**
   The cheapest possible way to practise a specific situation, and the foundation every other board
   feature builds on.

7. **Savestates in SRAM.**
   Turns "a board I set up once" into "a board I can attempt fifty times". Requires the cartridge
   change we already need for ROM space, so its marginal cost is low.

8. **Uncapped score and extended line counter.**
   The 999 999 cap actively hides performance from the people chasing 300 k and maxout categories.

9. **DAS delay control plus an on-screen DAS charge indicator.**
   The most-discussed open feature request in the reference project, and on Game Boy the delay is a
   single byte. The indicator turns an invisible mechanic into a trainable one.

10. **Board editor plus piece statistics / drought counter.**
    The "author your own drill" tool, and the information layer that tells you whether a bad run was
    your stacking or the ROM's biased randomizer.

**Explicitly excluded from the top 10 and from the project:** hard drop, hold, ghost piece, SRS,
3-piece preview (they make a different game — Rosy Retrospection already exists for that audience);
PAL/NTSC modes (meaningless on Game Boy); NES crash-bug recreation; T-spin trainers; and the full
tap/roll/Hz suite, which is far less decisive with Game Boy's 23-frame DAS than with NES's 16.

---

## 6.1 Revised top 10 after first community contact (2026-08-20) — SUPERSEDED by §6.2

The §6 list above was derived from structural evidence alone and is **kept as-is for the audit
trail**. This is the revision after §3.4. Changes are marked.

| # | Feature | Change |
| --- | --- | --- |
| 1 | **SPS — standardised Same Piece Set (seeded, shared piece sequences)** | ⬆ from #4. Named as the blocker for a physical cart run, and `docs/research.md` §3.5 shows the deterministic path already exists in the ROM. Highest value-to-cost ratio in the project. |
| 2 | **Extended level select — levels 0–20, hearts toggleable, no menu grind** | = #2. The community already hand-hacked this; being a clean superset is table stakes. |
| 3 | **Transition trainer — start near the end of a 9-start's 100-line grind** | ⬆ **from DROP.** Named as the single most annoying thing in a practitioner's routine. |
| 4 | **Instant restart of the current drill** | = #3. Multiplier on everything else. |
| 5 | **Floor mode / preset boards / garbage height at start** | = #6, explicitly requested. |
| 6 | **Hz / tap-rate counter** | ⬆ **from #20 ("low value on GB").** Explicitly requested; players do train tap skill. |
| 7 | **Low stack** | ⬆ from #17, explicitly requested and unbundled. |
| 8 | **Frame-accurate timer + 40-line sprint** | ⬇ from #1 — *provisionally, pending §7 A8.* Still backed by the CTWC France qualification format, but no practitioner has yet asked for it. **Do not drop; do ask.** |
| 9 | **Uncapped score / extra score digit** | = #8. Already hand-hacked by the community. |
| 10 | **VS-style garbage / dig practice** | ⬇ from #5. Still strong on tournament-format evidence, but unmentioned first-hand. |

Savestates, board editor, DAS control and piece statistics remain valuable and move just below the
top 10. Nothing was demoted out of the plan; the reordering reflects who asked, not what is possible.

**Method note.** Two of the four corrections in §3.4.1 came from reasoning about mechanics instead of
asking practitioners — a transition trainer dismissed on an NES-shaped analogy, and a tap-rate
counter dismissed from a DAS frame count. Both were confidently wrong. **Treat mechanics-derived
feature judgements as hypotheses, not conclusions**, and weight §7's open actions accordingly.

## 6.2 FINAL top 10 — after channel archaeology (supersedes §6 and §6.1)

§6 was structural inference. §6.1 over-corrected on one practitioner. **This is the ranking backed by
five years of the community's own conversation** (§3.5). §6 and §6.1 are retained for the audit trail.

The community has effectively already written the product definition:

> *"a competition rom with **A-M starts and SPS** would be the top of the list"* — nells

| # | Feature | Evidence | Status today |
| --- | --- | --- | --- |
| 1 | **SPS — same piece sequence, seeded and shareable** | Asked for repeatedly, by name, 2022→2026, by at least five people. *"never finished"*, *"no standard SPS rom yet"* | **Does not exist.** Our cheapest big win (`docs/research.md` §3.5) |
| 2 | **Extended level select A–M (10–22), hearts, no menu grind** | KLM is the de-facto standard ROM; leagues start on F and hearts; L starts have their own PB ladder | Exists as KLM — **we must match it or we are a downgrade** |
| 3 | **40-line sprint with a built-in frame timer** | The live-tournament qualification format; one of the two most-used ROMs | Exists (Pascal/Tolstoj) — **integrate and standardise, don't reinvent** |
| 4 | **Score uncap / extended digits** | Folded into KLM and in daily use | Exists — match it |
| 5 | **Instant restart / zero-friction reset into the drill** | Pascal's qual-ROM design notes are explicitly built around this | Partially exists (rocket skip, straight-to-menu) |
| 6 | **Transition trainer (the 9→10, 100-line grind)** | Named as the most annoying grind; *"closest thing we have"* workarounds discussed | **mathmaster13 is already building one — coordinate** |
| 7 | **Hz / tap-rate counter** | Requested; absent; Tolstoj proposed porting TetrisGYM's `hz.asm` | **Does not exist.** Cap at SHOULD — §3.5.5 |
| 8 | **Floor mode / preset boards / garbage height** | Requested in §3.4; standard Gym fare | Does not exist |
| 9 | **Low stack** | Requested in §3.4 | Does not exist |
| 10 | **VS-style garbage / dig practice** | The bracket format is link-cable VS | Does not exist |

**The MVP is now demand-pulled rather than inferred: a single, tested, buildable ROM with A–M level
starts + working SPS.** Everything else is follow-on.

### 6.2.1 Method post-mortem

Three rounds, three different rankings. Worth recording *why*:

| Round | Basis | Error |
| --- | --- | --- |
| §6 | Tournament formats, leaderboards, ROM internals | Missed SPS entirely — the community's #1 for five years — because it is invisible from outside |
| §6.1 | One practitioner's reply | Over-corrected: demoted the sprint timer, which the channel shows is one of the two most-used ROMs |
| **§6.2** | Five years of channel conversation | Best available. Still second-hand; keep asking |

**The generalisable lesson: desk research found the right shape and the wrong contents.** Structural
evidence (tournaments, leaderboards, disassemblies) reliably identified *what players compete at*,
but could not see *what they had already built, what they had given up on, or what they call things*.
Both errors — missing SPS, demoting the timer — were failures to ask. Weight §7's open actions
accordingly, and prefer "ask the channel" over "reason from the ROM" whenever both are available.

## 7. Confidence, gaps, and how to close them

**What I am confident about:** the existence, scale, continuity and *formats* of the competitive
Game Boy Tetris scene; the mechanics that constrain feature design; the absence of any existing
Game Boy training ROM. All of this rests on structural, multi-source, machine-readable evidence.

**What I am not confident about:** the *relative* ranking of features 5–10, and whether the scene
would rather have depth in VS practice or breadth across drills. That is opinion data, and the
opinion data lives where I could not reach it.

**Actions to close the gaps — do these before locking the roadmap beyond Milestone 2:**

| # | Action | Why |
| --- | --- | --- |
| A1 | **Join the GBTetris Discord and ask directly.** Post the top-10 list and ask what is missing and what is mis-ranked. | The single highest-value research action available. It is also how this project finds its first users and contributors. |
| A2 | Manually search r/Tetris and r/classictetris for Game Boy practice threads | Reddit was inaccessible to this session's tooling; it is a genuine blind spot |
| ~~A3~~ | **RESOLVED (§3.5.6): v1.1 is the community standard.** ~~Confirm which ROM version the communities treat as canonical~~ | We recommend v1.1 on technical grounds (`docs/research.md` §2.1); confirm it matches their rules |
| A4 | Ask what the CTWCGB *online* qualifier format is (the France event's 40L sprint is documented; the world championship's is not) | Determines whether the sprint mode needs a 40-line or a different target |
| A5 | Ask whether players use emulator (BGB is referenced in the scene), flash cart, or original hardware — and which flash carts | Determines how much the MBC1/SRAM requirement actually costs real users |
| A6 | Ask whether a link-cable-capable trainer (two modded carts playing VS with a shared seed) is wanted | Would be a genuinely novel capability with no NES equivalent, but it is expensive; only build it on demand |
| A7 | **Catalogue the Discord's existing-ROM channel** and obtain the "more level starts + score digit + rocket skip" hack | We must be a superset of what people already use, and must not duplicate work the local romhackers have done |
| A8 | Ask directly whether a timer / 40-line sprint mode is wanted | Our §6 #1 rests on tournament format, not on any practitioner having asked for it |
| ~~A9~~ | **RESOLVED (§3.5.2): L = level 21 in the KLM hack, with a properly extended gravity table.** |
| ~~A8~~ | **RESOLVED (§3.5.4): yes — a timer ROM exists and is the qual format. The §6.1 demotion was wrong.** |
| A12 | **Reply to Tolstoj's standing offer to hand off KLM hosting** (§3.5.8) | The strategic opening. Our M0 (byte-exact build + regression test) is precisely the thing whose absence broke his refactor |
| A13 | **Contact mathmaster13** about the in-progress transition trainer | Avoid duplicating work; possibly adopt it |
| A14 | Obtain the unfinished SPS ROM and ask what stalled it | Five years of "never finished" implies a real obstacle worth knowing before we start |
| A15 | Ask Pascal/Tolstoj for the qual ROM's exact timer start/stop semantics | Ours must agree to the frame, or times are not comparable (§3.5.4) |
| A10 | Ask **Gunter** which cartridge board is cheap to produce, and whether battery SRAM is acceptable | Directly determines D5 (mapper choice) and whether SRAM may be assumed |
| A11 | Ask what the existing "imperfect" SPS does — fixed sequence or genuinely seeded? | Determines whether we extend it or replace it, and what compatibility people expect |

---

## 8. Sources

* [Liquipedia — CTWCGB/2025](https://liquipedia.net/tetris/CTWCGB/2025) · [CTWCGB/2024](https://liquipedia.net/tetris/CTWCGB/2024) · [CTWC France/2026/Game Boy](https://liquipedia.net/tetris/CTWC_France/2026/Game_Boy)
* [speedrun.com — Tetris (Game Boy)](https://www.speedrun.com/tetrisgb) and its public API (categories, variables, leaderboards, run submissions)
* [kirjavascript/TetrisGYM](https://github.com/kirjavascript/TetrisGYM) — README, CHANGELOG, [issues](https://github.com/kirjavascript/TetrisGYM/issues) (notably [#134](https://github.com/kirjavascript/TetrisGYM/issues/134))
* [Hard Drop Wiki — Tetris (Game Boy)](https://harddrop.com/wiki/Tetris_(Game_Boy)) — randomizer bias, DAS values, v1.0 differences, B-Type endings
* [TetrisWiki — Tetris (Game Boy)](https://tetris.wiki/Tetris_(Game_Boy)) — timings, level table, VS garbage rules
* [TCRF — Tetris (Game Boy)](https://tcrf.net/Tetris_(Game_Boy)) — revisional differences
* [romhacking.net — Tetris (GB) hacks](https://www.romhacking.net/games/2622/): [Rosy Retrospection](https://www.romhacking.net/hacks/5813/), [Rosy Retrospection DX](https://www.romhacking.net/hacks/8259/), [Max Speed](https://www.romhacking.net/hacks/7896/), [highscore save](https://www.romhacking.net/hacks/4545/)
* [svendahlstrand/itris](https://github.com/svendahlstrand/itris) — GB Tetris romhack precedent
* [tetrisconcept.net — GB Tetris 999999](https://tetrisconcept.net/threads/game-boy-tetris-score-of-999999-points-and-9999-lines.1402/)
* [Guinness — Highest score on Tetris for Game Boy](https://www.guinnessworldrecords.com/world-records/385225-highest-score-on-tetris-for-game-boy)
* [Classic Tetris World Championship](https://thectwc.com/) · [Classic Tetris Monthly server list](https://ctm.gg/servers/)

---

## 8. Requests after the v0.2.0 release (GBTetris Discord, 2026-08-21)

First contact with players actually holding the ROM, rather than describing what
they would want. Recorded as evidence, not as a plan — §6.2's ranking still
governs order.

| Asked for | By | Notes |
| --- | --- | --- |
| **Crunch trainer** | báovofe67 [TAWS] — and a second person earlier the same day | **Two independent requests, unprompted, and the only feature named twice.** Costed in `docs/existing-hacks.md`: no new hooks needed |
| **A way out of a drill** back to the level select | báovofe67 [TAWS] | See below — this is a naming collision, not a missing feature |
| **(Quick)tap trainer and tap-quantity trainer** | toni | Both exist in TetrisGYM. GB's DAS is 23+9, not 16+6, so the thresholds do not port |
| **Six-digit seeds** | Hepta [PADX] | **Second independent voice after Tolstoj**, who asked for the same thing by DM the same morning. Ours is 16-bit, chosen for compatibility with the seeded ROM in circulation |

### 8.1 `A+B+Select+Start` means something different here

> *"also can you made smt to get out of the game … like a+b+select+start in
> tetrisgym"* — báovofe67 [TAWS]

In TetrisGYM that combination returns you to the **menu**. Here it restarts the
current drill in place (ADR 0005), which was a deliberate choice — *"when you are
drilling you want another go"* — and is the behaviour the Game Boy's own soft
reset already had.

Both are useful and they are not the same thing. A player arriving from the NES
ROM will expect the menu. **This is the first evidence that our instant restart
is surprising to someone who knows TetrisGYM**, and it is worth solving as *two*
gestures rather than by changing what the existing one does.

### 8.2 Bug: the reset combination does nothing while paused

> *"i notice that if you restart, the next box will turn off"* — báovofe67 [TAWS]

The report as written does not reproduce: the next-piece preview is four sprites
at OAM 8–11, and it stayed present and correctly placed across restarts during
play, from the game-over screen and inside a transition drill, sampled every ten
frames for two hundred frames after.

**What does reproduce is next to it.** Giovanni's reading — that the player is
fumbling the combination and pressing Start first — leads straight to a real
bug:

| | |
| --- | --- |
| `A+B+Select+Start` while playing | restarts, as designed |
| Start pressed first, then the combination | **nothing happens; the game stays paused** |

Start alone pauses. Pausing switches the background map from `$9800` to `$9C00`
— the PAUSE screen, where the playfield is replaced by text, which is the
original's own anti-cheat behaviour and is very likely the "box" that appeared
to turn off. From there the combination is swallowed and the drill never
restarts, so instant restart looks broken to the person using it.

**This is worth fixing:** the combination should restart from a paused game too.
It sits in `InGameCheckResetAndPause`, the same routine ADR 0005 already hooks.
