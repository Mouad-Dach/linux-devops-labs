# Lab 07 - Logs et diagnostic avec journalctl

## Objectif / Objective
FR: Lire et filtrer les logs avec journalctl, comprendre les niveaux de gravite, et appliquer une methode de reduction pour ne pas se perdre dans un journal charge.
EN: Read and filter logs with journalctl, understand severity levels, and apply a reduction method so as not to get lost in a large journal.

## Environnement / Environment
- VM1: ubuntu-server-1, VM2: ubuntu-server-2 (ufw actif)
- Messages de test crees avec logger

## Niveaux de gravite / Severity levels

    0 emerg | 1 alert | 2 crit | 3 err | 4 warning | 5 notice | 6 info | 7 debug

Regle : plus le chiffre est petit, plus c'est grave.
-p niveau garde ce niveau ET tous les niveaux plus graves.
- -p err garde 0 a 3 : un warning (4) est exclu
- -p warning garde 0 a 4 : il contient donc aussi les err
Mesure : -p warning = 38 lignes, -p err = 4 lignes sur la meme heure. La difference, ce sont les warnings.

## Commandes utilisees / Commands used

    journalctl -k --no-pager | grep "UFW BLOCK" | tail -n 3
    journalctl -p err --since "10 minutes ago" --no-pager
    journalctl -p err --since "10 minutes ago" -u ssh --no-pager
    journalctl -t webapp --since "10 minutes ago" --no-pager | wc -l
    journalctl -p warning -n 3 -o verbose --no-pager | grep -E "PRIORITY|MESSAGE"
    journalctl -f -u myservice
    logger -t webapp -p user.err "message de test"

- -k : kernel, messages du noyau (c'est lui qui applique le firewall)
- -p : priority, filtre par gravite
- --since : depuis quand ("1 hour ago", "14:00")
- -u : unit, un service systemd
- -t : tag, le nom de celui qui ecrit (utile pour logger)
- -n : nombre de dernieres lignes
- -f : follow, affiche les nouvelles lignes en direct (Ctrl+C pour quitter)
- -o verbose : tous les champs, dont PRIORITY
- logger : ecrit une ligne dans le journal pour tester

## Lire une ligne de log

    Oct 25 14:06:08  ubuntu-server-1  systemd[1]:  fwupd-refresh.service: Failed...
    QUAND            MACHINE          QUI          MESSAGE

Regarder d'abord QUI et MESSAGE. Le niveau exact se lit avec -o verbose (PRIORITY=).

## Trace d'un blocage ufw
Une ligne UFW BLOCK contient SRC (source), DST (destination), DPT (port de destination), SYN (demande d'ouverture TCP).
- Le paquet est arrive sur la machine (IN=enp0s8) : le reseau fonctionne
- ufw l'a jete : aucune regle n'autorise le port, la politique par defaut deny s'applique
- Trois lignes a 1 seconde d'ecart : le client renvoie son SYN, c'est la mecanique du timeout

## Methode de reduction / Reduction method

1. Compter : ... | wc -l
2. Gravite : -p err
3. Periode : --since
4. Service : -u ou -t
5. Lire seulement ce qui reste
6. Chercher la PREMIERE erreur de la sequence, pas la derniere

Piege : un filtre par service peut cacher un probleme plus grave ailleurs. Dans mon test, -t webapp n'a pas montre une ligne crit (PRIORITY=2) du tag backup. Ordre le plus sur : gravite d'abord, service ensuite.

## Ticket #1003 - webapp (journal charge)
- 40 lignes webapp, 2 apres -p err, 10 avec -p warning (2 err + 8 warning)
- refused : service absent ou arrete
- No such file or directory : chemin ou fichier absent
- La ligne backup : disk quota exceeded, niveau crit, cachee par -t webapp

## Chasse aux mots-cles avec grep

    journalctl --since "30 minutes ago" --no-pager | grep -iE "denied|failed|refused|No such file"
    ... | grep -vE "kernel|fwupd|grub|update-notifier"

- -i ignore la casse, -E permet le "ou" avec |, -v exclut les lignes
- 1425 lignes -> 23 avec grep -> 7 apres exclusion du bruit

| Mot-cle | Type de probleme |
|---|---|
| denied | droits ou securite |
| refused | service absent ou arrete |
| No such file | chemin faux ou fichier absent |
| failed | un echec, a regarder de plus pres |
| UFW BLOCK | le firewall a jete un paquet |

Piege : grep trouve des mots, pas des problemes. Une ligne "failed at package install time" etait dans le nom d'un service qui affichait Finished. Verifier Started / Finished.

## Tri des lignes en groupes
- Mon test : vrais problemes
- Bruit connu : vmwgfx, workqueue, fwupd (lecteur CD vide)
- A surveiller : watchdog sur logind, resolved, networkd. Verifier avec systemctl is-active : tous active, donc revenus

## Ticket #1004 - myservice ne demarre plus
FR: Le fichier run.sh a ete renomme en run.sh.bak. Le chemin de ExecStart etait bon, mais le fichier n'existait plus a cet endroit.

    sudo mv /opt/myservice/run.sh /opt/myservice/run.sh.bak && sudo systemctl restart myservice
    journalctl -f -u myservice

Observations :
- Unable to locate executable ... No such file or directory
- status=203/EXEC
- restart counter, Start request repeated too quickly : consequences, pas la cause

Fix :

    sudo mv /opt/myservice/run.sh.bak /opt/myservice/run.sh
    sudo systemctl restart myservice
    systemctl status myservice --no-pager
    ls -l /opt/myservice/

Validation : active (running), run.sh avec son x.

## Mindset pour lire les logs (a reecrire avec mes mots)
1. Un log est un temoin, pas un examen
2. Je ne lis pas, je cherche
3. Je n'ai pas besoin de comprendre chaque mot
4. La plupart des lignes sont du bruit, et c'est normal
5. Je remonte a la premiere erreur, pas a la derniere
6. Les logs deviennent normaux par la repetition courte

Phrase pour me recentrer : "Je ne dois pas tout comprendre. Je dois trouver la ligne qui compte."

## Ce que j'ai appris / What I learned
FR: Face a un journal charge, je compte, je filtre par gravite puis par service, et je remonte a la premiere erreur. Un filtre sans resultat est une information. grep trouve des mots, pas des problemes : je verifie le contexte.

EN: Facing a large journal, I count, filter by severity then by service, and go back to the first error. An empty result is information. grep finds words, not problems: I check the context.
