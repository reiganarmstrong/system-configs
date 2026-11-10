# Greet a new terminal with fastfetch, and spin its NixOS logo until you type.
#
# fastfetch prints the still logo. This then redraws that block of the screen
# with frames of the logo turning like a wheel (@frames@, made by
# fetch-logo.py). A timer process wakes zle 20 times a second, so the prompt
# works the whole time. The first key starts a wind-down of 1.5 to 4 seconds
# that ends upright; the logo is upright every third of a turn. Enter,
# Ctrl+C and Ctrl+L stop it at once.
#
# The frames go to fixed screen rows, so there is no spin when the summary
# has scrolled, and it stops if the window shrinks.

zmodload zsh/mathfunc

typeset -gi _fs_fd=0 _fs_row _fs_col _fs_lines _fs_cols _fs_shown=0
typeset -gi _fs_tick=-1 _fs_ticks
# Frames per tick: 192 frames a turn makes one turn every 12 seconds.
typeset -gF _fs_speed=0.8 _fs_pos=0 _fs_from _fs_to
typeset -g _fs_typed

# Ask the terminal for the cursor's row; it answers ESC [ row ; col R.
_fs_cursor_row() {
  setopt localoptions extendedglob
  local reply
  print -n '\e[6n' >/dev/tty
  read -rs -d R -t 0.3 reply </dev/tty || return 1
  # Keys typed before the answer arrive ahead of it.
  [[ $reply == (#b)(*)$'\e['([0-9]##)';'[0-9]## ]] || return 1
  _fs_typed+=$match[1]
  REPLY=$match[2]
}

_fs_draw() {
  local n=${#fetch_logo_frames}
  local i=$(( int(floor(_fs_pos)) % n + 1 ))
  (( i == _fs_shown )) && return
  _fs_shown=$i
  print -nr -- $'\e7\e['$_fs_row';'$_fs_col'H'${fetch_logo_frames[i]}$'\e8' >/dev/tty
}

_fs_tick() {
  local line
  read -r -u $1 line
  if (( LINES < _fs_lines || COLUMNS < _fs_cols )); then
    _fs_end
    return
  fi
  if (( _fs_tick < 0 )); then
    (( _fs_pos += _fs_speed ))
  elif (( ++_fs_tick >= _fs_ticks )); then
    _fs_end upright
    return
  else
    # Ease from the current speed to rest on the next upright frame:
    # a cubic that starts at _fs_speed and ends at speed 0.
    local -F s=$(( _fs_tick / float(_fs_ticks) ))
    (( _fs_pos = (2*s**3 - 3*s**2 + 1) * _fs_from
               + (s**3 - 2*s**2 + s) * _fs_ticks * _fs_speed
               + (3*s**2 - 2*s**3) * _fs_to ))
  fi
  _fs_draw
}

# Any key starts the wind-down.
_fs_pre_redraw() {
  (( _fs_fd && _fs_tick < 0 )) || return
  [[ -n $LASTWIDGET && $LASTWIDGET != zle-* ]] || return
  if [[ $LASTWIDGET == clear-screen ]]; then
    _fs_end
    return
  fi
  local n=$fetch_logo_rest
  _fs_from=$_fs_pos
  _fs_to=$(( (floor(_fs_pos / n) + 1) * n ))
  # As long as slowing down evenly would take, held to 1.5 to 4 seconds.
  _fs_ticks=$(( int(2 * (_fs_to - _fs_from) / _fs_speed) ))
  (( _fs_ticks < 30 )) && _fs_ticks=30
  (( _fs_ticks > 80 )) && _fs_ticks=80
  _fs_tick=0
}

_fs_line_init() {
  if (( _fs_fd )); then
    # A new prompt (after Ctrl+C) while still spinning.
    _fs_end upright
    return
  fi
  # Begin only if nothing scrolled: scrolling leaves the cursor on the
  # bottom row.
  if ! _fs_cursor_row || (( REPLY >= LINES )); then
    _fs_end
  else
    _fs_lines=$LINES _fs_cols=$COLUMNS
    exec {_fs_fd}< <(zmodload zsh/zselect; while print; do zselect -t 5; done)
    zle -F $_fs_fd _fs_tick
  fi
  [[ -n $_fs_typed ]] && zle -U -- "$_fs_typed"
  _fs_typed=
}

_fs_line_finish() {
  (( _fs_fd )) && _fs_end upright
}

# Stop for good. With "upright", first draw the logo at rest. Each third of
# a turn is upright, but the first frame is drawn straight from the art and
# reads best, so it always ends there.
_fs_end() {
  if (( _fs_fd )); then
    zle -F $_fs_fd
    # The timer exits when its next write finds the pipe closed.
    exec {_fs_fd}<&-
    _fs_fd=0
  fi
  if [[ $1 == upright ]]; then
    _fs_pos=0
    _fs_draw
  fi
  add-zle-hook-widget -d line-init _fs_line_init
  add-zle-hook-widget -d line-pre-redraw _fs_pre_redraw
  add-zle-hook-widget -d line-finish _fs_line_finish
  unset fetch_logo_frames
}

fetch_spin() {
  local top
  if [[ -t 0 && -t 1 ]] && _fs_cursor_row; then
    top=$REPLY
  fi
  fastfetch
  [[ -n $top ]] || return
  source @frames@
  # Where fastfetch put the logo: its padding moves it @top@ row down and
  # @left@ columns in.
  _fs_row=$(( top + @top@ ))
  _fs_col=$(( 1 + @left@ ))
  autoload -Uz add-zle-hook-widget
  add-zle-hook-widget line-init _fs_line_init
  add-zle-hook-widget line-pre-redraw _fs_pre_redraw
  add-zle-hook-widget line-finish _fs_line_finish
}
