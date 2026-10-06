namespace Singularity.Apps.Draw {

    public class Ora {
        public const string MIME = "image/openraster";

        public static string[] flattened_layers (Page page) {
            string[] names = {};
            foreach (var l in page.layers) {
                if (l.raster) continue;
                foreach (var it in page.items) {
                    if (page.layer_of (it) == l && !(it is RasterItem)) {
                        names += l.name;
                        break;
                    }
                }
            }
            return names;
        }

        public static uint8[] save (Document doc, Page? which = null) throws Error {
            var page = which ?? doc.page;
            int w = int.max (1, (int) Math.ceil (page.width)), h = int.max (1, (int) Math.ceil (page.height));
            var zip = new ZipWriter ();
            zip.add_text ("mimetype", MIME, false);
            var stack = new XmlWriter (true);
            stack.start ("image").attr ("version", "0.0.5").attr ("w", w.to_string ()).attr ("h", h.to_string ())
                .attr ("xres", "96").attr ("yres", "96");
            stack.start ("stack");
            int n = 0;
            var files = new Gee.ArrayList<string> ();
            var datas = new Gee.ArrayList<Bytes> ();
            for (int i = page.layers.size - 1; i >= 0; i--) {
                var l = page.layers[i];
                bool any = false;
                foreach (var it in page.items) if (page.layer_of (it) == l) any = true;
                if (!any && !l.raster) continue;
                string src = "data/layer%d.png".printf (++n);
                var surf = Raster.render_layer (page, l);
                files.add (src);
                datas.add (new Bytes (Pixels.png (surf)));
                stack.start ("layer").attr ("name", l.name).attr ("src", src).attr ("x", "0").attr ("y", "0")
                    .attr ("opacity", PathData.fmt (l.raster ? l.opacity : 1, 4))
                    .attr ("visibility", l.visible ? "visible" : "hidden")
                    .attr ("composite-op", l.raster ? l.blend.to_ora () : "svg:src-over");
                if (l.locked) stack.attr ("edit-locked", "true");
                stack.end ();
            }
            if (!Colors.is_none (page.background)) {
                string src = "data/layer%d.png".printf (++n);
                var bg = Pixels.blank (w, h);
                var cr = new Cairo.Context (bg);
                Rgba c;
                if (Colors.parse (page.background, out c)) c.apply (cr);
                cr.paint ();
                bg.flush ();
                files.add (src);
                datas.add (new Bytes (Pixels.png (bg)));
                stack.start ("layer").attr ("name", _("Background")).attr ("src", src).attr ("x", "0").attr ("y", "0")
                    .attr ("opacity", "1").attr ("visibility", "visible").attr ("composite-op", "svg:src-over")
                    .attr ("sdraw-background", page.background).end ();
            }
            stack.end ();
            stack.end ();
            zip.add_text ("stack.xml", stack.finish ());
            for (int i = 0; i < files.size; i++) zip.add (files[i], datas[i].get_data (), false);
            var merged = Export.render_area (page, Rect (0, 0, w, h), 1, Colors.is_none (page.background));
            zip.add ("mergedimage.png", Pixels.png (merged), false);
            zip.add ("Thumbnails/thumbnail.png", Pixels.png (thumbnail (merged, 256)), false);
            return zip.finish ();
        }

        public static Cairo.ImageSurface thumbnail (Cairo.ImageSurface src, int max) {
            int w = src.get_width (), h = src.get_height ();
            double sc = double.min (1, (double) max / int.max (w, h));
            int tw = int.max (1, (int) Math.round (w * sc)), th = int.max (1, (int) Math.round (h * sc));
            var t = Pixels.blank (tw, th);
            var cr = new Cairo.Context (t);
            cr.scale ((double) tw / w, (double) th / h);
            cr.set_source_surface (src, 0, 0);
            cr.get_source ().set_filter (Cairo.Filter.GOOD);
            cr.paint ();
            t.flush ();
            return t;
        }

        private class Entry {
            public string name;
            public string src;
            public double x;
            public double y;
            public double opacity;
            public bool visible;
            public bool locked;
            public BlendMode blend;
            public string? background;
        }

        private static void collect (Xml.Node* stack, Gee.List<Entry> into) {
            foreach (var n in XmlUtil.children (stack)) {
                if (n->name == "stack") {
                    collect (n, into);
                    continue;
                }
                if (n->name != "layer") continue;
                var e = new Entry ();
                e.name = XmlUtil.attr_or (n, "name", "");
                e.src = XmlUtil.attr_or (n, "src", "");
                e.x = XmlUtil.attr_double (n, "x", 0);
                e.y = XmlUtil.attr_double (n, "y", 0);
                e.opacity = XmlUtil.attr_double (n, "opacity", 1).clamp (0, 1);
                e.visible = XmlUtil.attr_or (n, "visibility", "visible") != "hidden";
                e.locked = XmlUtil.attr_or (n, "edit-locked", "false") == "true";
                e.blend = BlendMode.from_id (XmlUtil.attr (n, "composite-op"));
                e.background = XmlUtil.attr (n, "sdraw-background");
                into.add (e);
            }
        }

        public static Document load (uint8[] data) throws Error {
            var zip = new ZipReader (data);
            string? stack = zip.read_text ("stack.xml");
            if (stack == null) throw new FormatError.INVALID (_("The image has no layers."));
            Xml.Doc* xdoc = XmlUtil.parse (stack);
            var root = xdoc->get_root_element ();
            var doc = new Document ();
            var page = doc.page;
            var entries = new Gee.ArrayList<Entry> ();
            try {
                if (root == null || root->name != "image") throw new FormatError.INVALID (_("The image has no layers."));
                page.width = double.max (1, XmlUtil.attr_double (root, "w", 1));
                page.height = double.max (1, XmlUtil.attr_double (root, "h", 1));
                var top = XmlUtil.child (root, "stack");
                if (top != null) collect (top, entries);
            } finally {
                delete xdoc;
            }
            page.layers.clear ();
            page.background = "none";
            for (int i = entries.size - 1; i >= 0; i--) {
                var e = entries[i];
                if (i == entries.size - 1 && e.background != null) {
                    page.background = e.background;
                    continue;
                }
                var bytes = zip.read (e.src);
                Cairo.ImageSurface? surf = bytes != null ? Pixels.decode (bytes) : null;
                if (surf == null) surf = Pixels.blank ((int) page.width, (int) page.height);
                var item = new RasterItem.from_surface (surf, e.x, e.y);
                var l = Raster.add_layer (doc, page, e.name != "" ? e.name : null, item);
                l.opacity = e.opacity;
                l.visible = e.visible;
                l.locked = e.locked;
                l.blend = e.blend;
            }
            if (page.layers.size == 0) Raster.add_layer (doc, page);
            doc.modified = false;
            return doc;
        }
    }
}
