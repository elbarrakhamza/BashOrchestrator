#!/bin/bash
TARGET_DIR="/opt/BashOrchestrator"
SOURCE_DIR="/home/muslim/BashOrchestrator/projet"

echo "=== Déploiement $(date) ==="

# Préparation
echo "Préparation du déploiement..."
sudo mkdir -p "$TARGET_DIR"

# Copie des fichiers
echo "Copie des fichiers..."
sudo cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"

# Configuration des permissions
echo "Configuration des permissions..."
sudo chown -R root:root "$TARGET_DIR"
sudo chmod 755 "$TARGET_DIR/scripts"/*.sh
sudo chmod 644 "$TARGET_DIR/config"/*.json

echo "Déploiement terminé dans $TARGET_DIR"
