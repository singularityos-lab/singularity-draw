namespace Singularity.Apps.Draw {

    public class ShapeOps {
        public static PathData outline_of (Shape s) {
            var ps = s as PathShape;
            if (ps != null) return ps.page_path ();
            return s.page_outline ();
        }

        private static bool empty_area (PathData p) {
            return p.is_empty () || PathBoolean.area (p).abs () < 1;
        }

        public static Gee.ArrayList<PathData> fragment (Gee.List<Shape> shapes) {
            var pieces = new Gee.ArrayList<PathData> ();
            PathData? covered = null;
            foreach (var s in shapes) {
                var b = outline_of (s);
                var next = new Gee.ArrayList<PathData> ();
                foreach (var p in pieces) {
                    var inter = PathBoolean.apply (p, b, BoolOp.INTERSECT);
                    var rest = PathBoolean.apply (p, b, BoolOp.SUBTRACT);
                    if (!empty_area (inter)) next.add (inter);
                    if (!empty_area (rest)) next.add (rest);
                }
                var fresh = covered != null ? PathBoolean.apply (b, covered, BoolOp.SUBTRACT) : b;
                if (!empty_area (fresh)) next.add (fresh);
                covered = covered != null ? PathBoolean.apply (covered, b, BoolOp.UNION) : b;
                pieces = next;
            }
            return pieces;
        }

        public static PathData combine (Gee.List<Shape> shapes) {
            PathData? r = null;
            foreach (var s in shapes) {
                var o = outline_of (s);
                r = r == null ? o : PathBoolean.apply (r, o, BoolOp.EXCLUDE);
            }
            return r ?? new PathData ();
        }

        public static PathData join (Gee.List<Shape> shapes) {
            var p = new PathData ();
            foreach (var s in shapes) {
                var ps = s as PathShape;
                if (ps != null) p.append (ps.page_path ());
                else {
                    var g = s.geometry ();
                    foreach (var part in g.parts) p.append (part.path.transformed (s.transform ()));
                }
            }
            return p;
        }

        public static Gee.ArrayList<PathData> trim (Gee.List<Shape> shapes) {
            var result = new Gee.ArrayList<PathData> ();
            var closed = new Gee.ArrayList<Shape> ();
            var cutters = new Gee.ArrayList<Polygon> ();
            foreach (var s in shapes) foreach (var poly in outline_of (s).flatten (0.5)) cutters.add (poly);
            foreach (var s in shapes) {
                var ps = s as PathShape;
                if (ps != null && !ps.is_closed ()) {
                    foreach (var poly in ps.page_path ().flatten (0.5)) {
                        var cur = new PathData ();
                        cur.move_to (poly.pts[0].x, poly.pts[0].y);
                        for (int i = 1; i < poly.pts.length; i++) {
                            var a = poly.pts[i - 1];
                            var b = poly.pts[i];
                            var cuts = new Gee.ArrayList<double?> ();
                            foreach (var other in cutters) {
                                if (other == poly) continue;
                                int n = other.pts.length;
                                int last = other.closed ? n : n - 1;
                                for (int k = 0; k < last; k++) {
                                    double t, u;
                                    if (Router.seg_intersect (a, b, other.pts[k], other.pts[(k + 1) % n], out t, out u) && t > 1e-3 && t < 1 - 1e-3) cuts.add (t);
                                }
                            }
                            cuts.sort ((x, y) => x < y ? -1 : (x > y ? 1 : 0));
                            foreach (double? t in cuts) {
                                double tx = a.x + (b.x - a.x) * t, ty = a.y + (b.y - a.y) * t;
                                cur.line_to (tx, ty);
                                result.add (cur);
                                cur = new PathData ();
                                cur.move_to (tx, ty);
                            }
                            cur.line_to (b.x, b.y);
                        }
                        if (cur.segs.size > 1) result.add (cur);
                    }
                } else {
                    closed.add (s);
                }
            }
            if (closed.size > 0) result.add_all (fragment (closed));
            return result;
        }

        public static PathData offset (Shape s, double d) {
            var result = new PathData ();
            foreach (var poly in outline_of (s).flatten (0.5)) {
                int n = poly.pts.length;
                if (n < 2) continue;
                double sign = poly.area () >= 0 ? 1 : -1;
                Point[] out_pts = {};
                for (int i = 0; i < n; i++) {
                    bool open_end = !poly.closed && (i == 0 || i == n - 1);
                    var prev = poly.pts[(i - 1 + n) % n];
                    var cur = poly.pts[i];
                    var next = poly.pts[(i + 1) % n];
                    if (!poly.closed && i == 0) prev = cur;
                    if (!poly.closed && i == n - 1) next = cur;
                    double e1x = cur.x - prev.x, e1y = cur.y - prev.y;
                    double e2x = next.x - cur.x, e2y = next.y - cur.y;
                    double l1 = Math.hypot (e1x, e1y), l2 = Math.hypot (e2x, e2y);
                    double n1x = 0, n1y = 0, n2x = 0, n2y = 0;
                    if (l1 > 1e-9) {
                        n1x = e1y / l1 * sign;
                        n1y = -e1x / l1 * sign;
                    }
                    if (l2 > 1e-9) {
                        n2x = e2y / l2 * sign;
                        n2y = -e2x / l2 * sign;
                    }
                    if (l1 <= 1e-9) {
                        n1x = n2x;
                        n1y = n2y;
                    }
                    if (l2 <= 1e-9) {
                        n2x = n1x;
                        n2y = n1y;
                    }
                    double bx = n1x + n2x, by = n1y + n2y;
                    double bl = Math.hypot (bx, by);
                    if (bl < 1e-9 || open_end) {
                        bx = n1x;
                        by = n1y;
                        bl = 1;
                    } else {
                        bx /= bl;
                        by /= bl;
                    }
                    double dot = bx * n1x + by * n1y;
                    double k = dot.abs () > 0.25 ? d / dot : d * 4;
                    out_pts += Point (cur.x + bx * k, cur.y + by * k);
                }
                var p = new PathData ();
                p.add_polygon (out_pts, poly.closed);
                result.append (p);
            }
            return result;
        }
    }
}
