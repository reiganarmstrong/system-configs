# Shell functions carried over from the Fedora setup.

update_codex() {
  codex remote-control stop
  codex update
  pkill -9 -f "codex.*app-server" && pkill -9 -f "codex"
  codex remote-control start
}


# List MakeMKV disc titles, sorted from largest to smallest.
# Usage: makemkv_table [device-or-MakeMKV-source]
# Examples: makemkv_table, makemkv_table /dev/sr1, makemkv_table disc:0
makemkv_table() {
    emulate -L zsh
    setopt pipefail

    local source="${1:-dev:/dev/sr0}"
    if [[ "$source" == /* ]]; then
        source="dev:$source"
    fi

    print -u2 -- "Scanning $source..."

    {
        printf 'TITLE_ID\tBYTES\tSIZE\tDURATION\tPLAYLIST\tLANGUAGE\tOUTPUT_FILENAME\n'
        makemkvcon --robot info "$source" |
            awk -F, '
                function value_from_record(record, value) {
                    value = record
                    sub(/^[^,]*,[^,]*,[^,]*,/, "", value)
                    sub(/^"/, "", value)
                    sub(/"$/, "", value)
                    return value
                }

                /^TINFO:/ {
                    split($1, title_field, ":")
                    id = title_field[2]
                    code = $2
                    value = value_from_record($0)

                    if (code == 9)  duration[id] = value
                    if (code == 10) size[id] = value
                    if (code == 11) bytes[id] = value
                    if (code == 16) playlist[id] = value
                    if (code == 27) filename[id] = value
                    if (code == 29) language[id] = value
                }

                END {
                    for (id in bytes) {
                        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", \
                            id, bytes[id], size[id], duration[id], \
                            playlist[id], language[id], filename[id]
                    }
                }
            ' |
            sort -t $'\t' -k2,2nr
    } | column -t -s $'\t'
}
