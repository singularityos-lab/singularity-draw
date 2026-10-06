namespace Singularity.Apps.Draw {

    public class Vsdx {
        public const string NS = "http://schemas.microsoft.com/office/visio/2012/main";
        public const string NS_R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
        public const string NS_REL = "http://schemas.openxmlformats.org/package/2006/relationships";

        public static Document load (uint8[] data) throws Error {
            var reader = new VsdxReader (data);
            return reader.read ();
        }

        public static uint8[] save (Document doc) throws Error {
            var writer = new VsdxWriter (doc);
            return writer.write ();
        }

        public static UserStencil load_stencil (uint8[] data) throws Error {
            var reader = new VsdxReader (data);
            reader.stencil_mode = true;
            reader.read ();
            var st = new UserStencil ();
            st.name = reader.package_title;
            foreach (var m in reader.stencil_masters) st.masters.add (m);
            if (st.masters.size == 0) throw new FormatError.INVALID (_("The stencil has no shapes."));
            return st;
        }

        public static uint8[] save_stencil (UserStencil stencil) throws Error {
            var writer = new VsdxWriter.for_stencil (stencil);
            return writer.write ();
        }

        public static int arrow_to_visio (ArrowKind k) {
            switch (k) {
                case ArrowKind.OPEN: return 1;
                case ArrowKind.TRIANGLE_OPEN: return 2;
                case ArrowKind.TRIANGLE: return 4;
                case ArrowKind.STEALTH: return 5;
                case ArrowKind.BAR: return 9;
                case ArrowKind.CIRCLE_OPEN: return 10;
                case ArrowKind.DIAMOND_OPEN: return 11;
                case ArrowKind.CIRCLE: return 20;
                case ArrowKind.DIAMOND: return 22;
                case ArrowKind.ONE: return 24;
                case ArrowKind.CROWS_FOOT: return 29;
                default: return 0;
            }
        }

        public static ArrowKind arrow_from_visio (int v) {
            switch (v) {
                case 0: return ArrowKind.NONE;
                case 1: case 3: return ArrowKind.OPEN;
                case 2: return ArrowKind.TRIANGLE_OPEN;
                case 5: return ArrowKind.STEALTH;
                case 9: return ArrowKind.BAR;
                case 10: return ArrowKind.CIRCLE_OPEN;
                case 11: case 12: return ArrowKind.DIAMOND_OPEN;
                case 20: case 21: return ArrowKind.CIRCLE;
                case 22: case 23: return ArrowKind.DIAMOND;
                case 24: case 25: return ArrowKind.ONE;
                case 29: case 30: return ArrowKind.CROWS_FOOT;
                default: return v > 0 ? ArrowKind.TRIANGLE : ArrowKind.NONE;
            }
        }

        public static int dash_to_visio (DashKind d) {
            switch (d) {
                case DashKind.DASH: return 2;
                case DashKind.DOT: return 3;
                case DashKind.DASH_DOT: return 4;
                case DashKind.DASH_DOT_DOT: return 5;
                case DashKind.LONG_DASH: return 9;
                default: return 1;
            }
        }

        public static DashKind dash_from_visio (int v) {
            switch (v) {
                case 2: case 16: return DashKind.DASH;
                case 3: case 10: return DashKind.DOT;
                case 4: case 6: case 7: return DashKind.DASH_DOT;
                case 5: case 8: return DashKind.DASH_DOT_DOT;
                case 9: case 11: case 12: case 13: case 14: case 15: return DashKind.LONG_DASH;
                default: return DashKind.SOLID;
            }
        }

        public static string num (double v) {
            return PathData.fmt (v, 8);
        }

        public static string content_type_for (string ext) {
            switch (ext) {
                case "jpg": case "jpeg": return "image/jpeg";
                case "gif": return "image/gif";
                case "bmp": return "image/bmp";
                default: return "image/png";
            }
        }
    }

    private class VFrame {
        public double ox;
        public double oy_bottom;
        public double ppi;

        public VFrame (double ox, double oy_bottom, double ppi = Units.PX_PER_IN) {
            this.ox = ox;
            this.oy_bottom = oy_bottom;
            this.ppi = ppi;
        }

        public double fx (double px) {
            return (px - ox) / ppi;
        }

        public double fy (double py) {
            return (oy_bottom - py) / ppi;
        }
    }

    private class VMaster {
        public int id;
        public string kind;
        public string name;
        public double w;
        public double h;
        public bool connector = false;
        public StencilMaster? source = null;
        public Gee.ArrayList<double?> signature = new Gee.ArrayList<double?> ();
    }

    private class VsdxWriter {
        private Document doc;
        private ZipWriter zip = new ZipWriter ();
        private int media_count = 0;
        private Gee.HashMap<Item, int> ids = new Gee.HashMap<Item, int> ();
        private int next_sheet = 1;
        private Gee.ArrayList<string> page_rels = new Gee.ArrayList<string> ();
        private Gee.HashSet<string> media_exts = new Gee.HashSet<string> ();
        private Page page;
        private double ppi = Units.PX_PER_IN;
        private Gee.ArrayList<VMaster> masters = new Gee.ArrayList<VMaster> ();
        private Gee.HashMap<string, VMaster> master_by_kind = new Gee.HashMap<string, VMaster> ();
        private Gee.HashSet<VMaster> page_masters = new Gee.HashSet<VMaster> ();
        private ShapeSheet? cur_sheet = null;
        private StringBuilder comment_entries = new StringBuilder ();
        private Gee.ArrayList<string> comment_authors = new Gee.ArrayList<string> ();
        private int comment_count = 0;
        private UserStencil? stencil = null;

        public VsdxWriter (Document doc) {
            this.doc = doc;
        }

        public VsdxWriter.for_stencil (UserStencil st) {
            this.doc = new Document ();
            this.stencil = st;
        }

        private static void cell (XmlWriter w, string n, string v, string? u = null) {
            w.start ("Cell").attr ("N", n).attr ("V", v);
            if (u != null) w.attr ("U", u);
            w.end ();
        }

        private static void cell_num (XmlWriter w, string n, double v, string? u = null) {
            cell (w, n, Vsdx.num (v), u);
        }

        private static void user_row (XmlWriter w, string n, string v) {
            w.start ("Row").attr ("N", n);
            cell (w, "Value", v, "STR");
            cell (w, "Prompt", "", "STR");
            w.end ();
        }

        private static string color_value (string c, out double trans) {
            Rgba rgba;
            trans = 0;
            if (!Colors.parse (c, out rgba)) return "#000000";
            trans = 1 - rgba.a;
            return Colors.to_hex (rgba).up ();
        }

        private static double page_ppi (Page p) {
            if (!p.has_scale ()) return Units.PX_PER_IN;
            double r = p.scale_ratio ();
            return r > 0 ? Units.PX_PER_IN / r : Units.PX_PER_IN;
        }

        private static bool master_kind (Item it) {
            if (it.get_type () != typeof (Shape)) return false;
            var s = (Shape) it;
            if (s.kind == "" || s.kind.has_prefix ("master:")) return false;
            return ShapeLibrary.find (s.kind) != null;
        }

        private VMaster ensure_master (string kind, bool connector) {
            if (master_by_kind.has_key (kind)) return master_by_kind[kind];
            var m = new VMaster ();
            m.id = masters.size + 1;
            m.kind = kind;
            m.connector = connector;
            if (connector) {
                m.name = "Dynamic connector";
                m.w = Units.PX_PER_IN;
                m.h = 0;
            } else {
                var e = ShapeLibrary.find (kind);
                m.name = e != null ? e.name : kind;
                m.w = e != null ? double.max (e.w, 1) : 120;
                m.h = e != null ? double.max (e.h, 1) : 60;
                var s = new Shape (kind, 0, 0, m.w, m.h);
                ShapeLibrary.apply_defaults (s);
                var geo = s.geometry ();
                m.signature = signature (geo.parts, m.w, m.h);
            }
            foreach (var o in masters) {
                if (o.name == m.name) {
                    m.name = "%s.%d".printf (m.name, m.id);
                    break;
                }
            }
            masters.add (m);
            master_by_kind[kind] = m;
            return m;
        }

        private void collect_masters () {
            foreach (var p in doc.pages) {
                foreach (var it in p.all_items ()) {
                    if (it is Connector) ensure_master ("sdraw-connector", true);
                    else if (master_kind (it)) ensure_master (((Shape) it).kind, false);
                }
            }
        }

        private static Gee.ArrayList<double?> signature (Gee.List<GeomPart> parts, double w, double h) {
            var sig = new Gee.ArrayList<double?> ();
            double sw = w > 1e-6 ? w : 1, sh = h > 1e-6 ? h : 1;
            foreach (var part in parts) {
                sig.add ((double) part.mode);
                foreach (var seg in part.path.segs) {
                    sig.add ((double) seg.kind);
                    sig.add (seg.x / sw);
                    sig.add (seg.y / sh);
                    if (seg.kind == SegKind.CURVE) {
                        sig.add (seg.x1 / sw);
                        sig.add (seg.y1 / sh);
                        sig.add (seg.x2 / sw);
                        sig.add (seg.y2 / sh);
                    }
                }
            }
            return sig;
        }

        private static bool same_signature (Gee.List<double?> a, Gee.List<double?> b) {
            if (a.size != b.size) return false;
            for (int i = 0; i < a.size; i++) if ((a[i] - b[i]).abs () > 1e-4) return false;
            return true;
        }

        private static string rel_master (string id, int master) {
            return rel (id, "http://schemas.microsoft.com/visio/2010/relationships/master", "../masters/master%d.xml".printf (master));
        }

        public uint8[] write () throws Error {
            if (stencil != null) return write_stencil ();
            collect_masters ();
            for (int i = 0; i < doc.pages.size; i++) {
                page = doc.pages[i];
                ppi = page_ppi (page);
                Router.route_all (page);
                page_rels.clear ();
                page_masters.clear ();
                ids.clear ();
                next_sheet = 1;
                string xml = page_xml ();
                collect_comments (i);
                zip.add_text ("visio/pages/page%d.xml".printf (i + 1), xml);
                if (page_rels.size > 0 || page_masters.size > 0) {
                    var rw = new XmlWriter (true);
                    rw.start ("Relationships").attr ("xmlns", Vsdx.NS_REL);
                    foreach (string r in page_rels) rw.raw (r);
                    int k = page_rels.size;
                    foreach (var m in masters) if (page_masters.contains (m)) rw.raw (rel_master ("rId%d".printf (++k), m.id));
                    rw.end ();
                    zip.add_text ("visio/pages/_rels/page%d.xml.rels".printf (i + 1), rw.finish ());
                }
            }
            ppi = Units.PX_PER_IN;
            write_masters ();
            var th = doc.theme ();
            if (th != null) zip.add_text ("visio/theme/theme1.xml", theme_xml (th));
            if (comment_count > 0) zip.add_text ("visio/comments.xml", comments_xml ());
            zip.add_text ("[Content_Types].xml", content_types ());
            zip.add_text ("_rels/.rels", root_rels ());
            zip.add_text ("docProps/core.xml", core_xml ());
            zip.add_text ("docProps/app.xml", app_xml ());
            zip.add_text ("visio/document.xml", document_xml ());
            zip.add_text ("visio/_rels/document.xml.rels", document_rels ());
            zip.add_text ("visio/pages/pages.xml", pages_xml ());
            zip.add_text ("visio/pages/_rels/pages.xml.rels", pages_rels ());
            zip.add_text ("visio/windows.xml", windows_xml ());
            return zip.finish ();
        }

        private uint8[] write_stencil () throws Error {
            foreach (var sm in stencil.masters) {
                var m = new VMaster ();
                m.id = masters.size + 1;
                m.kind = "stencil:" + sm.id;
                m.name = sm.name;
                m.w = double.max (sm.w, 1);
                m.h = double.max (sm.h, 1);
                m.source = sm;
                masters.add (m);
            }
            doc.title = stencil.name;
            write_masters ();
            zip.add_text ("[Content_Types].xml", content_types ());
            zip.add_text ("_rels/.rels", root_rels ());
            zip.add_text ("docProps/core.xml", core_xml ());
            zip.add_text ("docProps/app.xml", app_xml ());
            zip.add_text ("visio/document.xml", document_xml ());
            zip.add_text ("visio/_rels/document.xml.rels", document_rels ());
            return zip.finish ();
        }

        private static string guid_for (string seed) {
            string h = Checksum.compute_for_string (ChecksumType.MD5, seed).up ();
            return "{%s-%s-%s-%s-%s}".printf (h.substring (0, 8), h.substring (8, 4), h.substring (12, 4), h.substring (16, 4), h.substring (20, 12));
        }

        private void write_masters () throws Error {
            if (masters.size == 0) return;
            var w = new XmlWriter (true);
            w.start ("Masters").attr ("xmlns", Vsdx.NS).attr ("xmlns:r", Vsdx.NS_R).attr ("xml:space", "preserve");
            var rw = new XmlWriter (true);
            rw.start ("Relationships").attr ("xmlns", Vsdx.NS_REL);
            foreach (var m in masters) {
                w.start ("Master").attr ("ID", m.id.to_string ()).attr ("NameU", m.name).attr ("IsCustomNameU", "1").attr ("Name", m.name)
                    .attr ("IsCustomName", "1").attr ("Prompt", m.source != null ? m.source.keywords : "").attr ("IconSize", "1").attr ("AlignName", "2")
                    .attr ("MatchByName", "0").attr ("IconUpdate", "1").attr ("UniqueID", guid_for ("u" + m.kind)).attr ("BaseID", guid_for ("b" + m.kind))
                    .attr ("PatternFlags", "0").attr ("Hidden", "0").attr ("MasterType", "2");
                w.start ("PageSheet").attr ("LineStyle", "0").attr ("FillStyle", "0").attr ("TextStyle", "0");
                cell_num (w, "PageWidth", m.w / Units.PX_PER_IN, "IN");
                cell_num (w, "PageHeight", double.max (m.h, 1) / Units.PX_PER_IN, "IN");
                cell (w, "ShdwOffsetX", "0.125", "IN");
                cell (w, "ShdwOffsetY", "-0.125", "IN");
                cell (w, "PageScale", "1", "IN");
                cell (w, "DrawingScale", "1", "IN");
                cell (w, "DrawingSizeType", "4");
                cell (w, "DrawingScaleType", "0");
                cell (w, "InhibitSnap", "0");
                cell (w, "UIVisibility", "0");
                cell (w, "DrawingResizeType", "0");
                w.end ();
                w.start ("Rel").attr ("r:id", "rId%d".printf (m.id)).end ();
                w.end ();
                rw.raw (rel ("rId%d".printf (m.id), "http://schemas.microsoft.com/visio/2010/relationships/master", "master%d.xml".printf (m.id)));
                zip.add_text ("visio/masters/master%d.xml".printf (m.id), master_xml (m));
            }
            w.end ();
            rw.end ();
            zip.add_text ("visio/masters/masters.xml", w.finish ());
            zip.add_text ("visio/masters/_rels/masters.xml.rels", rw.finish ());
        }

        private static void cell_f (XmlWriter w, string n, double v, string? f, string? u = null) {
            w.start ("Cell").attr ("N", n).attr ("V", Vsdx.num (v));
            if (u != null) w.attr ("U", u);
            if (f != null) w.attr ("F", f);
            w.end ();
        }

        private static string frac_formula (string dim, double frac) {
            if (frac.abs () < 1e-9) return "%s*0".printf (dim);
            return "%s*%s".printf (dim, PathData.fmt (frac, 8));
        }

        private string master_xml (VMaster m) {
            var w = new XmlWriter (true);
            w.start ("MasterContents").attr ("xmlns", Vsdx.NS).attr ("xmlns:r", Vsdx.NS_R).attr ("xml:space", "preserve");
            w.start ("Shapes");
            if (m.source != null) {
                write_stencil_master (w, m);
            } else if (m.connector) {
                write_connector_master (w, m);
            } else {
                write_shape_master (w, m);
            }
            w.end ();
            w.end ();
            return w.finish ();
        }

        private void write_stencil_master (XmlWriter w, VMaster m) {
            var items = m.source.items ();
            page = new Page ("");
            page.width = m.w;
            page.height = m.h;
            foreach (var it in items) page.items.add (it);
            Router.route_all (page);
            ids.clear ();
            next_sheet = 5;
            Item top;
            if (items.size == 1) {
                top = items[0];
            } else {
                var g = new Group ();
                g.id = "g0";
                foreach (var it in items) g.children.add (it);
                page.items.clear ();
                page.items.add (g);
                top = g;
            }
            assign_ids (page.items);
            write_item (w, top, new VFrame (0, m.h, Units.PX_PER_IN));
        }

        private void write_connector_master (XmlWriter w, VMaster m) {
            w.start ("Shape").attr ("ID", "5").attr ("NameU", m.name).attr ("IsCustomNameU", "1").attr ("Name", m.name).attr ("IsCustomName", "1")
                .attr ("Type", "Shape").attr ("LineStyle", "3").attr ("FillStyle", "3").attr ("TextStyle", "3");
            cell_f (w, "PinX", 0.5, "GUARD((BeginX+EndX)/2)");
            cell_f (w, "PinY", 0, "GUARD((BeginY+EndY)/2)");
            cell_f (w, "Width", 1, "GUARD(EndX-BeginX)");
            cell_f (w, "Height", 0, "GUARD(EndY-BeginY)");
            cell_f (w, "LocPinX", 0.5, "GUARD(Width*0.5)");
            cell_f (w, "LocPinY", 0, "GUARD(Height*0.5)");
            cell_f (w, "Angle", 0, "GUARD(0DA)");
            cell (w, "BeginX", "0");
            cell (w, "BeginY", "0");
            cell (w, "EndX", "1");
            cell (w, "EndY", "0");
            cell (w, "ObjType", "2");
            cell (w, "OneD", "1", "BOOL");
            cell (w, "ShapeRouteStyle", "1");
            cell (w, "ConFixedCode", "0");
            cell (w, "GlueType", "2");
            cell (w, "EndArrow", "4");
            cell (w, "NoAlignBox", "1", "BOOL");
            w.start ("Section").attr ("N", "User");
            user_row (w, "SDrawMasterKind", "connector");
            w.end ();
            w.start ("Section").attr ("N", "Geometry").attr ("IX", "0");
            cell (w, "NoFill", "1");
            cell (w, "NoLine", "0");
            cell (w, "NoShow", "0");
            cell (w, "NoSnap", "0");
            w.start ("Row").attr ("T", "MoveTo").attr ("IX", "1");
            cell_f (w, "X", 0, "Width*0");
            cell_f (w, "Y", 0, "Height*0");
            w.end ();
            w.start ("Row").attr ("T", "LineTo").attr ("IX", "2");
            cell_f (w, "X", 1, "Width*1");
            cell_f (w, "Y", 0, "Height*1");
            w.end ();
            w.end ();
            w.end ();
        }

        private void write_shape_master (XmlWriter w, VMaster m) {
            var s = new Shape (m.kind, 0, 0, m.w, m.h);
            ShapeLibrary.apply_defaults (s);
            double wi = m.w / Units.PX_PER_IN, hi = m.h / Units.PX_PER_IN;
            w.start ("Shape").attr ("ID", "5").attr ("NameU", m.name).attr ("IsCustomNameU", "1").attr ("Name", m.name).attr ("IsCustomName", "1")
                .attr ("Type", "Shape").attr ("LineStyle", "3").attr ("FillStyle", "3").attr ("TextStyle", "3");
            cell_num (w, "PinX", wi / 2, "IN");
            cell_num (w, "PinY", hi / 2, "IN");
            cell_num (w, "Width", wi, "IN");
            cell_num (w, "Height", hi, "IN");
            cell_f (w, "LocPinX", wi / 2, "Width*0.5", "IN");
            cell_f (w, "LocPinY", hi / 2, "Height*0.5", "IN");
            cell (w, "Angle", "0", "DEG");
            cell (w, "FlipX", "0", "BOOL");
            cell (w, "FlipY", "0", "BOOL");
            cell (w, "ResizeMode", "0");
            style_cells (w, s.style, false);
            var geo = s.geometry ();
            var tr = geo.text_rect;
            if (tr.w > 0 && tr.h > 0 && m.w > 0 && m.h > 0) {
                cell_f (w, "TxtPinX", (tr.x + tr.w / 2) / Units.PX_PER_IN, frac_formula ("Width", (tr.x + tr.w / 2) / m.w), "IN");
                cell_f (w, "TxtPinY", (m.h - tr.y - tr.h / 2) / Units.PX_PER_IN, frac_formula ("Height", (m.h - tr.y - tr.h / 2) / m.h), "IN");
                cell_f (w, "TxtWidth", tr.w / Units.PX_PER_IN, frac_formula ("Width", tr.w / m.w), "IN");
                cell_f (w, "TxtHeight", tr.h / Units.PX_PER_IN, frac_formula ("Height", tr.h / m.h), "IN");
                cell_f (w, "TxtLocPinX", tr.w / 2 / Units.PX_PER_IN, "TxtWidth*0.5", "IN");
                cell_f (w, "TxtLocPinY", tr.h / 2 / Units.PX_PER_IN, "TxtHeight*0.5", "IN");
                cell (w, "TxtAngle", "0");
            }
            w.start ("Section").attr ("N", "User");
            user_row (w, "SDrawMasterKind", m.kind);
            w.end ();
            text_sections (w, s.style, false);
            var ports = s.ports ();
            if (ports.length > 0) {
                w.start ("Section").attr ("N", "Connection");
                for (int i = 0; i < ports.length; i++) {
                    w.start ("Row").attr ("IX", i.to_string ());
                    cell_f (w, "X", ports[i].x * wi, frac_formula ("Width", ports[i].x), "IN");
                    cell_f (w, "Y", (1 - ports[i].y) * hi, frac_formula ("Height", 1 - ports[i].y), "IN");
                    cell (w, "DirX", "0");
                    cell (w, "DirY", "0");
                    cell (w, "Type", "0");
                    cell (w, "AutoGen", "0", "BOOL");
                    w.end ();
                }
                w.end ();
            }
            write_geometry (w, geo.parts, m.w, m.h, true);
            w.end ();
        }

        private string theme_xml (Theme t) {
            var w = new XmlWriter (true);
            w.start ("a:theme").attr ("xmlns:a", "http://schemas.openxmlformats.org/drawingml/2006/main").attr ("name", t.name);
            w.start ("a:themeElements");
            w.start ("a:clrScheme").attr ("name", t.name);
            string[] names = { "dk1", "lt1", "dk2", "lt2", "accent1", "accent2", "accent3", "accent4", "accent5", "accent6", "hlink", "folHlink" };
            string[] vals = { t.dark, t.light, t.line, t.background, t.accents[0], t.accents[1], t.accents[2], t.accents[3], t.accents[4], t.accents[5], t.accents[0], t.accents[4] };
            for (int i = 0; i < names.length; i++) {
                w.start ("a:" + names[i]);
                w.start ("a:srgbClr").attr ("val", Colors.rgb_hex (vals[i]).substring (1).up ()).end ();
                w.end ();
            }
            w.start ("a:extLst");
            w.start ("a:ext").attr ("uri", "{093E89EA-6996-430E-BFF9-83A9FAAAAB73}");
            w.start ("vt:bkgnd").attr ("xmlns:vt", "http://schemas.microsoft.com/office/visio/2012/theme");
            w.start ("a:srgbClr").attr ("val", Colors.rgb_hex (t.background).substring (1).up ()).end ();
            w.end ();
            w.end ();
            w.end ();
            w.end ();
            w.start ("a:fontScheme").attr ("name", t.name);
            foreach (string kind in new string[] { "a:majorFont", "a:minorFont" }) {
                w.start (kind);
                w.start ("a:latin").attr ("typeface", kind == "a:majorFont" ? t.heading_font : t.font).end ();
                w.start ("a:ea").attr ("typeface", "").end ();
                w.start ("a:cs").attr ("typeface", "").end ();
                w.end ();
            }
            w.end ();
            w.start ("a:fmtScheme").attr ("name", t.name);
            w.start ("a:fillStyleLst");
            for (int i = 0; i < 3; i++) {
                w.start ("a:solidFill");
                w.start ("a:schemeClr").attr ("val", "phClr").end ();
                w.end ();
            }
            w.end ();
            w.start ("a:lnStyleLst");
            for (int i = 0; i < 3; i++) {
                w.start ("a:ln").attr ("w", (9525 * (i + 1)).to_string ());
                w.start ("a:solidFill");
                w.start ("a:schemeClr").attr ("val", "phClr").end ();
                w.end ();
                w.end ();
            }
            w.end ();
            w.start ("a:effectStyleLst");
            for (int i = 0; i < 3; i++) {
                w.start ("a:effectStyle");
                w.start ("a:effectLst").end ();
                w.end ();
            }
            w.end ();
            w.start ("a:bgFillStyleLst");
            for (int i = 0; i < 3; i++) {
                w.start ("a:solidFill");
                w.start ("a:schemeClr").attr ("val", "phClr").end ();
                w.end ();
            }
            w.end ();
            w.end ();
            w.end ();
            w.end ();
            return w.finish ();
        }

        private int author_index (string name) {
            int i = comment_authors.index_of (name);
            if (i >= 0) return i;
            comment_authors.add (name);
            return comment_authors.size - 1;
        }

        private void add_comment_entry (Comment c, int page_index) {
            var w = new XmlWriter (false);
            w.start ("CommentEntry").attr ("AuthorID", author_index (c.author).to_string ()).attr ("PageID", page_index.to_string ());
            var it = c.item_id != "" ? page.find (c.item_id) : null;
            if (it != null && ids.has_key (it)) w.attr ("ShapeID", ids[it].to_string ());
            string date = new DateTime.from_unix_utc (c.time).format ("%Y-%m-%dT%H:%M:%S");
            w.attr ("Date", date).attr ("EditDate", date).attr ("Done", c.resolved ? "1" : "0").attr ("CommentID", comment_count.to_string ())
                .attr ("AutoCommentType", "0").text (c.text).end ();
            comment_entries.append (w.finish ());
            comment_count++;
            foreach (var r in c.replies) add_comment_entry (r, page_index);
        }

        private void collect_comments (int page_index) {
            foreach (var c in page.comments) add_comment_entry (c, page_index);
        }

        private string comments_xml () {
            var w = new XmlWriter (true);
            w.start ("Comments").attr ("xmlns", Vsdx.NS).attr ("xmlns:r", Vsdx.NS_R).attr ("xml:space", "preserve").attr ("ShowCommentTags", "0");
            w.start ("AuthorList");
            for (int i = 0; i < comment_authors.size; i++) {
                w.start ("AuthorEntry").attr ("ID", i.to_string ()).attr ("Name", comment_authors[i]).attr ("Initials", Comment.initials_of (comment_authors[i]))
                    .attr ("ResolutionID", guid_for ("a" + comment_authors[i])).end ();
            }
            w.end ();
            w.raw ("<CommentList>" + comment_entries.str + "</CommentList>");
            w.end ();
            return w.finish ();
        }

        private string content_types () {
            var w = new XmlWriter (true);
            w.start ("Types").attr ("xmlns", "http://schemas.openxmlformats.org/package/2006/content-types");
            w.start ("Default").attr ("Extension", "rels").attr ("ContentType", "application/vnd.openxmlformats-package.relationships+xml").end ();
            w.start ("Default").attr ("Extension", "xml").attr ("ContentType", "application/xml").end ();
            foreach (string ext in media_exts) w.start ("Default").attr ("Extension", ext).attr ("ContentType", Vsdx.content_type_for (ext)).end ();
            w.start ("Override").attr ("PartName", "/visio/document.xml").attr ("ContentType", stencil != null ? "application/vnd.ms-visio.stencil.main+xml" : "application/vnd.ms-visio.drawing.main+xml").end ();
            if (stencil == null) {
                w.start ("Override").attr ("PartName", "/visio/pages/pages.xml").attr ("ContentType", "application/vnd.ms-visio.pages+xml").end ();
                for (int i = 0; i < doc.pages.size; i++) {
                    w.start ("Override").attr ("PartName", "/visio/pages/page%d.xml".printf (i + 1)).attr ("ContentType", "application/vnd.ms-visio.page+xml").end ();
                }
                w.start ("Override").attr ("PartName", "/visio/windows.xml").attr ("ContentType", "application/vnd.ms-visio.windows+xml").end ();
            }
            if (masters.size > 0) {
                w.start ("Override").attr ("PartName", "/visio/masters/masters.xml").attr ("ContentType", "application/vnd.ms-visio.masters+xml").end ();
                foreach (var m in masters) w.start ("Override").attr ("PartName", "/visio/masters/master%d.xml".printf (m.id)).attr ("ContentType", "application/vnd.ms-visio.master+xml").end ();
            }
            if (stencil == null && doc.theme () != null) w.start ("Override").attr ("PartName", "/visio/theme/theme1.xml").attr ("ContentType", "application/vnd.openxmlformats-officedocument.theme+xml").end ();
            if (comment_count > 0) w.start ("Override").attr ("PartName", "/visio/comments.xml").attr ("ContentType", "application/vnd.ms-visio.comments+xml").end ();
            w.start ("Override").attr ("PartName", "/docProps/core.xml").attr ("ContentType", "application/vnd.openxmlformats-package.core-properties+xml").end ();
            w.start ("Override").attr ("PartName", "/docProps/app.xml").attr ("ContentType", "application/vnd.openxmlformats-officedocument.extended-properties+xml").end ();
            w.end ();
            return w.finish ();
        }

        private static string rel (string id, string type, string target) {
            var w = new XmlWriter (false);
            w.start ("Relationship").attr ("Id", id).attr ("Type", type).attr ("Target", target).end ();
            return w.finish ();
        }

        private string root_rels () {
            var w = new XmlWriter (true);
            w.start ("Relationships").attr ("xmlns", Vsdx.NS_REL);
            w.raw (rel ("rId1", "http://schemas.microsoft.com/visio/2010/relationships/document", "visio/document.xml"));
            w.raw (rel ("rId2", "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties", "docProps/core.xml"));
            w.raw (rel ("rId3", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties", "docProps/app.xml"));
            w.end ();
            return w.finish ();
        }

        private string core_xml () {
            var w = new XmlWriter (true);
            w.start ("cp:coreProperties").attr ("xmlns:cp", "http://schemas.openxmlformats.org/package/2006/metadata/core-properties")
                .attr ("xmlns:dc", "http://purl.org/dc/elements/1.1/").attr ("xmlns:dcterms", "http://purl.org/dc/terms/")
                .attr ("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance");
            if (doc.title != "") w.element ("dc:title", doc.title);
            var now = new DateTime.now_utc ();
            w.start ("dcterms:created").attr ("xsi:type", "dcterms:W3CDTF").text (now.format ("%Y-%m-%dT%H:%M:%SZ")).end ();
            w.start ("dcterms:modified").attr ("xsi:type", "dcterms:W3CDTF").text (now.format ("%Y-%m-%dT%H:%M:%SZ")).end ();
            w.end ();
            return w.finish ();
        }

        private string app_xml () {
            var w = new XmlWriter (true);
            w.start ("Properties").attr ("xmlns", "http://schemas.openxmlformats.org/officeDocument/2006/extended-properties");
            w.element ("Application", "Singularity Draw");
            w.element ("AppVersion", "15.0000");
            w.end ();
            return w.finish ();
        }

        private string document_xml () {
            var w = new XmlWriter (true);
            w.start ("VisioDocument").attr ("xmlns", Vsdx.NS).attr ("xmlns:r", Vsdx.NS_R).attr ("xml:space", "preserve");
            w.start ("DocumentSettings").attr ("TopPage", "0").attr ("DefaultTextStyle", "3").attr ("DefaultLineStyle", "3")
                .attr ("DefaultFillStyle", "3").attr ("DefaultGuideStyle", "4");
            w.element ("GlueSettings", "9");
            w.element ("SnapSettings", "65847");
            w.element ("SnapExtensions", "34");
            w.element ("DynamicGridEnabled", "1");
            w.element ("ProtectStyles", "0");
            w.element ("ProtectShapes", "0");
            w.element ("ProtectMasters", "0");
            w.element ("ProtectBkgnds", "0");
            w.end ();
            w.start ("Colors");
            string[] palette = { "#000000", "#FFFFFF", "#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF", "#00FFFF" };
            for (int i = 0; i < palette.length; i++) w.start ("ColorEntry").attr ("IX", i.to_string ()).attr ("RGB", palette[i]).end ();
            w.end ();
            w.start ("FaceNames");
            w.start ("FaceName").attr ("NameU", "Calibri").attr ("UnicodeRanges", "-536859905 -1073732485 9 0").attr ("CharSets", "1610613247 -65536")
                .attr ("Panose", "2 15 5 2 2 2 4 3 2 4").attr ("Flags", "325").end ();
            w.end ();
            w.start ("StyleSheets");
            w.start ("StyleSheet").attr ("ID", "0").attr ("NameU", "No Style").attr ("IsCustomNameU", "1").attr ("Name", "No Style").attr ("IsCustomName", "1");
            cell (w, "EnableLineProps", "1");
            cell (w, "EnableFillProps", "1");
            cell (w, "EnableTextProps", "1");
            cell (w, "HideForApply", "0");
            cell (w, "LineWeight", "0.01041666666666667", "PT");
            cell (w, "LineColor", "0");
            cell (w, "LinePattern", "1");
            cell (w, "Rounding", "0", "IN");
            cell (w, "EndArrowSize", "2");
            cell (w, "BeginArrow", "0");
            cell (w, "EndArrow", "0");
            cell (w, "LineCap", "0");
            cell (w, "BeginArrowSize", "2");
            cell (w, "LineColorTrans", "0");
            cell (w, "FillForegnd", "1");
            cell (w, "FillBkgnd", "0");
            cell (w, "FillPattern", "1");
            cell (w, "ShdwForegnd", "0");
            cell (w, "ShdwPattern", "0");
            cell (w, "FillForegndTrans", "0");
            cell (w, "FillBkgndTrans", "0");
            cell (w, "ShdwForegndTrans", "0");
            cell (w, "ShapeShdwType", "0");
            cell (w, "ShapeShdwOffsetX", "0", "IN");
            cell (w, "ShapeShdwOffsetY", "0", "IN");
            cell (w, "LeftMargin", "0", "PT");
            cell (w, "RightMargin", "0", "PT");
            cell (w, "TopMargin", "0", "PT");
            cell (w, "BottomMargin", "0", "PT");
            cell (w, "VerticalAlign", "1");
            cell (w, "TextBkgnd", "0");
            cell (w, "TextDirection", "0");
            w.start ("Section").attr ("N", "Character");
            w.start ("Row").attr ("IX", "0");
            cell (w, "Font", "Calibri");
            cell (w, "Color", "0");
            cell (w, "Style", "0");
            cell (w, "Size", "0.1666666666666667", "PT");
            w.end ();
            w.end ();
            w.start ("Section").attr ("N", "Paragraph");
            w.start ("Row").attr ("IX", "0");
            cell (w, "HorzAlign", "1");
            w.end ();
            w.end ();
            w.end ();
            w.start ("StyleSheet").attr ("ID", "3").attr ("NameU", "Normal").attr ("IsCustomNameU", "1").attr ("Name", "Normal")
                .attr ("IsCustomName", "1").attr ("LineStyle", "0").attr ("FillStyle", "0").attr ("TextStyle", "0").end ();
            w.start ("StyleSheet").attr ("ID", "4").attr ("NameU", "Guide").attr ("IsCustomNameU", "1").attr ("Name", "Guide")
                .attr ("IsCustomName", "1").attr ("LineStyle", "0").attr ("FillStyle", "0").attr ("TextStyle", "0");
            cell (w, "LinePattern", "23");
            cell (w, "FillPattern", "0");
            w.end ();
            w.end ();
            w.start ("DocumentSheet").attr ("NameU", "TheDoc").attr ("IsCustomNameU", "1").attr ("Name", "TheDoc").attr ("IsCustomName", "1")
                .attr ("LineStyle", "0").attr ("FillStyle", "0").attr ("TextStyle", "0");
            w.start ("Section").attr ("N", "User");
            user_row (w, "SDrawGrid", Vsdx.num (doc.grid_size));
            user_row (w, "SDrawUnits", doc.units);
            user_row (w, "SDrawTitle", doc.title);
            user_row (w, "SDrawPageIndex", doc.page_index.to_string ());
            if (doc.theme_id != "") {
                user_row (w, "SDrawTheme", doc.theme_id);
                user_row (w, "SDrawThemeVariant", doc.theme_variant.to_string ());
            }
            w.end ();
            w.end ();
            w.end ();
            return w.finish ();
        }

        private string document_rels () {
            var w = new XmlWriter (true);
            w.start ("Relationships").attr ("xmlns", Vsdx.NS_REL);
            if (stencil == null) {
                w.raw (rel ("rId1", "http://schemas.microsoft.com/visio/2010/relationships/pages", "pages/pages.xml"));
                w.raw (rel ("rId2", "http://schemas.microsoft.com/visio/2010/relationships/windows", "windows.xml"));
            }
            if (masters.size > 0) w.raw (rel ("rId3", "http://schemas.microsoft.com/visio/2010/relationships/masters", "masters/masters.xml"));
            if (stencil == null && doc.theme () != null) w.raw (rel ("rId4", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme", "theme/theme1.xml"));
            if (comment_count > 0) w.raw (rel ("rId5", "http://schemas.microsoft.com/visio/2010/relationships/comments", "comments.xml"));
            w.end ();
            return w.finish ();
        }

        private static string unit_code (string u) {
            switch (u) {
                case "mm": return "MM";
                case "cm": return "CM";
                case "m": return "M";
                case "km": return "KM";
                case "ft": return "FT";
                case "yd": return "YD";
                case "mi": return "MI";
                default: return "IN";
            }
        }

        private string pages_xml () {
            var w = new XmlWriter (true);
            w.start ("Pages").attr ("xmlns", Vsdx.NS).attr ("xmlns:r", Vsdx.NS_R).attr ("xml:space", "preserve");
            for (int i = 0; i < doc.pages.size; i++) {
                var p = doc.pages[i];
                double pp = page_ppi (p);
                w.start ("Page").attr ("ID", i.to_string ()).attr ("NameU", p.name).attr ("IsCustomNameU", "1").attr ("Name", p.name)
                    .attr ("IsCustomName", "1");
                if (p.is_background) w.attr ("Background", "1");
                var bg = doc.background_of (p);
                if (bg != null && doc.pages.index_of (bg) >= 0) w.attr ("BackPage", doc.pages.index_of (bg).to_string ());
                w.attr ("ViewScale", "1").attr ("ViewCenterX", Vsdx.num (p.width / 2 / pp)).attr ("ViewCenterY", Vsdx.num (p.height / 2 / pp));
                w.start ("PageSheet").attr ("LineStyle", "0").attr ("FillStyle", "0").attr ("TextStyle", "0");
                cell_num (w, "PageWidth", p.width / pp, "IN");
                cell_num (w, "PageHeight", p.height / pp, "IN");
                cell (w, "ShdwOffsetX", "0.125", "IN");
                cell (w, "ShdwOffsetY", "-0.125", "IN");
                if (p.has_scale ()) {
                    cell_num (w, "PageScale", p.scale_paper * Units.mm_per (p.scale_paper_units) / 25.4, unit_code (p.scale_paper_units));
                    cell_num (w, "DrawingScale", p.scale_world * Units.mm_per (p.scale_units) / 25.4, unit_code (p.scale_units));
                    cell (w, "DrawingSizeType", "3");
                    cell (w, "DrawingScaleType", "3");
                } else {
                    cell (w, "PageScale", "1", "IN");
                    cell (w, "DrawingScale", "1", "IN");
                    cell (w, "DrawingSizeType", "0");
                    cell (w, "DrawingScaleType", "0");
                }
                cell (w, "LineJumpCode", p.jump_style == JumpStyle.NONE ? "0" : (p.jumps_vertical ? "2" : "1"));
                cell (w, "PageLineJumpStyle", p.jump_style == JumpStyle.GAP ? "2" : (p.jump_style == JumpStyle.SQUARE ? "3" : "1"));
                cell_num (w, "LineJumpFactorX", p.jump_size * 0.66666667);
                cell_num (w, "LineJumpFactorY", p.jump_size * 0.66666667);
                cell (w, "InhibitSnap", "0");
                cell (w, "PageLockReplace", "0", "BOOL");
                cell (w, "PageLockDuplicate", "0", "BOOL");
                cell (w, "UIVisibility", "0");
                cell (w, "ShdwType", "0");
                cell (w, "ShdwObliqueAngle", "0");
                cell (w, "ShdwScaleFactor", "1");
                cell (w, "DrawingResizeType", "1");
                cell (w, "PageShapeSplit", "1");
                w.start ("Section").attr ("N", "User");
                user_row (w, "SDrawPageId", p.id);
                user_row (w, "SDrawBackground", p.background);
                var lids = new StringBuilder ();
                foreach (var l in p.layers) {
                    if (lids.len > 0) lids.append_c (';');
                    lids.append (l.id);
                }
                user_row (w, "SDrawLayerIds", lids.str);
                user_row (w, "SDrawActiveLayer", p.active_layer);
                if (p.comments.size > 0) {
                    var cw = new XmlWriter (false);
                    cw.start ("comments");
                    foreach (var c in p.comments) NativeFormat.write_comment (cw, c);
                    cw.end ();
                    user_row (w, "SDrawComments", cw.finish ());
                }
                w.end ();
                if (p.layers.size > 0) {
                    w.start ("Section").attr ("N", "Layer");
                    for (int li = 0; li < p.layers.size; li++) {
                        var l = p.layers[li];
                        w.start ("Row").attr ("IX", li.to_string ());
                        cell (w, "Name", l.name, "STR");
                        cell (w, "Color", "255");
                        cell (w, "Status", "0");
                        cell (w, "Visible", l.visible ? "1" : "0");
                        cell (w, "Print", l.printable ? "1" : "0");
                        cell (w, "Active", l.id == p.active_layer ? "1" : "0");
                        cell (w, "Lock", l.locked ? "1" : "0");
                        cell (w, "Snap", "1");
                        cell (w, "Glue", "1");
                        cell (w, "NameUniv", l.name, "STR");
                        cell (w, "ColorTrans", "0");
                        w.end ();
                    }
                    w.end ();
                }
                w.end ();
                w.start ("Rel").attr ("r:id", "rId%d".printf (i + 1)).end ();
                w.end ();
            }
            w.end ();
            return w.finish ();
        }

        private string pages_rels () {
            var w = new XmlWriter (true);
            w.start ("Relationships").attr ("xmlns", Vsdx.NS_REL);
            for (int i = 0; i < doc.pages.size; i++) {
                w.raw (rel ("rId%d".printf (i + 1), "http://schemas.microsoft.com/visio/2010/relationships/page", "page%d.xml".printf (i + 1)));
            }
            w.end ();
            return w.finish ();
        }

        private string windows_xml () {
            var w = new XmlWriter (true);
            w.start ("Windows").attr ("ClientWidth", "1600").attr ("ClientHeight", "900").attr ("xmlns", Vsdx.NS).attr ("xmlns:r", Vsdx.NS_R)
                .attr ("xml:space", "preserve");
            int pi = doc.page_index.clamp (0, doc.pages.size - 1);
            var p = doc.pages[pi];
            w.start ("Window").attr ("ID", "0").attr ("WindowType", "Drawing").attr ("WindowState", "1073741824").attr ("WindowLeft", "0")
                .attr ("WindowTop", "0").attr ("WindowWidth", "1600").attr ("WindowHeight", "900").attr ("ContainerType", "Page")
                .attr ("Page", pi.to_string ()).attr ("ViewScale", "1").attr ("ViewCenterX", Vsdx.num (p.width / 2 / page_ppi (p)))
                .attr ("ViewCenterY", Vsdx.num (p.height / 2 / page_ppi (p)));
            w.element ("ShowRulers", "1");
            w.element ("ShowGrid", "1");
            w.element ("ShowPageBreaks", "0");
            w.element ("ShowGuides", "1");
            w.element ("ShowConnectionPoints", "1");
            w.element ("GlueSettings", "9");
            w.element ("SnapSettings", "65847");
            w.element ("SnapExtensions", "34");
            w.element ("DynamicGridEnabled", "1");
            w.end ();
            w.end ();
            return w.finish ();
        }

        private void assign_ids (Gee.List<Item> items) {
            foreach (var it in items) {
                ids[it] = next_sheet++;
                var g = it as Group;
                if (g != null) assign_ids (g.children);
                var tb = it as TableShape;
                if (tb != null) next_sheet += tb.rows * tb.cols;
            }
        }

        private string page_xml () {
            assign_ids (page.items);
            var w = new XmlWriter (true);
            w.start ("PageContents").attr ("xmlns", Vsdx.NS).attr ("xmlns:r", Vsdx.NS_R).attr ("xml:space", "preserve");
            var frame = new VFrame (0, page.height, ppi);
            if (page.items.size > 0 || page.guides.size > 0) {
                w.start ("Shapes");
                foreach (var it in page.items) write_item (w, it, frame);
                foreach (var g in page.guides) write_guide (w, g, frame);
                w.end ();
            }
            var connects = new StringBuilder ();
            foreach (var c in page.connectors ()) {
                if (!ids.has_key (c)) continue;
                connect_row (connects, c, c.src, true);
                connect_row (connects, c, c.dst, false);
            }
            if (connects.len > 0) w.raw ("<Connects>" + connects.str + "</Connects>");
            w.end ();
            return w.finish ();
        }

        private void write_guide (XmlWriter w, PageGuide g, VFrame f) {
            w.start ("Shape").attr ("ID", (next_sheet++).to_string ()).attr ("Type", "Guide").attr ("LineStyle", "4").attr ("FillStyle", "4").attr ("TextStyle", "4");
            cell_num (w, "PinX", g.vertical ? f.fx (g.pos) : 0, "IN");
            cell_num (w, "PinY", g.vertical ? 0 : f.fy (g.pos), "IN");
            cell (w, "Width", "0", "IN");
            cell (w, "Height", "0", "IN");
            cell (w, "Angle", g.vertical ? "1.570796326794897" : "0", "DEG");
            w.start ("Section").attr ("N", "Geometry").attr ("IX", "0");
            cell (w, "NoFill", "1");
            cell (w, "NoLine", "0");
            cell (w, "NoShow", "0");
            w.start ("Row").attr ("T", "InfiniteLine").attr ("IX", "1");
            cell (w, "X", "0");
            cell (w, "Y", "0");
            cell (w, "A", "1");
            cell (w, "B", "0");
            w.end ();
            w.end ();
            w.end ();
        }

        private void connect_row (StringBuilder sb, Connector c, Endpoint e, bool begin) {
            if (!e.attached ()) return;
            var target = page.find (e.item_id);
            if (target == null || target is Connector || !ids.has_key (target)) return;
            var s = target as Shape;
            string to_cell = "PinX";
            int to_part = 3;
            if (s != null && e.port >= 0 && e.port < s.ports ().length) {
                to_cell = "Connections.X%d".printf (e.port + 1);
                to_part = 100 + e.port;
            }
            var w = new XmlWriter (false);
            w.start ("Connect").attr ("FromSheet", ids[c].to_string ()).attr ("FromCell", begin ? "BeginX" : "EndX")
                .attr ("FromPart", begin ? "9" : "12").attr ("ToSheet", ids[target].to_string ()).attr ("ToCell", to_cell)
                .attr ("ToPart", to_part.to_string ()).end ();
            sb.append (w.finish ());
        }

        private void write_common_user (XmlWriter w, Item it, string kind) {
            w.start ("Section").attr ("N", "User");
            user_row (w, "SDrawId", it.id);
            user_row (w, "SDrawKind", kind);
            user_row (w, "SDrawStyle", it.style.serialize ());
            if (it.name != "") user_row (w, "SDrawName", it.name);
            if (it.layer_id != "") user_row (w, "SDrawLayer", it.layer_id);
            if (it.locked) user_row (w, "SDrawLocked", "1");
            if (it.container_id != "") user_row (w, "SDrawContainer", it.container_id);
            if (it.link != "") user_row (w, "SDrawLink", it.link);
            var s = it as Shape;
            if (s != null) {
                user_row (w, "SDrawBox", "%s %s %s %s %s %s %s".printf (Vsdx.num (s.x), Vsdx.num (s.y), Vsdx.num (s.w), Vsdx.num (s.h),
                    Vsdx.num (s.rotation), s.flip_h ? "1" : "0", s.flip_v ? "1" : "0"));
            }
            var ps = it as PathShape;
            if (ps != null) {
                user_row (w, "SDrawPath", ps.path.to_svg (4));
                user_row (w, "SDrawNatural", "%s %s".printf (Vsdx.num (ps.natural_w), Vsdx.num (ps.natural_h)));
            }
            var img = it as ImageShape;
            if (img != null) user_row (w, "SDrawMime", img.mime);
            var tb = it as TableShape;
            if (tb != null) user_row (w, "SDrawItem", NativeFormat.serialize_items (new Gee.ArrayList<Item>.wrap ({ tb })));
            if (it.sheet != null && !it.sheet.is_empty ()) user_row (w, "SDrawHasSheet", "1");
            if (s != null && s.custom_ports != null) user_row (w, "SDrawPorts", NativeFormat.points_to_string (s.custom_ports));
            if (it.alt_title != "") user_row (w, "SDrawAltTitle", it.alt_title);
            if (it.alt_text != "") user_row (w, "SDrawAltText", it.alt_text);
            var us = it.sheet != null ? it.sheet.section ("User") : null;
            if (us != null) {
                foreach (var r in us.rows) {
                    if (r.deleted || r.name == null || r.name.has_prefix ("SDraw")) continue;
                    w.start ("Row").attr ("N", r.name);
                    foreach (var c in r.cells) write_sheet_cell (w, c);
                    w.end ();
                }
            }
            var c = it as Connector;
            if (c != null) {
                user_row (w, "SDrawRoute", c.route.to_id ());
                user_row (w, "SDrawSrc", "%s|%d|%s|%s".printf (c.src.item_id, c.src.port, Vsdx.num (c.src.x), Vsdx.num (c.src.y)));
                user_row (w, "SDrawDst", "%s|%d|%s|%s".printf (c.dst.item_id, c.dst.port, Vsdx.num (c.dst.x), Vsdx.num (c.dst.y)));
                if (c.waypoints.length > 0) user_row (w, "SDrawWaypoints", NativeFormat.points_to_string (c.waypoints));
                user_row (w, "SDrawLabelPos", Vsdx.num (c.label_pos));
                if (c.jumps) user_row (w, "SDrawJumps", "1");
            }
            w.end ();
            var psec = it.sheet != null ? it.sheet.section ("Property") : null;
            if (it.fields.size > 0) {
                w.start ("Section").attr ("N", "Property");
                for (int i = 0; i < it.fields.size; i++) {
                    SheetRow? pr = null;
                    if (psec != null) {
                        foreach (var r in psec.rows) {
                            var lc = r.get_cell ("Label");
                            if ((lc != null && lc.value == it.fields[i].key) || r.name == it.fields[i].key) pr = r;
                        }
                    }
                    w.start ("Row").attr ("N", pr != null && pr.name != null ? pr.name : "Row_%d".printf (i + 1));
                    var vc = pr != null ? pr.get_cell ("Value") : null;
                    if (vc != null && vc.has_formula () && vc.value == it.fields[i].value) write_sheet_cell (w, vc);
                    else cell (w, "Value", it.fields[i].value, "STR");
                    cell (w, "Prompt", "", "STR");
                    cell (w, "Label", it.fields[i].key, "STR");
                    cell (w, "Format", "", "STR");
                    cell (w, "SortKey", "", "STR");
                    cell (w, "Type", "0");
                    cell (w, "Invisible", "0", "BOOL");
                    cell (w, "Verify", "0", "BOOL");
                    cell (w, "DataLinked", "0", "BOOL");
                    cell (w, "LangID", "en-US");
                    cell (w, "Calendar", "0");
                    w.end ();
                }
                w.end ();
            }
        }

        private int layer_index (Item it) {
            for (int i = 0; i < page.layers.size; i++) if (page.layers[i].id == it.layer_id) return i;
            return page.layers.size > 0 ? 0 : -1;
        }

        private void style_cells (XmlWriter w, Style st, bool one_d) {
            double trans;
            if (st.has_stroke ()) {
                cell_num (w, "LineWeight", st.stroke_width / Units.PX_PER_IN, "PT");
                cell (w, "LineColor", color_value (st.stroke, out trans));
                cell_num (w, "LineColorTrans", trans);
                cell (w, "LinePattern", Vsdx.dash_to_visio (st.dash).to_string ());
            } else {
                cell (w, "LinePattern", "0");
            }
            cell_num (w, "Rounding", st.corner_radius / ppi, "IN");
            cell (w, "BeginArrow", Vsdx.arrow_to_visio (st.arrow_start).to_string ());
            cell (w, "EndArrow", Vsdx.arrow_to_visio (st.arrow_end).to_string ());
            string sz = ((int) Math.round (st.arrow_size * 2)).clamp (0, 6).to_string ();
            cell (w, "BeginArrowSize", sz);
            cell (w, "EndArrowSize", sz);
            if (!one_d && st.has_fill ()) {
                cell (w, "FillForegnd", color_value (st.fill, out trans));
                cell_num (w, "FillForegndTrans", trans);
                cell (w, "FillBkgnd", color_value (st.fill2, out trans));
                cell_num (w, "FillBkgndTrans", trans);
                cell (w, "FillPattern", "1");
                bool grad = st.fill_kind == FillKind.LINEAR || st.fill_kind == FillKind.RADIAL;
                cell (w, "FillGradientEnabled", grad ? "1" : "0");
                if (grad) {
                    cell (w, "FillGradientDir", st.fill_kind == FillKind.RADIAL ? "13" : "0");
                    cell_num (w, "FillGradientAngle", -st.gradient_angle * Math.PI / 180, "DEG");
                }
            } else {
                cell (w, "FillPattern", "0");
            }
            if (st.shadow) {
                cell (w, "ShdwPattern", "1");
                cell (w, "ShdwForegnd", color_value (st.shadow_color, out trans));
                cell_num (w, "ShdwForegndTrans", trans);
                cell (w, "ShapeShdwType", "1");
                cell_num (w, "ShapeShdwOffsetX", st.shadow_dx / ppi, "IN");
                cell_num (w, "ShapeShdwOffsetY", -st.shadow_dy / ppi, "IN");
                cell_num (w, "ShapeShdwBlur", st.shadow_blur / Units.PX_PER_IN, "PT");
            } else {
                cell (w, "ShdwPattern", "0");
            }
            cell (w, "VerticalAlign", st.valign == TextVAlign.TOP ? "0" : (st.valign == TextVAlign.BOTTOM ? "2" : "1"));
            if (st.quick_color >= 0) {
                string qc = st.quick_color == 0 ? "0" : (st.quick_color + 1).to_string ();
                string qm = (st.quick_style + 1).clamp (1, 6).to_string ();
                cell (w, "QuickStyleLineColor", qc);
                cell (w, "QuickStyleFillColor", qc);
                cell (w, "QuickStyleShadowColor", qc);
                cell (w, "QuickStyleFontColor", "1");
                cell (w, "QuickStyleLineMatrix", qm);
                cell (w, "QuickStyleFillMatrix", qm);
                cell (w, "QuickStyleEffectsMatrix", st.shadow ? "1" : "0");
                cell (w, "QuickStyleFontMatrix", "1");
                cell (w, "QuickStyleType", "0");
                cell (w, "QuickStyleVariation", "0");
            }
        }

        private static Gee.ArrayList<TextRun> run_formats (Gee.List<TextRun> runs) {
            var fmts = new Gee.ArrayList<TextRun> ();
            fmts.add (new TextRun ());
            foreach (var r in runs) {
                bool known = false;
                foreach (var f in fmts) if (f.same_format (r)) known = true;
                if (!known) fmts.add (r.copy_format (""));
            }
            return fmts;
        }

        private void text_element (XmlWriter w, Item it) {
            if (it.text == "") return;
            var runs = it.rich_runs ();
            if (runs == null) {
                w.element ("Text", it.text);
                return;
            }
            var fmts = run_formats (runs);
            w.start ("Text");
            foreach (var r in runs) {
                int ix = 0;
                for (int i = 0; i < fmts.size; i++) if (fmts[i].same_format (r)) ix = i;
                w.start ("cp").attr ("IX", ix.to_string ()).end ();
                w.text (r.text);
            }
            w.end ();
        }

        private void character_row (XmlWriter w, int ix, Style st, TextRun r) {
            double trans;
            w.start ("Row").attr ("IX", ix.to_string ());
            cell (w, "Font", r.eff_family (st));
            cell (w, "Color", color_value (r.eff_color (st), out trans));
            cell_num (w, "ColorTrans", trans);
            int bits = (r.eff_bold (st) ? 1 : 0) | (r.eff_italic (st) ? 2 : 0) | (r.eff_underline (st) ? 4 : 0);
            cell (w, "Style", bits.to_string ());
            cell (w, "Strikethru", r.eff_strike (st) ? "1" : "0", "BOOL");
            cell_num (w, "Size", r.eff_size (st) / 72.0, "PT");
            w.end ();
        }

        private void text_sections (XmlWriter w, Style st, bool with_grad, Item? it = null) {
            double trans;
            if (with_grad && (st.fill_kind == FillKind.LINEAR || st.fill_kind == FillKind.RADIAL)) {
                w.start ("Section").attr ("N", "FillGradient");
                string[] cols = { st.fill, st.fill2 };
                for (int i = 0; i < 2; i++) {
                    w.start ("Row").attr ("IX", i.to_string ());
                    cell (w, "GradientStopColor", color_value (cols[i], out trans));
                    cell_num (w, "GradientStopColorTrans", trans);
                    cell (w, "GradientStopPosition", i == 0 ? "0" : "1");
                    w.end ();
                }
                w.end ();
            }
            w.start ("Section").attr ("N", "Character");
            w.start ("Row").attr ("IX", "0");
            cell (w, "Font", st.font_family);
            cell (w, "Color", color_value (st.text_color, out trans));
            cell_num (w, "ColorTrans", trans);
            int bits = (st.bold ? 1 : 0) | (st.italic ? 2 : 0) | (st.underline ? 4 : 0);
            cell (w, "Style", bits.to_string ());
            cell (w, "Strikethru", st.strike ? "1" : "0", "BOOL");
            cell_num (w, "Size", st.font_size / 72.0, "PT");
            w.end ();
            var runs = it != null ? it.rich_runs () : null;
            if (runs != null) {
                var fmts = run_formats (runs);
                for (int i = 1; i < fmts.size; i++) character_row (w, i, st, fmts[i]);
            }
            w.end ();
            w.start ("Section").attr ("N", "Paragraph");
            w.start ("Row").attr ("IX", "0");
            cell (w, "HorzAlign", st.halign == TextHAlign.LEFT ? "0" : (st.halign == TextHAlign.RIGHT ? "2" : "1"));
            w.end ();
            w.end ();
        }

        private void xform_cells (XmlWriter w, VFrame f, double cx, double cy, double wpx, double hpx, double rotation, bool fh, bool fv) {
            double wi = wpx / ppi, hi = hpx / ppi;
            cell_f (w, "PinX", f.fx (cx), core_formula ("PinX"), "IN");
            cell_f (w, "PinY", f.fy (cy), core_formula ("PinY"), "IN");
            cell_f (w, "Width", wi, core_formula ("Width"), "IN");
            cell_f (w, "Height", hi, core_formula ("Height"), "IN");
            cell_f (w, "LocPinX", wi / 2, core_formula ("LocPinX") ?? "Width*0.5", "IN");
            cell_f (w, "LocPinY", hi / 2, core_formula ("LocPinY") ?? "Height*0.5", "IN");
            cell_f (w, "Angle", -rotation * Math.PI / 180, core_formula ("Angle"), "DEG");
            cell (w, "FlipX", fh ? "1" : "0", "BOOL");
            cell (w, "FlipY", fv ? "1" : "0", "BOOL");
            cell (w, "ResizeMode", "0");
        }

        private void write_item (XmlWriter w, Item it, VFrame f) {
            var g = it as Group;
            if (g != null) {
                write_group (w, g, f);
                return;
            }
            var c = it as Connector;
            if (c != null) {
                write_connector (w, c, f);
                return;
            }
            var tb = it as TableShape;
            if (tb != null) {
                write_table (w, tb, f);
                return;
            }
            var s = it as Shape;
            if (s != null) write_shape (w, s, f);
        }

        private void begin_sheet (XmlWriter w, Item it, string type, string name, VMaster? master = null) {
            w.start ("Shape").attr ("ID", ids[it].to_string ()).attr ("NameU", name).attr ("IsCustomNameU", "1").attr ("Name", name)
                .attr ("IsCustomName", "1").attr ("Type", type);
            if (master != null) {
                w.attr ("Master", master.id.to_string ());
                page_masters.add (master);
            }
            w.attr ("LineStyle", "3").attr ("FillStyle", "3").attr ("TextStyle", "3");
            cur_sheet = it.sheet;
        }

        private string? core_formula (string name) {
            if (cur_sheet == null) return null;
            var c = cur_sheet.get_cell (name);
            return c != null && c.has_formula () ? c.formula : null;
        }

        private static bool sheet_emitted (string n) {
            switch (n) {
                case "PinX": case "PinY": case "Width": case "Height": case "LocPinX": case "LocPinY": case "Angle": case "FlipX": case "FlipY":
                case "ResizeMode": case "LayerMember": case "LineWeight": case "LineColor": case "LineColorTrans": case "LinePattern": case "Rounding":
                case "BeginArrow": case "EndArrow": case "BeginArrowSize": case "EndArrowSize": case "FillForegnd": case "FillForegndTrans":
                case "FillBkgnd": case "FillBkgndTrans": case "FillPattern": case "FillGradientEnabled": case "FillGradientDir": case "FillGradientAngle":
                case "ShdwPattern": case "ShdwForegnd": case "ShdwForegndTrans": case "ShapeShdwType": case "ShapeShdwOffsetX": case "ShapeShdwOffsetY":
                case "ShapeShdwBlur": case "VerticalAlign": case "TxtPinX": case "TxtPinY": case "TxtWidth": case "TxtHeight": case "TxtLocPinX":
                case "TxtLocPinY": case "TxtAngle": case "ImgOffsetX": case "ImgOffsetY": case "ImgWidth": case "ImgHeight": case "BeginX": case "BeginY":
                case "EndX": case "EndY": case "ObjType": case "OneD": case "ShapeRouteStyle": case "ConLineRouteExt": case "ConFixedCode": case "GlueType":
                case "QuickStyleFillColor": case "QuickStyleLineColor": case "QuickStyleFillMatrix": case "QuickStyleLineMatrix": case "QuickStyleFontColor":
                    return true;
                default:
                    return false;
            }
        }

        private void sheet_cells (XmlWriter w) {
            if (cur_sheet == null) return;
            foreach (var c in cur_sheet.cells) {
                if (!c.has_formula () || sheet_emitted (c.name)) continue;
                w.start ("Cell").attr ("N", c.name).attr ("V", c.value);
                if (c.unit != null) w.attr ("U", c.unit);
                w.attr ("F", c.formula).end ();
            }
        }

        private static void write_sheet_cell (XmlWriter w, SheetCell c) {
            w.start ("Cell").attr ("N", c.name).attr ("V", c.value);
            if (c.unit != null) w.attr ("U", c.unit);
            if (c.has_formula ()) w.attr ("F", c.formula);
            w.end ();
        }

        private static void write_sheet_section (XmlWriter w, SheetSection sec) {
            w.start ("Section").attr ("N", sec.name);
            if (sec.ix >= 0) w.attr ("IX", sec.ix.to_string ());
            foreach (var c in sec.cells) write_sheet_cell (w, c);
            foreach (var r in sec.rows) {
                if (r.deleted) continue;
                w.start ("Row");
                if (r.name != null) w.attr ("N", r.name);
                else w.attr ("IX", r.ix.to_string ());
                if (r.kind != null) w.attr ("T", r.kind);
                foreach (var c in r.cells) write_sheet_cell (w, c);
                w.end ();
            }
            w.end ();
        }

        private static void scale_cell (SheetRow r, string name, double k) {
            var c = r.get_cell (name);
            if (c == null) return;
            double d;
            if (double.try_parse (c.value.strip (), out d)) c.value = Vsdx.num (d * k);
        }

        private static ShapeSheet rescaled (ShapeSheet src, double target_ppi) {
            var sh = src.copy ();
            double k = src.ppi / target_ppi;
            sh.ppi = target_ppi;
            foreach (var sec in sh.sections) {
                foreach (var r in sec.rows) {
                    string[] names = {};
                    switch (sec.name) {
                        case "Controls": case "Connection":
                            names = { "X", "Y" };
                            break;
                        case "Geometry":
                            switch (r.kind ?? "") {
                                case "MoveTo": case "LineTo": case "SplineStart": case "SplineKnot": case "PolylineTo": case "NURBSTo":
                                    names = { "X", "Y" };
                                    break;
                                case "ArcTo":
                                    names = { "X", "Y", "A" };
                                    break;
                                case "EllipticalArcTo":
                                    names = { "X", "Y", "A", "B" };
                                    break;
                                case "Ellipse": case "InfiniteLine":
                                    names = { "X", "Y", "A", "B", "C", "D" };
                                    break;
                            }
                            break;
                    }
                    foreach (string n in names) scale_cell (r, n, k);
                }
            }
            return sh;
        }

        private void sheet_sections (XmlWriter w, Item it, bool with_geometry, bool with_connections) {
            var sh = it.sheet;
            if (sh == null) return;
            if ((sh.ppi - ppi).abs () > 1e-9 && sh.ppi > 0) sh = rescaled (sh, ppi);
            foreach (var sec in sh.sections) {
                switch (sec.name) {
                    case "Controls": case "Scratch": case "Actions":
                        write_sheet_section (w, sec);
                        break;
                    case "Hyperlink":
                        if (it.link == "") write_sheet_section (w, sec);
                        break;
                    case "Geometry":
                        if (with_geometry) write_sheet_section (w, sec);
                        break;
                    case "Connection":
                        if (with_connections) write_sheet_section (w, sec);
                        break;
                }
            }
        }

        private void hyperlink_section (XmlWriter w, Item it) {
            if (it.link == "") return;
            string addr = it.link, sub = "";
            if (addr.has_prefix ("page:")) {
                sub = addr.substring (5);
                addr = "";
            } else {
                int hash = addr.index_of ("#");
                if (hash > 0) {
                    sub = addr.substring (hash + 1);
                    addr = addr.substring (0, hash);
                }
            }
            w.start ("Section").attr ("N", "Hyperlink");
            w.start ("Row").attr ("N", "Row_1");
            cell (w, "Description", "", "STR");
            cell (w, "Address", addr, "STR");
            cell (w, "SubAddress", sub, "STR");
            cell (w, "ExtraInfo", "", "STR");
            cell (w, "Frame", "", "STR");
            cell (w, "SortKey", "", "STR");
            cell (w, "NewWindow", "0", "BOOL");
            cell (w, "Default", "1", "BOOL");
            cell (w, "Invisible", "0", "BOOL");
            w.end ();
            w.end ();
        }

        private static void alt_data (XmlWriter w, Item it) {
            if (it.alt_title != "") w.element ("Data1", it.alt_title);
            if (it.alt_text != "") w.element ("Data2", it.alt_text);
        }

        private string sheet_name (Item it, string fallback) {
            string n = it.name != "" ? it.name : fallback;
            return "%s.%d".printf (n, ids[it]);
        }

        private void write_group (XmlWriter w, Group g, VFrame f) {
            var b = g.bounds ();
            if (b.is_empty ()) b = Rect (0, 0, 0, 0);
            begin_sheet (w, g, "Group", sheet_name (g, "Group"));
            xform_cells (w, f, b.cx (), b.cy (), b.w, b.h, 0, false, false);
            int li = layer_index (g);
            if (li >= 0) cell (w, "LayerMember", li.to_string ());
            style_cells (w, g.style, false);
            write_common_user (w, g, "group");
            text_sections (w, g.style, false, g);
            text_element (w, g);
            var inner = new VFrame (b.x, b.y2 (), ppi);
            if (g.children.size > 0) {
                w.start ("Shapes");
                foreach (var c in g.children) write_item (w, c, inner);
                w.end ();
            }
            w.end ();
        }

        private void write_table (XmlWriter w, TableShape t, VFrame f) {
            begin_sheet (w, t, "Group", sheet_name (t, "Table"));
            xform_cells (w, f, t.cx (), t.cy (), t.w, t.h, t.rotation, t.flip_h, t.flip_v);
            int li = layer_index (t);
            if (li >= 0) cell (w, "LayerMember", li.to_string ());
            style_cells (w, t.style, false);
            write_common_user (w, t, "table");
            text_sections (w, t.style, false);
            w.start ("Shapes");
            int id = ids[t] + 1;
            double hi = t.h / ppi;
            for (int r = 0; r < t.rows; r++) {
                for (int c = 0; c < t.cols; c++) {
                    double cx0 = t.col_x (c), cx1 = t.col_x (c + 1);
                    double ry0 = t.row_y (r), ry1 = t.row_y (r + 1);
                    double cw = (cx1 - cx0) / ppi, ch = (ry1 - ry0) / ppi;
                    w.start ("Shape").attr ("ID", (id++).to_string ()).attr ("Type", "Shape").attr ("LineStyle", "3").attr ("FillStyle", "3").attr ("TextStyle", "3");
                    cell_num (w, "PinX", (cx0 + cx1) / 2 / ppi, "IN");
                    cell_num (w, "PinY", hi - (ry0 + ry1) / 2 / ppi, "IN");
                    cell_num (w, "Width", cw, "IN");
                    cell_num (w, "Height", ch, "IN");
                    cell_num (w, "LocPinX", cw / 2, "IN");
                    cell_num (w, "LocPinY", ch / 2, "IN");
                    var cs = t.style.copy ();
                    if (r == 0 && t.header_row) {
                        cs.fill = t.header_fill;
                        cs.bold = true;
                    }
                    cs.fill_kind = FillKind.SOLID;
                    style_cells (w, cs, false);
                    text_sections (w, cs, false);
                    w.start ("Section").attr ("N", "Geometry").attr ("IX", "0");
                    cell (w, "NoFill", "0");
                    cell (w, "NoLine", "0");
                    cell (w, "NoShow", "0");
                    geom_row (w, "MoveTo", 1, 0, 0);
                    geom_row (w, "LineTo", 2, cw, 0);
                    geom_row (w, "LineTo", 3, cw, ch);
                    geom_row (w, "LineTo", 4, 0, ch);
                    geom_row (w, "LineTo", 5, 0, 0);
                    w.end ();
                    string v = t.get_cell (r, c);
                    if (v != "") w.element ("Text", v);
                    w.end ();
                }
            }
            w.end ();
            w.end ();
        }

        private static void geom_row (XmlWriter w, string t, int ix, double x, double y) {
            w.start ("Row").attr ("T", t).attr ("IX", ix.to_string ());
            cell_num (w, "X", x);
            cell_num (w, "Y", y);
            w.end ();
        }

        private void geom_row_f (XmlWriter w, string t, int ix, double x, double y, double wpx, double hpx, bool formulas) {
            if (!formulas || wpx <= 0.01 || hpx <= 0.01) {
                geom_row (w, t, ix, x / ppi, hpx / ppi - y / ppi);
                return;
            }
            w.start ("Row").attr ("T", t).attr ("IX", ix.to_string ());
            cell_f (w, "X", x / ppi, frac_formula ("Width", x / wpx));
            cell_f (w, "Y", hpx / ppi - y / ppi, frac_formula ("Height", 1 - y / hpx));
            w.end ();
        }

        private void write_geometry (XmlWriter w, Gee.List<GeomPart> parts, double wpx, double hpx, bool formulas = false) {
            int section = 0;
            double hi = hpx / ppi;
            bool rel_ok = wpx > 0.01 && hpx > 0.01;
            foreach (var part in parts) {
                bool closed = part.path.has_closed_subpath ();
                bool no_fill = part.mode == PartMode.STROKE || !closed;
                bool no_line = part.mode == PartMode.FILL_ONLY || part.mode == PartMode.FILL_DARK;
                w.start ("Section").attr ("N", "Geometry").attr ("IX", (section++).to_string ());
                cell (w, "NoFill", no_fill ? "1" : "0");
                cell (w, "NoLine", no_line ? "1" : "0");
                cell (w, "NoShow", "0");
                cell (w, "NoSnap", "0");
                int ix = 1;
                double cx = 0, cy = 0, sx = 0, sy = 0;
                foreach (var s in part.path.segs) {
                    switch (s.kind) {
                        case SegKind.MOVE:
                            geom_row_f (w, "MoveTo", ix++, s.x, s.y, wpx, hpx, formulas);
                            cx = sx = s.x;
                            cy = sy = s.y;
                            break;
                        case SegKind.LINE:
                            geom_row_f (w, "LineTo", ix++, s.x, s.y, wpx, hpx, formulas);
                            cx = s.x;
                            cy = s.y;
                            break;
                        case SegKind.CURVE:
                            if (rel_ok) {
                                w.start ("Row").attr ("T", "RelCubBezTo").attr ("IX", (ix++).to_string ());
                                cell_num (w, "X", s.x / wpx);
                                cell_num (w, "Y", 1 - s.y / hpx);
                                cell_num (w, "A", s.x1 / wpx);
                                cell_num (w, "B", 1 - s.y1 / hpx);
                                cell_num (w, "C", s.x2 / wpx);
                                cell_num (w, "D", 1 - s.y2 / hpx);
                                w.end ();
                            } else {
                                for (int k = 1; k <= 12; k++) {
                                    var p = PathData.bezier_point (cx, cy, s.x1, s.y1, s.x2, s.y2, s.x, s.y, k / 12.0);
                                    geom_row (w, "LineTo", ix++, p.x / ppi, hi - p.y / ppi);
                                }
                            }
                            cx = s.x;
                            cy = s.y;
                            break;
                        case SegKind.CLOSE:
                            if ((cx - sx).abs () > 1e-6 || (cy - sy).abs () > 1e-6) geom_row_f (w, "LineTo", ix++, sx, sy, wpx, hpx, formulas);
                            cx = sx;
                            cy = sy;
                            break;
                    }
                }
                w.end ();
            }
        }

        private void write_shape (XmlWriter w, Shape s, VFrame f) {
            var img = s as ImageShape;
            string kind = s.kind;
            if (s is PathShape) kind = "path";
            VMaster? master = master_kind (s) && master_by_kind.has_key (s.kind) ? master_by_kind[s.kind] : null;
            begin_sheet (w, s, img != null ? "Foreign" : "Shape", sheet_name (s, ShapeLibrary.display_name (s.kind)), master);
            xform_cells (w, f, s.cx (), s.cy (), s.w, s.h, s.rotation, s.flip_h, s.flip_v);
            int li = layer_index (s);
            if (li >= 0) cell (w, "LayerMember", li.to_string ());
            style_cells (w, s.style, false);
            sheet_cells (w);
            if (img != null) {
                cell (w, "ImgOffsetX", "0", "IN");
                cell (w, "ImgOffsetY", "0", "IN");
                cell_num (w, "ImgWidth", s.w / ppi, "IN");
                cell_num (w, "ImgHeight", s.h / ppi, "IN");
            }
            var geo = s.geometry ();
            var tr = geo.text_rect;
            if (tr.w > 0 && tr.h > 0 && img == null) {
                cell_num (w, "TxtPinX", (tr.x + tr.w / 2) / ppi, "IN");
                cell_num (w, "TxtPinY", (s.h - tr.y - tr.h / 2) / ppi, "IN");
                cell_num (w, "TxtWidth", tr.w / ppi, "IN");
                cell_num (w, "TxtHeight", tr.h / ppi, "IN");
                cell_num (w, "TxtLocPinX", tr.w / 2 / ppi, "IN");
                cell_num (w, "TxtLocPinY", tr.h / 2 / ppi, "IN");
                cell (w, "TxtAngle", "0");
            }
            write_common_user (w, s, kind);
            text_sections (w, s.style, true, s);
            bool sheet_shape = s is SheetShape;
            bool sheet_ports = sheet_shape && s.sheet != null && s.sheet.section ("Connection") != null && s.custom_ports == null;
            var ports = s.ports ();
            if (ports.length > 0 && !sheet_ports && (master == null || s.custom_ports != null)) {
                w.start ("Section").attr ("N", "Connection");
                for (int i = 0; i < ports.length; i++) {
                    w.start ("Row").attr ("IX", i.to_string ());
                    cell_num (w, "X", ports[i].x * s.w / ppi, "IN");
                    cell_num (w, "Y", (1 - ports[i].y) * s.h / ppi, "IN");
                    cell (w, "DirX", "0");
                    cell (w, "DirY", "0");
                    cell (w, "Type", "0");
                    cell (w, "AutoGen", "0", "BOOL");
                    w.end ();
                }
                if (master != null) {
                    int inherited_rows = ShapeLibrary.ports (master.kind, master.w, master.h).length;
                    for (int i = ports.length; i < inherited_rows; i++) w.start ("Row").attr ("IX", i.to_string ()).attr ("Del", "1").end ();
                }
                w.end ();
            }
            hyperlink_section (w, s);
            sheet_sections (w, s, sheet_shape, sheet_ports);
            if (img == null && !sheet_shape) {
                bool inherit = master != null && same_signature (signature (geo.parts, s.w, s.h), master.signature);
                if (!inherit) write_geometry (w, geo.parts, s.w, s.h);
            }
            if (s.text != "" && img == null) text_element (w, s);
            alt_data (w, s);
            if (img != null && img.bytes.length > 0) {
                uint8[] bytes = img.bytes;
                string ext = img.mime == "image/jpeg" ? "jpeg" : "png";
                if (img.mime != "image/jpeg" && img.mime != "image/png") {
                    var pix = Renderer.pixbuf_for (img);
                    if (pix != null) {
                        try {
                            pix.save_to_buffer (out bytes, "png");
                        } catch (Error e) {
                        }
                    }
                }
                media_count++;
                string media = "image%d.%s".printf (media_count, ext);
                media_exts.add (ext);
                try {
                    zip.add ("visio/media/" + media, bytes, false);
                } catch (Error e) {
                }
                string rid = "rId%d".printf (page_rels.size + 1);
                page_rels.add (rel (rid, "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image", "../media/" + media));
                w.start ("ForeignData").attr ("ForeignType", "Bitmap").attr ("CompressionType", ext == "jpeg" ? "JPEG" : "PNG");
                w.start ("Rel").attr ("r:id", rid).end ();
                w.end ();
            }
            w.end ();
        }

        private void write_connector (XmlWriter w, Connector c, VFrame f) {
            Point[] pts = c.points;
            if (pts.length < 2) pts = { Point (c.src.x, c.src.y), Point (c.dst.x, c.dst.y) };
            if (c.route == RouteKind.CURVED) {
                Point[] flat = {};
                foreach (var poly in c.path ().flatten (0.5)) foreach (var p in poly.pts) flat += p;
                if (flat.length >= 2) pts = flat;
            }
            double bx = f.fx (pts[0].x), by = f.fy (pts[0].y);
            double ex = f.fx (pts[pts.length - 1].x), ey = f.fy (pts[pts.length - 1].y);
            double len = Math.hypot (ex - bx, ey - by);
            double ang = Math.atan2 (ey - by, ex - bx);
            begin_sheet (w, c, "Shape", sheet_name (c, "Dynamic connector"), master_by_kind["sdraw-connector"]);
            cell_num (w, "PinX", (bx + ex) / 2, "IN");
            cell_num (w, "PinY", (by + ey) / 2, "IN");
            cell_num (w, "Width", len, "IN");
            cell (w, "Height", "0", "IN");
            cell_num (w, "LocPinX", len / 2, "IN");
            cell (w, "LocPinY", "0", "IN");
            cell_num (w, "Angle", ang, "DEG");
            cell (w, "FlipX", "0", "BOOL");
            cell (w, "FlipY", "0", "BOOL");
            cell_num (w, "BeginX", bx, "IN");
            cell_num (w, "BeginY", by, "IN");
            cell_num (w, "EndX", ex, "IN");
            cell_num (w, "EndY", ey, "IN");
            cell (w, "ObjType", "2");
            cell (w, "OneD", "1", "BOOL");
            cell (w, "ShapeRouteStyle", c.route == RouteKind.STRAIGHT ? "16" : "1");
            cell (w, "ConLineRouteExt", c.route == RouteKind.CURVED ? "2" : "1");
            cell (w, "ConFixedCode", "0");
            cell (w, "GlueType", "2");
            int li = layer_index (c);
            if (li >= 0) cell (w, "LayerMember", li.to_string ());
            style_cells (w, c.style, true);
            var lp = c.label_point ();
            double ca = Math.cos (-ang), sa = Math.sin (-ang);
            double lx = f.fx (lp.x) - (bx + ex) / 2, ly = f.fy (lp.y) - (by + ey) / 2;
            cell_num (w, "TxtPinX", lx * ca - ly * sa + len / 2, "IN");
            cell_num (w, "TxtPinY", lx * sa + ly * ca, "IN");
            cell_num (w, "TxtAngle", -ang, "DEG");
            write_common_user (w, c, "connector");
            text_sections (w, c.style, false, c);
            w.start ("Section").attr ("N", "Geometry").attr ("IX", "0");
            cell (w, "NoFill", "1");
            cell (w, "NoLine", "0");
            cell (w, "NoShow", "0");
            cell (w, "NoSnap", "0");
            for (int i = 0; i < pts.length; i++) {
                double px = f.fx (pts[i].x) - (bx + ex) / 2, py = f.fy (pts[i].y) - (by + ey) / 2;
                geom_row (w, i == 0 ? "MoveTo" : "LineTo", i + 1, px * ca - py * sa + len / 2, px * sa + py * ca);
            }
            w.end ();
            text_element (w, c);
            alt_data (w, c);
            w.end ();
        }
    }

    private class VCell {
        public string? v;
        public string? f;
        public string? u;
        public bool inherited = false;
        public bool master_formula = false;

        public VCell inherit () {
            var c = new VCell ();
            c.v = v;
            c.f = f;
            c.u = u;
            c.inherited = true;
            c.master_formula = true;
            return c;
        }

        public VCell over (VCell? master) {
            if (f != "Inh" || master == null || master.f == null || master.f == "Inh") return this;
            var c = new VCell ();
            c.v = v;
            c.f = master.f;
            c.u = u ?? master.u;
            c.master_formula = true;
            return c;
        }
    }

    private class VRow {
        public string key = "";
        public string? t = null;
        public string? n = null;
        public int ix = -1;
        public bool del = false;
        public Gee.HashMap<string, VCell> cells = new Gee.HashMap<string, VCell> ();

        public VRow copy () {
            var r = new VRow ();
            r.key = key;
            r.t = t;
            r.n = n;
            r.ix = ix;
            r.del = del;
            foreach (var e in cells.entries) r.cells[e.key] = e.value;
            return r;
        }
    }

    private class VSection {
        public string name = "";
        public string key = "";
        public int ix = -1;
        public bool del = false;
        public Gee.HashMap<string, VCell> cells = new Gee.HashMap<string, VCell> ();
        public Gee.ArrayList<VRow> rows = new Gee.ArrayList<VRow> ();

        public VSection copy () {
            var s = new VSection ();
            s.name = name;
            s.key = key;
            s.ix = ix;
            s.del = del;
            foreach (var e in cells.entries) s.cells[e.key] = e.value;
            foreach (var r in rows) s.rows.add (r.copy ());
            return s;
        }

        public VSection copy_inherited () {
            var s = copy ();
            foreach (var k in s.cells.keys.to_array ()) s.cells[k] = s.cells[k].inherit ();
            foreach (var r in s.rows) foreach (var k in r.cells.keys.to_array ()) r.cells[k] = r.cells[k].inherit ();
            return s;
        }

        public VRow? row (string k) {
            foreach (var r in rows) if (r.key == k) return r;
            return null;
        }
    }

    private class VSheet {
        public int id = -1;
        public string type = "Shape";
        public string name = "";
        public string name_u = "";
        public int master = -1;
        public int master_shape = -1;
        public string? line_style = null;
        public string? fill_style = null;
        public string? text_style = null;
        public Gee.HashMap<string, VCell> cells = new Gee.HashMap<string, VCell> ();
        public Gee.ArrayList<VSection> sections = new Gee.ArrayList<VSection> ();
        public string? text = null;
        public Gee.ArrayList<int> cp_ix = new Gee.ArrayList<int> ();
        public Gee.ArrayList<string> cp_text = new Gee.ArrayList<string> ();
        public string? foreign_rel = null;
        public Gee.ArrayList<VSheet> children = new Gee.ArrayList<VSheet> ();
        public string master_name = "";
        public string? type_attr = null;
        public string? data1 = null;
        public string? data2 = null;

        public VSection? section (string key) {
            foreach (var s in sections) if (s.key == key) return s;
            return null;
        }

        public Gee.ArrayList<VSection> sections_named (string name) {
            var list = new Gee.ArrayList<VSection> ();
            foreach (var s in sections) if (s.name == name) list.add (s);
            list.sort ((a, b) => a.ix - b.ix);
            return list;
        }
    }

    private class VsdxReader {
        private ZipReader zip;
        private Gee.HashMap<string, VSheet> styles = new Gee.HashMap<string, VSheet> ();
        private Gee.HashMap<int, VSheet> masters = new Gee.HashMap<int, VSheet> ();
        private Gee.HashMap<int, string> master_names = new Gee.HashMap<int, string> ();
        private Gee.HashMap<int, Item> id_map = new Gee.HashMap<int, Item> ();
        private Gee.HashMap<int, VSheet> sheet_map = new Gee.HashMap<int, VSheet> ();
        private Gee.HashMap<string, string> page_rel_targets = new Gee.HashMap<string, string> ();
        private string page_dir = "visio/pages";
        private double page_h = 11;
        private Document doc;
        private Page page;
        private Gee.ArrayList<string> layer_ids = new Gee.ArrayList<string> ();
        private bool own_file = false;
        private double ppi = Units.PX_PER_IN;
        private Theme? theme = null;
        private Gee.HashMap<string, Page> visio_pages = new Gee.HashMap<string, Page> ();
        private Gee.HashMap<Page, string> back_refs = new Gee.HashMap<Page, string> ();
        private string own_theme = "";
        private int own_variant = 0;
        public bool stencil_mode = false;
        public Gee.ArrayList<StencilMaster> stencil_masters = new Gee.ArrayList<StencilMaster> ();
        public string package_title = "";

        public VsdxReader (uint8[] data) throws Error {
            zip = new ZipReader (data);
        }

        private static string resolve (string base_dir, string target) {
            if (target.has_prefix ("/")) return target.substring (1);
            var parts = new Gee.ArrayList<string> ();
            if (base_dir != "") foreach (string p in base_dir.split ("/")) if (p != "") parts.add (p);
            foreach (string p in target.split ("/")) {
                if (p == "" || p == ".") continue;
                if (p == "..") {
                    if (parts.size > 0) parts.remove_at (parts.size - 1);
                } else {
                    parts.add (p);
                }
            }
            return string.joinv ("/", parts.to_array ());
        }

        private static string dir_of (string path) {
            int i = path.last_index_of ("/");
            return i < 0 ? "" : path.substring (0, i);
        }

        private static string rels_path (string part) {
            string d = dir_of (part);
            string f = part.substring (d.length > 0 ? d.length + 1 : 0);
            return (d != "" ? d + "/" : "") + "_rels/" + f + ".rels";
        }

        private Gee.HashMap<string, string> read_rels (string part, out Gee.HashMap<string, string> by_type) throws Error {
            var map = new Gee.HashMap<string, string> ();
            by_type = new Gee.HashMap<string, string> ();
            string? text = zip.read_text (rels_path (part));
            if (text == null) return map;
            Xml.Doc* x = XmlUtil.parse (text);
            foreach (var r in XmlUtil.children (x->get_root_element (), "Relationship")) {
                string id = XmlUtil.attr_or (r, "Id", "");
                string target = resolve (dir_of (part), XmlUtil.attr_or (r, "Target", ""));
                map[id] = target;
                string type = XmlUtil.attr_or (r, "Type", "");
                if (!by_type.has_key (type)) by_type[type] = target;
            }
            delete x;
            return map;
        }

        private static VCell read_cell (Xml.Node* n) {
            var c = new VCell ();
            c.v = XmlUtil.attr (n, "V");
            c.f = XmlUtil.attr (n, "F");
            c.u = XmlUtil.attr (n, "U");
            return c;
        }

        private static VSection read_section (Xml.Node* n) {
            var s = new VSection ();
            s.name = XmlUtil.attr_or (n, "N", "");
            string? ix = XmlUtil.attr (n, "IX");
            s.ix = ix != null ? int.parse (ix) : -1;
            s.key = ix != null ? s.name + "#" + ix : s.name;
            s.del = XmlUtil.attr_or (n, "Del", "0") == "1";
            int auto_ix = 0;
            foreach (var c in XmlUtil.children (n)) {
                if (c->name == "Cell") {
                    s.cells[XmlUtil.attr_or (c, "N", "")] = read_cell (c);
                } else if (c->name == "Row") {
                    var r = new VRow ();
                    r.t = XmlUtil.attr (c, "T");
                    r.n = XmlUtil.attr (c, "N");
                    string? rix = XmlUtil.attr (c, "IX");
                    r.ix = rix != null ? int.parse (rix) : auto_ix;
                    auto_ix = r.ix + 1;
                    r.key = r.n != null ? "N:" + r.n : "IX:" + r.ix.to_string ();
                    r.del = XmlUtil.attr_or (c, "Del", "0") == "1";
                    foreach (var cc in XmlUtil.children (c, "Cell")) r.cells[XmlUtil.attr_or (cc, "N", "")] = read_cell (cc);
                    s.rows.add (r);
                }
            }
            return s;
        }

        private static VSheet read_sheet (Xml.Node* n) {
            var s = new VSheet ();
            s.id = int.parse (XmlUtil.attr_or (n, "ID", "-1"));
            s.type = XmlUtil.attr_or (n, "Type", "Shape");
            s.name = XmlUtil.attr_or (n, "Name", "");
            s.name_u = XmlUtil.attr_or (n, "NameU", s.name);
            string? m = XmlUtil.attr (n, "Master");
            s.master = m != null ? int.parse (m) : -1;
            string? ms = XmlUtil.attr (n, "MasterShape");
            s.master_shape = ms != null ? int.parse (ms) : -1;
            s.line_style = XmlUtil.attr (n, "LineStyle");
            s.fill_style = XmlUtil.attr (n, "FillStyle");
            s.text_style = XmlUtil.attr (n, "TextStyle");
            s.type_attr = XmlUtil.attr (n, "Type");
            foreach (var c in XmlUtil.children (n)) {
                switch (c->name) {
                    case "Data1":
                        s.data1 = XmlUtil.text (c);
                        break;
                    case "Data2":
                        s.data2 = XmlUtil.text (c);
                        break;
                    case "Cell":
                        s.cells[XmlUtil.attr_or (c, "N", "")] = read_cell (c);
                        break;
                    case "Section":
                        s.sections.add (read_section (c));
                        break;
                    case "Text":
                        s.text = XmlUtil.text (c);
                        read_cps (c, s, 0);
                        break;
                    case "ForeignData":
                        var rel = XmlUtil.child (c, "Rel");
                        if (rel != null) s.foreign_rel = XmlUtil.attr (rel, "id", Vsdx.NS_R) ?? XmlUtil.attr (rel, "id");
                        break;
                    case "Shapes":
                        foreach (var sc in XmlUtil.children (c, "Shape")) s.children.add (read_sheet (sc));
                        break;
                }
            }
            return s;
        }

        private static VSheet merge (VSheet local, VSheet? master) {
            if (master == null) return local;
            var r = new VSheet ();
            r.id = local.id;
            r.type = local.type != "" ? local.type : master.type;
            r.name = local.name;
            r.name_u = local.name_u;
            r.master = local.master;
            r.master_shape = local.master_shape;
            r.master_name = local.master_name;
            r.line_style = local.line_style ?? master.line_style;
            r.fill_style = local.fill_style ?? master.fill_style;
            r.text_style = local.text_style ?? master.text_style;
            r.type_attr = local.type_attr;
            r.data1 = local.data1 ?? master.data1;
            r.data2 = local.data2 ?? master.data2;
            foreach (var e in master.cells.entries) r.cells[e.key] = e.value.inherit ();
            foreach (var e in local.cells.entries) r.cells[e.key] = e.value.over (master.cells[e.key]);
            foreach (var s in master.sections) r.sections.add (s.copy_inherited ());
            foreach (var ls in local.sections) {
                var existing = r.section (ls.key);
                if (ls.del) {
                    if (existing != null) r.sections.remove (existing);
                    continue;
                }
                if (existing == null) {
                    r.sections.add (ls.copy ());
                    continue;
                }
                foreach (var e in ls.cells.entries) existing.cells[e.key] = e.value.over (existing.cells[e.key]);
                foreach (var lr in ls.rows) {
                    var er = existing.row (lr.key);
                    if (lr.del) {
                        if (er != null) existing.rows.remove (er);
                        continue;
                    }
                    if (er == null) {
                        existing.rows.add (lr.copy ());
                        continue;
                    }
                    if (lr.t != null) er.t = lr.t;
                    foreach (var e in lr.cells.entries) er.cells[e.key] = e.value.over (er.cells[e.key]);
                }
                existing.rows.sort ((a, b) => a.ix - b.ix);
            }
            r.text = local.text ?? master.text;
            if (local.text != null) {
                r.cp_ix = local.cp_ix;
                r.cp_text = local.cp_text;
            } else {
                r.cp_ix = master.cp_ix;
                r.cp_text = master.cp_text;
            }
            r.foreign_rel = local.foreign_rel ?? master.foreign_rel;
            if (local.children.size > 0) {
                foreach (var lc in local.children) {
                    VSheet? mc = null;
                    foreach (var c in master.children) if (c.id == lc.master_shape) mc = c;
                    r.children.add (merge (lc, mc));
                }
            } else {
                foreach (var mc in master.children) r.children.add (mc);
            }
            return r;
        }

        private VSheet resolve_master (VSheet local, VSheet? parent_master) {
            VSheet? m = null;
            if (local.master >= 0 && masters.has_key (local.master)) {
                var mroot = masters[local.master];
                if (local.master_shape >= 0) {
                    foreach (var c in mroot.children) if (c.id == local.master_shape) m = c;
                } else {
                    m = mroot.children.size == 1 ? mroot.children[0] : null;
                    if (m == null && mroot.children.size > 1) {
                        m = new VSheet ();
                        m.type = "Group";
                        foreach (var c in mroot.children) m.children.add (c);
                    }
                }
                local.master_name = master_names[local.master] ?? "";
            } else if (parent_master != null && local.master_shape >= 0) {
                foreach (var c in parent_master.children) if (c.id == local.master_shape) m = c;
            }
            var merged = merge (local, m);
            if (local.master_name != "") merged.master_name = local.master_name;
            return merged;
        }

        private VCell? style_cell (string? style_id, string name, string kind, int depth) {
            if (style_id == null || depth > 12) return null;
            var st = styles[style_id];
            if (st == null) return null;
            if (st.cells.has_key (name)) return st.cells[name];
            string? parent = kind == "line" ? st.line_style : (kind == "fill" ? st.fill_style : st.text_style);
            if (parent == style_id) return null;
            return style_cell (parent, name, kind, depth + 1);
        }

        private static string kind_for_cell (string name) {
            if (name.has_prefix ("Line") || name.has_prefix ("BeginArrow") || name.has_prefix ("EndArrow") || name == "Rounding") return "line";
            if (name.has_prefix ("Fill") || name.has_prefix ("Shdw") || name.has_prefix ("ShapeShdw")) return "fill";
            return "text";
        }

        private VCell? get_cell (VSheet s, string name) {
            if (s.cells.has_key (name)) return s.cells[name];
            string kind = kind_for_cell (name);
            string? sid = kind == "line" ? s.line_style : (kind == "fill" ? s.fill_style : s.text_style);
            return style_cell (sid, name, kind, 0);
        }

        private VCell? section_cell (VSheet s, string section, string name) {
            var sec = s.section (section);
            if (sec != null) {
                foreach (var r in sec.rows) {
                    if (r.ix == 0 && r.cells.has_key (name)) return r.cells[name];
                }
            }
            string? sid = s.text_style;
            for (int depth = 0; sid != null && depth < 12; depth++) {
                var st = styles[sid];
                if (st == null) break;
                var ss = st.section (section);
                if (ss != null) foreach (var r in ss.rows) if (r.ix == 0 && r.cells.has_key (name)) return r.cells[name];
                if (st.text_style == sid) break;
                sid = st.text_style;
            }
            return null;
        }

        private static bool is_number (string? v) {
            if (v == null) return false;
            string t = v.strip ();
            if (t == "") return false;
            double d;
            return double.try_parse (t, out d);
        }

        private static double nv (VCell? c, double fallback) {
            if (c == null || !is_number (c.v)) return fallback;
            return double.parse (c.v.strip ());
        }

        private double num (VSheet s, string name, double fallback) {
            return nv (get_cell (s, name), fallback);
        }

        private static string? sv (VCell? c) {
            return c != null ? c.v : null;
        }

        private static string? color (VCell? c) {
            if (c == null || c.v == null) return null;
            string v = c.v.strip ();
            if (v.has_prefix ("#")) return v.down ();
            if (v.down ().has_prefix ("rgb")) {
                Rgba rgba;
                if (Colors.parse (v, out rgba)) return Colors.to_hex (rgba);
            }
            if (is_number (v)) {
                string[] palette = { "#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff",
                    "#800000", "#008000", "#000080", "#808000", "#800080", "#008080", "#c0c0c0", "#e6e6e6", "#cdcdcd",
                    "#b3b3b3", "#9a9a9a", "#808080", "#666666", "#4d4d4d", "#333333", "#1a1a1a" };
                int i = int.parse (v);
                if (i >= 0 && i < palette.length) return palette[i];
            }
            return null;
        }

        private static string with_alpha (string c, double trans) {
            if (trans <= 0.001) return c;
            Rgba rgba;
            if (!Colors.parse (c, out rgba)) return c;
            rgba.a = (1 - trans).clamp (0, 1);
            return Colors.to_hex (rgba, true);
        }

        private string user (VSheet s, string name) {
            var sec = s.section ("User");
            if (sec == null) return "";
            var r = sec.row ("N:" + name);
            if (r == null || !r.cells.has_key ("Value")) return "";
            return r.cells["Value"].v ?? "";
        }

        private bool has_user (VSheet s, string name) {
            var sec = s.section ("User");
            return sec != null && sec.row ("N:" + name) != null;
        }

        public Document read () throws Error {
            Gee.HashMap<string, string> root_types;
            read_rels ("", out root_types);
            string doc_part = root_types["http://schemas.microsoft.com/visio/2010/relationships/document"] ?? "visio/document.xml";
            string? doc_text = zip.read_text (doc_part);
            if (doc_text == null) throw new FormatError.INVALID (_("This is not a Visio drawing."));
            doc = new Document ();
            doc.pages.clear ();
            Xml.Doc* dx = XmlUtil.parse (doc_text);
            var droot = dx->get_root_element ();
            var sheets = XmlUtil.child (droot, "StyleSheets");
            foreach (var sn in XmlUtil.children (sheets, "StyleSheet")) {
                var st = read_sheet (sn);
                styles[XmlUtil.attr_or (sn, "ID", "")] = st;
            }
            var docsheet = XmlUtil.child (droot, "DocumentSheet");
            int page_index = 0;
            if (docsheet != null) {
                var ds = read_sheet (docsheet);
                if (has_user (ds, "SDrawGrid")) {
                    own_file = true;
                    doc.grid_size = double.parse (user (ds, "SDrawGrid"));
                    doc.units = user (ds, "SDrawUnits");
                    doc.title = user (ds, "SDrawTitle");
                    page_index = int.parse (user (ds, "SDrawPageIndex"));
                    own_theme = user (ds, "SDrawTheme");
                    own_variant = int.parse (user (ds, "SDrawThemeVariant"));
                }
            }
            delete dx;
            Gee.HashMap<string, string> doc_types;
            read_rels (doc_part, out doc_types);
            string? theme_part = doc_types["http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme"];
            if (theme_part != null) read_theme (theme_part);
            try {
                string? core_text = zip.read_text ("docProps/core.xml");
                if (core_text != null) {
                    Xml.Doc* cx = XmlUtil.parse (core_text);
                    var tn = XmlUtil.child (cx->get_root_element (), "title");
                    if (tn != null) package_title = XmlUtil.text (tn);
                    delete cx;
                }
            } catch (Error e) {
            }
            if (own_theme != "" && own_theme != "file") {
                doc.theme_id = own_theme;
                doc.theme_variant = own_variant;
            } else if (theme != null) {
                doc.custom_theme = theme;
                doc.theme_id = "file";
                doc.theme_variant = own_theme == "file" ? own_variant : 0;
            }
            string? masters_part = doc_types["http://schemas.microsoft.com/visio/2010/relationships/masters"];
            if (masters_part != null) read_masters (masters_part);
            if (stencil_mode) {
                build_stencil_masters ();
                return doc;
            }
            string pages_part = doc_types["http://schemas.microsoft.com/visio/2010/relationships/pages"] ?? "visio/pages/pages.xml";
            string? pages_text = zip.read_text (pages_part);
            if (pages_text == null) throw new FormatError.INVALID (_("The drawing has no pages."));
            Gee.HashMap<string, string> pages_types;
            var page_rels = read_rels (pages_part, out pages_types);
            Xml.Doc* px = XmlUtil.parse (pages_text);
            foreach (var pn in XmlUtil.children (px->get_root_element (), "Page")) {
                var rel = XmlUtil.child (pn, "Rel");
                if (rel == null) continue;
                string rid = XmlUtil.attr (rel, "id", Vsdx.NS_R) ?? XmlUtil.attr_or (rel, "id", "");
                string? part = page_rels[rid];
                if (part == null) continue;
                var ps = XmlUtil.child (pn, "PageSheet");
                VSheet? psheet = ps != null ? read_sheet (ps) : null;
                read_page (pn, psheet, part);
            }
            delete px;
            foreach (var e in back_refs.entries) {
                if (visio_pages.has_key (e.value)) e.key.back_page = visio_pages[e.value].id;
            }
            string? comments_part = doc_types["http://schemas.microsoft.com/visio/2010/relationships/comments"];
            if (comments_part != null) read_comments (comments_part);
            if (doc.pages.size == 0) {
                var p = new Page (_("Page 1"));
                p.id = "page1";
                doc.pages.add (p);
            }
            bool any_fg = false;
            foreach (var p in doc.pages) if (!p.is_background) any_fg = true;
            if (!any_fg) foreach (var p in doc.pages) p.is_background = false;
            doc.page_index = page_index.clamp (0, doc.pages.size - 1);
            return doc;
        }

        private void read_masters (string part) throws Error {
            string? text = zip.read_text (part);
            if (text == null) return;
            Gee.HashMap<string, string> types;
            var rels = read_rels (part, out types);
            Xml.Doc* x = XmlUtil.parse (text);
            foreach (var mn in XmlUtil.children (x->get_root_element (), "Master")) {
                int id = int.parse (XmlUtil.attr_or (mn, "ID", "-1"));
                master_names[id] = XmlUtil.attr (mn, "NameU") ?? XmlUtil.attr_or (mn, "Name", "");
                master_order.add (id);
                master_display[id] = XmlUtil.attr (mn, "Name") ?? master_names[id];
                master_prompt[id] = XmlUtil.attr_or (mn, "Prompt", "");
                if (XmlUtil.attr_or (mn, "Hidden", "0") == "1") master_hidden.add (id);
                var mps = XmlUtil.child (mn, "PageSheet");
                if (mps != null) {
                    var ms = read_sheet (mps);
                    master_height[id] = nv (ms.cells["PageHeight"], 11);
                }
                var rel = XmlUtil.child (mn, "Rel");
                if (rel == null) continue;
                string rid = XmlUtil.attr (rel, "id", Vsdx.NS_R) ?? XmlUtil.attr_or (rel, "id", "");
                string? mpart = rels[rid];
                if (mpart == null) continue;
                string? mtext = zip.read_text (mpart);
                if (mtext == null) continue;
                Xml.Doc* mx = XmlUtil.parse (mtext);
                var root = new VSheet ();
                root.type = "Master";
                var shapes = XmlUtil.child (mx->get_root_element (), "Shapes");
                foreach (var sn in XmlUtil.children (shapes, "Shape")) root.children.add (read_sheet (sn));
                masters[id] = root;
                delete mx;
            }
            delete x;
        }

        private Gee.ArrayList<int> master_order = new Gee.ArrayList<int> ();
        private Gee.HashMap<int, string> master_display = new Gee.HashMap<int, string> ();
        private Gee.HashMap<int, string> master_prompt = new Gee.HashMap<int, string> ();
        private Gee.HashMap<int, double?> master_height = new Gee.HashMap<int, double?> ();
        private Gee.HashSet<int> master_hidden = new Gee.HashSet<int> ();

        private void build_stencil_masters () {
            foreach (int id in master_order) {
                if (!masters.has_key (id) || master_hidden.contains (id)) continue;
                page = new Page ("");
                page_h = master_height.has_key (id) ? master_height[id] : 11;
                ppi = Units.PX_PER_IN;
                page.height = page_h * ppi;
                id_map.clear ();
                sheet_map.clear ();
                var items = new Gee.ArrayList<Item> ();
                var top = Cairo.Matrix.identity ();
                foreach (var child in masters[id].children) {
                    var it = build_item (resolve_master (child, null), top);
                    if (it != null) items.add (it);
                }
                if (items.size == 0) continue;
                var m = StencilMaster.from_items (master_display[id], items);
                m.id = "m%d".printf (id);
                m.keywords = master_prompt[id] ?? "";
                stencil_masters.add (m);
            }
        }

        private void read_page (Xml.Node* pn, VSheet? psheet, string part) throws Error {
            page = new Page (XmlUtil.attr (pn, "Name") ?? XmlUtil.attr_or (pn, "NameU", _("Page")));
            page.id = "page%d".printf (doc.pages.size + 1);
            page.is_background = XmlUtil.attr_or (pn, "Background", "0") == "1";
            string? back = XmlUtil.attr (pn, "BackPage");
            if (back != null) back_refs[page] = back;
            visio_pages[XmlUtil.attr_or (pn, "ID", doc.pages.size.to_string ())] = page;
            double pw = 8.5, ph = 11;
            layer_ids.clear ();
            ppi = Units.PX_PER_IN;
            if (psheet != null) {
                read_page_scale (psheet);
                read_page_jumps (psheet);
                pw = nv (psheet.cells["PageWidth"], pw);
                ph = nv (psheet.cells["PageHeight"], ph);
                if (has_user (psheet, "SDrawPageId")) {
                    page.id = user (psheet, "SDrawPageId");
                    page.background = user (psheet, "SDrawBackground");
                }
                string[] saved_ids = has_user (psheet, "SDrawLayerIds") ? user (psheet, "SDrawLayerIds").split (";") : new string[0];
                var lsec = psheet.section ("Layer");
                if (lsec != null && lsec.rows.size > 0) {
                    page.layers.clear ();
                    int i = 0;
                    foreach (var r in lsec.rows) {
                        string lid = i < saved_ids.length && saved_ids[i] != "" ? saved_ids[i] : "layer%d".printf (i + 1);
                        var l = new Layer (lid, sv (r.cells["Name"]) ?? sv (r.cells["NameUniv"]) ?? _("Layer %d").printf (i + 1));
                        l.visible = nv (r.cells["Visible"], 1) != 0;
                        l.printable = nv (r.cells["Print"], 1) != 0;
                        l.locked = nv (r.cells["Lock"], 0) != 0;
                        if (nv (r.cells["Active"], 0) != 0) page.active_layer = lid;
                        page.layers.add (l);
                        layer_ids.add (lid);
                        i++;
                    }
                    if (page.find_layer (page.active_layer) == null) page.active_layer = page.layers[0].id;
                }
                if (has_user (psheet, "SDrawActiveLayer") && page.find_layer (user (psheet, "SDrawActiveLayer")) != null) {
                    page.active_layer = user (psheet, "SDrawActiveLayer");
                }
            }
            page.width = pw * ppi;
            page.height = ph * ppi;
            page_h = ph;
            if (own_file && psheet != null && has_user (psheet, "SDrawComments")) {
                try {
                    Xml.Doc* cd = XmlUtil.parse (user (psheet, "SDrawComments"));
                    foreach (var cn in XmlUtil.children (cd->get_root_element (), "comment")) page.comments.add (NativeFormat.read_comment (cn));
                    delete cd;
                } catch (Error e) {
                }
            }
            string? text = zip.read_text (part);
            if (text == null) {
                doc.pages.add (page);
                return;
            }
            page_dir = dir_of (part);
            Gee.HashMap<string, string> types;
            page_rel_targets = read_rels (part, out types);
            id_map.clear ();
            sheet_map.clear ();
            Xml.Doc* x = XmlUtil.parse (text);
            var root = x->get_root_element ();
            var shapes = XmlUtil.child (root, "Shapes");
            var top = Cairo.Matrix.identity ();
            foreach (var sn in XmlUtil.children (shapes, "Shape")) {
                var sheet = resolve_master (read_sheet (sn), null);
                if (sheet.type == "Guide" || sheet.type_attr == "Guide") {
                    read_guide (sheet);
                    continue;
                }
                var it = build_item (sheet, top);
                if (it != null) page.items.add (it);
            }
            var connects = XmlUtil.child (root, "Connects");
            foreach (var cn in XmlUtil.children (connects, "Connect")) apply_connect (cn);
            delete x;
            doc.pages.add (page);
        }

        private static double unit_inches (string? u) {
            if (u == null) return 1;
            bool ok;
            double f = SheetFormulaParser.unit_factor (u, out ok);
            return ok ? f : 1;
        }

        private static string unit_id (string? u) {
            if (u == null) return "in";
            switch (u.up ()) {
                case "MM": return "mm";
                case "CM": return "cm";
                case "M": return "m";
                case "KM": return "km";
                case "FT": case "F_I": return "ft";
                case "YD": return "yd";
                case "MI": return "mi";
                default: return "in";
            }
        }

        private void read_page_scale (VSheet psheet) {
            var pc = psheet.cells["PageScale"];
            var dc = psheet.cells["DrawingScale"];
            double ps = nv (pc, 1), ds = nv (dc, 1);
            if (ps <= 0 || ds <= 0 || (ps - ds).abs () < 1e-9) return;
            ppi = Units.PX_PER_IN * ps / ds;
            string pu = unit_id (pc != null ? pc.u : null), du = unit_id (dc != null ? dc.u : null);
            page.scale_paper_units = pu;
            page.scale_units = du;
            page.scale_paper = ps * 25.4 / Units.mm_per (pu);
            page.scale_world = ds * 25.4 / Units.mm_per (du);
        }

        private void read_page_jumps (VSheet psheet) {
            double code = nv (psheet.cells["LineJumpCode"], 1);
            double style = nv (psheet.cells["PageLineJumpStyle"], 1);
            if (code == 0) page.jump_style = JumpStyle.NONE;
            else page.jump_style = style == 2 ? JumpStyle.GAP : (style == 3 ? JumpStyle.SQUARE : JumpStyle.ARC);
            page.jumps_vertical = code == 2;
            double f = nv (psheet.cells["LineJumpFactorX"], 0.66666667);
            if (f > 0) page.jump_size = (f / 0.66666667).clamp (0.25, 4);
        }

        private void read_guide (VSheet s) {
            double px = num (s, "PinX", 0), py = num (s, "PinY", 0), ang = num (s, "Angle", 0);
            bool vertical = false;
            foreach (var sec in s.sections_named ("Geometry")) {
                foreach (var r in sec.rows) {
                    if (r.t != "InfiniteLine") continue;
                    double dx = cv (r, "A") - cv (r, "X"), dy = cv (r, "B") - cv (r, "Y");
                    double rx = dx * Math.cos (ang) - dy * Math.sin (ang), ry = dx * Math.sin (ang) + dy * Math.cos (ang);
                    vertical = ry.abs () > rx.abs ();
                }
            }
            if (vertical) page.guides.add (new PageGuide (true, px * ppi));
            else page.guides.add (new PageGuide (false, (page_h - py) * ppi));
        }

        private string color_value (Xml.Node* n) {
            if (n == null) return "";
            foreach (var c in XmlUtil.children (n)) {
                if (c->name == "srgbClr") return "#" + XmlUtil.attr_or (c, "val", "000000").down ();
                if (c->name == "sysClr") return "#" + XmlUtil.attr_or (c, "lastClr", "000000").down ();
            }
            return "";
        }

        private void read_theme (string part) {
            string? text = null;
            try {
                text = zip.read_text (part);
            } catch (Error e) {
            }
            if (text == null) return;
            Xml.Doc* x = null;
            try {
                x = XmlUtil.parse (text);
            } catch (Error e) {
                return;
            }
            var root = x->get_root_element ();
            var t = new Theme ("file", XmlUtil.attr_or (root, "name", _("Drawing Theme")));
            var elems = XmlUtil.child (root, "themeElements");
            var clr = elems != null ? XmlUtil.child (elems, "clrScheme") : null;
            if (clr != null) {
                string dk1 = color_value (XmlUtil.child (clr, "dk1")), lt1 = color_value (XmlUtil.child (clr, "lt1"));
                string dk2 = color_value (XmlUtil.child (clr, "dk2"));
                if (dk1 != "") t.dark = dk1;
                if (lt1 != "") t.light = lt1;
                if (dk2 != "") t.line = dk2;
                string[] acc = {};
                for (int i = 1; i <= 6; i++) {
                    string a = color_value (XmlUtil.child (clr, "accent%d".printf (i)));
                    acc += a != "" ? a : t.accents[i - 1];
                }
                t.accents = acc;
                var ext = XmlUtil.child (clr, "extLst");
                if (ext != null) {
                    foreach (var e in XmlUtil.children (ext)) {
                        var bk = XmlUtil.child (e, "bkgnd");
                        if (bk != null) {
                            string b = color_value (bk);
                            if (b != "") t.background = b;
                        }
                    }
                }
            }
            var fonts = elems != null ? XmlUtil.child (elems, "fontScheme") : null;
            if (fonts != null) {
                var minor = XmlUtil.child (fonts, "minorFont");
                var major = XmlUtil.child (fonts, "majorFont");
                var ml = minor != null ? XmlUtil.child (minor, "latin") : null;
                var jl = major != null ? XmlUtil.child (major, "latin") : null;
                if (ml != null && XmlUtil.attr_or (ml, "typeface", "") != "") t.font = XmlUtil.attr_or (ml, "typeface", "Sans");
                if (jl != null && XmlUtil.attr_or (jl, "typeface", "") != "") t.heading_font = XmlUtil.attr_or (jl, "typeface", "Sans");
            }
            theme = t;
            delete x;
        }

        private void read_comments (string part) {
            string? text = null;
            try {
                text = zip.read_text (part);
            } catch (Error e) {
            }
            if (text == null) return;
            Xml.Doc* x = null;
            try {
                x = XmlUtil.parse (text);
            } catch (Error e) {
                return;
            }
            var root = x->get_root_element ();
            var authors = new Gee.HashMap<string, Xml.Node*> ();
            var al = XmlUtil.child (root, "AuthorList");
            foreach (var an in XmlUtil.children (al, "AuthorEntry")) authors[XmlUtil.attr_or (an, "ID", "")] = an;
            var cl = XmlUtil.child (root, "CommentList");
            foreach (var cn in XmlUtil.children (cl, "CommentEntry")) {
                string pid = XmlUtil.attr_or (cn, "PageID", "0");
                if (!visio_pages.has_key (pid)) continue;
                var p = visio_pages[pid];
                if (p.comments.size > 0 && own_file) continue;
                var c = new Comment ();
                c.id = "c%s".printf (XmlUtil.attr_or (cn, "CommentID", p.comments.size.to_string ()));
                string aid = XmlUtil.attr_or (cn, "AuthorID", "");
                if (authors.has_key (aid)) {
                    c.author = XmlUtil.attr_or (authors[aid], "Name", "");
                    c.initials = XmlUtil.attr_or (authors[aid], "Initials", Comment.initials_of (c.author));
                }
                var dt = new DateTime.from_iso8601 (XmlUtil.attr_or (cn, "Date", ""), new TimeZone.utc ());
                if (dt != null) c.time = dt.to_unix ();
                c.resolved = XmlUtil.attr_or (cn, "Done", "0") == "1";
                c.text = XmlUtil.text (cn);
                string? sid = XmlUtil.attr (cn, "ShapeID");
                if (sid != null) {
                    int shape_id = int.parse (sid);
                    foreach (var it in p.all_items ()) {
                        if (it.sheet != null && it.sheet.sheet_id == shape_id) {
                            c.item_id = it.id;
                            var b = it.bounds ();
                            c.x = b.x2 ();
                            c.y = b.y;
                            break;
                        }
                    }
                }
                p.comments.add (c);
            }
            delete x;
        }

        private void apply_connect (Xml.Node* cn) {
            int from = int.parse (XmlUtil.attr_or (cn, "FromSheet", "-1"));
            int to = int.parse (XmlUtil.attr_or (cn, "ToSheet", "-1"));
            if (!id_map.has_key (from) || !id_map.has_key (to)) return;
            var c = id_map[from] as Connector;
            var target = id_map[to];
            if (c == null || target is Connector) return;
            string from_cell = XmlUtil.attr_or (cn, "FromCell", "");
            var sheet = sheet_map[from];
            if (own_file && sheet != null && has_user (sheet, "SDrawSrc")) return;
            Endpoint e;
            if (from_cell == "BeginX") e = c.src;
            else if (from_cell == "EndX") e = c.dst;
            else return;
            e.item_id = target.id;
            e.port = -1;
            string to_cell = XmlUtil.attr_or (cn, "ToCell", "");
            int port = -1;
            if (to_cell.has_prefix ("Connections.X")) {
                port = int.parse (to_cell.substring ("Connections.X".length)) - 1;
            } else if (to_cell.has_prefix ("Connections.Row_")) {
                string rest = to_cell.substring ("Connections.Row_".length);
                int dot = rest.index_of (".");
                if (dot > 0) port = int.parse (rest.substring (0, dot)) - 1;
            } else {
                int part = int.parse (XmlUtil.attr_or (cn, "ToPart", "0"));
                if (part >= 100) port = part - 100;
            }
            var s = target as Shape;
            if (s != null && port >= 0 && port < s.ports ().length) e.port = port;
        }

        private Cairo.Matrix local_matrix (VSheet s) {
            double w = num (s, "Width", 0), h = num (s, "Height", 0);
            var m = Cairo.Matrix.identity ();
            m.translate (num (s, "PinX", 0), num (s, "PinY", 0));
            double a = num (s, "Angle", 0);
            if (a != 0) m.rotate (a);
            m.scale (num (s, "FlipX", 0) != 0 ? -1 : 1, num (s, "FlipY", 0) != 0 ? -1 : 1);
            m.translate (-num (s, "LocPinX", w / 2), -num (s, "LocPinY", h / 2));
            return m;
        }

        private static Cairo.Matrix mul (Cairo.Matrix a, Cairo.Matrix b) {
            var r = Cairo.Matrix.identity ();
            r.multiply (a, b);
            return r;
        }

        private Cairo.Matrix to_px () {
            return Cairo.Matrix (ppi, 0, 0, -ppi, 0, page_h * ppi);
        }

        private int nesting = 0;
        private ShapeSheet? last_sheet = null;

        private Item? build_item (VSheet s, Cairo.Matrix parent) {
            if (own_file && has_user (s, "SDrawKind")) return build_own (s, parent);
            bool one_d = s.cells.has_key ("BeginX") && s.cells.has_key ("EndX");
            if (!one_d) {
                var c = get_cell (s, "ObjType");
                one_d = c != null && nv (c, 0) == 2 && s.cells.has_key ("BeginX");
            }
            string mn = s.master_name.down ();
            if (mn.contains ("connector")) one_d = s.cells.has_key ("BeginX") || one_d;
            Item? it;
            var local = mul (local_matrix (s), parent);
            bool pushed = false;
            if (s.master >= 0 && masters.has_key (s.master)) {
                var map = new Gee.HashMap<int, int> ();
                var mroot = masters[s.master];
                if (s.master_shape < 0 && mroot.children.size == 1) map[mroot.children[0].id] = s.id;
                else if (s.master_shape >= 0) map[s.master_shape] = s.id;
                collect_master_ids (s, map);
                sheet_maps.add (map);
                pushed = true;
            }
            last_sheet = to_sheet (s);
            var full = last_sheet;
            if (one_d) it = build_connector (s, parent, local);
            else if (s.type == "Group") it = build_group (s, local);
            else it = build_shape (s, local);
            if (pushed) sheet_maps.remove_at (sheet_maps.size - 1);
            if (it == null) return null;
            it.id = "v%d_%d".printf (doc.pages.size + 1, s.id);
            if (s.name != "") it.name = s.name;
            if (it.sheet == null) {
                var kept = full.copy ();
                strip_geometry (kept);
                it.sheet = kept;
            }
            register (s, it);
            read_fields (s, it);
            read_layer (s, it);
            read_quick_style (s, it.style);
            read_link (s, it);
            if (s.data1 != null) it.alt_title = s.data1;
            if (s.data2 != null) it.alt_text = s.data2;
            var shape = it as Shape;
            if (shape != null && !(shape is ImageShape)) read_ports (full, shape);
            return it;
        }

        private Gee.ArrayList<Gee.HashMap<int, int>> sheet_maps = new Gee.ArrayList<Gee.HashMap<int, int>> ();

        private static void collect_master_ids (VSheet s, Gee.HashMap<int, int> map) {
            foreach (var c in s.children) {
                if (c.master_shape >= 0 && !map.has_key (c.master_shape)) map[c.master_shape] = c.id;
                collect_master_ids (c, map);
            }
        }

        private string remap_sheet_refs (string f) {
            if (sheet_maps.size == 0 || !f.contains ("Sheet.")) return f;
            var map = sheet_maps[sheet_maps.size - 1];
            var sb = new StringBuilder ();
            int i = 0;
            while (i < f.length) {
                int j = f.index_of ("Sheet.", i);
                if (j < 0) {
                    sb.append (f.substring (i));
                    break;
                }
                sb.append (f.substring (i, j - i));
                int k = j + 6;
                while (k < f.length && f[k].isdigit ()) k++;
                if (k > j + 6 && k < f.length && f[k] == '!') {
                    int id = int.parse (f.substring (j + 6, k - j - 6));
                    sb.append ("Sheet.%d".printf (map.has_key (id) ? map[id] : id));
                } else {
                    sb.append (f.substring (j, k - j));
                }
                i = k;
            }
            return sb.str;
        }

        private static void strip_geometry (ShapeSheet sh) {
            var drop = new Gee.ArrayList<SheetSection> ();
            foreach (var sec in sh.sections) if (sec.name == "Geometry") drop.add (sec);
            sh.sections.remove_all (drop);
        }

        private SheetCell sheet_cell (string name, VCell c) {
            string? f = c.f;
            if (f == "Inh" || f == "No Formula" || f == "") f = null;
            if (f != null && c.master_formula) f = remap_sheet_refs (f);
            var sc = new SheetCell (name, c.v ?? "", f, c.u);
            sc.inherited = c.inherited;
            return sc;
        }

        private ShapeSheet to_sheet (VSheet s) {
            var sh = new ShapeSheet ();
            sh.sheet_id = s.id;
            sh.nested = nesting > 0;
            sh.ppi = ppi;
            string[] core = { "PinX", "PinY", "Width", "Height", "LocPinX", "LocPinY", "Angle", "FlipX", "FlipY", "TxtPinX", "TxtPinY", "TxtWidth", "TxtHeight", "TxtLocPinX", "TxtLocPinY" };
            foreach (var e in s.cells.entries) {
                bool keep = e.key in core;
                if (!keep && e.value.f != null && e.value.f != "Inh" && e.value.f != "No Formula") keep = true;
                if (keep) sh.cells.add (sheet_cell (e.key, e.value));
            }
            foreach (var sec in s.sections) {
                if (sec.del) continue;
                switch (sec.name) {
                    case "User": case "Property": case "Controls": case "Scratch": case "Actions": case "Connection": case "Hyperlink": case "Geometry": case "Character":
                        break;
                    default:
                        continue;
                }
                var ss = new SheetSection (sec.name, sec.ix);
                foreach (var e in sec.cells.entries) ss.cells.add (sheet_cell (e.key, e.value));
                foreach (var r in sec.rows) {
                    if (r.del) continue;
                    if (sec.name == "Character" && r.ix != 0) continue;
                    var sr = new SheetRow ();
                    sr.name = r.n;
                    sr.kind = r.t;
                    sr.ix = r.ix;
                    foreach (var e in r.cells.entries) sr.cells.add (sheet_cell (e.key, e.value));
                    ss.rows.add (sr);
                }
                sh.sections.add (ss);
            }
            return sh;
        }

        private SheetContext import_context (ShapeSheet sh) {
            var ctx = new SheetContext (sh, null, page);
            ctx.evaluate_all = false;
            return ctx;
        }

        private void read_ports (ShapeSheet sh, Shape shape) {
            var sec = sh.section ("Connection");
            if (sec == null || sec.rows.size == 0) return;
            var ctx = import_context (sh);
            double wi = shape.w / ppi, hi = shape.h / ppi;
            if (wi <= 1e-9 || hi <= 1e-9) return;
            Point[] pts = {};
            var rows = new Gee.ArrayList<SheetRow> ();
            rows.add_all (sec.rows);
            rows.sort ((a, b) => a.ix - b.ix);
            foreach (var r in rows) {
                double x = SheetEval.cell_number (ctx, sec, r, "X", 0), y = SheetEval.cell_number (ctx, sec, r, "Y", 0);
                pts += Point (x / wi, 1 - y / hi);
            }
            if (pts.length == 0) return;
            if (shape is PathShape || shape is SheetShape || shape.kind == "text") {
                shape.custom_ports = pts;
                return;
            }
            var lib = ShapeLibrary.ports (shape.kind, shape.w, shape.h);
            bool same = lib.length == pts.length;
            for (int i = 0; same && i < pts.length; i++) {
                if ((lib[i].x - pts[i].x).abs () > 0.01 || (lib[i].y - pts[i].y).abs () > 0.01) same = false;
            }
            if (!same) shape.custom_ports = pts;
        }

        private void read_link (VSheet s, Item it) {
            var sec = s.section ("Hyperlink");
            if (sec == null) return;
            foreach (var r in sec.rows) {
                if (r.del) continue;
                string addr = sv (r.cells["Address"]) ?? "";
                string sub = sv (r.cells["SubAddress"]) ?? "";
                if (addr != "") {
                    it.link = addr + (sub != "" ? "#" + sub : "");
                    return;
                }
                if (sub != "") {
                    it.link = "page:" + sub;
                    return;
                }
            }
        }

        private void read_quick_style (VSheet s, Style st) {
            var fc = get_cell (s, "QuickStyleFillColor");
            if (fc == null || !is_number (fc.v)) return;
            int v = (int) nv (fc, -1);
            int q = -1;
            if (v >= 2 && v <= 7) q = v - 1;
            else if (v >= 100 && v <= 106) q = 1 + (v - 100) % 6;
            else if (v >= 200 && v <= 206) q = 1 + (v - 200) % 6;
            if (q < 0) return;
            st.quick_color = q;
            int m = (int) num (s, "QuickStyleFillMatrix", 3);
            st.quick_style = m >= 1 && m <= 6 ? m - 1 : QuickStyle.BALANCED;
        }

        private void register (VSheet s, Item it) {
            if (s.id >= 0) {
                id_map[s.id] = it;
                sheet_map[s.id] = s;
            }
        }

        private void read_layer (VSheet s, Item it) {
            var c = get_cell (s, "LayerMember");
            string? v = sv (c);
            if (v == null || v.strip () == "") {
                it.layer_id = page.layers.size > 0 ? page.layers[0].id : "";
                return;
            }
            int i = int.parse (v.split (";")[0]);
            it.layer_id = i >= 0 && i < page.layers.size ? page.layers[i].id : page.layers[0].id;
        }

        private void read_fields (VSheet s, Item it) {
            var sec = s.section ("Property");
            if (sec == null) return;
            foreach (var r in sec.rows) {
                if (r.del) continue;
                string key = sv (r.cells["Label"]) ?? "";
                if (key == "") key = r.n ?? "";
                string val = sv (r.cells["Value"]) ?? "";
                if (key != "") it.fields.add (new DataField (key, val));
            }
        }

        private void read_style (VSheet s, Style st, bool one_d) {
            double lp = num (s, "LinePattern", 1);
            if (lp == 0) {
                st.stroke = "none";
            } else {
                string lc = color (get_cell (s, "LineColor")) ?? "#000000";
                st.stroke = with_alpha (lc, num (s, "LineColorTrans", 0));
                st.stroke_width = num (s, "LineWeight", 0.01041666) * Units.PX_PER_IN;
                st.dash = Vsdx.dash_from_visio ((int) lp);
            }
            st.corner_radius = num (s, "Rounding", 0) * ppi;
            st.arrow_start = Vsdx.arrow_from_visio ((int) num (s, "BeginArrow", 0));
            st.arrow_end = Vsdx.arrow_from_visio ((int) num (s, "EndArrow", 0));
            double asz = num (s, "EndArrowSize", 2);
            st.arrow_size = double.max (asz / 2.0, 0.5);
            double fp = num (s, "FillPattern", 1);
            if (one_d || fp == 0) {
                st.fill_kind = FillKind.NONE;
            } else {
                string fc = color (get_cell (s, "FillForegnd")) ?? "#ffffff";
                st.fill = with_alpha (fc, num (s, "FillForegndTrans", 0));
                st.fill_kind = FillKind.SOLID;
                string bc = color (get_cell (s, "FillBkgnd")) ?? "#ffffff";
                st.fill2 = with_alpha (bc, num (s, "FillBkgndTrans", 0));
                if (num (s, "FillGradientEnabled", 0) != 0) {
                    var gs = s.section ("FillGradient");
                    if (gs != null && gs.rows.size >= 2) {
                        var r0 = gs.rows[0];
                        var r1 = gs.rows[gs.rows.size - 1];
                        st.fill = with_alpha (color (r0.cells["GradientStopColor"]) ?? st.fill, nv (r0.cells["GradientStopColorTrans"], 0));
                        st.fill2 = with_alpha (color (r1.cells["GradientStopColor"]) ?? st.fill2, nv (r1.cells["GradientStopColorTrans"], 0));
                    }
                    double dir = num (s, "FillGradientDir", 0);
                    st.fill_kind = dir >= 13 ? FillKind.RADIAL : FillKind.LINEAR;
                    st.gradient_angle = -num (s, "FillGradientAngle", -Math.PI / 2) * 180 / Math.PI;
                } else if (fp > 1 && fp < 25) {
                    st.fill_kind = FillKind.SOLID;
                } else if (fp >= 25 && fp <= 40) {
                    st.fill_kind = FillKind.LINEAR;
                    st.gradient_angle = 90;
                }
            }
            if (num (s, "ShdwPattern", 0) != 0) {
                st.shadow = true;
                st.shadow_color = with_alpha (color (get_cell (s, "ShdwForegnd")) ?? "#000000", num (s, "ShdwForegndTrans", 0.6));
                st.shadow_dx = num (s, "ShapeShdwOffsetX", 0.0417) * Units.PX_PER_IN;
                st.shadow_dy = -num (s, "ShapeShdwOffsetY", -0.0417) * Units.PX_PER_IN;
            }
            double va = num (s, "VerticalAlign", 1);
            st.valign = va == 0 ? TextVAlign.TOP : (va == 2 ? TextVAlign.BOTTOM : TextVAlign.MIDDLE);
            string? font = sv (section_cell (s, "Character", "Font"));
            if (font != null && font != "" && !is_number (font) && font != "Themed") st.font_family = font;
            else if (font == "Themed" && theme != null) st.font_family = theme.font;
            double size = nv (section_cell (s, "Character", "Size"), 0.1666667);
            st.font_size = size * 72;
            int bits = (int) nv (section_cell (s, "Character", "Style"), 0);
            st.bold = (bits & 1) != 0;
            st.italic = (bits & 2) != 0;
            st.underline = (bits & 4) != 0;
            st.strike = nv (section_cell (s, "Character", "Strikethru"), 0) != 0;
            string? tc = color (section_cell (s, "Character", "Color"));
            if (tc != null) st.text_color = with_alpha (tc, nv (section_cell (s, "Character", "ColorTrans"), 0));
            double ha = nv (section_cell (s, "Paragraph", "HorzAlign"), 1);
            st.halign = ha == 0 ? TextHAlign.LEFT : (ha == 2 ? TextHAlign.RIGHT : TextHAlign.CENTER);
        }

        private static int read_cps (Xml.Node* n, VSheet s, int ix) {
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type == Xml.ElementType.TEXT_NODE || c->type == Xml.ElementType.CDATA_SECTION_NODE) {
                    string t = c->get_content () ?? "";
                    if (t == "") continue;
                    if (s.cp_ix.size > 0 && s.cp_ix[s.cp_ix.size - 1] == ix) s.cp_text[s.cp_text.size - 1] += t;
                    else {
                        s.cp_ix.add (ix);
                        s.cp_text.add (t);
                    }
                } else if (c->type == Xml.ElementType.ELEMENT_NODE) {
                    if (c->name == "cp") ix = int.parse (XmlUtil.attr_or (c, "IX", "0"));
                    else ix = read_cps (c, s, ix);
                }
            }
            return ix;
        }

        private string rich_markup (VSheet s, Style st, string text) {
            if (s.cp_ix.size < 2 && (s.cp_ix.size == 0 || s.cp_ix[0] == 0)) return "";
            var sec = s.section ("Character");
            if (sec == null) return "";
            var runs = new Gee.ArrayList<TextRun> ();
            for (int i = 0; i < s.cp_ix.size; i++) {
                string t = s.cp_text[i].replace ("\r\n", "\n").replace ("\r", "\n").replace ("\u2028", "\n").replace ("\u2029", "\n");
                var r = new TextRun (t);
                VRow? row = null;
                foreach (var rr in sec.rows) if (rr.ix == s.cp_ix[i] && !rr.del) row = rr;
                if (row != null && s.cp_ix[i] != 0) {
                    string? font = sv (row.cells["Font"]);
                    if (font != null && font != "" && !is_number (font) && font != "Themed" && font != st.font_family) r.family = font;
                    if (row.cells.has_key ("Size")) {
                        double size = nv (row.cells["Size"], 0) * 72;
                        if (size > 0 && Math.fabs (size - st.font_size) > 0.05) r.size = Math.round (size * 100) / 100;
                    }
                    if (row.cells.has_key ("Style")) {
                        int bits = (int) nv (row.cells["Style"], 0);
                        r.bold = (bits & 1) != 0 && !st.bold;
                        r.italic = (bits & 2) != 0 && !st.italic;
                        r.underline = (bits & 4) != 0 && !st.underline;
                    }
                    if (row.cells.has_key ("Strikethru")) r.strike = nv (row.cells["Strikethru"], 0) != 0 && !st.strike;
                    string? tc = color (row.cells["Color"]);
                    if (tc != null && Colors.rgb_hex (tc).down () != Colors.rgb_hex (st.text_color).down ()) r.color = Colors.rgb_hex (tc);
                }
                runs.add (r);
            }
            var all = RichRuns.plain_text (runs);
            if (all != text && all.has_prefix (text)) runs = RichRuns.slice (runs, 0, text.length);
            return RichRuns.markup_from (runs, text);
        }

        private static string clean_text (string? t) {
            if (t == null) return "";
            string r = t.replace ("\r\n", "\n").replace ("\r", "\n").replace (" ", "\n").replace (" ", "\n");
            while (r.has_suffix ("\n")) r = r.substring (0, r.length - 1);
            return r;
        }

        private static string? kind_for_master (string name) {
            string n = name.down ().strip ();
            int dot = n.last_index_of (".");
            if (dot > 0 && is_number (n.substring (dot + 1))) n = n.substring (0, dot);
            switch (n) {
                case "rectangle": case "square": return "rectangle";
                case "rounded rectangle": return "rounded-rectangle";
                case "ellipse": return "ellipse";
                case "circle": return "circle";
                case "process": return "process";
                case "decision": return "decision";
                case "start/end": case "terminator": case "start/end ": return "terminator";
                case "data": return "data";
                case "document": return "document";
                case "multiple documents": return "multi-document";
                case "database": return "database";
                case "stored data": return "stored-data";
                case "predefined process": case "subprocess": return "predefined-process";
                case "manual input": return "manual-input";
                case "manual operation": return "manual-operation";
                case "preparation": return "preparation";
                case "display": return "display";
                case "delay": return "delay";
                case "internal storage": return "internal-storage";
                case "card": return "card";
                case "paper tape": return "punched-tape";
                case "off-page reference": return "off-page";
                case "on-page reference": return "on-page";
                case "loop limit": return "loop-limit";
                case "triangle": return "triangle";
                case "pentagon": return "pentagon";
                case "hexagon": return "hexagon";
                case "octagon": return "octagon";
                case "diamond": return "diamond";
                case "parallelogram": return "parallelogram";
                case "trapezoid": return "trapezoid";
                case "cross": return "cross";
                case "5-point star": case "star": return "star";
                case "cloud": return "cloud";
                case "cube": return "cube";
                case "cylinder": return "cylinder";
                case "heart": return "heart";
                case "text": return "text";
                default: return null;
            }
        }

        private Shape build_shape (VSheet s, Cairo.Matrix local) {
            double wi = num (s, "Width", 0), hi = num (s, "Height", 0);
            double wpx = wi * ppi, hpx = hi * ppi;
            var lm = Cairo.Matrix (1.0 / ppi, 0, 0, -1.0 / ppi, 0, hi);
            var a = mul (mul (lm, local), to_px ());
            Shape shape;
            string? mapped = kind_for_master (s.master_name);
            if (mapped == null) {
                string mk = user (s, "SDrawMasterKind");
                if (mk != "" && mk != "connector" && ShapeLibrary.find (mk) != null) mapped = mk;
            }
            var parts = new Gee.ArrayList<GeomPart> ();
            var sheet = last_sheet;
            if (s.type != "Foreign") parts = SheetEval.geometry_parts (import_context (sheet), wi, hi, ppi);
            if (s.type == "Foreign") {
                var img = new ImageShape ();
                string? rid = s.foreign_rel;
                if (rid != null && page_rel_targets.has_key (rid)) {
                    try {
                        var bytes = zip.read (page_rel_targets[rid]);
                        if (bytes != null) {
                            img.bytes = bytes;
                            img.mime = ImageShape.sniff_mime (bytes);
                        }
                    } catch (Error e) {
                    }
                }
                shape = img;
            } else if (mapped != null) {
                shape = new Shape (mapped);
            } else if (parts.size == 0) {
                shape = new Shape ("text");
            } else if (parts.size == 1 && is_box (parts[0].path, wpx, hpx) && parts[0].mode == PartMode.FILL_STROKE) {
                shape = new Shape ("rectangle");
            } else if (parts.size == 1 && s.sections_named ("Geometry").size == 1 && only_ellipse (s)) {
                shape = new Shape ("ellipse");
            } else if (SheetEval.needs_sheet_shape (sheet)) {
                var ss = new SheetShape ();
                ss.sheet = sheet;
                shape = ss;
            } else {
                shape = new PathShape ();
            }
            shape.w = wpx;
            shape.h = hpx;
            decompose (a, shape);
            var st = shape.style;
            read_style (s, st, false);
            if (shape.kind == "text" && !(shape is ImageShape)) {
                st.fill_kind = FillKind.NONE;
                st.stroke = "none";
            }
            if (shape is ImageShape) {
                st.fill_kind = FillKind.NONE;
                if (num (s, "LinePattern", 0) == 0) st.stroke = "none";
            }
            var ps = shape as PathShape;
            if (ps != null || shape is SheetShape) {
                var path = new PathData ();
                bool any_fill = false, any_line = false;
                foreach (var part in parts) {
                    path.append (part.path);
                    if (part.mode != PartMode.STROKE) any_fill = true;
                    if (part.mode != PartMode.FILL_ONLY) any_line = true;
                }
                if (ps != null) {
                    ps.path = path;
                    ps.natural_w = wpx;
                    ps.natural_h = hpx;
                }
                if (!any_fill) st.fill_kind = FillKind.NONE;
                if (!any_line) st.stroke = "none";
            }
            shape.text = clean_text (s.text);
            shape.markup = rich_markup (s, shape.style, shape.text);
            return shape;
        }

        private bool only_ellipse (VSheet s) {
            foreach (var sec in s.sections_named ("Geometry")) {
                int n = 0;
                foreach (var r in sec.rows) {
                    if (r.del) continue;
                    if (r.t != "Ellipse") return false;
                    n++;
                }
                if (n != 1) return false;
            }
            return true;
        }

        private static bool is_box (PathData p, double w, double h) {
            var polys = p.flatten (0.5);
            if (polys.size != 1 || !polys[0].closed || polys[0].pts.length != 4) return false;
            foreach (var pt in polys[0].pts) {
                bool okx = pt.x.abs () < 0.5 || (pt.x - w).abs () < 0.5;
                bool oky = pt.y.abs () < 0.5 || (pt.y - h).abs () < 0.5;
                if (!okx || !oky) return false;
            }
            return true;
        }

        private static void decompose (Cairo.Matrix a, Shape shape) {
            double det = a.xx * a.yy - a.xy * a.yx;
            bool flip = det < 0;
            double fx = flip ? -1 : 1;
            double r = Math.atan2 (fx * a.yx, fx * a.xx) * 180 / Math.PI;
            if (r.abs () < 1e-7) r = 0;
            shape.flip_h = flip;
            shape.flip_v = false;
            shape.rotation = Document.normalize_angle (r);
            if ((shape.rotation - 360).abs () < 1e-6) shape.rotation = 0;
            double cx = shape.w / 2, cy = shape.h / 2;
            a.transform_point (ref cx, ref cy);
            shape.x = cx - shape.w / 2;
            shape.y = cy - shape.h / 2;
        }

        private static double cv (VRow r, string n, double fallback = 0) {
            return nv (r.cells[n], fallback);
        }

        private Group build_group (VSheet s, Cairo.Matrix local) {
            var g = new Group ();
            read_style (s, g.style, false);
            g.text = clean_text (s.text);
            g.markup = rich_markup (s, g.style, g.text);
            var own = own_geometry (s, local);
            if (own != null) {
                if (g.text != "") {
                    own.text = g.text;
                    g.text = "";
                }
                g.children.add (own);
            }
            nesting++;
            foreach (var child in s.children) {
                var cs = resolve_master (child, null);
                var it = build_item (cs, local);
                if (it != null) g.children.add (it);
            }
            nesting--;
            if (g.text != "" && g.children.size > 0) {
                double wi = num (s, "Width", 0), hi = num (s, "Height", 0);
                var label = new Shape ("text");
                label.w = wi * ppi;
                label.h = hi * ppi;
                var lm = Cairo.Matrix (1.0 / ppi, 0, 0, -1.0 / ppi, 0, hi);
                decompose (mul (mul (lm, local), to_px ()), label);
                read_style (s, label.style, false);
                label.style.fill_kind = FillKind.NONE;
                label.style.stroke = "none";
                label.text = g.text;
                label.id = "v%d_%dt".printf (doc.pages.size + 1, s.id);
                label.layer_id = page.layers.size > 0 ? page.layers[0].id : "";
                g.text = "";
                g.children.add (label);
            }
            return g;
        }

        private PathShape? own_geometry (VSheet s, Cairo.Matrix local) {
            double wi = num (s, "Width", 0), hi = num (s, "Height", 0);
            if (last_sheet == null) return null;
            var parts = SheetEval.geometry_parts (import_context (last_sheet), wi, hi, ppi);
            if (parts.size == 0) return null;
            var ps = new PathShape ();
            var path = new PathData ();
            bool any_fill = false, any_line = false;
            foreach (var part in parts) {
                path.append (part.path);
                if (part.mode != PartMode.STROKE) any_fill = true;
                if (part.mode != PartMode.FILL_ONLY) any_line = true;
            }
            ps.path = path;
            ps.w = wi * ppi;
            ps.h = hi * ppi;
            ps.natural_w = ps.w;
            ps.natural_h = ps.h;
            var lm = Cairo.Matrix (1.0 / ppi, 0, 0, -1.0 / ppi, 0, hi);
            decompose (mul (mul (lm, local), to_px ()), ps);
            read_style (s, ps.style, false);
            if (!any_fill) ps.style.fill_kind = FillKind.NONE;
            if (!any_line) ps.style.stroke = "none";
            ps.id = "v%d_%dg".printf (doc.pages.size + 1, s.id);
            ps.layer_id = page.layers.size > 0 ? page.layers[0].id : "";
            return ps;
        }

        private Point page_point (Cairo.Matrix parent, double x, double y) {
            var m = mul (parent, to_px ());
            m.transform_point (ref x, ref y);
            return Point (x, y);
        }

        private Connector build_connector (VSheet s, Cairo.Matrix parent, Cairo.Matrix local) {
            var c = new Connector ();
            read_style (s, c.style, true);
            c.style.fill_kind = FillKind.NONE;
            var b = page_point (parent, num (s, "BeginX", 0), num (s, "BeginY", 0));
            var e = page_point (parent, num (s, "EndX", 0), num (s, "EndY", 0));
            c.src.x = b.x;
            c.src.y = b.y;
            c.dst.x = e.x;
            c.dst.y = e.y;
            Point[] pts = {};
            var m = mul (local, to_px ());
            double wi = num (s, "Width", 0), hi = num (s, "Height", 0);
            var csheet = last_sheet;
            var cctx = import_context (csheet);
            foreach (var sec in csheet.sections_named ("Geometry")) {
                var ns = sec.get_cell ("NoShow");
                if (ns != null && ns.number (0) != 0) continue;
                var path = SheetEval.section_path (cctx, sec, wi, hi);
                path.transform (m);
                foreach (var poly in path.flatten (0.5)) foreach (var p in poly.pts) pts += p;
                break;
            }
            double ext = num (s, "ConLineRouteExt", 0);
            double style = num (s, "ShapeRouteStyle", 0);
            bool ortho = pts.length >= 2;
            for (int i = 1; i < pts.length; i++) {
                if ((pts[i].x - pts[i - 1].x).abs () > 0.5 && (pts[i].y - pts[i - 1].y).abs () > 0.5) ortho = false;
            }
            if (ext == 2) c.route = RouteKind.CURVED;
            else if (style == 16) c.route = RouteKind.STRAIGHT;
            else if (s.master_name.down ().contains ("dynamic connector") || (ortho && pts.length > 2)) c.route = RouteKind.ORTHOGONAL;
            else c.route = RouteKind.STRAIGHT;
            if (pts.length >= 2) {
                c.points = pts;
                c.src.x = pts[0].x;
                c.src.y = pts[0].y;
                c.dst.x = pts[pts.length - 1].x;
                c.dst.y = pts[pts.length - 1].y;
            } else {
                c.points = { b, e };
            }
            if (c.route == RouteKind.STRAIGHT && pts.length > 2) {
                Point[] wp = {};
                for (int i = 1; i < pts.length - 1; i++) wp += pts[i];
                c.waypoints = wp;
            }
            c.text = clean_text (s.text);
            c.markup = rich_markup (s, c.style, c.text);
            return c;
        }

        private Item? build_own (VSheet s, Cairo.Matrix parent) {
            string kind = user (s, "SDrawKind");
            Item it;
            var local = mul (local_matrix (s), parent);
            switch (kind) {
                case "group":
                    var g = new Group ();
                    foreach (var child in s.children) {
                        var cit = build_item (resolve_master (child, null), local);
                        if (cit != null) g.children.add (cit);
                    }
                    it = g;
                    break;
                case "table":
                    Item? tb = null;
                    try {
                        var list = NativeFormat.parse_items (user (s, "SDrawItem"));
                        if (list.size > 0) tb = list[0];
                    } catch (Error e) {
                    }
                    if (tb == null) tb = new TableShape ();
                    it = tb;
                    break;
                case "connector":
                    var c = new Connector ();
                    c.route = RouteKind.from_id (user (s, "SDrawRoute"));
                    read_endpoint (user (s, "SDrawSrc"), c.src);
                    read_endpoint (user (s, "SDrawDst"), c.dst);
                    c.waypoints = NativeFormat.points_from_string (user (s, "SDrawWaypoints"));
                    c.label_pos = has_user (s, "SDrawLabelPos") ? double.parse (user (s, "SDrawLabelPos")) : 0.5;
                    c.jumps = user (s, "SDrawJumps") == "1";
                    it = c;
                    break;
                default:
                    Shape sh;
                    if (kind == "path") {
                        var ps = new PathShape ();
                        ps.path = PathData.parse_svg (user (s, "SDrawPath"));
                        string[] nat = user (s, "SDrawNatural").split (" ");
                        if (nat.length == 2) {
                            ps.natural_w = double.parse (nat[0]);
                            ps.natural_h = double.parse (nat[1]);
                        }
                        sh = ps;
                    } else if (s.type == "Foreign" || kind == "image") {
                        var img = new ImageShape ();
                        string? rid = s.foreign_rel;
                        if (rid != null && page_rel_targets.has_key (rid)) {
                            try {
                                var bytes = zip.read (page_rel_targets[rid]);
                                if (bytes != null) img.bytes = bytes;
                            } catch (Error e) {
                            }
                        }
                        img.mime = has_user (s, "SDrawMime") ? user (s, "SDrawMime") : ImageShape.sniff_mime (img.bytes);
                        if (img.bytes.length > 0 && ImageShape.sniff_mime (img.bytes) != img.mime) img.mime = ImageShape.sniff_mime (img.bytes);
                        sh = img;
                    } else if (kind == "sheet") {
                        sh = new SheetShape ();
                    } else {
                        sh = new Shape (kind);
                    }
                    sh.kind = kind == "path" ? "path" : (kind == "image" ? "image" : kind);
                    string[] box = user (s, "SDrawBox").split (" ");
                    if (box.length == 7) {
                        sh.x = double.parse (box[0]);
                        sh.y = double.parse (box[1]);
                        sh.w = double.parse (box[2]);
                        sh.h = double.parse (box[3]);
                        sh.rotation = double.parse (box[4]);
                        sh.flip_h = box[5] == "1";
                        sh.flip_v = box[6] == "1";
                    } else {
                        sh.w = num (s, "Width", 1) * ppi;
                        sh.h = num (s, "Height", 1) * ppi;
                        var lm = Cairo.Matrix (1.0 / ppi, 0, 0, -1.0 / ppi, 0, num (s, "Height", 0));
                        decompose (mul (mul (lm, local), to_px ()), sh);
                    }
                    if (has_user (s, "SDrawPorts")) sh.custom_ports = NativeFormat.points_from_string (user (s, "SDrawPorts"));
                    it = sh;
                    break;
            }
            if (user (s, "SDrawHasSheet") == "1") {
                var sheet = to_sheet (s);
                var us = sheet.section ("User");
                if (us != null) {
                    var drop = new Gee.ArrayList<SheetRow> ();
                    foreach (var r in us.rows) if (r.name != null && r.name.has_prefix ("SDraw")) drop.add (r);
                    us.rows.remove_all (drop);
                    if (us.rows.size == 0 && us.cells.size == 0) sheet.sections.remove (us);
                }
                var ps = sheet.section ("Property");
                if (ps != null) sheet.sections.remove (ps);
                if (!(it is SheetShape)) strip_geometry (sheet);
                it.sheet = sheet;
            }
            it.alt_title = user (s, "SDrawAltTitle");
            it.alt_text = user (s, "SDrawAltText");
            if (!(it is TableShape)) {
                it.style = Style.deserialize (user (s, "SDrawStyle"));
                it.text = s.text ?? "";
                it.markup = rich_markup (s, it.style, it.text);
                read_fields (s, it);
            }
            it.id = user (s, "SDrawId");
            it.name = user (s, "SDrawName");
            it.layer_id = user (s, "SDrawLayer");
            it.locked = user (s, "SDrawLocked") == "1";
            it.container_id = user (s, "SDrawContainer");
            it.link = user (s, "SDrawLink");
            register (s, it);
            return it;
        }

        private static void read_endpoint (string v, Endpoint e) {
            string[] parts = v.split ("|");
            if (parts.length != 4) return;
            e.item_id = parts[0];
            e.port = int.parse (parts[1]);
            e.x = double.parse (parts[2]);
            e.y = double.parse (parts[3]);
        }
    }
}
