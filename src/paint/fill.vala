namespace Singularity.Apps.Draw {

    public class FloodFill {
        public static bool matches (uint32 a, uint32 b, int tolerance) {
            for (int s = 0; s < 32; s += 8) {
                int ca = (int) ((a >> s) & 0xff), cb = (int) ((b >> s) & 0xff);
                if ((ca - cb).abs () > tolerance) return false;
            }
            return true;
        }

        public static uint8[] region (Cairo.ImageSurface source, int sx, int sy, int tolerance, uint8[]? selection = null) {
            source.flush ();
            int w = source.get_width (), h = source.get_height ();
            var out_mask = new uint8[w * h];
            if (sx < 0 || sy < 0 || sx >= w || sy >= h) return out_mask;
            if (selection != null && selection[sy * w + sx] == 0) return out_mask;
            uint32 seed = Pixels.get (source, sx, sy);
            var stack = new Gee.ArrayList<int> ();
            stack.add (sy * w + sx);
            while (stack.size > 0) {
                int idx = stack.remove_at (stack.size - 1);
                int y = idx / w;
                int x = idx % w;
                if (out_mask[idx] != 0) continue;
                int l = x;
                while (l > 0 && fillable (source, l - 1, y, w, seed, tolerance, out_mask, selection)) l--;
                int r = x;
                while (r < w - 1 && fillable (source, r + 1, y, w, seed, tolerance, out_mask, selection)) r++;
                for (int i = l; i <= r; i++) out_mask[y * w + i] = 255;
                for (int dir = -1; dir <= 1; dir += 2) {
                    int ny = y + dir;
                    if (ny < 0 || ny >= h) continue;
                    bool open = false;
                    for (int i = l; i <= r; i++) {
                        bool f = fillable (source, i, ny, w, seed, tolerance, out_mask, selection);
                        if (f && !open) {
                            stack.add (ny * w + i);
                            open = true;
                        } else if (!f) {
                            open = false;
                        }
                    }
                }
            }
            return out_mask;
        }

        private static bool fillable (Cairo.ImageSurface s, int x, int y, int w, uint32 seed, int tol, uint8[] done, uint8[]? sel) {
            int i = y * w + x;
            if (done[i] != 0) return false;
            if (sel != null && sel[i] == 0) return false;
            return matches (Pixels.get (s, x, y), seed, tol);
        }

        public static int apply (Cairo.ImageSurface target, uint8[] region, Rgba color) {
            target.flush ();
            int w = target.get_width (), h = target.get_height ();
            uint32 c = Pixels.pack (color);
            double ca = color.a.clamp (0, 1);
            int count = 0;
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    if (region[y * w + x] == 0) continue;
                    count++;
                    if (ca >= 0.999) {
                        Pixels.set (target, x, y, c);
                        continue;
                    }
                    uint32 d = Pixels.get (target, x, y);
                    uint32 o = 0;
                    for (int s = 0; s < 32; s += 8) {
                        double sv = (c >> s) & 0xff, dv = (d >> s) & 0xff;
                        uint v = (uint) Math.round (sv + dv * (1 - ca)).clamp (0, 255);
                        o |= v << s;
                    }
                    Pixels.set (target, x, y, o);
                }
            }
            target.mark_dirty ();
            return count;
        }

        public static int fill (Cairo.ImageSurface source, Cairo.ImageSurface target, int x, int y, Rgba color, int tolerance, uint8[]? selection = null) {
            var r = region (source, x, y, tolerance, selection);
            return apply (target, r, color);
        }
    }

    public class ColorSampler {
        public static Rgba sample (Page page, double x, double y) {
            var surf = Export.render_area (page, Rect (Math.floor (x), Math.floor (y), 1, 1), 1, false);
            return Pixels.unpack (Pixels.get (surf, 0, 0));
        }

        public static Rgba sample_surface (Cairo.ImageSurface s, int x, int y) {
            s.flush ();
            return Pixels.unpack (Pixels.get (s, x, y));
        }
    }
}
