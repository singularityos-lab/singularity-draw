namespace Singularity.Apps.Draw {

    public enum PartMode {
        FILL_STROKE,
        FILL_ONLY,
        STROKE,
        FILL_DARK,
        FILL_SHADE
    }

    public class GeomPart {
        public PathData path;
        public PartMode mode;
        public string? color = null;

        public GeomPart (PathData path, PartMode mode, string? color = null) {
            this.path = path;
            this.mode = mode;
            this.color = color;
        }

        public string? resolve_color (Style st) {
            if (color == null) return null;
            switch (color) {
                case "@fill": return st.fill;
                case "@fill2": return st.fill2;
                case "@stroke": return st.stroke;
                case "@text": return st.text_color;
                case "@light": return "#ffffff";
                case "@dark": return Colors.mix (Colors.is_none (st.stroke) ? "#1e1e1e" : st.stroke, "#000000", 0.25);
                case "@shade": return Colors.mix (Colors.is_none (st.fill) ? "#ffffff" : st.fill, "#1f2a36", 0.16);
                case "@tint": return Colors.mix (Colors.is_none (st.fill) ? "#ffffff" : st.fill, "#ffffff", 0.55);
                default: return color;
            }
        }
    }

    public class Geometry {
        public Gee.ArrayList<GeomPart> parts = new Gee.ArrayList<GeomPart> ();
        public Rect text_rect;

        public void add (PathData p, PartMode mode = PartMode.FILL_STROKE, string? color = null) {
            parts.add (new GeomPart (p, mode, color));
        }
    }

    public class LibEntry {
        public string kind;
        public string name;
        public string category;
        public double w;
        public double h;
        public string keywords;
        public StencilMaster? master = null;

        public LibEntry (string category, string kind, string name, double w, double h, string keywords = "") {
            this.category = category;
            this.kind = kind;
            this.name = name;
            this.w = w;
            this.h = h;
            this.keywords = keywords;
        }
    }

    public class LibCategory {
        public string id;
        public string name;
        public string icon;
        public string group = "";
        public bool user = false;

        public LibCategory (string id, string name, string icon, string group = "") {
            this.id = id;
            this.name = name;
            this.icon = icon;
            this.group = group;
        }
    }

    public class ShapeLibrary {
        private static Gee.ArrayList<LibEntry>? _entries = null;
        private static Gee.ArrayList<LibCategory>? _categories = null;

        public static Gee.ArrayList<LibCategory> categories () {
            if (_categories == null) {
                _categories = new Gee.ArrayList<LibCategory> ();
                _categories.add (new LibCategory ("basic", _("Basic Shapes"), "draw-shapes-symbolic"));
                _categories.add (new LibCategory ("arrows", _("Arrows"), "draw-arrow-symbolic"));
                _categories.add (new LibCategory ("flowchart", _("Flowchart"), "draw-flowchart-symbolic"));
                _categories.add (new LibCategory ("containers", _("Containers and Swimlanes"), "draw-swimlane-symbolic"));
                _categories.add (new LibCategory ("uml", _("UML"), "draw-uml-symbolic"));
                _categories.add (new LibCategory ("bpmn", _("BPMN"), "draw-bpmn-symbolic"));
                _categories.add (new LibCategory ("network", _("Network"), "draw-network-symbolic"));
                _categories.add (new LibCategory ("org", _("Org Chart"), "draw-org-symbolic"));
                _categories.add (new LibCategory ("project", _("Project Schedule"), "x-office-calendar-symbolic", StencilGroup.SCHEDULE));
                foreach (var c in _categories) if (c.group == "") c.group = StencilGroup.GENERAL;
                foreach (var c in Stencils.categories ()) {
                    bool exists = false;
                    foreach (var o in _categories) if (o.id == c.id) exists = true;
                    if (!exists) _categories.add (c);
                }
            }
            var all = new Gee.ArrayList<LibCategory> ();
            all.add_all (_categories);
            all.add_all (UserStencils.categories ());
            return all;
        }

        private static Gee.HashMap<string, LibEntry>? _index = null;

        public static Gee.ArrayList<LibEntry> entries () {
            if (_entries != null) return _entries;
            var l = new Gee.ArrayList<LibEntry> ();
            l.add (new LibEntry ("basic", "rectangle", _("Rectangle"), 120, 70, "box square"));
            l.add (new LibEntry ("basic", "rounded-rectangle", _("Rounded Rectangle"), 120, 70, "box"));
            l.add (new LibEntry ("basic", "ellipse", _("Ellipse"), 120, 80, "oval"));
            l.add (new LibEntry ("basic", "circle", _("Circle"), 80, 80, "round"));
            l.add (new LibEntry ("basic", "triangle", _("Triangle"), 90, 80, ""));
            l.add (new LibEntry ("basic", "right-triangle", _("Right Triangle"), 90, 80, ""));
            l.add (new LibEntry ("basic", "diamond", _("Diamond"), 100, 80, "rhombus"));
            l.add (new LibEntry ("basic", "parallelogram", _("Parallelogram"), 120, 60, ""));
            l.add (new LibEntry ("basic", "trapezoid", _("Trapezoid"), 120, 60, ""));
            l.add (new LibEntry ("basic", "pentagon", _("Pentagon"), 90, 86, ""));
            l.add (new LibEntry ("basic", "hexagon", _("Hexagon"), 110, 80, ""));
            l.add (new LibEntry ("basic", "octagon", _("Octagon"), 90, 90, "stop"));
            l.add (new LibEntry ("basic", "star", _("Star"), 90, 86, ""));
            l.add (new LibEntry ("basic", "star4", _("Four-Point Star"), 80, 80, "sparkle"));
            l.add (new LibEntry ("basic", "cross", _("Cross"), 80, 80, "plus"));
            l.add (new LibEntry ("basic", "heart", _("Heart"), 80, 72, "love"));
            l.add (new LibEntry ("basic", "cloud", _("Cloud"), 130, 84, ""));
            l.add (new LibEntry ("basic", "cube", _("Cube"), 100, 90, "box 3d"));
            l.add (new LibEntry ("basic", "cylinder", _("Cylinder"), 80, 100, "can drum"));
            l.add (new LibEntry ("basic", "donut", _("Ring"), 90, 90, "donut circle"));
            l.add (new LibEntry ("basic", "frame", _("Frame"), 120, 90, "border"));
            l.add (new LibEntry ("basic", "note", _("Note"), 110, 90, "sticky folded"));
            l.add (new LibEntry ("basic", "callout", _("Callout"), 130, 90, "speech balloon"));
            l.add (new LibEntry ("basic", "text", _("Text"), 120, 30, "label"));
            l.add (new LibEntry ("basic", "line-shape", _("Line"), 120, 0, "rule"));

            l.add (new LibEntry ("arrows", "arrow-right", _("Right Arrow"), 120, 60, ""));
            l.add (new LibEntry ("arrows", "arrow-left", _("Left Arrow"), 120, 60, ""));
            l.add (new LibEntry ("arrows", "arrow-up", _("Up Arrow"), 60, 120, ""));
            l.add (new LibEntry ("arrows", "arrow-down", _("Down Arrow"), 60, 120, ""));
            l.add (new LibEntry ("arrows", "arrow-left-right", _("Left and Right Arrow"), 140, 60, "double"));
            l.add (new LibEntry ("arrows", "arrow-up-down", _("Up and Down Arrow"), 60, 140, "double"));
            l.add (new LibEntry ("arrows", "arrow-quad", _("Four-Way Arrow"), 110, 110, "cross move"));
            l.add (new LibEntry ("arrows", "arrow-notched", _("Notched Arrow"), 120, 60, ""));
            l.add (new LibEntry ("arrows", "chevron", _("Chevron"), 100, 60, "step"));
            l.add (new LibEntry ("arrows", "arrow-pentagon", _("Pentagon Arrow"), 120, 60, "step process"));
            l.add (new LibEntry ("arrows", "arrow-uturn", _("U-Turn Arrow"), 110, 100, "return"));

            l.add (new LibEntry ("flowchart", "process", _("Process"), 120, 60, "step action"));
            l.add (new LibEntry ("flowchart", "decision", _("Decision"), 120, 80, "if condition diamond"));
            l.add (new LibEntry ("flowchart", "terminator", _("Start or End"), 120, 50, "terminal begin stop"));
            l.add (new LibEntry ("flowchart", "data", _("Data"), 120, 60, "input output io"));
            l.add (new LibEntry ("flowchart", "predefined-process", _("Predefined Process"), 120, 60, "subroutine"));
            l.add (new LibEntry ("flowchart", "document", _("Document"), 120, 70, "report"));
            l.add (new LibEntry ("flowchart", "multi-document", _("Multiple Documents"), 120, 76, "reports"));
            l.add (new LibEntry ("flowchart", "manual-input", _("Manual Input"), 120, 60, "keyboard"));
            l.add (new LibEntry ("flowchart", "manual-operation", _("Manual Operation"), 120, 60, ""));
            l.add (new LibEntry ("flowchart", "preparation", _("Preparation"), 120, 60, "hexagon setup"));
            l.add (new LibEntry ("flowchart", "delay", _("Delay"), 100, 60, "wait"));
            l.add (new LibEntry ("flowchart", "display", _("Display"), 120, 60, "screen"));
            l.add (new LibEntry ("flowchart", "database", _("Database"), 80, 90, "stored data disk"));
            l.add (new LibEntry ("flowchart", "direct-access", _("Direct Access Storage"), 120, 60, "drum"));
            l.add (new LibEntry ("flowchart", "stored-data", _("Stored Data"), 120, 60, ""));
            l.add (new LibEntry ("flowchart", "internal-storage", _("Internal Storage"), 90, 80, "memory"));
            l.add (new LibEntry ("flowchart", "card", _("Card"), 110, 70, "punched"));
            l.add (new LibEntry ("flowchart", "punched-tape", _("Punched Tape"), 120, 70, "tape"));
            l.add (new LibEntry ("flowchart", "on-page", _("On-Page Reference"), 50, 50, "connector circle"));
            l.add (new LibEntry ("flowchart", "off-page", _("Off-Page Reference"), 60, 60, "connector"));
            l.add (new LibEntry ("flowchart", "summing-junction", _("Summing Junction"), 60, 60, ""));
            l.add (new LibEntry ("flowchart", "or", _("Or"), 60, 60, ""));
            l.add (new LibEntry ("flowchart", "collate", _("Collate"), 60, 70, ""));
            l.add (new LibEntry ("flowchart", "sort", _("Sort"), 60, 70, ""));
            l.add (new LibEntry ("flowchart", "merge", _("Merge"), 80, 60, ""));
            l.add (new LibEntry ("flowchart", "extract", _("Extract"), 80, 60, ""));
            l.add (new LibEntry ("flowchart", "loop-limit", _("Loop Limit"), 120, 60, "loop"));
            l.add (new LibEntry ("flowchart", "annotation", _("Annotation"), 110, 60, "comment bracket"));

            l.add (new LibEntry ("containers", "container", _("Container"), 320, 220, "group box"));
            l.add (new LibEntry ("containers", "swimlane-h", _("Horizontal Swimlane"), 520, 140, "lane"));
            l.add (new LibEntry ("containers", "swimlane-v", _("Vertical Swimlane"), 200, 420, "lane"));
            l.add (new LibEntry ("containers", "pool", _("Pool"), 560, 260, "swimlane"));
            l.add (new LibEntry ("containers", "group-box", _("Titled Box"), 300, 200, "frame"));
            l.add (new LibEntry ("containers", "pool-v", _("Vertical Pool"), 460, 520, "swimlane cross-functional"));
            l.add (new LibEntry ("containers", "cff-phase", _("Phase"), 300, 450, "separator milestone stage cross-functional"));
            l.add (new LibEntry ("containers", "cff-phase-h", _("Horizontal Phase"), 450, 200, "separator milestone stage cross-functional"));

            l.add (new LibEntry ("uml", "uml-class", _("Class"), 160, 110, "object"));
            l.add (new LibEntry ("uml", "uml-interface", _("Interface"), 160, 90, ""));
            l.add (new LibEntry ("uml", "uml-object", _("Object"), 140, 50, "instance"));
            l.add (new LibEntry ("uml", "uml-actor", _("Actor"), 40, 80, "user person"));
            l.add (new LibEntry ("uml", "uml-usecase", _("Use Case"), 140, 70, "ellipse"));
            l.add (new LibEntry ("uml", "uml-package", _("Package"), 160, 110, "folder namespace"));
            l.add (new LibEntry ("uml", "uml-component", _("Component"), 150, 80, "module"));
            l.add (new LibEntry ("uml", "uml-node", _("Node"), 150, 100, "device 3d"));
            l.add (new LibEntry ("uml", "uml-note", _("Note"), 130, 70, "comment"));
            l.add (new LibEntry ("uml", "uml-state", _("State"), 130, 60, ""));
            l.add (new LibEntry ("uml", "uml-initial", _("Initial State"), 30, 30, "start"));
            l.add (new LibEntry ("uml", "uml-final", _("Final State"), 34, 34, "end"));
            l.add (new LibEntry ("uml", "uml-decision", _("Decision"), 40, 40, "merge branch"));
            l.add (new LibEntry ("uml", "uml-fork", _("Fork or Join"), 140, 8, "bar synchronization"));
            l.add (new LibEntry ("uml", "uml-lifeline", _("Lifeline"), 110, 300, "sequence"));
            l.add (new LibEntry ("uml", "uml-activation", _("Activation"), 14, 90, "sequence execution"));

            l.add (new LibEntry ("bpmn", "bpmn-task", _("Task"), 120, 80, "activity"));
            l.add (new LibEntry ("bpmn", "bpmn-subprocess", _("Subprocess"), 120, 80, "collapsed"));
            l.add (new LibEntry ("bpmn", "bpmn-start", _("Start Event"), 40, 40, "event"));
            l.add (new LibEntry ("bpmn", "bpmn-intermediate", _("Intermediate Event"), 40, 40, "event"));
            l.add (new LibEntry ("bpmn", "bpmn-end", _("End Event"), 40, 40, "event"));
            l.add (new LibEntry ("bpmn", "bpmn-timer", _("Timer Event"), 40, 40, "clock event"));
            l.add (new LibEntry ("bpmn", "bpmn-message", _("Message Event"), 40, 40, "mail event"));
            l.add (new LibEntry ("bpmn", "bpmn-gateway", _("Exclusive Gateway"), 50, 50, "xor"));
            l.add (new LibEntry ("bpmn", "bpmn-gateway-parallel", _("Parallel Gateway"), 50, 50, "and"));
            l.add (new LibEntry ("bpmn", "bpmn-gateway-inclusive", _("Inclusive Gateway"), 50, 50, "or"));
            l.add (new LibEntry ("bpmn", "bpmn-gateway-event", _("Event-Based Gateway"), 50, 50, ""));
            l.add (new LibEntry ("bpmn", "bpmn-data-object", _("Data Object"), 40, 54, "file"));
            l.add (new LibEntry ("bpmn", "bpmn-data-store", _("Data Store"), 56, 50, "database"));
            l.add (new LibEntry ("bpmn", "bpmn-pool", _("Pool"), 600, 200, "participant lane"));
            l.add (new LibEntry ("bpmn", "bpmn-group", _("Group"), 240, 160, ""));
            l.add (new LibEntry ("bpmn", "bpmn-annotation", _("Text Annotation"), 110, 50, "comment"));

            l.add (new LibEntry ("network", "net-server", _("Server"), 50, 70, "host rack"));
            l.add (new LibEntry ("network", "net-desktop", _("Desktop Computer"), 70, 60, "pc workstation"));
            l.add (new LibEntry ("network", "net-laptop", _("Laptop"), 76, 50, "notebook"));
            l.add (new LibEntry ("network", "net-phone", _("Mobile Phone"), 34, 60, "smartphone"));
            l.add (new LibEntry ("network", "net-router", _("Router"), 70, 44, "gateway"));
            l.add (new LibEntry ("network", "net-switch", _("Switch"), 90, 34, "hub"));
            l.add (new LibEntry ("network", "net-firewall", _("Firewall"), 70, 56, "security wall"));
            l.add (new LibEntry ("network", "net-wireless", _("Wireless Access Point"), 60, 54, "wifi ap"));
            l.add (new LibEntry ("network", "net-cloud", _("Internet"), 110, 70, "cloud"));
            l.add (new LibEntry ("network", "net-database", _("Database Server"), 56, 70, "sql"));
            l.add (new LibEntry ("network", "net-storage", _("Storage"), 60, 66, "nas san disk"));
            l.add (new LibEntry ("network", "net-printer", _("Printer"), 64, 56, ""));
            l.add (new LibEntry ("network", "net-user", _("User"), 46, 56, "person client"));

            l.add (new LibEntry ("org", "org-person", _("Person"), 180, 64, "employee"));
            l.add (new LibEntry ("org", "org-manager", _("Manager"), 180, 64, "executive head"));
            l.add (new LibEntry ("org", "org-assistant", _("Assistant"), 160, 56, "staff"));
            l.add (new LibEntry ("org", "org-position", _("Position"), 150, 50, "vacancy role"));
            l.add (new LibEntry ("org", "org-team", _("Team"), 170, 60, "department group"));
            l.add (new LibEntry ("project", "gantt", _("Gantt Chart"), 720, 212, "schedule project plan tasks timeline"));
            foreach (var d in Stencils.all ()) l.add (d.entry ());
            _entries = l;
            _index = new Gee.HashMap<string, LibEntry> ();
            foreach (var e in l) if (!_index.has_key (e.kind)) _index[e.kind] = e;
            return l;
        }

        public static Gee.ArrayList<LibEntry> all_entries () {
            var list = new Gee.ArrayList<LibEntry> ();
            list.add_all (entries ());
            list.add_all (UserStencils.entries ());
            return list;
        }

        public static LibEntry? find (string kind) {
            entries ();
            if (_index.has_key (kind)) return _index[kind];
            if (kind.has_prefix ("master:")) return UserStencils.find_entry (kind);
            return null;
        }

        public static string display_name (string kind) {
            var e = find (kind);
            if (e != null) return e.name;
            switch (kind) {
                case "path": return _("Path");
                case "image": return _("Image");
                case "table": return _("Table");
                default: return _("Shape");
            }
        }

        public static bool is_container (string kind) {
            var def = Stencils.find (kind);
            if (def != null) return def.container;
            switch (kind) {
                case "container":
                case "swimlane-h":
                case "swimlane-v":
                case "pool":
                case "pool-v":
                case "group-box":
                case "bpmn-pool":
                case "bpmn-group":
                case "uml-package":
                    return true;
                default:
                    return false;
            }
        }

        public static bool text_below (string kind) {
            var def = Stencils.find (kind);
            if (def != null) return def.below;
            return kind.has_prefix ("net-") || kind == "uml-actor" || kind == "uml-initial" || kind == "uml-final" ||
                   kind == "bpmn-start" || kind == "bpmn-intermediate" || kind == "bpmn-end" || kind == "bpmn-timer" ||
                   kind == "bpmn-message" || kind.has_prefix ("bpmn-gateway") || kind == "bpmn-data-object" ||
                   kind == "bpmn-data-store" || kind == "uml-decision";
        }

        public static void apply_defaults (Shape s) {
            var st = s.style;
            var def = Stencils.find (s.kind);
            if (def != null) {
                def.apply_defaults (st);
                return;
            }
            switch (s.kind) {
                case "text":
                    st.fill_kind = FillKind.NONE;
                    st.stroke = "none";
                    break;
                case "line-shape":
                    st.fill_kind = FillKind.NONE;
                    break;
                case "uml-actor":
                case "annotation":
                case "bpmn-annotation":
                case "uml-lifeline":
                    st.fill_kind = FillKind.NONE;
                    break;
                case "uml-initial":
                case "uml-fork":
                    st.fill = st.stroke;
                    break;
                case "bpmn-end":
                    st.stroke_width = 3.5;
                    st.stroke = "#b3261e";
                    st.fill = "#fdecea";
                    break;
                case "bpmn-start":
                    st.stroke = "#2e7d32";
                    st.fill = "#eaf6ec";
                    break;
                case "bpmn-task":
                case "bpmn-subprocess":
                case "uml-state":
                    st.corner_radius = 10;
                    break;
                case "rounded-rectangle":
                    st.corner_radius = 12;
                    break;
                case "note":
                case "uml-note":
                    st.fill = "#fff6c9";
                    st.stroke = "#b59a2b";
                    break;
                case "bpmn-group":
                    st.fill_kind = FillKind.NONE;
                    st.dash = DashKind.DASH_DOT;
                    st.corner_radius = 10;
                    st.valign = TextVAlign.TOP;
                    break;
                case "container":
                case "group-box":
                case "uml-package":
                    st.fill = "#f4f8fc";
                    st.valign = TextVAlign.TOP;
                    st.corner_radius = s.kind == "container" ? 8 : 0;
                    break;
                case "swimlane-h":
                case "swimlane-v":
                case "pool":
                case "pool-v":
                case "bpmn-pool":
                    st.fill = "#f4f8fc";
                    st.bold = true;
                    break;
                case "cff-phase":
                case "cff-phase-h":
                    st.fill = "#e9eef4";
                    st.dash = DashKind.DASH;
                    st.valign = TextVAlign.TOP;
                    break;
                case "org-manager":
                    st.fill2 = "#3a6ea5";
                    break;
                case "uml-class":
                case "uml-interface":
                    st.halign = TextHAlign.LEFT;
                    st.valign = TextVAlign.TOP;
                    break;
            }
            if (s.kind.has_prefix ("net-")) {
                st.fill = "#dcebf7";
                st.stroke = "#2f5f8f";
            }
        }

        public static string default_text (string kind) {
            var def = Stencils.find (kind);
            if (def != null) return def.text_default;
            switch (kind) {
                case "uml-class": return "ClassName\n--\n+ attribute: Type\n--\n+ operation(): Type";
                case "uml-interface": return "«interface»\nName\n--\n+ operation(): Type";
                case "uml-object": return "object : Class";
                case "uml-package": return "package";
                case "uml-lifeline": return ":Object";
                case "org-person": return "Name\nTitle";
                case "org-manager": return "Name\nManager";
                case "org-assistant": return "Name\nAssistant";
                case "org-position": return "Position";
                case "org-team": return "Team";
                case "pool": case "bpmn-pool": case "pool-v": return "Pool";
                case "cff-phase": case "cff-phase-h": return "Phase";
                case "swimlane-h": case "swimlane-v": return "Lane";
                case "container": return "Container";
                case "group-box": return "Title";
                case "text": return "Text";
                default: return "";
            }
        }

        public static Point[] ports (string kind, double w, double h) {
            var def = Stencils.find (kind);
            if (def != null && def.ports.length > 0) return def.ports;
            switch (kind) {
                case "triangle":
                    return { Point (0.5, 0), Point (0.75, 0.5), Point (0.5, 1), Point (0.25, 0.5) };
                case "right-triangle":
                    return { Point (0, 0), Point (0.5, 0.5), Point (0.5, 1), Point (0, 0.5) };
                case "line-shape":
                    return { Point (0, 0.5), Point (0.5, 0.5), Point (1, 0.5) };
                case "uml-lifeline":
                    return { Point (0.5, 0), Point (1, 0.08), Point (0.5, 1), Point (0, 0.08) };
                default:
                    return { Point (0.5, 0), Point (1, 0.5), Point (0.5, 1), Point (0, 0.5) };
            }
        }

        private static PathData unit (string d, double w, double h) {
            var p = PathData.parse_svg (d);
            p.scale (w, h);
            return p;
        }

        private static PathData poly (double w, double h, double[] xy, bool closed = true) {
            var p = new PathData ();
            for (int i = 0; i + 1 < xy.length; i += 2) {
                if (i == 0) p.move_to (xy[i] * w, xy[i + 1] * h);
                else p.line_to (xy[i] * w, xy[i + 1] * h);
            }
            if (closed) p.close ();
            return p;
        }

        private static PathData line (double x1, double y1, double x2, double y2) {
            var p = new PathData ();
            p.move_to (x1, y1);
            p.line_to (x2, y2);
            return p;
        }

        private static PathData regular (double w, double h, int n, double start) {
            var p = new PathData ();
            for (int i = 0; i < n; i++) {
                double a = start + i * 2 * Math.PI / n;
                double x = w / 2 + w / 2 * Math.cos (a), y = h / 2 + h / 2 * Math.sin (a);
                if (i == 0) p.move_to (x, y);
                else p.line_to (x, y);
            }
            p.close ();
            return p;
        }

        private static PathData star (double w, double h, int n, double inner) {
            var p = new PathData ();
            for (int i = 0; i < n * 2; i++) {
                double a = -Math.PI / 2 + i * Math.PI / n;
                double r = i % 2 == 0 ? 1 : inner;
                double x = w / 2 + w / 2 * r * Math.cos (a), y = h / 2 + h / 2 * r * Math.sin (a);
                if (i == 0) p.move_to (x, y);
                else p.line_to (x, y);
            }
            p.close ();
            return p;
        }

        public static Geometry build (string kind, double w, double h, Style st) {
            var def = Stencils.find (kind);
            if (def != null) return def.build (w, h, st);
            var g = new Geometry ();
            double pad = 4;
            g.text_rect = Rect (pad, pad, double.max (w - 2 * pad, 1), double.max (h - 2 * pad, 1));
            double r = st.corner_radius;
            switch (kind) {
                case "rectangle":
                case "process":
                case "container":
                case "bpmn-task":
                case "uml-state":
                case "org-position":
                    g.add (new PathData.round_rect (0, 0, w, h, r));
                    break;
                case "rounded-rectangle":
                    g.add (new PathData.round_rect (0, 0, w, h, r > 0 ? r : double.min (w, h) * 0.15));
                    break;
                case "text":
                    g.text_rect = Rect (0, 0, w, h);
                    if (st.has_fill () || st.has_stroke ()) g.add (new PathData.round_rect (0, 0, w, h, r));
                    break;
                case "line-shape":
                    g.add (line (0, h / 2, w, h / 2), PartMode.STROKE);
                    g.text_rect = Rect (0, h / 2 - 22, w, 20);
                    break;
                case "ellipse":
                case "circle":
                case "uml-usecase":
                    g.add (new PathData.ellipse (w / 2, h / 2, w / 2, h / 2));
                    g.text_rect = Rect (w * 0.15, h * 0.15, w * 0.7, h * 0.7);
                    break;
                case "on-page":
                    g.add (new PathData.ellipse (w / 2, h / 2, w / 2, h / 2));
                    break;
                case "triangle":
                    g.add (poly (w, h, { 0.5, 0, 1, 1, 0, 1 }));
                    g.text_rect = Rect (w * 0.25, h * 0.45, w * 0.5, h * 0.5);
                    break;
                case "right-triangle":
                    g.add (poly (w, h, { 0, 0, 1, 1, 0, 1 }));
                    g.text_rect = Rect (pad, h * 0.5, w * 0.5, h * 0.45);
                    break;
                case "diamond":
                case "decision":
                case "uml-decision":
                    g.add (poly (w, h, { 0.5, 0, 1, 0.5, 0.5, 1, 0, 0.5 }));
                    g.text_rect = Rect (w * 0.2, h * 0.2, w * 0.6, h * 0.6);
                    break;
                case "parallelogram":
                case "data":
                    double o = double.min (w * 0.2, h * 0.6);
                    var pg = new PathData ();
                    pg.add_polygon ({ Point (o, 0), Point (w, 0), Point (w - o, h), Point (0, h) });
                    g.add (pg);
                    g.text_rect = Rect (o, pad, double.max (w - 2 * o, 1), h - 2 * pad);
                    break;
                case "trapezoid":
                    double t = double.min (w * 0.2, h * 0.6);
                    var tp = new PathData ();
                    tp.add_polygon ({ Point (t, 0), Point (w - t, 0), Point (w, h), Point (0, h) });
                    g.add (tp);
                    break;
                case "manual-operation":
                    double mo = double.min (w * 0.15, h * 0.5);
                    var mp = new PathData ();
                    mp.add_polygon ({ Point (0, 0), Point (w, 0), Point (w - mo, h), Point (mo, h) });
                    g.add (mp);
                    g.text_rect = Rect (mo, pad, w - 2 * mo, h - 2 * pad);
                    break;
                case "pentagon":
                    g.add (regular (w, h, 5, -Math.PI / 2));
                    break;
                case "hexagon":
                case "preparation":
                    double hx = double.min (w * 0.25, h * 0.5);
                    var hp = new PathData ();
                    hp.add_polygon ({ Point (hx, 0), Point (w - hx, 0), Point (w, h / 2), Point (w - hx, h), Point (hx, h), Point (0, h / 2) });
                    g.add (hp);
                    g.text_rect = Rect (hx * 0.6, pad, w - hx * 1.2, h - 2 * pad);
                    break;
                case "octagon":
                    g.add (poly (w, h, { 0.29, 0, 0.71, 0, 1, 0.29, 1, 0.71, 0.71, 1, 0.29, 1, 0, 0.71, 0, 0.29 }));
                    break;
                case "star":
                    g.add (star (w, h, 5, 0.42));
                    g.text_rect = Rect (w * 0.3, h * 0.35, w * 0.4, h * 0.35);
                    break;
                case "star4":
                    g.add (star (w, h, 4, 0.38));
                    g.text_rect = Rect (w * 0.3, h * 0.3, w * 0.4, h * 0.4);
                    break;
                case "cross":
                    g.add (poly (w, h, { 0.33, 0, 0.67, 0, 0.67, 0.33, 1, 0.33, 1, 0.67, 0.67, 0.67, 0.67, 1, 0.33, 1, 0.33, 0.67, 0, 0.67, 0, 0.33, 0.33, 0.33 }));
                    break;
                case "heart":
                    g.add (unit ("M0.5 0.22 C0.5 0.06 0.3 -0.03 0.15 0.06 C-0.01 0.16 -0.02 0.42 0.12 0.56 L0.5 0.98 L0.88 0.56 C1.02 0.42 1.01 0.16 0.85 0.06 C0.7 -0.03 0.5 0.06 0.5 0.22 Z", w, h));
                    g.text_rect = Rect (w * 0.2, h * 0.2, w * 0.6, h * 0.45);
                    break;
                case "cloud":
                case "net-cloud":
                    g.add (unit ("M0.25 0.92 C0.06 0.92 0.0 0.66 0.15 0.56 C0.06 0.34 0.28 0.14 0.44 0.26 C0.52 0.04 0.83 0.06 0.84 0.34 C1.02 0.36 1.04 0.72 0.86 0.84 C0.84 0.92 0.8 0.92 0.76 0.92 Z", w, h));
                    g.text_rect = Rect (w * 0.18, h * 0.34, w * 0.64, h * 0.5);
                    break;
                case "cube":
                case "uml-node":
                    double d = double.min (w, h) * 0.18;
                    var front = new PathData ();
                    front.add_polygon ({ Point (0, d), Point (w - d, d), Point (w - d, h), Point (0, h) });
                    var top = new PathData ();
                    top.add_polygon ({ Point (0, d), Point (d, 0), Point (w, 0), Point (w - d, d) });
                    var side = new PathData ();
                    side.add_polygon ({ Point (w - d, d), Point (w, 0), Point (w, h - d), Point (w - d, h) });
                    g.add (front);
                    g.add (top, PartMode.FILL_SHADE);
                    g.add (side, PartMode.FILL_SHADE);
                    g.text_rect = Rect (pad, d + pad, w - d - 2 * pad, h - d - 2 * pad);
                    break;
                case "cylinder":
                case "database":
                case "net-database":
                    double e = double.min (h * 0.12, w * 0.3);
                    var body = new PathData ();
                    body.move_to (0, e);
                    body.line_to (0, h - e);
                    body.curve_to (0, h - e + e * 1.33, w, h - e + e * 1.33, w, h - e);
                    body.line_to (w, e);
                    body.curve_to (w, e - e * 1.33, 0, e - e * 1.33, 0, e);
                    body.close ();
                    g.add (body);
                    var rim = new PathData ();
                    rim.move_to (0, e);
                    rim.curve_to (0, e + e * 1.33, w, e + e * 1.33, w, e);
                    g.add (rim, PartMode.STROKE);
                    if (kind == "net-database") {
                        for (int i = 1; i <= 2; i++) {
                            double yy = e + (h - 2 * e) * i / 3.0;
                            var band = new PathData ();
                            band.move_to (0, yy);
                            band.curve_to (0, yy + e * 1.33, w, yy + e * 1.33, w, yy);
                            g.add (band, PartMode.STROKE);
                        }
                        g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    } else {
                        g.text_rect = Rect (pad, 2 * e + pad, w - 2 * pad, h - 3 * e - 2 * pad);
                    }
                    break;
                case "direct-access":
                    double ex = double.min (w * 0.12, h * 0.3);
                    var drum = new PathData ();
                    drum.move_to (ex, 0);
                    drum.line_to (w - ex, 0);
                    drum.curve_to (w - ex + ex * 1.33, 0, w - ex + ex * 1.33, h, w - ex, h);
                    drum.line_to (ex, h);
                    drum.curve_to (ex - ex * 1.33, h, ex - ex * 1.33, 0, ex, 0);
                    drum.close ();
                    g.add (drum);
                    var drim = new PathData ();
                    drim.move_to (w - ex, 0);
                    drim.curve_to (w - ex - ex * 1.33, 0, w - ex - ex * 1.33, h, w - ex, h);
                    g.add (drim, PartMode.STROKE);
                    g.text_rect = Rect (ex, pad, w - 3 * ex, h - 2 * pad);
                    break;
                case "stored-data":
                    double sd = double.min (w * 0.15, h * 0.4);
                    var sp = new PathData ();
                    sp.move_to (sd, 0);
                    sp.line_to (w, 0);
                    sp.curve_to (w - sd * 1.33, 0, w - sd * 1.33, h, w, h);
                    sp.line_to (sd, h);
                    sp.curve_to (-sd * 0.33, h, -sd * 0.33, 0, sd, 0);
                    sp.close ();
                    g.add (sp);
                    g.text_rect = Rect (sd, pad, w - 2 * sd, h - 2 * pad);
                    break;
                case "donut":
                    var dn = new PathData.ellipse (w / 2, h / 2, w / 2, h / 2);
                    var hole = new PathData.ellipse (w / 2, h / 2, w * 0.28, h * 0.28);
                    hole.reverse ();
                    dn.append (hole);
                    g.add (dn);
                    break;
                case "frame":
                    double fw = double.min (w, h) * 0.12;
                    var fr = new PathData.rect (0, 0, w, h);
                    var inner = new PathData.rect (fw, fw, w - 2 * fw, h - 2 * fw);
                    inner.reverse ();
                    fr.append (inner);
                    g.add (fr);
                    g.text_rect = Rect (fw + pad, fw + pad, w - 2 * fw - 2 * pad, h - 2 * fw - 2 * pad);
                    break;
                case "note":
                case "uml-note":
                case "bpmn-data-object":
                    double f = double.min (double.min (w, h) * 0.25, 18);
                    var np = new PathData ();
                    np.add_polygon ({ Point (0, 0), Point (w - f, 0), Point (w, f), Point (w, h), Point (0, h) });
                    g.add (np);
                    var fold = new PathData ();
                    fold.add_polygon ({ Point (w - f, 0), Point (w - f, f), Point (w, f) });
                    g.add (fold, PartMode.FILL_SHADE);
                    if (kind == "bpmn-data-object") g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "callout":
                    var cp = new PathData ();
                    double bh = h * 0.72;
                    double rr = double.min (r > 0 ? r : 10, double.min (w, bh) / 2);
                    cp.add_round_rect (0, 0, w, bh, rr);
                    var body_c = new PathData ();
                    body_c.move_to (rr, 0);
                    body_c.line_to (w - rr, 0);
                    body_c.curve_to (w - rr * 0.45, 0, w, rr * 0.45, w, rr);
                    body_c.line_to (w, bh - rr);
                    body_c.curve_to (w, bh - rr * 0.45, w - rr * 0.45, bh, w - rr, bh);
                    body_c.line_to (w * 0.42, bh);
                    body_c.line_to (w * 0.2, h);
                    body_c.line_to (w * 0.26, bh);
                    body_c.line_to (rr, bh);
                    body_c.curve_to (rr * 0.45, bh, 0, bh - rr * 0.45, 0, bh - rr);
                    body_c.line_to (0, rr);
                    body_c.curve_to (0, rr * 0.45, rr * 0.45, 0, rr, 0);
                    body_c.close ();
                    g.add (body_c);
                    g.text_rect = Rect (pad, pad, w - 2 * pad, bh - 2 * pad);
                    break;
                case "arrow-right":
                    g.add (poly (w, h, { 0, 0.25, 0.62, 0.25, 0.62, 0, 1, 0.5, 0.62, 1, 0.62, 0.75, 0, 0.75 }));
                    g.text_rect = Rect (pad, h * 0.25, w * 0.7, h * 0.5);
                    break;
                case "arrow-left":
                    g.add (poly (w, h, { 1, 0.25, 0.38, 0.25, 0.38, 0, 0, 0.5, 0.38, 1, 0.38, 0.75, 1, 0.75 }));
                    g.text_rect = Rect (w * 0.3, h * 0.25, w * 0.7 - pad, h * 0.5);
                    break;
                case "arrow-up":
                    g.add (poly (w, h, { 0.25, 1, 0.25, 0.38, 0, 0.38, 0.5, 0, 1, 0.38, 0.75, 0.38, 0.75, 1 }));
                    g.text_rect = Rect (w * 0.25, h * 0.38, w * 0.5, h * 0.6);
                    break;
                case "arrow-down":
                    g.add (poly (w, h, { 0.25, 0, 0.25, 0.62, 0, 0.62, 0.5, 1, 1, 0.62, 0.75, 0.62, 0.75, 0 }));
                    g.text_rect = Rect (w * 0.25, pad, w * 0.5, h * 0.6);
                    break;
                case "arrow-left-right":
                    g.add (poly (w, h, { 0, 0.5, 0.25, 0, 0.25, 0.25, 0.75, 0.25, 0.75, 0, 1, 0.5, 0.75, 1, 0.75, 0.75, 0.25, 0.75, 0.25, 1 }));
                    g.text_rect = Rect (w * 0.22, h * 0.25, w * 0.56, h * 0.5);
                    break;
                case "arrow-up-down":
                    g.add (poly (w, h, { 0.5, 0, 1, 0.25, 0.75, 0.25, 0.75, 0.75, 1, 0.75, 0.5, 1, 0, 0.75, 0.25, 0.75, 0.25, 0.25, 0, 0.25 }));
                    g.text_rect = Rect (w * 0.25, h * 0.25, w * 0.5, h * 0.5);
                    break;
                case "arrow-quad":
                    g.add (poly (w, h, { 0.5, 0, 0.66, 0.16, 0.57, 0.16, 0.57, 0.43, 0.84, 0.43, 0.84, 0.34, 1, 0.5, 0.84, 0.66, 0.84, 0.57, 0.57, 0.57, 0.57, 0.84, 0.66, 0.84, 0.5, 1, 0.34, 0.84, 0.43, 0.84, 0.43, 0.57, 0.16, 0.57, 0.16, 0.66, 0, 0.5, 0.16, 0.34, 0.16, 0.43, 0.43, 0.43, 0.43, 0.16, 0.34, 0.16 }));
                    break;
                case "arrow-notched":
                    g.add (poly (w, h, { 0, 0.25, 0.62, 0.25, 0.62, 0, 1, 0.5, 0.62, 1, 0.62, 0.75, 0, 0.75, 0.12, 0.5 }));
                    g.text_rect = Rect (w * 0.12, h * 0.25, w * 0.6, h * 0.5);
                    break;
                case "chevron":
                    double cv = double.min (w * 0.3, h * 0.5);
                    var ch = new PathData ();
                    ch.add_polygon ({ Point (0, 0), Point (w - cv, 0), Point (w, h / 2), Point (w - cv, h), Point (0, h), Point (cv, h / 2) });
                    g.add (ch);
                    g.text_rect = Rect (cv, pad, w - 2 * cv, h - 2 * pad);
                    break;
                case "arrow-pentagon":
                    double pa = double.min (w * 0.3, h * 0.5);
                    var pp = new PathData ();
                    pp.add_polygon ({ Point (0, 0), Point (w - pa, 0), Point (w, h / 2), Point (w - pa, h), Point (0, h) });
                    g.add (pp);
                    g.text_rect = Rect (pad, pad, w - pa - pad, h - 2 * pad);
                    break;
                case "arrow-uturn":
                    var up = new PathData ();
                    up.move_to (0, h);
                    up.line_to (0, h * 0.45);
                    up.arc_to (w * 0.4, h * 0.45, w * 0.4, h * 0.45, Math.PI, 2 * Math.PI);
                    up.line_to (w * 0.8, h * 0.62);
                    up.line_to (w, h * 0.62);
                    up.line_to (w * 0.7, h);
                    up.line_to (w * 0.4, h * 0.62);
                    up.line_to (w * 0.6, h * 0.62);
                    up.line_to (w * 0.6, h * 0.45);
                    up.arc_to (w * 0.4, h * 0.45, w * 0.2, h * 0.22, 2 * Math.PI, Math.PI);
                    up.line_to (w * 0.2, h);
                    up.close ();
                    g.add (up);
                    g.text_rect = Rect (0, h + 4, w, 20);
                    break;
                case "terminator":
                    g.add (new PathData.round_rect (0, 0, w, h, h / 2));
                    g.text_rect = Rect (h * 0.3, pad, w - h * 0.6, h - 2 * pad);
                    break;
                case "predefined-process":
                    double pv = double.min (w * 0.1, 14);
                    g.add (new PathData.rect (0, 0, w, h));
                    g.add (line (pv, 0, pv, h), PartMode.STROKE);
                    g.add (line (w - pv, 0, w - pv, h), PartMode.STROKE);
                    g.text_rect = Rect (pv + pad, pad, w - 2 * pv - 2 * pad, h - 2 * pad);
                    break;
                case "document":
                    g.add (unit ("M0 0 L1 0 L1 0.83 C0.75 0.72 0.62 0.72 0.5 0.86 C0.38 1.0 0.2 1.02 0 0.9 Z", w, h));
                    g.text_rect = Rect (pad, pad, w - 2 * pad, h * 0.78 - pad);
                    break;
                case "multi-document":
                    var back2 = unit ("M0.12 0 L1 0 L1 0.72 C0.97 0.71 0.95 0.71 0.94 0.71 L0.94 0.1 L0.12 0.1 Z", w, h);
                    var back1 = unit ("M0.06 0.06 L0.94 0.06 L0.94 0.78 C0.91 0.77 0.89 0.77 0.88 0.77 L0.88 0.16 L0.06 0.16 Z", w, h);
                    var fronts = unit ("M0 0.12 L0.88 0.12 L0.88 0.86 C0.66 0.76 0.55 0.76 0.44 0.88 C0.34 1.0 0.18 1.02 0 0.93 Z", w, h);
                    g.add (back2);
                    g.add (back1);
                    g.add (fronts);
                    g.text_rect = Rect (pad, h * 0.12 + pad, w * 0.88 - 2 * pad, h * 0.66);
                    break;
                case "manual-input":
                    g.add (poly (w, h, { 0, 0.3, 1, 0, 1, 1, 0, 1 }));
                    g.text_rect = Rect (pad, h * 0.3, w - 2 * pad, h * 0.7 - pad);
                    break;
                case "delay":
                    var dl = new PathData ();
                    double rad = double.min (h / 2, w / 2);
                    dl.move_to (0, 0);
                    dl.line_to (w - rad, 0);
                    dl.arc_to (w - rad, h / 2, rad, h / 2, -Math.PI / 2, Math.PI / 2);
                    dl.line_to (0, h);
                    dl.close ();
                    g.add (dl);
                    g.text_rect = Rect (pad, pad, w - rad * 0.6 - pad, h - 2 * pad);
                    break;
                case "display":
                    var dp = new PathData ();
                    double dr = double.min (w * 0.18, h / 2);
                    dp.move_to (dr, 0);
                    dp.line_to (w - dr, 0);
                    dp.curve_to (w - dr * 0.1, 0, w, h * 0.3, w, h / 2);
                    dp.curve_to (w, h * 0.7, w - dr * 0.1, h, w - dr, h);
                    dp.line_to (dr, h);
                    dp.line_to (0, h / 2);
                    dp.close ();
                    g.add (dp);
                    g.text_rect = Rect (dr, pad, w - 2 * dr, h - 2 * pad);
                    break;
                case "internal-storage":
                    double iv = double.min (w, h) * 0.18;
                    g.add (new PathData.rect (0, 0, w, h));
                    g.add (line (iv, 0, iv, h), PartMode.STROKE);
                    g.add (line (0, iv, w, iv), PartMode.STROKE);
                    g.text_rect = Rect (iv + pad, iv + pad, w - iv - 2 * pad, h - iv - 2 * pad);
                    break;
                case "card":
                    double cc = double.min (w, h) * 0.25;
                    var cardp = new PathData ();
                    cardp.add_polygon ({ Point (cc, 0), Point (w, 0), Point (w, h), Point (0, h), Point (0, cc) });
                    g.add (cardp);
                    break;
                case "punched-tape":
                    g.add (unit ("M0 0.1 C0.12 0.26 0.37 0.26 0.5 0.1 C0.62 -0.06 0.87 -0.06 1 0.1 L1 0.9 C0.87 0.74 0.62 0.74 0.5 0.9 C0.37 1.06 0.12 1.06 0 0.9 Z", w, h));
                    g.text_rect = Rect (pad, h * 0.2, w - 2 * pad, h * 0.6);
                    break;
                case "off-page":
                    g.add (poly (w, h, { 0, 0, 1, 0, 1, 0.62, 0.5, 1, 0, 0.62 }));
                    g.text_rect = Rect (pad, pad, w - 2 * pad, h * 0.6);
                    break;
                case "summing-junction":
                    g.add (new PathData.ellipse (w / 2, h / 2, w / 2, h / 2));
                    double k = 0.7071;
                    g.add (line (w / 2 - w / 2 * k, h / 2 - h / 2 * k, w / 2 + w / 2 * k, h / 2 + h / 2 * k), PartMode.STROKE);
                    g.add (line (w / 2 + w / 2 * k, h / 2 - h / 2 * k, w / 2 - w / 2 * k, h / 2 + h / 2 * k), PartMode.STROKE);
                    g.text_rect = Rect (-20, h + 4, w + 40, 20);
                    break;
                case "or":
                    g.add (new PathData.ellipse (w / 2, h / 2, w / 2, h / 2));
                    g.add (line (w / 2, 0, w / 2, h), PartMode.STROKE);
                    g.add (line (0, h / 2, w, h / 2), PartMode.STROKE);
                    g.text_rect = Rect (-20, h + 4, w + 40, 20);
                    break;
                case "collate":
                    g.add (poly (w, h, { 0, 0, 1, 0, 0, 1, 1, 1 }));
                    g.text_rect = Rect (-20, h + 4, w + 40, 20);
                    break;
                case "sort":
                    g.add (poly (w, h, { 0.5, 0, 1, 0.5, 0.5, 1, 0, 0.5 }));
                    g.add (line (0, h / 2, w, h / 2), PartMode.STROKE);
                    g.text_rect = Rect (-20, h + 4, w + 40, 20);
                    break;
                case "merge":
                    g.add (poly (w, h, { 0, 0, 1, 0, 0.5, 1 }));
                    g.text_rect = Rect (w * 0.2, pad, w * 0.6, h * 0.5);
                    break;
                case "extract":
                    g.add (poly (w, h, { 0.5, 0, 1, 1, 0, 1 }));
                    g.text_rect = Rect (w * 0.2, h * 0.5, w * 0.6, h * 0.5 - pad);
                    break;
                case "loop-limit":
                    double lc = double.min (w * 0.15, h * 0.4);
                    var ll = new PathData ();
                    ll.add_polygon ({ Point (lc, 0), Point (w - lc, 0), Point (w, lc), Point (w, h), Point (0, h), Point (0, lc) });
                    g.add (ll);
                    break;
                case "annotation":
                case "bpmn-annotation":
                    var br = new PathData ();
                    double bw = double.min (w * 0.12, 12);
                    br.move_to (bw, 0);
                    br.line_to (0, 0);
                    br.line_to (0, h);
                    br.line_to (bw, h);
                    g.add (br, PartMode.STROKE);
                    g.text_rect = Rect (bw, pad, w - bw - pad, h - 2 * pad);
                    break;
                case "swimlane-h":
                case "pool":
                case "bpmn-pool":
                    double hw = double.min (30, w * 0.3);
                    g.add (new PathData.rect (0, 0, w, h));
                    var header = new PathData.rect (0, 0, hw, h);
                    g.add (header, PartMode.FILL_SHADE);
                    g.add (line (hw, 0, hw, h), PartMode.STROKE);
                    g.text_rect = Rect (0, 0, hw, h);
                    break;
                case "pool-v":
                case "swimlane-v":
                    double hh = double.min (30, h * 0.3);
                    g.add (new PathData.rect (0, 0, w, h));
                    g.add (new PathData.rect (0, 0, w, hh), PartMode.FILL_SHADE);
                    g.add (line (0, hh, w, hh), PartMode.STROKE);
                    g.text_rect = Rect (pad, 0, w - 2 * pad, hh);
                    break;
                case "cff-phase":
                    double phh = double.min (26, h * 0.3);
                    g.add (new PathData.rect (0, 0, w, phh), PartMode.FILL_SHADE);
                    g.add (line (w, phh, w, h), PartMode.STROKE);
                    g.text_rect = Rect (pad, 0, w - 2 * pad, phh);
                    break;
                case "cff-phase-h":
                    double phw = double.min (26, w * 0.3);
                    g.add (new PathData.rect (0, 0, phw, h), PartMode.FILL_SHADE);
                    g.add (line (phw, h, w, h), PartMode.STROKE);
                    g.text_rect = Rect (0, 0, phw, h);
                    break;
                case "group-box":
                    double gh = double.min (28, h * 0.3);
                    g.add (new PathData.rect (0, 0, w, h));
                    g.add (new PathData.rect (0, 0, w, gh), PartMode.FILL_SHADE);
                    g.add (line (0, gh, w, gh), PartMode.STROKE);
                    g.text_rect = Rect (pad * 2, 0, w - 4 * pad, gh);
                    break;
                case "bpmn-group":
                    g.add (new PathData.round_rect (0, 0, w, h, r > 0 ? r : 10));
                    g.text_rect = Rect (pad * 2, pad, w - 4 * pad, 22);
                    break;
                case "uml-class":
                case "uml-interface":
                    g.add (new PathData.rect (0, 0, w, h));
                    g.text_rect = Rect (0, 0, w, h);
                    break;
                case "uml-object":
                    g.add (new PathData.rect (0, 0, w, h));
                    break;
                case "uml-actor":
                    double hr = double.min (w * 0.3, h * 0.13);
                    g.add (new PathData.ellipse (w / 2, hr + 1, hr, hr));
                    var stick = new PathData ();
                    stick.move_to (w / 2, 2 * hr + 1);
                    stick.line_to (w / 2, h * 0.64);
                    stick.move_to (0, h * 0.36);
                    stick.line_to (w, h * 0.36);
                    stick.move_to (0, h);
                    stick.line_to (w / 2, h * 0.64);
                    stick.line_to (w, h);
                    g.add (stick, PartMode.STROKE);
                    g.text_rect = Rect (-40, h + 4, w + 80, 20);
                    break;
                case "uml-package":
                    double tabw = double.min (w * 0.4, 70), tabh = double.min (h * 0.2, 20);
                    var tab = new PathData.rect (0, 0, tabw, tabh);
                    g.add (new PathData.rect (0, tabh, w, h - tabh));
                    g.add (tab, PartMode.FILL_SHADE);
                    g.text_rect = Rect (pad, tabh + pad, w - 2 * pad, 22);
                    break;
                case "uml-component":
                    g.add (new PathData.rect (0, 0, w, h));
                    double bx = w - 26, by = 8;
                    var icon = new PathData.rect (bx, by, 16, 20);
                    g.add (icon, PartMode.STROKE);
                    g.add (new PathData.rect (bx - 4, by + 4, 8, 4), PartMode.FILL_STROKE);
                    g.add (new PathData.rect (bx - 4, by + 12, 8, 4), PartMode.FILL_STROKE);
                    g.text_rect = Rect (pad, pad, w - 34, h - 2 * pad);
                    break;
                case "uml-initial":
                    g.add (new PathData.ellipse (w / 2, h / 2, w / 2, h / 2), PartMode.FILL_DARK);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "uml-final":
                    var ring = new PathData.ellipse (w / 2, h / 2, w / 2, h / 2);
                    g.add (ring);
                    g.add (new PathData.ellipse (w / 2, h / 2, w * 0.3, h * 0.3), PartMode.FILL_DARK);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "uml-fork":
                    g.add (new PathData.rect (0, 0, w, h), PartMode.FILL_DARK);
                    g.text_rect = Rect (0, -24, w, 20);
                    break;
                case "uml-lifeline":
                    double lh = double.min (40, h * 0.3);
                    g.add (new PathData.rect (0, 0, w, lh));
                    var dashline = new PathData ();
                    double yy = lh;
                    while (yy < h) {
                        dashline.move_to (w / 2, yy);
                        dashline.line_to (w / 2, double.min (yy + 6, h));
                        yy += 11;
                    }
                    g.add (dashline, PartMode.STROKE);
                    g.text_rect = Rect (pad, 0, w - 2 * pad, lh);
                    break;
                case "uml-activation":
                    g.add (new PathData.rect (0, 0, w, h));
                    break;
                case "bpmn-subprocess":
                    g.add (new PathData.round_rect (0, 0, w, h, r > 0 ? r : 10));
                    double ms = 12;
                    var mk = new PathData.rect (w / 2 - ms / 2, h - ms - 3, ms, ms);
                    g.add (mk, PartMode.STROKE);
                    g.add (line (w / 2 - ms / 2 + 3, h - ms / 2 - 3, w / 2 + ms / 2 - 3, h - ms / 2 - 3), PartMode.STROKE);
                    g.add (line (w / 2, h - ms, w / 2, h - 6), PartMode.STROKE);
                    g.text_rect = Rect (pad, pad, w - 2 * pad, h - ms - 2 * pad);
                    break;
                case "bpmn-start":
                case "bpmn-end":
                    g.add (new PathData.ellipse (w / 2, h / 2, w / 2, h / 2));
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "bpmn-intermediate":
                case "bpmn-timer":
                case "bpmn-message":
                    g.add (new PathData.ellipse (w / 2, h / 2, w / 2, h / 2));
                    g.add (new PathData.ellipse (w / 2, h / 2, w / 2 - 3, h / 2 - 3), PartMode.STROKE);
                    if (kind == "bpmn-timer") {
                        g.add (new PathData.ellipse (w / 2, h / 2, w * 0.3, h * 0.3), PartMode.STROKE);
                        var hands = new PathData ();
                        hands.move_to (w / 2, h * 0.28);
                        hands.line_to (w / 2, h / 2);
                        hands.line_to (w * 0.66, h * 0.58);
                        g.add (hands, PartMode.STROKE);
                    } else if (kind == "bpmn-message") {
                        var env = new PathData.rect (w * 0.28, h * 0.34, w * 0.44, h * 0.32);
                        g.add (env, PartMode.STROKE);
                        var flap = new PathData ();
                        flap.move_to (w * 0.28, h * 0.34);
                        flap.line_to (w / 2, h * 0.52);
                        flap.line_to (w * 0.72, h * 0.34);
                        g.add (flap, PartMode.STROKE);
                    }
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "bpmn-gateway":
                case "bpmn-gateway-parallel":
                case "bpmn-gateway-inclusive":
                case "bpmn-gateway-event":
                    g.add (poly (w, h, { 0.5, 0, 1, 0.5, 0.5, 1, 0, 0.5 }));
                    if (kind == "bpmn-gateway") {
                        var xm = new PathData ();
                        xm.move_to (w * 0.34, h * 0.34);
                        xm.line_to (w * 0.66, h * 0.66);
                        xm.move_to (w * 0.66, h * 0.34);
                        xm.line_to (w * 0.34, h * 0.66);
                        g.add (xm, PartMode.STROKE);
                    } else if (kind == "bpmn-gateway-parallel") {
                        var pm = new PathData ();
                        pm.move_to (w / 2, h * 0.28);
                        pm.line_to (w / 2, h * 0.72);
                        pm.move_to (w * 0.28, h / 2);
                        pm.line_to (w * 0.72, h / 2);
                        g.add (pm, PartMode.STROKE);
                    } else if (kind == "bpmn-gateway-inclusive") {
                        g.add (new PathData.ellipse (w / 2, h / 2, w * 0.2, h * 0.2), PartMode.STROKE);
                    } else {
                        g.add (new PathData.ellipse (w / 2, h / 2, w * 0.24, h * 0.24), PartMode.STROKE);
                        g.add (regular (w * 0.28, h * 0.28, 5, -Math.PI / 2).transformed (Cairo.Matrix (1, 0, 0, 1, w * 0.36, h * 0.36)), PartMode.STROKE);
                    }
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "bpmn-data-store":
                    double de = h * 0.14;
                    var ds = new PathData ();
                    ds.move_to (0, de);
                    ds.line_to (0, h - de);
                    ds.curve_to (0, h - de + de * 1.33, w, h - de + de * 1.33, w, h - de);
                    ds.line_to (w, de);
                    ds.curve_to (w, de - de * 1.33, 0, de - de * 1.33, 0, de);
                    ds.close ();
                    g.add (ds);
                    for (int i = 0; i < 3; i++) {
                        double yv = de + i * 5;
                        var b2 = new PathData ();
                        b2.move_to (0, yv);
                        b2.curve_to (0, yv + de * 1.33, w, yv + de * 1.33, w, yv);
                        g.add (b2, PartMode.STROKE);
                    }
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-server":
                    g.add (new PathData.round_rect (0, 0, w, h, 4));
                    for (int i = 1; i <= 3; i++) {
                        double sy = h * 0.18 * i;
                        g.add (line (w * 0.15, sy, w * 0.62, sy), PartMode.STROKE);
                        g.add (new PathData.ellipse (w * 0.8, sy, 2.2, 2.2), PartMode.FILL_DARK);
                    }
                    g.add (line (0, h * 0.72, w, h * 0.72), PartMode.STROKE);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-desktop":
                    g.add (new PathData.round_rect (0, 0, w, h * 0.72, 3));
                    g.add (new PathData.rect (w * 0.08, h * 0.08, w * 0.84, h * 0.56), PartMode.FILL_SHADE);
                    g.add (new PathData.rect (w * 0.44, h * 0.72, w * 0.12, h * 0.16));
                    g.add (new PathData.round_rect (w * 0.25, h * 0.88, w * 0.5, h * 0.12, 2));
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-laptop":
                    g.add (new PathData.round_rect (w * 0.1, 0, w * 0.8, h * 0.78, 3));
                    g.add (new PathData.rect (w * 0.16, h * 0.08, w * 0.68, h * 0.62), PartMode.FILL_SHADE);
                    g.add (poly (w, h, { 0.04, 0.8, 0.96, 0.8, 1, 1, 0, 1 }));
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-phone":
                    g.add (new PathData.round_rect (0, 0, w, h, double.min (w, h) * 0.18));
                    g.add (new PathData.rect (w * 0.12, h * 0.12, w * 0.76, h * 0.7), PartMode.FILL_SHADE);
                    g.add (new PathData.ellipse (w / 2, h * 0.91, 2.5, 2.5), PartMode.FILL_DARK);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-router":
                    double re = h * 0.22;
                    var rb = new PathData ();
                    rb.move_to (0, re);
                    rb.line_to (0, h - re);
                    rb.curve_to (0, h - re + re * 1.33, w, h - re + re * 1.33, w, h - re);
                    rb.line_to (w, re);
                    rb.curve_to (w, re - re * 1.33, 0, re - re * 1.33, 0, re);
                    rb.close ();
                    g.add (rb);
                    var rt = new PathData.ellipse (w / 2, re, w / 2, re);
                    g.add (rt, PartMode.FILL_SHADE);
                    var ar = new PathData ();
                    ar.move_to (w * 0.3, re - re * 0.4);
                    ar.line_to (w * 0.7, re + re * 0.4);
                    ar.move_to (w * 0.7, re - re * 0.4);
                    ar.line_to (w * 0.3, re + re * 0.4);
                    g.add (ar, PartMode.STROKE);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-switch":
                    g.add (new PathData.round_rect (0, 0, w, h, 4));
                    var sa = new PathData ();
                    sa.move_to (w * 0.2, h * 0.35);
                    sa.line_to (w * 0.8, h * 0.35);
                    sa.move_to (w * 0.72, h * 0.22);
                    sa.line_to (w * 0.8, h * 0.35);
                    sa.line_to (w * 0.72, h * 0.48);
                    sa.move_to (w * 0.8, h * 0.65);
                    sa.line_to (w * 0.2, h * 0.65);
                    sa.move_to (w * 0.28, h * 0.52);
                    sa.line_to (w * 0.2, h * 0.65);
                    sa.line_to (w * 0.28, h * 0.78);
                    g.add (sa, PartMode.STROKE);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-firewall":
                    g.add (new PathData.rect (0, 0, w, h));
                    var bricks = new PathData ();
                    int rows_n = 4;
                    for (int i = 1; i < rows_n; i++) {
                        bricks.move_to (0, h * i / rows_n);
                        bricks.line_to (w, h * i / rows_n);
                    }
                    for (int i = 0; i < rows_n; i++) {
                        double y0 = h * i / rows_n, y1 = h * (i + 1) / rows_n;
                        for (int j = 1; j < 3; j++) {
                            double xx = w * (j / 3.0 + (i % 2 == 0 ? 0 : -1 / 6.0));
                            bricks.move_to (xx, y0);
                            bricks.line_to (xx, y1);
                        }
                    }
                    g.add (bricks, PartMode.STROKE);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-wireless":
                    g.add (new PathData.round_rect (w * 0.2, h * 0.62, w * 0.6, h * 0.38, 3));
                    var waves = new PathData ();
                    for (int i = 1; i <= 3; i++) {
                        double wr = w * 0.12 * i;
                        waves.arc_to (w / 2, h * 0.55, wr, wr * 0.9, -Math.PI * 0.8, -Math.PI * 0.2, false);
                    }
                    g.add (waves, PartMode.STROKE);
                    g.add (new PathData.ellipse (w / 2, h * 0.55, 2.5, 2.5), PartMode.FILL_DARK);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-storage":
                    for (int i = 2; i >= 0; i--) {
                        double sy0 = h * i / 3.0;
                        double se = h * 0.1;
                        var disk = new PathData ();
                        disk.move_to (0, sy0 + se);
                        disk.line_to (0, sy0 + h / 3.0 - se * 0.2);
                        disk.curve_to (0, sy0 + h / 3.0 + se, w, sy0 + h / 3.0 + se, w, sy0 + h / 3.0 - se * 0.2);
                        disk.line_to (w, sy0 + se);
                        disk.curve_to (w, sy0 + se - se * 1.33, 0, sy0 + se - se * 1.33, 0, sy0 + se);
                        disk.close ();
                        g.add (disk);
                    }
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-printer":
                    g.add (new PathData.rect (w * 0.22, 0, w * 0.56, h * 0.4), PartMode.FILL_ONLY);
                    g.add (new PathData.rect (w * 0.22, 0, w * 0.56, h * 0.4), PartMode.STROKE);
                    g.add (new PathData.round_rect (0, h * 0.3, w, h * 0.46, 4));
                    g.add (new PathData.rect (w * 0.22, h * 0.62, w * 0.56, h * 0.38));
                    g.add (line (w * 0.3, h * 0.78, w * 0.7, h * 0.78), PartMode.STROKE);
                    g.add (line (w * 0.3, h * 0.88, w * 0.62, h * 0.88), PartMode.STROKE);
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "net-user":
                case "org-avatar":
                    g.add (new PathData.ellipse (w / 2, h * 0.26, w * 0.24, h * 0.24));
                    g.add (unit ("M0 1 C0 0.68 0.2 0.54 0.5 0.54 C0.8 0.54 1 0.68 1 1 Z", w, h));
                    g.text_rect = Rect (-30, h + 4, w + 60, 20);
                    break;
                case "org-person":
                case "org-manager":
                case "org-assistant":
                case "org-team":
                    double orr = r > 0 ? r : 8;
                    g.add (new PathData.round_rect (0, 0, w, h, orr));
                    if (kind == "org-manager") {
                        var band_m = new PathData ();
                        band_m.move_to (orr, 0);
                        band_m.line_to (w - orr, 0);
                        band_m.curve_to (w - orr * 0.45, 0, w, orr * 0.45, w, orr);
                        band_m.line_to (w, 6);
                        band_m.line_to (0, 6);
                        band_m.line_to (0, orr);
                        band_m.curve_to (0, orr * 0.45, orr * 0.45, 0, orr, 0);
                        band_m.close ();
                        g.add (band_m, PartMode.FILL_DARK);
                    }
                    if (kind == "org-assistant") {
                        g.add (line (0, h - 4, w, h - 4), PartMode.STROKE);
                    }
                    double av = double.min (h - 16, 40);
                    if (kind == "org-team") {
                        g.add (new PathData.ellipse (12 + av * 0.35, h / 2 - av * 0.1, av * 0.2, av * 0.2), PartMode.FILL_SHADE);
                        g.add (new PathData.ellipse (12 + av * 0.75, h / 2 - av * 0.1, av * 0.2, av * 0.2), PartMode.FILL_SHADE);
                        g.add (unit ("M0 1 C0 0.6 0.25 0.5 0.5 0.5 C0.75 0.5 1 0.6 1 1 Z", av * 1.1, av * 0.45).transformed (Cairo.Matrix (1, 0, 0, 1, 12 - av * 0.0, h / 2 + av * 0.05)), PartMode.FILL_SHADE);
                    } else {
                        g.add (new PathData.ellipse (12 + av / 2, h / 2, av / 2, av / 2), PartMode.FILL_SHADE);
                        g.add (new PathData.ellipse (12 + av / 2, h / 2 - av * 0.12, av * 0.17, av * 0.17), PartMode.FILL_ONLY);
                        g.add (unit ("M0.22 0.86 C0.28 0.66 0.38 0.6 0.5 0.6 C0.62 0.6 0.72 0.66 0.78 0.86 C0.7 0.94 0.6 0.98 0.5 0.98 C0.4 0.98 0.3 0.94 0.22 0.86 Z", av, av).transformed (Cairo.Matrix (1, 0, 0, 1, 12, h / 2 - av / 2)), PartMode.FILL_ONLY);
                    }
                    double tx = 12 + av * (kind == "org-team" ? 1.2 : 1) + 10;
                    g.text_rect = Rect (tx, 4, double.max (w - tx - 6, 10), h - 8);
                    break;
                default:
                    g.add (new PathData.round_rect (0, 0, w, h, r));
                    break;
            }
            return g;
        }
    }
}
