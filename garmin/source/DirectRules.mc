import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

module DirectRules {
    function contains(values, value) {
        for (var i=0; i<values.size(); i+=1) { if (values[i].equals(value)) { return true; } }
        return false;
    }
    function epoch(text) {
        if (!(text instanceof Lang.String) || text.length()<20) { return null; }
        try {
            if (!text.substring(4,5).equals("-") || !text.substring(7,8).equals("-") || !text.substring(10,11).equals("T")) { return null; }
            var offset=0; var len=text.length();
            if (!text.substring(len-1,len).equals("Z")) {
                var sign=text.substring(len-6,len-5);
                if ((!sign.equals("+") && !sign.equals("-")) || !text.substring(len-3,len-2).equals(":")) { return null; }
                offset=(text.substring(len-5,len-3).toNumber()*60+text.substring(len-2,len).toNumber())*60;
                if (sign.equals("-")) { offset=-offset; }
            }
            return Gregorian.moment({:year=>text.substring(0,4).toNumber(),:month=>text.substring(5,7).toNumber(),
                :day=>text.substring(8,10).toNumber(),:hour=>text.substring(11,13).toNumber(),
                :minute=>text.substring(14,16).toNumber(),:second=>text.substring(17,19).toNumber()}).value()-offset;
        } catch(e) { return null; }
    }
    function iso(seconds) {
        var t=Gregorian.utcInfo(new Time.Moment(seconds),Time.FORMAT_SHORT);
        return t.year.format("%04d")+"-"+t.month.format("%02d")+"-"+t.day.format("%02d")+"T"+
            t.hour.format("%02d")+":"+t.min.format("%02d")+":"+t.sec.format("%02d")+"Z";
    }
    function line(raw) {
        var j=raw["serviceJourney"]; if (!(j instanceof Lang.Dictionary)) { return null; }
        var l=j["line"]; if (!(l instanceof Lang.Dictionary)) { return null; }
        for(var idx0=0;idx0<(["shortName","designation","name"]).size();idx0+=1) { var key=(["shortName","designation","name"])[idx0];
            if (l[key] instanceof Lang.String && l[key].length()>0) { return l[key]; }
        }
        return null;
    }
    function stop(raw) { return raw["realtimeStopPoint"] instanceof Lang.Dictionary ? raw["realtimeStopPoint"] : raw["stopPoint"]; }
    function matches(raw, rule, direction, onward, prefilter) {
        var r=rule["direction"]; var s=stop(raw);
        if (rule["enabled"]!=true || !"verified".equals(r["verificationStatus"]) || !(s instanceof Lang.Dictionary) || !contains(rule["lineNames"],line(raw))) { return false; }
        if (r["allowedDirectionGids"].size()>0 && !contains(r["allowedDirectionGids"],direction)) { return false; }
        if (r["allowedStopPointGids"].size()>0 && !contains(r["allowedStopPointGids"],s["gid"])) { return false; }
        if (r["allowedPlatforms"].size()>0 && !contains(r["allowedPlatforms"],s["platform"])) { return false; }
        if (!prefilter) { for(var idx1=0;idx1<(r["mustPassStopAreaGids"]).size();idx1+=1) { var gid=(r["mustPassStopAreaGids"])[idx1]; if (!contains(onward,gid)) { return false; } } }
        return true;
    }
    function details(info, raw) {
        if (!(info instanceof Lang.Dictionary) || !(info["serviceJourneys"] instanceof Lang.Array)) { return null; }
        var planned=epoch(raw["plannedTime"]);
        for(var idx2=0;idx2<(info["serviceJourneys"]).size();idx2+=1) { var journey=(info["serviceJourneys"])[idx2];
            if (!raw["serviceJourney"]["gid"].equals(journey["gid"])) { continue; }
            var calls=journey["callsOnServiceJourney"]; if (!(calls instanceof Lang.Array)) { return null; }
            var index=-1;
            for(var i=0;i<calls.size();i+=1) {
                var c=calls[i];
                if (c["stopPoint"] instanceof Lang.Dictionary && raw["stopPoint"]["gid"].equals(c["stopPoint"]["gid"]) && planned!=null && planned==epoch(c["plannedDepartureTime"])) {
                    if (index>=0) { return null; } index=i;
                }
            }
            if(index<0) { return null; }
            var onward=[];
            for(var i=index+1;i<calls.size();i+=1) {
                var c=calls[i]; var s=stop(c);
                if(c["isArrivalCancelled"]!=true && (c["isCancelled"]!=true || c["isDepartureCancelled"]==true) && s instanceof Lang.Dictionary && s["stopArea"] instanceof Lang.Dictionary) { onward.add(s["stopArea"]["gid"]); }
            }
            return {"call"=>calls[index],"onward"=>onward};
        }
        return null;
    }
    function normalize(raw, station, call) {
        var planned=epoch(raw["plannedTime"]); var estimated=epoch(raw["estimatedTime"]);
        var actual=epoch(raw["estimatedOtherwisePlannedTime"]);
        if(actual==null) { actual=estimated==null ? planned : estimated; }
        var l=line(raw); var j=raw["serviceJourney"]; var s=stop(raw);
        if(planned==null || actual==null || l==null || !(j["gid"] instanceof Lang.String) || !(raw["stopPoint"] instanceof Lang.Dictionary)) { return null; }
        var flags=call==null ? raw : call;
        var cancelled=flags["isDepartureCancelled"]==true || (flags["isArrivalCancelled"]!=true && flags["isCancelled"]==true);
        var destination=j["direction"] instanceof Lang.String ? j["direction"] : "";
        if(j["directionDetails"] instanceof Lang.Dictionary && j["directionDetails"]["shortDirection"] instanceof Lang.String) { destination=j["directionDetails"]["shortDirection"]; }
        var delta=actual-planned;
        // Match Math.round, including negative half minutes.
        var delay=((delta+30)/60.0).toNumber(); if(delta+30<0 && (delta+30)%60!=0) { delay-=1; }
        return {"id"=>j["gid"]+":"+raw["stopPoint"]["gid"]+":"+planned.toString(),
            "stationKey"=>station["key"],"stationLabel"=>station["shortLabel"],"line"=>l,"destination"=>destination,
            "departureEpoch"=>actual,"isRealtime"=>estimated!=null,"isCancelled"=>cancelled,"delayMinutes"=>delay,
            "platform"=>s["platform"]==null ? "" : s["platform"],"platformChanged"=>raw["realtimeStopPoint"]!=null};
    }
    function insert(rows, row, now) {
        if(row==null || row["departureEpoch"]<now || row["departureEpoch"]>now+DirectConfig.HORIZON*60) { return; }
        for(var i=0;i<rows.size();i+=1) { if(rows[i]["id"].equals(row["id"])) { rows.remove(rows[i]); break; } }
        rows.add(row);
        for(var i=rows.size()-1;i>0;i-=1) {
            if(rows[i]["departureEpoch"]>=rows[i-1]["departureEpoch"]) { break; }
            var previous=rows[i-1]; rows[i-1]=rows[i]; rows[i]=previous;
        }
        if(rows.size()>DirectConfig.LIMIT) { rows.remove(rows[rows.size()-1]); }
    }
}
