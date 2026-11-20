# Pack-hero (working title)

A hero against a big knight, step by step, with free movement. The puppets'
swings are simulated, so the blade's real size is what hits. The raptor fight
from Pack-free is kept (R on the title, PC only). See PLAN.md.

- `play.bat` starts it.
- Tests: `godot --headless --path . --script res://tests/smoke.gd`
- Phone: `build_apk.bat` makes `build/Pack-hero.apk`; `build_apk.bat install`
  also installs it on a phone plugged in by USB (USB debugging on).
- New version for phones: `python tools/release.py 0.2 "what changed"` builds,
  commits, pushes and makes a GitHub release; the game's update button on the
  title finds it.
