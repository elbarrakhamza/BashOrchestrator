#!/bin/bash

echo "Message normal avant l'erreur (stdout)."
echo "ERREUR: Une condition d'erreur simulée va se produire ! (stderr)" >&2
echo "Fin de script_erreur.sh avant de sortir avec un code d'erreur." >&2 # Pour stderr aussi
exit 55