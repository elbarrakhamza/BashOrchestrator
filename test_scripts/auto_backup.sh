#!/bin/bash
BACKUP_DIR="/home/muslim/backups/$(date +%Y%m%d)"
SOURCE_DIR="/home/muslim/BashOrchestrator"

echo "=== Démarrage backup $(date) ==="
mkdir -p "$BACKUP_DIR"

# Backup configuration
echo "Sauvegarde configuration..."
cp -r "$SOURCE_DIR/projet/config" "$BACKUP_DIR/"

# Backup logs
echo "Sauvegarde logs..."
cp -r "$SOURCE_DIR/projet/logs" "$BACKUP_DIR/"

# Compression
echo "Compression des sauvegardes..."
tar -czf "$BACKUP_DIR.tar.gz" "$BACKUP_DIR"
rm -rf "$BACKUP_DIR"

echo "Backup terminé : $BACKUP_DIR.tar.gz"
