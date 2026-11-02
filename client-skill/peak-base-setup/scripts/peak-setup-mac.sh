#!/bin/bash
# Peak Base setup helper for macOS (the stock bash 3.2, curl, osascript, security).
#
# Run:  bash peak-setup-mac.sh <command> [args]
#
# Secrets (the Hostinger token, the server's root password, the password
# recovery key) live in the login Keychain as "Peak Base Setup" items. They are
# typed into a private dialog or generated here, and they are never printed:
# commands report "saved", "made" or "ok", and Hostinger answers are printed
# with every stored secret blanked out.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
API=https://developers.hostinger.com
COMPOSE=https://raw.githubusercontent.com/BillyRybka/peak-base-releases/main/server/docker-compose.yml
DOWNLOAD=https://github.com/BillyRybka/peak-base-releases/releases/latest/download/PeakBase-Mac.dmg
PROJECT=peak-base
SERVICE="Peak Base Setup"
CMD=${1:-help}; shift 2>/dev/null || true

die() { echo "error: $*" >&2; exit 1; }
need() { [ -n "${1:-}" ] || die "missing $2"; }
bare() { echo "$1" | sed -E 's#^https?://##; s#/+$##'; }

# ---- Keychain ----------------------------------------------------------------
get_secret() { security find-generic-password -s "$SERVICE" -a "$1" -w 2>/dev/null; }
set_secret() { security add-generic-password -U -s "$SERVICE" -a "$1" -l "$SERVICE: $1" -w "$2" >/dev/null; }
need_secret() {
  local v; v=$(get_secret "$1") || true
  [ -n "$v" ] || die "no saved secret named $1 (run ask-secret or make-secret first)"
  printf '%s' "$v"
}
# Letters and digits with at least one upper, lower and number (Hostinger's rule).
random_secret() {
  local n=$1 s
  while :; do
    s=$(LC_ALL=C tr -dc 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789' </dev/urandom | head -c "$n")
    case $s in *[A-Z]*) ;; *) continue ;; esac
    case $s in *[a-z]*) ;; *) continue ;; esac
    case $s in *[0-9]*) printf '%s' "$s"; return ;; esac
  done
}
ensure_secret() { [ -n "$(get_secret "$1")" ] || set_secret "$1" "$(random_secret "$2")"; }
hide() {
  local t; t=$(cat); local n v
  for n in hostinger-token server-root recovery-key resend-api-key; do
    v=$(get_secret "$n") || true
    [ -n "$v" ] && t=${t//"$v"/[hidden]}
  done
  printf '%s\n' "$t"
}

# ---- JSON (JavaScript for Automation, built into every Mac) -------------------
# js '<expression using o>' <json>   prints the expression's value
js() {
  osascript -l JavaScript - "$1" "$2" <<'EOF'
function run(argv) {
  var o = argv[1] ? JSON.parse(argv[1]) : null;
  var r = eval("(function(o){ return " + argv[0] + "; })")(o);
  return typeof r === "string" ? r : JSON.stringify(r);
}
EOF
}
json_str() { # a JSON string literal
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\t'/\\t}
  printf '"%s"' "$s"
}

# ---- The private box -----------------------------------------------------------
# ask <title> <message> -> prints what was typed, or nothing on Cancel
ask() {
  osascript - "$1" "$2" <<'EOF' 2>/dev/null
on run argv
  activate
  try
    set r to display dialog (item 2 of argv) with title (item 1 of argv) default answer "" with hidden answer buttons {"Cancel", "Save"} default button "Save" cancel button "Cancel"
    return text returned of r
  on error
    return ""
  end try
end run
EOF
}

# ---- Hostinger -----------------------------------------------------------------
# hapi METHOD PATH [BODYFILE] [TRIES] -> prints the answer; dies on a refusal.
hapi() {
  local m=$1 path=$2 body=${3:-} tries=${4:-12} tok out code text i wait
  tok=$(need_secret hostinger-token) || exit 1
  for i in $(seq 1 "$tries"); do
    if [ -n "$body" ]; then
      out=$(printf 'header = "Authorization: Bearer %s"\n' "$tok" | curl -sS -K - -X "$m" -H "Accept: application/json" \
        -H "Content-Type: application/json" --data-binary @"$body" -w $'\n%{http_code}' --max-time 60 "$API$path" 2>&1)
    else
      out=$(printf 'header = "Authorization: Bearer %s"\n' "$tok" | curl -sS -K - -X "$m" -H "Accept: application/json" \
        -w $'\n%{http_code}' --max-time 60 "$API$path" 2>&1)
    fi
    code=$(printf '%s' "$out" | tail -n1); text=$(printf '%s' "$out" | sed '$d')
    case $code in 2??) printf '%s' "$text"; return 0 ;; esac
    if [ "$i" -lt "$tries" ] && { [ "$code" = 000 ] || [ "$code" = 429 ] || [ "${code:0:1}" = 5 ] || printf '%s' "$text" | grep -qiE 'maintenance|temporarily|try again'; }; then
      wait=$((10 * i)); [ $wait -gt 60 ] && wait=60
      echo "Hostinger is busy ($code). Trying again in $wait seconds ($i of $tries)." >&2
      sleep $wait; continue
    fi
    die "Hostinger answered $code on $m $path: $(printf '%s' "$text" | hide)"
  done
}
items() { js 'o && o.data ? o.data : o' "$1"; }
docker_template() {
  js '(o.data||o).filter(function(t){return /Ubuntu/.test(t.name)&&/Docker/.test(t.name)}).sort(function(a,b){return a.name<b.name?1:-1})[0].id' "$(hapi GET /api/vps/v1/templates)"
}
bodyfile() { local f; f=$(mktemp -t peakbody); chmod 600 "$f"; printf '%s' "$1" >"$f"; echo "$f"; }

# ---- Commands -------------------------------------------------------------------
case $CMD in
  ask-secret) # ask-secret <name> <title> <message> [minLength] [confirm]
    need "${1:-}" name; need "${2:-}" title; need "${3:-}" message
    min=${4:-8}
    v=$(ask "$2" "$3")
    [ -n "$v" ] || { echo cancelled; exit 0; }
    [ ${#v} -ge "$min" ] || die "that was shorter than $min characters; nothing saved"
    if [ "${5:-}" = confirm ]; then
      v2=$(ask "$2" "Type it again:")
      [ "$v" = "$v2" ] || die "the two didn't match; nothing saved"
    fi
    set_secret "$1" "$v"; echo saved ;;
  has-secret) [ -n "$(get_secret "${1:-}")" ] && echo yes || echo no ;;
  make-secret) need "${1:-}" name
    if [ -n "$(get_secret "$1")" ]; then echo "kept (already saved)"; else set_secret "$1" "$(random_secret "${2:-40}")"; echo made; fi ;;
  secret-matches) # secret-matches <name> <sha256 hex> (tests)
    h=$(need_secret "${1:-}" | shasum -a 256 | cut -d' ' -f1)
    [ "$h" = "$(echo "${2:-}" | tr 'A-F' 'a-f')" ] && echo match || echo different ;;
  forget-secret) security delete-generic-password -s "$SERVICE" -a "${1:-}" >/dev/null 2>&1 && echo forgotten || echo "none saved" ;;

  check-token) a=$(hapi GET /api/vps/v1/virtual-machines) || exit 1
    echo "ok: the token works and sees $(js '(o.data||o).length' "$a") server(s)" ;;
  servers) a=$(hapi GET /api/vps/v1/virtual-machines) || exit 1
    js '(o.data||o).map(function(v){return {id:v.id,state:v.state,actions_lock:v.actions_lock,plan:v.plan,hostname:v.hostname,ipv4:(v.ipv4||[]).map(function(i){return i.address}),template:v.template?v.template.name:null,data_center_id:v.data_center_id,firewall_group_id:v.firewall_group_id,created_at:v.created_at}})' "$a" ;;
  options) d=$(hapi GET /api/vps/v1/data-centers) || exit 1; t=$(hapi GET /api/vps/v1/templates) || exit 1
    js '{docker_template:(o.t.data||o.t).filter(function(x){return /Ubuntu/.test(x.name)&&/Docker/.test(x.name)}).sort(function(a,b){return a.name<b.name?1:-1}).map(function(x){return {id:x.id,name:x.name}})[0], this_computer_time_zone:o.tz, data_centers:(o.d.data||o.d).map(function(x){return {id:x.id,name:x.name,city:x.city,location:x.location,continent:x.continent}})}' \
      "{\"d\":$d,\"t\":$t,\"tz\":$(json_str "$(readlink /etc/localtime | sed 's#.*zoneinfo/##')")}" ;;
  setup-server) # setup-server <serverId> <dataCenterId> [templateId]
    need "${1:-}" "server id"; need "${2:-}" "data center id"
    st=$(js 'o.state' "$(hapi GET "/api/vps/v1/virtual-machines/$1")") || exit 1
    [ "$st" = initial ] || die "this server is already set up (state $st); use set-root-password, or recreate-server to erase it"
    tid=${3:-$(docker_template)}; ensure_secret server-root 24
    f=$(bodyfile "{\"template_id\":$tid,\"data_center_id\":$2,\"password\":$(json_str "$(need_secret server-root)"),\"install_monarx\":false,\"enable_backups\":true}")
    a=$(hapi POST "/api/vps/v1/virtual-machines/$1/setup" "$f" 30); rc=$?; rm -f "$f"; [ $rc = 0 ] || exit 1
    echo "setup started: $(printf '%s' "$a" | hide)" ;;
  recreate-server) # recreate-server <serverId> erase-everything [templateId]
    need "${1:-}" "server id"; [ "${2:-}" = erase-everything ] || die "say erase-everything to confirm"
    tid=${3:-$(docker_template)}; ensure_secret server-root 24
    f=$(bodyfile "{\"template_id\":$tid,\"password\":$(json_str "$(need_secret server-root)")}")
    a=$(hapi POST "/api/vps/v1/virtual-machines/$1/recreate" "$f" 30); rc=$?; rm -f "$f"; [ $rc = 0 ] || exit 1
    echo "recreate started: $(printf '%s' "$a" | hide)" ;;
  set-root-password) need "${1:-}" "server id"; ensure_secret server-root 24
    f=$(bodyfile "{\"password\":$(json_str "$(need_secret server-root)")}")
    hapi PUT "/api/vps/v1/virtual-machines/$1/root-password" "$f" >/dev/null; rc=$?; rm -f "$f"; [ $rc = 0 ] || exit 1
    echo "root password replaced and saved in the Keychain" ;;
  wait-server) need "${1:-}" "server id"; end=$(( $(date +%s) + ${2:-20} * 60 ))
    while :; do
      a=$(hapi GET "/api/vps/v1/virtual-machines/$1") || exit 1
      s=$(js 'o.state+" "+o.actions_lock' "$a")
      [ "$s" = "running unlocked" ] && { echo "ready: $(js 'o.hostname+" "+JSON.stringify((o.ipv4||[]).map(function(i){return i.address}))' "$a")"; break; }
      [ "$(date +%s)" -lt $end ] || die "the server was still not ready ($s)"
      echo "Server is $s. Checking again in 20 seconds." >&2; sleep 20
    done ;;
  deploy) # deploy <serverId> <address>
    need "${1:-}" "server id"; need "${2:-}" address; addr=$(bare "$2")
    ensure_secret recovery-key 48
    env="DOMAIN=$addr"$'\n'"MCP_SERVER_TITLE=Business Brain"$'\n'"PASSWORD_RECOVERY_KEY=$(need_secret recovery-key)"
    mail=off
    if [ -f "$HERE/mail.key" ]; then
      m=$(base64 -D -i "$HERE/mail.key" 2>/dev/null || base64 -d "$HERE/mail.key")
      k=$(js 'o.key||""' "$m"); fr=$(js 'o.from||""' "$m")
      [ -n "$k" ] && [ -n "$fr" ] && { env="$env"$'\n'"RESEND_API_KEY=$k"$'\n'"EMAIL_FROM=\"$fr\""; mail=on; }
    fi
    f=$(bodyfile "{\"project_name\":\"$PROJECT\",\"content\":$(json_str "$COMPOSE"),\"environment\":$(json_str "$env")}")
    a=$(hapi POST "/api/vps/v1/virtual-machines/$1/docker" "$f" 20); rc=$?; rm -f "$f"; [ $rc = 0 ] || exit 1
    echo "deploy started (password reset email: $mail): $(printf '%s' "$a" | hide)" ;;
  update-server) need "${1:-}" "server id"; a=$(hapi POST "/api/vps/v1/virtual-machines/$1/docker/$PROJECT/update" "" 20) || exit 1
    echo "update started: $(printf '%s' "$a" | hide)" ;;
  projects) need "${1:-}" "server id"; a=$(hapi GET "/api/vps/v1/virtual-machines/$1/docker") || exit 1
    js '(o.data||o).map(function(p){return {name:p.name,state:p.state,status:p.status}})' "$a" ;;
  containers) need "${1:-}" "server id"; a=$(hapi GET "/api/vps/v1/virtual-machines/$1/docker/$PROJECT/containers") || exit 1
    js '(o.data||o).map(function(c){return {name:c.name,state:c.state,health:c.health,status:c.status}})' "$a" ;;
  logs) need "${1:-}" "server id"; hapi GET "/api/vps/v1/virtual-machines/$1/docker/$PROJECT/logs" | hide ;;
  firewall) need "${1:-}" "server id"
    fid=$(js 'o.firewall_group_id||""' "$(hapi GET "/api/vps/v1/virtual-machines/$1")")
    [ -n "$fid" ] || { echo "ok: no firewall on this server"; exit 0; }
    fw=$(hapi GET "/api/vps/v1/firewall/$fid") || exit 1; added=""
    for port in 22 80 443; do
      has=$(js "(o.rules||[]).some(function(r){return r.action!=='drop'&&(r.port==='$port'||r.port==='any')&&['TCP','any','SSH','HTTP','HTTPS'].indexOf(r.protocol)>=0})" "$fw")
      if [ "$has" != true ]; then
        f=$(bodyfile "{\"protocol\":\"TCP\",\"port\":\"$port\",\"source\":\"any\",\"source_detail\":\"any\"}")
        hapi POST "/api/vps/v1/firewall/$fid/rules" "$f" >/dev/null; rm -f "$f"; added="$added $port"
      fi
    done
    hapi POST "/api/vps/v1/firewall/$fid/sync/$1" >/dev/null
    echo "ok: firewall $fid allows 22, 80, 443 (added:${added:- none})" ;;
  health) need "${1:-}" address; addr=$(bare "$1"); end=$(( $(date +%s) + ${2:-15} * 60 ))
    while :; do
      r=$(curl -fsS --max-time 20 "https://$addr/health" 2>&1) && { echo "ok: $r"; break; }
      [ "$(date +%s)" -lt $end ] || die "https://$addr/health still does not answer: $r"
      echo "Not answering yet (the secure connection can take a few minutes). Checking again in 20 seconds." >&2; sleep 20
    done ;;

  install-app)
    dmg="$HOME/Downloads/PeakBase-Mac.dmg"
    curl -fsSL -o "$dmg" "$DOWNLOAD" || die "download failed"
    mnt=$(hdiutil attach -nobrowse -noverify -noautoopen "$dmg" | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -n1)
    [ -d "$mnt" ] || die "could not open the download"
    app=$(ls -d "$mnt"/*.app 2>/dev/null | head -n1)
    [ -n "$app" ] || { hdiutil detach "$mnt" -quiet; die "no app inside the download"; }
    dest=/Applications; [ -w "$dest" ] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
    name=$(basename "$app")
    rm -rf "$dest/$name.old"; [ -d "$dest/$name" ] && mv "$dest/$name" "$dest/$name.old"
    ditto "$app" "$dest/$name" || { hdiutil detach "$mnt" -quiet; die "copy into $dest failed"; }
    rm -rf "$dest/$name.old"
    hdiutil detach "$mnt" -quiet
    # The app is not signed by Apple yet: clear the "downloaded from the
    # internet" mark so macOS opens it without the Privacy & Security detour.
    xattr -cr "$dest/$name"
    open "$dest/$name"
    echo "installed: $dest/$name version $(defaults read "$dest/$name/Contents/Info" CFBundleShortVersionString 2>/dev/null) (opened)" ;;
  open-connect) need "${1:-}" address; addr=$(bare "$1"); open "https://$addr/open/connect"; echo "opened https://$addr/open/connect" ;;
  open-folder) need "${1:-}" folder; dir=$(cd "$1" && pwd) || die "no folder $1"
    q="path=$(js 'encodeURIComponent(o.p)' "{\"p\":$(json_str "$dir")}")"; [ "${2:-}" = skills ] && q="$q&skills=1"
    open "peakbase://open-folder?$q"; echo "asked Peak Base to open $dir" ;;

  find-vaults)
    cfg="$HOME/Library/Application Support/obsidian/obsidian.json"
    [ -f "$cfg" ] || { echo "no Obsidian vaults found (no $cfg)"; exit 0; }
    icloud_docs=false; [ -d "$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents" ] && icloud_docs=true
    js 'Object.keys(o.vaults).map(function(k){return o.vaults[k]})' "$(cat "$cfg")" >/dev/null || die "could not read $cfg"
    out="["; first=1
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      ex=false; files=0; mb=0; ph=0; sk=false
      if [ -d "$p" ]; then
        ex=true; files=$(find "$p" -type f -not -path '*/.git/*' -not -path '*/.obsidian/*' -not -path '*/.trash/*' 2>/dev/null | wc -l | tr -d ' ')
        mb=$(du -sm "$p" 2>/dev/null | cut -f1); ph=$(find "$p" -name '.*.icloud' 2>/dev/null | wc -l | tr -d ' ')
        { [ -d "$p/.claude/skills" ] || [ -d "$p/.agents/skills" ]; } && sk=true
      fi
      cloud=false
      case $p in *"Mobile Documents"*|*iCloud*|*CloudStorage*|*Dropbox*|*OneDrive*|*"Google Drive"*) cloud=true ;; esac
      case $p in "$HOME/Documents"*|"$HOME/Desktop"*) [ $icloud_docs = true ] && cloud=true ;; esac
      [ "$ph" != 0 ] && cloud=true
      [ $first = 1 ] || out="$out,"; first=0
      out="$out{\"path\":$(json_str "$p"),\"exists\":$ex,\"in_cloud_storage\":$cloud,\"icloud_placeholders\":$ph,\"files\":$files,\"megabytes\":${mb:-0},\"has_skills\":$sk}"
    done <<EOF
$(js 'Object.keys(o.vaults).map(function(k){return o.vaults[k].path}).join("\n")' "$(cat "$cfg")")
EOF
    echo "$out]" ;;
  move-vault) # move-vault <from> [to]
    need "${1:-}" folder; from=$(cd "$1" && pwd) || die "no folder $1"; to=${2:-"$HOME/Business Brain"}
    [ -d "$to" ] && [ -n "$(ls -A "$to" 2>/dev/null)" ] && die "$to already has files in it; pick another place"
    # iCloud may keep files online only: fetch them all before copying.
    if [ "$(find "$from" -name '.*.icloud' | wc -l | tr -d ' ')" != 0 ]; then
      brctl download "$from" 2>/dev/null
      for _ in $(seq 1 90); do [ "$(find "$from" -name '.*.icloud' | wc -l | tr -d ' ')" = 0 ] && break; sleep 10; done
    fi
    left=$(find "$from" -name '.*.icloud' | wc -l | tr -d ' ')
    [ "$left" = 0 ] || die "$left files are still only in iCloud; open the folder in Finder, wait for them to download, then try again"
    mkdir -p "$to"; ditto "$from" "$to" || die "copy failed"
    a=$(find "$from" -type f | wc -l | tr -d ' '); b=$(find "$to" -type f | wc -l | tr -d ' ')
    same=false; [ "$a" = "$b" ] && same=true
    echo "{\"from\":$(json_str "$from"),\"to\":$(json_str "$to"),\"files_before\":$a,\"files_after\":$b,\"same\":$same}" ;;

  reset-password) # reset-password <address> <email>
    need "${1:-}" address; need "${2:-}" email; base="https://$(bare "$1")"
    case $1 in http://localhost*|http://127.0.0.1*) base=${1%/} ;; esac # a local test server
    key=$(need_secret recovery-key) || exit 1
    pw=$(ask "Peak Base: new password" "Pick a new Peak Base password for $2 (at least 8 characters). Only you will see it.")
    [ -n "$pw" ] || { echo cancelled; exit 0; }
    [ ${#pw} -ge 8 ] || die "that was shorter than 8 characters; nothing changed"
    pw2=$(ask "Peak Base: new password" "Type it again:")
    [ "$pw" = "$pw2" ] || die "the two didn't match; nothing changed"
    f=$(bodyfile "{\"email\":$(json_str "$2"),\"password\":$(json_str "$pw")}")
    out=$(printf 'header = "Authorization: Bearer %s"\n' "$key" | curl -sS -K - -X POST -H "Content-Type: application/json" \
      --data-binary @"$f" -w $'\n%{http_code}' "$base/api/peak/recover-password"); rm -f "$f"
    [ "$(printf '%s' "$out" | tail -n1)" = 200 ] || die "the server refused: $(printf '%s' "$out" | sed '$d')"
    echo "ok: the new password is set. Sign in with it in Peak Base." ;;

  *) cat <<'EOF'
Peak Base setup helper. Commands:
  ask-secret <name> <title> <message> [minLength] [confirm]   private dialog, saved in the Keychain
  has-secret <name> | make-secret <name> [length] | forget-secret <name>
  check-token | servers | options
  setup-server <id> <dataCenterId> [templateId] | set-root-password <id>
  recreate-server <id> erase-everything [templateId] | wait-server <id> [minutes]
  deploy <id> <address> | update-server <id> | projects <id> | containers <id> | logs <id> | firewall <id> | health <address> [minutes]
  install-app | open-connect <address> | open-folder <folder> [skills]
  find-vaults | move-vault <from> [to]
  reset-password <address> <email>
EOF
  ;;
esac
