namespace Singularity.Apps.Draw {

    public class Router {
        public const double MARGIN = 14;
        public const double BEND_COST = 24;
        private const int MAX_OBSTACLES = 80;

        private struct End {
            public Point p;
            public Point dir;
            public Rect box;
            public bool has_box;
            public string id;
        }

        public static void route_all (Page page) {
            foreach (var c in page.connectors ()) route (page, c);
        }

        public static void route_attached (Page page, Gee.Collection<string> ids) {
            foreach (var c in page.connectors ()) {
                if (ids.contains (c.src.item_id) || ids.contains (c.dst.item_id) || ids.contains (c.id)) route (page, c);
            }
        }

        private static Point anchor_of (Page page, Endpoint e) {
            if (e.attached ()) {
                var it = page.find (e.item_id);
                var s = it as Shape;
                if (s != null) return e.port >= 0 ? s.port_point (e.port) : Point (s.cx (), s.cy ());
                if (it != null) {
                    var b = it.bounds ();
                    return Point (b.cx (), b.cy ());
                }
            }
            return Point (e.x, e.y);
        }

        private static End resolve (Page page, Endpoint e, Point toward, RouteKind kind) {
            var end = End ();
            end.p = Point (e.x, e.y);
            end.dir = Point (0, 0);
            end.has_box = false;
            end.id = e.item_id;
            if (!e.attached ()) return end;
            var it = page.find (e.item_id);
            if (it == null || it is Connector) {
                e.item_id = "";
                e.port = -1;
                end.id = "";
                return end;
            }
            end.box = it.bounds ();
            end.has_box = true;
            var s = it as Shape;
            if (s == null) {
                end.p = perimeter_rect (end.box, toward);
                end.dir = side_dir (end.box, end.p);
                e.x = end.p.x;
                e.y = end.p.y;
                return end;
            }
            if (e.port >= 0 && e.port < s.ports ().length) {
                end.p = s.port_point (e.port);
                end.dir = s.port_direction (e.port);
            } else if (kind == RouteKind.STRAIGHT) {
                end.p = perimeter (s, toward);
                end.dir = Point (0, 0);
            } else {
                int best = -1;
                double best_score = -double.INFINITY;
                var ports = s.ports ();
                double vx = toward.x - s.cx (), vy = toward.y - s.cy ();
                double vl = Math.hypot (vx, vy);
                if (vl < 1e-6) {
                    vx = 0;
                    vy = 1;
                    vl = 1;
                }
                for (int i = 0; i < ports.length; i++) {
                    var d = s.port_direction (i);
                    if (d.x == 0 && d.y == 0) continue;
                    var pp = s.port_point (i);
                    double score = (d.x * vx + d.y * vy) / vl - Math.hypot (toward.x - pp.x, toward.y - pp.y) / 10000.0;
                    if (score > best_score) {
                        best_score = score;
                        best = i;
                    }
                }
                if (best >= 0) {
                    end.p = s.port_point (best);
                    end.dir = s.port_direction (best);
                } else {
                    end.p = perimeter (s, toward);
                }
            }
            e.x = end.p.x;
            e.y = end.p.y;
            return end;
        }

        private static Point side_dir (Rect b, Point p) {
            double dl = (p.x - b.x).abs (), dr = (p.x - b.x2 ()).abs (), dt = (p.y - b.y).abs (), db = (p.y - b.y2 ()).abs ();
            double m = double.min (double.min (dl, dr), double.min (dt, db));
            if (m == dl) return Point (-1, 0);
            if (m == dr) return Point (1, 0);
            if (m == dt) return Point (0, -1);
            return Point (0, 1);
        }

        public static Point perimeter_rect (Rect b, Point toward) {
            double cx = b.cx (), cy = b.cy ();
            double dx = toward.x - cx, dy = toward.y - cy;
            if (dx.abs () < 1e-9 && dy.abs () < 1e-9) return Point (cx, b.y);
            double tx = dx != 0 ? (b.w / 2) / dx.abs () : double.INFINITY;
            double ty = dy != 0 ? (b.h / 2) / dy.abs () : double.INFINITY;
            double t = double.min (tx, ty);
            return Point (cx + dx * t, cy + dy * t);
        }

        public static Point perimeter (Shape s, Point toward) {
            double cx = s.cx (), cy = s.cy ();
            double dx = toward.x - cx, dy = toward.y - cy;
            double len = Math.hypot (dx, dy);
            if (len < 1e-6) return Point (cx, cy - s.h / 2);
            double far = (s.w + s.h) * 2 + len;
            var a = Point (cx, cy);
            var b = Point (cx + dx / len * far, cy + dy / len * far);
            double best_t = -1;
            foreach (var poly in s.page_outline ().flatten (0.5)) {
                int n = poly.pts.length;
                for (int i = 0; i < n; i++) {
                    var p = poly.pts[i];
                    var q = poly.pts[(i + 1) % n];
                    double t, u;
                    if (seg_intersect (a, b, p, q, out t, out u) && t > best_t) best_t = t;
                }
            }
            if (best_t < 0) return perimeter_rect (s.bounds (), toward);
            return Point (a.x + (b.x - a.x) * best_t, a.y + (b.y - a.y) * best_t);
        }

        public static bool seg_intersect (Point a, Point b, Point c, Point d, out double t, out double u) {
            t = 0;
            u = 0;
            double rx = b.x - a.x, ry = b.y - a.y, sx = d.x - c.x, sy = d.y - c.y;
            double den = rx * sy - ry * sx;
            if (den.abs () < 1e-12) return false;
            double qx = c.x - a.x, qy = c.y - a.y;
            t = (qx * sy - qy * sx) / den;
            u = (qx * ry - qy * rx) / den;
            return t >= 0 && t <= 1 && u >= 0 && u <= 1;
        }

        public static void route (Page page, Connector c) {
            var a0 = anchor_of (page, c.src);
            var b0 = anchor_of (page, c.dst);
            Point toward_src = c.waypoints.length > 0 ? c.waypoints[0] : b0;
            Point toward_dst = c.waypoints.length > 0 ? c.waypoints[c.waypoints.length - 1] : a0;
            var s = resolve (page, c.src, toward_src, c.route);
            var d = resolve (page, c.dst, toward_dst, c.route);
            if (c.route == RouteKind.STRAIGHT) {
                Point[] pts = { s.p };
                foreach (var w in c.waypoints) pts += w;
                pts += d.p;
                c.points = pts;
                return;
            }
            Point[] result;
            if (c.waypoints.length > 0) {
                result = elbow_through (s, d, c.waypoints);
            } else {
                var obstacles = collect_obstacles (page, c, s, d);
                result = orthogonal (s, d, obstacles);
            }
            c.points = simplify (result);
        }

        private static Gee.ArrayList<Rect?> collect_obstacles (Page page, Connector c, End s, End d) {
            var list = new Gee.ArrayList<Rect?> ();
            var region = Rect (s.p.x, s.p.y, 0, 0).include (d.p.x, d.p.y);
            if (s.has_box) region = region.union (s.box);
            if (d.has_box) region = region.union (d.box);
            region = region.inflate (240);
            foreach (var it in page.items) {
                if (it is Connector || !page.item_visible (it)) continue;
                var sh = it as Shape;
                if (sh != null && (sh.is_container () || sh.kind == "text" || sh.kind == "line-shape")) continue;
                var b = it.bounds ();
                if (!b.intersects (region)) continue;
                var inf = b.inflate (MARGIN);
                if (it.id != s.id && strictly_inside (inf, s.p)) continue;
                if (it.id != d.id && strictly_inside (inf, d.p)) continue;
                if (it.id == s.id || it.id == d.id) inf = b.inflate (MARGIN - 0.5);
                list.add (inf);
                if (list.size > MAX_OBSTACLES) break;
            }
            return list;
        }

        private static bool strictly_inside (Rect r, Point p) {
            return p.x > r.x + 1e-6 && p.x < r.x2 () - 1e-6 && p.y > r.y + 1e-6 && p.y < r.y2 () - 1e-6;
        }

        private static Point stub (End e) {
            if (e.dir.x == 0 && e.dir.y == 0) return e.p;
            return Point (e.p.x + e.dir.x * MARGIN, e.p.y + e.dir.y * MARGIN);
        }

        private static int dir_index (double dx, double dy) {
            if (dx.abs () > dy.abs ()) return dx > 0 ? 0 : 2;
            if (dy.abs () > 1e-9) return dy > 0 ? 1 : 3;
            return -1;
        }

        private class Node {
            public int xi;
            public int yi;
            public int dir;
            public double g;
            public double f;
            public Node? prev;
        }

        private static Point[] orthogonal (End s, End d, Gee.ArrayList<Rect?> obstacles) {
            var s1 = stub (s);
            var d1 = stub (d);
            var xs_set = new Gee.TreeSet<double?> ((a, b) => a < b ? -1 : (a > b ? 1 : 0));
            var ys_set = new Gee.TreeSet<double?> ((a, b) => a < b ? -1 : (a > b ? 1 : 0));
            xs_set.add (round2 (s1.x));
            xs_set.add (round2 (d1.x));
            ys_set.add (round2 (s1.y));
            ys_set.add (round2 (d1.y));
            xs_set.add (round2 ((s1.x + d1.x) / 2));
            ys_set.add (round2 ((s1.y + d1.y) / 2));
            foreach (var r in obstacles) {
                xs_set.add (round2 (r.x));
                xs_set.add (round2 (r.x2 ()));
                ys_set.add (round2 (r.y));
                ys_set.add (round2 (r.y2 ()));
            }
            double[] xs = {};
            double[] ys = {};
            foreach (var v in xs_set) xs += v;
            foreach (var v in ys_set) ys += v;
            int nx = xs.length, ny = ys.length;
            int sxi = index_of (xs, round2 (s1.x)), syi = index_of (ys, round2 (s1.y));
            int dxi = index_of (xs, round2 (d1.x)), dyi = index_of (ys, round2 (d1.y));
            int start_dir = dir_index (s.dir.x, s.dir.y);
            int end_dir = dir_index (-d.dir.x, -d.dir.y);
            var blocked = new bool[nx * ny];
            for (int i = 0; i < nx; i++) {
                for (int j = 0; j < ny; j++) {
                    var p = Point (xs[i], ys[j]);
                    foreach (var r in obstacles) {
                        if (strictly_inside (r, p)) {
                            blocked[i * ny + j] = true;
                            break;
                        }
                    }
                }
            }
            blocked[sxi * ny + syi] = false;
            blocked[dxi * ny + dyi] = false;
            var best = new Gee.HashMap<int, double?> ();
            var open = new Gee.PriorityQueue<Node> ((a, b) => a.f < b.f ? -1 : (a.f > b.f ? 1 : 0));
            var first = new Node ();
            first.xi = sxi;
            first.yi = syi;
            first.dir = start_dir;
            first.g = 0;
            first.f = (xs[dxi] - xs[sxi]).abs () + (ys[dyi] - ys[syi]).abs ();
            open.offer (first);
            Node? found = null;
            int[] dxs = { 1, 0, -1, 0 };
            int[] dys = { 0, 1, 0, -1 };
            int guard = 0;
            while (!open.is_empty && guard++ < 60000) {
                var cur = open.poll ();
                int key = (cur.xi * ny + cur.yi) * 5 + (cur.dir + 1);
                if (best.has_key (key) && best[key] < cur.g - 1e-9) continue;
                if (cur.xi == dxi && cur.yi == dyi) {
                    found = cur;
                    break;
                }
                for (int k = 0; k < 4; k++) {
                    if (cur.dir >= 0 && k == (cur.dir + 2) % 4) continue;
                    int ni = cur.xi + dxs[k], nj = cur.yi + dys[k];
                    if (ni < 0 || nj < 0 || ni >= nx || nj >= ny) continue;
                    if (blocked[ni * ny + nj]) continue;
                    var mid = Point ((xs[cur.xi] + xs[ni]) / 2, (ys[cur.yi] + ys[nj]) / 2);
                    bool hit = false;
                    foreach (var r in obstacles) {
                        if (strictly_inside (r, mid)) {
                            hit = true;
                            break;
                        }
                    }
                    if (hit) continue;
                    double step = (xs[ni] - xs[cur.xi]).abs () + (ys[nj] - ys[cur.yi]).abs ();
                    double g = cur.g + step + (cur.dir >= 0 && cur.dir != k ? BEND_COST : 0);
                    if (ni == dxi && nj == dyi && end_dir >= 0 && k != end_dir) g += BEND_COST;
                    int nkey = (ni * ny + nj) * 5 + (k + 1);
                    if (best.has_key (nkey) && best[nkey] <= g + 1e-9) continue;
                    best[nkey] = g;
                    var n = new Node ();
                    n.xi = ni;
                    n.yi = nj;
                    n.dir = k;
                    n.g = g;
                    n.f = g + (xs[dxi] - xs[ni]).abs () + (ys[dyi] - ys[nj]).abs ();
                    n.prev = cur;
                    open.offer (n);
                }
            }
            Point[] pts = {};
            if (found == null) {
                return elbow (s.p, s1, d1, d.p, s.dir);
            }
            var rev = new Gee.ArrayList<Node> ();
            for (Node? n = found; n != null; n = n.prev) rev.add (n);
            pts += s.p;
            for (int i = rev.size - 1; i >= 0; i--) pts += Point (xs[rev[i].xi], ys[rev[i].yi]);
            pts += d.p;
            return pts;
        }

        private static Point[] elbow (Point a, Point a1, Point b1, Point b, Point adir) {
            Point[] pts = { a, a1 };
            if (adir.y != 0) pts += Point (a1.x, b1.y);
            else pts += Point (b1.x, a1.y);
            pts += b1;
            pts += b;
            return pts;
        }

        private static Point[] elbow_through (End s, End d, Point[] waypoints) {
            Point[] pts = { s.p };
            var prev = stub (s);
            pts += prev;
            bool horizontal_first = s.dir.y == 0;
            foreach (var w in waypoints) {
                if (horizontal_first) pts += Point (w.x, prev.y);
                else pts += Point (prev.x, w.y);
                pts += w;
                prev = w;
                horizontal_first = !horizontal_first;
            }
            var d1 = stub (d);
            if (d.dir.x != 0) pts += Point (prev.x, d1.y);
            else pts += Point (d1.x, prev.y);
            pts += d1;
            pts += d.p;
            return pts;
        }

        private static double round2 (double v) {
            return Math.round (v * 100) / 100;
        }

        private static int index_of (double[] arr, double v) {
            for (int i = 0; i < arr.length; i++) if ((arr[i] - v).abs () < 1e-6) return i;
            return 0;
        }

        public static Point[] simplify (Point[] pts) {
            Point[] out_pts = {};
            foreach (var p in pts) {
                int n = out_pts.length;
                if (n > 0 && (out_pts[n - 1].x - p.x).abs () < 0.01 && (out_pts[n - 1].y - p.y).abs () < 0.01) continue;
                if (n >= 2) {
                    var a = out_pts[n - 2];
                    var b = out_pts[n - 1];
                    double cr = (b.x - a.x) * (p.y - b.y) - (b.y - a.y) * (p.x - b.x);
                    double dot = (b.x - a.x) * (p.x - b.x) + (b.y - a.y) * (p.y - b.y);
                    if (cr.abs () < 0.01 && dot >= 0) {
                        out_pts[n - 1] = p;
                        continue;
                    }
                }
                out_pts += p;
            }
            return out_pts;
        }

        public static PathData smooth (Point[] pts) {
            var p = new PathData ();
            if (pts.length == 0) return p;
            p.move_to (pts[0].x, pts[0].y);
            if (pts.length == 2) {
                p.line_to (pts[1].x, pts[1].y);
                return p;
            }
            double cx = pts[0].x, cy = pts[0].y;
            for (int i = 1; i < pts.length - 1; i++) {
                var ctrl = pts[i];
                Point target;
                if (i == pts.length - 2) target = pts[i + 1];
                else target = Point ((pts[i].x + pts[i + 1].x) / 2, (pts[i].y + pts[i + 1].y) / 2);
                p.curve_to (cx + 2.0 / 3 * (ctrl.x - cx), cy + 2.0 / 3 * (ctrl.y - cy),
                            target.x + 2.0 / 3 * (ctrl.x - target.x), target.y + 2.0 / 3 * (ctrl.y - target.y),
                            target.x, target.y);
                cx = target.x;
                cy = target.y;
            }
            return p;
        }
    }
}
