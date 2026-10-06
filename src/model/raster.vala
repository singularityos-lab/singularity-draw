namespace Singularity.Apps.Draw {

    public enum BlendMode {
        NORMAL,
        MULTIPLY,
        SCREEN,
        OVERLAY,
        DARKEN,
        LIGHTEN,
        COLOR_DODGE,
        COLOR_BURN,
        HARD_LIGHT,
        SOFT_LIGHT,
        DIFFERENCE;

        public static BlendMode[] all () {
            return { NORMAL, MULTIPLY, SCREEN, OVERLAY, DARKEN, LIGHTEN, COLOR_DODGE, COLOR_BURN, HARD_LIGHT, SOFT_LIGHT, DIFFERENCE };
        }

        public Cairo.Operator to_operator () {
            switch (this) {
                case MULTIPLY: return Cairo.Operator.MULTIPLY;
                case SCREEN: return Cairo.Operator.SCREEN;
                case OVERLAY: return Cairo.Operator.OVERLAY;
                case DARKEN: return Cairo.Operator.DARKEN;
                case LIGHTEN: return Cairo.Operator.LIGHTEN;
                case COLOR_DODGE: return Cairo.Operator.COLOR_DODGE;
                case COLOR_BURN: return Cairo.Operator.COLOR_BURN;
                case HARD_LIGHT: return Cairo.Operator.HARD_LIGHT;
                case SOFT_LIGHT: return Cairo.Operator.SOFT_LIGHT;
                case DIFFERENCE: return Cairo.Operator.DIFFERENCE;
                default: return Cairo.Operator.OVER;
            }
        }

        public string to_id () {
            switch (this) {
                case MULTIPLY: return "multiply";
                case SCREEN: return "screen";
                case OVERLAY: return "overlay";
                case DARKEN: return "darken";
                case LIGHTEN: return "lighten";
                case COLOR_DODGE: return "color-dodge";
                case COLOR_BURN: return "color-burn";
                case HARD_LIGHT: return "hard-light";
                case SOFT_LIGHT: return "soft-light";
                case DIFFERENCE: return "difference";
                default: return "normal";
            }
        }

        public static BlendMode from_id (string? id) {
            if (id == null) return NORMAL;
            string s = id.strip ().down ();
            if (s.has_prefix ("svg:")) s = s.substring (4);
            if (s == "src-over") return NORMAL;
            foreach (var m in all ()) if (m.to_id () == s) return m;
            return NORMAL;
        }

        public string to_ora () {
            return this == NORMAL ? "svg:src-over" : "svg:" + to_id ();
        }

        public string label () {
            switch (this) {
                case MULTIPLY: return _("Multiply");
                case SCREEN: return _("Screen");
                case OVERLAY: return _("Overlay");
                case DARKEN: return _("Darken");
                case LIGHTEN: return _("Lighten");
                case COLOR_DODGE: return _("Color Dodge");
                case COLOR_BURN: return _("Color Burn");
                case HARD_LIGHT: return _("Hard Light");
                case SOFT_LIGHT: return _("Soft Light");
                case DIFFERENCE: return _("Difference");
                default: return _("Normal");
            }
        }
    }

    public class Pixels {
        public static Cairo.ImageSurface blank (int w, int h) {
            return new Cairo.ImageSurface (Cairo.Format.ARGB32, int.max (1, w), int.max (1, h));
        }

        public static Cairo.ImageSurface copy (Cairo.ImageSurface src) {
            var dst = blank (src.get_width (), src.get_height ());
            var cr = new Cairo.Context (dst);
            cr.set_operator (Cairo.Operator.SOURCE);
            cr.set_source_surface (src, 0, 0);
            cr.paint ();
            dst.flush ();
            return dst;
        }

        public static Cairo.ImageSurface? decode (uint8[] data) {
            if (data.length == 0) return null;
            try {
                var loader = new Gdk.PixbufLoader ();
                loader.write (data);
                loader.close ();
                var pix = loader.get_pixbuf ();
                if (pix == null) return null;
                var rot = pix.apply_embedded_orientation ();
                return from_pixbuf (rot ?? pix);
            } catch (Error e) {
                return null;
            }
        }

        public static Cairo.ImageSurface from_pixbuf (Gdk.Pixbuf pix) {
            int w = pix.width, h = pix.height;
            var surf = blank (w, h);
            surf.flush ();
            unowned uint8[] dst = surf.get_data ();
            int ds = surf.get_stride ();
            unowned uint8[] src = pix.get_pixels ();
            int ss = pix.rowstride;
            int nc = pix.n_channels;
            bool alpha = pix.has_alpha;
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    int si = y * ss + x * nc;
                    uint a = alpha ? src[si + 3] : 255;
                    uint r = src[si] * a / 255, g = src[si + 1] * a / 255, b = src[si + 2] * a / 255;
                    uint32 v = (a << 24) | (r << 16) | (g << 8) | b;
                    *((uint32*) ((uint8*) dst + y * ds + x * 4)) = v;
                }
            }
            surf.mark_dirty ();
            return surf;
        }

        public static Gdk.Pixbuf to_pixbuf (Cairo.ImageSurface surf, bool keep_alpha) {
            surf.flush ();
            int w = surf.get_width (), h = surf.get_height ();
            var pix = new Gdk.Pixbuf (Gdk.Colorspace.RGB, keep_alpha, 8, w, h);
            unowned uint8[] dst = pix.get_pixels ();
            int ds = pix.rowstride;
            int nc = pix.n_channels;
            unowned uint8[] src = surf.get_data ();
            int ss = surf.get_stride ();
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    uint32 v = *((uint32*) ((uint8*) src + y * ss + x * 4));
                    uint a = (v >> 24) & 0xff, r = (v >> 16) & 0xff, g = (v >> 8) & 0xff, b = v & 0xff;
                    if (a > 0 && a < 255) {
                        r = uint.min (255, (r * 255 + a / 2) / a);
                        g = uint.min (255, (g * 255 + a / 2) / a);
                        b = uint.min (255, (b * 255 + a / 2) / a);
                    }
                    if (!keep_alpha) {
                        r = (r * a + 255 * (255 - a)) / 255;
                        g = (g * a + 255 * (255 - a)) / 255;
                        b = (b * a + 255 * (255 - a)) / 255;
                        if (a == 0) r = g = b = 255;
                    }
                    int di = y * ds + x * nc;
                    dst[di] = (uint8) r;
                    dst[di + 1] = (uint8) g;
                    dst[di + 2] = (uint8) b;
                    if (keep_alpha) dst[di + 3] = (uint8) a;
                }
            }
            return pix;
        }

        public static uint8[] png (Cairo.ImageSurface surf) {
            surf.flush ();
            return Export.png_bytes (surf);
        }

        public static uint8[] jpeg (Cairo.ImageSurface surf, int quality) throws Error {
            var pix = to_pixbuf (surf, false);
            uint8[] buf;
            pix.save_to_buffer (out buf, "jpeg", "quality", quality.clamp (1, 100).to_string ());
            return buf;
        }

        public static uint32 get (Cairo.ImageSurface surf, int x, int y) {
            if (x < 0 || y < 0 || x >= surf.get_width () || y >= surf.get_height ()) return 0;
            unowned uint8[] d = surf.get_data ();
            return *((uint32*) ((uint8*) d + y * surf.get_stride () + x * 4));
        }

        public static void set (Cairo.ImageSurface surf, int x, int y, uint32 v) {
            if (x < 0 || y < 0 || x >= surf.get_width () || y >= surf.get_height ()) return;
            unowned uint8[] d = surf.get_data ();
            *((uint32*) ((uint8*) d + y * surf.get_stride () + x * 4)) = v;
        }

        public static uint32 pack (Rgba c) {
            double a = c.a.clamp (0, 1);
            uint ai = (uint) Math.round (a * 255);
            uint r = (uint) Math.round (c.r.clamp (0, 1) * a * 255);
            uint g = (uint) Math.round (c.g.clamp (0, 1) * a * 255);
            uint b = (uint) Math.round (c.b.clamp (0, 1) * a * 255);
            return (ai << 24) | (r << 16) | (g << 8) | b;
        }

        public static Rgba unpack (uint32 v) {
            double a = ((v >> 24) & 0xff) / 255.0;
            if (a <= 0) return Rgba (0, 0, 0, 0);
            return Rgba (((v >> 16) & 0xff) / 255.0 / a, ((v >> 8) & 0xff) / 255.0 / a, (v & 0xff) / 255.0 / a, a);
        }
    }

    public class RasterItem : ImageShape {
        public Cairo.ImageSurface? surface = null;
        public bool dirty = false;

        public RasterItem () {
            base ();
            kind = "raster";
        }

        public RasterItem.blank (int pw, int ph, double x = 0, double y = 0) {
            base ();
            kind = "raster";
            surface = Pixels.blank (pw, ph);
            this.x = x;
            this.y = y;
            w = int.max (1, pw);
            h = int.max (1, ph);
            sync ();
        }

        public RasterItem.from_surface (Cairo.ImageSurface s, double x = 0, double y = 0) {
            base ();
            kind = "raster";
            surface = s;
            this.x = x;
            this.y = y;
            w = s.get_width ();
            h = s.get_height ();
            sync ();
        }

        public override Item clone () {
            var r = new RasterItem ();
            copy_shape (r);
            r.bytes = bytes;
            r.mime = mime;
            r.surface = dirty || bytes.length == 0 ? surface : null;
            r.dirty = dirty;
            r.pixel_width = pixel_width;
            r.pixel_height = pixel_height;
            return r;
        }

        public override bool hit (double px, double py, double tolerance) {
            return false;
        }

        public Cairo.ImageSurface pixels () {
            if (surface == null) {
                surface = Pixels.decode (bytes);
                if (surface == null) surface = Pixels.blank ((int) Math.ceil (w), (int) Math.ceil (h));
                pixel_width = surface.get_width ();
                pixel_height = surface.get_height ();
            }
            return surface;
        }

        public int pixel_w {
            get { return pixels ().get_width (); }
        }

        public int pixel_h {
            get { return pixels ().get_height (); }
        }

        public void detach () {
            surface = Pixels.copy (pixels ());
            dirty = true;
        }

        public void sync () {
            var s = pixels ();
            bytes = Pixels.png (s);
            mime = "image/png";
            cache = null;
            dirty = false;
            pixel_width = s.get_width ();
            pixel_height = s.get_height ();
        }

        public Point to_pixel (double px, double py) {
            var l = to_local (px, py);
            double sx = w > 1e-6 ? pixel_w / w : 1, sy = h > 1e-6 ? pixel_h / h : 1;
            return Point (l.x * sx, l.y * sy);
        }

        public Point from_pixel (double qx, double qy) {
            double sx = pixel_w > 0 ? w / pixel_w : 1, sy = pixel_h > 0 ? h / pixel_h : 1;
            return to_page (qx * sx, qy * sy);
        }

        public double pixel_scale () {
            return w > 1e-6 ? pixel_w / w : 1;
        }
    }

    public class Raster {
        public static RasterItem? item_for (Page page, string layer_id) {
            foreach (var it in page.items) {
                var r = it as RasterItem;
                if (r != null && r.layer_id == layer_id) return r;
            }
            return null;
        }

        public static bool has_raster (Page page) {
            foreach (var l in page.layers) if (l.raster) return true;
            return false;
        }

        public static bool is_painting (Document doc) {
            foreach (var p in doc.pages) {
                if (!has_raster (p)) return false;
                foreach (var it in p.items) if (!(it is RasterItem)) return false;
            }
            return true;
        }

        public static string new_layer_id (Page page) {
            int n = 1;
            while (page.find_layer ("paint%d".printf (n)) != null) n++;
            return "paint%d".printf (n);
        }

        public static string next_layer_name (Page page) {
            int n = 1;
            foreach (var l in page.layers) if (l.raster) n++;
            return _("Paint Layer %d").printf (n);
        }

        public static Layer add_layer (Document doc, Page page, string? name = null, RasterItem? content = null, int index = -1) {
            var l = new Layer (new_layer_id (page), name ?? next_layer_name (page));
            l.raster = true;
            if (index < 0 || index > page.layers.size) index = page.layers.size;
            page.layers.insert (index, l);
            var r = content ?? new RasterItem.blank ((int) Math.ceil (page.width), (int) Math.ceil (page.height));
            r.id = doc.new_id ("r");
            r.layer_id = l.id;
            page.items.add (r);
            sort_items (page);
            page.active_layer = l.id;
            return l;
        }

        public static void remove_layer (Page page, Layer layer) {
            for (int i = page.items.size - 1; i >= 0; i--) {
                var r = page.items[i] as RasterItem;
                if (r != null && r.layer_id == layer.id) page.items.remove_at (i);
            }
            page.layers.remove (layer);
        }

        public static void sort_items (Page page) {
            var slots = new Gee.ArrayList<int> ();
            var rasters = new Gee.ArrayList<RasterItem> ();
            for (int i = 0; i < page.items.size; i++) {
                var r = page.items[i] as RasterItem;
                if (r != null) {
                    slots.add (i);
                    rasters.add (r);
                }
            }
            var ordered = new Gee.ArrayList<RasterItem> ();
            foreach (var l in page.layers) {
                foreach (var r in rasters) if (r.layer_id == l.id && !ordered.contains (r)) ordered.add (r);
            }
            foreach (var r in rasters) if (!ordered.contains (r)) ordered.add (r);
            for (int i = 0; i < slots.size; i++) page.items[slots[i]] = ordered[i];
        }

        public static Document new_painting (int w, int h, string background = "#ffffff") {
            var doc = new Document ();
            var p = doc.page;
            p.width = int.max (1, w);
            p.height = int.max (1, h);
            p.background = background;
            p.layers.clear ();
            add_layer (doc, p);
            doc.modified = false;
            return doc;
        }

        public static Document from_image (uint8[] data) throws Error {
            var surf = Pixels.decode (data);
            if (surf == null) throw new FormatError.INVALID (_("The image could not be read."));
            var doc = new Document ();
            var p = doc.page;
            p.width = surf.get_width ();
            p.height = surf.get_height ();
            p.background = "none";
            p.layers.clear ();
            add_layer (doc, p, _("Background"), new RasterItem.from_surface (surf));
            return doc;
        }

        public static Cairo.ImageSurface render_layer (Page page, Layer layer) {
            int w = (int) Math.ceil (page.width), h = (int) Math.ceil (page.height);
            var surf = Pixels.blank (w, h);
            var cr = new Cairo.Context (surf);
            var opts = new RenderOptions ();
            opts.background = false;
            opts.print = false;
            foreach (var it in page.items) {
                if (page.layer_of (it) != layer) continue;
                var r = it as RasterItem;
                if (r != null) Renderer.draw_raster (cr, r, 1, BlendMode.NORMAL);
                else Renderer.draw_item (cr, it, opts);
            }
            surf.flush ();
            return surf;
        }
    }
}
