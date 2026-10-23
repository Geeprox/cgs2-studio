.pragma library
// One interpretation for the backdrop, precipitation and local demo. Unknown
// provider values stay empty instead of silently becoming a sunny day.
function normalized(sky){return String(sky||'').toLowerCase().replace(/[\s-]+/g,'_')}
function isNight(sky){return normalized(sky).indexOf('night')>=0}
function isOvercast(sky){var s=normalized(sky);return s==='cloudy'||s==='overcast'}
function isThunder(sky){var s=normalized(sky);return /thunder|lightning/.test(s)}
function scene(sky){
 var s=normalized(sky)
 if(!s)return 'none'
 if(/sleet/.test(s))return 'rain'
 if(/snow|hail/.test(s))return 'snow'
 if(/rain|shower|thunder|lightning/.test(s))return 'rain'
 if(/sand|dust/.test(s))return 'dust'
 if(/haze|smog/.test(s))return 'haze'
 if(/fog|mist/.test(s))return 'fog'
 if(/wind|gale/.test(s))return 'wind'
 if(/cloud|overcast/.test(s))return 'cloud'
 if(/clear|sun|fair/.test(s))return isNight(s)?'night':'sun'
 if(s==='night')return 'night'
 return 'none'
}
function precipitation(sky){var s=scene(sky);return s==='rain'||s==='snow'?s:''}
function label(sky){
 var s=scene(sky)
 if(isThunder(sky))return '雷雨'
 if(s==='cloud')return isOvercast(sky)?'阴天':isNight(sky)?'夜间多云':'多云'
 return ({sun:'晴',night:'晴夜',rain:'雨',snow:'雪',dust:'沙尘',haze:'雾霾',fog:'雾',wind:'风',none:'天气'})[s]
}
