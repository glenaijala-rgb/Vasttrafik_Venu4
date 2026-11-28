import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Position;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

function nowSeconds() { return Time.now().value(); }
function minutesUntil(t) {
    if (t == null) { return "?"; }
    var m=Math.ceil((t-nowSeconds())/60.0).toNumber();
    return m<0?"Passerad":m.toString();
}
function clockText(t) {
    if (t == null) { return "--:--"; }
    var d = Gregorian.info(new Time.Moment(t), Time.FORMAT_SHORT);
    return d.hour.format("%02d") + ":" + d.min.format("%02d");
}
function clipText(dc,s,font,maxW) {
    if (s == null) { return ""; }
    var a = s.toString();
    if (dc.getTextWidthInPixels(a,font)<=maxW) { return a; }
    while (a.length()>1 && dc.getTextWidthInPixels(a+"…",font)>maxW) {
        a=a.substring(0,a.length()-1);
    }
    return a+"…";
}
class TransitApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        var v=new TransitView();
        return [v,new TransitDelegate(v)];
    }
    function getGlanceView() { return [new TransitGlance()]; }
}
class TransitGlance extends WatchUi.GlanceView {
    function initialize() { GlanceView.initialize(); }
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK); dc.clear();
        var w=dc.getWidth();var h=dc.getHeight();
        var cache=Storage.getValue("dep_home");
        var rows=[];
        if (cache != null && nowSeconds()-cache["generatedEpoch"]<=180) {
            var all=cache["departures"];
            for(var i=0;i<all.size() && rows.size()<2;i++){
                if(!all[i]["isCancelled"] && all[i]["departureEpoch"]>=nowSeconds()){
                    rows.add(all[i]);
                }
            }
        }
        dc.drawText(w/2,2,Graphics.FONT_XTINY,"Hem",Graphics.TEXT_JUSTIFY_CENTER);
        if(rows.size()==0){
            dc.drawText(w/2,h/2,Graphics.FONT_TINY,"Öppna för avgångar",Graphics.TEXT_JUSTIFY_CENTER|Graphics.TEXT_JUSTIFY_VCENTER);return;
        }
        for(var j=0;j<rows.size();j++){
            var x=rows.size()==1?w/2:(j==0?w/4:3*w/4);
            dc.drawText(x,h*0.31,Graphics.FONT_MEDIUM,rows[j]["line"],Graphics.TEXT_JUSTIFY_CENTER);
            dc.drawText(x,h*0.66,Graphics.FONT_SMALL,minutesUntil(rows[j]["departureEpoch"])+" min",Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
class TransitView extends WatchUi.View {
    var page=0; // 0 Hem, 1 Jobb, 2 Åk hem
    var profileIds=["home","work"];
    var profileLabels=["Hem","Jobb"];
    var active=false;
    var timer;
    var gpsTimer;
    var gpsActive=false;
    var nextRefresh=0;
    var busy=false;
    var requestPage=0;
    var requestGeneration=0;
    var generation=0;
    var requestKind="";
    var response=null;
    var rows=[];
    var status="";
    var source="";
    var manualKey=null;
    var manualLabel="";
    var fix=null;
    var fixTime=0;
    var offset=0;
    var details=null;
    var originChoices=[];
    var pendingSearch=null;
    var retryAfter=0;
    function initialize(){
        View.initialize();
        timer=new Timer.Timer();
        gpsTimer=new Timer.Timer();
    }
    function onShow(){
        active=true;
        timer.start(method(:tick),1000,true);
        if(page!=2){loadCache();}
        nextRefresh=0; tick();
    }
    function onHide(){
        active=false;timer.stop();stopGps();
    }
    function loadCache(){
        response=Storage.getValue("dep_"+profileIds[page]);
        rows=response==null?[]:response["departures"];
    }
    function stopGps(){
        if(gpsActive){
            gpsActive=false;gpsTimer.stop();
            try{Position.enableLocationEvents(Position.LOCATION_DISABLE,null);}catch(e){}
        }
    }
    function switchPage(p){
        stopGps();page=p;generation++;offset=0;details=null;response=null;rows=[];status="";
        if(page<2){loadCache();}else{manualKey=null;source="";}
        nextRefresh=0;tick();
    }
    function tick(){
        if(!active){return;}
        if(pendingSearch!=null && !busy){
            var q=pendingSearch;pendingSearch=null;
            send("/api/v1/origins/search",{"q"=>q},"origins");
            return;
        }
        if(details==null && nowSeconds()>=nextRefresh && nowSeconds()>=retryAfter && !busy && !gpsActive){
            nextRefresh=nowSeconds()+60;
            refresh();
        }
        WatchUi.requestUpdate();
    }
    function forceRefresh(){
        details=null;offset=0;nextRefresh=0;
        if(!busy&&!gpsActive){tick();}
    }
    function acceptFix(info,maxAge){
        if(info==null||info.position==null||info.when==null||info.accuracy<Position.QUALITY_LAST_KNOWN){return false;}
        var age=nowSeconds()-info.when.value();
        if(age<0||age>maxAge){return false;}
        fix=info.position.toDegrees();fixTime=info.when.value();
        source=(age<=60&&info.accuracy>=Position.QUALITY_USABLE)?"GPS":"Senast känd";
        return true;
    }
    function refresh(){
        if(page<2){send("/api/v1/departures",{"profile"=>profileIds[page]},"departures");return;}
        if(manualKey!=null){
            source=manualLabel;send("/api/v1/journeys/home",{"originKey"=>manualKey},"journeys");return;
        }
        // Fresh/cached position first; never use an undated fix.
        var info=Position.getInfo();
        if(acceptFix(info,120)){requestJourney();return;}
        if(fix!=null && nowSeconds()-fixTime<=120){source="Senast känd";requestJourney();return;}
        status="Söker position…";gpsActive=true;
        try {
            Position.enableLocationEvents(Position.LOCATION_ONE_SHOT,method(:onPosition));
            gpsTimer.start(method(:gpsTimeout),20000,false);
        } catch(e) {gpsTimeout();}
    }
    function onPosition(info){
        if(!active||page!=2||!gpsActive){return;}
        if(info!=null && info.accuracy>=Position.QUALITY_USABLE && acceptFix(info,60)){
            stopGps();requestJourney();
        }
    }
    function gpsTimeout(){
        stopGps();
        if(!active||page!=2){return;}
        if(acceptFix(Position.getInfo(),300) || (fix!=null && nowSeconds()-fixTime<=300)){
            source="Senast känd";requestJourney();
        }else{status="Ingen position. Välj start.";rows=[];response=null;WatchUi.requestUpdate();}
    }
    function requestJourney(){
        send("/api/v1/journeys/home",{"lat"=>fix[0],"lon"=>fix[1]},"journeys");
    }
    function chooseOrigin(){
        if(busy){status="Hämtar… försök igen";return;}
        stopGps();send("/api/v1/origins",{},"origins");
    }
    function setOrigin(key,label){
        generation++;manualKey=key;manualLabel=label;details=null;rows=[];response=null;offset=0;
        nextRefresh=0;
    }
    function send(path,params,kind){
        if(busy){nextRefresh=0;return;}
        var url=Application.Properties.getValue("backendUrl");
        var key=Application.Properties.getValue("accessToken");
        if(url==null||key==null||url.length()<9||!url.substring(0,8).equals("https://")||key.length()<32){
            status="Ange server och nyckel";return;
        }
        if(url.substring(url.length()-1,url.length()).equals("/")){url=url.substring(0,url.length()-1);}
        busy=true;requestPage=page;requestKind=kind;requestGeneration=generation;status="Hämtar…";
        try{
            Communications.makeWebRequest(url+path,params,
            {:method=>Communications.HTTP_REQUEST_METHOD_GET,:headers=>{"Authorization"=>"Bearer "+key},:responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON},method(:onResponse));
        }catch(e){busy=false;status="Nätverksfel";}
    }
    function onResponse(code,data){
        busy=false;
        if(requestGeneration!=generation||requestPage!=page){return;}
        if(!active){return;}
        if(code!=200||!(data instanceof Lang.Dictionary)){
            status=code==429?"Vänta, trafikgräns":code==503?"Konfiguration saknas":code==401?"Fel åtkomstnyckel":"Ingen anslutning";
            if(code==429){retryAfter=nowSeconds()+120;}
            WatchUi.requestUpdate();return;
        }
        if(requestKind.equals("origins")){
            originChoices=data["origins"];
            var menu=new WatchUi.Menu2({:title=>"Startplats"});
            menu.addItem(new WatchUi.MenuItem("Automatisk GPS",null,"gps",{}));
            if(WatchUi has :TextPicker){menu.addItem(new WatchUi.MenuItem("Sök hållplats",null,"search",{}));}
            for(var i=0;i<originChoices.size();i++){
                menu.addItem(new WatchUi.MenuItem(originChoices[i]["label"],null,originChoices[i]["key"],{}));
            }
            status="";WatchUi.pushView(menu,new OriginDelegate(self),WatchUi.SLIDE_UP);return;
        }
        var list=requestKind.equals("journeys")?data["journeys"]:data["departures"];
        if(!(list instanceof Lang.Array)||data["generatedEpoch"]==null){status="Ogiltigt svar";return;}
        response=data;rows=list;status="";
        if(offset>=rows.size()){offset=0;}
        if(page<2){try{Storage.setValue("dep_"+profileIds[page],data);}catch(e){}}
        WatchUi.requestUpdate();
    }
    function showText(dc,x,y,font,s,maxW,color){
        dc.setColor(color,Graphics.COLOR_BLACK);
        dc.drawText(x,y,font,clipText(dc,s,font,maxW),Graphics.TEXT_JUSTIFY_CENTER);
    }
    function onUpdate(dc){
        var w=dc.getWidth();var h=dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE,Graphics.COLOR_BLACK);dc.clear();
        var title=page==2?"Åk hem":profileLabels[page];
        showText(dc,w/2,h*0.09,Graphics.FONT_MEDIUM,title,w*0.65,Graphics.COLOR_WHITE);
        var stale=response!=null && nowSeconds()-response["generatedEpoch"]>180;
        var note=status;
        if(stale){note="Gamla data";}
        else if(note.equals("")&&page==2){note=source;}
        else if(note.equals("")&&response!=null){note="Uppd "+clockText(response["generatedEpoch"]);}
        showText(dc,w/2,h*0.205,Graphics.FONT_XTINY,note,w*0.78,Graphics.COLOR_LT_GRAY);
        if(details!=null){drawDetails(dc,w,h);}
        else if(rows.size()==0){
            showText(dc,w/2,h*0.42,Graphics.FONT_SMALL,status.equals("")?"Inga förslag":"",w*0.8,Graphics.COLOR_WHITE);
        }else{
            var count=page==2?2:3;
            for(var i=0;i<count && offset+i<rows.size();i++){
                var r=rows[offset+i];var y=h*(0.28+i*(page==2?0.23:0.16));
                var main=page==2?r["line"]+"  "+minutesUntil(r["departureEpoch"])+" min":r["line"]+"  "+(r["isCancelled"]?"Inställd":minutesUntil(r["departureEpoch"])+" min");
                showText(dc,w/2,y,Graphics.FONT_MEDIUM,main,w*0.76,stale?Graphics.COLOR_LT_GRAY:Graphics.COLOR_WHITE);
                var sub=page==2?"Från "+r["boardStop"]:r["stationLabel"]+" · "+r["destination"];
                showText(dc,w/2,y+h*0.08,Graphics.FONT_XTINY,sub,w*0.78,Graphics.COLOR_LT_GRAY);
                if(page==2){
                    var walk=r["walkMeters"]==null?"":r["walkMeters"].toString()+" m · ";
                    showText(dc,w/2,y+h*0.145,Graphics.FONT_XTINY,walk+r["changes"].toString()+" byte · framme "+clockText(r["arrivalEpoch"]),w*0.84,Graphics.COLOR_LT_GRAY);
                }
            }
        }
        var left=details!=null?"Tillbaka":(page==2?"Start":"Hållplats");
        var right=page==2?"Hem/Jobb":"Åk hem";
        showText(dc,w*0.29,h*0.83,Graphics.FONT_TINY,left,w*0.44,Graphics.COLOR_WHITE);
        showText(dc,w*0.72,h*0.83,Graphics.FONT_TINY,right,w*0.45,Graphics.COLOR_WHITE);
        
    }
    function drawDetails(dc,w,h){
        var steps=details["steps"];
        for(var i=0;i<2 && offset+i<steps.size();i++){
            var s=steps[offset+i];var y=h*(0.30+i*0.24);
            var main=s["kind"].equals("walk")?"Gå":s["line"]+" "+clockText(s["departureEpoch"]);
            if(s["kind"].equals("walk")&&s["meters"]!=null){main+=" "+s["meters"].toString()+" m";}
            showText(dc,w/2,y,Graphics.FONT_SMALL,main,w*0.8,Graphics.COLOR_WHITE);
            showText(dc,w/2,y+h*0.08,Graphics.FONT_XTINY,s["from"]+" → "+s["to"],w*0.84,Graphics.COLOR_LT_GRAY);
            showText(dc,w/2,y+h*0.14,Graphics.FONT_XTINY,"Framme "+clockText(s["arrivalEpoch"]),w*0.8,Graphics.COLOR_LT_GRAY);
        }
    }
    function scroll(delta){
        var list=details==null?rows:details["steps"];
        offset=offset+delta;
        if(offset>=list.size()){offset=list.size()-1;}
        if(offset<0){offset=0;}
        WatchUi.requestUpdate();
    }
    function tap(x,y,w,h){
        if(y<h*0.25){forceRefresh();return true;}
        if(y>h*0.79){
            if(x<w/2){
                if(details!=null){details=null;offset=0;}
                else if(page==2){chooseOrigin();}else{switchPage(1-page);}
            }else{switchPage(page==2?0:2);}
            WatchUi.requestUpdate();return true;
        }
        if(page==2&&details==null){
            var i=offset+(y>=h*0.51?1:0);
            if(i<rows.size()){details=rows[i];offset=0;WatchUi.requestUpdate();}
        }else{scroll(1);}
        return true;
    }
}
class TransitDelegate extends WatchUi.BehaviorDelegate {
    var view;
    function initialize(v){BehaviorDelegate.initialize();view=v;}
    function onTap(evt){
        var xy=evt.getCoordinates();
        var settings=System.getDeviceSettings();
        return view.tap(xy[0],xy[1],settings.screenWidth,settings.screenHeight);
    }
    function onSwipe(evt){
        if(evt.getDirection()==WatchUi.SWIPE_UP){view.scroll(1);return true;}
        if(evt.getDirection()==WatchUi.SWIPE_DOWN){view.scroll(-1);return true;}
        return false;
    }
    function onSelect(){view.forceRefresh();return true;}
    function onBack(){if(view.details!=null){view.details=null;view.offset=0;WatchUi.requestUpdate();return true;}if(view.page==2){view.switchPage(0);return true;}return false;}
}
class OriginDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    function initialize(v){Menu2InputDelegate.initialize();view=v;}
    function onSelect(item){
        var id=item.getId();
        if(id.equals("search")){
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            WatchUi.pushView(new WatchUi.TextPicker(""),new StopSearchDelegate(view),WatchUi.SLIDE_UP);
            return;
        }
        if(id.equals("gps")){view.setOrigin(null,"");}
        else{for(var i=0;i<view.originChoices.size();i++){var c=view.originChoices[i];if(c["key"].equals(id)){view.setOrigin(id,c["label"]);break;}}}
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class StopSearchDelegate extends WatchUi.TextPickerDelegate {
    var view;
    function initialize(v){TextPickerDelegate.initialize();view=v;}
    function onTextEntered(text as Lang.String,changed as Lang.Boolean) as Lang.Boolean {
        if(text.length()>=2){view.pendingSearch=text;}
        return true;
    }
    function onCancel() as Lang.Boolean {return true;}
}
