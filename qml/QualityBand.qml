import QtQuick 2.9
import Qing.Snow 1.0
import "SensorLogic.js" as Logic
Item {
 id:band
 property var sensor
 property bool night:false
 readonly property var grades:Logic.categories(sensor)
 readonly property int activeIndex:Logic.gradeIndex(sensor,AirState.PreparingState)
 visible:grades.length>1
 Repeater {
  model:band.grades
  Rectangle { x:index*(band.width/band.grades.length);width:band.width/band.grades.length-4;height:band.height;radius:height/2;color:band.night?"#ff453a":modelData.tint;opacity:index===band.activeIndex?1:.22 }
 }
}
