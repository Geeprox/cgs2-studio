# SPDX-License-Identifier: MIT
"""Small ADB transport with remote exit-status verification."""
import re,shlex,shutil,subprocess
ORIGINAL="1c6043a24298812401fd45678ef5c1869a9f36815330fab32ef9da8107c918ac"
FINAL="91e0fc422f77f70e024bf9571a5bc395849eaeeb21c7c2a3c3973a49d8d7d8b7"
class Device:
 def __init__(self,serial=None,adb=None):
  self.adb=adb or shutil.which("adb") or "adb"
  devices=[p[0] for row in self.run(["devices"]).splitlines()[1:] if len(p:=row.split())>=2 and p[1]=="device"]
  if serial is None:
   if len(devices)!=1:raise ValueError("Connect exactly one device, or specify --serial")
   serial=devices[0]
  if serial not in devices:raise ValueError("Selected device is not connected/authorized")
  self.serial=serial
 def run(self,args,timeout=30):
  p=subprocess.run([self.adb,*args],capture_output=True,text=True,timeout=timeout)
  if p.returncode:raise RuntimeError("ADB operation failed; inspect connection locally")
  return p.stdout.replace("\r","")
 def shell(self,command,timeout=30):
  output=self.run(["-s",self.serial,"shell","("+command+"); cgs2_rc=$?; printf '\nCGS2_RC=%s\n' \"$cgs2_rc\""],timeout)
  m=re.search(r"\nCGS2_RC=(\d+)\n?$",output)
  if not m or m[1]!="0":raise RuntimeError("Remote operation failed or incomplete")
  return output[:m.start()].strip()
 def pull(self,source,target):return self.run(["-s",self.serial,"pull",source,str(target)],180)
 def push(self,source,target):return self.run(["-s",self.serial,"push",str(source),target],180)
 def inspect(self):
  values=self.shell("uname -m; uname -r; id -u; sha256sum /qingping/bin/QingSnow2App | cut -d ' ' -f1").splitlines()
  if len(values)!=4 or values[:3]!=["aarch64","4.19.232","0"]:raise ValueError("Unsupported device: require CGS2 aarch64 Linux 4.19.232 root ADB")
  if values[3]not in [ORIGINAL,FINAL]:raise ValueError("Unsupported application SHA; no write performed")
  self.sha=values[3]
  return {"architecture":values[0],"kernel":values[1],"root":True,"profile":"CGS2 4.5.6_0167","application":"factory" if self.sha==ORIGINAL else "studio-0.1.0","sensitiveValuesPrinted":False}
