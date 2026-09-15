import fs from 'node:fs/promises';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
// Packaging is delegated to the included Python zip helper for deterministic ZIP/JAR assembly.
const result=spawnSync(process.env.PYTHON || 'python',['scripts/package.py'],{stdio:'inherit'});
if(result.status!==0)process.exit(result.status || 1);
