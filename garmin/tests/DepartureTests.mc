import Toybox.Lang;
import Toybox.Test;
import Toybox.Time;

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
