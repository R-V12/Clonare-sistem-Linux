#!/bin/bash

diff_lipsa() {
    comm -23 "$1" "$2"
}

diff_in_plus() {
    comm -13 "$1" "$2"
}

diff_comune() {
    comm -12 "$1" "$2"
}

afiseaza_diferente() {
    local titlu="$1"
    local f_sursa="$2"
    local f_dest="$3"

    local lipsa in_plus
    lipsa=$(diff_lipsa "$f_sursa" "$f_dest")
    in_plus=$(diff_in_plus "$f_sursa" "$f_dest")

    echo
    echo "=== $titlu ==="
    if [ -n "$lipsa" ]; then
        echo "  De adaugat pe destinatie:"
        echo "$lipsa" | sed 's/^/    + /'
    else
        echo "  De adaugat pe destinatie: (nimic)"
    fi
    if [ -n "$in_plus" ]; then
        echo "  De sters de pe destinatie:"
        echo "$in_plus" | sed 's/^/    - /'
    else
        echo "  De sters de pe destinatie: (nimic)"
    fi
}

exista_diferente() {
    local f_sursa="$1"
    local f_dest="$2"
    if [ -n "$(diff_lipsa "$f_sursa" "$f_dest")" ] || \
       [ -n "$(diff_in_plus "$f_sursa" "$f_dest")" ]; then
        return 0
    fi
    return 1
}
