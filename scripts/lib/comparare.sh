#!/bin/bash

# Compararea se face cu utilitarul comm, care primeste doua liste sortate si le
# imparte in trei coloane: elementele prezente doar in prima lista, cele
# prezente doar in a doua si cele comune. Cifrele din optiuni indica ce coloane
# sunt ascunse, astfel incat sa ramana doar cea dorita.

# Elementele prezente pe sursa si absente pe destinatie: cele care trebuie
# create.
diff_lipsa() {
    comm -23 "$1" "$2"
}

# Elementele prezente pe destinatie si absente pe sursa: cele care trebuie
# sterse.
diff_in_plus() {
    comm -13 "$1" "$2"
}

# Elementele prezente pe ambele sisteme.
diff_comune() {
    comm -12 "$1" "$2"
}

# Afiseaza diferentele dintr-o categorie, marcand cu + elementele de adaugat si
# cu - pe cele de sters. Pasul este strict informativ: nu modifica nimic.
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

# Verifica daca intre cele doua sisteme exista vreo diferenta intr-o categorie.
exista_diferente() {
    local f_sursa="$1"
    local f_dest="$2"
    if [ -n "$(diff_lipsa "$f_sursa" "$f_dest")" ] || \
       [ -n "$(diff_in_plus "$f_sursa" "$f_dest")" ]; then
        return 0
    fi
    return 1
}
