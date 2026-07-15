# DOCUMENT DE CERINȚE - Clonare sistem Linux

Sd. Cap. Vlădescu Rareș - C 112-C


Tema Proiect: Clonare sistem Linux


Repo: https://github.com/R-V12/Clonare-sistem-Linux



# Capitolul 1: Introducere

## 1.1 Scopul proiectului

Aplicația este o colecție de scripturi Bash care replică starea unui sistem Linux
(sursă) pe alt sistem Linux (destinație). Scriptul se poate rula de pe oricare
dintre cele două sisteme. El colectează starea ambelor mașini, calculează diferențele,
le afișează și, numai după confirmarea utilizatorului, aplică modificările pe destinație.

Elementele care se pot clona: pachetele instalate, utilizatorii și grupurile, fișierele
din home-directory-uri, fișierele din directoare specificate și cronjob-urile.

Transferul se face prin SSH și rsync. Nicio modificare nu se aplică fără confirmare, iar
toate acțiunile se înregistrează într-un jurnal.

## 1.2 Lista definițiilor

**apt / dpkg** — utilitarele de gestiune a pachetelor pe distribuțiile Debian. `dpkg` ține
evidența pachetelor instalate, `apt` rezolvă dependențele.

**Bash** — interpretorul în care sunt scrise scripturile.

**Clonare** — replicarea configurației (utilizatori, pachete, fișiere, cronjob-uri) de pe
sursă pe destinație. Nu se referă la copierea sistemului de operare.

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

1. Citirea configurației (mod de rulare, adresa celeilalte mașini, categorii)
2. Stabilirea conexiunii SSH
3. Colectarea stării de pe ambele sisteme
4. Compararea listelor de pe cele doua sisteme
5. Afișarea rezultatelor, pe categorii
6. Interogarea utilizatorului, pe categorii
7. Aplicarea modificărilor confirmate
8. Jurnalizarea/Noteaza intr-un fisier ce a facut pe parcursul intregului script

## 2.2 Ordinea operațiilor

1. **Grupurile** se creează primele.
2. **Utilizatorii** — după grupuri (au nevoie de grupul principal).
3. **Fișierele** — după utilizatori, pentru ca owner-ul (UID) să poată fi aplicat corect.
4. **Pachetele** — independent.
5. **Cronjob-urile** — după utilizatorii corespunzători.

## 2.3 Diferențe și interogare

Diferențele se calculează în ambele direcții și rezultă trei categorii:

* **lipsă pe destinație** — pot fi clonate;
* **doar pe destinație** — pot fi șterse;
* **comune** — nu se recreează; diferențele de atribute se raportează.

Ex: pentru sursa cu `user1, user2, user3` si destinatie cu `user1, user2, user4`:

```
Diferente utilizatori:
  Lipsa pe destinatie:  user3
  Doar pe destinatie:   user4
  Comuni:               user1, user2

Clonez utilizatorii lipsa? [d/n] d
Sterg utilizatorii care exista doar pe destinatie? [d/n] n

Se creeaza: user3
user4: pastrat (refuzat de utilizator)
user1, user2: existenti, nemodificati
```
## 2.4 Platforma și mediul de lucru

Aplicația rulează pe Linux Mint (bazat pe Debian). Utilitare folosite: Bash, coreutils,
`useradd`/`groupadd`/`chpasswd`/`getent`, `dpkg`/`apt`, `ssh`, `rsync`, `crontab`.

Sunt necesare două mașini virtuale Linux Mint (sursă și destinație), conectate în rețea
(Host-Only sau Internal Network), cu SSH configurat pe bază de chei.

```
sudo apt install -y git openssh-server openssh-client rsync
ssh-keygen -t ed25519
ssh-copy-id user@ip_destinatie
ssh user@ip_destinatie "hostname"
```
## 2.6 Constrângeri

**Date.** Citirea utilizatorilor și a hash-urilor din `/etc/shadow` necesită root pe sursă.
Crearea utilizatorilor și instalarea pachetelor necesită root pe destinație. Căile pot
conține spații, deci variabilele se folosesc între ghilimele.

**Funcționale.** Aplicația rulează din linia de comandă. Nicio modificare fără confirmare.
Parametrii din linia de comandă au prioritate față de fișierul de configurare. Ordinea
operațiilor din 2.2 trebuie respectată.

**Tehnologice.** Implementare în Bash. Transfer prin SSH și rsync. Pachete prin `apt`.
Comparare fișiere prin sume de control. Utilizatori prin `useradd`, grupuri prin `groupadd`.

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

Aplicația se conectează prin SSH cu autentificare pe bază de chei. Dacă conexiunea
eșuează, aplicația se oprește.

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

### CF-09 – Calculul diferențelor/Identificarea clara a

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

Aplicația întreabă utilizatorul, pe fiecare categorie, dacă dorește clonarea elementelor
lipsă și, separat, dacă dorește ștergerea elementelor prezente doar pe destinație.
Confirmarea unei categorii acoperă toate operațiile din acea categorie. Refuzul unei
categorii nu afectează procesarea celorlalte.

### CF-12 – Clonarea pachetelor

Pachetele lipsă și confirmate se instalează prin `apt`, care rezolvă automat dependențele.
Pachetele deja instalate se sar.

### CF-13 – Clonarea grupurilor

Grupurile lipsă se creează cu `groupadd`, înaintea utilizatorilor care le folosesc.

### CF-14 – Clonarea utilizatorilor

Utilizatorii lipsă și confirmați se creează cu `useradd`, cu același UID, grup principal,
home-directory, shell și grupuri secundare ca pe sursă.

UID-ul se impune explicit (`useradd -u`), deoarece un UID alocat automat ar diferi de cel
de pe sursă, iar fișierele transferate ar ajunge cu proprietar greșit. Grupurile secundare
se aplică la creare (`useradd -G`), pentru ca și drepturile contului să fie clonate.

Parola se preia sub forma hash-ului din `/etc/shadow` și se aplică cu `chpasswd -e`.
Sistemul nu stochează parola în clar, ci doar hash-ul ei, deci transferul hash-ului este
singura modalitate prin care contul clonat păstrează parola de pe sursă. Necesită root pe
ambele sisteme.

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

Pentru fișiere, în categoriile confirmate: fișierele identice se sar, cele lipsă se
copiază, iar cele care există pe ambele cu conținut diferit se suprascriu cu versiunea de
pe sursă.

### CF-20 – Raportarea diferențelor pentru elementele comune

Pentru utilizatorii și grupurile existente pe ambele sisteme, aplicația compară UID, GID,
home-directory, shell și grupurile secundare, și raportează diferențele.

Elementele comune nu se modifică. Raportarea are rol de avertisment: un UID diferit
înseamnă că fișierele transferate păstrează UID-ul de pe sursă și vor apărea pe destinație
ca aparținând altui utilizator, deoarece proprietatea fișierelor e stocată numeric, nu ca
nume.

### CF-21 – Ștergerea elementelor prezente doar pe destinație

Elementele prezente pe destinație dar nu pe sursă (utilizatori, grupuri, cronjob-uri,
fișiere din directoarele specificate) se detectează și se afișează. Aplicația întreabă dacă
utilizatorul dorește ștergerea lor. La confirmare, se șterg și destinația devine identică
cu sursa în categoria respectivă. La refuz, rămân neatinse.

Restricții obligatorii la ștergerea utilizatorilor:

* nu se șterg conturile de sistem (UID < 1000);
* nu se șterge utilizatorul prin care e stabilită conexiunea SSH;
* nu se șterge utilizatorul care execută scriptul.

Pachetele nu fac obiectul ștergerii. Un pachet prezent doar pe destinație se raportează,
dar nu se dezinstalează: pachetele nu sunt independente între ele, iar dezinstalarea unuia
poate elimina prin dependențe alte pachete de care sistemul are nevoie. Utilizatorii nu
prezintă acest risc, fiecare cont fiind independent.

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

### CNF-6 – Mesaje de eroare
Mesajele indică operația eșuată, elementul implicat și cauza probabilă.

### CNF-7 – Jurnalizare
Format ușor de citit, cu dată, oră și nivel in fisier (`INFO`, `WARNING`, `ERROR`).

### CNF-8 – Configurabilitate
Fiecare categorie poate fi activată sau dezactivată:

```
CLONE_PACHETE=true
CLONE_UTILIZATORI=true
CLONE_HOME=true
CLONE_CRON=true
```
