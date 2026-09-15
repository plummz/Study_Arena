from pathlib import Path
import zipfile,json,hashlib
root=Path(__file__).resolve().parents[1]
out=root/'dist';out.mkdir(exist_ok=True)
jar=out/'study-arena.jar';services={};seen=set()
with zipfile.ZipFile(jar,'w',zipfile.ZIP_DEFLATED) as z:
 z.writestr('META-INF/MANIFEST.MF','Manifest-Version: 1.0\r\nMain-Class: ph.edu.wit.studyarena.Main\r\n\r\n');seen.add('META-INF/MANIFEST.MF')
 for dep in sorted((root/'.deps').glob('*.jar')):
  if dep.name=='ecj.jar':continue
  with zipfile.ZipFile(dep) as source:
   for entry in source.infolist():
    n=entry.filename
    if entry.is_dir() or n.upper().endswith(('.SF','.DSA','.RSA')) or n=='META-INF/MANIFEST.MF' or n.endswith('module-info.class'):continue
    data=source.read(n)
    if n.startswith('META-INF/services/'):
     services.setdefault(n,set()).update(data.decode().splitlines());continue
    if 'LICENSE' in n.upper() or 'NOTICE' in n.upper():
     z.writestr('META-INF/dependency-notices/'+dep.stem+'/'+n.replace('/','_'),data)
    if n not in seen:z.writestr(n,data);seen.add(n)
 for n,rows in services.items():z.writestr(n,'\n'.join(sorted(rows))+'\n')
 for p in sorted((root/'build/classes').rglob('*')):
  if p.is_file():z.write(p,p.relative_to(root/'build/classes').as_posix())
metadata={'java':'17','entrypoint':'ph.edu.wit.studyarena.Main','jar_sha256':hashlib.sha256(jar.read_bytes()).hexdigest(),'dependencies':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((root/'.deps').glob('*.jar')) if p.name!='ecj.jar'}}
(out/'build-manifest.json').write_text(json.dumps(metadata,indent=2))
print('Built executable JAR:',jar.stat().st_size,'bytes')
