"""Cross-check the Niri profile's key bindings against the installed Noctalia.

Usage: python3 -I tests/check_niri_keybinds.py ~/.config/niri/config.kdl

Run it where the profile was applied (it needs the `noctalia` binary). It
fails if a binding calls a `noctalia msg` command or argument this Noctalia
version doesn't accept, if a key is bound twice, or if one of the profile's
promised shortcuts is missing.
"""

import re
import shlex
import subprocess
import sys

# Panel ids from Noctalia 5.4.1's docs (docs/user/ipc/surfaces.mdx); the CLI
# help doesn't enumerate them.
PANEL_IDS = {'launcher', 'session', 'clipboard', 'wallpaper', 'control-center'}

# Shortcuts NIRI.md documents. Values are the action each must run.
EXPECTED = {
    'Mod+T': 'spawn "ghostty"',
    'Mod+Space': 'panel-toggle launcher',
    'Mod+Comma': 'settings-toggle',
    'Mod+S': 'panel-toggle control-center',
    'Mod+L': 'session lock',
    'Mod+Q': 'close-window',
    'Mod+F': 'fullscreen-window',
    'Mod+V': 'toggle-window-floating',
    'Mod+Shift+V': 'panel-toggle clipboard',
    'XF86AudioRaiseVolume': 'volume-up',
    'XF86AudioLowerVolume': 'volume-down',
    'XF86AudioMute': 'volume-mute',
    'XF86AudioMicMute': 'mic-mute',
    'XF86MonBrightnessUp': 'brightness-up',
    'XF86MonBrightnessDown': 'brightness-down',
    'XF86AudioPlay': 'media toggle',
}

BIND = re.compile(r'^\s*([A-Za-z0-9_+]+)((?:\s+[a-z-]+=(?:"[^"]*"|\S+))*)\s*\{\s*(.*?);?\s*\}\s*$')


def binds_block(text):
    start = text.index("\nbinds {") + 1
    depth = 0
    for index in range(start, len(text)):
        if text[index] == '{':
            depth += 1
        elif text[index] == '}':
            depth -= 1
            if depth == 0:
                return text[start:index + 1]
    raise ValueError('unterminated binds block')


def noctalia_help(*args):
    result = subprocess.run(['noctalia', 'msg', *args, '--help'], capture_output=True, text=True)
    return result.stdout + result.stderr


def main(path):
    with open(path) as handle:
        block = binds_block(handle.read())

    commands = set(re.findall(r'^  ([a-z][a-z-]+)\b', noctalia_help(), re.MULTILINE))
    if 'panel-toggle' not in commands:
        sys.exit('could not read the command list from `noctalia msg --help`')

    errors = []
    seen = {}
    for line in block.splitlines()[1:-1]:
        line = line.split('//', 1)[0].rstrip()
        if not line.strip():
            continue
        match = BIND.match(line)
        if not match:
            errors.append('unparsed binding line: ' + line.strip())
            continue
        key, _, action = match.groups()
        if key in seen:
            errors.append('{} is bound twice'.format(key))
        seen[key] = action

        if not action.startswith('spawn "noctalia" "msg"'):
            continue
        argv = shlex.split(action[len('spawn '):])[2:]
        command, rest = argv[0], argv[1:]
        if command not in commands:
            errors.append('{}: `noctalia msg {}` does not exist'.format(key, command))
            continue
        if command in ('panel-toggle', 'panel-open') and rest[0] not in PANEL_IDS:
            errors.append('{}: unknown panel id {!r}'.format(key, rest[0]))
        choices = re.search(r'one of: ([^\n]+)', noctalia_help(command))
        if choices and rest and not rest[0].startswith('--'):
            allowed = [choice.strip() for choice in choices.group(1).split(',')]
            if rest[0] not in allowed:
                errors.append('{}: {!r} is not one of {}'.format(key, rest[0], allowed))
        options = set(re.findall(r'(--[a-z-]+)', noctalia_help(command)))
        for option in (arg for arg in rest if arg.startswith('--')):
            if option not in options:
                errors.append('{}: `noctalia msg {}` has no {} option'.format(key, command, option))

    for key, wanted in EXPECTED.items():
        action = seen.get(key)
        if action is None:
            errors.append('{} is not bound'.format(key))
        elif wanted not in ' '.join(shlex.split(action)) and wanted not in action:
            errors.append('{} runs {!r}, expected {!r}'.format(key, action, wanted))

    for error in errors:
        print('FAIL', error)
    print('{} bindings checked, {} noctalia commands known, {} problems'.format(
        len(seen), len(commands), len(errors)))
    return 1 if errors else 0


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
