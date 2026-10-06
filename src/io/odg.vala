namespace Singularity.Apps.Draw {

    namespace OdfNs {
        public const string OFFICE = "urn:oasis:names:tc:opendocument:xmlns:office:1.0";
        public const string STYLE = "urn:oasis:names:tc:opendocument:xmlns:style:1.0";
        public const string TEXT = "urn:oasis:names:tc:opendocument:xmlns:text:1.0";
        public const string TABLE = "urn:oasis:names:tc:opendocument:xmlns:table:1.0";
        public const string DRAW = "urn:oasis:names:tc:opendocument:xmlns:drawing:1.0";
        public const string FO = "urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0";
        public const string XLINK = "http://www.w3.org/1999/xlink";
        public const string SVG = "urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0";
        public const string META = "urn:oasis:names:tc:opendocument:xmlns:meta:1.0";
        public const string DC = "http://purl.org/dc/elements/1.1/";
        public const string MANIFEST = "urn:oasis:names:tc:opendocument:xmlns:manifest:1.0";
        public const string XML = "http://www.w3.org/XML/1998/namespace";
        public const string MIME = "application/vnd.oasis.opendocument.graphics";
    }

    public class Odg {
        public static Document load (uint8[] data) throws Error {
            var zip = new ZipReader (data);
            string? content = zip.read_text ("content.xml");
            if (content == null) throw new FormatError.INVALID (_("The drawing has no content."));
            string? styles = zip.read_text ("styles.xml");
            var r = new OdgReader ();
            r.zip = zip;
            return r.read (content, styles);
        }

        public static Document load_flat (string text) throws Error {
            var r = new OdgReader ();
            return r.read (text, null);
        }

        public static uint8[] save (Document doc) throws Error {
            var w = new OdgWriter (doc, false);
            w.build ();
            var zip = new ZipWriter ();
            zip.add_text ("mimetype", OdfNs.MIME, false);
            zip.add_text ("content.xml", w.content_xml ());
            zip.add_text ("styles.xml", w.styles_xml ());
            zip.add_text ("meta.xml", w.meta_xml ());
            foreach (var pic in w.pictures) zip.add (pic.path, pic.bytes, false);
            zip.add_text ("META-INF/manifest.xml", w.manifest_xml ());
            return zip.finish ();
        }

        public static string save_flat (Document doc) throws Error {
            var w = new OdgWriter (doc, true);
            w.build ();
            return w.flat_xml ();
        }

        public static Cairo.Matrix parse_transform (string t) {
            return OdgReader.parse_transform (t);
        }

        public static string kind_to_odf (string kind) {
            switch (kind) {
                case "rectangle": return "rectangle";
                case "rounded-rectangle": return "round-rectangle";
                case "ellipse": return "ellipse";
                case "circle": return "circle";
                case "triangle": return "isosceles-triangle";
                case "right-triangle": return "right-triangle";
                case "diamond": return "diamond";
                case "parallelogram": return "parallelogram";
                case "trapezoid": return "trapezoid";
                case "pentagon": return "pentagon";
                case "hexagon": return "hexagon";
                case "octagon": return "octagon";
                case "star": return "star5";
                case "star4": return "star4";
                case "cross": return "cross";
                case "heart": return "heart";
                case "cloud": return "cloud";
                case "cube": return "cube";
                case "cylinder": return "can";
                case "donut": return "ring";
                case "frame": return "frame";
                case "callout": return "round-rectangular-callout";
                case "arrow-right": return "right-arrow";
                case "arrow-left": return "left-arrow";
                case "arrow-up": return "up-arrow";
                case "arrow-down": return "down-arrow";
                case "arrow-left-right": return "left-right-arrow";
                case "arrow-up-down": return "up-down-arrow";
                case "arrow-quad": return "quad-arrow";
                case "arrow-notched": return "notched-right-arrow";
                case "chevron": return "chevron";
                case "arrow-pentagon": return "pentagon-right";
                case "process": return "flowchart-process";
                case "decision": return "flowchart-decision";
                case "terminator": return "flowchart-terminator";
                case "data": return "flowchart-data";
                case "predefined-process": return "flowchart-predefined-process";
                case "document": return "flowchart-document";
                case "multi-document": return "flowchart-multidocument";
                case "manual-input": return "flowchart-manual-input";
                case "manual-operation": return "flowchart-manual-operation";
                case "preparation": return "flowchart-preparation";
                case "delay": return "flowchart-delay";
                case "display": return "flowchart-display";
                case "database": return "flowchart-magnetic-disk";
                case "direct-access": return "flowchart-direct-access-storage";
                case "stored-data": return "flowchart-stored-data";
                case "internal-storage": return "flowchart-internal-storage";
                case "card": return "flowchart-card";
                case "punched-tape": return "flowchart-punched-tape";
                case "on-page": return "flowchart-connector";
                case "off-page": return "flowchart-off-page-connector";
                case "summing-junction": return "flowchart-summing-junction";
                case "or": return "flowchart-or";
                case "collate": return "flowchart-collate";
                case "sort": return "flowchart-sort";
                case "merge": return "flowchart-merge";
                case "extract": return "flowchart-extract";
                default: return "non-primitive";
            }
        }

        public static string? odf_to_kind (string type) {
            switch (type) {
                case "rectangle": case "mso-spt1": return "rectangle";
                case "round-rectangle": case "mso-spt2": return "rounded-rectangle";
                case "ellipse": return "ellipse";
                case "circle": return "circle";
                case "isosceles-triangle": return "triangle";
                case "right-triangle": return "right-triangle";
                case "diamond": return "diamond";
                case "parallelogram": return "parallelogram";
                case "trapezoid": return "trapezoid";
                case "pentagon": return "pentagon";
                case "hexagon": return "hexagon";
                case "octagon": return "octagon";
                case "star5": return "star";
                case "star4": return "star4";
                case "cross": return "cross";
                case "heart": return "heart";
                case "cloud": return "cloud";
                case "cube": return "cube";
                case "can": return "cylinder";
                case "ring": return "donut";
                case "frame": return "frame";
                case "rectangular-callout": case "round-rectangular-callout": return "callout";
                case "right-arrow": return "arrow-right";
                case "left-arrow": return "arrow-left";
                case "up-arrow": return "arrow-up";
                case "down-arrow": return "arrow-down";
                case "left-right-arrow": return "arrow-left-right";
                case "up-down-arrow": return "arrow-up-down";
                case "quad-arrow": return "arrow-quad";
                case "notched-right-arrow": return "arrow-notched";
                case "chevron": return "chevron";
                case "pentagon-right": return "arrow-pentagon";
                case "flowchart-process": return "process";
                case "flowchart-decision": return "decision";
                case "flowchart-terminator": return "terminator";
                case "flowchart-data": return "data";
                case "flowchart-predefined-process": return "predefined-process";
                case "flowchart-document": return "document";
                case "flowchart-multidocument": return "multi-document";
                case "flowchart-manual-input": return "manual-input";
                case "flowchart-manual-operation": return "manual-operation";
                case "flowchart-preparation": return "preparation";
                case "flowchart-delay": return "delay";
                case "flowchart-display": return "display";
                case "flowchart-magnetic-disk": return "database";
                case "flowchart-direct-access-storage": return "direct-access";
                case "flowchart-stored-data": return "stored-data";
                case "flowchart-internal-storage": return "internal-storage";
                case "flowchart-card": return "card";
                case "flowchart-punched-tape": return "punched-tape";
                case "flowchart-connector": return "on-page";
                case "flowchart-off-page-connector": return "off-page";
                case "flowchart-summing-junction": return "summing-junction";
                case "flowchart-or": return "or";
                case "flowchart-collate": return "collate";
                case "flowchart-sort": return "sort";
                case "flowchart-merge": return "merge";
                case "flowchart-extract": return "extract";
                default: return null;
            }
        }

        public static string enc (string s) {
            return Uri.escape_string (s, null, true);
        }

        public static string dec (string s) {
            return Uri.unescape_string (s) ?? s;
        }

        public static string encode_fields (Gee.List<DataField> fields) {
            var sb = new StringBuilder ();
            foreach (var f in fields) {
                if (sb.len > 0) sb.append_c (';');
                sb.append (enc (f.key));
                sb.append_c ('=');
                sb.append (enc (f.value));
            }
            return sb.str;
        }

        public static void decode_fields (string s, Gee.List<DataField> into) {
            if (s == "") return;
            foreach (string part in s.split (";")) {
                int eq = part.index_of ("=");
                if (eq < 0) continue;
                into.add (new DataField (dec (part.substring (0, eq)), dec (part.substring (eq + 1))));
            }
        }

        public static string encode_layers (Gee.List<Layer> layers) {
            var sb = new StringBuilder ();
            foreach (var l in layers) {
                if (sb.len > 0) sb.append_c (';');
                sb.append ("%s,%s,%s,%s,%s".printf (enc (l.id), enc (l.name), l.visible ? "1" : "0", l.locked ? "1" : "0", l.printable ? "1" : "0"));
                if (l.raster) sb.append (",raster,%s,%s".printf (PathData.fmt (l.opacity, 4), l.blend.to_id ()));
            }
            return sb.str;
        }

        public static void decode_layers (string s, Gee.List<Layer> into) {
            foreach (string part in s.split (";")) {
                string[] f = part.split (",");
                if (f.length < 5) continue;
                var l = new Layer (dec (f[0]), dec (f[1]));
                l.visible = f[2] == "1";
                l.locked = f[3] == "1";
                l.printable = f[4] == "1";
                if (f.length >= 8 && f[5] == "raster") {
                    l.raster = true;
                    l.opacity = double.parse (f[6]).clamp (0, 1);
                    l.blend = BlendMode.from_id (f[7]);
                }
                into.add (l);
            }
        }

        public static string ncname (string id) {
            var sb = new StringBuilder ();
            for (int i = 0; i < id.length; i++) {
                char c = id[i];
                if (c.isalnum () || c == '_' || c == '-' || c == '.') sb.append_c (c);
                else sb.append ("_%02x".printf ((uint8) c));
            }
            string r = sb.str;
            if (r == "" || !(r[0].isalpha () || r[0] == '_')) r = "id_" + r;
            return r;
        }
    }

    public class OdgPicture {
        public string path;
        public uint8[] bytes;
        public string mime;
    }

    private class OdgWriter {
        private Document doc;
        private bool flat;
        private XmlWriter body;
        private StringBuilder autos = new StringBuilder ();
        private StringBuilder common = new StringBuilder ();
        private StringBuilder style_autos = new StringBuilder ();
        private StringBuilder masters = new StringBuilder ();
        private Gee.HashMap<string, string> graphic_names = new Gee.HashMap<string, string> ();
        private Gee.HashMap<string, string> para_names = new Gee.HashMap<string, string> ();
        private Gee.HashMap<string, string> gradient_names = new Gee.HashMap<string, string> ();
        private Gee.HashSet<string> markers = new Gee.HashSet<string> ();
        private Gee.HashSet<string> dashes = new Gee.HashSet<string> ();
        private Gee.HashMap<string, string> layout_masters = new Gee.HashMap<string, string> ();
        private Gee.HashMap<string, string> page_styles = new Gee.HashMap<string, string> ();
        private Gee.HashMap<string, string> col_styles = new Gee.HashMap<string, string> ();
        private Gee.HashMap<string, string> row_styles = new Gee.HashMap<string, string> ();
        private Gee.ArrayList<string> layer_names = new Gee.ArrayList<string> ();
        public Gee.ArrayList<OdgPicture> pictures = new Gee.ArrayList<OdgPicture> ();
        private int pic_count = 0;

        private const string NS_DECL = " xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" xmlns:style=\"urn:oasis:names:tc:opendocument:xmlns:style:1.0\" xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\" xmlns:table=\"urn:oasis:names:tc:opendocument:xmlns:table:1.0\" xmlns:draw=\"urn:oasis:names:tc:opendocument:xmlns:drawing:1.0\" xmlns:fo=\"urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns:meta=\"urn:oasis:names:tc:opendocument:xmlns:meta:1.0\" xmlns:svg=\"urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0\" xmlns:sdraw=\"urn:singularityos:draw:1\" office:version=\"1.3\"";

        public OdgWriter (Document doc, bool flat) {
            this.doc = doc;
            this.flat = flat;
        }

        private static string cm (double px) {
            return Units.cm (px);
        }

        private static string num (double v, int d = 4) {
            return PathData.fmt (v, d);
        }

        public void build () {
            foreach (var p in doc.pages) {
                foreach (var l in p.layers) if (!layer_names.contains (l.name)) layer_names.add (l.name);
            }
            body = new XmlWriter (false, false);
            body.start ("office:body").start ("office:drawing");
            body.attr ("sdraw:grid", num (doc.grid_size)).attr ("sdraw:units", doc.units).attr ("sdraw:title", doc.title).attr ("sdraw:page-index", doc.page_index.to_string ());
            foreach (var p in doc.pages) write_page (p);
            body.end ().end ();
            write_common_defs ();
        }

        private string master_for (Page p) {
            string key = "%s %s".printf (num (p.width, 3), num (p.height, 3));
            if (layout_masters.has_key (key)) return layout_masters[key];
            int n = layout_masters.size + 1;
            string pm = "PM%d".printf (n);
            string master = n == 1 ? "Default" : "Default_%d".printf (n);
            var w = new XmlWriter (false);
            w.start ("style:page-layout").attr ("style:name", pm);
            w.start ("style:page-layout-properties").attr ("fo:margin-top", "0cm").attr ("fo:margin-bottom", "0cm").attr ("fo:margin-left", "0cm")
                .attr ("fo:margin-right", "0cm").attr ("fo:page-width", cm (p.width)).attr ("fo:page-height", cm (p.height))
                .attr ("style:print-orientation", p.width >= p.height ? "landscape" : "portrait").end ();
            w.end ();
            style_autos.append (w.finish ());
            var m = new XmlWriter (false);
            m.start ("style:master-page").attr ("style:name", master).attr ("style:page-layout-name", pm).attr ("draw:style-name", "Mdp1").end ();
            masters.append (m.finish ());
            layout_masters[key] = master;
            return master;
        }

        private string page_style (Page p) {
            string key = p.background;
            if (page_styles.has_key (key)) return page_styles[key];
            string name = "dp%d".printf (page_styles.size + 1);
            var w = new XmlWriter (false);
            w.start ("style:style").attr ("style:name", name).attr ("style:family", "drawing-page");
            w.start ("style:drawing-page-properties").attr ("draw:background-size", "full");
            Rgba c;
            if (Colors.parse (p.background, out c) && c.a > 0) w.attr ("draw:fill", "solid").attr ("draw:fill-color", Colors.to_hex (c));
            else w.attr ("draw:fill", "none");
            w.end ().end ();
            autos.append (w.finish ());
            page_styles[key] = name;
            return name;
        }

        private void write_page (Page p) {
            string master = master_for (p);
            string ps = page_style (p);
            body.start ("draw:page").attr ("draw:name", p.name).attr ("draw:style-name", ps).attr ("draw:master-page-name", master);
            body.attr ("sdraw:id", p.id).attr ("sdraw:width", num (p.width, 4)).attr ("sdraw:height", num (p.height, 4))
                .attr ("sdraw:background", p.background).attr ("sdraw:layers", Odg.encode_layers (p.layers)).attr ("sdraw:active-layer", p.active_layer);
            foreach (var it in p.items) write_item (p, it);
            body.end ();
        }

        private string layer_name (Page p, Item it) {
            var l = p.find_layer (it.layer_id);
            if (l == null && p.layers.size > 0) l = p.layers[0];
            return l != null ? l.name : "layout";
        }

        private void common_attrs (Page p, Item it) {
            body.attr ("draw:layer", layer_name (p, it));
            if (it.name != "") body.attr ("draw:name", it.name);
            body.attr ("sdraw:id", it.id);
            if (it.name != "") body.attr ("sdraw:name", it.name);
            if (it.layer_id != "") body.attr ("sdraw:layer", it.layer_id);
            if (it.locked) body.attr ("sdraw:locked", "1");
            if (it.container_id != "") body.attr ("sdraw:container", it.container_id);
            if (it.link != "") body.attr ("sdraw:link", it.link);
            if (it.fields.size > 0) body.attr ("sdraw:fields", Odg.encode_fields (it.fields));
            body.attr ("sdraw:style", it.style.serialize ());
            if (it.has_rich_text ()) body.attr ("sdraw:markup", it.markup);
        }

        private void id_attrs (Item it) {
            string nc = Odg.ncname (it.id);
            body.attr ("draw:id", nc).attr ("xml:id", nc);
        }

        private void box_attrs (Shape s) {
            if (s.rotation == 0) {
                body.attr ("svg:x", cm (s.x)).attr ("svg:y", cm (s.y));
                body.attr ("svg:width", cm (s.w)).attr ("svg:height", cm (s.h));
                return;
            }
            body.attr ("svg:width", cm (s.w)).attr ("svg:height", cm (s.h));
            double r = s.rotation * Math.PI / 180;
            double cx = s.x + s.w / 2, cy = s.y + s.h / 2;
            double ox = -s.w / 2, oy = -s.h / 2;
            double tx = cx + ox * Math.cos (r) - oy * Math.sin (r);
            double ty = cy + ox * Math.sin (r) + oy * Math.cos (r);
            double a = Document.normalize_angle (360 - s.rotation) * Math.PI / 180;
            body.attr ("draw:transform", "rotate (%s) translate (%s %s)".printf (num (a, 8), cm (tx), cm (ty)));
        }

        private void shape_native (Shape s) {
            body.attr ("sdraw:kind", s.kind);
            body.attr ("sdraw:box", "%s %s %s %s".printf (num (s.x, 4), num (s.y, 4), num (s.w, 4), num (s.h, 4)));
            if (s.rotation != 0) body.attr ("sdraw:rotation", num (s.rotation, 6));
            if (s.flip_h) body.attr ("sdraw:flip-h", "1");
            if (s.flip_v) body.attr ("sdraw:flip-v", "1");
        }

        private void write_item (Page p, Item it) {
            var g = it as Group;
            if (g != null) {
                body.start ("draw:g");
                common_attrs (p, g);
                if (g.text != "") body.attr ("sdraw:text", g.text);
                foreach (var c in g.children) write_item (p, c);
                body.end ();
                return;
            }
            var c = it as Connector;
            if (c != null) {
                write_connector (p, c);
                return;
            }
            var img = it as ImageShape;
            if (img != null) {
                write_image (p, img);
                return;
            }
            var tb = it as TableShape;
            if (tb != null) {
                write_table (p, tb);
                return;
            }
            var ps = it as PathShape;
            if (ps != null) {
                write_path (p, ps);
                return;
            }
            var s = it as Shape;
            if (s != null) write_custom (p, s);
        }

        private void write_custom (Page p, Shape s) {
            body.start ("draw:custom-shape");
            body.attr ("draw:style-name", graphic_style (s.style, false));
            body.attr ("draw:text-style-name", para_style (s.style));
            id_attrs (s);
            box_attrs (s);
            common_attrs (p, s);
            shape_native (s);
            write_text (s.text, s.style, true, false, s.rich_runs ());
            var geo = s.geometry ();
            double vw = double.max (Math.round (s.w * 10), 1), vh = double.max (Math.round (s.h * 10), 1);
            double kx = s.w > 1e-6 ? vw / s.w : 10, ky = s.h > 1e-6 ? vh / s.h : 10;
            var sb = new StringBuilder ();
            foreach (var part in geo.parts) {
                foreach (var seg in part.path.segs) {
                    if (sb.len > 0) sb.append_c (' ');
                    switch (seg.kind) {
                        case SegKind.MOVE: sb.append ("M %s %s".printf (num (seg.x * kx, 1), num (seg.y * ky, 1))); break;
                        case SegKind.LINE: sb.append ("L %s %s".printf (num (seg.x * kx, 1), num (seg.y * ky, 1))); break;
                        case SegKind.CURVE:
                            sb.append ("C %s %s %s %s %s %s".printf (num (seg.x1 * kx, 1), num (seg.y1 * ky, 1), num (seg.x2 * kx, 1),
                                num (seg.y2 * ky, 1), num (seg.x * kx, 1), num (seg.y * ky, 1)));
                            break;
                        case SegKind.CLOSE: sb.append ("Z"); break;
                    }
                }
                if (part.mode == PartMode.STROKE) sb.append (" F");
                else if (part.mode == PartMode.FILL_ONLY) sb.append (" S");
                sb.append (" N");
            }
            var tr = geo.text_rect;
            body.start ("draw:enhanced-geometry").attr ("svg:viewBox", "0 0 %s %s".printf (num (vw, 0), num (vh, 0)));
            body.attr ("draw:type", Odg.kind_to_odf (s.kind));
            body.attr ("draw:text-areas", "%s %s %s %s".printf (num (tr.x * kx, 0), num (tr.y * ky, 0), num ((tr.x + tr.w) * kx, 0), num ((tr.y + tr.h) * ky, 0)));
            if (s.flip_h) body.attr ("draw:mirror-horizontal", "true");
            if (s.flip_v) body.attr ("draw:mirror-vertical", "true");
            if (sb.len > 0) body.attr ("draw:enhanced-path", sb.str);
            body.end ();
            body.end ();
        }

        private void write_path (Page p, PathShape s) {
            double nw = double.max (s.natural_w, 1e-3), nh = double.max (s.natural_h, 1e-3);
            double vw = double.max (Math.round (nw * 100), 1), vh = double.max (Math.round (nh * 100), 1);
            var scaled = s.path.copy ();
            scaled.scale (vw / nw, vh / nh);
            body.start ("draw:path");
            body.attr ("draw:style-name", graphic_style (s.style, !s.is_closed ()));
            body.attr ("draw:text-style-name", para_style (s.style));
            id_attrs (s);
            box_attrs (s);
            body.attr ("svg:viewBox", "0 0 %s %s".printf (num (vw, 0), num (vh, 0)));
            body.attr ("svg:d", scaled.to_svg (0));
            common_attrs (p, s);
            shape_native (s);
            body.attr ("sdraw:d", s.path.to_svg (4));
            body.attr ("sdraw:natural", "%s %s".printf (num (s.natural_w, 4), num (s.natural_h, 4)));
            write_text (s.text, s.style, true, false, s.rich_runs ());
            body.end ();
        }

        private void write_image (Page p, ImageShape img) {
            body.start ("draw:frame");
            body.attr ("draw:style-name", graphic_style (img.style, false));
            id_attrs (img);
            box_attrs (img);
            common_attrs (p, img);
            shape_native (img);
            body.attr ("sdraw:mime", img.mime);
            if (img.text != "") body.attr ("sdraw:text", img.text);
            body.start ("draw:image");
            if (flat) {
                body.start ("office:binary-data").text (Base64.encode (img.bytes)).end ();
            } else {
                var pic = new OdgPicture ();
                pic.path = "Pictures/image%d.%s".printf (++pic_count, img.extension ());
                pic.bytes = img.bytes;
                pic.mime = img.mime;
                pictures.add (pic);
                body.attr ("xlink:href", pic.path).attr ("xlink:type", "simple").attr ("xlink:show", "embed").attr ("xlink:actuate", "onLoad");
                body.attr ("draw:mime-type", img.mime);
            }
            body.end ();
            body.end ();
        }

        private string col_style (double width) {
            string key = num (width, 4);
            if (col_styles.has_key (key)) return col_styles[key];
            string name = "co%d".printf (col_styles.size + 1);
            var w = new XmlWriter (false);
            w.start ("style:style").attr ("style:name", name).attr ("style:family", "table-column");
            w.start ("style:table-column-properties").attr ("style:column-width", cm (width)).end ().end ();
            autos.append (w.finish ());
            col_styles[key] = name;
            return name;
        }

        private string row_style (double height) {
            string key = num (height, 4);
            if (row_styles.has_key (key)) return row_styles[key];
            string name = "ro%d".printf (row_styles.size + 1);
            var w = new XmlWriter (false);
            w.start ("style:style").attr ("style:name", name).attr ("style:family", "table-row");
            w.start ("style:table-row-properties").attr ("style:row-height", cm (height)).end ().end ();
            autos.append (w.finish ());
            row_styles[key] = name;
            return name;
        }

        private static string fracs (double[] v) {
            var sb = new StringBuilder ();
            foreach (double d in v) {
                if (sb.len > 0) sb.append_c (' ');
                sb.append (PathData.fmt (d, 8));
            }
            return sb.str;
        }

        private void write_table (Page p, TableShape t) {
            body.start ("draw:frame");
            body.attr ("draw:style-name", graphic_style (t.style, false));
            id_attrs (t);
            box_attrs (t);
            common_attrs (p, t);
            shape_native (t);
            body.attr ("sdraw:rows", t.rows.to_string ()).attr ("sdraw:cols", t.cols.to_string ());
            body.attr ("sdraw:header", t.header_row ? "1" : "0").attr ("sdraw:header-fill", t.header_fill);
            body.attr ("sdraw:col-fracs", fracs (t.col_fracs)).attr ("sdraw:row-fracs", fracs (t.row_fracs));
            if (t.text != "") body.attr ("sdraw:text", t.text);
            body.start ("table:table");
            if (t.header_row) body.attr ("table:use-first-row-styles", "true");
            for (int c = 0; c < t.cols; c++) body.start ("table:table-column").attr ("table:style-name", col_style (t.col_x (c + 1) - t.col_x (c))).end ();
            for (int r = 0; r < t.rows; r++) {
                bool header = r == 0 && t.header_row;
                if (header) body.start ("table:table-header-rows");
                body.start ("table:table-row").attr ("table:style-name", row_style (t.row_y (r + 1) - t.row_y (r)));
                for (int c = 0; c < t.cols; c++) {
                    body.start ("table:table-cell");
                    write_text (t.get_cell (r, c), t.style, false, true);
                    body.end ();
                }
                body.end ();
                if (header) body.end ();
            }
            body.end ();
            body.end ();
        }

        private void write_connector (Page p, Connector c) {
            body.start ("draw:connector");
            body.attr ("draw:style-name", graphic_style (c.style, true));
            body.attr ("draw:text-style-name", para_style (c.style));
            id_attrs (c);
            string type = c.route == RouteKind.STRAIGHT ? "line" : (c.route == RouteKind.CURVED ? "curve" : "standard");
            body.attr ("draw:type", type);
            Point a = c.points.length > 0 ? c.points[0] : Point (c.src.x, c.src.y);
            Point b = c.points.length > 0 ? c.points[c.points.length - 1] : Point (c.dst.x, c.dst.y);
            body.attr ("svg:x1", cm (a.x)).attr ("svg:y1", cm (a.y)).attr ("svg:x2", cm (b.x)).attr ("svg:y2", cm (b.y));
            if (c.src.attached () && p.find (c.src.item_id) != null) {
                body.attr ("draw:start-shape", Odg.ncname (c.src.item_id));
                if (c.src.port >= 0 && c.src.port < 4) body.attr ("draw:start-glue-point", c.src.port.to_string ());
            }
            if (c.dst.attached () && p.find (c.dst.item_id) != null) {
                body.attr ("draw:end-shape", Odg.ncname (c.dst.item_id));
                if (c.dst.port >= 0 && c.dst.port < 4) body.attr ("draw:end-glue-point", c.dst.port.to_string ());
            }
            common_attrs (p, c);
            body.attr ("sdraw:route", c.route.to_id ()).attr ("sdraw:label-pos", num (c.label_pos, 6));
            if (c.jumps) body.attr ("sdraw:jumps", "1");
            body.attr ("sdraw:src", c.src.item_id).attr ("sdraw:src-port", c.src.port.to_string ())
                .attr ("sdraw:src-pos", "%s %s".printf (num (c.src.x, 4), num (c.src.y, 4)));
            body.attr ("sdraw:dst", c.dst.item_id).attr ("sdraw:dst-port", c.dst.port.to_string ())
                .attr ("sdraw:dst-pos", "%s %s".printf (num (c.dst.x, 4), num (c.dst.y, 4)));
            if (c.waypoints.length > 0) body.attr ("sdraw:waypoints", NativeFormat.points_to_string (c.waypoints));
            write_text (c.text, c.style, true, false, c.rich_runs ());
            body.end ();
        }

        private void write_text (string text, Style st, bool with_style = true, bool always = false, Gee.List<TextRun>? runs = null) {
            if (text == "" && !always) return;
            string? ps = with_style ? para_style (st) : null;
            if (runs != null) {
                foreach (var line in RichRuns.split_lines (runs)) {
                    body.start ("text:p");
                    if (ps != null) body.attr ("text:style-name", ps);
                    foreach (var r in line) {
                        if (r.is_plain ()) {
                            write_line (r.text);
                            continue;
                        }
                        body.start ("text:span").attr ("text:style-name", span_style (st, r));
                        write_line (r.text);
                        body.end ();
                    }
                    body.end ();
                }
                return;
            }
            foreach (string line in text.split ("\n")) {
                body.start ("text:p");
                if (ps != null) body.attr ("text:style-name", ps);
                write_line (line);
                body.end ();
            }
        }

        private Gee.HashMap<string, string> span_names = new Gee.HashMap<string, string> ();

        private string span_style (Style st, TextRun r) {
            string key = r.format_key () + "|" + st.font_family + "|" + num (st.font_size, 3);
            if (span_names.has_key (key)) return span_names[key];
            string name = "T%d".printf (span_names.size + 1);
            var w = new XmlWriter (false);
            w.start ("style:style").attr ("style:name", name).attr ("style:family", "text");
            w.start ("style:text-properties");
            if (r.family != "") w.attr ("fo:font-family", r.family);
            if (r.size > 0 || r.big) w.attr ("fo:font-size", num (r.eff_size (st), 3) + "pt");
            if (r.bold) w.attr ("fo:font-weight", "bold");
            if (r.italic) w.attr ("fo:font-style", "italic");
            if (r.color != "") w.attr ("fo:color", Colors.rgb_hex (r.color));
            if (r.underline) w.attr ("style:text-underline-style", "solid").attr ("style:text-underline-width", "auto").attr ("style:text-underline-color", "font-color");
            if (r.strike) w.attr ("style:text-line-through-style", "solid");
            w.end ().end ();
            autos.append (w.finish ());
            span_names[key] = name;
            return name;
        }

        private void write_line (string line) {
            var buf = new StringBuilder ();
            int n = line.length;
            int i = 0;
            while (i < n) {
                char c = line[i];
                if (c == '\t') {
                    if (buf.len > 0) {
                        body.text (buf.str);
                        buf.truncate ();
                    }
                    body.start ("text:tab").end ();
                    i++;
                    continue;
                }
                if (c == ' ') {
                    int j = i;
                    while (j < n && line[j] == ' ') j++;
                    int run = j - i;
                    bool literal = run == 1 && i > 0 && j < n && line[i - 1] != '\t' && line[j] != '\t';
                    if (literal) {
                        buf.append_c (' ');
                    } else {
                        if (buf.len > 0) {
                            body.text (buf.str);
                            buf.truncate ();
                        }
                        body.start ("text:s");
                        if (run > 1) body.attr ("text:c", run.to_string ());
                        body.end ();
                    }
                    i = j;
                    continue;
                }
                buf.append_c (c);
                i++;
            }
            if (buf.len > 0) body.text (buf.str);
        }

        private string para_style (Style st) {
            string align = st.halign == TextHAlign.LEFT ? "start" : (st.halign == TextHAlign.RIGHT ? "end" : "center");
            if (para_names.has_key (align)) return para_names[align];
            string name = "P%d".printf (para_names.size + 1);
            var w = new XmlWriter (false);
            w.start ("style:style").attr ("style:name", name).attr ("style:family", "paragraph");
            w.start ("style:paragraph-properties").attr ("fo:text-align", align).end ().end ();
            autos.append (w.finish ());
            para_names[align] = name;
            return name;
        }

        private string gradient_name (Style st) {
            string key = "%s|%s|%s|%s".printf (st.fill_kind.to_id (), st.fill, st.fill2, num (st.gradient_angle, 3));
            if (gradient_names.has_key (key)) return gradient_names[key];
            string name = "Sd_gradient_%d".printf (gradient_names.size + 1);
            var w = new XmlWriter (false);
            w.start ("draw:gradient").attr ("draw:name", name).attr ("draw:display-name", "Gradient %d".printf (gradient_names.size + 1));
            w.attr ("draw:style", st.fill_kind == FillKind.RADIAL ? "radial" : "linear");
            if (st.fill_kind == FillKind.RADIAL) w.attr ("draw:cx", "50%").attr ("draw:cy", "50%");
            w.attr ("draw:start-color", Colors.rgb_hex (st.fill)).attr ("draw:end-color", Colors.rgb_hex (st.fill2));
            w.attr ("draw:start-intensity", "100%").attr ("draw:end-intensity", "100%");
            int tenths = (int) Math.round (Document.normalize_angle (90 - st.gradient_angle) * 10) % 3600;
            w.attr ("draw:angle", tenths.to_string ()).attr ("draw:border", "0%");
            w.end ();
            common.append (w.finish ());
            gradient_names[key] = name;
            return name;
        }

        private static string dash_name (DashKind d) {
            return "Sd_" + d.to_id ().replace ("-", "_");
        }

        private static string marker_name (ArrowKind k) {
            return "Sd_" + k.to_id ().replace ("-", "_");
        }

        private string graphic_style (Style st, bool line) {
            var w = new XmlWriter (false);
            w.start ("style:style").attr ("style:name", "@@").attr ("style:family", "graphic").attr ("style:parent-style-name", "standard");
            w.start ("style:graphic-properties");
            Rgba fc;
            bool has_fill = !line && st.fill_kind != FillKind.NONE && (st.fill_kind != FillKind.SOLID || (Colors.parse (st.fill, out fc) && fc.a > 0));
            if (!has_fill) {
                w.attr ("draw:fill", "none");
            } else if (st.fill_kind == FillKind.SOLID) {
                Colors.parse (st.fill, out fc);
                w.attr ("draw:fill", "solid").attr ("draw:fill-color", Colors.to_hex (fc));
                double op = fc.a * st.opacity;
                if (op < 0.999) w.attr ("draw:opacity", "%d%%".printf ((int) Math.round (op * 100)));
            } else {
                w.attr ("draw:fill", "gradient").attr ("draw:fill-gradient-name", gradient_name (st));
                if (st.opacity < 0.999) w.attr ("draw:opacity", "%d%%".printf ((int) Math.round (st.opacity * 100)));
            }
            if (!st.has_stroke ()) {
                w.attr ("draw:stroke", "none");
            } else {
                if (st.dash == DashKind.SOLID) {
                    w.attr ("draw:stroke", "solid");
                } else {
                    dashes.add (st.dash.to_id ());
                    w.attr ("draw:stroke", "dash").attr ("draw:stroke-dash", dash_name (st.dash));
                }
                Rgba sc;
                Colors.parse (st.stroke, out sc);
                w.attr ("svg:stroke-color", Colors.to_hex (sc)).attr ("svg:stroke-width", cm (st.stroke_width));
                double sop = sc.a * st.opacity;
                if (sop < 0.999) w.attr ("svg:stroke-opacity", "%d%%".printf ((int) Math.round (sop * 100)));
                w.attr ("draw:stroke-linejoin", "round");
            }
            double mw = (6 + st.stroke_width * 2.2) * st.arrow_size * 0.9;
            if (st.arrow_start != ArrowKind.NONE) {
                markers.add (st.arrow_start.to_id ());
                w.attr ("draw:marker-start", marker_name (st.arrow_start)).attr ("draw:marker-start-width", cm (mw));
            }
            if (st.arrow_end != ArrowKind.NONE) {
                markers.add (st.arrow_end.to_id ());
                w.attr ("draw:marker-end", marker_name (st.arrow_end)).attr ("draw:marker-end-width", cm (mw));
            }
            if (st.shadow) {
                Rgba shc;
                if (!Colors.parse (st.shadow_color, out shc)) shc = Rgba (0, 0, 0, 0.25);
                w.attr ("draw:shadow", "visible").attr ("draw:shadow-offset-x", cm (st.shadow_dx)).attr ("draw:shadow-offset-y", cm (st.shadow_dy));
                w.attr ("draw:shadow-color", Colors.to_hex (shc)).attr ("draw:shadow-opacity", "%d%%".printf ((int) Math.round (shc.a * 100)));
            } else {
                w.attr ("draw:shadow", "hidden");
            }
            if (!line) {
                w.attr ("draw:textarea-vertical-align", st.valign.to_id ());
                w.attr ("draw:textarea-horizontal-align", "justify");
                w.attr ("draw:auto-grow-height", "false").attr ("draw:auto-grow-width", "false");
                w.attr ("fo:wrap-option", st.wrap ? "wrap" : "no-wrap");
                w.attr ("fo:padding-top", "0.1cm").attr ("fo:padding-bottom", "0.1cm").attr ("fo:padding-left", "0.1cm").attr ("fo:padding-right", "0.1cm");
            }
            w.end ();
            w.start ("style:paragraph-properties").attr ("fo:text-align", st.halign == TextHAlign.LEFT ? "start" : (st.halign == TextHAlign.RIGHT ? "end" : "center")).end ();
            w.start ("style:text-properties");
            w.attr ("fo:font-family", st.font_family).attr ("fo:font-size", num (st.font_size, 3) + "pt");
            w.attr ("fo:font-weight", st.bold ? "bold" : "normal").attr ("fo:font-style", st.italic ? "italic" : "normal");
            w.attr ("fo:color", Colors.rgb_hex (st.text_color));
            w.attr ("style:text-underline-style", st.underline ? "solid" : "none");
            if (st.underline) w.attr ("style:text-underline-width", "auto").attr ("style:text-underline-color", "font-color");
            w.attr ("style:text-line-through-style", st.strike ? "solid" : "none");
            w.end ();
            w.end ();
            string frag = w.finish ();
            if (graphic_names.has_key (frag)) return graphic_names[frag];
            string name = "gr%d".printf (graphic_names.size + 1);
            autos.append (frag.replace ("\"@@\"", "\"" + name + "\""));
            graphic_names[frag] = name;
            return name;
        }

        private void write_common_defs () {
            var w = new XmlWriter (false);
            w.start ("style:default-style").attr ("style:family", "graphic");
            w.start ("style:graphic-properties").attr ("svg:stroke-color", "#2e3436").attr ("draw:fill-color", "#ffffff").end ();
            w.start ("style:text-properties").attr ("fo:font-size", "12pt").end ();
            w.end ();
            w.start ("style:style").attr ("style:name", "standard").attr ("style:family", "graphic");
            w.start ("style:graphic-properties").attr ("draw:stroke", "solid").attr ("svg:stroke-width", "0cm").attr ("svg:stroke-color", "#2e3436")
                .attr ("draw:fill", "solid").attr ("draw:fill-color", "#ffffff").end ();
            w.end ();
            foreach (string d in dashes) {
                var k = DashKind.from_id (d);
                w.start ("draw:stroke-dash").attr ("draw:name", dash_name (k)).attr ("draw:style", "rect");
                switch (k) {
                    case DashKind.DOT:
                        w.attr ("draw:dots1", "1").attr ("draw:dots1-length", "100%").attr ("draw:distance", "200%");
                        break;
                    case DashKind.DASH_DOT:
                        w.attr ("draw:dots1", "1").attr ("draw:dots1-length", "500%").attr ("draw:dots2", "1").attr ("draw:dots2-length", "100%").attr ("draw:distance", "200%");
                        break;
                    case DashKind.DASH_DOT_DOT:
                        w.attr ("draw:dots1", "1").attr ("draw:dots1-length", "500%").attr ("draw:dots2", "2").attr ("draw:dots2-length", "100%").attr ("draw:distance", "200%");
                        break;
                    case DashKind.LONG_DASH:
                        w.attr ("draw:dots1", "1").attr ("draw:dots1-length", "900%").attr ("draw:distance", "400%");
                        break;
                    default:
                        w.attr ("draw:dots1", "1").attr ("draw:dots1-length", "400%").attr ("draw:distance", "300%");
                        break;
                }
                w.end ();
            }
            foreach (string m in markers) {
                var k = ArrowKind.from_id (m);
                string d;
                string vb = "0 0 20 30";
                switch (k) {
                    case ArrowKind.OPEN: d = "M10 0 L20 27 L17 30 L10 10 L3 30 L0 27 Z"; break;
                    case ArrowKind.STEALTH: d = "M10 0 L20 30 L10 22 L0 30 Z"; break;
                    case ArrowKind.TRIANGLE_OPEN: d = "M10 0 L20 30 L0 30 Z M10 8 L4 27 L16 27 Z"; break;
                    case ArrowKind.DIAMOND: d = "M10 0 L20 15 L10 30 L0 15 Z"; break;
                    case ArrowKind.DIAMOND_OPEN: d = "M10 0 L20 15 L10 30 L0 15 Z M10 6 L4 15 L10 24 L16 15 Z"; break;
                    case ArrowKind.CIRCLE: d = new PathData.ellipse (10, 10, 10, 10).to_svg (2); vb = "0 0 20 20"; break;
                    case ArrowKind.CIRCLE_OPEN:
                        var ring = new PathData.ellipse (10, 10, 10, 10);
                        var hole = new PathData.ellipse (10, 10, 6, 6);
                        hole.reverse ();
                        ring.append (hole);
                        d = ring.to_svg (2);
                        vb = "0 0 20 20";
                        break;
                    case ArrowKind.BAR: d = "M0 0 L20 0 L20 4 L0 4 Z"; vb = "0 0 20 4"; break;
                    case ArrowKind.CROWS_FOOT: d = "M0 30 L10 0 L20 30 L18 30 L11 9 L11 30 L9 30 L9 9 L2 30 Z"; break;
                    case ArrowKind.ONE: d = "M0 0 L20 0 L20 3 L0 3 Z M0 10 L20 10 L20 13 L0 13 Z M9 0 L11 0 L11 30 L9 30 Z"; break;
                    default: d = "M10 0 L20 30 L0 30 Z"; break;
                }
                w.start ("draw:marker").attr ("draw:name", marker_name (k)).attr ("draw:display-name", k.to_id ()).attr ("svg:viewBox", vb).attr ("svg:d", d).end ();
            }
            common.prepend (w.finish ());
        }

        private string layer_set () {
            var w = new XmlWriter (false);
            w.start ("draw:layer-set");
            string[] builtin = { "layout", "background", "backgroundobjects", "controls", "measurelines" };
            foreach (string b in builtin) w.start ("draw:layer").attr ("draw:name", b).end ();
            foreach (string n in layer_names) {
                bool dup = false;
                foreach (string b in builtin) if (b == n) dup = true;
                if (dup) continue;
                Layer? found = null;
                foreach (var p in doc.pages) foreach (var l in p.layers) if (l.name == n && found == null) found = l;
                w.start ("draw:layer").attr ("draw:name", n);
                if (found != null) {
                    string display = found.visible ? (found.printable ? "always" : "screen") : (found.printable ? "printer" : "none");
                    w.attr ("draw:display", display);
                    if (found.locked) w.attr ("draw:protected", "true");
                }
                w.end ();
            }
            w.end ();
            return w.finish ();
        }

        private string master_styles () {
            return "<office:master-styles>" + layer_set () + masters.str + "</office:master-styles>";
        }

        private string styles_block () {
            return "<office:styles>" + common.str + "</office:styles>";
        }

        private string style_autos_block () {
            var w = new XmlWriter (false);
            w.start ("style:style").attr ("style:name", "Mdp1").attr ("style:family", "drawing-page");
            w.start ("style:drawing-page-properties").attr ("draw:background-size", "full").attr ("draw:fill", "none").end ().end ();
            return style_autos.str + w.finish ();
        }

        public string content_xml () {
            var sb = new StringBuilder ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
            sb.append ("<office:document-content" + NS_DECL + ">");
            sb.append ("<office:automatic-styles>" + autos.str + "</office:automatic-styles>");
            sb.append (body.finish ());
            sb.append ("</office:document-content>");
            return sb.str;
        }

        public string styles_xml () {
            var sb = new StringBuilder ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
            sb.append ("<office:document-styles" + NS_DECL + ">");
            sb.append (styles_block ());
            sb.append ("<office:automatic-styles>" + style_autos_block () + "</office:automatic-styles>");
            sb.append (master_styles ());
            sb.append ("</office:document-styles>");
            return sb.str;
        }

        private string meta_inner () {
            var w = new XmlWriter (false);
            w.start ("office:meta");
            w.element ("meta:generator", "Singularity Draw");
            if (doc.title != "") w.element ("dc:title", doc.title);
            w.element ("dc:date", new DateTime.now_utc ().format ("%Y-%m-%dT%H:%M:%S"));
            w.end ();
            return w.finish ();
        }

        public string meta_xml () {
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<office:document-meta" + NS_DECL + ">" + meta_inner () + "</office:document-meta>";
        }

        public string manifest_xml () {
            var w = new XmlWriter (true);
            w.start ("manifest:manifest").attr ("xmlns:manifest", OdfNs.MANIFEST).attr ("manifest:version", "1.3");
            w.start ("manifest:file-entry").attr ("manifest:full-path", "/").attr ("manifest:version", "1.3").attr ("manifest:media-type", OdfNs.MIME).end ();
            foreach (string part in new string[] { "content.xml", "styles.xml", "meta.xml" }) {
                w.start ("manifest:file-entry").attr ("manifest:full-path", part).attr ("manifest:media-type", "text/xml").end ();
            }
            foreach (var pic in pictures) w.start ("manifest:file-entry").attr ("manifest:full-path", pic.path).attr ("manifest:media-type", pic.mime).end ();
            w.end ();
            return w.finish ();
        }

        public string flat_xml () {
            var sb = new StringBuilder ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
            sb.append ("<office:document" + NS_DECL + " office:mimetype=\"" + OdfNs.MIME + "\">");
            sb.append (meta_inner ());
            sb.append (styles_block ());
            sb.append ("<office:automatic-styles>" + autos.str + style_autos_block () + "</office:automatic-styles>");
            sb.append (master_styles ());
            sb.append (body.finish ());
            sb.append ("</office:document>");
            return sb.str;
        }
    }

    private class OdfPending {
        public Connector conn;
        public string start_ref;
        public string end_ref;
        public int start_glue;
        public int end_glue;
    }

    private class OdgReader {
        public ZipReader? zip = null;
        private Document doc;
        private Gee.HashMap<string, void*> graphic_styles = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> para_styles = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> text_styles = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> page_layouts = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> master_pages = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> page_styles = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> col_styles = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> row_styles = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> gradients = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, void*> dashes = new Gee.HashMap<string, void*> ();
        private Gee.HashMap<string, string> font_faces = new Gee.HashMap<string, string> ();
        private Gee.ArrayList<void*> layer_nodes = new Gee.ArrayList<void*> ();
        private Xml.Node* default_graphic = null;
        private Gee.HashMap<string, string> ref_ids = new Gee.HashMap<string, string> ();
        private Gee.ArrayList<OdfPending> pending = new Gee.ArrayList<OdfPending> ();
        private Page? cur_page = null;
        private Gee.HashMap<string, string> layer_map = new Gee.HashMap<string, string> ();

        private static string? a (Xml.Node* n, string ns, string name) {
            return XmlUtil.attr (n, name, ns);
        }

        private static double len (Xml.Node* n, string ns, string name, double fallback = 0) {
            string? v = XmlUtil.attr (n, name, ns);
            return v == null ? fallback : Units.parse_length (v, fallback);
        }

        public Document read (string content, string? styles) throws Error {
            Xml.Doc* cdoc = XmlUtil.parse (content);
            Xml.Doc* sdoc = null;
            try {
                if (styles != null) {
                    sdoc = XmlUtil.parse (styles);
                    index_styles (sdoc->get_root_element ());
                }
                var root = cdoc->get_root_element ();
                index_styles (root);
                doc = new Document ();
                doc.pages.clear ();
                var body = XmlUtil.child (root, "body", OdfNs.OFFICE);
                Xml.Node* drawing = null;
                if (body != null) {
                    drawing = XmlUtil.child (body, "drawing", OdfNs.OFFICE);
                    if (drawing == null) drawing = XmlUtil.child (body, "presentation", OdfNs.OFFICE);
                }
                if (drawing == null) throw new FormatError.INVALID (_("The file is not an OpenDocument drawing."));
                string? grid = a (drawing, NativeFormat.NS, "grid");
                if (grid != null) doc.grid_size = double.parse (grid);
                doc.units = a (drawing, NativeFormat.NS, "units") ?? "px";
                doc.title = a (drawing, NativeFormat.NS, "title") ?? "";
                int index = 0;
                foreach (var pn in XmlUtil.children (drawing, "page", OdfNs.DRAW)) {
                    read_page (pn, ++index);
                }
                if (doc.pages.size == 0) {
                    var p = new Page (_("Page 1"));
                    p.id = "page1";
                    doc.pages.add (p);
                }
                string? pi = a (drawing, NativeFormat.NS, "page-index");
                doc.page_index = pi != null ? int.parse (pi).clamp (0, doc.pages.size - 1) : 0;
                if (doc.title == "") {
                    var meta = XmlUtil.find (root, "title", OdfNs.DC);
                    if (meta != null) doc.title = XmlUtil.text (meta);
                }
            } finally {
                delete cdoc;
                if (sdoc != null) delete sdoc;
            }
            doc.sync_ids ();
            doc.ensure_ids ();
            foreach (var p in doc.pages) Router.route_all (p);
            doc.modified = false;
            doc.clear_history ();
            return doc;
        }

        private void index_styles (Xml.Node* root) {
            foreach (var block in XmlUtil.children (root)) {
                string name = block->name;
                if (name == "font-face-decls") {
                    foreach (var ff in XmlUtil.children (block, "font-face", OdfNs.STYLE)) {
                        string? n = a (ff, OdfNs.STYLE, "name");
                        string? fam = a (ff, OdfNs.SVG, "font-family");
                        if (n != null && fam != null) font_faces[n] = fam.replace ("'", "").replace ("\"", "");
                    }
                } else if (name == "styles" || name == "automatic-styles") {
                    foreach (var st in XmlUtil.children (block)) index_style (st);
                } else if (name == "master-styles") {
                    foreach (var mp in XmlUtil.children (block)) {
                        if (mp->name == "master-page") {
                            string? n = a (mp, OdfNs.STYLE, "name");
                            if (n != null) master_pages[n] = mp;
                        } else if (mp->name == "layer-set") {
                            foreach (var l in XmlUtil.children (mp, "layer", OdfNs.DRAW)) layer_nodes.add (l);
                        }
                    }
                } else if (name == "body") {
                    foreach (var dr in XmlUtil.children (block)) {
                        var ls = XmlUtil.child (dr, "layer-set", OdfNs.DRAW);
                        if (ls != null) foreach (var l in XmlUtil.children (ls, "layer", OdfNs.DRAW)) layer_nodes.add (l);
                    }
                }
            }
        }

        private void index_style (Xml.Node* st) {
            string? name = a (st, OdfNs.STYLE, "name") ?? a (st, OdfNs.DRAW, "name");
            switch (st->name) {
                case "default-style":
                    if (a (st, OdfNs.STYLE, "family") == "graphic") default_graphic = st;
                    break;
                case "style":
                    if (name == null) break;
                    string fam = a (st, OdfNs.STYLE, "family") ?? "";
                    switch (fam) {
                        case "graphic": case "presentation": graphic_styles[name] = st; break;
                        case "paragraph": para_styles[name] = st; break;
                        case "text": text_styles[name] = st; break;
                        case "drawing-page": page_styles[name] = st; break;
                        case "table-column": col_styles[name] = st; break;
                        case "table-row": row_styles[name] = st; break;
                    }
                    break;
                case "page-layout":
                    if (name != null) page_layouts[name] = st;
                    break;
                case "gradient":
                    if (name != null) gradients[name] = st;
                    break;
                case "stroke-dash":
                    if (name != null) dashes[name] = st;
                    break;
            }
        }

        private void collect_props (Xml.Node* st, Gee.HashMap<string, string> into, Gee.HashMap<string, void*> family, int depth) {
            if (st == null || depth > 12) return;
            string? parent = a (st, OdfNs.STYLE, "parent-style-name");
            if (parent != null && family.has_key (parent)) collect_props ((Xml.Node*) family[parent], into, family, depth + 1);
            foreach (var pn in XmlUtil.children (st)) {
                if (!pn->name.has_suffix ("-properties")) continue;
                for (Xml.Attr* at = pn->properties; at != null; at = at->next) {
                    into[at->name] = at->children != null ? at->children->get_content () : "";
                }
            }
        }

        private Gee.HashMap<string, string> graphic_props (string? name) {
            var props = new Gee.HashMap<string, string> ();
            if (default_graphic != null) collect_props (default_graphic, props, graphic_styles, 0);
            if (name != null && graphic_styles.has_key (name)) collect_props ((Xml.Node*) graphic_styles[name], props, graphic_styles, 0);
            return props;
        }

        private void merge_style (Gee.HashMap<string, string> props, Gee.HashMap<string, void*> family, string? name) {
            if (name != null && family.has_key (name)) collect_props ((Xml.Node*) family[name], props, family, 0);
        }

        private static double percent (string v) {
            string t = v.strip ();
            if (t.has_suffix ("%")) return double.parse (t.substring (0, t.length - 1)) / 100.0;
            return double.parse (t);
        }

        private static string with_alpha (string hex, double alpha) {
            Rgba c;
            if (!Colors.parse (hex, out c)) return hex;
            c.a = alpha.clamp (0, 1);
            return Colors.to_hex (c, true);
        }

        private ArrowKind arrow_for (string? name) {
            if (name == null || name == "") return ArrowKind.NONE;
            if (name.has_prefix ("Sd_")) {
                var k = ArrowKind.from_id (name.substring (3).replace ("_", "-"));
                if (k != ArrowKind.NONE) return k;
            }
            string n = name.replace ("_20_", " ").down ();
            if (n.contains ("circle") || n.contains ("oval")) return n.contains ("unfilled") ? ArrowKind.CIRCLE_OPEN : ArrowKind.CIRCLE;
            if (n.contains ("diamond") || n.contains ("square 45")) return n.contains ("unfilled") ? ArrowKind.DIAMOND_OPEN : ArrowKind.DIAMOND;
            if (n.contains ("line arrow") || n.contains ("open")) return ArrowKind.OPEN;
            if (n.contains ("stealth") || n.contains ("concave")) return ArrowKind.STEALTH;
            if (n.contains ("unfilled")) return ArrowKind.TRIANGLE_OPEN;
            if (n.contains ("dimension") || n.contains ("line short") || n == "line") return ArrowKind.BAR;
            if (n.contains ("crow")) return ArrowKind.CROWS_FOOT;
            return ArrowKind.TRIANGLE;
        }

        private DashKind dash_for (string? name) {
            if (name == null) return DashKind.DASH;
            if (name.has_prefix ("Sd_")) return DashKind.from_id (name.substring (3).replace ("_", "-"));
            if (!dashes.has_key (name)) return DashKind.DASH;
            Xml.Node* d = (Xml.Node*) dashes[name];
            int dots1 = int.parse (a (d, OdfNs.DRAW, "dots1") ?? "0");
            int dots2 = int.parse (a (d, OdfNs.DRAW, "dots2") ?? "0");
            string l1 = a (d, OdfNs.DRAW, "dots1-length") ?? "";
            double len1 = l1.has_suffix ("%") ? percent (l1) : Units.parse_length (l1, 0) / 2;
            if (dots2 >= 2) return DashKind.DASH_DOT_DOT;
            if (dots2 == 1 && dots1 >= 1) return DashKind.DASH_DOT;
            if (dots1 >= 1 && len1 <= 1.5) return DashKind.DOT;
            if (len1 >= 7) return DashKind.LONG_DASH;
            return DashKind.DASH;
        }

        private void apply_props (Style st, Gee.HashMap<string, string> p, bool line) {
            string fill = p["fill"] ?? (p.has_key ("fill-color") ? "solid" : "");
            if (line) fill = "none";
            switch (fill) {
                case "none":
                    st.fill_kind = FillKind.NONE;
                    break;
                case "gradient":
                    string? gname = p["fill-gradient-name"];
                    if (gname != null && gradients.has_key (gname)) {
                        Xml.Node* g = (Xml.Node*) gradients[gname];
                        string gs = a (g, OdfNs.DRAW, "style") ?? "linear";
                        st.fill_kind = gs == "radial" || gs == "ellipsoid" || gs == "square" || gs == "rectangular" ? FillKind.RADIAL : FillKind.LINEAR;
                        st.fill = a (g, OdfNs.DRAW, "start-color") ?? "#ffffff";
                        st.fill2 = a (g, OdfNs.DRAW, "end-color") ?? "#000000";
                        string ang = a (g, OdfNs.DRAW, "angle") ?? "0";
                        double deg;
                        if (ang.has_suffix ("deg")) deg = double.parse (ang.substring (0, ang.length - 3));
                        else if (ang.has_suffix ("rad")) deg = double.parse (ang.substring (0, ang.length - 3)) * 180 / Math.PI;
                        else if (ang.has_suffix ("grad")) deg = double.parse (ang.substring (0, ang.length - 4)) * 0.9;
                        else deg = double.parse (ang) / 10.0;
                        st.gradient_angle = Document.normalize_angle (90 - deg);
                    } else {
                        st.fill_kind = FillKind.SOLID;
                        st.fill = p["fill-color"] ?? st.fill;
                    }
                    break;
                case "solid":
                case "bitmap":
                case "hatch":
                    st.fill_kind = FillKind.SOLID;
                    if (p.has_key ("fill-color")) st.fill = p["fill-color"];
                    break;
                default:
                    break;
            }
            if (p.has_key ("opacity") && st.fill_kind == FillKind.SOLID) {
                double op = percent (p["opacity"]);
                if (op < 0.999) st.fill = with_alpha (st.fill, op);
            }
            string stroke = p["stroke"] ?? "solid";
            if (stroke == "none") {
                st.stroke = "none";
            } else {
                if (p.has_key ("stroke-color")) st.stroke = p["stroke-color"];
                if (p.has_key ("stroke-width")) {
                    double sw = Units.parse_length (p["stroke-width"], 1);
                    st.stroke_width = sw < 0.5 ? 1 : sw;
                }
                st.dash = stroke == "dash" ? dash_for (p["stroke-dash"]) : DashKind.SOLID;
                if (p.has_key ("stroke-opacity")) {
                    double so = percent (p["stroke-opacity"]);
                    if (so < 0.999) st.stroke = with_alpha (st.stroke, so);
                }
            }
            st.arrow_start = arrow_for (p["marker-start"]);
            st.arrow_end = arrow_for (p["marker-end"]);
            if (p["shadow"] == "visible") {
                st.shadow = true;
                if (p.has_key ("shadow-offset-x")) st.shadow_dx = Units.parse_length (p["shadow-offset-x"], 3);
                if (p.has_key ("shadow-offset-y")) st.shadow_dy = Units.parse_length (p["shadow-offset-y"], 3);
                string col = p["shadow-color"] ?? "#000000";
                double op = p.has_key ("shadow-opacity") ? percent (p["shadow-opacity"]) : 0.4;
                st.shadow_color = with_alpha (col, op);
            } else {
                st.shadow = false;
            }
            if (p.has_key ("font-name") && font_faces.has_key (p["font-name"])) st.font_family = font_faces[p["font-name"]];
            else if (p.has_key ("font-name")) st.font_family = p["font-name"];
            if (p.has_key ("font-family")) st.font_family = p["font-family"].replace ("'", "").replace ("\"", "");
            if (p.has_key ("font-size")) {
                string fs = p["font-size"];
                if (!fs.has_suffix ("%")) st.font_size = Units.parse_length (fs, 16) / Units.PX_PER_PT;
            }
            if (p.has_key ("font-weight")) st.bold = p["font-weight"] == "bold" || int.parse (p["font-weight"]) >= 600;
            if (p.has_key ("font-style")) st.italic = p["font-style"] == "italic" || p["font-style"] == "oblique";
            if (p.has_key ("color")) st.text_color = p["color"];
            if (p.has_key ("text-underline-style")) st.underline = p["text-underline-style"] != "none";
            if (p.has_key ("text-line-through-style")) st.strike = p["text-line-through-style"] != "none";
            if (p.has_key ("text-align")) st.halign = TextHAlign.from_id (p["text-align"]);
            else if (p.has_key ("textarea-horizontal-align") && p["textarea-horizontal-align"] != "justify") st.halign = TextHAlign.from_id (p["textarea-horizontal-align"]);
            if (p.has_key ("textarea-vertical-align")) {
                string va = p["textarea-vertical-align"];
                st.valign = TextVAlign.from_id (va == "justify" ? "middle" : va);
            }
            if (p.has_key ("wrap-option")) st.wrap = p["wrap-option"] != "no-wrap";
        }

        private bool span_free = false;

        private Style style_for (Xml.Node* n, bool line) {
            string? native = a (n, NativeFormat.NS, "style");
            if (native != null) return Style.deserialize (native);
            var st = new Style ();
            var props = graphic_props (a (n, OdfNs.DRAW, "style-name") ?? a (n, "urn:oasis:names:tc:opendocument:xmlns:presentation:1.0", "style-name"));
            var p1 = first_desc (n, "p", OdfNs.TEXT);
            if (p1 != null) {
                merge_style (props, para_styles, a (p1, OdfNs.TEXT, "style-name"));
                var span = span_free ? null : first_desc (p1, "span", OdfNs.TEXT);
                if (span != null) merge_style (props, text_styles, a (span, OdfNs.TEXT, "style-name"));
            }
            apply_props (st, props, line);
            return st;
        }

        private static Xml.Node* first_desc (Xml.Node* n, string name, string ns) {
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
                if (c->name == "enhanced-geometry") continue;
                if (c->name == name && c->ns != null && c->ns->href == ns) return c;
                var r = first_desc (c, name, ns);
                if (r != null) return r;
            }
            return null;
        }

        private void read_page (Xml.Node* pn, int index) {
            var p = new Page (a (pn, OdfNs.DRAW, "name") ?? _("Page %d").printf (index));
            cur_page = p;
            p.id = a (pn, NativeFormat.NS, "id") ?? "page%d".printf (index);
            string? master = a (pn, OdfNs.DRAW, "master-page-name");
            if (master != null && master_pages.has_key (master)) {
                Xml.Node* mp = (Xml.Node*) master_pages[master];
                string? pl = a (mp, OdfNs.STYLE, "page-layout-name");
                if (pl != null && page_layouts.has_key (pl)) {
                    var props = XmlUtil.child ((Xml.Node*) page_layouts[pl], "page-layout-properties", OdfNs.STYLE);
                    if (props != null) {
                        p.width = len (props, OdfNs.FO, "page-width", p.width);
                        p.height = len (props, OdfNs.FO, "page-height", p.height);
                    }
                }
            }
            string? ps = a (pn, OdfNs.DRAW, "style-name");
            if (ps != null && page_styles.has_key (ps)) {
                var props = new Gee.HashMap<string, string> ();
                collect_props ((Xml.Node*) page_styles[ps], props, page_styles, 0);
                if (props["fill"] == "solid" && props.has_key ("fill-color")) p.background = props["fill-color"];
                else if (props["fill"] == "none") p.background = "#ffffff";
            }
            string? nw = a (pn, NativeFormat.NS, "width");
            if (nw != null) p.width = double.parse (nw);
            string? nh = a (pn, NativeFormat.NS, "height");
            if (nh != null) p.height = double.parse (nh);
            string? bg = a (pn, NativeFormat.NS, "background");
            if (bg != null) p.background = bg;
            layer_map.clear ();
            string? nl = a (pn, NativeFormat.NS, "layers");
            if (nl != null) {
                p.layers.clear ();
                Odg.decode_layers (nl, p.layers);
                if (p.layers.size == 0) p.layers.add (new Layer ("layer1", _("Layer 1")));
                foreach (var l in p.layers) layer_map[l.name] = l.id;
                p.active_layer = a (pn, NativeFormat.NS, "active-layer") ?? p.layers[0].id;
            } else {
                p.layers.clear ();
                var def = new Layer ("layout", _("Layer 1"));
                p.layers.add (def);
                string[] internal_layers = { "layout", "background", "backgroundobjects", "controls", "measurelines" };
                foreach (void* lp in layer_nodes) {
                    Xml.Node* ln = (Xml.Node*) lp;
                    string lname = a (ln, OdfNs.DRAW, "name") ?? "";
                    bool internal_layer = false;
                    foreach (string s in internal_layers) if (s == lname) internal_layer = true;
                    if (lname == "" || internal_layer || layer_map.has_key (lname)) continue;
                    var l = new Layer (lname, lname);
                    string display = a (ln, OdfNs.DRAW, "display") ?? "always";
                    l.visible = display == "always" || display == "screen";
                    l.printable = display == "always" || display == "printer";
                    l.locked = a (ln, OdfNs.DRAW, "protected") == "true";
                    p.layers.add (l);
                    layer_map[lname] = l.id;
                }
                p.active_layer = def.id;
            }
            doc.pages.add (p);
            pending.clear ();
            ref_ids.clear ();
            foreach (var c in XmlUtil.children (pn)) {
                var it = read_element (c);
                if (it != null) p.items.add (it);
            }
            foreach (var pc in pending) {
                if (pc.start_ref != "" && ref_ids.has_key (pc.start_ref)) {
                    pc.conn.src.item_id = ref_ids[pc.start_ref];
                    pc.conn.src.port = pc.start_glue >= 0 && pc.start_glue < 4 ? pc.start_glue : -1;
                }
                if (pc.end_ref != "" && ref_ids.has_key (pc.end_ref)) {
                    pc.conn.dst.item_id = ref_ids[pc.end_ref];
                    pc.conn.dst.port = pc.end_glue >= 0 && pc.end_glue < 4 ? pc.end_glue : -1;
                }
            }
        }

        private string new_item_id () {
            return doc.new_id ("o");
        }

        private void read_common (Xml.Node* n, Item it, bool line) {
            string? nid = a (n, NativeFormat.NS, "id");
            it.id = nid ?? new_item_id ();
            string? did = a (n, OdfNs.DRAW, "id");
            string? xid = a (n, OdfNs.XML, "id");
            if (did != null) ref_ids[did] = it.id;
            if (xid != null) ref_ids[xid] = it.id;
            it.name = a (n, NativeFormat.NS, "name") ?? a (n, OdfNs.DRAW, "name") ?? "";
            string? nl = a (n, NativeFormat.NS, "layer");
            if (nl != null || nid != null) {
                it.layer_id = nl ?? "";
            } else {
                string lname = a (n, OdfNs.DRAW, "layer") ?? "layout";
                it.layer_id = layer_map.has_key (lname) ? layer_map[lname] : cur_page.layers[0].id;
            }
            it.locked = a (n, NativeFormat.NS, "locked") == "1";
            it.container_id = a (n, NativeFormat.NS, "container") ?? "";
            it.link = a (n, NativeFormat.NS, "link") ?? "";
            string? f = a (n, NativeFormat.NS, "fields");
            if (f != null) Odg.decode_fields (f, it.fields);
            it.style = style_for (n, line);
            string? t = a (n, NativeFormat.NS, "text");
            it.text = t ?? read_text (n);
            string? nm = a (n, NativeFormat.NS, "markup");
            if (nm != null) {
                it.markup = nm;
                if (!it.has_rich_text ()) it.markup = "";
            } else if (t == null && it.text != "") {
                var runs = read_runs (n, it.style);
                if (RichRuns.any_format (runs) && a (n, NativeFormat.NS, "style") == null) {
                    span_free = true;
                    it.style = style_for (n, line);
                    span_free = false;
                    runs = read_runs (n, it.style);
                }
                it.markup = RichRuns.markup_from (runs, it.text);
            }
        }

        private Gee.ArrayList<TextRun>? run_sink = null;
        private Gee.HashMap<string, string> run_props = new Gee.HashMap<string, string> ();
        private Style? run_base = null;

        private void emit (StringBuilder sb, string t) {
            sb.append (t);
            if (run_sink == null || t == "") return;
            var r = new TextRun (t);
            if (t != "\n" && run_base != null && run_props.size > 0) {
                var b = run_base;
                var tmp = b.copy ();
                apply_text_props (tmp, run_props);
                r.bold = tmp.bold && !b.bold;
                r.italic = tmp.italic && !b.italic;
                r.underline = tmp.underline && !b.underline;
                r.strike = tmp.strike && !b.strike;
                if (tmp.font_family != b.font_family) r.family = tmp.font_family;
                if (Math.fabs (tmp.font_size - b.font_size) > 0.05) r.size = Math.round (tmp.font_size * 100) / 100;
                if (Colors.rgb_hex (tmp.text_color).down () != Colors.rgb_hex (b.text_color).down ()) r.color = Colors.rgb_hex (tmp.text_color);
            }
            run_sink.add (r);
        }

        private void apply_text_props (Style st, Gee.HashMap<string, string> p) {
            if (p.has_key ("font-name") && font_faces.has_key (p["font-name"])) st.font_family = font_faces[p["font-name"]];
            else if (p.has_key ("font-name")) st.font_family = p["font-name"];
            if (p.has_key ("font-family")) st.font_family = p["font-family"].replace ("'", "").replace ("\"", "");
            if (p.has_key ("font-size")) {
                string fs = p["font-size"];
                if (fs.has_suffix ("%")) st.font_size = st.font_size * percent (fs);
                else st.font_size = Units.parse_length (fs, 16) / Units.PX_PER_PT;
            }
            if (p.has_key ("font-weight")) st.bold = p["font-weight"] == "bold" || int.parse (p["font-weight"]) >= 600;
            if (p.has_key ("font-style")) st.italic = p["font-style"] == "italic" || p["font-style"] == "oblique";
            if (p.has_key ("color")) st.text_color = p["color"];
            if (p.has_key ("text-underline-style")) st.underline = p["text-underline-style"] != "none";
            if (p.has_key ("text-line-through-style")) st.strike = p["text-line-through-style"] != "none";
        }

        private Gee.ArrayList<TextRun> read_runs (Xml.Node* n, Style base_style) {
            run_sink = new Gee.ArrayList<TextRun> ();
            run_base = base_style;
            run_props = new Gee.HashMap<string, string> ();
            read_text (n);
            var runs = run_sink;
            run_sink = null;
            run_base = null;
            return runs;
        }

        private string read_text (Xml.Node* n) {
            var sb = new StringBuilder ();
            bool first = true;
            collect_paragraphs (n, sb, ref first);
            return sb.str;
        }

        private void collect_paragraphs (Xml.Node* n, StringBuilder sb, ref bool first) {
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
                if (c->ns != null && c->ns->href == OdfNs.TEXT && (c->name == "p" || c->name == "h")) {
                    if (!first) emit (sb, "\n");
                    first = false;
                    if (run_sink != null) {
                        run_props = new Gee.HashMap<string, string> ();
                        merge_style (run_props, para_styles, a (c, OdfNs.TEXT, "style-name"));
                    }
                    inline_text (c, sb);
                } else if (c->ns != null && c->ns->href == OdfNs.TEXT && (c->name == "list" || c->name == "list-item")) {
                    collect_paragraphs (c, sb, ref first);
                } else if (c->ns != null && c->ns->href == OdfNs.DRAW && c->name == "text-box") {
                    collect_paragraphs (c, sb, ref first);
                }
            }
        }

        private void inline_text (Xml.Node* n, StringBuilder sb) {
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type == Xml.ElementType.TEXT_NODE || c->type == Xml.ElementType.CDATA_SECTION_NODE) {
                    string t = c->content ?? "";
                    var o = new StringBuilder ();
                    bool space = false;
                    for (int i = 0; i < t.length; i++) {
                        char ch = t[i];
                        if (ch == ' ' || ch == '\n' || ch == '\r' || ch == '\t') {
                            if (!space) o.append_c (' ');
                            space = true;
                        } else {
                            o.append_c (ch);
                            space = false;
                        }
                    }
                    emit (sb, o.str);
                } else if (c->type == Xml.ElementType.ELEMENT_NODE) {
                    switch (c->name) {
                        case "s":
                            int count = int.parse (a (c, OdfNs.TEXT, "c") ?? "1");
                            emit (sb, string.nfill (int.max (count, 1), ' '));
                            break;
                        case "tab":
                            emit (sb, "\t");
                            break;
                        case "line-break":
                            emit (sb, "\n");
                            break;
                        case "span":
                            var saved = run_props;
                            if (run_sink != null) {
                                run_props = new Gee.HashMap<string, string> ();
                                run_props.set_all (saved);
                                merge_style (run_props, text_styles, a (c, OdfNs.TEXT, "style-name"));
                            }
                            inline_text (c, sb);
                            run_props = saved;
                            break;
                        case "a":
                            inline_text (c, sb);
                            break;
                        default:
                            if (c->name != "note" && c->name != "annotation") inline_text (c, sb);
                            break;
                    }
                }
            }
        }

        private bool read_native_box (Xml.Node* n, Shape s) {
            string? box = a (n, NativeFormat.NS, "box");
            if (box == null) return false;
            string[] v = box.split (" ");
            if (v.length < 4) return false;
            s.x = double.parse (v[0]);
            s.y = double.parse (v[1]);
            s.w = double.parse (v[2]);
            s.h = double.parse (v[3]);
            s.rotation = double.parse (a (n, NativeFormat.NS, "rotation") ?? "0");
            s.flip_h = a (n, NativeFormat.NS, "flip-h") == "1";
            s.flip_v = a (n, NativeFormat.NS, "flip-v") == "1";
            return true;
        }

        public static Cairo.Matrix parse_transform (string t) {
            var m = Cairo.Matrix.identity ();
            int i = 0;
            while (i < t.length) {
                while (i < t.length && (t[i].isspace () || t[i] == ',')) i++;
                int start = i;
                while (i < t.length && t[i].isalpha ()) i++;
                string op = t.substring (start, i - start);
                while (i < t.length && t[i] != '(') i++;
                int open = i;
                int close = t.index_of (")", open);
                if (open >= t.length || close < 0) break;
                string args = t.substring (open + 1, close - open - 1);
                i = close + 1;
                var vals = new Gee.ArrayList<string> ();
                foreach (string part in args.replace (",", " ").split (" ")) if (part.strip () != "") vals.add (part.strip ());
                var op_m = Cairo.Matrix.identity ();
                switch (op) {
                    case "rotate":
                        if (vals.size >= 1) {
                            double ang = -double.parse (vals[0]);
                            op_m = Cairo.Matrix (Math.cos (ang), Math.sin (ang), -Math.sin (ang), Math.cos (ang), 0, 0);
                        }
                        break;
                    case "translate":
                        double tx = vals.size >= 1 ? Units.parse_length (vals[0], 0) : 0;
                        double ty = vals.size >= 2 ? Units.parse_length (vals[1], 0) : 0;
                        op_m = Cairo.Matrix (1, 0, 0, 1, tx, ty);
                        break;
                    case "scale":
                        double sx = vals.size >= 1 ? double.parse (vals[0]) : 1;
                        double sy = vals.size >= 2 ? double.parse (vals[1]) : sx;
                        op_m = Cairo.Matrix (sx, 0, 0, sy, 0, 0);
                        break;
                    case "skewX":
                        if (vals.size >= 1) op_m = Cairo.Matrix (1, 0, Math.tan (-double.parse (vals[0])), 1, 0, 0);
                        break;
                    case "skewY":
                        if (vals.size >= 1) op_m = Cairo.Matrix (1, Math.tan (-double.parse (vals[0])), 0, 1, 0, 0);
                        break;
                    case "matrix":
                        if (vals.size >= 6) op_m = Cairo.Matrix (double.parse (vals[0]), double.parse (vals[1]), double.parse (vals[2]),
                            double.parse (vals[3]), Units.parse_length (vals[4], 0), Units.parse_length (vals[5], 0));
                        break;
                    default:
                        break;
                }
                Cairo.Matrix res;
                res = Cairo.Matrix.identity ();
                res.multiply (m, op_m);
                m = res;
            }
            return m;
        }

        private void place (Xml.Node* n, Shape s, double w, double h) {
            double x = len (n, OdfNs.SVG, "x", 0), y = len (n, OdfNs.SVG, "y", 0);
            string? tr = a (n, OdfNs.DRAW, "transform");
            if (tr == null || tr.strip () == "") {
                s.x = x;
                s.y = y;
                s.w = w;
                s.h = h;
                s.rotation = 0;
                return;
            }
            var m = parse_transform (tr);
            var pre = Cairo.Matrix (1, 0, 0, 1, x, y);
            Cairo.Matrix total = Cairo.Matrix.identity ();
            total.multiply (pre, m);
            double cx = w / 2, cy = h / 2;
            total.transform_point (ref cx, ref cy);
            double sx = Math.hypot (total.xx, total.yx);
            double det = total.xx * total.yy - total.xy * total.yx;
            double sy = sx > 1e-12 ? det / sx : 1;
            double rot = Math.atan2 (total.yx, total.xx) * 180 / Math.PI;
            s.w = w * sx;
            s.h = h * sy.abs ();
            s.flip_v = sy < 0;
            s.rotation = Document.normalize_angle (Math.round (rot * 1e6) / 1e6);
            s.x = cx - s.w / 2;
            s.y = cy - s.h / 2;
        }

        private Item? read_element (Xml.Node* n) {
            if (n->ns == null) return null;
            string ns = n->ns->href;
            if (ns == OdfNs.DRAW) {
                switch (n->name) {
                    case "custom-shape": return read_custom (n);
                    case "rect": return read_rect (n);
                    case "ellipse": case "circle": return read_ellipse (n);
                    case "line": return read_line (n);
                    case "polyline": case "polygon": return read_poly (n);
                    case "path": return read_path (n);
                    case "connector": return read_connector (n);
                    case "g": return read_group (n);
                    case "frame": return read_frame (n);
                    case "a":
                        foreach (var c in XmlUtil.children (n)) {
                            var it = read_element (c);
                            if (it != null) {
                                string? href = a (n, OdfNs.XLINK, "href");
                                if (href != null && it.link == "") it.link = href;
                                return it;
                            }
                        }
                        return null;
                    default: return null;
                }
            }
            return null;
        }

        private Item read_group (Xml.Node* n) {
            var g = new Group ();
            read_common (n, g, false);
            if (a (n, NativeFormat.NS, "style") == null) g.style = new Style ();
            if (a (n, NativeFormat.NS, "text") == null) g.text = "";
            foreach (var c in XmlUtil.children (n)) {
                var it = read_element (c);
                if (it != null) g.children.add (it);
            }
            return g;
        }

        private Item read_custom (Xml.Node* n) {
            var geo = XmlUtil.child (n, "enhanced-geometry", OdfNs.DRAW);
            string? nkind = a (n, NativeFormat.NS, "kind");
            if (nkind != null) {
                var s = new Shape (nkind);
                read_common (n, s, false);
                if (!read_native_box (n, s)) place (n, s, len (n, OdfNs.SVG, "width", 100), len (n, OdfNs.SVG, "height", 60));
                return s;
            }
            double w = len (n, OdfNs.SVG, "width", 100), h = len (n, OdfNs.SVG, "height", 60);
            string type = geo != null ? (a (geo, OdfNs.DRAW, "type") ?? "non-primitive") : "rectangle";
            string? kind = Odg.odf_to_kind (type);
            string? epath = geo != null ? a (geo, OdfNs.DRAW, "enhanced-path") : null;
            Shape s;
            if (kind == null && epath != null && epath.strip () != "") {
                var ps = new PathShape ();
                var eg = new EnhancedGeometry (geo);
                ps.path = eg.build_path (epath, w, h);
                ps.natural_w = w;
                ps.natural_h = h;
                s = ps;
            } else {
                s = new Shape (kind ?? "rectangle");
            }
            read_common (n, s, false);
            place (n, s, w, h);
            if (geo != null) {
                if (a (geo, OdfNs.DRAW, "mirror-horizontal") == "true") s.flip_h = !s.flip_h;
                if (a (geo, OdfNs.DRAW, "mirror-vertical") == "true") s.flip_v = !s.flip_v;
            }
            if (s.kind == "rounded-rectangle" && s.style.corner_radius == 0) s.style.corner_radius = double.min (s.w, s.h) * 0.15;
            return s;
        }

        private Item read_rect (Xml.Node* n) {
            var s = new Shape ("rectangle");
            read_common (n, s, false);
            if (!read_native_box (n, s)) place (n, s, len (n, OdfNs.SVG, "width", 100), len (n, OdfNs.SVG, "height", 60));
            if (a (n, NativeFormat.NS, "style") == null) {
                double r = len (n, OdfNs.DRAW, "corner-radius", 0);
                if (r > 0) s.style.corner_radius = r;
            }
            return s;
        }

        private Item read_ellipse (Xml.Node* n) {
            double w, h;
            if (n->name == "circle" && a (n, OdfNs.SVG, "r") != null && a (n, OdfNs.SVG, "width") == null) {
                double r = len (n, OdfNs.SVG, "r", 50);
                w = h = 2 * r;
            } else {
                w = len (n, OdfNs.SVG, "width", 100);
                h = len (n, OdfNs.SVG, "height", 100);
            }
            string k = a (n, OdfNs.DRAW, "kind") ?? "full";
            Shape s;
            if (k == "full" || a (n, NativeFormat.NS, "kind") != null) {
                s = new Shape (a (n, NativeFormat.NS, "kind") ?? (n->name == "circle" ? "circle" : "ellipse"));
            } else {
                var ps = new PathShape ();
                double sa = double.parse (a (n, OdfNs.DRAW, "start-angle") ?? "0");
                double ea = double.parse (a (n, OdfNs.DRAW, "end-angle") ?? "360");
                if (ea <= sa) ea += 360;
                var p = new PathData ();
                double cx = w / 2, cy = h / 2;
                if (k == "section") p.move_to (cx, cy);
                p.arc_to (cx, cy, w / 2, h / 2, -sa * Math.PI / 180, -ea * Math.PI / 180, k == "section");
                if (k != "arc") p.close ();
                ps.path = p;
                ps.natural_w = w;
                ps.natural_h = h;
                s = ps;
            }
            bool is_arc = k == "arc";
            read_common (n, s, is_arc);
            if (a (n, OdfNs.SVG, "cx") != null && a (n, OdfNs.SVG, "x") == null) {
                s.x = len (n, OdfNs.SVG, "cx", 0) - w / 2;
                s.y = len (n, OdfNs.SVG, "cy", 0) - h / 2;
                s.w = w;
                s.h = h;
            } else if (!read_native_box (n, s)) {
                place (n, s, w, h);
            }
            return s;
        }

        private Item read_line (Xml.Node* n) {
            var ps = new PathShape ();
            double x1 = len (n, OdfNs.SVG, "x1", 0), y1 = len (n, OdfNs.SVG, "y1", 0);
            double x2 = len (n, OdfNs.SVG, "x2", 0), y2 = len (n, OdfNs.SVG, "y2", 0);
            string? tr = a (n, OdfNs.DRAW, "transform");
            if (tr != null) {
                var m = parse_transform (tr);
                m.transform_point (ref x1, ref y1);
                m.transform_point (ref x2, ref y2);
            }
            var p = new PathData ();
            p.move_to (x1, y1);
            p.line_to (x2, y2);
            ps.set_page_path (p);
            read_common (n, ps, true);
            if (read_native_path (n, ps)) read_native_box (n, ps);
            return ps;
        }

        private bool read_native_path (Xml.Node* n, PathShape ps) {
            string? d = a (n, NativeFormat.NS, "d");
            if (d == null) return false;
            ps.path = PathData.parse_svg (d);
            string[] nat = (a (n, NativeFormat.NS, "natural") ?? "1 1").split (" ");
            ps.natural_w = double.parse (nat[0]);
            ps.natural_h = nat.length > 1 ? double.parse (nat[1]) : 1;
            return true;
        }

        private Rect view_box (Xml.Node* n, double w, double h) {
            string? vb = a (n, OdfNs.SVG, "viewBox");
            if (vb == null) return Rect (0, 0, w, h);
            var sc = new PathScanner (vb);
            double x = 0, y = 0, vw = 0, vh = 0;
            if (!sc.number (out x) || !sc.number (out y) || !sc.number (out vw) || !sc.number (out vh)) return Rect (0, 0, w, h);
            return Rect (x, y, vw, vh);
        }

        private void to_local (PathData p, Rect vb, double w, double h) {
            double kx = vb.w > 1e-9 ? w / vb.w : 1, ky = vb.h > 1e-9 ? h / vb.h : 1;
            var m = Cairo.Matrix (kx, 0, 0, ky, -vb.x * kx, -vb.y * ky);
            p.transform (m);
        }

        private Item read_poly (Xml.Node* n) {
            var ps = new PathShape ();
            double w = len (n, OdfNs.SVG, "width", 100), h = len (n, OdfNs.SVG, "height", 100);
            var p = new PathData ();
            var pts = NativeFormat.points_from_string (a (n, OdfNs.DRAW, "points"));
            p.add_polygon (pts, n->name == "polygon");
            to_local (p, view_box (n, w, h), w, h);
            ps.path = p;
            ps.natural_w = w;
            ps.natural_h = h;
            read_common (n, ps, n->name == "polyline");
            if (!read_native_path (n, ps) || !read_native_box (n, ps)) place (n, ps, w, h);
            return ps;
        }

        private Item read_path (Xml.Node* n) {
            var ps = new PathShape ();
            double w = len (n, OdfNs.SVG, "width", 100), h = len (n, OdfNs.SVG, "height", 100);
            var p = PathData.parse_svg (a (n, OdfNs.SVG, "d") ?? "");
            to_local (p, view_box (n, w, h), w, h);
            ps.path = p;
            ps.natural_w = w;
            ps.natural_h = h;
            bool native = read_native_path (n, ps);
            read_common (n, ps, !ps.is_closed ());
            if (!native || !read_native_box (n, ps)) place (n, ps, w, h);
            return ps;
        }

        private Item read_connector (Xml.Node* n) {
            var c = new Connector ();
            read_common (n, c, true);
            if (a (n, NativeFormat.NS, "style") == null) c.style.fill_kind = FillKind.NONE;
            string? route = a (n, NativeFormat.NS, "route");
            if (route != null) {
                c.route = RouteKind.from_id (route);
            } else {
                switch (a (n, OdfNs.DRAW, "type") ?? "standard") {
                    case "curve": c.route = RouteKind.CURVED; break;
                    case "line": case "lines": c.route = RouteKind.STRAIGHT; break;
                    default: c.route = RouteKind.ORTHOGONAL; break;
                }
            }
            c.src.x = len (n, OdfNs.SVG, "x1", 0);
            c.src.y = len (n, OdfNs.SVG, "y1", 0);
            c.dst.x = len (n, OdfNs.SVG, "x2", 0);
            c.dst.y = len (n, OdfNs.SVG, "y2", 0);
            string? nsrc = a (n, NativeFormat.NS, "src");
            if (nsrc != null) {
                c.src.item_id = nsrc;
                c.src.port = int.parse (a (n, NativeFormat.NS, "src-port") ?? "-1");
                var sp = NativeFormat.points_from_string (a (n, NativeFormat.NS, "src-pos"));
                if (sp.length > 0) {
                    c.src.x = sp[0].x;
                    c.src.y = sp[0].y;
                }
                c.dst.item_id = a (n, NativeFormat.NS, "dst") ?? "";
                c.dst.port = int.parse (a (n, NativeFormat.NS, "dst-port") ?? "-1");
                var dp = NativeFormat.points_from_string (a (n, NativeFormat.NS, "dst-pos"));
                if (dp.length > 0) {
                    c.dst.x = dp[0].x;
                    c.dst.y = dp[0].y;
                }
                c.waypoints = NativeFormat.points_from_string (a (n, NativeFormat.NS, "waypoints"));
                c.label_pos = double.parse (a (n, NativeFormat.NS, "label-pos") ?? "0.5");
                c.jumps = a (n, NativeFormat.NS, "jumps") == "1";
            } else {
                var pc = new OdfPending ();
                pc.conn = c;
                pc.start_ref = a (n, OdfNs.DRAW, "start-shape") ?? "";
                pc.end_ref = a (n, OdfNs.DRAW, "end-shape") ?? "";
                pc.start_glue = int.parse (a (n, OdfNs.DRAW, "start-glue-point") ?? "-1");
                pc.end_glue = int.parse (a (n, OdfNs.DRAW, "end-glue-point") ?? "-1");
                if (a (n, OdfNs.DRAW, "start-glue-point") == null) pc.start_glue = -1;
                if (a (n, OdfNs.DRAW, "end-glue-point") == null) pc.end_glue = -1;
                pending.add (pc);
            }
            return c;
        }

        private Item? read_frame (Xml.Node* n) {
            double w = len (n, OdfNs.SVG, "width", 100), h = len (n, OdfNs.SVG, "height", 60);
            var img = XmlUtil.child (n, "image", OdfNs.DRAW);
            var table = XmlUtil.child (n, "table", OdfNs.TABLE);
            var tbox = XmlUtil.child (n, "text-box", OdfNs.DRAW);
            if (table != null) return read_table (n, table, w, h);
            if (img != null) {
                ImageShape shape = a (n, NativeFormat.NS, "kind") == "raster" ? (ImageShape) new RasterItem () : new ImageShape ();
                uint8[]? bytes = null;
                foreach (var im in XmlUtil.children (n, "image", OdfNs.DRAW)) {
                    bytes = image_bytes (im);
                    if (bytes != null && bytes.length > 0) {
                        img = im;
                        break;
                    }
                }
                if (bytes != null) shape.bytes = bytes;
                read_common (n, shape, false);
                if (a (n, NativeFormat.NS, "style") == null) {
                    shape.style.fill_kind = FillKind.NONE;
                    var props = graphic_props (a (n, OdfNs.DRAW, "style-name"));
                    if (props["stroke"] != "solid" && props["stroke"] != "dash") {
                        shape.style.stroke = "none";
                        shape.style.stroke_width = 0;
                    }
                }
                if (a (n, NativeFormat.NS, "text") == null) shape.text = "";
                shape.mime = a (n, NativeFormat.NS, "mime") ?? a (img, OdfNs.DRAW, "mime-type") ?? ImageShape.sniff_mime (shape.bytes);
                if (shape.mime == "" || !shape.mime.has_prefix ("image/")) shape.mime = ImageShape.sniff_mime (shape.bytes);
                if (!read_native_box (shape_node (n), shape)) place (n, shape, w, h);
                return shape;
            }
            var s = new Shape ("text");
            read_common (n, s, false);
            if (a (n, NativeFormat.NS, "style") == null && tbox != null) {
                var props = graphic_props (a (n, OdfNs.DRAW, "style-name"));
                if (!props.has_key ("fill")) s.style.fill_kind = FillKind.NONE;
                if (!props.has_key ("stroke")) s.style.stroke = "none";
            }
            if (!read_native_box (n, s)) place (n, s, w, h);
            if (a (n, NativeFormat.NS, "kind") != null) s.kind = a (n, NativeFormat.NS, "kind");
            return s;
        }

        private Xml.Node* shape_node (Xml.Node* n) {
            return n;
        }

        private uint8[]? image_bytes (Xml.Node* im) {
            var bin = XmlUtil.child (im, "binary-data", OdfNs.OFFICE);
            if (bin != null) {
                string b64 = XmlUtil.text (bin);
                var clean = new StringBuilder ();
                for (int i = 0; i < b64.length; i++) if (!b64[i].isspace ()) clean.append_c (b64[i]);
                return Base64.decode (clean.str);
            }
            string? href = a (im, OdfNs.XLINK, "href");
            if (href == null || zip == null) return null;
            if (href.has_prefix ("./")) href = href.substring (2);
            try {
                return zip.read (href);
            } catch (Error e) {
                return null;
            }
        }

        private Item read_table (Xml.Node* frame, Xml.Node* table, double w, double h) {
            var rows = new Gee.ArrayList<Xml.Node*> ();
            bool header = false;
            foreach (var c in XmlUtil.children (table)) {
                if (c->name == "table-row") rows.add (c);
                else if (c->name == "table-header-rows") {
                    header = true;
                    foreach (var r in XmlUtil.children (c, "table-row", OdfNs.TABLE)) rows.add (r);
                } else if (c->name == "table-rows") {
                    foreach (var r in XmlUtil.children (c, "table-row", OdfNs.TABLE)) rows.add (r);
                }
            }
            var cols_nodes = new Gee.ArrayList<Xml.Node*> ();
            foreach (var c in XmlUtil.children (table, "table-column", OdfNs.TABLE)) {
                int rep = int.parse (a (c, OdfNs.TABLE, "number-columns-repeated") ?? "1");
                for (int i = 0; i < int.max (rep, 1) && cols_nodes.size < 100; i++) cols_nodes.add (c);
            }
            int ncols = cols_nodes.size;
            foreach (var r in rows) {
                int cnt = 0;
                foreach (var cell in XmlUtil.children (r)) {
                    if (cell->name == "table-cell" || cell->name == "covered-table-cell") cnt += int.max (int.parse (a (cell, OdfNs.TABLE, "number-columns-repeated") ?? "1"), 1);
                }
                ncols = int.max (ncols, cnt);
            }
            int nrows = int.max (rows.size, 1);
            ncols = int.max (ncols, 1).clamp (1, 100);
            nrows = nrows.clamp (1, 500);
            var t = new TableShape (nrows, ncols);
            read_common (frame, t, false);
            if (a (frame, NativeFormat.NS, "text") == null) t.text = "";
            if (a (frame, NativeFormat.NS, "style") == null) {
                t.style.fill = "#ffffff";
                t.style.fill_kind = FillKind.SOLID;
                t.style.halign = TextHAlign.LEFT;
                if (Colors.is_none (t.style.stroke)) t.style.stroke = "#2e3436";
                t.style.stroke_width = 1;
            }
            for (int r = 0; r < rows.size && r < nrows; r++) {
                int c = 0;
                foreach (var cell in XmlUtil.children (rows[r])) {
                    if (cell->name != "table-cell" && cell->name != "covered-table-cell") continue;
                    int rep = int.max (int.parse (a (cell, OdfNs.TABLE, "number-columns-repeated") ?? "1"), 1);
                    string txt = read_text (cell);
                    for (int k = 0; k < rep && c < ncols; k++) t.set_cell (r, c++, txt);
                }
            }
            t.header_row = header || a (table, OdfNs.TABLE, "use-first-row-styles") == "true";
            string? nh = a (frame, NativeFormat.NS, "header");
            if (nh != null) t.header_row = nh == "1";
            t.header_fill = a (frame, NativeFormat.NS, "header-fill") ?? t.header_fill;
            double[] cw = new double[ncols];
            double total = 0;
            for (int c = 0; c < ncols; c++) {
                double v = 0;
                if (c < cols_nodes.size) {
                    string? sn = a (cols_nodes[c], OdfNs.TABLE, "style-name");
                    if (sn != null && col_styles.has_key (sn)) {
                        var pp = XmlUtil.child ((Xml.Node*) col_styles[sn], "table-column-properties", OdfNs.STYLE);
                        if (pp != null) v = len (pp, OdfNs.STYLE, "column-width", 0);
                    }
                }
                cw[c] = v;
                total += v;
            }
            if (total > 0) {
                bool all = true;
                foreach (double v in cw) if (v <= 0) all = false;
                if (all) for (int c = 0; c < ncols; c++) t.col_fracs[c] = cw[c] / total;
            }
            double[] rh = new double[nrows];
            double rtotal = 0;
            bool rall = true;
            for (int r = 0; r < nrows && r < rows.size; r++) {
                string? sn = a (rows[r], OdfNs.TABLE, "style-name");
                double v = 0;
                if (sn != null && row_styles.has_key (sn)) {
                    var pp = XmlUtil.child ((Xml.Node*) row_styles[sn], "table-row-properties", OdfNs.STYLE);
                    if (pp != null) v = len (pp, OdfNs.STYLE, "row-height", 0);
                }
                rh[r] = v;
                rtotal += v;
                if (v <= 0) rall = false;
            }
            if (rall && rtotal > 0 && rows.size == nrows) for (int r = 0; r < nrows; r++) t.row_fracs[r] = rh[r] / rtotal;
            string? cf = a (frame, NativeFormat.NS, "col-fracs");
            if (cf != null) {
                string[] parts = cf.split (" ");
                if (parts.length == ncols) for (int c = 0; c < ncols; c++) t.col_fracs[c] = double.parse (parts[c]);
            }
            string? rf = a (frame, NativeFormat.NS, "row-fracs");
            if (rf != null) {
                string[] parts = rf.split (" ");
                if (parts.length == nrows) for (int r = 0; r < nrows; r++) t.row_fracs[r] = double.parse (parts[r]);
            }
            if (!read_native_box (frame, t)) place (frame, t, w, h);
            return t;
        }
    }

    public class EnhancedGeometry {
        private Rect vb;
        private double[] modifiers = {};
        private Gee.HashMap<string, string> equations = new Gee.HashMap<string, string> ();
        private Gee.HashMap<string, double?> cache = new Gee.HashMap<string, double?> ();
        private Gee.HashSet<string> busy = new Gee.HashSet<string> ();

        public EnhancedGeometry (Xml.Node* geo) {
            vb = Rect (0, 0, 21600, 21600);
            string? v = XmlUtil.attr (geo, "viewBox", OdfNs.SVG);
            if (v != null) {
                var sc = new PathScanner (v);
                double x = 0, y = 0, w = 0, h = 0;
                if (sc.number (out x) && sc.number (out y) && sc.number (out w) && sc.number (out h)) vb = Rect (x, y, w, h);
            }
            string? mods = XmlUtil.attr (geo, "modifiers", OdfNs.DRAW);
            if (mods != null) {
                var sc = new PathScanner (mods);
                double m = 0;
                double[] list = {};
                while (sc.number (out m)) list += m;
                modifiers = list;
            }
            foreach (var eq in XmlUtil.children (geo, "equation", OdfNs.DRAW)) {
                string? name = XmlUtil.attr (eq, "name", OdfNs.DRAW);
                string? formula = XmlUtil.attr (eq, "formula", OdfNs.DRAW);
                if (name != null && formula != null) equations[name] = formula;
            }
        }

        public EnhancedGeometry.simple (Rect view_box, double[] mods, Gee.Map<string, string> eqs) {
            vb = view_box;
            modifiers = mods;
            foreach (var e in eqs.entries) equations[e.key] = e.value;
        }

        public double equation (string name) {
            if (cache.has_key (name)) return cache[name];
            if (!equations.has_key (name) || busy.contains (name)) return 0;
            busy.add (name);
            double v = eval (equations[name]);
            busy.remove (name);
            cache[name] = v;
            return v;
        }

        public double eval (string formula) {
            var p = new FormulaParser (formula, this);
            return p.parse ();
        }

        public double identifier (string id) {
            switch (id) {
                case "left": return vb.x;
                case "top": return vb.y;
                case "right": return vb.x + vb.w;
                case "bottom": return vb.y + vb.h;
                case "width": case "logwidth": return vb.w;
                case "height": case "logheight": return vb.h;
                case "xstretch": case "ystretch": return 0;
                case "hasstroke": case "hasfill": return 1;
                case "pi": return Math.PI;
                default: return 0;
            }
        }

        public double modifier (int i) {
            return i >= 0 && i < modifiers.length ? modifiers[i] : 0;
        }

        public double param (string tok) {
            if (tok.has_prefix ("?")) return equation (tok.substring (1));
            if (tok.has_prefix ("$")) return modifier (int.parse (tok.substring (1)));
            if (tok.length > 0 && (tok[0].isalpha ())) return identifier (tok);
            return double.parse (tok);
        }

        public PathData build_path (string epath, double w, double h) {
            var tokens = new Gee.ArrayList<string> ();
            var cur = new StringBuilder ();
            for (int i = 0; i < epath.length; i++) {
                char c = epath[i];
                if (c.isspace () || c == ',') {
                    if (cur.len > 0) {
                        tokens.add (cur.str);
                        cur.truncate ();
                    }
                } else if (c.isalpha () && cur.len == 0 && (i + 1 >= epath.length || !epath[i + 1].isalpha ())) {
                    tokens.add (c.to_string ());
                } else {
                    cur.append_c (c);
                }
            }
            if (cur.len > 0) tokens.add (cur.str);
            double kx = vb.w > 1e-9 ? w / vb.w : 1, ky = vb.h > 1e-9 ? h / vb.h : 1;
            var p = new PathData ();
            char cmd = 'M';
            int idx = 0;
            double cx = 0, cy = 0;
            bool xfirst = true;
            while (idx < tokens.size) {
                string t = tokens[idx];
                if (t.length == 1 && t[0].isalpha () && t != "e") {
                    cmd = t[0];
                    idx++;
                    if (cmd == 'Z') p.close ();
                    if (cmd == 'X') xfirst = true;
                    if (cmd == 'Y') xfirst = false;
                    if (cmd == 'Z' || cmd == 'N' || cmd == 'F' || cmd == 'S') continue;
                    continue;
                }
                int need;
                switch (cmd) {
                    case 'M': case 'L': case 'X': case 'Y': need = 2; break;
                    case 'C': need = 6; break;
                    case 'Q': need = 4; break;
                    case 'A': case 'B': case 'W': case 'V': need = 8; break;
                    case 'T': case 'U': need = 6; break;
                    case 'G': need = 4; break;
                    default: need = 1; break;
                }
                if (idx + need > tokens.size) break;
                double[] v = new double[need];
                for (int k = 0; k < need; k++) v[k] = param (tokens[idx + k]);
                idx += need;
                switch (cmd) {
                    case 'M':
                        cx = X (v[0], kx);
                        cy = Y (v[1], ky);
                        p.move_to (cx, cy);
                        cmd = 'L';
                        break;
                    case 'L':
                        cx = X (v[0], kx);
                        cy = Y (v[1], ky);
                        p.line_to (cx, cy);
                        break;
                    case 'C':
                        p.curve_to (X (v[0], kx), Y (v[1], ky), X (v[2], kx), Y (v[3], ky), X (v[4], kx), Y (v[5], ky));
                        cx = X (v[4], kx);
                        cy = Y (v[5], ky);
                        break;
                    case 'Q':
                        double qx = X (v[0], kx), qy = Y (v[1], ky), ex = X (v[2], kx), ey = Y (v[3], ky);
                        p.curve_to (cx + 2.0 / 3 * (qx - cx), cy + 2.0 / 3 * (qy - cy), ex + 2.0 / 3 * (qx - ex), ey + 2.0 / 3 * (qy - ey), ex, ey);
                        cx = ex;
                        cy = ey;
                        break;
                    case 'X':
                    case 'Y':
                        double tx = X (v[0], kx), ty = Y (v[1], ky);
                        double K = PathData.KAPPA;
                        if (xfirst) p.curve_to (cx + K * (tx - cx), cy, tx, ty - K * (ty - cy), tx, ty);
                        else p.curve_to (cx, cy + K * (ty - cy), tx - K * (tx - cx), ty, tx, ty);
                        xfirst = !xfirst;
                        cx = tx;
                        cy = ty;
                        break;
                    case 'A':
                    case 'B':
                    case 'W':
                    case 'V':
                        double x1 = X (v[0], kx), y1 = Y (v[1], ky), x2 = X (v[2], kx), y2 = Y (v[3], ky);
                        double ocx = (x1 + x2) / 2, ocy = (y1 + y2) / 2, rx = (x2 - x1).abs () / 2, ry = (y2 - y1).abs () / 2;
                        if (rx < 1e-9 || ry < 1e-9) break;
                        double a1 = Math.atan2 ((Y (v[5], ky) - ocy) / ry, (X (v[4], kx) - ocx) / rx);
                        double a2 = Math.atan2 ((Y (v[7], ky) - ocy) / ry, (X (v[6], kx) - ocx) / rx);
                        bool clockwise = cmd == 'W' || cmd == 'V';
                        if (clockwise) {
                            if (a2 <= a1) a2 += 2 * Math.PI;
                        } else {
                            if (a2 >= a1) a2 -= 2 * Math.PI;
                        }
                        bool connect = (cmd == 'A' || cmd == 'W') && p.segs.size > 0;
                        p.arc_to (ocx, ocy, rx, ry, a1, a2, connect);
                        cx = ocx + rx * Math.cos (a2);
                        cy = ocy + ry * Math.sin (a2);
                        break;
                    case 'T':
                    case 'U':
                        double ecx = X (v[0], kx), ecy = Y (v[1], ky), erx = v[2] * kx, ery = v[3] * ky;
                        double t0 = v[4], t1 = v[5];
                        if (t1 <= t0) t1 += 360;
                        double b1 = -t0 * Math.PI / 180, b2 = -t1 * Math.PI / 180;
                        p.arc_to (ecx, ecy, erx, ery, b1, b2, cmd == 'T' && p.segs.size > 0);
                        cx = ecx + erx * Math.cos (b2);
                        cy = ecy + ery * Math.sin (b2);
                        break;
                    default:
                        break;
                }
            }
            return p;
        }

        private double X (double v, double k) {
            return (v - vb.x) * k;
        }

        private double Y (double v, double k) {
            return (v - vb.y) * k;
        }
    }

    public class FormulaParser {
        private string s;
        private int pos = 0;
        private EnhancedGeometry geo;

        public FormulaParser (string s, EnhancedGeometry geo) {
            this.s = s;
            this.geo = geo;
        }

        private void ws () {
            while (pos < s.length && s[pos].isspace ()) pos++;
        }

        public double parse () {
            double v = expr ();
            return v.is_nan () || v.is_infinity () != 0 ? 0 : v;
        }

        private double expr () {
            double v = term ();
            while (true) {
                ws ();
                if (pos < s.length && s[pos] == '+') {
                    pos++;
                    v += term ();
                } else if (pos < s.length && s[pos] == '-') {
                    pos++;
                    v -= term ();
                } else {
                    return v;
                }
            }
        }

        private double term () {
            double v = factor ();
            while (true) {
                ws ();
                if (pos < s.length && s[pos] == '*') {
                    pos++;
                    v *= factor ();
                } else if (pos < s.length && s[pos] == '/') {
                    pos++;
                    double d = factor ();
                    v = d != 0 ? v / d : 0;
                } else {
                    return v;
                }
            }
        }

        private double factor () {
            ws ();
            if (pos >= s.length) return 0;
            char c = s[pos];
            if (c == '-') {
                pos++;
                return -factor ();
            }
            if (c == '+') {
                pos++;
                return factor ();
            }
            if (c == '(') {
                pos++;
                double v = expr ();
                ws ();
                if (pos < s.length && s[pos] == ')') pos++;
                return v;
            }
            if (c == '?' || c == '$') {
                int start = pos;
                pos++;
                while (pos < s.length && (s[pos].isalnum () || s[pos] == '_')) pos++;
                return geo.param (s.substring (start, pos - start));
            }
            if (c.isdigit () || c == '.') {
                int start = pos;
                while (pos < s.length && (s[pos].isdigit () || s[pos] == '.')) pos++;
                if (pos < s.length && (s[pos] == 'e' || s[pos] == 'E')) {
                    int save = pos;
                    pos++;
                    if (pos < s.length && (s[pos] == '-' || s[pos] == '+')) pos++;
                    if (pos < s.length && s[pos].isdigit ()) {
                        while (pos < s.length && s[pos].isdigit ()) pos++;
                    } else {
                        pos = save;
                    }
                }
                return double.parse (s.substring (start, pos - start));
            }
            if (c.isalpha ()) {
                int start = pos;
                while (pos < s.length && (s[pos].isalnum () || s[pos] == '_')) pos++;
                string id = s.substring (start, pos - start);
                ws ();
                if (pos < s.length && s[pos] == '(') {
                    pos++;
                    double[] args = {};
                    ws ();
                    if (pos < s.length && s[pos] == ')') {
                        pos++;
                    } else {
                        while (true) {
                            args += expr ();
                            ws ();
                            if (pos < s.length && s[pos] == ',') {
                                pos++;
                                continue;
                            }
                            if (pos < s.length && s[pos] == ')') pos++;
                            break;
                        }
                    }
                    return call (id, args);
                }
                return geo.identifier (id);
            }
            pos++;
            return 0;
        }

        private static double arg (double[] a, int i) {
            return i < a.length ? a[i] : 0;
        }

        private double call (string f, double[] a) {
            switch (f) {
                case "abs": return arg (a, 0).abs ();
                case "sqrt": return Math.sqrt (double.max (arg (a, 0), 0));
                case "sin": return Math.sin (arg (a, 0));
                case "cos": return Math.cos (arg (a, 0));
                case "tan": return Math.tan (arg (a, 0));
                case "atan": return Math.atan (arg (a, 0));
                case "atan2": return Math.atan2 (arg (a, 0), arg (a, 1));
                case "min": return double.min (arg (a, 0), arg (a, 1));
                case "max": return double.max (arg (a, 0), arg (a, 1));
                case "if": return arg (a, 0) > 0 ? arg (a, 1) : arg (a, 2);
                default: return 0;
            }
        }
    }
}
