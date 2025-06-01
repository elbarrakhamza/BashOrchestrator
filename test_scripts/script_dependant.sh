#!/bin/bash
echo "Bonjour de script_dependant.sh."
if [ -f "indicateur_script_precedent.txt" ]; then
    echo "L'indicateur du script précédent a été trouvé !"
    rm "indicateur_script_precedent.txt"
    echo "Fin de script_dependant.sh - SUCCES."
    exit 0
else
    echo "ERREUR: L'indicateur du script précédent N'A PAS été trouvé." >&2
    echo "Fin de script_dependant.sh - ECHEC." >&2
    exit 77
fi