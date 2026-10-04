# Lab 03 - Processus et service systemd

## Objectif / Objective
FR: Creer un faux service (script bash en boucle), le gerer avec une unit file systemd, diagnostiquer un echec au demarrage et comprendre le comportement de Restart= selon les signaux.
EN: Create a fake service (looping bash script), manage it with a systemd unit file, diagnose a startup failure and understand how Restart= behaves depending on signals.

## Environnement / Environment
- VM: ubuntu-server-1 (192.168.171.10)
- Script: /opt/myservice/run.sh
- Unit file: /etc/systemd/system/myservice.service
- Fichiers de reference dans ce dossier: run.sh et myservice.service

## Commandes utilisees / Commands used

    sudo mkdir -p /opt/myservice
    sudo chmod +x /opt/myservice/run.sh
    sudo systemctl daemon-reload
    sudo systemctl enable --now myservice
    systemctl status myservice --no-pager
    journalctl -u myservice -f

- daemon-reload : systemd relit les unit files (obligatoire apres toute modification)
- enable : demarrage automatique au boot ; --now : demarre aussi immediatement
- journalctl -u : filtre sur une unit ; -f : follow, affichage en direct
- --no-pager : affiche tout sans passer par less

## Incident 1 - Service qui ne demarre pas (203/EXEC)

FR: Le fichier run.sh n'avait pas le droit d'execution.

    sudo chmod -x /opt/myservice/run.sh
    sudo systemctl restart myservice
    journalctl -u myservice --no-pager | grep -E "203|Permission denied"

Logs observes :
- Unable to locate executable '/opt/myservice/run.sh': Permission denied
- Failed at step EXEC spawning /opt/myservice/run.sh
- Main process exited, code=exited, status=203/EXEC
- Start request repeated too quickly (apres 5 redemarrages rapproches)

Diagnostic : ls -l montre -rw-r--r-- (pas de x).

Fix :

    sudo chmod +x /opt/myservice/run.sh
    sudo systemctl start myservice

Si start est refuse a cause de la limite de redemarrages : sudo systemctl reset-failed myservice

Lecon : quand un service boucle, les dernieres lignes de journalctl sont du bruit (compteur de restarts). La cause est au debut de la sequence. systemctl status affiche directement le code 203/EXEC.

## Signification de 203/EXEC
EXEC = etape ou systemd lance le programme. 203 = impossible de l'executer. Causes possibles : droit x manquant, chemin faux dans ExecStart, shebang absent. Premier reflexe : ls -l sur le fichier.

## Restart= et signaux

| Restart=   | kill -9 (SIGKILL) | kill -15 (SIGTERM) | systemctl stop |
|------------|-------------------|--------------------|----------------|
| no         | mort              | mort               | arrete         |
| on-failure | relance           | mort               | arrete         |
| always     | relance           | relance            | arrete         |

FR: Restart= ne s'applique que si systemd n'a pas demande l'arret. systemctl stop vient de systemd donc pas de relance. kill vient de l'exterieur donc systemd le traite comme un incident.

Pour arreter definitivement un service en Restart=always : systemctl stop (immediat), systemctl disable (plus de demarrage au boot), systemctl mask (interdit tout demarrage).

## Modifier une unit file

    sudo nano /etc/systemd/system/myservice.service
    sudo systemctl daemon-reload
    sudo systemctl restart myservice

Sans daemon-reload, systemd garde l'ancienne version en memoire.

## systemd vs systemctl
systemd = le demon (PID 1) qui gere les services. systemctl = l'outil de controle pour le piloter.

## Ce que j'ai appris / What I learned
FR: Un code 203/EXEC pointe vers un probleme d'execution (permissions, chemin, shebang). Le comportement de Restart= depend de qui a decide l'arret. Apres modification d'une unit file, daemon-reload est obligatoire.

EN: A 203/EXEC code points to an execution problem (permissions, path, shebang). Restart= behavior depends on who decided the stop. After editing a unit file, daemon-reload is mandatory.
