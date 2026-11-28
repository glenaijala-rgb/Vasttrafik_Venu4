import Toybox.Application;
import Toybox.WatchUi;

(:glance)
class VasttrafikApp extends Application.AppBase {
    var activeModel=null;
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        var model = new DepartureModel();
        activeModel=model;
        var view = new DeparturesView(model);
        return [view, new DeparturesDelegate(view, model)];
    }
    function getGlanceView() { return [new DeparturesGlance()]; }
    function onSettingsChanged() as Void {
        DirectAuth.token=null; DirectAuth.expires=0; DirectAuth.credentials=null;
        for(var i=0;i<StartupConfig.PROFILES.size();i+=1) {
            var id=StartupConfig.PROFILES[i]["id"];
            Application.Storage.deleteValue("data_"+id);
            Application.Storage.deleteValue("glance_"+id);
        }
        if(activeModel!=null) {
            activeModel.generation+=1; activeModel.busy=false; activeModel.lastRequest=-100;
            activeModel.data=null; activeModel.refresh();
        }
    }
    function onStop(state) as Void {
        Application.Storage.setValue("activeProfile", StartupConfig.PROFILE);
    }
}
