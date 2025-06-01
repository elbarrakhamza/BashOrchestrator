<<<<<<< HEAD
# BashOrchestrator - Gestionnaire Intelligent de Scripts Bash

**Version:** 0.9.1 (ou la version actuelle de votre projet)

## Table des Matières

1.  [Introduction](#introduction)
2.  [Fonctionnalités](#fonctionnalités)
3.  [Architecture du Projet](#architecture-du-projet)
4.  [Installation](#installation)
5.  [Utilisation](#utilisation)
    *   [Options Globales](#options-globales)
    *   [Commandes Principales](#commandes-principales)
        *   [Gestion des Scripts (`add`, `list`, `show`, `remove`)](#gestion-des-scripts)
        *   [Exécution de Scripts (`run`, `run-sequence`, `run-parallel`)](#exécution-de-scripts)
        *   [Planification (`schedule`, `check-schedule`)](#planification)
        *   [Restauration (`restore-settings`)](#restauration)
        *   [Aide (`help`)](#aide)
6.  [Journalisation et Rapports](#journalisation-et-rapports)
7.  [Planification Automatisée avec Cron](#planification-automatisée-avec-cron)
8.  [Tests](#tests)
    *   [Prérequis pour les Tests](#prérequis-pour-les-tests)
    *   [Exemples de Scénarios de Test](#exemples-de-scénarios-de-test)
9.  [Contributions](#contributions)
10. [Licence](#licence)

## 1. Introduction

`BashOrchestrator` est un outil en ligne de commande (CLI) écrit en Bash, conçu pour simplifier et automatiser la gestion et l'exécution de vos scripts Bash. Il permet d'enregistrer des scripts, de les exécuter individuellement, en séquence ou en parallèle, de planifier leur exécution à des dates et heures spécifiques, et de conserver une trace détaillée de toutes les opérations via des logs et des rapports d'exécution.

Ce projet vise à fournir une solution portable et flexible pour les utilisateurs et administrateurs système qui gèrent de multiples scripts et souhaitent optimiser leurs workflows.

## 2. Fonctionnalités

*   **Gestion Centralisée des Scripts :** Enregistrez vos scripts pour un accès et une gestion facilités.
*   **Modes d'Exécution Flexibles :**
    *   **Fork (par défaut) :** Exécution standard dans un nouveau processus.
    *   **Subshell (`-s`) :** Exécution dans un subshell de l'orchestrateur.
    *   **Arrière-plan (`-t`) :** Exécution "thread-like" non bloquante.
*   **Exécution Multiple :**
    *   **Séquentielle (`run-sequence`) :** Exécutez une série de scripts l'un après l'autre. L'échec d'un script interrompt la séquence.
    *   **Parallèle (`run-parallel`) :** Lancez plusieurs scripts simultanément. Chaque script enfant respecte le mode d'exécution global (`-f`, `-s`, `-t`) spécifié pour la commande `run-parallel`.
*   **Planification Avancée (`schedule`) :**
    *   Planifiez des scripts à une heure précise (`HH:MM`).
    *   Spécifiez une date d'exécution (`YYYY-MM-DD`) ou laissez récurrent (`*`).
    *   Définissez des jours spécifiques de la semaine (ex: `Lun,Mer,Ven`) ou tous les jours (`*`).
    *   Enchaînez des scripts planifiés avec une condition de succès (`--on-success`).
*   **Journalisation Détaillée :**
    *   Un fichier `history.log` centralise tous les messages de l'orchestrateur (DEBUG, INFOS, WARNINGS, ERRORS) et les sorties standard/erreur des scripts exécutés.
    *   Chaque entrée de log est horodatée, identifie l'utilisateur et le type de message.
*   **Rapports d'Exécution :**
    *   Des rapports textuels sont générés pour chaque exécution de script (via `run`, `run-sequence`, `run-parallel`, `check-schedule`), détaillant les paramètres, la durée, le statut et les sorties.
*   **Portabilité :** Par défaut, toutes les configurations, scripts gérés, logs et rapports sont stockés dans des sous-dossiers du répertoire principal du projet `BashOrchestrator_Project/`, le rendant autonome.
*   **Interface CLI Intuitive :** Commandes claires et aide intégrée.

## 3. Architecture du Projet

Le projet est structuré comme suit :

BashOrchestrator_Project/
├── BashOrchestrator.sh # Script principal, point d'entrée
├── lib/ # Fonctions shell modulaires
│ ├── logging_utils.sh # Gestion des logs et de l'aide
│ ├── parsing_utils.sh # Parsing des configurations et arguments
│ └── execution_utils.sh # Logique d'exécution des scripts et planification
├── config/ # Fichiers de configuration (créés au premier lancement)
│ ├── script_registry.conf # Registre des scripts ajoutés
│ └── schedules.conf # Tâches planifiées
├── managed_scripts/ # Copies des scripts enregistrés par l'utilisateur
└── logs/ # Répertoire des journaux et rapports
├── history.log # Journal principal des opérations de l'orchestrateur
└── reports/ # Sous-dossier pour les rapports d'exécution détaillés


## 4. Installation

`BashOrchestrator` est conçu pour être portable et ne nécessite pas d'installation complexe.

1.  **Clonez le dépôt ou copiez les fichiers** du projet dans un répertoire de votre choix (ex: `~/BashOrchestrator_Project`).
2.  **Assurez-vous que le script principal est exécutable :**
    ```bash
    cd chemin/vers/BashOrchestrator_Project/
    chmod +x BashOrchestrator.sh
    ```
3.  **(Optionnel) Créez un lien symbolique** vers `BashOrchestrator.sh` dans un répertoire de votre `PATH` pour un accès global (ex: `/usr/local/bin/`):
    ```bash
    sudo ln -s "$(pwd)/BashOrchestrator.sh" /usr/local/bin/bashorchestrator
    ```
    Si vous faites cela, vous pourrez appeler l'outil simplement avec `bashorchestrator`. Sinon, vous devrez l'appeler avec son chemin relatif (`./BashOrchestrator.sh`) ou absolu.

Les répertoires `config/`, `managed_scripts/`, et `logs/` seront créés automatiquement dans le répertoire de `BashOrchestrator.sh` lors de la première utilisation appropriée si le stockage local est activé (ce qui est le cas par défaut).

## 5. Utilisation

La syntaxe générale est :
`./BashOrchestrator.sh [OPTIONS_GLOBALES] <COMMANDE> [ARGUMENTS_COMMANDE...]`

### Options Globales

Ces options doivent précéder la `<COMMANDE>` :

*   `-h` : Affiche l'aide détaillée et quitte.
*   `-l <répertoire>` : Spécifie le répertoire parent pour le fichier `history.log` et le sous-dossier `reports/`. Par défaut, c'est `BashOrchestrator_Project/logs/`.
*   `-f` : (Pour les commandes `run`, `run-sequence`, `run-parallel`) Force l'exécution de chaque script enfant en mode "fork" (processus normal, comportement par défaut si aucune autre option de mode n'est donnée).
*   `-s` : (Pour les commandes `run`, `run-sequence`, `run-parallel`) Force l'exécution de chaque script enfant dans un "subshell".
*   `-t` : (Pour les commandes `run`, `run-sequence`, `run-parallel`) Force l'exécution de chaque script enfant en "arrière-plan" (non bloquant pour l'orchestrateur lors du lancement en parallèle ou séquentiel).
*   `-r` : (Uniquement pour la commande `restore-settings`) Active la permission de réinitialiser la configuration.

### Commandes Principales

#### Gestion des Scripts

*   **`add <chemin_vers_script_original> [alias_optionnel]`**
    Enregistre un nouveau script. Le script original est copié dans le répertoire `managed_scripts/`. Si `alias_optionnel` n'est pas fourni, un alias est généré à partir du nom du fichier script (sans extension).
    ```bash
    ./BashOrchestrator.sh add ~/mes_scripts/backup.sh mon_backup
    ./BashOrchestrator.sh add ~/mes_scripts/cleanup.sh 
    ```

*   **`list`**
    Affiche tous les scripts actuellement enregistrés avec leur alias, chemin original et date d'ajout.
    ```bash
    ./BashOrchestrator.sh list
    ```

*   **`show <alias>`**
    Affiche le contenu du script enregistré identifié par `<alias>`.
    ```bash
    ./BashOrchestrator.sh show mon_backup
    ```

*   **`remove <alias>`**
    Supprime le script identifié par `<alias>` de la gestion de l'orchestrateur (y compris sa copie dans `managed_scripts/`). Une confirmation est demandée.
    ```bash
    ./BashOrchestrator.sh remove mon_backup
    ```

#### Exécution de Scripts

*   **`run <alias> [arguments_pour_le_script_enfant...]`**
    Exécute le script enregistré identifié par `<alias>`. Tous les arguments suivants sont passés directement au script enfant. Les options globales `-f`, `-s`, `-t` s'appliquent.
    ```bash
    ./BashOrchestrator.sh run mon_backup --full --destination /mnt/backup_disk
    ./BashOrchestrator.sh -s run script_test "param1"
    ./BashOrchestrator.sh -t run script_longue_duree
    ```

*   **`run-sequence <alias1> <alias2> [<alias3> ...]`**
    Exécute une série de scripts (identifiés par leurs alias) séquentiellement, dans l'ordre fourni. Si un script de la séquence échoue (code de sortie non nul), les scripts suivants ne sont pas exécutés. Les options globales `-f`, `-s`, `-t` s'appliquent à *chaque* script de la séquence.
    ```bash
    ./BashOrchestrator.sh run-sequence prepare_data process_data generate_report
    ./BashOrchestrator.sh -s run-sequence init_env compile run_tests
    ```

*   **`run-parallel <alias1> <alias2> [<alias3> ...]`**
    Lance plusieurs scripts (identifiés par leurs alias) pour qu'ils s'exécutent en parallèle. L'orchestrateur lance chaque script et attend que tous les *processus de lancement* soient terminés. Chaque script enfant est exécuté selon l'option globale `-f`, `-s`, ou `-t` spécifiée. Pour un vrai parallélisme où l'orchestrateur ne bloque pas, utilisez `-t` avec `run-parallel`.
    ```bash
    ./BashOrchestrator.sh -t run-parallel tache_A tache_B tache_C
    ./BashOrchestrator.sh -f run-parallel script1 script2 # Lance script1 puis script2 en parallèle (les wrappers sont en //)
    ```

#### Planification

*   **`schedule add --script <alias> --time "HH:MM" [--date "YYYY-MM-DD"] [--days "Jour1,Jour2,..."] [--on-success <alias_script_suivant>]`**
    Ajoute une nouvelle tâche planifiée.
    *   `--script <alias>`: (Obligatoire) Alias du script à planifier.
    *   `--time "HH:MM"`: (Obligatoire) Heure d'exécution.
    *   `--date "YYYY-MM-DD"`: (Optionnel) Date spécifique. Si omis ou `*`, s'exécute chaque jour correspondant aux `--days`.
    *   `--days "Jour1,..."`: (Optionnel) Jours de la semaine (ex: `Lun,Mar,Mer` ou `Mon,Wed,Fri`). `*` pour tous les jours. Sensible aux abréviations anglaises (Mon, Tue, Wed, Thu, Fri, Sat, Sun).
    *   `--on-success <alias_script_suivant>`: (Optionnel) Alias d'un autre script à exécuter si le script principal réussit.
    ```bash
    ./BashOrchestrator.sh schedule add --script mon_backup --time "02:30" --days "Dim"
    ./BashOrchestrator.sh schedule add --script rapport_jour --date "2025-07-15" --time "18:00"
    ./BashOrchestrator.sh schedule add --script tache1 --time "10:00" --on-success tache2
    ```

*   **`schedule list`**
    Affiche toutes les tâches actuellement planifiées.

*   **`schedule remove <id_planification>`**
    Supprime une tâche planifiée en utilisant son ID (obtenu via `schedule list`).

*   **`check-schedule` (ou `schedule check`)**
    Vérifie manuellement la liste des planifications et exécute toutes les tâches qui sont dues. Cette commande est principalement destinée à être appelée par un service `cron` pour automatiser la vérification.

#### Restauration

*   **`-r restore-settings`**
    Réinitialise `BashOrchestrator` à ses paramètres d'usine. **ATTENTION :** Ceci supprime tous les scripts enregistrés, toutes les planifications, et réinitialise les fichiers de configuration locaux (`config/`, `managed_scripts/`). Les logs et rapports ne sont pas supprimés. Nécessite l'option `-r` et est généralement une action d'administrateur (bien que `sudo` ne soit pas strictement requis si les fichiers sont locaux et appartiennent à l'utilisateur).
    ```bash
    ./BashOrchestrator.sh -r restore-settings 
    ```

#### Aide

*   **`help [nom_commande]`**
    Affiche l'aide détaillée pour une commande spécifique. Si `nom_commande` est omis, affiche l'aide générale (similaire à `-h`).
    ```bash
    ./BashOrchestrator.sh help run
    ./BashOrchestrator.sh help schedule
    ```

## 6. Journalisation et Rapports

*   **Journal Principal (`history.log`) :**
    *   Situé par défaut dans `BashOrchestrator_Project/logs/history.log` (ou le répertoire spécifié par `-l`).
    *   Enregistre toutes les opérations de l'orchestrateur (DEBUG, INFOS, WARNINGS, ERRORS, CRITICALS) et les sorties standard/erreur des scripts enfants exécutés via `run`, `run-sequence`, `run-parallel`, ou `check-schedule`.
    *   Format : `yyyy-mm-dd-HH-MM-SS : utilisateur : TYPE : message`

*   **Rapports d'Exécution (`reports/report_....txt`) :**
    *   Situés dans un sous-dossier `reports/` à l'intérieur du répertoire de log (par défaut `BashOrchestrator_Project/logs/reports/`).
    *   Un rapport est généré pour chaque exécution de script (sauf pour les lancements en `-t` où un rapport de "lancement" est créé).
    *   Contenu : Alias, chemin du script, mode d'exécution, arguments, heures de début/fin, durée, code de sortie, statut (SUCCÈS/ÉCHEC), et l'intégralité des sorties standard et d'erreur du script exécuté.

L'affichage au terminal par l'orchestrateur est conçu pour être concis, fournissant les résultats directs des commandes (`list`, messages de succès/échec pour `add`/`remove`) et les sorties des scripts enfants si `run` est utilisé. Les messages de log internes (DEBUG, la plupart des INFOS) et les détails complets des exécutions sont dans les fichiers.

## 7. Planification Automatisée avec Cron

Pour que les tâches planifiées avec `BashOrchestrator schedule add ...` s'exécutent automatiquement, vous devez configurer une tâche `cron` pour appeler la commande `check-schedule` régulièrement.

1.  Ouvrez votre crontab utilisateur : `crontab -e`
2.  Ajoutez une ligne pour exécuter `check-schedule` (par exemple, toutes les minutes) :
    ```cron
    * * * * * /chemin/complet/vers/BashOrchestrator_Project/BashOrchestrator.sh check-schedule
    ```
    Remplacez `/chemin/complet/vers/BashOrchestrator_Project/` par le chemin réel de votre projet. Assurez-vous que le script est exécutable et que l'utilisateur `cron` a les permissions nécessaires si les scripts gérés interagissent avec des ressources spécifiques.

## 8. Tests

Un test rigoureux est essentiel.

### Prérequis pour les Tests

1.  **Nettoyez l'environnement de test :** Avant de commencer une nouvelle session de test, il est recommandé de vider les répertoires `config/`, `managed_scripts/`, et `logs/` pour des résultats clairs.
    ```bash
    rm -rf BashOrchestrator_Project/config/*
    rm -rf BashOrchestrator_Project/managed_scripts/*
    rm -rf BashOrchestrator_Project/logs/*
    ```
2.  **Préparez des scripts de test :** Créez une collection de petits scripts Bash dans un répertoire séparé (ex: `~/bo_test_scripts/`) pour simuler différentes fonctionnalités et erreurs. Rendez-les exécutables. Voir les exemples de scripts de test fournis dans les échanges précédents.

### Exemples de Scénarios de Test

*(Se référer au plan de test détaillé fourni précédemment, qui couvre chaque commande et option.)*

Quelques points clés à tester systématiquement :

*   **Aide et Erreurs :** Options `-h`, commandes inconnues, options invalides.
*   **CRUD des Scripts :** `add` (avec/sans alias, alias existant, fichier inexistant), `list` (vide/rempli), `show`, `remove` (confirmation oui/non).
*   **Exécution `run` :**
    *   Sans arguments, avec arguments.
    *   Avec options `-f`, `-s`, `-t`.
    *   Script qui réussit, script qui échoue (vérifier code de sortie et rapport).
    *   Script long (pour `-t`).
*   **Exécution `run-sequence` :**
    *   Séquence qui réussit entièrement.
    *   Séquence qui échoue au milieu (vérifier que les suivants ne s'exécutent pas).
    *   Avec options globales `-f`, `-s`, `-t`.
*   **Exécution `run-parallel` :**
    *   Lancement de plusieurs scripts.
    *   Avec options globales `-f`, `-s`, `-t` (observer comment les scripts enfants se comportent).
*   **Planification `schedule` :**
    *   `add` avec heure, date, jours, `on-success`.
    *   `list` pour vérifier.
    *   `check-schedule` (attendre l'heure ou la forcer) et vérifier l'exécution, les rapports, et la mise à jour du statut.
    *   `remove` une planification.
*   **Journalisation et Rapports :**
    *   Vérifier le contenu et le format de `logs/history.log` pour toutes les opérations.
    *   Vérifier la création et le contenu des rapports dans `logs/reports/`.
    *   Tester l'option `-l` pour rediriger les logs/rapports.
*   **Restauration :** `restore-settings` avec et sans `-r`, et avec confirmation.

## 9. Contributions

Les contributions, suggestions et rapports de bugs sont les bienvenus ! (À adapter si c'est un projet personnel ou ouvert).

## 10. Licence

(À définir - ex: MIT, GPLv3, etc. si vous prévoyez de le partager)
=======
# BashOrchestrator
BashOrchestrator - Gestionnaire Intelligent de Scripts Bash
>>>>>>> d921ef8e1e7a63f70bb88784a104bdc417fa9567
