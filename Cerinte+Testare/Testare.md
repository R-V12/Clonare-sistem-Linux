# DOCUMENT DE TESTARE - Clonare sistem Linux


Sd. Cap. Vlădescu Rareș - C 112-C


Repo: https://github.com/R-V12/Clonare-sistem-Linux

## Mediul de testare

Două mașini virtuale Linux Mint, sursă și destinație, conectate în rețea
(Host-Only), cu SSH pe bază de chei configurat între ele.

Verificare înainte de testare:

```
ssh user@ip_destinatie "hostname" 
```

Fiecare test conține: ce verifică, pasii și rezultatul așteptat. Coloana
*Cerință* indică cerința validată din documentul de cerințe.

---

# 1. Teste pentru parametri

## TP-01 — Parametri corecți

**Pași:** rulez `./clonare.sh --mod sursa --tinta <ip> --user rares`

**Rezultat:** scriptul pornește, se conectează și afișează diferențele.

## TP-02 — Parametru obligatoriu lipsă

**Pași:** rulez `./clonare.sh --mod sursa` (fără `--tinta`)

**Rezultat:** mesaj de eroare care indică parametrul lipsă, cod de ieșire diferit de `0`,
nicio modificare pe niciun sistem.

## TP-03 — Parametru necunoscut

**Pași:** rulez `./clonare.sh --xyz`

**Rezultat:** mesaj „opțiune necunoscută", scriptul se oprește, cod diferit de `0`.

## TP-04 — Valoare invalidă pentru mod 

**Pași:** rulez `./clonare.sh --mod altceva --tinta <ip>`

**Rezultat:** mesaj de eroare care indică valorile acceptate (`sursa` / `destinatie`).

## TP-05 — Fișier de configurare 

**Pași:** creez `clonare.conf` cu mod, țintă și user, apoi rulez
`./clonare.sh --config clonare.conf`

**Rezultat:** scriptul citește opțiunile din fișier și pornește identic ca la TP-01.

## TP-06 — Prioritatea parametrilor 

**Pași:** în `clonare.conf` pun `TINTA=192.168.56.30`, apoi rulez
`./clonare.sh --config clonare.conf --tinta 192.168.56.20`

**Rezultat:** scriptul se conectează la `.20` (parametrul din linia de comandă câștigă).

## TP-07 — Fișier de configurare inexistent 

**Pași:** rulez `./clonare.sh --config /tmp/nu_exista.conf`

**Rezultat:** mesaj de eroare care indică fișierul lipsă, cod diferit de `0`.

## TP-08 — Mesajul de ajutor
 
**Pași:** rulez `./clonare.sh --help`

**Rezultat:** se afișează parametrii disponibili și exemplele; cod de ieșire `0`;
nicio conexiune, nicio modificare.

## TP-09 — Selectarea categoriilor

**Pași:** rulez `./clonare.sh --mod sursa --tinta <ip> --user rares --categorii pachete`

**Rezultat:** se procesează doar pachetele; utilizatorii, home-urile și cronjob-urile sunt
ignorate.

## TP-10 — Modul destinație | CF-01

**Pași:** rulez scriptul de pe mașina destinație, cu `--mod destinatie --tinta <ip_sursa>`

**Rezultat:** același rezultat final ca la rularea în modul sursă.

---

# 2. Teste pentru limite și erori

## TL-01 — Adresă IP inexistentă

**Pași:** rulez cu `--tinta 192.168.56.99` (nicio mașină acolo)

**Rezultat:** mesaj de eroare clar despre conexiunea eșuată, scriptul se oprește, nimic
modificat pe niciun sistem.

## TL-02 — SSH oprit pe destinație

**Pași:** `sudo systemctl stop ssh` pe destinație, apoi rulez scriptul

**Rezultat:** eroare de conexiune, oprire controlată, cod diferit de `0`.

## TL-03 — Cheie SSH lipsă

**Pași:** redenumesc temporar `~/.ssh/id_ed25519`, apoi rulez scriptul

**Rezultat:** scriptul nu se blochează cerând parolă interactiv; raportează eșecul
autentificării și se oprește.

## TL-04 — Lipsa privilegiilor

**Pași:** rulez scriptul fără `sudo`, cu clonarea utilizatorilor confirmată

**Rezultat:** mesaj care indică lipsa privilegiilor pentru citirea `/etc/shadow` sau pentru
`useradd`; nu se raportează succes fals.

## TL-05 — Conflict de UID

**Pași:** pe destinație creez un user oarecare cu UID 1001, iar pe sursă `user3` are tot
UID 1001. Rulez scriptul și confirm clonarea utilizatorilor.

**Rezultat:** `useradd -u 1001` eșuează; eroarea e raportată și scriptul continuă cu
restul, fără să se oprească brusc.

## TL-06 — Pachet indisponibil

**Pași:** pe sursă instalez un pachet dintr-un repository pe care destinația nu îl are.
Rulez scriptul și confirm clonarea pachetelor.

**Rezultat:** pachetul e raportat ca neinstalabil; restul pachetelor se instalează normal.

## TL-07 — Căi cu spații

**Pași:** creez pe sursă `/home/user3/Documente vechi/nota importanta.txt`, apoi clonez
home-ul lui `user3`

**Rezultat:** fișierul ajunge pe destinație cu numele intact, fără erori de parsare.

## TL-08 — Utilizator fără drept de ștergere

**Pași:** confirm ștergerea utilizatorilor prezenți doar pe destinație, într-un scenariu în
care userul conectat prin SSH nu există pe sursă

**Rezultat:** userul conectat **nu** e șters; e raportat ca protejat; conexiunea rămâne
activă.

## TL-09 — Cont de sistem în lista de șters

**Pași:** verific ce apare în lista „doar pe destinație" când destinația are conturi de
sistem pe care sursa nu le are

**Rezultat:** conturile cu UID < 1000 nu apar în listă și nu sunt propuse pentru ștergere.

## TL-10 — Lipsa unei comenzi externe

**Pași:** redenumesc temporar `rsync` pe destinație, apoi confirm clonarea home-urilor

**Rezultat:** mesaj care indică comanda indisponibilă, nu o eroare generică.

---

# 3. Teste funcționale

## TF-01 — Clonarea unui pachet lipsă

**Pași:**
1. Pe sursă: `sudo apt install -y htop`. Pe destinație verific că `htop` nu e instalat.
2. Rulez scriptul, confirm clonarea pachetelor.
3. Pe destinație: `which htop`

**Rezultat:** `htop` e instalat pe destinație.

## TF-02 — Pachet doar pe destinație nu se dezinstalează

**Pași:**
1. Pe destinație instalez `nano`; pe sursă nu e instalat.
2. Rulez scriptul și clonez tot.
3. Pe destinație: `which nano`

**Rezultat:** `nano` e raportat ca fiind doar pe destinație, dar rămâne instalat.

## TF-03 — Clonarea unui utilizator lipsă

**Pași:**
1. Pe sursă: `sudo useradd -m -u 1001 -s /bin/bash user3`
2. Rulez scriptul, confirm clonarea utilizatorilor.
3. Pe destinație: `id user3`

**Rezultat:** `user3` există pe destinație cu același UID (1001), același shell și
același home.

## TF-04 — Clonarea grupurilor secundare

**Pași:**
1. Pe sursă: `sudo usermod -aG sudo user3`
2. Rulez scriptul, confirm clonarea utilizatorilor.
3. Pe destinație: `groups user3`

**Rezultat:** `user3` apare în grupul `sudo` și pe destinație.

## TF-05 — Clonarea parolei

**Pași:**
1. Pe sursă setez o parolă cunoscută pentru `user3`.
2. Rulez scriptul, confirm clonarea utilizatorilor.
3. Pe destinație încerc autentificarea ca `user3` cu aceeași parolă.

**Rezultat:** autentificarea reușește — hash-ul a fost transferat corect.

## TF-06 — Utilizatorii comuni nu se modifică

**Pași:**
1. `user1` există pe ambele. Pe destinație îi modific shell-ul în `/bin/sh`.
2. Rulez scriptul și clonez tot.
3. Pe destinație: `getent passwd user1`

**Rezultat:** diferența de shell e raportată, dar `user1` rămâne cu `/bin/sh` — nu e
modificat.

## TF-07 — Ștergerea unui utilizator doar pe destinație

**Pași:**
1. Pe destinație: `sudo useradd -m user4`; pe sursă nu există.
2. Rulez scriptul, confirm ștergerea (`d`).
3. Pe destinație: `id user4`

**Rezultat:** `user4` nu mai există.

## TF-08 — Ștergere refuzată 

**Pași:** același scenariu ca TF-07, dar refuz ștergerea (`n`)

**Rezultat:** `user4` rămâne, cu home-ul și parola intacte.

## TF-09 — Clonarea home-directory-ului

**Pași:**
1. Pun fișiere în `/home/user3` pe sursă, cu permisiuni `644`.
2. Rulez scriptul, confirm clonarea utilizatorilor și a home-urilor.
3. Pe destinație: `ls -l /home/user3`

**Rezultat:** fișierele există, cu același conținut, permisiuni `644` și owner `user3`.

## TF-10 — Ordinea operațiilor

**Pași:** clonez într-o singură rulare atât `user3`, cât și home-ul lui

**Rezultat:** fișierele din home apar deținute de `user3`, nu de un UID numeric fără nume —
ceea ce confirmă că userul a fost creat înaintea transferului.

## TF-11 — Suprascrierea fișierelor diferite

**Pași:**
1. Directorul `/opt/test` există pe ambele; fișierul `conf.txt` are conținut diferit.
2. Rulez scriptul, confirm clonarea directoarelor specificate.
3. Pe destinație: `cat /opt/test/conf.txt`

**Rezultat:** fișierul de pe destinație a fost înlocuit cu versiunea de pe sursă.

## TF-12 — Clonarea unui cronjob

**Pași:**
1. Pe sursă adaug un cronjob pentru `user3`.
2. Rulez scriptul, confirm clonarea cronjob-urilor.
3. Pe destinație: `sudo crontab -l -u user3`

**Rezultat:** cronjob-ul apare pe destinație.

## TF-13 — Afișarea diferențelor înainte de orice modificare

**Pași:**
1. Pregătesc o stare cunoscută: sursa are în plus 1 pachet și 1 user; destinația are în
   plus 1 user.
2. Rulez scriptul și mă opresc la lista afișată, fără să confirm nimic.
3. Verific ambele sisteme.

**Rezultat:** lista afișată conține exact elementele pregătite, în cele trei categorii
(lipsă / doar pe destinație / comune); niciun sistem nu e modificat.

## TF-14 — Respectarea alegerii utilizatorului

**Pași:**
1. Rulez scriptul.
2. Confirm clonarea pachetelor, refuz clonarea utilizatorilor.
3. Verific destinația.

**Rezultat:** pachetele sunt instalate, utilizatorii nu sunt creați.

## TF-15 — Rularea repetată (idempotență)

**Pași:**
1. Rulez scriptul și clonez tot.
2. Rulez scriptul a doua oară, fără să schimb nimic între timp.

**Rezultat:** la a doua rulare nu se raportează diferențe de clonat; nu se execută nicio
modificare.

## TF-16 — Jurnalul

**Pași:**
1. Rulez o clonare completă.
2. Citesc fișierul de jurnal.
3. Caut hash-uri de parolă în jurnal: `grep '\$6\$' jurnal.log`

**Rezultat:** jurnalul conține acțiunile cu timestamp și nivel; căutarea de hash-uri nu
returnează nimic.
