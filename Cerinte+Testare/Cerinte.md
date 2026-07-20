# DOCUMENT DE CERINȚE SOFTWARE

## Clonare sistem Linux

Student: Vlădescu Rareș

Proiect: Clonare sistem Linux

Repository: https://github.com/R-V12/Clonare-sistem-Linux

# Capitolul 1: Introducere

## 1.1 Scopul proiectului

Aplicația este o colecție de scripturi Bash care replică starea unui sistem Linux
(**sursă**) pe alt sistem Linux (**destinație**). Scriptul se poate rula de pe oricare
dintre cele două sisteme. El colectează starea ambelor mașini, calculează diferențele,
le afișează și, numai după confirmarea utilizatorului, aplică modificările pe destinație.

Clonarea este completă și indivizibilă: destinația devine identică cu sursa. Elementele
lipsă sunt create, cele cu conținut diferit sunt suprascrise, cele prezente doar pe
destinație sunt șterse, iar cele identice sunt păstrate neatinse. Utilizatorul nu selectează
ce se clonează; el confirmă sau anulează clonarea în întregime.

Elementele care se pot clona: pachetele instalate, utilizatorii și grupurile, fișierele
din home-directory-uri, fișierele din directoare specificate și cronjob-urile.

Clonarea vizează configurația sistemului (utilizatori, pachete, fișiere din locațiile
specificate, cronjob-uri), nu sistemul de operare al destinației, care rămâne neatins.

Transferul se face prin SSH și rsync. Nicio modificare nu se aplică fără confirmare, iar
toate acțiunile se înregistrează într-un jurnal.

## 1.2 Lista definițiilor

**apt / dpkg** — utilitarele de gestiune a pachetelor pe distribuțiile Debian. `dpkg` ține
evidența pachetelor instalate, `apt` rezolvă dependențele.

**Bash** — interpretorul în care sunt scrise scripturile.

**Clonare** — aducerea destinației în aceeași stare ca sursa: se creează ce lipsește, se
suprascrie ce diferă, se șterge ce există doar pe destinație, se păstrează ce e identic.
Vizează configurația (utilizatori, pachete, fișiere, cronjob-uri), nu sistemul de operare.

**Cronjob** — sarcină programată prin `cron`, vizibilă cu `crontab -l`.

**Fișier de configurare** — fișier text cu opțiunile aplicației.

**GID** — identificatorul numeric al unui grup.

**Home-directory** — directorul personal al unui utilizator, `/home/<user>`.

**Idempotență** — proprietatea de a produce același rezultat la rulări repetate.

**rsync** — utilitar de copiere care transferă doar diferențele și păstrează permisiunile
și owner-ul. Lucrează peste SSH.

**SSH** — protocol de conectare securizată la o mașină remote.

**Sistem sursă** — sistemul de la care se preia starea.

**Sistem destinație** — sistemul pe care se aplică clonarea.

**Sumă de control** — amprentă calculată din conținutul unui fișier (`sha256sum`), folosită
pentru a detecta dacă două fișiere diferă.

**UID** — identificatorul numeric al unui utilizator. Utilizatorii reali au UID ≥ 1000.

**/etc/passwd, /etc/shadow, /etc/group** — fișierele în care sunt stocate conturile,
hash-urile parolelor și grupurile.

## 1.3 Structura documentului

**Capitolul 1** prezintă scopul și termenii folosiți.
**Capitolul 2** prezintă funcționarea aplicației, mediul de lucru și constrângerile.
**Capitolul 3** definește cerințele funcționale (`CF`) și nefuncționale (`CNF`).

# Capitolul 2: Descrierea generală

## 2.1 Fluxul aplicației

1. Citirea configurației (mod de rulare, adresa celeilalte mașini, categorii).
2. Stabilirea conexiunii SSH.
3. Colectarea stării de pe ambele sisteme.
4. Calculul diferențelor.
5. Afișarea diferențelor.
6. Interogarea utilizatorului, pe categorii.
7. Aplicarea modificărilor confirmate.
8. Jurnalizarea.

## 2.2 Ordinea operațiilor

1. **Grupurile** se creează primele.
2. **Utilizatorii** — după grupuri (au nevoie de grupul principal).
3. **Fișierele** — după utilizatori, pentru ca owner-ul (UID) să poată fi aplicat corect.
4. **Pachetele** — independent.
5. **Cronjob-urile** — după utilizatorii corespunzători.

## 2.3 Diferențe și interogare

Diferențele se calculează în ambele direcții și rezultă trei categorii:

* **lipsă pe destinație** — se creează;
* **doar pe destinație** — se șterg;
* **identice pe ambele** — se păstrează neatinse;
* **prezente pe ambele, cu conținut diferit** — se suprascriu cu versiunea de pe sursă.

Diferențele se afișează integral, apoi aplicația cere o singură confirmare pentru întreaga
clonare. Utilizatorul nu selectează categorii: confirmă aplicarea tuturor modificărilor sau
anulează operația. Pentru conturi, diferențele de atribute (UID, shell, grupuri) se
raportează, dar conturile comune nu se modifică.

Exemplu, pentru sursă cu `user1, user2, user3` și destinație cu `user1, user2, user4`:

```
Diferențe utilizatori:
  Lipsă pe destinație:  user3
  Doar pe destinație:   user4
  Comuni:               user1, user2

Aplic clonarea? [d/n] d

Se creează: user3
Se șterge:  user4
user1, user2: existenți, nemodificați
```

## 2.4 Exemple de utilizare

```
./scripts/clonare.sh --mod sursa --tinta 192.168.56.20 --user rares
./scripts/clonare.sh --config config/clonare.conf
```

## 2.5 Platforma și mediul de lucru

Aplicația rulează pe Linux Mint (bazat pe Debian). Utilitare folosite: Bash, coreutils,
`getent`, `groupadd`, `usermod`, `userdel`, `dpkg`/`apt`, `ssh`, `rsync`, `crontab`.

Sunt necesare două mașini virtuale Linux Mint (sursă și destinație), conectate în rețea
(Host-Only sau Internal Network), cu SSH configurat pe bază de chei.

```
sudo apt install -y git openssh-server openssh-client rsync
ssh-keygen -t ed25519
ssh-copy-id user@ip_destinatie
ssh user@ip_destinatie "hostname"    # verificare: trebuie să răspundă fără parolă
```

Pe ambele mașini, contul folosit trebuie să poată rula `sudo` fără parolă (necesar pentru
operațiile privilegiate executate prin SSH):

```bash
echo "utilizator ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/clonare
sudo chmod 440 /etc/sudoers.d/clonare
```

## 2.6 Constrângeri

**Date.** Citirea utilizatorilor și a hash-urilor din `/etc/shadow` necesită root pe sursă.
Crearea utilizatorilor și instalarea pachetelor necesită root pe destinație. Căile pot
conține spații, deci variabilele se folosesc între ghilimele.

**Funcționale.** Aplicația rulează din linia de comandă. Nicio modificare fără confirmare.
Parametrii din linia de comandă au prioritate față de fișierul de configurare. Ordinea
operațiilor din 2.2 trebuie respectată.

**Tehnologice.** Implementare în Bash. Transfer prin SSH și rsync. Pachete prin `apt`.
Comparare fișiere prin sume de control. Utilizatori prin prelucrarea în bloc a fișierelor
`/etc/passwd` și `/etc/shadow`, grupuri prin `groupadd`.

**Securitate.** Operațiile privilegiate se execută cu `sudo`. Hash-urile de parolă nu se
afișează și nu se scriu în jurnal. Autentificarea SSH se face pe bază de chei.

**Conexiune.** Dacă mașina remote nu e accesibilă sau autentificarea eșuează, aplicația se
oprește controlat, fără a modifica niciun sistem.

# Capitolul 3: Cerințe specifice

## 3.1 Cerințe funcționale

### CF-01 – Modul de rulare

Aplicația rulează în modul **sursă** (sistemul local e referința, modificările se aplică
remote) sau **destinație** (referința se citește remote, modificările se aplică local).
Ambele moduri sunt implementate.

Pentru a evita duplicarea codului, comenzile se execută printr-o funcție unică ce primește
locul de execuție (local sau remote) și rulează comanda direct sau prin `ssh`. Restul
componentelor nu depind de modul de rulare.

### CF-02 – Parametri din linia de comandă

```
--mod       (sursa | destinatie)
--tinta     (adresa celeilalte mașini)
--user      (utilizatorul SSH)
--config    (fișier de configurare)
--categorii (pachete,utilizatori,home,cron)
--help
```

Parametrii au prioritate față de fișierul de configurare.

### CF-03 – Fișier de configurare

Aplicația citește opțiunile dintr-un fișier: modul de rulare, adresa și utilizatorul
celeilalte mașini, categoriile de clonat, directoarele suplimentare, locația jurnalului.

### CF-04 – Conexiunea SSH

Aplicația se conectează prin SSH cu autentificare pe bază de chei, în ambele direcții
(sursă → destinație și destinație → sursă), astfel încât să poată rula în oricare mod.
Dacă conexiunea eșuează, aplicația se oprește.

Deoarece operațiile de scriere de pe cealaltă mașină necesită privilegii, contul folosit
pentru SSH trebuie să poată executa `sudo` fără parolă interactivă: o comandă `sudo`
rulată printr-o sesiune SSH neinteractivă nu poate citi o parolă de la tastatură.
Configurarea acestui drept face parte din pregătirea mediului.

### CF-05 – Colectarea pachetelor

Aplicația obține de pe fiecare sistem lista pachetelor instalate manual
(`apt-mark showmanual`).

### CF-06 – Colectarea utilizatorilor și grupurilor

Aplicația obține utilizatorii reali (UID ≥ 1000) și grupurile, cu: nume, UID, GID,
home-directory, shell, grupuri secundare.

### CF-07 – Colectarea fișierelor

Aplicația identifică fișierele din home-directory-uri și din directoarele specificate,
împreună cu sumele lor de control.

### CF-08 – Colectarea cronjob-urilor

Aplicația extrage cronjob-urile utilizatorilor (`crontab -l`).

### CF-09 – Calculul diferențelor

Pentru fiecare categorie, aplicația determină: elementele prezente pe sursă și absente pe
destinație, elementele prezente pe destinație și absente pe sursă, elementele comune.

Pachetele, utilizatorii, grupurile și cronjob-urile se compară pe liste, după nume.
Fișierele se compară prin sume de control, pentru a detecta atât lipsurile, cât și
conținutul diferit.

### CF-10 – Afișarea diferențelor

Aplicația afișează diferențele grupate pe categorii: elementele lipsă, elementele prezente
doar pe destinație și diferențele de atribute ale elementelor comune. Pasul este strict
informativ.

### CF-11 – Interogarea utilizatorului

După afișarea diferențelor, aplicația cere o singură confirmare pentru întreaga clonare.
Utilizatorul nu selectează ce anume se clonează: la confirmare se aplică toate modificările
afișate (creări, suprascrieri, ștergeri), iar destinația devine identică cu sursa; la refuz
nu se execută nicio modificare, iar aplicația se oprește.

Confirmarea este obligatorie. Nicio operație de scriere sau de ștergere nu se execută
înainte de ea.

### CF-12 – Clonarea pachetelor

Pachetele lipsă se instalează prin `apt`, care rezolvă automat dependențele.
Pachetele deja instalate se sar. Pachetele prezente doar pe destinație se dezinstalează
(CF-21).

### CF-13 – Clonarea grupurilor

Grupurile lipsă se creează cu `groupadd`, înaintea utilizatorilor care le folosesc.

### CF-14 – Clonarea utilizatorilor

Utilizatorii se clonează prelucrând fișierele `/etc/passwd` și `/etc/shadow` în bloc, nu
cont cu cont. Pentru fiecare utilizator lipsă pe destinație se preia linia corespunzătoare
din `/etc/passwd` (nume, UID, GID, home, shell) și linia din `/etc/shadow` (hash-ul
parolei) de pe sursă, iar acestea se adaugă în fișierele destinației.

Prin această metodă, contul și parola sunt clonate împreună, cu exact aceleași valori ca
pe sursă (inclusiv UID-ul), astfel încât utilizatorul se poate autentifica pe destinație
cu aceeași parolă. Sistemul nu stochează parola în clar, ci doar hash-ul ei; transferul
liniei din `/etc/shadow` este singura modalitate de a păstra parola.

Se prelucrează numai liniile utilizatorilor reali (UID ≥ 1000). Conturile de sistem
(UID < 1000) nu sunt atinse, deoarece aparțin sistemului de operare al fiecărei mașini și
sunt recreate automat de `apt` odată cu pachetele care le folosesc. Înainte de modificare,
`/etc/passwd` și `/etc/shadow` de pe destinație sunt salvate într-o copie de siguranță.

Grupurile secundare ale utilizatorului se aplică separat, după adăugarea contului.
Operația necesită privilegii de root pe ambele sisteme.

Ordinea operațiilor este esențială pentru corectitudinea identificatorilor: mai întâi se
șterg utilizatorii și grupurile prezente doar pe destinație, eliberând UID-urile și
GID-urile, apoi se creează grupurile și utilizatorii de pe sursă, care primesc astfel
exact aceiași UID și GID. Fără această ordine, un identificator încă ocupat ar forța
alocarea altuia, iar contul clonat ar indica un grup greșit.

### CF-15 – Transferul home-directory-urilor

Home-directory-urile utilizatorilor creați se transferă cu `rsync` peste SSH, păstrând
permisiunile și owner-ul, după crearea utilizatorilor.

Se transferă numai home-directory-urile utilizatorilor creați în cadrul clonării. Cele ale
utilizatorilor existenți nu se modifică.

### CF-16 – Transferul directoarelor specificate

Fișierele din directoarele indicate în configurare se transferă păstrând permisiunile și
structura.

### CF-17 – Clonarea cronjob-urilor

Cronjob-urile de pe sursă se recreează pe destinație pentru utilizatorii corespunzători,
după ce aceștia există.

### CF-18 – Ordinea operațiilor

Clonarea se aplică în ordinea: grupuri → utilizatori → fișiere → pachete → cronjob-uri.

### CF-19 – Tratarea elementelor existente

Elementele existente pe destinație nu se recreează. Conturile de utilizator nu se
suprascriu niciodată — sunt doar create, șterse sau lăsate neatinse.

Pentru fișiere: cele identice cu sursa (aceeași sumă de control) se păstrează neatinse și
nu se retransferă, cele lipsă se copiază, cele care există pe ambele cu conținut diferit se
suprascriu cu versiunea de pe sursă, iar cele prezente doar pe destinație se șterg
(`rsync --delete`).

### CF-20 – Raportarea diferențelor pentru elementele comune

Pentru utilizatorii și grupurile existente pe ambele sisteme, aplicația compară UID, GID,
home-directory, shell și grupurile secundare, și raportează diferențele.

Elementele comune nu se modifică. Raportarea are rol de avertisment: un UID diferit
înseamnă că fișierele transferate păstrează UID-ul de pe sursă și vor apărea pe destinație
ca aparținând altui utilizator, deoarece proprietatea fișierelor e stocată numeric, nu ca
nume.

### CF-21 – Ștergerea elementelor prezente doar pe destinație

Elementele prezente pe destinație dar nu pe sursă — utilizatori, grupuri, pachete,
cronjob-uri, fișiere din home-directory-uri și din directoarele specificate — se detectează,
se afișează și se șterg la confirmarea clonării. Astfel, destinația devine identică cu
sursa.

Ștergerea se realizează cu: `userdel -r` pentru utilizatori, `groupdel` pentru grupuri,
`apt remove` pentru pachete, `crontab` pentru cronjob-uri și `rsync --delete` pentru
fișiere.

**Restricții obligatorii la ștergerea utilizatorilor.** Nu se șterg conturile de sistem
(UID < 1000), utilizatorul prin care e stabilită conexiunea SSH și utilizatorul care execută
scriptul. Ștergerea acestora ar întrerupe conexiunea sau execuția scriptului, lăsând
destinația într-o stare inconsistentă.

**Restricții obligatorii la ștergerea pachetelor.** Se dezinstalează numai pachete din lista
de pachete instalate manual. Înainte de dezinstalare, aplicația determină cu
`apt remove --dry-run` lista completă a pachetelor care ar fi eliminate prin dependențe și o
afișează utilizatorului. Dacă lista conține pachete esențiale sau pachete care nu apar în
diferența calculată, dezinstalarea acelui pachet este raportată și sărită. Motivul: pachetele
nu sunt independente între ele, iar dezinstalarea unuia poate elimina în cascadă componente
de care sistemul destinație are nevoie.

### CF-22 – Pachete indisponibile

Dacă un pachet de pe sursă nu există în repository-urile destinației, aplicația îl
raportează ca neinstalabil și continuă cu restul.

### CF-23 – Jurnalizarea

Aplicația înregistrează în jurnal acțiunile efectuate, elementele sărite și erorile, cu
timestamp. Informațiile sensibile (hash-uri de parolă) nu se scriu în jurnal.

### CF-24 – Mesajul de ajutor

`--help` afișează parametrii disponibili și exemple de utilizare.

### CF-25 – Gestionarea erorilor

Aplicația detectează și raportează: conexiune SSH eșuată, adresă invalidă, lipsa
privilegiilor, comandă externă indisponibilă, opțiune necunoscută, conflict de UID.

### CF-26 – Coduri de ieșire

Scripturile returnează `0` la succes și un cod diferit de `0` la eșec.

## 3.2 Cerințe nefuncționale

### CNF-01 – Compatibilitate
Aplicația rulează pe o distribuție Linux bazată pe Debian (platformă de test: Linux Mint).

### CNF-02 – Modularitate
Codul e împărțit în componente cu responsabilități clare (colectare, comparare, aplicare),
iar funcțiile comune sunt izolate în fișiere reutilizabile.

### CNF-03 – Claritatea codului
Nume descriptive, comentarii pentru operațiile importante, indentare consecventă.

### CNF-04 – Fiabilitate
Aplicația nu raportează succesul unei operații eșuate. O clonare parțial eșuată e raportată
ca atare.

### CNF-05 – Securitate
Autentificare SSH pe bază de chei. Operațiile privilegiate cu `sudo`. Hash-urile de parolă
nu se afișează și nu se scriu în jurnal. Parolele nu se scriu în cod.

### CNF-06 – Idempotență
Pentru aceeași stare a celor două sisteme, aplicația identifică aceleași diferențe. După o
clonare completă, o a doua rulare nu mai găsește diferențe și nu execută nicio modificare.

### CNF-07 – Gestionarea căilor
Scripturile procesează corect căile cu spații și caractere speciale. Variabilele cu căi se
folosesc între ghilimele.

### CNF-08 – Portabilitate
Fără căi fixe specifice unei mașini. Adresele, utilizatorii și directoarele se configurează
dinamic.

### CNF-09 – Ușurința utilizării
Parametri cu nume descriptive. Mesaje despre progresul operației.

### CNF-10 – Mesaje de eroare
Mesajele indică operația eșuată, elementul implicat și cauza probabilă.

### CNF-11 – Jurnalizare
Format ușor de citit, cu dată, oră și nivel (`INFO`, `WARNING`, `ERROR`).

### CNF-12 – Configurabilitate
Fiecare categorie poate fi activată sau dezactivată:

```text
CLONE_PACHETE=true
CLONE_UTILIZATORI=true
CLONE_HOME=true
CLONE_CRON=true
```

### CNF-13 – Siguranța operațiilor
Operațiile de scriere, creare sau ștergere se execută numai asupra unor căi și valori
validate, niciodată asupra unor variabile vide.

### CNF-14 – Controlul versiunilor
Codul se păstrează în Git, cu commituri descriptive.

### CNF-15 – Documentare
Repository-ul conține un `README.md` cu scopul proiectului, dependențele, exemplele de
utilizare și limitările cunoscute.

### CNF-16 – Protejarea datelor existente
Aplicația nu suprascrie și nu șterge automat fișiere, utilizatori sau configurări de pe
destinație. Toate modificările sunt afișate în prealabil și se execută numai după
confirmarea explicită a utilizatorului. La refuz, niciun sistem nu e modificat.
