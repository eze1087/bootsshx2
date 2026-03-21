#!/bin/bash
# ================================================
# SSH BOT PRO v8.6 - TOLICADOS
# Correcciones aplicadas:
# 1. ✅ Validación token MercadoPago FIXED
# 2. ✅ Fechas ISO 8601 correctas (MP SDK v2.x)
# 3. ✅ Parche error markedUnread de WhatsApp Web
# 4. ✅ Inicialización MP SDK corregida
# 5. ✅ Panel de control funcionando 100%
# ================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Banner inicial
clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
╠════════════════════════════════════╣
║                                                              ║
║           🚀 SSH BOT PRO v8.6 -    ║
║               📱 APK Auto + 3h Test                       ║ 
╚══════════════════════════════════════╝
BANNER
echo -e "${NC}"

echo -e "${GREEN}✅ CORRECCIONES APLICADAS EN ESTA VERSIÓN:${NC}"
echo -e "  🔴 ${RED}FIX 1:${NC} Validación token MP corregida (regex fija)"
echo -e "  🟢 ${GREEN}FIX 3:${NC} Parche error 'markedUnread' de WhatsApp Web"
echo -e "  🔵 ${BLUE}FIX 4:${NC} Inicialización MP SDK corregida"
echo -e "  🟣 ${PURPLE}FIX 5:${NC} Panel de control 100% funcional"
echo -e "${CYAN}══════════════════════════════════${NC}\n"

# Verificar root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}${BOLD}❌ ERROR: Debes ejecutar como root${NC}"
    echo -e "${YELLOW}Usa: sudo bash $0${NC}"
    exit 1
fi

# Detectar IP
echo -e "${CYAN}${BOLD}🔍 DETECTANDO IP DEL SERVIDOR...${NC}"
SERVER_IP=$(curl -4 -s --max-time 10 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "127.0.0.1")
if [[ -z "$SERVER_IP" || "$SERVER_IP" == "127.0.0.1" ]]; then
    echo -e "${RED}❌ No se pudo obtener IP pública${NC}"
    read -p "📝 Ingresa la IP del servidor manualmente: " SERVER_IP
fi

echo -e "${GREEN}✅ IP detectada: ${CYAN}$SERVER_IP${NC}\n"

# Confirmar instalación
echo -e "${YELLOW}⚠️  ESTE INSTALADOR HARÁ:${NC}"
echo -e "   • Instalar Node.js 20.x + Chrome"
echo -e "   • Crear SSH Bot Pro v8.6 CON TODOS LOS FIXES"
echo -e "   • Aplicar parche error WhatsApp Web"
echo -e "   • Configurar fechas ISO 8601 correctas"
echo -e "   • Panel de control 100% funcional"
echo -e "   • APK automático + Test 3h"
echo -e "\n${RED}⚠️  Se eliminarán instalaciones anteriores${NC}"

read -p "$(echo -e "${YELLOW}¿Continuar con la instalación? (s/N): ${NC}")" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${RED}❌ Instalación cancelada${NC}"
    exit 0
fi

# ================================================
# INSTALAR DEPENDENCIAS
# ================================================
echo -e "\n${CYAN}${BOLD}📦 INSTALANDO DEPENDENCIAS...${NC}"

echo -e "${YELLOW}🔄 Actualizando sistema...${NC}"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq > /dev/null 2>&1

echo -e "${YELLOW}📥 Instalando paquetes básicos...${NC}"
apt-get install -y -qq \
    curl wget git unzip \
    sqlite3 jq nano htop \
    cron build-essential \
    ca-certificates gnupg \
    software-properties-common \
    libgbm-dev libxshmfence-dev \
    sshpass at \
    > /dev/null 2>&1

# Habilitar servicio 'at'
systemctl enable atd 2>/dev/null || true
systemctl start atd 2>/dev/null || true

# Google Chrome
echo -e "${YELLOW}🌐 Instalando Google Chrome...${NC}"
if ! command -v google-chrome &> /dev/null; then
    wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb
    apt-get install -y -qq /tmp/chrome.deb > /dev/null 2>&1
    rm -f /tmp/chrome.deb
fi

# Node.js 20.x
echo -e "${YELLOW}🟢 Instalando Node.js 20.x...${NC}"
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - > /dev/null 2>&1
    apt-get install -y -qq nodejs > /dev/null 2>&1
fi

# PM2 global
echo -e "${YELLOW}⚡ Instalando PM2...${NC}"
npm install -g pm2 --silent > /dev/null 2>&1

echo -e "${GREEN}✅ Dependencias instaladas${NC}"

# ================================================
# PREPARAR ESTRUCTURA
# ================================================
echo -e "\n${CYAN}${BOLD}📁 CREANDO ESTRUCTURA...${NC}"

INSTALL_DIR="/opt/ssh-bot"
USER_HOME="/root/ssh-bot"
DB_FILE="$INSTALL_DIR/data/users.db"
CONFIG_FILE="$INSTALL_DIR/config/config.json"

# Limpiar instalaciones anteriores
echo -e "${YELLOW}🧹 Limpiando instalaciones anteriores...${NC}"
pm2 delete ssh-bot 2>/dev/null || true
pm2 flush 2>/dev/null || true
rm -rf "$INSTALL_DIR" "$USER_HOME" 2>/dev/null || true
rm -rf /root/.wwebjs_auth /root/.wwebjs_cache 2>/dev/null || true

# Crear directorios
mkdir -p "$INSTALL_DIR"/{data,config,qr_codes,logs}
mkdir -p "$USER_HOME"
mkdir -p /root/.wwebjs_auth
chmod -R 755 "$INSTALL_DIR"
chmod -R 700 /root/.wwebjs_auth

# Crear configuración
cat > "$CONFIG_FILE" << EOF
{
    "bot": {
        "name": "SSH Bot Pro",
        "version": "8.6-ALL-FIXES",
        "server_ip": "$SERVER_IP"
    },
    "prices": {
        "test_hours": 3,
        "price_7d": 950.00,
        "price_15d": 1750.00,
        "price_30d": 3750.00,
        "currency": "ARS"
    },
    "mercadopago": {
        "access_token": "",
        "enabled": false
    },
    "links": {
        "tutorial": "https://youtube.com",
        "support": "https://t.me/soporte"
    },
    "paths": {
        "database": "$DB_FILE",
        "chromium": "/usr/bin/google-chrome",
        "qr_codes": "$INSTALL_DIR/qr_codes"
    }
}
EOF

# Crear base de datos
sqlite3 "$DB_FILE" << 'SQL'
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    username TEXT UNIQUE,
    password TEXT,
    tipo TEXT DEFAULT 'test',
    expires_at DATETIME,
    max_connections INTEGER DEFAULT 1,
    status INTEGER DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE daily_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT,
    date DATE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(phone, date)
);
CREATE TABLE payments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payment_id TEXT UNIQUE,
    phone TEXT,
    plan TEXT,
    days INTEGER,
    amount REAL,
    status TEXT DEFAULT 'pending',
    payment_url TEXT,
    qr_code TEXT,
    preference_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    approved_at DATETIME
);
CREATE TABLE logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT,
    message TEXT,
    data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_payments_status ON payments(status);
SQL

echo -e "${GREEN}✅ Estructura creada${NC}"

# ================================================
# CREAR BOT CON TODOS LOS FIXES
# ================================================
echo -e "\n${CYAN}${BOLD}🤖 CREANDO BOT ...${NC}"

cd "$USER_HOME"

# package.json con MercadoPago SDK correcto
cat > package.json << 'PKGEOF'
{
    "name": "ssh-bot-pro",
    "version": "8.6.0",
    "main": "bot.js",
    "dependencies": {
        "whatsapp-web.js": "1.24.0",
        "qrcode-terminal": "^0.12.0",
        "qrcode": "^1.5.3",
        "moment": "^2.30.1",
        "sqlite3": "^5.1.7",
        "chalk": "^4.1.2",
        "node-cron": "^3.0.3",
        "mercadopago": "^2.0.15",
        "axios": "^1.6.5"
    }
}
PKGEOF

echo -e "${YELLOW}📦 Instalando paquetes Node.js...${NC}"
npm install --silent 2>&1 | grep -v "npm WARN" || true

# ✅ PARCHES whatsapp-web.js
echo -e "${YELLOW}🔧 Aplicando parches a WhatsApp Web...${NC}"

# 1. markedUnread
find node_modules/whatsapp-web.js -name "Client.js" -type f -exec \
  sed -i 's/if (chat && chat.markedUnread)/if (false \&\& chat.markedUnread)/g' {} \; 2>/dev/null || true

# 2. sendSeen (causa crash silencioso al responder mensajes)
find node_modules/whatsapp-web.js -name "Client.js" -type f -exec \
  sed -i 's/const sendSeen = async (chatId) => {/const sendSeen = async (chatId) => { console.log("[PATCH] sendSeen disabled"); return;/g' {} \; 2>/dev/null || true

# 3. setUserAgent crash (Session closed / Target closed) - EL MÁS IMPORTANTE
find node_modules/whatsapp-web.js -name "Client.js" -type f -exec \
  sed -i 's/await page\.setUserAgent(useragent);/try { await page.setUserAgent(useragent); } catch(_e) { console.log("[PATCH] setUserAgent skipped"); }/g' {} \; 2>/dev/null || true

# 4. LocalWebCache null crash (Cannot read properties of null reading 1)
find node_modules/whatsapp-web.js -name "LocalWebCache.js" -type f -exec \
  sed -i "s/const version = htmlFile\.match(/const version = (htmlFile ? htmlFile.match(/g" {} \; 2>/dev/null || true
find node_modules/whatsapp-web.js -name "LocalWebCache.js" -type f -exec \
  sed -i "s/const version = (htmlFile ? htmlFile\.match(\(.*\))\[1\]/const version = (htmlFile ? htmlFile.match(\1) || [] : [])[1]/g" {} \; 2>/dev/null || true

echo -e "${GREEN}✅ Parches aplicados${NC}"

# Crear bot.js CON TODOS LOS FIXES
echo -e "${YELLOW}📝 Creando bot.js con todos los fixes...${NC}"

cat > "bot.js" << 'BOTEOF'
"use strict";

const { Client, LocalAuth, MessageMedia } = require('whatsapp-web.js');
const qrcodeTerminal = require('qrcode-terminal');
const QRCode = require('qrcode');
const moment = require('moment');
const sqlite3 = require('sqlite3').verbose();
const { exec, execSync } = require('child_process');
const util = require('util');
const chalk = require('chalk');
const cron = require('node-cron');
const fs = require('fs');
const path = require('path');
const axios = require('axios');
const execPromise = util.promisify(exec);

// ─── CONFIG ────────────────────────────────────────────────────────────────
function loadConfig() {
  const paths = ['/root/ssh-bot/config/config.json', '/opt/ssh-bot/config/config.json'];
  for (const p of paths) {
    try { delete require.cache[require.resolve(p)]; return require(p); } catch (_) {}
  }
  return {};
}

let config = loadConfig();
const DB_FILE = (config.paths && config.paths.database) || '/opt/ssh-bot/data/users.db';
const db = new sqlite3.Database(DB_FILE);

// ─── MERCADOPAGO SDK v2.x ──────────────────────────────────────────────────
let mpClient = null;
let mpPreference = null;

function initMercadoPago() {
  config = loadConfig();
  if (config.mercadopago && config.mercadopago.access_token && config.mercadopago.access_token !== '') {
    try {
      const { MercadoPagoConfig, Preference } = require('mercadopago');
      mpClient = new MercadoPagoConfig({ accessToken: config.mercadopago.access_token, options: { timeout: 5000 } });
      mpPreference = new Preference(mpClient);
      console.log(chalk.green('✅ MercadoPago SDK v2.x ACTIVO'));
      console.log(chalk.cyan(`🔑 Token: ${config.mercadopago.access_token.substring(0, 20)}...`));
      return true;
    } catch (error) {
      console.log(chalk.red('❌ Error MP:'), error.message);
      mpClient = null; mpPreference = null; return false;
    }
  }
  console.log(chalk.yellow('⚠️  MercadoPago NO configurado (token vacío)'));
  return false;
}

let mpEnabled = initMercadoPago();
moment.locale('es');

console.log(chalk.cyan.bold('\n╔══════════════════════════════════════════════════╗'));
console.log(chalk.cyan.bold('║      🤖 SSH BOT ELNENE PRO v8.8.27               ║'));
console.log(chalk.cyan.bold('╚══════════════════════════════════════════════════╝\n'));
console.log(chalk.yellow(`📍 IP: ${config.bot && config.bot.server_ip}`));
console.log(chalk.yellow(`💳 MercadoPago: ${mpEnabled ? '✅ ACTIVO' : '❌ NO CONFIGURADO'}`));

// ─── CLIENT ────────────────────────────────────────────────────────────────
const client = new Client({
    authStrategy: new LocalAuth({dataPath: '/root/.wwebjs_auth', clientId: 'ssh-bot-v86'}),
    puppeteer: {
        headless: true,
        executablePath: '/usr/bin/google-chrome',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu', '--no-first-run', '--disable-extensions'],
        timeout: 60000
    },
    authTimeoutMs: 60000
});

let qrCount = 0;
client.on('qr', (qr) => {
  qrCount++;
  console.clear();
  console.log(chalk.yellow.bold(`\n╔════════ 📱 QR #${qrCount} - ESCANEA AHORA ════════╗\n`));
  qrcodeTerminal.generate(qr, { small: true });
  QRCode.toFile('/root/qr-whatsapp.png', qr, { width: 500 }).catch(() => {});
  fs.writeFileSync('/root/qr-whatsapp.txt', qr, 'utf8');
  console.log(chalk.green('\n💾 QR guardado: /root/qr-whatsapp.png\n'));
});

client.on('authenticated', () => console.log(chalk.green('✅ Autenticado')));
client.on('loading_screen', (p, m) => console.log(chalk.yellow(`⏳ Cargando: ${p}% - ${m}`)));
client.on('auth_failure', (m) => console.log(chalk.red('❌ Error auth:'), m));
client.on('disconnected', (r) => console.log(chalk.yellow('⚠️  Desconectado:'), r));

client.on('ready', () => {
  console.clear();
  console.log(chalk.green.bold('\n✅ BOT CONECTADO Y OPERATIVO\n'));
  console.log(chalk.cyan('💬 Envía "menu" a tu WhatsApp para probar\n'));
  qrCount = 0;
  // Auto-check pagos MP cada 2 min
  if (mpEnabled) {
    setTimeout(() => checkPendingPayments(), 8000);
    setInterval(() => checkPendingPayments(), 120000);
  }
  // Transferencias: siempre activas
  setTimeout(() => transferProcessApproved(), 12000);
  setInterval(() => transferProcessApproved(), 60000);
  setInterval(() => transferSendReminders(), 60000);
});

// ─── HELPERS ───────────────────────────────────────────────────────────────
function generateUsername() { return 'user' + Math.random().toString(36).substr(2, 4); }
function generatePassword() { return Math.random().toString(36).substr(2, 6) + Math.random().toString(36).substr(2, 4).toUpperCase(); }

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  try { fs.appendFileSync('/opt/ssh-bot/logs/bot.log', line + '\n'); } catch (_) {}
}

function normalizePhone(from) { return String(from).split('@')[0].replace(/\D/g, ''); }

function canCreateTest(phone) {
  return new Promise((resolve) => {
    const today = moment().format('YYYY-MM-DD');
    db.get('SELECT COUNT(*) as count FROM daily_tests WHERE phone = ? AND date = ?', [phone, today],
      (err, row) => resolve(!err && row && row.count === 0));
  });
}
function registerTest(phone) {
  db.run('INSERT OR IGNORE INTO daily_tests (phone, date) VALUES (?, ?)', [phone, moment().format('YYYY-MM-DD')]);
}

async function createSSHUser(phone, username, password, days, connections) {
  connections = connections || 1;
  if (days <= 1) {
    const testHours = (config.prices && config.prices.test_hours) || 3;
    const expireFull = moment().add(testHours, 'hours').format('YYYY-MM-DD HH:mm:ss');
    const expireDate = moment().add(testHours, 'hours').format('YYYY-MM-DD');
    try { execSync(`useradd -m -s /bin/bash ${username} 2>/dev/null || true`); } catch (_) {}
    try { execSync(`echo "${username}:${password}" | chpasswd`); } catch (_) {}
    try { execSync(`chage -E "${expireDate}" "${username}" 2>/dev/null || true`); } catch (_) {}
    return new Promise((resolve, reject) => {
      db.run('INSERT INTO users (phone, username, password, tipo, expires_at, max_connections, status) VALUES (?, ?, ?, "test", ?, ?, 1)',
        [phone, username, password, expireFull, connections],
        (err) => err ? reject(err) : resolve({ username, password, expires: expireFull }));
    });
  } else {
    const expireDate = moment().add(days, 'days').format('YYYY-MM-DD');
    const expireFull = expireDate + ' 23:59:59';
    try { execSync(`useradd -M -s /bin/false -e ${expireDate} ${username} 2>/dev/null || true`); } catch (_) {}
    try { execSync(`echo "${username}:${password}" | chpasswd`); } catch (_) {}
    return new Promise((resolve, reject) => {
      db.run('INSERT INTO users (phone, username, password, tipo, expires_at, max_connections, status) VALUES (?, ?, ?, "premium", ?, ?, 1)',
        [phone, username, password, expireFull, connections],
        (err) => err ? reject(err) : resolve({ username, password, expires: expireFull }));
    });
  }
}

function randStr(n) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
  let s = '';
  for (let i = 0; i < n; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

async function createToken(phone, plan, days) {
  const token = 'TKN_' + randStr(20);
  const exp = days ? moment().add(days, 'days').format('YYYY-MM-DD HH:mm:ss') : null;
  await new Promise((res, rej) => {
    db.run('INSERT INTO tokens(phone, token, plan, expires_at, status) VALUES(?,?,?,?,"active")',
      [phone, token, plan, exp], (err) => err ? rej(err) : res());
  });
  return { token, expires_at: exp };
}

// ─── MERCADOPAGO ──────────────────────────────────────────────────────────
function getPrice(plan) {
  config = loadConfig();
  if (plan === '7d' || plan === '7') return Number((config.prices && (config.prices.price_7d || config.prices.plan_7)) || 950);
  if (plan === '15d' || plan === '15') return Number((config.prices && (config.prices.price_15d || config.prices.plan_15)) || 1750);
  if (plan === '30d' || plan === '30') return Number((config.prices && (config.prices.price_30d || config.prices.plan_30)) || 3750);
  return 0;
}

async function createMercadoPagoPayment(phone, plan, days, amount, connections) {
  try {
    config = loadConfig();
    if (!config.mercadopago || !config.mercadopago.access_token || config.mercadopago.access_token === '')
      return { success: false, error: 'MercadoPago no configurado' };
    if (!mpPreference) { mpEnabled = initMercadoPago(); }
    if (!mpEnabled || !mpPreference) return { success: false, error: 'No se pudo inicializar MercadoPago' };

    const phoneClean = phone.split('@')[0];
    const paymentId = `PREMIUM-${phoneClean}-${plan}-${Date.now()}`;
    const cur = (config.prices && config.prices.currency) || 'ARS';

    const preferenceData = {
      items: [{ title: `SERVICIO PREMIUM ${days} DIAS`, quantity: 1, currency_id: cur, unit_price: parseFloat(amount) }],
      external_reference: paymentId,
      expires: true,
      expiration_date_from: moment().toISOString(),
      expiration_date_to: moment().add(24, 'hours').toISOString()
    };

    const response = await mpPreference.create({ body: preferenceData });
    if (response && response.id) {
      const paymentUrl = response.init_point;
      const qrDir = '/opt/ssh-bot/qr_codes';
      if (!fs.existsSync(qrDir)) fs.mkdirSync(qrDir, { recursive: true });
      const qrPath = `${qrDir}/${paymentId}.png`;
      await QRCode.toFile(qrPath, paymentUrl, { width: 400, margin: 1 });
      db.run('INSERT INTO payments (payment_id, phone, plan, days, amount, status, payment_url, qr_code, preference_id) VALUES (?,?,?,?,?,"pending",?,?,?)',
        [paymentId, phone, plan, days, amount, paymentUrl, qrPath, response.id]);
      console.log(chalk.green(`✅ Pago MP creado: ${paymentId}`));
      return { success: true, paymentId, paymentUrl, qrPath, preferenceId: response.id };
    }
    throw new Error('Respuesta inválida de MercadoPago');
  } catch (error) {
    console.error(chalk.red('❌ Error MP:'), error.message);
    return { success: false, error: error.message };
  }
}

async function checkPendingPayments() {
  config = loadConfig();
  if (!config.mercadopago || !config.mercadopago.access_token || config.mercadopago.access_token === '') return;
  db.all('SELECT * FROM payments WHERE status = "pending" AND created_at > datetime("now", "-48 hours")', async (err, payments) => {
    if (err || !payments || payments.length === 0) return;
    for (const payment of payments) {
      try {
        const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${payment.payment_id}`;
        const response = await axios.get(url, {
          headers: { 'Authorization': `Bearer ${config.mercadopago.access_token}` }, timeout: 15000
        });
        if (response.data && response.data.results && response.data.results.length > 0) {
          const mpPayment = response.data.results[0];
          if (mpPayment.status === 'approved') {
            const username = generateUsername();
            const password = generatePassword();
            await createSSHUser(payment.phone, username, password, payment.days, 1);
            db.run('UPDATE payments SET status = "approved", approved_at = CURRENT_TIMESTAMP WHERE payment_id = ?', [payment.payment_id]);
            const expireDate = moment().add(payment.days, 'days').format('DD/MM/YYYY');
            await client.sendMessage(payment.phone,
              `🎉 *PAGO CONFIRMADO*\n\n👤 *Usuario:* ${username}\n🔑 *Contraseña:* ${password}\n\n   recargas.personal.com.ar:80@${username}:${password}\n\n⏰ Válido hasta: ${expireDate}\n\n💬 Soporte: *Escribe 13*`,
              { sendSeen: false });
            console.log(chalk.green(`✅ Pago aprobado, usuario creado: ${username}`));
          }
        }
      } catch (e) { console.error(chalk.red('❌ Error check pago:'), e.message); }
    }
  });
}

// ─── TRANSFERENCIAS ────────────────────────────────────────────────────────
function transferCfg() {
  config = loadConfig();
  return {
    enabled: !!(config.transfer && config.transfer.enabled),
    alias: (config.transfer && config.transfer.alias) || '',
    cbu: (config.transfer && config.transfer.cbu) || '',
    titular: (config.transfer && config.transfer.titular) || '',
    admin: String((config.transfer && config.transfer.admin_whatsapp) || (config.links && config.links.support_whatsapp) || '').replace(/\D/g, '')
  };
}

function makeTransferRef(phone) {
  const last = String(phone).replace(/\D/g, '').slice(-4) || '0000';
  return `TR-${Date.now()}-${last}`;
}

function transferInstructions(ref) {
  const t = transferCfg();
  let lines = ['🏦 *Transferencia bancaria*'];
  if (t.titular) lines.push(`👤 Titular: *${t.titular}*`);
  if (t.alias)   lines.push(`🔤 Alias: *${t.alias}*`);
  if (t.cbu)     lines.push(`🏛️ CBU: *${t.cbu}*`);
  lines.push('', '📎 *Enviá el comprobante acá mismo* (foto o PDF).', '⏳ Se confirma en ~15 minutos.');
  if (t.admin) {
    const msg = encodeURIComponent(`CONFIRMAR PAGO ${ref}`);
    lines.push('', '⚡ Para avisar al admin:', `👉 https://wa.me/${t.admin}?text=${msg}`);
  }
  return lines.join('\n');
}

async function saveReceipt(msg, ref) {
  try {
    if (!msg.hasMedia) return { path: '', mime: '' };
    const media = await msg.downloadMedia();
    if (!media || !media.data) return { path: '', mime: '' };
    const dir = '/opt/ssh-bot/receipts';
    try { fs.mkdirSync(dir, { recursive: true }); } catch (_) {}
    const mime = media.mimetype || '';
    const ext = mime.includes('png') ? 'png' : mime.includes('pdf') ? 'pdf' : 'jpg';
    const outPath = `${dir}/${ref}.${ext}`;
    fs.writeFileSync(outPath, Buffer.from(media.data, 'base64'));
    return { path: outPath, mime };
  } catch (_) { return { path: '', mime: '' }; }
}

async function createTransferPayment({ phone, plan, appType, receiptPath, receiptMime, amount }) {
  const ref = makeTransferRef(phone);
  const cur = (config.prices && config.prices.currency) || 'ARS';
  // Asegurar columnas extras
  try { db.run("ALTER TABLE payments ADD COLUMN method TEXT DEFAULT 'mp'"); } catch (_) {}
  try { db.run('ALTER TABLE payments ADD COLUMN receipt_path TEXT'); } catch (_) {}
  try { db.run('ALTER TABLE payments ADD COLUMN receipt_mime TEXT'); } catch (_) {}
  try { db.run('ALTER TABLE payments ADD COLUMN app_type TEXT'); } catch (_) {}
  try { db.run('ALTER TABLE payments ADD COLUMN delivered INTEGER DEFAULT 0'); } catch (_) {}
  try { db.run('ALTER TABLE payments ADD COLUMN reminded INTEGER DEFAULT 0'); } catch (_) {}
  await new Promise((res, rej) => {
    db.run(
      "INSERT INTO payments (payment_id, phone, plan, days, amount, status, method, app_type, receipt_path, receipt_mime, delivered, reminded) VALUES (?,?,?,?,?,\"pending_admin\",\"transfer\",?,?,?,0,0)",
      [ref, phone, plan, plan === '7d' ? 7 : plan === '15d' ? 15 : 30, amount, appType || 'apk', receiptPath || '', receiptMime || ''],
      (err) => err ? rej(err) : res()
    );
  });
  return ref;
}

async function transferProcessApproved() {
  try {
    db.all(
      "SELECT * FROM payments WHERE method='transfer' AND status='approved' AND (delivered IS NULL OR delivered=0) AND created_at >= datetime('now','-14 days')",
      async (err, rows) => {
        if (err || !rows || rows.length === 0) return;
        for (const p of rows) {
          try {
            const plan = p.plan || '7d';
            const days = plan === '7d' ? 7 : plan === '15d' ? 15 : 30;
            const appType = p.app_type || 'apk';
            if (appType === 'token') {
              const t = await createToken(p.phone, plan, days);
              await client.sendMessage(p.phone,
                `🎉 *PAGO CONFIRMADO (Transferencia)*\n\n🔑 *Token*: ${t.token}\n📅 Expira: ${t.expires_at || '∞'}\n\n📌 Escribí *menu* para ver opciones.`,
                { sendSeen: false });
            } else {
              const u = await createSSHUser(p.phone, generateUsername(), generatePassword(), days, 1);
              await client.sendMessage(p.phone,
                `🎉 *PAGO CONFIRMADO (Transferencia)*\n\n👤 Usuario: *${u.username}*\n🔑 Pass: *${u.password}*\n📅 Expira: *${u.expires}*\n\n   recargas.personal.com.ar:80@${u.username}:${u.password}`,
                { sendSeen: false });
            }
            db.run("UPDATE payments SET delivered=1 WHERE payment_id=?", [p.payment_id]);
          } catch (e) { console.error('Transfer deliver error:', e.message); }
        }
      }
    );
  } catch (_) {}
}

async function transferSendReminders() {
  try {
    db.all(
      "SELECT * FROM payments WHERE method='transfer' AND status='pending_admin' AND (reminded IS NULL OR reminded=0) AND created_at <= datetime('now','-15 minutes')",
      async (err, rows) => {
        if (err || !rows || rows.length === 0) return;
        for (const p of rows) {
          try {
            await client.sendMessage(p.phone,
              `⏳ *Pago en revisión*\nRef: *${p.payment_id}*\nEstamos esperando la confirmación del admin. Si ya enviaste el comprobante, aguardá un momento más.`,
              { sendSeen: false });
            const t = transferCfg();
            if (t.admin) {
              await client.sendMessage(`${t.admin}@c.us`,
                `🏦 Transferencia pendiente >15min\nRef: ${p.payment_id}\nTel: ${String(p.phone).split('@')[0]}\nPlan: ${p.plan} | $${p.amount}`,
                { sendSeen: false });
            }
            db.run("UPDATE payments SET reminded=1 WHERE payment_id=?", [p.payment_id]);
          } catch (_) {}
        }
      }
    );
  } catch (_) {}
}

// ─── IA GEMINI ─────────────────────────────────────────────────────────────
async function geminiSupportReply(userText) {
  try {
    config = loadConfig();
    if (!config.gemini || !config.gemini.enabled || !config.gemini.api_key) return null;
    const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=${config.gemini.api_key}`;
    const resp = await axios.post(url, {
      contents: [{ parts: [{ text: `Eres soporte técnico SSH/VPN. Responde breve y profesional.\nConsulta: "${userText}"` }] }]
    }, { timeout: 15000 });
    return resp?.data?.candidates?.[0]?.content?.parts?.[0]?.text || null;
  } catch (_) { return null; }
}

// ─── COMANDOS ADMIN ────────────────────────────────────────────────────────
const ADMIN_NUMBERS = [];

function isAdmin(phone) {
  if (!ADMIN_NUMBERS.length) return true;
  return ADMIN_NUMBERS.includes(normalizePhone(phone));
}

async function handleAdminCommand(msg, text) {
  const parts = text.trim().split(/\s+/);
  const sub = (parts[1] || '').toLowerCase();
  const phone = msg.from;

  if (sub === 'usuarios') {
    db.all('SELECT username,tipo,expires_at,status FROM users ORDER BY id DESC LIMIT 50', (err, rows) => {
      if (!rows || !rows.length) return client.sendMessage(phone, 'No hay usuarios.');
      const lines = rows.map(r => `• ${r.username} | ${r.tipo} | ${r.expires_at || '∞'} | ${r.status === 1 ? 'ACTIVO' : 'INACTIVO'}`);
      client.sendMessage(phone, '*Usuarios (últimos 50)*\n' + lines.join('\n'));
    });
    return;
  }
  if (sub === 'borrar' && parts[2]) {
    const u = parts[2];
    db.run('DELETE FROM users WHERE username=?', [u]);
    try { execSync(`userdel -f ${u} 2>/dev/null || true`); } catch (_) {}
    return client.sendMessage(phone, `✅ Usuario borrado: ${u}`);
  }
  if (sub === 'tokens') {
    db.all('SELECT token,plan,expires_at,status FROM tokens ORDER BY id DESC LIMIT 50', (err, rows) => {
      if (!rows || !rows.length) return client.sendMessage(phone, 'No hay tokens.');
      const lines = rows.map(r => `• ${r.token} | ${r.plan} | ${r.expires_at || '∞'} | ${r.status}`);
      client.sendMessage(phone, '*Tokens (últimos 50)*\n' + lines.join('\n'));
    });
    return;
  }
  if (sub === 'revocar' && parts[2]) {
    db.run("UPDATE tokens SET status='revoked' WHERE token=?", [parts[2]]);
    return client.sendMessage(phone, `✅ Token revocado: ${parts[2]}`);
  }
  return client.sendMessage(phone, 'Admin: usuarios | borrar <user> | tokens | revocar <token>');
}

// ─── SESIONES ──────────────────────────────────────────────────────────────
const sessions = new Map();
function sGet(phone) {
  if (!sessions.has(phone)) sessions.set(phone, { step: 'idle' });
  return sessions.get(phone);
}
function sReset(phone) { sessions.set(phone, { step: 'idle' }); }

// ─── HANDLER PRINCIPAL DE MENSAJES ────────────────────────────────────────
client.on('message', async (msg) => {
  try {
    const phone = msg.from;
    if (!phone || phone.includes('@g.us')) return;
    config = loadConfig();

    const raw = (msg.body || '').trim();
    const text = raw.toLowerCase();

    log(`MSG from=${phone} body=${JSON.stringify(raw).slice(0, 100)}`);

    // Precios siempre frescos del config
    const p7  = getPrice('7d');
    const p15 = getPrice('15d');
    const p30 = getPrice('30d');
    const cur = (config.prices && config.prices.currency) || 'ARS';
    const testH = (config.prices && config.prices.test_hours) || 3;
    const supportLink = (config.links && (config.links.support_whatsapp || config.links.support)) || 'https://wa.me/543764243693';

    // ── ADMIN ──
    if (text.startsWith('admin ')) {
      if (!isAdmin(phone)) return client.sendMessage(phone, '❌ No autorizado.', { sendSeen: false });
      return handleAdminCommand(msg, text);
    }

    // ── VERIFICAR PAGO ──
    if (text.startsWith('verificar')) {
      const ref = raw.split(/\s+/)[1];
      if (!ref) return client.sendMessage(phone, 'Usá: verificar <REF>', { sendSeen: false });
      db.get('SELECT * FROM payments WHERE payment_id=?', [ref], async (err, row) => {
        if (!row) return client.sendMessage(phone, '❌ No encuentro esa referencia.', { sendSeen: false });
        if (row.status === 'approved') return client.sendMessage(phone, '✅ Ya estaba aprobado.', { sendSeen: false });
        if (row.method === 'transfer' || row.status === 'pending_admin') {
          return client.sendMessage(phone, '⏳ Transferencia en revisión por el admin (~15 min).', { sendSeen: false });
        }
        // Verificar con MP
        try {
          const url = `https://api.mercadopago.com/v1/payments/search?external_reference=${ref}`;
          const resp = await axios.get(url, { headers: { Authorization: `Bearer ${config.mercadopago.access_token}` }, timeout: 15000 });
          if (resp.data && resp.data.results && resp.data.results[0] && resp.data.results[0].status === 'approved') {
            const username = generateUsername(); const password = generatePassword();
            await createSSHUser(phone, username, password, row.days, 1);
            db.run('UPDATE payments SET status="approved", approved_at=CURRENT_TIMESTAMP WHERE payment_id=?', [ref]);
            return client.sendMessage(phone,
              `✅ Pago aprobado.\n👤 Usuario: *${username}*\n🔑 Pass: *${password}*\n\n   recargas.personal.com.ar:80@${username}:${password}`,
              { sendSeen: false });
          }
          return client.sendMessage(phone, '⏳ Aún no aprobado por MP. Esperá unos minutos.', { sendSeen: false });
        } catch (_) {
          return client.sendMessage(phone, '❌ Error verificando con MP. Intentá en unos minutos.', { sendSeen: false });
        }
      });
      return;
    }

    // ── HWID ──
    if (text.startsWith('hwid')) {
      const hwid = raw.split(/\s+/).slice(1).join(' ').trim();
      if (!hwid) return client.sendMessage(phone, 'Usá: hwid <TU_HARDWARE_ID>', { sendSeen: false });
      db.get('SELECT username FROM users WHERE phone=? ORDER BY id DESC LIMIT 1', [phone], async (err, row) => {
        if (!row) return client.sendMessage(phone, '❌ No tenés usuario asociado.', { sendSeen: false });
        db.run('UPDATE users SET hwid=? WHERE username=?', [hwid, row.username]);
        try {
          const hcDir = '/root/ssh-bot/hc';
          fs.mkdirSync(hcDir, { recursive: true });
          fs.writeFileSync(`${hcDir}/${hwid}.hc`, `HWID=${hwid}\nUSER=${row.username}\n`, 'utf8');
        } catch (_) {}
        return client.sendMessage(phone, `✅ HWID guardado para ${row.username}.`, { sendSeen: false });
      });
      return;
    }

    // ── PRECIOS ──
    if (text === 'precios' || text === '!precios') {
      return client.sendMessage(phone,
        `💲 *PRECIOS* (${cur})\n• Test ${testH}h: $0\n• 7 días: $${p7}\n• 15 días: $${p15}\n• 30 días: $${p30}`,
        { sendSeen: false });
    }

    // ── SESIÓN ACTIVA: flujo compra ──
    const s = sGet(phone);

    if (s.step === 'choose_app') {
      const appMap = { '1': 'apk', '2': 'hc', '3': 'token' };
      const app = appMap[text];
      if (!app) return client.sendMessage(phone,
        '📱 *Elegí tipo de app*:\n\n1) APK\n2) HC (HWID)\n3) Token-Only\n\n(Respondé: 1/2/3)', { sendSeen: false });
      s.app = app;

      // Test: crear directo
      if (s.plan === 'test') {
        if (app === 'token') {
          const t = await createToken(phone, 'test', 0);
          sReset(phone);
          return client.sendMessage(phone, `✅ *Test ${testH}h listo.*\n🔑 Token: ${t.token}\n\n📌 Escribí *menu* para ver opciones.`, { sendSeen: false });
        }
        const u = await createSSHUser(phone, generateUsername(), generatePassword(), 1, 1);
        registerTest(phone);
        sReset(phone);
        return client.sendMessage(phone,
          `✅ *PRUEBA ACTIVADA*\n\n👤 *App Usuario:* ${u.username}\n🔑 *App Contraseña:* ${u.password}\n\n   recargas.personal.com.ar:80@${u.username}:${u.password}\n\n⏰ Duración: ${testH} horas  1 dispositivo`,
          { sendSeen: false });
      }

      // Plan de pago: elegir método
      s.step = 'choose_payment';
      const hint = mpEnabled ? '' : '\n\n⚠️ MercadoPago no configurado, usá *2) Transferencia*.';
      return client.sendMessage(phone,
        `💳 *Método de pago*\n\n1) MercadoPago (tarjeta / saldo)\n2) Transferencia (Alias/CBU)\n\n(Respondé: 1/2)${hint}`,
        { sendSeen: false });
    }

    if (s.step === 'choose_payment') {
      if (text === '1') {
        if (!mpEnabled) return client.sendMessage(phone, '⚠️ MercadoPago no configurado. Elegí *2) Transferencia*.', { sendSeen: false });
        const planDays = { '7d': 7, '15d': 15, '30d': 30 };
        const days = planDays[s.plan] || 7;
        const amount = getPrice(s.plan);
        const payment = await createMercadoPagoPayment(phone, s.plan, days, amount, 1);
        sReset(phone);
        if (payment.success) {
          await client.sendMessage(phone,
            `💳 *PAGO GENERADO*\n\nPlan: *${s.plan}* (${days} días)\nMonto: $${amount} ${cur}\n\n🔗 *ENLACE DE PAGO:*\n${payment.paymentUrl}\n\n⏰ Válido: 24 horas\n🔄 Verificación automática cada 2 min\nTambién podés escribir: *verificar ${payment.paymentId}*`,
            { sendSeen: false });
          if (payment.qrPath && fs.existsSync(payment.qrPath)) {
            const media = MessageMedia.fromFilePath(payment.qrPath);
            await client.sendMessage(phone, media, { caption: '📱 Escanea con la app de MercadoPago', sendSeen: false });
          }
        } else {
          await client.sendMessage(phone, `❌ Error al generar pago: ${payment.error}\n💬 Escribe *13*`, { sendSeen: false });
        }
        return;
      }
      if (text === '2') {
        s.step = 'await_receipt';
        const refPreview = makeTransferRef(phone);
        return client.sendMessage(phone, transferInstructions(refPreview), { sendSeen: false });
      }
      return client.sendMessage(phone, 'Elegí: 1) MercadoPago  2) Transferencia', { sendSeen: false });
    }

    if (s.step === 'await_receipt') {
      if (text === 'cancelar' || text === 'menu') {
        sReset(phone);
        return client.sendMessage(phone, '✅ Cancelado. Escribí *menu* para ver opciones.', { sendSeen: false });
      }
      if (!msg.hasMedia) {
        return client.sendMessage(phone, '📎 Enviá el *comprobante* (foto o PDF).\nO escribí *cancelar* para salir.', { sendSeen: false });
      }
      const ref = makeTransferRef(phone);
      const receipt = await saveReceipt(msg, ref);
      await createTransferPayment({ phone, plan: s.plan, appType: s.app, receiptPath: receipt.path, receiptMime: receipt.mime, amount: getPrice(s.plan) });
      await client.sendMessage(phone, `✅ Comprobante recibido.\n\nRef: *${ref}*\n⏳ Tu pago se procesa en ~15 minutos.`, { sendSeen: false });
      const t = transferCfg();
      if (t.admin) {
        try {
          await client.sendMessage(`${t.admin}@c.us`,
            `🏦 *Nuevo pago por transferencia*\nRef: *${ref}*\nTel: ${normalizePhone(phone)}\nPlan: ${s.plan} | $${getPrice(s.plan)} ${cur}\n\nConfirmar desde panel: sshbot`,
            { sendSeen: false });
          if (receipt.path && fs.existsSync(receipt.path)) {
            const media = MessageMedia.fromFilePath(receipt.path);
            await client.sendMessage(`${t.admin}@c.us`, media, { caption: `Comprobante ${ref}`, sendSeen: false });
          }
        } catch (_) {}
      }
      sReset(phone);
      return;
    }

    // ── MENU / OPCIONES PRINCIPALES ──
    if (['menu', 'hola', 'start', 'hi', 'inicio'].includes(text)) {
      sReset(phone);
      return client.sendMessage(phone,
        `╔══════════════════════════════════╗\n║   🤖 BOT VPS SUPERC4MPEON        ║\n╚══════════════════════════════════╝\n\n📋 *MENÚ:*\n\n🆓 *1* - Prueba GRATIS (${testH}h)\n💰 *2* - Planes premium\n👤 *3* - MIS USUARIOS VPS\n💳 *4* - Estado de pago\n📱 *5* - Descargar APP Satelite_VPS\n✔ *6* Premium 7dias $${p7} ${cur} 6️⃣✔\n✔ *7* Premium 15 dias $${p15} ${cur} 7️⃣✔\n✔ *8* Premium 30 dias $${p30} ${cur} 8️⃣✔\n🆘 *9* - Payload Front\n🆘 *10* - Host Front\n🆘 *11* - Payload Flare\n🆘 *12* - Host Flare\n🆘 *13* - Soporte tecnico\n\n💬 Responde con el Número`,
        { sendSeen: false });
    }

    // ── 1: PRUEBA GRATIS ──
    if (text === '1') {
      if (!(await canCreateTest(phone))) {
        return client.sendMessage(phone, `⚠️ *YA USASTE TU PRUEBA HOY*\n\n⏳ Vuelve mañana\n💎 *Escribe 2* para Ver Premium`, { sendSeen: false });
      }
      await client.sendMessage(phone, '⏳ Creando cuenta test...', { sendSeen: false });
      try {
        const s2 = sGet(phone);
        s2.plan = 'test'; s2.step = 'choose_app';
        return client.sendMessage(phone,
          `📱 *Elegí tipo de app*:\n\n1) APK\n2) HC (HWID)\n3) Token-Only\n\n(Respondé: 1/2/3)`, { sendSeen: false });
      } catch (error) {
        return client.sendMessage(phone, `❌ Error: ${error.message}`, { sendSeen: false });
      }
    }

    // ── 2: PLANES PREMIUM ──
    if (text === '2') {
      return client.sendMessage(phone,
        `💎 *PLANES PREMIUM*\n\n🥉 *7 días* - $${p7} ${cur}\n   1 dispositivo - opcion: *6*\n\n🥈 *15 días* - $${p15} ${cur}\n   1 dispositivo - opcion: *7*\n\n🥇 *30 días* - $${p30} ${cur}\n   1 dispositivo - opcion: *8*\n\n💳 Pago: MercadoPago / Transferencia\n⚡ Activación: 2-5 min\n\nEscribe el comando: *6* *7* *8*`,
        { sendSeen: false });
    }

    // ── 3: MIS USUARIOS ──
    if (text === '3') {
      db.all('SELECT username, password, tipo, expires_at, max_connections FROM users WHERE phone = ? AND status = 1 ORDER BY created_at DESC LIMIT 10', [phone],
        async (err, rows) => {
          if (!rows || rows.length === 0) {
            return client.sendMessage(phone, `📋 *SIN CUENTAS*\n\n🆓 *1* - Prueba gratis\n💰 *2* - Ver Premium`, { sendSeen: false });
          }
          let msgTxt = '📋 *TUS CUENTAS ACTIVAS*\n\n';
          rows.forEach((a) => {
            const tipo = a.tipo === 'premium' ? '💎 PREMIUM' : '🆓 TEST';
            msgTxt += `${tipo}\n👤 *App Usuario:* ${a.username}\n🔑 *App Contraseña:* ${a.password}\n🔌 ${a.max_connections} dispositivos\n   recargas.personal.com.ar:80@${a.username}:${a.password}\n\n`;
          });
          return client.sendMessage(phone, msgTxt, { sendSeen: false });
        });
      return;
    }

    // ── 4: ESTADO PAGO ──
    if (text === '4') {
      db.all('SELECT payment_id, plan, amount, status, created_at, payment_url FROM payments WHERE phone = ? ORDER BY created_at DESC LIMIT 5', [phone],
        async (err, pays) => {
          if (!pays || pays.length === 0) {
            return client.sendMessage(phone, `💳 *SIN PAGOS REGISTRADOS*\n\n*2* - Ver planes disponibles`, { sendSeen: false });
          }
          let msgTxt = '💳 *ESTADO DE PAGOS*\n\n';
          pays.forEach((p, i) => {
            const emoji = p.status === 'approved' ? '✅' : '⏳';
            const statusText = p.status === 'approved' ? 'APROBADO' : p.status === 'pending_admin' ? 'REVISIÓN ADMIN' : 'PENDIENTE';
            msgTxt += `${i + 1}. ${emoji} ${statusText}\nPlan: ${p.plan} | $${p.amount} ${cur}\nFecha: ${moment(p.created_at).format('DD/MM HH:mm')}\n\n`;
          });
          msgTxt += '🔄 Verificación automática cada 2 minutos';
          return client.sendMessage(phone, msgTxt, { sendSeen: false });
        });
      return;
    }

    // ── 5: APK ──
    if (text === '5') {
      const searchPaths = ['/root/app.apk', '/root/ssh-bot/app.apk', '/root/android.apk', '/root/vpn.apk'];
      let apkFound = null; let apkName = 'app.apk';
      for (const fp of searchPaths) { if (fs.existsSync(fp)) { apkFound = fp; apkName = path.basename(fp); break; } }
      if (apkFound) {
        try {
          const fileSize = (fs.statSync(apkFound).size / (1024 * 1024)).toFixed(2);
          await client.sendMessage(phone, `📱 *DESCARGANDO Satelite_VPS*\n\n📦 ${apkName} (${fileSize} MB)\n\n⏳ Enviando archivo, espera...`, { sendSeen: false });
          const media = MessageMedia.fromFilePath(apkFound);
          await client.sendMessage(phone, media, {
            caption: `📱 ${apkName}\n\n1. Toca para instalar\n2. Permite "Fuentes desconocidas"\n3. Abre la app e ingresa tus datos`,
            sendSeen: false
          });
          console.log(chalk.green('✅ APK enviada'));
        } catch (error) {
          console.error(chalk.red('❌ Error APK:'), error.message);
          await client.sendMessage(phone, `❌ Error enviando APK.\n💬 Contacta soporte: *Escribe 13*`, { sendSeen: false });
        }
      } else {
        await client.sendMessage(phone, `❌ *APK NO DISPONIBLE*\nContacta al administrador.\n💬 *Escribe 13*`, { sendSeen: false });
      }
      return;
    }

    // ── 6/7/8: COMPRAR PREMIUM ──
    if (['6', '7', '8', 'comprar7', 'comprar15', 'comprar30'].includes(text)) {
      const planMap = {
        '6': '7d', 'comprar7': '7d',
        '7': '15d', 'comprar15': '15d',
        '8': '30d', 'comprar30': '30d'
      };
      const s2 = sGet(phone);
      s2.plan = planMap[text];
      s2.step = 'choose_app';
      return client.sendMessage(phone,
        `📱 *Elegí tipo de app*:\n\n1) APK\n2) HC (HWID)\n3) Token-Only\n\n(Respondé: 1/2/3)`, { sendSeen: false });
    }

    // ── 9: PAYLOAD FRONT ──
    if (text === '9') {
      return client.sendMessage(phone,
        'GET / HTTP/1.1[crlf]Host: recargas.personal.com.ar[crlf][crlf][split][crlf][crlf]GET- / HTTP/1.1[crlf]Host: recargas.personal.com.ar[lf][lf]GET /app405309 HTTP/1.1[crlf]Host:[rotate= cloudfront-08.centraldacdn.org;cloudfront-06.centraldacdn.org;cloudfront-07.centraldacdn.org][lf]Connection:  Upgrade[lf]Upgrade: websocket[lf]User-Agent: Googltml)[lf][lf]',
        { sendSeen: false });
    }

    // ── 10: HOST FRONT ──
    if (text === '10') {
      return client.sendMessage(phone, 'recargas.personal.com.ar:80@USER:PASS', { sendSeen: false });
    }

    // ── 11: PAYLOAD FLARE ──
    if (text === '11') {
      return client.sendMessage(phone,
        'ACL //  HTTP/1.9[lf]Host: recargas.personal.com.ar[lf]Expect: 911-continue[crlf][crlf][split][crlf][crlf]GET- // HTTP/1.1[crlf]Host: 1.vps204.shop[crlf]Connection: Upgrade[crlf]-_-[crlf]Upgrade: websocket[crlf][crlf]',
        { sendSeen: false });
    }

    // ── 12: HOST FLARE ──
    if (text === '12') {
      return client.sendMessage(phone, 'emailmarketing.personal.com.ar:80@User:Pass', { sendSeen: false });
    }

    // ── 13: SOPORTE ──
    if (text === '13' || text === 'soporte') {
      return client.sendMessage(phone,
        `🆘 *Soporte Tecnico*\n\n📞 Canal de soporte:\n${supportLink}`,
        { sendSeen: false });
    }

    // ── FALLBACK: IA Gemini ──
    const aiReply = await geminiSupportReply(raw);
    if (aiReply) {
      return client.sendMessage(phone, `🤖 *Soporte automático*\n\n${aiReply}`, { sendSeen: false });
    }
    // Si no es comando conocido y está idle, no responde (evita spam)

  } catch (e) {
    console.error(chalk.red('❌ Error en mensaje:'), e.message || e);
  }
});

// ─── CRONS ─────────────────────────────────────────────────────────────────
// Verificar pagos MP cada 2 min
cron.schedule('*/2 * * * *', () => {
  if (mpEnabled) { console.log(chalk.yellow('🔄 Verificando pagos pendientes...')); checkPendingPayments(); }
});

// Limpiar usuarios expirados cada 15 min
cron.schedule('*/15 * * * *', async () => {
  const now = moment().format('YYYY-MM-DD HH:mm:ss');
  db.all('SELECT username FROM users WHERE expires_at < ? AND status = 1', [now], async (err, rows) => {
    if (err || !rows || rows.length === 0) return;
    for (const r of rows) {
      try {
        await execPromise(`pkill -u ${r.username} 2>/dev/null || true`);
        await execPromise(`userdel -f ${r.username} 2>/dev/null || true`);
        db.run('UPDATE users SET status = 0 WHERE username = ?', [r.username]);
        console.log(chalk.green(`🗑️  Expirado: ${r.username}`));
      } catch (_) {}
    }
  });
});

// Limpiar pagos viejos cada 24h
cron.schedule('0 0 * * *', () => {
  db.run('DELETE FROM payments WHERE status = "pending" AND created_at < datetime("now", "-7 days")');
});

console.log(chalk.green('\n🚀 Inicializando bot...\n'));
client.initialize();
BOTEOF


echo -e "${GREEN}✅ Bot creado con todos los fixes${NC}"

# ================================================
# CREAR PANEL CON VALIDACIÓN FIXED (FIX 1)
# ================================================
echo -e "\n${CYAN}${BOLD}🎛️  CREANDO PANEL DE CONTROL CON VALIDACIÓN FIXED...${NC}"


# ================================================
# PANEL ADMIN – descarga panel_admin.sh del repo
# ================================================
echo -e "\n${CYAN}${BOLD}🎛️  Instalando panel admin...${NC}"

PANEL_URL="https://raw.githubusercontent.com/eze1087/bootsshx2/main/panel_admin.sh"
PANEL_PATH="/usr/local/bin/sshbot"

if curl -fsSL "$PANEL_URL" -o "$PANEL_PATH" 2>/dev/null; then
  echo -e "${GREEN}✅ Panel descargado OK${NC}"
elif wget -qO "$PANEL_PATH" "$PANEL_URL" 2>/dev/null; then
  echo -e "${GREEN}✅ Panel descargado OK (wget)${NC}"
else
  echo -e "${RED}❌ ERROR: No se pudo descargar el panel desde: $PANEL_URL${NC}"
  echo -e "${YELLOW}➡️  Verificá que panel_admin.sh esté en tu repo bootsshx2${NC}"
  exit 1
fi

chmod +x "$PANEL_PATH"
hash -r 2>/dev/null || true
echo -e "${GREEN}✅ Panel instalado como: sshbot${NC}"

echo -e "${GREEN}✅ Panel creado con validación fixed${NC}"

# ================================================
# INICIAR BOT
# ================================================
echo -e "\n${CYAN}${BOLD}🚀 INICIANDO BOT...${NC}"

cd "$USER_HOME"
pm2 start bot.js --name ssh-bot
pm2 save
pm2 startup systemd -u root --hp /root > /dev/null 2>&1

sleep 3

# ================================================
# MENSAJE FINAL
# ================================================
clear
echo -e "${GREEN}${BOLD}"
cat << "FINAL"
╔═════════════════════════════════════════  
║                                                                  ║
║         SSH BOT PRO v8.6 - TODOS LOS FIXES APLICADOS  ║
║           💳 MercadoPago SDK v2.x FULLY FIXED              ║
║           🤖 WhatsApp markedUnread parcheado               ║
║           🔑 Validación token corregida                         ║
║           📱 APK Automático + Test 3h                        ║
╚═════════════════════════════════════════╝
FINAL
echo -e "${NC}"

echo -e "${CYAN}═════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Bot instalado con TODOS los fixes aplicados${NC}"
echo -e "${GREEN}✅ Panel de control con validación corregida${NC}"
echo -e "${GREEN}✅ Fechas ISO 8601 corregidas para MP v2.x${NC}"
echo -e "${GREEN}✅ Error WhatsApp Web parcheado (markedUnread)${NC}"
echo -e "${GREEN}✅ Validación de token MP corregida${NC}"
echo -e "${CYAN}═════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 COMANDOS:${NC}\n"
echo -e "  ${GREEN}sshbot${NC}           - Panel de control"
echo -e "  ${GREEN}pm2 logs ssh-bot${NC} - Ver logs"
echo -e "  ${GREEN}pm2 restart ssh-bot${NC} - Reiniciar\n"

echo -e "${YELLOW}🔧 CONFIGURACIÓN:${NC}\n"
echo -e "  1. Ejecuta: ${GREEN}sshbot${NC}"
echo -e "  2. Opción ${CYAN}[8]${NC} - Configurar MercadoPago (ahora acepta tu token)"
echo -e "  3. Opción ${CYAN}[14]${NC} - Test MercadoPago"
echo -e "  4. Opción ${CYAN}[3]${NC} - Escanear QR WhatsApp"
echo -e "  5. Sube APK a /root/app.apk\n"

echo -e "${YELLOW}📊 INFO:${NC}"
echo -e "  IP: ${CYAN}$SERVER_IP${NC}"
echo -e "  BD: ${CYAN}$DB_FILE${NC}"
echo -e "  Config: ${CYAN}$CONFIG_FILE${NC}\n"

echo -e "${CYAN}═════════════════════════════════════${NC}\n"

read -p "$(echo -e "${YELLOW}¿Abrir panel? (s/N): ${NC}")" -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "\n${CYAN}Abriendo panel...${NC}\n"
    sleep 2
    /usr/local/bin/sshbot
else
    echo -e "\n${YELLOW}💡 Ejecuta: ${GREEN}sshbot${NC}\n"
    echo -e "${RED}⚠️  Recuerda configurar MercadoPago (opción 8)${NC}\n"
fi

echo -e "${GREEN}${BOLD}¡Instalación exitosa con todos los fixes! 🚀${NC}\n"
