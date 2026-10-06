namespace Singularity.Apps.Draw {

    public class StencilsBpmn {
        private const string START = "start";
        private const string START_NI = "start-ni";
        private const string CATCH = "catch";
        private const string THROW = "throw";
        private const string BOUNDARY = "boundary";
        private const string BOUNDARY_NI = "boundary-ni";
        private const string END = "end";

        public static void register () {
            Stencils.use_category ("bpmn");
            events ();
            activities ();
            gateways ();
            data ();
            pools ();
            choreography ();
        }

        private static string marker_name (string m) {
            switch (m) {
                case "message": return _("Message");
                case "timer": return _("Timer");
                case "error": return _("Error");
                case "escalation": return _("Escalation");
                case "cancel": return _("Cancel");
                case "compensation": return _("Compensation");
                case "conditional": return _("Conditional");
                case "link": return _("Link");
                case "signal": return _("Signal");
                case "terminate": return _("Terminate");
                case "multiple": return _("Multiple");
                case "parallel": return _("Parallel Multiple");
                default: return _("None");
            }
        }

        private static string event_name (string type, string m) {
            string mk = marker_name (m);
            switch (type) {
                case START: return m == "none" ? _("Start Event") : _("%s Start Event").printf (mk);
                case START_NI: return _("Non-Interrupting %s Start Event").printf (mk);
                case CATCH: return _("%s Intermediate Catch Event").printf (mk);
                case THROW: return m == "none" ? _("Intermediate Throw Event") : _("%s Intermediate Throw Event").printf (mk);
                case BOUNDARY: return _("%s Boundary Event").printf (mk);
                case BOUNDARY_NI: return _("Non-Interrupting %s Boundary Event").printf (mk);
                default: return m == "none" ? _("End Event") : _("%s End Event").printf (mk);
            }
        }

        private static void add_marker (StencilDef d, string m, bool filled) {
            switch (m) {
                case "message":
                    if (filled) {
                        d.dark (StencilKit.rect (28, 34, 44, 32));
                        d.ink (StencilKit.envelope_flap (28, 34, 44, 32), "@fill");
                    } else {
                        d.fill (StencilKit.rect (28, 34, 44, 32));
                        d.line (StencilKit.envelope_flap (28, 34, 44, 32));
                    }
                    break;
                case "timer":
                    d.fill (StencilKit.circle (50, 50, 26));
                    var ticks = new StringBuilder ();
                    for (int i = 0; i < 12; i++) {
                        double a = i * 30 * Math.PI / 180;
                        if (ticks.len > 0) ticks.append_c (' ');
                        ticks.append (StencilKit.line (50 + 21 * Math.cos (a), 50 + 21 * Math.sin (a), 50 + 26 * Math.cos (a), 50 + 26 * Math.sin (a)));
                    }
                    d.line (ticks.str);
                    d.line ("M50 32 V50 L63 56");
                    break;
                case "error":
                    string e = StencilKit.poly ({ 28, 74, 40, 34, 56, 56, 72, 26, 60, 66, 44, 46 });
                    if (filled) d.dark (e);
                    else d.line (e);
                    break;
                case "escalation":
                    string es = StencilKit.poly ({ 50, 24, 68, 74, 50, 58, 32, 74 });
                    if (filled) d.dark (es);
                    else d.line (es);
                    break;
                case "cancel":
                    string c = StencilKit.poly (StencilKit.rotate ({ 44, 24, 56, 24, 56, 44, 76, 44, 76, 56, 56, 56, 56, 76, 44, 76, 44, 56, 24, 56, 24, 44, 44, 44 }, 45, 50, 50));
                    if (filled) d.dark (c);
                    else d.line (c);
                    break;
                case "compensation":
                    string cp = StencilKit.poly ({ 24, 50, 49, 34, 49, 66 }) + " " + StencilKit.poly ({ 49, 50, 74, 34, 74, 66 });
                    if (filled) d.dark (cp);
                    else d.line (cp);
                    break;
                case "conditional":
                    d.fill (StencilKit.rect (32, 26, 36, 48));
                    d.line ("M38 36 H62 M38 46 H62 M38 56 H62 M38 66 H62");
                    break;
                case "link":
                    string l = StencilKit.poly ({ 26, 42, 54, 42, 54, 30, 76, 50, 54, 70, 54, 58, 26, 58 });
                    if (filled) d.dark (l);
                    else d.line (l);
                    break;
                case "signal":
                    string s = StencilKit.poly ({ 50, 24, 75, 68, 25, 68 });
                    if (filled) d.dark (s);
                    else d.line (s);
                    break;
                case "terminate":
                    d.dark (StencilKit.circle (50, 50, 30));
                    break;
                case "multiple":
                    string mp = StencilKit.regular (5, 50, 53, 25, 25, -90);
                    if (filled) d.dark (mp);
                    else d.line (mp);
                    break;
                case "parallel":
                    d.line (StencilKit.poly ({ 43, 24, 57, 24, 57, 43, 76, 43, 76, 57, 57, 57, 57, 76, 43, 76, 43, 57, 24, 57, 24, 43, 43, 43 }));
                    break;
                default:
                    break;
            }
        }

        private static void add_event (string type, string m) {
            string kind = "bpmn2-%s-%s".printf (type, m);
            unowned StencilDef d = Stencils.shape (kind, event_name (type, m), 40, 40, "event bpmn %s %s".printf (type, m));
            switch (type) {
                case START:
                    d.fill (StencilKit.circle (50, 50, 50));
                    d.defaults ("stroke:#2e7d32;fill:#eaf6ec");
                    break;
                case START_NI:
                    d.solid (StencilKit.circle (50, 50, 50), "@fill");
                    d.line (StencilKit.dashed_ellipse (50, 50, 50, 50, 12));
                    d.defaults ("stroke:#2e7d32;fill:#eaf6ec");
                    break;
                case CATCH:
                case THROW:
                case BOUNDARY:
                    d.fill (StencilKit.circle (50, 50, 50));
                    d.line (StencilKit.circle (50, 50, 42));
                    d.defaults ("stroke:#b26a00;fill:#fff4e0");
                    break;
                case BOUNDARY_NI:
                    d.solid (StencilKit.circle (50, 50, 50), "@fill");
                    d.line (StencilKit.dashed_ellipse (50, 50, 50, 50, 12));
                    d.line (StencilKit.dashed_ellipse (50, 50, 42, 42, 10));
                    d.defaults ("stroke:#b26a00;fill:#fff4e0");
                    break;
                default:
                    d.fill (StencilKit.circle (50, 50, 50));
                    d.defaults ("stroke:#b3261e;fill:#fdecea;stroke-width:3.5");
                    break;
            }
            add_marker (d, m, type == THROW || type == END);
            d.label_below ();
            d.ports_box ();
        }

        private static void events () {
            string[] start = { "message", "timer", "conditional", "signal", "multiple", "parallel", "error", "escalation", "compensation" };
            foreach (string m in start) add_event (START, m);
            string[] start_ni = { "message", "timer", "escalation", "conditional", "signal", "multiple", "parallel" };
            foreach (string m in start_ni) add_event (START_NI, m);
            string[] catch_m = { "message", "timer", "conditional", "link", "signal", "multiple", "parallel" };
            foreach (string m in catch_m) add_event (CATCH, m);
            string[] throw_m = { "none", "message", "escalation", "link", "compensation", "signal", "multiple" };
            foreach (string m in throw_m) add_event (THROW, m);
            string[] boundary = { "message", "timer", "error", "escalation", "cancel", "compensation", "conditional", "signal", "multiple", "parallel" };
            foreach (string m in boundary) add_event (BOUNDARY, m);
            string[] boundary_ni = { "message", "timer", "escalation", "conditional", "signal", "multiple", "parallel" };
            foreach (string m in boundary_ni) add_event (BOUNDARY_NI, m);
            string[] end = { "message", "error", "escalation", "cancel", "compensation", "signal", "terminate", "multiple" };
            foreach (string m in end) add_event (END, m);
        }

        private static unowned StencilDef task (string kind, string name, string keywords) {
            unowned StencilDef d = Stencils.shape (kind, name, 120, 80, keywords)
                .box (120, 80)
                .fill (StencilKit.rrect (0, 0, 120, 80, 10))
                .label (8, 16, 104, 46)
                .ports_box ();
            return d;
        }

        private static string gear (double cx, double cy, double r) {
            return StencilKit.star (8, cx, cy, r, r, 0.74, -90 + 11.25);
        }

        private static void activities () {
            task ("bpmn2-task-user", _("User Task"), "task human person activity")
                .fill (StencilKit.circle (16, 11, 5))
                .fill ("M7 26 C7 18 11 16 16 16 C21 16 25 18 25 26 Z");
            task ("bpmn2-task-service", _("Service Task"), "task automated system gear activity")
                .fill (gear (15, 14, 9))
                .fill (StencilKit.circle (15, 14, 3.5))
                .fill (gear (21, 20, 8))
                .fill (StencilKit.circle (21, 20, 3));
            task ("bpmn2-task-script", _("Script Task"), "task script code activity")
                .fill ("M10 6 H26 C22 11 22 13 26 18 C30 23 26 26 26 26 H10 C14 21 14 19 10 14 C6 9 10 6 10 6 Z")
                .line ("M13 11 H22 M13 16 H23 M14 21 H23");
            task ("bpmn2-task-send", _("Send Task"), "task send message activity")
                .dark (StencilKit.rect (7, 7, 20, 14))
                .ink (StencilKit.envelope_flap (7, 7, 20, 14), "@fill");
            task ("bpmn2-task-receive", _("Receive Task"), "task receive message activity")
                .fill (StencilKit.rect (7, 7, 20, 14))
                .line (StencilKit.envelope_flap (7, 7, 20, 14));
            task ("bpmn2-task-manual", _("Manual Task"), "task manual hand activity")
                .fill ("M6 16 C6 12 9 10 12 10 H26 C28 10 28 13 26 13 H18 H28 C30 13 30 16 28 16 H19 H28 C30 16 30 19 28 19 H19 H27 C29 19 29 22 27 22 H12 C8 22 6 20 6 16 Z");
            task ("bpmn2-task-rule", _("Business Rule Task"), "task decision rule table dmn activity")
                .fill (StencilKit.rect (6, 7, 22, 16))
                .shade (StencilKit.rect (6, 7, 22, 5))
                .line ("M6 17 H28 M12 12 V23");
            task ("bpmn2-task-loop", _("Loop Task"), "task loop repeat standard loop")
                .line (StencilKit.arc (60, 68, 6, 6, -60, 220))
                .line ("M53 61 L55 67 L50 69");
            task ("bpmn2-task-mi-parallel", _("Multi-Instance Task, Parallel"), "task multi instance parallel")
                .line ("M55 62 V74 M60 62 V74 M65 62 V74");
            task ("bpmn2-task-mi-sequential", _("Multi-Instance Task, Sequential"), "task multi instance sequential")
                .line ("M54 62 H66 M54 68 H66 M54 74 H66");
            task ("bpmn2-task-compensation", _("Compensation Task"), "task compensation undo")
                .line (StencilKit.poly ({ 50, 68, 60, 62, 60, 74 }) + " " + StencilKit.poly ({ 60, 68, 70, 62, 70, 74 }));
            Stencils.shape ("bpmn2-subprocess-expanded", _("Expanded Subprocess"), 360, 220, "subprocess expanded container activity")
                .fill (StencilKit.rrect (0, 0, 100, 100, 5))
                .defaults ("valign:top;halign:left;bold:1")
                .label (3, 2, 94, 12)
                .as_container ()
                .ports_box ();
            Stencils.shape ("bpmn2-event-subprocess", _("Event Subprocess"), 360, 220, "event subprocess dotted container")
                .solid (StencilKit.rrect (0, 0, 100, 100, 5), "@fill")
                .line (StencilKit.dashed_rect (2, 0, 96, 100, 1.5, 1.5))
                .defaults ("valign:top;halign:left")
                .label (3, 2, 94, 12)
                .as_container ()
                .ports_box ();
            Stencils.shape ("bpmn2-transaction", _("Transaction"), 360, 220, "transaction double border container")
                .fill (StencilKit.rrect (0, 0, 100, 100, 5))
                .line (StencilKit.rrect (1.5, 2.5, 97, 95, 4))
                .defaults ("valign:top;halign:left")
                .label (3, 4, 94, 12)
                .as_container ()
                .ports_box ();
            Stencils.shape ("bpmn2-call-activity", _("Call Activity"), 120, 80, "call activity global reusable")
                .box (120, 80)
                .fill (StencilKit.rrect (0, 0, 120, 80, 10))
                .defaults ("stroke-width:4")
                .label (8, 8, 104, 64)
                .ports_box ();
            Stencils.shape ("bpmn2-call-activity-collapsed", _("Collapsed Call Activity"), 120, 80, "call activity subprocess collapsed")
                .box (120, 80)
                .fill (StencilKit.rrect (0, 0, 120, 80, 10))
                .line (StencilKit.rect (53, 60, 14, 14) + " M56 67 H64 M60 63 V71")
                .defaults ("stroke-width:4")
                .label (8, 8, 104, 50)
                .ports_box ();
            Stencils.shape ("bpmn2-adhoc-subprocess", _("Ad-Hoc Subprocess"), 120, 80, "adhoc subprocess tilde")
                .box (120, 80)
                .fill (StencilKit.rrect (0, 0, 120, 80, 10))
                .line (StencilKit.rect (60, 60, 14, 14) + " M63 67 H71 M67 63 V71 M42 68 C45 63 48 63 50 67 C52 71 55 71 58 66")
                .label (8, 8, 104, 50)
                .ports_box ();
            Stencils.shape ("bpmn2-subprocess-loop", _("Looping Subprocess"), 120, 80, "subprocess loop collapsed")
                .box (120, 80)
                .fill (StencilKit.rrect (0, 0, 120, 80, 10))
                .line (StencilKit.rect (60, 60, 14, 14) + " M63 67 H71 M67 63 V71")
                .line (StencilKit.arc (48, 67, 6, 6, -60, 220) + " M41 60 L43 66 L38 68")
                .label (8, 8, 104, 50)
                .ports_box ();
        }

        private static void gateways () {
            string diamond = StencilKit.poly ({ 50, 0, 100, 50, 50, 100, 0, 50 });
            Stencils.shape ("bpmn2-gateway-blank", _("Exclusive Gateway (Unmarked)"), 50, 50, "gateway xor decision blank")
                .fill (diamond)
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-gateway-complex", _("Complex Gateway"), 50, 50, "gateway complex asterisk")
                .fill (diamond)
                .line ("M50 26 V74 M26 50 H74 M33 33 L67 67 M67 33 L33 67")
                .defaults ("stroke-width:2")
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-gateway-event-start", _("Exclusive Event-Based Start Gateway"), 50, 50, "gateway event instantiate")
                .fill (diamond)
                .line (StencilKit.circle (50, 50, 20))
                .line (StencilKit.regular (5, 50, 51, 12, 12, -90))
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-gateway-event-parallel", _("Parallel Event-Based Gateway"), 50, 50, "gateway event parallel instantiate")
                .fill (diamond)
                .line (StencilKit.circle (50, 50, 20))
                .line (StencilKit.poly ({ 46, 36, 54, 36, 54, 46, 64, 46, 64, 54, 54, 54, 54, 64, 46, 64, 46, 54, 36, 54, 36, 46, 46, 46 }))
                .label_below ()
                .ports_box ();
        }

        private static string doc_page () {
            return "M0 0 H72 L100 26 V100 H0 Z";
        }

        private static void data () {
            Stencils.shape ("bpmn2-data-input", _("Data Input"), 40, 54, "data input parameter")
                .fill (doc_page ())
                .line ("M72 0 V26 H100")
                .line (StencilKit.poly ({ 8, 12, 24, 12, 24, 6, 36, 17, 24, 28, 24, 22, 8, 22 }))
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-data-output", _("Data Output"), 40, 54, "data output result")
                .fill (doc_page ())
                .line ("M72 0 V26 H100")
                .dark (StencilKit.poly ({ 8, 12, 24, 12, 24, 6, 36, 17, 24, 28, 24, 22, 8, 22 }))
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-data-collection", _("Data Collection"), 40, 54, "data object list collection")
                .fill (doc_page ())
                .line ("M72 0 V26 H100 M40 76 V94 M50 76 V94 M60 76 V94")
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-message", _("Message"), 50, 34, "message envelope initiating")
                .fill (StencilKit.envelope_body (0, 0, 100, 100))
                .line (StencilKit.envelope_flap (0, 0, 100, 100))
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-message-reply", _("Non-Initiating Message"), 50, 34, "message envelope reply non initiating")
                .shade (StencilKit.envelope_body (0, 0, 100, 100))
                .line (StencilKit.envelope_flap (0, 0, 100, 100))
                .label_below ()
                .ports_box ();
        }

        private static void pools () {
            Stencils.shape ("bpmn2-pool-v", _("Vertical Pool"), 240, 520, "pool participant vertical swimlane")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .shade (StencilKit.rect (0, 0, 100, 6))
                .defaults ("bold:1;valign:top")
                .text (_("Pool"))
                .label (2, 0, 96, 6)
                .as_container ()
                .ports_box ();
            Stencils.shape ("bpmn2-lane-h", _("Lane"), 560, 140, "lane swimlane role horizontal")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M5 0 V100")
                .defaults ("valign:top;halign:left")
                .text (_("Lane"))
                .label (6, 3, 60, 22)
                .as_container ()
                .ports_box ();
            Stencils.shape ("bpmn2-lane-v", _("Vertical Lane"), 200, 480, "lane swimlane role vertical")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M0 6 H100")
                .text (_("Lane"))
                .label (2, 0, 96, 6)
                .as_container ()
                .ports_box ();
            Stencils.shape ("bpmn2-pool-collapsed", _("Collapsed Pool"), 500, 60, "black box pool participant")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("bold:1")
                .text (_("Participant"))
                .ports_box ();
        }

        private static void choreography () {
            Stencils.shape ("bpmn2-choreo-task", _("Choreography Task"), 120, 100, "choreography interaction participants")
                .box (120, 100)
                .fill (StencilKit.rrect (0, 0, 120, 100, 10))
                .shade ("M0 22 V10 A10 10 0 0 1 10 0 H110 A10 10 0 0 1 120 10 V22 Z")
                .shade ("M0 78 V90 A10 10 0 0 0 10 100 H110 A10 10 0 0 0 120 90 V78 Z")
                .label (6, 24, 108, 52)
                .ports_box ();
            Stencils.shape ("bpmn2-choreo-subprocess", _("Choreography Subprocess"), 120, 100, "choreography subprocess participants")
                .box (120, 100)
                .fill (StencilKit.rrect (0, 0, 120, 100, 10))
                .shade ("M0 22 V10 A10 10 0 0 1 10 0 H110 A10 10 0 0 1 120 10 V22 Z")
                .shade ("M0 78 V90 A10 10 0 0 0 10 100 H110 A10 10 0 0 0 120 90 V78 Z")
                .line (StencilKit.rect (53, 62, 14, 14) + " M56 69 H64 M60 65 V73")
                .label (6, 24, 108, 36)
                .ports_box ();
            string hex = StencilKit.poly ({ 25, 0, 75, 0, 100, 50, 75, 100, 25, 100, 0, 50 });
            Stencils.shape ("bpmn2-conversation", _("Conversation"), 50, 44, "conversation hexagon message exchange")
                .fill (hex)
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-call-conversation", _("Call Conversation"), 50, 44, "conversation call global")
                .fill (hex)
                .defaults ("stroke-width:4")
                .label_below ()
                .ports_box ();
            Stencils.shape ("bpmn2-subconversation", _("Sub-Conversation"), 50, 44, "conversation sub collapsed")
                .fill (hex)
                .line (StencilKit.rect (38, 66, 24, 26) + " M43 79 H57 M50 71 V87")
                .label_below ()
                .ports_box ();
        }
    }
}
