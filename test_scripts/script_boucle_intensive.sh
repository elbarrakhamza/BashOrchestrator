#!/bin/bash

echo "Début de script_boucle_intensive.sh"
result=0
for i in $(seq 1 50000); do
    result=$((result + i % 100))
done
echo "Fin de script_boucle_intensive.sh. Résultat (sans importance): ${result}"
exit 0