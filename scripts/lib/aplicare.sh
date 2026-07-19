#!/bin/bash

aplica_grupuri() {
    local f_sursa="$1"
    local f_dest="$2"
    local de_adaugat de_sters

    de_adaugat=$(diff_lipsa "$f_sursa" "$f_dest")
    de_sters=$(diff_in_plus "$f_sursa" "$f_dest")

    local grup linie gid membri
    while IFS= read -r grup; do
        [ -z "$grup" ] && continue
        linie=$(linie_grup "$SURSA" "$grup")
        gid=$(echo "$linie" | cut -d: -f3)
        info "Creez grupul $grup (GID $gid)"
        ruleaza_sudo "$DESTINATIE" groupadd -g "$gid" "$grup" 2>/dev/null \
            || atentie "Grupul $grup nu a putut fi creat (poate exista deja cu alt GID)"
    done <<< "$de_adaugat"

    while IFS= read -r grup; do
        [ -z "$grup" ] && continue
        info "Sterg grupul $grup de pe destinatie"
        ruleaza_sudo "$DESTINATIE" groupdel "$grup" 2>/dev/null \
            || atentie "Grupul $grup nu a putut fi sters"
    done <<< "$de_sters"
}

aplica_utilizatori() {
    local f_sursa="$1"
    local f_dest="$2"
    local de_adaugat de_sters

    de_adaugat=$(diff_lipsa "$f_sursa" "$f_dest")
    de_sters=$(diff_in_plus "$f_sursa" "$f_dest")

    info "Fac o copie de siguranta a fisierelor passwd si shadow pe destinatie"
    ruleaza_sudo "$DESTINATIE" cp /etc/passwd /etc/passwd.bak.clonare
    ruleaza_sudo "$DESTINATIE" cp /etc/shadow /etc/shadow.bak.clonare

    local user linie_p linie_s grupuri home
    while IFS= read -r user; do
        [ -z "$user" ] && continue

        linie_p=$(linie_passwd "$SURSA" "$user")
        linie_s=$(linie_shadow "$SURSA" "$user")

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
    done <<< "$de_adaugat"

    local user_conectat
    user_conectat="$USER_SSH"

    while IFS= read -r user; do
        [ -z "$user" ] && continue

        if [ "$user" = "$user_conectat" ]; then
            atentie "Utilizatorul $user este cel conectat prin SSH - NU se sterge (protectie)"
            continue
        fi
        if [ "$user" = "root" ]; then
            atentie "Utilizatorul root nu se sterge (protectie)"
            continue
        fi

        info "Sterg utilizatorul $user de pe destinatie (cu home)"
        ruleaza_sudo "$DESTINATIE" userdel -r "$user" 2>/dev/null \
            || atentie "Utilizatorul $user nu a putut fi sters complet"
    done <<< "$de_sters"
}

aplica_home() {
    local user="$1"
    local home_sursa home_dest

    home_sursa=$(home_utilizator "$SURSA" "$user")
    home_dest=$(home_utilizator "$DESTINATIE" "$user")
    [ -z "$home_dest" ] && home_dest="$home_sursa"

    info "Transfer home-directory-ul lui $user"

    if [ "$SURSA" = "local" ]; then
        sudo rsync -aAX --delete \
            "$home_sursa/" "${USER_SSH}@${TINTA}:$home_dest/" 2>/dev/null \
            || atentie "Transferul home-ului lui $user a intampinat probleme"
    else
        sudo rsync -aAX --delete \
            "${USER_SSH}@${TINTA}:$home_sursa/" "$home_dest/" 2>/dev/null \
            || atentie "Transferul home-ului lui $user a intampinat probleme"
    fi

    ruleaza_sudo "$DESTINATIE" chown -R "$user:$user" "$home_dest" 2>/dev/null || true
}

aplica_pachete() {
    local f_sursa="$1"
    local f_dest="$2"
    local de_instalat de_dezinstalat

    de_instalat=$(diff_lipsa "$f_sursa" "$f_dest")
    de_dezinstalat=$(diff_in_plus "$f_sursa" "$f_dest")

    if [ -n "$de_instalat" ]; then
        info "Instalez pachetele lipsa pe destinatie"
        ruleaza_sudo "$DESTINATIE" apt-get update -qq 2>/dev/null || true
        local pachet
        while IFS= read -r pachet; do
            [ -z "$pachet" ] && continue
            info "  apt install $pachet"
            ruleaza_sudo "$DESTINATIE" apt-get install -y "$pachet" 2>/dev/null \
                || atentie "Pachetul $pachet nu a putut fi instalat (poate lipseste din repository)"
        done <<< "$de_instalat"
    fi

    if [ -n "$de_dezinstalat" ]; then
        info "Dezinstalez pachetele prezente doar pe destinatie"
        local pachet cascada
        while IFS= read -r pachet; do
            [ -z "$pachet" ] && continue
            cascada=$(ruleaza_sudo "$DESTINATIE" apt-get remove --dry-run "$pachet" 2>/dev/null \
                | grep -c '^Remv' || echo 0)
            if [ "$cascada" -gt 1 ]; then
                atentie "Dezinstalarea lui $pachet ar elimina $cascada pachete in cascada - sarita"
            else
                info "  apt remove $pachet"
                ruleaza_sudo "$DESTINATIE" apt-get remove -y "$pachet" 2>/dev/null \
                    || atentie "Pachetul $pachet nu a putut fi dezinstalat"
            fi
        done <<< "$de_dezinstalat"
    fi
}

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
