import QtQuick 2.9
import Qing.Snow 1.0
import "SensorLogic.js" as Logic
Item {
 id:c
 property var sensor
 property string sensorKey:""
 property color tint:"#ff8a32"
 property bool compact:false
 property bool night:false
 readonly property bool preparing:!sensor||sensor.state===AirState.PreparingState
 readonly property string kind:Logic.kind(sensorKey)
 signal clicked()
 Rectangle { anchors.fill:parent;radius:18;color:hit.pressed?"#24272b":"#030405" }
 Text { x:10;y:0;width:170;height:27;text:c.sensor?c.sensor.name:"--";color:c.night?c.tint:"#c6cbd3";font.pixelSize:23;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter }
 Text { x:8;y:27;width:174;height:51;text:c.preparing?"--":c.sensor.valueString;color:c.night?c.tint:"#f5f6f7";font.pixelSize:46;font.weight:Font.Medium;fontSizeMode:Text.Fit;minimumPixelSize:34;verticalAlignment:Text.AlignVCenter }
 Text { x:10;y:79;width:174;height:25;text:c.sensor?(c.sensor.unitString+(c.kind==="comfort"&&!c.preparing?"  "+c.sensor.evalutionDescription:"")):"";color:c.night?"#dd4036":"#aeb5bf";font.pixelSize:18;elide:Text.ElideRight;verticalAlignment:Text.AlignVCenter }
 QualityBand { x:10;y:107;width:169;height:5;visible:c.kind!=="comfort"&&!c.preparing;sensor:c.sensor;night:c.night }
 Rectangle { x:170;y:10;width:8;height:8;radius:4;visible:c.kind==="comfort"&&!c.preparing;color:c.night?c.tint:(c.sensor?c.sensor.evalutionColor:"#707780") }
 MouseArea { id:hit;anchors.fill:parent;onClicked:c.clicked() }
}
