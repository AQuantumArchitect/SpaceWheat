#!/usr/bin/env python3
"""Godot runtime wallet-source-isolation referee; no game autoloads or physics."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

GDSCRIPT = r'''extends SceneTree
class Economy extends Node:
    signal resource_changed(emoji: String, amount: int)
    var emoji_credits: Dictionary = {}
    func get_resource(emoji: String) -> int:
        return int(emoji_credits.get(emoji, 0))
    func set_resource(emoji: String, amount: int) -> void:
        emoji_credits[emoji] = amount
        resource_changed.emit(emoji, amount)

var failures: Array[String] = []
func require(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var panel = load("res://UI/Widgets/ResourcePanel.gd").new()
    root.add_child(panel)
    var old_wallet = Economy.new()
    old_wallet.emoji_credits = {"grain": 7, "timber": 4}
    root.add_child(old_wallet)
    var new_wallet = Economy.new()
    new_wallet.emoji_credits = {"grain": 0, "bread": 2}
    root.add_child(new_wallet)
    panel.connect_to_economy(old_wallet)
    require(panel.get_snapshot().resources == {"grain": 7, "timber": 4}, "initial wallet must mirror its authoritative balances")
    panel.connect_to_economy(new_wallet)
    require(panel.economy_ref == new_wallet, "rebind must select new authority")
    require(panel.get_snapshot().resources == {"bread": 2}, "rebind must remove currencies absent or zero in new wallet")
    require(old_wallet.resource_changed.get_connections().is_empty(), "old authority must disconnect on rebind")
    old_wallet.set_resource("grain", 99)
    require(panel.get_snapshot().resources == {"bread": 2}, "retired economy must not change current wallet display")
    new_wallet.set_resource("bread", 6)
    require(panel.get_snapshot().resources == {"bread": 6}, "new authority signals must update live wallet")
    panel.connect_to_economy(new_wallet)
    require(new_wallet.resource_changed.get_connections().size() == 1, "repeat bind must keep one callback")
    new_wallet.set_resource("bread", 0)
    require(panel.get_snapshot().resources.is_empty(), "live zero balance must disappear")
    panel.free()
    old_wallet.free()
    new_wallet.free()
    if failures.is_empty():
        print("S3_WALLET_REBIND_PASS")
        quit(0)
    else:
        for failure in failures:
            print("S3_WALLET_REBIND_FAIL: " + failure)
        quit(1)
'''

# Only the glyph art adapter is inert; counters, labels, sorting and signal
# lifecycle run in the actual candidate widget and actual Godot controls.
GLYPH = '''class_name EmojiDisplay
extends Control
var emoji: String = ""
var font_size: int = 17
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-root", default=".")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "/home/primearchitect/.local/bin/godot"))
    args = parser.parse_args()
    source_root = Path(args.source_root).resolve()
    candidate = source_root / "UI/Widgets/ResourcePanel.gd"
    digest = hashlib.sha256(candidate.read_bytes()).hexdigest()
    with tempfile.TemporaryDirectory(prefix="s3-wallet-referee-") as tmp:
        project = Path(tmp)
        (project / "project.godot").write_text('[application]\nconfig/name="S3 isolated wallet referee"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        for relative in ("UI/Widgets/ResourcePanel.gd", "UI/Core/UIStyleFactory.gd"):
            target = project / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source_root / relative, target)
        (project / "EmojiDisplay.gd").write_text(GLYPH, encoding="utf-8")
        (project / "wallet.gd").write_text(GDSCRIPT, encoding="utf-8")
        imported = subprocess.run([args.godot, "--headless", "--audio-driver", "Dummy", "--path", str(project), "--editor", "--quit"], capture_output=True, text=True, timeout=40)
        result = subprocess.run([args.godot, "--headless", "--audio-driver", "Dummy", "--path", str(project), "--script", "res://wallet.gd"], capture_output=True, text=True, timeout=40)
    output = imported.stdout + imported.stderr + result.stdout + result.stderr
    print(output)
    errors = any(marker in output for marker in ("SCRIPT ERROR", "Parse Error", "ERROR:"))
    passed = imported.returncode == result.returncode == 0 and "S3_WALLET_REBIND_PASS" in output and not errors
    print(json.dumps({"candidate": str(candidate), "sha256": digest, "godot_exit": result.returncode,
                      "passed": passed, "fixture": "actual-widget-synthetic-economies-inert-glyph-art"}))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
