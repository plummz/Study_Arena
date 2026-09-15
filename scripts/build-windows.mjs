import {existsSync} from 'node:fs';
import {mkdir,readdir,readFile,writeFile,copyFile,rename} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
export async function javaExecutable(){
  if(process.env.JAVA_BIN)return process.env.JAVA_BIN;
  const dir=path.join(root,'runtime','java');
  if(existsSync(dir))for(const name of await readdir(dir)){const bin=path.join(dir,name,'bin','java.exe');if(existsSync(bin))return bin;}
  return 'java';
}
export function run(command,args){return new Promise((resolve,reject)=>{const p=spawn(command,args,{cwd:root,stdio:'inherit',windowsHide:true});p.on('error',reject);p.on('exit',code=>code===0?resolve():reject(new Error(command+' exited with '+code)));});}
export async function build(){
  const java=await javaExecutable();
  const javac=java==='java'?'javac':path.join(path.dirname(java),'javac.exe');
  await mkdir(path.join(root,'.deps'),{recursive:true});await mkdir(path.join(root,'build','classes'),{recursive:true});
  const lock=JSON.parse(await readFile(path.join(root,'dist','build-manifest.json'),'utf8'));
  const deps=[['sqlite-jdbc','org/xerial/sqlite-jdbc','3.53.4.0'],['jackson-databind','com/fasterxml/jackson/core/jackson-databind','2.19.2'],['jackson-core','com/fasterxml/jackson/core/jackson-core','2.19.2'],['jackson-annotations','com/fasterxml/jackson/core/jackson-annotations','2.19.2'],['slf4j-api','org/slf4j/slf4j-api','2.0.17'],['slf4j-nop','org/slf4j/slf4j-nop','2.0.17']];
  for(const [name,group,version] of deps){
    const file=path.join(root,'.deps',name+'.jar');const expected=lock.dependencies[name+'.jar'];
    if(existsSync(file)&&createHash('sha256').update(await readFile(file)).digest('hex')===expected)continue;
    const response=await fetch(`https://repo.maven.apache.org/maven2/${group}/${version}/${name}-${version}.jar`,{signal:AbortSignal.timeout(180000)});
    if(!response.ok)throw new Error('Dependency download failed: '+name);
    const bytes=Buffer.from(await response.arrayBuffer());
    if(createHash('sha256').update(bytes).digest('hex')!==expected)throw new Error('Dependency checksum mismatch: '+name);
    await writeFile(file+'.part',bytes);await rename(file+'.part',file);console.log('Verified '+name);
  }
  const src=path.join(root,'server','src','main','java','ph','edu','wit','studyarena');
  await run(javac,['--release','17','-encoding','UTF-8','-cp',path.join(root,'.deps','*'),'-d',path.join(root,'build','classes'),...(await readdir(src)).filter(n=>n.endsWith('.java')).map(n=>path.join(src,n))]);
  await copyFile(path.join(root,'server','src','main','resources','schema.sql'),path.join(root,'build','classes','schema.sql'));
  console.log('Study Arena compiled successfully.');
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url))await build();
