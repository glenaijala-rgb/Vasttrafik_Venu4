import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;
import Toybox.Application;

(:test)
class OfflineDepartureModel extends DepartureModel {
    function refresh() { }
}

// Synthetic rows exist only in this test target, never in the production app.
(:test)
function cacheSelectsChronologicalNonCancelledCalls(logger) as Boolean {
    var now = Time.now().value();
    var data = {"generatedEpoch" => now, "departures" => [
        {"line" => "753", "departureEpoch" => now-60},
        {"line" => "25", "departureEpoch" => now+60, "isCancelled" => true},
        {"line" => "753", "departureEpoch" => now+120},
        {"line" => "753", "departureEpoch" => now+180}
    ]};
    var rows = DepartureCache.upcoming(data, true);
    Test.assert(rows.size() == 2);
    Test.assert(rows[0]["line"].equals(rows[1]["line"]));
    Test.assert(DepartureCache.upcoming(data, false).size() == 3);
    return true;
}

(:test)
function cacheRejectsStaleAndFutureClock(logger) as Boolean {
    var now = Time.now().value();
    Test.assert(!DepartureCache.fresh(null));
    Test.assert(!DepartureCache.fresh({"generatedEpoch" => now-181, "staleAfterSeconds" => 180}));
    Test.assert(!DepartureCache.fresh({"generatedEpoch" => now+60}));
    Test.assert(DepartureCache.fresh({"generatedEpoch" => now, "staleAfterSeconds" => 180}));
    Test.assert(DepartureCache.upcoming({"departures" => []}, true).size() == 0);
    return true;
}

(:test)
function minutesAreCalculatedAtReadTime(logger) as Boolean {
    var now = Time.now().value();
    Test.assert(DepartureCache.minutes({"departureEpoch" => now+119}).equals("2"));
    Test.assert(DepartureCache.upcoming({"departures" => [{"line" => "25", "departureEpoch" => now+300}]}, true).size() == 1);
    return true;
}

(:test)
function lateProfileResponseDoesNotChangeCurrentProfile(logger) as Boolean {
    var m = new DepartureModel();
    m.profile = "work"; m.generation = 2; m.status = "sentinel";
    m.receive("home", 1, 503, null);
    Test.assert(m.profile.equals("work"));
    Test.assert(m.status.equals("sentinel"));
    return true;
}

(:test)
function profileStringsAndStoredResponsesUseValueEquality(logger) as Boolean {
    var model = new OfflineDepartureModel();
    model.profile = "ho" + "me";
    Test.assert(model.label().equals("Hem"));
    var now = Time.now().value();
    var result = {"schemaVersion" => 1, "profileId" => "h" + "ome", "profileLabel" => "Hem",
        "generatedEpoch" => now, "staleAfterSeconds" => 180, "isPartial" => false,
        "departures" => [{"line" => "753", "stationLabel" => "TEST", "destination" => "TEST",
            "departureEpoch" => now+120, "delayMinutes" => 0, "isCancelled" => false}]};
    Test.assert(model.validResponse(result, "hom" + "e"));
    model.receive("hom" + "e", model.generation, 200, result);
    Test.assert(model.data != null);
    Test.assert(DepartureCache.read("hom" + "e") != null);
    var compact = Application.Storage.getValue("glance_home") as Lang.Dictionary;
    Test.assert(compact["departures"].size() == 1);
    var view = new DeparturesView(model);
    var delegate = new DeparturesDelegate(view, model);
    delegate.switchProfile();
    Test.assert(model.profile.equals("work"));
    Test.assert(model.label().equals("Jobb"));
    delegate.switchProfile();
    Test.assert(model.profile.equals("home"));
    Application.Storage.deleteValue("data_home");
    Application.Storage.deleteValue("glance_home");
    return true;
}
