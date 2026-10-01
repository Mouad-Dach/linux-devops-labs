# Lab 00 — VM Lab Setup & Host-Only Networking

## Objectif / Objective
FR: Mettre en place deux VMs Ubuntu Server (26.04.1 LTS) sur VirtualBox, communicant entre elles via un reseau isole (Host-only), avec IP statiques configurees via Netplan.
EN: Set up two Ubuntu Server VMs (26.04.1 LTS) on VirtualBox, communicating over an isolated Host-only network, with static IPs configured via Netplan.

## Environnement / Environment
- Host: Windows, VirtualBox
- Guest OS: Ubuntu Server 26.04.1 LTS x2 (VM1 cloned to VM2)
- Network: NAT (internet access) + Host-only Adapter (inter-VM communication)

## Incident rencontre / Incident encountered
FR: Apres configuration initiale d'un reseau Host-only dans VirtualBox et attribution d'une IP statique via Netplan, la connexion SSH/ping depuis le PC hote echouait avec un timeout.

EN: After initial Host-only network setup in VirtualBox and static IP assignment via Netplan, SSH/ping from the host PC failed with a timeout.

## Investigation

    ping 192.168.107.10
    # Reply from 81.192.249.77: TTL expired in transit  <- reponse d'une IP publique, anormal

    ipconfig /all
    # Revele un adaptateur "VirtualBox Host-Only Ethernet Adapter #3"
    # avec une IP differente (192.168.171.1) de celle vue dans VirtualBox

## Root cause
FR: Desalignement entre le reseau Host-only affiche dans le Network Manager de VirtualBox et l'adaptateur reseau reellement enregistre cote Windows, suite a une recreation du reseau apres une erreur initiale (VERR_INTNET_FLT_IF_NOT_FOUND).

EN: Mismatch between the Host-only network shown in VirtualBox's Network Manager and the adapter actually registered on the Windows side, after the network had to be recreated following an initial error (VERR_INTNET_FLT_IF_NOT_FOUND).

## Fix
FR: Identification de la plage IP reelle via ipconfig /all, puis reconfiguration de Netplan sur les deux VMs avec la bonne plage (192.168.171.0/24). Voir netplan-vm1.yaml et netplan-vm2.yaml dans ce dossier.

## Validation

    ping -c 4 192.168.171.11
    # 0% packet loss

    ssh madmin@192.168.171.11
    # Connexion reussie

## Ce que j'ai appris / What I learned
FR: Toujours verifier la correspondance entre ce qu'un outil de virtualisation affiche (VirtualBox) et ce que le systeme d'exploitation hote a reellement enregistre (Windows) - ne jamais assumer une synchronisation automatique apres une operation de recreation reseau.

EN: Always verify that what a virtualization tool displays (VirtualBox) matches what the host OS actually registered (Windows) - never assume automatic sync after a network recreation operation.
