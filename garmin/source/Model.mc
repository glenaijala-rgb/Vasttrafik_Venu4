import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

class DepartureModel {
    var profile = StartupConfig.PROFILE;
    var profiles = StartupConfig.PROFILES;
    var data = null;
    var status = "Öppna för att hämta";
    var busy = false;
    var generation = 0;
    var lastRequest = -100;
    var request = null;
    function checkTimeout() {
        if (busy && Time.now().value() - lastRequest > 45) {
            generation += 1; busy = false; status = "Ingen anslutning";
        }
    }
    function initialize() {
        data = DepartureCache.read(profile);
        Application.Storage.setValue("activeProfile", profile);
    }
    function selectProfile(id) {
        if (id.equals(profile)) { return; }
        profile = id;
        generation += 1;
        busy = false;
        lastRequest = -100;
        data = DepartureCache.read(profile);
        Application.Storage.setValue("activeProfile", profile);
        refresh();
    }
    function label() {
        for (var i = 0; i < profiles.size(); i += 1) { var p = profiles[i]; if (profile.equals(p["id"])) { return p["label"]; } }
        return profile;
    }
    function refresh() {
        var now = Time.now().value();
        if (busy || now - lastRequest < 15) { return; }
        if (data != null && DepartureCache.fresh(data) && now-data["generatedEpoch"] < DirectConfig.TTL) {
            status = "Uppdaterad"; WatchUi.requestUpdate(); return;
        }
        busy = true; lastRequest = now; status = "Hämtar...";
        request = new DirectRequest(self, profile, generation);
        try { request.start(); } catch(e) { receive(profile,generation,502,null); }
        WatchUi.requestUpdate();
    }
    function receive(id, version, code, result) {
        // An older request must never replace the newly selected profile.
        if (!id.equals(profile) || version != generation) { return; }
        busy = false;
        if (code == 200 && validResponse(result, id)) {
            data = result;
            if (result["profiles"] instanceof Lang.Array && result["profiles"].size() > 0) { profiles = result["profiles"]; }
            status = result["isPartial"] == true ? "Ofullständig lista" : "Uppdaterad";
            try {
                // Full cache and small glance cache share the same timestamp and profile.
                Application.Storage.setValue("data_" + profile, data);
                var glanceRows = [];
                var upcoming = DepartureCache.upcoming(data, true);
                for (var i = 0; i < upcoming.size(); i += 1) {
                    glanceRows.add({"line" => upcoming[i]["line"], "departureEpoch" => upcoming[i]["departureEpoch"]});
                }
                var compact = {"schemaVersion" => 1, "profileId" => profile, "profileLabel" => label(),
                    "generatedEpoch" => data["generatedEpoch"], "staleAfterSeconds" => data["staleAfterSeconds"],
                    "isPartial" => data["isPartial"], "departures" => glanceRows};
                Application.Storage.setValue("glance_" + profile, compact);
            } catch (e) { status = "Cache kunde inte sparas"; }
        } else {
            status = code == 503 ? "Konfiguration saknas" : code == 401 ? "Ställ in API-nycklar" :
                code == 429 ? "Vänta, försök igen" : code == 502 ? "Trafikdata otillgänglig" : "Ingen anslutning";
            // Invalid configuration/auth must not leave old times looking operational.
            if (code == 503 || code == 401) {
                data = null;
                try { Application.Storage.deleteValue("data_" + profile); Application.Storage.deleteValue("glance_" + profile); } catch (e) { }
            }
        }
        WatchUi.requestUpdate();
    }
    function validResponse(r, id) {
        if (!(r instanceof Lang.Dictionary) || r["schemaVersion"] != 1 || !id.equals(r["profileId"]) ||
            !(r["generatedEpoch"] instanceof Lang.Number) || !(r["departures"] instanceof Lang.Array) || r["departures"].size() > 100) { return false; }
        var previous = 0;
        for (var i = 0; i < r["departures"].size(); i += 1) {
            var d = r["departures"][i];
            if (!(d instanceof Lang.Dictionary) || !(d["line"] instanceof Lang.String) ||
                !(d["stationLabel"] instanceof Lang.String) || !(d["destination"] instanceof Lang.String) ||
                !(d["departureEpoch"] instanceof Lang.Number) || d["departureEpoch"] < previous ||
                !(d["delayMinutes"] instanceof Lang.Number)) { return false; }
            previous = d["departureEpoch"];
        }
        return true;
    }
}
