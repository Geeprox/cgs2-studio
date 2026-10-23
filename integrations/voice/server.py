# SPDX-License-Identifier: MIT
"""Bounded local-only PCM -> Whisper bridge. Audio/text are never logged or saved."""
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse, hmac, ipaddress, json, os, re, ssl, threading, time
from voice_stream import StreamSession,StreamError,chunked_pcm

MAX_PCM=256000
class VoiceHTTPServer(ThreadingHTTPServer):
    request_queue_size=4
    daemon_threads=True
    tls_context=None
    def __init__(self,*args):
        self.slots=threading.BoundedSemaphore(4)
        super().__init__(*args)
    def process_request(self,request,client_address):
        request.settimeout(12)
        if not self.slots.acquire(blocking=False):
            request.close();return
        try:super().process_request(request,client_address)
        except Exception:
            self.slots.release();request.close();raise
    def process_request_thread(self,request,client_address):
        try:
            if self.tls_context:request=self.tls_context.wrap_socket(request,server_side=True)
            super().process_request_thread(request,client_address)
        except (OSError,ssl.SSLError):request.close()
        finally:self.slots.release()
    def handle_error(self,*_):
        # Never put request headers, audio, or transcription into diagnostics.
        pass

class Recognizer:
    def __init__(self, model, warmup=None):
        self.model=model
        self.lock=threading.Lock()
        self.ready=False
        self.converter=None
        self.warmup=warmup
        self.decode_warmup_passes=0
        # MLX's stream/compilation context must survive HTTP request threads.
        # Warmup and every live decode share this one bounded serial worker.
        self.decode_worker=ThreadPoolExecutor(max_workers=1,thread_name_prefix='cgs2-decode')
    def warm(self):
        return self.decode_worker.submit(self._warm).result()
    def _decode(self,samples):
        import mlx_whisper
        return mlx_whisper.transcribe(samples,path_or_hf_repo=self.model,language='zh',verbose=None,temperature=0,condition_on_previous_text=False,no_speech_threshold=.55,logprob_threshold=-1.0,compression_ratio_threshold=2.4,sample_len=96)
    def _warm(self):
        import numpy as np
        import mlx_whisper
        from opencc import OpenCC
        self.converter=OpenCC("t2s")
        # Load/compile once before accepting microphone traffic. Synthetic silence only.
        self._decode(np.zeros(16000,dtype=np.float32))
        # Silence does not necessarily run the real language decoder. The only
        # persisted PCM allowed here is this operator-supplied, controlled
        # synthetic fixture; user microphone input never reaches a file.
        if self.warmup is None:raise ValueError('A controlled synthetic warmup PCM is required')
        path=Path(self.warmup)
        if path.is_symlink() or path.suffix!='.pcm' or not path.is_file() or not 3200<=path.stat().st_size<=128000:raise ValueError('Invalid synthetic warmup PCM')
        with path.open('rb') as source:raw=source.read(128002)
        if len(raw)%2 or not 3200<=len(raw)<=128000:raise ValueError('Invalid synthetic warmup PCM')
        synthetic=np.frombuffer(raw,dtype='<i2').astype(np.float32)/32768.0
        warm_rms=float(np.sqrt(np.mean(synthetic*synthetic)))
        if warm_rms<.00065:raise ValueError('Synthetic warmup must contain an audible controlled utterance')
        synthetic=np.clip(synthetic*min(4.0,max(1.0,.025/warm_rms)),-1,1)
        for samples in [synthetic[:25600],np.pad(synthetic,(0,max(0,96000-len(synthetic))))]:
            self._decode(samples)
            self.decode_warmup_passes+=1
        raw=None;synthetic=None
        self.ready=True
    def transcribe(self, raw):
        if not self.lock.acquire(blocking=False):raise RuntimeError('busy')
        try:return self.decode_worker.submit(self._transcribe,raw).result()
        finally:self.lock.release()
    def _transcribe(self, raw):
        import numpy as np
        samples=np.frombuffer(raw,dtype='<i2').astype(np.float32)/32768.0
        rms=float(np.sqrt(np.mean(samples*samples))) if samples.size else 0
        level=min(1.0,rms*12)
        if rms<.00045:return {'text':'','level':level,'speech':False}
        # Short noise windows may otherwise spend 224 tokens hallucinating
        # before confidence rejection. Six seconds of speech has a 96-token
        # decode budget; input length and capture are still independently bound.
        gain=min(4.0,max(1.0,.025/max(rms,.00045)))
        samples=np.clip(samples*gain,-1,1)
        result=self._decode(samples)
        text=''.join(s.get('text','') for s in result.get('segments',[]) if s.get('no_speech_prob',1)<.55 and s.get('avg_logprob',-99)>-1 and s.get('compression_ratio',99)<2.4).strip()[:1200]
        if self.converter:text=self.converter.convert(text)
        return {'text':text,'level':level,'speech':bool(text)}

def make_server(address, token, recognizer, allowed_peer=None):
    expected_host=f'{address[0]}:{address[1]}'
    class Handler(BaseHTTPRequestHandler):
        server_version='CGS2LocalVoice/2'
        protocol_version='HTTP/1.1'
        def log_message(self,*_):pass
        def reply(self,code,data):
            raw=json.dumps(data,ensure_ascii=True,separators=(',',':')).encode()
            self.send_response(code);self.send_header('Content-Type','application/json');self.send_header('Content-Length',str(len(raw)));self.send_header('Cache-Control','no-store');self.end_headers();self.wfile.write(raw)
        def authorized(self):
            peer=self.client_address[0]
            try:private=ipaddress.ip_address(peer).is_private
            except ValueError:private=False
            if not private or allowed_peer and peer!=allowed_peer or len(self.header_values('Host'))!=1 or len(self.header_values('Authorization'))!=1 or self.headers.get('Host')!=expected_host or self.headers.get('Origin') is not None or not hmac.compare_digest(self.headers.get('Authorization','').encode('utf-8'),('Bearer '+token).encode('utf-8')):
                self.close_connection=True
                self.reply(403,{'error':'access_denied'});return False
            return True
        def header_values(self,name):
            if hasattr(self.headers,'get_all'):return self.headers.get_all(name,[])
            return [self.headers[name]] if name in self.headers else []
        def do_GET(self):
            if not self.authorized():return
            if self.path!='/health':self.reply(404,{'error':'not_found'});return
            self.reply(200,{'ready':recognizer.ready,'service':'cgs2-local-voice','localRecognition':True,'streaming':True,'captureLimitSeconds':20,'tailLimitSeconds':8,'decodeWarmupPasses':getattr(recognizer,'decode_warmup_passes',0)})
        def do_POST(self):
            self.connection.settimeout(12)
            if not self.authorized():return
            if self.path=='/stream':self.stream();return
            if self.path!='/transcribe':self.reply(404,{'error':'not_found'});return
            session=self.headers.get('X-Voice-Session','')
            if not re.fullmatch(r'[A-Za-z0-9_-]{1,96}',session) or len(self.header_values('X-Voice-Session'))!=1 or self.headers.get('Content-Type')!='application/octet-stream' or self.headers.get('Transfer-Encoding'):
                self.reply(400,{'error':'invalid_request'});return
            try:n=int(self.headers.get('Content-Length','0'))
            except ValueError:n=0
            if n<3200 or n>MAX_PCM or n%2:self.reply(413,{'error':'audio_limit'});return
            raw=self.rfile.read(n)
            if len(raw)!=n:self.reply(400,{'error':'incomplete_audio'});return
            if not recognizer.ready:self.reply(503,{'error':'model_loading'});return
            begin=time.monotonic()
            try:result=recognizer.transcribe(raw)
            except RuntimeError:self.reply(409,{'error':'busy'});return
            except Exception:self.reply(502,{'error':'recognition_failed'});return
            finally:raw=None
            self.reply(200,{'session':session,**result,'processingMs':round((time.monotonic()-begin)*1000)})
        def handle_expect_100(self):
            # Authenticate before acknowledging any upload. The shipped client
            # suppresses Expect; this supports conforming HTTP/1.1 peers too.
            if not self.authorized():return False
            self.send_response_only(100);self.end_headers();return True
        def stream(self):
            session=self.headers.get('X-Voice-Session','')
            if not re.fullmatch(r'[A-Za-z0-9_-]{1,96}',session) or len(self.header_values('X-Voice-Session'))!=1 or len(self.header_values('Content-Type'))!=1 or len(self.header_values('Transfer-Encoding'))!=1 or self.headers.get('Content-Type')!='application/octet-stream' or self.headers.get('Transfer-Encoding','').lower()!='chunked' or self.headers.get('Content-Length') is not None:
                self.close_connection=True;self.reply(400,{'error':'invalid_request'});return
            if not recognizer.ready:self.close_connection=True;self.reply(503,{'error':'model_loading'});return
            self.connection.settimeout(4)
            self.send_response(200);self.send_header('Content-Type','application/x-ndjson');self.send_header('Transfer-Encoding','chunked');self.send_header('Cache-Control','no-store');self.send_header('Connection','close');self.end_headers()
            def emit(event):
                raw=(json.dumps({'session':session,**event},ensure_ascii=True,separators=(',',':'))+'\n').encode()
                self.wfile.write(('%x\r\n'%len(raw)).encode()+raw+b'\r\n');self.wfile.flush()
            stream=StreamSession(recognizer,emit)
            try:
                stream.run(chunked_pcm(self.rfile))
                self.wfile.write(b'0\r\n\r\n');self.wfile.flush()
            except (OSError,BrokenPipeError):pass
            finally:
                stream.cancelled.set();self.close_connection=True
                try:self.connection.shutdown(0)
                except OSError:pass
    server=VoiceHTTPServer(address,Handler)
    return server

def main():
    p=argparse.ArgumentParser();p.add_argument('--host',required=True);p.add_argument('--port',type=int,default=6095);p.add_argument('--private',type=Path,required=True);p.add_argument('--model',required=True);p.add_argument('--peer');p.add_argument('--warmup',type=Path,default=Path(__file__).with_name('synthetic-warmup.pcm'));args=p.parse_args()
    if not ipaddress.ip_address(args.host).is_private:raise SystemExit('A private LAN interface is required')
    token=(args.private/'token').read_text().strip();rec=Recognizer(args.model,args.warmup);rec.warm()
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.minimum_version=ssl.TLSVersion.TLSv1_2;context.load_cert_chain(args.private/'server.pem',args.private/'server.key')
    server=make_server((args.host,args.port),token,rec,args.peer);server.tls_context=context
    print('CGS2 local voice ready; audio/text persistence disabled',flush=True)
    try:server.serve_forever(poll_interval=.5)
    except KeyboardInterrupt:pass
    finally:server.server_close()
if __name__=='__main__':main()
