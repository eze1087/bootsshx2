#!/usr/bin/env bash
set -euo pipefail
if (set -o pipefail 2>/dev/null); then set -o pipefail; fi

# ================================================
# SSH BOT ELNENE PRO – INSTALADOR UNIFICADO (EMBED)
# Version: 8.8.27
# ================================================

BOT_VERSION="8.8.27"
BOT_NAME="ssh-bot"

INSTALL_DIR="/opt/ssh-bot"
BOT_HOME="/root/ssh-bot"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"

# Ruta del instalador (para ubicar panel_admin.sh local)
SCRIPT_PATH="${SCRIPT_PATH:-$0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     ███████╗███████╗██║  ██║    ██████╗  ██████╗ ████████╗  ║
║     ██╔════╝██╔════╝██║  ██║    ██╔══██╗██╔═══██╗╚══██╔══╝  ║
║     ███████╗███████╗███████║    ██████╔╝██║   ██║   ██║     ║
║     ╚════██║╚════██║██╔══██║    ██╔══██╗██║   ██║   ██║     ║
║     ███████║███████║██║  ██║    ██████╔╝╚██████╔╝   ██║     ║
║     ╚══════╝╚══════╝╚═╝  ╚═╝    ╚═════╝  ╚═════╝    ╚═╝     ║
║                                                              ║
║        🚀 SSH BOT ELNENE PRO – v8.8.27 (EMBED)              ║
║        🤖 Bot WhatsApp + panel admin PRO                     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}${BOLD}❌ Debes ejecutar como root${NC}"
  exit 1
fi

echo -e "${CYAN}${BOLD}🔍 Detectando IP pública...${NC}"
SERVER_IP="$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
if [[ -z "${SERVER_IP}" ]]; then
  read -rp "📝 Ingresa IP del servidor: " SERVER_IP
fi
echo -e "${GREEN}✅ IP detectada: ${CYAN}${SERVER_IP}${NC}\n"

echo -e "${YELLOW}⚠️  ESTE INSTALADOR INSTALA:${NC}"
echo -e "   ✅ 🤖 Bot WhatsApp + panel admin PRO"
echo -e "   ✅ 💳 MercadoPago integrado (token editable desde panel)"
echo -e "      ↳ QR de pago + link + referencia (external_reference)"
echo -e "      ↳ Verificación automática cada 2 min + auto-entrega al aprobar"
echo -e "   ✅ 🏦 Transferencia bancaria: Alias/CBU/Titular editables desde panel"
echo -e "      ↳ El cliente envía comprobante + REF + link al WhatsApp del admin"
echo -e "      ↳ Pendientes en panel + confirmación manual + auto-entrega (15 min)"
echo -e "   ✅ 💲 Precios editables 7/15/30 desde panel"
echo -e "   ✅ 🧩 Selector de app en compra: APK / HC(HWID) / Token-Only"
echo -e "   ✅ 🆔 HWID: user+pass = HWID + envío de <HWID>.hc"
echo -e "   ✅ 🔑 Token-Only: genera y gestiona tokens (revocar/listar)"
echo -e "   ✅ 📲 Gestión APK (subir/borrar/listar)"
echo -e "   ✅ 👥 Gestión usuarios: eliminar / eliminar expirados / conectados"
echo -e "   ✅ 📊 Estadísticas: ventas + ganancias"
echo -e "   ✅ 🔄 Auto-refresh PM2 cada 2 horas + Update desde panel (anti-cuelgue)"
echo -e "   ✅ 🧠 IA Gemini (opcional): soporte automático + fallback al menú"
echo -e "   ✅ 🧾 Menú cliente restaurado: responde a \"menu\" (y detecta textos mal escritos)"
echo -e "   ✅ 📲 APK: importar desde /root + descargar por URL (ambas opciones)"
echo -e "   ✅ 🌐 Custom/HTTP: mensaje + URL editables desde panel (para el cliente)"
echo -e "   ✅ 🆘 Soporte/Tutorial: WhatsApp + Telegram + links editables desde panel"
echo -e "   ✅ 📱 QR FIX: Vincular WhatsApp desde panel (TXT/PNG)"
echo
read -rp "$(echo -e "${YELLOW}¿Continuar? (s/N): ${NC}")" -n 1 -r
echo
[[ ! $REPLY =~ ^[Ss]$ ]] && { echo "Cancelado."; exit 0; }

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

apt-get install -y -qq \
  curl wget git unzip \
  sqlite3 jq nano htop \
  cron build-essential \
  ca-certificates gnupg \
  software-properties-common \
  libgbm-dev libxshmfence-dev \
  sshpass at >/dev/null 2>&1 || true

# Extras (no romper si no existen en el repo)
apt-get install -y -qq qrencode chafa >/dev/null 2>&1 || true

systemctl enable atd >/dev/null 2>&1 || true
systemctl start atd >/dev/null 2>&1 || true
systemctl enable cron >/dev/null 2>&1 || true
systemctl restart cron >/dev/null 2>&1 || true

if ! command -v google-chrome >/dev/null 2>&1; then
  echo -e "${CYAN}${BOLD}🌐 Instalando Google Chrome...${NC}"
  wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
  apt-get install -y /tmp/chrome.deb >/dev/null 2>&1 || true
  rm -f /tmp/chrome.deb
fi

if ! command -v node >/dev/null 2>&1; then
  echo -e "${CYAN}${BOLD}🟢 Instalando NodeJS 20...${NC}"
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >/dev/null 2>&1 || true
  apt-get install -y nodejs >/dev/null 2>&1 || true
fi

npm install -g pm2 --silent >/dev/null 2>&1 || true

# Asegurar pm2 en PATH (algunas distros no lo ven en /usr/local/bin)
if ! command -v pm2 >/dev/null 2>&1; then
  npm install -g pm2 --silent >/dev/null 2>&1 || true
fi
PM2_BIN=$(command -v pm2 2>/dev/null || true)
if [[ -n "$PM2_BIN" && ! -x /usr/bin/pm2 ]]; then
  ln -sf "$PM2_BIN" /usr/bin/pm2 2>/dev/null || true
fi


mkdir -p "$INSTALL_DIR"/{data,config,qr_codes,logs,backups}
mkdir -p "$BOT_HOME"/{config,data,apks,hc,logs}
chmod -R 755 "$INSTALL_DIR" >/dev/null 2>&1 || true
chmod -R 700 "$INSTALL_DIR/config" >/dev/null 2>&1 || true

if [[ ! -s "$CONFIG_FILE" ]]; then
  cat > "$CONFIG_FILE" <<EOF
{
  "bot": { "name": "SSH BOT ELNENE PRO", "version": "8.8.27", "server_ip": "${SERVER_IP}" },
  "admins": [],
  "prices": { "test_hours": 2, "plan_7": 500, "plan_15": 800, "plan_30": 1200, "currency": "ARS" },
  "mercadopago": { "access_token": "", "enabled": false },
"transfer": {
  "enabled": true,
  "alias": "",
  "cbu": "",
  "titular": "",
  "admin_whatsapp": ""
},

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
  }
}
EOF
  chmod 600 "$CONFIG_FILE" >/dev/null 2>&1 || true
fi
cp -f "$CONFIG_FILE" "$BOT_HOME/config/config.json" >/dev/null 2>&1 || true

# DB
sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS users (
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
);
CREATE TABLE IF NOT EXISTS tokens (
 id INTEGER PRIMARY KEY AUTOINCREMENT,
 phone TEXT,
 token TEXT UNIQUE,
 plan TEXT,
 expires_at TEXT,
 status TEXT DEFAULT 'active',
 created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS payments (
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
);
SQL

echo -e "${CYAN}${BOLD}🤖 Instalando bot.js (embebido)...${NC}"
cat > "$BOT_HOME/bot.js" <<'BOTJS'
/**
 * SSH BOT ELNENE PRO – bot.js (embedded)
 * Version: 8.8.27
 * Features:
 *  - WhatsApp connection via whatsapp-web.js (LocalAuth)
 *  - Saves QR to /root/qr-whatsapp.txt and /root/qr-whatsapp.png
 *  - MercadoPago preference creation (optional)
 *  - Minimal purchase flow + user/token generation persisted in SQLite
 *
 * NOTE: This is a self-contained bot implementation meant to be installed by the unified installer.
 */

"use strict";

const fs = require("fs");
const path = require("path");
const os = require("os");
const { execSync } = require("child_process");

const sqlite3 = require("sqlite3").verbose();
const axios = require("axios").default;

const qrcode = require("qrcode");
const qrcodeTerminal = require("qrcode-terminal");

const { Client, LocalAuth, MessageMedia } = require("whatsapp-web.js");

const ROOT = "/root";
const INSTALL_DIR = "/opt/ssh-bot";
const BOT_HOME = "/root/ssh-bot";
const DB_FILE = path.join(INSTALL_DIR, "data", "users.db");

const QR_TXT = path.join(ROOT, "qr-whatsapp.txt");
const QR_PNG = path.join(ROOT, "qr-whatsapp.png");

const CONFIG_CANDIDATES = [
  path.join(BOT_HOME, "config", "config.json"),
  path.join(INSTALL_DIR, "config", "config.json"),
  path.join(BOT_HOME, "config.json"),
];

function readJsonSafe(p) {
  try { return JSON.parse(fs.readFileSync(p, "utf8")); } catch { return null; }
}

function loadConfig() {
  for (const p of CONFIG_CANDIDATES) {
    const j = readJsonSafe(p);
    if (j) return { config: j, path: p };
  }
  return { config: {}, path: "" };
}

let { config, path: configPath } = loadConfig();

function reloadConfig() {
  const r = loadConfig();
  config = r.config || {};
  configPath = r.path || configPath;
}

function cfg(pathExpr, fallback) {
  try {
    // simple dot-notation getter
    const parts = pathExpr.split(".");
    let cur = config;
    for (const k of parts) {
      if (cur && Object.prototype.hasOwnProperty.call(cur, k)) cur = cur[k];
      else return fallback;
    }
    return (cur === undefined || cur === null) ? fallback : cur;
  } catch {
    return fallback;
  }
}

const BOT_NAME = cfg("bot.name", "SSH BOT ELNENE PRO");
const BOT_VERSION = cfg("bot.version", "8.8.27");

const MP_TOKEN = cfg("mercadopago.access_token", "");
const MP_ENABLED = !!MP_TOKEN && cfg("mercadopago.enabled", false) !== false;

const TEST_HOURS = Number(cfg("prices.test_hours", 2));
const PRICE_7 = Number(cfg("prices.plan_7", 0));
const PRICE_15 = Number(cfg("prices.plan_15", 0));
const PRICE_30 = Number(cfg("prices.plan_30", 0));
const CURRENCY = cfg("prices.currency", "ARS");

function linksCfg() {
  return {
    support: cfg("links.support", "https://t.me/soporte"),
    support_whatsapp: cfg("links.support_whatsapp", ""),
    telegram: cfg("links.telegram", ""),
    tutorial: cfg("links.tutorial", "https://youtube.com"),
  };
}

function downloadsCfg() {
  return {
    apk_url: cfg("downloads.apk_url", ""),
    custom_url: cfg("downloads.custom_url", ""),
    custom_message: cfg("downloads.custom_message", "📲 *HTTP Custom*\n\n⬇️ Descargá desde:\n{URL}\n\nLuego importá tu archivo .hc (HWID) y conectá."),
  };
}


function transferCfg() {
  return {
    enabled: !!cfg("transfer.enabled", true),
    alias: cfg("transfer.alias", ""),
    cbu: cfg("transfer.cbu", ""),
    titular: cfg("transfer.titular", ""),
    admin_whatsapp: String(cfg("transfer.admin_whatsapp", "") || cfg("links.support_whatsapp", "") || "").replace(/\D/g, ""),
  };
}

function paymentMethodMenuText() {
  return `💳 *Método de pago*\n\n1) MercadoPago (tarjeta / saldo)\n2) Transferencia\n\n(Respondé: 1/2)`;
}

function transferInstructionsText(ref) {
  const t = transferCfg();
  const lines = [];
  lines.push("🏦 *Transferencia bancaria*");
  if (t.titular) lines.push(`👤 Titular: *${t.titular}*`);
  if (t.alias) lines.push(`🔤 Alias: *${t.alias}*`);
  if (t.cbu) lines.push(`🏛️ CBU: *${t.cbu}*`);
  lines.push("");
  lines.push("📎 *Luego enviá el comprobante acá mismo* (foto o PDF).");
  lines.push("⏳ Se procesa en menos de *15 minutos* (a confirmar por el admin).");
  lines.push("");
  const admin = t.admin_whatsapp;
  if (admin) {
    const msg = encodeURIComponent(`CONFIRMAR PAGO ${ref}`);
    lines.push("⚡ Para avisar al admin rápidamente:");
    lines.push(`👉 https://wa.me/${admin}?text=${msg}`);
    lines.push(`(o copiá y pegá: CONFIRMAR PAGO ${ref})`);
  }
  return lines.join("\n");
}
function geminiCfg() {
  return {
    enabled: !!cfg("gemini.enabled", false),
    api_key: cfg("gemini.api_key", ""),
  };
}

async function geminiSupportReply(userText) {
  try {
    const g = geminiCfg();
    if (!g.enabled || !g.api_key) return null;
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${g.api_key}`;
    const payload = {
      contents: [{
        parts: [{
          text:
`Eres soporte técnico de un servicio SSH/VPN.
Responde claro, profesional y breve.
Ayuda a diagnosticar errores comunes de conexión.
Usa emojis moderados.
Si el usuario pide el menú, decile que escriba "menu".

Consulta del usuario:
"${userText}"`
        }]
      }]
    };
    const resp = await axios.post(url, payload, { timeout: 15000 });
    const out = resp?.data?.candidates?.[0]?.content?.parts?.[0]?.text;
    return out ? String(out).trim() : null;
  } catch (e) {
    log(`Gemini error: ${e.message}`);
    return null;
  }
}

function menuText() {
  return `🤖 *${BOT_NAME}* (${BOT_VERSION})\n\n` +
    `1️⃣ 🆓 Prueba GRATIS (${TEST_HOURS}h)\n` +
    `2️⃣ 💳 Planes Premium (7/15/30)\n` +
    `3️⃣ 👤 Mis cuentas\n` +
    `4️⃣ 💳 Estado de pago\n` +
    `5️⃣ 📲 Descargar app / Custom\n` +
    `6️⃣ 🆘 Soporte\n\n` +
    `💬 Responde con el número o escribí *comprar* para comprar.`;
}

function premiumMenuText() {
  return `💎 *PLANES PREMIUM*\n\n` +
    `1️⃣ 7 días  - $${PRICE_7} ${CURRENCY}\n` +
    `2️⃣ 15 días - $${PRICE_15} ${CURRENCY}\n` +
    `3️⃣ 30 días - $${PRICE_30} ${CURRENCY}\n\n` +
    `💬 Responde 1/2/3`;
}

function supportText() {
  const l = linksCfg();
  const parts = [];
  if (l.support_whatsapp) parts.push(`📱 WhatsApp: ${l.support_whatsapp}`);
  if (l.telegram) parts.push(`✈️ Telegram: ${l.telegram}`);
  if (l.support) parts.push(`🔗 Soporte: ${l.support}`);
  if (l.tutorial) parts.push(`📺 Tutorial: ${l.tutorial}`);
  return `🆘 *SOPORTE*\n\n${parts.join("\n")}\n\n💬 Si querés, escribí tu problema y te responde la IA (si está activada).`;
}

function customDownloadText() {
  const d = downloadsCfg();
  const url = d.custom_url || "(sin URL configurada)";
  const msg = (d.custom_message || "").replace(/\{URL\}/g, url);
  return msg;
}

const ADMIN_NUMBERS = (cfg("admins", []) || [])
  .map(s => String(s).replace(/\D/g, ""))
  .filter(Boolean);

function nowIso() {
  return new Date().toISOString().replace("T", " ").replace("Z", "");
}

function addHours(date, h) {
  return new Date(date.getTime() + h * 3600 * 1000);
}
function addDays(date, d) {
  return new Date(date.getTime() + d * 24 * 3600 * 1000);
}

function randStr(n) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
  let s = "";
  for (let i = 0; i < n; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

function normalizeNumber(from) {
  // from: "54911....@c.us"
  const num = String(from).split("@")[0].replace(/\D/g, "");
  return num;
}

function isAdminNumber(num) {
  if (!ADMIN_NUMBERS.length) return true; // if not configured, allow
  return ADMIN_NUMBERS.includes(num);
}

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  try { fs.appendFileSync(path.join(INSTALL_DIR, "logs", "bot.log"), line + "\n"); } catch {}
}

function chatIdFromPhone(phone) {
  const p = String(phone || "").trim();
  if (!p) return "";
  return p.includes("@") ? p : `${p}@c.us`;
}

async function safeSend(client, phone, text, opts = {}) {
  try {
    const to = chatIdFromPhone(phone);
    if (!to) return;
    await client.sendMessage(to, text, Object.assign({ sendSeen: false }, opts));
  } catch (e) {
    log(`sendMessage error: ${e && e.message ? e.message : e}`);
  }
}


function ensureDb() {
  fs.mkdirSync(path.dirname(DB_FILE), { recursive: true });
  const db = new sqlite3.Database(DB_FILE);
  db.serialize(() => {
    db.run(`CREATE TABLE IF NOT EXISTS users (
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
    );`);
    db.run(`CREATE TABLE IF NOT EXISTS tokens (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT,
      token TEXT UNIQUE,
      plan TEXT,
      expires_at TEXT,
      status TEXT DEFAULT 'active',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );`);
    db.run(`CREATE TABLE IF NOT EXISTS payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT,
      external_reference TEXT UNIQUE,
      preference_id TEXT,
      amount REAL,
      currency TEXT,
      status TEXT DEFAULT 'pending',
      plan TEXT,
      app_type TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP,
      approved_at TEXT
    );`);
  });
  return db;
}

const db = ensureDb();

function dbGet(sql, params=[]) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (err, row) => err ? reject(err) : resolve(row));
  });
}
function dbAll(sql, params=[]) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (err, rows) => err ? reject(err) : resolve(rows));
  });
}
function dbRun(sql, params=[]) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function(err) {
      if (err) reject(err);
      else resolve({ lastID: this.lastID, changes: this.changes });
    });
  });
}

/**
 * Create a Linux system user for SSH
 */
function createLinuxUser(username, password) {
  // Best-effort, assumes running as root
  execSync(`id -u ${username} >/dev/null 2>&1 || useradd -m -s /bin/bash ${username}`, { stdio: "ignore" });
  execSync(`echo "${username}:${password}" | chpasswd`, { stdio: "ignore" });
}

function setLinuxExpire(username, expiresAt) {
  if (!expiresAt) return;
  // expiresAt format "YYYY-MM-DD HH:MM:SS" (UTC-ish). We'll convert to YYYY-MM-DD.
  const date = String(expiresAt).split(" ")[0];
  execSync(`chage -E "${date}" "${username}" >/dev/null 2>&1 || true`, { stdio: "ignore" });
}

function deleteLinuxUser(username) {
  execSync(`id -u ${username} >/dev/null 2>&1 && userdel -r ${username} >/dev/null 2>&1 || true`, { stdio: "ignore" });
}

function makeCredentials() {
  const username = ("u" + randStr(7)).toLowerCase();
  const password = randStr(10);
  return { username, password };
}

function computeExpiry(plan) {
  const base = new Date();
  if (plan === "test") return addHours(base, TEST_HOURS);
  if (plan === "7") return addDays(base, 7);
  if (plan === "15") return addDays(base, 15);
  if (plan === "30") return addDays(base, 30);
  return null;
}

function fmtDate(d) {
  if (!d) return "";
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth()+1).padStart(2,"0");
  const dd = String(d.getUTCDate()).padStart(2,"0");
  const hh = String(d.getUTCHours()).padStart(2,"0");
  const mi = String(d.getUTCMinutes()).padStart(2,"0");
  const ss = String(d.getUTCSeconds()).padStart(2,"0");
  return `${yyyy}-${mm}-${dd} ${hh}:${mi}:${ss}`;
}

function planPrice(plan) {
  if (plan === "test") return 0;
  if (plan === "7") return PRICE_7;
  if (plan === "15") return PRICE_15;
  if (plan === "30") return PRICE_30;
  return 0;
}

function planLabel(plan) {
  if (plan === "test") return `Test ${TEST_HOURS}h`;
  if (plan === "7") return "7 días";
  if (plan === "15") return "15 días";
  if (plan === "30") return "30 días";
  return plan;
}

function appLabel(app) {
  if (app === "apk") return "APK";
  if (app === "hc") return "HC(HWID)";
  if (app === "token") return "Token-Only";
  return app || "";
}

// ---------------- HWID helpers (HC/Custom) ----------------
function sanitizeHwid(raw) {
  const s = String(raw || "").trim();
  // Allow only safe chars for linux username and filename
  const cleaned = s.replace(/[^a-zA-Z0-9_-]/g, "");
  if (!cleaned || cleaned.length < 4 || cleaned.length > 32) return null;
  return cleaned;
}

async function createDbUserFromHwid(phone, plan, hwidRaw) {
  const hwid = sanitizeHwid(hwidRaw);
  if (!hwid) throw new Error("HWID inválido. Usá solo letras/números y sin espacios.");
  // Username/password = HWID (requested)
  const username = hwid.toLowerCase();
  const password = hwid;

  const days = planDays(plan);
  const appType = "hc";
  const expiresAt = days === 0
    ? moment().add(TEST_HOURS, "hours").format("YYYY-MM-DD HH:mm:ss")
    : moment().add(days, "days").endOf("day").format("YYYY-MM-DD HH:mm:ss");

  await ensureSystemUser(username, password, expiresAt);

  await dbRun(
    `INSERT OR REPLACE INTO users (phone, username, password, tipo, expires_at, max_connections, status, hwid, app_type)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)`,
    [phone, username, password, plan === "test" ? "test" : "premium", expiresAt, 1, hwid, appType]
  );

  return { username, password, expires_at: expiresAt, hwid };
}

async function getHcFilePath(hwidRaw) {
  const hwid = sanitizeHwid(hwidRaw);
  if (!hwid) return null;
  const candidates = [
    path.join(HC_DIR, `${hwid}.hc`),
    path.join(HC_DIR, `${hwid.toLowerCase()}.hc`),
    path.join(HC_DIR, `${hwid.toUpperCase()}.hc`),
  ];
  for (const p of candidates) {
    try { if (fs.existsSync(p)) return p; } catch {}
  }
  return null;
}

async function markPaymentAwaitHwid(paymentId) {
  await dbRun(`UPDATE payments SET status='await_hwid', delivered=0 WHERE payment_id=?`, [paymentId]);
}

async function markPaymentCompleted(paymentId, hwidRaw) {
  const hwid = sanitizeHwid(hwidRaw) || "";
  await dbRun(`UPDATE payments SET status='completed', delivered=1, approved_at=CURRENT_TIMESTAMP, hwid=? WHERE payment_id=?`, [hwid, paymentId]);
}

async function getAwaitHwidPaymentForPhone(phone) {
  return await dbGet(`SELECT * FROM payments WHERE phone=? AND status='await_hwid' AND delivered=0 ORDER BY id DESC LIMIT 1`, [phone]);
}

// Try finalize a pending HC payment by sending HWID
async function tryFinalizeHwidFlow(phone, msg, text) {
  const lower = String(text || "").trim().toLowerCase();
  // ignore commands
  const known = ["menu","hola","start","hi","1","2","3","4","5","6","7","8","9","0","mp","mercadopago","transferencia"];
  if (known.includes(lower) || lower.startsWith("verificar ") || lower.startsWith("confirmar pago")) return false;

  const pay = await getAwaitHwidPaymentForPhone(phone);
  if (!pay) return false;

  const hwid = sanitizeHwid(text);
  if (!hwid) {
    await client.sendMessage(msg.from, "⚠️ Ese HWID no es válido. Enviá solo el código (sin espacios).", { sendSeen: false });
    return true;
  }

  const plan = pay.plan || "30d";
  const u = await createDbUserFromHwid(phone, plan, hwid);

  // Send HC file if exists
  const hcPath = await getHcFilePath(hwid);
  if (hcPath) {
    try {
      const media = MessageMedia.fromFilePath(hcPath);
      await client.sendMessage(msg.from, media, { caption: `🧩 Archivo HC: ${path.basename(hcPath)}`, sendSeen: false });
    } catch {}
  }

  await markPaymentCompleted(pay.payment_id, hwid);

  const msgTxt =
`✅ *Pago aprobado* y *Custom activado*.

👤 Usuario: *${u.username}*
🔐 Clave: *${u.password}*
🆔 HWID: *${hwid}*
⏳ Vence: *${moment(u.expires_at).format("DD/MM/YYYY HH:mm")}*

${customDownloadText()}

📌 Escribí *menu* para ver opciones.`;

  await client.sendMessage(msg.from, msgTxt, { sendSeen: false });
  return true;
}


async function createDbUser(phone, plan, appType, hwid="", maxConn=1) {
  const { username, password } = makeCredentials();
  const exp = computeExpiry(plan);
  const expires_at = exp ? fmtDate(exp) : null;

  // db first to ensure uniqueness; if collision, retry
  for (let i=0; i<5; i++) {
    try {
      await dbRun(
        "INSERT INTO users(phone, username, password, tipo, expires_at, max_connections, status, app_type, hwid) VALUES(?,?,?,?,?,?,1,?,?)",
        [phone, username, password, plan === "test" ? "test" : "premium", expires_at, (maxConn||1), appType || "", hwid || ""]
      );
      // system user
      createLinuxUser(username, password);
      if (expires_at) setLinuxExpire(username, expires_at);
      return { username, password, expires_at };
    } catch (e) {
      if (String(e).includes("UNIQUE")) continue;
      throw e;
    }
  }
  throw new Error("No pude generar username único.");
}

async function createToken(phone, plan, daysOrNull) {
  const token = "TKN_" + randStr(20);
  const exp = daysOrNull ? fmtDate(addDays(new Date(), daysOrNull)) : null;
  await dbRun(
    "INSERT INTO tokens(phone, token, plan, expires_at, status) VALUES(?,?,?,?, 'active')",
    [phone, token, plan, exp]
  );
  return { token, expires_at: exp };
}

async function ensurePaymentsColumns() {
  try {
    const cols = await dbAll("PRAGMA table_info(payments)");
    const names = new Set((cols || []).map(c => c.name));
    const alters = [];
    if (!names.has("payment_url")) alters.push("ALTER TABLE payments ADD COLUMN payment_url TEXT");
    if (!names.has("qr_path")) alters.push("ALTER TABLE payments ADD COLUMN qr_path TEXT");
    if (!names.has("mp_payment_id")) alters.push("ALTER TABLE payments ADD COLUMN mp_payment_id TEXT");
    if (!names.has("mp_status_detail")) alters.push("ALTER TABLE payments ADD COLUMN mp_status_detail TEXT");
    if (!names.has("delivered")) alters.push("ALTER TABLE payments ADD COLUMN delivered INTEGER DEFAULT 0");
    if (!names.has("method")) alters.push("ALTER TABLE payments ADD COLUMN method TEXT DEFAULT 'mp'");
    if (!names.has("receipt_path")) alters.push("ALTER TABLE payments ADD COLUMN receipt_path TEXT");
    if (!names.has("receipt_mime")) alters.push("ALTER TABLE payments ADD COLUMN receipt_mime TEXT");
    if (!names.has("reminded")) alters.push("ALTER TABLE payments ADD COLUMN reminded INTEGER DEFAULT 0");
    for (const sql of alters) {
      try { await dbRun(sql, []); } catch {}
    }
  } catch {}
}

function mpHeaders() {
  return { Authorization: `Bearer ${MP_TOKEN}`, "Content-Type": "application/json" };
}

function mpPrefBody({ external_reference, plan, appType }) {
  // ISO-8601 expirations (24h window)
  const from = new Date();
  const to = new Date(from.getTime() + 24 * 60 * 60 * 1000);

  const body = {
    items: [
      {
        title: `${BOT_NAME} – ${planLabel(plan)} – ${appLabel(appType)}`,
        quantity: 1,
        currency_id: CURRENCY,
        unit_price: Number(planPrice(plan) || 0)
      }
    ],
    external_reference,
    expires: true,
    expiration_date_from: from.toISOString(),
    expiration_date_to: to.toISOString(),
  };

  // Optional: notification_url (webhook) if admin set it in config
  const notif = cfg("mercadopago.notification_url", "");
  if (notif) body.notification_url = String(notif);

  // Optional: back_urls for better UX in MP app
  const wa = phoneToWa(cfg("links.support_whatsapp", "")) || "";
  const backBase = cfg("mercadopago.back_urls_base", "");
  if (backBase) {
    body.back_urls = {
      success: `${backBase}?status=success&ref=${encodeURIComponent(external_reference)}`,
      failure: `${backBase}?status=failure&ref=${encodeURIComponent(external_reference)}`,
      pending: `${backBase}?status=pending&ref=${encodeURIComponent(external_reference)}`
    };
    body.auto_return = "approved";
  } else if (wa) {
    // fallback to wa.me if admin configured WhatsApp
    body.back_urls = {
      success: `https://wa.me/${wa}?text=Pago%20exitoso%20(ref%20${encodeURIComponent(external_reference)})`,
      failure: `https://wa.me/${wa}?text=Pago%20fallido%20(ref%20${encodeURIComponent(external_reference)})`,
      pending: `https://wa.me/${wa}?text=Pago%20pendiente%20(ref%20${encodeURIComponent(external_reference)})`
    };
    body.auto_return = "approved";
  }

  return body;
}

async function mpCreatePreference({ phone, plan, appType }) {
  const amount = planPrice(plan);
  if (!MP_ENABLED) throw new Error("MercadoPago no está configurado.");
  if (!amount || Number(amount) <= 0) throw new Error("No hay precio configurado para ese plan.");

  await ensurePaymentsColumns();

  const external_reference = `SSH-${phone}-${Date.now()}-${randStr(4)}`;

  // Create preference via API (stable & simple)
  const body = mpPrefBody({ external_reference, plan, appType });

  const resp = await axios.post(
    "https://api.mercadopago.com/checkout/preferences",
    body,
    { headers: mpHeaders(), timeout: 20000 }
  );

  const pref = resp.data || {};
  const init_point = pref.init_point || pref.sandbox_init_point || "";
  const prefId = pref.id || "";

  // QR file (payment QR)
  let qrPath = "";
  try {
    const qrDir = path.join(INSTALL_DIR, "qr_codes");
    fs.mkdirSync(qrDir, { recursive: true });
    qrPath = path.join(qrDir, `${external_reference}.png`);
    if (init_point) {
      await qrcode.toFile(qrPath, init_point, { width: 500, margin: 1, errorCorrectionLevel: "M" });
    }
  } catch { qrPath = ""; }

  // Persist
  await dbRun(
    "INSERT OR IGNORE INTO payments(phone, external_reference, preference_id, amount, currency, status, plan, app_type, payment_url, qr_path, delivered) VALUES(?,?,?,?,?, 'pending', ?, ?, ?, ?, 0)",
    [phone, external_reference, prefId, amount, CURRENCY, String(plan), String(appType), init_point, qrPath]
  );

  return { init_point, preference_id: prefId, external_reference, qr_path: qrPath };
}

async function mpCheckApproved(external_reference) {
  if (!MP_ENABLED) return { approved: false, reason: "MP no configurado" };

  try {
    // Search payments by external_reference
    const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${encodeURIComponent(external_reference)}`;
    const resp = await axios.get(url, { headers: mpHeaders(), timeout: 20000 });
    const results = (resp.data && resp.data.results) ? resp.data.results : [];

    // Pick latest
    results.sort((a, b) => (b.date_created || "").localeCompare(a.date_created || ""));
    const pay = results[0];
    if (!pay) return { approved: false, reason: "Sin pagos encontrados aún" };

    if (pay.status === "approved") return { approved: true, payment: pay };
    if (pay.status === "rejected") return { approved: false, reason: `Rechazado (${pay.status_detail || "sin detalle"})`, payment: pay };
    if (pay.status === "cancelled") return { approved: false, reason: "Cancelado", payment: pay };
    return { approved: false, reason: `Estado: ${pay.status}${pay.status_detail ? " (" + pay.status_detail + ")" : ""}`, payment: pay };
  } catch (e) {
    return { approved: false, reason: `Error consultando MP: ${e && e.message ? e.message : "desconocido"}` };
  }
}

async function mpProcessPendingPayments(client) {
  if (!MP_ENABLED) return;
  await ensurePaymentsColumns();

  const rows = await dbAll(
    "SELECT phone, external_reference, plan, app_type, amount, currency, payment_url, qr_path FROM payments WHERE status='pending' AND (method IS NULL OR method='mp') AND (delivered IS NULL OR delivered=0) AND created_at >= datetime('now','-48 hours') ORDER BY id ASC",
    []
  );

  if (!rows || !rows.length) return;

  for (const p of rows) {
    try {
      const chk = await mpCheckApproved(p.external_reference);
      if (!chk.approved) continue;

      const pay = chk.payment || {};
      await dbRun(
        "UPDATE payments SET status='approved', approved_at=?, mp_payment_id=?, mp_status_detail=? WHERE external_reference=?",
        [nowIso(), String(pay.id || ""), String(pay.status_detail || ""), p.external_reference]
      );

      const appType = p.app_type || "apk";
      const plan = p.plan || "7";

      if (appType === "token") {
        const days = plan === "7" ? 7 : plan === "15" ? 15 : plan === "30" ? 30 : 1;
        const t = await createToken(p.phone, plan, days);
        await safeSend(client, p.phone,
          `🎉 *PAGO CONFIRMADO*\n\n🔑 *Token*: ${t.token}\n📅 Expira: ${t.expires_at || "∞"}\n\n📌 Escribí *menu* para ver opciones.`
        );
} else {
  // Plan paid: deliver depending on app type
  if (appType === "hc") {
    await safeSend(client, p.phone,
      `✅ *Pago aprobado*.

🧩 Elegiste *Custom / HC (HWID)*.

🆔 Enviá tu *HWID* ahora para activar.

${customDownloadText()}

📌 (Enviá solo el código, sin espacios).`
    );
    await markPaymentAwaitHwid(p.external_reference);
    continue;
  }

  const u = await createDbUser(p.phone, plan, appType);

  let extra = "";
  if (appType === "apk") {
    const d = downloadsCfg();
    if (d.apk_url) extra = `

📲 Descarga APK:
${d.apk_url}`;
    else extra = `

📲 Escribí *5* para descargar la app.`;
  } else if (appType === "token") {
    // token delivery handled by createDbUser
  }

  await safeSend(client, p.phone,
    `🎉 *PAGO CONFIRMADO*

👤 Usuario: *${u.username}*
🔐 Pass: *${u.password}*
📅 Expira: *${u.expires_at || "∞"}*${extra}`
  );

  await dbRun("UPDATE payments SET delivered=1 WHERE external_reference=?", [p.external_reference]);
}
} catch (e) {
      log(`MP process error: ${e && e.message ? e.message : e}`);
    }
  }
}

async function transferProcessApprovedPayments(client) {
  await ensurePaymentsColumns();
  const rows = await dbAll(
    "SELECT phone, external_reference, plan, app_type, amount, currency, receipt_path, receipt_mime FROM payments WHERE method='transfer' AND status='approved' AND (delivered IS NULL OR delivered=0) AND created_at >= datetime('now','-14 days') ORDER BY id ASC",
    []
  );
  if (!rows || !rows.length) return;

  for (const p of rows) {
    try {
      const appType = p.app_type || "apk";
      const plan = p.plan || "7";
      if (appType === "token") {
        const days = plan === "7" ? 7 : plan === "15" ? 15 : plan === "30" ? 30 : 1;
        const t = await createToken(p.phone, plan, days);
        await safeSend(client, p.phone,
          `🎉 *PAGO CONFIRMADO (Transferencia)*\n\n🔑 *Token*: ${t.token}\n📅 Expira: ${t.expires_at || "∞"}\n\n📌 Escribí *menu* para ver opciones.`
        );
      
} else {
  if (appType === "hc") {
    await safeSend(client, p.phone,
      `✅ *Pago por transferencia aprobado*.

🧩 Elegiste *Custom / HC (HWID)*.

🆔 Enviá tu *HWID* ahora para activar.

${customDownloadText()}

📌 (Enviá solo el código, sin espacios).`
    );
    await markPaymentAwaitHwid(p.external_reference);
    continue;
  }

  const u = await createDbUser(p.phone, plan, appType);

  let extra = "";
  if (appType === "apk") {
    const d = downloadsCfg();
    if (d.apk_url) extra = `

📲 Descarga APK:
${d.apk_url}`;
    else extra = `

📲 Escribí *5* para descargar la app.`;
  }

  await safeSend(client, p.phone,
    `✅ *TRANSFERENCIA APROBADA*

👤 Usuario: *${u.username}*
🔐 Pass: *${u.password}*
📅 Expira: *${u.expires_at || "∞"}*${extra}`
  );

  await dbRun("UPDATE payments SET delivered=1 WHERE external_reference=?", [p.external_reference]);
}
} catch (e) {
      log(`Transfer deliver error: ${e && e.message ? e.message : e}`);
    }
  }
}

async function transferSendReminders(client) {
  await ensurePaymentsColumns();
  const rows = await dbAll(
    "SELECT phone, external_reference, plan, app_type, amount, currency, created_at FROM payments WHERE method='transfer' AND status='pending_admin' AND (reminded IS NULL OR reminded=0) AND created_at <= datetime('now','-15 minutes') ORDER BY id ASC",
    []
  );
  if (!rows || !rows.length) return;

  for (const p of rows) {
    try {
      await safeSend(client, p.phone,
        `⏳ *Pago en revisión*\n\nRef: *${p.external_reference}*\nEstamos esperando la confirmación del admin.\nSi ya enviaste el comprobante, por favor aguardá unos minutos más.`
      );
      // ping admin(s)
      const admin = transferCfg().admin_whatsapp;
      if (admin) {
        await safeSend(client, `${admin}@c.us`,
          `🏦 Pago por transferencia pendiente >15min\nRef: ${p.external_reference}\nTel: ${String(p.phone).split("@")[0]}\nPlan: ${planLabel(p.plan)} | App: ${appLabel(p.app_type)} | $${p.amount} ${p.currency}`
        );
      } else if (ADMIN_NUMBERS.length) {
        await safeSend(client, `${ADMIN_NUMBERS[0]}@c.us`,
          `🏦 Pago por transferencia pendiente >15min\nRef: ${p.external_reference}\nTel: ${String(p.phone).split("@")[0]}\nPlan: ${planLabel(p.plan)} | App: ${appLabel(p.app_type)} | $${p.amount} ${p.currency}`
        );
      }
      await dbRun("UPDATE payments SET reminded=1 WHERE external_reference=?", [p.external_reference]);
    } catch {}
  }
}

function makeTransferRef(phone) {
  const p = String(phone || "").replace(/\D/g, "");
  const last = p.slice(-4) || "0000";
  return `TR-${Date.now()}-${last}`;
}

async function saveReceiptFromMsg(msg, ref) {
  try {
    if (!msg.hasMedia) return { path: "", mime: "" };
    const media = await msg.downloadMedia();
    if (!media || !media.data) return { path: "", mime: media ? (media.mimetype || "") : "" };

    const dir = path.join(INSTALL_DIR, "receipts");
    try { fs.mkdirSync(dir, { recursive: true }); } catch {}
    const mime = media.mimetype || "";
    const ext =
      mime.includes("png") ? "png" :
      mime.includes("pdf") ? "pdf" :
      mime.includes("jpeg") || mime.includes("jpg") ? "jpg" :
      "bin";
    const outPath = path.join(dir, `${ref}.${ext}`);
    fs.writeFileSync(outPath, Buffer.from(media.data, "base64"));
    return { path: outPath, mime };
  } catch (e) {
    return { path: "", mime: "" };
  }
}

async function createTransferPayment({ phone, plan, appType, receiptPath, receiptMime, amount }) {
  await ensurePaymentsColumns();
  const ref = makeTransferRef(phone);
  const cur = CURRENCY;
  await dbRun(
    "INSERT INTO payments (phone, external_reference, amount, currency, status, plan, app_type, method, receipt_path, receipt_mime, created_at, delivered, reminded) VALUES (?,?,?,?,?,?,?,?,?,?,datetime('now'),0,0)",
    [phone, ref, amount, cur, "pending_admin", plan, appType, "transfer", receiptPath || "", receiptMime || ""]
  );
  return ref;
}



const sessions = new Map(); // phone -> session state

function sessionGet(phone) {
  if (!sessions.has(phone)) sessions.set(phone, { step: "idle" });
  return sessions.get(phone);
}

function resetSession(phone) {
  sessions.set(phone, { step: "idle" });
}

function helpText(isAdmin) {
  const base =
`🤖 *${BOT_NAME}* (v${BOT_VERSION})

🛒 Para comprar:
1) Escribí: *comprar*
2) Elegí plan y tipo de app
3) Pagás y luego enviás: *verificar <REF>* (te la da el bot)

📌 Comandos:
• *comprar* – iniciar compra
• *precios* – ver precios
• *ayuda* – ver ayuda
`;

  const admin =
`
👑 Admin:
• *admin usuarios* – listar usuarios
• *admin borrar <user>* – borrar usuario
• *admin tokens* – listar tokens
• *admin revocar <token>* – revocar token
`;

  return base + (isAdmin ? admin : "");
}

function pricesText() {
  return `💲 *Precios* (${CURRENCY})
• Test ${TEST_HOURS}h: $0
• 7 días: $${PRICE_7}
• 15 días: $${PRICE_15}
• 30 días: $${PRICE_30}`;
}

function buyMenuText() {
  return `🧩 *Elegí un PLAN* respondiendo con el número:

1) Test ${TEST_HOURS}h
2) 7 días
3) 15 días
4) 30 días

(Respondé: 1/2/3/4)`;
}

function appMenuText() {
  return `📱 *Elegí tipo de app*:

1) APK
2) HC (HWID)
3) Token-Only

(Respondé: 1/2/3)`;
}

function mapPlanChoice(c) {
  if (c === "1") return "test";
  if (c === "2") return "7";
  if (c === "3") return "15";
  if (c === "4") return "30";
  return null;
}
function mapAppChoice(c) {
  if (c === "1") return "apk";
  if (c === "2") return "hc";
  if (c === "3") return "token";
  return null;
}

async function handleAdminCommand(client, msg, phone, text) {
  const parts = text.trim().split(/\s+/);
  const sub = (parts[1] || "").toLowerCase();

  if (sub === "usuarios") {
    const rows = await dbAll("SELECT username,tipo,expires_at,app_type FROM users ORDER BY id DESC LIMIT 50");
    if (!rows.length) return client.sendMessage(msg.from, "No hay usuarios.");
    const lines = rows.map(r => `• ${r.username} | ${r.tipo} | exp: ${r.expires_at || "∞"} | ${r.app_type || "-"}`);
    return client.sendMessage(msg.from, "*Usuarios (últimos 50)*\n" + lines.join("\n"));
  }

  if (sub === "borrar" && parts[2]) {
    const u = parts[2];
    const row = await dbGet("SELECT username FROM users WHERE username=?", [u]);
    if (!row) return client.sendMessage(msg.from, "No existe ese usuario.");
    await dbRun("DELETE FROM users WHERE username=?", [u]);
    try { deleteLinuxUser(u); } catch {}
    return client.sendMessage(msg.from, `✅ Usuario borrado: ${u}`);
  }

  if (sub === "tokens") {
    const rows = await dbAll("SELECT token,plan,expires_at,status FROM tokens ORDER BY id DESC LIMIT 50");
    if (!rows.length) return client.sendMessage(msg.from, "No hay tokens.");
    const lines = rows.map(r => `• ${r.token} | ${r.plan} | exp: ${r.expires_at || "∞"} | ${r.status}`);
    return client.sendMessage(msg.from, "*Tokens (últimos 50)*\n" + lines.join("\n"));
  }

  if (sub === "revocar" && parts[2]) {
    const t = parts[2];
    await dbRun("UPDATE tokens SET status='revoked' WHERE token=?", [t]);
    return client.sendMessage(msg.from, `✅ Token revocado: ${t}`);
  }

  return client.sendMessage(msg.from, "Admin: comandos: admin usuarios | admin borrar <user> | admin tokens | admin revocar <token>");
}

async function handleMessage(client, msg) {
  const phone = normalizeNumber(msg.from);
  const text = (msg.body || "").trim();
  const lower = text.toLowerCase();
  const isAdmin = isAdminNumber(phone);


  // Reload config (so panel edits apply without reinstall; restart still recommended)
  reloadConfig();

  // HC/Custom: if there is an approved payment awaiting HWID, accept HWID now
  if (await tryFinalizeHwidFlow(phone, msg, text)) return;


  // Quick menu
  if (lower === "menu" || lower === "start" || lower === "inicio" || lower === "hola" || lower === "hi") {
    resetSession(phone);
    return client.sendMessage(msg.from, menuText());
  }

  // Session handling
  const s = sessionGet(phone);

  // Menu numeric shortcuts (when not already in flow)
  if (!s.step || s.step === "idle") {
    if (lower === "1") { s.step = "choose_app"; s.plan = "test"; s.app = null; return client.sendMessage(msg.from, appMenuText()); }
    if (lower === "2") { s.step = "choose_premium_plan"; s.plan = null; s.app = null; return client.sendMessage(msg.from, premiumMenuText()); }
    if (lower === "3") {
      const rows = await dbAll("SELECT username, password, tipo, expires_at, app_type, hwid FROM users WHERE phone=? ORDER BY id DESC LIMIT 5", [phone]);
      const toks = await dbAll("SELECT token, plan, expires_at, status FROM tokens WHERE phone=? ORDER BY id DESC LIMIT 5", [phone]);
      if ((!rows || rows.length===0) && (!toks || toks.length===0)) {
        return client.sendMessage(msg.from, "📭 No tenés cuentas registradas.\n\nEscribí *menu* o *comprar*.");
      }
      let out = "👤 *MIS CUENTAS*\n\n";
      if (rows && rows.length) {
        for (const r of rows) {
          out += `✅ Usuario: *${r.username}*\n🔐 Pass: *${r.password}*\n📦 Tipo: *${r.tipo || ""}*\n📅 Expira: *${r.expires_at || "∞"}*\n🧩 App: *${r.app_type || "-"}*\n`;
          if (r.hwid) out += `🆔 HWID: *${r.hwid}*\n`;
          out += "----------------------\n";
        }
      }
      if (toks && toks.length) {
        out += "\n🔑 *TOKENS*\n";
        for (const t of toks) {
          out += `• ${t.token}  (${t.plan})  expira: ${t.expires_at || "∞"}  [${t.status}]\n`;
        }
      }
      return client.sendMessage(msg.from, out);
    }
    if (lower === "4") {
      const pays = await dbAll("SELECT external_reference, status, plan, app_type, amount, currency, created_at FROM payments WHERE phone=? ORDER BY id DESC LIMIT 5", [phone]);
      if (!pays || !pays.length) return client.sendMessage(msg.from, "💳 No tengo pagos registrados.\n\nEscribí *comprar* para generar uno.");
      let out = "💳 *ESTADO DE PAGOS*\n\n";
      for (const p of pays) {
        out += `${p.status === "approved" ? "✅" : "⏳"} *${p.status.toUpperCase()}*\n`;
        out += `Plan: ${p.plan || "-"} | Tipo: ${p.app_type || "-"} | $${p.amount || 0} ${p.currency || CURRENCY}\n`;
        out += `Ref: ${p.external_reference}\n`;
        out += `Fecha: ${p.created_at || ""}\n`;
        out += "----------------------\n";
      }
      out += `\n🔎 Para verificar manual: *verificar <REF>*`;
      return client.sendMessage(msg.from, out);
    }
    if (lower === "5") {
      // APK / Custom download info
      const d = downloadsCfg();
      let out = "📲 *DESCARGAS*\n\n";
      // Try send latest APK in BOT_HOME/apks
      try {
        const apkDir = path.join(BOT_HOME, "apks");
        const files = fs.existsSync(apkDir) ? fs.readdirSync(apkDir).filter(f=>f.toLowerCase().endsWith(".apk")) : [];
        if (files.length) {
          files.sort((a,b)=>fs.statSync(path.join(apkDir,b)).mtimeMs - fs.statSync(path.join(apkDir,a)).mtimeMs);
          const fp = path.join(apkDir, files[0]);
          const st = fs.statSync(fp);
          out += `✅ APK disponible: *${files[0]}* (${(st.size/1024/1024).toFixed(2)} MB)\n`;
          out += "Si WhatsApp permite, te la envío ahora...\n";
          const media = MessageMedia.fromFilePath(fp);
          await client.sendMessage(msg.from, media, { caption: `📲 APK: ${files[0]}` });
          return;
        }
      } catch (_) {}
      if (d.apk_url) out += `🔗 APK URL: ${d.apk_url}\n\n`;
      out += `🧩 *HTTP Custom*\n${customDownloadText()}\n`;
      return client.sendMessage(msg.from, out);
    }
    if (lower === "6" || lower === "soporte") {
      return client.sendMessage(msg.from, supportText());
    }
  }

  if (lower === "ayuda" || lower === "help" || lower === "!help" || lower === "/help") {
    return client.sendMessage(msg.from, helpText(isAdmin));
  }
  if (lower === "precios" || lower === "!precios") {
    return client.sendMessage(msg.from, pricesText());
  }

  if (lower.startsWith("admin ")) {
    if (!isAdmin) return client.sendMessage(msg.from, "❌ No autorizado.");
    return handleAdminCommand(client, msg, phone, text);
  }

  // Verify payment: "verificar <REF>"
  if (lower.startsWith("verificar")) {
    const ref = text.split(/\s+/)[1];
    if (!ref) return client.sendMessage(msg.from, "Usá: verificar <REF>");
    const row = await dbGet("SELECT status, plan, app_type, phone, method, delivered FROM payments WHERE external_reference=?", [ref]);
    if (!row) return client.sendMessage(msg.from, "No encuentro esa referencia.");
if (row.method === "transfer") {
  if (row.status === "approved") {
    return client.sendMessage(msg.from, "✅ Transferencia confirmada. Si todavía no recibiste el acceso, esperá 1-2 minutos o avisá al admin.");
  }
  if (row.status === "pending_admin") {
    return client.sendMessage(msg.from, "⏳ Transferencia en revisión por el admin. Se procesa en ~15 min.");
  }
  return client.sendMessage(msg.from, `ℹ️ Estado actual: ${String(row.status || "").toUpperCase()}`);
}

    if (row.status === "approved") return client.sendMessage(msg.from, "✅ Ya estaba aprobado. Si no recibiste acceso, avisá al admin.");

    const chk = await mpCheckApproved(ref);
    if (!chk.approved) return client.sendMessage(msg.from, `⏳ Aún no aprobado. ${chk.reason}`);

    await ensurePaymentsColumns();
    const pay = chk.payment || {};
    await dbRun("UPDATE payments SET status='approved', approved_at=?, mp_payment_id=?, mp_status_detail=?, delivered=1 WHERE external_reference=?", [nowIso(), String(pay.id || ""), String(pay.status_detail || ""), ref]);

    const appType = row.app_type || "apk";
    const plan = row.plan || "7";

    if (appType === "token") {
      const days = plan === "7" ? 7 : plan === "15" ? 15 : plan === "30" ? 30 : 1;
      const t = await createToken(phone, plan, days);
      return client.sendMessage(msg.from,
        `✅ Pago aprobado.\n🔑 *Token*: ${t.token}\n📅 Expira: ${t.expires_at || "∞"}\n\n📌 Escribí *menu* para ver opciones.`
      );
    }

    const u = await createDbUser(phone, plan, appType);
    let extra = "";
    if (appType === "apk") {
      const d = downloadsCfg();
      if (d.apk_url) extra = "\n\n📲 Descarga APK: " + d.apk_url;
      else extra = "\n\n📲 Escribí *5* para descargar la app.";
    }
    if (appType === "hc") {
      extra = "\n🆔 Enviá tu *HWID* para activar (formato texto).\n\n" + customDownloadText();
    }
    return client.sendMessage(msg.from,
      `✅ Pago aprobado.\n👤 *Usuario*: ${u.username}\n🔐 *Pass*: ${u.password}\n📅 Expira: ${u.expires_at || "∞"}${extra}`
    );
  }

  // HWID message: "hwid <value>"
  if (lower.startsWith("hwid")) {
    const hwid = text.split(/\s+/).slice(1).join(" ").trim();
    if (!hwid) return client.sendMessage(msg.from, "Usá: hwid <TU_HARDWARE_ID>");
    // attach hwid to latest active user for this phone
    const row = await dbGet("SELECT username FROM users WHERE phone=? ORDER BY id DESC LIMIT 1", [phone]);
    if (!row) return client.sendMessage(msg.from, "No tengo un usuario asociado todavía.");
    await dbRun("UPDATE users SET hwid=? WHERE username=?", [hwid, row.username]);

    // also write .hc file for pickup
    try {
      const hcDir = path.join(BOT_HOME, "hc");
      fs.mkdirSync(hcDir, { recursive: true });
      const fp = path.join(hcDir, `${hwid}.hc`);
      fs.writeFileSync(fp, `HWID=${hwid}\nUSER=${row.username}\n`, "utf8");
    } catch {}

    return client.sendMessage(msg.from, `✅ HWID guardado para ${row.username}.`);
  }

  // Start purchase
  if (lower === "comprar" || lower === "!comprar" || lower === "/comprar") {
    const s = sessionGet(phone);
    s.step = "choose_plan";
    s.plan = null;
    s.app = null;
    return client.sendMessage(msg.from, buyMenuText());
  }

  if (s.step === "choose_premium_plan") {
    const v = String(text).trim();
    let plan = null;
    if (v === "1") plan = "7";
    else if (v === "2") plan = "15";
    else if (v === "3") plan = "30";
    if (!plan) return client.sendMessage(msg.from, "Elegí: 1/2/3");
    s.plan = plan;
    s.step = "choose_app";
    return client.sendMessage(msg.from, appMenuText());
  }

  if (s.step === "choose_plan") {
    const plan = mapPlanChoice(text);
    if (!plan) return client.sendMessage(msg.from, "Elegí: 1/2/3/4");
    s.plan = plan;
    s.step = "choose_app";
    return client.sendMessage(msg.from, appMenuText());
  }

  if (s.step === "choose_app") {
    const app = mapAppChoice(text);
    if (!app) return client.sendMessage(msg.from, "Elegí: 1/2/3");
    s.app = app;

    
// If test: no payment, but for HC we must ask HWID first
    if (s.plan === "test") {
      if (app === "token") {
        const t = await createToken(phone, "test", 1);
        resetSession(phone);
        return client.sendMessage(msg.from,
          `✅ *Test ${TEST_HOURS}h* listo.\n🔑 Token: ${t.token}\n📅 Expira: ${t.expires_at || "∞"}\n\n📌 Escribí *menu* para ver opciones.`,
          { sendSeen: false }
        );
      }
      if (app === "hc") {
        s.step = "await_hwid_test";
        return client.sendMessage(
          msg.from,
          `🧩 Elegiste *Custom / HC (HWID)*.\n\n🆔 Enviá tu *HWID* ahora para generar tu usuario.\n\n(Enviá solo el código, sin espacios).`,
          { sendSeen: false }
        );
      }

      const u = await createDbUser(phone, "test", app);
      resetSession(phone);
      return client.sendMessage(
        msg.from,
        `✅ *Test ${TEST_HOURS}h* listo.\n👤 Usuario: ${u.username}\n🔐 Pass: ${u.password}\n📅 Expira: ${u.expires_at || "∞"}` +
          (app === "apk"
            ? (downloadsCfg().apk_url ? ("\n\n📲 Descarga APK: " + downloadsCfg().apk_url) : "\n\n📲 Escribí *5* para descargar la app.")
            : ""),
        { sendSeen: false }
      );
    }
// Paid plans: elegir método de pago
s.step = "choose_payment_method";
const hint = MP_ENABLED ? "" : "\n\n⚠️ MercadoPago no está configurado en el servidor, usá *2) Transferencia*.";
return client.sendMessage(msg.from, paymentMethodMenuText() + hint, { sendSeen: false });

  }

// Step: awaiting HWID for TEST Custom/HC
if (s.step === "await_hwid_test") {
  const hwid = sanitizeHwid(text);
  if (!hwid) {
    return client.sendMessage(msg.from, "⚠️ HWID inválido. Enviá solo el código (sin espacios).", { sendSeen: false });
  }
  try {
    const u = await createDbUserFromHwid(phone, "test", hwid);
    resetSession(phone);

    const hcPath = await getHcFilePath(hwid);
    if (hcPath) {
      try {
        const media = MessageMedia.fromFilePath(hcPath);
        await client.sendMessage(msg.from, media, { caption: `🧩 Archivo HC: ${path.basename(hcPath)}`, sendSeen: false });
      } catch {}
    }

    return client.sendMessage(
      msg.from,
`✅ *Test ${TEST_HOURS}h* activado (Custom/HC)

👤 Usuario: *${u.username}*
🔐 Clave: *${u.password}*
🆔 HWID: *${hwid}*
⏳ Vence: *${moment(u.expires_at).format("DD/MM/YYYY HH:mm")}*

${customDownloadText()}

📌 Escribí *menu* para ver opciones.`,
      { sendSeen: false }
    );
  } catch (e) {
    resetSession(phone);
    return client.sendMessage(msg.from, `❌ No pude activar el HWID: ${e.message}\n\nEscribí *menu* para reintentar.`, { sendSeen: false });
  }
}

// Step: payment method
if (s.step === "choose_payment_method") {
  const ans = lower;
  if (ans === "1" || ans === "mp" || ans === "mercadopago") {
    if (!MP_ENABLED) {
      return client.sendMessage(msg.from, "⚠️ MercadoPago no está configurado. Elegí *2) Transferencia*.", { sendSeen: false });
    }
    // crear preferencia MP
    const pref = await mpCreatePreference({ phone, plan: s.plan, appType: s.app });
    resetSession(phone);

    const payText =
      `✅ *Compra iniciada*\n\nPlan: *${planLabel(s.plan)}*\nTipo: *${appLabel(s.app)}*\nTotal: $${planPrice(s.plan)} ${CURRENCY}` +
      `\n\n✅ Pagá aquí:\n${pref.init_point}` +
      `\n\n🔄 Verificación automática cada 2 minutos.\nTambién podés escribir:\n*verificar ${pref.external_reference}*`;

    await client.sendMessage(msg.from, payText, { sendSeen: false });

    // Enviar QR de pago
    try {
      if (pref.qr_path && fs.existsSync(pref.qr_path)) {
        const media = MessageMedia.fromFilePath(pref.qr_path);
        await client.sendMessage(msg.from, media, { caption: "📱 QR MercadoPago", sendSeen: false });
      }
    } catch {}
    return;
  }

  if (ans === "2" || ans === "transfer" || ans === "transferencia") {
    // Transferencia: pedir comprobante
    s.step = "await_transfer_receipt";
    const refPreview = makeTransferRef(phone);
    // mostramos un ref preliminar para el link (se confirmará al guardar)
    return client.sendMessage(msg.from, transferInstructionsText(refPreview), { sendSeen: false });
  }

  return client.sendMessage(msg.from, "Elegí: 1) MercadoPago  2) Transferencia", { sendSeen: false });
}

// Step: wait receipt for transfer
if (s.step === "await_transfer_receipt") {
  if (lower === "cancelar" || lower === "menu") {
    resetSession(phone);
    return client.sendMessage(msg.from, "✅ Operación cancelada. Escribí *menu* para ver opciones.", { sendSeen: false });
  }

  if (!msg.hasMedia) {
    return client.sendMessage(msg.from, "📎 Enviá el *comprobante* (foto o PDF).\n\nO escribí *cancelar* para salir.", { sendSeen: false });
  }

  const ref = makeTransferRef(phone);
  const receipt = await saveReceiptFromMsg(msg, ref);
  const refSaved = await createTransferPayment({
    phone,
    plan: s.plan,
    appType: s.app,
    receiptPath: receipt.path,
    receiptMime: receipt.mime,
    amount: planPrice(s.plan),
  });

  // avisar usuario
  await client.sendMessage(
    msg.from,
    `✅ Comprobante recibido.\n\nRef: *${refSaved}*\n⏳ Tu pago se procesará en menos de *15 minutos* (confirmación del admin).`,
    { sendSeen: false }
  );

  const t = transferCfg();
  if (t.admin_whatsapp) {
    const msgTxt = encodeURIComponent(`CONFIRMAR PAGO ${refSaved}`);
    await client.sendMessage(
      msg.from,
      `⚡ Para avisar al admin rápido:\n👉 https://wa.me/${t.admin_whatsapp}?text=${msgTxt}`,
      { sendSeen: false }
    );
  }

  // notificar admin
  try {
    const adminChat = (t.admin_whatsapp ? `${t.admin_whatsapp}@c.us` : (ADMIN_NUMBERS[0] ? `${ADMIN_NUMBERS[0]}@c.us` : ""));
    if (adminChat) {
      await safeSend(client, adminChat,
        `🏦 *Nuevo pago por transferencia*\nRef: *${refSaved}*\nTel: ${String(phone).split("@")[0]}\nPlan: ${planLabel(s.plan)} | App: ${appLabel(s.app)}\nMonto: $${planPrice(s.plan)} ${CURRENCY}\n\nConfirmar desde panel: sshbot → Transferencias`
      );
      if (receipt.path && fs.existsSync(receipt.path)) {
        const media = MessageMedia.fromFilePath(receipt.path);
        await safeSend(client, adminChat, media, { caption: `Comprobante ${refSaved}` });
      }
    }
  } catch {}

  resetSession(phone);
  return;
}


  // Default response minimal
  if (lower === "hola" || lower === "buenas" || lower === "buenos dias" || lower === "buenas tardes" || lower === "buenas noches") {
    return client.sendMessage(msg.from, `Hola 👋\n${helpText(isAdmin)}`);
  }
}

function saveQr(qr) {
  try { fs.writeFileSync(QR_TXT, qr, "utf8"); } catch {}
  try {
    qrcode.toFile(QR_PNG, qr, { width: 1024, margin: 2, errorCorrectionLevel: "H" }).catch(() => {});
  } catch {}
}

function main() {
  log(`${BOT_NAME} v${BOT_VERSION} iniciando...`);
  if (configPath) log(`Config: ${configPath}`);
  log(`DB: ${DB_FILE}`);
  log(`MercadoPago: ${MP_ENABLED ? "ON" : "OFF"}`);

  const client = new Client({
    authStrategy: new LocalAuth({ clientId: "ssh-bot", dataPath: BOT_HOME }),
    puppeteer: {
    headless: "new",
    executablePath: cfg("paths.chromium", "/usr/bin/google-chrome"),
    args: [
      "--no-sandbox",
      "--disable-setuid-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu",
      "--disable-software-rasterizer",
      "--no-zygote",
      "--disable-features=IsolateOrigins,site-per-process"
    ]
  }
  });

// Make PM2 restart the bot if WhatsApp/Chromium throws fatal errors
process.on("uncaughtException", (e) => {
  log("uncaughtException: " + (e?.stack || e?.message || e));
  process.exit(1);
});
process.on("unhandledRejection", (e) => {
  log("unhandledRejection: " + (e?.stack || e?.message || e));
  process.exit(1);
});


  client.on("qr", (qr) => {
    log("QR generado. Guardando...");
    saveQr(qr);
    try { qrcodeTerminal.generate(qr, { small: true }); } catch {}
  });

  client.on("ready", () => {
    log("✅ WhatsApp listo.");
    try { fs.unlinkSync(QR_TXT); } catch {}
    try { fs.unlinkSync(QR_PNG); } catch {}

    // Auto-verificación MercadoPago (cada 2 min) – mantiene el comando "verificar <REF>"
    if (MP_ENABLED) {
      log("💳 MercadoPago: verificación automática cada 2 minutos.");
      setTimeout(() => { mpProcessPendingPayments(client).catch(()=>{}); }, 8000);
      setInterval(() => { mpProcessPendingPayments(client).catch(()=>{}); }, 120000);
// Transferencias: entregar pagos confirmados por admin + recordatorios
setTimeout(() => { transferProcessApprovedPayments(client).catch(()=>{}); }, 12000);
setInterval(() => { transferProcessApprovedPayments(client).catch(()=>{}); }, 60000);
setInterval(() => { transferSendReminders(client).catch(()=>{}); }, 60000);
    }
  });

client.on("authenticated", () => log("🔐 Autenticado."));
  client.on("auth_failure", (msg) => log(`❌ Auth failure: ${msg}`));
  client.on("disconnected", (reason) => log(`⚠️ Desconectado: ${reason}`));

  client.on("message", async (msg) => {
    try {
      // ignore groups
      if (msg.from && msg.from.endsWith("@g.us")) return;
      try {
        const b = (msg.body || "").toString().replace(/\s+/g," ").slice(0,200);
        log(`📩 ${msg.from}: ${b}`);
      } catch {}
      await handleMessage(client, msg);
    } catch (e) {
      log(`ERR: ${e && e.stack ? e.stack : e}`);
      try { await client.sendMessage(msg.from, "⚠️ Error interno. Intentá de nuevo en unos segundos."); } catch {}
    }
  });

// Some WhatsApp versions trigger incoming messages via message_create; add a fallback
client.on("message_create", async (msg) => {
  try {
    if (msg.fromMe) return;
    if (msg.from && msg.from.endsWith("@g.us")) return;
    try {
      const b = (msg.body || "").toString().replace(/\s+/g," ").slice(0,200);
      log(`📩(create) ${msg.from}: ${b}`);
    } catch {}
    await handleMessage(client, msg);
  } catch (e) {
    log("message_create error: " + (e?.message || e));
  }
});



  // Enforce max_connections (best effort) – checks sshd sessions per user
  function countSshd(username) {
    try {
      const out = execSync(`pgrep -u ${username} -cx sshd 2>/dev/null || echo 0`, { stdio: ["ignore","pipe","ignore"] }).toString().trim();
      const n = parseInt(out, 10);
      return Number.isFinite(n) ? n : 0;
    } catch { return 0; }
  }

  async function enforceConnections() {
    try {
      const rows = await dbAll("SELECT username, max_connections FROM users WHERE status=1", []);
      for (const r of rows || []) {
        const u = r.username;
        if (!u) continue;
        const maxc = parseInt(r.max_connections || 1, 10) || 1;
        const online = countSshd(u);
        if (online > maxc) {
          log(`⚠️ ${u} conexiones ${online} > ${maxc} (cortando sshd)`);
          try { execSync(`pkill -u ${u} -x sshd 2>/dev/null || true`, { stdio: "ignore" }); } catch {}
        }
      }
    } catch {}
  }

  setInterval(enforceConnections, 30000);
  setTimeout(enforceConnections, 8000);
  client.initialize();
}

process.on("SIGINT", () => { try { db.close(); } catch {} process.exit(0); });
process.on("SIGTERM", () => { try { db.close(); } catch {} process.exit(0); });

main();
BOTJS

chmod +x "$BOT_HOME/bot.js" >/dev/null 2>&1 || true

echo -e "${CYAN}${BOLD}📦 Instalando dependencias Node...${NC}"
cat > "$BOT_HOME/package.json" <<'EOF'
{
  "name": "ssh-bot-pro",
  "version": "8.8.27",
  "description": "SSH Bot Pro WhatsApp",
  "main": "bot.js",
  "scripts": { "start": "node bot.js" },
  "dependencies": {
    "axios": "^1.6.5",
    "qrcode": "^1.5.4",
    "qrcode-terminal": "^0.12.0",
    "sqlite3": "^5.1.7",
    "whatsapp-web.js": "^1.24.0"
  }
}
EOF

cd "$BOT_HOME"
npm cache clean --force >/dev/null 2>&1 || true
npm install --silent >/dev/null 2>&1 || true

# Parche whatsapp-web.js (anti-markedUnread) – best-effort
# 1) Ajuste simple (cuando existe la clave markedUnread)
find node_modules/whatsapp-web.js -name "Client.js" -type f -exec \
  sed -i "s/markedUnread: true/markedUnread: false/g" {} \; 2>/dev/null || true
# 2) Fallback defensivo (algunas versiones traen el if(chat && chat.markedUnread))
find node_modules/whatsapp-web.js -name "Client.js" -type f -exec \
  sed -i "s/if (chat && chat.markedUnread)/if (false \\&\\& chat.markedUnread)/g" {} \; 2>/dev/null || true
# 3) Fallback extra (deshabilitar sendSeen si tu build lo usa y rompe por markedUnread)
find node_modules/whatsapp-web.js -name "Client.js" -type f -exec \
  sed -i "s/const sendSeen = async (chatId) => {/const sendSeen = async (chatId) => { console.log(\\"[DEBUG] sendSeen deshabilitado\\"); return; /g" {} \; 2>/dev/null || true

# Auto-refresh cada 2 horas
( crontab -l 2>/dev/null | grep -v 'ssh-bot-refresh' ) | crontab - || true
echo "0 */2 * * * pm2 restart $BOT_NAME >/dev/null 2>&1 # ssh-bot-refresh" | crontab - || true

# Limpieza expirados cada 15 min (DB)
( crontab -l 2>/dev/null | grep -v 'ssh-bot-clean' ) | crontab - || true
echo "*/15 * * * * sqlite3 $DB_FILE \"DELETE FROM users WHERE expires_at IS NOT NULL AND datetime(expires_at) <= datetime('now');\" >/dev/null 2>&1 # ssh-bot-clean" | crontab - || true

echo -e "${CYAN}${BOLD}🚀 Iniciando bot con PM2...${NC}"
pm2 delete "$BOT_NAME" >/dev/null 2>&1 || true
pm2 start "$BOT_HOME/bot.js" --name "$BOT_NAME" --cwd "$BOT_HOME" >/dev/null 2>&1 || true
pm2 save >/dev/null 2>&1 || true

# ================================================
# ================================================
# PANEL ADMIN (COMANDO sshbot)
# ================================================
echo -e "${CYAN}${BOLD}📊 Instalando panel admin (sshbot)...${NC}"
mkdir -p /usr/local/bin

# ✅ Panel separado para evitar scripts gigantes y errores de pegado.
# Si existe panel_admin.sh en el mismo directorio del instalador, lo usa.
# Si no, lo descarga desde GitHub (PANEL_URL).
PANEL_LOCAL_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd -P 2>/dev/null || echo "")"
PANEL_LOCAL="${PANEL_LOCAL_DIR}/panel_admin.sh"

PANEL_URL_DEFAULT="https://raw.githubusercontent.com/eze1087/bootsshx2/refs/heads/main/install.sh"
PANEL_URL="${PANEL_URL:-$PANEL_URL_DEFAULT}"

PANEL_PATH="/usr/local/bin/panel_admin"

if [[ -n "$PANEL_LOCAL_DIR" && -f "$PANEL_LOCAL" ]]; then
  cp -f "$PANEL_LOCAL" "$PANEL_PATH"
else
  (curl -fsSL "$PANEL_URL" -o "$PANEL_PATH" || wget -qO "$PANEL_PATH" "$PANEL_URL") || {
    echo -e "${RED}❌ ERROR: No se pudo descargar el panel admin.${NC}"
    echo -e "${YELLOW}➡️ Subí panel_admin.sh al repo y verificá PANEL_URL.${NC}"
    exit 1
  }
fi

chmod +x "$PANEL_PATH"
ln -sf "$PANEL_PATH" /usr/local/bin/sshbot
chmod +x /usr/local/bin/sshbot
hash -r 2>/dev/null || true
hash -r 2>/dev/null || true

echo
echo -e "${GREEN}${BOLD}✅ Instalación EMBED completada.${NC}"
echo -e "${CYAN}👉 Panel: ${BOLD}sshbot${NC}"
echo -e "${CYAN}👉 QR: en panel opción [2] (borra sesión + fuerza QR nuevo)${NC}"
echo
