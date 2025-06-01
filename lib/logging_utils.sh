#!/bin/bash

# lib/logging_utils.sh

# Variables globales attendues: APP_NAME, LOG_DIR_DEFAULT, LOG_FILENAME, OPT_LOG_DIR, CONFIG_BASE_DIR, REPORTS_SUBDIR, SCRIPT_DIR_REAL

display_help() {
    local app_name_local="${APP_NAME:-BashOrchestrator}"
    # Si SCRIPT_DIR_REAL est défini (ce qui devrait être le cas), l'utiliser pour le chemin par défaut
    local default_log_path_base="${SCRIPT_DIR_REAL:-.}"
    local log_dir_default_local="${LOG_DIR_DEFAULT:-${default_log_path_base}/logs}"
    local log_filename_local="${LOG_FILENAME:-history.log}"
    local reports_subdir_local="${REPORTS_SUBDIR:-reports}"

    log_message "INFOS" "Aide principale demandée par l'utilisateur." # Va uniquement au fichier log

    # Affichage direct au terminal
    echo "Usage: ${app_name_local} [options] <commande> [arguments_commande...]"
    echo ""
    echo "Description:"
    echo "  ${app_name_local} est un gestionnaire intelligent de scripts Bash."
    echo ""
    echo "Options Globales:"
    echo "  -h          Afficher cette aide et quitter."
    echo "  -l <dir>    Spécifier le répertoire parent pour '${log_filename_local}' et '${reports_subdir_local}/'."
    echo "              (Défaut si ce script est dans BashOrchestrator_Project: BashOrchestrator_Project/logs)"
    echo "  -f          (Pour 'run'/'run-sequence'/'run-parallel') Exécuter via fork (normal)."
    echo "  -s          (Pour 'run'/'run-sequence'/'run-parallel') Exécuter dans un subshell."
    echo "  -t          (Pour 'run'/'run-sequence'/'run-parallel') Exécuter en arrière-plan."
    echo "  -r          (Pour 'restore-settings') Activer la réinitialisation."
    echo ""
    echo "Commandes Disponibles:"
    echo "  add             Enregistrer un script."
    echo "  list            Lister les scripts."
    echo "  show            Afficher le contenu d'un script."
    echo "  remove          Supprimer un script."
    echo "  run             Exécuter un script."
    echo "  run-sequence    Exécuter une série de scripts séquentiellement."
    echo "  run-parallel    Exécuter plusieurs scripts en parallèle."
    echo "  schedule        Gérer la planification (add, list, remove)."
    echo "  check-schedule  Vérifier et exécuter les tâches planifiées."
    echo "  restore-settings Réinitialiser la configuration (avec -r)."
    echo "  help [commande] Aide spécifique pour une commande."
    echo ""
}

display_help_extended() {
    local cmd_to_help="$1"; local app_name_local="${APP_NAME:-BashOrchestrator}"
    if [ -z "${cmd_to_help}" ]; then log_message "INFOS" "Aide principale (via help) demandée."; display_help; return; fi
    log_message "INFOS" "Aide étendue pour la commande '${cmd_to_help}' demandée."
    # Affichage direct au terminal
    echo "Aide pour la commande '${cmd_to_help}' de ${app_name_local}:"; echo ""
    case "${cmd_to_help}" in
        add) echo "Usage: ${app_name_local} add <path_script> [alias]"; echo "  Enregistre un script.";;
        list) echo "Usage: ${app_name_local} list"; echo "  Liste les scripts.";;
        show) echo "Usage: ${app_name_local} show <alias>"; echo "  Affiche un script.";;
        remove) echo "Usage: ${app_name_local} remove <alias>"; echo "  Supprime un script.";;
        run) echo "Usage: ${app_name_local} [-f|-s|-t] run <alias> [args...]"; echo "  Exécute un script. Les options -f,-s,-t s'appliquent à ce script.";;
        run-sequence) echo "Usage: ${app_name_local} [-f|-s|-t] run-sequence <alias1> <alias2> ..."; echo "  Exécute des scripts en séquence. L'option -f,-s,-t globale s'applique à chaque script de la séquence.";;
        run-parallel) echo "Usage: ${app_name_local} [-f|-s|-t] run-parallel <alias1> <alias2> ..."; echo "  Exécute des scripts en parallèle. L'option -f,-s,-t globale s'applique à chaque script lancé.";;
        schedule) echo "Usage: ${app_name_local} schedule <add|list|remove|check> [opts...]"; echo "  Gère la planification.";
                  echo "    add --script <alias> --time \"HH:MM\" [--date \"YYYY-MM-DD\"] [--days \"Mon,...\"] [--on-success <next_alias>]";;
        check-schedule) echo "Usage: ${app_name_local} check-schedule"; echo "  Vérifie les tâches planifiées.";;
        restore-settings) echo "Usage: ${app_name_local} -r restore-settings"; echo "  Réinitialise la config.";;
        *) echo "Aucune aide pour '${cmd_to_help}'."; log_message "WARNING" "Aide demandée pour commande inconnue: '${cmd_to_help}'.";;
    esac
}

log_message() {
    local type="$1"; local message="$2"; local timestamp; timestamp=$(date '+%Y-%m-%d-%H-%M-%S')
    local user="${USER:-$(id -un)}"
    # S'assurer que les variables pour les chemins de log ont des valeurs par défaut robustes
    local default_log_dir_for_log="${SCRIPT_DIR_REAL:-.}/logs" # Pour le cas où SCRIPT_DIR_REAL est la seule info de chemin
    local effective_log_dir="${OPT_LOG_DIR:-${LOG_DIR_DEFAULT:-${default_log_dir_for_log}}}"
    local effective_log_filename="${LOG_FILENAME:-history.log}"
    local log_file_path="${effective_log_dir}/${effective_log_filename}"
    local log_line="${timestamp} : ${user} : ${type} : ${message}"

    if [ ! -d "${effective_log_dir}" ]; then
        # Tenter une création ici si elle n'a pas eu lieu, car c'est critique pour le log
        if ! mkdir -p "${effective_log_dir}"; then
            echo "${timestamp} : ${user} : CRITICAL : Dir log ${effective_log_dir} inexistant ET impossible à créer. Log impossible: ${message}" >&2
            return 1
        fi
    fi
    if [ -w "${effective_log_dir}" ]; then
        if ! echo "${log_line}" >> "${log_file_path}"; then
             echo "${timestamp} : ${user} : CRITICAL : Échec écriture ${log_file_path}. Message: ${message}" >&2; fi
    else
        # Fallback (moins probable avec stockage local par défaut)
        local fallback_log_dir="${SCRIPT_DIR_REAL:-.}/config/logs_fallback"
        mkdir -p "${fallback_log_dir}" 2>/dev/null
        if [ -d "${fallback_log_dir}" ] && [ -w "${fallback_log_dir}" ]; then
            local fallback_log_file="${fallback_log_dir}/${effective_log_filename}"
            local fb_warn_msg="${timestamp} : ${user} : WARNING : Log principal (${log_file_path}) inaccessible. Log secours: ${fallback_log_file}"
            echo "${fb_warn_msg}" >&2; echo "${fb_warn_msg}" >> "${fallback_log_file}"; echo "${log_line}" >> "${fallback_log_file}"
        else echo "${timestamp} : ${user} : CRITICAL : Logs principal et secours inaccessibles. Non journalisé: ${message}" >&2; fi
        return 1
    fi
    # Affichage conditionnel sur le terminal : ERROR et CRITICAL uniquement
    if [[ "${type}" == "ERROR" ]] || [[ "${type}" == "CRITICAL" ]]; then echo "${log_line}" >&2; fi
    return 0
}

handle_error() {
    local error_code="$1"; local error_message="$2"
    log_message "ERROR" "Code ${error_code}: ${error_message}" # Ira au fichier et au terminal
    echo ""; display_help; exit "${error_code}" # display_help ira au terminal et loguera INFOS au fichier
}