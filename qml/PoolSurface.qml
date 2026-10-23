import QtQuick 2.14
import QtQuick.Window 2.2
import 'PoolWater.js' as Water
Item {
 id:s
 property bool running:true
 property real fixedTime:0
 property int paintedFrames:0
 property int phaseTicks:0
 property real phase:Water.wrapTime(fixedTime)
 clip:true
 readonly property bool active:running&&visible
 readonly property bool materialsReady:pool.status===Image.Ready&&a.status===Image.Ready&&b.status===Image.Ready
 readonly property var flow:Water.motion(phase)
 readonly property real waterExtent:Water.surfaceExtent(width,height)
 // Three permanent textures: surface highlights cover the entire viewport, including
 // the still pool walls. Overscan keeps their transparent image edges off screen.
 Image{id:pool;anchors.fill:parent;source:'water/pool-still-v4.png';asynchronous:true}
 Image{id:a;x:(s.width-width)/2+s.flow.ax*s.width/720;y:(s.height-height)/2+s.flow.ay*s.height/720;width:s.waterExtent;height:s.waterExtent;scale:s.flow.as;opacity:s.flow.ao;source:'water/caustics-a-v4.png';asynchronous:true;smooth:true}
 Image{id:b;x:(s.width-width)/2+s.flow.bx*s.width/720;y:(s.height-height)/2+s.flow.by*s.height/720;width:s.waterExtent;height:s.waterExtent;scale:s.flow.bs;opacity:s.flow.bo;source:'water/caustics-b-v4.png';asynchronous:true;smooth:true}
 Timer{interval:66;running:s.active&&s.materialsReady;repeat:true;onTriggered:{s.phase=Water.wrapTime(s.phase+.066);s.phaseTicks++}}
 Connections{target:s.Window.window;ignoreUnknownSignals:true;function onFrameSwapped(){if(s.active)s.paintedFrames++}}
 onFixedTimeChanged:phase=Water.wrapTime(fixedTime)
}
