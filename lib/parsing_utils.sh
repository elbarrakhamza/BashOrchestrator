#!/bin/bash

# lib/parsing_utils.sh

# ... (find_script_by_alias, generate_schedule_id comme avant) ...
find_script_by_alias() {
    local alias_name_to_find="$1"
    if [ -z "${alias_name_to_find}" ]; then log_message "DEBUG" "find_by_alias: alias vide."; return 1; fi
    if [ ! -f "${SCRIPT_REGISTRY_FILE}" ]; then log_message "DEBUG" "find_by_alias: Registre ${SCRIPT_REGISTRY_FILE} non trouvé."; return 1; fi
    local found_managed_path; found_managed_path=$(awk -F':' -v alias_awk="${alias_name_to_find}" '$1 == alias_awk { print $3; exit }' "${SCRIPT_REGISTRY_FILE}")
    if [ -n "${found_managed_path}" ]; then
        if [ -f "${found_managed_path}" ]; then echo "${found_managed_path}"; return 0;
        else log_message "WARNING" "find_by_alias: Alias '${alias_name_to_find}' dans registre mais fichier ${found_managed_path} introuvable."; return 1; fi
    else return 1; fi
}
generate_schedule_id() { date +%s%N"$RANDOM" | sha256sum | cut -c1-8; }

add_schedule_entry() {
    local script_alias_sched=""
    local exec_time_sched=""    # HH:MM
    local exec_date_sched="*"   # YYYY-MM-DD ou * (défaut à *)
    local exec_days_sched="*"   # Mon,Tue,... ou * (défaut à *)
    local on_success_alias_sched="NONE"
    local schedule_id

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --script) script_alias_sched="$2"; shift 2 ;;
            --time) exec_time_sched="$2"; shift 2 ;;
            --date) exec_date_sched="$2"; shift 2 ;;
            --days) exec_days_sched="$2"; shift 2 ;;
            --on-success) on_success_alias_sched="$2"; shift 2 ;;
            *) log_message "WARNING" "add_schedule_entry: Argument inconnu '$1'"; shift ;;
        esac
    done

    if [ -z "${script_alias_sched}" ] || [ -z "${exec_time_sched}" ]; then
        log_message "ERROR" "Planification: --script <alias> et --time \"HH:MM\" sont obligatoires."; return 1;
    fi
    # ... (Autres validations comme avant) ...
    if ! find_script_by_alias "${script_alias_sched}" >/dev/null; then log_message "ERROR" "Planification: Script '${script_alias_sched}' non trouvé."; return 1; fi
    if [[ "${on_success_alias_sched}" != "NONE" ]] && ! find_script_by_alias "${on_success_alias_sched}" >/dev/null; then log_message "ERROR" "Planification: Script on-success '${on_success_alias_sched}' non trouvé."; return 1; fi
    if ! [[ "${exec_time_sched}" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then log_message "ERROR" "Planification: Format heure '${exec_time_sched}' invalide (HH:MM)."; return 1; fi
    if [[ "${exec_date_sched}" != "*" ]] && ! date -d "${exec_date_sched}" "+%Y-%m-%d" &>/dev/null; then
        log_message "ERROR" "Planification: Format date '${exec_date_sched}' invalide (YYYY-MM-DD ou '*')."; return 1;
    fi
    if [[ -z "${exec_days_sched}" ]]; then exec_days_sched="*"; fi # S'assurer d'une valeur par défaut
    if [[ -z "${exec_date_sched}" ]]; then exec_date_sched="*"; fi # S'assurer d'une valeur par défaut

    schedule_id=$(generate_schedule_id)
    # Nouveau format: id:alias:heure:date:jours:on_success:last_status:last_run_datetime
    local new_schedule_line="${schedule_id}:${script_alias_sched}:${exec_time_sched}:${exec_date_sched}:${exec_days_sched}:${on_success_alias_sched}:PENDING:NEVER_RUN"
    
    if echo "${new_schedule_line}" >> "${SCHEDULES_FILE}"; then
        log_message "INFOS" "Planification (ID: ${schedule_id}) ajoutée pour '${script_alias_sched}' à ${exec_time_sched} (date: ${exec_date_sched}, jours: ${exec_days_sched})."
    else
        log_message "ERROR" "Échec écriture nouvelle planification dans ${SCHEDULES_FILE}."; return 1;
    fi
}

list_schedules() {
    log_message "INFOS" "Exécution de la commande 'schedule list'."
    if [ ! -s "${SCHEDULES_FILE}" ]; then
        echo "  Aucune tâche n'est actuellement planifiée."; log_message "INFOS" "Aucune planification à lister."; return;
    fi
    
    local header_sched
    # Ajout de la colonne DATE
    header_sched=$(printf "  %-10s | %-18s | %-8s | %-11s | %-11s | %-18s | %-10s | %-19s" \
           "ID" "SCRIPT (ALIAS)" "HEURE" "DATE" "JOURS" "SUIVANT (SI SUCCÈS)" "STATUT" "DERNIÈRE EXÉC.")
    local separator_sched # Ajuster la longueur pour la nouvelle colonne
    separator_sched="---------------------------------------------------------------------------------------------------------------------------------------------------"

    # Affichage direct au terminal
    echo "${separator_sched}"; echo "${header_sched}"; echo "${separator_sched}"
    # Lecture du nouveau format (8 champs)
    awk -F':' '{ printf "  %-10s | %-18s | %-8s | %-11s | %-11s | %-18s | %-10s | %s\n", $1, $2, $3, $4, $5, $6, $7, $8 }' "${SCHEDULES_FILE}"
    echo "${separator_sched}"
    log_message "INFOS" "Liste des planifications affichée à l'utilisateur."
}

# ... (remove_schedule_entry et update_schedule_status doivent être adaptés au nouveau format à 8 champs)
remove_schedule_entry() {
    local schedule_id_to_remove="$1"; log_message "DEBUG" "Suppression planif ID: '${schedule_id_to_remove}'"
    if [ -z "${schedule_id_to_remove}" ]; then log_message "ERROR" "ID planif manquant pour remove."; return 1; fi
    if ! grep -q "^${schedule_id_to_remove}:" "${SCHEDULES_FILE}"; then log_message "ERROR" "Planif ID '${schedule_id_to_remove}' non trouvée."; return 1; fi
    local temp_schedules_file="${SCHEDULES_FILE}.tmp.${RANDOM}"
    if grep -v "^${schedule_id_to_remove}:" "${SCHEDULES_FILE}" > "${temp_schedules_file}"; then
        if mv "${temp_schedules_file}" "${SCHEDULES_FILE}"; then log_message "INFOS" "Planif ID '${schedule_id_to_remove}' supprimée.";
        else log_message "ERROR" "Échec MàJ ${SCHEDULES_FILE} après suppression ID '${schedule_id_to_remove}'. Temp: ${temp_schedules_file}."; return 1; fi
    else log_message "ERROR" "Échec filtrage ${SCHEDULES_FILE} pour supprimer ID '${schedule_id_to_remove}'."; rm -f "${temp_schedules_file}"; return 1; fi
}

update_schedule_status() {
    local schedule_id_to_update="$1"; local new_run_status="$2"; local current_datetime; current_datetime=$(date '+%Y-%m-%d %H:%M:%S')
    log_message "DEBUG" "MàJ statut planif ID '${schedule_id_to_update}' à '${new_run_status}' (date: ${current_datetime})"
    if [ ! -f "${SCHEDULES_FILE}" ]; then log_message "ERROR" "Fichier ${SCHEDULES_FILE} non trouvé pour MàJ statut."; return 1; fi
    local temp_schedules_file="${SCHEDULES_FILE}.tmp.${RANDOM}"; local updated_flag=0
    while IFS= read -r line || [ -n "$line" ]; do
        local line_id; line_id=$(echo "$line" | cut -d':' -f1)
        if [[ "${line_id}" == "${schedule_id_to_update}" ]]; then
            local old_alias old_time old_date old_days old_next_alias # old_status old_date (non utilisés ici)
            # Nouveau format: id:alias:heure:date:jours:on_success:status_dernier_run:date_dernier_run
            IFS=':' read -r _ old_alias old_time old_date old_days old_next_alias _ _ <<< "$line"
            echo "${line_id}:${old_alias}:${old_time}:${old_date}:${old_days}:${old_next_alias}:${new_run_status}:${current_datetime}" >> "${temp_schedules_file}"
            updated_flag=1
        else echo "$line" >> "${temp_schedules_file}"; fi
    done < "${SCHEDULES_FILE}"
    if [[ ${updated_flag} -eq 1 ]]; then
        if mv "${temp_schedules_file}" "${SCHEDULES_FILE}"; then log_message "DEBUG" "Statut planif ID '${schedule_id_to_update}' mis à jour.";
        else log_message "ERROR" "Échec remplacement ${SCHEDULES_FILE} avec ${temp_schedules_file}."; rm -f "${temp_schedules_file}"; return 1; fi
    else log_message "WARNING" "Planif ID '${schedule_id_to_update}' non trouvée pour MàJ statut."; rm -f "${temp_schedules_file}"; return 1; fi
}