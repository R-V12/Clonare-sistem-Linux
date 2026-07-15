## Clonare sistem Linux

Student: Vlădescu Rareș
Proiect: „Clonare" sistem Linux
Repository: https://github.com/R-V12/Clonare-sistem-Linux

# Capitolul 1: Introducere

## 1.1 Scopul proiectului

Scopul proiectului este proiectarea și implementarea unui sistem software care replică
starea unui sistem de operare Linux, numit **sursă**, pe un alt sistem
Linux, numit **destinație**. Aplicația va fi implementată sub forma unei colecții de
scripturi Bash.

Scriptul poate fi rulat de pe oricare dintre cele două sisteme. El colectează starea
ambelor mașini, compară cele două sisteme, afișează diferențele dintre ele și, numai după
confirmarea utilizatorului, clonează pe destinație elementele care lipsesc.

Elementele care pot fi clonate sunt:

* pachetele (aplicațiile) instalate;
* utilizatorii și grupurile;
* fișierele din home-directory-uri;
* fișierele din directoare specificate de utilizator;
* cronjob-urile;
* alte elemente de configurare (servicii, chei SSH), opțional.

O caracteristică definitorie a aplicației este că nu clonează automat totul: mai întâi
calculează și afișează diferențele dintre sursă și destinație, apoi întreabă utilizatorul
ce anume dorește să cloneze. Elementele care există deja pe destinație nu sunt
suprascrise. Transferul datelor între cele două sisteme se realizează prin SSH și
SCP/rsync, iar toate acțiunile sunt înregistrate într-un fișier jurnal.

Documentul de față definește funcționalitățile aplicației, termenii utilizați, platforma
necesară, pregătirea mediului de lucru, constrângerile de implementare și cerințele
funcționale și nefuncționale care trebuie respectate.

## 1.2 Lista definițiilor

**apt / dpkg**
Utilitarele de gestiune a pachetelor pe distribuțiile bazate pe Debian. `dpkg` ține
evidența pachetelor instalate, iar `apt` rezolvă dependențele și descarcă pachetele.

**Bash**
Interpretor de comenzi și limbaj de scripting disponibil pe Linux. Scripturile
proiectului sunt implementate în Bash.

**Clonare**
În contextul acestui proiect, replicarea configurației (utilizatori, pachete, fișiere,
cronjob-uri) de pe sistemul sursă pe sistemul destinație. Nu se referă la copierea
întregului sistem de operare.

**Cronjob**
Sarcină programată să ruleze automat, la intervale definite, prin serviciul `cron`.
Vizibilă cu `crontab -l` și stocată în `/var/spool/cron/crontabs/` sau în `/etc/cron.*`.

**Fișier de configurare**
Fișier text care conține opțiunile aplicației: modul de rulare, adresa celeilalte mașini,
categoriile de clonat și directoarele suplimentare.

**GID – Group Identifier**
Identificator numeric al unui grup de utilizatori.

**Home-directory**
Directorul personal al unui utilizator, de regulă `/home/<user>`.

**Idempotență**
Proprietatea unei operații de a produce același rezultat indiferent de câte ori este
executată. Rularea repetată a scriptului nu trebuie să producă modificări suplimentare
sau efecte secundare.

**Pachet**
Aplicație instalată prin managerul de pachete.

**rsync**
Utilitar de copiere a fișierelor care transferă doar diferențele și păstrează permisiunile
și owner-ul. Poate lucra peste SSH.

**SCP – Secure Copy**
Utilitar de copiere a fișierelor între mașini, peste SSH.

**SSH – Secure Shell**
Protocol de conectare securizată la o mașină remote, folosit pentru rularea comenzilor la
distanță și pentru transferul fișierelor.

**Sistem sursă**
Sistemul de la care se preia starea (referința).

**Sistem destinație**
Sistemul pe care se aplică clonarea.

**Sumă de control (checksum)**
Valoare („amprentă") calculată din conținutul unui fișier, folosită pentru a compara
fișiere și a detecta modificările. Se calculează cu `md5sum` sau `sha256sum`.

**UID – User Identifier**
Identificator numeric al unui utilizator. Utilizatorii „reali" au de obicei UID ≥ 1000,
iar conturile de sistem au UID mai mic.

**/etc/passwd, /etc/shadow, /etc/group**
Fișierele text de sistem în care sunt stocate conturile de utilizator, hash-urile
parolelor și, respectiv, grupurile.

## 1.3 Structura documentului

Documentul este organizat în trei capitole:

**Capitolul 1 – Introducere** prezintă scopul proiectului, termenii folosiți, referințele
și structura documentului.

**Capitolul 2 – Descrierea generală** prezintă funcționarea aplicației, platforma
necesară, pregătirea mediului de lucru și constrângerile.

**Capitolul 3 – Cerințe specifice** definește cerințele funcționale (prefix `CF`) și
nefuncționale (prefix `CNF`).

# Capitolul 2: Descrierea generală a produsului software

## 2.1 Descrierea produsului software

Produsul este o colecție de scripturi Bash care replică starea unui sistem Linux pe altul.
Aplicația este organizată în componente cu responsabilități clare, care colaborează pentru
realizarea fluxului complet.

Structura orientativă a proiectului:

```text
Clonare-sistem-Linux/
├── config/
│   └── clonare.conf
├── scripts/
│   ├── clonare.sh
│   ├── colectare.sh
│   ├── comparare.sh
│   ├── aplicare.sh
│   └── lib/
├── docs/
│   ├── document_cerinte.md
│   └── document_testare.md
├── logs/
├── README.md
└── .gitignore
```

### Fluxul aplicației

Aplicația parcurge următoarele etape, în ordine:

1. **Citirea configurației** – modul de rulare (sursă/destinație), adresa și utilizatorul
   celeilalte mașini, categoriile de clonat, directoarele suplimentare.
2. **Stabilirea conexiunii SSH** cu cealaltă mașină.
3. **Colectarea stării** de pe ambele sisteme: pachete, utilizatori, grupuri,
   home-directory-uri, cronjob-uri, directoare specificate.
4. **Calculul diferențelor** – pentru fiecare categorie, ce există pe sursă dar lipsește
   pe destinație.
5. **Afișarea diferențelor**, grupate pe categorii.
6. **Interogarea utilizatorului** – pentru fiecare categorie, dacă să fie clonată.
7. **Aplicarea clonării** – doar pentru categoriile confirmate, respectând ordinea corectă
   a operațiilor.
8. **Jurnalizarea** – înregistrarea a ceea ce s-a clonat, ce s-a sărit și a erorilor.

### Ordinea operațiilor de clonare

Ordinea de aplicare este importantă din cauza dependențelor:

1. **Grupurile** se creează primele.
2. **Utilizatorii** se creează după grupuri (au nevoie de grupul principal).
3. **Home-directory-urile și fișierele** se transferă după crearea utilizatorilor,
   pentru ca owner-ul (UID/GID) să poată fi aplicat corect. Transferul înaintea creării
   utilizatorului ar face imposibilă atribuirea corectă a proprietarului.
4. **Pachetele** pot fi instalate independent.
5. **Cronjob-urile** se recreează după ce utilizatorii corespunzători există.

### Fluxul de diferențe și interogare

Aceasta este caracteristica centrală a proiectului. Înainte de orice modificare:

* pentru fiecare categorie se afișează lista elementelor prezente pe sursă dar absente pe
  destinație (de exemplu: „Pachete de clonat: htop, tree, ncdu");
* utilizatorul este întrebat separat pentru fiecare categorie dacă dorește clonarea
  (`Clonez pachetele lipsă? [d/n]`);
* dacă utilizatorul refuză o categorie, aceasta este ignorată complet, iar restul
  categoriilor se procesează normal;
* nicio operație de scriere nu se execută înainte de confirmare.

### Exemple de utilizare

Rulare cu parametri:

```bash
./scripts/clonare.sh --mod sursa --tinta 192.168.56.20 --user rares
```

Rulare cu fișier de configurare:

```bash
./scripts/clonare.sh --config config/clonare.conf
```

## 2.2 Platforma HW/SW și pregătirea mediului de lucru

### Platforma hardware

Aplicația nu necesită hardware specializat. Este suficient un calculator care poate rula
două mașini virtuale Linux simultan (minimum recomandat: procesor cu suport de
virtualizare, memorie suficientă pentru gazdă plus două VM-uri, spațiu de disc pentru
ambele sisteme).

### Platforma software

Aplicația se dezvoltă și se testează pe Linux Mint (bazat pe Ubuntu/Debian). Utilitarele
folosite: Bash, coreutils (`md5sum`, `sha256sum`, `sort`, `comm`, `diff`), utilitarele de
utilizatori (`useradd`, `groupadd`, `chpasswd`, `getent`), `dpkg`/`apt`, `ssh`/`scp`,
`rsync`, `cron`/`crontab`.

### Pregătirea mediului de lucru

**Cele două mașini virtuale.** Proiectul necesită două sisteme: sursă și destinație. Se
folosesc două mașini virtuale Linux Mint (identice ca bază), obținute prin clonarea VM-ului
inițial în VirtualBox (Full Clone, cu adrese MAC regenerate). Cele două VM-uri trebuie să
se poată vedea în rețea (adaptor Host-Only sau Internal Network) pentru a comunica prin
SSH.

**Instalarea git și configurarea:**

```bash
sudo apt update
sudo apt install -y git
git config --global user.name "rares.vladescu"
git config --global user.email "rares.vladescu@mta.ro"
```

**Instalarea SSH și generarea cheilor** (pe ambele mașini):

```bash
sudo apt install -y openssh-server openssh-client
ssh-keygen -t ed25519
ssh-copy-id user@ip_destinatie
```

**Instalarea rsync:**

```bash
sudo apt install -y rsync
```

**Verificarea mediului:**

```bash
ssh user@ip_destinatie "hostname"    # conexiune SSH funcțională
rsync --version                       # rsync disponibil
git --version                         # git disponibil
```

### Activități de familiarizare

Înainte de integrarea în aplicație, se vor realiza următoarele activități minime de
familiarizare cu noțiunile noi:

1. Listarea pachetelor instalate manual cu `apt-mark showmanual`.
2. Citirea utilizatorilor reali (UID ≥ 1000) din `/etc/passwd`.
3. Crearea și ștergerea unui utilizator de test cu `useradd` / `userdel`.
4. Adăugarea și listarea unui cronjob de test cu `crontab`.
5. Conectarea prin SSH și rularea unei comenzi remote fără parolă (chei).
6. Transferul unui director cu `rsync` peste SSH, verificând păstrarea permisiunilor.
7. Compararea a două fișiere prin `sha256sum` și a două liste prin `comm`.

## 2.3 Constrângeri

### Constrângeri privind datele

Datele de pe sursă trebuie să fie accesibile utilizatorului care execută scriptul.
Colectarea utilizatorilor și a hash-urilor de parolă (`/etc/shadow`) necesită privilegii
administrative. Directoarele de destinație trebuie să permită scrierea. Căile fișierelor
pot conține spații și caractere speciale, deci scripturile trebuie să folosească ghilimele
și metode sigure de parcurgere.

### Constrângeri funcționale

Aplicația trebuie să ruleze din linia de comandă. Nicio modificare nu se aplică fără
confirmarea utilizatorului. Elementele existente pe destinație nu se suprascriu.
Parametrii din linia de comandă au prioritate față de fișierul de configurare. Ordinea
operațiilor (grupuri → utilizatori → fișiere → cronjob-uri) trebuie respectată din cauza
dependențelor.

### Constrângeri tehnologice

Aplicația trebuie implementată în Bash. Transferul între sisteme se face prin SSH și
`rsync`/`scp`. Instalarea pachetelor se face prin `apt`. Compararea fișierelor se face
prin sume de control. Utilizatorii se creează prin `useradd`, iar grupurile prin
`groupadd`.

### Constrângeri de securitate

Operațiile care necesită privilegii (creare utilizatori, instalare pachete) se execută cu
`sudo`. Dacă se transferă hash-urile de parolă din `/etc/shadow`, acestea nu trebuie
afișate pe ecran și nu trebuie înregistrate în jurnal. Autentificarea SSH se face pe bază
de chei; parolele nu se scriu în cod și nu se transmit ca text vizibil. Operațiile de
scriere se execută numai asupra unor căi validate.

### Constrângeri privind conexiunea

Aplicația depinde de o conexiune SSH funcțională între cele două mașini. Dacă mașina
destinație nu este accesibilă sau autentificarea eșuează, aplicația trebuie să se
oprească controlat, cu un mesaj de eroare, fără a modifica niciun sistem.

---

# Capitolul 3: Detalierea cerințelor specifice

## 3.1 Cerințe funcționale (CF)

### CF-01 – Selectarea modului de rulare

Aplicația trebuie să permită rularea în modul **sursă** sau **destinație**. Modul
determină pe care mașină se citește starea de referință și pe care se aplică modificările.
Modul se stabilește prin parametru sau prin fișierul de configurare.

### CF-02 – Procesarea parametrilor din linia de comandă

Aplicația trebuie să accepte parametri pentru configurarea operației, de exemplu:

```text
--mod       (sursa | destinatie)
--tinta     (adresa celeilalte mașini)
--user      (utilizatorul SSH pe cealaltă mașină)
--config    (fișier de configurare)
--categorii (pachete,utilizatori,home,cron,...)
--help
```

Parametrii din linia de comandă au prioritate față de fișierul de configurare.

### CF-03 – Citirea fișierului de configurare

Aplicația trebuie să permită citirea opțiunilor dintr-un fișier de configurare, care poate
conține modul de rulare, adresa și utilizatorul celeilalte mașini, categoriile de clonat,
directoarele suplimentare și locația jurnalului.

### CF-04 – Stabilirea conexiunii SSH

Aplicația trebuie să stabilească o conexiune SSH cu cealaltă mașină, folosind autentificare
pe bază de chei. Conexiunea este folosită atât pentru rularea comenzilor de colectare, cât
și pentru transferul fișierelor. Dacă conexiunea eșuează, aplicația se oprește.

### CF-05 – Colectarea listei de pachete

Aplicația trebuie să obțină de pe fiecare sistem lista pachetelor instalate manual
(`apt-mark showmanual`), pentru comparație.

### CF-06 – Colectarea utilizatorilor și grupurilor

Aplicația trebuie să obțină lista utilizatorilor reali (UID ≥ 1000) și a grupurilor, cu
datele relevante: nume, UID, GID, home-directory, shell și apartenența la grupuri.

### CF-07 – Colectarea home-directory-urilor

Aplicația trebuie să identifice conținutul home-directory-urilor utilizatorilor, pentru a
putea determina ce fișiere trebuie transferate.

### CF-08 – Colectarea directoarelor specificate

Aplicația trebuie să poată colecta și fișierele din directoare suplimentare indicate de
utilizator în configurare.

### CF-09 – Colectarea cronjob-urilor

Aplicația trebuie să extragă cronjob-urile utilizatorilor (`crontab -l`) și, opțional, pe
cele de sistem.

### CF-10 – Calculul diferențelor

Pentru fiecare categorie, aplicația trebuie să determine elementele prezente pe sursă dar
absente pe destinație. Pentru pachete, utilizatori, grupuri și cronjob-uri, comparația se
face pe liste. Pentru fișiere, comparația se face pe baza sumelor de control, astfel încât
să fie detectate atât fișierele lipsă, cât și cele cu conținut diferit.

### CF-11 – Afișarea diferențelor

Aplicația trebuie să afișeze diferențele calculate, grupate pe categorii, astfel încât
utilizatorul să vadă exact ce ar urma să fie clonat. Acest pas este strict informativ.

### CF-12 – Interogarea utilizatorului

Înainte de orice modificare, aplicația trebuie să întrebe utilizatorul, pe fiecare
categorie, dacă dorește clonarea. Nicio operație de scriere nu se execută fără confirmare.
Refuzul unei categorii nu afectează procesarea celorlalte.

### CF-13 – Clonarea pachetelor

Pachetele prezente pe sursă dar absente pe destinație și confirmate de utilizator trebuie
instalate pe destinație prin `apt`. Pachetele deja instalate sunt sărite.

### CF-14 – Clonarea grupurilor

Grupurile care există pe sursă dar nu pe destinație trebuie create pe destinație
(`groupadd`), înaintea creării utilizatorilor care le folosesc.

### CF-15 – Clonarea utilizatorilor

Utilizatorii care există pe sursă dar nu pe destinație trebuie creați pe destinație
(`useradd`), cu grupul principal, home-directory-ul și shell-ul corespunzător. Opțional,
se poate transfera hash-ul parolei din `/etc/shadow`, astfel încât contul să fie utilizabil
imediat. Un utilizator care există deja pe destinație nu este recreat.

### CF-16 – Transferul home-directory-urilor

Home-directory-urile utilizatorilor clonați trebuie transferate pe destinație cu `rsync`
peste SSH, păstrând permisiunile și owner-ul. Transferul se face după crearea
utilizatorilor, pentru ca UID/GID să poată fi aplicate corect.

### CF-17 – Transferul directoarelor specificate

Fișierele din directoarele suplimentare indicate în configurare trebuie transferate pe
destinație păstrând permisiunile și structura.

### CF-18 – Clonarea cronjob-urilor

Cronjob-urile definite pe sursă trebuie recreate pe destinație pentru utilizatorii
corespunzători, după ce aceștia există.

### CF-19 – Respectarea ordinii operațiilor

Aplicația trebuie să aplice clonarea în ordinea: grupuri → utilizatori → fișiere
(home-dir-uri și directoare) → pachete → cronjob-uri, din cauza dependențelor dintre
acestea.

### CF-20 – Protejarea elementelor existente

Aplicația nu trebuie să suprascrie sau să modifice elementele care există deja pe
destinație. Un pachet instalat, un utilizator existent sau un fișier identic sunt tratate
ca „deja prezente" și sunt sărite. Aceasta permite rularea repetată fără efecte secundare.

### CF-21 – Gestionarea conflictelor de UID/GID

Dacă un utilizator sau grup există pe destinație cu alt UID/GID decât pe sursă, aplicația
trebuie să detecteze conflictul, să nu îl suprascrie automat și să raporteze situația
utilizatorului.

### CF-22 – Tratarea pachetelor indisponibile

Dacă un pachet de pe sursă nu este disponibil în repository-urile destinației, aplicația
trebuie să raporteze pachetul ca neinstalabil și să continue cu restul, fără a se opri.

### CF-23 – Gestionarea categoriei „altele" (opțional)

Aplicația poate clona și alte elemente de configurare (de exemplu servicii systemd
activate, chei SSH `authorized_keys`), dacă utilizatorul le activează explicit. Dacă
această categorie nu este implementată, absența ei trebuie menționată ca decizie asumată.

### CF-24 – Jurnalizarea

Aplicația trebuie să înregistreze într-un fișier jurnal toate acțiunile efectuate,
elementele sărite și erorile, fiecare cu un moment de timp (timestamp). Informațiile
sensibile (parole, hash-uri) nu trebuie introduse în jurnal.

### CF-25 – Afișarea mesajului de ajutor

Aplicația trebuie să afișeze instrucțiuni de utilizare la folosirea parametrului `--help`,
prezentând parametrii disponibili și exemple.

### CF-26 – Gestionarea erorilor

Aplicația trebuie să detecteze și să raporteze cel puțin: conexiune SSH eșuată, adresă de
destinație invalidă, lipsa privilegiilor necesare, comandă externă indisponibilă, opțiune
necunoscută și conflict de UID/GID.

### CF-27 – Codurile de ieșire

Scripturile trebuie să returneze codul `0` la succes și un cod diferit de `0` la eșec.

## 3.2 Cerințe nefuncționale (CNF)

### CNF-01 – Compatibilitate

Aplicația trebuie să ruleze pe o distribuție Linux bazată pe Debian (platforma de test:
Linux Mint), cu utilitarele necesare instalate.

### CNF-02 – Modularitate

Codul trebuie împărțit în componente cu responsabilități clare (colectare, comparare,
aplicare), iar funcțiile comune trebuie izolate în fișiere reutilizabile din `lib/`.

### CNF-03 – Claritatea codului

Scripturile trebuie să folosească nume descriptive, comentarii pentru operațiile
importante, indentare consecventă și mesaje de eroare clare.

### CNF-04 – Fiabilitate

Aplicația nu trebuie să raporteze succesul unei operații care a eșuat. O clonare parțial
eșuată trebuie raportată ca atare.

### CNF-05 – Securitate

Autentificarea SSH se face pe bază de chei. Operațiile privilegiate se execută cu `sudo`.
Hash-urile de parolă și orice informație sensibilă nu se afișează și nu se scriu în jurnal.
Parolele nu se scriu în cod și nu se introduc în repository.

### CNF-06 – Comportament determinist (idempotență)

Pentru aceeași stare a celor două sisteme și aceeași configurație, aplicația trebuie să
identifice aceleași diferențe. Rularea repetată nu trebuie să producă modificări
suplimentare peste ceea ce a fost deja clonat.

### CNF-07 – Gestionarea căilor

Scripturile trebuie să proceseze corect căile care conțin spații și caractere speciale.
Variabilele care conțin căi trebuie utilizate între ghilimele.

### CNF-08 – Portabilitate

Scripturile trebuie să evite căile fixe specifice unei singure mașini. Adresele, utilizatorii
și directoarele trebuie configurate dinamic.

### CNF-09 – Ușurința utilizării

Parametrii trebuie să aibă nume descriptive. Aplicația trebuie să afișeze mesaje despre
progresul operației (colectare, comparare, aplicare).

### CNF-10 – Mesaje de eroare

Mesajele de eroare trebuie să indice operația care a eșuat, elementul implicat și cauza
probabilă. Un mesaj generic „Eroare" nu este suficient.

### CNF-11 – Jurnalizare

Fișierul jurnal trebuie să folosească un format ușor de citit, cu dată, oră și nivel
(`INFO`, `WARNING`, `ERROR`) pentru fiecare mesaj.

### CNF-12 – Configurabilitate

Utilizatorul trebuie să poată activa sau dezactiva fiecare categorie de clonat, de exemplu:

```text
CLONE_PACHETE=true
CLONE_UTILIZATORI=true
CLONE_HOME=true
CLONE_CRON=true
CLONE_ALTELE=false
```

### CNF-13 – Siguranța operațiilor

Operațiile de scriere sau creare pe destinație trebuie executate numai asupra unor căi și
valori validate. Aplicația nu trebuie să execute operații periculoase asupra unor variabile
vide sau nevalidate.

### CNF-14 – Controlul versiunilor

Codul proiectului trebuie păstrat într-un repository Git, cu commituri descriptive, de
exemplu:

```text
Adauga colectarea listei de utilizatori
Implementeaza calculul diferentelor
Adauga transferul home-dir prin rsync
```

### CNF-15 – Documentare

Repository-ul trebuie să conțină un fișier `README.md` care prezintă scopul proiectului,
structura directoarelor, dependențele, instalarea, exemplele de utilizare și limitările
cunoscute.

### CNF-16 – Protejarea datelor existente

Aplicația nu trebuie să suprascrie automat utilizatori, fișiere sau configurări existente
pe destinație. Orice suprascriere trebuie să fie rezultatul unei confirmări explicite a
utilizatorului.

