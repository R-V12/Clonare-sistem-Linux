#!/bin/bash

    local unde="$1"
    ruleaza "$unde" apt-mark showmanual 2>/dev/null | sort
}
colecteaza_utilizatori() {
    local unde="$1"
    ruleaza "$unde" getent passwd \
        | awk -F: '$3 >= 1000 && $3 < 65534 { print $1 }' \
        | sort
}
atribute_utilizator() {
    local unde="$1"
    local user="$2"
    ruleaza "$unde" getent passwd "$user" \
        | awk -F: '{ print $1 ":" $3 ":" $4 ":" $6 ":" $7 }'
}
grupuri_secundare() {
    local unde="$1"
    local user="$2"
    ruleaza "$unde" id -nG "$user" 2>/dev/null \
        | tr ' ' '\n' \
        | tail -n +2 \
        | paste -sd ',' -
}
colecteaza_grupuri() {
    local unde="$1"
    ruleaza "$unde" getent group \
        | awk -F: '$3 >= 1000 && $3 < 65534 { print $1 }' \
        | sort
}
colecteaza_cronjoburi() {
    local unde="$1"
    local user="$2"
    ruleaza "$unde" sudo crontab -l -u "$user" 2>/dev/null \
        | grep -v '^[[:space:]]*#' \
        | grep -v '^[[:space:]]*$' \
        | sort
}
colecteaza_fisiere() {
    local unde="$1"
    local director="$2"

    ruleaza "$unde" sudo find "$director" -type f -print0 2>/dev/null \
        | ruleaza "$unde" sudo xargs -0 -r sha256sum 2>/dev/null \
        | sed "s| $director/| |" \
        | sort -k2
}
home_utilizator() {
    local unde="$1"
    local user="$2"
    ruleaza "$unde" getent passwd "$user" | cut -d: -f6
}
