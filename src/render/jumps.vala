namespace Singularity.Apps.Draw {

    public class JumpPoint {
        public int seg;
        public double t;
        public Point p;

        public JumpPoint (int seg, double t, Point p) {
            this.seg = seg;
            this.t = t;
            this.p = p;
        }
    }

    public class JumpMap {
        public Gee.HashMap<Connector, Gee.ArrayList<JumpPoint>> map = new Gee.HashMap<Connector, Gee.ArrayList<JumpPoint>> ();
        public JumpStyle style = JumpStyle.ARC;
        public double size = 1;

        public Gee.ArrayList<JumpPoint>? get_jumps (Connector c) {
            return map.has_key (c) ? map[c] : null;
        }

        public int total () {
            int n = 0;
            foreach (var e in map.entries) n += e.value.size;
            return n;
        }
    }

    public class LineJumps {
        private static bool horizontal (Point a, Point b) {
            return (a.y - b.y).abs () < 0.5 && (a.x - b.x).abs () > 0.5;
        }

        private static bool vertical (Point a, Point b) {
            return (a.x - b.x).abs () < 0.5 && (a.y - b.y).abs () > 0.5;
        }

        private static Rect box (Point[] pts) {
            var r = Rect.empty ();
            foreach (var p in pts) r = r.include (p.x, p.y);
            return r;
        }

        public static JumpMap compute (Page page) {
            var jm = new JumpMap ();
            jm.style = page.jump_style;
            jm.size = page.jump_size;
            var conns = new Gee.ArrayList<Connector> ();
            foreach (var c in page.connectors ()) {
                if (c.points.length < 2 || c.route == RouteKind.CURVED || !page.item_visible (page.top_level (c))) continue;
                conns.add (c);
            }
            var boxes = new Gee.ArrayList<Rect?> ();
            foreach (var c in conns) boxes.add (box (c.points).inflate (1));
            for (int i = 0; i < conns.size; i++) {
                var ci = conns[i];
                for (int j = 0; j < i; j++) {
                    var cj = conns[j];
                    if (!boxes[i].intersects (boxes[j])) continue;
                    for (int a = 1; a < ci.points.length; a++) {
                        var a0 = ci.points[a - 1];
                        var a1 = ci.points[a];
                        for (int b = 1; b < cj.points.length; b++) {
                            var b0 = cj.points[b - 1];
                            var b1 = cj.points[b];
                            double t, u;
                            if (!Router.seg_intersect (a0, a1, b0, b1, out t, out u)) continue;
                            double la = a0.distance (a1), lb = b0.distance (b1);
                            if (la < 1 || lb < 1) continue;
                            double ea = 6 / la, eb = 6 / lb;
                            if (t < ea || t > 1 - ea || u < eb || u > 1 - eb) continue;
                            var p = Point (a0.x + (a1.x - a0.x) * t, a0.y + (a1.y - a0.y) * t);
                            bool i_jumps;
                            if (ci.jumps != cj.jumps) {
                                i_jumps = ci.jumps;
                            } else if (page.jumps_vertical) {
                                bool vi = vertical (a0, a1), vj = vertical (b0, b1);
                                i_jumps = vi == vj ? true : vi;
                            } else {
                                bool hi = horizontal (a0, a1), hj = horizontal (b0, b1);
                                i_jumps = hi == hj ? true : hi;
                            }
                            var target = i_jumps ? ci : cj;
                            int seg = i_jumps ? a - 1 : b - 1;
                            double tt = i_jumps ? t : u;
                            if (!jm.map.has_key (target)) jm.map[target] = new Gee.ArrayList<JumpPoint> ();
                            jm.map[target].add (new JumpPoint (seg, tt, p));
                        }
                    }
                }
            }
            foreach (var e in jm.map.entries) {
                e.value.sort ((x, y) => x.seg != y.seg ? x.seg - y.seg : (x.t < y.t ? -1 : (x.t > y.t ? 1 : 0)));
            }
            return jm;
        }

        public static PathData jumped_path (Connector c, Gee.List<JumpPoint> jumps, JumpStyle style, double radius) {
            var p = new PathData ();
            var pts = c.points;
            p.move_to (pts[0].x, pts[0].y);
            int k = 0;
            for (int s = 1; s < pts.length; s++) {
                var a = pts[s - 1];
                var b = pts[s];
                double len = a.distance (b);
                double dx = len > 0 ? (b.x - a.x) / len : 0, dy = len > 0 ? (b.y - a.y) / len : 0;
                double nx = dy, ny = -dx;
                if (ny > 0 || (ny == 0 && nx > 0)) {
                    nx = -nx;
                    ny = -ny;
                }
                double last_t = 0;
                while (k < jumps.size && jumps[k].seg < s - 1) k++;
                while (k < jumps.size && jumps[k].seg == s - 1) {
                    var j = jumps[k];
                    double r = double.min (radius, len * 0.25);
                    double pos = j.t * len;
                    if (pos - r < last_t * len + 0.5) {
                        k++;
                        continue;
                    }
                    double sx = a.x + dx * (pos - r), sy = a.y + dy * (pos - r);
                    double ex = a.x + dx * (pos + r), ey = a.y + dy * (pos + r);
                    p.line_to (sx, sy);
                    switch (style) {
                        case JumpStyle.GAP:
                            p.move_to (ex, ey);
                            break;
                        case JumpStyle.SQUARE:
                            p.line_to (sx + nx * r, sy + ny * r);
                            p.line_to (ex + nx * r, ey + ny * r);
                            p.line_to (ex, ey);
                            break;
                        default:
                            double k2 = r * 1.3333 * 0.75;
                            p.curve_to (sx + nx * k2, sy + ny * k2, ex + nx * k2, ey + ny * k2, ex, ey);
                            break;
                    }
                    last_t = (pos + r) / len;
                    k++;
                }
                p.line_to (b.x, b.y);
            }
            return p;
        }
    }
}
