namespace Singularity.Apps.Draw {

    public enum BrushKind {
        PENCIL,
        BRUSH,
        AIRBRUSH,
        MARKER,
        ERASER;

        public string label () {
            switch (this) {
                case PENCIL: return _("Pencil");
                case AIRBRUSH: return _("Airbrush");
                case MARKER: return _("Marker");
                case ERASER: return _("Eraser");
                default: return _("Brush");
            }
        }
    }

    public enum DabMode {
        MAX,
        ACCUMULATE
    }

    public struct Dab {
        public double x;
        public double y;
        public double radius;
        public double alpha;

        public Dab (double x, double y, double radius, double alpha) {
            this.x = x;
            this.y = y;
            this.radius = radius;
            this.alpha = alpha;
        }
    }

    public class BrushSettings {
        public BrushKind kind = BrushKind.BRUSH;
        public double size = 12;
        public double opacity = 1;
        public double hardness = 0.6;
        public double spacing = 0.12;
        public double flow = 1;
        public double smoothing = 0.4;
        public bool pressure_size = true;
        public bool pressure_opacity = true;
        public double min_size = 0.15;
        public double min_opacity = 0.1;
        public double gamma = 1;

        public BrushSettings (BrushKind kind = BrushKind.BRUSH) {
            this.kind = kind;
            switch (kind) {
                case BrushKind.PENCIL:
                    size = 3;
                    hardness = 1;
                    spacing = 0.25;
                    pressure_size = false;
                    pressure_opacity = true;
                    min_opacity = 0.25;
                    smoothing = 0.2;
                    break;
                case BrushKind.AIRBRUSH:
                    size = 48;
                    hardness = 0;
                    spacing = 0.1;
                    flow = 0.08;
                    pressure_size = false;
                    pressure_opacity = true;
                    smoothing = 0.3;
                    break;
                case BrushKind.MARKER:
                    size = 18;
                    hardness = 0.9;
                    spacing = 0.08;
                    opacity = 0.55;
                    pressure_size = false;
                    pressure_opacity = false;
                    smoothing = 0.5;
                    break;
                case BrushKind.ERASER:
                    size = 24;
                    hardness = 0.8;
                    spacing = 0.1;
                    pressure_size = true;
                    pressure_opacity = false;
                    smoothing = 0.3;
                    break;
                default:
                    break;
            }
        }

        public BrushSettings copy () {
            var b = new BrushSettings (kind);
            b.size = size;
            b.opacity = opacity;
            b.hardness = hardness;
            b.spacing = spacing;
            b.flow = flow;
            b.smoothing = smoothing;
            b.pressure_size = pressure_size;
            b.pressure_opacity = pressure_opacity;
            b.min_size = min_size;
            b.min_opacity = min_opacity;
            b.gamma = gamma;
            return b;
        }

        public DabMode dab_mode () {
            return kind == BrushKind.AIRBRUSH ? DabMode.ACCUMULATE : DabMode.MAX;
        }

        public Cairo.Operator composite () {
            switch (kind) {
                case BrushKind.ERASER: return Cairo.Operator.DEST_OUT;
                case BrushKind.MARKER: return Cairo.Operator.MULTIPLY;
                default: return Cairo.Operator.OVER;
            }
        }

        public double size_at (double pressure) {
            double p = pressure.clamp (0, 1);
            if (!pressure_size) return size;
            double f = min_size + (1 - min_size) * Math.pow (p, gamma);
            return double.max (size * f, 0.5);
        }

        public double alpha_at (double pressure) {
            double p = pressure.clamp (0, 1);
            double base_alpha = kind == BrushKind.AIRBRUSH ? flow : 1;
            if (!pressure_opacity) return base_alpha;
            return base_alpha * (min_opacity + (1 - min_opacity) * Math.pow (p, gamma));
        }

        public double step_at (double pressure) {
            return double.max (0.5, spacing * size_at (pressure));
        }
    }

    public class Stabilizer {
        public double strength;
        private bool started = false;
        private double sx;
        private double sy;
        private double sp;
        private double rx;
        private double ry;
        private double rp;

        public Stabilizer (double strength) {
            this.strength = strength.clamp (0, 0.95);
        }

        private double factor () {
            return 1 - strength * 0.92;
        }

        public void push (double x, double y, double p, out double ox, out double oy, out double op) {
            rx = x;
            ry = y;
            rp = p;
            if (!started) {
                started = true;
                sx = x;
                sy = y;
                sp = p;
            } else {
                double k = factor ();
                sx += (x - sx) * k;
                sy += (y - sy) * k;
                sp += (p - sp) * k;
            }
            ox = sx;
            oy = sy;
            op = sp;
        }

        public Gee.ArrayList<Point?> finish () {
            var list = new Gee.ArrayList<Point?> ();
            if (!started) return list;
            double k = factor ();
            for (int i = 0; i < 64 && Math.hypot (rx - sx, ry - sy) > 0.5; i++) {
                sx += (rx - sx) * k;
                sy += (ry - sy) * k;
                list.add (Point (sx, sy));
            }
            if (Math.hypot (rx - sx, ry - sy) > 1e-6) {
                sx = rx;
                sy = ry;
                list.add (Point (sx, sy));
            }
            return list;
        }

        public double pressure {
            get { return sp; }
        }
    }

    public class StrokeEngine {
        public BrushSettings brush;
        public Rgba color;
        public bool record = false;
        public Gee.ArrayList<Dab?> dabs = new Gee.ArrayList<Dab?> ();
        public int dab_count = 0;
        private Cairo.ImageSurface target;
        private Cairo.ImageSurface base_pixels;
        private Cairo.ImageSurface mask;
        private float[] alpha;
        private uint8[]? selection;
        private int w;
        private int h;
        private bool started = false;
        private double lx;
        private double ly;
        private double lp;
        private double residual = 0;
        private int dx0;
        private int dy0;
        private int dx1;
        private int dy1;
        private int bx0;
        private int by0;
        private int bx1;
        private int by1;

        public StrokeEngine (Cairo.ImageSurface target, BrushSettings brush, Rgba color, uint8[]? selection = null) {
            this.target = target;
            this.brush = brush;
            this.color = color;
            this.selection = selection;
            w = target.get_width ();
            h = target.get_height ();
            target.flush ();
            base_pixels = Pixels.copy (target);
            mask = new Cairo.ImageSurface (Cairo.Format.A8, w, h);
            alpha = new float[w * h];
            reset_dirty ();
            bx0 = w;
            by0 = h;
            bx1 = -1;
            by1 = -1;
        }

        private void reset_dirty () {
            dx0 = w;
            dy0 = h;
            dx1 = -1;
            dy1 = -1;
        }

        public float mask_at (int x, int y) {
            if (x < 0 || y < 0 || x >= w || y >= h) return 0;
            return alpha[y * w + x];
        }

        public static double coverage (double d, double radius, double hardness, bool aliased) {
            if (aliased) return d <= double.max (radius, 0.5) ? 1 : 0;
            if (d >= radius + 0.5) return 0;
            double hard = hardness.clamp (0, 1);
            double inner = radius * hard;
            if (hard >= 0.999 || radius - inner < 0.75) return (radius + 0.5 - d).clamp (0, 1);
            if (d <= inner) return 1;
            double t = ((d - inner) / (radius - inner)).clamp (0, 1);
            return 1 - t * t * (3 - 2 * t);
        }

        public void stamp (double cx, double cy, double radius, double a) {
            dab_count++;
            if (record) dabs.add (Dab (cx, cy, radius, a));
            bool aliased = brush.kind == BrushKind.PENCIL;
            var mode = brush.dab_mode ();
            int x0 = int.max (0, (int) Math.floor (cx - radius - 1));
            int y0 = int.max (0, (int) Math.floor (cy - radius - 1));
            int x1 = int.min (w - 1, (int) Math.ceil (cx + radius + 1));
            int y1 = int.min (h - 1, (int) Math.ceil (cy + radius + 1));
            if (x1 < x0 || y1 < y0) return;
            for (int y = y0; y <= y1; y++) {
                double py = y + 0.5 - cy;
                for (int x = x0; x <= x1; x++) {
                    double d = Math.sqrt ((x + 0.5 - cx) * (x + 0.5 - cx) + py * py);
                    double c = coverage (d, radius, brush.hardness, aliased);
                    if (c <= 0) continue;
                    double v = a * c;
                    if (selection != null) v *= selection[y * w + x] / 255.0;
                    if (v <= 0) continue;
                    int i = y * w + x;
                    if (mode == DabMode.MAX) {
                        if (v > alpha[i]) alpha[i] = (float) v;
                    } else {
                        alpha[i] = (float) (alpha[i] + v * (1 - alpha[i]));
                    }
                }
            }
            dx0 = int.min (dx0, x0);
            dy0 = int.min (dy0, y0);
            dx1 = int.max (dx1, x1);
            dy1 = int.max (dy1, y1);
        }

        private void dab_at (double x, double y, double p) {
            stamp (x, y, brush.size_at (p) / 2, brush.alpha_at (p));
        }

        public void begin (double x, double y, double pressure) {
            started = true;
            lx = x;
            ly = y;
            lp = pressure;
            residual = 0;
            dab_at (x, y, pressure);
        }

        public void line_to (double x, double y, double pressure) {
            if (!started) {
                begin (x, y, pressure);
                return;
            }
            double len = Math.hypot (x - lx, y - ly);
            if (len < 1e-9) {
                lp = pressure;
                return;
            }
            double pos = brush.step_at (lp) - residual;
            double last = 0;
            bool any = false;
            int guard = 0;
            while (pos <= len + 1e-9 && guard++ < 100000) {
                double t = pos / len;
                double p = lp + (pressure - lp) * t;
                dab_at (lx + (x - lx) * t, ly + (y - ly) * t, p);
                last = pos;
                any = true;
                pos += brush.step_at (p);
            }
            residual = any ? len - last : residual + len;
            lx = x;
            ly = y;
            lp = pressure;
        }

        public void tick (double seconds) {
            if (!started || brush.kind != BrushKind.AIRBRUSH) return;
            int n = int.max (1, (int) Math.round (seconds * 60));
            for (int i = 0; i < n; i++) dab_at (lx, ly, lp);
        }

        public bool has_dirty () {
            return dx1 >= dx0 && dy1 >= dy0;
        }

        public void compose () {
            if (!has_dirty ()) return;
            int x0 = dx0, y0 = dy0, x1 = dx1, y1 = dy1;
            bx0 = int.min (bx0, x0);
            by0 = int.min (by0, y0);
            bx1 = int.max (bx1, x1);
            by1 = int.max (by1, y1);
            reset_dirty ();
            mask.flush ();
            unowned uint8[] md = mask.get_data ();
            int ms = mask.get_stride ();
            for (int y = y0; y <= y1; y++) {
                for (int x = x0; x <= x1; x++) {
                    md[y * ms + x] = (uint8) Math.round (alpha[y * w + x].clamp (0, 1) * 255);
                }
            }
            mask.mark_dirty ();
            var cr = new Cairo.Context (target);
            cr.rectangle (x0, y0, x1 - x0 + 1, y1 - y0 + 1);
            cr.clip ();
            cr.set_operator (Cairo.Operator.SOURCE);
            cr.set_source_surface (base_pixels, 0, 0);
            cr.paint ();
            cr.set_operator (brush.composite ());
            if (brush.kind == BrushKind.ERASER) cr.set_source_rgba (0, 0, 0, brush.opacity.clamp (0, 1));
            else cr.set_source_rgba (color.r, color.g, color.b, (color.a * brush.opacity).clamp (0, 1));
            cr.mask_surface (mask, 0, 0);
            target.flush ();
        }

        public void finish () {
            compose ();
        }

        public bool bounds (out int x, out int y, out int bw, out int bh) {
            x = bx0;
            y = by0;
            bw = bx1 - bx0 + 1;
            bh = by1 - by0 + 1;
            return bx1 >= bx0 && by1 >= by0;
        }
    }
}
