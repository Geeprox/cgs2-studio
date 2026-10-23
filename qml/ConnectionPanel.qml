import QtQuick 2.9
Rectangle {
 id:p;color:"#08090b"
 property var store
 property bool confirmReboot:false
 property color accent:"#ff8a32"
 signal closed()
 signal openRequested(string url)
 Text { x:110;y:35;width:460;height:50;text:"连接与时间";color:"#f4f5f6";font.pixelSize:35 }
 Action { x:24;y:30;width:72;height:60;label:"‹";onClicked:p.closed() }
 Text { x:48;y:141;width:624;height:42;text:p.store&&p.store.recovery.message?p.store.recovery.message:"正在读取连接状态";color:p.accent;font.pixelSize:30;wrapMode:Text.WordWrap }
 Text { x:48;y:205;width:624;height:76;text:"恢复连接会保留已存网络。连接不到路由器时，也可以返回设置。";color:"#a1a7b1";font.pixelSize:24;wrapMode:Text.WordWrap }
 Action { x:48;y:310;width:624;height:76;label:p.store&&p.store.recovery.phase==="kernel-blocked"?(p.confirmReboot?"再次轻点确认重启 · 保留配置":"重启设备恢复 Wi-Fi"):p.store&&p.store.recovery.phase==="recovering"?"正在恢复…":"恢复 Wi-Fi 连接";enabled:!(p.store&&["recovering","disabled"].indexOf(p.store.recovery.phase)>=0);onClicked:{if(p.store.recovery.phase==="kernel-blocked"){if(p.confirmReboot)p.store.rebootForWifi();else{p.confirmReboot=true;resetConfirm.restart()}}else p.store.recover()} }
 Timer{id:resetConfirm;interval:5000;onTriggered:p.confirmReboot=false}
 Action { x:48;y:404;width:624;height:76;label:"Wi-Fi 设置";onClicked:p.openRequested("qrc:/Modules/WiFi/WiFiPage.qml") }
 Rectangle { x:48;y:520;width:624;height:1;color:"#2a2e35" }
 Text { x:48;y:551;width:624;height:40;text:p.store&&p.store.online?"Micro 局域网在线":"Micro 局域网未连接";color:"#f0f1f2";font.pixelSize:26 }
 Text { x:48;y:608;width:624;height:78;text:"日常运行仅需供电与 Wi-Fi。联网后使用系统网络校时；局域网动作不会自动重试。";color:"#838a95";font.pixelSize:23;wrapMode:Text.WordWrap }
}
