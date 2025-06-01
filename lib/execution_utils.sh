#!/bin/bash

# lib/execution_utils.sh

# ... (run_script comme dans la version 0.9.0 / ou votre dernière version fonctionnelle avec affichage terminal des sorties enfants)
run_script() {
    local alias_name_run="$1"; shift; local script_specific_args_run=("$@")
    local script_path_run; local exit_code_run=0
    local start_time_epoch=$(date '+%s'); local start_time_readable=$(date '+%Y-%m-%d %H:%M:%S' -d "@${start_time_epoch}")
    # Utiliser la variable globale OPT_EXEC_MODE ici
    local current_exec_mode="${OPT_EXEC_MODE:-fork}" # fork si vide

    log_message "DEBUG" "run_script: alias '${alias_name_run}' mode '${current_exec_mode}' args [${script_specific_args_run[*]}]"
    if [ -z "${alias_name_run}" ]; then log_message "ERROR" "run_script: Alias manquant."; return 160; fi
    script_path_run=$(find_script_by_alias "${alias_name_run}")
    if [ -z "${script_path_run}" ]; then log_message "ERROR" "run_script: Alias '${alias_name_run}' non trouvé."; return 161; fi
    if [ ! -x "${script_path_run}" ]; then
        log_message "WARNING" "run_script: '${script_path_run}' non exécutable. Tentative chmod..."
        if ! chmod u+x "${script_path_run}"; then log_message "ERROR" "run_script: chmod échec pour '${script_path_run}'."; return 162; fi
    fi
    log_message "INFOS" "Début exécution script '${alias_name_run}' (${script_path_run}) à ${start_time_readable} (mode: ${current_exec_mode})"
    local script_stdout_temp_file=$(mktemp "${TMPDIR:-/tmp}/${APP_NAME:-Bo}_stdout.XXXXXX")
    local script_stderr_temp_file=$(mktemp "${TMPDIR:-/tmp}/${APP_NAME:-Bo}_stderr.XXXXXX")
    case "${current_exec_mode}" in # Utilise current_exec_mode
        subshell)
            log_message "DEBUG" "run_script: '${alias_name_run}' en subshell."
            ( "${script_path_run}" "${script_specific_args_run[@]}" >"${script_stdout_temp_file}" 2>"${script_stderr_temp_file}" )
            exit_code_run=$? ;;
        background)
            log_message "DEBUG" "run_script: '${alias_name_run}' en arrière-plan."
            "${script_path_run}" "${script_specific_args_run[@]}" >"${script_stdout_temp_file}" 2>"${script_stderr_temp_file}" &
            local script_pid=$!; log_message "INFOS" "Script '${alias_name_run}' lancé en bg (PID: ${script_pid})."
            exit_code_run=0
            # ... (rapport de lancement bg comme avant) ...
            local report_timestamp_bg=$(date '+%Y%m%d_%H%M%S'); local eff_reports_dir_bg="${OPT_LOG_DIR}/${REPORTS_SUBDIR}"
            local report_file_path_bg="${eff_reports_dir_bg}/report_${alias_name_run}_launched_${report_timestamp_bg}.txt"
            if [ -d "${eff_reports_dir_bg}" ] && [ -w "${eff_reports_dir_bg}" ]; then
                { echo "RAPPORT (LANCEMENT BG)"; echo "Alias: ${alias_name_run}"; echo "Mode: background";
                  echo "Lancé: ${start_time_readable}"; echo "PID: ${script_pid}";
                  # ... (autres détails)
                } > "${report_file_path_bg}"; log_message "INFOS" "Rapport lancement bg pour '${alias_name_run}' généré: ${report_file_path_bg}";
            else log_message "WARNING" "Impossible de générer rapport lancement bg pour '${alias_name_run}'."; fi
            ;;
        fork|*) # fork ou mode normal (défaut)
            log_message "DEBUG" "run_script: '${alias_name_run}' en mode fork/normal."
            "${script_path_run}" "${script_specific_args_run[@]}" >"${script_stdout_temp_file}" 2>"${script_stderr_temp_file}"
            exit_code_run=$? ;;
    esac
    local end_time_epoch=$(date '+%s'); local end_time_readable=$(date '+%Y-%m-%d %H:%M:%S' -d "@${end_time_epoch}")
    local duration_secs=$((end_time_epoch - start_time_epoch))
    # Affichage terminal des sorties enfants + log fichier (selon votre préférence)
    if [ -s "${script_stdout_temp_file}" ]; then
        # Afficher sur le terminal de l'orchestrateur
        cat "${script_stdout_temp_file}"
        # Logguer dans history.log
        log_message "INFOS" "[${alias_name_run}] Début STDOUT script enfant:"; 
        while IFS= read -r line; do log_message "INFOS" "[${alias_name_run}] STDOUT: ${line}"; done < "${script_stdout_temp_file}";
        log_message "INFOS" "[${alias_name_run}] Fin STDOUT script enfant.";
    fi
    if [ -s "${script_stderr_temp_file}" ]; then
        # Afficher sur le terminal de l'orchestrateur (stderr)
        cat "${script_stderr_temp_file}" >&2
        # Logguer dans history.log
        log_message "ERROR" "[${alias_name_run}] Début STDERR script enfant:"; 
        while IFS= read -r line; do log_message "ERROR" "[${alias_name_run}] STDERR: ${line}"; done < "${script_stderr_temp_file}";
        log_message "ERROR" "[${alias_name_run}] Fin STDERR script enfant.";
    fi
    # Rapport (sauf si background)
    if [[ "${current_exec_mode}" != "background" ]]; then # Utilise current_exec_mode
        local report_timestamp_fg=$(date '+%Y%m%d_%H%M%S'); local eff_reports_dir_fg="${OPT_LOG_DIR}/${REPORTS_SUBDIR}"
        local report_file_path_fg="${eff_reports_dir_fg}/report_${alias_name_run}_${report_timestamp_fg}.txt"
        if [ -d "${eff_reports_dir_fg}" ] && [ -w "${eff_reports_dir_fg}" ]; then
            { echo "RAPPORT D'EXÉCUTION"; echo "Alias: ${alias_name_run}"; echo "Mode: ${current_exec_mode}";
              # ... (autres détails du rapport)
              echo "Début: ${start_time_readable}"; echo "Fin: ${end_time_readable}";
              echo "Durée: ${duration_secs}s"; echo "Code Sortie: ${exit_code_run}"; echo "Statut: $(if [ ${exit_code_run} -eq 0 ]; then echo SUCCES; else echo ECHEC; fi)";
              echo "--- STDOUT ---"; cat "${script_stdout_temp_file}"; echo "--- STDERR ---"; cat "${script_stderr_temp_file}"; echo "Fin Rapport.";
            } > "${report_file_path_fg}"; log_message "INFOS" "Rapport pour '${alias_name_run}' généré: ${report_file_path_fg}";
        else log_message "WARNING" "Impossible de générer rapport pour '${alias_name_run}'."; fi
    fi
    rm -f "${script_stdout_temp_file}" "${script_stderr_temp_file}"
    if [[ "${current_exec_mode}" != "background" ]]; then
        if [ ${exit_code_run} -eq 0 ]; then log_message "INFOS" "Script '${alias_name_run}' terminé succès (code: ${exit_code_run}).";
        else log_message "ERROR" "Script '${alias_name_run}' terminé erreur (code: ${exit_code_run})."; fi
    fi
    return ${exit_code_run}
}

run_sequence() {
    local aliases_to_run_sequence=("$@")
    local overall_status=0; local previous_alias="START"
    if [ ${#aliases_to_run_sequence[@]} -eq 0 ]; then handle_error 175 "Aucun alias pour 'run-sequence'."; fi

    log_message "INFOS" "Lancement séquence: [${aliases_to_run_sequence[*]}] (Mode global: '${OPT_EXEC_MODE:-normal}')"
    # L'option OPT_EXEC_MODE globale s'appliquera à chaque script de la séquence via run_script

    for alias_rs in "${aliases_to_run_sequence[@]}"; do
        log_message "INFOS" "Séquence: Exécution de '${alias_rs}' (après '${previous_alias}')."
        # run_script utilise la variable globale OPT_EXEC_MODE pour son mode d'exécution
        if run_script "${alias_rs}"; then # Pas d'arguments spécifiques passés aux scripts dans la séquence ici
            log_message "INFOS" "Séquence: Script '${alias_rs}' terminé avec succès."
            previous_alias="${alias_rs}"
        else
            local exit_c=$?
            log_message "ERROR" "Séquence: Script '${alias_rs}' a échoué (code: ${exit_c}). Arrêt de la séquence."
            overall_status=1; break;
        fi
    done
    if [[ ${overall_status} -eq 0 ]]; then log_message "INFOS" "Séquence terminée avec succès.";
    else log_message "ERROR" "Séquence interrompue par une erreur."; fi
    return ${overall_status}
}

run_parallel() {
    local aliases_to_run_parallel=("$@")
    local pids_parallel=()
    if [ ${#aliases_to_run_parallel[@]} -eq 0 ]; then handle_error 170 "Aucun alias pour 'run-parallel'."; fi

    # OPT_EXEC_MODE global (-f, -s, -t) sera utilisé par chaque run_script.
    # Pour un vrai parallélisme, l'utilisateur devrait probablement utiliser -t avec run-parallel.
    # Si -f ou -s est utilisé, chaque `run_script` s'exécutera dans ce mode, mais le `&` ci-dessous
    # mettra le processus *parent* (qui appelle run_script) en arrière-plan.
    log_message "INFOS" "Lancement parallèle: [${aliases_to_run_parallel[*]}] (Mode global pour enfants: '${OPT_EXEC_MODE:-normal}')"

    for alias_rp in "${aliases_to_run_parallel[@]}"; do
        # Chaque run_script est lancé en arrière-plan pour le parallélisme des lancements.
        # run_script utilisera la variable globale OPT_EXEC_MODE pour exécuter le script final.
        (
            # Isoler OPT_EXEC_MODE pour chaque enfant si nécessaire,
            # mais ici, run_script lit la variable globale.
            run_script "${alias_rp}"
            # Le code de sortie du subshell ici est celui de run_script
        ) &
        pids_parallel+=($!)
    done

    local overall_launch_status=0; local child_errors=0
    for pid_rp_wrapper in "${pids_parallel[@]}"; do
        if wait "${pid_rp_wrapper}"; then
            log_message "DEBUG" "Processus wrapper parallèle (PID: ${pid_rp_wrapper}) terminé."
        else
            log_message "ERROR" "Un processus wrapper parallèle (PID: ${pid_rp_wrapper}) a signalé une erreur (le script enfant a peut-être échoué)."
            overall_launch_status=1 # Indique un problème avec au moins un des scripts.
            child_errors=$((child_errors + 1))
        fi
    done

    if [[ ${overall_launch_status} -eq 0 ]]; then
        log_message "INFOS" "Tous les scripts pour 'run-parallel' ont été lancés et terminés (ou sont en bg si -t). Vérifiez les rapports."
    else
        log_message "ERROR" "${child_errors} script(s) de 'run-parallel' ont rencontré des erreurs ou ont été lancés avec erreur."
    fi
    return ${overall_launch_status}
}


handle_schedule_command() {
    local sub_command_sched="$1"; shift; local sub_args_sched=("$@")
    log_message "DEBUG" "Cmd 'schedule', sous-cmd: '${sub_command_sched}', args: [${sub_args_sched[*]}]"
    case "${sub_command_sched}" in
        add) add_schedule_entry "${sub_args_sched[@]}" ;;
        list) list_schedules ;;
        remove) if [ -z "${sub_args_sched[0]}" ]; then handle_error 180 "ID planif manquant."; fi; remove_schedule_entry "${sub_args_sched[0]}" ;;
        check) log_message "INFOS" "'schedule check' appelé."; check_and_run_schedules ;;
        *) handle_error 181 "Sous-cmd '${sub_command_sched}' inconnue pour 'schedule'." ;;
    esac
}

check_and_run_schedules() {
    log_message "INFOS" "Début vérification tâches planifiées..."
    if [ ! -f "${SCHEDULES_FILE}" ] || [ ! -s "${SCHEDULES_FILE}" ]; then
        log_message "INFOS" "Aucune tâche planifiée."; return 0;
    fi

    local current_time_hm=$(date '+%H:%M')
    local current_date_ymd=$(date '+%Y-%m-%d')
    local current_day_abbrev=$(LC_TIME=C date '+%a')

    local original_exec_mode_sched="${OPT_EXEC_MODE}"; OPT_EXEC_MODE="" # Mode normal par défaut pour scripts planifiés

    local line_sched; local tasks_run_this_cycle=0
    # Nouveau format: id:alias:heure:date:jours:on_success:status_dernier_run:date_dernier_run
    while IFS= read -r line_sched || [ -n "$line_sched" ]; do
        log_message "DEBUG" "Vérif planif: ${line_sched}"
        local s_id s_alias s_time s_date s_days s_next_alias s_last_status s_last_run_date_str
        IFS=':' read -r s_id s_alias s_time s_date s_days s_next_alias s_last_status s_last_run_date_str <<< "$line_sched"

        # 1. Vérifier date (si pas *)
        if [[ "${s_date}" != "*" ]] && [[ "${s_date}" != "${current_date_ymd}" ]]; then
            # log_message "DEBUG" "Tâche ${s_id}: Date ${s_date} != ${current_date_ymd}. Saut."
            continue
        fi
        log_message "DEBUG" "Tâche ${s_id}: Correspondance date (${s_date})."

        # 2. Vérifier heure
        if [[ "${s_time}" != "${current_time_hm}" ]]; then continue; fi
        log_message "DEBUG" "Tâche ${s_id}: Correspondance heure (${s_time})."

        # 3. Vérifier jour de la semaine (si pas *)
        if [[ "${s_days}" != "*" ]]; then
            local day_matches_sched=0; local days_array_sched
            IFS=',' read -r -a days_array_sched <<< "${s_days}"
            for day_in_schedule_sched in "${days_array_sched[@]}"; do
                if [[ "$(echo "${current_day_abbrev}" | tr '[:upper:]' '[:lower:]' | cut -c1-3)" == \
                      "$(echo "${day_in_schedule_sched}" | tr '[:upper:]' '[:lower:]' | cut -c1-3)" ]]; then
                    day_matches_sched=1; break;
                fi
            done
            if [[ ${day_matches_sched} -eq 0 ]]; then continue; fi
        fi
        log_message "DEBUG" "Tâche ${s_id}: Correspondance jour ([${s_days}])."
        
        # 4. Anti-répétition
        local last_run_date_part=""; local last_run_time_part=""
        if [[ "${s_last_run_date_str}" != "NEVER_RUN" ]]; then
            last_run_date_part=$(echo "${s_last_run_date_str}" | cut -d' ' -f1)
            if [[ "${s_last_run_date_str}" == *" "* ]]; then
                 last_run_time_part=$(echo "${s_last_run_date_str}" | cut -d' ' -f2 | cut -d':' -f1,2)
            fi
        fi
        if [[ "${last_run_date_part}" == "${current_date_ymd}" ]] && \
           [[ "${last_run_time_part}" == "${current_time_hm}" ]]; then
            log_message "DEBUG" "Tâche ${s_id}: Déjà exécutée aujourd'hui à ${s_time}. Saut."
            continue
        fi
        log_message "DEBUG" "Tâche ${s_id}: Prête à exécution (dernière: ${s_last_run_date_str})."

        log_message "INFOS" "Déclenchement tâche planifiée ID: ${s_id} pour script: ${s_alias}"
        tasks_run_this_cycle=$((tasks_run_this_cycle + 1))

        # run_script utilisera OPT_EXEC_MODE qui est "" (normal/fork) ici.
        if run_script "${s_alias}"; then
            update_schedule_status "${s_id}" "SUCCESS"
            log_message "INFOS" "Tâche planifiée ID '${s_id}' ('${s_alias}') SUCCÈS."
            if [ -n "${s_next_alias}" ] && [ "${s_next_alias}" != "NONE" ]; then
                log_message "INFOS" "Tâche ID '${s_id}': Exécution on-success '${s_next_alias}'..."
                # OPT_EXEC_MODE pour on-success est aussi normal/fork
                if run_script "${s_next_alias}"; then log_message "INFOS" "Tâche ID '${s_id}': on-success '${s_next_alias}' SUCCÈS.";
                else log_message "ERROR" "Tâche ID '${s_id}': on-success '${s_next_alias}' ÉCHEC (code $?)."; fi
            fi
        else
            local last_exit_code=$? 
            update_schedule_status "${s_id}" "FAILURE"
            log_message "ERROR" "Tâche planifiée ID '${s_id}' ('${s_alias}') ÉCHEC (code ${last_exit_code})."
        fi
    done < "${SCHEDULES_FILE}"
    OPT_EXEC_MODE="${original_exec_mode_sched}" 
    if [[ ${tasks_run_this_cycle} -gt 0 ]]; then log_message "INFOS" "${tasks_run_this_cycle} tâche(s) traitée(s).";
    else log_message "INFOS" "Aucune tâche due pour exécution."; fi
    log_message "INFOS" "Vérification tâches planifiées terminée."
}