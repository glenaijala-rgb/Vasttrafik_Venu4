import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class DeparturesGlance extends WatchUi.GlanceView {
    function initialize() { GlanceView.initialize(); }
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        var w = dc.getWidth(); var h = dc.getHeight();
        var data = null; var profile = StartupConfig.PROFILE;
        try {
            var active = Application.Storage.getValue("activeProfile");
            if (active instanceof Lang.String) { profile = active; }
            var cached = Application.Storage.getValue("glance_" + profile);
            if (cached instanceof Lang.Dictionary && cached["profileId"] == profile && cached["schemaVersion"] == 1 &&
                cached["generatedEpoch"] instanceof Lang.Number && cached["departures"] instanceof Lang.Array) { data = cached; }
        } catch (e) { }
        var label = profile;
        for (var n = 0; n < StartupConfig.PROFILES.size(); n += 1) { var p = StartupConfig.PROFILES[n]; if (p["id"] == profile) { label = p["label"]; } }
        if (data != null && data["profileLabel"] instanceof Lang.String) { label = data["profileLabel"]; }
        dc.drawText(w/2, 0, Graphics.FONT_XTINY, "VÄSTTRAFIK · " + label.toUpper(), Graphics.TEXT_JUSTIFY_CENTER);
        var y = dc.getFontHeight(Graphics.FONT_XTINY) + 1;
        if (!DepartureCache.fresh(data)) {
            dc.drawText(w/2, y, Graphics.FONT_XTINY, data == null ? "Öppna för att hämta" : "Gammal data", Graphics.TEXT_JUSTIFY_CENTER); return;
        }
        if (data["isPartial"] == true) {
            dc.drawText(w/2, y, Graphics.FONT_XTINY, "Ofullständig lista", Graphics.TEXT_JUSTIFY_CENTER); return;
        }
        var rows = DepartureCache.upcoming(data, true);
        if (rows.size() == 0) {
            dc.drawText(w/2, y, Graphics.FONT_XTINY, "Inga avgångar", Graphics.TEXT_JUSTIFY_CENTER); return;
        }
        for (var i = 0; i < 2; i += 1) {
            var line = i < rows.size() ? rows[i]["line"] : "—";
            var mins = i < rows.size() ? " " + DepartureCache.minutes(rows[i]) + "m" : "";
            var text = line + mins;
            var font = Graphics.FONT_MEDIUM;
            if (dc.getTextWidthInPixels(text, font) > w/2 - 12 || dc.getFontHeight(font) > h-y) { font = Graphics.FONT_SMALL; }
            if (dc.getTextWidthInPixels(text, font) > w/2 - 12 || dc.getFontHeight(font) > h-y) { font = Graphics.FONT_XTINY; }
            var x = w*(i*2+1)/4 - dc.getTextWidthInPixels(text, font)/2;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(x, y, font, line, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0x7dd3fc, Graphics.COLOR_BLACK);
            dc.drawText(x + dc.getTextWidthInPixels(line, font), y, font, mins, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}
