import assert from 'node:assert/strict';
import {crearRpc} from '../frontend/js/lib/rpc.js';
let calls=0,last;
const rpc=crearRpc(20,()=>({rpc(nombre,datos){calls++;last={nombre,datos};return {abortSignal:signal=>new Promise((resolve,reject)=>{if(nombre==='lenta')signal.addEventListener('abort',()=>reject(signal.reason));else resolve(nombre==='error'?{error:conflict}:{data:{ok:true}});})};}}));
const conflict={code:'40001',message:'Conflicto'};
assert.deepEqual(await rpc('panel'),{ok:true});assert.deepEqual(last,{nombre:'panel',datos:{}});
await assert.rejects(rpc('error',{version:1}),e=>e===conflict);assert.equal(calls,2);
const alive=setTimeout(()=>{},100);await assert.rejects(rpc('lenta'),e=>e.name==='TimeoutError');clearTimeout(alive);
console.log('RPC OK: datos, error original, timeout y sin reintento automático.');
