import QtQuick 2.9
Rectangle {
 id: b
 property string label: ""
 property color accent: "#ff8a32"
 property bool selected: false
 property bool night: false
 signal clicked()
 radius: 16
 color: mouse.pressed ? "#36332f" : selected ? "#332217" : "#181a1d"
 border.width: selected ? 2 : 0
 border.color: accent
 opacity: enabled ? 1 : 0.35
 Text { anchors.fill:parent;anchors.margins:8;text:b.label;color:b.selected||b.night?b.accent:"#eeeeef";font.pixelSize:24;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;wrapMode:Text.WordWrap }
 MouseArea { id:mouse;anchors.fill:parent;onClicked:b.clicked() }
 Behavior on color { ColorAnimation { duration:100 } }
}
