namespace Singularity.Apps.Draw {

    public class StencilsElectrical {
        private const string INK = "fill-kind:none;stroke:#1e1e1e;stroke-width:1.5;font-size:9";

        private static TechPen pen () {
            return new TechPen ();
        }

        private static unowned StencilDef part (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults (INK)
                .label (0, h + 2, w, 14);
        }

        private static unowned StencilDef two (string kind, string name, string kw, string body) {
            return part (kind, name, 80, 30, kw)
                .line (pen ().line (0, 15, 20, 15).line (60, 15, 80, 15).str ())
                .line (body)
                .port (0, 15)
                .port (80, 15);
        }

        private static unowned StencilDef two_gap (string kind, string name, string kw, double a, double b, string body) {
            return part (kind, name, 80, 30, kw)
                .line (pen ().line (0, 15, a, 15).line (b, 15, 80, 15).str ())
                .line (body)
                .port (0, 15)
                .port (80, 15);
        }

        private static string arrows_in (double x, double y) {
            return pen ().arrow (x, y, x + 8, y + 8, 3).arrow (x + 7, y - 2, x + 15, y + 6, 3).str ();
        }

        private static string arrows_out (double x, double y) {
            return pen ().arrow (x, y, x + 8, y - 8, 3).arrow (x + 6, y + 2, x + 14, y - 6, 3).str ();
        }

        private static string humps (double x0, double y, int count, double r) {
            var p = pen ().m (x0, y);
            for (int i = 0; i < count; i++) p.a (r, r, false, true, x0 + (i + 1) * 2 * r, y);
            return p.str ();
        }

        private static string vhumps (double x, double y0, int count, double r, bool right) {
            var p = pen ().m (x, y0);
            for (int i = 0; i < count; i++) p.a (r, r, false, right, x, y0 + (i + 1) * 2 * r);
            return p.str ();
        }

        private static string diode_at (double x, double y, double dx, double dy, double s) {
            double px = -dy, py = dx;
            var p = pen ();
            p.poly ({ x + dx * s, y + dy * s, x - dx * s + px * s, y - dy * s + py * s, x - dx * s - px * s, y - dy * s - py * s });
            p.line (x + dx * s + px * s, y + dy * s + py * s, x + dx * s - px * s, y + dy * s - py * s);
            return p.str ();
        }

        private static void register_components () {
            Stencils.category ("electrical", _("Electrical"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            two ("elec-resistor-iec", _("Resistor (IEC)"), "resistor ohm", pen ().rect (20, 9, 40, 12).str ());
            two ("elec-resistor-ansi", _("Resistor (ANSI)"), "resistor ohm zigzag", pen ().zigzag (20, 15, 60, 3, 7).str ());
            two ("elec-resistor-variable", _("Variable Resistor"), "rheostat adjustable resistor", pen ().rect (20, 9, 40, 12).arrow (24, 28, 58, 2, 4).str ());
            part ("elec-potentiometer", _("Potentiometer"), 80, 30, "pot trimmer divider")
                .line (pen ().line (0, 20, 20, 20).line (60, 20, 80, 20).rect (20, 14, 40, 12).str ())
                .ink (pen ().arrow (40, 0, 40, 13, 4).str ())
                .port (0, 20)
                .port (80, 20)
                .port (40, 0);
            two ("elec-thermistor", _("Thermistor"), "ntc ptc temperature resistor", pen ().rect (20, 9, 40, 12).m (16, 28).l (24, 28).l (56, 2).str ());
            two ("elec-ldr", _("Light Dependent Resistor"), "ldr photoresistor light sensor", pen ().rect (20, 9, 40, 12).str ())
                .ink (arrows_in (18, -8));
            two_gap ("elec-capacitor", _("Capacitor"), "capacitor cap farad", 37, 43, pen ().line (37, 2, 37, 28).line (43, 2, 43, 28).str ());
            two_gap ("elec-capacitor-polarized", _("Polarized Capacitor"), "electrolytic capacitor polarized", 37, 43, pen ().line (37, 2, 37, 28).m (46, 2).q (41, 15, 46, 28).line (28, 5, 32, 5).line (30, 3, 30, 7).str ());
            two_gap ("elec-capacitor-variable", _("Variable Capacitor"), "trimmer tuning capacitor", 37, 43, pen ().line (37, 2, 37, 28).line (43, 2, 43, 28).arrow (26, 29, 54, 1, 4).str ());
            two ("elec-inductor", _("Inductor"), "coil inductor choke henry", humps (20, 15, 4, 5));
            two ("elec-inductor-core", _("Iron Core Inductor"), "choke iron core inductor", humps (20, 15, 4, 5) + " " + pen ().line (20, 5, 60, 5).line (20, 2, 60, 2).str ());
            part ("elec-transformer", _("Transformer"), 60, 70, "transformer coupled coils")
                .line (pen ().line (0, 15, 20, 15).line (0, 55, 20, 55).line (40, 15, 60, 15).line (40, 55, 60, 55).line (28, 12, 28, 58).line (32, 12, 32, 58).str ())
                .line (vhumps (20, 15, 4, 5, true))
                .line (vhumps (40, 15, 4, 5, false))
                .port (0, 15)
                .port (0, 55)
                .port (60, 15)
                .port (60, 55);
            two ("elec-diode", _("Diode"), "diode rectifier", pen ().line (20, 15, 60, 15).str ())
                .dark (pen ().poly ({ 30, 5, 50, 15, 30, 25 }).str ())
                .line (pen ().line (50, 5, 50, 25).str ());
            two ("elec-led", _("LED"), "light emitting diode led", pen ().line (20, 15, 60, 15).line (50, 5, 50, 25).str ())
                .dark (pen ().poly ({ 30, 5, 50, 15, 30, 25 }).str ())
                .ink (arrows_out (44, -1));
            two ("elec-zener", _("Zener Diode"), "zener regulator diode", pen ().line (20, 15, 60, 15).m (46, 3).l (50, 5).l (50, 25).l (54, 27).str ())
                .dark (pen ().poly ({ 30, 5, 50, 15, 30, 25 }).str ());
            two ("elec-schottky", _("Schottky Diode"), "schottky diode", pen ().line (20, 15, 60, 15).m (46, 5).l (46, 3).l (50, 3).l (50, 27).l (54, 27).l (54, 25).str ())
                .dark (pen ().poly ({ 30, 5, 50, 15, 30, 25 }).str ());
            two ("elec-photodiode", _("Photodiode"), "photodiode light sensor", pen ().line (20, 15, 60, 15).line (50, 5, 50, 25).str ())
                .dark (pen ().poly ({ 30, 5, 50, 15, 30, 25 }).str ())
                .ink (arrows_in (22, -10));
            double k = 0.7071;
            part ("elec-bridge", _("Bridge Rectifier"), 70, 70, "bridge rectifier diodes")
                .line (pen ().poly ({ 35, 0, 70, 35, 35, 70, 0, 35 }).str ())
                .dark (diode_at (52.5, 17.5, k, k, 4) + " " + diode_at (17.5, 17.5, k, -k, 4) + " " + diode_at (17.5, 52.5, k, k, 4) + " " + diode_at (52.5, 52.5, k, -k, 4))
                .port (35, 0)
                .port (70, 35)
                .port (35, 70)
                .port (0, 35);
            transistor ("elec-npn", _("NPN Transistor"), "npn bjt transistor", true);
            transistor ("elec-pnp", _("PNP Transistor"), "pnp bjt transistor", false);
            mosfet ("elec-nmos", _("N-Channel MOSFET"), "nmos mosfet fet transistor", true);
            mosfet ("elec-pmos", _("P-Channel MOSFET"), "pmos mosfet fet transistor", false);
            part ("elec-jfet", _("JFET"), 70, 70, "jfet junction field effect transistor")
                .line (pen ().circle (37, 35, 22).line (0, 45, 28, 45).line (28, 20, 28, 50).line (28, 25, 46, 25).line (46, 25, 46, 0).line (28, 45, 46, 45).line (46, 45, 46, 70).str ())
                .ink (pen ().arrow (12, 45, 26, 45, 5).str ())
                .port (0, 45)
                .port (46, 0)
                .port (46, 70);
            opamp ("elec-opamp", _("Operational Amplifier"), "op amp operational amplifier", "");
            opamp ("elec-comparator", _("Comparator"), "comparator voltage compare", pen ().m (32, 40).l (40, 40).l (40, 30).l (46, 30).m (36, 40).l (36, 30).l (44, 30).l (44, 40).str ());
            two_gap ("elec-battery", _("Battery"), "battery cells dc", 26, 54, pen ().line (26, 3, 26, 27).line (32, 9, 32, 21).line (38, 3, 38, 27).line (44, 9, 44, 21).line (48, 3, 48, 27).line (54, 9, 54, 21).line (18, 4, 22, 4).line (20, 2, 20, 6).str ());
            two_gap ("elec-cell", _("Cell"), "cell battery single", 37, 43, pen ().line (37, 2, 37, 28).line (43, 9, 43, 21).line (28, 4, 32, 4).line (30, 2, 30, 6).str ());
            source ("elec-dc-source", _("DC Voltage Source"), "dc voltage source supply", pen ().line (30, 30, 36, 30).line (33, 27, 33, 33).line (44, 30, 50, 30).str ());
            source ("elec-ac-source", _("AC Voltage Source"), "ac alternating source sine", pen ().m (28, 30).q (33, 20, 40, 30).q (47, 40, 52, 30).str ());
            source ("elec-current-source", _("Current Source"), "current source amps", pen ().arrow (28, 30, 52, 30, 5).str ());
            part ("elec-ground", _("Ground"), 40, 36, "ground earth gnd")
                .line (pen ().line (20, 0, 20, 16).line (4, 16, 36, 16).line (10, 24, 30, 24).line (16, 32, 24, 32).str ())
                .port (20, 0);
            part ("elec-chassis-ground", _("Chassis Ground"), 40, 36, "chassis frame ground")
                .line (pen ().line (20, 0, 20, 16).line (4, 16, 36, 16).line (8, 16, 2, 28).line (20, 16, 14, 28).line (32, 16, 26, 28).str ())
                .port (20, 0);
            part ("elec-signal-ground", _("Signal Ground"), 40, 36, "signal ground reference")
                .line (pen ().line (20, 0, 20, 14).poly ({ 6, 14, 34, 14, 20, 32 }).str ())
                .port (20, 0);
            two ("elec-switch-spst", _("Switch SPST"), "switch spst toggle single pole", pen ().line (22, 15, 56, 3).str ())
                .solid (pen ().circle (21, 15, 2).circle (59, 15, 2).str (), "@stroke");
            part ("elec-switch-spdt", _("Switch SPDT"), 80, 40, "switch spdt changeover")
                .line (pen ().line (0, 20, 20, 20).line (60, 6, 80, 6).line (60, 34, 80, 34).line (22, 20, 56, 8).str ())
                .solid (pen ().circle (21, 20, 2).circle (59, 6, 2).circle (59, 34, 2).str (), "@stroke")
                .port (0, 20)
                .port (80, 6)
                .port (80, 34);
            part ("elec-switch-dpdt", _("Switch DPDT"), 80, 84, "switch dpdt double pole")
                .line (pen ().line (0, 20, 20, 20).line (60, 6, 80, 6).line (60, 34, 80, 34).line (22, 20, 56, 8).line (0, 64, 20, 64).line (60, 50, 80, 50).line (60, 78, 80, 78).line (22, 64, 56, 52).str ())
                .ink (pen ().line (39, 14, 39, 58).str (), "@stroke")
                .solid (pen ().circle (21, 20, 2).circle (59, 6, 2).circle (59, 34, 2).circle (21, 64, 2).circle (59, 50, 2).circle (59, 78, 2).str (), "@stroke")
                .port (0, 20)
                .port (80, 6)
                .port (80, 34)
                .port (0, 64)
                .port (80, 50)
                .port (80, 78);
            two ("elec-push-no", _("Push Button (NO)"), "push button normally open momentary", pen ().line (22, 6, 58, 6).line (40, 6, 40, 0).line (34, 0, 46, 0).str ())
                .solid (pen ().circle (21, 15, 2).circle (59, 15, 2).str (), "@stroke");
            two ("elec-push-nc", _("Push Button (NC)"), "push button normally closed", pen ().line (20, 19, 60, 19).line (40, 19, 40, 4).line (34, 4, 46, 4).str ())
                .solid (pen ().circle (21, 15, 2).circle (59, 15, 2).str (), "@stroke");
            two ("elec-relay-coil", _("Relay Coil"), "relay coil solenoid", pen ().rect (26, 4, 28, 22).line (26, 26, 54, 4).str ());
            two ("elec-relay-no", _("Relay Contact (NO)"), "relay contact normally open", pen ().line (20, 15, 34, 15).line (46, 15, 60, 15).line (34, 6, 34, 24).line (46, 6, 46, 24).str ());
            two ("elec-relay-nc", _("Relay Contact (NC)"), "relay contact normally closed", pen ().line (20, 15, 34, 15).line (46, 15, 60, 15).line (34, 6, 34, 24).line (46, 6, 46, 24).line (30, 26, 50, 4).str ());
            two ("elec-fuse", _("Fuse"), "fuse protection", pen ().rect (22, 9, 36, 12).line (20, 15, 60, 15).str ());
            two ("elec-breaker", _("Circuit Breaker"), "circuit breaker mcb", pen ().m (24, 15).a (17, 17, false, true, 56, 15).str ())
                .solid (pen ().circle (22, 15, 2).circle (58, 15, 2).str (), "@stroke");
            two_gap ("elec-lamp", _("Lamp"), "lamp bulb light indicator", 25, 55, pen ().circle (40, 15, 14).line (30, 5, 50, 25).line (50, 5, 30, 25).str ());
            circle_part ("elec-motor", _("Motor"), "motor electric m", "M");
            circle_part ("elec-generator", _("Generator"), "generator alternator dynamo g", "G");
            circle_part ("elec-voltmeter", _("Voltmeter"), "voltmeter volts meter", "V");
            circle_part ("elec-ammeter", _("Ammeter"), "ammeter amps meter", "A");
            circle_part ("elec-ohmmeter", _("Ohmmeter"), "ohmmeter resistance meter", "Ω");
            part ("elec-oscilloscope", _("Oscilloscope"), 60, 50, "oscilloscope scope waveform")
                .line (pen ().round (0, 0, 60, 50, 3).rect (6, 6, 48, 32).m (10, 22).q (18, 8, 26, 22).q (34, 36, 42, 22).q (46, 15, 50, 22).str ())
                .port (0, 44)
                .port (60, 44);
            part ("elec-speaker", _("Speaker"), 50, 50, "loudspeaker speaker audio")
                .line (pen ().line (0, 18, 12, 18).line (0, 32, 12, 32).rect (12, 14, 10, 22).poly ({ 22, 14, 36, 2, 36, 48, 22, 36 }).str ())
                .port (0, 18)
                .port (0, 32);
            part ("elec-buzzer", _("Buzzer"), 50, 40, "buzzer beeper piezo")
                .line (pen ().line (0, 34, 14, 34).line (36, 34, 50, 34).m (10, 34).a (15, 15, false, true, 40, 34).z ().str ())
                .port (0, 34)
                .port (50, 34);
            part ("elec-microphone", _("Microphone"), 50, 40, "microphone mic audio input")
                .line (pen ().circle (20, 20, 12).line (8, 6, 8, 34).line (32, 20, 50, 20).str ())
                .port (50, 20);
            part ("elec-antenna", _("Antenna"), 40, 50, "antenna aerial rf")
                .line (pen ().line (20, 50, 20, 6).poly ({ 4, 2, 20, 22, 36, 2 }, false).str ())
                .port (20, 50);
            two_gap ("elec-crystal", _("Crystal"), "crystal oscillator quartz xtal", 32, 48, pen ().line (32, 5, 32, 25).line (48, 5, 48, 25).rect (36, 7, 8, 16).str ());
            part ("elec-terminal", _("Terminal"), 40, 20, "terminal connection point")
                .line (pen ().line (8, 10, 40, 10).circle (6, 10, 5).str ())
                .port (1, 10)
                .port (40, 10);
            Stencils.shape ("elec-junction", _("Junction Dot"), 10, 10, "junction node dot connection")
                .box (10, 10)
                .defaults ("fill:#1e1e1e;stroke:#1e1e1e;stroke-width:1")
                .dark (pen ().circle (5, 5, 5).str ())
                .port (5, 5);
            part ("elec-plug", _("Plug"), 60, 30, "plug connector male")
                .line (pen ().line (0, 15, 22, 15).rect (22, 5, 18, 20).line (40, 10, 58, 10).line (40, 20, 58, 20).str ())
                .port (0, 15)
                .port (60, 15);
            part ("elec-socket", _("Socket"), 60, 30, "socket jack connector female")
                .line (pen ().line (38, 15, 60, 15).rect (20, 5, 18, 20).line (2, 10, 20, 10).line (2, 20, 20, 20).str ())
                .port (0, 15)
                .port (60, 15);
            dip ("elec-dip8", _("IC DIP-8"), 8);
            dip ("elec-dip14", _("IC DIP-14"), 14);
            dip ("elec-dip16", _("IC DIP-16"), 16);
            part ("elec-regulator", _("Voltage Regulator"), 80, 50, "regulator ldo 7805 linear")
                .line (pen ().rect (20, 5, 40, 30).line (0, 20, 20, 20).line (60, 20, 80, 20).line (40, 35, 40, 50).str ())
                .label (20, 5, 40, 30)
                .text ("REG")
                .port (0, 20)
                .port (80, 20)
                .port (40, 50);
            two ("elec-heater", _("Heater"), "heating element heater", pen ().rect (20, 5, 40, 20).line (27, 5, 27, 25).line (33, 5, 33, 25).line (40, 5, 40, 25).line (47, 5, 47, 25).line (53, 5, 53, 25).str ());
            two_gap ("elec-solar", _("Solar Cell"), "solar cell photovoltaic pv", 37, 43, pen ().circle (40, 15, 14).line (37, 7, 37, 23).line (43, 11, 43, 19).str ())
                .ink (arrows_in (16, -12));
        }

        private static void transistor (string kind, string name, string kw, bool npn) {
            var d = part (kind, name, 70, 70, kw)
                .line (pen ().circle (37, 35, 24).line (0, 35, 26, 35).line (26, 20, 26, 50).m (26, 28).l (46, 16).l (46, 0).m (26, 42).l (46, 54).l (46, 70).str ());
            if (npn) d.dark (pen ().poly ({ 46, 54, 36, 53, 41, 45 }).str ());
            else d.dark (pen ().poly ({ 26, 42, 36, 43, 31, 51 }).str ());
            d.port (0, 35).port (46, 0).port (46, 70);
        }

        private static void mosfet (string kind, string name, string kw, bool n) {
            var d = part (kind, name, 70, 70, kw)
                .line (pen ().circle (38, 35, 24).line (0, 45, 22, 45).line (22, 22, 22, 48).line (28, 20, 28, 27).line (28, 32, 28, 38).line (28, 43, 28, 50).line (28, 23, 46, 23).line (46, 23, 46, 0).line (28, 47, 46, 47).line (46, 47, 46, 70).line (28, 35, 46, 35).line (46, 35, 46, 47).str ());
            if (n) d.dark (pen ().poly ({ 29, 35, 36, 31, 36, 39 }).str ());
            else d.dark (pen ().poly ({ 44, 35, 37, 31, 37, 39 }).str ());
            d.port (0, 45).port (46, 0).port (46, 70);
        }

        private static void opamp (string kind, string name, string kw, string extra) {
            var d = part (kind, name, 80, 70, kw)
                .fill (pen ().poly ({ 12, 4, 12, 66, 68, 35 }).str ())
                .line (pen ().line (0, 20, 12, 20).line (0, 50, 12, 50).line (68, 35, 80, 35).line (16, 20, 22, 20).line (16, 50, 22, 50).line (19, 47, 19, 53).str ())
                .defaults ("fill:#ffffff;fill-kind:solid");
            if (extra != "") d.line (extra);
            d.port (0, 20).port (0, 50).port (80, 35);
        }

        private static void source (string kind, string name, string kw, string glyph) {
            part (kind, name, 80, 60, kw)
                .line (pen ().circle (40, 30, 16).line (0, 30, 24, 30).line (56, 30, 80, 30).str ())
                .line (glyph)
                .port (0, 30)
                .port (80, 30);
        }

        private static void circle_part (string kind, string name, string kw, string letter) {
            part (kind, name, 80, 40, kw)
                .line (pen ().circle (40, 20, 17).line (0, 20, 23, 20).line (57, 20, 80, 20).str ())
                .label (23, 3, 34, 34)
                .text (letter)
                .port (0, 20)
                .port (80, 20);
        }

        private static void dip (string kind, string name, int pins) {
            int side = pins / 2;
            double pitch = 14;
            double h = side * pitch + 8;
            var p = pen ().rect (16, 0, 48, h).arc (40, 0, 5, 0, 180);
            for (int i = 0; i < side; i++) {
                double y = 4 + pitch / 2 + i * pitch;
                p.line (0, y, 16, y).line (64, y, 80, y);
            }
            var d = part (kind, name, 80, h, "ic chip integrated circuit dip")
                .line (p.str ())
                .label (16, 0, 48, h);
            for (int i = 0; i < side; i++) d.port (0, 4 + pitch / 2 + i * pitch);
            for (int i = side - 1; i >= 0; i--) d.port (80, 4 + pitch / 2 + i * pitch);
        }

        private static unowned StencilDef gate (string kind, string name, string kw, string body, double out_x, bool bubble, int inputs) {
            unowned StencilDef d = Stencils.shape (kind, name, 80, 50, kw)
                .box (80, 50)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:9")
                .fill (body);
            var leads = pen ();
            if (inputs == 1) leads.line (0, 25, 15, 25);
            else leads.line (0, 15, 17, 15).line (0, 35, 17, 35);
            if (bubble) {
                d.fill (pen ().circle (out_x + 4, 25, 4).str ());
                leads.line (out_x + 8, 25, 80, 25);
            } else {
                leads.line (out_x, 25, 80, 25);
            }
            d.line (leads.str ());
            d.label (0, 52, 80, 14);
            if (inputs == 1) d.port (0, 25);
            else d.port (0, 15).port (0, 35);
            d.port (80, 25);
            return d;
        }

        private static string and_body () {
            return pen ().m (15, 5).l (40, 5).a (20, 20, false, true, 40, 45).l (15, 45).z ().str ();
        }

        private static string or_body (double dx = 0) {
            return pen ().m (12 + dx, 5).q (27 + dx, 25, 12 + dx, 45).q (45 + dx, 45, 62 + dx, 25).q (45 + dx, 5, 12 + dx, 5).z ().str ();
        }

        private static unowned StencilDef iec (string kind, string name, string kw, string label, bool bubble, int inputs) {
            unowned StencilDef d = Stencils.shape (kind, name, 80, 50, kw + " iec")
                .box (80, 50)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:11")
                .fill (pen ().rect (18, 3, 44, 44).str ())
                .label (18, 3, 44, 44)
                .text (label);
            var leads = pen ();
            if (inputs == 1) leads.line (0, 25, 18, 25);
            else leads.line (0, 15, 18, 15).line (0, 35, 18, 35);
            if (bubble) {
                d.fill (pen ().circle (66, 25, 4).str ());
                leads.line (70, 25, 80, 25);
            } else {
                leads.line (62, 25, 80, 25);
            }
            d.line (leads.str ());
            if (inputs == 1) d.port (0, 25);
            else d.port (0, 15).port (0, 35);
            d.port (80, 25);
            return d;
        }

        private static unowned StencilDef block (string kind, string name, string kw, string label, double w, double h, int left, int right) {
            var p = pen ().rect (15, 0, w - 30, h);
            unowned StencilDef d = Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:10;bold:1")
                .label (15, 0, w - 30, h)
                .text (label);
            for (int i = 0; i < left; i++) {
                double y = h * (i + 1) / (left + 1);
                p.line (0, y, 15, y);
                d.port (0, y);
            }
            for (int i = 0; i < right; i++) {
                double y = h * (i + 1) / (right + 1);
                p.line (w - 15, y, w, y);
                d.port (w, y);
            }
            d.fill (p.str ());
            return d;
        }

        private static void register_logic () {
            Stencils.category ("logic", _("Logic Gates and Digital"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            gate ("logic-and", _("AND Gate"), "and gate logic", and_body (), 60, false, 2);
            gate ("logic-or", _("OR Gate"), "or gate logic", or_body (), 62, false, 2);
            gate ("logic-not", _("NOT Gate"), "not inverter logic", pen ().poly ({ 15, 5, 55, 25, 15, 45 }).str (), 55, true, 1);
            gate ("logic-nand", _("NAND Gate"), "nand gate logic", and_body (), 60, true, 2);
            gate ("logic-nor", _("NOR Gate"), "nor gate logic", or_body (), 62, true, 2);
            gate ("logic-xor", _("XOR Gate"), "xor exclusive or gate", or_body (4), 66, false, 2)
                .line (pen ().m (10, 5).q (25, 25, 10, 45).str ());
            gate ("logic-xnor", _("XNOR Gate"), "xnor equivalence gate", or_body (4), 66, true, 2)
                .line (pen ().m (10, 5).q (25, 25, 10, 45).str ());
            gate ("logic-buffer", _("Buffer"), "buffer driver", pen ().poly ({ 15, 5, 55, 25, 15, 45 }).str (), 55, false, 1);
            gate ("logic-tristate", _("Tri-State Buffer"), "tri state buffer enable", pen ().poly ({ 15, 5, 55, 25, 15, 45 }).str (), 55, false, 1)
                .line (pen ().line (35, 15, 35, 0).str ())
                .port (35, 0);
            gate ("logic-schmitt", _("Schmitt Trigger"), "schmitt trigger hysteresis", pen ().poly ({ 15, 5, 55, 25, 15, 45 }).str (), 55, false, 1)
                .line (pen ().m (20, 30).l (30, 30).l (30, 20).l (38, 20).m (24, 30).l (24, 20).l (34, 20).l (34, 30).str ());
            iec ("logic-iec-and", _("AND Gate (IEC)"), "and gate", "&", false, 2);
            iec ("logic-iec-or", _("OR Gate (IEC)"), "or gate", "≥1", false, 2);
            iec ("logic-iec-not", _("NOT Gate (IEC)"), "not inverter", "1", true, 1);
            iec ("logic-iec-nand", _("NAND Gate (IEC)"), "nand gate", "&", true, 2);
            iec ("logic-iec-nor", _("NOR Gate (IEC)"), "nor gate", "≥1", true, 2);
            iec ("logic-iec-xor", _("XOR Gate (IEC)"), "xor gate", "=1", false, 2);
            iec ("logic-iec-xnor", _("XNOR Gate (IEC)"), "xnor gate", "=1", true, 2);
            iec ("logic-iec-buffer", _("Buffer (IEC)"), "buffer", "1", false, 1);
            flipflop ("logic-dff", _("D Flip-Flop"), "d flip flop register", "D", "D");
            flipflop ("logic-jkff", _("JK Flip-Flop"), "jk flip flop", "JK", "J K");
            flipflop ("logic-tff", _("T Flip-Flop"), "t toggle flip flop", "T", "T");
            flipflop ("logic-srff", _("SR Flip-Flop"), "sr set reset flip flop", "SR", "S R");
            block ("logic-latch", _("Latch"), "latch d latch", "LATCH", 90, 80, 2, 2);
            Stencils.shape ("logic-mux", _("Multiplexer"), 60, 100, "mux multiplexer selector")
                .box (60, 100)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:10;bold:1")
                .fill (pen ().poly ({ 12, 0, 48, 20, 48, 80, 12, 100 }).str ())
                .line (pen ().line (0, 20, 12, 20).line (0, 40, 12, 40).line (0, 60, 12, 60).line (0, 80, 12, 80).line (48, 50, 60, 50).line (30, 90, 30, 100).str ())
                .label (12, 20, 36, 60)
                .text ("MUX")
                .port (0, 20)
                .port (0, 40)
                .port (0, 60)
                .port (0, 80)
                .port (60, 50)
                .port (30, 100);
            Stencils.shape ("logic-demux", _("Demultiplexer"), 60, 100, "demux demultiplexer")
                .box (60, 100)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:10;bold:1")
                .fill (pen ().poly ({ 12, 20, 48, 0, 48, 100, 12, 80 }).str ())
                .defaults ("font-size:7")
                .line (pen ().line (0, 50, 12, 50).line (48, 20, 60, 20).line (48, 40, 60, 40).line (48, 60, 60, 60).line (48, 80, 60, 80).line (30, 90, 30, 100).str ())
                .label (12, 20, 36, 60)
                .text ("DEMUX")
                .port (0, 50)
                .port (60, 20)
                .port (60, 40)
                .port (60, 60)
                .port (60, 80)
                .port (30, 100);
            block ("logic-half-adder", _("Half Adder"), "half adder sum carry", "HA", 90, 70, 2, 2);
            block ("logic-full-adder", _("Full Adder"), "full adder sum carry", "FA", 90, 80, 3, 2);
            block ("logic-counter", _("Counter"), "counter binary ctr", "CTR", 90, 100, 3, 4);
            block ("logic-register", _("Register"), "register shift storage", "REG", 90, 100, 4, 4);
            block ("logic-decoder", _("Decoder"), "decoder 2 to 4", "DEC", 90, 100, 2, 4);
            Stencils.shape ("logic-clock", _("Clock Source"), 80, 40, "clock oscillator square wave")
                .box (80, 40)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5")
                .fill (pen ().rect (0, 0, 60, 40).str ())
                .line (pen ().m (8, 28).l (18, 28).l (18, 12).l (30, 12).l (30, 28).l (42, 28).l (42, 12).l (52, 12).line (60, 20, 80, 20).str ())
                .label (0, 42, 60, 14)
                .port (80, 20);
        }

        private static void flipflop (string kind, string name, string kw, string label, string inputs) {
            var d = block (kind, name, kw, label, 90, 90, 3, 2);
            d.line (pen ().poly ({ 15, 60, 23, 67.5, 15, 75 }, false).str ());
            if (inputs == "") return;
        }

        private static unowned StencilDef symbol (string kind, string name, string kw, string body, string label = "") {
            unowned StencilDef d = Stencils.shape (kind, name, 40, 40, kw)
                .box (40, 40)
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:1.5;font-size:8;bold:1")
                .fill (body)
                .label (6, 6, 28, 28)
                .ports_box ();
            if (label != "") d.text (label);
            return d;
        }

        private static void register_building () {
            Stencils.category ("building-services", _("Building Services"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            symbol ("elec-outlet", _("Duplex Outlet"), "outlet receptacle socket power", pen ().circle (20, 20, 10).str ())
                .line (pen ().line (6, 16, 34, 16).line (6, 24, 34, 24).str ());
            symbol ("elec-outlet-gfci", _("GFCI Outlet"), "gfci outlet ground fault", pen ().circle (20, 20, 12).str (), "GFI");
            symbol ("elec-light-switch", _("Light Switch"), "switch wall light", pen ().circle (20, 20, 12).str (), "S");
            symbol ("elec-light", _("Light Fixture"), "light fixture ceiling lamp", pen ().circle (20, 20, 14).str ())
                .line (pen ().line (10, 10, 30, 30).line (30, 10, 10, 30).str ());
            symbol ("elec-downlight", _("Recessed Light"), "downlight recessed can", pen ().circle (20, 20, 12).str ())
                .solid (pen ().circle (20, 20, 5).str (), "@stroke");
            symbol ("elec-ceiling-fan", _("Ceiling Fan"), "fan ceiling", pen ().circle (20, 20, 4).str ())
                .line (pen ().round (16, 1, 8, 13, 4).round (16, 26, 8, 13, 4).round (1, 16, 13, 8, 4).round (26, 16, 13, 8, 4).str ());
            symbol ("elec-smoke", _("Smoke Detector"), "smoke detector alarm", pen ().circle (20, 20, 14).str (), "SD");
            symbol ("elec-thermostat", _("Thermostat"), "thermostat temperature control", pen ().circle (20, 20, 14).str (), "T");
            symbol ("elec-junction-box", _("Junction Box"), "junction box", pen ().circle (20, 20, 12).str (), "J");
            symbol ("elec-panel", _("Panelboard"), "panel board distribution breaker", pen ().rect (4, 12, 32, 16).str ())
                .dark (pen ().poly ({ 4, 28, 36, 12, 36, 28 }).str ());
            symbol ("elec-vent", _("HVAC Vent"), "hvac vent diffuser air supply", pen ().rect (6, 6, 28, 28).str ())
                .line (pen ().line (6, 6, 34, 34).line (34, 6, 6, 34).str ());
            symbol ("elec-return-vent", _("Return Air Grille"), "return air grille hvac", pen ().rect (6, 6, 28, 28).str ())
                .line (pen ().line (6, 6, 34, 34).str ());
            symbol ("elec-sprinkler", _("Sprinkler Head"), "sprinkler fire", pen ().circle (20, 20, 8).str ())
                .solid (pen ().circle (20, 20, 3).str (), "@stroke")
                .line (pen ().line (20, 2, 20, 10).line (20, 30, 20, 38).line (2, 20, 10, 20).line (30, 20, 38, 20).str ());
            symbol ("elec-fire-alarm", _("Fire Alarm"), "fire alarm pull station", pen ().rect (6, 6, 28, 28).str (), "F");
            symbol ("elec-emergency-light", _("Emergency Light"), "emergency exit light", pen ().circle (20, 20, 12).str ())
                .dark (pen ().m (8, 20).a (12, 12, false, true, 32, 20).z ().str ());
            symbol ("elec-exit-sign", _("Exit Sign"), "exit sign", pen ().rect (2, 10, 36, 20).str (), "EXIT");
            symbol ("elec-meter", _("Electric Meter"), "meter kwh utility", pen ().circle (20, 20, 14).str (), "kWh");
            symbol ("elec-data-outlet", _("Data Outlet"), "data network jack outlet", pen ().poly ({ 4, 32, 20, 8, 36, 32 }).str ());
            symbol ("elec-phone-outlet", _("Telephone Outlet"), "telephone jack outlet", pen ().rect (8, 8, 24, 24).str ())
                .dark (pen ().poly ({ 8, 32, 32, 8, 32, 32 }).str ());
            symbol ("elec-doorbell", _("Doorbell"), "doorbell chime", pen ().circle (20, 20, 12).str ())
                .line (pen ().line (8, 20, 32, 20).str ());
        }

        public static void register () {
            register_components ();
            register_logic ();
            register_building ();
        }
    }
}
