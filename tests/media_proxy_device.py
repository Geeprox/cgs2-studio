#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Opt-in real ARM64 relay test with a synthetic TLS source, isolated from providers."""
import argparse,hashlib,http.server,json,os,shutil,ssl,subprocess,sys,threading,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from adb_device import Device
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--host',required=True,help='This computer RFC1918 IPv4 reachable from the device');p.add_argument('--serial');a=p.parse_args()
ID=uuid.uuid4().hex;stage=ROOT/'.local/relay-test'/ID;stage.mkdir(parents=True,mode=0o700);remote='/tmp/cgs2-relay-test-'+ID
DATA=b'cgs2-public-synthetic-media-fixture';TOKEN='fixture-device-token';REV='a'*24
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_HEAD(self):self.reply(True)
 def do_GET(self):self.reply(False)
 def reply(self,head):
  if self.path!='/api/media/item/1/video?revision='+REV or self.headers.get('Authorization')!='Bearer '+TOKEN or self.headers.get('Origin')!=origin:self.send_error(403);return
  start,end=0,len(DATA)-1;code=200
  if self.headers.get('Range')=='bytes=4-9':start,end,code=4,9,206
  elif self.headers.get('Range') is not None:self.send_error(416);return
  self.send_response(code);self.send_header('Content-Type','video/mp4');self.send_header('Content-Length',str(end-start+1));self.send_header('Connection','close')
  if code==206:self.send_header('Content-Range',f'bytes {start}-{end}/{len(DATA)}')
  self.end_headers()
  if not head:self.wfile.write(DATA[start:end+1])
server=http.server.ThreadingHTTPServer((a.host,0),Handler);origin='https://'+a.host+':'+str(server.server_port)
subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-sha256','-days','1','-subj','/CN=CGS2 fixture','-addext','subjectAltName=IP:'+a.host,'-keyout',str(stage/'server.key'),'-out',str(stage/'ca.pem')],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(stage/'ca.pem',stage/'server.key');server.socket=context.wrap_socket(server.socket,server_side=True);thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
d=Device(a.serial);d.inspect();pid=''
try:
 (stage/'origin').write_text(origin+'\n');(stage/'auth-header').write_text('Authorization: Bearer '+TOKEN+'\n')
 source=(ROOT/'device/media-proxy.c').read_text().replace('/userdata/cgs2-media',remote).replace('/userdata/cgs2-micro',remote).replace('6097','6098').replace('0xd117','0xd217');(stage/'relay.c').write_text(source)
 subprocess.run([shutil.which('clang')or'clang','-target','aarch64-linux-gnu','-Os','-fno-pic','-fno-pie','-fno-jump-tables','-ffreestanding','-fno-stack-protector','-fno-builtin','-fno-unwind-tables','-fno-asynchronous-unwind-tables','-I',str(ROOT/'device'),'-c',str(stage/'relay.c'),'-o',str(stage/'relay.o')],check=True)
 subprocess.run([sys.executable,str(ROOT/'tools/link_proxy.py'),'--input',str(stage/'relay.o'),'--output',str(stage/'relay')],check=True,stdout=subprocess.DEVNULL)
 d.shell('mkdir '+remote+';chmod 700 '+remote)
 for n in ['relay','origin','auth-header','ca.pem']:d.push(stage/n,remote+'/'+n)
 pid=d.shell('chmod 700 '+remote+'/relay;/usr/bin/setsid '+remote+'/relay </dev/null >'+remote+'/launch.log 2>&1 & sleep .3; for e in /proc/[0-9]*/exe;do [ "$(readlink "$e" 2>/dev/null)" = '+remote+'/relay ] || continue;p=${e#/proc/};echo ${p%/exe};done')
 if not pid.isdigit():
  d.pull(remote+'/launch.log',stage/'launch.log')
  raise RuntimeError('Test process did not start; inspect local launch.log')
 d.shell('sleep .2;test "$(readlink /proc/'+pid+'/exe)" = '+remote+'/relay')
 def request(path,options=''):
  return d.shell('curl --silent --max-time 5 '+options+' -o '+remote+'/body -D '+remote+'/headers -w \'%{http_code}\' \'http://127.0.0.1:6098/'+path+'\'')
 assert request('invalid')=='400'
 route='media/1?revision='+REV
 assert request(route)=='200';d.pull(remote+'/body',stage/'body');assert (stage/'body').read_bytes()==DATA
 assert request(route,'-H \'Range: bytes=4-9\'')=='206';d.pull(remote+'/body',stage/'body');assert (stage/'body').read_bytes()==DATA[4:10]
 assert request(route,'--head -H \'Range: bytes=4-9\'')=='206';d.pull(remote+'/headers',stage/'headers');assert 'Content-Length: 6' in (stage/'headers').read_text()
 assert request(route,'-H \'Range: bytes=0-1,4-5\'')=='400'
 report={'realAArch64LinuxRelay':True,'sourceIsSyntheticTLSFixture':True,'productionProviderFilesRead':False,'requests':['invalid route 400','GET verified bytes 200','single Range verified bytes 206','HEAD content length 206','multiple Range rejected 400'],'passed':True}
 (stage/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
finally:
 if pid.isdigit():
  try:d.shell('if [ "$(readlink /proc/'+pid+'/exe)" = '+remote+'/relay ];then kill -TERM -'+pid+';fi')
  except Exception:pass
 try:d.shell('rm -rf '+remote)
 except Exception:pass
 server.shutdown();server.server_close();thread.join()
