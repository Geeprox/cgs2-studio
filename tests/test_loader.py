# SPDX-License-Identifier: MIT
"""Exercise the actual boot selector with isolated filesystem and stubbed insmod."""
import os, pathlib, subprocess, tempfile, time
loader = (pathlib.Path(__file__).resolve().parents[1]/'driver/skw_insmod.sh').read_text()
results = []
for case in ['original', 'trial', 'enabled', 'unconfirmed', 'bad-hash', 'load-failed']:
    with tempfile.TemporaryDirectory(prefix='cgs2-loader-') as temp:
        base = pathlib.Path(temp); root = base/'state'; root.mkdir(); bindir = base/'bin'; bindir.mkdir()
        for name, code in {
            'insmod': '#!/bin/sh\necho "$1" >> "$CALLS"\ncase "$1" in *skw-lock-order-v1.ko) [ "$CASE" != load-failed ];; *) exit 0;; esac\n',
            'sha256sum': '#!/bin/sh\nif [ "$CASE" = bad-hash ];then echo wrong;else echo d88d8f8e807162a681201d04391b38cac139239b23f035e97d909547f1ee2ffa;fi\n'
        }.items():
            p=bindir/name; p.write_text(code);p.chmod(0o700)
        (root/'skw-lock-order-v1.ko').write_bytes(b'isolated-stub')
        if case=='trial':(root/'trial.once').touch()
        if case in ['enabled','unconfirmed','bad-hash','load-failed']:(root/'enabled').touch()
        if case=='unconfirmed':(root/'boot-pending').touch()
        actual=loader.replace('ROOT=/userdata/cgs2-wifi-rea', 'ROOT='+str(root))
        # Test boot selection, not the delayed 90-second health subprocess.
        actual=actual.replace('if [ "$mode" = enabled ];then', 'if false;then')
        p=base/'loader.sh';p.write_text(actual)
        env=dict(os.environ,PATH=str(bindir)+':'+os.environ['PATH'],CASE=case,CALLS=str(base/'calls'))
        subprocess.run(['/bin/sh',str(p)],check=True,env=env,capture_output=True)
        calls=(base/'calls').read_text().splitlines()
        status=(root/'load-status').read_text().strip()
        original='/system/lib/modules/skw.ko'
        if case in ['original','unconfirmed','bad-hash']:assert calls[-1]==original,(case,calls)
        if case in ['trial','enabled']:assert calls[-1].endswith('skw-lock-order-v1.ko')
        if case=='load-failed':assert calls[-2].endswith('skw-lock-order-v1.ko') and calls[-1]==original
        if case=='trial':assert not (root/'trial.once').exists()
        if case in ['unconfirmed','bad-hash','load-failed']:assert not (root/'enabled').exists()
        results.append({'case':case,'result':'pass','status':status})
import json

print(json.dumps(results,indent=2))
