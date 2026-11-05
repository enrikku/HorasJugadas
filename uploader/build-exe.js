// Genera dist/HorasJugadasUploader.exe (Node "Single Executable Application").
// Tus amigos no necesitan instalar Node: les pasas la carpeta dist/ entera (exe + config.json).
//   node build-exe.js
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, execSync } = require('node:child_process');

const dir = __dirname;
const dist = path.join(dir, 'dist');
const exeName = process.platform === 'win32' ? 'HorasJugadasUploader.exe' : 'HorasJugadasUploader';
const exe = path.join(dist, exeName);
const blob = path.join(dist, 'sea-prep.blob');
const seaConfig = path.join(dist, 'sea-config.json');

fs.mkdirSync(dist, { recursive: true });
fs.writeFileSync(seaConfig, JSON.stringify({
    main: path.join(dir, 'horasjugadas-uploader.js'),
    output: blob,
    disableExperimentalSEAWarning: true,
}));

console.log('1/3 Generando blob...');
execFileSync(process.execPath, ['--experimental-sea-config', seaConfig], { stdio: 'inherit' });

console.log('2/3 Copiando node...');
fs.copyFileSync(process.execPath, exe);

console.log('3/3 Inyectando el programa en el ejecutable...');
const args = ['--yes', 'postject@1.0.0-alpha.6', exe, 'NODE_SEA_BLOB', blob,
    '--sentinel-fuse', 'NODE_SEA_FUSE_fce680ab2cc467b6e072b8b5df1996b2'];
if (process.platform === 'darwin') args.push('--macho-segment-name', 'NODE_SEA');
// "npx" sin comillas: en Windows, cmd resuelve mal la ruta de npx.cmd si va entrecomillado.
execSync(['npx', ...args.map((a) => `"${a}"`)].join(' '), { stdio: 'inherit' });

fs.rmSync(blob);
fs.rmSync(seaConfig);

const cfg = path.join(dir, 'config.json');
fs.copyFileSync(fs.existsSync(cfg) ? cfg : path.join(dir, 'config.example.json'), path.join(dist, 'config.json'));

// Para quien juega en Linux: el .exe no le sirve, usa el script con Node.
fs.copyFileSync(path.join(dir, 'horasjugadas-uploader.js'), path.join(dist, 'horasjugadas-uploader.js'));

console.log(`\nListo: ${exe}`);
console.log('Reparte la carpeta dist/ entera (.exe, script para Linux y config.json).');
