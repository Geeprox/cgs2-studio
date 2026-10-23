#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Build the complete version-pinned native patch locally, without device access."""
import argparse,hashlib,json,os,shutil,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'native'))
from resources import prepare,ORIGINAL
FINAL='91e0fc422f77f70e024bf9571a5bc395849eaeeb21c7c2a3c3973a49d8d7d8b7'

def build(source,out):
    if not __debug__:raise ValueError('Run without Python -O')
    if out.exists():raise ValueError('Output directory must not exist')
    if source.is_symlink():raise ValueError('Input must be a regular file')
    patched,native=prepare(source.read_bytes())
    out.mkdir(parents=True,mode=0o700)
    qrc=out/'resources';qrc.mkdir();(qrc/'QingSnow2App').write_bytes(patched)
    for name,content in native.items():(out/name).write_bytes(content)
    current=qrc/'QingSnow2App'
    for script,name in [('brightness.py','brightness'),('touch_wake.py','touch-wake'),('idle_dim.py','idle-dim')]:
        target=out/name
        subprocess.run([sys.executable,str(ROOT/'native'/script),'--input',str(current),'--output',str(target)],check=True,stdout=subprocess.DEVNULL)
        current=target/'QingSnow2App'
    digest=hashlib.sha256(current.read_bytes()).hexdigest()
    if digest!=FINAL:raise ValueError('Final native candidate does not match the tested profile')
    shutil.copy2(current,out/'QingSnow2App')
    report={'factorySha256':ORIGINAL,'candidateSha256':FINAL,'steps':['ui-hooks','wifi-controls','brightness','touch-wake','idle-dim'],'vendorFilesAreLocalOnly':True,'installed':False}
    (out/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    for p in out.rglob('*'):p.chmod(0o700 if p.is_dir() else 0o600)
    return report

def main():
    os.umask(0o077)
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--input',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);a=parser.parse_args()
    try:print(json.dumps(build(a.input,a.output),indent=2))
    except (ValueError,OSError,subprocess.SubprocessError) as e:print('Build refused: '+str(e),file=sys.stderr);return 2
    return 0
if __name__=='__main__':raise SystemExit(main())
