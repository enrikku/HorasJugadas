// Pruebas del parser de SavedVariables:  node test.js
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { parseSavedVariables, buildPayloads, findRetail, linuxWowRoots, systemdUnit } = require('./horasjugadas-uploader.js');

const utf8 = (s) => Buffer.from(s, 'utf8');

// Cadenas UTF-8 tal cual (como las escribe WoW)
let r = parseSavedVariables(utf8('DB = {\n["nick"] = "Enríc",\n["Thrallín-Sanguino"] = 1,\n}\n'));
assert.equal(r.DB.nick, 'Enríc');
assert.equal(r.DB['Thrallín-Sanguino'], 1);

// Escapes de Lua: \" \\ \n y bytes \ddd (í = \195\173)
r = parseSavedVariables(utf8(String.raw`X = { "a\"b\\c", "l1\nl2", ["a\195\173b"] = 2 }`));
assert.equal(r.X[1], 'a"b\\c');
assert.equal(r.X[2], 'l1\nl2');
assert.equal(r.X['aíb'], 2);

// Arrays con comentarios "-- [n]", números, booleanos, nil, claves sin corchetes
r = parseSavedVariables(utf8('T = {\n1.5, -- [1]\n-2.5e3, -- [2]\ntrue, -- [3]\n}\nU = { y = false, z = nil, [10] = 0x1F }\n'));
assert.deepEqual(r.T, { 1: 1.5, 2: -2500, 3: true });
assert.deepEqual(r.U, { y: false, z: null, 10: 31 });

// BOM al principio
r = parseSavedVariables(Buffer.concat([Buffer.from([0xef, 0xbb, 0xbf]), utf8('A = 1')]));
assert.equal(r.A, 1);

// Archivo a medio escribir => error (el uploader reintenta)
assert.throws(() => parseSavedVariables(utf8('DB = { ["a"] = ')));

// La estadística de muertes viaja desde cada personaje hasta el payload.
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'horasjugadas-'));
try {
    const file = path.join(tmp, 'HorasJugadas.lua');
    fs.writeFileSync(file, 'HorasJugadasDB = { nick = "Ana", players = { ["Ana"] = { days = {}, chars = { ["Luna-Reino"] = { played = 7200, deaths = 7, class = "MAGE", level = 80, last = 123 } } } } }');
    const payload = buildPayloads([file])[0];
    assert.equal(payload.p_chars[0].deaths, 7);

    // Los duplicados con el reino con espacios (addon anterior a 1.1.1) no se suben.
    fs.writeFileSync(file, 'HorasJugadasDB = { nick = "Ana", players = { ["Ana"] = { days = {}, chars = { ["Luna-ReinoDos"] = { played = 7200, class = "MAGE", level = 80, last = 123 }, ["Luna-Reino Dos"] = { played = 56, last = 124 } } } } }');
    const deduped = buildPayloads([file])[0];
    assert.deepEqual(deduped.p_chars.map((c) => c.char_key), ['Luna-ReinoDos']);

    // Rutas de WoW en Linux: Lutris, Bottles, Steam/Proton y bibliotecas de Steam en otros discos.
    const home = path.join(tmp, 'home');
    const otherLib = path.join(tmp, 'otro-disco');
    const steam = path.join(home, '.local', 'share', 'Steam', 'steamapps');
    fs.mkdirSync(path.join(home, 'Games', 'battlenet'), { recursive: true });
    fs.mkdirSync(path.join(home, '.local', 'share', 'bottles', 'bottles', 'wow'), { recursive: true });
    fs.mkdirSync(path.join(steam, 'compatdata', '111'), { recursive: true });
    fs.mkdirSync(path.join(otherLib, 'steamapps', 'compatdata', '222'), { recursive: true });
    fs.writeFileSync(path.join(steam, 'libraryfolders.vdf'), `"libraryfolders" { "1" { "path"\t\t"${otherLib}" } }`);
    const roots = linuxWowRoots(home);
    const pf = path.join('drive_c', 'Program Files (x86)', 'World of Warcraft');
    for (const expected of [
        path.join(home, '.wine', pf),
        path.join(home, 'Games', 'battlenet', pf),
        path.join(home, '.local', 'share', 'bottles', 'bottles', 'wow', pf),
        path.join(steam, 'compatdata', '111', 'pfx', pf),
        path.join(otherLib, 'steamapps', 'compatdata', '222', 'pfx', pf),
    ]) assert.ok(roots.includes(expected), `falta ${expected}`);

    // Con varias instalaciones gana la que tiene datos del addon, aunque vaya después.
    const wow = path.join(tmp, 'wow');
    fs.mkdirSync(path.join(wow, '_retail_', 'WTF', 'Account', 'A', 'SavedVariables'), { recursive: true });
    assert.equal(findRetail({ wowPath: wow }), path.join(wow, '_retail_'));
    const sv = path.join(wow, '_forever_', 'WTF', 'Account', 'A', 'SavedVariables');
    fs.mkdirSync(sv, { recursive: true });
    fs.writeFileSync(path.join(sv, 'HorasJugadas.lua'), 'HorasJugadasDB = {}');
    assert.equal(findRetail({ wowPath: wow }), path.join(wow, '_forever_'));
} finally {
    fs.rmSync(tmp, { recursive: true, force: true });
}

// El servicio de systemd admite rutas con espacios y caracteres especiales.
assert.match(systemdUnit(['/usr/bin/node', '/home/a b/100%/$x.js']),
    /^ExecStart="\/usr\/bin\/node" "\/home\/a b\/100%%\/\$\$x\.js"$/m);

console.log('OK: todas las pruebas pasan');
