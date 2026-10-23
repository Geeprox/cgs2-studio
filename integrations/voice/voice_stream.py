# SPDX-License-Identifier: MIT
"""Bounded PCM streaming and real hypothesis delivery; no audio/text persistence."""
from array import array
from collections import deque
import math, queue, sys, threading, time

RATE=16000
FRAME_BYTES=3200                         # 100 ms, signed little endian PCM16
MAX_STREAM_PCM=RATE*2*20                 # 20 s capture, <= 640 KB in transit
FIRST_WINDOW_BYTES=int(1.6*RATE*2)
NEXT_WINDOW_BYTES=int(1.2*RATE*2)
MAX_UTTERANCE_BYTES=6*RATE*2
TAIL_SECONDS=8

class StreamError(Exception):pass

def chunked_pcm(reader, maximum=MAX_STREAM_PCM):
    """Strict HTTP/1.1 chunk decoding; reject extensions/trailers and excess PCM."""
    total=0
    while True:
        line=reader.readline(34)
        if not line.endswith(b'\r\n') or len(line)>32:raise StreamError('invalid_chunk')
        size=line[:-2]
        if not size or any(c not in b'0123456789abcdefABCDEF' for c in size):raise StreamError('invalid_chunk')
        count=int(size,16)
        if count==0:
            if reader.readline(3)!=b'\r\n':raise StreamError('invalid_trailer')
            return
        total+=count
        if total>maximum:raise StreamError('audio_limit')
        left=count
        while left:
            block=reader.read(min(FRAME_BYTES,left))
            if not block:raise StreamError('incomplete_audio')
            left-=len(block);yield block
        if reader.read(2)!=b'\r\n':raise StreamError('invalid_chunk')

def energy(raw):
    values=array('h');values.frombytes(raw[:len(raw)//2*2])
    if sys.byteorder!='little':values.byteswap()
    if not values:return 0.0
    return math.sqrt(sum(v*v for v in values)/len(values))/32768.0

def join_text(stable,new):
    """De-duplicate a small, exact overlap without deleting single common letters."""
    stable=stable.strip();new=new.strip()
    if not new:return stable
    if not stable:return new[:1200]
    for n in range(min(60,len(stable),len(new)),1,-1):
        if stable[-n:]==new[:n]:return (stable+new[n:])[-1200:]
    return (stable+' '+new)[-1200:]

class StreamSession:
    def __init__(self,recognizer,emit,clock=time.monotonic,queue_frames=96):
        self.recognizer=recognizer;self.emit=emit;self.clock=clock
        self.frames=queue.Queue(maxsize=queue_frames)
        self.cancelled=threading.Event();self.reader_done=threading.Event()
        self.error='';self.ended_at=None;self.sequence=0
        self.received=0;self.decoded=0;self.committed='';self.partial='';self.level=0
        self.maximumQueuedFrames=0;self.windows=0;self.began=self.clock();self.lastInferenceMs=0;self.maximumInferenceMs=0;self.maximumFrameRms=0

    def receive(self,source):
        pending=bytearray()
        try:
            for block in source:
                if self.cancelled.is_set():return
                self.received+=len(block)
                if self.received>MAX_STREAM_PCM:raise StreamError('audio_limit')
                pending.extend(block)
                while len(pending)>=FRAME_BYTES:
                    self._enqueue(bytes(pending[:FRAME_BYTES]));del pending[:FRAME_BYTES]
            if len(pending)%2:raise StreamError('incomplete_audio')
            if pending:self._enqueue(bytes(pending))
        except StreamError as exc:self.error=str(exc)
        except (OSError,TimeoutError):self.error='stream_interrupted'
        finally:self.ended_at=self.clock();self.reader_done.set()

    def _enqueue(self,frame):
        try:self.frames.put(frame,timeout=.05)
        except queue.Full:raise StreamError('audio_backpressure')
        self.maximumQueuedFrames=max(self.maximumQueuedFrames,self.frames.qsize())

    def event(self,status,**extra):
        self.sequence+=1
        self.emit({'sequence':self.sequence,'status':status,'text':self.committed,'partial':self.partial,
                   'level':self.level,'speech':bool(self.committed or self.partial),
                   'metrics':{'pcmBytesReceived':self.received,'queuedFrames':self.frames.qsize(),'maximumQueuedFrames':self.maximumQueuedFrames,'recognitionWindows':self.windows,'serverElapsedMs':round((self.clock()-self.began)*1000),'lastInferenceMs':self.lastInferenceMs,'maximumInferenceMs':self.maximumInferenceMs,'maximumFrameRms':self.maximumFrameRms},**extra})

    def run(self,source):
        reader=threading.Thread(target=self.receive,args=(source,),daemon=True);reader.start()
        utterance=bytearray();pre=deque(maxlen=3);quiet=0;since=0;has_speech=False;began=self.clock();announced=False;inferred=False
        try:
            while not self.reader_done.is_set() or not self.frames.empty():
                if self.error:raise StreamError(self.error)
                if self.clock()-began>29:raise StreamError('capture_timeout')
                if self.ended_at is not None and self.clock()-self.ended_at>TAIL_SECONDS:raise StreamError('tail_timeout')
                try:frame=self.frames.get(timeout=.1)
                except queue.Empty:continue
                rms=energy(frame);self.level=min(1,rms*18);self.maximumFrameRms=max(self.maximumFrameRms,rms)
                if not announced:self.event('listening');announced=True
                # This is an energy eligibility check, not a claim of speech VAD.
                # Quiet far-field speech at RMS .002 is retained. Whisper's
                # no-speech and confidence checks make the speech decision.
                eligible=rms>=.00065
                if not has_speech:
                    if not eligible:pre.append(frame);continue
                    utterance.extend(b''.join(pre));pre.clear();has_speech=True
                utterance.extend(frame);since+=len(frame);quiet=0 if eligible else quiet+1
                final=quiet>=4 or len(utterance)>=MAX_UTTERANCE_BYTES
                first=not inferred and len(utterance)>=FIRST_WINDOW_BYTES
                if final or first and since>=FIRST_WINDOW_BYTES or inferred and since>=NEXT_WINDOW_BYTES:
                    self._recognize(bytes(utterance),final)
                    inferred=True;since=0
                    if final:
                        # No sample from the utterance is discarded: the full
                        # buffer was decoded before its memory is released.
                        if quiet<4:
                            for start in range(max(0,len(utterance)-3*FRAME_BYTES),len(utterance),FRAME_BYTES):pre.append(bytes(utterance[start:start+FRAME_BYTES]))
                        utterance.clear();has_speech=False;quiet=0;inferred=False
            if self.error:raise StreamError(self.error)
            if utterance:self._recognize(bytes(utterance),True)
            self.partial='';self.level=0;self.event('done')
        except StreamError as exc:
            self.event('error',error=str(exc))
        finally:
            self.cancelled.set()
            reader.join(timeout=.15)

    def _recognize(self,raw,final):
        if self.ended_at is not None and self.clock()-self.ended_at>TAIL_SECONDS:raise StreamError('tail_timeout')
        start=self.clock()
        self.windows+=1
        try:result=self.recognizer.transcribe(raw)
        except RuntimeError:raise StreamError('busy')
        except Exception:raise StreamError('recognition_failed')
        self.decoded+=len(raw)
        self.lastInferenceMs=round((self.clock()-start)*1000);self.maximumInferenceMs=max(self.maximumInferenceMs,self.lastInferenceMs)
        new=result.get('text','') if result.get('speech') else ''
        if final:self.committed=join_text(self.committed,new);self.partial=''
        elif new:self.partial=new[:1200]
        if self.ended_at is not None and self.clock()-self.ended_at>TAIL_SECONDS:raise StreamError('tail_timeout')
        self.event('final' if final else 'partial',processingMs=round((self.clock()-start)*1000))
