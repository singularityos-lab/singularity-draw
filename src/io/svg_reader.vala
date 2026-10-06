namespace Singularity.Apps.Draw {

    public class SvgReader {

        private class CssRule {
            public string tag = "";
            public string id = "";
            public string[] classes = {};
            public int spec;
            public int order;
            public Gee.HashMap<string, string> props = new Gee.HashMap<string, string> ();
        }

        private class Ctx {
            public Gee.HashMap<string, string> props = new Gee.HashMap<string, string> ();
            public double opacity = 1;
            public Cairo.Matrix m = Cairo.Matrix.identity ();
            public int depth = 0;
        }

        private const string[] INHERITED = {
            "fill", "fill-opacity", "fill-rule", "stroke", "stroke-width", "stroke-opacity", "stroke-dasharray",
            "stroke-linecap", "stroke-linejoin", "font-family", "font-size", "font-weight", "font-style", "text-anchor",
            "text-decoration", "visibility", "color", "marker-start", "marker-end", "marker-mid"
        };

        private const string[] PRESENTATION = {
            "fill", "fill-opacity", "fill-rule", "stroke", "stroke-width", "stroke-opacity", "stroke-dasharray",
            "stroke-linecap", "stroke-linejoin", "font-family", "font-size", "font-weight", "font-style", "text-anchor",
            "text-decoration", "visibility", "color", "marker-start", "marker-end", "marker-mid", "opacity", "display",
            "stop-color", "stop-opacity"
        };

        private Gee.ArrayList<CssRule> rules = new Gee.ArrayList<CssRule> ();
        private Gee.HashMap<string, Xml.Node*> ids = new Gee.HashMap<string, Xml.Node*> ();
        private double width = 0;
        private double height = 0;
        private Gee.ArrayList<Layer> raster_layers = new Gee.ArrayList<Layer> ();

        public static Document load (string text) throws Error {
            var reader = new SvgReader ();
            var doc = new Document ();
            var items = reader.read (text);
            var page = doc.page;
            page.width = double.max (reader.width, 1);
            page.height = double.max (reader.height, 1);
            foreach (var l in reader.raster_layers) page.layers.add (l);
            assign_ids (items, doc);
            foreach (var it in items) doc.add_item (it);
            doc.modified = false;
            return doc;
        }

        public static Gee.ArrayList<Item> import_items (string text, Document doc) throws Error {
            var reader = new SvgReader ();
            var items = reader.read (text);
            assign_ids (items, doc);
            return items;
        }

        private static void assign_ids (Gee.List<Item> items, Document doc) {
            foreach (var it in items) {
                it.id = doc.new_id ();
                var g = it as Group;
                if (g != null) assign_ids (g.children, doc);
            }
        }

        private Gee.ArrayList<Item> read (string text) throws Error {
            Xml.Doc* xdoc = XmlUtil.parse (text);
            var root = xdoc->get_root_element ();
            var items = new Gee.ArrayList<Item> ();
            try {
                if (root->name != "svg") throw new FormatError.INVALID (_("This is not an SVG image."));
                index (root);
                collect_styles (root);
                var ctx = new Ctx ();
                ctx.props["fill"] = "black";
                ctx.m = viewport (root, true);
                process_children (root, ctx, items);
            } finally {
                delete xdoc;
            }
            return items;
        }

        private void index (Xml.Node* n) {
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
                string? id = XmlUtil.attr (c, "id");
                if (id != null && !ids.has_key (id)) ids[id] = c;
                index (c);
            }
        }

        private static bool is_percent (string? s) {
            return s != null && s.strip ().has_suffix ("%");
        }

        private static double[] numbers (string? s) {
            double[] v = {};
            if (s == null) return v;
            var sc = new PathScanner (s);
            while (true) {
                double d = 0;
                if (!sc.number (out d)) break;
                v += d;
            }
            return v;
        }

        private static double length (string? s, double fallback) {
            if (s == null || s.strip () == "" || is_percent (s)) return fallback;
            return Units.parse_length (s, fallback);
        }

        private Cairo.Matrix viewport (Xml.Node* n, bool root) {
            double[] vb = numbers (XmlUtil.attr (n, "viewBox"));
            bool has_vb = vb.length == 4 && vb[2] > 0 && vb[3] > 0;
            double w = length (XmlUtil.attr (n, "width"), has_vb ? vb[2] : 300);
            double h = length (XmlUtil.attr (n, "height"), has_vb ? vb[3] : 150);
            if (is_percent (XmlUtil.attr (n, "width")) && !has_vb) w = 300;
            if (root) {
                width = w;
                height = h;
            }
            var m = Cairo.Matrix.identity ();
            if (!root) m.translate (length (XmlUtil.attr (n, "x"), 0), length (XmlUtil.attr (n, "y"), 0));
            if (!has_vb) return m;
            double sx = w / vb[2], sy = h / vb[3];
            string par = (XmlUtil.attr (n, "preserveAspectRatio") ?? "xMidYMid meet").strip ();
            double tx = 0, ty = 0;
            if (!par.has_prefix ("none")) {
                double s = par.contains ("slice") ? double.max (sx, sy) : double.min (sx, sy);
                string align = par.split (" ")[0];
                double ex = w - vb[2] * s, ey = h - vb[3] * s;
                if (align.contains ("xMid")) tx = ex / 2;
                else if (align.contains ("xMax")) tx = ex;
                if (align.contains ("YMid")) ty = ey / 2;
                else if (align.contains ("YMax")) ty = ey;
                sx = sy = s;
            }
            m.translate (tx, ty);
            m.scale (sx, sy);
            m.translate (-vb[0], -vb[1]);
            return m;
        }

        private void collect_styles (Xml.Node* n) {
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
                if (c->name == "style") parse_css (XmlUtil.text (c));
                else collect_styles (c);
            }
        }

        private void parse_css (string text) {
            string css = text;
            while (true) {
                int a = css.index_of ("/*");
                if (a < 0) break;
                int b = css.index_of ("*/", a + 2);
                css = css.substring (0, a) + (b < 0 ? "" : css.substring (b + 2));
            }
            foreach (string block in css.split ("}")) {
                int brace = block.index_of ("{");
                if (brace < 0) continue;
                string selectors = block.substring (0, brace);
                var props = parse_decls (block.substring (brace + 1));
                foreach (string raw in selectors.split (",")) {
                    string sel = raw.strip ();
                    if (sel == "" || sel.contains (":") || sel.contains ("[") || sel.has_prefix ("@")) continue;
                    string[] parts = sel.split_set (" >+~");
                    string last = "";
                    foreach (string p in parts) if (p.strip () != "") last = p.strip ();
                    if (last == "" || last == "*") continue;
                    var r = new CssRule ();
                    r.order = rules.size;
                    int i = 0;
                    var cur = new StringBuilder ();
                    char mode = 't';
                    while (i <= last.length) {
                        char ch = i < last.length ? last[i] : '\0';
                        if (ch == '.' || ch == '#' || ch == '\0') {
                            string tok = cur.str;
                            if (tok != "") {
                                if (mode == 't') r.tag = tok;
                                else if (mode == '.') r.classes += tok;
                                else r.id = tok;
                            }
                            cur.truncate ();
                            mode = ch;
                        } else {
                            cur.append_c (ch);
                        }
                        i++;
                    }
                    r.spec = (r.id != "" ? 100 : 0) + r.classes.length * 10 + (r.tag != "" ? 1 : 0);
                    foreach (var e in props.entries) r.props[e.key] = e.value;
                    rules.add (r);
                }
            }
            rules.sort ((a, b) => a.spec != b.spec ? a.spec - b.spec : a.order - b.order);
        }

        private static Gee.HashMap<string, string> parse_decls (string s) {
            var map = new Gee.HashMap<string, string> ();
            foreach (string d in s.split (";")) {
                int colon = d.index_of (":");
                if (colon < 0) continue;
                string k = d.substring (0, colon).strip ().down ();
                string v = d.substring (colon + 1).strip ();
                if (v.has_suffix ("!important")) v = v.substring (0, v.length - 10).strip ();
                if (k != "") map[k] = v;
            }
            return map;
        }

        private bool matches (CssRule r, Xml.Node* n) {
            if (r.tag != "" && r.tag != n->name) return false;
            if (r.id != "" && XmlUtil.attr (n, "id") != r.id) return false;
            if (r.classes.length > 0) {
                string cls = XmlUtil.attr (n, "class") ?? "";
                string[] have = cls.split_set (" \t\n");
                foreach (string want in r.classes) {
                    bool found = false;
                    foreach (string h in have) if (h == want) found = true;
                    if (!found) return false;
                }
            }
            return true;
        }

        private Gee.HashMap<string, string> own_props (Xml.Node* n, Ctx parent) {
            var p = new Gee.HashMap<string, string> ();
            foreach (string k in INHERITED) if (parent.props.has_key (k)) p[k] = parent.props[k];
            foreach (string k in PRESENTATION) {
                string? v = XmlUtil.attr (n, k);
                if (v != null && v.strip () != "" && v.strip () != "inherit") p[k] = v.strip ();
            }
            foreach (var r in rules) {
                if (!matches (r, n)) continue;
                foreach (var e in r.props.entries) if (e.value != "inherit") p[e.key] = e.value;
            }
            string? inline = XmlUtil.attr (n, "style");
            if (inline != null) foreach (var e in parse_decls (inline).entries) if (e.value != "inherit") p[e.key] = e.value;
            return p;
        }

        public static Cairo.Matrix parse_transform (string? s) {
            var m = Cairo.Matrix.identity ();
            if (s == null) return m;
            int i = 0;
            while (i < s.length) {
                while (i < s.length && (s[i].isspace () || s[i] == ',')) i++;
                int start = i;
                while (i < s.length && s[i].isalpha ()) i++;
                string name = s.substring (start, i - start);
                int open = s.index_of ("(", i);
                int close = open >= 0 ? s.index_of (")", open) : -1;
                if (name == "" || open < 0 || close < 0) break;
                double[] a = numbers (s.substring (open + 1, close - open - 1));
                i = close + 1;
                Cairo.Matrix op = Cairo.Matrix.identity ();
                switch (name) {
                    case "matrix":
                        if (a.length == 6) op = Cairo.Matrix (a[0], a[1], a[2], a[3], a[4], a[5]);
                        break;
                    case "translate":
                        if (a.length >= 1) op.translate (a[0], a.length > 1 ? a[1] : 0);
                        break;
                    case "scale":
                        if (a.length >= 1) op.scale (a[0], a.length > 1 ? a[1] : a[0]);
                        break;
                    case "rotate":
                        if (a.length >= 1) {
                            double cx = a.length >= 3 ? a[1] : 0, cy = a.length >= 3 ? a[2] : 0;
                            op.translate (cx, cy);
                            op.rotate (a[0] * Math.PI / 180);
                            op.translate (-cx, -cy);
                        }
                        break;
                    case "skewX":
                        if (a.length >= 1) op = Cairo.Matrix (1, 0, Math.tan (a[0] * Math.PI / 180), 1, 0, 0);
                        break;
                    case "skewY":
                        if (a.length >= 1) op = Cairo.Matrix (1, Math.tan (a[0] * Math.PI / 180), 0, 1, 0, 0);
                        break;
                    default:
                        break;
                }
                var r = Cairo.Matrix.identity ();
                r.multiply (op, m);
                m = r;
            }
            return m;
        }

        private Ctx child_ctx (Xml.Node* n, Ctx parent, out bool hidden) {
            var c = new Ctx ();
            c.props = own_props (n, parent);
            c.depth = parent.depth + 1;
            hidden = (c.props["display"] ?? "") == "none";
            string op = c.props["opacity"] ?? "1";
            c.opacity = parent.opacity * parse_fraction (op, 1);
            var own = parse_transform (XmlUtil.attr (n, "transform"));
            var total = Cairo.Matrix.identity ();
            total.multiply (own, parent.m);
            c.m = total;
            return c;
        }

        private static double parse_fraction (string? v, double fallback) {
            if (v == null || v.strip () == "") return fallback;
            string t = v.strip ();
            if (t.has_suffix ("%")) return (double.parse (t.substring (0, t.length - 1)) / 100).clamp (0, 1);
            return double.parse (t).clamp (0, 1);
        }

        private void process_children (Xml.Node* n, Ctx ctx, Gee.List<Item> out_items) {
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
                if (c->ns != null && c->ns->href != "http://www.w3.org/2000/svg") continue;
                process (c, ctx, out_items);
            }
        }

        private void process (Xml.Node* n, Ctx parent, Gee.List<Item> out_items) {
            if (parent.depth > 64) return;
            bool hidden;
            var ctx = child_ctx (n, parent, out hidden);
            if (hidden && !(n->name == "image" && XmlUtil.attr (n, "data-sdraw-raster") == "1")) return;
            switch (n->name) {
                case "g":
                case "a":
                case "switch":
                case "svg":
                    if (n->name == "svg") {
                        var vp = viewport (n, false);
                        var t = Cairo.Matrix.identity ();
                        t.multiply (vp, ctx.m);
                        ctx.m = t;
                    }
                    var list = new Gee.ArrayList<Item> ();
                    process_children (n, ctx, list);
                    if (list.size >= 2) {
                        var g = new Group ();
                        string? gid = XmlUtil.attr (n, "id");
                        if (gid != null) g.name = gid;
                        g.children.add_all (list);
                        out_items.add (g);
                    } else {
                        out_items.add_all (list);
                    }
                    break;
                case "use":
                    string? href = XmlUtil.attr (n, "href") ?? XmlUtil.attr (n, "href", "http://www.w3.org/1999/xlink");
                    if (href == null || !href.has_prefix ("#") || !ids.has_key (href.substring (1))) break;
                    var target = ids[href.substring (1)];
                    var shift = Cairo.Matrix.identity ();
                    shift.translate (length (XmlUtil.attr (n, "x"), 0), length (XmlUtil.attr (n, "y"), 0));
                    var um = Cairo.Matrix.identity ();
                    um.multiply (shift, ctx.m);
                    ctx.m = um;
                    if (target->name == "symbol") {
                        var symbol_items = new Gee.ArrayList<Item> ();
                        var sym = Cairo.Matrix.identity ();
                        if (XmlUtil.attr (target, "viewBox") != null && XmlUtil.attr (n, "width") != null) {
                            double[] vb = numbers (XmlUtil.attr (target, "viewBox"));
                            if (vb.length == 4 && vb[2] > 0 && vb[3] > 0) {
                                sym.scale (length (XmlUtil.attr (n, "width"), vb[2]) / vb[2], length (XmlUtil.attr (n, "height"), vb[3]) / vb[3]);
                                sym.translate (-vb[0], -vb[1]);
                            }
                        }
                        var sm = Cairo.Matrix.identity ();
                        sm.multiply (sym, ctx.m);
                        ctx.m = sm;
                        process_children (target, ctx, symbol_items);
                        if (symbol_items.size >= 2) {
                            var sg = new Group ();
                            sg.children.add_all (symbol_items);
                            out_items.add (sg);
                        } else {
                            out_items.add_all (symbol_items);
                        }
                    } else if (target != n) {
                        ctx.depth += 8;
                        process (target, ctx, out_items);
                    }
                    break;
                case "rect":
                    add_rect (n, ctx, out_items);
                    break;
                case "circle":
                case "ellipse":
                    add_ellipse (n, ctx, out_items);
                    break;
                case "line":
                    var lp = new PathData ();
                    lp.move_to (length (XmlUtil.attr (n, "x1"), 0), length (XmlUtil.attr (n, "y1"), 0));
                    lp.line_to (length (XmlUtil.attr (n, "x2"), 0), length (XmlUtil.attr (n, "y2"), 0));
                    add_path (lp, ctx, out_items);
                    break;
                case "polyline":
                case "polygon":
                    double[] v = numbers (XmlUtil.attr (n, "points"));
                    if (v.length < 4) break;
                    var pp = new PathData ();
                    pp.move_to (v[0], v[1]);
                    for (int i = 2; i + 1 < v.length; i += 2) pp.line_to (v[i], v[i + 1]);
                    if (n->name == "polygon") pp.close ();
                    add_path (pp, ctx, out_items);
                    break;
                case "path":
                    var dp = PathData.parse_svg (XmlUtil.attr_or (n, "d", ""));
                    if (!dp.is_empty ()) add_path (dp, ctx, out_items);
                    break;
                case "text":
                    add_text (n, ctx, out_items);
                    break;
                case "image":
                    add_image (n, ctx, out_items);
                    break;
                default:
                    break;
            }
        }

        private static bool axis_aligned (Cairo.Matrix m) {
            return m.xy.abs () < 1e-9 && m.yx.abs () < 1e-9;
        }

        private static bool similarity (Cairo.Matrix m) {
            return (m.xx - m.yy).abs () < 1e-6 && (m.xy + m.yx).abs () < 1e-6 && (m.xx != 0 || m.yx != 0);
        }

        private static double scale_of (Cairo.Matrix m) {
            return Math.sqrt ((m.xx * m.yy - m.xy * m.yx).abs ());
        }

        private static bool place_box (Shape s, Cairo.Matrix m, double x, double y, double w, double h) {
            if (axis_aligned (m)) {
                double x1 = x, y1 = y, x2 = x + w, y2 = y + h;
                m.transform_point (ref x1, ref y1);
                m.transform_point (ref x2, ref y2);
                s.set_bounds (Rect.from_points (x1, y1, x2, y2));
                return true;
            }
            if (similarity (m)) {
                double sc = Math.hypot (m.xx, m.yx);
                double cx = x + w / 2, cy = y + h / 2;
                m.transform_point (ref cx, ref cy);
                s.w = w * sc;
                s.h = h * sc;
                s.x = cx - s.w / 2;
                s.y = cy - s.h / 2;
                s.rotation = Document.normalize_angle (Math.atan2 (m.yx, m.xx) * 180 / Math.PI);
                return true;
            }
            return false;
        }

        private void add_rect (Xml.Node* n, Ctx ctx, Gee.List<Item> out_items) {
            double x = length (XmlUtil.attr (n, "x"), 0), y = length (XmlUtil.attr (n, "y"), 0);
            double w = length (XmlUtil.attr (n, "width"), 0), h = length (XmlUtil.attr (n, "height"), 0);
            if (w <= 0 || h <= 0) return;
            string? rxs = XmlUtil.attr (n, "rx"), rys = XmlUtil.attr (n, "ry");
            double rx = length (rxs ?? rys, 0), ry = length (rys ?? rxs, 0);
            rx = double.min (rx, w / 2);
            ry = double.min (ry, h / 2);
            var s = new Shape (rx > 0 ? "rounded-rectangle" : "rectangle");
            if (place_box (s, ctx.m, x, y, w, h)) {
                s.style = make_style (ctx, true);
                if (rx > 0) s.style.corner_radius = double.max (rx, ry) * scale_of (ctx.m);
                s.text = "";
                out_items.add (s);
                return;
            }
            var p = new PathData ();
            p.add_round_rect (x, y, w, h, double.max (rx, ry));
            add_path (p, ctx, out_items);
        }

        private void add_ellipse (Xml.Node* n, Ctx ctx, Gee.List<Item> out_items) {
            double cx = length (XmlUtil.attr (n, "cx"), 0), cy = length (XmlUtil.attr (n, "cy"), 0);
            double rx, ry;
            if (n->name == "circle") {
                rx = ry = length (XmlUtil.attr (n, "r"), 0);
            } else {
                rx = length (XmlUtil.attr (n, "rx"), 0);
                ry = length (XmlUtil.attr (n, "ry"), 0);
            }
            if (rx <= 0 || ry <= 0) return;
            var s = new Shape ("ellipse");
            if (place_box (s, ctx.m, cx - rx, cy - ry, rx * 2, ry * 2)) {
                s.style = make_style (ctx, true);
                out_items.add (s);
                return;
            }
            add_path (new PathData.ellipse (cx, cy, rx, ry), ctx, out_items);
        }

        private void add_path (PathData local, Ctx ctx, Gee.List<Item> out_items) {
            var page_path = local.transformed (ctx.m);
            var b = page_path.control_bounds ();
            if (b.is_empty ()) return;
            var ps = new PathShape ();
            ps.set_page_path (page_path);
            ps.style = make_style (ctx, local.has_closed_subpath ());
            ps.style.arrow_start = marker (ctx.props["marker-start"]);
            ps.style.arrow_end = marker (ctx.props["marker-end"]);
            out_items.add (ps);
        }

        private ArrowKind marker (string? v) {
            if (v == null || !v.has_prefix ("url(")) return ArrowKind.NONE;
            string? id = url_id (v);
            if (id == null || !ids.has_key (id)) return ArrowKind.TRIANGLE;
            var mk = ids[id];
            foreach (var c in XmlUtil.children (mk)) {
                if (c->name == "circle" || c->name == "ellipse") return ArrowKind.CIRCLE;
                if (c->name == "path" || c->name == "polygon" || c->name == "polyline") {
                    string fill = XmlUtil.attr (c, "fill") ?? "";
                    string st = XmlUtil.attr (c, "style") ?? "";
                    if (fill == "none" || st.contains ("fill:none")) return ArrowKind.OPEN;
                    return ArrowKind.TRIANGLE;
                }
            }
            return ArrowKind.TRIANGLE;
        }

        private static string? url_id (string v) {
            int a = v.index_of ("#");
            int b = v.index_of (")");
            if (a < 0 || b < a) return null;
            return v.substring (a + 1, b - a - 1).strip ().replace ("'", "").replace ("\"", "");
        }

        private string resolve_color (string raw, Ctx ctx) {
            string v = raw.strip ();
            if (v == "currentColor") v = ctx.props["color"] ?? "black";
            return v;
        }

        private static string alpha_hex (string color, double alpha) {
            Rgba c;
            if (!Colors.parse (color, out c)) return "none";
            c.a *= alpha.clamp (0, 1);
            return Colors.to_hex (c, true);
        }

        private Xml.Node* gradient_with_stops (Xml.Node* g) {
            Xml.Node* cur = g;
            for (int i = 0; i < 8 && cur != null; i++) {
                if (XmlUtil.children (cur, "stop").size > 0) return cur;
                string? href = XmlUtil.attr (cur, "href") ?? XmlUtil.attr (cur, "href", "http://www.w3.org/1999/xlink");
                if (href == null || !href.has_prefix ("#") || !ids.has_key (href.substring (1))) return null;
                cur = ids[href.substring (1)];
            }
            return null;
        }

        private string stop_color (Xml.Node* s, double extra) {
            var p = parse_decls (XmlUtil.attr (s, "style") ?? "");
            string col = p["stop-color"] ?? XmlUtil.attr (s, "stop-color") ?? "black";
            double op = parse_fraction (p["stop-opacity"] ?? XmlUtil.attr (s, "stop-opacity"), 1);
            return alpha_hex (col, op * extra);
        }

        private bool apply_gradient (Style st, string id, double alpha) {
            if (!ids.has_key (id)) return false;
            var g = ids[id];
            if (g->name != "linearGradient" && g->name != "radialGradient") return false;
            var holder = gradient_with_stops (g);
            if (holder == null) return false;
            var stops = XmlUtil.children (holder, "stop");
            st.fill = stop_color (stops[0], alpha);
            if (stops.size == 1) {
                st.fill_kind = FillKind.SOLID;
                return true;
            }
            st.fill2 = stop_color (stops[stops.size - 1], alpha);
            if (g->name == "radialGradient") {
                st.fill_kind = FillKind.RADIAL;
                return true;
            }
            st.fill_kind = FillKind.LINEAR;
            double x1 = coord (XmlUtil.attr (g, "x1"), 0), y1 = coord (XmlUtil.attr (g, "y1"), 0);
            double x2 = coord (XmlUtil.attr (g, "x2"), 1), y2 = coord (XmlUtil.attr (g, "y2"), 0);
            if ((x2 - x1).abs () < 1e-9 && (y2 - y1).abs () < 1e-9) st.gradient_angle = 0;
            else st.gradient_angle = Document.normalize_angle (Math.atan2 (y2 - y1, x2 - x1) * 180 / Math.PI);
            return true;
        }

        private static double coord (string? v, double fallback) {
            if (v == null || v.strip () == "") return fallback;
            string t = v.strip ();
            if (t.has_suffix ("%")) return double.parse (t.substring (0, t.length - 1)) / 100;
            return double.parse (t);
        }

        private static DashKind dash_from (string? v, double width) {
            if (v == null || v.strip () == "none" || v.strip () == "") return DashKind.SOLID;
            double[] a = numbers (v);
            if (a.length == 0) return DashKind.SOLID;
            double u = double.max (width, 0.5);
            if (a.length >= 6) return DashKind.DASH_DOT_DOT;
            if (a.length >= 4) return DashKind.DASH_DOT;
            if (a[0] <= u * 1.5) return DashKind.DOT;
            if (a[0] >= u * 8) return DashKind.LONG_DASH;
            return DashKind.DASH;
        }

        private Style make_style (Ctx ctx, bool closed) {
            var st = new Style ();
            var p = ctx.props;
            st.opacity = ctx.opacity;
            double sc = scale_of (ctx.m);
            string fill = resolve_color (p["fill"] ?? "black", ctx);
            double fo = parse_fraction (p["fill-opacity"], 1);
            if (fill == "none" || !closed) {
                st.fill_kind = FillKind.NONE;
                if (fill != "none" && fill.has_prefix ("url(") == false) st.fill = alpha_hex (fill, fo);
            } else if (fill.has_prefix ("url(")) {
                string? id = url_id (fill);
                if (id == null || !apply_gradient (st, id, fo)) {
                    st.fill_kind = FillKind.SOLID;
                    st.fill = "#000000";
                }
            } else {
                st.fill_kind = FillKind.SOLID;
                st.fill = alpha_hex (fill, fo);
                if (st.fill == "none") st.fill_kind = FillKind.NONE;
            }
            string stroke = resolve_color (p["stroke"] ?? "none", ctx);
            double so = parse_fraction (p["stroke-opacity"], 1);
            double sw = length (p["stroke-width"], 1);
            if (stroke == "none") {
                st.stroke = "none";
            } else if (stroke.has_prefix ("url(")) {
                var tmp = new Style ();
                string? id = url_id (stroke);
                st.stroke = id != null && apply_gradient (tmp, id, so) ? tmp.fill : "#000000";
            } else {
                st.stroke = alpha_hex (stroke, so);
            }
            st.stroke_width = sw * sc;
            st.dash = dash_from (p["stroke-dasharray"], sw);
            return st;
        }

        private static string clean_family (string f) {
            string first = f.split (",")[0].strip ();
            first = first.replace ("'", "").replace ("\"", "");
            switch (first) {
                case "sans-serif": return "Sans";
                case "serif": return "Serif";
                case "monospace": return "Monospace";
                default: return first == "" ? "Sans" : first;
            }
        }

        private class TextSeg {
            public string text;
            public Ctx ctx;

            public TextSeg (string text, Ctx ctx) {
                this.text = text;
                this.ctx = ctx;
            }
        }

        private void collect_text (Xml.Node* n, Ctx ctx, StringBuilder cur, Gee.List<string> lines, Gee.ArrayList<TextSeg> segs, Gee.List<Gee.ArrayList<TextSeg>> seg_lines) {
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type == Xml.ElementType.TEXT_NODE || c->type == Xml.ElementType.CDATA_SECTION_NODE) {
                    string t = c->get_content () ?? "";
                    t = t.replace ("\n", " ").replace ("\t", " ");
                    cur.append (t);
                    segs.add (new TextSeg (t, ctx));
                } else if (c->type == Xml.ElementType.ELEMENT_NODE && (c->name == "tspan" || c->name == "a" || c->name == "textPath")) {
                    bool breaks = XmlUtil.attr (c, "y") != null || (numbers (XmlUtil.attr (c, "dy")).length > 0 && numbers (XmlUtil.attr (c, "dy"))[0] != 0);
                    if (breaks && cur.str.strip () != "") {
                        lines.add (cur.str.strip ());
                        cur.truncate ();
                        seg_lines.add (copy_segs (segs));
                        segs.clear ();
                    } else if (breaks) {
                        segs.clear ();
                    }
                    bool hidden;
                    var sub = child_ctx (c, ctx, out hidden);
                    collect_text (c, sub, cur, lines, segs, seg_lines);
                }
            }
        }

        private static Gee.ArrayList<TextSeg> copy_segs (Gee.List<TextSeg> segs) {
            var l = new Gee.ArrayList<TextSeg> ();
            l.add_all (segs);
            return l;
        }

        private TextRun run_for (TextSeg seg, Style st, string text, double sc) {
            var r = new TextRun (text);
            var p = seg.ctx.props;
            string weight = p["font-weight"] ?? "normal";
            bool bold = weight == "bold" || weight == "bolder" || (weight.length > 0 && weight[0].isdigit () && int.parse (weight) >= 600);
            string fs = p["font-style"] ?? "";
            bool italic = fs == "italic" || fs == "oblique";
            string deco = p["text-decoration"] ?? "";
            r.bold = bold && !st.bold;
            r.italic = italic && !st.italic;
            r.underline = deco.contains ("underline") && !st.underline;
            r.strike = deco.contains ("line-through") && !st.strike;
            string fam = clean_family (p["font-family"] ?? "Sans");
            if (fam != st.font_family) r.family = fam;
            double size = double.max (length (p["font-size"], 16) * sc * 0.75, 1);
            if (Math.fabs (size - st.font_size) > 0.05) r.size = Math.round (size * 100) / 100;
            string fill = resolve_color (p["fill"] ?? "black", seg.ctx);
            if (!fill.has_prefix ("url(") && fill != "none") {
                string hex = Colors.rgb_hex (fill);
                if (hex.down () != Colors.rgb_hex (st.text_color).down ()) r.color = hex;
            }
            return r;
        }

        private string rich_markup (Gee.List<Gee.ArrayList<TextSeg>> seg_lines, Gee.List<string> lines, Style st, double sc) {
            var runs = new Gee.ArrayList<TextRun> ();
            for (int i = 0; i < seg_lines.size && i < lines.size; i++) {
                if (i > 0) runs.add (new TextRun ("\n"));
                var segs = seg_lines[i];
                var sb = new StringBuilder ();
                foreach (var sg in segs) sb.append (sg.text);
                string full = sb.str;
                string want = lines[i];
                int lead = full.index_of (want);
                if (lead < 0) return "";
                int pos = 0;
                int end = lead + want.length;
                foreach (var sg in segs) {
                    int a = int.max (pos, lead), b = int.min (pos + sg.text.length, end);
                    if (a < b) runs.add (run_for (sg, st, sg.text.substring (a - pos, b - a), sc));
                    pos += sg.text.length;
                }
            }
            return RichRuns.markup_from (runs, string.joinv ("\n", lines.to_array ()));
        }

        private void add_text (Xml.Node* n, Ctx ctx, Gee.List<Item> out_items) {
            var lines = new Gee.ArrayList<string> ();
            var cur = new StringBuilder ();
            var segs = new Gee.ArrayList<TextSeg> ();
            var seg_lines = new Gee.ArrayList<Gee.ArrayList<TextSeg>> ();
            collect_text (n, ctx, cur, lines, segs, seg_lines);
            if (cur.str.strip () != "") {
                lines.add (cur.str.strip ());
                seg_lines.add (copy_segs (segs));
            }
            if (lines.size == 0) return;
            string text = string.joinv ("\n", lines.to_array ());
            double[] xs = numbers (XmlUtil.attr (n, "x"));
            double[] ys = numbers (XmlUtil.attr (n, "y"));
            double x = xs.length > 0 ? xs[0] : 0, y = ys.length > 0 ? ys[0] : 0;
            if (xs.length == 0 || ys.length == 0) {
                foreach (var t in XmlUtil.children (n, "tspan")) {
                    double[] tx = numbers (XmlUtil.attr (t, "x"));
                    double[] ty = numbers (XmlUtil.attr (t, "y"));
                    if (xs.length == 0 && tx.length > 0) x = tx[0];
                    if (ys.length == 0 && ty.length > 0) y = ty[0];
                    break;
                }
            }
            double[] dx = numbers (XmlUtil.attr (n, "dx"));
            double[] dy = numbers (XmlUtil.attr (n, "dy"));
            if (dx.length > 0) x += dx[0];
            if (dy.length > 0) y += dy[0];
            var first_span = XmlUtil.child (n, "tspan");
            var p = ctx.props;
            if (first_span != null) {
                bool hidden;
                var sctx = child_ctx (first_span, ctx, out hidden);
                p = sctx.props;
            }
            var st = new Style ();
            st.fill_kind = FillKind.NONE;
            st.stroke = "none";
            st.wrap = false;
            st.valign = TextVAlign.TOP;
            double sc = scale_of (ctx.m);
            double px = length (p["font-size"], 16);
            st.font_size = double.max (px * sc * 0.75, 1);
            st.font_family = clean_family (p["font-family"] ?? "Sans");
            string weight = p["font-weight"] ?? "normal";
            st.bold = weight == "bold" || weight == "bolder" || (weight.length > 0 && weight[0].isdigit () && int.parse (weight) >= 600);
            string fs = p["font-style"] ?? "";
            st.italic = fs == "italic" || fs == "oblique";
            string deco = p["text-decoration"] ?? "";
            st.underline = deco.contains ("underline");
            st.strike = deco.contains ("line-through");
            string fill = resolve_color (p["fill"] ?? "black", ctx);
            if (fill.has_prefix ("url(")) {
                var tmp = new Style ();
                string? id = url_id (fill);
                fill = id != null && apply_gradient (tmp, id, 1) ? tmp.fill : "#000000";
            }
            st.text_color = fill == "none" ? "#000000" : alpha_hex (fill, parse_fraction (p["fill-opacity"], 1));
            st.opacity = ctx.opacity;
            string anchor = p["text-anchor"] ?? "start";
            st.halign = anchor == "middle" ? TextHAlign.CENTER : (anchor == "end" ? TextHAlign.RIGHT : TextHAlign.LEFT);
            var block = SvgWriter.measure (st, text, 0, false);
            double baseline = block.lines.size > 0 ? block.lines[0].baseline : st.font_size * Units.PX_PER_PT * 0.8;
            double w = block.width + 2, h = double.max (block.height, 1);
            double lx = x;
            if (st.halign == TextHAlign.CENTER) lx = x - w / (2 * sc);
            else if (st.halign == TextHAlign.RIGHT) lx = x - w / sc;
            var s = new Shape ("text");
            s.text = text;
            s.style = st;
            if (seg_lines.size == lines.size) s.markup = rich_markup (seg_lines, lines, st, sc);
            if (s.markup != "") {
                block = SvgWriter.measure (st, text, 0, false, s.rich_runs ());
                baseline = block.lines.size > 0 ? block.lines[0].baseline : baseline;
                w = block.width + 2;
                h = double.max (block.height, 1);
                lx = x;
                if (st.halign == TextHAlign.CENTER) lx = x - w / (2 * sc);
                else if (st.halign == TextHAlign.RIGHT) lx = x - w / sc;
            }
            double top = y - baseline / sc;
            if (!place_box (s, ctx.m, lx, top, w / sc, h / sc)) {
                double ax = lx, ay = top;
                ctx.m.transform_point (ref ax, ref ay);
                s.x = ax;
                s.y = ay;
                s.w = w;
                s.h = h;
            }
            s.w = w;
            s.h = h;
            out_items.add (s);
        }

        private void add_image (Xml.Node* n, Ctx ctx, Gee.List<Item> out_items) {
            string? href = XmlUtil.attr (n, "href") ?? XmlUtil.attr (n, "href", "http://www.w3.org/1999/xlink");
            if (href == null || !href.has_prefix ("data:")) return;
            int comma = href.index_of (",");
            if (comma < 0) return;
            string head = href.substring (5, comma - 5);
            string payload = href.substring (comma + 1);
            bool raster = XmlUtil.attr (n, "data-sdraw-raster") == "1";
            ImageShape img = raster ? (ImageShape) new RasterItem () : new ImageShape ();
            string mime = head.split (";")[0];
            if (head.contains ("base64")) {
                img.bytes = Base64.decode (payload.replace (" ", "").replace ("\n", ""));
            } else {
                string? dec = Uri.unescape_string (payload);
                img.bytes = (dec ?? payload).data;
            }
            if (img.bytes.length == 0) return;
            img.mime = mime != "" ? mime : ImageShape.sniff_mime (img.bytes);
            double x = length (XmlUtil.attr (n, "x"), 0), y = length (XmlUtil.attr (n, "y"), 0);
            double w = length (XmlUtil.attr (n, "width"), 0), h = length (XmlUtil.attr (n, "height"), 0);
            if (w <= 0 || h <= 0) {
                var pix = Renderer.pixbuf_for (img);
                if (pix != null) {
                    if (w <= 0) w = pix.width;
                    if (h <= 0) h = pix.height;
                }
            }
            if (w <= 0 || h <= 0) return;
            if (!place_box (img, ctx.m, x, y, w, h)) {
                var r = new PathData.rect (x, y, w, h).transformed (ctx.m).control_bounds ();
                img.set_bounds (r);
            }
            img.style.opacity = ctx.opacity;
            if (raster) {
                img.style.opacity = 1;
                var l = new Layer ("paint%d".printf (raster_layers.size + 1), XmlUtil.attr_or (n, "data-sdraw-layer", _("Paint Layer %d").printf (raster_layers.size + 1)));
                l.raster = true;
                l.visible = XmlUtil.attr (n, "data-sdraw-hidden") != "1";
                l.locked = XmlUtil.attr (n, "data-sdraw-locked") == "1";
                l.opacity = double.parse (XmlUtil.attr_or (n, "opacity", "1")).clamp (0, 1);
                string st = XmlUtil.attr_or (n, "style", "");
                int bi = st.index_of ("mix-blend-mode:");
                if (bi >= 0) l.blend = BlendMode.from_id (st.substring (bi + 15).split (";")[0]);
                raster_layers.add (l);
                img.layer_id = l.id;
            }
            out_items.add (img);
        }
    }
}
