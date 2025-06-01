#!/bin/bash
# Ancien script_creation_fichier.sh, modifié pour créer un indicateur
FICHIER_A_CREER="indicateur_script_precedent.txt" # Nom fixe pour le test de dépendance
echo "Bonjour de script_creation_fichier.sh (modifié)."
echo "Je vais créer le fichier indicateur : ${FICHIER_A_CREER} dans le répertoire courant."

echo "Indicateur créé le $(date)" > "${FICHIER_A_CREER}"

if [ -f "${FICHIER_A_CREER}" ]; then
    echo "Fichier indicateur '${FICHIER_A_CREER}' créé avec succès."
    exit 0
else
    echo "ERREUR: Le fichier indicateur '${FICHIER_A_CREER}' n'a pas pu être créé." >&2
    exit 1
fi