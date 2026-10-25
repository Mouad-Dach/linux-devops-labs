# Lab 06 - Firewall ufw

## Objectif / Objective
FR: Installer et activer un firewall (ufw) sur VM2, comprendre la politique par defaut et l'ordre des regles, puis diagnostiquer un blocage SSH venant d'une regle deny.
EN: Enable a firewall (ufw) on VM2, understand the default policy and rule order, then diagnose an SSH block caused by a deny rule.

## Environnement / Environment
- VM1: ubuntu-server-1 (192.168.171.10), VM2: ubuntu-server-2 (192.168.171.11)
- ufw sur VM2, test depuis VM1

## Commandes utilisees / Commands used

    sudo ufw status
    sudo ufw allow 22/tcp
    sudo ufw enable
    sudo ufw status verbose
    sudo ufw status numbered
    sudo ufw delete 1

- allow 22/tcp : autorise le trafic entrant sur le port 22 (SSH)
- enable : active le firewall et le garde actif au demarrage
- status verbose : etat detaille et politique par defaut
- status numbered : numerote les regles, utile pour en supprimer une
- IMPORTANT : toujours autoriser SSH AVANT enable, sinon le firewall coupe la session

Politique par defaut observee : deny (incoming), allow (outgoing). On bloque tout ce qui entre, puis on ouvre au cas par cas.

## Test d'un port non autorise

    nc -zv -w 3 192.168.171.11 80
    # nc: connect to ... port 80 (tcp) timed out

- nc : netcat ; -z teste sans envoyer de donnees ; -v verbose ; -w 3 abandonne apres 3 secondes
- timeout = un firewall jette les paquets (DROP)
- refused = la machine repond que personne n'ecoute (service absent), le firewall laisse passer

## Incident - Ticket #1002 : SSH de VM1 vers VM2 ne marche plus

FR: Regle deny inseree en premiere position pour la source VM1.

    sudo ufw insert 1 deny from 192.168.171.10 to any port 22 proto tcp

Diagnostic depuis VM1 :

    ssh -o ConnectTimeout=5 madmin@192.168.171.11   # Connection timed out
    ping -c 2 192.168.171.11                         # OK, 0% de perte
    nc -zv -w 3 192.168.171.11 22                    # timed out

- ping OK : le reseau et la machine fonctionnent
- timeout sur le port 22 : un firewall jette les paquets ; sshd n'est pas en cause (il repondrait refused)
- une session SSH depuis le PC fonctionnait toujours : sshd tourne, seul le trafic de VM1 est bloque

Recherche de la cause sur VM2 :

    sudo ufw status numbered
    # [ 1] 22/tcp DENY IN 192.168.171.10
    # [ 2] 22/tcp ALLOW IN Anywhere

Cause : ufw lit les regles de haut en bas et applique la premiere qui correspond. Le deny pour VM1 est avant le allow general, donc il l'emporte pour cette source.

Fix :

    sudo ufw delete 1
    sudo ufw status numbered

Apres une suppression, les numeros se decalent : relancer status numbered avant de supprimer une autre regle.

Validation : ssh madmin@192.168.171.11 depuis VM1 fonctionne a nouveau.

## Ce que j'ai appris / What I learned
FR: Ping OK et timeout sur un port precis indique un firewall. L'ordre des regles ufw compte : la premiere qui correspond s'applique. Toujours autoriser SSH avant d'activer le firewall.

EN: Ping OK with a timeout on one port points to a firewall. Rule order matters in ufw: the first matching rule applies. Always allow SSH before enabling the firewall.
