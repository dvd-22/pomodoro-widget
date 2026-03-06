# Pomodoro Timer — KDE Plasma 6 Plasmoid

A taskbar pomodoro widget for KDE Plasma 6. Sits in your panel, shows a countdown, and fills up as the session progresses.

![License](https://img.shields.io/badge/license-GPL--2.0-blue)
![Plasma](https://img.shields.io/badge/Plasma-6-informational)

---

## What it does

- Lives in your taskbar. Small clock icon + countdown, no fuss.
- The background fills left to right as the current block progresses — red for work, green for breaks.
- Click it to open the full popup: big timer, a scrollable session timeline where the current block is always centered, start/end times, and blocks remaining.
- Skip button if you want to move on early.
- Two built-in presets (25+5 and 50+10). Add your own through the config window.
- Right-click → Configure (or the + button in the popup) to build custom presets — either with the quick-fill tool or block by block.

## Install

```bash
git clone https://github.com/yourusername/pomodoro-plasmoid
cd pomodoro-plasmoid
chmod +x install.sh
./install.sh
```

Then right-click your panel → **Edit Panel** → **Add Widgets** → search **Pomodoro Timer**.

### Requirements

- KDE Plasma 6
- Arch Linux (or any distro with Plasma 6 — not tested elsewhere but should work)

## Usage

The widget loads your default preset on start. Hit **Start**, walk away, come back when it beeps mentally.

The timeline in the popup shows every block in order. Past ones are greyed out, the current one is centered and highlighted, upcoming ones are dimmed to the right.

To build a custom preset:

1. Right-click the widget → **Configure Pomodoro Timer**
2. Use **Quick fill** (e.g. 4× 25m work / 5m break) or add blocks one by one
3. Give it a name, save it
4. It shows up as a button in the popup and in the default preset dropdown

## File structure

```
com.pomodoro.timer/
├── metadata.json
└── contents/
    ├── config/
    │   ├── config.qml      # registers config tabs
    │   └── main.xml        # config key definitions
    └── ui/
        ├── main.qml        # widget + popup
        └── configGeneral.qml  # configure window
```

Any PR is welcomed! Hope this helps you stay focused and productive. Happy pomodoro-ing!
