import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.Time;
import Toybox.System;

// Credentials are user-supplied properties, never compiled resources or log output.
module DirectAuth {
    var token=null;
    var expires=0;
    var credentials=null;
    var blockedUntil=0;
}

class DirectRequest {
    var owner; var id; var version; var profile; var started;
    var tasks=[]; var taskIndex=0; var offset=0; var rows=[]; var partial=false;
    var page=[]; var rowIndex=0; var pageCount=0; var stage=""; var auth=null;
    var retried=false; var lastUrl; var lastParams; var resumeStage=null;
    const BASE="https://ext-api.vasttrafik.se/pr/v4/";
    // Garmin limits serialized web responses; five calls fit the device buffer.
    const PAGE_SIZE=5;
    const MAX_PAGES=80;
    function initialize(model, selected, generation) { owner=model; id=selected; version=generation; started=Time.now().value(); }
    function active() { return owner.profile.equals(id) && owner.generation==version && owner.busy; }
    function fail(code) { if(active()) { owner.receive(id,version,code,null); } }
    function readCredentials() {
        return [Application.Properties.getValue("VasttrafikClientId"),Application.Properties.getValue("VasttrafikClientSecret")];
    }
    function start() {
        if(!DirectConfig.VALID) { fail(503); return; }
        for(var idx0=0;idx0<(DirectConfig.PROFILES).size();idx0+=1) { var p=(DirectConfig.PROFILES)[idx0]; if(id.equals(p["id"])) { profile=p; } }
        if(profile==null) { fail(503); return; }
        for(var idx1=0;idx1<(profile["stations"]).size();idx1+=1) { var station=(profile["stations"])[idx1];
            var directions=[];
            for(var idx2=0;idx2<(station["criteria"]).size();idx2+=1) { var rule=(station["criteria"])[idx2];
                if(rule["enabled"]!=true) { continue; }
                var list=rule["direction"]["allowedDirectionGids"];
                if(list.size()==0) { list=[""]; }
                for(var idx3=0;idx3<(list).size();idx3+=1) { var dir=(list)[idx3]; if(!DirectRules.contains(directions,dir)) { directions.add(dir); } }
            }
            for(var idx4=0;idx4<(directions).size();idx4+=1) { var dir=(directions)[idx4]; tasks.add({"station"=>station,"direction"=>dir}); }
        }
        if(Time.now().value()<DirectAuth.blockedUntil) { fail(429); return; }
        var credentials=readCredentials(); var client=credentials[0]; var secret=credentials[1];
        if(!(client instanceof Lang.String) || !(secret instanceof Lang.String) || client.length()<2 || secret.length()<2) { fail(401); return; }
        auth="Basic "+StringUtil.encodeBase64(client+":"+secret);
        if(DirectAuth.credentials==null || !auth.equals(DirectAuth.credentials)) { DirectAuth.token=null; DirectAuth.expires=0; DirectAuth.credentials=auth; }
        if(DirectAuth.token==null || Time.now().value()>=DirectAuth.expires) { token(); } else { nextPage(); }
    }
    function token() {
        stage="token";
        send("https://ext-api.vasttrafik.se/token",{"grant_type"=>"client_credentials"},true);
    }
    function send(url, params, isToken) {
        if(!active()) { return; }
        if(Time.now().value()-started>40) { fail(502); return; }
        try {
            Communications.makeWebRequest(url,params,{
                :method=>isToken ? Communications.HTTP_REQUEST_METHOD_POST : Communications.HTTP_REQUEST_METHOD_GET,
                :headers=>isToken ? {"Authorization"=>auth,"Content-Type"=>Communications.REQUEST_CONTENT_TYPE_URL_ENCODED} :
                    {"Authorization"=>"Bearer "+DirectAuth.token,"Accept"=>"application/json","Accept-Language"=>"sv"},
                :responseType=>Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },method(:received));
        } catch(e) { fail(502); }
    }
    function nextPage() {
        if(!active()) { return; }
        if(taskIndex>=tasks.size()) {
            owner.receive(id,version,200,{"schemaVersion"=>1,"profileId"=>id,"profileLabel"=>profile["label"],
                "generatedEpoch"=>started,"staleAfterSeconds"=>DirectConfig.STALE,"isPartial"=>partial,
                "profiles"=>StartupConfig.PROFILES,"departures"=>rows}); return;
        }
        var task=tasks[taskIndex];
        lastUrl=BASE+"stop-areas/"+task["station"]["stopAreaGid"]+"/departures";
        lastParams={"startDateTime"=>DirectRules.iso(started),"timeSpanInMinutes"=>DirectConfig.HORIZON,
            "maxDeparturesPerLineAndDirection"=>100,"limit"=>PAGE_SIZE,"offset"=>offset};
        if(task["direction"].length()>0) { lastParams["directionGid"]=task["direction"]; }
        stage="departures"; send(lastUrl,lastParams,false);
    }
    function received(code as Lang.Number, data as Communications.ContentType or Null) as Void {
        if(!active()) { return; }
        System.println("Vasttrafik request stage="+stage+" status="+code);
        if(Time.now().value()-started>40) { fail(502); return; }
        if(code==429) { DirectAuth.blockedUntil=Time.now().value()+60; fail(429); return; }
        if(stage.equals("token")) {
            if(code!=200 || !(data instanceof Lang.Dictionary) || !(data["access_token"] instanceof Lang.String) || !(data["expires_in"] instanceof Lang.Number) || data["expires_in"]<=60) { fail(code==400 || code==401 ? 401 : 502); return; }
            DirectAuth.token=data["access_token"]; DirectAuth.expires=Time.now().value()+data["expires_in"]-60;
            if(resumeStage!=null) { stage=resumeStage; resumeStage=null; send(lastUrl,lastParams,false); } else { nextPage(); }
            return;
        }
        if(code==401 && !retried) { retried=true; resumeStage=stage; DirectAuth.token=null; token(); return; }
        if(code!=200 || !(data instanceof Lang.Dictionary)) { fail(code==401 || code==403 ? 401 : 502); return; }
        try {
            if(stage.equals("departures")) {
                if(data["results"]==null && data.hasKey("results")) { page=[]; }
                else if(data["results"] instanceof Lang.Array) { page=data["results"]; }
                else { fail(502); return; }
                rowIndex=0; pageCount=page.size(); processPage();
            } else {
                var raw=page[rowIndex]; var details=DirectRules.details(data,raw);
                if(details==null) { fail(502); return; }
                accept(raw,details["call"],details["onward"]); rowIndex+=1; processPage();
            }
        } catch(e) { fail(502); }
    }
    function accept(raw, call, onward) {
        var task=tasks[taskIndex];
        for(var idx5=0;idx5<(task["station"]["criteria"]).size();idx5+=1) { var rule=(task["station"]["criteria"])[idx5];
            if(DirectRules.matches(raw,rule,task["direction"],onward,false)) {
                var normalized=DirectRules.normalize(raw,task["station"],call);
                if(normalized==null) { fail(502); return; }
                DirectRules.insert(rows,normalized,started); return;
            }
        }
    }
    function processPage() {
        var task=tasks[taskIndex];
        while(rowIndex<page.size() && active()) {
            var raw=page[rowIndex]; var relevant=false; var needsDetails=false;
            for(var idx6=0;idx6<(task["station"]["criteria"]).size();idx6+=1) { var rule=(task["station"]["criteria"])[idx6];
                if(DirectRules.matches(raw,rule,task["direction"],[],true)) {
                    relevant=true; needsDetails=needsDetails || rule["direction"]["mustPassStopAreaGids"].size()>0;
                }
            }
            if(relevant && (needsDetails || raw["isPartCancelled"]==true)) {
                if(!(raw["detailsReference"] instanceof Lang.String)) { fail(502); return; }
                lastUrl=BASE+"stop-areas/"+task["station"]["stopAreaGid"]+"/departures/"+Communications.encodeURL(raw["detailsReference"])+"/details";
                lastParams={"includes"=>"servicejourneycalls"}; stage="details"; send(lastUrl,lastParams,false); return;
            }
            if(relevant) { accept(raw,null,[]); }
            rowIndex+=1;
        }
        page=[];
        if(pageCount<PAGE_SIZE || offset+PAGE_SIZE>=PAGE_SIZE*MAX_PAGES) {
            if(pageCount>=PAGE_SIZE) { partial=true; }
            taskIndex+=1; offset=0;
        } else { offset+=PAGE_SIZE; }
        nextPage();
    }
}
