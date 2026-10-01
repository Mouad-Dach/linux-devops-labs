# Lab 01 — Permissions (chmod, chown, SGID)

## Objectif / Objective
FR: Creer une arborescence simulant une application web avec des permissions differenciees selon le role de chaque dossier (config, logs, data), gerees par un compte de service dedie.
EN: Create a directory tree simulating a web application with differentiated permissions per folder role (config, logs, data), managed through a dedicated service account.

## Environnement / Environment
- VM: ubuntu-server-1 (192.168.171.10)
- Structure: /opt/webapp/{config,logs,data}
- Service account: webapp-svc (compte systeme, sans login interactif)

## Commandes utilisees / Commands used

### Creation de la structure et du compte de service
    sudo mkdir -p /opt/webapp/{config,logs,data}
    sudo useradd -r -s /usr/sbin/nologin webapp-svc

### Attribution des permissions par dossier
    sudo chown root:webapp-svc /opt/webapp/config
    sudo chmod 750 /opt/webapp/config

    sudo chown webapp-svc:webapp-svc /opt/webapp/logs
    sudo chmod 770 /opt/webapp/logs

    sudo chown webapp-svc:webapp-svc /opt/webapp/data
    sudo chmod 750 /opt/webapp/data

## Tableau des permissions

| Dossier | Owner:Group        | Permissions | Pourquoi |
|---------|--------------------|-----------|---------------------------------------------------|
| config  | root:webapp-svc    | 750 (rwxr-x---) | Le service peut lire sa config via le groupe, mais ne peut pas la modifier - limite l'impact d'une faille |
| logs    | webapp-svc:webapp-svc | 770 (rwxrwx---) | Le service doit pouvoir ecrire ses logs librement |
| data    | webapp-svc:webapp-svc | 750 (rwxr-x---) | Lecture/ecriture pour le proprietaire, lecture seule pour le groupe |

## Incident simule / Simulated incident
FR: Permissions de config mises a 000 intentionnellement pour simuler un service qui ne peut plus lire sa configuration.
EN: config permissions intentionally set to 000 to simulate a service that can no longer read its configuration.

    sudo chmod 000 /opt/webapp/config
    sudo -u webapp-svc ls /opt/webapp/config
    # Resultat: Permission denied

### Diagnostic
    ls -la /opt/webapp/
    # d--------- 2 root webapp-svc 4096 ... config
    # Toutes les permissions a zero : ni owner, ni group, ni others n'a de droit

### Fix
    sudo chmod 750 /opt/webapp/config

### Validation
    sudo -u webapp-svc ls /opt/webapp/config
    # Fonctionne, plus d'erreur

## Concept cle : le bit x sur un dossier vs un fichier
FR: Sur un fichier, x = droit d'executer ce fichier. Sur un dossier, x = droit de le TRAVERSER (cd dedans, acceder aux fichiers qu'il contient). r sur un dossier = droit de lister son contenu (ls). Sans x, impossible de faire cd dans le dossier meme avec r.

Test realise :
    chmod 640 /opt/webapp/data   # retire le x au owner
    cd /opt/webapp/data
    # Permission denied, confirme malgre le droit de lecture (r)

## Notation symbolique vs octale

FR: Deux facons d'utiliser chmod.
- Octale (ex: chmod 750) : definit les 3 categories (owner/group/others) d'un coup, utile pour une config initiale complete.
- Symbolique (ex: chmod g+s) : modifie une partie precise sans toucher au reste.

Structure de la notation symbolique : [qui][operation][quoi]
- Qui : u (user/owner), g (group), o (others - PAS owner, piege frequent), a (all)
- Operation : + (ajoute), - (retire), = (definit exactement, ecrase le reste)
- Quoi : r, w, x, s (SUID/SGID), t (sticky bit)

Exemples pratiques :
    chmod g+s dossier     # ajoute le SGID au groupe
    chmod u+x script.sh   # ajoute l'execution pour le owner seulement
    chmod o-r fichier     # retire la lecture pour "others"
    chmod g=rx dossier    # definit exactement rx pour le groupe
    chmod a+r fichier     # ajoute la lecture pour tout le monde

## SGID sur un dossier
FR: Le SGID applique a un dossier force tous les nouveaux fichiers crees dedans a heriter automatiquement du groupe du dossier - utile en travail d'equipe pour eviter les problemes de groupe incoherent.

    sudo chmod g+s /opt/webapp/data
    ls -la /opt/webapp/
    # drwxr-s--- (le s remplace le x dans l'affichage du groupe)

## Ce que j'ai appris / What I learned
FR: La difference entre r et x sur un dossier est fondamentale et souvent mal comprise - r permet de lister, x permet de traverser/acceder. Le piege o=others (pas owner) est une source d'erreur frequente en notation symbolique. La notation symbolique est preferable pour un changement cible, l'octale pour une configuration initiale complete.

EN: The difference between r and x on a directory is fundamental and often misunderstood - r allows listing, x allows traversing/accessing. The o=others (not owner) trap is a frequent source of error in symbolic notation. Symbolic notation is better for a targeted change, octal for a full initial configuration.
