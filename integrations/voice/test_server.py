# SPDX-License-Identifier: MIT
import importlib.util, pathlib, unittest, threading, http.client, json
spec=importlib.util.spec_from_file_location('voice',pathlib.Path(__file__).with_name('server.py'));voice=importlib.util.module_from_spec(spec);spec.loader.exec_module(voice)
class Stub:
 ready=True
 def __init__(self):self.calls=0
 def transcribe(self,raw):self.calls+=1;return {'text':'fixture','level':.1,'speech':True}
class TestVoice(unittest.TestCase):
 def setUp(self):
  self.rec=Stub();self.server=voice.make_server(('127.0.0.1',0),'fixture-token',self.rec);self.server.server_address=('127.0.0.1',self.server.socket.getsockname()[1]);self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
 def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join()
 def call(self,path='/transcribe',body=b'\0'*3200,headers=None):
  # Factory's exact Host is based on requested bind tuple (port 0 in isolated fixture).
  h={'Host':'127.0.0.1:0','Authorization':'Bearer fixture-token','Content-Type':'application/octet-stream','X-Voice-Session':'fixture_1',**(headers or {})};c=http.client.HTTPConnection('127.0.0.1',self.server.server_address[1]);c.request('POST',path,body,h);r=c.getresponse();data=r.read();c.close();return r.status,json.loads(data)
 def test_authorized_pcm_and_session(self):
  status,data=self.call();self.assertEqual(status,200);self.assertEqual(data['session'],'fixture_1');self.assertEqual(self.rec.calls,1)
 def test_credential_host_origin_and_session_rejected_before_inference(self):
  for h in [{'Authorization':'Bearer wrong'},{'Host':'evil.example'},{'Origin':'http://friday.local'},{'X-Voice-Session':'../private'},{'Content-Type':'text/plain'}]:self.assertIn(self.call(headers=h)[0],[400,403])
  self.assertEqual(self.rec.calls,0)
 def test_payload_and_route_bounds(self):
  for b in [b'',b'x'*3199,b'x'*256002]:self.assertEqual(self.call(body=b)[0],413)
  self.assertEqual(self.call('/private')[0],404);self.assertEqual(self.rec.calls,0)
if __name__=='__main__':unittest.main()
