import {existsSync,readFileSync} from 'node:fs';
import {spawn} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import {javaExecutable,build} from './build-windows.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');process.chdir(root);
// The local demo reads only the optional AI settings from .env (Docker Compose passes the whole
// file). A variable already set in the shell wins. Values are never printed.
function localEnv(){
  const env={...process.env};
  if(!existsSync('.env'))return env;
  for(const line of readFileSync('.env','utf8').split(/\r?\n/)){
    const match=line.match(/^\s*(GEMINI_API_KEY|GEMINI_MODEL)\s*=\s*(.*?)\s*$/);
    if(match&&match[2]&&!env[match[1]])env[match[1]]=match[2].replace(/^(['"])(.*)\1$/,'$2');
  }
  return env;
}
try{
  const java=await javaExecutable();
  const packaged=existsSync('dist/study-arena.jar');
  if(!packaged&&!existsSync('build/classes/ph/edu/wit/studyarena/Main.class'))await build();
  const args=packaged?['-Xmx256m','-jar','dist/study-arena.jar','--demo']:['-Xmx256m','-cp',`build/classes${path.delimiter}.deps/*`,'ph.edu.wit.studyarena.Main','--demo'];
  const child=spawn(java,args,{cwd:root,env:localEnv(),stdio:['inherit','pipe','inherit']});let opened=false;
  child.stdout.on('data',data=>{process.stdout.write(data);if(!opened&&data.toString().includes('Study Arena ready')){opened=true;spawn('cmd.exe',['/c','start','',`http://localhost:${process.env.PORT||8080}`],{windowsHide:true,stdio:'ignore'}).on('error',()=>{});}});
  child.on('error',e=>{console.error('Cannot start Java: '+e.message);process.exitCode=1;});
  child.on('exit',code=>{process.exitCode=code??1;});
  process.on('SIGINT',()=>child.kill());
}catch(e){console.error(e.message);process.exitCode=1;}
