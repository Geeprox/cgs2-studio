import QtQuick 2.9
import 'SpatialProjection.js' as Space
import 'FaceLayout.js' as Layout
Item{
 id:p;width:720;height:720
 property Item depthHost:null
 property Item readingHost:null
 property bool dragging:false
 property var view:({yaw:0,pitch:0})
 property var host
 property var spec:Space.primary
 property string numberFont:'Roboto'
 property string sensorKey:''
 property bool primary:false
 property bool clockPlane:false
 property string displayText:''
 readonly property string readingText:displayText!==''?displayText:host?host.value(sensorKey):''
 readonly property var zones:Space.readingRects(spec)
 readonly property real strokeWeight:spec.strokeWeight||1.2
 readonly property real echoWeight:spec.echoWeight||.8
 readonly property var render:Space.renderBundle(spec,view)
 property point pointerStart:Qt.point(0,0)
 signal chosen()
 signal grabbed()
 signal moved(real dx,real dy)
 signal dropped()
 function projection(layer){var m=render.matrices[layer]||render.matrices[0];return Qt.matrix4x4(m[0],m[1],m[2],m[3],m[4],m[5],m[6],m[7],m[8],m[9],m[10],m[11],m[12],m[13],m[14],m[15])}
 function rail(corner){return render.rails[corner]}
 function fontSize(role){if(role==='label')return primary?28:Math.max(19,24*spec.w/194);if(role==='unit')return primary?19:Math.max(16,18*spec.w/194);return primary?158:clockPlane?(spec.kind==='seconds'?52:111):Math.max(54,72*spec.w/194)}
 // All wire structures live below every reading, so another plate's depth
 // lines can cross the scene without crossing the letters in front of them.
 Item{
  parent:p.depthHost||p;width:720;height:720;visible:p.visible;z:-p.render.depth
  Repeater{model:Space.layerCount(p.spec)
   Item{width:p.spec.w;height:p.spec.h;z:-index;transform:Matrix4x4{matrix:p.projection(index)}
    Rectangle{anchors.fill:parent;color:'transparent';antialiasing:true;border.width:index===0?p.strokeWeight:p.echoWeight;border.color:index===0?(p.primary||p.clockPlane?'#e4eee0':'#a8bda9'):'#6e8675';opacity:index===0?1:.78-index*.11}
   }
  }
  Repeater{model:4
   Rectangle{x:p.rail(index).x;y:p.rail(index).y;width:p.rail(index).length;height:Math.max(.65,p.echoWeight*.85);rotation:p.rail(index).angle;transformOrigin:Item.TopLeft;color:p.primary||p.clockPlane?'#91a68f':'#647d69';opacity:.82;antialiasing:true}
  }
 }
 Item{
  parent:p.readingHost||p;width:p.spec.w;height:p.spec.h;visible:p.visible;z:p.dragging?3000:p.primary?2000:-p.render.depth
  transform:Matrix4x4{matrix:p.projection(0)}
  Repeater{model:p.zones
   Rectangle{x:modelData.x-2;y:modelData.y-2;width:modelData.w+4;height:modelData.h+4;color:'#0d1010';opacity:.98}
  }
  Repeater{model:p.zones
   ArtText{x:modelData.x;y:modelData.y;width:modelData.w;height:modelData.h
    text:modelData.role==='value'?p.readingText:p.host?(modelData.role==='label'?p.host.label(p.sensorKey):p.host.unit(p.sensorKey)):''
    font.family:modelData.role==='value'?p.numberFont:'Source Han Sans CN';font.pixelSize:p.fontSize(modelData.role);fontSizeMode:Text.Fit;minimumPixelSize:modelData.role==='value'?(p.primary?74:32):15
    color:modelData.role==='value'&&(p.primary||p.clockPlane)?'#0d1010':modelData.role==='value'?'#e5efdf':'#b4c7b1'
    style:modelData.role==='value'&&(p.primary||p.clockPlane)?Text.Outline:Text.Normal;styleColor:'#ecf4e3';horizontalAlignment:Text.AlignHCenter
    scale:modelData.role==='value'&&p.primary&&p.host?Math.min(1.02,p.host.primaryEmphasis):1
   }
  }
  Repeater{model:p.clockPlane?[]:p.zones
   MouseArea{objectName:'perspective-touch-'+p.sensorKey+(modelData.role==='value'?'':'-'+modelData.role);x:modelData.x-2;y:modelData.y-2;width:modelData.w+4;height:modelData.h+4;preventStealing:true;propagateComposedEvents:false
    onPressed:{p.pointerStart=mapToItem(p.parent,mouse.x,mouse.y);p.dragging=false;mouse.accepted=true}
    onPositionChanged:{if(!pressed)return;var q=mapToItem(p.parent,mouse.x,mouse.y),dx=q.x-p.pointerStart.x,dy=q.y-p.pointerStart.y;if(!p.dragging&&Layout.distance(dx,dy)<10)return;if(!p.dragging){p.dragging=true;p.grabbed()}p.moved(dx,dy)}
    onReleased:{if(p.dragging){p.dragging=false;p.dropped()}else p.chosen()}
    onCanceled:{if(p.dragging){p.dragging=false;p.dropped()}}
   }
  }
 }
}
