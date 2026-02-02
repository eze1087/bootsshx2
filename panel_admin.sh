
#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="/opt/ssh-bot"
BOT_HOME="/root/ssh-bot"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"
BOT_NAME="ssh-bot"

QR_PNG="/root/qr-whatsapp.png"
QR_TXT="/root/qr-whatsapp.txt"

APK_DIR="$BOT_HOME/apks"
HC_DIR="$BOT_HOME/hc"
HC_TEMPLATE_DIR="/root"
HC_ACTIVE_KEY=".downloads.hc_template"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'


header() {
  clear || true
  local title="${1:-}"
  echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║              🎛️  PANEL SSH BOT PRO v8.8.27                 ║${NC}"
  if [[ -n "$title" ]]; then
    printf "${CYAN}║  %-58s║${NC}\n" " $title"
  else
    echo -e "${CYAN}║                                                              ║${NC}"
  fi
  echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}


ok()   { echo -e "${GREEN}✅ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()  { echo -e "${RED}❌ $*${NC}"; }
pause(){ read -rp "Presiona Enter para continuar..." _; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }
pausa(){ read -rp "Presioná ENTER para continuar..." _ || true; }

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

PM2_BIN=""
pm2_resolve(){ PM2_BIN="$(command -v pm2 2>/dev/null || true)"; }
pm2_run(){
  pm2_resolve
  if [[ -n "${PM2_BIN}" ]]; then
    "${PM2_BIN}" "$@"
    return $?
  fi
  echo -e "${RED}❌ pm2 no está instalado o no está en PATH.${NC}"
  echo -e "${YELLOW}➡️ Solución: ejecutá en la VPS:${NC}"
  echo -e "   npm i -g pm2  ${YELLOW}(o rerun del instalador)${NC}"
  return 127
}

ensure_runtime(){
  # Instala deps mínimas del panel si faltan (no rompe si ya existen)
  local pkgs=()
  for c in jq sqlite3 curl wget; do
    command -v "$c" >/dev/null 2>&1 || pkgs+=("$c")
  done

  if [[ ${#pkgs[@]} -gt 0 ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y "${pkgs[@]}" >/dev/null 2>&1 || true
  fi

  # Asegurar pm2
  if ! command -v pm2 >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true

    if ! command -v npm >/dev/null 2>&1; then
      # Node 20 + npm
      curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || true
      apt-get install -y nodejs >/dev/null 2>&1 || true
    fi

    npm i -g pm2 >/dev/null 2>&1 || true
    hash -r 2>/dev/null || true
  fi

  pm2_resolve
}
require_root() {
  if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
    echo -e "${RED}❌ Ejecutar como root${NC}"
    exit 1
  fi
}

ensure_dirs() {
  mkdir -p "$INSTALL_DIR"/{data,config,qr_codes,logs,backups} "$BOT_HOME"/{config,data,apks,hc,logs} >/dev/null 2>&1 || true
  chmod 700 "$INSTALL_DIR/config" >/dev/null 2>&1 || true
}

get_json() { jq -r "$1" "$CONFIG_FILE" 2>/dev/null || echo ""; }

migrate_config() {
  # Add missing keys without overwriting existing values
  [[ -s "$CONFIG_FILE" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  jq '(
    .bot.name //= "SSH BOT ELNENE PRO" |
    .bot.version //= "8.8.27" |
    .prices.test_hours //= 2 |
    .prices.plan_7 //= (.prices.price_7d // 500) |
    .prices.plan_15 //= (.prices.price_15d // 800) |
    .prices.plan_30 //= (.prices.price_30d // 1200) |
    .prices.price_7d //= (.prices.plan_7 // 500) |
    .prices.price_15d //= (.prices.plan_15 // 800) |
    .prices.price_30d //= (.prices.plan_30 // 1200) |
    .prices.currency //= "ARS" |
    .mercadopago //= {"access_token":"","enabled":false} |
    .gemini //= {"enabled":false,"api_key":""} |
    .links //= {"tutorial":"https://youtube.com","support":"https://t.me/soporte","support_whatsapp":"","telegram":""} |
    .links.tutorial //= "https://youtube.com" |
    .links.support //= "https://t.me/soporte" |
    .links.support_whatsapp //= "" |
    .links.telegram //= "" |
    .downloads //= {"apk_url":"","custom_url":"","custom_message":"📲 *HTTP Custom*\n\n⬇️ Descargá desde:\n{URL}\n\nLuego importá tu archivo .hc (HWID) y conectá."} |
    .downloads.apk_url //= "" |
    .downloads.custom_url //= "" |
    .downloads.custom_message //= "📲 *HTTP Custom*\n\n⬇️ Descargá desde:\n{URL}\n\nLuego importá tu archivo .hc (HWID) y conectá." |
    .transfer //= {"enabled":true,"titular":"","alias":"","cbu":"","admin_whatsapp":""} |
    .transfer.enabled //= true |
    .transfer.titular //= "" |
    .transfer.alias //= "" |
    .transfer.cbu //= "" |
    .transfer.admin_whatsapp //= (.links.support_whatsapp // "")
  )' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE" || true
  mkdir -p "$BOT_HOME/config" >/dev/null 2>&1 || true
  cp -f "$CONFIG_FILE" "$BOT_HOME/config/config.json" >/dev/null 2>&1 || true
  migrate_config
}


set_json() {
  local filter="$1"
  local tmp
  tmp="$(mktemp)"
  jq "$filter" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE" || true
  mkdir -p "$BOT_HOME/config" >/dev/null 2>&1 || true
  cp -f "$CONFIG_FILE" "$BOT_HOME/config/config.json" >/dev/null 2>&1 || true
  migrate_config
}

ensure_config() {
  ensure_dirs
  if [[ ! -s "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" <<'JSON'
{
  "bot": { "name": "SSH BOT ELNENE PRO", "version": "8.8.27" },
  "prices": {
    "test_hours": 2,
    "plan_7": 500,
    "plan_15": 800,
    "plan_30": 1200,
    "price_7d": 500,
    "price_15d": 800,
    "price_30d": 1200,
    "currency": "ARS"
  },
  "mercadopago": { "access_token": "", "enabled": false },
  "gemini": { "enabled": false, "api_key": "" },
  "links": {
    "tutorial": "https://youtube.com",
    "support": "https://t.me/soporte",
    "support_whatsapp": "",
    "telegram": ""
  },
  "downloads": {
    "apk_url": "",
    "custom_url": "",
    "custom_message": "📲 *HTTP Custom*\n\n⬇️ Descargá desde:\n{URL}\n\nLuego importá tu archivo .hc (HWID) y conectá."
  },
  "transfer": {
    "enabled": true,
    "alias": "",
    "cbu": "",
    "titular": "",
    "admin_whatsapp": ""
  }
}
JSON
    chmod 600 "$CONFIG_FILE" || true
  fi
  mkdir -p "$BOT_HOME/config" >/dev/null 2>&1 || true
  cp -f "$CONFIG_FILE" "$BOT_HOME/config/config.json" >/dev/null 2>&1 || true
}

ensure_db() {
  ensure_dirs
  sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT,
      username TEXT UNIQUE,
      password TEXT,
      tipo TEXT,
      expires_at DATETIME,
      max_connections INTEGER DEFAULT 1,
      status INTEGER DEFAULT 1,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      app_type TEXT DEFAULT '',
      hwid TEXT DEFAULT ''
    );" >/dev/null 2>&1 || true

  sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT,
      token TEXT UNIQUE,
      plan TEXT,
      expires_at TEXT,
      status TEXT DEFAULT 'active',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );" >/dev/null 2>&1 || true

  sqlite3 "$DB_FILE" "CREATE TABLE IF NOT EXISTS payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT,
      external_reference TEXT UNIQUE,
      preference_id TEXT,
      amount REAL,
      currency TEXT,
      status TEXT DEFAULT 'pending',
      plan TEXT,
      app_type TEXT,
      method TEXT DEFAULT 'mp',
      receipt_path TEXT,
      receipt_mime TEXT,
      reminded INTEGER DEFAULT 0,
      payment_url TEXT,
      qr_path TEXT,
      mp_payment_id TEXT,
      mp_status_detail TEXT,
      delivered INTEGER DEFAULT 0,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      approved_at TEXT
    );" >/dev/null 2>&1 || true

  # Campos extra (pagos MP + QR) – no rompe instalaciones anteriores
  for coldef in "method TEXT DEFAULT 'mp'" "receipt_path TEXT" "receipt_mime TEXT" "reminded INTEGER DEFAULT 0" "payment_url TEXT" "qr_path TEXT" "mp_payment_id TEXT" "mp_status_detail TEXT" "delivered INTEGER DEFAULT 0"; do
    col="${coldef%% *}"
    if ! sqlite3 "$DB_FILE" "PRAGMA table_info(payments);" 2>/dev/null | awk -F'|' '{print $2}' | grep -qx "$col"; then
      sqlite3 "$DB_FILE" "ALTER TABLE payments ADD COLUMN $coldef;" >/dev/null 2>&1 || true
    fi
  done
}

pm2_status() {
  pm2_resolve
  if [[ -z "${PM2_BIN}" ]]; then echo "OFF"; return; fi
  local st
  st="$(pm2_run jlist 2>/dev/null | jq -r '.[]|select(.name=="'"$BOT_NAME"'")|.pm2_env.status' | head -n1)"
  [[ -z "$st" || "$st" == "null" ]] && st="OFF"
  echo "$st"
}

count_users_total() {
  [[ -f "$DB_FILE" ]] || { echo 0; return; }
  sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo 0
}

count_users_active() {
  [[ -f "$DB_FILE" ]] || { echo 0; return; }
  sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE expires_at IS NULL OR datetime(expires_at) > datetime('now');" 2>/dev/null || echo 0
}

count_premium_active() {
  sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM users WHERE tipo='premium' AND (expires_at IS NULL OR datetime(expires_at) > datetime('now'));" 2>/dev/null || echo 0
}

estado_sistema() {
  local st total active mp apk prem
  st="$(pm2_status)"
  total="$(count_users_total)"
  active="$(count_users_active)"
  prem="$(count_premium_active)"
  mp="$(get_json '.mercadopago.access_token // empty')"
  [[ -n "$mp" && "$mp" != "null" ]] && mp="✅ ACTIVO" || mp="❌ NO CONFIG"
  [[ -n "$(ls -1 "$APK_DIR"/*.apk 2>/dev/null | head -n1)" ]] && apk="✅ DISPONIBLE" || apk="❌ NO"
  echo -e "${CYAN}📊 ESTADO DEL SISTEMA${NC}"
  echo "┌─────────────────────────────────────┐"
  echo "│ Bot WhatsApp: $st"
  echo "│ Usuarios: $active/$total activos/total"
  echo "│ Premium: $prem usuarios"
  echo "│ MercadoPago: $mp"
  echo "│ APK: $apk"
  echo "│ QR: $([[ -s "$QR_TXT" || -s "$QR_PNG" ]] && echo 'LISTO' || echo 'NO')"
  echo "└─────────────────────────────────────┘"
  echo
}

# ---------- BOT CONTROL ----------
bot_control_menu() {
  while true; do
    clear
    estado_sistema
    echo -e "${BOLD}🚀 Control bot (PM2)${NC}"
    echo "[1] Iniciar/Reiniciar"
    echo "[2] Detener"
    echo "[3] Ver logs"
    echo "[0] Volver"
    read -rp "Opción: " o
    case "$o" in
      1) if pm2_run describe "$BOT_NAME" >/dev/null 2>&1; then pm2_run restart "$BOT_NAME" >/dev/null 2>&1 || true; else pm2_run start "$BOT_HOME/bot.js" --name "$BOT_NAME" --cwd "$BOT_HOME" >/dev/null 2>&1 || true; fi; pm2_run save >/dev/null 2>&1 || true; echo "OK"; pausa ;;
      2) pm2_run stop "$BOT_NAME" >/dev/null 2>&1 || true; pm2_run save >/dev/null 2>&1 || true; echo "OK"; pausa ;;
      3) pm2_run logs "$BOT_NAME" --lines 220; pausa ;;
      0) return ;;
      *) echo "Inválido"; sleep 1 ;;
    esac
  done
}

# ---------- QR ----------
reset_whatsapp_session() {
  rm -rf "$BOT_HOME/.wwebjs_auth" "$BOT_HOME/.wwebjs_cache" "/root/.wwebjs_auth" "/root/.wwebjs_cache" >/dev/null 2>&1 || true
  rm -f "$QR_PNG" "$QR_TXT" >/dev/null 2>&1 || true
}

show_qr_console() {
  # Solo mostrar QR en consola si NO hay PNG (evita doble QR)
  if [[ -s "$QR_PNG" ]]; then
    return 0
  fi
  echo -e "${BOLD}🧾 QR en consola${NC}"
  echo
  if [[ -s "$QR_TXT" ]] && need_cmd qrencode; then
    qrencode -t ANSIUTF8 < "$QR_TXT" || true
    echo
    return 0
  fi
  pm2_run logs "$BOT_NAME" --lines 260 --nostream 2>/dev/null | tail -n 260 || true
}

show_qr_png() {
  if [[ -s "$QR_PNG" ]]; then
    echo -e "${GREEN}✅ PNG guardado: $QR_PNG${NC}"
    if need_cmd chafa; then
      chafa -s 70x40 "$QR_PNG" 2>/dev/null || true
    elif need_cmd ; then -w 60 "$QR_PNG" 2>/dev/null || true
    else
      echo -e "${YELLOW}No hay visor en terminal. Abrilo manualmente: ls -lah $QR_PNG${NC}"
    fi
  fi
}

ver_qr() {
  while true; do
    clear
    echo -e "${CYAN}${BOLD}📱 WhatsApp – QR / Vinculación${NC}"
    echo "----------------------------------------"
    echo "[1] Ver QR actual (sin borrar sesión)"
    echo "[2] Forzar QR nuevo (borrar sesión + reiniciar)"
    echo "[3] Ver logs (PM2)"
    echo "[0] Volver"
    echo
    read -rp "Opción: " q
    case "$q" in
      1)
        echo
        echo -e "${CYAN}🧾 Mostrando QR (si está disponible)...${NC}"
        echo
        show_qr_console || true
        echo
        show_qr_png || true
        pausa
        ;;
      2)
        clear
        echo -e "${CYAN}${BOLD}📱 Forzar QR NUEVO${NC}"
        echo "----------------------------------------"
        echo -e "${YELLOW}⚠️  Esto borra sesión y fuerza un QR NUEVO.${NC}"
        echo
        reset_whatsapp_session
        echo -e "${CYAN}🔁 Reiniciando bot...${NC}"
        if pm2_run describe "$BOT_NAME" >/dev/null 2>&1; then
          pm2_run restart "$BOT_NAME" >/dev/null 2>&1 || true
        else
          pm2_run start "$BOT_HOME/bot.js" --name "$BOT_NAME" --cwd "$BOT_HOME" >/dev/null 2>&1 || true
        fi
        pm2_run save >/dev/null 2>&1 || true

        echo -e "${CYAN}⏳ Esperando QR (hasta 120s)...${NC}"
        for i in {1..120}; do
          [[ -s "$QR_TXT" || -s "$QR_PNG" ]] && break
          sleep 1
        done
        echo
        show_qr_console || true
        echo
        show_qr_png || true
        echo
        echo -e "${CYAN}👉 Escanealo desde tu WhatsApp principal: Dispositivos vinculados.${NC}"
        pausa
        ;;
      3)
        pm2_run logs "$BOT_NAME" --lines 220
        pausa
        ;;
      0) return ;;
      *) echo "Opción inválida"; sleep 1 ;;
    esac
  done
}

# ---------- MERCADOPAGO ----------
mp_configurar_token() {
  ensure_config
  local curr
  curr="$(get_json '.mercadopago.access_token // empty')"
  clear
  echo -e "${CYAN}${BOLD}💳 MercadoPago – Token${NC}"
  echo "----------------------------------------"
  if [[ -n "$curr" && "$curr" != "null" ]]; then
    echo "Actual: ${curr:0:12}********"
  else
    echo "Actual: (vacío)"
  fi
  echo
  echo -e "${YELLOW}Formato válido:${NC} debe empezar con ${BOLD}APP_USR-${NC} (producción) o ${BOLD}TEST-${NC} (test)."
  echo
  read -rp "Pegá el nuevo token (enter=cancelar): " tok
  [[ -z "$tok" ]] && { echo "Cancelado."; pausa; return; }

  if [[ ! "$tok" =~ ^APP_USR- ]] && [[ ! "$tok" =~ ^TEST- ]]; then
    echo -e "${RED}❌ Token inválido.${NC}"
    echo -e "${YELLOW}Debe empezar con APP_USR- o TEST-${NC}"
    pausa
    return
  fi

  set_json ".mercadopago.access_token = \"$tok\" | .mercadopago.enabled = true"
  echo -e "${GREEN}✅ Token guardado.${NC}"
  echo -e "${YELLOW}🔄 Reiniciando bot para aplicar...${NC}"
  pm2_run restart "$BOT_NAME" >/dev/null 2>&1 || true
  pm2_run save >/dev/null 2>&1 || true
  pausa
}


# ---------- PRECIOS ----------
cambiar_precios() {
  ensure_config
  local p7 p15 p30
  p7="$(get_json '.prices.plan_7 // 0')"
  p15="$(get_json '.prices.plan_15 // 0')"
  p30="$(get_json '.prices.plan_30 // 0')"
  clear
  echo -e "${CYAN}${BOLD}💲 Precios${NC}"
  echo "7 días : $p7"
  echo "15 días: $p15"
  echo "30 días: $p30"
  echo
  read -rp "Nuevo 7 días (enter=mantener): " np7
  read -rp "Nuevo 15 días (enter=mantener): " np15
  read -rp "Nuevo 30 días (enter=mantener): " np30
  [[ -z "$np7" ]] && np7="$p7"
  [[ -z "$np15" ]] && np15="$p15"
  [[ -z "$np30" ]] && np30="$p30"
  set_json ".prices.plan_7 = ($np7|tonumber) | .prices.plan_15 = ($np15|tonumber) | .prices.plan_30 = ($np30|tonumber)"
  echo -e "${GREEN}✅ Precios actualizados.${NC}"
  pausa
}

# ---------- APK ----------
apk_menu() {
  ensure_dirs
  while true; do
    clear
    echo -e "${CYAN}${BOLD}📲 Gestión APK${NC}"
    echo "[1] Listar APK"
    echo "[2] Subir APK (descargar por URL)"
    echo "[4] Importar APK desde /root (copiar)"
    echo "[3] Borrar APK"
    echo "[0] Volver"
    read -rp "Opción: " o
    case "$o" in
      1)
        ls -lah "$APK_DIR"/*.apk 2>/dev/null || echo "No hay APKs."
        pausa
        ;;
      2)
        read -rp "URL directa del .apk: " url
        [[ -z "$url" ]] && { echo "Cancelado."; pausa; continue; }
        fn="$(basename "$url")"
        [[ "$fn" != *.apk ]] && fn="app_$(date +%s).apk"
        wget -qO "$APK_DIR/$fn" "$url" || curl -fsSL "$url" -o "$APK_DIR/$fn" || true
        if [[ -s "$APK_DIR/$fn" ]]; then
          echo -e "${GREEN}✅ Guardado: $APK_DIR/$fn${NC}"
        else
          rm -f "$APK_DIR/$fn" >/dev/null 2>&1 || true
          echo -e "${RED}❌ No pude descargar.${NC}"
        fi
        pausa
        ;;
      3)
        ls -1 "$APK_DIR"/*.apk 2>/dev/null || { echo "No hay APKs."; pausa; continue; }
        echo
        read -rp "Nombre exacto a borrar (ej: algo.apk): " name
        [[ -z "$name" ]] && { echo "Cancelado."; pausa; continue; }
        rm -f "$APK_DIR/$name" >/dev/null 2>&1 || true
        echo "OK"
        pausa
        ;;
      4)
        # Importar APK desde /root (copiar a $APK_DIR)
        mapfile -t found < <(find /root -maxdepth 2 -type f -name "*.apk" 2>/dev/null | sort -r)
        if [[ "${#found[@]}" -eq 0 ]]; then
          echo "No encontré .apk en /root."
          echo "Tip: subí tu APK a /root/app.apk"
          pausa
          continue
        fi
        echo
        echo "APKs encontrados en /root:"
        local idx=1
        for f in "${found[@]}"; do
          local sz; sz="$(du -h "$f" 2>/dev/null | awk '{print $1}')"
          echo "  [$idx] $f  ($sz)"
          idx=$((idx+1))
        done
        echo
        read -rp "Elegí número para copiar a $APK_DIR (0=cancelar): " sel
        [[ -z "$sel" || "$sel" == "0" ]] && { echo "Cancelado."; pausa; continue; }
        if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#found[@]} )); then
          echo "Inválido."
          pausa
          continue
        fi
        src_apk="${found[$((sel-1))]}"
        base="$(basename "$src_apk")"
        cp -f "$src_apk" "$APK_DIR/$base" >/dev/null 2>&1 || true
        if [[ -s "$APK_DIR/$base" ]]; then
          chmod 644 "$APK_DIR/$base" >/dev/null 2>&1 || true
          echo -e "${GREEN}✅ Importado: $APK_DIR/$base${NC}"
        else
          rm -f "$APK_DIR/$base" >/dev/null 2>&1 || true
          echo -e "${RED}❌ No pude copiar.${NC}"
        fi
        pausa
        ;;
      0) return ;;
      *) echo "Inválido"; sleep 1 ;;
    esac
  done
}

# ---------- HC / HWID ----------
hc_menu() {
  ensure_dirs
  while true; do
    clear
    echo -e "${CYAN}${BOLD}🧩 Gestión .hc (HWID)${NC}"
    echo "[1] Listar .hc (plantillas en /root + generado por HWID)"
    echo "[2] Seleccionar .hc ACTIVO (plantilla en /root)"
    echo "[3] Importar .hc desde /root (solo seleccionar)"
    echo "[4] Crear .hc manual (por HWID)"
    echo "[5] Borrar .hc"
    echo "[0] Volver"
    read -rp "Opción: " o
    case "$o" in
1)
  echo -e "${YELLOW}📌 Plantillas (.hc) en /root:${NC}"
  ls -lah "$HC_TEMPLATE_DIR"/*.hc 2>/dev/null || echo "No hay plantillas .hc en /root."
  echo
  echo -e "${YELLOW}📌 Generados por HWID (bot):${NC}"
  ls -lah "$HC_DIR"/*.hc 2>/dev/null || echo "No hay .hc generados."
  echo
  local active
  active=$(jq -r "$HC_ACTIVE_KEY" "$CONFIG_FILE" 2>/dev/null || echo "")
  [[ "$active" == "null" ]] && active=""
  echo -e "${CYAN}HC activo:${NC} ${active:-"(no configurado)"}"
  pausa
  ;;
2)
  echo -e "${CYAN}${BOLD}✅ Seleccionar .hc ACTIVO (plantilla)${NC}"
  echo -e "${YELLOW}Subí tu .hc a /root y elegilo de la lista.${NC}"
  mapfile -t files < <(ls -1 "$HC_TEMPLATE_DIR"/*.hc 2>/dev/null || true)
  if [[ "${#files[@]}" -eq 0 ]]; then
    echo "No hay .hc en /root."
    pausa
    continue
  fi
  echo
  for i in "${!files[@]}"; do
    echo "[$((i+1))] ${files[$i]}"
  done
  echo "[0] Cancelar"
  read -rp "Elegí: " sel
  if [[ "$sel" == "0" ]]; then
        pausa
        continue
      fi
  if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel>=1 && sel<=${#files[@]} )); then
    chosen="${files[$((sel-1))]}"
    cfg_set_json "$HC_ACTIVE_KEY" "\"$chosen\""
    echo -e "${GREEN}✅ HC activo seteado:${NC} $chosen"
  else
    echo "Opción inválida."
  fi
  pausa
  ;;
3)
  echo -e "${CYAN}${BOLD}📥 Importar .hc desde /root${NC}"
  echo -e "${YELLOW}Esto NO crea nada manualmente: solo toma un archivo existente en /root y lo deja como ACTIVO.${NC}"
  echo -e "Subí tu archivo a /root (SCP/SFTP) y luego usá la opción [2]."
  pausa
  ;;
4)
  read -rp "HWID: " hw
  [[ -z "$hw" ]] && { echo "HWID vacío"; pausa; continue; }
  read -rp "USER (vacío=HWID): " u
  read -rp "PASS (vacío=HWID): " p
  [[ -z "$u" ]] && u="$hw"
  [[ -z "$p" ]] && p="$hw"
  mkdir -p "$HC_DIR"
  fp="$HC_DIR/${hw}.hc"
  echo -e "HWID=${hw}\nUSER=${u}\nPASS=${p}\n" > "$fp"
  chmod 600 "$fp"
  echo -e "${GREEN}✅ Creado:${NC} $fp"
  pausa
  ;;
5)
  echo -e "${CYAN}${BOLD}🗑️ Borrar .hc${NC}"
  echo "[1] Borrar plantilla en /root"
  echo "[2] Borrar generado por HWID (bot)"
  echo "[0] Cancelar"
  read -rp "Elegí: " which
  case "$which" in
    1)
      mapfile -t files < <(ls -1 "$HC_TEMPLATE_DIR"/*.hc 2>/dev/null || true)
      [[ "${#files[@]}" -eq 0 ]] && { echo "No hay plantillas."; pausa; break; }
      for i in "${!files[@]}"; do echo "[$((i+1))] ${files[$i]}"; done
      echo "[0] Cancelar"
      read -rp "Elegí: " sel
      [[ "$sel" == "0" ]] && { pausa; break; }
      if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel>=1 && sel<=${#files[@]} )); then
        rm -f "${files[$((sel-1))]}"
        echo "OK"
      else
        echo "Inválido"
      fi
      pausa
      ;;
    2)
      mapfile -t files < <(ls -1 "$HC_DIR"/*.hc 2>/dev/null || true)
      [[ "${#files[@]}" -eq 0 ]] && { echo "No hay generados."; pausa; break; }
      for i in "${!files[@]}"; do echo "[$((i+1))] ${files[$i]}"; done
      echo "[0] Cancelar"
      read -rp "Elegí: " sel
      [[ "$sel" == "0" ]] && { pausa; break; }
      if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel>=1 && sel<=${#files[@]} )); then
        rm -f "${files[$((sel-1))]}"
        echo "OK"
      else
        echo "Inválido"
      fi
      pausa
      ;;
    *) pausa ;;
  esac
  ;;
    esac
  done
}

# ---------- USUARIOS ----------
usuarios_menu() {
  ensure_db

  auto_user(){ echo "user$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)"; }
  auto_pass(){ tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12; }

  user_online_sessions() {
    local u="$1"
    # Count sshd processes running as user (best effort)
    local c
    c="$(pgrep -u "$u" -c sshd 2>/dev/null || echo 0)"
    [[ -z "$c" ]] && c=0
    echo "$c"
  }

  list_users() {
    echo -e "${CYAN}${BOLD}👥 Usuarios (con online)${NC}"
    echo
    mapfile -t rows < <(sqlite3 -separator '|' "$DB_FILE" "SELECT username,tipo,expires_at,max_connections,status FROM users ORDER BY id DESC LIMIT 80;")
    if [[ "${#rows[@]}" -eq 0 ]]; then
      echo "(sin usuarios)"
      return
    fi

    printf "%-18s %-8s %-19s %-6s %-7s %-8s\n" "USERNAME" "TIPO" "EXPIRES" "MAX" "STATUS" "ONLINE"
    printf "%-18s %-8s %-19s %-6s %-7s %-8s\n" "------------------" "--------" "-------------------" "------" "-------" "--------"
    for r in "${rows[@]}"; do
      IFS='|' read -r u tipo exp mc st <<< "$r"
      [[ -z "$u" ]] && continue
      local on="0"
      if id -u "$u" >/dev/null 2>&1; then
        on="$(user_online_sessions "$u")"
      fi
      [[ -z "$mc" ]] && mc="1"
      [[ -z "$st" ]] && st="1"
      printf "%-18s %-8s %-19s %-6s %-7s %-8s\n" "$u" "${tipo:-?}" "${exp:-NULL}" "$mc" "$st" "$on"
    done
  }

  create_user_manual() {
    clear
    echo -e "${CYAN}${BOLD}👤 Crear usuario manual${NC}"
    echo "----------------------------------------"
    read -rp "Teléfono (opcional): " phone
    read -rp "Usuario (vacío=auto): " u
    read -rp "Contraseña (vacío=auto): " p
    read -rp "Días (0=test 2h): " days
    read -rp "Conexiones max (1): " mc
    read -rp "Tipo (test/premium) (auto): " tipo

    [[ -z "$u" ]] && u="$(auto_user)"
    [[ -z "$p" ]] && p="$(auto_pass)"
    [[ -z "$days" ]] && days="30"
    [[ -z "$mc" ]] && mc="1"

    if [[ "$days" == "0" ]]; then
      tipo="test"
      exp_full="$(date -d "+2 hours" "+%Y-%m-%d %H:%M:%S")"
      exp_date="$(date -d "+2 hours" "+%Y-%m-%d")"
    else
      [[ -z "$tipo" ]] && tipo="premium"
      exp_full="$(date -d "+${days} days 23:59:59" "+%Y-%m-%d %H:%M:%S")"
      exp_date="$(date -d "+${days} days" "+%Y-%m-%d")"
    fi

    # DB
    if sqlite3 "$DB_FILE" "SELECT 1 FROM users WHERE username='$u' LIMIT 1;" 2>/dev/null | grep -q 1; then
      echo -e "${RED}❌ Ya existe en DB: $u${NC}"
      pausa; return
    fi

    # Linux user
    if id -u "$u" >/dev/null 2>&1; then
      echo -e "${YELLOW}⚠️ Ya existe en Linux: $u (no recreo)${NC}"
      echo "$u:$p" | chpasswd >/dev/null 2>&1 || true
    else
      useradd -m -s /bin/bash "$u" >/dev/null 2>&1 || { echo -e "${RED}❌ Error useradd${NC}"; pausa; return; }
      echo "$u:$p" | chpasswd >/dev/null 2>&1 || true
    fi
    chage -E "$exp_date" "$u" >/dev/null 2>&1 || true

    sqlite3 "$DB_FILE" "INSERT INTO users(phone,username,password,tipo,expires_at,max_connections,status) VALUES('${phone}','${u}','${p}','${tipo}','${exp_full}',${mc},1);" >/dev/null 2>&1 || {
      echo -e "${RED}❌ Error insert DB${NC}"
      pausa; return
    }

    echo
    echo -e "${GREEN}✅ Usuario creado${NC}"
    echo "👤 $u"
    echo "🔑 $p"
    echo "⏰ Expira: $exp_full"
    echo "🔌 Max conexiones: $mc"
    pausa
  }

  renovar_usuario() {
    clear
    echo -e "${CYAN}${BOLD}📅 Renovar / Cambiar fecha${NC}"
    echo "----------------------------------------"
    read -rp "Username: " u
    [[ -z "$u" ]] && { echo "Cancelado."; pausa; return; }

    local cur
    cur="$(sqlite3 "$DB_FILE" "SELECT expires_at FROM users WHERE username='$u' LIMIT 1;" 2>/dev/null || true)"
    if [[ -z "$cur" || "$cur" == "null" ]]; then
      cur="$(date "+%Y-%m-%d %H:%M:%S")"
    fi

    echo "Actual expires_at: ${cur}"
    echo
    read -rp "Días a sumar (0=test 2h desde ahora): " days
    [[ -z "$days" ]] && { echo "Cancelado."; pausa; return; }

    if [[ "$days" == "0" ]]; then
      new_full="$(date -d "+2 hours" "+%Y-%m-%d %H:%M:%S")"
      new_date="$(date -d "+2 hours" "+%Y-%m-%d")"
      sqlite3 "$DB_FILE" "UPDATE users SET tipo='test', expires_at='${new_full}', status=1 WHERE username='${u}';" >/dev/null 2>&1 || true
    else
      # base: si estaba vencido, renovamos desde ahora
      base_ts="$(date -d "$cur" +%s 2>/dev/null || date +%s)"
      now_ts="$(date +%s)"
      [[ "$base_ts" -lt "$now_ts" ]] && base_ts="$now_ts"
      base_fmt="$(date -d "@$base_ts" "+%Y-%m-%d %H:%M:%S")"
      new_full="$(date -d "$base_fmt +${days} days" "+%Y-%m-%d 23:59:59")"
      new_date="$(date -d "$base_fmt +${days} days" "+%Y-%m-%d")"
      sqlite3 "$DB_FILE" "UPDATE users SET tipo='premium', expires_at='${new_full}', status=1 WHERE username='${u}';" >/dev/null 2>&1 || true
    fi

    if id -u "$u" >/dev/null 2>&1; then
      chage -E "$new_date" "$u" >/dev/null 2>&1 || true
    fi

    echo -e "${GREEN}✅ Actualizado${NC} -> $new_full"
    pausa
  }

  cambiar_clave() {
    clear
    echo -e "${CYAN}${BOLD}🔑 Cambiar contraseña${NC}"
    echo "----------------------------------------"
    read -rp "Username: " u
    [[ -z "$u" ]] && { echo "Cancelado."; pausa; return; }
    read -rp "Nueva contraseña (vacío=auto): " p
    [[ -z "$p" ]] && p="$(auto_pass)"

    if id -u "$u" >/dev/null 2>&1; then
      echo "$u:$p" | chpasswd >/dev/null 2>&1 || true
    fi
    sqlite3 "$DB_FILE" "UPDATE users SET password='${p}' WHERE username='${u}';" >/dev/null 2>&1 || true

    echo -e "${GREEN}✅ Clave actualizada${NC}"
    echo "👤 $u"
    echo "🔑 $p"
    pausa
  }

  cambiar_conexiones() {
    clear
    echo -e "${CYAN}${BOLD}🔌 Cambiar max conexiones${NC}"
    echo "----------------------------------------"
    read -rp "Username: " u
    [[ -z "$u" ]] && { echo "Cancelado."; pausa; return; }
    read -rp "Nuevo max (1): " mc
    [[ -z "$mc" ]] && mc="1"

    sqlite3 "$DB_FILE" "UPDATE users SET max_connections=${mc} WHERE username='${u}';" >/dev/null 2>&1 || true

    # Si está pasado, cortar sshd
    if id -u "$u" >/dev/null 2>&1; then
      on="$(user_online_sessions "$u")"
      if [[ "$on" -gt "$mc" ]]; then
        pkill -u "$u" -x sshd >/dev/null 2>&1 || true
      fi
    fi

    echo -e "${GREEN}✅ Max conexiones actualizado${NC} -> $mc"
    pausa
  }

  eliminar_usuario() {
    clear
    echo -e "${CYAN}${BOLD}🗑️ Eliminar usuario${NC}"
    echo "----------------------------------------"
    read -rp "Username a borrar: " u
    [[ -z "$u" ]] && { echo "Cancelado."; pausa; return; }
    sqlite3 "$DB_FILE" "DELETE FROM users WHERE username='${u}';" >/dev/null 2>&1 || true
    if id -u "$u" >/dev/null 2>&1; then
      pkill -u "$u" >/dev/null 2>&1 || true
      userdel -r "$u" >/dev/null 2>&1 || true
    fi
    echo -e "${GREEN}✅ Borrado: $u${NC}"
    pausa
  }

  eliminar_expirados() {
    mapfile -t exp < <(sqlite3 "$DB_FILE" "SELECT username FROM users WHERE expires_at IS NOT NULL AND datetime(expires_at) <= datetime('now');" 2>/dev/null || true)
    if [[ "${#exp[@]}" -eq 0 ]]; then
      echo "No hay expirados."
      pausa; return
    fi
    echo "Expirados:"
    printf ' - %s\n' "${exp[@]}"
    echo
    read -rp "¿Eliminar TODOS? (s/N): " yn
    [[ ! "$yn" =~ ^[Ss]$ ]] && { echo "Cancelado."; pausa; return; }
    for u in "${exp[@]}"; do
      sqlite3 "$DB_FILE" "DELETE FROM users WHERE username='${u}';" >/dev/null 2>&1 || true
      if id -u "$u" >/dev/null 2>&1; then
        pkill -u "$u" >/dev/null 2>&1 || true
        userdel -r "$u" >/dev/null 2>&1 || true
      fi
    done
    echo -e "${GREEN}✅ Expirados eliminados: ${#exp[@]}${NC}"
    pausa
  }

  conectados_ahora() {
    clear
    echo -e "${CYAN}${BOLD}🔌 Conectados ahora (best-effort)${NC}"
    echo "----------------------------------------"
    echo -e "${YELLOW}who:${NC}"
    who || true
    echo
    echo -e "${YELLOW}sshd (procesos):${NC}"
    ps -eo user,comm,args | grep -E "sshd: " | grep -v grep || echo "(sin sshd visibles)"
    echo
    pausa
  }

  while true; do
    clear
    echo -e "${CYAN}${BOLD}👥 Usuarios (DB + Linux)${NC}"
    echo "[1] Listar (con online)"
    echo "[2] Crear usuario manual"
    echo "[3] Renovar / Cambiar fecha"
    echo "[4] Cambiar contraseña"
    echo "[5] Cambiar conexiones"
    echo "[6] Eliminar usuario (DB + Linux)"
    echo "[7] Eliminar expirados (DB + Linux)"
    echo "[8] Conectados ahora"
    echo "[0] Volver"
    echo
    read -rp "Opción: " o
    case "$o" in
      1) clear; list_users; pausa ;;
      2) create_user_manual ;;
      3) renovar_usuario ;;
      4) cambiar_clave ;;
      5) cambiar_conexiones ;;
      6) eliminar_usuario ;;
      7) eliminar_expirados ;;
      8) conectados_ahora ;;
      0) return ;;
      *) echo "Inválido"; sleep 1 ;;
    esac
  done
}

tokens_menu() {
  ensure_db
  while true; do
    clear
    echo -e "${CYAN}${BOLD}🔑 Tokens (Token-Only)${NC}"
    echo "[1] Listar (últimos 60)"
    echo "[2] Generar token"
    echo "[3] Revocar token"
    echo "[0] Volver"
    read -rp "Opción: " o
    case "$o" in
      1)
        sqlite3 -header -column "$DB_FILE" "SELECT token,plan,expires_at,status,created_at FROM tokens ORDER BY id DESC LIMIT 60;"
        pausa
        ;;
      2)
        read -rp "Phone (solo números, opcional): " ph
        read -rp "Plan (7/15/30/test): " pl
        [[ -z "$pl" ]] && { echo "Cancelado."; pausa; continue; }
        tok="TKN_$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22)"
        exp=""
        case "$pl" in
          7) exp="$(date -u -d '+7 days' '+%F %T')" ;;
          15) exp="$(date -u -d '+15 days' '+%F %T')" ;;
          30) exp="$(date -u -d '+30 days' '+%F %T')" ;;
          test) exp="$(date -u -d '+1 days' '+%F %T')" ;;
          *) exp="" ;;
        esac
        sqlite3 "$DB_FILE" "INSERT INTO tokens(phone,token,plan,expires_at,status) VALUES('$ph','$tok','$pl','$exp','active');" >/dev/null 2>&1 || true
        echo -e "${GREEN}✅ Token: $tok${NC}"
        echo "Expira: ${exp:-∞}"
        pausa
        ;;
      3)
        read -rp "Token a revocar: " t
        [[ -z "$t" ]] && { echo "Cancelado."; pausa; continue; }
        sqlite3 "$DB_FILE" "UPDATE tokens SET status='revoked' WHERE token='$t';" >/dev/null 2>&1 || true
        echo "OK"
        pausa
        ;;
      0) return ;;
      *) echo "Inválido"; sleep 1 ;;
    esac
  done
}

# ---------- ESTADÍSTICAS ----------
stats_menu() {
  ensure_db
  clear
  echo -e "${CYAN}${BOLD}📊 Estadísticas / Ventas / Ganancias${NC}"
  local total approved sum
  total="$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM payments;" 2>/dev/null || echo 0)"
  approved="$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM payments WHERE status='approved';" 2>/dev/null || echo 0)"
  sum="$(sqlite3 "$DB_FILE" "SELECT IFNULL(SUM(amount),0) FROM payments WHERE status='approved';" 2>/dev/null || echo 0)"
  echo "• Pagos totales: $total"
  echo "• Aprobados: $approved"
  echo "• Ganancia aprobada: $sum"
  echo
  echo -e "${BOLD}Últimos 20 pagos:${NC}"
  sqlite3 -header -column "$DB_FILE" "SELECT phone,amount,currency,status,plan,app_type,created_at FROM payments ORDER BY id DESC LIMIT 20;" 2>/dev/null || true
  pausa
}

# ---------- MIGRAR ----------
migrar_usuario_a_token() {
  ensure_db
  clear
  echo -e "${CYAN}${BOLD}🔁 Migrar usuario -> Token${NC}"
  read -rp "Username: " u
  [[ -z "$u" ]] && { echo "Cancelado."; pausa; return; }
  local row
  row="$(sqlite3 -separator '|' "$DB_FILE" "SELECT phone,expires_at,tipo FROM users WHERE username='$u' LIMIT 1;")"
  if [[ -z "$row" ]]; then
    echo "No existe."
    pausa
    return
  fi
  local ph exp tipo
  ph="$(cut -d'|' -f1 <<<"$row")"
  exp="$(cut -d'|' -f2 <<<"$row")"
  tipo="$(cut -d'|' -f3 <<<"$row")"

  tok="TKN_$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 22)"
  sqlite3 "$DB_FILE" "INSERT INTO tokens(phone,token,plan,expires_at,status) VALUES('$ph','$tok','$tipo','$exp','active');" >/dev/null 2>&1 || true
  sqlite3 "$DB_FILE" "DELETE FROM users WHERE username='$u';" >/dev/null 2>&1 || true
  id -u "$u" >/dev/null 2>&1 && userdel -r "$u" >/dev/null 2>&1 || true

  echo -e "${GREEN}✅ Migrado.${NC}"
  echo "Token: $tok"
  echo "Expira: ${exp:-∞}"
  pausa
}

# ---------- UPDATE ----------
update_menu() {
  clear
  echo -e "${CYAN}${BOLD}🔄 Update (anti-cuelgue)${NC}"
  echo "Esto ejecuta: npm install + restart PM2 (si hay git también hace pull)."
  echo
  if [[ -d "$BOT_HOME/.git" ]]; then
    echo -e "${CYAN}➡️ git pull...${NC}"
    (cd "$BOT_HOME" && git pull) || true
  fi
  echo -e "${CYAN}➡️ npm install...${NC}"
  (cd "$BOT_HOME" && npm install --silent) || true
  echo -e "${CYAN}➡️ restart PM2...${NC}"
  if pm2_run describe "$BOT_NAME" >/dev/null 2>&1; then
    pm2_run restart "$BOT_NAME" >/dev/null 2>&1 || true
  else
    pm2_run start "$BOT_HOME/bot.js" --name "$BOT_NAME" --cwd "$BOT_HOME" >/dev/null 2>&1 || true
  fi
  pm2_run save >/dev/null 2>&1 || true
  echo -e "${GREEN}✅ Update OK.${NC}"
  pausa
}


# ---------- AJUSTES (Soporte / IA / Descargas) ----------
ajustes_menu() {
  ensure_config
  while true; do
    clear
    echo -e "${CYAN}${BOLD}⚙️ Ajustes${NC}"
    echo "[1] 📞 Soporte (WhatsApp / Telegram / Link)"
    echo "[2] 🧠 IA Gemini (API Key)"
    echo "[3] 🌐 Descargas (APK URL / HTTP Custom)"
    echo "[0] Volver"
    echo
    read -rp "Opción: " o
    case "$o" in
      1) ajustar_soporte ;;
      2) ajustar_gemini ;;
      3) ajustar_descargas ;;
      0) return ;;
      *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1 ;;
    esac
  done
}


transfer_menu() {
  while true; do
    header "🏦 Transferencias"
    echo "Datos actuales para recibir transferencias:"
    echo "  Titular : $(get_json '.transfer.titular')"
    echo "  Alias   : $(get_json '.transfer.alias')"
    echo "  CBU     : $(get_json '.transfer.cbu')"
    echo "  Admin WA: $(get_json '.transfer.admin_whatsapp')"
    echo ""
    echo "[1] ✏️  Editar datos (Titular/Alias/CBU)"
    echo "[2] 📲 Editar número admin WhatsApp (para confirmar)"
    echo "[3] 📋 Ver pagos pendientes (Transferencia)"
    echo "[4] ✅ Confirmar pago (por REF)"
    echo "[5] ❌ Rechazar / borrar pago (por REF)"
    echo "[0] ↩️  Volver"
    read -rp "Opción: " op
    case "$op" in
      1)
        read -rp "Titular (Nombre y Apellido): " titular
        read -rp "Alias: " alias
        read -rp "CBU: " cbu
        [[ -n "$titular" ]] && set_json ".transfer.titular = \"${titular}\""
        [[ -n "$alias" ]] && set_json ".transfer.alias = \"${alias}\""
        [[ -n "$cbu" ]] && set_json ".transfer.cbu = \"${cbu}\""
        ok "Datos actualizados."
        pause
        ;;
      2)
        echo "Formato: solo números con código país (ej: 5491122334455)"
        read -rp "Número admin WhatsApp: " nwa
        nwa="$(echo "$nwa" | tr -cd '0-9')"
        [[ -n "$nwa" ]] && set_json ".transfer.admin_whatsapp = \"${nwa}\""
        ok "Número admin actualizado."
        pause
        ;;
      3)
        header "📋 Pagos pendientes - Transferencias"
        ensure_db
        sqlite3 -header -column "$DB" "SELECT external_reference AS REF, substr(phone,1,15) AS TEL, plan AS PLAN, app_type AS APP, amount AS MONTO, status AS ESTADO, created_at AS FECHA FROM payments WHERE method='transfer' AND status='pending_admin' ORDER BY id DESC LIMIT 50;" 2>/dev/null || true
        echo ""
        echo "Tip: confirmá desde [4] con la REF."
        pause
        ;;
      4)
        ensure_db
        read -rp "REF a confirmar: " ref
        [[ -z "$ref" ]] && continue
        sqlite3 "$DB" "UPDATE payments SET status='approved', approved_at=datetime('now') WHERE external_reference='$ref' AND method='transfer' AND status='pending_admin';" 2>/dev/null || true
        ok "Marcado como APPROVED. El bot entregará automáticamente en 1-2 min."
        pause
        ;;
      5)
        ensure_db
        read -rp "REF a rechazar/borrar: " ref
        [[ -z "$ref" ]] && continue
        sqlite3 "$DB" "UPDATE payments SET status='rejected' WHERE external_reference='$ref' AND method='transfer' AND status='pending_admin';" 2>/dev/null || true
        ok "Marcado como REJECTED."
        pause
        ;;
      0) return ;;
      *) warn "Opción inválida"; sleep 1 ;;
    esac
  done
}

ajustar_soporte() {
  ensure_config
  local sup wa tg tut
  sup="$(get_json '.links.support // ""')"
  wa="$(get_json '.links.support_whatsapp // ""')"
  tg="$(get_json '.links.telegram // ""')"
  tut="$(get_json '.links.tutorial // ""')"

  clear
  echo -e "${CYAN}${BOLD}📞 Configurar soporte y links${NC}"
  echo "----------------------------------------"
  echo "• Soporte (link):        ${sup}"
  echo "• WhatsApp (wa.me):      ${wa}"
  echo "• Telegram (t.me/alias): ${tg}"
  echo "• Tutorial:              ${tut}"
  echo
  read -rp "Nuevo link soporte (enter=mantener): " nsup
  read -rp "Nuevo link WhatsApp wa.me (enter=mantener): " nwa
  read -rp "Nuevo alias/link Telegram (enter=mantener): " ntg
  read -rp "Nuevo link tutorial (enter=mantener): " ntut

  [[ -z "$nsup" ]] && nsup="$sup"
  [[ -z "$nwa" ]] && nwa="$wa"
  [[ -z "$ntg" ]] && ntg="$tg"
  [[ -z "$ntut" ]] && ntut="$tut"

  set_json ".links.support = \"$nsup\" | .links.support_whatsapp = \"$nwa\" | .links.telegram = \"$ntg\" | .links.tutorial = \"$ntut\""
  echo -e "${GREEN}✅ Guardado.${NC}"
  echo -e "${YELLOW}Tip: reiniciá el bot (PM2) para aplicar al instante si no actualiza solo.${NC}"
  pausa
}

ajustar_gemini() {
  ensure_config
  local en key
  en="$(get_json '.gemini.enabled // false')"
  key="$(get_json '.gemini.api_key // ""')"

  clear
  echo -e "${CYAN}${BOLD}🧠 IA Gemini${NC}"
  echo "----------------------------------------"
  echo "Estado: $en"
  if [[ -n "$key" && "$key" != "null" ]]; then
    echo "Key: ${key:0:8}********"
  else
    echo "Key: (vacía)"
  fi
  echo
  read -rp "¿Habilitar IA? (s/N): " yn
  if [[ "$yn" == "s" || "$yn" == "S" ]]; then
    set_json ".gemini.enabled = true"
  elif [[ "$yn" == "n" || "$yn" == "N" || -z "$yn" ]]; then
    # no cambia
    :
  fi

  read -rp "Pegar API Key (enter=mantener): " nk
  [[ -n "$nk" ]] && set_json ".gemini.api_key = \"$nk\""

  echo -e "${GREEN}✅ Configurado.${NC}"
  echo -e "${YELLOW}Recomendado: reiniciar bot para aplicar (PM2 -> restart).${NC}"
  pausa
}

ajustar_descargas() {
  ensure_config
  local apkurl curl cmsg
  apkurl="$(get_json '.downloads.apk_url // ""')"
  curl="$(get_json '.downloads.custom_url // ""')"
  cmsg="$(get_json '.downloads.custom_message // ""')"

  clear
  echo -e "${CYAN}${BOLD}🌐 Descargas (cliente)${NC}"
  echo "----------------------------------------"
  echo "APK URL (si no se envía archivo):"
  echo "  $apkurl"
  echo
  echo "HTTP Custom URL:"
  echo "  $curl"
  echo
  echo "Mensaje HTTP Custom (usa {URL} como placeholder):"
  echo "  $(echo "$cmsg" | head -n 3)"
  echo
  read -rp "Nuevo APK URL (enter=mantener): " napk
  read -rp "Nuevo HTTP Custom URL (enter=mantener): " ncurl
  echo
  echo "Editar mensaje HTTP Custom ahora? (s/N)"
  read -rp "> " edit
  if [[ "$edit" == "s" || "$edit" == "S" ]]; then
    echo "Pegá el mensaje completo. Terminá con una línea que diga: EOF"
    tmp="$(mktemp)"
    while IFS= read -r line; do
      [[ "$line" == "EOF" ]] && break
      echo "$line" >> "$tmp"
    done
    newmsg="$(cat "$tmp")"
    rm -f "$tmp"
    [[ -n "$newmsg" ]] && cmsg="$newmsg"
  fi

  [[ -z "$napk" ]] && napk="$apkurl"
  [[ -z "$ncurl" ]] && ncurl="$curl"

  set_json ".downloads.apk_url = \"$napk\" | .downloads.custom_url = \"$ncurl\" | .downloads.custom_message = \"$cmsg\""
  echo -e "${GREEN}✅ Guardado.${NC}"
  pausa
}

main_menu() {
  require_root
  ensure_dirs
  ensure_config
  ensure_db
  ensure_runtime

  while true; do
    clear
    estado_sistema
    echo "[1] 🚀 Control bot (PM2)"
    echo "[2] 📱 Ver QR WhatsApp"
    echo "[3] 💳 MercadoPago: configurar token"
    echo "[4] 💲 Cambiar precios (7/15/30)"
    echo "[5] 📲 Gestión APK"
    echo "[6] 🧩 Gestión .hc (HWID)"
    echo "[7] 👥 Usuarios (DB + expirados + conectados)"
    echo "[8] 🔑 Tokens (Token-Only)"
    echo "[9] 📊 Estadísticas / Ventas / Ganancias"
    echo "[10] 🔁 Migrar usuario -> Token"
    echo "[11] 🔄 Update (npm install + restart)"
    echo "[12] ⚙️ Ajustes (Soporte / IA / Descargas)"
    echo "[0] 🚪 Salir"
    echo
    read -rp "Opción: " opt
    case "$opt" in
      1) bot_control_menu ;;
      2) ver_qr ;;
      3) mp_configurar_token ;;
      4) cambiar_precios ;;
      5) apk_menu ;;
      6) hc_menu ;;
      7) usuarios_menu ;;
      8) tokens_menu ;;
      9) stats_menu ;;
      10) migrar_usuario_a_token ;;
      11) update_menu ;;
      12) ajustes_menu ;;
      13) transfer_menu ;;
      0) exit 0 ;;
      *) echo -e "${RED}❌ Opción inválida${NC}"; sleep 1 ;;
    esac
  done
}

main_menu
