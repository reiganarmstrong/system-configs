#!/usr/bin/python3
"""Add keys to a JSON or JSONC object file only when they are missing.

Usage: jsonc-add-missing.py FILE KEY=JSON_VALUE [KEY=JSON_VALUE ...]

VS Code-style settings files allow comments and trailing commas, and the user
owns them. Existing keys are never changed, comments and formatting are kept,
and missing keys are inserted as new lines right after the opening brace.
A missing or empty file becomes a plain JSON object.

Prints one JSON line: {"changed": bool, "added": [...], "error": str | null}.
Exits non-zero only on usage errors; a file it can't safely parse is reported
through "error" and left untouched.
"""

import json
import os
import sys


def strip_jsonc(text):
    """Return text with comments blanked out at the same length, or raise ValueError."""
    out = []
    index = 0
    length = len(text)
    in_string = False
    while index < length:
        char = text[index]
        if in_string:
            out.append(char)
            if char == '\\' and index + 1 < length:
                out.append(text[index + 1])
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
            continue
        if char == '"':
            in_string = True
            out.append(char)
            index += 1
            continue
        if text.startswith('//', index):
            end = text.find('\n', index)
            end = length if end == -1 else end
            out.append(' ' * (end - index))
            index = end
            continue
        if text.startswith('/*', index):
            end = text.find('*/', index + 2)
            if end == -1:
                raise ValueError('unterminated block comment')
            end += 2
            out.append(''.join(c if c == '\n' else ' ' for c in text[index:end]))
            index = end
            continue
        out.append(char)
        index += 1
    if in_string:
        raise ValueError('unterminated string')
    return ''.join(out)


def remove_trailing_commas(text):
    result = []
    in_string = False
    index = 0
    while index < len(text):
        char = text[index]
        if in_string:
            result.append(char)
            if char == '\\' and index + 1 < len(text):
                result.append(text[index + 1])
                index += 2
                continue
            if char == '"':
                in_string = False
        elif char == '"':
            in_string = True
            result.append(char)
        elif char == ',':
            rest = text[index + 1:].lstrip()
            if rest[:1] in ('}', ']'):
                result.append(' ')
            else:
                result.append(char)
        else:
            result.append(char)
        index += 1
    return ''.join(result)


def add_missing(path, wanted):
    try:
        with open(path, encoding='utf-8') as handle:
            text = handle.read()
    except FileNotFoundError:
        text = ''

    if not text.strip():
        new_text = json.dumps(wanted, indent=2) + '\n'
        added = list(wanted)
    else:
        stripped = strip_jsonc(text)
        data = json.loads(remove_trailing_commas(stripped))
        if not isinstance(data, dict):
            raise ValueError('top level is not an object')
        missing = {key: value for key, value in wanted.items() if key not in data}
        if not missing:
            return []
        brace = stripped.index('{')
        members = ',\n'.join(
            '\t{}: {}'.format(json.dumps(key), json.dumps(value)) for key, value in missing.items()
        )
        # Preserve the original interior even when it contains only comments.
        # An empty object needs no separator after the inserted members.
        lines = '\n' + members + (',' if data else '\n')
        new_text = text[:brace + 1] + lines + text[brace + 1:]
        added = list(missing)

    temporary = path + '.ansible-tmp'
    with open(temporary, 'w', encoding='utf-8') as handle:
        handle.write(new_text)
    if os.path.exists(path):
        os.chmod(temporary, os.stat(path).st_mode & 0o7777)
    os.replace(temporary, path)
    return added


def main(argv):
    if len(argv) < 3:
        sys.stderr.write(__doc__)
        return 2
    path = argv[1]
    wanted = {}
    for pair in argv[2:]:
        key, separator, value = pair.partition('=')
        if not separator:
            sys.stderr.write('expected KEY=JSON_VALUE, got {!r}\n'.format(pair))
            return 2
        wanted[key] = json.loads(value)
    try:
        added = add_missing(path, wanted)
    except (ValueError, OSError) as error:
        print(json.dumps({'changed': False, 'added': [], 'error': str(error)}))
        return 0
    print(json.dumps({'changed': bool(added), 'added': added, 'error': None}))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
