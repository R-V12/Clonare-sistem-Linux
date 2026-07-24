#!/bin/bash

# Sterge de pe destinatie utilizatorii care nu exista pe sursa.
# Nu se sterg contul root si utilizatorul prin care e stabilita conexiunea SSH,
# deoarece stergerea lor ar intrerupe executia clonarii.
sterge_utilizatori() {
    local f_sursa="$1"
    local f_dest="$2"
    local de_sters user
    de_sters=$(diff_in_plus "$f_sursa" "$f_dest")

    mapfile -t lista_useri <<< "$de_sters"
    for user in "${lista_useri[@]}"; do
        [ -z "$user" ] && continue
        if [ "$user" = "$USER_SSH" ]; then
            atentie "Utilizatorul $user este cel conectat prin SSH - NU se sterge (protectie)"
            continue
        fi
        if [ "$user" = "root" ]; then
            atentie "Utilizatorul root nu se sterge (protectie)"
            continue
        fi
        info "Sterg utilizatorul $user de pe destinatie (cu home)"
        ruleaza_sudo "$DESTINATIE" pkill -u "$user" 2>/dev/null || true
        ruleaza_sudo "$DESTINATIE" userdel -r "$user" 2>/dev/null \
            || atentie "Utilizatorul $user nu a putut fi sters complet"
    done
}

# Sterge de pe destinatie grupurile care nu exista pe sursa.
# Grupurile principale ale utilizatorilor sunt deja eliminate de userdel,
# deci se verifica intai daca grupul mai exista.
sterge_grupuri() {
    local f_sursa="$1"
    local f_dest="$2"
    local de_sters grup
    de_sters=$(diff_in_plus "$f_sursa" "$f_dest")

    mapfile -t lista_grupuri <<< "$de_sters"
    for grup in "${lista_grupuri[@]}"; do
        [ -z "$grup" ] && continue
        if ! ruleaza "$DESTINATIE" getent group "$grup" >/dev/null 2>&1; then
            continue
        fi
        info "Sterg grupul $grup de pe destinatie"
        ruleaza_sudo "$DESTINATIE" groupdel "$grup" 2>/dev/null \
            || atentie "Grupul $grup nu a putut fi sters"
    done
}

# Creeaza pe destinatie grupurile de pe sursa, pastrand acelasi GID.
creaza_grupuri() {
    local f_sursa="$1"
    local f_dest="$2"
    local de_adaugat grup linie gid
    de_adaugat=$(diff_lipsa "$f_sursa" "$f_dest")

    mapfile -t lista_grupuri <<< "$de_adaugat"
    for grup in "${lista_grupuri[@]}"; do
        [ -z "$grup" ] && continue
        linie=$(linie_grup "$SURSA" "$grup")
        gid=$(echo "$linie" | cut -d: -f3)
        if ruleaza "$DESTINATIE" getent group "$grup" >/dev/null 2>&1; then
            info "Grupul $grup exista deja pe destinatie"
        else
            info "Creez grupul $grup (GID $gid)"
            ruleaza_sudo "$DESTINATIE" groupadd -g "$gid" "$grup" 2>/dev/null \
                || ruleaza_sudo "$DESTINATIE" groupadd "$grup" 2>/dev/null \
                || atentie "Grupul $grup nu a putut fi creat"
        fi
    done
}

# Cloneaza utilizatorii prelucrand in bloc fisierele /etc/passwd si /etc/shadow:
# linia din passwd (nume, UID, GID, home, shell) si linia din shadow (hash-ul
# parolei) se preiau de pe sursa si se adauga in fisierele destinatiei. Astfel
# contul si parola sunt clonate impreuna, iar utilizatorul se poate autentifica
# pe destinatie cu aceeasi parola.
creaza_utilizatori() {
    local f_sursa="$1"
    local f_dest="$2"
    local de_adaugat user linie_p linie_s grupuri home

    de_adaugat=$(diff_lipsa "$f_sursa" "$f_dest")

    info "Fac o copie de siguranta a fisierelor passwd si shadow pe destinatie"
    ruleaza_sudo "$DESTINATIE" cp /etc/passwd /etc/passwd.bak.clonare
    ruleaza_sudo "$DESTINATIE" cp /etc/shadow /etc/shadow.bak.clonare

    mapfile -t lista_useri <<< "$de_adaugat"
    for user in "${lista_useri[@]}"; do
        [ -z "$user" ] && continue

        linie_p=$(linie_passwd "$SURSA" "$user")
        linie_s=$(linie_shadow "$SURSA" "$user")

        if ruleaza "$DESTINATIE" getent passwd "$user" >/dev/null 2>&1; then
            info "Utilizatorul $user exista deja - actualizez parola (shadow)"
            ruleaza_sudo "$DESTINATIE" bash -c "sed -i '\|^$user:|d' /etc/shadow"
            echo "$linie_s" | ruleaza_sudo "$DESTINATIE" tee -a /etc/shadow >/dev/null
            continue
        fi

        info "Clonez utilizatorul $user (passwd + shadow, in bloc)"
        echo "$linie_p" | ruleaza_sudo "$DESTINATIE" tee -a /etc/passwd >/dev/null
        echo "$linie_s" | ruleaza_sudo "$DESTINATIE" tee -a /etc/shadow >/dev/null

        home=$(echo "$linie_p" | cut -d: -f6)
        ruleaza_sudo "$DESTINATIE" mkdir -p "$home"

        grupuri=$(grupuri_secundare "$SURSA" "$user")
        if [ -n "$grupuri" ]; then
            info "Adaug $user in grupurile secundare: $grupuri"
            ruleaza_sudo "$DESTINATIE" usermod -aG "$grupuri" "$user" 2>/dev/null \
                || atentie "Nu am putut seta toate grupurile pentru $user"
        fi
    done
}

# Transfera home-directory-ul unui utilizator cu rsync peste SSH, pastrand
# permisiunile si proprietarul. Optiunea --delete elimina de pe destinatie
# fisierele care nu exista pe sursa, iar --rsync-path ruleaza rsync cu drepturi
# de root pe partea remote, pentru a putea scrie in home.
aplica_home() {
    local user="$1"
    local home_sursa home_dest
    home_sursa=$(home_utilizator "$SURSA" "$user")
    home_dest=$(home_utilizator "$DESTINATIE" "$user")
    [ -z "$home_dest" ] && home_dest="$home_sursa"

    info "Transfer home-directory-ul lui $user"
    local opt="ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes -i /home/${USER_SSH}/.ssh/id_ed25519"

    if [ "$SURSA" = "local" ]; then
        sudo rsync -aAX --delete -e "$opt" --rsync-path="sudo rsync" \
            "$home_sursa/" "${USER_SSH}@${TINTA}:$home_dest/" \
            && info "Home-ul lui $user transferat" \
            || atentie "Transferul home-ului lui $user a intampinat probleme"
    else
        sudo rsync -aAX --delete -e "$opt" --rsync-path="sudo rsync" \
            "${USER_SSH}@${TINTA}:$home_sursa/" "$home_dest/" \
            && info "Home-ul lui $user transferat" \
            || atentie "Transferul home-ului lui $user a intampinat probleme"
    fi

    ruleaza_sudo "$DESTINATIE" chown -R "$user:$user" "$home_dest" 2>/dev/null || true
}

# Instaleaza pe destinatie pachetele prezente doar pe sursa si dezinstaleaza
# pachetele prezente doar pe destinatie. Inainte de dezinstalare se verifica,
# cu apt-get remove --dry-run, cate pachete ar fi eliminate prin dependente;
# daca ar cadea si altele in afara diferentei calculate, operatia este sarita.
aplica_pachete() {
    local f_sursa="$1"
    local f_dest="$2"
    local de_instalat de_dezinstalat pachet cascada

    de_instalat=$(diff_lipsa "$f_sursa" "$f_dest")
    de_dezinstalat=$(diff_in_plus "$f_sursa" "$f_dest")

    if [ -n "$de_instalat" ]; then
        info "Instalez pachetele lipsa pe destinatie"
        ruleaza_sudo "$DESTINATIE" apt-get update -qq 2>/dev/null || true
        mapfile -t lista_inst <<< "$de_instalat"
        for pachet in "${lista_inst[@]}"; do
            [ -z "$pachet" ] && continue
            info "  apt install $pachet"
            ruleaza_sudo "$DESTINATIE" apt-get install -y "$pachet" >/dev/null 2>&1 \
                && info "  $pachet instalat" \
                || atentie "Pachetul $pachet nu a putut fi instalat"
        done
    fi

    if [ -n "$de_dezinstalat" ]; then
        info "Verific pachetele prezente doar pe destinatie"
        mapfile -t lista_dez <<< "$de_dezinstalat"
        for pachet in "${lista_dez[@]}"; do
            [ -z "$pachet" ] && continue
            cascada=$(ruleaza_sudo "$DESTINATIE" apt-get remove --dry-run "$pachet" 2>/dev/null \
                | grep -c '^Remv' || echo 0)
            if [ "$cascada" -gt 1 ]; then
                atentie "Dezinstalarea lui $pachet ar elimina $cascada pachete in cascada - sarita"
            else
                info "  apt remove $pachet"
                ruleaza_sudo "$DESTINATIE" apt-get remove -y "$pachet" >/dev/null 2>&1 \
                    && info "  $pachet dezinstalat" \
                    || atentie "Pachetul $pachet nu a putut fi dezinstalat"
            fi
        done
    fi
}

# Recreeaza pe destinatie cronjob-urile unui utilizator, dupa ce contul exista.
aplica_cronjoburi() {
    local user="$1"
    local cron_sursa
    cron_sursa=$(colecteaza_cronjoburi "$SURSA" "$user")
    if [ -n "$cron_sursa" ]; then
        info "Recreez cronjob-urile lui $user pe destinatie"
        echo "$cron_sursa" | ruleaza_sudo "$DESTINATIE" crontab -u "$user" - 2>/dev/null \
            || atentie "Cronjob-urile lui $user nu au putut fi recreate"
    fi
}
