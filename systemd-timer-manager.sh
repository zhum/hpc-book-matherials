#!/usr/bin/env bash

# Schedule or show systemd user/system timers

set -euo pipefail

####### Color Definitions for UI #######
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

####### Defaults & Configuration #######
USE_USER_SPACE=true # Default to --user level systemd timers (no sudo needed)
TIMER_NAME=""
COMMAND_TO_RUN=""
SCHEDULE=""
DESCRIPTION="Type a description here"
WORKING_DIR="/tmp"
RUN_AS_USER="root"
ACTION="create" # create or list
SHOW_SCHEDULE=false # In list mode, show schedule instead of last run time
MAX_COL_WIDTH=40 # Max width for schedule column in list view

####### Help Menu #######
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

A utility to schedule commands or scripts as systemd timers, or list active ones.
If no arguments are provided, the script runs in interactive mode.

Options:
  -n, --name NAME         Unique name for the timer (alphanumeric, dashes, underscores).
  -c, --command CMD       The exact command or script path to execute.
  -s, --schedule SCHED    Systemd OnCalendar expression (e.g., "daily", "hourly", "*-*-* 00:00:00", "Mon..Fri 09:00").
  -d, --description DESC  Optional description for the systemd service.
  -w, --workdir DIR       Working directory for the command (default: /tmp).
  -u, --user USER         User to run the command as (only valid with --global, default: root).
  -g, --global            Run as system-wide timer (requires sudo/root permissions).
  -l, --list              List all configured systemd timers in a clean table.
  -S, --show-schedule     In list view, show the timer schedule (OnCalendar) instead of last execution time.
  -h, --help              Show this help message.

Examples:
  $(basename "$0") -n "db-backup" -c "/usr/local/bin/backup.sh" -s "daily" -w "/home/user/backups"
  $(basename "$0") -n "cleanup-tmp" -c "rm -rf /tmp/my-app/*" -s "hourly" -g -u "www-data"
  $(basename "$0") --list -S
  $(basename "$0")  # Starts interactive mode
EOF
}

####### Parse Arguments #######
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                TIMER_NAME="$2"
                shift 2
                ;;
            -c|--command)
                COMMAND_TO_RUN="$2"
                shift 2
                ;;
            -s|--schedule)
                SCHEDULE="$2"
                shift 2
                ;;
            -d|--description)
                DESCRIPTION="$2"
                shift 2
                ;;
            -w|--workdir)
                WORKING_DIR="$2"
                shift 2
                ;;
            -u|--user)
                RUN_AS_USER="$2"
                shift 2
                ;;
            -g|--global)
                USE_USER_SPACE=false
                shift
                ;;
            -l|--list)
                ACTION="list"
                shift
                ;;
            -S|--show-schedule)
                SHOW_SCHEDULE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

####### Format and List Timers as a Table #######
list_timers() {
    local cmd_prefix="systemctl --user"
    local scope_label="User Timers"
    
    if [ "$USE_USER_SPACE" = false ]; then
        cmd_prefix="sudo systemctl"
        scope_label="System-wide Timers"
    fi

    echo -e "${BLUE}=== Active Timers (${scope_label}) ===${NC}\n"

    # Verify systemctl is available
    if ! command -v systemctl &> /dev/null; then
        echo -e "${RED}Error: systemctl is not available on this system.${NC}"
        exit 1
    fi

    # Retrieve all timers without legend/pager
    local raw_timers
    raw_timers=$(eval "$cmd_prefix list-timers --all --no-legend --no-pager" 2>/dev/null || true)

    if [[ -z "$raw_timers" ]]; then
        echo -e "${YELLOW}No active systemd timers found under this scope.${NC}"
        return
    fi

    # We collect row data into an array to pre-calculate lengths
    local timer_rows=()
    local max_sched_len=16

    while read -r line; do
        # Strip leading/trailing whitespaces
        line=$(echo "$line" | xargs)
        [ -z "$line" ] && continue

        # Split line into an array of fields
        read -r -a fields <<< "$line"
        local num_fields=${#fields[@]}
        
        # Ensure we have at least unit and trigger data
        if (( num_fields < 2 )); then
            continue
        fi
        
        # local service_unit="${fields[num_fields-1]}"
        local timer_unit="${fields[num_fields-2]}"
        
        # Track down indices of dates in the format YYYY-MM-DD
        local date_indices=()
        for ((i=0; i<num_fields-2; i++)); do
            if [[ "${fields[i]}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                date_indices+=( "$i" )
            fi
        done
        
        local next_date="N/A"
        local last_date="Never"
        
        if (( ${#date_indices[@]} == 2 )); then
            # Both NEXT and LAST dates are present
            local idx1=${date_indices[0]}
            local idx2=${date_indices[1]}
            next_date="${fields[idx1]} ${fields[idx1+1]:0:5}"
            last_date="${fields[idx2]} ${fields[idx2+1]:0:5}"
        elif (( ${#date_indices[@]} == 1 )); then
            local idx=${date_indices[0]}
            if [[ "${fields[0]}" == "n/a" ]]; then
                # NEXT is n/a, so the only date must be LAST
                next_date="N/A"
                last_date="${fields[idx]} ${fields[idx+1]:0:5}"
            else
                # NEXT is valid, so the only date must be NEXT
                next_date="${fields[idx]} ${fields[idx+1]:0:5}"
                last_date="Never"
            fi
        fi

        # Get description
        local desc
        desc=$(eval "$cmd_prefix show -p Description \"$timer_unit\"" 2>/dev/null | cut -d= -f2-)
        if [[ -z "$desc" ]]; then
            desc="N/A"
        fi

        local middle_column_val="$last_date"
        if [ "$SHOW_SCHEDULE" = true ]; then
            local sched="N/A"
            local show_output
            show_output=$(eval "$cmd_prefix show -p TimersCalendar \"$timer_unit\"" 2>/dev/null || "none")
            if [[ "$show_output" =~ OnCalendar=([^;\}]+) ]]; then
                sched="${BASH_REMATCH[1]}"
                sched=$(echo "$sched" | xargs)
            else
                # Fallback check for monotonic timers (e.g., OnUnitActiveSec)
                for prop in OnActiveSec OnBootSec OnStartupSec OnUnitActiveSec OnUnitInactiveSec; do
                    local val
                    val=$(eval "$cmd_prefix show -p $prop \"$timer_unit\"" 2>/dev/null | cut -d= -f2-)
                    if [[ -n "$val" && "$val" != "0" && "$val" != "n/a" ]]; then
                        sched="${prop/On/}:$val"
                        break
                    fi
                done
            fi
            middle_column_val="$sched"
            if (( ${#sched} > max_sched_len )); then
                max_sched_len=${#sched}
            fi
        fi

        # Store fields tab-separated so spaces don't break extraction
        timer_rows+=( "${next_date}	${middle_column_val}	${timer_unit}	${desc}" )
    done <<< "$raw_timers"

    # Determine dynamic column sizing for the second column
    local middle_col_width=16
    if [ "$SHOW_SCHEDULE" = true ]; then
        middle_col_width=$max_sched_len
        # Cap it at a sensible limit to protect screen spacing
        if (( middle_col_width > ${MAX_COL_WIDTH} )); then
            middle_col_width=${MAX_COL_WIDTH}
        fi
    fi

    # Determine dynamic terminal width
    local cols
    cols=$(tput cols 2>/dev/null || echo "80")
    if ! [[ "$cols" =~ ^[0-9]+$ ]] || (( cols < 80 )); then
        cols=80
    fi

    # Fixed-width columns: NEXT (16) + MIDDLE_COL (middle_col_width) + UNIT (32) + 9 (separators)
    # Re-use MAX_COL_WIDTH to ensure we don't exceed reasonable limits on smaller screens
    local fixed_width=$(( 16 + middle_col_width + 32 + 9 ))
    local desc_width=$(( cols - fixed_width ))
    if (( desc_width < 10 )); then
        desc_width=$MAX_COL_WIDTH
    fi
    local table_width=$(( fixed_width + desc_width ))

    # Render Table Header
    local separator
    separator=$(printf "%*s" "$table_width" "" | tr ' ' '-')
    
    local middle_header="LAST EXECUTION"
    if [ "$SHOW_SCHEDULE" = true ]; then
        middle_header="SCHEDULE"
    fi

    echo -e "${CYAN}${separator}${NC}"
    printf "${CYAN}%-16s | %-${middle_col_width}s | %-32s | %-${desc_width}s${NC}\n" "NEXT EXECUTION" "$middle_header" "TIMER / UNIT NAME" "DESCRIPTION"
    echo -e "${CYAN}${separator}${NC}"

    # Print table rows cleanly
    for row in "${timer_rows[@]}"; do
        IFS=$'\t' read -r r_next r_middle r_unit r_desc <<< "$row"
        
        local display_next display_middle display_unit display_desc
        display_next=$(echo "$r_next" | cut -c1-16)
        display_middle=$(echo "$r_middle" | cut -c1-"$middle_col_width")
        display_unit=$(echo "$r_unit" | cut -c1-32)
        display_desc=$(echo "$r_desc" | cut -c1-"$desc_width")

        printf "%-16s | %-${middle_col_width}s | %-32s | %-${desc_width}s\n" "$display_next" "$display_middle" "$display_unit" "$display_desc"
    done
    echo -e "${CYAN}${separator}${NC}\n"
}

####### Interactive Mode: Dialog TUI (GUI) #######
run_interactive_dialog() {
    local backtitle="Systemd Timer Scheduler"
    
    # Action
    local action_choice
    action_choice=$(dialog --backtitle "$backtitle" \
        --title "Choose Action" \
        --cancel-label "Exit" \
        --menu "What would you like to do?" 12 60 2 \
        1 "Schedule and start a new timer" \
        2 "List existing scheduled timers" \
        3>&1 1>&2 2>&3) || exit 0

    # Scope
    local scope_choice
    scope_choice=$(dialog --backtitle "$backtitle" \
        --title "Choose Scope" \
        --cancel-label "Exit" \
        --menu "Where would you like to target systemd?" 12 60 2 \
        1 "User space (Local account, no sudo)" \
        2 "System space (Requires root/sudo)" \
        3>&1 1>&2 2>&3) || exit 0
    
    if [[ "$scope_choice" == "2" ]]; then
        USE_USER_SPACE=false
    fi

    # Handle View-List Mode
    if [[ "$action_choice" == "2" ]]; then
        ACTION="list"
        local col_choice
        col_choice=$(dialog --backtitle "$backtitle" \
            --title "Column View Setup" \
            --cancel-label "Exit" \
            --menu "What would you like to display in the second column?" 12 60 2 \
            1 "Last Execution Time" \
            2 "Schedule (OnCalendar)" \
            3>&1 1>&2 2>&3) || exit 0
        if [[ "$col_choice" == "2" ]]; then
            SHOW_SCHEDULE=true
        fi
        clear
        return
    fi

    # Timer Name
    while true; do
        local input_name
        input_name=$(dialog --backtitle "$backtitle" \
            --title "Timer Name" \
            --cancel-label "Exit" \
            --inputbox "Enter a unique name for this job (alphanumeric, dashes, underscores):" 10 60 "my-task" \
            3>&1 1>&2 2>&3) || exit 0
        
        local cleaned_name
        cleaned_name=$(echo "$input_name" | sed 's/[^a-zA-Z0-9_-]//g')
        if [[ -n "$cleaned_name" ]]; then
            TIMER_NAME="$cleaned_name"
            break
        else
            dialog --backtitle "$backtitle" --title "Error" --msgbox "Invalid name. Use alphanumeric characters, dashes, or underscores only." 8 50
        fi
    done

    # Command Type Choice & File Picker
    local cmd_type
    cmd_type=$(dialog --backtitle "$backtitle" \
        --title "Command Specification Mode" \
        --cancel-label "Exit" \
        --menu "How would you like to specify the command/script?" 12 65 2 \
        1 "Type command manually (e.g. bash scripts or shell pipelines)" \
        2 "Browse and select an executable/script file" \
        3>&1 1>&2 2>&3) || exit 0

    if [[ "$cmd_type" == "2" ]]; then
        while true; do
            local input_file
            input_file=$(dialog --backtitle "$backtitle" \
                --title "Command to run. SPACE: autocomplete, type: hint" \
                --cancel-label "Exit" \
                --fselect "/" 15 75 \
                3>&1 1>&2 2>&3) || exit 0
            
            # Trim whitespaces
            input_file=$(echo "$input_file" | xargs)

            if [[ -f "$input_file" ]]; then
                COMMAND_TO_RUN="$input_file"
                break
            else
                dialog --backtitle "$backtitle" --title "Error" --msgbox "Please select an existing, valid file path." 8 50
            fi
        done
    else
        while true; do
            local input_cmd
            input_cmd=$(dialog --backtitle "$backtitle" \
                --title "Command to Run" \
                --cancel-label "Exit" \
                --inputbox "Enter the exact command or path to execute:" 10 60 "" \
                3>&1 1>&2 2>&3) || exit 0
            
            if [[ -n "$input_cmd" ]]; then
                COMMAND_TO_RUN="$input_cmd"
                break
            else
                dialog --backtitle "$backtitle" --title "Error" --msgbox "Command cannot be empty." 8 50
            fi
        done
    fi

    # Optional command-line arguments input
    local input_args
    input_args=$(dialog --backtitle "$backtitle" \
        --title "Additional Arguments" \
        --cancel-label "Skip" \
        --inputbox "Enter any additional arguments to append to the command (optional):" 10 60 "" \
        3>&1 1>&2 2>&3) || input_args=""
    
    input_args=$(echo "$input_args" | xargs)
    if [[ -n "$input_args" ]]; then
        COMMAND_TO_RUN="$COMMAND_TO_RUN $input_args"
    fi

    # 5. Schedule (with Help button and loop behavior)
    while true; do
        local exit_code=0
        local input_sched
        
        input_sched=$(dialog --backtitle "$backtitle" \
            --title "Schedule Expression" \
            --cancel-label "Exit" \
            --help-button \
            --help-label "Format Help" \
            --inputbox "Enter systemd OnCalendar expression\n(e.g., daily, hourly, minutely, 'Mon..Fri 09:00'):" 12 60 "daily" \
            3>&1 1>&2 2>&3) && exit_code=0 || exit_code=$?

        if [[ "$exit_code" -eq 0 ]]; then
            SCHEDULE="${input_sched:-daily}"
            break
        elif [[ "$exit_code" -eq 2 ]]; then
            # Show Calendar Help dialog
            dialog --backtitle "$backtitle" \
                --title "Systemd OnCalendar Format Help" \
                --msgbox "Systemd OnCalendar events define execution timers.\n\n\
Common Shortcuts:\n\
  - minutely, hourly, daily, weekly, monthly, yearly\n\n\
Calendar Expression Examples:\n\
  - Mon..Fri 09:00:00   -> Monday through Friday at 9:00 AM\n\
  - *-*-* 00,12:00:00   -> Every day at midnight and noon\n\
  - *-01-01 00:00:00    -> Every new year's day at midnight\n\
  - Sun 02:00:00        -> Every Sunday at 2:00 AM\n\
  - *:0/15              -> Every 15 minutes\n\n\
Format syntax:\n\
  DayOfWeek Year-Month-Day Hour:Minute:Second" 20 70
        else
            # Cancel (1) or Escaped (255)
            exit 0
        fi
    done

    # Working Directory
    local input_workdir
    input_workdir=$(dialog --backtitle "$backtitle" \
        --title "Work directory. SPACE: autocomplete, type: hint" \
        --cancel-label "Exit" \
        --dselect "/tmp/" 15 75 \
        3>&1 1>&2 2>&3) || exit 0
    
    # Strip spaces and optional trailing slashes
    WORKING_DIR=$(echo "$input_workdir" | sed 's/\/$//' | xargs)
    if [[ -z "$WORKING_DIR" ]]; then
        WORKING_DIR="/tmp"
    fi

    # Run as User (System space only)
    if [ "$USE_USER_SPACE" = false ]; then
        local input_user
        input_user=$(dialog --backtitle "$backtitle" \
            --title "Execution User" \
            --cancel-label "Exit" \
            --inputbox "User account to run the command under:" 10 60 "root" \
            3>&1 1>&2 2>&3) || exit 0
        RUN_AS_USER="${input_user:-root}"
    fi

    # Description
    local input_desc
    input_desc=$(dialog --backtitle "$backtitle" \
        --title "Timer Description" \
        --cancel-label "Exit" \
        --inputbox "Provide a short description for systemd logs:" 10 60 "$DESCRIPTION" \
        3>&1 1>&2 2>&3) || exit 0
    if [[ -n "$input_desc" ]]; then
        DESCRIPTION="$input_desc"
    fi

    clear
}

####### Interactive Mode: Select Fallback (CLI) #######
run_interactive_fallback() {
    echo -e "${BLUE}=== Systemd Timer Interactive Hub ===${NC}\n"

    # Action
    echo -e "What would you like to do?"
    local options_action=("Schedule and start a new timer" "List existing scheduled timers")
    local action_choice=1
    PS3="Select action [1-2] (default: 1): "
    select opt in "${options_action[@]}"; do
        case "$REPLY" in
            1|""|"$opt") action_choice=1; break ;;
            2) action_choice=2; break ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
    done
    echo

    # Scope
    echo -e "Where would you like to execute your query?"
    local options_scope=("User space (Local account, no sudo)" "System space (Requires root/sudo)")
    PS3="Select scope [1-2] (default: 1): "
    select opt in "${options_scope[@]}"; do
        case "$REPLY" in
            1|""|"$opt") USE_USER_SPACE=true; break ;;
            2) USE_USER_SPACE=false; break ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
    done
    echo

    # View-List Mode
    if [[ "$action_choice" -eq 2 ]]; then
        ACTION="list"
        echo -e "What would you like to display in the second column?"
        local options_col=("Last Execution Time" "Schedule (OnCalendar)")
        PS3="Select column option [1-2] (default: 1): "
        select opt in "${options_col[@]}"; do
            case "$REPLY" in
                1|""|"$opt") SHOW_SCHEDULE=false; break ;;
                2) SHOW_SCHEDULE=true; break ;;
                *) echo -e "${RED}Invalid option.${NC}" ;;
            esac
        done
        echo
        return
    fi

    # Timer Name
    while true; do
        read -rp "Enter a unique name for this job (e.g., my-backup-task): " input_name
        local cleaned_name
        cleaned_name=$(echo "$input_name" | sed 's/[^a-zA-Z0-9_-]//g')
        if [[ -n "$cleaned_name" ]]; then
            TIMER_NAME="$cleaned_name"
            break
        else
            echo -e "${RED}Invalid name. Please use alphanumeric characters, dashes, or underscores.${NC}"
        fi
    done
    echo

    # Command to Run
    while true; do
        read -rp "Enter the exact command or path to the script to run: " input_cmd
        if [[ -n "$input_cmd" ]]; then
            COMMAND_TO_RUN="$input_cmd"
            break
        else
            echo -e "${RED}Command cannot be empty.${NC}"
        fi
    done

    # Optional command-line arguments
    read -rp "Enter any additional arguments to append to the command (optional): " input_args
    input_args=$(echo "$input_args" | xargs)
    if [[ -n "$input_args" ]]; then
        COMMAND_TO_RUN="$COMMAND_TO_RUN $input_args"
    fi
    echo

    # Schedule/Calendar Expression
    echo -e "${BLUE}=== Schedule Expression (OnCalendar) ===${NC}"
    echo -e "Enter systemd OnCalendar format (e.g. 'daily', 'hourly', 'Mon..Fri 09:00')."
    echo -e "Type ${YELLOW}help${NC} to view detailed scheduling syntax and examples."
    while true; do
        read -rp "Schedule (default: daily): " input_sched
        input_sched="${input_sched:-daily}"
        if [[ "$input_sched" == "help" ]]; then
            echo -e "\n${CYAN}--- Systemd Calendar Event Help ---${NC}"
            echo -e "Format: [DayOfWeek] [Year-Month-Day] [Hour:Minute:Second]\n"
            echo -e "1. Shortcuts: minutely, hourly, daily, weekly, monthly, quarterly, yearly"
            echo -e "2. Days of week: Mon, Tue, Wed, Thu, Fri, Sat, Sun (or Mon..Fri)"
            echo -e "3. Repeating intervals: *:0/15 (every 15 mins), *:0/10 (every 10 mins)"
            echo -e "4. Concrete examples:"
            echo -e "   - ${YELLOW}Mon..Fri 09:00${NC}       (Monday to Friday at 9:00 AM)"
            echo -e "   - ${YELLOW}*-*-* 00,12:00:00${NC}    (Every day at 12:00 AM and 12:00 PM)"
            echo -e "   - ${YELLOW}Sun 02:00:00${NC}         (Every Sunday at 2:00 AM)"
            echo -e "   - ${YELLOW}daily${NC}                (Every day at midnight)\n"
            continue
        fi
        SCHEDULE="$input_sched"
        break
    done
    echo

    # Working Directory
    read -rp "Working directory (default: /tmp): " input_workdir
    WORKING_DIR="${input_workdir:-/tmp}"
    echo

    # Execution User (Only applicable to system-wide tasks)
    if [ "$USE_USER_SPACE" = false ]; then
        read -rp "User to run the command as (default: root): " input_user
        RUN_AS_USER="${input_user:-root}"
        echo
    fi

    # Description
    read -rp "Provide a brief description (optional): " input_desc
    if [[ -n "$input_desc" ]]; then
        DESCRIPTION="$input_desc"
    fi
    echo
}

####### Unified Interactive Selector #######
run_interactive() {
    if command -v dialog &> /dev/null; then
        run_interactive_dialog
    else
        run_interactive_fallback
    fi
}

####### Validations #######
validate_inputs() {
    if [[ -z "$TIMER_NAME" || -z "$COMMAND_TO_RUN" || -z "$SCHEDULE" ]]; then
        echo -e "${RED}Error: Missing required variables (Name, Command, and Schedule are all required).${NC}" >&2
        exit 1
    fi
}

####### Main Logic #######
main() {
    parse_arguments "$@"

    # If list is parsed directly from CLI argument
    if [[ "$ACTION" == "list" ]]; then
        list_timers
        exit 0
    fi

    # If any mandatory parameter is missing, fall back to interactive mode
    if [[ -z "$TIMER_NAME" || -z "$COMMAND_TO_RUN" || -z "$SCHEDULE" ]]; then
        # Ensure we are in an interactive terminal
        if [[ ! -t 0 ]]; then
            echo -e "${RED}Error: Missing arguments and non-interactive terminal detected.${NC}" >&2
            show_help
            exit 1
        fi
        run_interactive
    fi

    # If user selected listing during interactive flow
    if [[ "$ACTION" == "list" ]]; then
        list_timers
        exit 0
    fi

    validate_inputs

    # Determine paths and systemctl prefix
    local systemd_dir
    local cmd_prefix=""

    if [ "$USE_USER_SPACE" = true ]; then
        systemd_dir="$HOME/.config/systemd/user"
        cmd_prefix="systemctl --user"
        # Ensure the user systemd directory exists
        mkdir -p "$systemd_dir"
    else
        systemd_dir="/etc/systemd/system"
        cmd_prefix="sudo systemctl"
        # Verify sudo permissions or root execution
        if [ "$EUID" -ne 0 ] && ! command -v sudo &> /dev/null; then
            echo -e "${RED}Error: System-level scheduling requires root privileges or sudo access.${NC}" >&2
            exit 1
        fi
    fi

    local service_file="${systemd_dir}/${TIMER_NAME}.service"
    local timer_file="${systemd_dir}/${TIMER_NAME}.timer"

    echo -e "${BLUE}Configuring systemd units...${NC}"

    # Prepare file creation helper (handles sudo if necessary)
    write_file() {
        local filepath="$1"
        local content="$2"
        if [ "$USE_USER_SPACE" = true ]; then
            echo "$content" > "$filepath"
        else
            echo "$content" | sudo tee "$filepath" > /dev/null
        fi
    }

    # 1. Create the .service unit file
    # Note: Systemd services require absolute paths for binaries inside ExecStart.
    local resolved_cmd="$COMMAND_TO_RUN"
    local base_binary
    base_binary=$(echo "$COMMAND_TO_RUN" | awk '{print $1}')

    if [[ "$base_binary" != /* ]]; then
        local absolute_binary
        absolute_binary=$(which "$base_binary" 2>/dev/null || true)
        if [[ -n "$absolute_binary" ]]; then
            resolved_cmd=$(echo "$COMMAND_TO_RUN" | sed "s|^$base_binary|$absolute_binary|")
        fi
    fi

    # Assemble Service Contents
    local service_content="[Unit]
Description=${DESCRIPTION} (Service)
Wants=${TIMER_NAME}.timer

[Service]
Type=oneshot
WorkingDirectory=${WORKING_DIR}"

    # Only set 'User=' for system-level services
    if [ "$USE_USER_SPACE" = false ]; then
        service_content="${service_content}
User=${RUN_AS_USER}"
    fi

    service_content="${service_content}
ExecStart=${resolved_cmd}"

    service_content="${service_content}

[Install]
WantedBy=default.target"

    write_file "$service_file" "$service_content"
    echo -e "  - Created service file: ${YELLOW}${service_file}${NC}"

    # 2. Create the .timer unit file
    local timer_content="[Unit]
Description=Trigger ${DESCRIPTION} on schedule

[Timer]
OnCalendar=${SCHEDULE}
Persistent=true
Unit=${TIMER_NAME}.service

[Install]
WantedBy=timers.target"

    write_file "$timer_file" "$timer_content"
    echo -e "  - Created timer file: ${YELLOW}${timer_file}${NC}"

    # 3. Reload, Enable and Start
    echo -e "\n${BLUE}Activating systemd timer...${NC}"
    
    eval "$cmd_prefix daemon-reload"
    eval "$cmd_prefix enable ${TIMER_NAME}.timer"
    eval "$cmd_prefix restart ${TIMER_NAME}.timer"

    # 4. Display Status
    echo -e "\n${GREEN}Successfully set up timer!${NC}"
    echo -e "----------------------------------------------------"
    echo -e "To check the current status of your new timer:"
    echo -e "  ${BLUE}${cmd_prefix} status ${TIMER_NAME}.timer${NC}"
    echo -e "To view when it is scheduled to run next:"
    echo -e "  ${BLUE}${cmd_prefix} list-timers --all | grep ${TIMER_NAME}${NC}"
    echo -e "To view the logs of your running command:"
    if [ "$USE_USER_SPACE" = true ]; then
        echo -e "  ${BLUE}journalctl --user -u ${TIMER_NAME}.service -f${NC}"
    else
        echo -e "  ${BLUE}journalctl -u ${TIMER_NAME}.service -f${NC}"
    fi
    echo -e "----------------------------------------------------"
}

main "$@"
