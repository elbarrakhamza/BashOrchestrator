#!/bin/bash
echo "=== Maintenance système $(date) ==="

# Nettoyage des logs anciens
find /home/muslim/BashOrchestrator/projet/logs -type f -name "*.log" -mtime +30 -delete
echo "Logs anciens nettoyés"

# Nettoyage des backups anciens
find /home/muslim/backups -type f -name "*.tar.gz" -mtime +7 -delete
echo "Anciens backups nettoyés"

# Vérification des permissions
chmod 755 /home/muslim/BashOrchestrator/projet/scripts/*.sh
chmod 644 /home/muslim/BashOrchestrator/projet/config/*.json
echo "Permissions corrigées"

# Optimisation
echo "Optimisation des fichiers journaux..."
find /home/muslim/BashOrchestrator/projet/logs -type f -name "*.log" -exec truncate -s 1M {} \;
