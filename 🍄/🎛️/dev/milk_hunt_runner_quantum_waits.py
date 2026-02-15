#!/usr/bin/env python3
import os
import runpy
from pathlib import Path

TARGET = Path(__file__).with_name("milk_hunt_runner_graphics_waits.py")
if not os.environ.get("MILK_HUNT_SILENT_RENAME_NOTICE"):
    print("[rename] milk_hunt_runner_quantum_waits.py -> milk_hunt_runner_graphics_waits.py", flush=True)
runpy.run_path(str(TARGET), run_name="__main__")
