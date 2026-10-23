import QtQuick 2.9
import "qrc:/Main/Views/AirDatas"
Item {
 id:host
 property bool isSaver: false
 signal openRequested(string url)
 UiState { id:store }
 Loader {
  id:faceLoader
  anchors.fill:parent
  source:store.skin===100?(host.isSaver?"NativeScreenSaver.qml":"NativeAirDatasView.qml"):"Dashboard.qml?theme="+store.skin
  onLoaded: { if(store.skin!==100){item.store=store;item.isSaver=host.isSaver} }
 }
 Connections {
  target:faceLoader.item
  ignoreUnknownSignals:true
  function onOpenRequested(url) { if(host.isSaver)screenManager.closeScreenSaver();else host.openRequested(url) }
 }
 Action { x:280;y:8;width:160;height:54;visible:store.skin===100;label:"表盘";onClicked:store.chooseSkin(0) }
 Item {
  anchors.fill:parent;visible:store.skin!==100&&airdataController.isTVOCWarning;z:50
  MouseArea { anchors.fill:parent }
  TVOCWarning { anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom;anchors.bottomMargin:43;onClosed:airdataController.closeTVOCWarning() }
 }
 function restore() {}
}
