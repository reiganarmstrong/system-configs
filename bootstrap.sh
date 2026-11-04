#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mkdir -p .local
python3 -m venv .local/ansible
.local/ansible/bin/python -m pip install --requirement requirements.txt
.local/ansible/bin/ansible-galaxy collection install --requirements-file requirements.yml --collections-path .local/collections
