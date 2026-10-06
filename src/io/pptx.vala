namespace Singularity.Apps.Draw {

    public class PptxSlide {
        public Page page;
        public Rect area;
        public string name;

        public PptxSlide (Page page, Rect area, string name) {
            this.page = page;
            this.area = area;
            this.name = name;
        }
    }

    public class Pptx {
        public const string NS_P = "http://schemas.openxmlformats.org/presentationml/2006/main";
        public const string NS_A = "http://schemas.openxmlformats.org/drawingml/2006/main";
        public const string NS_R = "http://schemas.openxmlformats.org/officeDocument/2006/relationships";
        public const string NS_PKG = "http://schemas.openxmlformats.org/package/2006/relationships";
        public const string REL_SLIDE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide";
        public const string REL_IMAGE = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/image";
        public const string REL_LAYOUT = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout";
        public const string REL_MASTER = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster";
        public const string REL_THEME = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme";
        public const int64 SLIDE_W = 12192000;
        public const int64 SLIDE_H = 6858000;

        private Gee.ArrayList<Bytes> media = new Gee.ArrayList<Bytes> ();
        private Gee.ArrayList<string> media_ext = new Gee.ArrayList<string> ();
        private Gee.ArrayList<string> slide_rels = new Gee.ArrayList<string> ();
        private XmlWriter w;
        private int next_shape = 2;
        private double k = 9525;
        private double ox = 0;
        private double oy = 0;
        private Rect area;
        private Page page;
        public int native_shapes = 0;
        public int picture_shapes = 0;

        public static Gee.ArrayList<PptxSlide> slides_for (Document doc, bool snippets_only = false) {
            var list = new Gee.ArrayList<PptxSlide> ();
            doc.link_backgrounds ();
            foreach (var p in doc.foreground_pages ()) {
                foreach (var sn in p.snippets) list.add (new PptxSlide (p, sn.area, sn.name != "" ? sn.name : p.name));
            }
            if (list.size > 0 || snippets_only) return list;
            foreach (var p in doc.foreground_pages ()) list.add (new PptxSlide (p, Rect (0, 0, p.width, p.height), p.name));
            return list;
        }

        public static uint8[] save (Document doc, Gee.List<PptxSlide>? slides = null) throws Error {
            var x = new Pptx ();
            return x.build (doc, slides ?? slides_for (doc));
        }

        private uint8[] build (Document doc, Gee.List<PptxSlide> slides) throws Error {
            var zip = new ZipWriter ();
            var slide_xml = new Gee.ArrayList<string> ();
            var rels_xml = new Gee.ArrayList<string> ();
            foreach (var s in slides) {
                slide_rels.clear ();
                slide_xml.add (write_slide (s));
                var rw = rels_writer ();
                rw.start ("Relationship").attr ("Id", "rId1").attr ("Type", REL_LAYOUT).attr ("Target", "../slideLayouts/slideLayout1.xml").end ();
                for (int i = 0; i < slide_rels.size; i++) {
                    rw.start ("Relationship").attr ("Id", "rId%d".printf (i + 2)).attr ("Type", REL_IMAGE).attr ("Target", "../media/" + slide_rels[i]).end ();
                }
                rels_xml.add (rw.finish ());
            }
            zip.add_text ("[Content_Types].xml", content_types (slide_xml.size));
            zip.add_text ("_rels/.rels", root_rels ());
            zip.add_text ("docProps/app.xml", app_props (slide_xml.size));
            zip.add_text ("docProps/core.xml", core_props (doc));
            zip.add_text ("ppt/presentation.xml", presentation (slide_xml.size));
            zip.add_text ("ppt/_rels/presentation.xml.rels", presentation_rels (slide_xml.size));
            zip.add_text ("ppt/presProps.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:presentationPr xmlns:a=\"%s\" xmlns:r=\"%s\" xmlns:p=\"%s\"/>".printf (NS_A, NS_R, NS_P));
            zip.add_text ("ppt/viewProps.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<p:viewPr xmlns:a=\"%s\" xmlns:r=\"%s\" xmlns:p=\"%s\"><p:normalViewPr><p:restoredLeft sz=\"15620\"/><p:restoredTop sz=\"94660\"/></p:normalViewPr><p:gridSpacing cx=\"76200\" cy=\"76200\"/></p:viewPr>".printf (NS_A, NS_R, NS_P));
            zip.add_text ("ppt/tableStyles.xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<a:tblStyleLst xmlns:a=\"%s\" def=\"{5C22544A-7EE6-4342-B048-85BDC9FD1C3A}\"/>".printf (NS_A));
            zip.add_text ("ppt/theme/theme1.xml", theme ());
            zip.add_text ("ppt/slideMasters/slideMaster1.xml", master ());
            zip.add_text ("ppt/slideMasters/_rels/slideMaster1.xml.rels", master_rels ());
            zip.add_text ("ppt/slideLayouts/slideLayout1.xml", layout ());
            zip.add_text ("ppt/slideLayouts/_rels/slideLayout1.xml.rels", layout_rels ());
            for (int i = 0; i < slide_xml.size; i++) {
                zip.add_text ("ppt/slides/slide%d.xml".printf (i + 1), slide_xml[i]);
                zip.add_text ("ppt/slides/_rels/slide%d.xml.rels".printf (i + 1), rels_xml[i]);
            }
            for (int i = 0; i < media.size; i++) zip.add ("ppt/media/image%d.%s".printf (i + 1, media_ext[i]), media[i].get_data (), false);
            return zip.finish ();
        }

        private static XmlWriter rels_writer () {
            var rw = new XmlWriter ();
            rw.start ("Relationships").attr ("xmlns", NS_PKG);
            return rw;
        }

        private string content_types (int slides) {
            var c = new XmlWriter ();
            c.start ("Types").attr ("xmlns", "http://schemas.openxmlformats.org/package/2006/content-types");
            c.start ("Default").attr ("Extension", "rels").attr ("ContentType", "application/vnd.openxmlformats-package.relationships+xml").end ();
            c.start ("Default").attr ("Extension", "xml").attr ("ContentType", "application/xml").end ();
            c.start ("Default").attr ("Extension", "png").attr ("ContentType", "image/png").end ();
            c.start ("Default").attr ("Extension", "jpeg").attr ("ContentType", "image/jpeg").end ();
            string[,] parts = {
                { "/ppt/presentation.xml", "application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml" },
                { "/ppt/presProps.xml", "application/vnd.openxmlformats-officedocument.presentationml.presProps+xml" },
                { "/ppt/viewProps.xml", "application/vnd.openxmlformats-officedocument.presentationml.viewProps+xml" },
                { "/ppt/tableStyles.xml", "application/vnd.openxmlformats-officedocument.presentationml.tableStyles+xml" },
                { "/ppt/theme/theme1.xml", "application/vnd.openxmlformats-officedocument.theme+xml" },
                { "/ppt/slideMasters/slideMaster1.xml", "application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml" },
                { "/ppt/slideLayouts/slideLayout1.xml", "application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml" },
                { "/docProps/core.xml", "application/vnd.openxmlformats-package.core-properties+xml" },
                { "/docProps/app.xml", "application/vnd.openxmlformats-officedocument.extended-properties+xml" }
            };
            for (int i = 0; i < parts.length[0]; i++) c.start ("Override").attr ("PartName", parts[i, 0]).attr ("ContentType", parts[i, 1]).end ();
            for (int i = 1; i <= slides; i++) {
                c.start ("Override").attr ("PartName", "/ppt/slides/slide%d.xml".printf (i)).attr ("ContentType", "application/vnd.openxmlformats-officedocument.presentationml.slide+xml").end ();
            }
            return c.finish ();
        }

        private string root_rels () {
            var r = rels_writer ();
            r.start ("Relationship").attr ("Id", "rId1").attr ("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument").attr ("Target", "ppt/presentation.xml").end ();
            r.start ("Relationship").attr ("Id", "rId2").attr ("Type", "http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties").attr ("Target", "docProps/core.xml").end ();
            r.start ("Relationship").attr ("Id", "rId3").attr ("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties").attr ("Target", "docProps/app.xml").end ();
            return r.finish ();
        }

        private string app_props (int slides) {
            var a = new XmlWriter ();
            a.start ("Properties").attr ("xmlns", "http://schemas.openxmlformats.org/officeDocument/2006/extended-properties");
            a.element ("Application", "Singularity Draw");
            a.element ("Slides", slides.to_string ());
            return a.finish ();
        }

        private string core_props (Document doc) {
            var c = new XmlWriter ();
            c.start ("cp:coreProperties").attr ("xmlns:cp", "http://schemas.openxmlformats.org/package/2006/metadata/core-properties")
                .attr ("xmlns:dc", "http://purl.org/dc/elements/1.1/").attr ("xmlns:dcterms", "http://purl.org/dc/terms/")
                .attr ("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance");
            if (doc.title != "") c.element ("dc:title", doc.title);
            string now = new DateTime.now_utc ().format ("%Y-%m-%dT%H:%M:%SZ");
            c.start ("dcterms:created").attr ("xsi:type", "dcterms:W3CDTF").text (now).end ();
            c.start ("dcterms:modified").attr ("xsi:type", "dcterms:W3CDTF").text (now).end ();
            return c.finish ();
        }

        private string presentation (int slides) {
            var p = new XmlWriter ();
            p.start ("p:presentation").attr ("xmlns:a", NS_A).attr ("xmlns:r", NS_R).attr ("xmlns:p", NS_P).attr ("saveSubsetFonts", "1");
            p.start ("p:sldMasterIdLst").start ("p:sldMasterId").attr ("id", "2147483648").attr ("r:id", "rId1").end ().end ();
            p.start ("p:sldIdLst");
            for (int i = 0; i < slides; i++) p.start ("p:sldId").attr ("id", (256 + i).to_string ()).attr ("r:id", "rId%d".printf (i + 6)).end ();
            p.end ();
            p.start ("p:sldSz").attr ("cx", SLIDE_W.to_string ()).attr ("cy", SLIDE_H.to_string ()).end ();
            p.start ("p:notesSz").attr ("cx", "6858000").attr ("cy", "9144000").end ();
            p.start ("p:defaultTextStyle");
            p.start ("a:defPPr").start ("a:defRPr").attr ("lang", "en-US").end ().end ();
            p.end ();
            return p.finish ();
        }

        private string presentation_rels (int slides) {
            var r = rels_writer ();
            r.start ("Relationship").attr ("Id", "rId1").attr ("Type", REL_MASTER).attr ("Target", "slideMasters/slideMaster1.xml").end ();
            r.start ("Relationship").attr ("Id", "rId2").attr ("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/presProps").attr ("Target", "presProps.xml").end ();
            r.start ("Relationship").attr ("Id", "rId3").attr ("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/viewProps").attr ("Target", "viewProps.xml").end ();
            r.start ("Relationship").attr ("Id", "rId4").attr ("Type", REL_THEME).attr ("Target", "theme/theme1.xml").end ();
            r.start ("Relationship").attr ("Id", "rId5").attr ("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/tableStyles").attr ("Target", "tableStyles.xml").end ();
            for (int i = 0; i < slides; i++) r.start ("Relationship").attr ("Id", "rId%d".printf (i + 6)).attr ("Type", REL_SLIDE).attr ("Target", "slides/slide%d.xml".printf (i + 1)).end ();
            return r.finish ();
        }

        private string master_rels () {
            var r = rels_writer ();
            r.start ("Relationship").attr ("Id", "rId1").attr ("Type", REL_LAYOUT).attr ("Target", "../slideLayouts/slideLayout1.xml").end ();
            r.start ("Relationship").attr ("Id", "rId2").attr ("Type", REL_THEME).attr ("Target", "../theme/theme1.xml").end ();
            return r.finish ();
        }

        private string layout_rels () {
            var r = rels_writer ();
            r.start ("Relationship").attr ("Id", "rId1").attr ("Type", REL_MASTER).attr ("Target", "../slideMasters/slideMaster1.xml").end ();
            return r.finish ();
        }

        private static void empty_tree (XmlWriter x) {
            x.start ("p:spTree");
            x.start ("p:nvGrpSpPr").start ("p:cNvPr").attr ("id", "1").attr ("name", "").end ().start ("p:cNvGrpSpPr").end ().start ("p:nvPr").end ().end ();
            x.start ("p:grpSpPr").start ("a:xfrm");
            x.start ("a:off").attr ("x", "0").attr ("y", "0").end ().start ("a:ext").attr ("cx", "0").attr ("cy", "0").end ();
            x.start ("a:chOff").attr ("x", "0").attr ("y", "0").end ().start ("a:chExt").attr ("cx", "0").attr ("cy", "0").end ();
            x.end ().end ();
        }

        private string master () {
            var m = new XmlWriter ();
            m.start ("p:sldMaster").attr ("xmlns:a", NS_A).attr ("xmlns:r", NS_R).attr ("xmlns:p", NS_P);
            m.start ("p:cSld");
            m.start ("p:bg").start ("p:bgRef").attr ("idx", "1001").start ("a:schemeClr").attr ("val", "bg1").end ().end ().end ();
            empty_tree (m);
            m.end ();
            m.end ();
            m.start ("p:clrMap").attr ("bg1", "lt1").attr ("tx1", "dk1").attr ("bg2", "lt2").attr ("tx2", "dk2").attr ("accent1", "accent1").attr ("accent2", "accent2")
                .attr ("accent3", "accent3").attr ("accent4", "accent4").attr ("accent5", "accent5").attr ("accent6", "accent6").attr ("hlink", "hlink").attr ("folHlink", "folHlink").end ();
            m.start ("p:sldLayoutIdLst").start ("p:sldLayoutId").attr ("id", "2147483649").attr ("r:id", "rId1").end ().end ();
            m.start ("p:txStyles");
            foreach (string st in new string[] { "p:titleStyle", "p:bodyStyle", "p:otherStyle" }) {
                m.start (st).start ("a:lvl1pPr").start ("a:defRPr").attr ("sz", st == "p:titleStyle" ? "4400" : "1800").start ("a:solidFill").start ("a:schemeClr").attr ("val", "tx1").end ().end ()
                    .start ("a:latin").attr ("typeface", "+mn-lt").end ().end ().end ().end ();
            }
            m.end ();
            return m.finish ();
        }

        private string layout () {
            var l = new XmlWriter ();
            l.start ("p:sldLayout").attr ("xmlns:a", NS_A).attr ("xmlns:r", NS_R).attr ("xmlns:p", NS_P).attr ("type", "blank").attr ("preserve", "1");
            l.start ("p:cSld").attr ("name", "Blank");
            empty_tree (l);
            l.end ();
            l.end ();
            l.start ("p:clrMapOvr").start ("a:masterClrMapping").end ().end ();
            return l.finish ();
        }

        private string theme () {
            var t = new XmlWriter ();
            t.start ("a:theme").attr ("xmlns:a", NS_A).attr ("name", "Singularity");
            t.start ("a:themeElements");
            t.start ("a:clrScheme").attr ("name", "Singularity");
            t.start ("a:dk1").start ("a:sysClr").attr ("val", "windowText").attr ("lastClr", "000000").end ().end ();
            t.start ("a:lt1").start ("a:sysClr").attr ("val", "window").attr ("lastClr", "FFFFFF").end ().end ();
            string[,] cols = {
                { "a:dk2", "1E1E1E" }, { "a:lt2", "F2F2F2" }, { "a:accent1", "3A6EA5" }, { "a:accent2", "E5534B" }, { "a:accent3", "6FBF5A" },
                { "a:accent4", "F5C518" }, { "a:accent5", "8A63C9" }, { "a:accent6", "35A797" }, { "a:hlink", "1F4E79" }, { "a:folHlink", "5A3A8F" }
            };
            for (int i = 0; i < cols.length[0]; i++) t.start (cols[i, 0]).start ("a:srgbClr").attr ("val", cols[i, 1]).end ().end ();
            t.end ();
            t.start ("a:fontScheme").attr ("name", "Singularity");
            foreach (string f in new string[] { "a:majorFont", "a:minorFont" }) {
                t.start (f).start ("a:latin").attr ("typeface", "Calibri").end ().start ("a:ea").attr ("typeface", "").end ().start ("a:cs").attr ("typeface", "").end ().end ();
            }
            t.end ();
            t.start ("a:fmtScheme").attr ("name", "Singularity");
            t.start ("a:fillStyleLst");
            for (int i = 0; i < 3; i++) t.start ("a:solidFill").start ("a:schemeClr").attr ("val", "phClr").end ().end ();
            t.end ();
            t.start ("a:lnStyleLst");
            foreach (string wv in new string[] { "6350", "12700", "19050" }) {
                t.start ("a:ln").attr ("w", wv).start ("a:solidFill").start ("a:schemeClr").attr ("val", "phClr").end ().end ().start ("a:prstDash").attr ("val", "solid").end ().end ();
            }
            t.end ();
            t.start ("a:effectStyleLst");
            for (int i = 0; i < 3; i++) t.start ("a:effectStyle").start ("a:effectLst").end ().end ();
            t.end ();
            t.start ("a:bgFillStyleLst");
            for (int i = 0; i < 3; i++) t.start ("a:solidFill").start ("a:schemeClr").attr ("val", "phClr").end ().end ();
            t.end ();
            t.end ();
            t.end ();
            return t.finish ();
        }

        private string emu (double px) {
            return ((int64) Math.round (px * k)).to_string ();
        }

        private string ex (double x) {
            return ((int64) Math.round ((x - area.x) * k + ox)).to_string ();
        }

        private string ey (double y) {
            return ((int64) Math.round ((y - area.y) * k + oy)).to_string ();
        }

        private static string hex6 (string c) {
            return Colors.rgb_hex (c).substring (1).up ();
        }

        private void color_el (string c, double opacity = 1) {
            Rgba rgba;
            if (!Colors.parse (c, out rgba)) rgba = Rgba (0, 0, 0, 1);
            w.start ("a:srgbClr").attr ("val", hex6 (c));
            double al = rgba.a * opacity;
            if (al < 0.999) w.start ("a:alpha").attr ("val", ((int) Math.round (al.clamp (0, 1) * 100000)).to_string ()).end ();
            w.end ();
        }

        private void solid (string c, double opacity = 1) {
            w.start ("a:solidFill");
            color_el (c, opacity);
            w.end ();
        }

        private void fill_el (Style st, string? override_color = null) {
            if (override_color != null) {
                solid (override_color, st.opacity);
                return;
            }
            if (!st.has_fill ()) {
                w.start ("a:noFill").end ();
                return;
            }
            if (st.fill_kind == FillKind.LINEAR || st.fill_kind == FillKind.RADIAL) {
                w.start ("a:gradFill").attr ("rotWithShape", "1");
                w.start ("a:gsLst");
                w.start ("a:gs").attr ("pos", "0");
                color_el (st.fill, st.opacity);
                w.end ();
                w.start ("a:gs").attr ("pos", "100000");
                color_el (st.fill2, st.opacity);
                w.end ();
                w.end ();
                if (st.fill_kind == FillKind.LINEAR) {
                    int ang = (int) Math.round (Document.normalize_angle (st.gradient_angle) * 60000) % 21600000;
                    w.start ("a:lin").attr ("ang", ang.to_string ()).attr ("scaled", "0").end ();
                } else {
                    w.start ("a:path").attr ("path", "circle").start ("a:fillToRect").attr ("l", "50000").attr ("t", "50000").attr ("r", "50000").attr ("b", "50000").end ().end ();
                }
                w.end ();
                return;
            }
            solid (st.fill, st.opacity);
        }

        private static string dash_name (DashKind d) {
            switch (d) {
                case DashKind.DASH: return "dash";
                case DashKind.DOT: return "sysDot";
                case DashKind.DASH_DOT: return "dashDot";
                case DashKind.LONG_DASH: return "lgDash";
                case DashKind.DASH_DOT_DOT: return "sysDashDotDot";
                default: return "solid";
            }
        }

        private static string? arrow_name (ArrowKind a) {
            switch (a) {
                case ArrowKind.NONE: return null;
                case ArrowKind.OPEN: case ArrowKind.TRIANGLE_OPEN: return "arrow";
                case ArrowKind.STEALTH: return "stealth";
                case ArrowKind.DIAMOND: case ArrowKind.DIAMOND_OPEN: return "diamond";
                case ArrowKind.CIRCLE: case ArrowKind.CIRCLE_OPEN: return "oval";
                default: return "triangle";
            }
        }

        private void line_el (Style st, bool arrows) {
            if (!st.has_stroke ()) {
                w.start ("a:ln").start ("a:noFill").end ().end ();
                return;
            }
            w.start ("a:ln").attr ("w", emu (double.max (st.stroke_width, 0.25)));
            solid (st.stroke, st.opacity);
            w.start ("a:prstDash").attr ("val", dash_name (st.dash)).end ();
            w.start ("a:round").end ();
            if (arrows) {
                string sz = st.arrow_size >= 1.5 ? "lg" : (st.arrow_size <= 0.7 ? "sm" : "med");
                string? h = arrow_name (st.arrow_start), t = arrow_name (st.arrow_end);
                if (h != null) w.start ("a:headEnd").attr ("type", h).attr ("w", sz).attr ("len", sz).end ();
                if (t != null) w.start ("a:tailEnd").attr ("type", t).attr ("w", sz).attr ("len", sz).end ();
            }
            w.end ();
        }

        private void effects (Style st) {
            if (!st.shadow) return;
            Rgba c;
            if (!Colors.parse (st.shadow_color, out c)) c = Rgba (0, 0, 0, 0.25);
            double dist = Math.sqrt (st.shadow_dx * st.shadow_dx + st.shadow_dy * st.shadow_dy);
            double dir = Document.normalize_angle (Math.atan2 (st.shadow_dy, st.shadow_dx) * 180 / Math.PI);
            w.start ("a:effectLst").start ("a:outerShdw").attr ("blurRad", emu (st.shadow_blur)).attr ("dist", emu (dist))
                .attr ("dir", ((int) Math.round (dir * 60000)).to_string ()).attr ("algn", "ctr").attr ("rotWithShape", "0");
            w.start ("a:srgbClr").attr ("val", Colors.to_hex (Rgba (c.r, c.g, c.b, 1)).substring (1, 6).up ());
            w.start ("a:alpha").attr ("val", ((int) Math.round (c.a * 100000)).to_string ()).end ();
            w.end ().end ().end ();
        }

        private void xfrm (string tag, Shape s) {
            w.start (tag);
            if (s.rotation != 0) w.attr ("rot", ((int) Math.round (Document.normalize_angle (s.rotation) * 60000)).to_string ());
            if (s.flip_h) w.attr ("flipH", "1");
            if (s.flip_v) w.attr ("flipV", "1");
            w.start ("a:off").attr ("x", ex (s.x)).attr ("y", ey (s.y)).end ();
            w.start ("a:ext").attr ("cx", emu (double.max (s.w, 0.01))).attr ("cy", emu (double.max (s.h, 0.01))).end ();
            w.end ();
        }

        private void nv (string tag, string pr_tag, Item it, string fallback) {
            w.start (tag);
            w.start ("p:cNvPr").attr ("id", (next_shape++).to_string ()).attr ("name", it.name != "" ? it.name : "%s %d".printf (fallback, next_shape - 1));
            string descr = it.alt_text != "" ? it.alt_text : it.alt_title;
            if (descr != "") w.attr ("descr", descr);
            w.end ();
            w.start (pr_tag).end ();
            w.start ("p:nvPr").end ();
            w.end ();
        }

        private void path_el (PathData path, double pw, double ph, string fill, bool stroke, double sx, double sy, double dx = 0, double dy = 0) {
            w.start ("a:path").attr ("w", ((int64) Math.round (double.max (pw, 0.01) * 100)).to_string ()).attr ("h", ((int64) Math.round (double.max (ph, 0.01) * 100)).to_string ());
            if (fill != "norm") w.attr ("fill", fill);
            if (!stroke) w.attr ("stroke", "0");
            foreach (var seg in path.segs) {
                switch (seg.kind) {
                    case SegKind.MOVE:
                        w.start ("a:moveTo");
                        pt ((seg.x - dx) * sx, (seg.y - dy) * sy);
                        w.end ();
                        break;
                    case SegKind.LINE:
                        w.start ("a:lnTo");
                        pt ((seg.x - dx) * sx, (seg.y - dy) * sy);
                        w.end ();
                        break;
                    case SegKind.CURVE:
                        w.start ("a:cubicBezTo");
                        pt ((seg.x1 - dx) * sx, (seg.y1 - dy) * sy);
                        pt ((seg.x2 - dx) * sx, (seg.y2 - dy) * sy);
                        pt ((seg.x - dx) * sx, (seg.y - dy) * sy);
                        w.end ();
                        break;
                    case SegKind.CLOSE:
                        w.start ("a:close").end ();
                        break;
                }
            }
            w.end ();
        }

        private void pt (double x, double y) {
            w.start ("a:pt").attr ("x", ((int64) Math.round (x * 100)).to_string ()).attr ("y", ((int64) Math.round (y * 100)).to_string ()).end ();
        }

        private static string part_fill (PartMode m) {
            switch (m) {
                case PartMode.STROKE: return "none";
                case PartMode.FILL_DARK: return "darken";
                case PartMode.FILL_SHADE: return "darkenLess";
                default: return "norm";
            }
        }

        private void cust_geom (Geometry geo, double sw, double sh, Gee.List<GeomPart> parts) {
            w.start ("a:custGeom");
            w.start ("a:avLst").end ().start ("a:gdLst").end ().start ("a:ahLst").end ().start ("a:cxnLst").end ();
            w.start ("a:rect").attr ("l", "0").attr ("t", "0").attr ("r", "r").attr ("b", "b").end ();
            w.start ("a:pathLst");
            foreach (var part in parts) path_el (part.path, sw, sh, part_fill (part.mode), part.mode != PartMode.FILL_ONLY && part.mode != PartMode.FILL_DARK && part.mode != PartMode.FILL_SHADE, 1, 1);
            w.end ();
            w.end ();
        }

        private void text_body (Item it, string text, Style st, Rect? inset_box, double box_w, double box_h, bool line_label = false) {
            w.start ("p:txBody");
            w.start ("a:bodyPr").attr ("rtlCol", "0").attr ("wrap", st.wrap && !line_label ? "square" : "none");
            if (inset_box != null) {
                Rect r = inset_box;
                w.attr ("lIns", emu (double.max (r.x, 0))).attr ("tIns", emu (double.max (r.y, 0)));
                w.attr ("rIns", emu (double.max (box_w - r.x - r.w, 0))).attr ("bIns", emu (double.max (box_h - r.y - r.h, 0)));
            } else {
                w.attr ("lIns", "0").attr ("tIns", "0").attr ("rIns", "0").attr ("bIns", "0");
            }
            w.attr ("anchor", st.valign == TextVAlign.TOP ? "t" : (st.valign == TextVAlign.BOTTOM ? "b" : "ctr"));
            w.start ("a:noAutofit").end ();
            w.end ();
            w.start ("a:lstStyle").end ();
            var runs = text == it.text ? it.rich_runs () : null;
            if (runs == null) {
                runs = new Gee.ArrayList<TextRun> ();
                runs.add (new TextRun (text));
            }
            string algn = st.halign == TextHAlign.LEFT ? "l" : (st.halign == TextHAlign.RIGHT ? "r" : "ctr");
            foreach (var line in RichRuns.split_lines (runs)) {
                w.start ("a:p");
                w.start ("a:pPr").attr ("algn", algn).end ();
                foreach (var r in line) {
                    w.start ("a:r");
                    run_props ("a:rPr", st, r);
                    w.element ("a:t", r.text);
                    w.end ();
                }
                run_props ("a:endParaRPr", st, new TextRun ());
                w.end ();
            }
            w.end ();
        }

        private void run_props (string tag, Style st, TextRun r) {
            double pt = r.eff_size (st) * k / 9525.0;
            w.start (tag).attr ("lang", "en-US").attr ("sz", ((int) Math.round (pt.clamp (1, 4000) * 100)).to_string ());
            if (r.eff_bold (st)) w.attr ("b", "1");
            if (r.eff_italic (st)) w.attr ("i", "1");
            if (r.eff_underline (st)) w.attr ("u", "sng");
            if (r.eff_strike (st)) w.attr ("strike", "sngStrike");
            w.attr ("dirty", "0");
            solid (r.eff_color (st), st.opacity);
            string fam = r.eff_family (st);
            w.start ("a:latin").attr ("typeface", fam == "Sans" ? "Calibri" : (fam == "Serif" ? "Cambria" : (fam == "Monospace" ? "Consolas" : fam))).end ();
            w.end ();
        }

        private bool needs_picture (Item it) {
            if (it is ImageShape) return !((it as ImageShape).bytes.length > 0);
            if (it is Group || it is Connector) return false;
            var tb = it as TableShape;
            if (tb != null) return tb.rotation != 0;
            var s = it as Shape;
            if (s == null) return true;
            var t = s.get_type ();
            if (t != typeof (Shape) && t != typeof (PathShape)) return true;
            if (it.data_graphic != "") return true;
            if (s.kind == "uml-class" || s.kind == "uml-interface" || s.kind.has_prefix ("org-")) return true;
            return false;
        }

        private void write_item (Item it) {
            if (needs_picture (it)) {
                picture_fallback (it);
                return;
            }
            var g = it as Group;
            if (g != null) {
                write_group (g);
                return;
            }
            var c = it as Connector;
            if (c != null) {
                write_connector (c);
                return;
            }
            var img = it as ImageShape;
            if (img != null) {
                write_image (img);
                return;
            }
            var tb = it as TableShape;
            if (tb != null) {
                write_table (tb);
                return;
            }
            write_shape ((Shape) it);
        }

        private void write_shape (Shape s) {
            var geo = s.geometry ();
            bool colored = false;
            foreach (var part in geo.parts) if (part.color != null) colored = true;
            if (colored) {
                var b = s.box ();
                w.start ("p:grpSp");
                nv ("p:nvGrpSpPr", "p:cNvGrpSpPr", s, "Group");
                w.start ("p:grpSpPr");
                w.start ("a:xfrm");
                if (s.rotation != 0) w.attr ("rot", ((int) Math.round (Document.normalize_angle (s.rotation) * 60000)).to_string ());
                if (s.flip_h) w.attr ("flipH", "1");
                if (s.flip_v) w.attr ("flipV", "1");
                w.start ("a:off").attr ("x", ex (b.x)).attr ("y", ey (b.y)).end ();
                w.start ("a:ext").attr ("cx", emu (b.w)).attr ("cy", emu (b.h)).end ();
                w.start ("a:chOff").attr ("x", ex (b.x)).attr ("y", ey (b.y)).end ();
                w.start ("a:chExt").attr ("cx", emu (b.w)).attr ("cy", emu (b.h)).end ();
                w.end ().end ();
                foreach (var part in geo.parts) {
                    var one = new Gee.ArrayList<GeomPart> ();
                    one.add (part);
                    var flat = new Shape (s.kind, s.x, s.y, s.w, s.h);
                    w.start ("p:sp");
                    nv ("p:nvSpPr", "p:cNvSpPr", flat, "Part");
                    w.start ("p:spPr");
                    xfrm ("a:xfrm", flat);
                    cust_geom (geo, s.w, s.h, one);
                    if (part.mode == PartMode.STROKE) w.start ("a:noFill").end ();
                    else fill_el (s.style, part.color);
                    if (part.mode == PartMode.FILL_ONLY || part.mode == PartMode.FILL_DARK || part.mode == PartMode.FILL_SHADE) w.start ("a:ln").start ("a:noFill").end ().end ();
                    else line_el (s.style, false);
                    w.end ();
                    w.end ();
                    native_shapes++;
                }
                string text = s.display_text ();
                if (text != "") {
                    w.start ("p:sp");
                    nv ("p:nvSpPr", "p:cNvSpPr", s, "Text");
                    w.start ("p:spPr");
                    var flat = new Shape (s.kind, s.x, s.y, s.w, s.h);
                    xfrm ("a:xfrm", flat);
                    w.start ("a:prstGeom").attr ("prst", "rect").start ("a:avLst").end ().end ();
                    w.start ("a:noFill").end ();
                    w.start ("a:ln").start ("a:noFill").end ().end ();
                    w.end ();
                    text_body (s, text, s.style, Renderer.text_rect_for (s, geo), s.w, s.h);
                    w.end ();
                }
                w.end ();
                return;
            }
            w.start ("p:sp");
            nv ("p:nvSpPr", "p:cNvSpPr", s, "Shape");
            w.start ("p:spPr");
            xfrm ("a:xfrm", s);
            if (geo.parts.size == 0) w.start ("a:prstGeom").attr ("prst", "rect").start ("a:avLst").end ().end ();
            else cust_geom (geo, s.w, s.h, geo.parts);
            bool any_fill = false, any_stroke = false;
            foreach (var part in geo.parts) {
                if (part.mode != PartMode.STROKE) any_fill = true;
                if (part.mode == PartMode.STROKE || part.mode == PartMode.FILL_STROKE) any_stroke = true;
            }
            if (any_fill || geo.parts.size == 0) fill_el (s.style);
            else w.start ("a:noFill").end ();
            if (any_stroke) line_el (s.style, s is PathShape);
            else w.start ("a:ln").start ("a:noFill").end ().end ();
            effects (s.style);
            w.end ();
            string text = s.display_text ();
            if (text != "") text_body (s, text, s.style, Renderer.text_rect_for (s, geo), s.w, s.h);
            w.end ();
            native_shapes++;
        }

        private void write_group (Group g) {
            var b = g.bounds ();
            w.start ("p:grpSp");
            nv ("p:nvGrpSpPr", "p:cNvGrpSpPr", g, "Group");
            w.start ("p:grpSpPr").start ("a:xfrm");
            w.start ("a:off").attr ("x", ex (b.x)).attr ("y", ey (b.y)).end ();
            w.start ("a:ext").attr ("cx", emu (b.w)).attr ("cy", emu (b.h)).end ();
            w.start ("a:chOff").attr ("x", ex (b.x)).attr ("y", ey (b.y)).end ();
            w.start ("a:chExt").attr ("cx", emu (b.w)).attr ("cy", emu (b.h)).end ();
            w.end ().end ();
            foreach (var c in g.children) write_item (c);
            w.end ();
            string text = g.display_text ();
            if (text != "") text_box (g, text, g.style, b);
        }

        private void text_box (Item it, string text, Style st, Rect r, bool label = false) {
            w.start ("p:sp");
            nv ("p:nvSpPr", "p:cNvSpPr", it, "Text");
            w.start ("p:spPr");
            w.start ("a:xfrm").start ("a:off").attr ("x", ex (r.x)).attr ("y", ey (r.y)).end ().start ("a:ext").attr ("cx", emu (r.w)).attr ("cy", emu (r.h)).end ().end ();
            w.start ("a:prstGeom").attr ("prst", "rect").start ("a:avLst").end ().end ();
            if (label) solid (Colors.is_none (st.fill) || st.fill_kind == FillKind.NONE ? "#ffffff" : st.fill, 0.92);
            else w.start ("a:noFill").end ();
            w.start ("a:ln").start ("a:noFill").end ().end ();
            w.end ();
            text_body (it, text, st, null, r.w, r.h, label);
            w.end ();
            native_shapes++;
        }

        private void write_connector (Connector c) {
            var path = c.path ();
            if (path.segs.size < 2) return;
            var b = Rect.empty ();
            foreach (var seg in path.segs) {
                if (seg.kind == SegKind.CLOSE) continue;
                b = b.include (seg.x, seg.y);
                if (seg.kind == SegKind.CURVE) {
                    b = b.include (seg.x1, seg.y1);
                    b = b.include (seg.x2, seg.y2);
                }
            }
            double bw = double.max (b.w, 0.01), bh = double.max (b.h, 0.01);
            w.start ("p:cxnSp");
            nv ("p:nvCxnSpPr", "p:cNvCxnSpPr", c, "Connector");
            w.start ("p:spPr");
            w.start ("a:xfrm").start ("a:off").attr ("x", ex (b.x)).attr ("y", ey (b.y)).end ().start ("a:ext").attr ("cx", emu (bw)).attr ("cy", emu (bh)).end ().end ();
            w.start ("a:custGeom");
            w.start ("a:avLst").end ().start ("a:gdLst").end ().start ("a:ahLst").end ().start ("a:cxnLst").end ();
            w.start ("a:rect").attr ("l", "0").attr ("t", "0").attr ("r", "r").attr ("b", "b").end ();
            w.start ("a:pathLst");
            path_el (path, bw, bh, "none", true, 1, 1, b.x, b.y);
            w.end ();
            w.end ();
            w.start ("a:noFill").end ();
            line_el (c.style, true);
            effects (c.style);
            w.end ();
            w.end ();
            native_shapes++;
            string text = c.display_text ();
            if (text != "") {
                if (scratch == null) scratch = new Cairo.Context (new Cairo.ImageSurface (Cairo.Format.ARGB32, 4, 4));
                var lr = Renderer.connector_label_rect (scratch, c);
                text_box (c, text, c.style, lr, true);
            }
        }

        private static Cairo.Context? scratch = null;

        private string add_media (uint8[] data, string ext) {
            media.add (new Bytes (data));
            media_ext.add (ext);
            string name = "image%d.%s".printf (media.size, ext);
            slide_rels.add (name);
            return "rId%d".printf (slide_rels.size + 1);
        }

        private void pic (Item it, string rid, Rect r, double rotation, bool fh, bool fv) {
            w.start ("p:pic");
            w.start ("p:nvPicPr");
            w.start ("p:cNvPr").attr ("id", (next_shape++).to_string ()).attr ("name", it.name != "" ? it.name : "Picture %d".printf (next_shape - 1));
            string descr = it.display_text ();
            if (it.alt_title != "") descr = it.alt_title;
            if (it.alt_text != "") descr = it.alt_text;
            if (descr != "") w.attr ("descr", descr);
            w.end ();
            w.start ("p:cNvPicPr").start ("a:picLocks").attr ("noChangeAspect", "1").end ().end ();
            w.start ("p:nvPr").end ();
            w.end ();
            w.start ("p:blipFill").start ("a:blip").attr ("r:embed", rid).end ().start ("a:stretch").start ("a:fillRect").end ().end ().end ();
            w.start ("p:spPr");
            w.start ("a:xfrm");
            if (rotation != 0) w.attr ("rot", ((int) Math.round (Document.normalize_angle (rotation) * 60000)).to_string ());
            if (fh) w.attr ("flipH", "1");
            if (fv) w.attr ("flipV", "1");
            w.start ("a:off").attr ("x", ex (r.x)).attr ("y", ey (r.y)).end ().start ("a:ext").attr ("cx", emu (double.max (r.w, 0.01))).attr ("cy", emu (double.max (r.h, 0.01))).end ();
            w.end ();
            w.start ("a:prstGeom").attr ("prst", "rect").start ("a:avLst").end ().end ();
            w.end ();
            w.end ();
        }

        private void write_image (ImageShape img) {
            uint8[] data = img.bytes;
            string ext = "png";
            if (img.mime == "image/jpeg") ext = "jpeg";
            else if (img.mime != "image/png") {
                var pix = Renderer.pixbuf_for (img);
                if (pix == null) {
                    picture_fallback (img);
                    return;
                }
                try {
                    pix.save_to_buffer (out data, "png");
                } catch (Error e) {
                    picture_fallback (img);
                    return;
                }
            }
            string rid = add_media (data, ext);
            pic (img, rid, img.box (), img.rotation, img.flip_h, img.flip_v);
            native_shapes++;
        }

        private void picture_fallback (Item it) {
            var b = it.bounds ().inflate (4);
            if (b.is_empty () || b.w < 1 || b.h < 1) return;
            var only = new Gee.ArrayList<Item> ();
            only.add (it);
            double scale = double.min (3, 4000 / double.max (b.w, b.h));
            var surf = Export.render_area (page, b, double.max (scale, 0.5), true, only);
            string rid = add_media (Export.png_bytes (surf), "png");
            pic (it, rid, b, 0, false, false);
            picture_shapes++;
        }

        private void write_table (TableShape t) {
            w.start ("p:graphicFrame");
            w.start ("p:nvGraphicFramePr");
            w.start ("p:cNvPr").attr ("id", (next_shape++).to_string ()).attr ("name", t.name != "" ? t.name : "Table %d".printf (next_shape - 1)).end ();
            w.start ("p:cNvGraphicFramePr").start ("a:graphicFrameLocks").attr ("noGrp", "1").end ().end ();
            w.start ("p:nvPr").end ();
            w.end ();
            w.start ("p:xfrm").start ("a:off").attr ("x", ex (t.x)).attr ("y", ey (t.y)).end ().start ("a:ext").attr ("cx", emu (t.w)).attr ("cy", emu (t.h)).end ().end ();
            w.start ("a:graphic").start ("a:graphicData").attr ("uri", "http://schemas.openxmlformats.org/drawingml/2006/table");
            w.start ("a:tbl");
            w.start ("a:tblPr").attr ("firstRow", t.header_row ? "1" : "0").end ();
            w.start ("a:tblGrid");
            for (int c = 0; c < t.cols; c++) w.start ("a:gridCol").attr ("w", emu (t.col_x (c + 1) - t.col_x (c))).end ();
            w.end ();
            for (int r = 0; r < t.rows; r++) {
                w.start ("a:tr").attr ("h", emu (t.row_y (r + 1) - t.row_y (r)));
                for (int c = 0; c < t.cols; c++) {
                    var st = t.style.copy ();
                    if (r == 0 && t.header_row) st.bold = true;
                    w.start ("a:tc");
                    var plain = new Shape ("text");
                    plain.text = t.get_cell (r, c);
                    w.start ("a:txBody");
                    w.start ("a:bodyPr").end ();
                    w.start ("a:lstStyle").end ();
                    string[] lines = plain.text == "" ? new string[] { "" } : plain.text.split ("\n");
                    foreach (string line in lines) {
                        w.start ("a:p");
                        w.start ("a:pPr").attr ("algn", st.halign == TextHAlign.LEFT ? "l" : (st.halign == TextHAlign.RIGHT ? "r" : "ctr")).end ();
                        if (line != "") {
                            w.start ("a:r");
                            run_props ("a:rPr", st, new TextRun (line));
                            w.element ("a:t", line);
                            w.end ();
                        }
                        run_props ("a:endParaRPr", st, new TextRun ());
                        w.end ();
                    }
                    w.end ();
                    w.start ("a:tcPr").attr ("anchor", "ctr");
                    foreach (string side in new string[] { "a:lnL", "a:lnR", "a:lnT", "a:lnB" }) {
                        w.start (side).attr ("w", emu (double.max (t.style.stroke_width, 0.5)));
                        if (t.style.has_stroke ()) solid (t.style.stroke);
                        else w.start ("a:noFill").end ();
                        w.end ();
                    }
                    if (r == 0 && t.header_row) solid (t.header_fill);
                    else if (t.style.has_fill ()) solid (t.style.fill);
                    else w.start ("a:noFill").end ();
                    w.end ();
                    w.end ();
                }
                w.end ();
            }
            w.end ();
            w.end ().end ();
            w.end ();
            native_shapes++;
        }

        private void write_page_items (Page p) {
            foreach (var it in p.items) {
                if (!p.item_visible (it)) continue;
                if (!it.bounds ().intersects (area)) continue;
                write_item (it);
            }
        }

        private string write_slide (PptxSlide s) {
            page = s.page;
            area = s.area;
            double aw = double.max (area.w, 1), ah = double.max (area.h, 1);
            k = double.min (SLIDE_W / aw, SLIDE_H / ah) * 0.94;
            ox = (SLIDE_W - aw * k) / 2;
            oy = (SLIDE_H - ah * k) / 2;
            next_shape = 2;
            w = new XmlWriter ();
            w.start ("p:sld").attr ("xmlns:a", NS_A).attr ("xmlns:r", NS_R).attr ("xmlns:p", NS_P);
            w.start ("p:cSld");
            if (s.name != "") w.attr ("name", s.name);
            string bg = page.background;
            if (page.back_ref != null && Colors.is_none (bg)) bg = page.back_ref.background;
            if (!Colors.is_none (bg) && Colors.rgb_hex (bg).down () != "#ffffff") {
                w.start ("p:bg").start ("p:bgPr");
                solid (bg);
                w.start ("a:effectLst").end ();
                w.end ().end ();
            }
            empty_tree_open ();
            if (page.back_ref != null) {
                var keep = page;
                page = page.back_ref;
                write_page_items (page);
                page = keep;
            }
            write_page_items (page);
            w.end ();
            w.end ();
            w.start ("p:clrMapOvr").start ("a:masterClrMapping").end ().end ();
            return w.finish ();
        }

        private void empty_tree_open () {
            w.start ("p:spTree");
            w.start ("p:nvGrpSpPr").start ("p:cNvPr").attr ("id", "1").attr ("name", "").end ().start ("p:cNvGrpSpPr").end ().start ("p:nvPr").end ().end ();
            w.start ("p:grpSpPr").start ("a:xfrm");
            w.start ("a:off").attr ("x", "0").attr ("y", "0").end ().start ("a:ext").attr ("cx", "0").attr ("cy", "0").end ();
            w.start ("a:chOff").attr ("x", "0").attr ("y", "0").end ().start ("a:chExt").attr ("cx", "0").attr ("cy", "0").end ();
            w.end ().end ();
        }
    }
}
