namespace Singularity.Apps.Draw {

    public class DrawPrintSource : Singularity.Print.PageSource {
        private class Tile {
            public Page page;
            public int col;
            public int row;
            public int cols;
            public int rows;
            public double scale;
        }

        private Document doc;
        private Gee.ArrayList<Page> pages;
        private Gee.ArrayList<Tile> tiles = new Gee.ArrayList<Tile> ();
        private Singularity.Print.PageFormat format = new Singularity.Print.PageFormat ();

        public DrawPrintSource (Document doc, string title) {
            this.doc = doc;
            this.title = title;
            doc.link_backgrounds ();
            pages = doc.foreground_pages ();
            if (pages.size == 0) pages = doc.pages;
            current_page = int.max (pages.index_of (doc.page), 0);
        }

        public int tile_count () {
            return tiles.size;
        }

        public void layout (double cw, double ch) {
            tiles.clear ();
            double pt_per_px = 72.0 / Units.PX_PER_IN;
            foreach (var p in pages) {
                int cols = 1, rows = 1;
                double sc;
                if (p.print_tiles_x > 0) {
                    cols = p.print_tiles_x;
                    rows = int.max (p.print_tiles_y, 1);
                    sc = double.min (cw * cols / p.width, ch * rows / p.height);
                } else if (p.print_zoom > 0) {
                    sc = pt_per_px * p.print_zoom;
                    cols = int.max (1, (int) Math.ceil (p.width * sc / cw - 1e-6));
                    rows = int.max (1, (int) Math.ceil (p.height * sc / ch - 1e-6));
                } else {
                    sc = double.min (cw / p.width, ch / p.height);
                }
                for (int r = 0; r < rows; r++) {
                    for (int c = 0; c < cols; c++) {
                        var t = new Tile ();
                        t.page = p;
                        t.col = c;
                        t.row = r;
                        t.cols = cols;
                        t.rows = rows;
                        t.scale = sc;
                        tiles.add (t);
                    }
                }
            }
        }

        public override async int paginate (Singularity.Print.PageFormat format) throws Error {
            this.format = format;
            page_width = format.width;
            page_height = format.height;
            layout (format.content_width, format.content_height);
            document_pages = tiles.size;
            return tiles.size;
        }

        public override void render_page (Cairo.Context cr, int index) {
            render_tile (cr, index, format.margin_left, format.margin_top, format.content_width, format.content_height);
        }

        public void render_tile (Cairo.Context cr, int index, double ox, double oy, double cw, double ch) {
            if (index < 0 || index >= tiles.size) return;
            var t = tiles[index];
            var p = t.page;
            cr.save ();
            cr.translate (ox, oy);
            cr.rectangle (0, 0, cw, ch);
            cr.clip ();
            if (t.cols == 1 && t.rows == 1) cr.translate ((cw - p.width * t.scale) / 2, (ch - p.height * t.scale) / 2);
            else cr.translate (-t.col * cw, -t.row * ch);
            cr.scale (t.scale, t.scale);
            if (!Colors.is_none (p.background)) {
                Rgba bg;
                Colors.parse (p.background, out bg);
                bg.apply (cr);
                cr.rectangle (0, 0, p.width, p.height);
                cr.fill ();
            }
            var opts = new RenderOptions ();
            opts.print = true;
            opts.background = false;
            Renderer.draw_page (cr, p, opts);
            cr.restore ();
            if (t.cols > 1 || t.rows > 1) {
                cr.save ();
                cr.translate (ox, oy);
                cr.set_source_rgba (0, 0, 0, 0.5);
                cr.set_line_width (0.5);
                double m = 12;
                foreach (double x in new double[] { 0, cw }) {
                    foreach (double y in new double[] { 0, ch }) {
                        cr.move_to (x, y + (y == 0 ? m : -m));
                        cr.line_to (x, y);
                        cr.line_to (x + (x == 0 ? m : -m), y);
                    }
                }
                cr.stroke ();
                var layout = Pango.cairo_create_layout (cr);
                layout.set_font_description (Pango.FontDescription.from_string ("Sans 6"));
                layout.set_text (_("%s, sheet %d of %d").printf (p.name, t.row * t.cols + t.col + 1, t.cols * t.rows), -1);
                cr.move_to (2, ch + 2);
                Pango.cairo_show_layout (cr, layout);
                cr.restore ();
            }
        }
    }
}
