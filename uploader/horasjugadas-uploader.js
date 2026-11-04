#!/usr/bin/env node
// Horas Jugadas - Uploader
//
// Lee el archivo SavedVariables del addon (WTF\Account\<CUENTA>\SavedVariables\HorasJugadas.lua)
// y sube tus horas y muertes a Supabase cada vez que cambia (WoW lo escribe al salir o con /reload).
//
// Uso:
//   horasjugadas-uploader                 vigila y sube automáticamente (déjalo abierto)
//   horasjugadas-uploader --once          sube una vez y termina
//   horasjugadas-uploader --dry-run       muestra lo que subiría, sin subir nada
//   horasjugadas-uploader --force         sube aunque no haya cambios
//   horasjugadas-uploader --instalar-inicio   arrancar oculto al iniciar Windows
//   horasjugadas-uploader --quitar-inicio     quitar del inicio de Windows
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');

const VERSION = '1.1.0';
const POLL_MS = 30_000;
const SV_FILE = 'HorasJugadas.lua';

function isSea() {
    try { return require('node:sea').isSea(); } catch { return false; }
}

const BASE_DIR = isSea() ? path.dirname(process.execPath) : __dirname;
const DATA_DIR = path.join(process.env.APPDATA || path.join(os.homedir(), '.config'), 'HorasJugadas');
const STATE_FILE = path.join(DATA_DIR, 'estado.json');
const LOG_FILE = path.join(DATA_DIR, 'uploader.log');

// ---------------------------------------------------------------------------
// Log
// ---------------------------------------------------------------------------
function log(...args) {
    const line = `[${new Date().toLocaleString('es-ES')}] ${args.join(' ')}`;
    console.log(line);
    try {
        fs.mkdirSync(DATA_DIR, { recursive: true });
        if (fs.existsSync(LOG_FILE) && fs.statSync(LOG_FILE).size > 1_000_000) fs.writeFileSync(LOG_FILE, '');
        fs.appendFileSync(LOG_FILE, line + '\n');
    } catch { /* sin log en disco, no pasa nada */ }
}

// ---------------------------------------------------------------------------
// Configuración y estado
// ---------------------------------------------------------------------------
function loadConfig() {
    const file = path.join(BASE_DIR, 'config.json');
    let cfg = {};
    if (fs.existsSync(file)) {
        try {
            cfg = JSON.parse(fs.readFileSync(file, 'utf8'));
        } catch (e) {
            throw new Error(`config.json no es un JSON válido: ${e.message}`);
        }
    }
    cfg.supabaseUrl = (process.env.HJ_SUPABASE_URL || cfg.supabaseUrl || '').replace(/\/+$/, '');
    cfg.supabaseKey = process.env.HJ_SUPABASE_KEY || cfg.supabaseKey || '';
    cfg.wowPath = process.env.HJ_WOW_PATH || cfg.wowPath || '';
    cfg.file = file;
    return cfg;
}

function checkConfig(cfg) {
    const bad = (v) => !v || /TU-PROYECTO|TU_CLAVE/i.test(v);
    if (bad(cfg.supabaseUrl) || bad(cfg.supabaseKey)) {
        throw new Error(
            `Falta configurar Supabase. Edita ${cfg.file} con "supabaseUrl" y "supabaseKey" ` +
            `(Supabase > Project Settings > API).`);
    }
}

function loadState() {
    let state = {};
    try { state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8')); } catch { /* primera vez */ }
    if (!state.token) {
        state.token = crypto.randomBytes(32).toString('hex');
        saveState(state);
        log('Token personal creado en', STATE_FILE, '(no lo compartas; si lo pierdes, pide al admin que libere tu apodo)');
    }
    return state;
}

function saveState(state) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
    fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

// ---------------------------------------------------------------------------
// Parser del formato SavedVariables de WoW (subconjunto de Lua)
// ---------------------------------------------------------------------------
class LuaParser {
    constructor(src) {
        this.s = src;
        this.i = 0;
    }

    error(msg) {
        const line = this.s.slice(0, this.i).split('\n').length;
        return new Error(`SavedVariables línea ${line}: ${msg}`);
    }

    eof() { return this.i >= this.s.length; }

    skipWs() {
        const s = this.s;
        while (this.i < s.length) {
            const c = s[this.i];
            if (c === ' ' || c === '\t' || c === '\r' || c === '\n') {
                this.i++;
            } else if (c === '-' && s[this.i + 1] === '-') {
                if (s.startsWith('[[', this.i + 2)) {
                    const end = s.indexOf(']]', this.i + 4);
                    this.i = end < 0 ? s.length : end + 2;
                } else {
                    const end = s.indexOf('\n', this.i);
                    this.i = end < 0 ? s.length : end + 1;
                }
            } else {
                break;
            }
        }
    }

    expect(ch) {
        this.skipWs();
        if (this.s[this.i] !== ch) throw this.error(`se esperaba '${ch}' y hay '${this.s[this.i] ?? 'EOF'}'`);
        this.i++;
    }

    match(re) {
        re.lastIndex = this.i;
        const m = re.exec(this.s);
        if (!m) return null;
        this.i = re.lastIndex;
        return m[0];
    }

    readIdent() {
        const id = this.match(/[A-Za-z_][A-Za-z0-9_]*/y);
        if (!id) throw this.error('se esperaba un nombre');
        return id;
    }

    readValue() {
        this.skipWs();
        const c = this.s[this.i];
        if (c === '{') return this.readTable();
        if (c === '"' || c === "'") return this.readString();
        const num = this.match(/-?(?:0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/y);
        if (num !== null) return Number(num);
        const id = this.match(/[A-Za-z_][A-Za-z0-9_]*/y);
        if (id === 'true') return true;
        if (id === 'false') return false;
        if (id === 'nil') return null;
        if (id === 'inf') return Infinity;
        throw this.error(`valor inesperado '${id ?? c}'`);
    }

    readString() {
        const q = this.s[this.i++];
        let out = '';
        while (true) {
            if (this.eof()) throw this.error('cadena sin cerrar');
            const c = this.s[this.i++];
            if (c === q) break;
            if (c !== '\\') { out += c; continue; }
            const e = this.s[this.i++];
            const map = { n: '\n', t: '\t', r: '\r', a: '\x07', b: '\b', f: '\f', v: '\v', '\\': '\\', '"': '"', "'": "'", '\n': '\n' };
            if (e in map) {
                out += map[e];
            } else if (/\d/.test(e)) {
                let digits = e;
                while (digits.length < 3 && /\d/.test(this.s[this.i])) digits += this.s[this.i++];
                out += String.fromCharCode(Number(digits));
            } else {
                out += e;
            }
        }
        // El archivo se lee byte a byte (latin1); WoW guarda UTF-8, así que se decodifica aquí.
        return Buffer.from(out, 'latin1').toString('utf8');
    }

    readTable() {
        this.expect('{');
        const obj = {};
        let arrayIndex = 1;
        while (true) {
            this.skipWs();
            if (this.s[this.i] === '}') { this.i++; break; }
            let key;
            if (this.s[this.i] === '[') {
                this.i++;
                key = this.readValue();
                this.expect(']');
                this.expect('=');
            } else {
                const save = this.i;
                const id = this.match(/[A-Za-z_][A-Za-z0-9_]*/y);
                this.skipWs();
                if (id && this.s[this.i] === '=' && this.s[this.i + 1] !== '=') {
                    this.i++;
                    key = id;
                } else {
                    this.i = save;
                    key = arrayIndex++;
                }
            }
            obj[key] = this.readValue();
            this.skipWs();
            if (this.s[this.i] === ',' || this.s[this.i] === ';') this.i++;
        }
        return obj;
    }

    readFile() {
        const result = {};
        while (true) {
            this.skipWs();
            if (this.eof()) break;
            const name = this.readIdent();
            this.expect('=');
            result[name] = this.readValue();
        }
        return result;
    }
}

// `data`: Buffer con el contenido del archivo (o string ya en latin1).
function parseSavedVariables(data) {
    let text = Buffer.isBuffer(data) ? data.toString('latin1') : data;
    if (text.startsWith('\xef\xbb\xbf')) text = text.slice(3); // BOM UTF-8
    return new LuaParser(text).readFile();
}

// ---------------------------------------------------------------------------
// Localizar WoW y los archivos del addon
// ---------------------------------------------------------------------------
function registryInstallPath() {
    if (process.platform !== 'win32') return [];
    const keys = [
        'HKLM\\SOFTWARE\\WOW6432Node\\Blizzard Entertainment\\World of Warcraft',
        'HKLM\\SOFTWARE\\Blizzard Entertainment\\World of Warcraft',
    ];
    const found = [];
    for (const key of keys) {
        try {
            const out = execFileSync('reg', ['query', key, '/v', 'InstallPath'],
                { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], windowsHide: true });
            const m = out.match(/InstallPath\s+REG_SZ\s+(.+)/);
            if (m) found.push(m[1].trim());
        } catch { /* clave no existe */ }
    }
    return found;
}

function wowCandidates(cfg) {
    const list = [];
    const add = (p) => { list.push(p, path.join(p, '_retail_')); };
    if (cfg.wowPath) add(cfg.wowPath);
    registryInstallPath().forEach(add);
    if (process.platform === 'win32') {
        const dirs = ['Program Files (x86)\\World of Warcraft', 'Program Files\\World of Warcraft',
            'World of Warcraft', 'Games\\World of Warcraft', 'Juegos\\World of Warcraft',
            'Battle.net\\World of Warcraft', 'Blizzard\\World of Warcraft'];
        for (const d of 'CDEFGH') for (const p of dirs) list.push(`${d}:\\${p}\\_retail_`);
    } else if (process.platform === 'darwin') {
        list.push('/Applications/World of Warcraft/_retail_');
    }
    return list;
}

function findRetail(cfg) {
    for (const c of wowCandidates(cfg)) {
        if (fs.existsSync(path.join(c, 'WTF', 'Account'))) return c;
    }
    return null;
}

function findSavedVariables(retail) {
    const accountsDir = path.join(retail, 'WTF', 'Account');
    const files = [];
    for (const ent of fs.readdirSync(accountsDir, { withFileTypes: true })) {
        if (!ent.isDirectory() || ent.name === 'SavedVariables') continue;
        const f = path.join(accountsDir, ent.name, 'SavedVariables', SV_FILE);
        if (fs.existsSync(f)) files.push(f);
    }
    return files;
}

// ---------------------------------------------------------------------------
// Preparar los datos a subir (solo tus datos, no los de otros que el addon haya sincronizado)
// ---------------------------------------------------------------------------
function buildPayloads(files) {
    const byNick = new Map();
    for (const file of files) {
        const db = parseSavedVariables(fs.readFileSync(file)).HorasJugadasDB;
        if (!db || !db.nick || !db.players) continue;
        const me = db.players[db.nick];
        if (!me) continue;

        let agg = byNick.get(db.nick);
        if (!agg) {
            agg = { nick: db.nick, days: {}, chars: new Map() };
            byNick.set(db.nick, agg);
        }
        // Varias cuentas de WoW con el mismo apodo: se suman los días
        for (const [day, sec] of Object.entries(me.days || {})) {
            if (/^\d{4}-\d{2}-\d{2}$/.test(day) && Number.isFinite(Number(sec))) {
                agg.days[day] = (agg.days[day] || 0) + Number(sec);
            }
        }
        for (const [key, c] of Object.entries(me.chars || {})) {
            const prev = agg.chars.get(key);
            if (!prev || (c.last || 0) > (prev.last || 0)) agg.chars.set(key, c);
        }
    }

    return [...byNick.values()].map((agg) => ({
        p_nick: agg.nick,
        p_days: Object.fromEntries(
            Object.entries(agg.days).sort().map(([d, s]) => [d, Math.min(86400, Math.round(s))])),
        p_chars: [...agg.chars.entries()].sort().map(([key, c]) => ({
            char_key: key,
            class: c.class || '',
            level: Number.isFinite(c.level) ? c.level : null,
            played_seconds: Math.round(c.played || 0),
            deaths: Math.max(0, Math.round(Number(c.deaths) || 0)),
            last_seen: Math.round(c.last || 0),
        })),
    }));
}

function hours(sec) { return (sec / 3600).toFixed(1) + 'h'; }

// ---------------------------------------------------------------------------
// Supabase
// ---------------------------------------------------------------------------
async function upload(cfg, payload) {
    const headers = { apikey: cfg.supabaseKey, 'Content-Type': 'application/json' };
    // Las claves antiguas (JWT) también van en Authorization; las nuevas "sb_publishable_" no.
    if (!cfg.supabaseKey.startsWith('sb_')) headers.Authorization = `Bearer ${cfg.supabaseKey}`;

    const res = await fetch(`${cfg.supabaseUrl}/rest/v1/rpc/upload_play_data`, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
    });
    if (!res.ok) {
        let msg = await res.text();
        try { msg = JSON.parse(msg).message || msg; } catch { /* texto plano */ }
        throw new Error(`Supabase respondió ${res.status}: ${msg}`);
    }
}

// ---------------------------------------------------------------------------
// Ejecución
// ---------------------------------------------------------------------------
async function runOnce(cfg, state, { force = false, dryRun = false } = {}) {
    const retail = findRetail(cfg);
    if (!retail) {
        log('No encuentro World of Warcraft. Pon la ruta en config.json, por ejemplo:',
            '"wowPath": "D:\\\\Juegos\\\\World of Warcraft"');
        return false;
    }
    const files = findSavedVariables(retail);
    if (files.length === 0) {
        log(`No hay datos todavía en ${retail}. Entra al juego con el addon y sal (o haz /reload).`);
        return false;
    }

    const payloads = buildPayloads(files);
    if (payloads.length === 0) {
        log('El archivo del addon no tiene datos tuyos aún.');
        return false;
    }

    const hash = crypto.createHash('sha256').update(JSON.stringify(payloads)).digest('hex');
    if (!force && !dryRun && hash === state.lastHash) return true;

    for (const p of payloads) {
        const total = Object.values(p.p_days).reduce((a, b) => a + b, 0);
        const deaths = p.p_chars.reduce((sum, c) => sum + c.deaths, 0);
        const summary = `${p.p_nick}: ${Object.keys(p.p_days).length} días (${hours(total)}), ` +
            `${p.p_chars.length} personajes, ${deaths} muertes`;
        if (dryRun) {
            log('[prueba]', summary);
            console.log(JSON.stringify(p, null, 2));
            continue;
        }
        await upload(cfg, { ...p, p_token: state.token });
        log('Subido ->', summary);
    }
    if (!dryRun) {
        state.lastHash = hash;
        state.lastUpload = new Date().toISOString();
        saveState(state);
    }
    return true;
}

function fileSignature(cfg) {
    const retail = findRetail(cfg);
    if (!retail) return '';
    return findSavedVariables(retail)
        .map((f) => `${f}:${fs.statSync(f).mtimeMs}`)
        .join('|');
}

async function watch(cfg, state) {
    log(`Horas Jugadas uploader v${VERSION}: vigilando cambios cada ${POLL_MS / 1000}s. Ctrl+C para salir.`);
    let lastSig = null;
    const tick = async () => {
        try {
            const sig = fileSignature(cfg);
            if (sig !== lastSig) {
                // Esperar a que WoW termine de escribir el archivo
                const newest = Math.max(0, ...sig.split('|').map((s) => Number(s.split(':').pop()) || 0));
                if (Date.now() - newest < 3000) return;
                await runOnce(cfg, state);
                lastSig = sig;
            }
        } catch (e) {
            log('Error:', e.message, '(se reintentará)');
        }
    };
    await tick();
    setInterval(tick, POLL_MS);
}

// ---------------------------------------------------------------------------
// Inicio automático con Windows
// ---------------------------------------------------------------------------
function startupFile() {
    return path.join(process.env.APPDATA || '', 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup',
        'HorasJugadasUploader.vbs');
}

function installStartup() {
    if (process.platform !== 'win32') throw new Error('Solo disponible en Windows.');
    const cmd = isSea() ? `"${process.execPath}"` : `"${process.execPath}" "${__filename}"`;
    const vbs = `CreateObject("WScript.Shell").Run "${cmd.replace(/"/g, '""')}", 0, False\r\n`;
    fs.writeFileSync(startupFile(), vbs);
    log('Instalado: se iniciará oculto con Windows. Log en', LOG_FILE);
}

function removeStartup() {
    if (fs.existsSync(startupFile())) fs.unlinkSync(startupFile());
    log('Quitado del inicio de Windows.');
}

// ---------------------------------------------------------------------------
async function main() {
    const args = new Set(process.argv.slice(2));
    if (args.has('--ayuda') || args.has('--help') || args.has('-h')) {
        console.log(`Horas Jugadas uploader v${VERSION}

  (sin opciones)       vigila y sube automáticamente
  --once               sube una vez y termina
  --dry-run            muestra lo que subiría, sin subir nada
  --force              sube aunque no haya cambios
  --instalar-inicio    arrancar oculto al iniciar Windows
  --quitar-inicio      quitar del inicio de Windows

Config:  ${path.join(BASE_DIR, 'config.json')}
Estado:  ${STATE_FILE}
Log:     ${LOG_FILE}`);
        return;
    }
    if (args.has('--instalar-inicio')) return installStartup();
    if (args.has('--quitar-inicio')) return removeStartup();

    const cfg = loadConfig();
    const dryRun = args.has('--dry-run');
    if (!dryRun) checkConfig(cfg);
    const state = loadState();

    if (dryRun || args.has('--once')) {
        await runOnce(cfg, state, { force: args.has('--force'), dryRun });
    } else {
        if (args.has('--force')) await runOnce(cfg, state, { force: true });
        await watch(cfg, state);
    }
}

if (require.main === module || isSea()) {
    main().catch((e) => {
        log('Error:', e.message);
        process.exitCode = 1;
    });
}

module.exports = { parseSavedVariables, buildPayloads };
