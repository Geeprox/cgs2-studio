# SPDX-License-Identifier: MIT
"""Locally transform three pinned Qt resources; never distribute OEM resources."""
import hashlib, struct, zlib

ORIGINAL='1c6043a24298812401fd45678ef5c1869a9f36815330fab32ef9da8107c918ac'
QRC_PROFILE='5892cbc1e82ff70c1282219a805b1747d54893004998b5527e872b24f7b60309'
RESOURCES=[
 ('NativeAirDatasView.qml',2500930,1571,True,'78e5146ea5106046bcfd92fdb1d9fe36c51621b107360ab943eadad86fd7a152',False),
 ('NativeScreenSaver.qml',2276100,824,False,'0adc0fefc96b354d93ecdb6af9f0cdecf9d49468284e41aeb4a3c636ff2341d5',True),
 ('WiFiPage.qml',2419581,2214,False,'28c677e3f81fdb4b9f8d74d8c75164f19ed2a912e90f62a82e9d2b8f76fd1df7',False),
]

def digest(data):return hashlib.sha256(data).hexdigest()

def wifi_controls(original):
    # Reuse only the imports/page properties from the owner's firmware. Replace
    # the loading-only stack with a controls page that can refresh an empty scan.
    prefix=original.decode().split('    initialItem:',1)[0]
    return (prefix+'''
    // Keep the existing controls reachable when a scan returns no networks.
    initialItem: wifiIndexPage

    Component {
        id: wifiIndexPage
        WiFiIndexPage {
            id: index
            title: control.title
            showTurnOffSwitch: control.showTurnOffSwitch
            onShowLoading: {
                if (wifiManager.wlanEnabled) {
                    wifiManager.refreshWiFi()
                }
            }
            onDepthChanged: control.isIndex = mainStackView.depth <= 1
            onExited: control.exited()
            onVisibleChanged: {
                if (visible && wifiManager.wlanEnabled) {
                    wifiManager.refreshWiFi()
                }
            }
        }
    }
    Component.onCompleted: {
        if (wifiManager.wlanEnabled) {
            wifiManager.refreshWiFi()
        }
        console.info("CGS2 WiFi UI: network controls stay available during scans")
    }
}
''').encode()

def prepare(data):
    if digest(data)!=ORIGINAL:raise ValueError('Unsupported factory application')
    out=bytearray(data);native={};allowed=set()
    for name,start,budget,compressed,expected,saver in RESOURCES:
        if struct.unpack_from('>I',data,start-4)[0]!=budget:raise ValueError('Resource length mismatch')
        raw=data[start:start+budget]
        decoded=zlib.decompress(raw[4:]) if compressed else raw
        if digest(decoded)!=expected:raise ValueError('Resource content mismatch')
        if name=='WiFiPage.qml':hook=wifi_controls(decoded)
        else:
            native[name]=decoded
            hook=('import QtQuick 2.9\nItem {\n Loader { id:l;anchors.fill:parent;source:"file:///userdata/cgs2-ui/qml/FaceHost.qml";onLoaded:item.isSaver='+str(saver).lower()+' }\n Connections { target:l.item;ignoreUnknownSignals:true;function onOpenRequested(url) { '+('screenManager.closeScreenSaver()' if saver else 'openPage(url)')+' } }\n function restore() {}\n}\n').encode()
        encoded=struct.pack('>I',len(hook))+zlib.compress(hook,9) if compressed else hook
        if len(encoded)>budget:raise ValueError('Replacement exceeds fixed resource budget')
        out[start-4:start]=struct.pack('>I',len(encoded))
        out[start:start+budget]=encoded+bytes(budget-len(encoded))
        allowed.update(range(start-4,start+budget))
    # Reproducible resource modification stamps invalidate the Qt disk cache.
    for offset in [2259746,2262210,2265048]:
        out[offset:offset+8]=bytes.fromhex('000001a15f597adf');allowed.update(range(offset,offset+8))
    if len(out)!=len(data) or any(a!=b and i not in allowed for i,(a,b)in enumerate(zip(data,out))):raise ValueError('Unexpected change outside Qt resources')
    if digest(out)!=QRC_PROFILE:raise ValueError('Resource candidate differs from supported profile: '+digest(out))
    return bytes(out),native
