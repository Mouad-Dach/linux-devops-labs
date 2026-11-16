# Lab 08 - auth.log, SSH, logrotate et reprise apres gel

## Objectif / Objective
FR: Lire les traces d'authentification (sudo, SSH) dans auth.log, comprendre logrotate, et diagnostiquer un gel de VM avec journalctl.
EN: Read authentication traces (sudo, SSH) in auth.log, understand logrotate, and diagnose a VM freeze with journalctl.

## Environnement / Environment
- VM1: ubuntu-server-1 (192.168.171.10)
- PC hote vu par la VM : 192.168.171.1

## 1. Echec sudo dans auth.log

    sudo grep -i "sudo" /var/log/auth.log | grep -iE "incorrect|failure" | tail -n 5

Resultat observe : une ligne pam_unix(sudo:auth): authentication failure ... user=madmin (mot de passe rate apres une nuit).
- authentication failure = le mot de passe est faux (different de "denied", qui concerne un droit refuse)
- Lire : QUI (user=), QUAND, COMBIEN de fois
- Une ligne, mon compte, une heure coherente : normal

## 2. Connexions SSH dans auth.log

    sudo grep "sshd" /var/log/auth.log | grep -E "Accepted|Failed|Invalid" | tail -n 5

- Accepted password for madmin from 192.168.171.1 : connexions depuis mon PC (deux lignes a la meme seconde : MobaXterm ouvre le terminal et le SFTP)
- Lecture en 4 morceaux : QUAND / QUI / D'OU / RESULTAT

### Echec provoque
    ssh fauxuser@192.168.171.10

    Invalid user fauxuser from 192.168.171.10
    Failed password for invalid user fauxuser from 192.168.171.10 (x2)

- Invalid user = le compte n'existe pas sur la machine
- Failed password for <compte existant> = le compte existe, le mot de passe est faux
- La source etait 192.168.171.10 (VM1 elle-meme) car j'ai lance le ssh depuis la VM : le champ "from" indique d'ou vient la connexion
- Rien n'est bloque : sshd refuse les essais, mais la source peut recommencer. Seul un outil comme fail2ban bannit une source apres plusieurs echecs (a faire en Phase 2)

Signaux suspects : Failed password en rafale depuis une source inconnue, Invalid user, connexion Accepted a une heure inhabituelle.

## 3. Tri d'un journal : le cas chronyd

    journalctl -p err --since "1 hour ago" --no-pager | wc -l

- 16 lignes dont 1 separateur "-- Boot --" : 15 vraies lignes
- Bruit connu : vmwgfx (graphique VirtualBox), sshd mm_reap signal 15 (arret des sessions), systemd-tmpfiles
- Nouveau et repete : chronyd "NTS-KE session ... timed out" toutes les 4-5 minutes

Verification de l'impact :

    timedatectl | grep -i synchronized     # System clock synchronized: yes
    ping -c 2 8.8.8.8                      # 0% de perte

Verdict : pas d'impact (horloge synchronisee, Internet OK). Bruit probable lie au reseau, a surveiller.
Regle : une ligne nouvelle ou repetee, je ne l'ignore pas, je mesure l'impact avec une commande, puis je decide.

## 4. logrotate

Probleme : un log qui grossit sans limite finit par remplir le disque.

    systemctl list-timers --no-pager | grep logrotate
    cat /etc/logrotate.conf | grep -v "^#" | grep -v "^$"
    ls /etc/logrotate.d/
    sudo logrotate -d /etc/logrotate.conf 2>&1 | head -n 20

- logrotate est lance chaque jour par un timer systemd
- Une regle par application dans /etc/logrotate.d/ (observe : rsyslog, ufw, apt, chrony, dpkg, cloud-init-base...)
- rotate 4 : garde 4 anciens fichiers archives, supprime les plus vieux
- compress, missingok, notifempty : archives compressees, pas d'erreur si absent, pas de rotation si vide
- -d : simulation, n'applique RIEN (message : "logrotate in debug mode does nothing except printing debug messages"). A utiliser apres avoir ecrit ou modifie une regle

A completer : contenu de /etc/logrotate.d/rsyslog et liste de /var/log/auth.log* (pas encore releves).

## 5. Incident - VM figee (Network error: Connection timed out)

Reaction : ACPI Shutdown sans effet, puis Power Off, puis demarrage.
Verification apres redemarrage :

    systemctl is-active myservice      # active (enabled, reparti au boot)
    systemctl --failed                 # 0 loaded units listed
    journalctl -b -1 -p err --no-pager | tail -n 10
    journalctl -b -1 -n 15 --no-pager

Observations :
- Aucune erreur err liee au gel (seulement vmwgfx au demarrage)
- Le journal du boot precedent s'arrete a 14:05:42 (sudo logrotate -d, session fermee proprement), alors que la connexion a expire vers 14:13 : les dernieres lignes ont pu etre perdues a l'arret brutal
- Beaucoup de "hogged CPU for >10000us" (e1000_watchdog, drm_fb_helper, ata_sff_pio_task) : piste de manque de ressources, non prouvee
- Compteur compare : 42 lignes (boot precedent, ~20 min) contre 10 (boot actuel, ~5 min), soit environ 2 par minute dans les deux cas. Ces messages sont donc presents de facon reguliere sur cette VM : ils ne suffisent pas a expliquer le gel

Cause du gel : non determinee.
Lecon : apres un plantage, lire les dernieres lignes avant l'arret. Avant de comparer deux compteurs, verifier qu'ils couvrent la meme duree.

## Ce que j'ai appris / What I learned
FR: auth.log se lit en 4 morceaux (quand, qui, d'ou, resultat). Invalid user et Failed password n'ont pas le meme sens. Une ligne nouvelle ou repetee se verifie par son impact avant d'etre classee. logrotate evite qu'un log remplisse le disque, et -d permet de le tester sans risque.

EN: auth.log is read in four parts (when, who, from where, result). Invalid user and Failed password mean different things. A new or repeated line is checked by its impact before being classified. logrotate prevents a log from filling the disk, and -d tests it safely.
