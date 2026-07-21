# Setarea mediului de lucru pentru testarea aplicației

**Student:** Vlădescu Rareș
**Proiect:** Clonare sistem Linux
**Repository:** https://github.com/R-V12/Clonare-sistem-Linux

Acest document descrie, pas cu pas, cum se pregătește mediul necesar rulării și testării
aplicației de clonare, pornind de la zero. Urmând acești pași, oricine poate reconstrui un
mediu identic și verifica funcționarea programului într-un cadru controlat, înainte de a-l
folosi pe sisteme reale.

Aplicația modifică utilizatori, pachete și fișiere pe sistemul destinație. Din acest motiv,
testarea se face pe două mașini virtuale dedicate, nu pe sisteme de producție.

---

## 1. Instalarea VirtualBox și a primei mașini

### 1.1 VirtualBox

Se instalează Oracle VirtualBox pe calculatorul gazdă (Windows sau Linux).

> **[SCREENSHOT]** Fereastra principală VirtualBox Manager, goală sau cu mașinile existente.

### 1.2 Prima mașină virtuală (sursă)

Se creează o mașină virtuală cu Linux Mint:
- minimum 2 GB memorie (RAM);
- minimum 25 GB spațiu de disc;
- se instalează Linux Mint din imaginea ISO.

> **[SCREENSHOT]** Fereastra „Create Virtual Machine" cu numele, tipul (Linux) și versiunea
> (Ubuntu 64-bit) completate.

> **[SCREENSHOT]** Desktopul Linux Mint pornit, care confirmă instalarea reușită a primei
> mașini.

---

## 2. Clonarea celei de-a doua mașini (destinație)

A doua mașină se obține prin clonarea primei, ca ambele să fie identice ca bază.

### 2.1 Oprirea primei mașini

Se oprește complet mașina sursă (Shut Down din interiorul sistemului, sau Power Off).

> **[SCREENSHOT]** Lista VirtualBox cu mașina sursă marcată „Powered Off".

### 2.2 Clonarea

Click dreapta pe mașina sursă → **Clone**.

> **[SCREENSHOT]** Meniul care apare la click dreapta pe mașină, cu opțiunea **Clone**
> evidențiată.

În fereastra de clonare:
- **Name:** `LinuxMint-Destinatie`;
- **MAC Address Policy:** `Generate new MAC addresses for all network adapters`
  (obligatoriu, altfel ambele mașini au aceeași adresă și nu comunică);
- tip: **Full clone**.

> **[SCREENSHOT]** Fereastra de clonare cu numele completat și politica MAC selectată pe
> „Generate new MAC addresses for all network adapters".

> **[SCREENSHOT]** Lista VirtualBox cu ambele mașini: `LinuxMint` și `LinuxMint-Destinatie`.

### 2.3 Diferențierea mașinilor

Fiind o clonă, a doua mașină are același nume de gazdă. Pe destinație se schimbă:

```bash
sudo hostnamectl set-hostname destinatie
```

După deschiderea unui terminal nou, promptul devine `vladescu@destinatie`.

> **[SCREENSHOT]** Terminalul pe destinație, cu promptul `vladescu@destinatie` vizibil după
> schimbarea numelui.

---

## 3. Configurarea rețelei dintre mașini

Implicit, mașinile folosesc NAT, prin care nu se văd una pe alta. Se adaugă un al doilea
adaptor de rețea, de tip Host-Only, pe **fiecare** mașină.

### 3.1 Adăugarea adaptorului Host-Only

Pentru fiecare mașină: **Settings** → **Network** → tab **Adapter 2**:
- se bifează **Enable Network Adapter**;
- **Attached to:** `Host-only Adapter`;
- **Name:** `VirtualBox Host-Only Ethernet Adapter`.

> **[SCREENSHOT]** Fereastra Settings → Network → Adapter 2, cu „Enable Network Adapter"
> bifat și „Host-only Adapter" selectat. (Câte una pentru fiecare mașină, sau una
> reprezentativă.)

Adaptorul 1 (NAT) rămâne, pentru accesul la internet necesar instalării pachetelor.

### 3.2 Verificarea adreselor

Pe fiecare mașină:

```bash
ip a
```

Se caută interfața `enp0s8` cu adresă de forma `192.168.56.x`. În configurația de
referință:
- sursă: `192.168.56.101`;
- destinație: `192.168.56.102`.

> **[SCREENSHOT]** Terminalul cu rezultatul `ip a` pe sursă, cu adresa `192.168.56.101`
> evidențiată pe `enp0s8`.

> **[SCREENSHOT]** Terminalul cu rezultatul `ip a` pe destinație, cu adresa `192.168.56.102`
> evidențiată pe `enp0s8`.

### 3.3 Verificarea conectivității

De pe sursă:

```bash
ping -c 3 192.168.56.102
```

Un răspuns cu `0% packet loss` confirmă că mașinile se văd în rețea.

> **[SCREENSHOT]** Terminalul cu rezultatul comenzii `ping`, arătând `0% packet loss`.

---

## 4. Instalarea utilitarelor

Pe **ambele** mașini:

```bash
sudo apt update
sudo apt install -y git openssh-server openssh-client rsync
```

- `openssh-server` — permite mașinii să primească conexiuni SSH;
- `openssh-client` — permite mașinii să inițieze conexiuni SSH;
- `rsync` — copierea fișierelor cu păstrarea permisiunilor;
- `git` — obținerea codului din repository.

> **[SCREENSHOT]** Terminalul la finalul instalării, arătând că pachetele au fost instalate.

Verificarea că serverul SSH ascultă, pe destinație:

```bash
sudo systemctl status ssh.socket
```

Trebuie să apară `active (listening)`.

> **[SCREENSHOT]** Terminalul cu `active (listening)` evidențiat în rezultatul comenzii.

---

## 5. Conexiunea SSH pe bază de chei

Aplicația se conectează automat între mașini, fără parolă. Se configurează chei SSH în
ambele direcții, deoarece aplicația poate rula de pe oricare mașină.

### 5.1 Sursă către destinație

Pe sursă:

```bash
ssh-keygen -t ed25519
ssh-copy-id vladescu@192.168.56.102
```

La `ssh-keygen` se apasă Enter la toate întrebările (fără parolă pe cheie). `ssh-copy-id`
cere parola o singură dată.

> **[SCREENSHOT]** Terminalul cu mesajul „Number of key(s) added: 1" după `ssh-copy-id`.

### 5.2 Destinație către sursă

Pe destinație:

```bash
ssh-keygen -t ed25519
ssh-copy-id vladescu@192.168.56.101
```

### 5.3 Verificarea

De pe sursă:

```bash
ssh vladescu@192.168.56.102 "hostname"
```

Trebuie să afișeze `destinatie` **fără a cere parola**.

> **[SCREENSHOT]** Terminalul care afișează `destinatie` ca răspuns, fără a fi cerut o
> parolă.

---

## 6. Configurarea sudo fără parolă

Aplicația rulează comenzi privilegiate pe mașina remote prin SSH. O comandă `sudo` rulată
astfel nu poate citi o parolă de la tastatură, deci contul trebuie să poată executa `sudo`
fără parolă. Pe **ambele** mașini:

```bash
echo "vladescu ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/clonare
sudo chmod 440 /etc/sudoers.d/clonare
```

Verificare:

```bash
sudo -n true && echo "sudo fara parola OK"
```

> **[SCREENSHOT]** Terminalul care afișează „sudo fara parola OK".

---

## 7. Obținerea programului

Pe mașina de pe care se rulează (sursa):

```bash
cd ~/Desktop
git clone https://github.com/R-V12/Clonare-sistem-Linux.git
cd Clonare-sistem-Linux
chmod +x scripts/clonare.sh
```

`chmod +x` marchează scriptul principal ca executabil.

> **[SCREENSHOT]** Terminalul cu structura proiectului după clonare (`ls scripts scripts/lib
> config`), arătând `clonare.sh` și fișierele din `lib/`.

---

## 8. Verificarea finală a mediului

Aceste comenzi nu modifică niciun sistem; confirmă doar că totul e pregătit.

```bash
git --version
rsync --version
ssh vladescu@192.168.56.102 "hostname"
./scripts/clonare.sh --help
```

Rularea în regim de colectare, care citește starea ambelor mașini fără să modifice nimic:

```bash
./scripts/clonare.sh --mod sursa --tinta 192.168.56.102 --user vladescu
```

Aplicația se conectează, afișează diferențele dintre cele două sisteme și cere confirmarea.
Dacă la acest punct se răspunde cu `n`, niciun sistem nu este modificat. Dacă acest pas
reușește, mediul este pregătit complet.

> **[SCREENSHOT]** Terminalul cu rularea scriptului până la afișarea diferențelor și
> întrebarea „Aplic clonarea? [d/n]".

---

## 9. Măsuri de siguranță la testare

- Se face un **snapshot** al mașinii destinație înainte de fiecare test, pentru a putea
  reveni la starea inițială: VirtualBox → mașina destinație → tab **Snapshots** → **Take**.
- Aplicația afișează toate modificările și cere confirmare înainte de a le aplica; la refuz,
  niciun sistem nu este modificat.
- La închiderea mașinilor se folosește **Power Off**, nu Save State, deoarece Save State
  poate bloca reinițializarea corectă a rețelei și a clipboard-ului la repornire.

> **[SCREENSHOT]** Fereastra Snapshots a mașinii destinație, cu un snapshot creat înainte de
> testare.
