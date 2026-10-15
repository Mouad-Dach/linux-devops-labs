# Lab 05 - Reseau et DNS

## Objectif / Objective
FR: Observer la configuration reseau d'une VM (interfaces, routes, ports en ecoute), comprendre la resolution de noms (/etc/hosts puis DNS) et diagnostiquer un incident de resolution.
EN: Observe a VM's network configuration (interfaces, routes, listening ports), understand name resolution (/etc/hosts then DNS) and diagnose a resolution incident.

## Environnement / Environment
- VM1: ubuntu-server-1 (192.168.171.10), VM2: ubuntu-server-2 (192.168.171.11)
- enp0s3 : NAT (10.0.2.15), sortie Internet, passerelle 10.0.2.2
- enp0s8 : host-only, reseau prive entre PC et VMs

## Commandes utilisees / Commands used

    ip a
    ip route
    ip route get 8.8.8.8
    ip route get 192.168.171.11
    sudo ss -tulpn | grep :22

- ip a : a = address, liste les interfaces et IP
- ip route : table de routage ; la ligne "default via" = passerelle
- ip route get IP : montre le chemin reel. "via" present = passerelle, absent = reseau local
- ss -tulpn : t=tcp, u=udp, l=listening, p=process, n=numeric
- sans sudo, la colonne Process est vide ; avec sudo on voit sshd sur le port 22
- 0.0.0.0:22 = ecoute sur toutes les interfaces ; 127.0.0.1:port = accessible seulement depuis la machine

## Resolution de noms

Ordre : /etc/hosts d'abord, puis DNS (/etc/resolv.conf). L'ordre est defini dans /etc/nsswitch.conf (ligne hosts: files ... dns).

    echo "192.168.171.11 vm2" | sudo tee -a /etc/hosts
    ping -c 2 vm2
    getent hosts vm2

- tee -a : append, ajoute sans ecraser le fichier
- getent hosts nom : demande au systeme vers quelle IP il traduit le nom, en suivant le meme chemin que ping (hosts puis DNS). Plus fiable que cat /etc/hosts, qui ne montre qu'un fichier.

## Incident - vm2 injoignable par son nom

FR: /etc/hosts modifie pour pointer vm2 vers une IP inexistante.

    sudo sed -i 's/192.168.171.11 vm2/192.168.171.99 vm2/' /etc/hosts
    getent hosts vm2
    ping -c 2 vm2
    ping -c 2 192.168.171.11

Observations :
- getent hosts vm2 renvoie 192.168.171.99
- ping vm2 : Destination Host Unreachable (100% de perte)
- ping par IP (.11) : fonctionne

Diagnostic : le reseau est sain, c'est la resolution de nom qui est fautive.

Fix : remettre la bonne IP avec sed (sens inverse) ou sudo nano /etc/hosts, puis verifier avec getent hosts vm2.

## sed en bref
    sed -i 's/CHERCHER/REMPLACER/' fichier

- s = substitue, trois / obligatoires (un / manquant donne "unterminated s command")
- -i = in-place, modifie le fichier ; sans -i, affiche le resultat sans modifier
- utile dans un script ou Ansible, ou l'on ne peut pas ouvrir d'editeur ; verifier ensuite le resultat

## Ce que j'ai appris / What I learned
FR: Ping par IP OK et par nom KO signifie que le probleme est la resolution, pas le reseau. getent suit le meme chemin que ping, donc il montre ce que le systeme utilise vraiment.

EN: Ping by IP OK but by name KO means the problem is resolution, not the network. getent follows the same path as ping, so it shows what the system really uses.
