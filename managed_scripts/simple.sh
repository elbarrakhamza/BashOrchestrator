#!/bin/bash

echo "Bonjour de script_simple.sh !"
echo "Ce script a été appelé avec $# argument(s)."

if [ "$#" -gt 0 ]; then
    echo "Arguments reçus :"
    count=1
    for arg in "$@"; do
        echo "  Arg ${count}: ${arg}"
        count=$((count + 1))
    done
else
    echo "Aucun argument n'a été fourni."
fi

echo "Variable d'environnement TEST_VAR: ${TEST_VAR:-Non définie}"
echo "Fin de script_simple.sh."
exit 0