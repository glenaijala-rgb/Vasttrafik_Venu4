import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

(:test)
function directTimestampHandlesOffsetsAndDst(logger) as Boolean {
    Test.assert(DirectRules.epoch("2026-10-25T02:30:00+02:00")+3600==DirectRules.epoch("2026-10-25T02:30:00+01:00"));
    Test.assert(DirectRules.epoch("2026-11-30T15:04:00.0000000+01:00")==1796047440);
    Test.assert(DirectRules.epoch("2026-11-30T14:04:00Z")==1796047440);
    Test.assert(DirectRules.epoch("2026-11-30T14:04:00")==null);
    Test.assert(DirectRules.iso(1796047440).equals("2026-11-30T14:04:00Z"));
    return true;
}

(:test)
function directRulesAgreeWithVerifiedBackendSnapshots(logger) as Boolean {
    for(var i=0;i<LiveFixtures.DATA.size();i+=1) {
        var sample=LiveFixtures.DATA[i]; var station=null;
        for(var p=0;p<DirectConfig.PROFILES.size();p+=1) {
            var stations=DirectConfig.PROFILES[p]["stations"];
            for(var s=0;s<stations.size();s+=1) { if(stations[s]["key"].equals(sample["stationKey"])) { station=stations[s]; } }
        }
        Test.assert(station!=null);
        var raw=sample["raw"];
        for(var r=0;r<station["criteria"].size();r+=1) {
            Test.assert(DirectRules.matches(raw,station["criteria"][r],"",[],false)==sample["matches"][r]);
        }
        var normal=DirectRules.normalize(raw,station,null); var expected=sample["expected"];
        Test.assert(normal["line"].equals(expected["line"]));
        Test.assert(normal["destination"].equals(expected["destination"]));
        Test.assert(normal["departureEpoch"]==expected["departureEpoch"]);
        Test.assert(normal["delayMinutes"]==expected["delayMinutes"]);
        var details=DirectRules.details(sample["details"],raw);
        Test.assert(details!=null);
        Test.assert(details["onward"].size()==sample["onward"].size());
        for(var n=0;n<sample["onward"].size();n+=1) { Test.assert(details["onward"][n].equals(sample["onward"][n])); }
    }
    return true;
}

(:test)
class TestDirectRequest extends DirectRequest {
    var sent=0; var sentUrl; var sentParams; var sentToken;
    function initialize(m) { DirectRequest.initialize(m,m.profile,m.generation); }
    function readCredentials() { return ["TEST-ID","TEST-SECRET"]; }
    function send(url, params, isToken) { sent+=1; sentUrl=url; sentParams=params; sentToken=isToken; }
}

(:test)
function directNetworkStateMachineAndBackoff(logger) as Boolean {
    DirectAuth.token=null; DirectAuth.credentials=null; DirectAuth.blockedUntil=0;
    var m=new DepartureModel(); m.profile="work"; m.busy=true;
    var req=new TestDirectRequest(m); req.start();
    Test.assert(req.sentToken);
    req.received(200,{"access_token"=>"TEST-TOKEN","expires_in"=>3600});
    Test.assert(req.stage.equals("departures"));
    Test.assert(req.sentParams["offset"]==0);
    req.received(401,{}); Test.assert(req.sentToken);
    req.received(200,{"access_token"=>"TEST-RENEWED","expires_in"=>3600});
    Test.assert(req.stage.equals("departures"));
    req.received(200,{"results"=>null});
    Test.assert(!m.busy && m.data["departures"].size()==0);
    var before=req.sent;
    m.generation+=1; req.received(200,{"results"=>[]}); Test.assert(req.sent==before);
    m.busy=true; req=new TestDirectRequest(m); req.start(); req.received(429,{});
    Test.assert(!m.busy && DirectAuth.blockedUntil>Time.now().value());
    m.busy=true; req=new TestDirectRequest(m); req.start(); Test.assert(req.sent==0 && !m.busy);
    DirectAuth.blockedUntil=0; DirectAuth.token=null; DirectAuth.credentials=null;
    return true;
}

(:test)
function directPaginationCancellationAndMerge(logger) as Boolean {
    DirectAuth.token="TEST-TOKEN"; DirectAuth.expires=Time.now().value()+600;
    var m=new DepartureModel(); m.profile="work"; m.busy=true;
    var req=new TestDirectRequest(m); req.start();
    if(req.sentToken) { req.received(200,{"access_token"=>"TEST-TOKEN","expires_in"=>3600}); }
    // A full page of irrelevant departures must advance offset, not produce an empty final result.
    var page=[];
    for(var i=0;i<req.PAGE_SIZE;i+=1) { page.add({"serviceJourney"=>{"line"=>{"shortName"=>"OTHER"}},"stopPoint"=>{"gid"=>"OTHER"}}); }
    req.received(200,{"results"=>page});
    Test.assert(req.sentParams["offset"]==req.PAGE_SIZE && m.busy);
    req.received(200,{"results"=>[]}); Test.assert(!m.busy);
    var now=Time.now().value(); var rows=[];
    DirectRules.insert(rows,{"id"=>"later","departureEpoch"=>now+120},now);
    DirectRules.insert(rows,{"id"=>"first","departureEpoch"=>now+60},now);
    DirectRules.insert(rows,{"id"=>"first","departureEpoch"=>now+60},now);
    DirectRules.insert(rows,{"id"=>"past","departureEpoch"=>now-1},now);
    Test.assert(rows.size()==2 && rows[0]["id"].equals("first"));
    var sample=LiveFixtures.DATA[0];
    var station=DirectConfig.PROFILES[0]["stations"][0];
    var normal=DirectRules.normalize(sample["raw"],station,{"isCancelled"=>true,"isArrivalCancelled"=>true});
    Test.assert(!normal["isCancelled"]);
    normal=DirectRules.normalize(sample["raw"],station,{"isDepartureCancelled"=>true});
    Test.assert(normal["isCancelled"]);
    DirectAuth.token=null; DirectAuth.credentials=null;
    return true;
}
