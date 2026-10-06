namespace Singularity.Apps.Draw {

    public class Drawio {

        private class Cell {
            public string id = "";
            public string parent = "";
            public string value = "";
            public Gee.HashMap<string, string> style = new Gee.HashMap<string, string> ();
            public Gee.HashSet<string> flags = new Gee.HashSet<string> ();
            public string base_name = "";
            public bool vertex = false;
            public bool edge = false;
            public bool visible = true;
            public bool connectable = true;
            public string source = "";
            public string target = "";
            public double x = 0;
            public double y = 0;
            public double w = 0;
            public double h = 0;
            public bool has_x = false;
            public bool relative = false;
            public Point[] points = {};
            public bool has_sp = false;
            public Point sp;
            public bool has_tp = false;
            public Point tp;
            public Gee.ArrayList<DataField> fields = new Gee.ArrayList<DataField> ();
            public string link = "";
            public bool consumed = false;
            public Gee.ArrayList<Cell> children = new Gee.ArrayList<Cell> ();

            public string? get (string key) {
                return style.has_key (key) ? style[key] : null;
            }

            public double num (string key, double fallback) {
                string? v = get (key);
                if (v == null || v.strip () == "") return fallback;
                return double.parse (v);
            }

            public bool on (string key) {
                string? v = get (key);
                return v != null && v != "0" && v != "false";
            }

            public string shape_name () {
                string? s = get ("shape");
                return s != null ? s : base_name;
            }
        }

        private class StyleOut {
            private StringBuilder sb = new StringBuilder ();
            private Gee.HashSet<string> keys = new Gee.HashSet<string> ();

            public void raw (string fragment) {
                foreach (string part in fragment.split (";")) {
                    if (part == "") continue;
                    int eq = part.index_of ("=");
                    if (eq < 0) {
                        sb.append (part);
                        sb.append_c (';');
                    } else {
                        add (part.substring (0, eq), part.substring (eq + 1));
                    }
                }
            }

            public void add (string key, string value) {
                if (keys.contains (key)) return;
                keys.add (key);
                sb.append (key);
                sb.append_c ('=');
                sb.append (value);
                sb.append_c (';');
            }

            public string str () {
                return sb.str;
            }
        }

        public static Document load (string text) throws Error {
            Xml.Doc* xdoc = XmlUtil.parse (text);
            var root = xdoc->get_root_element ();
            var doc = new Document ();
            doc.pages.clear ();
            try {
                if (root->name == "mxGraphModel") {
                    load_model (doc, root, _("Page 1"), "");
                } else if (root->name == "mxfile") {
                    int n = 0;
                    foreach (var dn in XmlUtil.children (root, "diagram")) {
                        n++;
                        string name = XmlUtil.attr_or (dn, "name", _("Page %d").printf (n));
                        string id = XmlUtil.attr_or (dn, "id", "");
                        var model = XmlUtil.child (dn, "mxGraphModel");
                        if (model != null) {
                            load_model (doc, model, name, id);
                            continue;
                        }
                        string content = XmlUtil.text (dn).strip ();
                        if (content == "") continue;
                        string xml = inflate (content);
                        Xml.Doc* inner = XmlUtil.parse (xml);
                        var ir = inner->get_root_element ();
                        if (ir->name == "mxGraphModel") load_model (doc, ir, name, id);
                        delete inner;
                    }
                } else {
                    throw new FormatError.INVALID (_("This is not a draw.io diagram."));
                }
            } finally {
                delete xdoc;
            }
            if (doc.pages.size == 0) throw new FormatError.INVALID (_("The diagram has no pages."));
            doc.page_index = 0;
            doc.sync_ids ();
            return doc;
        }

        public static string inflate (string b64) throws Error {
            uint8[] raw = Base64.decode (b64.strip ());
            if (raw.length == 0) throw new FormatError.INVALID (_("The diagram data is empty."));
            var conv = new ZlibDecompressor (ZlibCompressorFormat.RAW);
            var input = new MemoryInputStream.from_data (raw);
            var stream = new ConverterInputStream (input, conv);
            var buf = new ByteArray ();
            uint8[] chunk = new uint8[65536];
            ssize_t n;
            while ((n = stream.read (chunk)) > 0) buf.append (chunk[0:n]);
            string s = Formats.as_text (buf.data);
            if (s.strip ().has_prefix ("<")) return s;
            string? u = Uri.unescape_string (s);
            return u ?? s;
        }

        public static string deflate (string xml) throws Error {
            string escaped = Uri.escape_string (xml, "!*'()", false);
            var conv = new ZlibCompressor (ZlibCompressorFormat.RAW, 9);
            var mem = new MemoryOutputStream.resizable ();
            var stream = new ConverterOutputStream (mem, conv);
            size_t written;
            stream.write_all (escaped.data, out written);
            stream.close ();
            uint8[] payload = mem.steal_data ();
            payload.length = (int) mem.get_data_size ();
            return Base64.encode (payload);
        }

        private static void parse_style (Cell c, string s) {
            string last_key = "";
            foreach (string raw in s.split (";")) {
                string p = raw.strip ();
                if (p == "") continue;
                int eq = p.index_of ("=");
                if (eq < 0) {
                    if (last_key == "image" && p.has_prefix ("base64,")) {
                        c.style["image"] = c.style["image"] + ";" + p;
                        continue;
                    }
                    if (c.base_name == "") c.base_name = p;
                    c.flags.add (p);
                    continue;
                }
                last_key = p.substring (0, eq).strip ();
                c.style[last_key] = p.substring (eq + 1).strip ();
            }
        }

        private static Cell read_cell (Xml.Node* n, Xml.Node* wrapper) {
            var c = new Cell ();
            if (wrapper != null) {
                c.id = XmlUtil.attr_or (wrapper, "id", "");
                c.value = XmlUtil.attr_or (wrapper, "label", "");
                for (Xml.Attr* a = wrapper->properties; a != null; a = a->next) {
                    string key = a->name;
                    string val = a->children != null ? a->children->get_content () : "";
                    switch (key) {
                        case "id":
                        case "label":
                        case "placeholders":
                        case "tooltip":
                            break;
                        case "link":
                            c.link = val;
                            break;
                        default:
                            c.fields.add (new DataField (key, val));
                            break;
                    }
                }
            } else {
                c.id = XmlUtil.attr_or (n, "id", "");
                c.value = XmlUtil.attr_or (n, "value", "");
            }
            c.parent = XmlUtil.attr_or (n, "parent", "");
            parse_style (c, XmlUtil.attr_or (n, "style", ""));
            c.vertex = XmlUtil.attr_or (n, "vertex", "0") == "1";
            c.edge = XmlUtil.attr_or (n, "edge", "0") == "1";
            c.visible = XmlUtil.attr_or (n, "visible", "1") != "0";
            c.connectable = XmlUtil.attr_or (n, "connectable", "1") != "0";
            c.source = XmlUtil.attr_or (n, "source", "");
            c.target = XmlUtil.attr_or (n, "target", "");
            var g = XmlUtil.child (n, "mxGeometry");
            if (g != null) {
                c.has_x = XmlUtil.attr (g, "x") != null;
                c.x = XmlUtil.attr_double (g, "x", 0);
                c.y = XmlUtil.attr_double (g, "y", 0);
                c.w = XmlUtil.attr_double (g, "width", 0);
                c.h = XmlUtil.attr_double (g, "height", 0);
                c.relative = XmlUtil.attr_or (g, "relative", "0") == "1";
                foreach (var pn in XmlUtil.children (g, "mxPoint")) {
                    var p = Point (XmlUtil.attr_double (pn, "x", 0), XmlUtil.attr_double (pn, "y", 0));
                    string role = XmlUtil.attr_or (pn, "as", "");
                    if (role == "sourcePoint") {
                        c.has_sp = true;
                        c.sp = p;
                    } else if (role == "targetPoint") {
                        c.has_tp = true;
                        c.tp = p;
                    }
                }
                foreach (var an in XmlUtil.children (g, "Array")) {
                    if (XmlUtil.attr_or (an, "as", "") != "points") continue;
                    Point[] pts = {};
                    foreach (var pn in XmlUtil.children (an, "mxPoint")) pts += Point (XmlUtil.attr_double (pn, "x", 0), XmlUtil.attr_double (pn, "y", 0));
                    c.points = pts;
                }
            }
            return c;
        }

        private static void load_model (Document doc, Xml.Node* model, string name, string id) {
            var page = new Page (name);
            page.id = id;
            bool used = id == "";
            foreach (var p in doc.pages) if (p.id == id) used = true;
            if (used) page.id = doc.new_page_id ();
            page.width = XmlUtil.attr_double (model, "pageWidth", 850);
            page.height = XmlUtil.attr_double (model, "pageHeight", 1100);
            string? bg = XmlUtil.attr (model, "background");
            if (bg != null && bg != "none" && bg != "") page.background = color (bg, "#ffffff");
            doc.grid_size = XmlUtil.attr_double (model, "gridSize", doc.grid_size);
            var rootn = XmlUtil.child (model, "root");
            var cells = new Gee.ArrayList<Cell> ();
            var map = new Gee.HashMap<string, Cell> ();
            if (rootn != null) {
                foreach (var n in XmlUtil.children (rootn)) {
                    Cell c;
                    if (n->name == "mxCell") {
                        c = read_cell (n, null);
                    } else if (n->name == "object" || n->name == "UserObject") {
                        var inner = XmlUtil.child (n, "mxCell");
                        if (inner == null) continue;
                        c = read_cell (inner, n);
                    } else {
                        continue;
                    }
                    if (c.id == "" || map.has_key (c.id)) continue;
                    cells.add (c);
                    map[c.id] = c;
                }
            }
            foreach (var c in cells) {
                if (c.parent != "" && map.has_key (c.parent)) map[c.parent].children.add (c);
            }
            var layers = new Gee.ArrayList<Cell> ();
            foreach (var c in cells) {
                if (c.parent == "" || !map.has_key (c.parent)) {
                    foreach (var l in c.children) if (!l.vertex && !l.edge) layers.add (l);
                }
            }
            if (layers.size > 0) {
                page.layers.clear ();
                int ln = 0;
                foreach (var l in layers) {
                    ln++;
                    var layer = new Layer (l.id, l.value != "" ? l.value : _("Layer %d").printf (ln));
                    layer.visible = l.visible;
                    layer.locked = l.on ("locked");
                    page.layers.add (layer);
                }
                page.active_layer = page.layers[0].id;
            }
            var items = new Gee.HashMap<string, Item> ();
            foreach (var l in layers) {
                foreach (var c in l.children) handle (page, c, page.items, 0, 0, l.id, "", map, items);
            }
            foreach (var c in cells) {
                if (c.parent == "" || !map.has_key (c.parent)) {
                    foreach (var ch in c.children) {
                        if (ch.vertex || ch.edge) handle (page, ch, page.items, 0, 0, page.layers[0].id, "", map, items);
                    }
                }
            }
            foreach (var con in page.connectors ()) {
                foreach (var e in new Endpoint[] { con.src, con.dst }) {
                    if (e.item_id == "") continue;
                    var target = page.find (e.item_id);
                    if (target == null || target is Connector) {
                        e.item_id = "";
                        e.port = -1;
                    }
                }
            }
            if (doc.pages.size > 0) {
                var taken = new Gee.HashSet<string> ();
                foreach (var p in doc.pages) foreach (var it in p.all_items ()) taken.add (it.id);
                var remap = new Gee.HashMap<string, string> ();
                bool clash = false;
                var all = page.all_items ();
                foreach (var it in all) {
                    string nid = it.id;
                    if (taken.contains (nid)) {
                        clash = true;
                        int k = doc.pages.size + 1;
                        do {
                            nid = "p%d_%s".printf (k++, it.id);
                        } while (taken.contains (nid));
                    }
                    taken.add (nid);
                    remap[it.id] = nid;
                }
                if (clash) Document.remap_ids (all, remap);
            }
            doc.pages.add (page);
        }

        private static void handle (Page page, Cell c, Gee.List<Item> into, double ox, double oy, string layer, string container,
                                    Gee.HashMap<string, Cell> map, Gee.HashMap<string, Item> items) {
            if (c.consumed) return;
            c.consumed = true;
            if (c.edge) {
                var con = make_connector (c, ox, oy, map);
                con.layer_id = layer;
                into.add (con);
                items[con.id] = con;
                return;
            }
            if (!c.vertex) {
                foreach (var ch in c.children) handle (page, ch, into, ox, oy, layer, container, map, items);
                return;
            }
            string kind = resolve_kind (c);
            if (kind == "group") {
                var g = new Group ();
                g.id = c.id;
                g.layer_id = layer;
                g.text = html_value (c);
                copy_fields (c, g);
                into.add (g);
                items[g.id] = g;
                foreach (var ch in c.children) handle (page, ch, g.children, ox + c.x, oy + c.y, layer, container, map, items);
                return;
            }
            Shape s;
            if (kind == "table") {
                s = make_table (c, ox, oy);
            } else if ((kind == "uml-class" || kind == "uml-interface" || c.get ("childLayout") == "stackLayout") && c.children.size > 0 && kind != "pool") {
                s = make_shape (c, kind == "uml-interface" ? kind : "uml-class", ox, oy);
                var sb = new StringBuilder (html_value (c));
                foreach (var ch in c.children) {
                    ch.consumed = true;
                    if (!ch.vertex) continue;
                    string sn = ch.shape_name ();
                    if (sn == "line") continue;
                    sb.append ("\n--\n");
                    sb.append (html_value (ch));
                }
                s.text = sb.str;
                if (c.get ("sdrawKind") == null) {
                    s.style.halign = TextHAlign.LEFT;
                    s.style.valign = TextVAlign.TOP;
                }
            } else {
                s = make_shape (c, kind, ox, oy);
            }
            s.layer_id = layer;
            if (container != "") s.container_id = container;
            string? sc = c.get ("sdrawContainer");
            if (sc != null) s.container_id = sc;
            into.add (s);
            items[s.id] = s;
            bool holds = s.is_container () || c.on ("container") || c.flags.contains ("swimlane");
            string child_container = holds ? s.id : container;
            foreach (var ch in c.children) handle (page, ch, into, ox + c.x, oy + c.y, layer, child_container, map, items);
        }

        private static void copy_fields (Cell c, Item it) {
            foreach (var f in c.fields) it.fields.add (new DataField (f.key, f.value));
            it.link = c.link;
        }

        public static string strip_html (string s) {
            if (!s.contains ("<") && !s.contains ("&")) return s;
            string t = s;
            try {
                t = new Regex ("<br\\s*/?>", RegexCompileFlags.CASELESS).replace (t, -1, 0, "\n");
                t = new Regex ("<(div|p|li|h[1-6])(\\s[^>]*)?>", RegexCompileFlags.CASELESS).replace (t, -1, 0, "\n");
                t = new Regex ("<[^>]*>").replace (t, -1, 0, "");
            } catch (RegexError e) {
            }
            t = decode_entities (t);
            while (t.has_prefix ("\n")) t = t.substring (1);
            while (t.has_suffix ("\n")) t = t.substring (0, t.length - 1);
            return t;
        }

        public static string decode_entities (string s) {
            if (!s.contains ("&")) return s;
            var sb = new StringBuilder ();
            int i = 0;
            while (i < s.length) {
                if (s[i] == '&') {
                    int semi = s.index_of (";", i);
                    if (semi > i && semi - i < 12) {
                        string ent = s.substring (i + 1, semi - i - 1);
                        string? rep = null;
                        switch (ent) {
                            case "amp": rep = "&"; break;
                            case "lt": rep = "<"; break;
                            case "gt": rep = ">"; break;
                            case "quot": rep = "\""; break;
                            case "apos": rep = "'"; break;
                            case "nbsp": rep = " "; break;
                            default:
                                if (ent.has_prefix ("#x") || ent.has_prefix ("#X")) {
                                    unichar u = (unichar) long.parse ("0x" + ent.substring (2), 16);
                                    if (u > 0) rep = u.to_string ();
                                } else if (ent.has_prefix ("#")) {
                                    unichar u = (unichar) int.parse (ent.substring (1));
                                    if (u > 0) rep = u.to_string ();
                                }
                                break;
                        }
                        if (rep != null) {
                            sb.append (rep);
                            i = semi + 1;
                            continue;
                        }
                    }
                }
                sb.append_c (s[i]);
                i++;
            }
            return sb.str;
        }

        private static string html_value (Cell c) {
            if (c.on ("html")) return strip_html (c.value);
            return c.value;
        }

        public static string color (string? v, string fallback) {
            if (v == null) return fallback;
            string t = v.strip ();
            if (t.has_prefix ("light-dark(")) {
                int comma = t.index_of (",");
                t = comma > 0 ? t.substring (11, comma - 11).strip () : t;
            }
            if (t == "none" || t == "") return "none";
            if (t == "default" || t == "inherit") return fallback;
            Rgba c;
            if (!Colors.parse (t, out c)) return fallback;
            return Colors.to_hex (c, true);
        }

        private static string with_opacity (string col, double pct) {
            if (pct >= 100) return col;
            Rgba c;
            if (!Colors.parse (col, out c)) return col;
            c.a *= (pct / 100.0).clamp (0, 1);
            return Colors.to_hex (c, true);
        }

        private static string resolve_kind (Cell c) {
            string? sk = c.get ("sdrawKind");
            if (sk != null && sk != "") return sk;
            if (c.flags.contains ("group")) return "group";
            string shape = c.shape_name ();
            if (shape.has_prefix ("mxgraph.flowchart.")) {
                switch (shape.substring (18)) {
                    case "decision": return "decision";
                    case "terminator": return "terminator";
                    case "start_1": case "start_2": return "ellipse";
                    case "data": return "data";
                    case "document": return "document";
                    case "multi-document": return "multi-document";
                    case "manual_input": return "manual-input";
                    case "manual_operation": return "manual-operation";
                    case "predefined_process": return "predefined-process";
                    case "preparation": return "preparation";
                    case "delay": return "delay";
                    case "display": return "display";
                    case "database": return "database";
                    case "stored_data": return "stored-data";
                    case "internal_storage": return "internal-storage";
                    case "punched_tape": case "paper_tape": return "punched-tape";
                    case "off-page_reference": return "off-page";
                    case "on-page_reference": return "on-page";
                    case "summing_function": return "summing-junction";
                    case "or": return "or";
                    case "collate": return "collate";
                    case "sort": return "sort";
                    case "merge_or_storage": return "merge";
                    case "extract_or_measurement": return "extract";
                    case "loop_limit": return "loop-limit";
                    case "annotation_1": case "annotation_2": return "annotation";
                    case "direct_data": return "direct-access";
                    case "card": return "card";
                    case "process": return "process";
                    default: return "rectangle";
                }
            }
            if (shape.has_prefix ("mxgraph.bpmn.")) {
                string sym = c.get ("symbol") ?? "";
                string outline = c.get ("outline") ?? "";
                string bgv = c.get ("background") ?? "";
                if (shape.has_prefix ("mxgraph.bpmn.gateway") || bgv == "gateway" || sym.has_suffix ("Gw")) {
                    switch (c.get ("gwType") ?? "") {
                        case "parallel": return "bpmn-gateway-parallel";
                        case "inclusive": return "bpmn-gateway-inclusive";
                        case "eventBased": case "event": return "bpmn-gateway-event";
                        default: break;
                    }
                    switch (sym) {
                        case "parallelGw": return "bpmn-gateway-parallel";
                        case "inclusiveGw": return "bpmn-gateway-inclusive";
                        case "eventGw": case "exclusiveEventGw": case "parallelEventGw": return "bpmn-gateway-event";
                        default: return "bpmn-gateway";
                    }
                }
                if (shape == "mxgraph.bpmn.data" || shape == "mxgraph.bpmn.data2") return "bpmn-data-object";
                if (shape == "mxgraph.bpmn.task" || shape == "mxgraph.bpmn.task2") return "bpmn-task";
                if (shape == "mxgraph.bpmn.shape" || shape.has_prefix ("mxgraph.bpmn.event")) {
                    if (sym == "timer") return "bpmn-timer";
                    if (sym == "message") return "bpmn-message";
                    if (outline == "end") return "bpmn-end";
                    if (outline == "standard" || outline == "eventNonint" || outline == "") return "bpmn-start";
                    return "bpmn-intermediate";
                }
                return "bpmn-task";
            }
            if (shape.has_prefix ("mxgraph.basic.")) {
                switch (shape.substring (14)) {
                    case "star": return "star";
                    case "4_point_star_2": return "star4";
                    case "heart": return "heart";
                    case "cross2": case "x": return "cross";
                    case "octagon2": return "octagon";
                    case "pentagon": return "pentagon";
                    case "donut": return "donut";
                    case "frame": case "rounded_frame": return "frame";
                    case "cloud_callout": case "rectCallout": case "roundRectCallout": return "callout";
                    case "cone": case "cone2": return "triangle";
                    default: return "rectangle";
                }
            }
            if (shape.has_prefix ("mxgraph.arrows2.")) {
                switch (shape.substring (16)) {
                    case "twoWayArrow": return "arrow-left-right";
                    case "quadArrow": return "arrow-quad";
                    case "uTurnArrow": return "arrow-uturn";
                    case "notchedSignalIn": return "arrow-notched";
                    default: return "arrow-right";
                }
            }
            if (shape.has_prefix ("mxgraph.networks.")) {
                switch (shape.substring (17)) {
                    case "server": case "web_server": case "mail_server": case "proxy_server": case "server_storage": return "net-server";
                    case "pc": case "desktop_pc": case "monitor": return "net-desktop";
                    case "laptop": return "net-laptop";
                    case "mobile": case "tablet": return "net-phone";
                    case "router": return "net-router";
                    case "switch": case "hub": return "net-switch";
                    case "firewall": return "net-firewall";
                    case "cloud": return "net-cloud";
                    case "printer": return "net-printer";
                    case "storage": case "nas_filer": return "net-storage";
                    case "wireless_hub": case "wireless_modem": case "radio_tower": return "net-wireless";
                    case "user_male": case "user_female": case "users": return "net-user";
                    case "database": return "net-database";
                    default: return "net-server";
                }
            }
            switch (shape) {
                case "ellipse":
                    return c.get ("aspect") == "fixed" && (c.w - c.h).abs () < 0.5 ? "circle" : "ellipse";
                case "doubleEllipse": return "ellipse";
                case "rhombus": return "diamond";
                case "triangle": return "triangle";
                case "hexagon": return "hexagon";
                case "cylinder": case "cylinder2": case "cylinder3": return "cylinder";
                case "cloud": return "cloud";
                case "process": return "predefined-process";
                case "document": return "document";
                case "parallelogram": return "parallelogram";
                case "trapezoid": return "trapezoid";
                case "step": return "chevron";
                case "card": return "card";
                case "note": case "note2": return "note";
                case "actor": return "net-user";
                case "umlActor": return "uml-actor";
                case "umlLifeline": return "uml-lifeline";
                case "folder": return "uml-package";
                case "component": return "uml-component";
                case "cube": return "cube";
                case "internalStorage": return "internal-storage";
                case "delay": return "delay";
                case "display": return "display";
                case "datastore": return "bpmn-data-store";
                case "tape": return "punched-tape";
                case "manualInput": return "manual-input";
                case "dataStorage": return "stored-data";
                case "offPageConnector": return "off-page";
                case "callout": return "callout";
                case "singleArrow": return "arrow-right";
                case "doubleArrow": return "arrow-left-right";
                case "cross": return "cross";
                case "star": return "star";
                case "orEllipse": return "or";
                case "sumEllipse": return "summing-junction";
                case "sortShape": return "sort";
                case "collate": return "collate";
                case "loopLimit": return "loop-limit";
                case "endState": return "uml-final";
                case "text": return "text";
                case "line": return "line-shape";
                case "image": return "image";
                case "table": return "table";
                case "pool": return "pool";
                case "swimlane":
                    if (c.get ("childLayout") == "stackLayout") return "uml-class";
                    return c.get ("horizontal") == "0" ? "swimlane-h" : "swimlane-v";
                default:
                    break;
            }
            if (c.on ("container")) return "container";
            if (c.on ("rounded")) return "rounded-rectangle";
            return "rectangle";
        }

        private static Shape make_shape (Cell c, string kind, double ox, double oy) {
            Shape s;
            if (kind == "image") {
                var img = new ImageShape ();
                string src = c.get ("image") ?? "";
                if (src.has_prefix ("data:")) {
                    int comma = src.index_of (",");
                    if (comma > 0) {
                        string head = src.substring (5, comma - 5);
                        string payload = src.substring (comma + 1);
                        string mime = head.split (";")[0];
                        if (mime != "") img.mime = mime;
                        if (head.contains ("base64") || !payload.has_prefix ("<")) {
                            img.bytes = Base64.decode (payload);
                        } else {
                            string? dec = Uri.unescape_string (payload);
                            img.bytes = (dec ?? payload).data;
                        }
                    }
                } else if (src != "") {
                    img.link = src;
                }
                s = img;
            } else if (kind == "path") {
                var ps = new PathShape ();
                ps.path = PathData.parse_svg (c.get ("sdrawPath") ?? "");
                ps.natural_w = c.num ("sdrawNW", c.w);
                ps.natural_h = c.num ("sdrawNH", c.h);
                s = ps;
            } else {
                s = new Shape (kind);
            }
            s.id = c.id;
            s.x = ox + c.x;
            s.y = oy + c.y;
            s.w = c.w;
            s.h = c.h;
            s.text = html_value (c);
            copy_fields (c, s);
            apply_vertex_style (s, c);
            string dir = c.get ("direction") ?? "";
            if (c.get ("sdrawKind") == null) {
                double extra = 0;
                if (kind == "triangle") {
                    string d = dir != "" ? dir : "east";
                    if (c.shape_name () == "mxgraph.basic.cone" || c.shape_name () == "mxgraph.basic.cone2") d = dir != "" ? dir : "north";
                    extra = d == "east" ? 90 : (d == "south" ? 180 : (d == "west" ? 270 : 0));
                } else if (kind == "arrow-right" && dir != "") {
                    s.kind = dir == "west" ? "arrow-left" : (dir == "north" ? "arrow-up" : (dir == "south" ? "arrow-down" : "arrow-right"));
                    if (s.kind == "arrow-up" || s.kind == "arrow-down") swap_box (s);
                } else if (kind == "arrow-left-right" && (dir == "north" || dir == "south")) {
                    s.kind = "arrow-up-down";
                    swap_box (s);
                } else if (dir == "south" || dir == "north" || dir == "west") {
                    extra = dir == "south" ? 90 : (dir == "west" ? 180 : 270);
                    if (kind == "chevron" || kind == "hexagon" || kind == "document" || kind == "delay" || kind == "display" || kind == "card") {
                    } else {
                        extra = 0;
                    }
                }
                if (extra != 0) {
                    if (extra == 90 || extra == 270) swap_box (s);
                    s.rotation = Document.normalize_angle (s.rotation + extra);
                }
            }
            return s;
        }

        private static void swap_box (Shape s) {
            double cx = s.cx (), cy = s.cy ();
            double w = s.w;
            s.w = s.h;
            s.h = w;
            s.x = cx - s.w / 2;
            s.y = cy - s.h / 2;
        }

        private static Shape make_table (Cell c, double ox, double oy) {
            var rows = new Gee.ArrayList<Cell> ();
            foreach (var ch in c.children) {
                ch.consumed = true;
                if (ch.vertex) rows.add (ch);
            }
            int ncols = 1;
            foreach (var r in rows) {
                int n = 0;
                foreach (var cc in r.children) if (cc.vertex) n++;
                ncols = int.max (ncols, n);
            }
            var t = new TableShape (int.max (rows.size, 1), ncols);
            t.id = c.id;
            t.x = ox + c.x;
            t.y = oy + c.y;
            t.w = c.w;
            t.h = c.h;
            copy_fields (c, t);
            apply_vertex_style (t, c);
            t.header_row = false;
            double total_h = 0;
            foreach (var r in rows) total_h += r.h;
            if (total_h <= 0) total_h = double.max (c.h, 1);
            for (int ri = 0; ri < rows.size; ri++) {
                var r = rows[ri];
                t.row_fracs[ri] = r.h > 0 ? r.h / total_h : 1.0 / rows.size;
                int ci = 0;
                double total_w = 0;
                foreach (var cc in r.children) if (cc.vertex) total_w += cc.w;
                foreach (var cc in r.children) {
                    cc.consumed = true;
                    if (!cc.vertex || ci >= ncols) continue;
                    t.set_cell (ri, ci, html_value (cc));
                    if (ri == 0 && total_w > 0) t.col_fracs[ci] = cc.w / total_w;
                    if (ri == 0) {
                        string fc = color (cc.get ("fillColor"), "none");
                        if (fc != "none") {
                            t.header_row = true;
                            t.header_fill = fc;
                        }
                    }
                    ci++;
                }
            }
            if (c.get ("sdrawHeader") != null) t.header_row = c.get ("sdrawHeader") == "1";
            if (c.get ("sdrawHeaderFill") != null) t.header_fill = color (c.get ("sdrawHeaderFill"), t.header_fill);
            return t;
        }

        private static DashKind dash_from (Cell c) {
            if (!c.on ("dashed")) return DashKind.SOLID;
            string? sd = c.get ("sdrawDash");
            if (sd != null) return DashKind.from_id (sd);
            string? pat = c.get ("dashPattern");
            if (pat == null) return DashKind.DASH;
            double[] v = {};
            foreach (string part in pat.split (" ")) if (part.strip () != "") v += double.parse (part);
            if (v.length == 0) return DashKind.DASH;
            if (v.length >= 6) return DashKind.DASH_DOT_DOT;
            if (v.length >= 4) return DashKind.DASH_DOT;
            if (v[0] <= 1.5) return DashKind.DOT;
            if (v[0] >= 8) return DashKind.LONG_DASH;
            return DashKind.DASH;
        }

        private static void apply_text_style (Style st, Cell c) {
            st.text_color = color (c.get ("fontColor"), "#000000");
            if (st.text_color == "none") st.text_color = "#000000";
            st.font_size = c.num ("fontSize", 11) * 0.75;
            st.font_family = c.get ("fontFamily") ?? "Helvetica";
            int fs = (int) c.num ("fontStyle", 0);
            st.bold = (fs & 1) != 0;
            st.italic = (fs & 2) != 0;
            st.underline = (fs & 4) != 0;
            st.strike = (fs & 8) != 0;
            st.halign = TextHAlign.from_id (c.get ("align") ?? "center");
            st.valign = TextVAlign.from_id (c.get ("verticalAlign") ?? "middle");
            st.wrap = c.get ("whiteSpace") == "wrap";
            st.opacity = c.num ("opacity", 100) / 100.0;
            st.shadow = c.on ("shadow");
            string? ts = c.get ("sdrawTextOpacity");
            if (ts != null) st.opacity = double.parse (ts);
        }

        private static void apply_vertex_style (Shape s, Cell c) {
            var st = s.style;
            bool texty = s.kind == "text" || c.flags.contains ("text");
            string fill = color (c.get ("fillColor"), (texty || (s is ImageShape)) ? "none" : "#ffffff");
            if (fill == "none") {
                st.fill_kind = FillKind.NONE;
            } else {
                st.fill_kind = FillKind.SOLID;
                st.fill = with_opacity (fill, c.num ("fillOpacity", 100));
            }
            string grad = color (c.get ("gradientColor"), "none");
            if (grad != "none" && st.fill_kind != FillKind.NONE) {
                st.fill2 = with_opacity (grad, c.num ("fillOpacity", 100));
                string gd = c.get ("gradientDirection") ?? "south";
                if (gd == "radial") {
                    st.fill_kind = FillKind.RADIAL;
                } else {
                    st.fill_kind = FillKind.LINEAR;
                    st.gradient_angle = gd == "north" ? 270 : (gd == "east" ? 0 : (gd == "west" ? 180 : 90));
                }
                string? ga = c.get ("sdrawGradientAngle");
                if (ga != null) st.gradient_angle = double.parse (ga);
            }
            string stroke = color (c.get ("strokeColor"), (texty || (s is ImageShape)) ? "none" : "#000000");
            st.stroke = stroke == "none" ? "none" : with_opacity (stroke, c.num ("strokeOpacity", 100));
            st.stroke_width = c.num ("strokeWidth", 1);
            st.dash = dash_from (c);
            apply_text_style (st, c);
            s.rotation = Document.normalize_angle (c.num ("rotation", 0));
            s.flip_h = c.on ("flipH");
            s.flip_v = c.on ("flipV");
            string? sr = c.get ("sdrawRadius");
            if (sr != null) {
                st.corner_radius = double.parse (sr);
            } else if (c.on ("rounded")) {
                double arc = c.num ("arcSize", -1);
                if (c.on ("absoluteArcSize")) st.corner_radius = arc > 0 ? arc / 2 : 0;
                else if (arc > 0) st.corner_radius = double.min (s.w, s.h) * arc / 100.0;
            }
            if (s.kind == "line-shape") {
                st.arrow_start = arrow_from (c.get ("startArrow") ?? "none", c.get ("startFill") != "0");
                st.arrow_end = arrow_from (c.get ("endArrow") ?? "none", c.get ("endFill") != "0");
            }
            string? sa = c.get ("sdrawArrowStart");
            if (sa != null) st.arrow_start = ArrowKind.from_id (sa);
            string? ea = c.get ("sdrawArrowEnd");
            if (ea != null) st.arrow_end = ArrowKind.from_id (ea);
            string? sz = c.get ("sdrawArrowSize");
            if (sz != null) st.arrow_size = double.parse (sz);
        }

        private static ArrowKind arrow_from (string name, bool fill) {
            switch (name) {
                case "none": case "": return ArrowKind.NONE;
                case "classic": case "classicThin": return fill ? ArrowKind.STEALTH : ArrowKind.TRIANGLE_OPEN;
                case "block": case "blockThin": return fill ? ArrowKind.TRIANGLE : ArrowKind.TRIANGLE_OPEN;
                case "open": case "openThin": case "openAsync": return ArrowKind.OPEN;
                case "oval": return fill ? ArrowKind.CIRCLE : ArrowKind.CIRCLE_OPEN;
                case "diamond": case "diamondThin": return fill ? ArrowKind.DIAMOND : ArrowKind.DIAMOND_OPEN;
                case "dash": return ArrowKind.BAR;
                case "ERmany": case "ERzeroToMany": case "ERoneToMany": return ArrowKind.CROWS_FOOT;
                case "ERone": case "ERmandOne": case "ERzeroToOne": return ArrowKind.ONE;
                default: return fill ? ArrowKind.TRIANGLE : ArrowKind.TRIANGLE_OPEN;
            }
        }

        private static void arrow_to (ArrowKind k, out string name, out bool fill) {
            fill = true;
            switch (k) {
                case ArrowKind.TRIANGLE: name = "block"; break;
                case ArrowKind.TRIANGLE_OPEN: name = "block"; fill = false; break;
                case ArrowKind.STEALTH: name = "classic"; break;
                case ArrowKind.OPEN: name = "open"; break;
                case ArrowKind.DIAMOND: name = "diamond"; break;
                case ArrowKind.DIAMOND_OPEN: name = "diamond"; fill = false; break;
                case ArrowKind.CIRCLE: name = "oval"; break;
                case ArrowKind.CIRCLE_OPEN: name = "oval"; fill = false; break;
                case ArrowKind.BAR: name = "dash"; break;
                case ArrowKind.CROWS_FOOT: name = "ERmany"; break;
                case ArrowKind.ONE: name = "ERmandOne"; break;
                default: name = "none"; break;
            }
        }

        private static int nearest_port (Cell target, double px, double py) {
            string kind = resolve_kind (target);
            var ports = ShapeLibrary.ports (kind, target.w, target.h);
            int best = -1;
            double bd = double.INFINITY;
            for (int i = 0; i < ports.length; i++) {
                double d = Math.hypot (ports[i].x - px, ports[i].y - py);
                if (d < bd) {
                    bd = d;
                    best = i;
                }
            }
            return best;
        }

        private static Connector make_connector (Cell c, double ox, double oy, Gee.HashMap<string, Cell> map) {
            var con = new Connector ();
            con.id = c.id;
            var st = con.style;
            string es = c.get ("edgeStyle") ?? "";
            if (c.on ("curved")) con.route = RouteKind.CURVED;
            else if (es == "" || es == "none") con.route = RouteKind.STRAIGHT;
            else con.route = RouteKind.ORTHOGONAL;
            string? sr = c.get ("sdrawRoute");
            if (sr != null) con.route = RouteKind.from_id (sr);
            string stroke = color (c.get ("strokeColor"), "#000000");
            st.stroke = stroke == "none" ? "none" : with_opacity (stroke, c.num ("strokeOpacity", 100));
            st.stroke_width = c.num ("strokeWidth", 1);
            st.dash = dash_from (c);
            apply_text_style (st, c);
            st.wrap = false;
            st.arrow_start = arrow_from (c.get ("startArrow") ?? "none", c.get ("startFill") != "0");
            st.arrow_end = arrow_from (c.get ("endArrow") ?? "classic", c.get ("endFill") != "0");
            string? sa = c.get ("sdrawArrowStart");
            if (sa != null) st.arrow_start = ArrowKind.from_id (sa);
            string? ea = c.get ("sdrawArrowEnd");
            if (ea != null) st.arrow_end = ArrowKind.from_id (ea);
            string? sz = c.get ("sdrawArrowSize");
            if (sz != null) st.arrow_size = double.parse (sz);
            string lbg = color (c.get ("labelBackgroundColor"), "none");
            if (lbg != "none") {
                st.fill_kind = FillKind.SOLID;
                st.fill = lbg;
            } else {
                st.fill_kind = FillKind.NONE;
            }
            var sb = new StringBuilder (html_value (c));
            if (c.has_x && c.relative) con.label_pos = ((c.x + 1) / 2).clamp (0, 1);
            foreach (var ch in c.children) {
                ch.consumed = true;
                string t = html_value (ch);
                if (t == "") continue;
                if (sb.len > 0) sb.append_c ('\n');
                sb.append (t);
                if (ch.relative && ch.has_x) con.label_pos = ((ch.x + 1) / 2).clamp (0, 1);
            }
            con.text = sb.str;
            string? lp = c.get ("sdrawLabelPos");
            if (lp != null) con.label_pos = double.parse (lp);
            copy_fields (c, con);
            Point[] wps = {};
            foreach (var p in c.points) wps += Point (p.x + ox, p.y + oy);
            con.waypoints = wps;
            con.src.x = c.has_sp ? c.sp.x + ox : (wps.length > 0 ? wps[0].x : ox);
            con.src.y = c.has_sp ? c.sp.y + oy : (wps.length > 0 ? wps[0].y : oy);
            con.dst.x = c.has_tp ? c.tp.x + ox : (wps.length > 0 ? wps[wps.length - 1].x : ox);
            con.dst.y = c.has_tp ? c.tp.y + oy : (wps.length > 0 ? wps[wps.length - 1].y : oy);
            if (c.source != "" && map.has_key (c.source) && !map[c.source].edge) {
                con.src.item_id = c.source;
                if (c.get ("exitX") != null && c.get ("exitY") != null) con.src.port = nearest_port (map[c.source], c.num ("exitX", 0.5), c.num ("exitY", 0.5));
            }
            if (c.target != "" && map.has_key (c.target) && !map[c.target].edge) {
                con.dst.item_id = c.target;
                if (c.get ("entryX") != null && c.get ("entryY") != null) con.dst.port = nearest_port (map[c.target], c.num ("entryX", 0.5), c.num ("entryY", 0.5));
            }
            return con;
        }

        private static string shape_style (string kind) {
            switch (kind) {
                case "rectangle": return "rounded=0";
                case "rounded-rectangle": return "rounded=1";
                case "ellipse": case "uml-usecase": case "on-page": case "uml-initial": return "ellipse";
                case "circle": return "ellipse;aspect=fixed";
                case "triangle": case "extract": return "triangle;direction=north";
                case "merge": return "triangle;direction=south";
                case "diamond": case "uml-decision": return "rhombus";
                case "decision": return "shape=mxgraph.flowchart.decision";
                case "process": return "shape=mxgraph.flowchart.process";
                case "parallelogram": return "shape=parallelogram;perimeter=parallelogramPerimeter;fixedSize=1";
                case "data": return "shape=mxgraph.flowchart.data";
                case "trapezoid": return "shape=trapezoid;perimeter=trapezoidPerimeter;fixedSize=1";
                case "hexagon": return "shape=hexagon;perimeter=hexagonPerimeter2;fixedSize=1";
                case "preparation": return "shape=mxgraph.flowchart.preparation";
                case "pentagon": return "shape=mxgraph.basic.pentagon";
                case "octagon": return "shape=mxgraph.basic.octagon2;dx=15";
                case "star": return "shape=mxgraph.basic.star";
                case "star4": return "shape=mxgraph.basic.4_point_star_2;dx=0.8";
                case "cross": return "shape=cross";
                case "heart": return "shape=mxgraph.basic.heart";
                case "cloud": return "ellipse;shape=cloud";
                case "cube": case "uml-node": return "shape=cube";
                case "cylinder": case "database": return "shape=cylinder3;boundedLbl=1;backgroundOutline=1;size=15";
                case "donut": return "shape=mxgraph.basic.donut;dx=25";
                case "frame": return "shape=mxgraph.basic.frame;dx=10";
                case "note": case "uml-note": return "shape=note";
                case "callout": return "shape=callout";
                case "text": return "text";
                case "line-shape": return "line";
                case "arrow-right": return "shape=singleArrow";
                case "arrow-left": return "shape=singleArrow;direction=west";
                case "arrow-up": return "shape=singleArrow;direction=north";
                case "arrow-down": return "shape=singleArrow;direction=south";
                case "arrow-left-right": return "shape=doubleArrow";
                case "arrow-up-down": return "shape=doubleArrow;direction=north";
                case "arrow-quad": return "shape=mxgraph.arrows2.quadArrow";
                case "arrow-notched": return "shape=mxgraph.arrows2.notchedSignalIn";
                case "chevron": return "shape=step;perimeter=stepPerimeter;fixedSize=1";
                case "arrow-pentagon": return "shape=mxgraph.arrows2.arrow;dy=0;dx=20;notch=0";
                case "arrow-uturn": return "shape=mxgraph.arrows2.uTurnArrow";
                case "terminator": return "shape=mxgraph.flowchart.terminator";
                case "predefined-process": return "shape=process";
                case "document": return "shape=document";
                case "multi-document": return "shape=mxgraph.flowchart.multi-document";
                case "manual-input": return "shape=manualInput";
                case "manual-operation": return "shape=mxgraph.flowchart.manual_operation";
                case "delay": return "shape=delay";
                case "display": return "shape=display";
                case "direct-access": return "shape=mxgraph.flowchart.direct_data";
                case "stored-data": return "shape=dataStorage";
                case "internal-storage": return "shape=internalStorage";
                case "card": return "shape=card";
                case "punched-tape": return "shape=tape";
                case "off-page": return "shape=offPageConnector";
                case "summing-junction": return "shape=sumEllipse;perimeter=ellipsePerimeter";
                case "or": return "shape=orEllipse;perimeter=ellipsePerimeter";
                case "collate": return "shape=collate";
                case "sort": return "shape=sortShape;perimeter=rhombusPerimeter";
                case "loop-limit": return "shape=loopLimit";
                case "annotation": case "bpmn-annotation": return "shape=mxgraph.flowchart.annotation_1";
                case "container": return "container=1";
                case "swimlane-h": return "swimlane;horizontal=0;startSize=30";
                case "swimlane-v": return "swimlane;startSize=30";
                case "group-box": return "swimlane;startSize=28";
                case "pool": case "bpmn-pool": return "shape=pool;horizontal=0;startSize=30";
                case "uml-actor": return "shape=umlActor";
                case "uml-package": return "shape=folder;tabWidth=60;tabHeight=18;tabPosition=left";
                case "uml-component": return "shape=component";
                case "uml-final": return "ellipse;shape=endState";
                case "uml-lifeline": return "shape=umlLifeline;perimeter=lifelinePerimeter";
                case "bpmn-start": return "shape=mxgraph.bpmn.shape;outline=standard;symbol=general;perimeter=ellipsePerimeter";
                case "bpmn-intermediate": return "shape=mxgraph.bpmn.shape;outline=catching;symbol=general;perimeter=ellipsePerimeter";
                case "bpmn-end": return "shape=mxgraph.bpmn.shape;outline=end;symbol=terminate2;perimeter=ellipsePerimeter";
                case "bpmn-timer": return "shape=mxgraph.bpmn.shape;outline=catching;symbol=timer;perimeter=ellipsePerimeter";
                case "bpmn-message": return "shape=mxgraph.bpmn.shape;outline=catching;symbol=message;perimeter=ellipsePerimeter";
                case "bpmn-gateway": return "shape=mxgraph.bpmn.shape;perimeter=rhombusPerimeter;background=gateway;outline=none;symbol=exclusiveGw";
                case "bpmn-gateway-parallel": return "shape=mxgraph.bpmn.shape;perimeter=rhombusPerimeter;background=gateway;outline=none;symbol=parallelGw";
                case "bpmn-gateway-inclusive": return "shape=mxgraph.bpmn.shape;perimeter=rhombusPerimeter;background=gateway;outline=none;symbol=inclusiveGw";
                case "bpmn-gateway-event": return "shape=mxgraph.bpmn.shape;perimeter=rhombusPerimeter;background=gateway;outline=none;symbol=eventGw";
                case "bpmn-data-object": return "shape=mxgraph.bpmn.data";
                case "bpmn-data-store": return "shape=datastore";
                case "net-server": return "shape=mxgraph.networks.server";
                case "net-desktop": return "shape=mxgraph.networks.pc";
                case "net-laptop": return "shape=mxgraph.networks.laptop";
                case "net-phone": return "shape=mxgraph.networks.mobile";
                case "net-router": return "shape=mxgraph.networks.router";
                case "net-switch": return "shape=mxgraph.networks.switch";
                case "net-firewall": return "shape=mxgraph.networks.firewall";
                case "net-wireless": return "shape=mxgraph.networks.wireless_hub";
                case "net-cloud": return "shape=mxgraph.networks.cloud";
                case "net-database": return "shape=mxgraph.networks.database";
                case "net-storage": return "shape=mxgraph.networks.storage";
                case "net-printer": return "shape=mxgraph.networks.printer";
                case "net-user": return "shape=mxgraph.networks.user_male";
                case "bpmn-task": case "bpmn-subprocess": case "uml-state": case "bpmn-group":
                case "org-person": case "org-manager": case "org-assistant": case "org-team": case "org-position":
                    return "rounded=1";
                default: return "rounded=0";
            }
        }

        private static string hex (string c) {
            return Colors.is_none (c) ? "none" : Colors.rgb_hex (c);
        }

        private static string pct (string c) {
            return PathData.fmt (Colors.alpha (c) * 100, 1);
        }

        private static void text_style (StyleOut so, Style st) {
            so.add ("fontColor", hex (st.text_color));
            so.add ("fontSize", PathData.fmt (st.font_size / 0.75, 3));
            so.add ("fontFamily", st.font_family);
            int fs = (st.bold ? 1 : 0) | (st.italic ? 2 : 0) | (st.underline ? 4 : 0) | (st.strike ? 8 : 0);
            so.add ("fontStyle", fs.to_string ());
            so.add ("align", st.halign.to_id ());
            so.add ("verticalAlign", st.valign.to_id ());
            if (st.wrap) so.add ("whiteSpace", "wrap");
            if (st.opacity < 0.999) {
                so.add ("opacity", PathData.fmt (st.opacity * 100, 2));
                so.add ("sdrawTextOpacity", PathData.fmt (st.opacity, 4));
            }
            if (st.shadow) so.add ("shadow", "1");
        }

        private static void stroke_style (StyleOut so, Style st) {
            so.add ("strokeColor", hex (st.stroke));
            if (!Colors.is_none (st.stroke) && Colors.alpha (st.stroke) < 0.999) so.add ("strokeOpacity", pct (st.stroke));
            so.add ("strokeWidth", PathData.fmt (st.stroke_width, 3));
            if (st.dash != DashKind.SOLID) {
                so.add ("dashed", "1");
                var pat = st.dash.pattern (1);
                var sb = new StringBuilder ();
                foreach (double d in pat) {
                    if (sb.len > 0) sb.append_c (' ');
                    sb.append (PathData.fmt (d, 2));
                }
                so.add ("dashPattern", sb.str);
                so.add ("sdrawDash", st.dash.to_id ());
            }
        }

        private static void arrow_style (StyleOut so, Style st) {
            string name;
            bool fill;
            arrow_to (st.arrow_start, out name, out fill);
            so.add ("startArrow", name);
            so.add ("startFill", fill ? "1" : "0");
            arrow_to (st.arrow_end, out name, out fill);
            so.add ("endArrow", name);
            so.add ("endFill", fill ? "1" : "0");
            so.add ("sdrawArrowStart", st.arrow_start.to_id ());
            so.add ("sdrawArrowEnd", st.arrow_end.to_id ());
            if (st.arrow_size != 1) so.add ("sdrawArrowSize", PathData.fmt (st.arrow_size, 3));
        }

        private static string vertex_style (Shape s) {
            var st = s.style;
            var so = new StyleOut ();
            if (s is ImageShape) {
                var img = (ImageShape) s;
                so.raw ("shape=image;imageAspect=0");
                if (img.bytes.length > 0) so.add ("image", "data:%s,%s".printf (img.mime, Base64.encode (img.bytes)));
                else if (img.link != "") so.add ("image", img.link);
            } else if (s is PathShape) {
                var ps = (PathShape) s;
                so.raw ("shape=image;imageAspect=0");
                so.add ("image", "data:image/svg+xml,%s".printf (Base64.encode (path_svg (ps).data)));
                so.add ("sdrawPath", ps.path.to_svg (3));
                so.add ("sdrawNW", PathData.fmt (ps.natural_w, 3));
                so.add ("sdrawNH", PathData.fmt (ps.natural_h, 3));
            } else {
                so.raw (shape_style (s.kind));
            }
            so.add ("sdrawKind", s.kind);
            so.add ("html", "0");
            if (s.style.corner_radius > 0) {
                so.add ("rounded", "1");
                so.add ("absoluteArcSize", "1");
                so.add ("arcSize", PathData.fmt (st.corner_radius * 2, 3));
                so.add ("sdrawRadius", PathData.fmt (st.corner_radius, 3));
            } else if (s.kind != "rounded-rectangle") {
                so.add ("sdrawRadius", "0");
            }
            if (!st.has_fill ()) {
                so.add ("fillColor", "none");
            } else {
                so.add ("fillColor", hex (st.fill));
                if (Colors.alpha (st.fill) < 0.999) so.add ("fillOpacity", pct (st.fill));
                if (st.fill_kind == FillKind.LINEAR || st.fill_kind == FillKind.RADIAL) {
                    so.add ("gradientColor", hex (st.fill2));
                    string gd = "south";
                    if (st.fill_kind == FillKind.RADIAL) gd = "radial";
                    else {
                        double a = Document.normalize_angle (st.gradient_angle);
                        if (a >= 225 && a < 315) gd = "north";
                        else if (a >= 315 || a < 45) gd = "east";
                        else if (a >= 135 && a < 225) gd = "west";
                    }
                    so.add ("gradientDirection", gd);
                    so.add ("sdrawGradientAngle", PathData.fmt (st.gradient_angle, 3));
                }
            }
            stroke_style (so, st);
            text_style (so, st);
            if (s.kind == "line-shape" || s is PathShape) arrow_style (so, st);
            if (s.rotation != 0) so.add ("rotation", PathData.fmt (s.rotation, 4));
            if (s.flip_h) so.add ("flipH", "1");
            if (s.flip_v) so.add ("flipV", "1");
            if (s.container_id != "") so.add ("sdrawContainer", s.container_id);
            return so.str ();
        }

        private static string path_svg (PathShape ps) {
            var w = new XmlWriter (false);
            w.start ("svg").attr ("xmlns", "http://www.w3.org/2000/svg")
                .attr ("viewBox", "0 0 %s %s".printf (PathData.fmt (double.max (ps.w, 1), 3), PathData.fmt (double.max (ps.h, 1), 3)));
            w.start ("path").attr ("d", ps.local_path ().to_svg (2));
            w.attr ("fill", ps.is_closed () && ps.style.has_fill () ? hex (ps.style.fill) : "none");
            w.attr ("stroke", ps.style.has_stroke () ? hex (ps.style.stroke) : "none");
            w.attr_num ("stroke-width", ps.style.stroke_width, 3);
            w.end ();
            return w.finish ();
        }

        private static string safe_key (string k) {
            var sb = new StringBuilder ();
            for (int i = 0; i < k.length; i++) {
                char ch = k[i];
                if (ch.isalnum () || ch == '_' || ch == '-' || ch == '.' || (uchar) ch >= 0x80) sb.append_c (ch);
                else sb.append_c ('_');
            }
            string r = sb.str;
            if (r == "" || r[0].isdigit () || r[0] == '-' || r[0] == '.') r = "_" + r;
            switch (r) {
                case "id": case "label": case "link": case "placeholders": case "tooltip":
                    r = "_" + r;
                    break;
            }
            return r;
        }

        private static void open_cell (XmlWriter w, Item it, string value, string style, string parent, bool vertex) {
            bool wrap = it.fields.size > 0 || it.link != "";
            if (wrap) {
                w.start ("object").attr ("label", value).attr ("id", it.id);
                if (it.link != "") w.attr ("link", it.link);
                foreach (var f in it.fields) w.attr (safe_key (f.key), f.value);
                w.start ("mxCell");
            } else {
                w.start ("mxCell").attr ("id", it.id).attr ("value", value);
            }
            w.attr ("style", style);
            if (vertex) w.attr ("vertex", "1");
            else w.attr ("edge", "1");
            w.attr ("parent", parent);
        }

        private static void close_cell (XmlWriter w, Item it) {
            w.end ();
            if (it.fields.size > 0 || it.link != "") w.end ();
        }

        private static void geometry (XmlWriter w, double x, double y, double wd, double ht) {
            w.start ("mxGeometry").attr_num ("x", x, 3).attr_num ("y", y, 3).attr_num ("width", wd, 3).attr_num ("height", ht, 3).attr ("as", "geometry").end ();
        }

        private static void write_item (XmlWriter w, Page page, Item it, string parent, double ox, double oy) {
            var g = it as Group;
            if (g != null) {
                var b = g.bounds ();
                if (b.is_empty ()) b = Rect (0, 0, 0, 0);
                open_cell (w, g, g.text, "group;sdrawKind=group", parent, true);
                geometry (w, b.x - ox, b.y - oy, b.w, b.h);
                close_cell (w, g);
                foreach (var c in g.children) write_item (w, page, c, g.id, b.x, b.y);
                return;
            }
            var con = it as Connector;
            if (con != null) {
                write_connector (w, page, con, parent, ox, oy);
                return;
            }
            var tb = it as TableShape;
            if (tb != null) {
                write_table (w, tb, parent, ox, oy);
                return;
            }
            var s = it as Shape;
            if (s == null) return;
            bool stack = s.kind == "uml-class" || s.kind == "uml-interface";
            string[] sections = stack ? s.text.split ("\n--\n") : new string[] { s.text };
            string style = vertex_style (s);
            if (stack) style = "swimlane;childLayout=stackLayout;horizontal=1;startSize=26;horizontalStack=0;resizeParent=1;resizeParentMax=0;resizeLast=0;collapsible=0;marginBottom=0;" + style;
            open_cell (w, s, sections[0], style, parent, true);
            geometry (w, s.x - ox, s.y - oy, s.w, s.h);
            close_cell (w, s);
            if (stack && sections.length > 1) {
                double y = 26;
                double each = double.max ((s.h - 26) / (sections.length - 1) - 8, 10);
                for (int i = 1; i < sections.length; i++) {
                    if (i > 1) {
                        w.start ("mxCell").attr ("id", "%s-line%d".printf (s.id, i)).attr ("value", "")
                            .attr ("style", "line;strokeWidth=1;fillColor=none;align=left;verticalAlign=middle;spacingTop=-1;spacingLeft=3;spacingRight=3;rotatable=0;labelPosition=right;points=[];portConstraint=eastwest;")
                            .attr ("vertex", "1").attr ("parent", s.id);
                        geometry (w, 0, y, s.w, 8);
                        w.end ();
                        y += 8;
                    }
                    w.start ("mxCell").attr ("id", "%s-sec%d".printf (s.id, i)).attr ("value", sections[i])
                        .attr ("style", "text;strokeColor=none;fillColor=none;align=left;verticalAlign=top;spacingLeft=4;spacingRight=4;overflow=hidden;rotatable=0;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;whiteSpace=wrap;")
                        .attr ("vertex", "1").attr ("parent", s.id);
                    geometry (w, 0, y, s.w, each);
                    w.end ();
                    y += each;
                }
            }
        }

        private static void write_table (XmlWriter w, TableShape t, string parent, double ox, double oy) {
            string style = "shape=table;startSize=0;container=1;collapsible=0;childLayout=tableLayout;" + vertex_style (t)
                + "sdrawHeader=%s;sdrawHeaderFill=%s;".printf (t.header_row ? "1" : "0", hex (t.header_fill));
            open_cell (w, t, "", style, parent, true);
            geometry (w, t.x - ox, t.y - oy, t.w, t.h);
            close_cell (w, t);
            for (int r = 0; r < t.rows; r++) {
                string rid = "%s-r%d".printf (t.id, r);
                double ry = t.row_y (r), rh = t.row_y (r + 1) - ry;
                w.start ("mxCell").attr ("id", rid).attr ("value", "")
                    .attr ("style", "shape=tableRow;horizontal=0;startSize=0;swimlaneHead=0;swimlaneBody=0;top=0;left=0;bottom=0;right=0;collapsible=0;dropTarget=0;fillColor=none;points=[[0,0.5],[1,0.5]];portConstraint=eastwest;")
                    .attr ("vertex", "1").attr ("parent", t.id);
                geometry (w, 0, ry, t.w, rh);
                w.end ();
                for (int c = 0; c < t.cols; c++) {
                    double cx = t.col_x (c), cw = t.col_x (c + 1) - cx;
                    string fill = r == 0 && t.header_row ? hex (t.header_fill) : "none";
                    string cs = "shape=partialRectangle;html=0;whiteSpace=wrap;connectable=0;overflow=hidden;top=0;left=0;bottom=0;right=0;pointerEvents=1;fillColor=%s;strokeColor=%s;fontColor=%s;align=%s;%s".printf (
                        fill, hex (t.style.stroke), hex (t.style.text_color), t.style.halign.to_id (), r == 0 && t.header_row ? "fontStyle=1;" : "");
                    w.start ("mxCell").attr ("id", "%s-c%d".printf (rid, c)).attr ("value", t.get_cell (r, c))
                        .attr ("style", cs).attr ("vertex", "1").attr ("parent", rid);
                    geometry (w, cx, 0, cw, rh);
                    w.end ();
                }
            }
        }

        private static void write_connector (XmlWriter w, Page page, Connector c, string parent, double ox, double oy) {
            var st = c.style;
            var so = new StyleOut ();
            switch (c.route) {
                case RouteKind.STRAIGHT: so.add ("edgeStyle", "none"); break;
                case RouteKind.CURVED: so.add ("edgeStyle", "orthogonalEdgeStyle"); so.add ("curved", "1"); break;
                default: so.add ("edgeStyle", "orthogonalEdgeStyle"); so.add ("rounded", "0"); break;
            }
            so.add ("sdrawRoute", c.route.to_id ());
            so.add ("html", "0");
            arrow_style (so, st);
            stroke_style (so, st);
            text_style (so, st);
            if (st.fill_kind != FillKind.NONE && !Colors.is_none (st.fill)) so.add ("labelBackgroundColor", hex (st.fill));
            if (c.label_pos != 0.5) so.add ("sdrawLabelPos", PathData.fmt (c.label_pos, 4));
            add_port (so, page, c.src, "exit");
            add_port (so, page, c.dst, "entry");
            open_cell (w, c, c.text, so.str (), parent, false);
            if (c.src.attached ()) w.attr ("source", c.src.item_id);
            if (c.dst.attached ()) w.attr ("target", c.dst.item_id);
            w.start ("mxGeometry").attr ("relative", "1").attr ("as", "geometry");
            if (c.label_pos != 0.5) w.attr_num ("x", c.label_pos * 2 - 1, 4);
            w.start ("mxPoint").attr_num ("x", c.src.x - ox, 3).attr_num ("y", c.src.y - oy, 3).attr ("as", "sourcePoint").end ();
            w.start ("mxPoint").attr_num ("x", c.dst.x - ox, 3).attr_num ("y", c.dst.y - oy, 3).attr ("as", "targetPoint").end ();
            if (c.waypoints.length > 0) {
                w.start ("Array").attr ("as", "points");
                foreach (var p in c.waypoints) w.start ("mxPoint").attr_num ("x", p.x - ox, 3).attr_num ("y", p.y - oy, 3).end ();
                w.end ();
            }
            w.end ();
            close_cell (w, c);
        }

        private static void add_port (StyleOut so, Page page, Endpoint e, string prefix) {
            if (!e.attached () || e.port < 0) return;
            var s = page.find (e.item_id) as Shape;
            if (s == null) return;
            var ports = s.ports ();
            if (e.port >= ports.length) return;
            so.add (prefix + "X", PathData.fmt (ports[e.port].x, 4));
            so.add (prefix + "Y", PathData.fmt (ports[e.port].y, 4));
            so.add (prefix + "Dx", "0");
            so.add (prefix + "Dy", "0");
        }

        public static string save (Document doc) throws Error {
            var w = new XmlWriter (true, true);
            w.start ("mxfile").attr ("host", "Singularity").attr ("type", "device");
            foreach (var page in doc.pages) {
                w.start ("diagram").attr ("id", page.id).attr ("name", page.name);
                w.start ("mxGraphModel").attr ("dx", "0").attr ("dy", "0").attr ("grid", "1").attr_num ("gridSize", doc.grid_size, 2)
                    .attr ("guides", "1").attr ("tooltips", "1").attr ("connect", "1").attr ("arrows", "1").attr ("fold", "1")
                    .attr ("page", "1").attr ("pageScale", "1").attr_num ("pageWidth", page.width, 3).attr_num ("pageHeight", page.height, 3)
                    .attr ("background", Colors.is_none (page.background) ? "none" : hex (page.background)).attr ("math", "0").attr ("shadow", "0");
                w.start ("root");
                w.start ("mxCell").attr ("id", "0").end ();
                foreach (var l in page.layers) {
                    w.start ("mxCell").attr ("id", l.id).attr ("value", l.name).attr ("style", l.locked ? "locked=1;" : "").attr ("parent", "0");
                    if (!l.visible) w.attr ("visible", "0");
                    w.end ();
                }
                string fallback = page.layers.size > 0 ? page.layers[0].id : "1";
                if (page.layers.size == 0) w.start ("mxCell").attr ("id", "1").attr ("parent", "0").end ();
                foreach (var it in page.items) {
                    string layer = page.find_layer (it.layer_id) != null ? it.layer_id : fallback;
                    write_item (w, page, it, layer, 0, 0);
                }
                w.end ();
                w.end ();
                w.end ();
            }
            w.end ();
            return w.finish ();
        }
    }
}
