import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class DeparturesGlance extends WatchUi.GlanceView {
    function initialize() { GlanceView.initialize(); }
    function fit(dc, text, font, width) {
        if (dc.getTextWidthInPixels(text, font) <= width) { return text; }
        while (text.length() > 0 && dc.getTextWidthInPixels(text + "…", font) > width) { text = text.substring(0, text.length()-1); }
        return text + "…";
    }
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        var w = dc.getWidth(); var h = dc.getHeight();
        var data = null; var profile = StartupConfig.PROFILE;
        try {
            var active = Application.Storage.getValue("activeProfile");
            if (active instanceof Lang.String) { profile = active; }
            var cached = Application.Storage.getValue("glance_" + profile);
            if (cached instanceof Lang.Dictionary && profile.equals(cached["profileId"]) && cached["schemaVersion"] == 1 &&
                cached["generatedEpoch"] instanceof Lang.Number && cached["departures"] instanceof Lang.Array) { data = cached; }
        } catch (e) { }
        var label = profile;
        for (var n = 0; n < StartupConfig.PROFILES.size(); n += 1) { var p = StartupConfig.PROFILES[n]; if (profile.equals(p["id"])) { label = p["label"]; } }
        if (data != null && data["profileLabel"] instanceof Lang.String) { label = data["profileLabel"]; }
        var headerY = (h * 0.22).toNumber();
        var headerFont = Graphics.getVectorFont({:font => Graphics.FONT_XTINY, :scale => 0.75});
        if (headerFont == null) { headerFont = Graphics.FONT_XTINY; }
        dc.drawText(8, headerY, headerFont, fit(dc, "VÄSTTRAFIK · " + label.toUpper(), headerFont, w-16), Graphics.TEXT_JUSTIFY_LEFT);
        var y = headerY + dc.getFontHeight(headerFont) + 4;
        if (!DepartureCache.fresh(data)) {
            dc.drawText(w/2, y, Graphics.FONT_XTINY, fit(dc, data == null ? "Öppna för att hämta" : "Gammal data", Graphics.FONT_XTINY, w-16), Graphics.TEXT_JUSTIFY_CENTER); return;
        }
        if (data["isPartial"] == true) {
            dc.drawText(w/2, y, Graphics.FONT_XTINY, "Ofullständig lista", Graphics.TEXT_JUSTIFY_CENTER); return;
        }
        var rows = DepartureCache.upcoming(data, true);
        if (rows.size() == 0) {
            dc.drawText(w/2, y, Graphics.FONT_XTINY, "Inga avgångar", Graphics.TEXT_JUSTIFY_CENTER); return;
        }
        var font = Graphics.getVectorFont({:font => Graphics.FONT_MEDIUM, :scale => 0.75});
        if (font == null) { font = Graphics.FONT_SMALL; }
        for (var n = 0; n < 2 && n < rows.size(); n += 1) {
            var candidate = rows[n]["line"] + " " + DepartureCache.minutes(rows[n]) + "m";
            if (dc.getTextWidthInPixels(candidate, font) > w/2 - 12 || dc.getFontHeight(font) > h-y) { font = Graphics.FONT_XTINY; }
        }
        for (var i = 0; i < 2; i += 1) {
            var line = i < rows.size() ? rows[i]["line"] : "—";
            var mins = i < rows.size() ? " " + DepartureCache.minutes(rows[i]) + "m" : "";
            var text = line + mins;
            var x = w*(i*2+1)/4 - dc.getTextWidthInPixels(text, font)/2;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.drawText(x, y, font, line, Graphics.TEXT_JUSTIFY_LEFT);
            dc.setColor(0x7dd3fc, Graphics.COLOR_BLACK);
            dc.drawText(x + dc.getTextWidthInPixels(line, font), y, font, mins, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}
