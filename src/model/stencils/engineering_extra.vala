namespace Singularity.Apps.Draw {

    public class StencilsEngineeringExtra {
        private const string INK = "fill-kind:none;stroke:#1e1e1e;stroke-width:1.5;font-size:9";
        private const string PART = "fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:9";

        private static TechPen pen () {
            return new TechPen ();
        }

        private static unowned StencilDef sym (string kind, string name, double w, double h, string kw, string style = INK) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults (style)
                .label (0, h + 2, w, 14);
        }

        private static unowned StencilDef two (string kind, string name, string kw, string body) {
            return sym (kind, name, 80, 30, kw)
                .line (pen ().line (0, 15, 20, 15).line (60, 15, 80, 15).str ())
                .line (body)
                .port (0, 15)
                .port (80, 15);
        }

        private static string tri (double x, double y, bool right) {
            return right ? pen ().poly ({ x, y - 10, x + 20, y, x, y + 10 }).str () : pen ().poly ({ x + 20, y - 10, x, y, x + 20, y + 10 }).str ();
        }

        private static string arrows_in (double x, double y) {
            return pen ().arrow (x, y, x + 8, y + 8, 3).arrow (x + 7, y - 2, x + 15, y + 6, 3).str ();
        }

        private static string arrows_out (double x, double y) {
            return pen ().arrow (x, y, x + 8, y - 8, 3).arrow (x + 6, y + 2, x + 14, y - 6, 3).str ();
        }

        private static unowned StencilDef diode (string kind, string name, string kw, string extra) {
            return two (kind, name, kw, pen ().line (20, 15, 60, 15).line (50, 5, 50, 25).str () + (extra != "" ? " " + extra : ""))
                .dark (tri (30, 15, true));
        }

        private static unowned StencilDef circled (string kind, string name, string kw, string letter, double w = 60) {
            return sym (kind, name, w, 40, kw)
                .line (pen ().line (0, 20, w / 2 - 16, 20).line (w / 2 + 16, 20, w, 20).circle (w / 2, 20, 16).str ())
                .text (letter)
                .label (w / 2 - 14, 8, 28, 24)
                .port (0, 20)
                .port (w, 20);
        }

        private static unowned StencilDef contact (string kind, string name, string kw, bool closed, string actuator) {
            var p = pen ().line (0, 25, 22, 25).line (58, 25, 80, 25);
            if (closed) p.line (22, 25, 60, 18).line (58, 25, 58, 14);
            else p.line (22, 25, 54, 10);
            return sym (kind, name, 80, 34, kw)
                .line (p.str ())
                .line (actuator)
                .port (0, 25)
                .port (80, 25);
        }

        private static void register_electrical () {
            Stencils.category ("electrical-power", _("Electrical: Power and Control"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            diode ("elx-varactor", _("Varactor Diode"), "varicap tuning diode capacitance", pen ().line (55, 5, 55, 25).str ());
            diode ("elx-tvs", _("TVS Diode"), "transient voltage suppressor protection", pen ().m (46, 1).l (50, 5).m (50, 25).l (54, 29).str ())
                .dark (tri (50, 15, false));
            diode ("elx-tunnel", _("Tunnel Diode"), "esaki tunnel diode", pen ().line (50, 5, 46, 5).line (50, 25, 46, 25).str ());
            diode ("elx-laser-diode", _("Laser Diode"), "laser diode emitter", pen ().line (34, 2, 34, 28).str ())
                .ink (arrows_out (44, -1));
            two ("elx-diac", _("DIAC"), "diac trigger diode bidirectional", pen ().line (20, 15, 60, 15).line (40, 2, 40, 28).line (44, 2, 44, 28).str ())
                .dark (pen ().poly ({ 24, 2, 40, 9, 24, 15 }).poly ({ 60, 15, 44, 21, 60, 28 }).str ());
            sym ("elx-triac", _("TRIAC"), 80, 44, "triac ac switch thyristor")
                .line (pen ().line (0, 15, 80, 15).line (36, 2, 36, 28).line (44, 2, 44, 28).line (44, 28, 58, 44).str ())
                .dark (pen ().poly ({ 20, 2, 36, 9, 20, 15 }).poly ({ 60, 15, 44, 21, 60, 28 }).str ())
                .port (0, 15).port (80, 15).port (58, 44);
            sym ("elx-scr", _("Thyristor (SCR)"), 80, 44, "scr silicon controlled rectifier thyristor")
                .line (pen ().line (0, 15, 80, 15).line (50, 5, 50, 25).line (50, 25, 62, 44).str ())
                .dark (tri (30, 15, true))
                .port (0, 15).port (80, 15).port (62, 44);
            sym ("elx-gto", _("GTO Thyristor"), 80, 44, "gate turn off thyristor")
                .line (pen ().line (0, 15, 80, 15).line (50, 5, 50, 25).line (50, 25, 62, 44).line (54, 33, 60, 30).str ())
                .dark (tri (30, 15, true))
                .port (0, 15).port (80, 15).port (62, 44);
            sym ("elx-darlington", _("Darlington Transistor"), 80, 80, "darlington pair npn transistor")
                .line (pen ().circle (44, 40, 34).line (0, 40, 18, 40).line (18, 26, 18, 54).line (18, 32, 36, 18).line (18, 48, 30, 56).line (30, 56, 30, 34).line (30, 34, 34, 34).line (34, 22, 34, 46).line (34, 28, 58, 6).line (34, 40, 58, 66).line (58, 66, 58, 80).line (58, 6, 58, 0).line (36, 18, 58, 6).str ())
                .ink (pen ().arrow (40, 46, 54, 62, 4).str ())
                .port (0, 40).port (58, 0).port (58, 80);
            sym ("elx-phototransistor", _("Phototransistor"), 80, 70, "photo transistor light sensor")
                .line (pen ().circle (44, 35, 24).line (34, 22, 34, 48).line (34, 30, 54, 14).line (54, 14, 54, 0).line (34, 40, 54, 56).line (54, 56, 54, 70).str ())
                .ink (pen ().arrow (42, 46, 52, 54, 4).str ())
                .ink (arrows_in (4, 14))
                .port (54, 0).port (54, 70);
            sym ("elx-igbt", _("IGBT"), 80, 70, "insulated gate bipolar transistor")
                .line (pen ().line (0, 45, 24, 45).line (24, 25, 24, 45).line (30, 22, 30, 48).line (30, 28, 50, 14).line (50, 14, 50, 0).line (30, 42, 50, 56).line (50, 56, 50, 70).str ())
                .ink (pen ().arrow (38, 48, 48, 55, 4).str ())
                .port (0, 45).port (50, 0).port (50, 70);
            sym ("elx-nmos-depletion", _("N-Channel MOSFET (Depletion)"), 70, 70, "depletion mode nmos fet")
                .line (pen ().line (0, 50, 20, 50).line (20, 22, 20, 50).line (28, 18, 28, 52).line (28, 22, 50, 22).line (50, 22, 50, 0).line (28, 48, 50, 48).line (50, 48, 50, 70).line (28, 35, 50, 35).line (50, 35, 50, 48).str ())
                .ink (pen ().arrow (46, 35, 31, 35, 4).str ())
                .port (0, 50).port (50, 0).port (50, 70);
            sym ("elx-pmos-depletion", _("P-Channel MOSFET (Depletion)"), 70, 70, "depletion mode pmos fet")
                .line (pen ().line (0, 50, 20, 50).line (20, 22, 20, 50).line (28, 18, 28, 52).line (28, 22, 50, 22).line (50, 22, 50, 0).line (28, 48, 50, 48).line (50, 48, 50, 70).line (28, 35, 50, 35).line (50, 35, 50, 48).str ())
                .ink (pen ().arrow (31, 35, 46, 35, 4).str ())
                .port (0, 50).port (50, 0).port (50, 70);
            sym ("elx-pjfet", _("P-Channel JFET"), 70, 70, "pjfet junction field effect transistor")
                .line (pen ().circle (37, 35, 22).line (0, 45, 28, 45).line (28, 20, 28, 50).line (28, 25, 46, 25).line (46, 25, 46, 0).line (28, 45, 46, 45).line (46, 45, 46, 70).str ())
                .ink (pen ().arrow (26, 45, 12, 45, 5).str ())
                .port (0, 45).port (46, 0).port (46, 70);
            sym ("elx-ujt", _("Unijunction Transistor"), 70, 70, "ujt unijunction")
                .line (pen ().circle (37, 35, 22).line (28, 18, 28, 52).line (28, 24, 46, 24).line (46, 24, 46, 0).line (28, 46, 46, 46).line (46, 46, 46, 70).line (0, 50, 16, 50).str ())
                .ink (pen ().arrow (12, 52, 27, 40, 4).str ())
                .port (0, 50).port (46, 0).port (46, 70);
            sym ("elx-optocoupler", _("Optocoupler"), 100, 70, "optoisolator opto coupler isolation")
                .line (pen ().rect (10, 0, 80, 70).line (0, 15, 30, 15).line (30, 15, 30, 25).line (30, 45, 30, 55).line (0, 55, 30, 55).line (20, 25, 40, 25).line (64, 22, 64, 48).line (64, 30, 80, 18).line (80, 18, 100, 18).line (64, 40, 80, 52).line (80, 52, 100, 52).str ())
                .dark (pen ().poly ({ 20, 45, 40, 45, 30, 25 }).str ())
                .ink (pen ().arrow (42, 30, 56, 36, 3).arrow (42, 40, 56, 46, 3).str ())
                .port (0, 15).port (0, 55).port (100, 18).port (100, 52);
            two ("elx-varistor", _("Varistor"), "mov metal oxide varistor vdr", pen ().rect (20, 9, 40, 12).m (14, 26).l (24, 26).l (56, 4).str ());
            two ("elx-ntc", _("NTC Thermistor"), "ntc negative temperature coefficient", pen ().rect (20, 9, 40, 12).m (16, 28).l (24, 28).l (56, 2).str ())
                .text ("-t°");
            two ("elx-ptc", _("PTC Thermistor"), "ptc positive temperature coefficient", pen ().rect (20, 9, 40, 12).m (16, 28).l (24, 28).l (56, 2).str ())
                .text ("+t°");
            two ("elx-trimmer-cap", _("Trimmer Capacitor"), "trimmer capacitor preset", pen ().line (37, 2, 37, 28).line (43, 2, 43, 28).line (28, 26, 52, 4).line (48, 1, 55, 7).str ());
            two ("elx-ferrite", _("Ferrite Bead"), "ferrite bead emi filter", pen ().round (24, 6, 32, 18, 3).line (28, 2, 52, 28).str ());
            two ("elx-inductor-variable", _("Variable Inductor"), "variable inductor tuning coil", pen ().m (20, 15).a (5, 5, false, true, 30, 15).a (5, 5, false, true, 40, 15).a (5, 5, false, true, 50, 15).a (5, 5, false, true, 60, 15).arrow (24, 28, 58, 0, 4).str ());
            sym ("elx-inductor-tapped", _("Tapped Inductor"), 80, 40, "center tap inductor coil")
                .line (pen ().line (0, 15, 20, 15).line (60, 15, 80, 15).m (20, 15).a (5, 5, false, true, 30, 15).a (5, 5, false, true, 40, 15).a (5, 5, false, true, 50, 15).a (5, 5, false, true, 60, 15).line (40, 15, 40, 40).str ())
                .port (0, 15).port (80, 15).port (40, 40);
            sym ("elx-transformer-ct", _("Center Tapped Transformer"), 70, 70, "center tap transformer")
                .line (pen ().line (0, 15, 20, 15).line (0, 55, 20, 55).line (40, 15, 70, 15).line (40, 55, 70, 55).line (40, 35, 70, 35).line (28, 12, 28, 58).line (32, 12, 32, 58).str ())
                .line (pen ().m (20, 15).a (5, 5, false, true, 20, 25).a (5, 5, false, true, 20, 35).a (5, 5, false, true, 20, 45).a (5, 5, false, true, 20, 55).str ())
                .line (pen ().m (40, 15).a (5, 5, false, false, 40, 25).a (5, 5, false, false, 40, 35).a (5, 5, false, false, 40, 45).a (5, 5, false, false, 40, 55).str ())
                .port (0, 15).port (0, 55).port (70, 15).port (70, 35).port (70, 55);
            sym ("elx-autotransformer", _("Autotransformer"), 60, 80, "autotransformer variac")
                .line (pen ().line (0, 10, 30, 10).line (0, 70, 30, 70).line (30, 40, 60, 40).line (60, 70, 30, 70).m (30, 10).a (6, 6, false, true, 30, 22).a (6, 6, false, true, 30, 34).a (6, 6, false, true, 30, 46).a (6, 6, false, true, 30, 58).a (6, 6, false, true, 30, 70).str ())
                .ink (pen ().arrow (50, 66, 36, 30, 4).str ())
                .port (0, 10).port (0, 70).port (60, 40).port (60, 70);
            sym ("elx-current-transformer", _("Current Transformer"), 80, 40, "ct current transformer measuring")
                .line (pen ().line (0, 20, 80, 20).circle (40, 20, 12).line (34, 32, 34, 40).line (46, 32, 46, 40).str ())
                .port (0, 20).port (80, 20).port (34, 40).port (46, 40);
            circled ("elx-wattmeter", _("Wattmeter"), "watt meter power", "W");
            circled ("elx-frequency-meter", _("Frequency Meter"), "frequency hertz meter", "Hz");
            circled ("elx-energy-meter", _("Energy Meter"), "kwh energy meter", "Wh");
            circled ("elx-power-factor", _("Power Factor Meter"), "cos phi power factor", "cosφ");
            circled ("elx-galvanometer", _("Galvanometer"), "galvanometer current detector", "")
                .ink (pen ().arrow (20, 32, 40, 8, 4).str ());
            circled ("elx-tachometer", _("Tachometer"), "rpm speed meter", "n");
            circled ("elx-motor-3ph", _("Three-Phase Motor"), "three phase induction motor", "M3~");
            circled ("elx-motor-dc", _("DC Motor"), "dc motor brushed", "M=");
            circled ("elx-stepper", _("Stepper Motor"), "stepper stepping motor", "MS");
            circled ("elx-servo", _("Servo Motor"), "servomotor feedback", "SM");
            circled ("elx-alternator", _("Alternator"), "alternator ac generator", "G~");
            circled ("elx-lamp-signal", _("Signal Lamp"), "indicator pilot lamp", "×");
            sym ("elx-thermocouple", _("Thermocouple"), 70, 40, "thermocouple temperature sensor")
                .line (pen ().line (0, 10, 40, 10).line (0, 30, 40, 30).line (40, 10, 56, 20).line (40, 30, 56, 20).str ())
                .solid (pen ().circle (56, 20, 3).str (), "@stroke")
                .port (0, 10).port (0, 30);
            sym ("elx-hall", _("Hall Sensor"), 60, 50, "hall effect magnetic sensor")
                .line (pen ().rect (10, 10, 40, 30).line (30, 0, 30, 10).line (30, 40, 30, 50).line (0, 25, 10, 25).line (50, 25, 60, 25).str ())
                .text ("H")
                .label (10, 10, 40, 30)
                .port (30, 0).port (30, 50).port (0, 25).port (60, 25);
            two ("elx-strain-gauge", _("Strain Gauge"), "strain gauge load cell", pen ().rect (20, 9, 40, 12).arrow (26, 26, 54, 26, 4).str ());
            sym ("elx-reed", _("Reed Switch"), 80, 30, "reed switch magnetic")
                .line (pen ().line (0, 15, 30, 15).line (50, 15, 80, 15).line (30, 15, 48, 11).round (18, 4, 44, 22, 10).str ())
                .port (0, 15).port (80, 15);
            contact ("elx-limit-no", _("Limit Switch (NO)"), "limit switch position normally open", false, pen ().m (34, 4).l (40, 0).l (46, 4).str ());
            contact ("elx-limit-nc", _("Limit Switch (NC)"), "limit switch position normally closed", true, pen ().m (34, 4).l (40, 0).l (46, 4).str ());
            contact ("elx-float-switch", _("Float Switch"), "level float switch", false, pen ().line (38, 16, 38, 2).circle (38, 0, 4).str ());
            contact ("elx-pressure-switch", _("Pressure Switch"), "pressure switch pressostat", false, pen ().line (38, 16, 38, 6).poly ({ 30, 6, 46, 6, 38, 0 }).str ());
            contact ("elx-temperature-switch", _("Temperature Switch"), "thermostat temperature switch", false, pen ().line (38, 16, 38, 6).m (32, 6).l (36, 0).l (40, 6).l (44, 0).str ());
            contact ("elx-key-switch", _("Key Switch"), "key operated switch", false, pen ().line (38, 16, 38, 6).circle (38, 3, 3).line (41, 3, 50, 3).str ());
            contact ("elx-foot-switch", _("Foot Switch"), "pedal foot switch", false, pen ().line (38, 16, 38, 8).poly ({ 30, 8, 48, 8, 44, 2, 30, 2 }).str ());
            contact ("elx-emergency-stop", _("Emergency Stop"), "emergency stop e-stop mushroom", true, pen ().line (40, 14, 40, 6).m (30, 6).a (10, 6, false, true, 50, 6).l (30, 6).str ());
            contact ("elx-time-on", _("Time Delay Contact (On)"), "timer on delay contact", false, pen ().line (40, 16, 40, 8).m (32, 0).a (8, 8, false, false, 48, 0).str ());
            contact ("elx-time-off", _("Time Delay Contact (Off)"), "timer off delay contact", false, pen ().line (40, 16, 40, 8).m (32, 8).a (8, 8, false, true, 48, 8).str ());
            sym ("elx-selector-3", _("Three-Position Selector"), 80, 50, "selector switch hand off auto")
                .line (pen ().line (0, 25, 22, 25).line (22, 25, 54, 25).line (60, 5, 80, 5).line (60, 25, 80, 25).line (60, 45, 80, 45).str ())
                .solid (pen ().circle (22, 25, 2).circle (58, 5, 2).circle (58, 25, 2).circle (58, 45, 2).str (), "@stroke")
                .port (0, 25).port (80, 5).port (80, 25).port (80, 45);
            sym ("elx-rotary", _("Rotary Switch"), 80, 60, "rotary selector switch multi position")
                .line (pen ().line (0, 30, 22, 30).line (22, 30, 52, 14).arc (22, 30, 34, -60, 60).str ())
                .solid (pen ().circle (22, 30, 2).circle (39, 0.6, 2).circle (52, 13, 2).circle (56, 30, 2).circle (52, 47, 2).circle (39, 59.4, 2).str (), "@stroke")
                .port (0, 30);
            two ("elx-ssr", _("Solid State Relay"), "ssr solid state relay", pen ().rect (24, 3, 32, 24).line (24, 27, 56, 3).str ())
                .text ("SSR");
            two ("elx-contactor-coil", _("Contactor Coil"), "contactor coil km", pen ().rect (26, 3, 28, 24).str ())
                .text ("K");
            sym ("elx-contactor-3p", _("Three-Pole Contactor"), 90, 60, "three pole main contactor")
                .line (pen ().line (15, 0, 15, 20).line (15, 20, 25, 42).line (15, 44, 15, 60).line (45, 0, 45, 20).line (45, 20, 55, 42).line (45, 44, 45, 60).line (75, 0, 75, 20).line (75, 20, 85, 42).line (75, 44, 75, 60).line (20, 31, 80, 31).str ())
                .solid (pen ().circle (15, 44, 2).circle (45, 44, 2).circle (75, 44, 2).str (), "@stroke")
                .port (15, 0).port (45, 0).port (75, 0).port (15, 60).port (45, 60).port (75, 60);
            sym ("elx-overload", _("Thermal Overload Relay"), 90, 50, "thermal overload protection relay")
                .line (pen ().rect (5, 10, 80, 30).line (15, 0, 15, 10).line (45, 0, 45, 10).line (75, 0, 75, 10).line (15, 40, 15, 50).line (45, 40, 45, 50).line (75, 40, 75, 50).m (35, 30).l (35, 20).l (55, 20).l (55, 30).str ())
                .port (15, 0).port (45, 0).port (75, 0).port (15, 50).port (45, 50).port (75, 50);
            two ("elx-rcd", _("Residual Current Device"), "rcd rccb gfci earth leakage", pen ().line (22, 15, 54, 2).round (30, 18, 20, 10, 5).str ());
            sym ("elx-surge", _("Surge Arrester"), 40, 70, "surge arrester lightning protection spd")
                .line (pen ().line (20, 0, 20, 15).rect (10, 15, 20, 36).line (20, 51, 20, 60).line (8, 60, 32, 60).line (12, 65, 28, 65).line (16, 70, 24, 70).str ())
                .ink (pen ().arrow (20, 22, 20, 44, 4).str ())
                .port (20, 0);
            two ("elx-disconnector", _("Disconnector"), "isolator disconnect switch", pen ().line (22, 15, 54, 2).line (58, 9, 58, 21).str ());
            two ("elx-fuse-switch", _("Fuse Switch"), "fuse switch disconnector", pen ().line (22, 15, 54, 2).str ())
                .fill (pen ().poly ({ 32, 7, 46, 1, 48, 6, 34, 12 }).str ());
            two ("elx-thermal-fuse", _("Thermal Fuse"), "thermal cutoff fuse", pen ().rect (22, 9, 36, 12).line (20, 15, 60, 15).m (34, 28).l (38, 24).l (42, 28).l (46, 24).str ());
            two ("elx-spark-gap", _("Spark Gap"), "spark gap discharge", pen ().line (20, 15, 34, 15).line (46, 15, 60, 15).poly ({ 34, 10, 40, 15, 34, 20 }, false).poly ({ 46, 10, 40, 15, 46, 20 }, false).str ());
            two ("elx-piezo", _("Piezoelectric Element"), "piezo crystal transducer", pen ().line (34, 4, 34, 26).line (46, 4, 46, 26).rect (37, 8, 6, 14).str ());
            two ("elx-solenoid", _("Solenoid"), "solenoid actuator coil", pen ().rect (24, 4, 32, 22).line (28, 4, 28, 26).line (52, 4, 52, 26).str ());
            two ("elx-electromagnet", _("Electromagnet"), "electromagnet coil iron", pen ().m (20, 15).a (5, 5, false, true, 30, 15).a (5, 5, false, true, 40, 15).a (5, 5, false, true, 50, 15).a (5, 5, false, true, 60, 15).line (18, 26, 62, 26).str ());
            two ("elx-bell", _("Bell"), "bell alarm ringer", pen ().m (26, 26).a (14, 14, false, true, 54, 26).l (26, 26).str ());
            two ("elx-siren", _("Siren"), "siren alarm sounder", pen ().poly ({ 28, 8, 52, 8, 56, 26, 24, 26 }).line (34, 8, 34, 2).line (46, 8, 46, 2).str ());
            two ("elx-horn", _("Horn"), "horn klaxon audible", pen ().poly ({ 26, 10, 34, 10, 52, 0, 52, 30, 34, 20, 26, 20 }).str ());
            two ("elx-earphone", _("Earphone"), "earphone headphone receiver", pen ().m (26, 24).a (14, 14, false, true, 54, 24).line (26, 24, 26, 15).line (54, 24, 54, 15).str ());
            two ("elx-neon", _("Neon Lamp"), "neon glow lamp indicator", pen ().ellipse (40, 15, 16, 12).line (32, 15, 37, 15).line (43, 15, 48, 15).str ())
                .solid (pen ().circle (35, 15, 2).str (), "@stroke");
            two ("elx-fluorescent", _("Fluorescent Lamp"), "fluorescent tube lamp", pen ().rect (22, 6, 36, 18).line (26, 10, 26, 20).line (54, 10, 54, 20).str ());
            two ("elx-coax", _("Coaxial Cable"), "coax shielded cable rf", pen ().line (20, 15, 60, 15).ellipse (40, 15, 10, 8).str ());
            two ("elx-shielded", _("Shielded Conductor"), "shielded wire screen cable", pen ().line (20, 15, 60, 15).line (24, 7, 56, 7).line (24, 23, 56, 23).str ());
            two ("elx-twisted-pair", _("Twisted Pair"), "twisted pair cable", pen ().m (20, 10).c (30, 10, 30, 20, 40, 20).c (50, 20, 50, 10, 60, 10).m (20, 20).c (30, 20, 30, 10, 40, 10).c (50, 10, 50, 20, 60, 20).str ());
            sym ("elx-busbar", _("Busbar"), 160, 20, "busbar bus rail")
                .fill (pen ().rect (0, 6, 160, 8).str ())
                .defaults ("fill:#1e1e1e")
                .port (0, 10).port (40, 10).port (80, 10).port (120, 10).port (160, 10);
            sym ("elx-crossing", _("Wire Crossing"), 40, 40, "wire crossover hop")
                .line (pen ().line (0, 20, 14, 20).m (14, 20).a (6, 6, false, true, 26, 20).line (26, 20, 40, 20).line (20, 0, 20, 40).str ())
                .port (0, 20).port (40, 20).port (20, 0).port (20, 40);
            sym ("elx-test-point", _("Test Point"), 30, 40, "test point probe tp")
                .line (pen ().line (15, 40, 15, 16).circle (15, 9, 7).str ())
                .port (15, 40);
            sym ("elx-earth-protective", _("Protective Earth"), 40, 40, "protective earth pe ground")
                .line (pen ().circle (20, 22, 17).line (20, 0, 20, 18).line (10, 18, 30, 18).line (13, 24, 27, 24).line (16, 30, 24, 30).str ())
                .port (20, 0);
            sym ("elx-noiseless-earth", _("Noiseless Earth"), 40, 40, "clean earth functional ground")
                .line (pen ().line (20, 0, 20, 18).line (6, 18, 34, 18).line (10, 24, 30, 24).line (14, 30, 26, 30).m (4, 22).a (16, 16, false, false, 36, 22).str ())
                .port (20, 0);
            sym ("elx-dc-supply", _("DC Power Supply"), 80, 60, "power supply psu ac dc converter", PART)
                .fill (pen ().rect (10, 0, 60, 60).line (10, 60, 70, 0).str ())
                .line (pen ().line (0, 30, 10, 30).line (70, 30, 80, 30).m (16, 14).q (20, 8, 24, 14).q (28, 20, 32, 14).line (50, 46, 62, 46).line (50, 50, 62, 50).str ())
                .port (0, 30).port (80, 30);
            sym ("elx-inverter", _("Inverter"), 80, 60, "inverter dc ac converter", PART)
                .fill (pen ().rect (10, 0, 60, 60).line (10, 60, 70, 0).str ())
                .line (pen ().line (0, 30, 10, 30).line (70, 30, 80, 30).line (18, 14, 30, 14).line (18, 18, 30, 18).m (48, 46).q (52, 40, 56, 46).q (60, 52, 64, 46).str ())
                .port (0, 30).port (80, 30);
            sym ("elx-rectifier-block", _("Rectifier"), 80, 60, "rectifier ac dc block", PART)
                .fill (pen ().rect (10, 0, 60, 60).line (10, 60, 70, 0).str ())
                .line (pen ().line (0, 30, 10, 30).line (70, 30, 80, 30).m (16, 14).q (20, 8, 24, 14).q (28, 20, 32, 14).line (50, 46, 62, 46).str ())
                .dark (pen ().poly ({ 50, 36, 58, 40, 50, 44 }).str ())
                .port (0, 30).port (80, 30);
            sym ("elx-ups-block", _("Uninterruptible Supply"), 80, 60, "ups uninterruptible power supply", PART)
                .fill (pen ().rect (10, 0, 60, 60).str ())
                .line (pen ().line (0, 30, 10, 30).line (70, 30, 80, 30).line (30, 40, 30, 52).line (36, 44, 36, 48).line (42, 40, 42, 52).line (48, 44, 48, 48).str ())
                .text ("UPS")
                .label (10, 4, 60, 30)
                .port (0, 30).port (80, 30);
            sym ("elx-vfd", _("Variable Frequency Drive"), 80, 60, "vfd inverter drive motor speed", PART)
                .fill (pen ().rect (10, 0, 60, 60).str ())
                .line (pen ().line (0, 30, 10, 30).line (70, 30, 80, 30).str ())
                .text ("VFD")
                .label (10, 0, 60, 60)
                .port (0, 30).port (80, 30);
            sym ("elx-plc", _("PLC Module"), 90, 70, "plc programmable logic controller io", PART)
                .fill (pen ().rect (0, 0, 90, 70).str ())
                .line (pen ().rect (6, 6, 78, 16).str ())
                .solid (pen ().circle (12, 34, 2).circle (24, 34, 2).circle (36, 34, 2).circle (48, 34, 2).circle (60, 34, 2).circle (72, 34, 2).circle (12, 58, 2).circle (24, 58, 2).circle (36, 58, 2).circle (48, 58, 2).circle (60, 58, 2).circle (72, 58, 2).str (), "@stroke")
                .text ("PLC")
                .label (6, 6, 78, 16)
                .ports_box ();
            sym ("elx-555", _("Timer IC 555"), 80, 80, "555 timer ic astable", PART)
                .fill (pen ().rect (15, 0, 50, 80).str ())
                .line (pen ().line (0, 15, 15, 15).line (0, 35, 15, 35).line (0, 55, 15, 55).line (65, 15, 80, 15).line (65, 40, 80, 40).line (65, 65, 80, 65).str ())
                .text ("555")
                .label (15, 0, 50, 80)
                .port (0, 15).port (0, 35).port (0, 55).port (80, 15).port (80, 40).port (80, 65);
            sym ("elx-microcontroller", _("Microcontroller"), 100, 100, "mcu microcontroller chip", PART)
                .fill (pen ().rect (15, 15, 70, 70).str ())
                .line (pen ().line (25, 0, 25, 15).line (41, 0, 41, 15).line (59, 0, 59, 15).line (75, 0, 75, 15).line (25, 85, 25, 100).line (41, 85, 41, 100).line (59, 85, 59, 100).line (75, 85, 75, 100).line (0, 25, 15, 25).line (0, 41, 15, 41).line (0, 59, 15, 59).line (0, 75, 15, 75).line (85, 25, 100, 25).line (85, 41, 100, 41).line (85, 59, 100, 59).line (85, 75, 100, 75).str ())
                .text ("MCU")
                .label (15, 15, 70, 70)
                .ports_box ();
            two ("elx-fuse-ansi", _("Fuse (ANSI)"), "fuse ansi s curve", pen ().m (20, 15).c (28, 2, 36, 2, 40, 15).c (44, 28, 52, 28, 60, 15).str ());
            two ("elx-battery-rechargeable", _("Rechargeable Battery"), "accumulator rechargeable cell", pen ().line (34, 3, 34, 27).line (40, 9, 40, 21).line (46, 3, 46, 27).arrow (28, 28, 54, 2, 4).str ());
        }

        private static string position_flow (string pattern, double x) {
            var p = pen ();
            double top = 10, bot = 40;
            switch (pattern) {
                case "open":
                    p.arrow (x + 15, bot - 2, x + 15, top + 2, 4);
                    break;
                case "closed":
                    p.line (x + 15, bot, x + 15, bot - 8).line (x + 10, bot - 8, x + 20, bot - 8).line (x + 15, top, x + 15, top + 8).line (x + 10, top + 8, x + 20, top + 8);
                    break;
                case "p-a":
                    p.arrow (x + 10, bot - 2, x + 10, top + 2, 4).line (x + 22, bot, x + 22, bot - 8).line (x + 17, bot - 8, x + 27, bot - 8);
                    break;
                case "a-t":
                    p.arrow (x + 10, top + 2, x + 22, bot - 2, 4).line (x + 10, bot, x + 10, bot - 8).line (x + 5, bot - 8, x + 15, bot - 8);
                    break;
                case "par4":
                    p.arrow (x + 8, bot - 2, x + 8, top + 2, 4).arrow (x + 22, top + 2, x + 22, bot - 2, 4);
                    break;
                case "x4":
                    p.arrow (x + 8, bot - 2, x + 22, top + 2, 4).arrow (x + 8, top + 2, x + 22, bot - 2, 4);
                    break;
                case "closed4":
                    foreach (double px in new double[] { x + 8, x + 22 }) {
                        p.line (px, bot, px, bot - 7).line (px - 4, bot - 7, px + 4, bot - 7).line (px, top, px, top + 7).line (px - 4, top + 7, px + 4, top + 7);
                    }
                    break;
                case "open4":
                    p.line (x + 8, top, x + 8, bot).line (x + 22, top, x + 22, bot).line (x + 8, 25, x + 22, 25);
                    break;
                case "tandem4":
                    p.line (x + 8, bot, x + 8, 30).line (x + 8, 30, x + 22, 30).line (x + 22, 30, x + 22, bot).line (x + 8, top, x + 8, top + 7).line (x + 4, top + 7, x + 12, top + 7).line (x + 22, top, x + 22, top + 7).line (x + 18, top + 7, x + 26, top + 7);
                    break;
                case "float4":
                    p.line (x + 8, top, x + 8, 30).line (x + 22, top, x + 22, bot).line (x + 8, 30, x + 22, 30).line (x + 8, bot, x + 8, bot - 7).line (x + 4, bot - 7, x + 12, bot - 7);
                    break;
                case "par5":
                    p.arrow (x + 15, bot - 2, x + 9, top + 2, 4).arrow (x + 21, top + 2, x + 26, bot - 2, 4).line (x + 4, bot, x + 4, bot - 7).line (x + 1, bot - 7, x + 7, bot - 7);
                    break;
                case "x5":
                    p.arrow (x + 15, bot - 2, x + 21, top + 2, 4).arrow (x + 9, top + 2, x + 4, bot - 2, 4).line (x + 26, bot, x + 26, bot - 7).line (x + 23, bot - 7, x + 29, bot - 7);
                    break;
                case "closed5":
                    foreach (double px in new double[] { x + 4, x + 15, x + 26 }) p.line (px, bot, px, bot - 7).line (px - 3, bot - 7, px + 3, bot - 7);
                    foreach (double px in new double[] { x + 9, x + 21 }) p.line (px, top, px, top + 7).line (px - 3, top + 7, px + 3, top + 7);
                    break;
                case "exhaust5":
                    p.arrow (x + 9, top + 2, x + 4, bot - 2, 4).arrow (x + 21, top + 2, x + 26, bot - 2, 4).line (x + 15, bot, x + 15, bot - 7).line (x + 12, bot - 7, x + 18, bot - 7);
                    break;
                case "pressure5":
                    p.arrow (x + 15, bot - 2, x + 9, top + 2, 4).arrow (x + 15, bot - 2, x + 21, top + 2, 4);
                    foreach (double px in new double[] { x + 4, x + 26 }) p.line (px, bot, px, bot - 7).line (px - 3, bot - 7, px + 3, bot - 7);
                    break;
            }
            return p.str ();
        }

        private static string actuator (string act, double x, bool left) {
            var p = pen ();
            double d = left ? -1 : 1;
            switch (act) {
                case "solenoid":
                    double sx = left ? x - 14 : x;
                    p.rect (sx, 15, 14, 20).line (sx, 35, sx + 14, 15);
                    break;
                case "spring":
                    p.m (x, 25);
                    for (int i = 0; i < 5; i++) p.l (x + d * (3 + i * 3), i % 2 == 0 ? 19 : 31);
                    p.l (x + d * 16, 25);
                    break;
                case "lever":
                    p.line (x, 25, x + d * 8, 25).line (x + d * 8, 25, x + d * 16, 14).circle (x + d * 16, 12, 2);
                    break;
                case "button":
                    p.line (x, 25, x + d * 8, 25).m (x + d * 8, 17).a (8, 8, false, !left, x + d * 8, 33);
                    break;
                case "pilot":
                    p.line (x, 25, x + d * 4, 25).poly ({ x + d * 4, 18, x + d * 4, 32, x + d * 14, 25 }).line (x + d * 14, 25, x + d * 20, 25);
                    break;
                case "detent":
                    p.line (x, 25, x + d * 10, 25).m (x + d * 6, 21).l (x + d * 10, 25).l (x + d * 6, 29);
                    break;
            }
            return p.str ();
        }

        private static void valve (string body_id, string body_name, string[] positions, int port_count, string left, string right, string act_id, string act_name) {
            int n = positions.length;
            double w = n * 30 + 40;
            double x0 = 20;
            var boxes = pen ();
            for (int i = 0; i < n; i++) boxes.rect (x0 + i * 30, 10, 30, 30);
            var flows = new StringBuilder ();
            for (int i = 0; i < n; i++) flows.append (position_flow (positions[i], x0 + i * 30)).append (" ");
            int normal = n == 3 ? 1 : n - 1;
            double nx = x0 + normal * 30;
            var lines = pen ();
            double[] bottom = {}, top = {};
            switch (port_count) {
                case 2: bottom = { 15 }; top = { 15 }; break;
                case 3: bottom = { 10, 22 }; top = { 10 }; break;
                case 4: bottom = { 8, 22 }; top = { 8, 22 }; break;
                default: bottom = { 4, 15, 26 }; top = { 9, 21 }; break;
            }
            foreach (double b in bottom) lines.line (nx + b, 40, nx + b, 50);
            foreach (double t in top) lines.line (nx + t, 0, nx + t, 10);
            string kw = "%s directional control valve fluid power iso 1219 pneumatic hydraulic %s".printf (body_name, act_name.down ());
            unowned StencilDef d = sym ("fp-valve-%s-%s".printf (body_id, act_id), _("%s Valve, %s").printf (body_name, act_name), w, 50, kw, PART)
                .fill (boxes.str ())
                .line (flows.str.strip ())
                .line (lines.str ())
                .line (actuator (left, x0, true))
                .line (actuator (right, x0 + n * 30, false));
            foreach (double b in bottom) d.port (nx + b, 50);
            foreach (double t in top) d.port (nx + t, 0);
        }

        private static void register_fluid_power () {
            Stencils.category ("fluid-power", _("Fluid Power (ISO 1219)"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            string[,] bodies2 = {
                { "22nc", "2/2 Normally Closed", "open,closed", "2" },
                { "22no", "2/2 Normally Open", "closed,open", "2" },
                { "32nc", "3/2 Normally Closed", "p-a,a-t", "3" },
                { "32no", "3/2 Normally Open", "a-t,p-a", "3" },
                { "42", "4/2", "par4,x4", "4" },
                { "52", "5/2", "par5,x5", "5" },
                { "42d", "4/2 Detented", "par4,x4", "4" }
            };
            string[,] acts2 = {
                { "sol", "Solenoid and Spring", "solenoid", "spring" },
                { "dsol", "Double Solenoid", "solenoid", "solenoid" },
                { "lever", "Lever and Spring", "lever", "spring" },
                { "button", "Push Button and Spring", "button", "spring" },
                { "pilot", "Pilot and Spring", "pilot", "spring" }
            };
            for (int b = 0; b < bodies2.length[0]; b++) {
                for (int a = 0; a < acts2.length[0]; a++) {
                    string right = acts2[a, 3];
                    if (bodies2[b, 0] == "42d") {
                        if (a != 1 && a != 2) continue;
                        right = "detent";
                    }
                    valve (bodies2[b, 0], _(bodies2[b, 1]), bodies2[b, 2].split (","), int.parse (bodies2[b, 3]), acts2[a, 2], right, acts2[a, 0], _(acts2[a, 1]));
                }
            }
            string[,] bodies3 = {
                { "43cc", "4/3 Closed Center", "par4,closed4,x4", "4" },
                { "43oc", "4/3 Open Center", "par4,open4,x4", "4" },
                { "43tc", "4/3 Tandem Center", "par4,tandem4,x4", "4" },
                { "43fc", "4/3 Float Center", "par4,float4,x4", "4" },
                { "53cc", "5/3 Closed Center", "par5,closed5,x5", "5" },
                { "53ec", "5/3 Exhaust Center", "par5,exhaust5,x5", "5" },
                { "53pc", "5/3 Pressure Center", "par5,pressure5,x5", "5" }
            };
            string[,] acts3 = {
                { "sol", "Solenoids, Spring Centered", "solenoid", "solenoid" },
                { "lever", "Lever", "lever", "detent" },
                { "pilot", "Pilots, Spring Centered", "pilot", "pilot" }
            };
            for (int b = 0; b < bodies3.length[0]; b++) {
                for (int a = 0; a < acts3.length[0]; a++) {
                    valve (bodies3[b, 0], _(bodies3[b, 1]), bodies3[b, 2].split (","), int.parse (bodies3[b, 3]), acts3[a, 2], acts3[a, 3], acts3[a, 0], _(acts3[a, 1]));
                }
            }
            sym ("fp-cyl-single", _("Single-Acting Cylinder, Spring Return"), 140, 48, "single acting cylinder spring return pneumatic", PART)
                .fill (pen ().rect (0, 0, 90, 40).str ())
                .fill (pen ().rect (16, 4, 6, 32).str ())
                .line (pen ().line (22, 20, 140, 20).zigzag (24, 26, 88, 5, 5).line (6, 40, 6, 48).str ())
                .port (6, 48).port (140, 20);
            sym ("fp-cyl-double", _("Double-Acting Cylinder"), 140, 48, "double acting cylinder", PART)
                .fill (pen ().rect (0, 0, 90, 40).str ())
                .fill (pen ().rect (46, 4, 6, 32).str ())
                .line (pen ().line (52, 20, 140, 20).line (8, 40, 8, 48).line (82, 40, 82, 48).str ())
                .port (8, 48).port (82, 48).port (140, 20);
            sym ("fp-cyl-double-rod", _("Double-Rod Cylinder"), 160, 48, "through rod double ended cylinder", PART)
                .fill (pen ().rect (30, 0, 100, 40).str ())
                .fill (pen ().rect (77, 4, 6, 32).str ())
                .line (pen ().line (0, 20, 77, 20).line (83, 20, 160, 20).line (38, 40, 38, 48).line (122, 40, 122, 48).str ())
                .port (38, 48).port (122, 48).port (0, 20).port (160, 20);
            sym ("fp-cyl-cushion", _("Cylinder with Adjustable Cushions"), 140, 48, "cushioned cylinder damping", PART)
                .fill (pen ().rect (0, 0, 90, 40).str ())
                .fill (pen ().rect (46, 4, 6, 32).str ())
                .line (pen ().line (52, 20, 140, 20).rect (4, 12, 8, 16).rect (78, 12, 8, 16).arrow (2, 34, 14, 6, 3).arrow (76, 34, 88, 6, 3).line (8, 40, 8, 48).line (82, 40, 82, 48).str ())
                .port (8, 48).port (82, 48).port (140, 20);
            sym ("fp-cyl-telescopic", _("Telescopic Cylinder"), 160, 48, "telescopic multi stage cylinder", PART)
                .fill (pen ().rect (0, 0, 70, 40).rect (70, 6, 40, 28).str ())
                .line (pen ().line (110, 20, 160, 20).line (8, 40, 8, 48).str ())
                .port (8, 48).port (160, 20);
            sym ("fp-rotary-actuator", _("Rotary Actuator"), 60, 60, "semi rotary actuator oscillating", PART)
                .fill (pen ().circle (30, 30, 22).str ())
                .line (pen ().arc (30, 30, 14, 200, 340).line (16, 52, 16, 60).line (44, 52, 44, 60).str ())
                .ink (pen ().arrow (17, 25, 13, 34, 4).arrow (43, 25, 47, 34, 4).str ())
                .port (16, 60).port (44, 60);
            sym ("fp-air-motor", _("Pneumatic Motor"), 60, 70, "air motor pneumatic rotation", PART)
                .fill (pen ().circle (30, 35, 22).str ())
                .line (pen ().poly ({ 30, 23, 22, 13, 38, 13 }).line (30, 0, 30, 13).line (30, 57, 30, 70).line (52, 35, 60, 35).str ())
                .port (30, 0).port (30, 70).port (60, 35);
            sym ("fp-compressor", _("Air Compressor"), 60, 70, "compressor air supply pneumatic", PART)
                .fill (pen ().circle (30, 35, 22).str ())
                .line (pen ().poly ({ 30, 13, 22, 23, 38, 23 }).line (30, 0, 30, 13).line (30, 57, 30, 70).str ())
                .port (30, 0).port (30, 70);
            sym ("fp-vacuum-pump", _("Vacuum Pump"), 60, 70, "vacuum pump generator", PART)
                .fill (pen ().circle (30, 35, 22).str ())
                .line (pen ().poly ({ 30, 57, 22, 47, 38, 47 }).line (30, 0, 30, 13).line (30, 57, 30, 70).str ())
                .port (30, 0).port (30, 70);
            sym ("fp-variable-pump", _("Variable Displacement Pump"), 70, 70, "variable pump adjustable hydraulic", PART)
                .fill (pen ().circle (35, 35, 22).str ())
                .dark (pen ().poly ({ 35, 13, 27, 25, 43, 25 }).str ())
                .line (pen ().line (35, 0, 35, 13).line (35, 57, 35, 70).arrow (8, 62, 62, 8, 5).str ())
                .port (35, 0).port (35, 70);
            sym ("fp-frl", _("Filter Regulator Lubricator"), 120, 60, "frl air preparation unit", PART)
                .fill (pen ().rect (10, 0, 100, 60).str ())
                .line (pen ().line (0, 30, 10, 30).line (110, 30, 120, 30).line (43, 0, 43, 60).line (77, 0, 77, 60).poly ({ 26, 14, 36, 30, 26, 46, 16, 30 }).line (16, 30, 36, 30).poly ({ 94, 14, 104, 30, 94, 46, 84, 30 }).line (94, 46, 94, 34).str ())
                .ink (pen ().arrow (52, 44, 68, 16, 4).str ())
                .port (0, 30).port (120, 30);
            sym ("fp-filter-water", _("Filter with Water Separator"), 50, 60, "water separator drain filter", PART)
                .fill (pen ().poly ({ 25, 6, 47, 30, 25, 54, 3, 30 }).str ())
                .line (pen ().line (0, 30, 3, 30).line (47, 30, 50, 30).line (10, 30, 40, 30).line (25, 54, 25, 60).line (18, 44, 32, 44).str ())
                .port (0, 30).port (50, 30).port (25, 60);
            sym ("fp-lubricator", _("Lubricator"), 50, 60, "oil lubricator mist", PART)
                .fill (pen ().poly ({ 25, 6, 47, 30, 25, 54, 3, 30 }).str ())
                .line (pen ().line (0, 30, 3, 30).line (47, 30, 50, 30).line (25, 22, 25, 46).str ())
                .port (0, 30).port (50, 30);
            sym ("fp-regulator", _("Pressure Regulator"), 60, 60, "pressure reducing regulator valve", PART)
                .fill (pen ().rect (10, 10, 40, 40).str ())
                .line (pen ().line (0, 30, 10, 30).line (50, 30, 60, 30).line (30, 50, 30, 60).str ())
                .ink (pen ().arrow (16, 44, 44, 16, 4).arrow (22, 30, 38, 30, 4).str ())
                .port (0, 30).port (60, 30);
            sym ("fp-relief", _("Pressure Relief Valve"), 60, 60, "relief safety valve", PART)
                .fill (pen ().rect (10, 10, 40, 40).str ())
                .line (pen ().line (30, 50, 30, 60).line (30, 0, 30, 10).m (50, 30).l (54, 26).l (58, 34).l (60, 30).line (14, 20, 26, 20).str ())
                .ink (pen ().arrow (36, 46, 36, 14, 4).str ())
                .port (30, 0).port (30, 60);
            sym ("fp-sequence", _("Sequence Valve"), 60, 60, "sequence valve pressure", PART)
                .fill (pen ().rect (10, 10, 40, 40).str ())
                .line (pen ().line (30, 50, 30, 60).line (30, 0, 30, 10).m (50, 30).l (54, 26).l (58, 34).l (60, 30).line (14, 50, 14, 58).str ())
                .ink (pen ().arrow (26, 46, 34, 14, 4).str ())
                .port (30, 0).port (30, 60).port (14, 58);
            sym ("fp-flow-control", _("Flow Control Valve"), 80, 40, "throttle flow control needle", PART)
                .line (pen ().line (0, 20, 30, 20).line (50, 20, 80, 20).m (30, 10).q (40, 20, 30, 30).m (50, 10).q (40, 20, 50, 30).arrow (28, 36, 52, 4, 4).str ())
                .port (0, 20).port (80, 20);
            sym ("fp-flow-check", _("One-Way Flow Control Valve"), 80, 60, "flow control with check valve bypass", PART)
                .fill (pen ().rect (10, 0, 60, 60).str ())
                .line (pen ().line (0, 30, 10, 30).line (70, 30, 80, 30).m (30, 8).q (40, 18, 30, 26).m (50, 8).q (40, 18, 50, 26).circle (40, 44, 6).line (30, 52, 36, 48).line (50, 52, 44, 48).str ())
                .port (0, 30).port (80, 30);
            sym ("fp-shuttle", _("Shuttle Valve"), 60, 50, "shuttle or valve", PART)
                .fill (pen ().rect (10, 10, 40, 30).str ())
                .line (pen ().line (0, 25, 10, 25).line (50, 25, 60, 25).line (30, 0, 30, 10).circle (30, 25, 6).line (14, 15, 22, 25).line (14, 35, 22, 25).line (46, 15, 38, 25).line (46, 35, 38, 25).str ())
                .port (0, 25).port (60, 25).port (30, 0);
            sym ("fp-quick-exhaust", _("Quick Exhaust Valve"), 60, 60, "quick exhaust fast venting", PART)
                .fill (pen ().rect (10, 10, 40, 40).str ())
                .line (pen ().line (0, 30, 10, 30).line (50, 30, 60, 30).line (30, 50, 30, 60).circle (30, 30, 6).line (24, 52, 36, 52).str ())
                .port (0, 30).port (60, 30).port (30, 60);
            sym ("fp-silencer", _("Silencer"), 40, 40, "muffler exhaust silencer", PART)
                .fill (pen ().rect (8, 12, 24, 28).str ())
                .line (pen ().line (20, 0, 20, 12).line (12, 18, 28, 18).line (12, 24, 28, 24).line (12, 30, 28, 30).str ())
                .port (20, 0);
            sym ("fp-air-dryer", _("Air Dryer"), 50, 60, "air dryer desiccant", PART)
                .fill (pen ().poly ({ 25, 6, 47, 30, 25, 54, 3, 30 }).str ())
                .line (pen ().line (0, 30, 3, 30).line (47, 30, 50, 30).line (14, 18, 36, 42).line (14, 42, 36, 18).str ())
                .port (0, 30).port (50, 30);
            sym ("fp-cooler", _("Fluid Cooler"), 50, 60, "cooler heat exchanger hydraulic", PART)
                .fill (pen ().poly ({ 25, 6, 47, 30, 25, 54, 3, 30 }).str ())
                .line (pen ().line (0, 30, 3, 30).line (47, 30, 50, 30).str ())
                .ink (pen ().arrow (25, 20, 25, 6, 4).arrow (25, 40, 25, 54, 4).str ())
                .port (0, 30).port (50, 30);
            sym ("fp-heater", _("Fluid Heater"), 50, 60, "heater heat exchanger hydraulic", PART)
                .fill (pen ().poly ({ 25, 6, 47, 30, 25, 54, 3, 30 }).str ())
                .line (pen ().line (0, 30, 3, 30).line (47, 30, 50, 30).str ())
                .ink (pen ().arrow (25, 8, 25, 22, 4).arrow (25, 52, 25, 38, 4).str ())
                .port (0, 30).port (50, 30);
            sym ("fp-pressure-switch", _("Fluid Pressure Switch"), 60, 50, "pressure switch transducer", PART)
                .fill (pen ().rect (16, 10, 36, 30).str ())
                .line (pen ().line (0, 25, 16, 25).line (24, 32, 44, 18).line (44, 18, 44, 14).str ())
                .solid (pen ().circle (24, 32, 2).str (), "@stroke")
                .port (0, 25);
            sym ("fp-flow-meter", _("Fluid Flow Meter"), 50, 60, "flowmeter flow measurement", PART)
                .fill (pen ().circle (25, 30, 18).str ())
                .line (pen ().line (25, 0, 25, 12).line (25, 48, 25, 60).str ())
                .ink (pen ().arrow (25, 42, 25, 18, 4).str ())
                .port (25, 0).port (25, 60);
            sym ("fp-thermometer", _("Fluid Thermometer"), 40, 60, "temperature gauge thermometer", PART)
                .fill (pen ().circle (20, 30, 16).str ())
                .line (pen ().line (20, 46, 20, 60).line (20, 20, 20, 36).str ())
                .solid (pen ().circle (20, 38, 4).str (), "@stroke")
                .port (20, 60);
            sym ("fp-pressure-source", _("Pressure Source"), 40, 40, "pneumatic pressure source supply", PART)
                .fill (pen ().circle (20, 20, 14).str ())
                .solid (pen ().circle (20, 20, 4).str (), "@stroke")
                .line (pen ().line (20, 34, 20, 40).str ())
                .port (20, 40);
            sym ("fp-exhaust", _("Exhaust Port"), 40, 30, "exhaust vent atmosphere", PART)
                .line (pen ().line (20, 0, 20, 14).poly ({ 8, 14, 32, 14, 20, 28 }).str ())
                .port (20, 0);
            sym ("fp-plugged-port", _("Plugged Port"), 30, 30, "blocked plugged port", PART)
                .line (pen ().line (15, 0, 15, 16).line (5, 16, 25, 16).str ())
                .port (15, 0);
            sym ("fp-quick-coupling", _("Quick Coupling"), 70, 30, "quick connect coupling", PART)
                .line (pen ().line (0, 15, 24, 15).line (46, 15, 70, 15).line (24, 6, 24, 24).line (46, 6, 46, 24).line (30, 15, 40, 15).str ())
                .dark (pen ().poly ({ 30, 10, 36, 15, 30, 20 }).poly ({ 40, 10, 34, 15, 40, 20 }).str ())
                .port (0, 15).port (70, 15);
            sym ("fp-rotary-joint", _("Rotary Joint"), 50, 50, "rotary union swivel joint", PART)
                .line (pen ().circle (25, 25, 12).line (0, 25, 13, 25).line (37, 25, 50, 25).circle (25, 25, 4).str ())
                .port (0, 25).port (50, 25);
            sym ("fp-intensifier", _("Pressure Intensifier"), 120, 50, "booster intensifier multiplier", PART)
                .fill (pen ().rect (0, 0, 60, 50).rect (60, 15, 40, 20).str ())
                .line (pen ().line (100, 25, 120, 25).line (30, 0, 30, 50).str ())
                .port (0, 25).port (120, 25);
            sym ("fp-hose", _("Flexible Hose"), 80, 30, "hose flexible line", PART)
                .line (pen ().line (0, 15, 14, 15).m (14, 15).c (30, 0, 50, 30, 66, 15).line (66, 15, 80, 15).str ())
                .port (0, 15).port (80, 15);
            sym ("fp-pilot-line", _("Pilot Line"), 80, 20, "pilot control line dashed", PART)
                .line (StencilKit.dashed_line (0, 10, 80, 10, 6, 4))
                .port (0, 10).port (80, 10);
        }

        private static void register_hvac () {
            Stencils.category ("hvac", _("HVAC"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            string duct = "fill:#eef4fa;stroke:#2f5f8f;stroke-width:1.2;font-size:9";
            sym ("hvac-diffuser-square", _("Square Supply Diffuser"), 60, 60, "ceiling diffuser supply air four way", duct)
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().rect (10, 10, 40, 40).rect (20, 20, 20, 20).line (0, 0, 20, 20).line (60, 0, 40, 20).line (0, 60, 20, 40).line (60, 60, 40, 40).str ())
                .ports_box ();
            sym ("hvac-diffuser-round", _("Round Diffuser"), 60, 60, "round ceiling diffuser", duct)
                .fill (pen ().circle (30, 30, 29).str ())
                .line (pen ().circle (30, 30, 20).circle (30, 30, 11).str ())
                .ports_box ();
            sym ("hvac-linear-diffuser", _("Linear Slot Diffuser"), 160, 24, "slot linear diffuser", duct)
                .fill (pen ().rect (0, 0, 160, 24).str ())
                .line (pen ().line (6, 8, 154, 8).line (6, 16, 154, 16).str ())
                .ports_box ();
            sym ("hvac-exhaust-grille", _("Exhaust Grille"), 60, 60, "exhaust extract grille", duct)
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().line (0, 0, 60, 60).line (60, 0, 0, 60).str ())
                .ports_box ();
            sym ("hvac-exhaust-fan", _("Exhaust Fan"), 60, 60, "extract fan ventilation", duct)
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().circle (30, 30, 22).m (30, 30).q (40, 14, 30, 8).m (30, 30).q (46, 40, 52, 30).m (30, 30).q (20, 46, 10, 40).m (30, 30).q (14, 20, 12, 28).str ())
                .ports_box ();
            sym ("hvac-ahu", _("Air Handling Unit"), 200, 70, "ahu air handler", duct)
                .fill (pen ().rect (0, 0, 200, 70).str ())
                .line (pen ().line (40, 0, 40, 70).line (80, 0, 80, 70).line (120, 0, 120, 70).line (160, 0, 160, 70).line (8, 10, 32, 60).line (16, 10, 40, 60).circle (100, 35, 16).line (128, 10, 152, 60).line (152, 10, 128, 60).str ())
                .text ("AHU")
                .label (160, 0, 40, 70)
                .ports_box ();
            sym ("hvac-fcu", _("Fan Coil Unit"), 100, 50, "fcu fan coil", duct)
                .fill (pen ().rect (0, 0, 100, 50).str ())
                .line (pen ().circle (30, 25, 14).zigzag (56, 25, 92, 4, 10).str ())
                .ports_box ();
            sym ("hvac-vav", _("VAV Box"), 100, 50, "variable air volume terminal", duct)
                .fill (pen ().rect (0, 0, 100, 50).str ())
                .line (pen ().line (20, 40, 40, 10).circle (30, 25, 3).str ())
                .text ("VAV")
                .label (46, 0, 54, 50)
                .ports_box ();
            sym ("hvac-damper-volume", _("Volume Damper"), 60, 40, "balancing damper", duct)
                .fill (pen ().rect (0, 0, 60, 40).str ())
                .line (pen ().line (14, 32, 46, 8).str ())
                .solid (pen ().circle (30, 20, 3).str (), "@stroke")
                .port (0, 20).port (60, 20);
            sym ("hvac-damper-fire", _("Fire Damper"), 60, 40, "fire damper fd", duct)
                .fill (pen ().rect (0, 0, 60, 40).str ())
                .line (pen ().line (0, 0, 60, 40).line (60, 0, 0, 40).str ())
                .text ("FD")
                .port (0, 20).port (60, 20);
            sym ("hvac-damper-backdraft", _("Backdraft Damper"), 60, 40, "gravity backdraft damper", duct)
                .fill (pen ().rect (0, 0, 60, 40).str ())
                .line (pen ().line (10, 4, 22, 16).line (24, 4, 36, 16).line (38, 4, 50, 16).str ())
                .port (0, 20).port (60, 20);
            sym ("hvac-duct", _("Rectangular Duct"), 200, 40, "duct straight supply", duct)
                .fill (pen ().rect (0, 0, 200, 40).str ())
                .line (pen ().line (0, 0, 200, 40).str ())
                .port (0, 20).port (200, 20);
            sym ("hvac-duct-round", _("Round Duct"), 200, 40, "spiral round duct", duct)
                .fill (pen ().rect (0, 0, 200, 40).str ())
                .line (pen ().line (0, 20, 200, 20).str ())
                .port (0, 20).port (200, 20);
            sym ("hvac-elbow", _("Duct Elbow"), 100, 100, "duct elbow bend 90", duct)
                .fill (pen ().m (0, 100).l (0, 60).a (60, 60, false, true, 60, 0).l (100, 0).l (100, 40).l (60, 40).a (20, 20, false, false, 40, 60).l (40, 100).z ().str ())
                .port (100, 20).port (20, 100);
            sym ("hvac-tee", _("Duct Tee"), 160, 90, "duct tee branch", duct)
                .fill (pen ().poly ({ 0, 0, 160, 0, 160, 40, 100, 40, 100, 90, 60, 90, 60, 40, 0, 40 }).str ())
                .port (0, 20).port (160, 20).port (80, 90);
            sym ("hvac-reducer", _("Duct Reducer"), 100, 60, "duct transition reducer", duct)
                .fill (pen ().poly ({ 0, 0, 30, 0, 70, 15, 100, 15, 100, 45, 70, 45, 30, 60, 0, 60 }).str ())
                .port (0, 30).port (100, 30);
            sym ("hvac-flex-duct", _("Flexible Duct"), 160, 30, "flex duct connector", duct)
                .fill (pen ().rect (0, 0, 160, 30).str ())
                .line (pen ().line (20, 0, 20, 30).line (40, 0, 40, 30).line (60, 0, 60, 30).line (80, 0, 80, 30).line (100, 0, 100, 30).line (120, 0, 120, 30).line (140, 0, 140, 30).str ())
                .port (0, 15).port (160, 15);
            sym ("hvac-chiller", _("Chiller"), 140, 70, "chiller chilled water plant", duct)
                .fill (pen ().rect (0, 0, 140, 70).str ())
                .line (pen ().circle (35, 35, 20).circle (105, 35, 20).str ())
                .text ("CH")
                .label (55, 0, 30, 70)
                .ports_box ();
            sym ("hvac-boiler", _("Boiler"), 80, 100, "boiler hot water heating", duct)
                .fill (pen ().round (0, 0, 80, 100, 8).str ())
                .line (pen ().m (28, 80).q (20, 60, 34, 50).q (30, 64, 40, 62).q (46, 44, 40, 34).q (60, 52, 52, 80).z ().str ())
                .ports_box ();
            sym ("hvac-cooling-tower", _("Cooling Tower"), 100, 100, "cooling tower evaporative", duct)
                .fill (pen ().poly ({ 10, 100, 25, 20, 75, 20, 90, 100 }).str ())
                .line (pen ().ellipse (50, 20, 25, 6).line (30, 60, 70, 60).line (28, 70, 72, 70).str ())
                .ink (pen ().arrow (50, 14, 50, 0, 4).str ())
                .ports_box ();
            sym ("hvac-heat-pump", _("Heat Pump"), 100, 70, "heat pump air source", duct)
                .fill (pen ().rect (0, 0, 100, 70).str ())
                .line (pen ().circle (35, 35, 22).circle (35, 35, 4).line (35, 13, 35, 57).line (13, 35, 57, 35).line (66, 14, 92, 14).line (66, 24, 92, 24).line (66, 34, 92, 34).line (66, 44, 92, 44).line (66, 54, 92, 54).str ())
                .ports_box ();
            sym ("hvac-split-indoor", _("Split Unit, Indoor"), 120, 40, "wall split air conditioner indoor", duct)
                .fill (pen ().round (0, 0, 120, 40, 8).str ())
                .line (pen ().line (10, 30, 110, 30).line (10, 34, 110, 34).str ())
                .ports_box ();
            sym ("hvac-split-outdoor", _("Split Unit, Outdoor"), 100, 80, "condensing unit outdoor", duct)
                .fill (pen ().rect (0, 0, 100, 80).str ())
                .line (pen ().circle (40, 40, 28).circle (40, 40, 5).line (80, 10, 80, 70).line (88, 10, 88, 70).str ())
                .ports_box ();
            sym ("hvac-radiator", _("Radiator"), 120, 50, "radiator heater panel", duct)
                .fill (pen ().rect (0, 0, 120, 50).str ())
                .line (pen ().line (15, 5, 15, 45).line (30, 5, 30, 45).line (45, 5, 45, 45).line (60, 5, 60, 45).line (75, 5, 75, 45).line (90, 5, 90, 45).line (105, 5, 105, 45).str ())
                .ports_box ();
            sym ("hvac-underfloor", _("Underfloor Heating Loop"), 140, 100, "underfloor radiant heating pipe", duct)
                .line (pen ().m (0, 10).l (130, 10).a (10, 10, false, true, 130, 30).l (20, 30).a (10, 10, false, false, 20, 50).l (130, 50).a (10, 10, false, true, 130, 70).l (20, 70).a (10, 10, false, false, 20, 90).l (140, 90).str ())
                .port (0, 10).port (140, 90);
            sym ("hvac-humidistat", _("Humidistat"), 40, 40, "humidity controller sensor", duct)
                .fill (pen ().circle (20, 20, 19).str ())
                .text ("H")
                .label (0, 0, 40, 40)
                .ports_box ();
            sym ("hvac-co2-sensor", _("CO2 Sensor"), 40, 40, "carbon dioxide air quality sensor", duct)
                .fill (pen ().circle (20, 20, 19).str ())
                .text ("CO2")
                .label (0, 0, 40, 40)
                .ports_box ();
            sym ("hvac-temp-sensor", _("Temperature Sensor"), 40, 40, "zone temperature sensor", duct)
                .fill (pen ().rect (1, 1, 38, 38).str ())
                .text ("T")
                .label (0, 0, 40, 40)
                .ports_box ();
            sym ("hvac-erv", _("Energy Recovery Ventilator"), 120, 80, "erv hrv heat recovery ventilation", duct)
                .fill (pen ().rect (0, 0, 120, 80).str ())
                .line (pen ().poly ({ 60, 10, 90, 40, 60, 70, 30, 40 }).line (30, 40, 90, 40).line (60, 10, 60, 70).str ())
                .ports_box ();
        }

        private static void register_plumbing () {
            Stencils.category ("plumbing", _("Plumbing"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            string pl = "fill:#ffffff;stroke:#1f4e79;stroke-width:1.5;font-size:9";
            sym ("plb-elbow-90", _("Elbow 90°"), 50, 50, "pipe elbow 90 fitting", pl)
                .line (pen ().line (0, 15, 35, 15).line (35, 15, 35, 50).line (30, 10, 40, 20).str ())
                .port (0, 15).port (35, 50);
            sym ("plb-elbow-45", _("Elbow 45°"), 50, 50, "pipe elbow 45 fitting", pl)
                .line (pen ().line (0, 40, 22, 40).line (22, 40, 50, 12).line (22, 34, 22, 46).str ())
                .port (0, 40).port (50, 12);
            sym ("plb-tee", _("Pipe Tee"), 60, 40, "pipe tee fitting", pl)
                .line (pen ().line (0, 10, 60, 10).line (30, 10, 30, 40).line (24, 4, 24, 16).line (36, 4, 36, 16).str ())
                .port (0, 10).port (60, 10).port (30, 40);
            sym ("plb-cross", _("Pipe Cross"), 60, 60, "pipe cross fitting", pl)
                .line (pen ().line (0, 30, 60, 30).line (30, 0, 30, 60).rect (24, 24, 12, 12).str ())
                .port (0, 30).port (60, 30).port (30, 0).port (30, 60);
            sym ("plb-union", _("Union"), 60, 30, "pipe union", pl)
                .line (pen ().line (0, 15, 60, 15).line (24, 5, 24, 25).line (30, 5, 30, 25).line (36, 5, 36, 25).str ())
                .port (0, 15).port (60, 15);
            sym ("plb-coupling", _("Coupling"), 60, 30, "pipe coupling socket", pl)
                .line (pen ().line (0, 15, 60, 15).line (26, 7, 26, 23).line (34, 7, 34, 23).str ())
                .port (0, 15).port (60, 15);
            sym ("plb-floor-drain", _("Floor Drain"), 40, 40, "floor drain gully", pl)
                .fill (pen ().circle (20, 20, 19).str ())
                .line (pen ().line (8, 14, 32, 14).line (6, 20, 34, 20).line (8, 26, 32, 26).str ())
                .ports_box ();
            sym ("plb-cleanout", _("Cleanout"), 40, 40, "cleanout access rodding eye", pl)
                .fill (pen ().circle (20, 20, 19).str ())
                .text ("CO")
                .label (0, 0, 40, 40)
                .ports_box ();
            sym ("plb-water-meter", _("Water Meter"), 60, 40, "water meter", pl)
                .fill (pen ().circle (30, 20, 14).str ())
                .line (pen ().line (0, 20, 16, 20).line (44, 20, 60, 20).str ())
                .text ("WM")
                .label (16, 6, 28, 28)
                .port (0, 20).port (60, 20);
            sym ("plb-gas-meter", _("Gas Meter"), 60, 40, "gas meter", pl)
                .fill (pen ().rect (16, 6, 28, 28).str ())
                .line (pen ().line (0, 20, 16, 20).line (44, 20, 60, 20).str ())
                .text ("GM")
                .label (16, 6, 28, 28)
                .port (0, 20).port (60, 20);
            sym ("plb-backflow", _("Backflow Preventer"), 80, 40, "backflow prevention double check", pl)
                .line (pen ().line (0, 20, 80, 20).poly ({ 20, 8, 20, 32, 36, 20 }).poly ({ 44, 8, 44, 32, 60, 20 }).line (36, 8, 36, 32).line (60, 8, 60, 32).str ())
                .port (0, 20).port (80, 20);
            sym ("plb-prv", _("Pressure Reducing Valve"), 80, 50, "prv pressure reducing water", pl)
                .line (pen ().line (0, 30, 80, 30).poly ({ 24, 18, 24, 42, 40, 30 }).poly ({ 56, 18, 56, 42, 40, 30 }).line (40, 30, 40, 10).rect (32, 2, 16, 8).str ())
                .port (0, 30).port (80, 30);
            sym ("plb-hose-bib", _("Hose Bib"), 60, 40, "outdoor tap hose bib sillcock", pl)
                .line (pen ().line (0, 20, 30, 20).m (30, 14).l (40, 14).q (52, 14, 52, 30).line (36, 14, 36, 4).line (30, 4, 42, 4).str ())
                .port (0, 20);
            sym ("plb-shutoff", _("Shutoff Valve"), 80, 40, "isolation stop valve", pl)
                .line (pen ().line (0, 20, 24, 20).line (56, 20, 80, 20).poly ({ 24, 8, 24, 32, 56, 8, 56, 32 }).line (40, 20, 40, 4).line (32, 4, 48, 4).str ())
                .port (0, 20).port (80, 20);
            sym ("plb-expansion-tank", _("Expansion Tank"), 50, 80, "expansion vessel tank", pl)
                .fill (pen ().round (5, 10, 40, 60, 18).str ())
                .line (pen ().line (5, 40, 45, 40).line (25, 70, 25, 80).str ())
                .port (25, 80);
            sym ("plb-sump-pump", _("Sump Pump"), 60, 80, "sump pump pit", pl)
                .fill (pen ().rect (0, 20, 60, 60).str ())
                .line (pen ().circle (30, 56, 12).line (30, 44, 30, 0).str ())
                .port (30, 0);
            sym ("plb-grease-trap", _("Grease Trap"), 100, 60, "grease interceptor trap", pl)
                .fill (pen ().rect (0, 0, 100, 60).str ())
                .line (pen ().line (30, 0, 30, 46).line (70, 14, 70, 60).str ())
                .text ("GT")
                .ports_box ();
            sym ("plb-p-trap", _("P-Trap"), 60, 60, "p trap u bend", pl)
                .line (pen ().line (10, 0, 10, 30).a (15, 15, false, false, 40, 30).line (40, 30, 40, 20).line (40, 20, 60, 20).str ())
                .port (10, 0).port (60, 20);
            sym ("plb-vent-stack", _("Vent Stack"), 40, 120, "vent stack soil pipe", pl)
                .fill (pen ().rect (12, 0, 16, 120).str ())
                .line (pen ().line (8, 6, 32, 6).str ())
                .port (20, 120);
            sym ("plb-urinal", _("Urinal"), 50, 50, "urinal wall", pl)
                .fill (pen ().m (5, 0).l (45, 0).l (45, 20).q (45, 50, 25, 50).q (5, 50, 5, 20).z ().str ())
                .line (pen ().m (12, 10).l (38, 10).q (36, 40, 25, 40).q (14, 40, 12, 10).str ())
                .ports_box ();
            sym ("plb-bidet", _("Bidet"), 50, 70, "bidet bathroom", pl)
                .fill (pen ().round (5, 0, 40, 16, 3).str ())
                .fill (pen ().m (5, 16).l (45, 16).q (45, 70, 25, 70).q (5, 70, 5, 16).z ().str ())
                .line (pen ().circle (25, 30, 3).str ())
                .ports_box ();
            sym ("plb-utility-sink", _("Utility Sink"), 70, 60, "laundry tub utility sink", pl)
                .fill (pen ().rect (0, 0, 70, 60).str ())
                .line (pen ().round (6, 10, 58, 44, 4).circle (35, 32, 3).str ())
                .ports_box ();
            sym ("plb-drinking-fountain", _("Drinking Fountain"), 50, 40, "water fountain bubbler", pl)
                .fill (pen ().m (0, 0).l (50, 0).l (50, 20).q (50, 40, 25, 40).q (0, 40, 0, 20).z ().str ())
                .line (pen ().circle (25, 18, 6).str ())
                .ports_box ();
            sym ("plb-shower-drain", _("Linear Shower Drain"), 120, 20, "linear channel drain", pl)
                .fill (pen ().rect (0, 0, 120, 20).str ())
                .line (pen ().line (10, 6, 110, 6).line (10, 14, 110, 14).str ())
                .ports_box ();
            sym ("plb-water-softener", _("Water Softener"), 60, 100, "water softener treatment", pl)
                .fill (pen ().round (0, 0, 26, 100, 12).str ())
                .fill (pen ().rect (32, 30, 28, 70).str ())
                .ports_box ();
            sym ("plb-gas-valve", _("Gas Valve"), 80, 40, "gas cock valve", pl)
                .line (pen ().line (0, 20, 24, 20).line (56, 20, 80, 20).poly ({ 24, 8, 24, 32, 56, 8, 56, 32 }).line (40, 20, 40, 4).line (40, 4, 52, 4).str ())
                .text ("G")
                .label (24, 22, 32, 18)
                .port (0, 20).port (80, 20);
        }

        private static void register_lab () {
            Stencils.category ("laboratory", _("Laboratory Equipment"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            string gl = "fill:#eaf6fb;stroke:#1e1e1e;stroke-width:1.4;font-size:9";
            sym ("lab-beaker", _("Beaker"), 60, 80, "beaker glassware", gl)
                .fill (pen ().m (4, 0).l (6, 4).l (8, 76).q (8, 80, 12, 80).l (48, 80).q (52, 80, 52, 76).l (54, 4).l (56, 0).str ())
                .line (pen ().line (40, 24, 50, 24).line (44, 36, 50, 36).line (40, 48, 50, 48).line (44, 60, 50, 60).str ())
                .ports_box ();
            sym ("lab-erlenmeyer", _("Erlenmeyer Flask"), 60, 80, "conical flask erlenmeyer", gl)
                .fill (pen ().poly ({ 22, 0, 38, 0, 38, 26, 58, 76, 54, 80, 6, 80, 2, 76, 22, 26 }).str ())
                .line (pen ().line (14, 50, 46, 50).str ())
                .ports_box ();
            sym ("lab-round-flask", _("Round-Bottom Flask"), 60, 80, "round bottom flask boiling", gl)
                .fill (pen ().m (24, 0).l (24, 28).a (26, 26, true, false, 36, 28).l (36, 0).z ().str ())
                .ports_box ();
            sym ("lab-volumetric", _("Volumetric Flask"), 50, 100, "volumetric measuring flask", gl)
                .fill (pen ().m (21, 0).l (21, 54).q (2, 62, 2, 80).q (2, 100, 25, 100).q (48, 100, 48, 80).q (48, 62, 29, 54).l (29, 0).z ().str ())
                .line (pen ().line (19, 24, 31, 24).str ())
                .ports_box ();
            sym ("lab-florence", _("Florence Flask"), 60, 90, "florence flat bottom flask", gl)
                .fill (pen ().m (24, 0).l (24, 30).q (0, 40, 2, 64).q (4, 88, 20, 88).l (40, 88).q (56, 88, 58, 64).q (60, 40, 36, 30).l (36, 0).z ().str ())
                .ports_box ();
            sym ("lab-test-tube", _("Test Tube"), 24, 90, "test tube", gl)
                .fill (pen ().m (2, 0).l (2, 78).a (10, 10, false, false, 22, 78).l (22, 0).str ())
                .ports_box ();
            sym ("lab-tube-rack", _("Test Tube Rack"), 120, 70, "test tube rack holder", gl)
                .fill (pen ().rect (0, 30, 120, 10).rect (0, 62, 120, 8).str ())
                .line (pen ().line (4, 40, 4, 62).line (116, 40, 116, 62).str ())
                .fill (pen ().m (14, 4).l (14, 56).a (6, 6, false, false, 26, 56).l (26, 4).str ())
                .fill (pen ().m (44, 4).l (44, 56).a (6, 6, false, false, 56, 56).l (56, 4).str ())
                .fill (pen ().m (74, 4).l (74, 56).a (6, 6, false, false, 86, 56).l (86, 4).str ())
                .ports_box ();
            sym ("lab-graduated-cylinder", _("Graduated Cylinder"), 40, 110, "measuring cylinder graduated", gl)
                .fill (pen ().m (8, 0).l (10, 4).l (10, 98).l (30, 98).l (30, 4).l (32, 0).str ())
                .fill (pen ().poly ({ 2, 98, 38, 98, 38, 110, 2, 110 }).str ())
                .line (pen ().line (20, 20, 30, 20).line (24, 32, 30, 32).line (20, 44, 30, 44).line (24, 56, 30, 56).line (20, 68, 30, 68).line (24, 80, 30, 80).str ())
                .ports_box ();
            sym ("lab-burette", _("Burette"), 30, 140, "burette titration", gl)
                .fill (pen ().rect (9, 0, 12, 110).str ())
                .line (pen ().line (15, 110, 15, 140).line (6, 118, 24, 118).line (15, 20, 21, 20).line (17, 40, 21, 40).line (15, 60, 21, 60).line (17, 80, 21, 80).str ())
                .ports_box ();
            sym ("lab-pipette", _("Pipette"), 20, 140, "pipette transfer", gl)
                .fill (pen ().m (8, 0).l (8, 50).q (2, 60, 2, 70).q (2, 82, 8, 88).l (9, 140).l (11, 140).l (12, 88).q (18, 82, 18, 70).q (18, 60, 12, 50).l (12, 0).z ().str ())
                .ports_box ();
            sym ("lab-dropper", _("Dropper"), 24, 90, "eye dropper pasteur", gl)
                .fill (pen ().round (4, 0, 16, 26, 7).str ())
                .fill (pen ().poly ({ 6, 26, 18, 26, 13, 90, 11, 90 }).str ())
                .ports_box ();
            sym ("lab-funnel", _("Funnel"), 60, 80, "filter funnel", gl)
                .fill (pen ().poly ({ 0, 0, 60, 0, 34, 40, 34, 80, 26, 80, 26, 40 }).str ())
                .ports_box ();
            sym ("lab-separatory", _("Separatory Funnel"), 60, 130, "separating funnel", gl)
                .fill (pen ().m (26, 0).l (26, 10).q (2, 40, 22, 80).l (28, 90).l (28, 130).l (32, 130).l (32, 90).l (38, 80).q (58, 40, 34, 10).l (34, 0).z ().str ())
                .line (pen ().line (20, 96, 40, 96).str ())
                .ports_box ();
            sym ("lab-buchner", _("Büchner Funnel"), 70, 90, "buchner vacuum filtration", gl)
                .fill (pen ().poly ({ 0, 0, 70, 0, 70, 34, 40, 50, 40, 90, 30, 90, 30, 50, 0, 34 }).str ())
                .line (pen ().line (0, 20, 70, 20).str ())
                .ports_box ();
            sym ("lab-condenser", _("Liebig Condenser"), 160, 40, "condenser liebig cooling", gl)
                .fill (pen ().rect (20, 4, 120, 32).str ())
                .line (pen ().line (0, 20, 160, 20).line (40, 4, 40, 0).line (120, 36, 120, 40).str ())
                .port (0, 20).port (160, 20);
            sym ("lab-bunsen", _("Bunsen Burner"), 50, 110, "bunsen burner flame gas", gl)
                .fill (pen ().rect (18, 30, 14, 64).str ())
                .fill (pen ().poly ({ 4, 94, 46, 94, 50, 110, 0, 110 }).str ())
                .solid (pen ().m (25, 30).q (14, 18, 25, 0).q (36, 18, 25, 30).z ().str (), "#f08a3c")
                .line (pen ().line (32, 70, 46, 70).str ())
                .ports_box ();
            sym ("lab-tripod", _("Tripod"), 80, 80, "tripod stand", gl)
                .line (pen ().line (4, 4, 76, 4).line (10, 4, 2, 80).line (40, 4, 40, 80).line (70, 4, 78, 80).str ())
                .ports_box ();
            sym ("lab-gauze", _("Wire Gauze"), 80, 20, "wire gauze mesh", gl)
                .fill (pen ().rect (0, 6, 80, 8).str ())
                .line (pen ().line (10, 6, 10, 14).line (20, 6, 20, 14).line (30, 6, 30, 14).line (40, 6, 40, 14).line (50, 6, 50, 14).line (60, 6, 60, 14).line (70, 6, 70, 14).str ())
                .ports_box ();
            sym ("lab-crucible", _("Crucible"), 50, 50, "crucible porcelain", gl)
                .fill (pen ().poly ({ 2, 10, 48, 10, 40, 50, 10, 50 }).str ())
                .fill (pen ().round (0, 0, 50, 10, 4).str ())
                .ports_box ();
            sym ("lab-evaporating", _("Evaporating Dish"), 80, 30, "evaporating basin dish", gl)
                .fill (pen ().m (0, 4).q (40, 50, 80, 4).z ().str ())
                .ports_box ();
            sym ("lab-petri", _("Petri Dish"), 80, 30, "petri dish culture", gl)
                .fill (pen ().rect (0, 12, 80, 18).str ())
                .fill (pen ().rect (-2, 6, 84, 10).str ())
                .ports_box ();
            sym ("lab-watch-glass", _("Watch Glass"), 80, 20, "watch glass", gl)
                .fill (pen ().m (0, 2).q (40, 30, 80, 2).q (40, 16, 0, 2).z ().str ())
                .ports_box ();
            sym ("lab-mortar", _("Mortar and Pestle"), 70, 70, "mortar pestle grind", gl)
                .fill (pen ().m (0, 30).l (70, 30).q (66, 70, 35, 70).q (4, 70, 0, 30).z ().str ())
                .fill (pen ().poly ({ 44, 0, 52, 4, 34, 40, 28, 36 }).str ())
                .ports_box ();
            sym ("lab-thermometer", _("Laboratory Thermometer"), 20, 120, "thermometer mercury", gl)
                .fill (pen ().m (6, 6).a (4, 4, false, true, 14, 6).l (14, 100).a (8, 8, true, true, 6, 100).z ().str ())
                .solid (pen ().rect (8, 50, 4, 52).circle (10, 106, 6).str (), "#c62828")
                .ports_box ();
            sym ("lab-microscope", _("Microscope"), 80, 110, "microscope optical", gl)
                .fill (pen ().round (0, 98, 80, 12, 3).str ())
                .fill (pen ().m (60, 98).l (60, 50).q (60, 20, 34, 18).l (34, 26).q (52, 30, 52, 50).l (52, 98).z ().str ())
                .fill (pen ().poly ({ 20, 4, 34, 0, 46, 54, 32, 58 }).str ())
                .fill (pen ().rect (10, 70, 50, 6).str ())
                .ports_box ();
            sym ("lab-balance", _("Analytical Balance"), 100, 80, "scale balance weighing", gl)
                .fill (pen ().rect (0, 50, 100, 30).str ())
                .fill (pen ().rect (10, 0, 80, 50).str ())
                .line (pen ().line (30, 40, 70, 40).rect (64, 60, 28, 12).str ())
                .ports_box ();
            sym ("lab-spatula", _("Spatula"), 120, 20, "spatula scoop", gl)
                .fill (pen ().round (0, 6, 40, 8, 4).str ())
                .fill (pen ().rect (40, 8, 80, 4).str ())
                .ports_box ();
            sym ("lab-tongs", _("Crucible Tongs"), 120, 40, "tongs forceps", gl)
                .line (pen ().m (0, 6).q (60, 10, 120, 20).m (0, 34).q (60, 30, 120, 20).str ())
                .ports_box ();
            sym ("lab-ring-stand", _("Ring Stand"), 80, 150, "retort stand clamp", gl)
                .fill (pen ().rect (0, 140, 80, 10).str ())
                .fill (pen ().rect (16, 0, 6, 140).str ())
                .line (pen ().line (22, 50, 44, 50).ellipse (56, 50, 12, 4).str ())
                .ports_box ();
            sym ("lab-clamp", _("Burette Clamp"), 80, 30, "clamp holder", gl)
                .fill (pen ().rect (0, 10, 50, 10).str ())
                .line (pen ().m (50, 4).q (66, 15, 50, 26).m (78, 4).q (62, 15, 78, 26).str ())
                .ports_box ();
            sym ("lab-wash-bottle", _("Wash Bottle"), 60, 100, "squeeze wash bottle", gl)
                .fill (pen ().round (4, 30, 46, 70, 8).str ())
                .line (pen ().line (27, 30, 27, 12).line (27, 12, 56, 4).str ())
                .fill (pen ().rect (18, 22, 18, 8).str ())
                .ports_box ();
            sym ("lab-desiccator", _("Desiccator"), 100, 100, "desiccator drying", gl)
                .fill (pen ().m (10, 30).l (90, 30).l (82, 100).l (18, 100).z ().str ())
                .fill (pen ().m (6, 30).q (50, -10, 94, 30).z ().str ())
                .line (pen ().line (14, 60, 86, 60).circle (50, 4, 5).str ())
                .ports_box ();
            sym ("lab-centrifuge-tube", _("Centrifuge Tube"), 24, 90, "conical centrifuge tube falcon", gl)
                .fill (pen ().poly ({ 2, 10, 22, 10, 22, 70, 12, 90, 2, 70 }).str ())
                .fill (pen ().rect (0, 0, 24, 10).str ())
                .ports_box ();
            sym ("lab-retort", _("Retort"), 120, 70, "retort distillation", gl)
                .fill (pen ().m (40, 70).a (30, 30, true, true, 60, 12).l (118, 40).l (114, 44).l (64, 26).q (70, 50, 40, 70).z ().str ())
                .ports_box ();
            sym ("lab-cuvette", _("Cuvette"), 30, 60, "cuvette spectrophotometer cell", gl)
                .fill (pen ().rect (2, 0, 26, 60).str ())
                .line (pen ().line (2, 20, 28, 20).str ())
                .ports_box ();
            sym ("lab-hot-plate", _("Hot Plate Stirrer"), 100, 60, "hot plate magnetic stirrer", gl)
                .fill (pen ().rect (0, 14, 100, 46).str ())
                .fill (pen ().rect (10, 0, 80, 14).str ())
                .line (pen ().circle (26, 38, 8).circle (74, 38, 8).str ())
                .ports_box ();
        }

        public static void register () {
            register_electrical ();
            register_fluid_power ();
            register_hvac ();
            register_plumbing ();
            register_lab ();
        }
    }
}
