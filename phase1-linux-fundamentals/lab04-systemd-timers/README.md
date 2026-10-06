# Lab 04 - Systemd timers

## Objectif / Objective
FR: Planifier une tache avec un timer systemd (paire .timer + .service), diagnostiquer un service declenche par un timer qui echoue, et comparer avec cron.
EN: Schedule a task with a systemd timer (.timer + .service pair), diagnose a timer-triggered service that fails, and compare with cron.

## Fichiers / Files
- heartbeat.service : ce qu'on execute (Type=oneshot, une fois puis fin)
- heartbeat.timer : quand on l'execute (OnCalendar chaque minute, Persistent=true)

## Commandes utilisees / Commands used

    sudo systemctl daemon-reload
    sudo systemctl enable --now heartbeat.timer
    systemctl list-timers --no-pager
    tail -n 5 /var/log/heartbeat.log

- On active le .timer, pas le .service
- Type=oneshot : le processus s'execute une fois et se termine
- OnCalendar=*-*-* *:*:00 : annee-mois-jour heure:minute:seconde, * = tous
- Persistent=true : rattrape l'execution manquee si la machine etait eteinte
- AccuracySec (1min par defaut) : explique pourquoi les secondes varient dans le log

## Incident - Service du timer en echec

FR: ExecStart modifie vers un chemin inexistant (/opt/heartbeat/inexistant.sh).

    sudo systemctl daemon-reload
    systemctl list-timers --no-pager
    systemctl status heartbeat.service --no-pager
    journalctl -u heartbeat.service -n 20 --no-pager

Observations :
- Code 203/EXEC avec No such file or directory
- Le timer reste actif et continue de se declencher : seul le service est casse
- Pas de Restart= donc pas de boucle de redemarrages, un echec par minute
- heartbeat.log s'arrete : trou de 16 minutes entre 14:02 et 14:18

Fix : remettre le bon ExecStart, puis sudo systemctl daemon-reload. Les lignes reviennent dans le log.

Piege : list-timers affiche LAST meme si le service a echoue. Un timer actif ne prouve pas que la tache reussit : verifier le service et le log.

## Timer vs cron

| | cron | systemd timer |
|---|---|---|
| Fichiers | 1 ligne dans la crontab | .timer + .service |
| Logs | pas de journal integre | journalctl -u |
| Machine eteinte | tache ratee | Persistent=true rattrape |
| Visibilite | limitee | list-timers, status |
| Dependances | aucune | After=, Requires= |
| Disponibilite | presque partout | uniquement sous systemd |

## Ce que j'ai appris / What I learned
FR: Timer et service sont deux unites independantes. Un timer actif ne garantit pas que la tache s'execute. Le trou dans le log est la preuve d'une tache qui n'a pas tourne.

EN: Timer and service are independent units. An active timer does not guarantee the task runs. A gap in the log is the proof of a missed task.
