#!/bin/bash
echo "=== Monitoring Système $(date) ==="

# Vérification CPU
echo -e "\n=== CPU ==="
top -bn1 | head -n 5

# Vérification Mémoire
echo -e "\n=== Mémoire ==="
free -h

# Vérification Disque
echo -e "\n=== Espace Disque ==="
df -h /

# Vérification Processus
echo -e "\n=== Processus Critiques ==="
ps aux | awk '\$3 > 50.0 || \$4 > 50.0'

# Vérification Services
echo -e "\n=== Services Système ==="
systemctl list-units --state=failed
