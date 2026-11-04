// Pruebas del parser de SavedVariables:  node test.js
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { parseSavedVariables, buildPayloads } = require('./horasjugadas-uploader.js');

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
} finally {
    fs.rmSync(tmp, { recursive: true, force: true });
}

console.log('OK: todas las pruebas pasan');
