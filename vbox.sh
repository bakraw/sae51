#!/bin/bash

# Variables pour la configuration de la machine virtuelle
TAILLE_RAM=4096       # Taille de la RAM en Mo
TAILLE_DISQUE=65536   # Taille du disque dur en MiB
IMAGE_ISO="./debian-12.7.0-amd64-netinst.iso"  # Chemin vers l'image ISO Debian

# Fonction pour vérifier si VBoxManage est installé
check_vboxmanage() {
    if ! command -v VBoxManage &> /dev/null; then
        echo "VBoxManage n'est pas installé. Veuillez installer VirtualBox."
        exit 1
    fi
}

# Fonction pour obtenir la date et l'utilisateur
get_metadata() {
    DATE_CREATION=$(date '+%Y-%m-%d %H:%M:%S')
    ID_USER=${USER}
}

# Fonction pour lister les machines virtuelles avec leurs métadonnées
list_vms() {
    echo "Liste des machines virtuelles :"
    VBoxManage list vms > /tmp/vms_list.txt

    while read -r line; do
        local NOM_VM=$(echo $line | awk '{print $1}' | sed 's/"//g')
        echo -n "$NOM_VM : "

        # Récupérer et afficher les métadonnées
        DATE_CREATION=$(VBoxManage getextradata "$NOM_VM" "CreationDate" 2>/dev/null | awk -F ':' '{print $2}' | sed 's/^ *//')
        ID_USER=$(VBoxManage getextradata "$NOM_VM" "UserID" 2>/dev/null | awk -F ':' '{print $2}' | sed 's/^ *//')

        if [ -z "$DATE_CREATION" ]; then
            DATE_CREATION="Non spécifiée"
        fi

        if [ -z "$ID_USER" ]; then
            ID_USER="Non spécifiée"
        fi

        echo "Date de création: $DATE_CREATION, ID utilisateur: $ID_USER"
    done < /tmp/vms_list.txt

    rm -f /tmp/vms_list.txt
}

# Fonction pour ajouter une nouvelle machine virtuelle
creer_vm() {
    if VBoxManage list vms | grep -q "\"$NOM_VM\""; then
        echo "Une machine virtuelle nommée '$NOM_VM' existe déjà. Suppression en cours..."
        VBoxManage controlvm "$NOM_VM" poweroff 2>/dev/null
        VBoxManage unregistervm "$NOM_VM" --delete
    fi

    VBoxManage createvm --name "$NOM_VM" --ostype Debian_64 --register

    VBoxManage modifyvm "$NOM_VM" --memory $TAILLE_RAM --cpus 2 --vram 128

    VBoxManage createhd --filename "$NOM_VM.vdi" --size $TAILLE_DISQUE --format VDI
    VBoxManage storagectl "$NOM_VM" --name "SATA Controller" --add sata
    VBoxManage storageattach "$NOM_VM" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$NOM_VM.vdi"

    # Attacher l'image ISO comme disque de démarrage
    VBoxManage storagectl "$NOM_VM" --name "IDE Controller" --add ide
    VBoxManage storageattach "$NOM_VM" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$IMAGE_ISO"

    VBoxManage modifyvm "$NOM_VM" --nic1 nat
    VBoxManage modifyvm "$NOM_VM" --boot1 dvd --boot2 disk

    get_metadata
    VBoxManage setextradata "$NOM_VM" "CreationDate" "$DATE_CREATION"
    VBoxManage setextradata "$NOM_VM" "UserID" "$ID_USER"

    # Démarrer la machine virtuelle pour commencer l'installation
    VBoxManage startvm "$NOM_VM" --type gui
}

# Fonction pour supprimer une machine virtuelle
supprimer_vm() {
    if VBoxManage list vms | grep -q "\"$NOM_VM\""; then
        echo "Suppression de la machine virtuelle '$NOM_VM'..."
        VBoxManage controlvm "$NOM_VM" poweroff 2>/dev/null
        VBoxManage unregistervm "$NOM_VM" --delete
    else
        echo "La machine virtuelle '$NOM_VM' n'existe pas."
    fi
}

# Fonction pour démarrer une machine virtuelle
demarrer_vm() {
    if VBoxManage list vms | grep -q "\"$NOM_VM\""; then
        echo "Démarrage de la machine virtuelle '$NOM_VM'..."
        VBoxManage startvm "$NOM_VM" --type gui
    else
        echo "La machine virtuelle '$NOM_VM' n'existe pas."
    fi
}

# Fonction pour arrêter une machine virtuelle
arreter_vm() {
    if VBoxManage list vms | grep -q "\"$NOM_VM\""; then
        echo "Arrêt de la machine virtuelle '$NOM_VM'..."
        VBoxManage controlvm "$NOM_VM" poweroff
    else
        echo "La machine virtuelle '$NOM_VM' n'existe pas."
    fi
}

# Vérification de la présence de VBoxManage
check_vboxmanage

# Vérification du nombre d'arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 [L|N|S|D|A] [nom_machine]"
    echo "  L: Liste des machines"
    echo "  N: Nouvelle machine"
    echo "  S: Supprimer une machine"
    echo "  D: Démarrer une machine"
    echo "  A: Arrêter une machine"
    exit 1
fi

# Stockage des arguments dans des variables
ACTION=$1
NOM_VM=$2

# Exécuter l'action demandée
case $ACTION in
    L)
        list_vms
        ;;
    N)
        if [ -z "$NOM_VM" ]; then
            echo "Vous devez spécifier le nom de la machine virtuelle pour ajouter."
            exit 1
        fi
        creer_vm
        ;;
    S)
        if [ -z "$NOM_VM" ]; then
            echo "Vous devez spécifier le nom de la machine virtuelle pour supprimer."
            exit 1
        fi
        supprimer_vm
        ;;
    D)
        if [ -z "$NOM_VM" ]; then
            echo "Vous devez spécifier le nom de la machine virtuelle pour démarrer."
            exit 1
        fi
        demarrer_vm
        ;;
    A)
        if [ -z "$NOM_VM" ]; then
            echo "Vous devez spécifier le nom de la machine virtuelle pour arrêter."
            exit 1
        fi
        arreter_vm
        ;;
    *)
        echo "Action non reconnue. Utilisez L, N, S, D, ou A."
        exit 1
        ;;
esac
