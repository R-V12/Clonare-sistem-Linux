# Clonare sistem Linux

Set de scripturi Bash care aduce un sistem Linux (**destinație**) în aceeași stare ca un
alt sistem Linux (**sursă**).

Se clonează: pachetele instalate, utilizatorii și grupurile, fișierele din
home-directory-uri, fișierele din directoarele specificate și cronjob-urile. Clonarea
vizează configurația sistemului, nu sistemul de operare al destinației, care rămâne neatins.

Proiect de practică — Academia Tehnică Militară „Ferdinand I".

## Cum funcționează

Scriptul poate fi rulat de pe oricare dintre cele două mașini. El:

1. citește configurația și se conectează prin SSH la cealaltă mașină;
2. colectează starea ambelor sisteme;
3. calculează diferențele și le afișează grupate pe categorii;
4. cere o singură confirmare;
5. aplică modificările: șterge ce există doar pe destinație, creează ce lipsește,
   suprascrie ce diferă și păstrează ce este identic.

Nicio modificare nu se aplică fără confirmare. Toate acțiunile se înregistrează într-un
jurnal.

Utilizatorii se clonează prin prelucrarea în bloc a fișierelor `/etc/passwd` și
`/etc/shadow`, astfel încât contul și parola sunt transferate împreună, iar utilizatorul se
poate autentifica pe destinație cu aceeași parolă. Se prelucrează numai utilizatorii reali
(UID ≥ 1000); conturile de sistem nu sunt atinse.

## Structura proiectului

```text
scripts/clonare.sh        scriptul principal
scripts/lib/comun.sh      functii comune (jurnalizare, executie locala sau prin ssh)
scripts/lib/colectare.sh  citirea starii unui sistem
scripts/lib/comparare.sh  calculul diferentelor
scripts/lib/aplicare.sh   aplicarea clonarii
config/clonare.conf       fisier de configurare
logs/                     jurnalele de rulare
```

## Mediul necesar

Două sisteme Linux bazate pe Debian (dezvoltat și testat pe Linux Mint), conectate în rețea.

```bash
sudo apt install -y git openssh-server openssh-client rsync
ssh-keygen -t ed25519
ssh-copy-id user@ip_destinatie
ssh user@ip_destinatie "hostname"    # trebuie sa raspunda fara parola
```

Pe ambele mașini, contul folosit trebuie să poată rula `sudo` fără parolă, deoarece
operațiile privilegiate se execută prin SSH neinteractiv:

```bash
echo "utilizator ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/clonare
sudo chmod 440 /etc/sudoers.d/clonare
```

## Utilizare

```bash
./scripts/clonare.sh --mod sursa --tinta 192.168.56.102 --user vladescu
./scripts/clonare.sh --config config/clonare.conf
```

Parametri:

```text
--mod        sursa | destinatie (rolul masinii pe care se ruleaza)
--tinta      adresa IP a celeilalte masini
--user       utilizatorul folosit pentru conexiunea SSH
--config     fisier de configurare
--categorii  pachete,utilizatori,home,cron
--help       afiseaza mesajul de ajutor
```

Parametrii din linia de comandă au prioritate față de valorile din fișierul de configurare.

## Limitări

* Conturile de sistem (UID < 1000) nu sunt modificate; ele sunt create automat de `apt`
  odată cu pachetele care le folosesc.
* Utilizatorul conectat prin SSH și contul root nu sunt niciodată șterse.
* Se clonează pachetele instalate prin `apt`; snap, flatpak și pip nu sunt tratate.
* Dezinstalarea unui pachet este sărită dacă ar elimina în cascadă alte componente.
