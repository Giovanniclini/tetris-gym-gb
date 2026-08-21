#!/usr/bin/env python3
"""SPS - same piece sequence.

    .venv/bin/python tests/test_sps.py

The generator is the community's LFSR, transcribed byte for byte, so that a
given seed produces the same pieces here as on their ROM. For a fairness
mechanism interoperability is the feature; see docs/existing-hacks.md section 4.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from tools.emu import Tetris, sym, hATypeLevel, GS_IN_GAME_MAIN  # noqa: E402

ROM = "build/tetrisgym.gb"
wGymRngLo, wGymRngHi = sym("wGymRngLo"), sym("wGymRngHi")
wGymSeedLo, wGymSeedHi = sym("wGymSeedLo"), sym("wGymSeedHi")
GS_IN_GAME_INIT = 0x0A
hGymSpsEnabled = 0xFFFE
hHiddenLoadedPiece = 0xFFAE
rDIV = 0xFF04

# The retry loop draws up to three times per piece, so per-frame sampling can
# miss intermediate LFSR steps.
MAX_DRAWS_PER_PIECE = 3


def lfsr_step(h, l):
    """The community ROM's LFSR at $0532, transcribed in docs/existing-hacks.md."""
    a, c = h, 0
    a = ((a >> 1) | (c << 7)) & 0xFF
    c = h & 1
    a = ((l >> 1) | (c << 7)) & 0xFF
    c = l & 1
    a ^= h
    h2 = a
    c = 0
    a = ((l >> 1) | (c << 7)) & 0xFF
    c = l & 1
    a = ((h2 >> 1) | (c << 7)) & 0xFF
    a ^= l
    l2 = a
    return a ^ h2, l2


def arm(t, seed):
    t.pb.memory[wGymRngLo] = seed & 0xFF
    t.pb.memory[wGymRngHi] = seed >> 8
    t.pb.memory[hGymSpsEnabled] = 1


def piece_sequence(seed, frames=3000):
    with Tetris(ROM) as t:
        t.start_game_at(9)
        t.tick(30)
        arm(t, seed)
        seq, last = [], t[hHiddenLoadedPiece]
        for _ in range(frames):
            t.tick(1)
            v = t[hHiddenLoadedPiece]
            if v != last:
                seq.append(v)
                last = v
        return seq


def test_the_same_seed_gives_the_same_pieces():
    a = piece_sequence(0xACE1)
    b = piece_sequence(0xACE1)
    assert len(a) >= 8, f"only {len(a)} pieces observed"
    assert a == b, f"not deterministic:\n  {a}\n  {b}"


def test_different_seeds_give_different_pieces():
    a = piece_sequence(0xACE1)
    b = piece_sequence(0x1234)
    assert a != b, "two seeds produced the same sequence"


def test_the_lfsr_matches_the_community_rom():
    """Every state our ROM reaches must appear, in order, in the sequence the
    transcribed model produces - allowing for steps we cannot see, since the
    retry loop can draw up to three times inside a single frame.
    """
    seed = 0xACE1
    h, l = seed >> 8, seed & 0xFF
    model = []
    for _ in range(200):
        h, l = lfsr_step(h, l)
        model.append((h, l))

    with Tetris(ROM) as t:
        t.start_game_at(9)
        t.tick(30)
        arm(t, seed)
        seen, last = [], (t[wGymRngHi], t[wGymRngLo])
        for _ in range(3000):
            t.tick(1)
            cur = (t[wGymRngHi], t[wGymRngLo])
            if cur != last:
                seen.append(cur)
                last = cur

    assert len(seen) >= 8, f"only {len(seen)} states observed"
    i = 0
    for state in seen:
        gap = 0
        while i < len(model) and model[i] != state:
            i += 1
            gap += 1
            assert gap <= MAX_DRAWS_PER_PIECE, (
                f"state {state[0]:02X}{state[1]:02X} is not the model's next "
                f"(searched {gap} ahead)"
            )
        assert i < len(model), f"state {state[0]:02X}{state[1]:02X} never occurs in the model"
        i += 1


def test_sps_off_leaves_the_original_generator_alone():
    """With SPS disabled the LFSR must not run at all - pieces come from rDIV,
    as they always did.

    Note this cannot be shown by comparing two runs: the emulator is
    deterministic, so rDIV yields the same values at the same cycle counts and
    identical runs look "seeded". Assert instead that the LFSR state never
    advances, which is only true if the rDIV branch is being taken.
    """
    with Tetris(ROM) as t:
        t.start_game_at(9)
        assert t[hGymSpsEnabled] == 0, "SPS should default to off"
        before = (t[wGymRngHi], t[wGymRngLo])
        pieces, last = 0, t[hHiddenLoadedPiece]
        for _ in range(3000):
            t.tick(1)
            v = t[hHiddenLoadedPiece]
            if v != last:
                pieces += 1
                last = v
        assert pieces >= 8, f"only {pieces} pieces drawn; the test proves nothing"
        assert (t[wGymRngHi], t[wGymRngLo]) == before, (
            "the LFSR advanced while SPS was off - the rDIV branch is not taken"
        )


def test_a_seed_of_zero_means_no_seed():
    """$0000 is spent as the "off" value rather than left as a trap.

    It is also a degenerate LFSR state - period 1, every draw returns zero - so
    the community's ROM, which offers it as a default and does not guard it, can
    reach it. Ours cannot: zero disarms SPS and pieces come from rDIV, which is
    genuinely random. That is why there is no "randomise" button.
    """
    h, l = 0, 0
    for _ in range(5):
        h, l = lfsr_step(h, l)
        assert (h, l) == (0, 0), "the model should confirm $0000 is a fixed point"

    with Tetris(ROM) as t:
        t.to_level_select()
        t.pb.memory[wGymSeedLo] = 0
        t.pb.memory[wGymSeedHi] = 0
        t.pb.memory[hATypeLevel] = 9
        t.press("start")
        t.run_until_state(GS_IN_GAME_MAIN)
        assert t[hGymSpsEnabled] == 0, "a zero seed should leave SPS off"


def test_the_seed_is_reloaded_at_the_start_of_every_game():
    """A restart must repeat the sequence, not continue it."""
    def lfsr_at_init(t, limit=200):
        seen = []
        for _ in range(limit):
            t.tick(1)
            if t.state == GS_IN_GAME_INIT:
                seen.append((t[wGymRngHi] << 8) | t[wGymRngLo])
                if len(seen) >= 3:
                    break
        return seen

    with Tetris(ROM) as t:
        t.to_level_select()
        t.pb.memory[wGymSeedLo] = 0xE1
        t.pb.memory[wGymSeedHi] = 0xAC
        t.pb.memory[hATypeLevel] = 9
        t.press("start")
        t.run_until_state(GS_IN_GAME_MAIN)
        t.tick(600)
        mid = (t[wGymRngHi] << 8) | t[wGymRngLo]
        assert mid != 0xACE1, "the LFSR should have advanced during play"

        for b in ("a", "b", "select", "start"):
            t.pb.button_press(b)
        seen = lfsr_at_init(t)
        for b in ("a", "b", "select", "start"):
            t.pb.button_release(b)
        assert 0xACE1 in seen, (
            f"seed not reloaded on restart; saw {[hex(v) for v in seen]}"
        )


def test_seed_can_be_entered_from_the_menu():
    """The SEED row of the Gym menu: A opens the digits, Left/Right pick one,
    Up/Down change it. See docs/decisions/0007."""
    with Tetris(ROM) as t:
        t.to_title()
        t.press("start")
        t.run_until_state(0x0E)                # the Gym menu
        t.tick(20)
        for _ in range(3):
            t.press("down")                    # TETRIS -> ... -> SEED
        t.press("a")                           # open the digits
        for nibble in (0xA, 0xC, 0xE, 0x1):
            for _ in range(nibble):
                t.press("up")
            t.press("right")
        t.press("a")                           # close them
        for _ in range(3):
            t.press("up")                      # back up to TETRIS
        seed = (t[wGymSeedHi] << 8) | t[wGymSeedLo]
        assert seed == 0xACE1, f"typed $ACE1, got ${seed:04X}"

        t.press("start")                       # TETRIS -> the level select
        t.run_until_state(0x11)
        t.tick(6)
        t.press("start")
        t.run_until_state(GS_IN_GAME_MAIN)
        assert t[hGymSpsEnabled] != 0, "a non-zero seed should arm SPS"


TESTS = [v for k, v in sorted(globals().items()) if k.startswith("test_")]

if __name__ == "__main__":
    failures = 0
    for fn in TESTS:
        try:
            fn()
            print(f"PASS  {fn.__name__}")
        except AssertionError as exc:
            failures += 1
            print(f"FAIL  {fn.__name__}: {exc}")
    print(f"\n{len(TESTS) - failures}/{len(TESTS)} passed")
    raise SystemExit(1 if failures else 0)
