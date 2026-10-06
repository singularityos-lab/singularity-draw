namespace Singularity.Apps.Draw {

    public class StencilsEngineering {
        private const string PID = "fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:9";
        private const string UI = "fill:#ffffff;stroke:#9aa0a6;stroke-width:1;text-color:#3c4043;font-size:10";

        private static TechPen pen () {
            return new TechPen ();
        }

        private static unowned StencilDef pid (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults (PID)
                .label (0, h + 2, w, 14);
        }

        private static string bowtie (double x, double y, double w, double h) {
            return pen ().poly ({ x, y, x + w / 2, y + h / 2, x, y + h }).poly ({ x + w, y, x + w / 2, y + h / 2, x + w, y + h }).str ();
        }

        private static unowned StencilDef valve (string kind, string name, string kw) {
            return pid (kind, name, 60, 30, kw + " valve")
                .fill (bowtie (0, 0, 60, 30))
                .port (0, 15)
                .port (60, 15);
        }

        private static void bubble (string kind, string name, string kw, string text, int mode) {
            unowned StencilDef d = pid (kind, name, 50, 50, kw + " instrument")
                .label (5, 5, 40, 40)
                .text (text)
                .ports_box ();
            if (mode == 2) d.fill (pen ().rect (0, 0, 50, 50).str ()).fill (pen ().circle (25, 25, 24).str ());
            else if (mode == 3) d.fill (pen ().rect (0, 0, 50, 50).str ()).line (pen ().poly ({ 25, 0, 50, 25, 25, 50, 0, 25 }).str ());
            else d.fill (pen ().circle (25, 25, 24).str ());
            if (mode == 1 || mode == 2) {
                d.line (pen ().line (1, 25, 49, 25).str ());
                d.label (5, 6, 40, 18);
            }
        }

        private static void register_pid () {
            Stencils.category ("pid", _("Process and Instrumentation"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            valve ("pid-gate-valve", _("Gate Valve"), "gate isolation");
            valve ("pid-globe-valve", _("Globe Valve"), "globe throttling")
                .dark (pen ().circle (30, 15, 5).str ());
            valve ("pid-ball-valve", _("Ball Valve"), "ball quarter turn")
                .fill (pen ().circle (30, 15, 7).str ());
            pid ("pid-butterfly-valve", _("Butterfly Valve"), 60, 30, "butterfly valve")
                .line (pen ().line (4, 2, 4, 28).line (56, 2, 56, 28).line (4, 15, 56, 15).line (22, 28, 38, 2).str ())
                .dark (pen ().circle (30, 15, 3).str ())
                .port (0, 15)
                .port (60, 15);
            valve ("pid-check-valve", _("Check Valve"), "check non return")
                .dark (pen ().poly ({ 0, 0, 30, 15, 0, 30 }).str ());
            valve ("pid-plug-valve", _("Plug Valve"), "plug cock")
                .fill (pen ().rect (24, 9, 12, 12).str ());
            valve ("pid-needle-valve", _("Needle Valve"), "needle metering")
                .line (pen ().line (30, 15, 30, 0).line (22, 0, 38, 0).str ());
            pid ("pid-control-valve", _("Control Valve"), 60, 55, "control valve actuator diaphragm")
                .fill (bowtie (0, 25, 60, 30))
                .line (pen ().line (30, 40, 30, 14).str ())
                .fill (pen ().m (12, 14).a (18, 13, false, true, 48, 14).z ().str ())
                .port (0, 40)
                .port (60, 40);
            pid ("pid-relief-valve", _("Relief Valve"), 50, 60, "relief safety psv pressure valve")
                .fill (pen ().poly ({ 0, 20, 20, 30, 0, 40 }).poly ({ 10, 60, 20, 30, 30, 60 }).str ())
                .line (pen ().poly ({ 20, 30, 20, 26, 27, 23, 13, 19, 27, 15, 13, 11, 27, 7, 20, 4 }, false).line (13, 4, 27, 4).str ())
                .port (0, 30)
                .port (20, 60);
            pid ("pid-three-way-valve", _("Three-Way Valve"), 60, 45, "three way diverter valve")
                .fill (bowtie (0, 0, 60, 30))
                .fill (pen ().poly ({ 15, 45, 30, 15, 45, 45 }).str ())
                .port (0, 15)
                .port (60, 15)
                .port (30, 45);
            pid ("pid-pump", _("Centrifugal Pump"), 60, 60, "pump centrifugal")
                .fill (pen ().circle (30, 32, 26).str ())
                .line (pen ().line (30, 6, 60, 6).poly ({ 10, 52, 4, 60, 56, 60, 50, 52 }, false).str ())
                .port (0, 32)
                .port (60, 6);
            pid ("pid-pump-pd", _("Positive Displacement Pump"), 60, 60, "pump positive displacement gear piston")
                .fill (pen ().circle (30, 30, 26).str ())
                .line (pen ().rect (18, 18, 24, 24).line (0, 30, 4, 30).line (56, 30, 60, 30).str ())
                .port (0, 30)
                .port (60, 30);
            pid ("pid-compressor", _("Compressor"), 60, 60, "compressor gas")
                .fill (pen ().circle (30, 30, 26).str ())
                .line (pen ().line (10, 12, 50, 22).line (10, 48, 50, 38).str ())
                .port (0, 30)
                .port (60, 30);
            pid ("pid-fan", _("Fan or Blower"), 60, 60, "fan blower")
                .fill (pen ().circle (30, 30, 26).str ())
                .line (pen ().line (30, 30, 30, 8).line (30, 30, 49, 41).line (30, 30, 11, 41).str ())
                .port (0, 30)
                .port (60, 30);
            pid ("pid-tank-vertical", _("Vertical Tank"), 60, 120, "tank vessel storage vertical")
                .fill (pen ().m (0, 15).a (30, 15, false, true, 60, 15).l (60, 105).a (30, 15, false, true, 0, 105).z ().str ())
                .ports_box ();
            pid ("pid-tank-horizontal", _("Horizontal Tank"), 120, 60, "tank vessel drum horizontal")
                .fill (pen ().m (15, 0).l (105, 0).a (15, 30, false, true, 105, 60).l (15, 60).a (15, 30, false, true, 15, 0).z ().str ())
                .ports_box ();
            pid ("pid-tank-open", _("Open Tank"), 80, 70, "open tank basin atmospheric")
                .fill (pen ().poly ({ 0, 0, 0, 70, 80, 70, 80, 0 }, false).str ())
                .line (pen ().line (0, 20, 80, 20).str ())
                .ports_box ();
            pid ("pid-vessel", _("Pressure Vessel"), 50, 110, "vessel reactor pressure")
                .fill (pen ().m (0, 25).a (25, 25, false, true, 50, 25).l (50, 85).a (25, 25, false, true, 0, 85).z ().str ())
                .ports_box ();
            var trays = pen ().m (0, 20).a (20, 20, false, true, 40, 20).l (40, 140).a (20, 20, false, true, 0, 140).z ();
            for (int i = 0; i < 8; i++) trays.line (0, 34 + i * 13, 40, 34 + i * 13);
            pid ("pid-column", _("Distillation Column"), 40, 160, "column tower distillation trays")
                .fill (trays.str ())
                .ports_box ();
            pid ("pid-hx-shell", _("Shell and Tube Exchanger"), 120, 50, "heat exchanger shell tube")
                .fill (pen ().m (15, 0).l (105, 0).a (15, 25, false, true, 105, 50).l (15, 50).a (15, 25, false, true, 15, 0).z ().str ())
                .line (pen ().zigzag (10, 25, 110, 5, 14).str ())
                .port (0, 25)
                .port (120, 25)
                .port (30, 0)
                .port (90, 50);
            pid ("pid-hx-plate", _("Plate Heat Exchanger"), 60, 80, "plate heat exchanger")
                .fill (pen ().rect (0, 0, 60, 80).str ())
                .line (pen ().line (0, 0, 60, 80).line (60, 0, 0, 80).str ())
                .ports_box ();
            pid ("pid-cooler", _("Air Cooler"), 100, 50, "air cooler fin fan")
                .fill (pen ().rect (0, 0, 100, 30).str ())
                .line (pen ().zigzag (5, 15, 95, 6, 10).circle (50, 42, 8).line (42, 42, 58, 42).str ())
                .ports_box ();
            pid ("pid-furnace", _("Furnace"), 80, 100, "furnace fired heater")
                .fill (pen ().poly ({ 0, 30, 20, 0, 60, 0, 80, 30, 80, 100, 0, 100 }).str ())
                .line (pen ().m (10, 40).l (70, 40).l (70, 55).l (10, 55).l (10, 70).l (70, 70).str ())
                .ink (TechGlyphs.draw ("flame", 28, 74, 24), "#e25822")
                .ports_box ();
            pid ("pid-filter", _("Filter"), 50, 80, "filter strainer")
                .fill (pen ().rect (0, 0, 50, 80).str ())
                .line (pen ().line (25, 4, 25, 12).line (25, 18, 25, 26).line (25, 32, 25, 40).line (25, 46, 25, 54).line (25, 60, 25, 68).line (25, 72, 25, 76).str ())
                .port (0, 40)
                .port (50, 40);
            pid ("pid-mixer", _("Mixer"), 70, 100, "mixer agitator stirred tank")
                .fill (pen ().m (0, 20).a (35, 15, false, true, 70, 20).l (70, 88).a (35, 12, false, true, 0, 88).z ().str ())
                .line (pen ().line (35, 0, 35, 76).poly ({ 20, 70, 35, 76, 50, 70 }, false).poly ({ 20, 82, 35, 76, 50, 82 }, false).str ())
                .ports_box ();
            pid ("pid-separator", _("Separator"), 120, 70, "separator knockout drum boot")
                .fill (pen ().m (15, 0).l (105, 0).a (15, 25, false, true, 105, 50).l (70, 50).l (70, 70).l (50, 70).l (50, 50).l (15, 50).a (15, 25, false, true, 15, 0).z ().str ())
                .ports_box ();
            bubble ("pid-instrument", _("Field Instrument"), "field instrument bubble", "TI", 0);
            bubble ("pid-instrument-panel", _("Panel Instrument"), "panel mounted instrument", "PI", 1);
            bubble ("pid-instrument-dcs", _("DCS Function"), "dcs shared display control", "FIC", 2);
            bubble ("pid-instrument-plc", _("PLC Function"), "plc logic programmable", "LC", 3);
            bubble ("pid-flow-transmitter", _("Flow Transmitter"), "flow transmitter ft", "FT", 0);
            bubble ("pid-pressure-transmitter", _("Pressure Transmitter"), "pressure transmitter pt", "PT", 0);
            bubble ("pid-level-transmitter", _("Level Transmitter"), "level transmitter lt", "LT", 0);
            pid ("pid-flow-meter", _("Flow Meter"), 60, 30, "flow meter magnetic turbine")
                .fill (pen ().rect (15, 0, 30, 30).str ())
                .line (pen ().line (0, 15, 15, 15).line (45, 15, 60, 15).circle (30, 15, 8).str ())
                .port (0, 15)
                .port (60, 15);
            pid ("pid-orifice", _("Orifice Plate"), 40, 40, "orifice plate flow element")
                .line (pen ().line (0, 20, 16, 20).line (24, 20, 40, 20).line (16, 2, 16, 38).line (24, 2, 24, 38).str ())
                .port (0, 20)
                .port (40, 20);
            pid ("pid-reducer", _("Reducer"), 50, 30, "reducer concentric pipe")
                .fill (pen ().poly ({ 0, 0, 50, 8, 50, 22, 0, 30 }).str ())
                .port (0, 15)
                .port (50, 15);
            pid ("pid-flange", _("Flange"), 20, 40, "flange joint pipe")
                .line (pen ().line (6, 0, 6, 40).line (14, 0, 14, 40).line (0, 20, 6, 20).line (14, 20, 20, 20).str ())
                .port (0, 20)
                .port (20, 20);
            pid ("pid-cap", _("Pipe Cap"), 20, 30, "cap end pipe")
                .line (pen ().line (0, 15, 8, 15).m (8, 3).a (12, 12, false, true, 8, 27).z ().str ())
                .port (0, 15);
            pid ("pid-drain", _("Drain"), 30, 40, "drain funnel")
                .line (pen ().line (15, 0, 15, 22).poly ({ 3, 22, 27, 22, 15, 38 }).str ())
                .port (15, 0);
            pid ("pid-vent", _("Vent"), 30, 40, "vent atmosphere gooseneck")
                .line (pen ().m (15, 40).l (15, 12).a (7, 7, false, true, 29, 12).l (29, 20).str ())
                .port (15, 40);
            pid ("pid-nozzle", _("Spray Nozzle"), 40, 40, "spray nozzle sprinkler")
                .fill (pen ().poly ({ 12, 0, 28, 0, 20, 14 }).str ())
                .line (pen ().line (20, 14, 20, 40).line (20, 14, 4, 38).line (20, 14, 36, 38).line (20, 14, 10, 40).line (20, 14, 30, 40).str ())
                .port (20, 0);
        }

        private static unowned StencilDef ui (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw + " wireframe mockup ui")
                .box (w, h)
                .defaults (UI)
                .ports_box ();
        }

        private static string lines (double x, double y, double w, double step, int count) {
            var p = pen ();
            for (int i = 0; i < count; i++) p.line (x, y + i * step, x + (i == count - 1 ? w * 0.6 : w), y + i * step);
            return p.str ();
        }

        private static void register_wireframe () {
            Stencils.category ("wireframe", _("Wireframe"), "draw-shapes-symbolic", StencilGroup.SOFTWARE);
            ui ("ui-window", _("Window"), 400, 300, "window application frame")
                .fill (pen ().round (0, 0, 400, 300, 6).str ())
                .shade (pen ().m (0, 28).l (0, 6).a (6, 6, false, true, 6, 0).l (394, 0).a (6, 6, false, true, 400, 6).l (400, 28).z ().str ())
                .solid (pen ().circle (380, 14, 5).circle (362, 14, 5).circle (344, 14, 5).str (), "#c4c7cc")
                .label (10, 0, 300, 28)
                .defaults ("valign:top;halign:left;bold:1")
                .text (_("Window Title"))
                .as_container ();
            ui ("ui-browser", _("Browser Window"), 480, 320, "browser web page")
                .fill (pen ().round (0, 0, 480, 320, 6).str ())
                .shade (pen ().m (0, 44).l (0, 6).a (6, 6, false, true, 6, 0).l (474, 0).a (6, 6, false, true, 480, 6).l (480, 44).z ().str ())
                .fill (pen ().round (80, 10, 380, 24, 12).str ())
                .solid (pen ().circle (16, 22, 5).circle (32, 22, 5).circle (48, 22, 5).str (), "#c4c7cc")
                .label (92, 10, 360, 24)
                .defaults ("halign:left;font-size:9")
                .text ("https://example.org")
                .as_container ();
            ui ("ui-phone", _("Phone Frame"), 180, 360, "phone mobile screen")
                .fill (pen ().round (0, 0, 180, 360, 24).str ())
                .line (pen ().round (8, 12, 164, 336, 18).str ())
                .solid (pen ().round (62, 16, 56, 10, 5).str (), "#3c4043")
                .label (8, 30, 164, 320)
                .as_container ();
            ui ("ui-tablet", _("Tablet Frame"), 360, 480, "tablet screen")
                .fill (pen ().round (0, 0, 360, 480, 22).str ())
                .line (pen ().round (14, 20, 332, 440, 6).str ())
                .solid (pen ().circle (180, 10, 3).str (), "#3c4043")
                .as_container ();
            ui ("ui-dialog", _("Dialog"), 300, 180, "dialog modal alert")
                .fill (pen ().round (0, 0, 300, 180, 10).str ())
                .solid (pen ().round (136, 136, 70, 30, 6).str (), "#e8eaed")
                .solid (pen ().round (216, 136, 70, 30, 6).str (), "#3a6ea5")
                .line (lines (16, 60, 268, 14, 3))
                .label (16, 12, 268, 30)
                .defaults ("halign:left;valign:top;bold:1;font-size:12")
                .text (_("Dialog Title"));
            ui ("ui-button", _("Button"), 100, 32, "button action")
                .fill (pen ().round (0, 0, 100, 32, 6).str ())
                .defaults ("fill:#3a6ea5;stroke:#2c5a8a;text-color:#ffffff;bold:1")
                .text (_("Button"));
            ui ("ui-button-secondary", _("Secondary Button"), 100, 32, "button secondary outline")
                .fill (pen ().round (0, 0, 100, 32, 6).str ())
                .text (_("Cancel"));
            ui ("ui-text-field", _("Text Field"), 180, 30, "text field input entry")
                .fill (pen ().round (0, 0, 180, 30, 4).str ())
                .label (8, 0, 164, 30)
                .defaults ("halign:left;text-color:#80868b")
                .text (_("Placeholder"));
            ui ("ui-text-area", _("Text Area"), 220, 100, "text area multiline")
                .fill (pen ().round (0, 0, 220, 100, 4).str ())
                .line (pen ().line (206, 88, 214, 80).line (210, 92, 216, 86).str ())
                .label (8, 6, 200, 88)
                .defaults ("halign:left;valign:top;text-color:#80868b")
                .text (_("Type here"));
            ui ("ui-checkbox", _("Checkbox"), 120, 20, "checkbox checked option")
                .solid (pen ().round (1, 1, 18, 18, 3).str (), "#3a6ea5")
                .ink (pen ().poly ({ 5, 10, 9, 14, 15, 6 }, false).str (), "#ffffff")
                .label (26, 0, 94, 20)
                .defaults ("halign:left")
                .text (_("Option"));
            ui ("ui-checkbox-off", _("Unchecked Checkbox"), 120, 20, "checkbox unchecked")
                .fill (pen ().round (1, 1, 18, 18, 3).str ())
                .label (26, 0, 94, 20)
                .defaults ("halign:left")
                .text (_("Option"));
            ui ("ui-radio", _("Radio Button"), 120, 20, "radio option choice")
                .fill (pen ().circle (10, 10, 9).str ())
                .solid (pen ().circle (10, 10, 4.5).str (), "#3a6ea5")
                .label (26, 0, 94, 20)
                .defaults ("halign:left")
                .text (_("Choice"));
            ui ("ui-toggle", _("Toggle Switch"), 44, 24, "toggle switch on off")
                .solid (pen ().round (0, 0, 44, 24, 12).str (), "#3a6ea5")
                .solid (pen ().circle (32, 12, 9).str (), "#ffffff");
            ui ("ui-slider", _("Slider"), 160, 20, "slider range")
                .solid (pen ().round (0, 8, 160, 4, 2).str (), "#dadce0")
                .solid (pen ().round (0, 8, 90, 4, 2).str (), "#3a6ea5")
                .fill (pen ().circle (90, 10, 8).str ());
            ui ("ui-dropdown", _("Dropdown"), 160, 30, "dropdown select menu")
                .fill (pen ().round (0, 0, 160, 30, 4).str ())
                .ink (pen ().poly ({ 138, 12, 144, 18, 150, 12 }, false).str (), "#5f6368")
                .label (8, 0, 124, 30)
                .defaults ("halign:left")
                .text (_("Select"));
            ui ("ui-combo", _("Combo Box"), 160, 30, "combo box editable")
                .fill (pen ().round (0, 0, 160, 30, 4).str ())
                .line (pen ().line (128, 0, 128, 30).str ())
                .ink (pen ().poly ({ 138, 12, 144, 18, 150, 12 }, false).str (), "#5f6368")
                .label (8, 0, 116, 30)
                .defaults ("halign:left")
                .text (_("Value"));
            var rows = pen ().round (0, 0, 160, 140, 4);
            for (int i = 1; i < 5; i++) rows.line (0, i * 28, 160, i * 28);
            ui ("ui-list", _("List"), 160, 140, "list rows items")
                .fill (rows.str ())
                .solid (pen ().rect (1, 1, 158, 27).str (), "#e8f0fe");
            var grid = pen ().rect (0, 0, 240, 120);
            for (int i = 1; i < 5; i++) grid.line (0, i * 24, 240, i * 24);
            for (int i = 1; i < 4; i++) grid.line (i * 60, 0, i * 60, 120);
            ui ("ui-table", _("Data Table"), 240, 120, "table grid data")
                .fill (grid.str ())
                .shade (pen ().rect (0, 0, 240, 24).str ());
            ui ("ui-tabs", _("Tabs"), 240, 36, "tabs tab bar")
                .line (pen ().line (0, 35, 240, 35).str ())
                .fill (pen ().m (0, 35).l (0, 6).a (6, 6, false, true, 6, 0).l (74, 0).a (6, 6, false, true, 80, 6).l (80, 35).str ())
                .solid (pen ().rect (0, 33, 80, 3).str (), "#3a6ea5")
                .label (0, 0, 80, 34)
                .text (_("Tab"));
            ui ("ui-menu-bar", _("Menu Bar"), 300, 24, "menu bar")
                .shade (pen ().rect (0, 0, 300, 24).str ())
                .label (8, 0, 284, 24)
                .defaults ("halign:left")
                .text (_("File    Edit    View    Help"));
            ui ("ui-context-menu", _("Context Menu"), 140, 110, "context menu popup")
                .fill (pen ().round (0, 0, 140, 110, 6).str ())
                .line (pen ().line (8, 53, 132, 53).str ())
                .label (12, 6, 120, 100)
                .defaults ("halign:left;valign:top")
                .text (_("Cut\nCopy\nPaste\n\nDelete"));
            ui ("ui-tooltip", _("Tooltip"), 120, 40, "tooltip hint")
                .fill (pen ().poly ({ 4, 0, 116, 0, 120, 4, 120, 26, 116, 30, 66, 30, 60, 40, 54, 30, 4, 30, 0, 26, 0, 4 }).str ())
                .defaults ("fill:#3c4043;stroke:#3c4043;text-color:#ffffff;font-size:9")
                .label (0, 0, 120, 30)
                .text (_("Tooltip"));
            ui ("ui-progress", _("Progress Bar"), 160, 14, "progress bar loading")
                .fill (pen ().round (0, 0, 160, 14, 7).str ())
                .solid (pen ().round (1, 1, 100, 12, 6).str (), "#3a6ea5");
            var spin = pen ();
            for (int i = 0; i < 8; i++) {
                double ang = i * Math.PI / 4;
                spin.line (16 + 7 * Math.cos (ang), 16 + 7 * Math.sin (ang), 16 + 14 * Math.cos (ang), 16 + 14 * Math.sin (ang));
            }
            ui ("ui-spinner", _("Spinner"), 32, 32, "spinner loading busy")
                .ink (spin.str (), "#5f6368");
            ui ("ui-image", _("Image Placeholder"), 160, 120, "image picture placeholder")
                .fill (pen ().rect (0, 0, 160, 120).str ())
                .ink (pen ().poly ({ 20, 100, 60, 50, 90, 85, 110, 65, 140, 100 }).circle (115, 35, 10).str (), "#9aa0a6")
                .defaults ("fill:#f1f3f4");
            ui ("ui-avatar", _("Avatar"), 48, 48, "avatar profile picture user")
                .fill (pen ().circle (24, 24, 23).str ())
                .solid (pen ().circle (24, 18, 8).m (10, 40).c (12, 30, 36, 30, 38, 40).z ().str (), "#9aa0a6")
                .defaults ("fill:#e8eaed");
            ui ("ui-icon", _("Icon Placeholder"), 32, 32, "icon placeholder")
                .fill (pen ().rect (0, 0, 32, 32).str ())
                .line (pen ().line (0, 0, 32, 32).line (32, 0, 0, 32).str ());
            ui ("ui-heading", _("Heading"), 200, 30, "heading title text")
                .solid (pen ().rect (0, 0, 200, 30).str (), "#ffffff00")
                .defaults ("font-size:16;bold:1;halign:left;stroke:none")
                .text (_("Heading"));
            ui ("ui-paragraph", _("Paragraph"), 220, 70, "paragraph text lines body")
                .ink (lines (0, 8, 220, 14, 5), "#bdc1c6")
                .defaults ("stroke-width:4");
            ui ("ui-link", _("Link"), 80, 20, "link hyperlink")
                .solid (pen ().rect (0, 0, 80, 20).str (), "#ffffff00")
                .defaults ("text-color:#1a73e8;underline:1;stroke:none")
                .text (_("Link"));
            ui ("ui-breadcrumb", _("Breadcrumb"), 240, 20, "breadcrumb path navigation")
                .solid (pen ().rect (0, 0, 240, 20).str (), "#ffffff00")
                .ink (pen ().poly ({ 62, 6, 66, 10, 62, 14 }, false).poly ({ 142, 6, 146, 10, 142, 14 }, false).str (), "#80868b")
                .defaults ("stroke:none;halign:left;text-color:#1a73e8")
                .text (_("Home         Section         Page"));
            var pages = pen ();
            for (int i = 0; i < 5; i++) pages.round (i * 36, 0, 30, 30, 4);
            ui ("ui-pagination", _("Pagination"), 174, 30, "pagination pages")
                .fill (pages.str ())
                .solid (pen ().round (36, 0, 30, 30, 4).str (), "#3a6ea5")
                .ink (pen ().poly ({ 18, 9, 12, 15, 18, 21 }, false).poly ({ 156, 9, 162, 15, 156, 21 }, false).str (), "#5f6368");
            ui ("ui-card", _("Card"), 200, 150, "card tile panel")
                .fill (pen ().round (0, 0, 200, 150, 8).str ())
                .solid (pen ().m (0, 70).l (0, 8).a (8, 8, false, true, 8, 0).l (192, 0).a (8, 8, false, true, 200, 8).l (200, 70).z ().str (), "#e8eaed")
                .ink (lines (12, 108, 176, 12, 3), "#bdc1c6")
                .label (12, 76, 176, 22)
                .defaults ("halign:left;bold:1")
                .text (_("Card Title"));
            ui ("ui-navbar", _("Navigation Bar"), 400, 48, "navigation bar header app bar")
                .fill (pen ().rect (0, 0, 400, 48).str ())
                .solid (pen ().circle (24, 24, 12).str (), "#3a6ea5")
                .label (48, 0, 340, 48)
                .defaults ("fill:#f8f9fa;halign:left;bold:1")
                .text (_("Product          Features          Pricing"));
            ui ("ui-sidebar", _("Sidebar"), 160, 300, "sidebar navigation drawer")
                .fill (pen ().rect (0, 0, 160, 300).str ())
                .solid (pen ().round (8, 12, 144, 28, 6).str (), "#e8f0fe")
                .ink (lines (16, 70, 110, 30, 5), "#bdc1c6")
                .defaults ("fill:#f8f9fa;stroke-width:4");
            ui ("ui-search", _("Search Box"), 200, 32, "search box field")
                .fill (pen ().round (0, 0, 200, 32, 16).str ())
                .ink (TechGlyphs.draw ("search", 8, 6, 20), "#5f6368")
                .label (34, 0, 160, 32)
                .defaults ("halign:left;text-color:#80868b")
                .text (_("Search"));
            var cal = pen ().round (0, 0, 196, 170, 6).line (0, 30, 196, 30);
            for (int i = 1; i < 7; i++) cal.line (i * 28, 30, i * 28, 170);
            for (int i = 1; i < 5; i++) cal.line (0, 30 + i * 28, 196, 30 + i * 28);
            ui ("ui-date-picker", _("Date Picker"), 196, 170, "date picker calendar")
                .fill (cal.str ())
                .solid (pen ().rect (85, 87, 26, 26).str (), "#3a6ea5")
                .label (0, 0, 196, 30)
                .defaults ("bold:1")
                .text (_("June 2026"));
            ui ("ui-stepper", _("Stepper"), 220, 40, "stepper wizard steps progress")
                .line (pen ().line (20, 16, 200, 16).str ())
                .solid (pen ().circle (20, 16, 12).circle (110, 16, 12).str (), "#3a6ea5")
                .fill (pen ().circle (200, 16, 12).str ());
            ui ("ui-badge", _("Badge"), 40, 20, "badge count notification")
                .fill (pen ().round (0, 0, 40, 20, 10).str ())
                .defaults ("fill:#d93025;stroke:#d93025;text-color:#ffffff;bold:1;font-size:9")
                .text ("12");
            ui ("ui-toast", _("Toast"), 240, 44, "toast snackbar notification")
                .fill (pen ().round (0, 0, 240, 44, 8).str ())
                .defaults ("fill:#323232;stroke:#323232;text-color:#ffffff;halign:left")
                .label (14, 0, 212, 44)
                .text (_("Changes saved"));
            ui ("ui-modal", _("Modal Overlay"), 400, 300, "modal overlay scrim dialog")
                .solid (pen ().rect (0, 0, 400, 300).str (), "#00000066")
                .solid (pen ().round (100, 80, 200, 140, 10).str (), "#ffffff")
                .as_container ();
            ui ("ui-scrollbar", _("Scrollbar"), 12, 160, "scrollbar scroll")
                .solid (pen ().round (0, 0, 12, 160, 6).str (), "#f1f3f4")
                .solid (pen ().round (2, 20, 8, 50, 4).str (), "#9aa0a6");
            var keys = pen ().round (0, 0, 320, 120, 8);
            for (int r = 0; r < 3; r++) for (int i = 0; i < 10; i++) keys.round (8 + i * 30.4 + r * 8, 8 + r * 28, 26, 24, 3);
            keys.round (80, 92, 160, 22, 3);
            ui ("ui-keyboard", _("Keyboard"), 320, 120, "keyboard on screen keys")
                .fill (keys.str ())
                .defaults ("fill:#f1f3f4");
        }

        private static unowned StencilDef ft (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw + " fault tree fta")
                .box (w, h)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:9");
        }

        private static unowned StencilDef ft_gate (string kind, string name, string kw, string body) {
            return ft (kind, name, 60, 80, kw)
                .fill (body)
                .line (pen ().line (30, 0, 30, 12).line (30, 70, 30, 80).str ())
                .label (0, 82, 60, 14)
                .port (30, 0)
                .port (30, 80);
        }

        private static string and_gate () {
            return pen ().m (5, 70).l (5, 37).a (25, 25, false, true, 55, 37).l (55, 70).z ().str ();
        }

        private static string or_gate () {
            return pen ().m (5, 70).q (30, 58, 55, 70).q (55, 30, 30, 12).q (5, 30, 5, 70).z ().str ();
        }

        private static void register_fault_tree () {
            Stencils.category ("fault-tree", _("Fault Tree Analysis"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            ft_gate ("ft-and", _("AND Gate"), "and gate", and_gate ());
            ft_gate ("ft-or", _("OR Gate"), "or gate", or_gate ());
            ft_gate ("ft-priority-and", _("Priority AND Gate"), "priority and gate sequence", and_gate ())
                .line (pen ().line (10, 66, 50, 30).str ());
            ft_gate ("ft-xor", _("Exclusive OR Gate"), "xor exclusive gate", or_gate ())
                .line (pen ().m (5, 76).q (30, 64, 55, 76).str ());
            ft_gate ("ft-voting", _("Voting Gate"), "k out of n voting gate", or_gate ())
                .label (10, 38, 40, 22)
                .text ("k/n");
            ft_gate ("ft-inhibit", _("Inhibit Gate"), "inhibit condition gate", pen ().poly ({ 30, 12, 55, 26, 55, 56, 30, 70, 5, 56, 5, 26 }).str ());
            ft ("ft-basic", _("Basic Event"), 50, 50, "basic event primary failure")
                .fill (pen ().circle (25, 25, 24).str ())
                .label_below ()
                .port (25, 0);
            ft ("ft-undeveloped", _("Undeveloped Event"), 60, 40, "undeveloped event")
                .fill (pen ().poly ({ 30, 0, 60, 20, 30, 40, 0, 20 }).str ())
                .label_below ()
                .port (30, 0);
            ft ("ft-house", _("House Event"), 50, 50, "house event external normal")
                .fill (pen ().poly ({ 25, 0, 50, 18, 50, 50, 0, 50, 0, 18 }).str ())
                .label_below ()
                .port (25, 0);
            ft ("ft-conditioning", _("Conditioning Event"), 70, 40, "conditioning event condition")
                .fill (pen ().ellipse (35, 20, 34, 19).str ())
                .label (6, 4, 58, 32)
                .ports_box ();
            ft ("ft-intermediate", _("Intermediate Event"), 120, 50, "intermediate event top event description")
                .fill (pen ().rect (0, 0, 120, 50).str ())
                .label (4, 4, 112, 42)
                .port (60, 0)
                .port (60, 50);
            ft ("ft-transfer-in", _("Transfer In"), 50, 50, "transfer in triangle")
                .fill (pen ().poly ({ 25, 10, 50, 50, 0, 50 }).str ())
                .line (pen ().line (25, 0, 25, 10).str ())
                .port (25, 0);
            ft ("ft-transfer-out", _("Transfer Out"), 60, 50, "transfer out triangle")
                .fill (pen ().poly ({ 25, 10, 50, 50, 0, 50 }).str ())
                .line (pen ().line (37, 30, 60, 30).str ())
                .port (60, 30);
            ft ("ft-zero", _("Zero Event"), 50, 50, "zero event never occurs")
                .fill (pen ().circle (25, 25, 24).str ())
                .line (pen ().circle (25, 25, 16).str ())
                .port (25, 0);
        }

        private static unowned StencilDef mech (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:9")
                .label (0, h + 2, w, 14);
        }

        private static void register_mechanical () {
            Stencils.category ("mechanical", _("Mechanical and Fluid Power"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            var sp = pen ().m (15, 0).l (15, 8);
            for (int i = 0; i < 8; i++) sp.l (i % 2 == 0 ? 28 : 2, 12 + i * 8);
            sp.l (15, 72).l (15, 80);
            mech ("mech-spring", _("Spring"), 30, 80, "spring coil compression")
                .line (sp.str ())
                .port (15, 0)
                .port (15, 80);
            mech ("mech-gear", _("Gear"), 70, 70, "gear cog wheel")
                .fill (pen ().star (35, 35, 34, 27, 12, -90).str ())
                .line (pen ().circle (35, 35, 8).str ())
                .ports_box ();
            mech ("mech-bearing", _("Bearing"), 60, 60, "bearing ball roller")
                .fill (pen ().circle (30, 30, 29).str ())
                .line (pen ().circle (30, 30, 13).str ())
                .solid (pen ().circle (30, 9, 4).circle (51, 30, 4).circle (30, 51, 4).circle (9, 30, 4).circle (45, 15, 4).circle (15, 15, 4).circle (45, 45, 4).circle (15, 45, 4).str (), "@stroke")
                .ports_box ();
            mech ("mech-shaft", _("Shaft"), 160, 24, "shaft axle rod")
                .fill (pen ().rect (0, 0, 160, 24).str ())
                .ink (pen ().line (4, 12, 20, 12).line (28, 12, 32, 12).line (40, 12, 56, 12).line (64, 12, 68, 12).line (76, 12, 92, 12).line (100, 12, 104, 12).line (112, 12, 128, 12).line (136, 12, 140, 12).line (148, 12, 156, 12).str (), "@stroke")
                .port (0, 12)
                .port (160, 12);
            var thread = pen ().rect (14, 20, 12, 60);
            for (int i = 0; i < 9; i++) thread.line (14, 30 + i * 6, 26, 26 + i * 6);
            mech ("mech-bolt", _("Bolt"), 40, 80, "bolt screw fastener")
                .fill (pen ().rect (0, 0, 40, 20).str ())
                .fill (thread.str ())
                .ports_box ();
            mech ("mech-nut", _("Nut"), 50, 50, "nut hex fastener")
                .fill (pen ().regular (25, 25, 25, 6, 0).str ())
                .line (pen ().circle (25, 25, 11).str ())
                .ports_box ();
            mech ("mech-washer", _("Washer"), 50, 50, "washer ring")
                .fill (pen ().circle (25, 25, 24).str ())
                .fill (pen ().circle (25, 25, 10).str ())
                .ports_box ();
            mech ("mech-pulley", _("Pulley"), 60, 60, "pulley sheave wheel")
                .fill (pen ().circle (30, 30, 29).str ())
                .line (pen ().circle (30, 30, 22).circle (30, 30, 6).str ())
                .ports_box ();
            mech ("mech-belt", _("Belt Drive"), 160, 70, "belt drive pulleys")
                .fill (pen ().circle (35, 35, 30).circle (130, 35, 20).str ())
                .line (pen ().line (35, 5, 130, 15).line (35, 65, 130, 55).circle (35, 35, 5).circle (130, 35, 4).str ())
                .ports_box ();
            mech ("mech-cylinder", _("Hydraulic Cylinder"), 140, 40, "cylinder actuator piston ram")
                .fill (pen ().rect (0, 0, 90, 40).str ())
                .fill (pen ().rect (46, 6, 6, 28).str ())
                .line (pen ().line (52, 20, 140, 20).line (20, 40, 20, 46).line (76, 40, 76, 46).str ())
                .port (20, 40)
                .port (76, 40)
                .port (140, 20);
            mech ("mech-hyd-pump", _("Hydraulic Pump"), 50, 60, "hydraulic pump fluid power")
                .fill (pen ().circle (25, 30, 22).str ())
                .dark (pen ().poly ({ 25, 8, 17, 20, 33, 20 }).str ())
                .line (pen ().line (25, 52, 25, 60).line (25, 0, 25, 8).str ())
                .port (25, 0)
                .port (25, 60);
            mech ("mech-hyd-motor", _("Hydraulic Motor"), 50, 60, "hydraulic motor fluid power")
                .fill (pen ().circle (25, 30, 22).str ())
                .dark (pen ().poly ({ 25, 20, 17, 8, 33, 8 }).str ())
                .line (pen ().line (25, 52, 25, 60).line (25, 0, 25, 8).str ())
                .port (25, 0)
                .port (25, 60);
            mech ("mech-valve-22", _("2/2 Directional Valve"), 80, 50, "directional valve 2 2 fluid power")
                .fill (pen ().rect (0, 10, 40, 30).rect (40, 10, 40, 30).str ())
                .line (pen ().arrow (20, 36, 20, 14, 5).line (54, 36, 54, 26).line (48, 26, 60, 26).line (66, 14, 66, 24).line (60, 24, 72, 24).line (12, 40, 12, 50).line (28, 40, 28, 50).str ())
                .port (12, 50)
                .port (28, 50);
            mech ("mech-valve-42", _("4/2 Directional Valve"), 80, 60, "directional valve 4 2 fluid power")
                .fill (pen ().rect (0, 15, 40, 30).rect (40, 15, 40, 30).str ())
                .line (pen ().arrow (10, 42, 10, 18, 5).arrow (30, 18, 30, 42, 5).arrow (50, 42, 70, 18, 5).arrow (70, 42, 50, 18, 5).line (10, 45, 10, 60).line (30, 45, 30, 60).line (10, 0, 10, 15).line (30, 0, 30, 15).str ())
                .port (10, 0)
                .port (30, 0)
                .port (10, 60)
                .port (30, 60);
            mech ("mech-accumulator", _("Accumulator"), 40, 70, "accumulator gas bladder")
                .fill (pen ().round (0, 0, 40, 62, 20).str ())
                .line (pen ().line (0, 31, 40, 31).line (20, 62, 20, 70).str ())
                .port (20, 70);
            mech ("mech-reservoir", _("Reservoir"), 60, 40, "reservoir tank fluid")
                .line (pen ().poly ({ 0, 0, 0, 40, 60, 40, 60, 0 }, false).line (20, 0, 20, 30).line (40, 0, 40, 30).str ())
                .port (20, 0)
                .port (40, 0);
            mech ("mech-fluid-filter", _("Fluid Filter"), 50, 50, "filter strainer fluid")
                .fill (pen ().poly ({ 25, 0, 50, 25, 25, 50, 0, 25 }).str ())
                .line (pen ().line (8, 25, 14, 25).line (19, 25, 25, 25).line (30, 25, 36, 25).line (40, 25, 42, 25).str ())
                .port (25, 0)
                .port (25, 50);
            mech ("mech-check-valve", _("Fluid Check Valve"), 40, 50, "check valve ball seat")
                .fill (pen ().circle (20, 28, 9).str ())
                .line (pen ().poly ({ 8, 40, 20, 18, 32, 40 }, false).line (20, 0, 20, 19).line (20, 37, 20, 50).str ())
                .port (20, 0)
                .port (20, 50);
            mech ("mech-gauge", _("Pressure Gauge"), 50, 60, "pressure gauge manometer")
                .fill (pen ().circle (25, 25, 23).str ())
                .line (pen ().arrow (14, 36, 34, 14, 5).line (25, 48, 25, 60).str ())
                .port (25, 60);
        }

        public static void register () {
            register_pid ();
            register_wireframe ();
            register_fault_tree ();
            register_mechanical ();
        }
    }
}
