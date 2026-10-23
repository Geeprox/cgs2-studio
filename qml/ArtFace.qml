import QtQuick 2.9
import Qing.Snow 1.0
import 'FaceLogic.js' as F
Item{
 id:a
 property int skin:9
 property var owner:null
 property bool ownerReady:false
 onOwnerChanged:{ownerReady=false;Qt.callLater(function(){if(a.owner!==null)a.ownerReady=true})}
 property var store:null
 property bool animate:visible&&(!store||store.faceMotion!==false)&&(owner?(owner.displayActive!==undefined?owner.displayActive:owner.visible!==false)&&(owner.panel===undefined||owner.panel===''):true)
 property bool foregroundOnly:false
 property real previewTime:0
 property real primaryEmphasis:1
 onPrimaryKeyChanged:if(animate)selectionPulse.restart();else primaryEmphasis=1
 onAnimateChanged:if(!animate){selectionPulse.stop();primaryEmphasis=1}
 SequentialAnimation{id:selectionPulse;NumberAnimation{target:a;property:"primaryEmphasis";to:1.035;duration:90}NumberAnimation{target:a;property:"primaryEmphasis";to:1;duration:170}}
 readonly property string secondsMode:owner&&owner.secondsMode!==undefined?owner.secondsMode:F.secondsMode(skin,true)
 readonly property date clock:owner?owner.clock:new Date()
 readonly property string primaryKey:owner?owner.primaryKey:'airPM25'
 readonly property var primary:airdataController[primaryKey]
 readonly property var keys:F.secondary(primaryKey,0)
 readonly property color ink:skin===12||skin===10||skin===5||skin===7?'#e5ece5':'#17242b'
 readonly property string hand:marker.name
 readonly property string tech:techFont.name
 readonly property bool ready:faceLoader.item!==null&&faceLoader.item.host===a&&marker.status===FontLoader.Ready&&techFont.status===FontLoader.Ready&&(faceLoader.item.materialsReady===undefined||faceLoader.item.materialsReady)
 readonly property var fontInfo:({hand:marker.name,tech:techFont.name})
 FontLoader{id:techFont;source:"file:///usr/share/fonts/DIN_Condensed_QP.ttf"}
 FontLoader{id:marker;source:'fonts/PermanentMarker-Regular.ttf'}
 function dateLabel(){return Qt.formatDate(clock,'MM.dd')+'  '+['周日','周一','周二','周三','周四','周五','周六'][clock.getDay()]}
 function label(k){return k==='airCO2'?'CO<sub>2</sub>':F.label(k)}
 function value(k){var s=airdataController[k];return s&&s.state!==AirState.PreparingState?s.valueString:'—'}
 function unit(k){var s=airdataController[k];return s?s.unitString:''}
 function ratio(k){return F.ratio(k,airdataController[k])}
 function range(k){return F.range(k,airdataController[k])}
 function choose(k){global.currentSensorNameOfDataPage=k}
 function history(){if(owner)owner.history()}
 function interactionState(){return faceLoader.item&&faceLoader.item.interactionState?faceLoader.item.interactionState():{}}
 function diagnostics(){return {waterPaints:faceLoader.item&&faceLoader.item.waterPaints!==undefined?faceLoader.item.waterPaints:0}}
 readonly property var samples:store&&store.historyData&&store.historyData[primaryKey]?store.historyData[primaryKey]:[]
 Loader{id:faceLoader;anchors.fill:parent;active:a.ownerReady;source:a.skin===5?'ArtOrbit.qml':a.skin===7?'PoolFace.qml':a.skin===9?'ArtComic.qml':a.skin===10?'ArtLumen.qml':a.skin===11?'ArtPoster.qml':'ArtOrbit.qml';onLoaded:item.host=a}
}
