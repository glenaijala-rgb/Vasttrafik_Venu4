import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;

(:glance)
module DepartureCache {
    function read(profile) {
        try {
            var data = Application.Storage.getValue("data_" + profile);
            if (data instanceof Lang.Dictionary && data["schemaVersion"] == 1 && profile.equals(data["profileId"]) &&
                data["generatedEpoch"] instanceof Lang.Number && data["departures"] instanceof Lang.Array) { return data; }
        } catch (e) { }
        return null;
    }
    function fresh(data) {
        if (data == null) { return false; }
        var age = Time.now().value() - data["generatedEpoch"];
        var ttl = data["staleAfterSeconds"];
        if (!(ttl instanceof Lang.Number) || ttl < 1 || ttl > 180) { ttl = 180; }
        return age >= -30 && age <= ttl;
    }
    function upcoming(data, excludeCancelled) {
        var out = [];
        if (data == null) { return out; }
        var now = Time.now().value();
        for (var i = 0; i < data["departures"].size(); i += 1) {
            var d = data["departures"][i];
            if (d instanceof Lang.Dictionary && d["departureEpoch"] instanceof Lang.Number &&
                d["departureEpoch"] >= now && (!excludeCancelled || d["isCancelled"] != true)) { out.add(d); }
        }
        return out;
    }
    function minutes(d) {
        var seconds = d["departureEpoch"] - Time.now().value();
        return ((seconds + 59) / 60).toNumber().toString();
    }
}
