# SPDX-License-Identifier: MIT
"""Execute the real shell worker with a bounded synthetic NAS transport."""
import json,os,signal,subprocess,tempfile,time,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class WorkerTest(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(prefix='cgs2-worker-');self.root=Path(self.tmp.name);self.run=self.root/'run';self.run.mkdir();self.bin=self.root/'bin';self.bin.mkdir();self.conf=self.root/'conf';self.conf.mkdir()
  (self.conf/'origin').write_text('https://10.0.0.1:6080');(self.root/'uptime').write_text('1000.0 0');self.write('presence.json',{'uptime':1000,'active':True})
  (self.bin/'flock').write_text('#!/bin/sh\nexit 0\n');(self.bin/'flock').chmod(0o755)
  curl='''#!/usr/bin/env python3
import sys,json,pathlib,urllib.parse,os,time
root=pathlib.Path(os.environ['FIXTURE']);args=sys.argv[1:];dest=pathlib.Path(args[args.index('--output')+1]);u=urllib.parse.urlparse(args[-1])
if u.path=='/api/media/manifest':
 page=urllib.parse.parse_qs(u.query)['offset'][0];raw=(root/('page-'+page+'.json')).read_text();dest.write_text(raw);(root/'authorized.json').write_text(json.dumps([x['id'] for x in json.loads(raw)['items']]))
else:
 if u.path.split('/')[-2] not in json.loads((root/'authorized.json').read_text()):sys.exit(1)
 dest.write_bytes(b'synthetic-jpeg')
'''
  (self.bin/'curl').write_text(curl);(self.bin/'curl').chmod(0o755)
  s=(ROOT/'device/media-client.sh').read_text().replace('/tmp/cgs2-media',str(self.run)).replace('/userdata/cgs2-media',str(self.conf)).replace('/userdata/cgs2-micro',str(self.conf)).replace('/userdata/cgs2-ui/cache/media',str(self.root/'video')).replace('/proc/uptime',str(self.root/'uptime'))
  (self.root/'worker.sh').write_text(s);self.n=0;self.process=None
 def tearDown(self):
  if self.process:
   os.killpg(self.process.pid,signal.SIGTERM);self.process.wait(timeout=5);self.process.stderr.close()
  self.tmp.cleanup()
 def write(self,name,v):
  p=self.run/name;p.with_suffix('.new').write_text(json.dumps(v));p.with_suffix('.new').replace(p)
 def page(self,offset,items,more=False):
  (self.root/('page-'+str(offset)+'.json')).write_text(json.dumps({'enabled':True,'revision':'a'*24,'albumName':'Synthetic','intervalMs':3000,'offset':offset,'hasMore':more,'items':[{'id':str(i),'kind':kind,'streamable':kind!='photo'} for i,kind in items]}))
 def start(self):
  self.process=subprocess.Popen(['sh',str(self.root/'worker.sh')],env={**os.environ,'PATH':str(self.bin)+os.pathsep+os.environ['PATH'],'FIXTURE':str(self.root)},stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,start_new_session=True)
  self.wait(lambda v:'protocol'in v)
 def wait(self,check):
  end=time.monotonic()+12
  while time.monotonic()<end:
   if self.process.poll() is not None:self.fail(self.process.stderr.read().decode())
   try:
    v=json.loads((self.run/'manifest.json').read_text())
    if check(v):return v
   except (FileNotFoundError,json.JSONDecodeError):pass
   time.sleep(.04)
  self.fail('Worker state timed out')
 def request(self,kind,page=0,index=0,video=False,next_ready=False):
  self.n+=1;rid='test-'+str(self.n);self.write('request.json',dict(protocol=2,id=rid,uptime=1000,page=page,index=index,video=video,kind=kind))
  return self.wait(lambda v:v['requestId']==rid and v.get('mediaKind')==kind and not v['busy'] and (not v['items'] or v['items'][v['current']].get('previewReady')) and (not next_ready or v.get('nextPreview')) and (not video or v.get('readyVideoId')))
 def test_shuffle_cache_and_typed_views(self):
  self.page(0,[(1,'photo'),(2,'video'),(3,'photo'),(4,'audio'),(5,'photo')]);self.start()
  v=self.request('photo',next_ready=True);seen={v['items'][v['current']]['id']}
  for _ in range(2):
   target=v['nextIndex'];self.assertNotEqual(v['items'][target]['id'],v['items'][v['current']]['id']);self.assertTrue(Path(v['nextPreview'][7:]).exists())
   v=self.request('photo',index=target,next_ready=True);self.assertNotIn(v['items'][v['current']]['id'],seen);seen.add(v['items'][v['current']]['id'])
  self.assertEqual(len(seen),3);self.assertLessEqual(len(list((self.run/'cache').glob('*.jpg'))),4)
  v=self.request('video',video=True);self.assertEqual([i['kind'] for i in v['items']],['video']);self.assertEqual(v['readyVideoId'],'2')
  v=self.request('audio');self.assertEqual([i['kind'] for i in v['items']],['audio'])
 def test_cross_page_preload_and_sparse_categories(self):
  self.page(0,[(1,'photo')],True);self.page(24,[(2,'audio')],True);self.page(48,[(3,'photo'),(4,'video')]);self.start()
  v=self.request('photo',next_ready=True);self.assertEqual(v['offset'],0);self.assertEqual(v['nextPage'],48);self.assertTrue(Path(v['nextPreview'][7:]).exists())
  v=self.request('photo',page=v['nextPage'],index=v['nextIndex'],next_ready=True);self.assertEqual(v['items'][v['current']]['id'],'3');self.assertEqual(v['nextPage'],0)
  v=self.request('video');self.assertEqual(v['offset'],48);self.assertEqual([i['id'] for i in v['items']],['4'])
  (self.run/'cache'/('a'*24+'-4.jpg')).unlink(missing_ok=True)
  v=self.request('video',page=24,index=23);self.assertEqual(v['offset'],48);self.assertFalse(v['hasPrevious'])
 def test_manual_navigation_restores_photos_page_scope_after_cross_page_warmup(self):
  self.page(0,[(i,'photo') for i in range(1,7)],True);self.page(24,[(7,'photo')]);self.start()
  v=self.request('photo',next_ready=True)
  for _ in range(5):v=self.request('photo',index=v['nextIndex'],next_ready=True)
  self.assertEqual(v['nextPage'],24)
  target=(v['current']+1)%6;photo_id=v['items'][target]['id']
  cached=self.run/'cache'/('a'*24+'-'+photo_id+'.jpg');cached.unlink(missing_ok=True)
  v=self.request('photo',index=target,next_ready=True)
  self.assertEqual(v['items'][v['current']]['id'],photo_id);self.assertTrue(cached.exists());self.assertEqual(v['error'],'')
 def test_no_matching_media_is_empty_not_wrong_kind(self):
  self.page(0,[(1,'photo')]);self.start();v=self.request('audio');self.assertEqual(v['items'],[])
if __name__=='__main__':unittest.main()
