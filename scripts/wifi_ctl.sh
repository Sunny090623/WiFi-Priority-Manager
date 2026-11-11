#!/system/bin/sh
# WiFi Priority Manager CLI entrypoint router (invoked by WebUI, action.sh, and daemon).

case "$0" in
  */*) SCRIPT_DIR=$(CDPATH= cd -- "${0%/*}" && pwd) ;;
  *)   SCRIPT_DIR=$(pwd) ;;
esac
MODDIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

. "$SCRIPT_DIR/lib_common.sh"
. "$SCRIPT_DIR/wifi_info.sh"
. "$SCRIPT_DIR/wifi_config.sh"
. "$SCRIPT_DIR/wifi_enforce.sh"

cmd_daemon_control() {
  ensure_data_dir
  subcmd="$1"
  case "$subcmd" in
    status)
      dpid=$(get_daemon_pid)
      if [ -n "$dpid" ]; then
        printf '{"running":true,"pid":%s}\n' "$dpid"
      else
        echo '{"running":false,"pid":0}'
      fi
      ;;
    stop)
      dpid=$(get_daemon_pid)
      if [ -n "$dpid" ]; then
        kill "$dpid" 2>/dev/null
        sleep 1
        kill -9 "$dpid" 2>/dev/null
      fi
      rm -f "$PID_FILE"
      append_log "INFO" "Daemon stopped"
      echo '{"ok":true,"running":false,"pid":0}'
      ;;
    start|restart|ensure)
      if [ "$subcmd" = "ensure" ] && is_daemon_running; then
        dpid=$(get_daemon_pid)
        printf '{"ok":true,"running":true,"pid":%s}\n' "$dpid"
        return 0
      fi
      if [ "$subcmd" = "restart" ] || [ "$subcmd" = "start" ]; then
        dpid=$(get_daemon_pid)
        if [ -n "$dpid" ]; then
          kill "$dpid" 2>/dev/null
          sleep 1
          kill -9 "$dpid" 2>/dev/null
          rm -f "$PID_FILE"
        fi
      fi
      if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
        echo '{"ok":false,"running":false,"error":"module_disabled"}'
        return 1
      fi
      # Detach all standard FDs so ksu.exec / shell callers receive EOF immediately
      /system/bin/sh "$SCRIPT_DIR/wifi_daemon.sh" </dev/null >/dev/null 2>&1 &
      tries=0
      dpid=""
      while [ "$tries" -lt 10 ]; do
        sleep 1
        dpid=$(get_daemon_pid)
        [ -n "$dpid" ] && break
        tries=$((tries + 1))
      done
      if [ -n "$dpid" ]; then
        printf '{"ok":true,"running":true,"pid":%s}\n' "$dpid"
      else
        echo '{"ok":false,"running":false,"error":"daemon_start_timeout"}'
        return 1
      fi
      ;;
    *)
      echo '{"ok":false,"error":"unknown daemon_control action"}'
      return 1
      ;;
  esac
}

case "$1" in
  status|get_wifi_status)       cmd_status ;;
  saved_networks|list_saved_networks) cmd_saved_networks ;;
  scan_results)                 cmd_scan_results ;;
  get_config)                   cmd_get_config ;;
  save_config)                  shift; cmd_save_config "$1" ;;
  enforce_once)                 shift; cmd_enforce_once "$1" ;;
  get_logs)                     shift; cmd_get_logs "$1" ;;
  clear_logs)                   cmd_clear_logs ;;
  daemon_control)               shift; cmd_daemon_control "$1" ;;
  *)
    echo '{"ok":false,"error":"usage: wifi_ctl.sh <status|saved_networks|scan_results|get_config|save_config|enforce_once|get_logs|clear_logs|daemon_control>"}'
    exit 1
    ;;
esac
