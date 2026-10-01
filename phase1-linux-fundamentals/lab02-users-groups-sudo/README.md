# Lab 02 — Users, Groups, Sudo

## Objectif / Objective
FR: Creer plusieurs utilisateurs avec des roles differents (admin, dev, readonly), configurer sudo pour un seul d'entre eux via /etc/sudoers.d/, et comprendre la difference entre un refus sudo et un refus de permissions filesystem standard.
EN: Create multiple users with different roles (admin, dev, readonly), configure sudo for only one of them via /etc/sudoers.d/, and understand the difference between a sudo denial and a standard filesystem permission denial.

## Commandes utilisees / Commands used

### Creation des utilisateurs
    sudo useradd -m -s /bin/bash admin-user
    sudo useradd -m -s /bin/bash dev-user
    sudo useradd -m -s /bin/bash readonly-user
    sudo passwd admin-user
    sudo passwd dev-user
    sudo passwd readonly-user

-m : cree automatiquement le home directory (/home/xxx-user)
-s /bin/bash : definit bash comme shell de connexion

### Creation d'un groupe et ajout d'un membre
    sudo groupadd devteam
    sudo usermod -aG devteam dev-user

-a : append, ajoute au groupe SANS retirer les groupes existants
-G : specifie le(s) groupe(s) secondaire(s)

Piege a retenir : usermod -G seul (sans -a) REMPLACE tous les groupes secondaires existants au lieu d'ajouter. Toujours -aG ensemble.

### Configuration sudo pour admin-user uniquement
    echo "admin-user ALL=(ALL:ALL) ALL" | sudo tee /etc/sudoers.d/admin-user

Decomposition de la ligne sudoers :
- admin-user = a qui ca s'applique
- ALL (1er) = sur quelles machines
- (ALL:ALL) = en tant que quel user:group il peut executer
- ALL (dernier) = quelles commandes autorisees

Bonne pratique : utiliser /etc/sudoers.d/ plutot que modifier /etc/sudoers directement (plus sur, plus facile a gerer/annuler).

## Incident / test simule

### Test 1 - sudo sans droits configures
    su - dev-user
    sudo ls /root
    # Resultat: "sudo: I'm sorry dev-user. I'm afraid I can't do that"

Diagnostic : dev-user n'a aucune entree dans /etc/sudoers.d/, donc aucun droit sudo, peu importe la commande tentee. Ce n'est pas specifique a /root.

### Test 2 - acces direct sans sudo
    ls /root
    # Resultat: Permission denied

Diagnostic :
    ls -la / | grep root
    # drwx------ root root ... /root

/root appartient a root:root avec permissions 700 (rwx pour owner seulement). dev-user n'etant ni owner ni dans le groupe root, il n'a ni r (lister) ni x (traverser) sur ce dossier.

## Distinction cle : sudo vs permissions filesystem

| Test                  | Mecanisme                  | Raison du refus                                  |
|------------------------|------------------------------|---------------------------------------------------|
| sudo ls /root           | Controle sudo (sudoers)      | dev-user n'a aucun droit sudo configure           |
| ls /root (sans sudo)    | Permissions filesystem standard | /root est en 700, accessible seulement a root     |

FR: Deux couches de securite independantes qui se renforcent mutuellement - meme un compte avec sudo configure resterait bloque si les permissions filesystem l'interdisaient, et inversement.

## Ce que j'ai appris / What I learned
FR: Un refus d'acces peut venir de deux mecanismes completement differents (sudo vs permissions standard), et il faut savoir les distinguer pour diagnostiquer correctement un incident. Le lien avec le Lab 01 est direct : le refus sur /root est exactement le meme principe que le bit x sur un dossier vu precedemment.

EN: An access denial can come from two completely different mechanisms (sudo vs standard permissions), and knowing how to distinguish them is key to correct incident diagnosis. Direct link to Lab 01: the /root denial follows the exact same x-bit-on-directory principle covered earlier.
