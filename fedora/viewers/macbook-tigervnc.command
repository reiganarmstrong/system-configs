#!/bin/bash
set -euo pipefail

# Run on the Mac with the existing SSH tunnel to localhost:5903 open.
# The VM's matching display override is profiles/niri-vnc-macbook.yml.
# These are CLI options; RemoteResize/DesktopSize are not supported in all
# TigerVNC saved-profile formats.
exec /usr/bin/open -na TigerVNC --args \
  -RemoteResize=0 \
  -DesktopSize=1512x982 \
  -AutoSelect=0 \
  -FullColor=1 \
  -NoJPEG=1 \
  -PreferredEncoding=Tight \
  -FullScreen \
  -Shared=1 \
  127.0.0.1::5903
