#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Create a fresh local service directory with independent TLS and credentials."""
import argparse,ipaddress,json,os,secrets,subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('service',choices=['media','voice']);p.add_argument('--host',required=True);p.add_argument('--port',type=int);p.add_argument('--output',type=Path,required=True);p.add_argument('--root',type=Path,action='append',default=[]);p.add_argument('--photos-origin');a=p.parse_args()
address=ipaddress.ip_address(a.host)
if address.version!=4 or not any(address in ipaddress.ip_network(s)for s in ['10.0.0.0/8','172.16.0.0/12','192.168.0.0/16']):p.error('Host must be an RFC1918 LAN IPv4 address')
port=a.port or (6080 if a.service=='media' else 6095)
if not 1<=port<=65535:p.error('Invalid port')
if a.output.exists():p.error('Output directory must not exist')
if a.service=='media' and not a.root:p.error('At least one explicit media --root is required')
roots=[]
for r in a.root:
 value=r.resolve(strict=True)
 if not value.is_dir() or r.is_symlink():p.error('Media root must be a real directory')
 roots.append({'label':value.name,'path':str(value)})
os.umask(0o077);a.output.mkdir(parents=True,mode=0o700)
subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-sha256','-days','365','-subj','/CN=CGS2 Local Service','-addext','subjectAltName=IP:'+a.host,'-keyout',str(a.output/'server.key'),'-out',str(a.output/'server.pem')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
if a.service=='media':
 admin=secrets.token_hex(32);device=secrets.token_hex(32)
 (a.output/'admin-token').write_text(admin+'\n');(a.output/'device-token').write_text(device+'\n');(a.output/'auth-header').write_text('Authorization: Bearer '+device+'\n')
 config={'host':a.host,'port':port,'roots':roots}
 if a.photos_origin:config['photos']={'origin':a.photos_origin,'lanIp':a.host}
 (a.output/'server.json').write_text(json.dumps(config,indent=2)+'\n')
else:
 token=secrets.token_hex(32);(a.output/'token').write_text(token+'\n');(a.output/'auth-header').write_text('Authorization: Bearer '+token+'\n')
(a.output/'origin').write_text('https://'+a.host+':'+str(port)+'\n')
for f in a.output.iterdir():f.chmod(0o600)
print('Created private service files. Keep this directory outside Git and copy only server.pem and auth-header to the device.')
