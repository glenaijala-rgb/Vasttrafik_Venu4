import Toybox.Graphics;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

class DeparturesView extends WatchUi.View {
    var model; var offset = 0; var visible = 2; var width = 0; var height = 0; var ticker;
    function initialize(m) { View.initialize(); model = m; ticker = new Timer.Timer(); }
    function onShow() { model.refresh(); ticker.start(method(:tick), 15000, true); }
    function onHide() { ticker.stop(); }
    function tick() as Void { model.checkTimeout(); WatchUi.requestUpdate(); }
    function scroll(delta) {
        var total = DepartureCache.upcoming(model.data, false).size();
        offset = offset + delta;
        if (offset < 0) { offset = 0; }
        if (offset > total-visible) { offset = total-visible; }
        if (offset < 0) { offset = 0; }
        WatchUi.requestUpdate();
    }
    function fit(dc, text, font, maxWidth) {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) { return text; }
        while (text.length() > 0 && dc.getTextWidthInPixels(text + "…", font) > maxWidth) { text = text.substring(0, text.length()-1); }
        return text + "…";
    }
    function onUpdate(dc) {
        width = dc.getWidth(); height = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        dc.drawText(width/2, 24, Graphics.FONT_SMALL, model.label().toUpper(), Graphics.TEXT_JUSTIFY_CENTER);
        var rows = DepartureCache.upcoming(model.data, false);
        var top = 72; var bottom = height-112;
        var rowHeight = dc.getFontHeight(Graphics.FONT_MEDIUM) + dc.getFontHeight(Graphics.FONT_XTINY) + 10;
        visible = ((bottom-top)/rowHeight).toNumber();
        if (visible < 1) { visible = 1; }
        if (offset > rows.size()-visible) { offset = rows.size()-visible; }
        if (offset < 0) { offset = 0; }
        var fresh = DepartureCache.fresh(model.data);
        if (rows.size() == 0) {
            dc.drawText(width/2, height/2-25, Graphics.FONT_SMALL, model.data == null ? "Västtrafik" : "Inga avgångar", Graphics.TEXT_JUSTIFY_CENTER);
        }
        for (var i = 0; i < visible && i+offset < rows.size(); i += 1) {
            var d = rows[i+offset]; var y = top+i*rowHeight;
            var left = 42; var right = width-42;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(left, y, Graphics.FONT_MEDIUM, fit(dc, d["line"], Graphics.FONT_MEDIUM, width/3), Graphics.TEXT_JUSTIFY_LEFT);
            var minutes = d["isCancelled"] == true ? "Inställd" : fresh ? DepartureCache.minutes(d) + " min" : "—";
            dc.setColor(d["isCancelled"] == true ? 0xffa15c : 0x7dd3fc, Graphics.COLOR_BLACK);
            dc.drawText(right, y, Graphics.FONT_MEDIUM, minutes, Graphics.TEXT_JUSTIFY_RIGHT);
            var detail = d["stationLabel"] + " · " + d["destination"];
            if (d["delayMinutes"] > 0 && d["isCancelled"] != true) { detail = d["stationLabel"] + " · +" + d["delayMinutes"] + "m · " + d["destination"]; }
            if (d["platformChanged"] == true) { detail = d["stationLabel"] + " · Läge " + d["platform"] + " · " + d["destination"]; }
            if (d["isRealtime"] != true) { detail = detail + " · tidtabell"; }
            dc.setColor(0xcbd5e1, Graphics.COLOR_BLACK);
            dc.drawText(left, y+dc.getFontHeight(Graphics.FONT_MEDIUM), Graphics.FONT_XTINY,
                fit(dc, detail, Graphics.FONT_XTINY, right-left), Graphics.TEXT_JUSTIFY_LEFT);
        }
        var status = model.status;
        if (model.data != null && !fresh) { status = "Gammal data · " + status; }
        else if (model.data != null && status.equals("Uppdaterad")) {
            var time = Gregorian.info(new Time.Moment(model.data["generatedEpoch"]), Time.FORMAT_SHORT);
            status = "Uppd " + time.hour.format("%02d") + ":" + time.min.format("%02d");
        }
        dc.setColor(0xcbd5e1, Graphics.COLOR_BLACK);
        dc.drawText(width/2, height-105, Graphics.FONT_XTINY, fit(dc, status, Graphics.FONT_XTINY, width-90), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x17354d, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(width/2-90, height-75, 180, 46, 14);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(width/2, height-72, Graphics.FONT_SMALL, "Hållplats", Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class DeparturesDelegate extends WatchUi.BehaviorDelegate {
    var view; var model;
    function initialize(v, m) { BehaviorDelegate.initialize(); view = v; model = m; }
    function onSwipe(event) {
        if (event.getDirection() == WatchUi.SWIPE_UP) { view.scroll(1); return true; }
        if (event.getDirection() == WatchUi.SWIPE_DOWN) { view.scroll(-1); return true; }
        return false;
    }
    function onNextPage() { view.scroll(1); return true; }
    function onPreviousPage() { view.scroll(-1); return true; }
    function onMenu() { model.refresh(); return true; }
    function onSelect() { switchProfile(); return true; }
    function onTap(event) {
        var point = event.getCoordinates();
        if (point[1] >= view.height-75 && point[1] <= view.height-29 &&
            point[0] >= view.width/2-90 && point[0] <= view.width/2+90) { switchProfile(); return true; }
        if (point[1] < 70) { model.refresh(); return true; }
        return false;
    }
    function switchProfile() {
        view.offset = 0;
        if (model.profiles.size() == 2) {
            model.selectProfile(model.profiles[0]["id"] == model.profile ? model.profiles[1]["id"] : model.profiles[0]["id"]);
        } else {
            var menu = new WatchUi.Menu2({:title => "Hållplats"});
            for (var i = 0; i < model.profiles.size(); i += 1) { var p = model.profiles[i]; menu.addItem(new WatchUi.MenuItem(p["label"], null, p["id"], null)); }
            WatchUi.pushView(menu, new ProfileDelegate(model), WatchUi.SLIDE_UP);
        }
    }
}

class ProfileDelegate extends WatchUi.Menu2InputDelegate {
    var model;
    function initialize(m) { Menu2InputDelegate.initialize(); model = m; }
    function onSelect(item) { model.selectProfile(item.getId()); WatchUi.popView(WatchUi.SLIDE_DOWN); }
}
