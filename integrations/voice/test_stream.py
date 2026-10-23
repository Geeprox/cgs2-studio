# SPDX-License-Identifier: MIT
import io,json,math,sys,threading,time,unittest,types
from array import array
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
import voice_stream as stream
import server as voice

def pcm(seconds,amplitude=68):
 return array('h',(int(amplitude*math.sin(i*.08)) for i in range(int(seconds*16000)))).tobytes()
def chunks(raw,n=3200):
 for p in range(0,len(raw),n):yield raw[p:p+n]
def encoded(raw):return b''.join(('%x\r\n'%len(p)).encode()+p+b'\r\n' for p in chunks(raw))+b'0\r\n\r\n'
class Rec:
 ready=True
 def __init__(self):self.audio=[]
 def transcribe(self,raw):self.audio.append(raw);return {'text':'fixture-'+str(len(self.audio)),'speech':True,'level':.02}
class StreamTests(unittest.TestCase):
 def test_strict_chunk_decoder_and_bounds(self):
  raw=pcm(.31);self.assertEqual(b''.join(stream.chunked_pcm(io.BytesIO(encoded(raw)))),raw)
  for data in [b'1;bad=x\r\nx\r\n0\r\n\r\n',b'1\r\nx!',b'0\r\nEvil: trailer\r\n',b'fffffff\r\n']:
   with self.assertRaises(stream.StreamError):list(stream.chunked_pcm(io.BytesIO(data)))
 def test_true_first_partial_at_1_6s_before_eof(self):
  events=[];rec=Rec();ended=False
  def source():
   nonlocal ended
   for p in chunks(pcm(2.1)):
    yield p;time.sleep(.001)
   ended=True
  def emit(e):events.append((e,ended))
  session=stream.StreamSession(rec,emit);session.run(source())
  self.assertEqual(len(rec.audio[0]),stream.FIRST_WINDOW_BYTES)
  partials=[item for item in events if item[0]['status']=='partial'];self.assertTrue(partials);self.assertFalse(partials[0][1]);self.assertEqual(events[-1][0]['status'],'done')
 def test_capture_reads_while_inference_is_blocked(self):
  entered=threading.Event();release=threading.Event();rec=Rec();orig=rec.transcribe
  def slow(raw):entered.set();release.wait(2);return orig(raw)
  rec.transcribe=slow;session=stream.StreamSession(rec,lambda e:None)
  def source():
   for p in chunks(pcm(3)):yield p;time.sleep(.001)
  worker=threading.Thread(target=session.run,args=(source(),));worker.start();self.assertTrue(entered.wait(1))
  end=time.monotonic()+1
  while session.received<96000 and time.monotonic()<end:time.sleep(.005)
  self.assertEqual(session.received,96000);self.assertLessEqual(session.maximumQueuedFrames,64);release.set();worker.join(2);self.assertFalse(worker.is_alive())
 def test_stop_flushes_short_tail_and_no_extra_capture(self):
  raw=pcm(.35);rec=Rec();events=[];session=stream.StreamSession(rec,events.append);session.run(chunks(raw,517))
  self.assertEqual(rec.audio,[raw]);self.assertEqual(events[-1]['status'],'done');self.assertTrue(events[-1]['text'])
 def test_quiet_far_field_eligible_but_digital_silence_not_inferred(self):
  rec=Rec();events=[];session=stream.StreamSession(rec,events.append);session.run(chunks(pcm(.7,96)))
  self.assertTrue(rec.audio);self.assertAlmostEqual(stream.energy(pcm(.1,96)),.00206,places=4)
  rec=Rec();session=stream.StreamSession(rec,lambda e:None);session.run(chunks(b'\0'*64000));self.assertEqual(rec.audio,[])
 def test_backpressure_is_explicit_not_silent_drop(self):
  session=stream.StreamSession(Rec(),lambda e:None,queue_frames=1);session.receive(chunks(pcm(1)))
  self.assertEqual(session.error,'audio_backpressure');self.assertLessEqual(session.maximumQueuedFrames,1)
 def test_partial_final_and_overlap(self):
  self.assertEqual(stream.join_text('今天阳光很好','光很好我们出去走走'),'今天阳光很好我们出去走走')
  rec=Rec();events=[];stream.StreamSession(rec,events.append).run(chunks(pcm(1)+b'\0'*16000));self.assertEqual(events[-1]['status'],'done')
 def test_eight_second_tail_deadline_preserves_recognized_text(self):
  clock=[0.0];events=[];rec=Rec()
  def slow(raw):clock[0]=9.1;return {'text':'fixture','speech':True,'level':.1}
  rec.transcribe=slow;session=stream.StreamSession(rec,events.append,clock=lambda:clock[0]);session.run(chunks(pcm(.4)))
  self.assertEqual(events[-1]['status'],'error');self.assertEqual(events[-1]['error'],'tail_timeout');self.assertEqual(events[-1]['text'],'fixture')
 def test_twenty_second_capture_bound(self):
  rec=Rec();events=[];session=stream.StreamSession(rec,events.append)
  def source():
   for block in chunks(pcm(20)):yield block;time.sleep(.001)
  session.run(source());self.assertEqual(session.received,640000);self.assertEqual(events[-1]['status'],'done')
 def test_delayed_short_utterance_remains_whole_despite_constant_room_noise(self):
  prefix=pcm(2.5,96);speech=pcm(2.8,1200);raw=prefix+speech+pcm(1.0,96)
  rec=Rec();events=[];stream.StreamSession(rec,events.append).run(chunks(raw))
  self.assertEqual(events[-1]['status'],'done');self.assertTrue(any(speech in window for window in rec.audio));self.assertLessEqual(max(map(len,rec.audio)),6*32000)
 def test_empty_hypothesis_uses_followup_cadence_and_resets_each_utterance(self):
  rec=Rec()
  def empty(raw):rec.audio.append(raw);return {'text':'','speech':False,'level':.02}
  rec.transcribe=empty;stream.StreamSession(rec,lambda e:None).run(chunks(pcm(6.5)))
  self.assertEqual([len(x) for x in rec.audio[:5]],[51200,89600,128000,166400,192000])
  self.assertEqual(len(rec.audio[-1]),25600)

class HandlerTests(unittest.TestCase):
 def handler(self,headers=None,raw=None,peer='127.0.0.1'):
  rec=Rec();original=voice.VoiceHTTPServer
  voice.VoiceHTTPServer=lambda address,handler:types.SimpleNamespace(handler=handler)
  try:base=voice.make_server(('127.0.0.1',6095),'fixture-token',rec,'127.0.0.1').handler
  finally:voice.VoiceHTTPServer=original
  class Handler(base):
   def reply(self,code,data):self.replied=(code,data)
   def send_response(self,code):self.code=code
   def send_response_only(self,code):self.code=code
   def send_header(self,k,v):self.sent_headers[k]=v
   def end_headers(self):pass
  h=object.__new__(Handler);h.client_address=(peer,0);h.connection=types.SimpleNamespace(settimeout=lambda _:None,shutdown=lambda _:None);h.path='/stream';h.close_connection=False;h.sent_headers={};h.headers={'Host':'127.0.0.1:6095','Authorization':'Bearer fixture-token','Content-Type':'application/octet-stream','X-Voice-Session':'fixture','Transfer-Encoding':'chunked',**(headers or {})};h.rfile=io.BytesIO(encoded(pcm(.4)) if raw is None else raw);h.wfile=io.BytesIO();return h,rec
 def test_stream_response_chunks_flush_and_session(self):
  h,rec=self.handler();h.do_POST();self.assertEqual(h.code,200);self.assertEqual(h.sent_headers['Transfer-Encoding'],'chunked');data=b''.join(stream.chunked_pcm(io.BytesIO(h.wfile.getvalue())));rows=[json.loads(r) for r in data.splitlines()];self.assertTrue(all(r['session']=='fixture' for r in rows));self.assertEqual(rows[-1]['status'],'done');self.assertTrue(rec.audio)
 def test_stream_negative_auth_host_origin_peer_and_smuggling(self):
  for headers in [{'Authorization':'Bearer wrong'},{'Host':'evil'},{'Origin':'http://evil'},{'X-Voice-Session':'../bad'},{'Content-Length':'100'},{'Transfer-Encoding':'chunked, gzip'}]:
   h,rec=self.handler(headers);h.do_POST();self.assertIn(h.replied[0],[400,403]);self.assertEqual(rec.audio,[])
  h,rec=self.handler(peer='127.0.0.2');h.do_POST();self.assertEqual(h.replied[0],403)
 def test_expect_is_authenticated_before_100(self):
  h,rec=self.handler({'Authorization':'Bearer wrong'});self.assertFalse(h.handle_expect_100());self.assertEqual(h.replied[0],403)
  h,rec=self.handler();self.assertTrue(h.handle_expect_100());self.assertEqual(h.code,100)
 def test_duplicate_headers_are_rejected(self):
  from email.message import Message
  for duplicate in ['Host','Authorization','Transfer-Encoding','X-Voice-Session','Content-Type']:
   h,rec=self.handler();msg=Message()
   for key,value in h.headers.items():msg[key]=value
   msg[duplicate]=h.headers[duplicate];h.headers=msg;h.do_POST();self.assertIn(h.replied[0],[400,403]);self.assertEqual(rec.audio,[])
 def test_legacy_endpoint_still_bounded_and_session_fenced(self):
  h,rec=self.handler();h.path='/transcribe';del h.headers['Transfer-Encoding'];h.headers['Content-Length']='3200';h.rfile=io.BytesIO(pcm(.1));h.do_POST();self.assertEqual(h.replied[0],200);self.assertEqual(h.replied[1]['session'],'fixture')
  h,rec=self.handler();h.path='/transcribe';del h.headers['Transfer-Encoding'];h.headers['Content-Length']='256002';h.rfile=io.BytesIO(b'');h.do_POST();self.assertEqual(h.replied[0],413);self.assertEqual(rec.audio,[])

class RecognitionGateTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  # Import outside patch.dict so extension modules are not removed on exit.
  import numpy
 def test_quiet_shared_microphone_reaches_model_with_bounded_gain(self):
  import numpy as np
  from unittest.mock import patch
  captured=[]
  fake=types.SimpleNamespace(transcribe=lambda samples,**kw:captured.append(samples.copy()) or {'segments':[{'text':'synthetic fixture','no_speech_prob':.1,'avg_logprob':-.2,'compression_ratio':1.1}]})
  recognizer=voice.Recognizer('unused-fixture-model')
  with patch.dict(sys.modules,{'mlx_whisper':fake}):
   result=recognizer.transcribe(pcm(.7,96))
   self.assertTrue(result['speech']);self.assertEqual(len(captured),1)
   self.assertLessEqual(float(np.max(np.abs(captured[0]))),96/32768*4+.00001)
   recognizer.transcribe(b'\0'*3200);self.assertEqual(len(captured),1)
 def test_noise_and_uncertain_model_hypotheses_do_not_emit_text(self):
  from unittest.mock import patch
  recognizer=voice.Recognizer('unused-fixture-model')
  for bad in [{'no_speech_prob':.9,'avg_logprob':-.2,'compression_ratio':1.1},{'no_speech_prob':.1,'avg_logprob':-1.2,'compression_ratio':1.1},{'no_speech_prob':.1,'avg_logprob':-.2,'compression_ratio':3.1}]:
   fake=types.SimpleNamespace(transcribe=lambda samples,**kw:{'segments':[{'text':'must not emit',**bad}]})
   with patch.dict(sys.modules,{'mlx_whisper':fake}):self.assertFalse(recognizer.transcribe(pcm(.7,96))['speech'])
 def test_ready_waits_for_two_controlled_speech_decode_warmups(self):
  from unittest.mock import patch
  import tempfile,numpy as np
  with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
   file=Path(folder)/'synthetic.pcm';file.write_bytes(pcm(.7,96));rec=voice.Recognizer('unused-fixture-model',file);calls=[]
   def transcribe(samples,**kw):self.assertFalse(rec.ready);calls.append(bool(np.any(samples)));return {'segments':[]}
   fake=types.SimpleNamespace(transcribe=transcribe)
   with patch.dict(sys.modules,{'mlx_whisper':fake}):rec.warm()
   self.assertEqual(calls,[False,True,True]);self.assertTrue(rec.ready);self.assertEqual(rec.decode_warmup_passes,2)
 def test_http_callers_reuse_same_actual_decode_thread_and_budget_as_warmup(self):
  from unittest.mock import patch
  import tempfile
  calls=[]
  with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
   file=Path(folder)/'synthetic.pcm';file.write_bytes(pcm(2.8,96));rec=voice.Recognizer('unused-fixture-model',file)
   def decode(samples,**kw):calls.append((threading.get_ident(),len(samples),kw['sample_len']));return {'segments':[]}
   fake=types.SimpleNamespace(transcribe=decode)
   with patch.dict(sys.modules,{'mlx_whisper':fake}):
    rec.warm()
    for size in [1.6,2.8,4]:
     request=threading.Thread(target=rec.transcribe,args=(pcm(size,96),));request.start();request.join(2);self.assertFalse(request.is_alive())
   self.assertEqual(len(calls),6);self.assertEqual(len(set(row[0] for row in calls)),1);self.assertNotEqual(calls[0][0],threading.get_ident());self.assertEqual([row[1] for row in calls[:3]],[16000,25600,96000]);self.assertTrue(all(row[2]==96 for row in calls));rec.decode_worker.shutdown()

if __name__=='__main__':unittest.main(verbosity=2)
