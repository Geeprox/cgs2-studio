#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Generate a controlled synthetic warmup fixture on macOS; no microphone access."""
import argparse,subprocess,tempfile,wave
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--voice',default='Tingting');a=p.parse_args()
if a.output.exists():p.error('Output must not exist')
with tempfile.TemporaryDirectory(prefix='cgs2-warmup-') as t:
 t=Path(t)
 subprocess.run(['/usr/bin/say','-v',a.voice,'-o',str(t/'voice.aiff'),'这是一段用于语音模型预热的测试声音。'],check=True)
 subprocess.run(['/usr/bin/afconvert','-f','WAVE','-d','LEI16@16000','-c','1',str(t/'voice.aiff'),str(t/'voice.wav')],check=True)
 with wave.open(str(t/'voice.wav'),'rb') as source:raw=source.readframes(64000)
 if not 3200<=len(raw)<=128000:raise SystemExit('Synthetic sample duration is out of bounds')
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_bytes(raw);a.output.chmod(0o600)
print('Synthetic warmup created; no microphone was recorded')
