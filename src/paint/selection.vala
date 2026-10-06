namespace Singularity.Apps.Draw {

    public enum SelectOp {
        REPLACE,
        ADD,
        SUBTRACT
    }

    public class RasterSelection {
        public int w;
        public int h;
        public Cairo.ImageSurface mask;
        public Gee.ArrayList<PathData> outlines = new Gee.ArrayList<PathData> ();

        public RasterSelection (int w, int h) {
            this.w = int.max (1, w);
            this.h = int.max (1, h);
            mask = new Cairo.ImageSurface (Cairo.Format.A8, this.w, this.h);
        }

        public RasterSelection copy () {
            var s = new RasterSelection (w, h);
            var cr = new Cairo.Context (s.mask);
            cr.set_operator (Cairo.Operator.SOURCE);
            cr.set_source_surface (mask, 0, 0);
            cr.paint ();
            s.mask.flush ();
            foreach (var p in outlines) s.outlines.add (p.copy ());
            return s;
        }

        public static PathData rect_path (double x0, double y0, double x1, double y1) {
            var r = Rect.from_points (x0, y0, x1, y1);
            return new PathData.rect (r.x, r.y, r.w, r.h);
        }

        public static PathData ellipse_path (double x0, double y0, double x1, double y1) {
            var r = Rect.from_points (x0, y0, x1, y1);
            return new PathData.ellipse (r.cx (), r.cy (), r.w / 2, r.h / 2);
        }

        public static PathData lasso_path (Gee.List<Point?> pts) {
            var p = new PathData ();
            Point[] arr = {};
            foreach (var q in pts) arr += q;
            if (arr.length >= 3) p.add_polygon (arr, true);
            return p;
        }

        public void combine (PathData path, SelectOp op) {
            var cr = new Cairo.Context (mask);
            if (op == SelectOp.REPLACE) {
                cr.set_operator (Cairo.Operator.CLEAR);
                cr.paint ();
                outlines.clear ();
            }
            cr.set_operator (op == SelectOp.SUBTRACT ? Cairo.Operator.DEST_OUT : Cairo.Operator.OVER);
            cr.set_fill_rule (Cairo.FillRule.WINDING);
            cr.new_path ();
            path.to_cairo (cr);
            cr.set_source_rgba (0, 0, 0, 1);
            cr.fill ();
            mask.flush ();
            outlines.add (path.copy ());
        }

        public void select_all () {
            combine (new PathData.rect (0, 0, w, h), SelectOp.REPLACE);
        }

        public void invert () {
            var inv = new Cairo.ImageSurface (Cairo.Format.A8, w, h);
            var cr = new Cairo.Context (inv);
            cr.set_source_rgba (0, 0, 0, 1);
            cr.paint ();
            cr.set_operator (Cairo.Operator.DEST_OUT);
            cr.set_source_surface (mask, 0, 0);
            cr.paint ();
            inv.flush ();
            mask = inv;
            outlines.add (new PathData.rect (0, 0, w, h));
        }

        public uint8 at (int x, int y) {
            if (x < 0 || y < 0 || x >= w || y >= h) return 0;
            unowned uint8[] d = mask.get_data ();
            return d[y * mask.get_stride () + x];
        }

        public uint8[] bytes () {
            mask.flush ();
            var b = new uint8[w * h];
            unowned uint8[] d = mask.get_data ();
            int st = mask.get_stride ();
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) b[y * w + x] = d[y * st + x];
            }
            return b;
        }

        public bool bounds (out int bx, out int by, out int bw, out int bh) {
            mask.flush ();
            unowned uint8[] d = mask.get_data ();
            int st = mask.get_stride ();
            int x0 = w, y0 = h, x1 = -1, y1 = -1;
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    if (d[y * st + x] == 0) continue;
                    if (x < x0) x0 = x;
                    if (x > x1) x1 = x;
                    if (y < y0) y0 = y;
                    if (y > y1) y1 = y;
                }
            }
            bx = x0;
            by = y0;
            bw = x1 - x0 + 1;
            bh = y1 - y0 + 1;
            return x1 >= x0 && y1 >= y0;
        }

        public bool is_empty () {
            int a, b, c, d;
            return !bounds (out a, out b, out c, out d);
        }

        public Cairo.ImageSurface? extract (Cairo.ImageSurface layer, out int bx, out int by) {
            int bw, bh;
            if (!bounds (out bx, out by, out bw, out bh)) return null;
            var out_surf = Pixels.blank (bw, bh);
            var cr = new Cairo.Context (out_surf);
            cr.translate (-bx, -by);
            cr.set_source_surface (layer, 0, 0);
            cr.mask_surface (mask, 0, 0);
            out_surf.flush ();
            return out_surf;
        }

        public void clear_pixels (Cairo.ImageSurface layer) {
            var cr = new Cairo.Context (layer);
            cr.set_operator (Cairo.Operator.DEST_OUT);
            cr.set_source_rgba (0, 0, 0, 1);
            cr.mask_surface (mask, 0, 0);
            layer.flush ();
        }
    }

    public class FloatingSelection {
        public Cairo.ImageSurface pixels;
        public Cairo.ImageSurface region;
        public int ox;
        public int oy;
        public int bw;
        public int bh;
        public double tx = 0;
        public double ty = 0;
        public double sx = 1;
        public double sy = 1;
        public double angle = 0;
        public Gee.ArrayList<PathData> outlines = new Gee.ArrayList<PathData> ();

        public static FloatingSelection? lift (Cairo.ImageSurface layer, RasterSelection sel) {
            int bx, by, bw, bh;
            if (!sel.bounds (out bx, out by, out bw, out bh)) return null;
            var f = new FloatingSelection ();
            f.ox = bx;
            f.oy = by;
            f.bw = bw;
            f.bh = bh;
            f.pixels = Pixels.blank (bw, bh);
            var cr = new Cairo.Context (f.pixels);
            cr.translate (-bx, -by);
            cr.set_source_surface (layer, 0, 0);
            cr.mask_surface (sel.mask, 0, 0);
            f.pixels.flush ();
            f.region = new Cairo.ImageSurface (Cairo.Format.A8, bw, bh);
            var rc = new Cairo.Context (f.region);
            rc.set_source_surface (sel.mask, -bx, -by);
            rc.paint ();
            f.region.flush ();
            foreach (var p in sel.outlines) {
                var q = p.copy ();
                q.translate (-bx, -by);
                f.outlines.add (q);
            }
            sel.clear_pixels (layer);
            return f;
        }

        public static FloatingSelection from_pixels (Cairo.ImageSurface src, int ox, int oy) {
            var f = new FloatingSelection ();
            f.ox = ox;
            f.oy = oy;
            f.bw = src.get_width ();
            f.bh = src.get_height ();
            f.pixels = Pixels.copy (src);
            f.region = new Cairo.ImageSurface (Cairo.Format.A8, f.bw, f.bh);
            var rc = new Cairo.Context (f.region);
            rc.set_source_rgba (0, 0, 0, 1);
            rc.paint ();
            f.region.flush ();
            f.outlines.add (new PathData.rect (0, 0, f.bw, f.bh));
            return f;
        }

        public Cairo.ImageSurface rendered (out int x, out int y) {
            var c = corners ();
            double x0 = c[0].x, y0 = c[0].y, x1 = c[0].x, y1 = c[0].y;
            foreach (var p in c) {
                x0 = double.min (x0, p.x);
                y0 = double.min (y0, p.y);
                x1 = double.max (x1, p.x);
                y1 = double.max (y1, p.y);
            }
            x = (int) Math.floor (x0);
            y = (int) Math.floor (y0);
            var s = Pixels.blank ((int) Math.ceil (x1) - x, (int) Math.ceil (y1) - y);
            var cr = new Cairo.Context (s);
            cr.translate (-x, -y);
            paint (cr);
            s.flush ();
            return s;
        }

        public Cairo.Matrix matrix () {
            var m = Cairo.Matrix.identity ();
            m.translate (ox + bw / 2.0 + tx, oy + bh / 2.0 + ty);
            if (angle != 0) m.rotate (angle);
            m.scale (sx, sy);
            m.translate (-bw / 2.0, -bh / 2.0);
            return m;
        }

        public Point map (double lx, double ly) {
            var m = matrix ();
            m.transform_point (ref lx, ref ly);
            return Point (lx, ly);
        }

        public Point[] corners () {
            return { map (0, 0), map (bw, 0), map (bw, bh), map (0, bh) };
        }

        public Point center () {
            return map (bw / 2.0, bh / 2.0);
        }

        public bool contains (double px, double py) {
            var m = matrix ();
            if (m.invert () != Cairo.Status.SUCCESS) return false;
            m.transform_point (ref px, ref py);
            return px >= 0 && py >= 0 && px <= bw && py <= bh;
        }

        public void paint (Cairo.Context cr, double opacity = 1) {
            cr.save ();
            cr.transform (matrix ());
            cr.set_source_surface (pixels, 0, 0);
            cr.get_source ().set_filter (Cairo.Filter.BILINEAR);
            cr.paint_with_alpha (opacity);
            cr.restore ();
        }

        public void stamp (Cairo.ImageSurface layer) {
            var cr = new Cairo.Context (layer);
            paint (cr);
            layer.flush ();
        }

        public RasterSelection selection (int w, int h) {
            var s = new RasterSelection (w, h);
            var cr = new Cairo.Context (s.mask);
            cr.transform (matrix ());
            cr.set_source_surface (region, 0, 0);
            cr.get_source ().set_filter (Cairo.Filter.BILINEAR);
            cr.paint ();
            s.mask.flush ();
            var m = matrix ();
            foreach (var p in outlines) s.outlines.add (p.transformed (m));
            return s;
        }
    }
}
