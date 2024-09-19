# Script de gestion de machines virtuelles VirtualBox

Ce script Bash permet de gérer les machines virtuelles dans VirtualBox en offrant des fonctionnalités pour créer, démarrer, arrêter, supprimer et lister les machines virtuelles. Il configure également la machine virtuelle pour démarrer automatiquement à partir d'une image ISO Debian.

## Prérequis

- **VirtualBox** doit être installé sur la machine hôte.
- **VBoxManage** doit être accessible depuis la ligne de commande.

## Variables

- `TAILLE_RAM` : Taille de la RAM allouée à la machine virtuelle en Mo.
- `TAILLE_DISQUE` : Taille du disque dur virtuel en MiB.
- `IMAGE_ISO` : Chemin vers l'image ISO Debian à utiliser pour l'installation.

## Fonctions

### `check_vboxmanage`

Vérifie si `VBoxManage` est installé. Si ce n'est pas le cas, affiche un message d'erreur et termine l'exécution du script.

```bash
check_vboxmanage() {
    if ! command -v VBoxManage &> /dev/null; then
        echo "VBoxManage n'est pas installé. Veuillez installer VirtualBox."
        exit 1
    fi
}
```

### get_metadata

Obtient la date actuelle et l'ID utilisateur pour les métadonnées de la machine virtuelle.

```bash

get_metadata() {
    DATE_CREATION=$(date '+%Y-%m-%d %H:%M:%S')
    ID_USER=${USER}
}
```

### list_vms

Liste toutes les machines virtuelles avec leurs métadonnées telles que la date de création et l'ID utilisateur.

```bash

list_vms() {
    echo "Liste des machines virtuelles :"
    VBoxManage list vms > /tmp/vms_list.txt

    while read -r line; do
        local NOM_VM=$(echo $line | awk '{print $1}' | sed 's/"//g')
        echo -n "$NOM_VM : "

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
```

### creer_vm

Crée une nouvelle machine virtuelle, la configure avec les ressources spécifiées, et attache une image ISO pour l'installation. Démarre ensuite la machine virtuelle pour commencer l'installation.

```bash

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

    VBoxManage storagectl "$NOM_VM" --name "IDE Controller" --add ide
    VBoxManage storageattach "$NOM_VM" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$IMAGE_ISO"

    VBoxManage modifyvm "$NOM_VM" --nic1 nat
    VBoxManage modifyvm "$NOM_VM" --boot1 dvd --boot2 disk

    get_metadata
    VBoxManage setextradata "$NOM_VM" "CreationDate" "$DATE_CREATION"
    VBoxManage setextradata "$NOM_VM" "UserID" "$ID_USER"

    VBoxManage startvm "$NOM_VM" --type gui
}
```

### supprimer_vm

Supprime une machine virtuelle spécifiée si elle existe.

```bash

supprimer_vm() {
    if VBoxManage list vms | grep -q "\"$NOM_VM\""; then
        echo "Suppression de la machine virtuelle '$NOM_VM'..."
        VBoxManage controlvm "$NOM_VM" poweroff 2>/dev/null
        VBoxManage unregistervm "$NOM_VM" --delete
    else
        echo "La machine virtuelle '$NOM_VM' n'existe pas."
    fi
}
```

### demarrer_vm

Démarre une machine virtuelle spécifiée. L'ouverture automatique de session n'est pas encore configurée dans ce script.

```bash

demarrer_vm() {
    if VBoxManage list vms | grep -q "\"$NOM_VM\""; then
        echo "Démarrage de la machine virtuelle '$NOM_VM'..."
        VBoxManage startvm "$NOM_VM" --type gui
    else
        echo "La machine virtuelle '$NOM_VM' n'existe pas."
    fi
}
```
### arreter_vm

Arrête une machine virtuelle spécifiée.

```bash

arreter_vm() {
    if VBoxManage list vms | grep -q "\"$NOM_VM\""; then
        echo "Arrêt de la machine virtuelle '$NOM_VM'..."
        VBoxManage controlvm "$NOM_VM" poweroff
    else
        echo "La machine virtuelle '$NOM_VM' n'existe pas."
    fi
}
```

## Utilisation du Script

Le script doit être exécuté avec un argument pour l'action désirée. Les options disponibles sont :

    L : Liste des machines virtuelles.
    N : Créer une nouvelle machine virtuelle.
    S : Supprimer une machine virtuelle.
    D : Démarrer une machine virtuelle.
    A : Arrêter une machine virtuelle.

Exemples d'exécution :

    Lister les machines : ./vbox.sh L
    Créer une machine : ./vbox.sh N <nom_machine>
    Supprimer une machine : ./vbox.sh S <nom_machine>
    Démarrer une machine : ./vbox.sh D <nom_machine>
    Arrêter une machine : ./vbox.sh A <nom_machine>
