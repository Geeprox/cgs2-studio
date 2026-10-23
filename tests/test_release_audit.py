#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Privacy regressions in a temporary public export; never inspect real secrets."""
import importlib.util,os,subprocess,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('audit',ROOT/'tools/check_release.py');audit=importlib.util.module_from_spec(spec);spec.loader.exec_module(audit)
class AuditTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory(prefix='cgs2-export-test-');self.root=Path(self.tmp.name);(self.root/'README.md').write_text('Safe source')
 def tearDown(self):self.tmp.cleanup()
 def categories(self,write=False):return {f['category']for f in audit.audit(self.root,write)['findings']}
 def test_manifest_and_unlisted_file(self):
  self.assertEqual(self.categories(True),set());self.assertEqual(self.categories(),set());(self.root/'README.md').write_text('Changed');self.assertIn('manifest_mismatch',self.categories())
 def test_symlink_and_vendor_artifact(self):
  (self.root/'qml').mkdir();(self.root/'qml/native.ko').write_bytes(b'\x7fELFfixture');(self.root/'qml/link').symlink_to(self.root/'README.md');self.assertIn('symlink',self.categories(True));self.assertIn('forbidden_artifact',self.categories(True))
 def test_private_local_ignored_but_forced_git_index_rejected(self):
  private=self.root/'.local';private.mkdir();(private/'fixture.txt').write_text('ignored local fixture')
  self.assertEqual(self.categories(True),set());subprocess.run(['git','init','-q',str(self.root)],check=True)
  subprocess.run(['git','-C',str(self.root),'add','-f','.local/fixture.txt'],check=True)
  self.assertIn('private_or_missing_tracked_file',self.categories(True))
 def test_personal_path_and_unreviewed_image(self):
  (self.root/'README.md').write_text('/'+'Users'+'/fixture/private')
  (self.root/'qml').mkdir();(self.root/'qml/image.png').write_bytes(b'not a PNG')
  self.assertIn('personal_home',self.categories(True));self.assertIn('unreviewed_image',self.categories(True))
if __name__=='__main__':unittest.main()
