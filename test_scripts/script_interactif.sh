#!/bin/bash

echo "Script interactif : Bonjour !"
read -r -p "Veuillez entrer votre nom: " nom
if [ -n "${nom}" ]; then
    echo "Merci, ${nom} !"
else
    echo "Aucun nom entré."
fi
echo "Fin de script_interactif.sh."
exit 0