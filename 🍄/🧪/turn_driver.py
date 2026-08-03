#!/usr/bin/env python3
"""Shared turn-driver DSL for 🧪 probe/drive scripts (SLOP_PATROL_2026-07-29 knot #8).

Every probe used to hand-roll the same three closures: a monotonically
increasing turn counter ``t()``, a ``go(action, **kwargs)`` wrapper around
``RigClient.run_turn``, and a ``press(seq)`` key-press loop.  This module is
the single home for that boilerplate.

Timeouts are deliberately NOT unified: each script passes its own historical
values explicitly (``GO_TIMEOUT_S`` / ``PRESS_TIMEOUT_S`` / ``PRESS_SETTLE_FRAMES``
constants at the top of the script).  There is no canonical timeout here —
``make_go`` / ``make_press`` require them as explicit keyword arguments.

Usage (module top, after the rig_client sys.path insert):

    from turn_driver import TurnDriver

    GO_TIMEOUT_S = 90
    PRESS_TIMEOUT_S = 25
    PRESS_SETTLE_FRAMES = 4

    _driver = TurnDriver(start=10)
    t = _driver.t

    def main():
        c = RigClient()
        ...
        go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S)
        press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES,
                                   timeout_s=PRESS_TIMEOUT_S)
"""


class TurnDriver:
    """Turn counter + factories for the go/press probe DSL."""

    def __init__(self, start=0):
        self._turn = [start]

    def t(self):
        """Increment and return the turn counter (the classic ``t()``)."""
        self._turn[0] += 1
        return self._turn[0]

    @property
    def turn(self):
        """Current turn number WITHOUT incrementing (for filenames etc.)."""
        return self._turn[0]

    def reset(self, value):
        """Set the turn counter to an explicit value (mid-run phase jumps)."""
        self._turn[0] = value

    def make_go(self, client, *, timeout_s, caller_override=False):
        """Return ``go(action, **kwargs)`` bound to *client*.

        caller_override=False (dominant probe idiom): any caller-supplied
        ``timeout_s`` is discarded and the script's fixed timeout is used.
        caller_override=True: caller ``timeout_s`` wins; *timeout_s* is the
        default (the ``kw.pop("timeout_s", N)`` / ``setdefault`` idiom).
        """
        def go(action, **kwargs):
            if caller_override:
                to = kwargs.pop("timeout_s", timeout_s)
            else:
                kwargs.pop("timeout_s", None)
                to = timeout_s
            return client.run_turn(self.t(), action, timeout_s=to, **kwargs)
        return go

    def make_press(self, client, *, settle_frames, timeout_s):
        """Return ``press(seq, settle=None)`` bound to *client*.

        *seq* is a key name or list of key names; each key is one turn.
        *settle* (positional or keyword) overrides the script's default
        settle frames for that call.
        """
        def press(seq, settle=None):
            frames = settle_frames if settle is None else settle
            if isinstance(seq, str):
                seq = [seq]
            for key in seq:
                client.run_turn(self.t(), "press_key", key=key,
                                settle_frames=frames, timeout_s=timeout_s)
        return press

    def make_client_go(self, *, timeout_s, caller_override=True):
        """Return ``go(client, action, **kwargs)`` — the explicit-client idiom
        (save_verify_campaign_probe / self_tab_screenshot_probe family)."""
        def go(client, action, **kwargs):
            if caller_override:
                to = kwargs.pop("timeout_s", timeout_s)
            else:
                kwargs.pop("timeout_s", None)
                to = timeout_s
            return client.run_turn(self.t(), action, timeout_s=to, **kwargs)
        return go

    def make_client_press(self, *, settle_frames, timeout_s):
        """Return ``press(client, seq, settle=None)`` — explicit-client idiom."""
        def press(client, seq, settle=None):
            frames = settle_frames if settle is None else settle
            if isinstance(seq, str):
                seq = [seq]
            for key in seq:
                client.run_turn(self.t(), "press_key", key=key,
                                settle_frames=frames, timeout_s=timeout_s)
        return press
