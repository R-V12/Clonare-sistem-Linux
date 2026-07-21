# Document de testare — Clonare sistem Linux

**Student:** Vlădescu Rareș
**Repository:** https://github.com/R-V12/Clonare-sistem-Linux

---

## 1. Ce face programul (pe scurt)

Programul este un set de scripturi Bash care copiază starea unui sistem Linux (**sursă**)
pe alt sistem Linux (**destinație**). Compară cele două sisteme, afișează diferențele și
întreabă utilizatorul ce dorește să cloneze. Se pot clona: pachete instalate, utilizatori,
home-directory-uri și cronjob-uri. Transferul se face prin SSH și rsync. Ce există deja pe
destinație nu se suprascrie.

## 2. Mediul de testare

Testele se fac pe două mașini virtuale Linux Mint, numite **sursă** și **destinație**,
conectate în rețea (Host-Only), cu SSH configurat pe bază de chei între ele.

Înainte de teste se verifică:

```bash
ssh user@ip_destinatie "hostname"    # trebuie să răspundă fără parolă
```

## 3. Cum sunt scrise testele

Fiecare test are: **ce verifică**, **pașii** de urmat și **rezultatul așteptat**.
Testele sunt împărțite în două: teste pe componente (bucăți din script, luate separat) și
teste pe funcționalități (programul întreg, între cele două mașini).

---

# 4. Teste pe componente

## T1 — Colectarea listei de pachete

**Ce verifică:** că scriptul poate obține lista pachetelor instalate.

**Pași:**
1. Pe sursă instalez un pachet: `sudo apt install -y cowsay`
2. Rulez funcția/scriptul de colectare a pachetelor
3. Caut `cowsay` în lista rezultată

**Rezultat așteptat:** `cowsay` apare în listă.

---

## T2 — Colectarea listei de utilizatori

**Ce verifică:** că scriptul obține utilizatorii reali, nu conturile de sistem.

**Pași:**
1. Creez un user de test: `sudo useradd -m testuser`
2. Rulez funcția de colectare a utilizatorilor
3. Verific lista
4. Șterg userul: `sudo userdel -r testuser`

**Rezultat așteptat:** `testuser` apare în listă, iar `root` și `daemon` nu apar.

---

## T3 — Colectarea cronjob-urilor

**Ce verifică:** că scriptul citește corect cronjob-urile unui utilizator.

**Pași:**
1. Adaug un cronjob de test: `(crontab -l; echo "* * * * * echo test") | crontab -`
2. Rulez funcția de colectare a cronjob-urilor
3. Curăț: `crontab -r`

**Rezultat așteptat:** linia adăugată apare în rezultat.

---

## T4 — Conexiunea SSH

**Ce verifică:** că scriptul se conectează la cealaltă mașină fără parolă.

**Pași:**
1. Rulez prin script comanda `hostname` pe destinație

**Rezultat așteptat:** scriptul afișează hostname-ul destinației, fără să ceară parolă.

---

## T5 — Calculul diferențelor

**Ce verifică:** că scriptul găsește corect ce e pe sursă dar lipsește pe destinație.

**Pași:**
1. Creez două liste de test: sursă = `A, B, C` și destinație = `A, C`
2. Rulez funcția de comparare

**Rezultat așteptat:** rezultatul este `B` (singurul element lipsă pe destinație).

---

## T6 — Compararea fișierelor

**Ce verifică:** că scriptul detectează dacă două fișiere diferă.

**Pași:**
1. Creez un fișier și o copie identică → compar
2. Modific copia → compar din nou

**Rezultat așteptat:** prima comparație spune „identice", a doua spune „diferite".

---

## T7 — Transferul unui director

**Ce verifică:** că fișierele ajung pe destinație cu permisiunile păstrate.

**Pași:**
1. Creez pe sursă un director cu un fișier cu permisiuni `644`
2. Transfer directorul prin funcția de copiere (rsync peste SSH)
3. Pe destinație rulez `ls -l` pe fișier

**Rezultat așteptat:** fișierul există pe destinație și are tot permisiunile `644`.

---

## T8 — Crearea unui utilizator

**Ce verifică:** că scriptul creează corect un user pe destinație.

**Pași:**
1. Rulez funcția de creare pentru un user care nu există pe destinație
2. Pe destinație verific: `id nume_user`

**Rezultat așteptat:** userul există, cu home-directory și shell corecte.

---

# 5. Teste pe funcționalități

## T9 — Clonarea unui pachet lipsă

**Ce verifică:** că programul instalează pe destinație un pachet care lipsește.

**Pași:**
1. Pe sursă instalez `htop`, pe destinație mă asigur că nu e instalat
2. Rulez scriptul
3. Confirm clonarea pachetelor când mă întreabă
4. Pe destinație verific: `which htop`

**Rezultat așteptat:** `htop` este instalat pe destinație.

---

## T10 — Clonarea unui utilizator lipsă

**Ce verifică:** că programul creează pe destinație un user care lipsește.

**Pași:**
1. Pe sursă creez `user3`, care nu există pe destinație
2. Rulez scriptul și confirm clonarea utilizatorilor
3. Pe destinație verific: `id user3`

**Rezultat așteptat:** `user3` există pe destinație.

---

## T11 — Clonarea home-directory-ului

**Ce verifică:** că fișierele din home ajung pe destinație.

**Pași:**
1. Pun câteva fișiere în home-ul unui user de pe sursă
2. Rulez scriptul și confirm clonarea home-dir-urilor
3. Pe destinație verific conținutul home-ului

**Rezultat așteptat:** fișierele apar pe destinație, cu același conținut și permisiuni.

---

## T12 — Clonarea unui cronjob

**Ce verifică:** că cronjob-urile ajung pe destinație.

**Pași:**
1. Adaug un cronjob pe sursă
2. Rulez scriptul și confirm clonarea cronjob-urilor
3. Pe destinație verific: `crontab -l`

**Rezultat așteptat:** cronjob-ul apare pe destinație.

---

## T13 — Afișarea diferențelor

**Ce verifică:** că programul afișează corect ce lipsește, înainte de a face ceva.

**Pași:**
1. Pregătesc o situație cunoscută: sursa are în plus 1 pachet și 1 user
2. Rulez scriptul și mă uit la lista de diferențe afișată

**Rezultat așteptat:** lista afișată conține exact acel pachet și acel user, iar până la
confirmare nu se modifică nimic pe destinație.

---

## T14 — Utilizator prezent doar pe destinație

**Ce verifică:** ce face programul cu un user care există pe destinație dar nu pe sursă.

**Pași:**
1. Pe destinație creez `user4`, care nu există pe sursă
2. Rulez scriptul
3. După rulare verific pe destinație: `id user4`

**Rezultat așteptat:** programul raportează că `user4` există doar pe destinație și **nu îl
șterge**. Ștergerea se face doar dacă utilizatorul o cere explicit.

---

## T15 — Respectarea alegerii utilizatorului

**Ce verifică:** că programul face doar ce a confirmat utilizatorul.

**Pași:**
1. Rulez scriptul
2. La întrebări: confirm clonarea pachetelor, refuz clonarea utilizatorilor
3. Verific pe destinație

**Rezultat așteptat:** pachetele sunt instalate, userii nu sunt creați.

---

## T16 — Rularea de două ori

**Ce verifică:** că a doua rulare nu strică nimic și nu clonează din nou.

**Pași:**
1. Rulez scriptul și clonez tot
2. Rulez scriptul a doua oară, fără să schimb nimic între timp

**Rezultat așteptat:** la a doua rulare nu apar diferențe de clonat; elementele existente
sunt raportate ca fiind deja prezente.

---

## T17 — Eroare de conexiune

**Ce verifică:** că programul se oprește corect când nu poate ajunge la cealaltă mașină.

**Pași:**
1. Rulez scriptul cu o adresă IP greșită

**Rezultat așteptat:** apare un mesaj de eroare clar și scriptul se oprește, fără să
modifice ceva.
