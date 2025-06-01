#!/bin/bash

# BashOrchestrator - Gestionnaire intelligent de scripts Bash
# Version: 0.9.1 (Planification avec date, run-sequence, run-parallel amélioré)
# Author: Votre Nom

# --- Définition des Constantes et Chemins Initiaux ---
SCRIPT_DIR_REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
readonly SCRIPT_DIR_REAL
APP_NAME="BashOrchestrator"
readonly APP_NAME
LIB_DIR="${SCRIPT_DIR_REAL}/lib"
readonly LIB_DIR

# --- Chargement des Bibliothèques Essentielles ---
if [ ! -f "${LIB_DIR}/logging_utils.sh" ]; then
    echo "ERREUR CRITIQUE: lib/logging_utils.sh introuvable dans ${LIB_DIR}." >&2; exit 10;
fi
# shellcheck source=lib/logging_utils.sh
source "${LIB_DIR}/logging_utils.sh"
if [ ! -f "${LIB_DIR}/parsing_utils.sh" ]; then
    log_message "CRITICAL" "lib/parsing_utils.sh introuvable."; exit 11;
fi
# shellcheck source=lib/parsing_utils.sh
source "${LIB_DIR}/parsing_utils.sh"
if [ ! -f "${LIB_DIR}/execution_utils.sh" ]; then
    log_message "CRITICAL" "lib/execution_utils.sh introuvable."; exit 12;
fi
# shellcheck source=lib/execution_utils.sh
source "${LIB_DIR}/execution_utils.sh"

# --- Configuration des Variables Globales et des Chemins Applicatifs (Portables) ---
CONFIG_BASE_DIR="${SCRIPT_DIR_REAL}/config" # Stockage local
readonly CONFIG_BASE_DIR
DATA_BASE_DIR="${SCRIPT_DIR_REAL}" # Stockage local
readonly DATA_BASE_DIR
LOG_DIR_DEFAULT="${SCRIPT_DIR_REAL}/logs" # Stockage local
readonly LOG_DIR_DEFAULT
LOG_FILENAME="history.log"
readonly LOG_FILENAME
REPORTS_SUBDIR="reports"
readonly REPORTS_SUBDIR

CONFIG_DIR="${CONFIG_BASE_DIR}"
MANAGED_SCRIPTS_DIR="${DATA_BASE_DIR}/managed_scripts"
SCRIPT_REGISTRY_FILE="${CONFIG_DIR}/script_registry.conf"
SCHEDULES_FILE="${CONFIG_DIR}/schedules.conf"

declare OPT_LOG_DIR="${LOG_DIR_DEFAULT}"
declare OPT_EXEC_MODE="" # Options -f, -s, -t pour 'run', 'run-sequence', 'run-parallel'
declare OPT_RESTORE=0
declare -a SCRIPT_ARGS=()

# --- Initialisation des Répertoires Applicatifs ---
initialize_application_directories() {
    log_message "DEBUG" "Initialisation des répertoires applicatifs..."
    log_message "DEBUG" "CONFIG_DIR=${CONFIG_DIR}"
    log_message "DEBUG" "MANAGED_SCRIPTS_DIR=${MANAGED_SCRIPTS_DIR}"
    log_message "DEBUG" "OPT_LOG_DIR=${OPT_LOG_DIR}"
    if ! mkdir -p "${CONFIG_DIR}"; then log_message "CRITICAL" "Impossible de créer ${CONFIG_DIR}."; exit 20; fi
    if ! mkdir -p "${MANAGED_SCRIPTS_DIR}"; then log_message "CRITICAL" "Impossible de créer ${MANAGED_SCRIPTS_DIR}."; exit 21; fi
    touch "${SCRIPT_REGISTRY_FILE}" || { log_message "CRITICAL" "Impossible de créer ${SCRIPT_REGISTRY_FILE}"; exit 22; }
    touch "${SCHEDULES_FILE}" || { log_message "CRITICAL" "Impossible de créer ${SCHEDULES_FILE}"; exit 23; }
    local effective_reports_dir="${OPT_LOG_DIR}/${REPORTS_SUBDIR}"
    if ! mkdir -p "${OPT_LOG_DIR}"; then log_message "CRITICAL" "Impossible de créer ${OPT_LOG_DIR}."; exit 24; fi
    if ! mkdir -p "${effective_reports_dir}"; then log_message "CRITICAL" "Impossible de créer ${effective_reports_dir}."; exit 25; fi
    log_message "DEBUG" "Répertoires de logs et rapports prêts dans ${OPT_LOG_DIR}."
    return 0
}

# --- Fonction Principale (main) ---
main() {
    OPTIND=1
    while getopts ":hl:fstr" opt; do # -f, -s, -t sont des options globales
        case ${opt} in
            h) display_help; exit 0 ;;
            l) OPT_LOG_DIR="${OPTARG}" ;;
            f) OPT_EXEC_MODE="fork" ;;
            s) OPT_EXEC_MODE="subshell" ;;
            t) OPT_EXEC_MODE="background" ;;
            r) OPT_RESTORE=1 ;;
            \?) handle_error 100 "Option invalide: -$OPTARG" ;;
            :) handle_error 101 "L'option -$OPTARG requiert un argument." ;;
        esac
    done
    shift $((OPTIND -1))

    initialize_application_directories

    local main_command="$1"
    if [ -z "${main_command}" ]; then display_help; exit 0; fi
    shift
    SCRIPT_ARGS=("$@")

    log_message "DEBUG" "Commande: '${main_command}', Mode Exec global: '${OPT_EXEC_MODE}', Restore: '${OPT_RESTORE}', Args: [${SCRIPT_ARGS[*]}]"
    if [[ ${OPT_RESTORE} -eq 1 ]] && [[ "${main_command}" != "restore-settings" ]]; then
        log_message "WARNING" "Option -r ignorée (pour 'restore-settings' uniquement)."
    fi

    case "${main_command}" in
        add)                add_script "${SCRIPT_ARGS[@]}" ;;
        list)               list_scripts ;;
        show)               show_script_content "${SCRIPT_ARGS[0]}" ;;
        remove)             remove_script "${SCRIPT_ARGS[0]}" ;;
        run)                run_script "${SCRIPT_ARGS[0]}" "${SCRIPT_ARGS[@]:1}" ;; # OPT_EXEC_MODE s'applique
        run-sequence)       run_sequence "${SCRIPT_ARGS[@]}" ;; # OPT_EXEC_MODE s'applique à chaque script
        run-parallel)       run_parallel "${SCRIPT_ARGS[@]}" ;; # OPT_EXEC_MODE s'applique à chaque script
        schedule)           handle_schedule_command "${SCRIPT_ARGS[0]}" "${SCRIPT_ARGS[@]:1}" ;;
        check-schedule)     check_and_run_schedules ;;
        restore-settings)   restore_default_settings ;;
        help)               display_help_extended "${SCRIPT_ARGS[0]}" ;;
        *)                  handle_error 100 "Commande inconnue: '${main_command}'" ;;
    esac

    log_message "DEBUG" "Exécution de BashOrchestrator terminée pour '${main_command}'."
    exit 0
}

# --- Implémentation des Fonctions de Commande Spécifiques ---
add_script() {
    local script_path_original="$1"; local alias_name="$2"
    log_message "DEBUG" "Cmd 'add': path='${script_path_original}', alias='${alias_name}'"
    if [ -z "${script_path_original}" ]; then handle_error 120 "Chemin script manquant."; fi
    if [ ! -f "${script_path_original}" ]; then handle_error 121 "Fichier script '${script_path_original}' non trouvé."; fi
    if [ ! -r "${script_path_original}" ]; then handle_error 122 "Fichier script '${script_path_original}' non lisible."; fi
    if [ -z "${alias_name}" ]; then
        alias_name=$(basename "${script_path_original}"); alias_name="${alias_name%.*}"
        log_message "INFOS" "Alias auto-généré: '${alias_name}' pour ${script_path_original}"
    fi
    if ! [[ "${alias_name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then handle_error 123 "Alias '${alias_name}' invalide."; fi
    if [ -f "${SCRIPT_REGISTRY_FILE}" ] && grep -q "^${alias_name}:" "${SCRIPT_REGISTRY_FILE}"; then
        handle_error 124 "Alias '${alias_name}' existe déjà."
    fi
    local target_script_filename="${alias_name}.sh"
    local target_script_path="${MANAGED_SCRIPTS_DIR}/${target_script_filename}"
    if ! cp "${script_path_original}" "${target_script_path}"; then handle_error 125 "Échec copie vers ${target_script_path}."; fi
    if ! chmod u+x "${target_script_path}"; then log_message "WARNING" "Impossible de rendre ${target_script_path} exécutable."; fi
    echo "${alias_name}:${script_path_original}:${target_script_path}:$(date '+%Y-%m-%d %H:%M:%S')" >> "${SCRIPT_REGISTRY_FILE}"
    echo "Script '${script_path_original}' ajouté avec succès sous l'alias '${alias_name}'."
    log_message "INFOS" "Script '${script_path_original}' ajouté (alias: '${alias_name}', géré: ${target_script_path})."
}

list_scripts() {
    log_message "INFOS" "Exécution de la commande 'list'."
    if [ ! -s "${SCRIPT_REGISTRY_FILE}" ]; then
        echo "  Aucun script n'est actuellement enregistré."; log_message "INFOS" "Aucun script à lister."; return;
    fi
    local separator_list="----------------------------------------------------------------------------------------------------"
    printf "  %-20s | %-50s | %-19s\n" "ALIAS" "CHEMIN ORIGINAL" "DATE D'AJOUT"; echo "${separator_list}"
    awk -F':' '{ printf "  %-20s | %-50s | %-19s\n", $1, $2, $4 }' "${SCRIPT_REGISTRY_FILE}"; echo "${separator_list}"
    log_message "INFOS" "Liste des scripts affichée à l'utilisateur."
}

show_script_content() {
    local alias_name="$1"; log_message "DEBUG" "Cmd 'show': alias='${alias_name}'"
    if [ -z "${alias_name}" ]; then handle_error 130 "Alias manquant pour 'show'."; fi
    local managed_path; managed_path=$(find_script_by_alias "${alias_name}")
    if [ -z "${managed_path}" ]; then handle_error 131 "Alias '${alias_name}' non trouvé."; fi
    if [ ! -f "${managed_path}" ]; then handle_error 132 "Fichier pour alias '${alias_name}' (${managed_path}) non trouvé."; fi
    log_message "INFOS" "Affichage contenu script '${alias_name}' demandé."
    echo "==================== Contenu de [${alias_name}] ===================="; cat "${managed_path}"; echo "==================== Fin du contenu de [${alias_name}] ===================="
}

remove_script() {
    local alias_name="$1"; log_message "DEBUG" "Cmd 'remove': alias='${alias_name}'"
    if [ -z "${alias_name}" ]; then handle_error 140 "Alias manquant pour 'remove'."; fi
    local managed_path; managed_path=$(find_script_by_alias "${alias_name}")
    if [ -z "${managed_path}" ]; then handle_error 141 "Alias '${alias_name}' non trouvé pour suppression."; fi
    local confirmation; read -r -p "Supprimer script '${alias_name}' (${managed_path})? (oui/NON): " confirmation
    log_message "DEBUG" "Confirmation suppression '${alias_name}': '${confirmation}'"
    if [[ "$(echo "${confirmation}" | tr '[:upper:]' '[:lower:]')" != "oui" ]]; then
        echo "Suppression de '${alias_name}' annulée."; log_message "INFOS" "Suppression de '${alias_name}' annulée."; exit 0;
    fi
    local temp_registry="${SCRIPT_REGISTRY_FILE}.tmp.${RANDOM}"
    if grep -v "^${alias_name}:" "${SCRIPT_REGISTRY_FILE}" > "${temp_registry}"; then
        if ! mv "${temp_registry}" "${SCRIPT_REGISTRY_FILE}"; then handle_error 142 "Échec MàJ registre pour '${alias_name}'."; fi
    else log_message "WARNING" "grep échec pour '${alias_name}'."; fi
    if [ -f "${managed_path}" ]; then
        if ! rm "${managed_path}"; then log_message "ERROR" "Échec suppression fichier ${managed_path}."; fi
    else log_message "WARNING" "Fichier ${managed_path} non trouvé pour suppression."; fi
    echo "Script '${alias_name}' supprimé."; log_message "INFOS" "Script '${alias_name}' supprimé."
}

restore_default_settings() {
    log_message "DEBUG" "Cmd 'restore-settings': OPT_RESTORE=${OPT_RESTORE}"
    if [[ ${OPT_RESTORE} -ne 1 ]]; then handle_error 150 "Cmd 'restore-settings' nécessite -r."; fi
    if [[ $EUID -ne 0 ]]; then log_message "WARNING" "Restauration sans sudo. Certaines actions pourraient échouer si -l pointe vers un dir système."; fi
    local confirmation; read -r -p "ATTENTION: Réinitialisation des fichiers locaux. Continuer? (oui/NON): " confirmation
    log_message "DEBUG" "Confirmation restauration: '${confirmation}'"
    if [[ "$(echo "${confirmation}" | tr '[:upper:]' '[:lower:]')" != "oui" ]]; then
        echo "Restauration annulée."; log_message "INFOS" "Restauration annulée."; exit 0;
    fi
    log_message "INFOS" "Début restauration (fichiers locaux)..."
    rm -f "${SCRIPT_REGISTRY_FILE}" && touch "${SCRIPT_REGISTRY_FILE}" || log_message "ERROR" "Échec réinit ${SCRIPT_REGISTRY_FILE}."
    rm -f "${SCHEDULES_FILE}" && touch "${SCHEDULES_FILE}" || log_message "ERROR" "Échec réinit ${SCHEDULES_FILE}."
    if [ -d "${MANAGED_SCRIPTS_DIR}" ]; then
        log_message "INFOS" "Suppression scripts dans ${MANAGED_SCRIPTS_DIR}..."
        find "${MANAGED_SCRIPTS_DIR}" -type f -name "*.sh" -print -delete
    fi
    echo "Restauration des paramètres terminée."; log_message "INFOS" "Restauration (fichiers locaux) terminée."
}

# --- Point d'Entrée du Script ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi