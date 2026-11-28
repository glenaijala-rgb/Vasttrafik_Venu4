import Toybox.Application;
import Toybox.WatchUi;

(:glance)
class VasttrafikApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        var model = new DepartureModel();
        var view = new DeparturesView(model);
        return [view, new DeparturesDelegate(view, model)];
    }
    function getGlanceView() { return [new DeparturesGlance()]; }
    function onStop(state) as Void {
        Application.Storage.setValue("activeProfile", StartupConfig.PROFILE);
    }
}
