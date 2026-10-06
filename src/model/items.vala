namespace Singularity.Apps.Draw {

    public class DataField {
        public string key;
        public string value;

        public DataField (string key, string value) {
            this.key = key;
            this.value = value;
        }
    }

    public abstract class Item : Object {
        public string id = "";
        public string name = "";
        public string layer_id = "";
        public string text = "";
        public Style style = new Style ();
        public bool locked = false;
        public string container_id = "";
        public string link = "";
        public Gee.ArrayList<DataField> fields = new Gee.ArrayList<DataField> ();
        public string alt_title = "";
        public string alt_text = "";
        public string markup = "";
        public ShapeSheet? sheet = null;
        public string data_source = "";
        public string data_key = "";
        public string data_graphic = "";

        public abstract Item clone ();
        public abstract Rect bounds ();
        public abstract void move_by (double dx, double dy);
        public abstract bool hit (double px, double py, double tolerance);

        protected void copy_base (Item dst) {
            dst.id = id;
            dst.name = name;
            dst.layer_id = layer_id;
            dst.text = text;
            dst.style = style.copy ();
            dst.locked = locked;
            dst.container_id = container_id;
            dst.link = link;
            foreach (var f in fields) dst.fields.add (new DataField (f.key, f.value));
            dst.alt_title = alt_title;
            dst.alt_text = alt_text;
            dst.markup = markup;
            dst.sheet = sheet != null ? sheet.copy () : null;
            dst.data_source = data_source;
            dst.data_key = data_key;
            dst.data_graphic = data_graphic;
        }

        public string? get_field (string key) {
            foreach (var f in fields) if (f.key == key) return f.value;
            return null;
        }

        public void set_field (string key, string value) {
            foreach (var f in fields) {
                if (f.key == key) {
                    f.value = value;
                    return;
                }
            }
            fields.add (new DataField (key, value));
        }

        public void remove_field (string key) {
            for (int i = 0; i < fields.size; i++) {
                if (fields[i].key == key) {
                    fields.remove_at (i);
                    return;
                }
            }
        }

        public bool has_rich_text () {
            if (markup == "") return false;
            string plain;
            try {
                Pango.parse_markup (markup, -1, 0, null, out plain, null);
            } catch (Error e) {
                return false;
            }
            return plain == text;
        }

        public Gee.ArrayList<TextRun>? rich_runs () {
            if (!has_rich_text ()) return null;
            var runs = RichRuns.parse (markup);
            return RichRuns.any_format (runs) ? runs : null;
        }

        public string display_text () {
            if (fields.size == 0 || !text.contains ("{")) return text;
            var sb = new StringBuilder ();
            int i = 0;
            while (i < text.length) {
                if (text[i] == '{') {
                    int close = text.index_of ("}", i);
                    if (close > i) {
                        string key = text.substring (i + 1, close - i - 1);
                        string? v = get_field (key);
                        if (v != null) {
                            sb.append (v);
                            i = close + 1;
                            continue;
                        }
                    }
                }
                sb.append_c (text[i]);
                i++;
            }
            return sb.str;
        }
    }

    public class Shape : Item {
        public string kind = "rectangle";
        public double x;
        public double y;
        public double w = 120;
        public double h = 60;
        public double rotation = 0;
        public bool flip_h = false;
        public bool flip_v = false;
        public Point[]? custom_ports = null;
        public string callout_target = "";

        public Shape (string kind = "rectangle", double x = 0, double y = 0, double w = 120, double h = 60) {
            this.kind = kind;
            this.x = x;
            this.y = y;
            this.w = w;
            this.h = h;
        }

        protected void copy_shape (Shape dst) {
            copy_base (dst);
            dst.kind = kind;
            dst.x = x;
            dst.y = y;
            dst.w = w;
            dst.h = h;
            dst.rotation = rotation;
            dst.flip_h = flip_h;
            dst.flip_v = flip_v;
            dst.custom_ports = custom_ports;
            dst.callout_target = callout_target;
        }

        public override Item clone () {
            var s = new Shape (kind);
            copy_shape (s);
            return s;
        }

        public Cairo.Matrix transform () {
            var m = Cairo.Matrix.identity ();
            m.translate (x + w / 2, y + h / 2);
            if (rotation != 0) m.rotate (rotation * Math.PI / 180);
            m.scale (flip_h ? -1 : 1, flip_v ? -1 : 1);
            m.translate (-w / 2, -h / 2);
            return m;
        }

        public Point to_page (double lx, double ly) {
            var m = transform ();
            m.transform_point (ref lx, ref ly);
            return Point (lx, ly);
        }

        public Point to_local (double px, double py) {
            var m = transform ();
            if (m.invert () != Cairo.Status.SUCCESS) return Point (px - x, py - y);
            m.transform_point (ref px, ref py);
            return Point (px, py);
        }

        public double cx () {
            return x + w / 2;
        }

        public double cy () {
            return y + h / 2;
        }

        public Rect box () {
            return Rect (x, y, w, h);
        }

        public override Rect bounds () {
            if (rotation == 0) return Rect (x, y, w, h);
            var r = Rect.empty ();
            double[] xs = { 0, w, w, 0 };
            double[] ys = { 0, 0, h, h };
            for (int i = 0; i < 4; i++) {
                var p = to_page (xs[i], ys[i]);
                r = r.include (p.x, p.y);
            }
            return r;
        }

        public override void move_by (double dx, double dy) {
            x += dx;
            y += dy;
        }

        public virtual Geometry geometry () {
            return ShapeLibrary.build (kind, w, h, style);
        }

        public PathData outline () {
            var g = geometry ();
            var p = new PathData ();
            foreach (var part in g.parts) if (part.mode == PartMode.FILL_STROKE || part.mode == PartMode.FILL_ONLY) p.append (part.path);
            if (p.is_empty ()) foreach (var part in g.parts) p.append (part.path);
            return p;
        }

        public PathData page_outline () {
            return outline ().transformed (transform ());
        }

        public override bool hit (double px, double py, double tolerance) {
            var l = to_local (px, py);
            if (l.x < -tolerance || l.y < -tolerance || l.x > w + tolerance || l.y > h + tolerance) return false;
            var g = geometry ();
            bool filled = style.has_fill () || text != "" || this is ImageShape || this is TableShape;
            foreach (var part in g.parts) {
                if (part.mode != PartMode.STROKE && (filled || part.mode == PartMode.FILL_DARK) && part.path.contains (l.x, l.y)) return true;
                if (part.path.distance_to (l.x, l.y) <= tolerance + style.stroke_width / 2) return true;
            }
            if (g.parts.size == 0 || kind == "text") return l.x >= 0 && l.y >= 0 && l.x <= w && l.y <= h;
            return false;
        }

        public bool is_container () {
            return ShapeLibrary.is_container (kind);
        }

        public Point[] ports () {
            if (custom_ports != null) return custom_ports;
            return ShapeLibrary.ports (kind, w, h);
        }

        public Point port_point (int i) {
            var ps = ports ();
            if (i < 0 || i >= ps.length) return Point (cx (), cy ());
            return to_page (ps[i].x * w, ps[i].y * h);
        }

        public Point port_direction (int i) {
            var ps = ports ();
            if (i < 0 || i >= ps.length) return Point (0, 0);
            double nx = ps[i].x - 0.5, ny = ps[i].y - 0.5;
            if (flip_h) nx = -nx;
            if (flip_v) ny = -ny;
            Point d;
            if (nx.abs () > ny.abs () + 1e-9) d = Point (nx > 0 ? 1 : -1, 0);
            else if (ny.abs () > 1e-9) d = Point (0, ny > 0 ? 1 : -1);
            else d = Point (0, -1);
            if (rotation != 0) {
                double a = rotation * Math.PI / 180;
                d = Point (d.x * Math.cos (a) - d.y * Math.sin (a), d.x * Math.sin (a) + d.y * Math.cos (a));
            }
            return d;
        }

        public void set_bounds (Rect r) {
            x = r.x;
            y = r.y;
            w = double.max (r.w, 0);
            h = double.max (r.h, 0);
        }
    }

    public class PathShape : Shape {
        public PathData path = new PathData ();
        public double natural_w = 1;
        public double natural_h = 1;

        public PathShape () {
            base ("path");
        }

        public override Item clone () {
            var s = new PathShape ();
            copy_shape (s);
            s.path = path.copy ();
            s.natural_w = natural_w;
            s.natural_h = natural_h;
            return s;
        }

        public bool is_closed () {
            return path.has_closed_subpath ();
        }

        public PathData local_path () {
            double sx = natural_w > 1e-6 ? w / natural_w : 1;
            double sy = natural_h > 1e-6 ? h / natural_h : 1;
            var p = path.copy ();
            if (sx != 1 || sy != 1) p.scale (sx, sy);
            return p;
        }

        public override Geometry geometry () {
            var g = new Geometry ();
            g.parts.add (new GeomPart (local_path (), is_closed () ? PartMode.FILL_STROKE : PartMode.STROKE));
            g.text_rect = Rect (0, 0, w, h);
            return g;
        }

        public void set_page_path (PathData page_path) {
            var b = page_path.bounds ();
            if (b.is_empty ()) b = Rect (0, 0, 0, 0);
            var p = page_path.copy ();
            p.translate (-b.x, -b.y);
            path = p;
            x = b.x;
            y = b.y;
            w = b.w;
            h = b.h;
            natural_w = b.w;
            natural_h = b.h;
            rotation = 0;
            flip_h = false;
            flip_v = false;
        }

        public PathData page_path () {
            return local_path ().transformed (transform ());
        }

        public void normalize () {
            set_page_path (page_path ());
        }
    }

    public class ImageShape : Shape {
        public uint8[] bytes = {};
        public string mime = "image/png";
        public Object? cache = null;
        public int pixel_width = 0;
        public int pixel_height = 0;

        public ImageShape () {
            base ("image");
            style.fill_kind = FillKind.NONE;
            style.stroke = "none";
            style.stroke_width = 0;
        }

        public override Item clone () {
            var s = new ImageShape ();
            copy_shape (s);
            s.bytes = bytes;
            s.mime = mime;
            s.cache = cache;
            s.pixel_width = pixel_width;
            s.pixel_height = pixel_height;
            return s;
        }

        public string extension () {
            switch (mime) {
                case "image/jpeg": return "jpg";
                case "image/gif": return "gif";
                case "image/svg+xml": return "svg";
                case "image/webp": return "webp";
                case "image/bmp": return "bmp";
                default: return "png";
            }
        }

        public static string sniff_mime (uint8[] d) {
            if (d.length >= 8 && d[0] == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G') return "image/png";
            if (d.length >= 3 && d[0] == 0xff && d[1] == 0xd8 && d[2] == 0xff) return "image/jpeg";
            if (d.length >= 6 && d[0] == 'G' && d[1] == 'I' && d[2] == 'F') return "image/gif";
            if (d.length >= 12 && d[0] == 'R' && d[1] == 'I' && d[2] == 'F' && d[3] == 'F' && d[8] == 'W' && d[9] == 'E') return "image/webp";
            if (d.length >= 2 && d[0] == 'B' && d[1] == 'M') return "image/bmp";
            if (d.length >= 5) {
                var sb = new StringBuilder ();
                for (int i = 0; i < int.min (d.length, 256); i++) sb.append_c ((char) d[i]);
                if (sb.str.contains ("<svg") || sb.str.has_prefix ("<?xml")) return "image/svg+xml";
            }
            return "image/png";
        }
    }

    public class TableShape : Shape {
        public int rows = 3;
        public int cols = 3;
        public Gee.ArrayList<string> cells = new Gee.ArrayList<string> ();
        public double[] col_fracs = {};
        public double[] row_fracs = {};
        public bool header_row = true;
        public string header_fill = "#dde9f1";

        public TableShape (int rows = 3, int cols = 3) {
            base ("table");
            resize_grid (rows, cols);
            style.fill = "#ffffff";
            style.halign = TextHAlign.LEFT;
            style.stroke_width = 1;
        }

        public void resize_grid (int nrows, int ncols) {
            var old = new Gee.ArrayList<string> ();
            old.add_all (cells);
            int orows = rows, ocols = cols;
            cells.clear ();
            for (int r = 0; r < nrows; r++) {
                for (int c = 0; c < ncols; c++) {
                    string v = "";
                    if (r < orows && c < ocols && r * ocols + c < old.size) v = old[r * ocols + c];
                    cells.add (v);
                }
            }
            rows = nrows;
            cols = ncols;
            col_fracs = new double[ncols];
            row_fracs = new double[nrows];
            for (int c = 0; c < ncols; c++) col_fracs[c] = 1.0 / ncols;
            for (int r = 0; r < nrows; r++) row_fracs[r] = 1.0 / nrows;
        }

        public string get_cell (int r, int c) {
            int i = r * cols + c;
            return i >= 0 && i < cells.size ? cells[i] : "";
        }

        public void set_cell (int r, int c, string v) {
            int i = r * cols + c;
            if (i >= 0 && i < cells.size) cells[i] = v;
        }

        public double col_x (int c) {
            double s = 0;
            for (int i = 0; i < c && i < col_fracs.length; i++) s += col_fracs[i];
            return s * w;
        }

        public double row_y (int r) {
            double s = 0;
            for (int i = 0; i < r && i < row_fracs.length; i++) s += row_fracs[i];
            return s * h;
        }

        public bool cell_at (double lx, double ly, out int row, out int col) {
            row = -1;
            col = -1;
            for (int r = 0; r < rows; r++) {
                if (ly >= row_y (r) && ly <= row_y (r + 1)) row = r;
            }
            for (int c = 0; c < cols; c++) {
                if (lx >= col_x (c) && lx <= col_x (c + 1)) col = c;
            }
            return row >= 0 && col >= 0;
        }

        public override Item clone () {
            var s = new TableShape (1, 1);
            copy_shape (s);
            s.rows = rows;
            s.cols = cols;
            s.cells.clear ();
            s.cells.add_all (cells);
            s.col_fracs = col_fracs;
            s.row_fracs = row_fracs;
            s.header_row = header_row;
            s.header_fill = header_fill;
            return s;
        }

        public override Geometry geometry () {
            var g = new Geometry ();
            g.parts.add (new GeomPart (new PathData.rect (0, 0, w, h), PartMode.FILL_STROKE));
            g.text_rect = Rect (0, 0, w, h);
            return g;
        }
    }

    public class Group : Item {
        public Gee.ArrayList<Item> children = new Gee.ArrayList<Item> ();

        public override Item clone () {
            var g = new Group ();
            copy_base (g);
            foreach (var c in children) g.children.add (c.clone ());
            return g;
        }

        public override Rect bounds () {
            var r = Rect.empty ();
            foreach (var c in children) r = r.union (c.bounds ());
            return r;
        }

        public override void move_by (double dx, double dy) {
            foreach (var c in children) c.move_by (dx, dy);
        }

        public override bool hit (double px, double py, double tolerance) {
            for (int i = children.size - 1; i >= 0; i--) if (children[i].hit (px, py, tolerance)) return true;
            return false;
        }

        public void collect (Gee.List<Item> into) {
            foreach (var c in children) {
                into.add (c);
                var g = c as Group;
                if (g != null) g.collect (into);
            }
        }
    }

    public enum RouteKind {
        STRAIGHT,
        ORTHOGONAL,
        CURVED;

        public string to_id () {
            return this == STRAIGHT ? "straight" : (this == CURVED ? "curved" : "orthogonal");
        }

        public static RouteKind from_id (string s) {
            return s == "straight" ? STRAIGHT : (s == "curved" ? CURVED : ORTHOGONAL);
        }
    }

    public class Endpoint {
        public string item_id = "";
        public int port = -1;
        public double x;
        public double y;

        public Endpoint (double x = 0, double y = 0) {
            this.x = x;
            this.y = y;
        }

        public Endpoint copy () {
            var e = new Endpoint (x, y);
            e.item_id = item_id;
            e.port = port;
            return e;
        }

        public bool attached () {
            return item_id != "";
        }
    }

    public class Connector : Item {
        public Endpoint src = new Endpoint ();
        public Endpoint dst = new Endpoint ();
        public RouteKind route = RouteKind.ORTHOGONAL;
        public Point[] waypoints = {};
        public Point[] points = {};
        public double label_pos = 0.5;
        public bool jumps = false;

        public Connector () {
            style.fill_kind = FillKind.NONE;
            style.arrow_end = ArrowKind.TRIANGLE;
            style.stroke_width = 1.5;
        }

        public override Item clone () {
            var c = new Connector ();
            copy_base (c);
            c.src = src.copy ();
            c.dst = dst.copy ();
            c.route = route;
            c.waypoints = waypoints;
            c.points = points;
            c.label_pos = label_pos;
            c.jumps = jumps;
            return c;
        }

        public override Rect bounds () {
            var r = Rect.empty ();
            if (points.length == 0) {
                r = r.include (src.x, src.y);
                r = r.include (dst.x, dst.y);
                return r;
            }
            foreach (var p in path ().flatten (1)) foreach (var q in p.pts) r = r.include (q.x, q.y);
            return r;
        }

        public override void move_by (double dx, double dy) {
            if (!src.attached ()) {
                src.x += dx;
                src.y += dy;
            }
            if (!dst.attached ()) {
                dst.x += dx;
                dst.y += dy;
            }
            for (int i = 0; i < waypoints.length; i++) {
                waypoints[i].x += dx;
                waypoints[i].y += dy;
            }
            for (int i = 0; i < points.length; i++) {
                points[i].x += dx;
                points[i].y += dy;
            }
        }

        public PathData path () {
            var p = new PathData ();
            if (points.length < 2) {
                p.move_to (src.x, src.y);
                p.line_to (dst.x, dst.y);
                return p;
            }
            if (route == RouteKind.CURVED) return Router.smooth (points);
            p.add_polygon (points, false);
            return p;
        }

        public override bool hit (double px, double py, double tolerance) {
            return path ().distance_to (px, py) <= tolerance + style.stroke_width / 2;
        }

        public Point label_point () {
            var polys = path ().flatten (0.5);
            if (polys.size == 0) return Point ((src.x + dst.x) / 2, (src.y + dst.y) / 2);
            var poly = polys[0];
            double total = poly.length ();
            double target = total * label_pos.clamp (0, 1);
            double acc = 0;
            for (int i = 1; i < poly.pts.length; i++) {
                double l = poly.pts[i - 1].distance (poly.pts[i]);
                if (acc + l >= target && l > 0) {
                    double t = (target - acc) / l;
                    return Point (poly.pts[i - 1].x + (poly.pts[i].x - poly.pts[i - 1].x) * t, poly.pts[i - 1].y + (poly.pts[i].y - poly.pts[i - 1].y) * t);
                }
                acc += l;
            }
            return poly.pts[poly.pts.length - 1];
        }
    }

    public class Layer : Object {
        public string id = "";
        public string name = "";
        public bool visible = true;
        public bool locked = false;
        public bool printable = true;
        public bool raster = false;
        public double opacity = 1;
        public BlendMode blend = BlendMode.NORMAL;

        public Layer (string id, string name) {
            this.id = id;
            this.name = name;
        }

        public Layer copy () {
            var l = new Layer (id, name);
            l.visible = visible;
            l.locked = locked;
            l.printable = printable;
            l.raster = raster;
            l.opacity = opacity;
            l.blend = blend;
            return l;
        }
    }

    public class PageGuide {
        public bool vertical;
        public double pos;

        public PageGuide (bool vertical, double pos) {
            this.vertical = vertical;
            this.pos = pos;
        }
    }

    public class Snippet {
        public string name;
        public Rect area;

        public Snippet (string name, Rect area) {
            this.name = name;
            this.area = area;
        }
    }

    public enum JumpStyle {
        NONE,
        ARC,
        GAP,
        SQUARE;

        public string to_id () {
            switch (this) {
                case NONE: return "none";
                case GAP: return "gap";
                case SQUARE: return "square";
                default: return "arc";
            }
        }

        public static JumpStyle from_id (string s) {
            switch (s) {
                case "none": return NONE;
                case "gap": return GAP;
                case "square": return SQUARE;
                default: return ARC;
            }
        }
    }

    public class Page : Object {
        public string id = "";
        public string name = "";
        public double width = 1122.52;
        public double height = 793.7;
        public string background = "#ffffff";
        public Gee.ArrayList<Item> items = new Gee.ArrayList<Item> ();
        public Gee.ArrayList<Layer> layers = new Gee.ArrayList<Layer> ();
        public string active_layer = "";
        public bool is_background = false;
        public string back_page = "";
        public double scale_paper = 1;
        public string scale_paper_units = "cm";
        public double scale_world = 1;
        public string scale_units = "";
        public Gee.ArrayList<Comment> comments = new Gee.ArrayList<Comment> ();
        public Gee.ArrayList<PageGuide> guides = new Gee.ArrayList<PageGuide> ();
        public Gee.ArrayList<Snippet> snippets = new Gee.ArrayList<Snippet> ();
        public JumpStyle jump_style = JumpStyle.ARC;
        public bool jumps_vertical = false;
        public double jump_size = 1;
        public int print_tiles_x = 0;
        public int print_tiles_y = 0;
        public double print_zoom = 0;
        public Page? back_ref = null;
        public Gee.ArrayList<DataGraphic>? graphics_ref = null;

        public Page (string name = "") {
            this.name = name;
            var l = new Layer ("layer1", _("Layer 1"));
            layers.add (l);
            active_layer = l.id;
        }

        public Page clone () {
            var p = new Page (name);
            p.id = id;
            p.width = width;
            p.height = height;
            p.background = background;
            p.layers.clear ();
            foreach (var l in layers) p.layers.add (l.copy ());
            p.active_layer = active_layer;
            foreach (var i in items) p.items.add (i.clone ());
            p.is_background = is_background;
            p.back_page = back_page;
            p.scale_paper = scale_paper;
            p.scale_paper_units = scale_paper_units;
            p.scale_world = scale_world;
            p.scale_units = scale_units;
            foreach (var c in comments) p.comments.add (c.copy ());
            foreach (var g in guides) p.guides.add (new PageGuide (g.vertical, g.pos));
            foreach (var sn in snippets) p.snippets.add (new Snippet (sn.name, sn.area));
            p.jump_style = jump_style;
            p.jumps_vertical = jumps_vertical;
            p.jump_size = jump_size;
            p.print_tiles_x = print_tiles_x;
            p.print_tiles_y = print_tiles_y;
            p.print_zoom = print_zoom;
            return p;
        }

        public bool has_scale () {
            return scale_units != "" && scale_paper > 0 && scale_world > 0;
        }

        public double scale_ratio () {
            if (!has_scale ()) return 1;
            return (scale_world * Units.mm_per (scale_units)) / (scale_paper * Units.mm_per (scale_paper_units));
        }

        public double to_world (double px) {
            if (!has_scale ()) return px;
            return px / Units.PX_PER_MM * scale_ratio () / Units.mm_per (scale_units);
        }

        public double from_world (double v) {
            if (!has_scale ()) return v;
            return v * Units.mm_per (scale_units) / scale_ratio () * Units.PX_PER_MM;
        }

        public Layer? find_layer (string id) {
            foreach (var l in layers) if (l.id == id) return l;
            return null;
        }

        public Layer? layer_of (Item item) {
            var l = find_layer (item.layer_id);
            return l ?? (layers.size > 0 ? layers[0] : null);
        }

        public bool item_visible (Item item) {
            var l = layer_of (item);
            return l == null || l.visible;
        }

        public bool item_locked (Item item) {
            var l = layer_of (item);
            return item.locked || (l != null && l.locked);
        }

        public bool item_printable (Item item) {
            var l = layer_of (item);
            return l == null || (l.visible && l.printable);
        }

        public Item? find (string id) {
            if (id == "") return null;
            return find_in (items, id);
        }

        private static Item? find_in (Gee.List<Item> list, string id) {
            foreach (var i in list) {
                if (i.id == id) return i;
                var g = i as Group;
                if (g != null) {
                    var r = find_in (g.children, id);
                    if (r != null) return r;
                }
            }
            return null;
        }

        public Group? parent_of (Item item) {
            return parent_in (items, item);
        }

        private static Group? parent_in (Gee.List<Item> list, Item item) {
            foreach (var i in list) {
                var g = i as Group;
                if (g == null) continue;
                if (g.children.contains (item)) return g;
                var r = parent_in (g.children, item);
                if (r != null) return r;
            }
            return null;
        }

        public Gee.List<Item> list_of (Item item) {
            var g = parent_of (item);
            return g != null ? g.children : items;
        }

        public Item top_level (Item item) {
            Item cur = item;
            var g = parent_of (cur);
            while (g != null) {
                cur = g;
                g = parent_of (cur);
            }
            return cur;
        }

        public Gee.ArrayList<Item> all_items () {
            var list = new Gee.ArrayList<Item> ();
            foreach (var i in items) {
                list.add (i);
                var g = i as Group;
                if (g != null) g.collect (list);
            }
            return list;
        }

        public Gee.ArrayList<Connector> connectors () {
            var list = new Gee.ArrayList<Connector> ();
            foreach (var i in all_items ()) {
                var c = i as Connector;
                if (c != null) list.add (c);
            }
            return list;
        }

        public Gee.ArrayList<Connector> connectors_of (string item_id) {
            var list = new Gee.ArrayList<Connector> ();
            foreach (var c in connectors ()) if (c.src.item_id == item_id || c.dst.item_id == item_id) list.add (c);
            return list;
        }

        public Gee.ArrayList<Shape> members_of (Shape container) {
            var list = new Gee.ArrayList<Shape> ();
            foreach (var i in all_items ()) {
                var s = i as Shape;
                if (s != null && s != container && s.container_id == container.id) list.add (s);
            }
            return list;
        }

        public Rect content_bounds () {
            var r = Rect.empty ();
            foreach (var i in items) if (item_visible (i)) r = r.union (i.bounds ());
            return r;
        }

        public Item? hit (double x, double y, double tolerance) {
            for (int i = items.size - 1; i >= 0; i--) {
                var it = items[i];
                if (!item_visible (it)) continue;
                if (it.hit (x, y, tolerance)) return it;
            }
            return null;
        }

        public void remove (Item item) {
            list_of (item).remove (item);
        }
    }
}
