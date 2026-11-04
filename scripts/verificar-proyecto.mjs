import {readdirSync,readFileSync,existsSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {execFileSync} from 'node:child_process';
const files=dir=>readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(dir+'/'+e.name):[dir+'/'+e.name]);
const js=files('frontend/js').filter(f=>f.endsWith('.js'));
for(const file of js){execFileSync(process.execPath,['--check',file]);const code=readFileSync(file,'utf8');for(const m of code.matchAll(/(?:from\s*|import\s*)['"](\.[^'"]+)['"]/g)){if(!existsSync(resolve(dirname(file),m[1])))throw new Error(`${file}: import inexistente ${m[1]}`);}}
const html=readFileSync('frontend/index.html','utf8');for(const m of html.matchAll(/(?:src|href)="([^"#]+)"/g)){if(/^(https?:|data:|mailto:)/.test(m[1]))continue;if(!existsSync(resolve('frontend',m[1])))throw new Error('Asset inexistente: '+m[1]);}
const sw=readFileSync('frontend/sw.js','utf8'),assets=JSON.parse(sw.match(/const ASSETS=(\[[^;]+\]);/)[1]);for(const a of assets)if(!existsSync(resolve('frontend',a)))throw new Error('Cache inexistente: '+a);
console.log(`Imports/sintaxis OK: ${js.length} módulos; HTML y ${assets.length} assets PWA.`);
