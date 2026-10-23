#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Audit the public tree and Git index without reading ignored local inputs."""
import argparse,hashlib,json,os,re,subprocess,sys,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
EXCLUDED={'.git','.local','.private','.runtime','.venv','node_modules','dist','build','__pycache__'}
ALLOWED={'.gitignore','.github','README.md','VERSION','CHANGELOG.md','LICENSE','SECURITY.md','CONTRIBUTING.md','SOURCE-MANIFEST.json','qml','native','driver','device','tools','tests','docs','preview','integrations'}
FORBIDDEN={'.ko','.o','.pem','.key','.log','.mp4','.mp3','.wav','.pcm','.zip','.pyc','.jpg','.jpeg'}

def files(root):
 result={};issues=[]
 for base,dirs,names in os.walk(root,followlinks=False):
  base=Path(base)
  for name in list(dirs):
   path=base/name
   if path.is_symlink():issues.append((str(path.relative_to(root)),'symlink'));dirs.remove(name)
   elif name in EXCLUDED:dirs.remove(name)
  for name in names:
   path=base/name;rel=path.relative_to(root).as_posix()
   if path.is_symlink():issues.append((rel,'symlink'));continue
   if name=='.DS_Store':issues.append((rel,'desktop_metadata'));continue
   result[rel]=path
 return result,issues

def audit(root,write=False):
 source,issues=files(root);digest=lambda b:hashlib.sha256(b).hexdigest()
 images={}
 for name in ['qml/textures/provenance.json','qml/water/provenance.json','qml/art/provenance.json','docs/previews/provenance.json']:
  p=root/name
  if p.is_file():
   try:
    meta=json.loads(p.read_text());values=meta.get('files',meta.get('generated',{}))
    images.update({str(Path(name).parent/k):v for k,v in values.items()})
   except (ValueError,TypeError):issues.append((name,'invalid_asset_provenance'))
 for name,p in source.items():
  if Path(name).parts[0]not in ALLOWED:issues.append((name,'unexpected_root'))
  data=p.read_bytes()
  if p.suffix.lower()in FORBIDDEN or p.name in ['NativeAirDatasView.qml','NativeScreenSaver.qml','wpa_supplicant.conf','auth-header','QingSnow2App']or data.startswith(b'\x7fELF'):issues.append((name,'forbidden_artifact'))
  if p.suffix=='.ttf':
   if name!='qml/fonts/PermanentMarker-Regular.ttf' or digest(data)!='28f82c8a7943cb8e9d599f8554da1d4fc75dbcf69b9885ad6c0611d20c6946c5' or not (root/'qml/fonts/PermanentMarker-LICENSE.txt').is_file():issues.append((name,'unreviewed_font'))
   continue
  if p.suffix=='.png':
   if images.get(name)!=digest(data):issues.append((name,'unreviewed_image'))
   if not data.startswith(b'\x89PNG\r\n\x1a\n'):issues.append((name,'invalid_png'));continue
   at=8;ended=False
   while at+12<=len(data):
    size=int.from_bytes(data[at:at+4],'big');kind=data[at+4:at+8]
    if at+size+12>len(data)or zlib.crc32(data[at+4:at+8+size])&0xffffffff!=int.from_bytes(data[at+8+size:at+12+size],'big'):issues.append((name,'invalid_png_chunk'));break
    if kind in [b'eXIf',b'tEXt',b'iTXt',b'zTXt']:issues.append((name,'image_metadata'))
    if kind==b'IEND':ended=True
    at+=size+12
   if at!=len(data)or not ended:issues.append((name,'invalid_png_end'))
   continue
  try:text=data.decode('utf8')
  except UnicodeError:issues.append((name,'unreviewed_binary'));continue
  rules={'personal_home':r'/(?:Users|home)/[^/\s]+','device_identifier':r'\bMSNS[A-Z0-9]{8,}\b','hardware_address':r'(?i)(?<![\w:])(?:[0-9a-f]{2}:){5}[0-9a-f]{2}(?![\w:])','github_credential':r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})','private_key':r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----','personal_domain':r'geeprox\.synology\.me'}
  for category,pattern in rules.items():
   if re.search(pattern,text):issues.append((name,category))
  for value in re.findall(r'(?<![\d.])(?:192\.168\.\d+\.\d+|10\.\d+\.\d+\.\d+|172\.(?:1[6-9]|2\d|3[01])\.\d+\.\d+)(?![\d.])',text):
   fixture=name.startswith('tests/')or Path(name).name in ['test.mjs','test_server.py','test_stream.py']
   if value not in ['10.0.0.0','172.16.0.0','192.168.0.0']and not fixture:issues.append((name,'private_network_value'))
 # The index is checked separately so git add -f cannot leak ignored local files.
 if (root/'.git').exists():
  index=subprocess.run(['git','-C',str(root),'ls-files','-z'],capture_output=True,check=True).stdout.decode().split('\0')
  for name in filter(None,index):
   if any(x in EXCLUDED for x in Path(name).parts)or name not in source:issues.append((name,'private_or_missing_tracked_file'))
 public={name:digest(p.read_bytes())for name,p in sorted(source.items())if name!='SOURCE-MANIFEST.json'}
 if write and not issues:(root/'SOURCE-MANIFEST.json').write_text(json.dumps(public,indent=2,sort_keys=True)+'\n')
 elif not write:
  try:
   if json.loads((root/'SOURCE-MANIFEST.json').read_text())!=public:issues.append(('SOURCE-MANIFEST.json','manifest_mismatch'))
  except (OSError,ValueError):issues.append(('SOURCE-MANIFEST.json','missing_manifest'))
 return {'publicFiles':len(public),'findings':[{'path':p,'category':c}for p,c in sorted(set(issues))],'sensitiveValuesPrinted':False}

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path,default=ROOT);p.add_argument('--write-manifest',action='store_true');a=p.parse_args();report=audit(a.root,a.write_manifest);print(json.dumps(report,indent=2));return 2 if report['findings']else 0
if __name__=='__main__':raise SystemExit(main())
