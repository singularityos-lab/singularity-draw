namespace Singularity.Apps.Draw {

    namespace StencilGroup {
        public const string GENERAL = "general";
        public const string BUSINESS = "business";
        public const string SOFTWARE = "software";
        public const string NETWORK = "network";
        public const string CLOUD = "cloud";
        public const string ENGINEERING = "engineering";
        public const string PLANS = "plans";
        public const string SCHEDULE = "schedule";
        public const string CUSTOM = "custom";

        public string label (string id) {
            switch (id) {
                case BUSINESS: return _("Business");
                case SOFTWARE: return _("Software and Database");
                case NETWORK: return _("Network");
                case CLOUD: return _("Cloud");
                case ENGINEERING: return _("Engineering");
                case PLANS: return _("Maps and Floor Plans");
                case SCHEDULE: return _("Schedule");
                case CUSTOM: return _("My Shapes");
                default: return _("General");
            }
        }

        public string[] order () {
            return { GENERAL, BUSINESS, SOFTWARE, NETWORK, CLOUD, ENGINEERING, PLANS, SCHEDULE, CUSTOM };
        }
    }

    public class StencilPart {
        public string d;
        public PartMode mode;
        public string? color;
        public bool fixed_aspect;
        public PathData? cache = null;

        public StencilPart (string d, PartMode mode, string? color, bool fixed_aspect) {
            this.d = d;
            this.mode = mode;
            this.color = color;
            this.fixed_aspect = fixed_aspect;
        }

        public PathData path () {
            if (cache == null) cache = PathData.parse_svg (d);
            return cache;
        }
    }

    public class StencilDef {
        public string kind;
        public string name;
        public string category;
        public double w;
        public double h;
        public string keywords;
        public double vw = 100;
        public double vh = 100;
        public Gee.ArrayList<StencilPart> parts = new Gee.ArrayList<StencilPart> ();
        public double[] text_box = {};
        public Point[] ports = {};
        public string style = "";
        public string text_default = "";
        public bool below = false;
        public bool container = false;
        public bool aspect = false;
        public string world_size = "";

        public StencilDef (string category, string kind, string name, double w, double h, string keywords) {
            this.category = category;
            this.kind = kind;
            this.name = name;
            this.w = w;
            this.h = h;
            this.keywords = keywords;
        }

        public LibEntry entry () {
            return new LibEntry (category, kind, name, w, h, keywords);
        }

        private unowned StencilDef part (string d, PartMode mode, string? color, bool fixed) {
            parts.add (new StencilPart (d, mode, color, fixed || aspect));
            return this;
        }

        public unowned StencilDef box (double vw, double vh) {
            this.vw = vw;
            this.vh = vh;
            return this;
        }

        public unowned StencilDef fill (string d) {
            return part (d, PartMode.FILL_STROKE, null, false);
        }

        public unowned StencilDef line (string d) {
            return part (d, PartMode.STROKE, null, false);
        }

        public unowned StencilDef shade (string d) {
            return part (d, PartMode.FILL_SHADE, null, false);
        }

        public unowned StencilDef dark (string d) {
            return part (d, PartMode.FILL_DARK, null, false);
        }

        public unowned StencilDef solid (string d, string color = "@fill") {
            return part (d, PartMode.FILL_ONLY, color, false);
        }

        public unowned StencilDef ink (string d, string color = "@stroke") {
            return part (d, PartMode.STROKE, color, false);
        }

        public unowned StencilDef glyph (string d, string color = "@stroke") {
            return part (d, PartMode.FILL_ONLY, color, true);
        }

        public unowned StencilDef glyph_line (string d, string color = "@stroke") {
            return part (d, PartMode.STROKE, color, true);
        }

        public unowned StencilDef icon () {
            aspect = true;
            return this;
        }

        public unowned StencilDef label (double x, double y, double w, double h) {
            text_box = { x, y, w, h };
            return this;
        }

        public unowned StencilDef label_below () {
            below = true;
            return this;
        }

        public unowned StencilDef port (double x, double y) {
            Point[] list = ports;
            list += Point (x / vw, y / vh);
            ports = list;
            return this;
        }

        public unowned StencilDef ports_box () {
            ports = { Point (0.5, 0), Point (1, 0.5), Point (0.5, 1), Point (0, 0.5) };
            return this;
        }

        public unowned StencilDef ports_eight () {
            ports = { Point (0.5, 0), Point (1, 0.5), Point (0.5, 1), Point (0, 0.5), Point (0, 0), Point (1, 0), Point (1, 1), Point (0, 1) };
            return this;
        }

        public unowned StencilDef defaults (string serialized_style) {
            style = style == "" ? serialized_style : style + ";" + serialized_style;
            return this;
        }

        public unowned StencilDef text (string t) {
            text_default = t;
            return this;
        }

        public unowned StencilDef as_container () {
            container = true;
            return this;
        }

        public unowned StencilDef real_size (string size) {
            world_size = size;
            return this;
        }

        public void apply_defaults (Style st) {
            if (style != "") st.apply_serialized (style);
        }

        private Cairo.Matrix placement (double w, double h, bool fixed) {
            if (!fixed) return Cairo.Matrix (w / vw, 0, 0, h / vh, 0, 0);
            double sc = double.min (w / vw, h / vh);
            return Cairo.Matrix (sc, 0, 0, sc, (w - vw * sc) / 2, (h - vh * sc) / 2);
        }

        public Geometry build (double w, double h, Style st) {
            var g = new Geometry ();
            double pad = 4;
            foreach (var p in parts) {
                var path = p.path ().transformed (placement (w, h, p.fixed_aspect));
                g.add (path, p.mode, p.color);
            }
            if (below) {
                g.text_rect = Rect (-40, h + 4, w + 80, 20);
            } else if (text_box.length == 4) {
                var m = placement (w, h, aspect);
                double x1 = text_box[0], y1 = text_box[1], x2 = text_box[0] + text_box[2], y2 = text_box[1] + text_box[3];
                m.transform_point (ref x1, ref y1);
                m.transform_point (ref x2, ref y2);
                g.text_rect = Rect (x1, y1, double.max (x2 - x1, 1), double.max (y2 - y1, 1));
            } else {
                g.text_rect = Rect (pad, pad, double.max (w - 2 * pad, 1), double.max (h - 2 * pad, 1));
            }
            return g;
        }
    }

    public class Stencils {
        private static Gee.ArrayList<LibCategory>? _categories = null;
        private static Gee.ArrayList<StencilDef>? _defs = null;
        private static Gee.HashMap<string, StencilDef>? _index = null;
        private static string current = "basic";

        private static void ensure () {
            if (_defs != null) return;
            _defs = new Gee.ArrayList<StencilDef> ();
            _categories = new Gee.ArrayList<LibCategory> ();
            _index = new Gee.HashMap<string, StencilDef> ();
            StencilsGeneral.register ();
            StencilsBusiness.register ();
            StencilsBpmn.register ();
            StencilsUml.register ();
            StencilsDatabase.register ();
            StencilsNetwork.register ();
            StencilsCloud.register ();
            StencilsElectrical.register ();
            StencilsPlans.register ();
            StencilsSchedule.register ();
            StencilsEngineering.register ();
            StencilsEngineeringExtra.register ();
            StencilsBusinessExtra.register ();
            StencilsPlansExtra.register ();
            StencilsGeneralExtra.register ();
        }

        public static void category (string id, string name, string icon, string group) {
            current = id;
            foreach (var c in _categories) if (c.id == id) return;
            _categories.add (new LibCategory (id, name, icon, group));
        }

        public static void use_category (string id) {
            current = id;
        }

        public static unowned StencilDef shape (string kind, string name, double w, double h, string keywords = "") {
            var d = new StencilDef (current, kind, name, w, h, keywords);
            if (_index.has_key (kind)) warning ("draw: duplicate stencil %s", kind);
            _defs.add (d);
            _index[kind] = d;
            unowned StencilDef r = d;
            return r;
        }

        public static Gee.ArrayList<LibCategory> categories () {
            ensure ();
            return _categories;
        }

        public static Gee.ArrayList<StencilDef> all () {
            ensure ();
            return _defs;
        }

        public static StencilDef? find (string kind) {
            ensure ();
            return _index[kind];
        }
    }

    public class StencilMaster {
        public string id = "";
        public string name = "";
        public string keywords = "";
        public double w = 100;
        public double h = 60;
        public string xml = "";

        public Gee.ArrayList<Item> items () {
            try {
                return NativeFormat.parse_items (xml);
            } catch (Error e) {
                return new Gee.ArrayList<Item> ();
            }
        }

        public static StencilMaster from_items (string name, Gee.List<Item> items) {
            var m = new StencilMaster ();
            m.name = name;
            var b = Document.selection_bounds (items);
            var copies = new Gee.ArrayList<Item> ();
            foreach (var it in items) {
                var c = it.clone ();
                if (!b.is_empty ()) c.move_by (-b.x, -b.y);
                copies.add (c);
            }
            m.w = b.is_empty () ? 100 : double.max (b.w, 1);
            m.h = b.is_empty () ? 60 : double.max (b.h, 1);
            m.xml = NativeFormat.serialize_items (copies);
            return m;
        }
    }

    public class UserStencil {
        public string id = "";
        public string name = "";
        public string path = "";
        public bool builtin_custom = false;
        public Gee.ArrayList<StencilMaster> masters = new Gee.ArrayList<StencilMaster> ();

        public StencilMaster? find (string master_id) {
            foreach (var m in masters) if (m.id == master_id) return m;
            return null;
        }

        public string new_master_id () {
            int n = masters.size + 1;
            while (find ("m%d".printf (n)) != null) n++;
            return "m%d".printf (n);
        }

        public string serialize () {
            var w = new XmlWriter (true);
            w.start ("sdstencil").attr ("xmlns", NativeFormat.NS).attr ("version", "1").attr ("id", id).attr ("name", name);
            foreach (var m in masters) {
                w.start ("master").attr ("id", m.id).attr ("name", m.name).attr ("keywords", m.keywords).attr_num ("w", m.w).attr_num ("h", m.h);
                w.element ("items", m.xml);
                w.end ();
            }
            return w.finish ();
        }

        public static UserStencil parse (string text) throws Error {
            Xml.Doc* doc = XmlUtil.parse (text);
            var root = doc->get_root_element ();
            if (root == null || root->name != "sdstencil") {
                delete doc;
                throw new FormatError.INVALID (_("This is not a stencil."));
            }
            var st = new UserStencil ();
            st.id = XmlUtil.attr_or (root, "id", "");
            st.name = XmlUtil.attr_or (root, "name", _("Stencil"));
            foreach (var mn in XmlUtil.children (root, "master")) {
                var m = new StencilMaster ();
                m.id = XmlUtil.attr_or (mn, "id", st.new_master_id ());
                m.name = XmlUtil.attr_or (mn, "name", _("Master"));
                m.keywords = XmlUtil.attr_or (mn, "keywords", "");
                m.w = XmlUtil.attr_double (mn, "w", 100);
                m.h = XmlUtil.attr_double (mn, "h", 60);
                var xn = XmlUtil.child (mn, "items");
                if (xn != null) m.xml = XmlUtil.text (xn);
                st.masters.add (m);
            }
            delete doc;
            return st;
        }
    }

    public class UserStencils {
        private static Gee.ArrayList<UserStencil>? _list = null;
        public static string? dir_override = null;
        public const string MY_SHAPES = "my-shapes";

        public static string dir () {
            if (dir_override != null) return dir_override;
            return Path.build_filename (Environment.get_user_data_dir (), "singularity-draw", "stencils");
        }

        public static Gee.ArrayList<UserStencil> stencils () {
            if (_list == null) reload ();
            return _list;
        }

        public static void reload () {
            _list = new Gee.ArrayList<UserStencil> ();
            try {
                var d = Dir.open (dir ());
                string? name;
                var names = new Gee.ArrayList<string> ();
                while ((name = d.read_name ()) != null) if (name.has_suffix (".sdstencil")) names.add (name);
                names.sort ();
                foreach (string n in names) {
                    string path = Path.build_filename (dir (), n);
                    try {
                        string text;
                        FileUtils.get_contents (path, out text);
                        var st = UserStencil.parse (text);
                        st.path = path;
                        if (st.id == "") st.id = n.substring (0, n.length - ".sdstencil".length);
                        _list.add (st);
                    } catch (Error e) {
                        warning ("draw: stencil %s: %s", n, e.message);
                    }
                }
            } catch (Error e) {
            }
        }

        public static UserStencil? find (string id) {
            foreach (var s in stencils ()) if (s.id == id) return s;
            return null;
        }

        public static UserStencil my_shapes () {
            var s = find (MY_SHAPES);
            if (s != null) return s;
            s = new UserStencil ();
            s.id = MY_SHAPES;
            s.name = _("Favorites");
            stencils ().insert (0, s);
            return s;
        }

        public static string unique_id (string base_name) {
            var sb = new StringBuilder ();
            foreach (char c in base_name.down ().to_utf8 ()) {
                if (c.isalnum ()) sb.append_c (c);
                else if (sb.len > 0 && sb.str[sb.len - 1] != '-') sb.append_c ('-');
            }
            string b = sb.str.strip ();
            while (b.has_suffix ("-")) b = b.substring (0, b.length - 1);
            if (b == "") b = "stencil";
            string id = b;
            int n = 2;
            while (find (id) != null) id = "%s-%d".printf (b, n++);
            return id;
        }

        public static UserStencil create (string name) {
            var s = new UserStencil ();
            s.id = unique_id (name);
            s.name = name;
            stencils ().add (s);
            return s;
        }

        public static void save (UserStencil s) throws Error {
            DirUtils.create_with_parents (dir (), 0755);
            if (s.path == "") s.path = Path.build_filename (dir (), s.id + ".sdstencil");
            var file = File.new_for_path (s.path);
            file.replace_contents (s.serialize ().data, null, false, FileCreateFlags.REPLACE_DESTINATION, null);
        }

        public static void remove (UserStencil s) {
            stencils ().remove (s);
            if (s.path != "") FileUtils.remove (s.path);
        }

        public static UserStencil import_file (string path) throws Error {
            uint8[] data;
            FileUtils.get_data (path, out data);
            UserStencil st;
            string low = path.down ();
            if (low.has_suffix (".sdstencil")) {
                st = UserStencil.parse (Formats.as_text (data));
            } else {
                st = StencilImport.load (data, path);
            }
            string base_name = Path.get_basename (path);
            int dot = base_name.last_index_of (".");
            if (dot > 0) base_name = base_name.substring (0, dot);
            if (st.name == "") st.name = base_name;
            st.id = unique_id (st.name);
            st.path = "";
            stencils ().add (st);
            save (st);
            return st;
        }

        public static UserStencil import_svg_files (string[] paths) throws Error {
            string folder = paths.length > 0 ? Path.get_basename (Path.get_dirname (paths[0])) : "";
            var st = StencilImport.from_svg_files (paths, folder != "" && folder != "." ? folder : _("Imported Shapes"));
            st.id = unique_id (st.name);
            st.path = "";
            stencils ().add (st);
            save (st);
            return st;
        }

        public static string kind_for (UserStencil s, StencilMaster m) {
            return "master:%s/%s".printf (s.id, m.id);
        }

        public static bool split_kind (string kind, out string stencil_id, out string master_id) {
            stencil_id = "";
            master_id = "";
            if (!kind.has_prefix ("master:")) return false;
            string rest = kind.substring (7);
            int slash = rest.last_index_of ("/");
            if (slash <= 0) return false;
            stencil_id = rest.substring (0, slash);
            master_id = rest.substring (slash + 1);
            return true;
        }

        public static StencilMaster? find_master (string kind) {
            string sid, mid;
            if (!split_kind (kind, out sid, out mid)) return null;
            var s = find (sid);
            return s != null ? s.find (mid) : null;
        }

        public static Gee.ArrayList<LibCategory> categories () {
            var list = new Gee.ArrayList<LibCategory> ();
            foreach (var s in stencils ()) {
                var c = new LibCategory ("user:" + s.id, s.name, "draw-shapes-symbolic", StencilGroup.CUSTOM);
                c.user = true;
                list.add (c);
            }
            return list;
        }

        public static Gee.ArrayList<LibEntry> entries () {
            var list = new Gee.ArrayList<LibEntry> ();
            foreach (var s in stencils ()) {
                foreach (var m in s.masters) {
                    var e = new LibEntry ("user:" + s.id, kind_for (s, m), m.name, m.w, m.h, m.keywords);
                    e.master = m;
                    list.add (e);
                }
            }
            return list;
        }

        public static LibEntry? find_entry (string kind) {
            foreach (var e in entries ()) if (e.kind == kind) return e;
            return null;
        }
    }

    public class StencilImport {
        public static bool is_mxlibrary (uint8[] data) {
            string head = Formats.as_text (data.length > 512 ? data[0:512] : data).strip ();
            return head.has_prefix ("<mxlibrary") || head.has_prefix ("[{") || (head.has_prefix ("<?xml") && head.contains ("<mxlibrary"));
        }

        private static string json_text (string text) {
            int a = text.index_of ("<mxlibrary");
            if (a < 0) return text.strip ();
            int b = text.index_of (">", a);
            int e = text.last_index_of ("</mxlibrary>");
            if (b < 0 || e < 0 || e <= b) throw new FormatError.INVALID (_("This is not a draw.io library."));
            return Drawio.decode_entities (text.substring (b + 1, e - b - 1)).strip ();
        }

        public static UserStencil load_mxlibrary (string text) throws Error {
            var parser = new Json.Parser ();
            parser.load_from_data (json_text (text));
            var root = parser.get_root ();
            if (root == null || root.get_node_type () != Json.NodeType.ARRAY) throw new FormatError.INVALID (_("This is not a draw.io library."));
            var st = new UserStencil ();
            int n = 0;
            foreach (var node in root.get_array ().get_elements ()) {
                if (node.get_node_type () != Json.NodeType.OBJECT) continue;
                var o = node.get_object ();
                n++;
                string title = o.has_member ("title") ? o.get_string_member ("title") : "";
                if (title == "") title = _("Shape %d").printf (n);
                var items = new Gee.ArrayList<Item> ();
                if (o.has_member ("xml")) {
                    string xml = o.get_string_member ("xml").strip ();
                    if (!xml.has_prefix ("<")) xml = Drawio.inflate (xml);
                    try {
                        var doc = Drawio.load (xml);
                        items.add_all (doc.page.items);
                    } catch (Error e) {
                        continue;
                    }
                } else if (o.has_member ("data")) {
                    string uri = o.get_string_member ("data");
                    int comma = uri.index_of (",");
                    if (!uri.has_prefix ("data:") || comma < 0) continue;
                    string head = uri.substring (5, comma - 5);
                    string payload = uri.substring (comma + 1);
                    uint8[] bytes = head.contains ("base64") ? Base64.decode (payload) : (Uri.unescape_string (payload) ?? payload).data;
                    if (head.has_prefix ("image/svg")) {
                        var doc = SvgReader.load (Formats.as_text (bytes));
                        items.add_all (doc.page.items);
                    } else {
                        var img = Formats.image_item (bytes, 0, 0);
                        if (o.has_member ("w") && o.has_member ("h")) {
                            img.w = o.get_double_member ("w");
                            img.h = o.get_double_member ("h");
                        }
                        items.add (img);
                    }
                }
                if (items.size == 0) continue;
                var m = StencilMaster.from_items (title, items);
                m.id = st.new_master_id ();
                m.keywords = title.down ();
                st.masters.add (m);
            }
            if (st.masters.size == 0) throw new FormatError.INVALID (_("The library has no shapes."));
            return st;
        }

        public static UserStencil from_svg_files (string[] paths, string name) throws Error {
            var st = new UserStencil ();
            st.name = name;
            foreach (string p in paths) {
                string text;
                FileUtils.get_contents (p, out text);
                var doc = SvgReader.load (text);
                if (doc.page.items.size == 0) continue;
                string title = Path.get_basename (p);
                int dot = title.last_index_of (".");
                if (dot > 0) title = title.substring (0, dot);
                title = title.replace ("_", " ").replace ("-", " ");
                var m = StencilMaster.from_items (title, doc.page.items);
                m.id = st.new_master_id ();
                m.keywords = title.down ();
                st.masters.add (m);
            }
            if (st.masters.size == 0) throw new FormatError.INVALID (_("None of the files has shapes."));
            return st;
        }

        public static UserStencil load (uint8[] data, string path) throws Error {
            if (is_mxlibrary (data)) return load_mxlibrary (Formats.as_text (data));
            var k = Formats.sniff (data, path);
            if (k == FileKind.VSDX) return Vsdx.load_stencil (data);
            if (k == FileKind.VSD) return Vsd.load_stencil (data);
            throw new FormatError.UNSUPPORTED (_("This stencil type is not supported."));
        }
    }
}
