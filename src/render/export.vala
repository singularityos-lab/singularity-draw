namespace Singularity.Apps.Draw {

    public class Export {
        public static Cairo.ImageSurface render_area (Page page, Rect area, double scale, bool transparent, Gee.List<Item>? only = null) {
            int w = int.max (1, (int) Math.ceil (area.w * scale));
            int h = int.max (1, (int) Math.ceil (area.h * scale));
            var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, w, h);
            var cr = new Cairo.Context (surf);
            if (!transparent) {
                Rgba bg;
                if (!Colors.parse (page.background, out bg)) bg = Rgba (1, 1, 1, 1);
                bg.apply (cr);
                cr.paint ();
            }
            cr.scale (scale, scale);
            cr.translate (-area.x, -area.y);
            var opts = new RenderOptions ();
            opts.background = false;
            opts.print = true;
            if (only != null) Renderer.draw_items (cr, only, opts);
            else Renderer.draw_page (cr, page, opts);
            surf.flush ();
            return surf;
        }

        public static uint8[] png_bytes (Cairo.ImageSurface surf) {
            var buf = new ByteArray ();
            surf.write_to_png_stream ((data) => {
                buf.append (data);
                return Cairo.Status.SUCCESS;
            });
            return buf.steal ();
        }

        public static void png (Page page, string path, Rect area, double scale, bool transparent, Gee.List<Item>? only = null) throws Error {
            var surf = render_area (page, area, scale, transparent, only);
            var status = surf.write_to_png (path);
            if (status != Cairo.Status.SUCCESS) throw new IOError.FAILED (_("The image could not be written."));
        }

        public static string? page_target (Document doc, Gee.List<Page> pages, string link) {
            if (!link.has_prefix ("page:")) return null;
            string name = link.substring (5);
            for (int i = 0; i < pages.size; i++) if (pages[i].name == name || pages[i].id == name) return "%d".printf (i + 1);
            return null;
        }

        private static void add_links (Cairo.Context cr, Document doc, Gee.List<Page> pages, Page p) {
            foreach (var it in p.all_items ()) {
                if (it.link == "" || !p.item_visible (p.top_level (it))) continue;
                var b = it.bounds ();
                string rect = "rect=[%s %s %s %s]".printf (PathData.fmt (b.x, 2), PathData.fmt (b.y, 2), PathData.fmt (b.w, 2), PathData.fmt (b.h, 2));
                string? pg = page_target (doc, pages, it.link);
                string attrs;
                if (pg != null) attrs = "page=%s %s".printf (pg, rect);
                else attrs = "uri='%s' %s".printf (it.link.replace ("'", "%27"), rect);
                cr.tag_begin (Cairo.TAG_LINK, attrs);
                cr.tag_end (Cairo.TAG_LINK);
            }
        }

        public static void pdf (Document doc, string path, bool all_pages, bool fit_content = false) throws Error {
            doc.link_backgrounds ();
            var pages = all_pages ? doc.foreground_pages () : new Gee.ArrayList<Page>.wrap ({ doc.page });
            if (pages.size == 0) pages = doc.pages;
            Cairo.PdfSurface? surf = null;
            Cairo.Context? cr = null;
            foreach (var p in pages) {
                Rect area = fit_content ? SvgWriter.content_area (p, null, 20) : Rect (0, 0, p.width, p.height);
                double pw = area.w * 72.0 / Units.PX_PER_IN, ph = area.h * 72.0 / Units.PX_PER_IN;
                if (surf == null) {
                    surf = new Cairo.PdfSurface (path, pw, ph);
                    surf.set_metadata (Cairo.PdfMetadata.CREATOR, "Draw");
                    if (doc.title != "") surf.set_metadata (Cairo.PdfMetadata.TITLE, doc.title);
                    cr = new Cairo.Context (surf);
                } else {
                    surf.set_size (pw, ph);
                }
                cr.save ();
                cr.scale (72.0 / Units.PX_PER_IN, 72.0 / Units.PX_PER_IN);
                cr.translate (-area.x, -area.y);
                if (!Colors.is_none (p.background)) {
                    Rgba bg;
                    Colors.parse (p.background, out bg);
                    bg.apply (cr);
                    cr.rectangle (area.x, area.y, area.w, area.h);
                    cr.fill ();
                }
                var opts = new RenderOptions ();
                opts.background = false;
                opts.print = true;
                Renderer.draw_page (cr, p, opts);
                add_links (cr, doc, pages, p);
                cr.restore ();
                cr.show_page ();
            }
            if (surf != null) {
                surf.finish ();
                if (surf.status () != Cairo.Status.SUCCESS) throw new IOError.FAILED (_("The PDF could not be written."));
            }
        }
    }
}
