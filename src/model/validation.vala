namespace Singularity.Apps.Draw {

    public enum IssueSeverity {
        ERROR,
        WARNING;

        public string label () {
            return this == ERROR ? _("Error") : _("Warning");
        }
    }

    public class ValidationIssue {
        public string rule;
        public string rule_set;
        public string page_id;
        public string item_id;
        public string message;
        public IssueSeverity severity;

        public ValidationIssue (string rule_set, string rule, Page page, Item? item, string message, IssueSeverity severity) {
            this.rule_set = rule_set;
            this.rule = rule;
            this.page_id = page.id;
            this.item_id = item != null ? item.id : "";
            this.message = message;
            this.severity = severity;
        }

        public string key () {
            return "%s:%s:%s".printf (rule, page_id, item_id);
        }
    }

    public class Validator {
        private enum Role {
            OTHER,
            FLOW_STEP,
            FLOW_DECISION,
            FLOW_TERMINATOR,
            BPMN_START,
            BPMN_INTERMEDIATE,
            BPMN_END,
            BPMN_ACTIVITY,
            BPMN_GATEWAY,
            BPMN_EVENT_GATEWAY,
            BPMN_POOL,
            BPMN_LANE,
            BPMN_DATA,
            BPMN_ARTIFACT,
            UML_CLASS,
            UML_ACTOR,
            UML_USECASE,
            UML_INITIAL,
            UML_FINAL,
            UML_ACTIVITY_NODE,
            UML_STATE,
            UML_INITIAL_STATE
        }

        public static string[] rule_sets () {
            return { "flowchart", "bpmn", "uml" };
        }

        public static string rule_set_label (string id) {
            switch (id) {
                case "bpmn": return _("BPMN 2.0");
                case "uml": return _("UML");
                default: return _("Flowchart");
            }
        }

        private static Role role (Shape s) {
            string k = s.kind;
            if (k.has_prefix ("bpmn")) {
                if (k.contains ("pool") || k.contains ("participant")) return Role.BPMN_POOL;
                if (k.contains ("lane")) return Role.BPMN_LANE;
                if (k.contains ("annotation") || k.contains ("group")) return Role.BPMN_ARTIFACT;
                if (k.contains ("data") || k.contains ("message-flow-marker") || k.has_suffix ("-message-object")) return Role.BPMN_DATA;
                if (k.contains ("gateway")) return k.contains ("event") ? Role.BPMN_EVENT_GATEWAY : Role.BPMN_GATEWAY;
                if (k.contains ("start")) return Role.BPMN_START;
                if (k.contains ("end") && !k.contains ("extend")) return Role.BPMN_END;
                if (k.contains ("intermediate") || k.contains ("boundary") || k == "bpmn-timer" || k == "bpmn-message") return Role.BPMN_INTERMEDIATE;
                if (k.contains ("task") || k.contains ("subprocess") || k.contains ("activity") || k.contains ("transaction") || k.contains ("call")) return Role.BPMN_ACTIVITY;
                return Role.OTHER;
            }
            if (k.has_prefix ("uml")) {
                if (k.contains ("class") || k.contains ("interface") || k.contains ("enum")) return Role.UML_CLASS;
                if (k.contains ("actor")) return Role.UML_ACTOR;
                if (k.contains ("usecase") || k.contains ("use-case")) return Role.UML_USECASE;
                if (k == "uml-initial" || k.contains ("initial-node") || k.contains ("activity-initial")) return Role.UML_INITIAL;
                if (k.contains ("initial")) return Role.UML_INITIAL_STATE;
                if (k.contains ("final")) return Role.UML_FINAL;
                if (k.contains ("state")) return Role.UML_STATE;
                if (k.contains ("action") || k.contains ("decision") || k.contains ("fork") || k.contains ("join")) return Role.UML_ACTIVITY_NODE;
                return Role.OTHER;
            }
            var e = ShapeLibrary.find (k);
            if (e != null && e.category == "flowchart") {
                if (k == "decision" || k.contains ("decision")) return Role.FLOW_DECISION;
                if (k == "terminator" || k.contains ("terminator")) return Role.FLOW_TERMINATOR;
                if (k == "annotation" || k == "on-page" || k == "off-page") return Role.OTHER;
                return Role.FLOW_STEP;
            }
            return Role.OTHER;
        }

        public static Gee.ArrayList<string> detect (Document doc) {
            var found = new Gee.ArrayList<string> ();
            foreach (var p in doc.pages) {
                foreach (var it in p.all_items ()) {
                    var s = it as Shape;
                    if (s == null) continue;
                    var r = role (s);
                    string set = r == Role.OTHER ? "" : (r <= Role.FLOW_TERMINATOR ? "flowchart" : (r <= Role.BPMN_ARTIFACT ? "bpmn" : "uml"));
                    if (set != "" && !found.contains (set)) found.add (set);
                }
            }
            return found;
        }

        public static Gee.ArrayList<string> active_sets (Document doc) {
            if (doc.validation_rules == "") return detect (doc);
            var list = new Gee.ArrayList<string> ();
            foreach (string s in doc.validation_rules.split (",")) if (s.strip () != "") list.add (s.strip ());
            return list;
        }

        private class Flow {
            public Gee.ArrayList<Connector> incoming = new Gee.ArrayList<Connector> ();
            public Gee.ArrayList<Connector> outgoing = new Gee.ArrayList<Connector> ();
        }

        private static bool reversed (Connector c) {
            return c.style.arrow_end == ArrowKind.NONE && c.style.arrow_start != ArrowKind.NONE;
        }

        private static Gee.HashMap<string, Flow> flows (Page page) {
            var map = new Gee.HashMap<string, Flow> ();
            foreach (var c in page.connectors ()) {
                string a = reversed (c) ? c.dst.item_id : c.src.item_id;
                string b = reversed (c) ? c.src.item_id : c.dst.item_id;
                if (a != "") {
                    if (!map.has_key (a)) map[a] = new Flow ();
                    map[a].outgoing.add (c);
                }
                if (b != "") {
                    if (!map.has_key (b)) map[b] = new Flow ();
                    map[b].incoming.add (c);
                }
            }
            return map;
        }

        private static Flow flow_of (Gee.HashMap<string, Flow> map, Item it) {
            return map.has_key (it.id) ? map[it.id] : new Flow ();
        }

        private static bool is_message_flow (Connector c) {
            return c.style.dash != DashKind.SOLID;
        }

        private static Shape? pool_of (Page page, Shape s) {
            string cid = s.container_id;
            int guard = 0;
            while (cid != "" && guard++ < 20) {
                var c = page.find (cid) as Shape;
                if (c == null) return null;
                if (role (c) == Role.BPMN_POOL || c.kind == "pool") return c;
                cid = c.container_id;
            }
            return null;
        }

        private static string label (Shape s) {
            string t = s.display_text ().strip ().replace ("\n", " ");
            return t != "" ? "“%s”".printf (t.length > 40 ? t.substring (0, 40) : t) : ShapeLibrary.display_name (s.kind);
        }

        public static Gee.ArrayList<ValidationIssue> run (Document doc, Gee.List<string>? sets = null) {
            var list = new Gee.ArrayList<ValidationIssue> ();
            var active = sets ?? active_sets (doc);
            foreach (var page in doc.pages) {
                if (page.is_background) continue;
                var map = flows (page);
                if (active.contains ("flowchart")) flowchart (page, map, list);
                if (active.contains ("bpmn")) bpmn (page, map, list);
                if (active.contains ("uml")) uml (page, map, list);
                if (active.size > 0) connectors (page, list, active[0]);
            }
            var result = new Gee.ArrayList<ValidationIssue> ();
            foreach (var i in list) if (!doc.ignored_issues.contains (i.key ()) && !doc.ignored_issues.contains ("rule:" + i.rule)) result.add (i);
            return result;
        }

        private static void connectors (Page page, Gee.List<ValidationIssue> list, string set) {
            foreach (var c in page.connectors ()) {
                if (!c.src.attached () || !c.dst.attached ()) {
                    list.add (new ValidationIssue (set, "dangling-connector", page, c, _("Connector is not glued to a shape at both ends"), IssueSeverity.ERROR));
                }
            }
        }

        private static void flowchart (Page page, Gee.HashMap<string, Flow> map, Gee.List<ValidationIssue> list) {
            int steps = 0, terminators = 0;
            var shapes = new Gee.ArrayList<Shape> ();
            foreach (var it in page.all_items ()) {
                var s = it as Shape;
                if (s == null) continue;
                var r = role (s);
                if (r != Role.FLOW_STEP && r != Role.FLOW_DECISION && r != Role.FLOW_TERMINATOR) continue;
                shapes.add (s);
                steps++;
                if (r == Role.FLOW_TERMINATOR) terminators++;
            }
            if (steps == 0) return;
            if (terminators == 0 && steps > 1) list.add (new ValidationIssue ("flowchart", "flow-no-terminator", page, null, _("The flowchart has no start or end shape"), IssueSeverity.WARNING));
            foreach (var s in shapes) {
                var f = flow_of (map, s);
                var r = role (s);
                int ins = f.incoming.size, outs = f.outgoing.size;
                if (ins + outs == 0 && steps > 1) {
                    list.add (new ValidationIssue ("flowchart", "flow-unconnected", page, s, _("%s is not connected to the flow").printf (label (s)), IssueSeverity.ERROR));
                    continue;
                }
                if (s.display_text ().strip () == "" && r != Role.FLOW_TERMINATOR) list.add (new ValidationIssue ("flowchart", "flow-no-text", page, s, _("%s has no text").printf (ShapeLibrary.display_name (s.kind)), IssueSeverity.WARNING));
                switch (r) {
                    case Role.FLOW_DECISION:
                        if (outs < 2) list.add (new ValidationIssue ("flowchart", "flow-decision-branches", page, s, _("Decision %s needs at least two outgoing connectors").printf (label (s)), IssueSeverity.ERROR));
                        bool unlabeled = false;
                        foreach (var c in f.outgoing) if (c.display_text ().strip () == "") unlabeled = true;
                        if (outs >= 2 && unlabeled) list.add (new ValidationIssue ("flowchart", "flow-decision-labels", page, s, _("Outgoing connectors of decision %s should be labeled").printf (label (s)), IssueSeverity.WARNING));
                        if (ins == 0) list.add (new ValidationIssue ("flowchart", "flow-no-incoming", page, s, _("%s has no incoming connector").printf (label (s)), IssueSeverity.WARNING));
                        break;
                    case Role.FLOW_TERMINATOR:
                        if (ins > 0 && outs > 0) list.add (new ValidationIssue ("flowchart", "flow-terminator-both", page, s, _("Start or end shape %s has both incoming and outgoing connectors").printf (label (s)), IssueSeverity.ERROR));
                        break;
                    default:
                        if (outs == 0) list.add (new ValidationIssue ("flowchart", "flow-dead-end", page, s, _("%s has no outgoing connector; end the flow with an end shape").printf (label (s)), IssueSeverity.WARNING));
                        if (ins == 0) list.add (new ValidationIssue ("flowchart", "flow-no-incoming", page, s, _("%s has no incoming connector").printf (label (s)), IssueSeverity.WARNING));
                        break;
                }
            }
        }

        private static void bpmn (Page page, Gee.HashMap<string, Flow> map, Gee.List<ValidationIssue> list) {
            var shapes = new Gee.ArrayList<Shape> ();
            int starts = 0, ends = 0, nodes = 0;
            foreach (var it in page.all_items ()) {
                var s = it as Shape;
                if (s == null) continue;
                var r = role (s);
                if (r == Role.OTHER || r > Role.BPMN_ARTIFACT) continue;
                shapes.add (s);
                if (r == Role.BPMN_START) starts++;
                if (r == Role.BPMN_END) ends++;
                if (r == Role.BPMN_ACTIVITY || r == Role.BPMN_GATEWAY || r == Role.BPMN_EVENT_GATEWAY || r == Role.BPMN_INTERMEDIATE) nodes++;
            }
            if (shapes.size == 0) return;
            if (nodes > 0 && starts == 0) list.add (new ValidationIssue ("bpmn", "bpmn-no-start", page, null, _("The process has no start event"), IssueSeverity.WARNING));
            if (nodes > 0 && ends == 0) list.add (new ValidationIssue ("bpmn", "bpmn-no-end", page, null, _("The process has no end event"), IssueSeverity.WARNING));
            foreach (var s in shapes) {
                var f = flow_of (map, s);
                var r = role (s);
                int ins = 0, outs = 0;
                foreach (var c in f.incoming) if (!is_message_flow (c)) ins++;
                foreach (var c in f.outgoing) if (!is_message_flow (c)) outs++;
                switch (r) {
                    case Role.BPMN_START:
                        if (ins > 0) list.add (new ValidationIssue ("bpmn", "bpmn-start-incoming", page, s, _("Start event %s cannot have incoming sequence flow").printf (label (s)), IssueSeverity.ERROR));
                        if (outs == 0) list.add (new ValidationIssue ("bpmn", "bpmn-start-outgoing", page, s, _("Start event %s has no outgoing sequence flow").printf (label (s)), IssueSeverity.ERROR));
                        break;
                    case Role.BPMN_END:
                        if (outs > 0) list.add (new ValidationIssue ("bpmn", "bpmn-end-outgoing", page, s, _("End event %s cannot have outgoing sequence flow").printf (label (s)), IssueSeverity.ERROR));
                        if (ins == 0) list.add (new ValidationIssue ("bpmn", "bpmn-end-incoming", page, s, _("End event %s has no incoming sequence flow").printf (label (s)), IssueSeverity.ERROR));
                        break;
                    case Role.BPMN_ACTIVITY:
                    case Role.BPMN_INTERMEDIATE:
                        if (ins == 0 && !s.kind.contains ("boundary")) list.add (new ValidationIssue ("bpmn", "bpmn-unreachable", page, s, _("%s has no incoming sequence flow").printf (label (s)), IssueSeverity.ERROR));
                        if (outs == 0) list.add (new ValidationIssue ("bpmn", "bpmn-no-outgoing", page, s, _("%s has no outgoing sequence flow").printf (label (s)), IssueSeverity.ERROR));
                        if (r == Role.BPMN_ACTIVITY && s.display_text ().strip () == "") list.add (new ValidationIssue ("bpmn", "bpmn-unnamed", page, s, _("Activity has no name"), IssueSeverity.WARNING));
                        break;
                    case Role.BPMN_GATEWAY:
                    case Role.BPMN_EVENT_GATEWAY:
                        if (ins == 0 || outs == 0) list.add (new ValidationIssue ("bpmn", "bpmn-gateway-flow", page, s, _("Gateway %s needs incoming and outgoing sequence flow").printf (label (s)), IssueSeverity.ERROR));
                        else if (ins < 2 && outs < 2) list.add (new ValidationIssue ("bpmn", "bpmn-gateway-useless", page, s, _("Gateway %s neither splits nor joins the flow").printf (label (s)), IssueSeverity.WARNING));
                        if (r == Role.BPMN_EVENT_GATEWAY) {
                            foreach (var c in f.outgoing) {
                                var t = page.find (reversed (c) ? c.src.item_id : c.dst.item_id) as Shape;
                                if (t == null) continue;
                                var tr = role (t);
                                if (tr != Role.BPMN_INTERMEDIATE && !(tr == Role.BPMN_ACTIVITY && t.kind.contains ("receive"))) {
                                    list.add (new ValidationIssue ("bpmn", "bpmn-event-gateway-target", page, t, _("An event-based gateway must be followed by intermediate catch events or receive tasks"), IssueSeverity.ERROR));
                                }
                            }
                        }
                        break;
                    default:
                        break;
                }
            }
            foreach (var c in page.connectors ()) {
                var a = page.find (c.src.item_id) as Shape;
                var b = page.find (c.dst.item_id) as Shape;
                if (a == null || b == null) continue;
                if (role (a) == Role.OTHER && role (b) == Role.OTHER) continue;
                if (role (a) == Role.BPMN_DATA || role (b) == Role.BPMN_DATA || role (a) == Role.BPMN_ARTIFACT || role (b) == Role.BPMN_ARTIFACT) continue;
                var pa = pool_of (page, a);
                var pb = pool_of (page, b);
                bool cross = pa != null && pb != null && pa != pb;
                if (cross && !is_message_flow (c)) list.add (new ValidationIssue ("bpmn", "bpmn-sequence-cross-pool", page, c, _("Sequence flow cannot cross pool boundaries; use a message flow"), IssueSeverity.ERROR));
                if (!cross && pa != null && pa == pb && is_message_flow (c) && c.style.dash == DashKind.DASH) list.add (new ValidationIssue ("bpmn", "bpmn-message-same-pool", page, c, _("Message flow must connect different pools"), IssueSeverity.ERROR));
            }
        }

        private static void uml (Page page, Gee.HashMap<string, Flow> map, Gee.List<ValidationIssue> list) {
            var names = new Gee.HashMap<string, Shape> ();
            int initials = 0;
            foreach (var it in page.all_items ()) {
                var s = it as Shape;
                if (s == null) continue;
                var r = role (s);
                var f = flow_of (map, s);
                switch (r) {
                    case Role.UML_CLASS:
                        string n = s.display_text ().split ("\n")[0].replace ("«interface»", "").strip ();
                        if (n == "" || n == "ClassName") {
                            if (n == "") list.add (new ValidationIssue ("uml", "uml-class-name", page, s, _("Class has no name"), IssueSeverity.ERROR));
                            break;
                        }
                        if (names.has_key (n)) list.add (new ValidationIssue ("uml", "uml-duplicate-class", page, s, _("Class name “%s” is used more than once").printf (n), IssueSeverity.ERROR));
                        else names[n] = s;
                        break;
                    case Role.UML_USECASE:
                        if (f.incoming.size + f.outgoing.size == 0) list.add (new ValidationIssue ("uml", "uml-usecase-actor", page, s, _("Use case %s is not associated with an actor").printf (label (s)), IssueSeverity.WARNING));
                        break;
                    case Role.UML_INITIAL:
                        initials++;
                        if (f.incoming.size > 0) list.add (new ValidationIssue ("uml", "uml-initial-incoming", page, s, _("Initial node cannot have incoming edges"), IssueSeverity.ERROR));
                        if (f.outgoing.size != 1) list.add (new ValidationIssue ("uml", "uml-initial-outgoing", page, s, _("Initial node must have exactly one outgoing edge"), IssueSeverity.ERROR));
                        break;
                    case Role.UML_INITIAL_STATE:
                        if (f.outgoing.size != 1) list.add (new ValidationIssue ("uml", "uml-initial-outgoing", page, s, _("Initial pseudostate must have exactly one outgoing transition"), IssueSeverity.ERROR));
                        break;
                    case Role.UML_FINAL:
                        if (f.outgoing.size > 0) list.add (new ValidationIssue ("uml", "uml-final-outgoing", page, s, _("Final node cannot have outgoing edges"), IssueSeverity.ERROR));
                        break;
                    case Role.UML_ACTIVITY_NODE:
                    case Role.UML_STATE:
                        if (f.incoming.size + f.outgoing.size == 0) list.add (new ValidationIssue ("uml", "uml-unconnected", page, s, _("%s is not connected").printf (label (s)), IssueSeverity.WARNING));
                        break;
                    default:
                        break;
                }
            }
            if (initials > 1) list.add (new ValidationIssue ("uml", "uml-multiple-initial", page, null, _("The activity has more than one initial node"), IssueSeverity.WARNING));
            var parents = new Gee.HashMap<string, Gee.ArrayList<string>> ();
            foreach (var c in page.connectors ()) {
                bool gen_end = c.style.arrow_end == ArrowKind.TRIANGLE_OPEN;
                bool gen_start = c.style.arrow_start == ArrowKind.TRIANGLE_OPEN;
                if (!gen_end && !gen_start) continue;
                string child = gen_end ? c.src.item_id : c.dst.item_id;
                string parent = gen_end ? c.dst.item_id : c.src.item_id;
                if (child == "" || parent == "") continue;
                if (!parents.has_key (child)) parents[child] = new Gee.ArrayList<string> ();
                parents[child].add (parent);
            }
            foreach (string start in parents.keys) {
                var seen = new Gee.HashSet<string> ();
                var stack = new Gee.ArrayList<string> ();
                stack.add_all (parents[start]);
                bool cycle = false;
                while (stack.size > 0 && !cycle) {
                    string cur = stack.remove_at (stack.size - 1);
                    if (cur == start) cycle = true;
                    if (seen.contains (cur)) continue;
                    seen.add (cur);
                    if (parents.has_key (cur)) stack.add_all (parents[cur]);
                }
                if (cycle) list.add (new ValidationIssue ("uml", "uml-generalization-cycle", page, page.find (start), _("Generalization forms a cycle"), IssueSeverity.ERROR));
            }
        }
    }
}
