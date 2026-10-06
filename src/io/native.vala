namespace Singularity.Apps.Draw {

    public class NativeFormat {
        public const string MIME = "application/x-singularity-draw";
        public const string NS = "urn:singularityos:draw:1";

        public static string serialize_items (Gee.List<Item> items) {
            var w = new XmlWriter (true);
            w.start ("sdraw").attr ("xmlns", NS).attr ("version", "1");
            foreach (var it in items) write_item (w, it);
            return w.finish ();
        }

        public static string serialize_document (Document doc) {
            var w = new XmlWriter (true);
            w.start ("sdraw").attr ("xmlns", NS).attr ("version", "1");
            w.attr_num ("grid", doc.grid_size).attr ("units", doc.units).attr ("title", doc.title).attr ("page-index", doc.page_index.to_string ());
            if (doc.theme_id != "") w.attr ("theme", doc.theme_id).attr ("theme-variant", doc.theme_variant.to_string ());
            if (doc.validation_rules != "") w.attr ("validation", doc.validation_rules);
            if (doc.ignored_issues.size > 0) w.attr ("ignored-issues", DataImport.join ("|", doc.ignored_issues));
            if (doc.custom_theme != null) {
                var t = doc.custom_theme;
                w.start ("theme-def").attr ("name", t.name).attr ("dark", t.dark).attr ("light", t.light).attr ("line", t.line)
                    .attr ("accents", string.joinv (" ", t.accents)).attr ("font", t.font).attr ("heading-font", t.heading_font)
                    .attr ("effects", t.effects.to_string ()).attr ("background", t.background).end ();
            }
            foreach (var p in doc.pages) write_page (w, p);
            foreach (var d in doc.data_sources) {
                w.start ("datasource").attr ("id", d.id).attr ("name", d.name).attr ("kind", d.kind).attr ("path", d.path)
                    .attr ("sheet", d.sheet).attr ("query", d.query).attr ("key", d.key_column).attr ("refreshed", d.refreshed.to_string ());
                if (d.table != null) w.element ("data", DataImport.to_csv_table (d.table));
                w.end ();
            }
            foreach (var g in doc.data_graphics) {
                w.start ("datagraphic").attr ("id", g.id).attr ("name", g.name);
                foreach (var gi in g.items) {
                    w.start ("item").attr ("field", gi.field).attr ("kind", gi.kind).attr ("position", gi.position)
                        .attr_num ("min", gi.min, 6).attr_num ("max", gi.max, 6).attr ("color", gi.color).attr ("icon-set", gi.icon_set);
                    foreach (var r in gi.rules) w.start ("rule").attr ("op", r.op).attr ("value", r.value).attr ("color", r.color).attr ("icon", r.icon).end ();
                    w.end ();
                }
                w.end ();
            }
            return w.finish ();
        }

        public static void write_comment (XmlWriter w, Comment c) {
            w.start ("comment").attr ("id", c.id).attr ("author", c.author).attr ("initials", c.initials).attr ("time", c.time.to_string ());
            if (c.item_id != "") w.attr ("item", c.item_id);
            w.attr_num ("x", c.x, 3).attr_num ("y", c.y, 3);
            if (c.resolved) w.attr ("resolved", "1");
            w.element ("text", c.text);
            foreach (var r in c.replies) write_comment (w, r);
            w.end ();
        }

        public static Comment read_comment (Xml.Node* n) {
            var c = new Comment ();
            c.id = XmlUtil.attr_or (n, "id", "");
            c.author = XmlUtil.attr_or (n, "author", "");
            c.initials = XmlUtil.attr_or (n, "initials", "");
            c.time = int64.parse (XmlUtil.attr_or (n, "time", "0"));
            c.item_id = XmlUtil.attr_or (n, "item", "");
            c.x = XmlUtil.attr_double (n, "x", 0);
            c.y = XmlUtil.attr_double (n, "y", 0);
            c.resolved = XmlUtil.attr_or (n, "resolved", "0") == "1";
            foreach (var ch in XmlUtil.children (n)) {
                if (ch->name == "text") c.text = XmlUtil.text (ch);
                else if (ch->name == "comment") c.replies.add (read_comment (ch));
            }
            return c;
        }

        public static void write_page (XmlWriter w, Page p) {
            w.start ("page").attr ("id", p.id).attr ("name", p.name).attr_num ("width", p.width).attr_num ("height", p.height)
                .attr ("background", p.background).attr ("active-layer", p.active_layer);
            if (p.is_background) w.attr ("is-background", "1");
            if (p.back_page != "") w.attr ("back-page", p.back_page);
            if (p.has_scale ()) {
                w.attr_num ("scale-paper", p.scale_paper, 6).attr ("scale-paper-units", p.scale_paper_units)
                    .attr_num ("scale-world", p.scale_world, 6).attr ("scale-units", p.scale_units);
            }
            if (p.jump_style != JumpStyle.ARC) w.attr ("jump-style", p.jump_style.to_id ());
            if (p.jumps_vertical) w.attr ("jumps-vertical", "1");
            if (p.jump_size != 1) w.attr_num ("jump-size", p.jump_size, 3);
            if (p.print_tiles_x > 0 || p.print_tiles_y > 0) w.attr ("print-tiles", "%d %d".printf (p.print_tiles_x, p.print_tiles_y));
            if (p.print_zoom > 0) w.attr_num ("print-zoom", p.print_zoom, 4);
            foreach (var g in p.guides) w.start ("guide").attr ("orientation", g.vertical ? "vertical" : "horizontal").attr_num ("pos", g.pos, 3).end ();
            foreach (var sn in p.snippets) w.start ("snippet").attr ("name", sn.name).attr_num ("x", sn.area.x, 3).attr_num ("y", sn.area.y, 3).attr_num ("width", sn.area.w, 3).attr_num ("height", sn.area.h, 3).end ();
            foreach (var c in p.comments) write_comment (w, c);
            foreach (var l in p.layers) {
                w.start ("layer").attr ("id", l.id).attr ("name", l.name).attr ("visible", l.visible ? "1" : "0")
                    .attr ("locked", l.locked ? "1" : "0").attr ("printable", l.printable ? "1" : "0");
                if (l.raster) w.attr ("raster", "1").attr_num ("opacity", l.opacity, 4).attr ("blend", l.blend.to_id ());
                w.end ();
            }
            foreach (var it in p.items) write_item (w, it);
            w.end ();
        }

        public static string points_to_string (Point[] pts) {
            var sb = new StringBuilder ();
            foreach (var p in pts) {
                if (sb.len > 0) sb.append_c (' ');
                sb.append (PathData.fmt (p.x, 3));
                sb.append_c (',');
                sb.append (PathData.fmt (p.y, 3));
            }
            return sb.str;
        }

        public static Point[] points_from_string (string? s) {
            Point[] pts = {};
            if (s == null) return pts;
            var sc = new PathScanner (s);
            while (true) {
                double x = 0, y = 0;
                if (!sc.number (out x) || !sc.number (out y)) break;
                pts += Point (x, y);
            }
            return pts;
        }

        public static void write_common (XmlWriter w, Item it) {
            w.attr ("id", it.id);
            if (it.name != "") w.attr ("name", it.name);
            if (it.layer_id != "") w.attr ("layer", it.layer_id);
            if (it.locked) w.attr ("locked", "1");
            if (it.container_id != "") w.attr ("container", it.container_id);
            if (it.link != "") w.attr ("link", it.link);
            if (it.data_source != "") w.attr ("data-source", it.data_source);
            if (it.data_key != "") w.attr ("data-key", it.data_key);
            if (it.data_graphic != "") w.attr ("data-graphic", it.data_graphic);
            w.attr ("style", it.style.serialize ());
        }

        public static void write_tail (XmlWriter w, Item it) {
            if (it.text != "") w.element ("text", it.text);
            foreach (var f in it.fields) w.start ("field").attr ("key", f.key).attr ("value", f.value).end ();
            if (it.markup != "" && it.has_rich_text ()) w.element ("markup", it.markup);
            if (it.alt_title != "") w.element ("alt-title", it.alt_title);
            if (it.alt_text != "") w.element ("alt-text", it.alt_text);
            if (it.sheet != null && !it.sheet.is_empty ()) it.sheet.write (w);
        }

        public static void write_item (XmlWriter w, Item it) {
            var g = it as Group;
            if (g != null) {
                w.start ("group");
                write_common (w, g);
                write_tail (w, g);
                foreach (var c in g.children) write_item (w, c);
                w.end ();
                return;
            }
            var c = it as Connector;
            if (c != null) {
                w.start ("connector");
                write_common (w, c);
                w.attr ("route", c.route.to_id ()).attr_num ("label-pos", c.label_pos, 4);
                if (c.jumps) w.attr ("jumps", "1");
                w.attr ("src", c.src.item_id).attr ("src-port", c.src.port.to_string ()).attr_num ("src-x", c.src.x, 3).attr_num ("src-y", c.src.y, 3);
                w.attr ("dst", c.dst.item_id).attr ("dst-port", c.dst.port.to_string ()).attr_num ("dst-x", c.dst.x, 3).attr_num ("dst-y", c.dst.y, 3);
                if (c.waypoints.length > 0) w.attr ("waypoints", points_to_string (c.waypoints));
                write_tail (w, c);
                w.end ();
                return;
            }
            var s = it as Shape;
            if (s == null) return;
            string tag = (s is PathShape) ? "path" : ((s is ImageShape) ? "image" : ((s is TableShape) ? "table" : "shape"));
            w.start (tag);
            write_common (w, s);
            w.attr ("kind", s.kind).attr_num ("x", s.x, 3).attr_num ("y", s.y, 3).attr_num ("w", s.w, 3).attr_num ("h", s.h, 3);
            if (s.rotation != 0) w.attr_num ("rotation", s.rotation, 4);
            if (s.flip_h) w.attr ("flip-h", "1");
            if (s.flip_v) w.attr ("flip-v", "1");
            if (s.custom_ports != null) w.attr ("ports", points_to_string (s.custom_ports));
            if (s.callout_target != "") w.attr ("callout-target", s.callout_target);
            var ps = s as PathShape;
            if (ps != null) {
                w.attr ("d", ps.path.to_svg (3)).attr_num ("natural-w", ps.natural_w, 3).attr_num ("natural-h", ps.natural_h, 3);
                var modes = new StringBuilder ();
                bool annotated = false;
                foreach (var segment in ps.path.segs) {
                    char mode = segment.handle_mode == HandleMode.CORNER ? 'c' : (segment.handle_mode == HandleMode.SMOOTH ? 's' : (segment.handle_mode == HandleMode.SYMMETRIC ? 'z' : 'a'));
                    modes.append_c (mode);
                    if (mode != 'a') annotated = true;
                }
                if (annotated) w.attr ("node-modes", modes.str);
            }
            var img = s as ImageShape;
            if (img != null) w.attr ("mime", img.mime);
            var tb = s as TableShape;
            if (tb != null) {
                w.attr ("rows", tb.rows.to_string ()).attr ("cols", tb.cols.to_string ()).attr ("header", tb.header_row ? "1" : "0").attr ("header-fill", tb.header_fill);
                w.attr ("col-fracs", fracs (tb.col_fracs)).attr ("row-fracs", fracs (tb.row_fracs));
            }
            write_tail (w, s);
            if (img != null) w.element ("data", Base64.encode (img.bytes));
            if (tb != null) foreach (string cell in tb.cells) w.element ("cell", cell);
            var gs = s as GanttShape;
            if (gs != null) gs.write_extra (w);
            w.end ();
        }

        private static string fracs (double[] v) {
            var sb = new StringBuilder ();
            foreach (double d in v) {
                if (sb.len > 0) sb.append_c (' ');
                sb.append (PathData.fmt (d, 6));
            }
            return sb.str;
        }

        private static double[] parse_fracs (string? s, int n) {
            var out_v = new double[n];
            for (int i = 0; i < n; i++) out_v[i] = 1.0 / n;
            if (s == null) return out_v;
            string[] parts = s.strip ().split (" ");
            if (parts.length != n) return out_v;
            for (int i = 0; i < n; i++) out_v[i] = double.parse (parts[i]);
            return out_v;
        }

        public static Gee.ArrayList<Item> parse_items (string text) throws Error {
            var list = new Gee.ArrayList<Item> ();
            Xml.Doc* doc = XmlUtil.parse (text);
            var root = doc->get_root_element ();
            foreach (var n in XmlUtil.children (root)) {
                var it = read_item (n);
                if (it != null) list.add (it);
            }
            delete doc;
            return list;
        }

        public static Document parse_document (string text) throws Error {
            Xml.Doc* xdoc = XmlUtil.parse (text);
            var root = xdoc->get_root_element ();
            if (root->name != "sdraw") {
                delete xdoc;
                throw new FormatError.INVALID ("Not a drawing.");
            }
            var doc = new Document ();
            doc.pages.clear ();
            doc.grid_size = XmlUtil.attr_double (root, "grid", 10);
            doc.units = XmlUtil.attr_or (root, "units", "px");
            doc.title = XmlUtil.attr_or (root, "title", "");
            doc.theme_id = XmlUtil.attr_or (root, "theme", "");
            doc.theme_variant = int.parse (XmlUtil.attr_or (root, "theme-variant", "0"));
            doc.validation_rules = XmlUtil.attr_or (root, "validation", "");
            var tn = XmlUtil.child (root, "theme-def");
            if (tn != null) {
                var t = new Theme ("file", XmlUtil.attr_or (tn, "name", _("Drawing Theme")));
                t.dark = XmlUtil.attr_or (tn, "dark", t.dark);
                t.light = XmlUtil.attr_or (tn, "light", t.light);
                t.line = XmlUtil.attr_or (tn, "line", t.line);
                string[] acc = XmlUtil.attr_or (tn, "accents", "").split (" ");
                if (acc.length == 6) t.accents = acc;
                t.font = XmlUtil.attr_or (tn, "font", t.font);
                t.heading_font = XmlUtil.attr_or (tn, "heading-font", t.heading_font);
                t.effects = int.parse (XmlUtil.attr_or (tn, "effects", "0"));
                t.background = XmlUtil.attr_or (tn, "background", t.background);
                doc.custom_theme = t;
            }
            foreach (string iss in XmlUtil.attr_or (root, "ignored-issues", "").split ("|")) if (iss != "") doc.ignored_issues.add (iss);
            foreach (var dn in XmlUtil.children (root, "datasource")) {
                var d = new DataSource ();
                d.id = XmlUtil.attr_or (dn, "id", "");
                d.name = XmlUtil.attr_or (dn, "name", "");
                d.kind = XmlUtil.attr_or (dn, "kind", "csv");
                d.path = XmlUtil.attr_or (dn, "path", "");
                d.sheet = XmlUtil.attr_or (dn, "sheet", "");
                d.query = XmlUtil.attr_or (dn, "query", "");
                d.key_column = XmlUtil.attr_or (dn, "key", "");
                d.refreshed = int64.parse (XmlUtil.attr_or (dn, "refreshed", "0"));
                var dd = XmlUtil.child (dn, "data");
                if (dd != null) d.table = CsvTable.parse (XmlUtil.text (dd));
                doc.data_sources.add (d);
            }
            foreach (var gn in XmlUtil.children (root, "datagraphic")) {
                var g = new DataGraphic ();
                g.id = XmlUtil.attr_or (gn, "id", "");
                g.name = XmlUtil.attr_or (gn, "name", "");
                foreach (var inode in XmlUtil.children (gn, "item")) {
                    var gi = new DataGraphicItem ();
                    gi.field = XmlUtil.attr_or (inode, "field", "");
                    gi.kind = XmlUtil.attr_or (inode, "kind", "text");
                    gi.position = XmlUtil.attr_or (inode, "position", "top-right");
                    gi.min = XmlUtil.attr_double (inode, "min", 0);
                    gi.max = XmlUtil.attr_double (inode, "max", 100);
                    gi.color = XmlUtil.attr_or (inode, "color", gi.color);
                    gi.icon_set = XmlUtil.attr_or (inode, "icon-set", gi.icon_set);
                    foreach (var rn in XmlUtil.children (inode, "rule")) {
                        var r = new DataGraphicRule ();
                        r.op = XmlUtil.attr_or (rn, "op", ">=");
                        r.value = XmlUtil.attr_or (rn, "value", "");
                        r.color = XmlUtil.attr_or (rn, "color", "");
                        r.icon = XmlUtil.attr_or (rn, "icon", "");
                        gi.rules.add (r);
                    }
                    g.items.add (gi);
                }
                doc.data_graphics.add (g);
            }
            foreach (var pn in XmlUtil.children (root, "page")) {
                var p = new Page (XmlUtil.attr_or (pn, "name", ""));
                p.id = XmlUtil.attr_or (pn, "id", doc.new_page_id ());
                p.width = XmlUtil.attr_double (pn, "width", p.width);
                p.height = XmlUtil.attr_double (pn, "height", p.height);
                p.background = XmlUtil.attr_or (pn, "background", "#ffffff");
                var layers = XmlUtil.children (pn, "layer");
                if (layers.size > 0) p.layers.clear ();
                foreach (var ln in layers) {
                    var l = new Layer (XmlUtil.attr_or (ln, "id", ""), XmlUtil.attr_or (ln, "name", ""));
                    l.visible = XmlUtil.attr_or (ln, "visible", "1") == "1";
                    l.locked = XmlUtil.attr_or (ln, "locked", "0") == "1";
                    l.printable = XmlUtil.attr_or (ln, "printable", "1") == "1";
                    l.raster = XmlUtil.attr_or (ln, "raster", "0") == "1";
                    l.opacity = XmlUtil.attr_double (ln, "opacity", 1).clamp (0, 1);
                    l.blend = BlendMode.from_id (XmlUtil.attr (ln, "blend"));
                    p.layers.add (l);
                }
                p.active_layer = XmlUtil.attr_or (pn, "active-layer", p.layers.size > 0 ? p.layers[0].id : "");
                p.is_background = XmlUtil.attr_or (pn, "is-background", "0") == "1";
                p.back_page = XmlUtil.attr_or (pn, "back-page", "");
                string? su = XmlUtil.attr (pn, "scale-units");
                if (su != null) {
                    p.scale_units = su;
                    p.scale_paper = XmlUtil.attr_double (pn, "scale-paper", 1);
                    p.scale_paper_units = XmlUtil.attr_or (pn, "scale-paper-units", "cm");
                    p.scale_world = XmlUtil.attr_double (pn, "scale-world", 1);
                }
                p.jump_style = JumpStyle.from_id (XmlUtil.attr_or (pn, "jump-style", "arc"));
                p.jumps_vertical = XmlUtil.attr_or (pn, "jumps-vertical", "0") == "1";
                p.jump_size = XmlUtil.attr_double (pn, "jump-size", 1);
                string[] tiles = XmlUtil.attr_or (pn, "print-tiles", "0 0").split (" ");
                if (tiles.length == 2) {
                    p.print_tiles_x = int.parse (tiles[0]);
                    p.print_tiles_y = int.parse (tiles[1]);
                }
                p.print_zoom = XmlUtil.attr_double (pn, "print-zoom", 0);
                foreach (var gn in XmlUtil.children (pn, "guide")) p.guides.add (new PageGuide (XmlUtil.attr_or (gn, "orientation", "") == "vertical", XmlUtil.attr_double (gn, "pos", 0)));
                foreach (var sn in XmlUtil.children (pn, "snippet")) p.snippets.add (new Snippet (XmlUtil.attr_or (sn, "name", ""), Rect (XmlUtil.attr_double (sn, "x", 0), XmlUtil.attr_double (sn, "y", 0), XmlUtil.attr_double (sn, "width", 0), XmlUtil.attr_double (sn, "height", 0))));
                foreach (var cn in XmlUtil.children (pn, "comment")) p.comments.add (read_comment (cn));
                foreach (var n in XmlUtil.children (pn)) {
                    var it = read_item (n);
                    if (it != null) p.items.add (it);
                }
                doc.pages.add (p);
            }
            if (doc.pages.size == 0) doc.pages.add (new Page (_("Page 1")));
            doc.page_index = int.parse (XmlUtil.attr_or (root, "page-index", "0")).clamp (0, doc.pages.size - 1);
            delete xdoc;
            doc.sync_ids ();
            doc.ensure_ids ();
            foreach (var p in doc.pages) Router.route_all (p);
            return doc;
        }

        private static void read_common (Xml.Node* n, Item it) {
            it.id = XmlUtil.attr_or (n, "id", "");
            it.name = XmlUtil.attr_or (n, "name", "");
            it.layer_id = XmlUtil.attr_or (n, "layer", "");
            it.locked = XmlUtil.attr_or (n, "locked", "0") == "1";
            it.container_id = XmlUtil.attr_or (n, "container", "");
            it.link = XmlUtil.attr_or (n, "link", "");
            it.data_source = XmlUtil.attr_or (n, "data-source", "");
            it.data_key = XmlUtil.attr_or (n, "data-key", "");
            it.data_graphic = XmlUtil.attr_or (n, "data-graphic", "");
            string? st = XmlUtil.attr (n, "style");
            if (st != null) it.style = Style.deserialize (st);
            foreach (var c in XmlUtil.children (n)) {
                if (c->name == "text") it.text = XmlUtil.text (c);
                else if (c->name == "field") it.fields.add (new DataField (XmlUtil.attr_or (c, "key", ""), XmlUtil.attr_or (c, "value", "")));
                else if (c->name == "alt-title") it.alt_title = XmlUtil.text (c);
                else if (c->name == "markup") it.markup = XmlUtil.text (c);
                else if (c->name == "alt-text") it.alt_text = XmlUtil.text (c);
                else if (c->name == "sheet") it.sheet = ShapeSheet.read (c);
            }
        }

        public static Item? read_item (Xml.Node* n) {
            switch (n->name) {
                case "group":
                    var g = new Group ();
                    read_common (n, g);
                    foreach (var c in XmlUtil.children (n)) {
                        var child = read_item (c);
                        if (child != null) g.children.add (child);
                    }
                    return g;
                case "connector":
                    var c = new Connector ();
                    read_common (n, c);
                    c.route = RouteKind.from_id (XmlUtil.attr_or (n, "route", "orthogonal"));
                    c.label_pos = XmlUtil.attr_double (n, "label-pos", 0.5);
                    c.jumps = XmlUtil.attr_or (n, "jumps", "0") == "1";
                    c.src.item_id = XmlUtil.attr_or (n, "src", "");
                    c.src.port = int.parse (XmlUtil.attr_or (n, "src-port", "-1"));
                    c.src.x = XmlUtil.attr_double (n, "src-x", 0);
                    c.src.y = XmlUtil.attr_double (n, "src-y", 0);
                    c.dst.item_id = XmlUtil.attr_or (n, "dst", "");
                    c.dst.port = int.parse (XmlUtil.attr_or (n, "dst-port", "-1"));
                    c.dst.x = XmlUtil.attr_double (n, "dst-x", 0);
                    c.dst.y = XmlUtil.attr_double (n, "dst-y", 0);
                    c.waypoints = points_from_string (XmlUtil.attr (n, "waypoints"));
                    return c;
                case "shape":
                case "path":
                case "image":
                case "table":
                    Shape s;
                    if (n->name == "path") {
                        var ps = new PathShape ();
                        ps.path = PathData.parse_svg (XmlUtil.attr_or (n, "d", ""));
                        string modes = XmlUtil.attr_or (n, "node-modes", "");
                        if (modes.length == ps.path.segs.size) {
                            for (int i = 0; i < modes.length; i++) {
                                char mode = modes[i];
                                ps.path.segs[i].handle_mode = mode == 'c' ? HandleMode.CORNER : (mode == 's' ? HandleMode.SMOOTH : (mode == 'z' ? HandleMode.SYMMETRIC : HandleMode.AUTO));
                            }
                        }
                        ps.natural_w = XmlUtil.attr_double (n, "natural-w", 1);
                        ps.natural_h = XmlUtil.attr_double (n, "natural-h", 1);
                        s = ps;
                    } else if (n->name == "image") {
                        ImageShape img = XmlUtil.attr_or (n, "kind", "") == "raster" ? (ImageShape) new RasterItem () : new ImageShape ();
                        img.mime = XmlUtil.attr_or (n, "mime", "image/png");
                        var dn = XmlUtil.child (n, "data");
                        if (dn != null) img.bytes = Base64.decode (XmlUtil.text (dn).strip ());
                        s = img;
                    } else if (n->name == "table") {
                        int rows = int.parse (XmlUtil.attr_or (n, "rows", "1")).clamp (1, 500);
                        int cols = int.parse (XmlUtil.attr_or (n, "cols", "1")).clamp (1, 100);
                        var tb = new TableShape (rows, cols);
                        tb.header_row = XmlUtil.attr_or (n, "header", "1") == "1";
                        tb.header_fill = XmlUtil.attr_or (n, "header-fill", tb.header_fill);
                        tb.col_fracs = parse_fracs (XmlUtil.attr (n, "col-fracs"), cols);
                        tb.row_fracs = parse_fracs (XmlUtil.attr (n, "row-fracs"), rows);
                        int i = 0;
                        foreach (var cn in XmlUtil.children (n, "cell")) {
                            if (i < tb.cells.size) tb.cells[i] = XmlUtil.text (cn);
                            i++;
                        }
                        s = tb;
                    } else if (XmlUtil.attr_or (n, "kind", "") == "sheet") {
                        s = new SheetShape ();
                    } else if (XmlUtil.attr_or (n, "kind", "") == "gantt") {
                        s = new GanttShape ();
                    } else {
                        s = new Shape ();
                    }
                    read_common (n, s);
                    s.kind = XmlUtil.attr_or (n, "kind", s.kind);
                    s.x = XmlUtil.attr_double (n, "x", 0);
                    s.y = XmlUtil.attr_double (n, "y", 0);
                    s.w = XmlUtil.attr_double (n, "w", 100);
                    s.h = XmlUtil.attr_double (n, "h", 60);
                    s.rotation = XmlUtil.attr_double (n, "rotation", 0);
                    s.flip_h = XmlUtil.attr_or (n, "flip-h", "0") == "1";
                    s.flip_v = XmlUtil.attr_or (n, "flip-v", "0") == "1";
                    string? pts = XmlUtil.attr (n, "ports");
                    if (pts != null) s.custom_ports = points_from_string (pts);
                    s.callout_target = XmlUtil.attr_or (n, "callout-target", "");
                    var gs = s as GanttShape;
                    if (gs != null) gs.read_extra (n);
                    return s;
                default:
                    return null;
            }
        }
    }
}
