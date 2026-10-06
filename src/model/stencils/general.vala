namespace Singularity.Apps.Draw {

    public class StencilKit {
        public static string n (double v) {
            return PathData.fmt (v, 3);
        }

        public static string ellipse (double cx, double cy, double rx, double ry) {
            return "M%s %s A%s %s 0 1 0 %s %s A%s %s 0 1 0 %s %s Z".printf (n (cx - rx), n (cy), n (rx), n (ry), n (cx + rx), n (cy), n (rx), n (ry), n (cx - rx), n (cy));
        }

        public static string ellipse_rev (double cx, double cy, double rx, double ry) {
            return "M%s %s A%s %s 0 1 1 %s %s A%s %s 0 1 1 %s %s Z".printf (n (cx - rx), n (cy), n (rx), n (ry), n (cx + rx), n (cy), n (rx), n (ry), n (cx - rx), n (cy));
        }

        public static string circle (double cx, double cy, double r) {
            return ellipse (cx, cy, r, r);
        }

        public static string ring (double cx, double cy, double ro, double ri) {
            return circle (cx, cy, ro) + " " + ellipse_rev (cx, cy, ri, ri);
        }

        public static string rect (double x, double y, double w, double h) {
            return "M%s %s H%s V%s H%s Z".printf (n (x), n (y), n (x + w), n (y + h), n (x));
        }

        public static string rect_rev (double x, double y, double w, double h) {
            return "M%s %s V%s H%s V%s Z".printf (n (x), n (y), n (y + h), n (x + w), n (y));
        }

        public static string rrect (double x, double y, double w, double h, double r) {
            double rr = double.min (r, double.min (w, h) / 2);
            return "M%s %s H%s A%s %s 0 0 1 %s %s V%s A%s %s 0 0 1 %s %s H%s A%s %s 0 0 1 %s %s V%s A%s %s 0 0 1 %s %s Z".printf (
                n (x + rr), n (y), n (x + w - rr), n (rr), n (rr), n (x + w), n (y + rr), n (y + h - rr), n (rr), n (rr), n (x + w - rr), n (y + h),
                n (x + rr), n (rr), n (rr), n (x), n (y + h - rr), n (y + rr), n (rr), n (rr), n (x + rr), n (y));
        }

        public static string poly (double[] xy, bool closed = true) {
            var sb = new StringBuilder ();
            for (int i = 0; i + 1 < xy.length; i += 2) {
                sb.append (i == 0 ? "M" : " L");
                sb.append ("%s %s".printf (n (xy[i]), n (xy[i + 1])));
            }
            if (closed) sb.append (" Z");
            return sb.str;
        }

        public static string line (double x1, double y1, double x2, double y2) {
            return "M%s %s L%s %s".printf (n (x1), n (y1), n (x2), n (y2));
        }

        public static string lines (double[] segs) {
            var sb = new StringBuilder ();
            for (int i = 0; i + 3 < segs.length; i += 4) {
                if (sb.len > 0) sb.append_c (' ');
                sb.append (line (segs[i], segs[i + 1], segs[i + 2], segs[i + 3]));
            }
            return sb.str;
        }

        public static double[] points_regular (int count, double cx, double cy, double rx, double ry, double start_deg) {
            double[] xy = {};
            for (int i = 0; i < count; i++) {
                double a = (start_deg + i * 360.0 / count) * Math.PI / 180;
                xy += cx + rx * Math.cos (a);
                xy += cy + ry * Math.sin (a);
            }
            return xy;
        }

        public static string regular (int count, double cx, double cy, double rx, double ry, double start_deg = -90) {
            return poly (points_regular (count, cx, cy, rx, ry, start_deg));
        }

        public static string star (int count, double cx, double cy, double rx, double ry, double inner, double start_deg = -90) {
            double[] xy = {};
            for (int i = 0; i < count * 2; i++) {
                double a = (start_deg + i * 180.0 / count) * Math.PI / 180;
                double r = i % 2 == 0 ? 1 : inner;
                xy += cx + rx * r * Math.cos (a);
                xy += cy + ry * r * Math.sin (a);
            }
            return poly (xy);
        }

        public static string arc (double cx, double cy, double rx, double ry, double a1, double a2) {
            double span = a2 - a1;
            if (span.abs () >= 359.99) {
                double mid = a1 + span / 2;
                return arc (cx, cy, rx, ry, a1, mid) + arc_to (cx, cy, rx, ry, mid, a2);
            }
            double r1 = a1 * Math.PI / 180;
            return "M%s %s".printf (n (cx + rx * Math.cos (r1)), n (cy + ry * Math.sin (r1))) + arc_to (cx, cy, rx, ry, a1, a2);
        }

        public static string arc_to (double cx, double cy, double rx, double ry, double a1, double a2) {
            double r2 = a2 * Math.PI / 180;
            int large = (a2 - a1).abs () > 180 ? 1 : 0;
            int sweep = a2 > a1 ? 1 : 0;
            return " A%s %s 0 %d %d %s %s".printf (n (rx), n (ry), large, sweep, n (cx + rx * Math.cos (r2)), n (cy + ry * Math.sin (r2)));
        }

        public static string dashed_ellipse (double cx, double cy, double rx, double ry, int segments) {
            var sb = new StringBuilder ();
            double step = 360.0 / segments;
            for (int i = 0; i < segments; i++) {
                if (sb.len > 0) sb.append_c (' ');
                sb.append (arc (cx, cy, rx, ry, i * step, i * step + step * 0.6));
            }
            return sb.str;
        }

        public static string dashed_line (double x1, double y1, double x2, double y2, double dash, double gap) {
            var sb = new StringBuilder ();
            double len = Math.hypot (x2 - x1, y2 - y1);
            if (len <= 0) return "";
            double ux = (x2 - x1) / len, uy = (y2 - y1) / len;
            double t = 0;
            while (t < len) {
                double e = double.min (t + dash, len);
                if (sb.len > 0) sb.append_c (' ');
                sb.append (line (x1 + ux * t, y1 + uy * t, x1 + ux * e, y1 + uy * e));
                t = e + gap;
            }
            return sb.str;
        }

        public static string dashed_rect (double x, double y, double w, double h, double dash, double gap) {
            return string.join (" ", dashed_line (x, y, x + w, y, dash, gap), dashed_line (x + w, y, x + w, y + h, dash, gap),
                dashed_line (x + w, y + h, x, y + h, dash, gap), dashed_line (x, y + h, x, y, dash, gap));
        }

        public static double[] orient (double[] xy, int mode, double size = 100) {
            double[] o = {};
            for (int i = 0; i + 1 < xy.length; i += 2) {
                double x = xy[i], y = xy[i + 1];
                switch (mode) {
                    case 1: o += size - x; o += y; break;
                    case 2: o += x; o += size - y; break;
                    case 3: o += size - y; o += x; break;
                    case 4: o += y; o += size - x; break;
                    case 5: o += size - x; o += size - y; break;
                    default: o += x; o += y; break;
                }
            }
            return o;
        }

        public static double[] rotate (double[] xy, double deg, double cx, double cy, double scale = 1) {
            double[] o = {};
            double a = deg * Math.PI / 180;
            for (int i = 0; i + 1 < xy.length; i += 2) {
                double dx = (xy[i] - cx) * scale, dy = (xy[i + 1] - cy) * scale;
                o += cx + dx * Math.cos (a) - dy * Math.sin (a);
                o += cy + dx * Math.sin (a) + dy * Math.cos (a);
            }
            return o;
        }

        public static string envelope_body (double x, double y, double w, double h) {
            return rect (x, y, w, h);
        }

        public static string envelope_flap (double x, double y, double w, double h) {
            return poly ({ x, y, x + w / 2, y + h * 0.55, x + w, y }, false);
        }
    }

    public class StencilsGeneral {
        private static string n (double v) {
            return StencilKit.n (v);
        }

        public static void register () {
            Stencils.use_category ("basic");
            Stencils.shape ("basic-plaque", _("Plaque"), 120, 70, "badge frame")
                .fill ("M10 0 H90 A10 10 0 0 0 100 10 V90 A10 10 0 0 0 90 100 H10 A10 10 0 0 0 0 90 V10 A10 10 0 0 0 10 0 Z")
                .label (10, 10, 80, 80)
                .ports_box ();
            basic ();
            arrows ();
            callouts ();
            mindmap ();
            brainstorm ();
            infographic ();
        }

        private static void basic () {
            Stencils.shape ("basic-snip-corner", _("Snipped Corner Rectangle"), 120, 70, "cut corner")
                .fill ("M0 0 H82 L100 18 V100 H0 Z")
                .ports_box ();
            Stencils.shape ("basic-snip-same", _("Snipped Same Side Rectangle"), 120, 70, "cut corners tab")
                .fill ("M18 0 H82 L100 18 V100 H0 V18 Z")
                .ports_box ();
            Stencils.shape ("basic-snip-diagonal", _("Snipped Diagonal Rectangle"), 120, 70, "cut corners")
                .fill ("M0 0 H82 L100 18 V100 H18 L0 82 Z")
                .ports_box ();
            Stencils.shape ("basic-round-single", _("Single Round Corner Rectangle"), 120, 70, "rounded corner")
                .fill ("M0 0 H80 A20 20 0 0 1 100 20 V100 H0 Z")
                .ports_box ();
            Stencils.shape ("basic-round-same", _("Round Same Side Rectangle"), 120, 70, "rounded top tab")
                .fill ("M20 0 H80 A20 20 0 0 1 100 20 V100 H0 V20 A20 20 0 0 1 20 0 Z")
                .ports_box ();
            Stencils.shape ("basic-round-diagonal", _("Round Diagonal Rectangle"), 120, 70, "rounded corners leaf")
                .fill ("M20 0 H100 V80 A20 20 0 0 1 80 100 H0 V20 A20 20 0 0 1 20 0 Z")
                .ports_box ();
            Stencils.shape ("basic-half-circle", _("Half Circle"), 100, 50, "semicircle dome")
                .box (100, 50)
                .fill ("M0 50 A50 50 0 0 1 100 50 Z")
                .label (15, 20, 70, 28)
                .port (50, 0).port (100, 50).port (50, 50).port (0, 50);
            Stencils.shape ("basic-quarter-circle", _("Quarter Circle"), 80, 80, "sector")
                .fill ("M0 100 V0 A100 100 0 0 1 100 100 Z")
                .label (5, 45, 55, 50)
                .port (0, 0).port (100, 100).port (0, 100).port (0, 50);
            Stencils.shape ("basic-pie", _("Pie"), 90, 90, "sector slice chart")
                .fill ("M50 50 L50 0 A50 50 0 1 0 100 50 Z")
                .label (15, 45, 45, 35)
                .ports_box ();
            Stencils.shape ("basic-arc", _("Arc"), 100, 50, "curve bow")
                .box (100, 50)
                .line ("M0 50 A50 50 0 0 1 100 50")
                .defaults ("fill-kind:none")
                .port (0, 50).port (50, 0).port (100, 50);
            Stencils.shape ("basic-chord", _("Chord"), 90, 90, "circle segment")
                .fill ("M85.36 85.36 A50 50 0 1 0 14.64 85.36 Z")
                .label (15, 20, 70, 55)
                .ports_box ();
            Stencils.shape ("basic-block-arc", _("Block Arc"), 110, 55, "rainbow arch")
                .box (100, 50)
                .fill ("M0 50 A50 50 0 0 1 100 50 H75 A25 25 0 0 0 25 50 Z")
                .label (0, 50, 100, 20)
                .port (50, 0).port (87.5, 50).port (12.5, 50);
            Stencils.shape ("basic-arch", _("Arch"), 90, 100, "doorway gate")
                .fill ("M0 100 V50 A50 50 0 0 1 100 50 V100 H75 V50 A25 25 0 0 0 25 50 V100 Z")
                .label (0, 100, 100, 20)
                .ports_box ();
            Stencils.shape ("basic-half-frame", _("Half Frame"), 90, 90, "corner frame")
                .fill ("M0 0 H100 L80 20 H20 V80 L0 100 Z")
                .label (25, 25, 70, 70)
                .port (50, 0).port (0, 50);
            Stencils.shape ("basic-l-shape", _("L-Shape"), 90, 90, "corner angle")
                .fill ("M0 0 H40 V60 H100 V100 H0 Z")
                .label (4, 64, 92, 32)
                .port (20, 0).port (100, 80).port (50, 100).port (0, 50);
            Stencils.shape ("basic-cross-diagonal", _("Diagonal Cross"), 80, 80, "x multiply close")
                .fill (StencilKit.poly ({ 15, 0, 50, 35, 85, 0, 100, 15, 65, 50, 100, 85, 85, 100, 50, 65, 15, 100, 0, 85, 35, 50, 0, 15 }))
                .label (0, 100, 100, 20)
                .ports_box ();
            Stencils.shape ("basic-plus-thin", _("Thin Plus"), 80, 80, "cross add")
                .fill (StencilKit.poly ({ 40, 0, 60, 0, 60, 40, 100, 40, 100, 60, 60, 60, 60, 100, 40, 100, 40, 60, 0, 60, 0, 40, 40, 40 }))
                .label (0, 100, 100, 20)
                .ports_box ();
            Stencils.shape ("basic-can-horizontal", _("Horizontal Cylinder"), 120, 60, "drum tube pipe")
                .box (100, 60)
                .fill ("M15 0 H85 A15 30 0 0 1 85 60 H15 A15 30 0 0 1 15 0 Z")
                .line ("M85 0 A15 30 0 0 0 85 60")
                .label (4, 4, 76, 52)
                .port (50, 0).port (100, 30).port (50, 60).port (0, 30);
            Stencils.shape ("basic-cone", _("Cone"), 80, 100, "funnel 3d")
                .fill ("M50 0 L100 86 A50 14 0 0 1 0 86 Z")
                .line ("M0 86 A50 14 0 0 1 100 86")
                .label (20, 50, 60, 30)
                .port (50, 0).port (100, 86).port (50, 100).port (0, 86);
            Stencils.shape ("basic-pyramid", _("Pyramid"), 100, 90, "3d triangle")
                .fill (StencilKit.poly ({ 50, 0, 0, 86, 64, 100 }))
                .shade (StencilKit.poly ({ 50, 0, 64, 100, 100, 80 }))
                .label (15, 60, 45, 30)
                .port (50, 0).port (100, 80).port (64, 100).port (0, 86);
            Stencils.shape ("basic-prism", _("Triangular Prism"), 110, 80, "3d wedge")
                .fill (StencilKit.poly ({ 30, 0, 0, 100, 60, 100 }))
                .shade (StencilKit.poly ({ 30, 0, 70, 0, 100, 100, 60, 100 }))
                .label (0, 100, 100, 20)
                .ports_box ();
            string sun = StencilKit.circle (50, 50, 22);
            for (int i = 0; i < 8; i++) {
                sun += " " + StencilKit.poly (StencilKit.rotate ({ 50, 2, 43, 20, 57, 20 }, i * 45, 50, 50));
            }
            Stencils.shape ("basic-sun", _("Sun"), 90, 90, "weather bright")
                .fill (sun)
                .label (32, 38, 36, 24)
                .ports_box ();
            Stencils.shape ("basic-moon", _("Moon"), 70, 90, "crescent night")
                .fill ("M75 6.7 A50 50 0 1 0 75 93.3 A48 48 0 0 1 75 6.7 Z")
                .label (0, 100, 100, 20)
                .port (75, 7).port (60, 50).port (75, 93).port (0, 50);
            Stencils.shape ("basic-lightning", _("Lightning Bolt"), 70, 100, "flash power storm")
                .fill (StencilKit.poly ({ 40, 0, 78, 0, 56, 36, 82, 36, 24, 100, 40, 52, 16, 52 }))
                .label (0, 100, 100, 20)
                .port (59, 0).port (82, 36).port (24, 100).port (16, 52);
            Stencils.shape ("basic-smiley", _("Smiley Face"), 80, 80, "happy emoji face")
                .fill (StencilKit.circle (50, 50, 50))
                .dark (StencilKit.circle (34, 38, 6) + " " + StencilKit.circle (66, 38, 6))
                .line ("M28 62 A26 26 0 0 0 72 62")
                .label (0, 100, 100, 20)
                .ports_box ();
            Stencils.shape ("basic-teardrop", _("Teardrop"), 70, 90, "drop water")
                .fill ("M50 0 L85 50 A37 37 0 1 1 15 50 Z")
                .label (20, 52, 60, 34)
                .port (50, 0).port (87, 62).port (50, 99).port (13, 62);
            Stencils.shape ("basic-wave", _("Wave"), 120, 70, "banner flag")
                .fill ("M0 15 C25 -5 25 35 50 15 C75 -5 75 35 100 15 V85 C75 105 75 65 50 85 C25 105 25 65 0 85 Z")
                .label (4, 22, 92, 56)
                .ports_box ();
            Stencils.shape ("basic-double-wave", _("Double Wave"), 120, 70, "banner flag")
                .fill ("M0 12 C12 -4 13 28 25 12 C37 -4 38 28 50 12 C62 -4 63 28 75 12 C87 -4 88 28 100 12 V88 C88 104 87 72 75 88 C63 104 62 72 50 88 C38 104 37 72 25 88 C13 104 12 72 0 88 Z")
                .label (4, 20, 92, 60)
                .ports_box ();
            Stencils.shape ("basic-bevel", _("Bevel"), 110, 80, "button raised 3d")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .shade (StencilKit.poly ({ 0, 0, 100, 0, 88, 12, 12, 12 }))
                .shade (StencilKit.poly ({ 0, 0, 12, 12, 12, 88, 0, 100 }))
                .shade (StencilKit.poly ({ 100, 0, 100, 100, 88, 88, 88, 12 }))
                .shade (StencilKit.poly ({ 0, 100, 12, 88, 88, 88, 100, 100 }))
                .fill (StencilKit.rect (12, 12, 76, 76))
                .label (14, 14, 72, 72)
                .ports_box ();
            Stencils.shape ("basic-diagonal-stripe", _("Diagonal Stripe"), 90, 90, "slash band")
                .fill ("M0 50 L50 0 H100 L0 100 Z")
                .label (10, 25, 50, 30)
                .port (25, 25).port (75, 0).port (50, 50).port (0, 75);
            Stencils.shape ("basic-kite", _("Kite"), 80, 100, "deltoid")
                .fill (StencilKit.poly ({ 50, 0, 100, 35, 50, 100, 0, 35 }))
                .label (22, 25, 56, 30)
                .port (50, 0).port (100, 35).port (50, 100).port (0, 35);
            Stencils.shape ("basic-trapezoid-inverted", _("Inverted Trapezoid"), 120, 60, "funnel")
                .fill (StencilKit.poly ({ 0, 0, 100, 0, 80, 100, 20, 100 }))
                .label (18, 6, 64, 88)
                .ports_box ();
            Stencils.shape ("basic-tab-folder", _("Folder Tab"), 120, 80, "directory")
                .fill ("M0 18 V100 H100 V18 H50 L42 0 H6 L0 6 Z")
                .line ("M0 18 H50")
                .label (4, 22, 92, 74)
                .ports_box ();
            Stencils.shape ("basic-no-symbol", _("No Symbol"), 80, 80, "forbidden prohibited stop")
                .fill (StencilKit.ring (50, 50, 50, 36) + " " + StencilKit.poly (StencilKit.rotate ({ 15, 43, 85, 43, 85, 57, 15, 57 }, 45, 50, 50)))
                .label (0, 100, 100, 20)
                .ports_box ();
            Stencils.shape ("basic-bracket-pair", _("Bracket Pair"), 100, 70, "square brackets group")
                .line ("M12 0 H0 V100 H12 M88 0 H100 V100 H88")
                .defaults ("fill-kind:none")
                .label (8, 4, 84, 92)
                .ports_box ();
            Stencils.shape ("basic-brace-pair", _("Brace Pair"), 100, 70, "curly braces group")
                .line ("M14 0 C4 0 7 8 7 20 V40 C7 46 4 50 0 50 C4 50 7 54 7 60 V80 C7 92 4 100 14 100 M86 0 C96 0 93 8 93 20 V40 C93 46 96 50 100 50 C96 50 93 54 93 60 V80 C93 92 96 100 86 100")
                .defaults ("fill-kind:none")
                .label (10, 4, 80, 92)
                .ports_box ();
            Stencils.shape ("basic-left-brace", _("Left Brace"), 30, 100, "curly brace group")
                .line ("M100 0 C40 0 50 10 50 25 V40 C50 46 40 50 0 50 C40 50 50 54 50 60 V75 C50 90 40 100 100 100")
                .defaults ("fill-kind:none")
                .label (-240, 30, 220, 40)
                .port (100, 0).port (0, 50).port (100, 100);
            Stencils.shape ("basic-can-3d", _("Hollow Can"), 80, 100, "cup tube 3d")
                .fill ("M0 12 V88 A50 12 0 0 0 100 88 V12 A50 12 0 0 0 0 12 Z")
                .shade (StencilKit.ellipse (50, 12, 50, 12))
                .fill (StencilKit.ellipse (50, 12, 38, 8))
                .label (4, 30, 92, 56)
                .ports_box ();
            string[] poly_names = { _("Heptagon"), _("Nonagon"), _("Decagon"), _("Hendecagon"), _("Dodecagon") };
            int[] poly_sides = { 7, 9, 10, 11, 12 };
            for (int i = 0; i < poly_sides.length; i++) {
                Stencils.shape ("basic-polygon-%d".printf (poly_sides[i]), poly_names[i], 90, 90, "polygon regular %d sides".printf (poly_sides[i]))
                    .fill (StencilKit.regular (poly_sides[i], 50, 50, 50, 50, -90))
                    .label (18, 18, 64, 64)
                    .ports_box ();
            }
            int[] star_points = { 6, 7, 8, 10, 12, 16, 24, 32 };
            double[] star_inner = { 0.55, 0.55, 0.6, 0.65, 0.72, 0.78, 0.84, 0.88 };
            foreach (int k in star_points) {
                int idx = 0;
                for (int j = 0; j < star_points.length; j++) if (star_points[j] == k) idx = j;
                double inner = star_inner[idx];
                Stencils.shape ("basic-star-%d".printf (k), _("%d-Point Star").printf (k), 90, 90, "star seal burst badge")
                    .fill (StencilKit.star (k, 50, 50, 50, 50, inner))
                    .label (50 - 35 * inner, 50 - 35 * inner, 70 * inner, 70 * inner)
                    .ports_box ();
            }
        }

        private static void arrow_variants (string kind, string name, string keywords, double[] xy, double w, double h, double[] lbl) {
            Stencils.shape (kind, name, w, h, keywords)
                .fill (StencilKit.poly (xy))
                .label (lbl[0], lbl[1], lbl[2], lbl[3])
                .ports_box ();
        }

        private static string curved_arrow (int mode) {
            double[] outer_pts = { 0, 100, 70, 20 };
            double[] head = { 70, 20, 70, 0, 100, 35, 70, 70, 70, 50 };
            double[] inner_pts = { 70, 50, 30, 100 };
            var o = StencilKit.orient (outer_pts, mode);
            var hd = StencilKit.orient (head, mode);
            var ip = StencilKit.orient (inner_pts, mode);
            bool flip = mode == 1 || mode == 2;
            int s1 = flip ? 0 : 1;
            int s2 = flip ? 1 : 0;
            return "M%s %s A80 80 0 0 %d %s %s L%s %s L%s %s L%s %s L%s %s A50 50 0 0 %d %s %s Z".printf (
                n (o[0]), n (o[1]), s1, n (o[2]), n (o[3]), n (hd[2]), n (hd[3]), n (hd[4]), n (hd[5]), n (hd[6]), n (hd[7]), n (hd[8]), n (hd[9]),
                s2, n (ip[2]), n (ip[3]));
        }

        private static string circular_arrow () {
            double cx = 50, cy = 50, ro = 46, ri = 30;
            double a0 = 150, a1 = 390;
            double rm = (ro + ri) / 2;
            var sb = new StringBuilder ();
            double r0 = a0 * Math.PI / 180;
            sb.append ("M%s %s".printf (n (cx + ro * Math.cos (r0)), n (cy + ro * Math.sin (r0))));
            sb.append (StencilKit.arc_to (cx, cy, ro, ro, a0, a1));
            double r1 = a1 * Math.PI / 180;
            double tx = -Math.sin (r1), ty = Math.cos (r1);
            double ox = cx + (ro + 8) * Math.cos (r1), oy = cy + (ro + 8) * Math.sin (r1);
            double ix = cx + (ri - 8) * Math.cos (r1), iy = cy + (ri - 8) * Math.sin (r1);
            double px = cx + rm * Math.cos (r1) + tx * 20, py = cy + rm * Math.sin (r1) + ty * 20;
            sb.append (" L%s %s L%s %s L%s %s".printf (n (ox), n (oy), n (px), n (py), n (ix), n (iy)));
            sb.append (" L%s %s".printf (n (cx + ri * Math.cos (r1)), n (cy + ri * Math.sin (r1))));
            sb.append (StencilKit.arc_to (cx, cy, ri, ri, a1, a0));
            sb.append (" Z");
            return sb.str;
        }

        private static void arrows () {
            Stencils.use_category ("arrows");
            string[] cnames = { _("Curved Up Right Arrow"), _("Curved Up Left Arrow"), _("Curved Down Right Arrow"), _("Curved Right Down Arrow"), _("Curved Left Up Arrow") };
            int[] cmodes = { 0, 1, 2, 3, 4 };
            for (int i = 0; i < cmodes.length; i++) {
                Stencils.shape ("arrow2-curved-%d".printf (i + 1), cnames[i], 100, 100, "curved bent turn")
                    .fill (curved_arrow (cmodes[i]))
                    .label (0, 100, 100, 20)
                    .ports_box ();
            }
            Stencils.shape ("arrow2-circular", _("Circular Arrow"), 90, 90, "cycle loop refresh repeat")
                .fill (circular_arrow ())
                .label (30, 36, 40, 28)
                .ports_box ();
            Stencils.shape ("arrow2-striped-right", _("Striped Right Arrow"), 130, 60, "motion speed")
                .fill (StencilKit.rect (0, 25, 5, 50) + " " + StencilKit.rect (9, 25, 8, 50) + " " + StencilKit.poly ({ 21, 25, 66, 25, 66, 0, 100, 50, 66, 100, 66, 75, 21, 75 }))
                .label (24, 25, 45, 50)
                .ports_box ();
            arrow_variants ("arrow2-bent-right", _("Bent Arrow"), "turn corner", { 0, 100, 0, 38, 68, 38, 68, 16, 100, 48, 68, 80, 68, 58, 20, 58, 20, 100 }, 110, 90, { 22, 40, 44, 16 });
            arrow_variants ("arrow2-bent-up", _("Bent Up Arrow"), "turn corner", { 0, 72, 58, 72, 58, 30, 42, 30, 70, 0, 98, 30, 82, 30, 82, 100, 0, 100 }, 100, 100, { 2, 74, 56, 24 });
            arrow_variants ("arrow2-left-up", _("Left and Up Arrow"), "two way corner", { 0, 72, 22, 50, 22, 62, 62, 62, 62, 22, 50, 22, 72, 0, 94, 22, 82, 22, 82, 82, 22, 82, 22, 94 }, 100, 100, { 22, 64, 40, 16 });
            arrow_variants ("arrow2-left-right-up", _("Left, Right and Up Arrow"), "three way tee", { 0, 76, 20, 56, 20, 68, 42, 68, 42, 22, 30, 22, 50, 0, 70, 22, 58, 22, 58, 68, 80, 68, 80, 56, 100, 76, 80, 96, 80, 84, 20, 84, 20, 96 }, 120, 100, { 25, 69, 50, 14 });
            arrow_variants ("arrow2-notched-left", _("Notched Left Arrow"), "back", StencilKit.orient ({ 0, 25, 62, 25, 62, 0, 100, 50, 62, 100, 62, 75, 0, 75, 12, 50 }, 1), 120, 60, { 28, 25, 60, 50 });
            arrow_variants ("arrow2-pentagon-left", _("Left Pentagon Arrow"), "step process back", StencilKit.orient ({ 0, 0, 70, 0, 100, 50, 70, 100, 0, 100 }, 1), 120, 60, { 30, 4, 66, 92 });
            arrow_variants ("arrow2-chevron-left", _("Left Chevron"), "step back", StencilKit.orient ({ 0, 0, 70, 0, 100, 50, 70, 100, 0, 100, 30, 50 }, 1), 100, 60, { 30, 4, 40, 92 });
            Stencils.shape ("arrow2-double-chevron", _("Double Chevron"), 110, 60, "fast forward next")
                .fill (StencilKit.poly ({ 0, 0, 30, 0, 55, 50, 30, 100, 0, 100, 25, 50 }) + " " + StencilKit.poly ({ 45, 0, 75, 0, 100, 50, 75, 100, 45, 100, 70, 50 }))
                .label (0, 100, 100, 20)
                .ports_box ();
            arrow_variants ("arrow2-fat-right", _("Wide Head Arrow"), "big block", { 0, 32, 50, 32, 50, 0, 100, 50, 50, 100, 50, 68, 0, 68 }, 120, 70, { 2, 32, 60, 36 });
            arrow_variants ("arrow2-slim-right", _("Slim Arrow"), "thin block", { 0, 42, 78, 42, 78, 22, 100, 50, 78, 78, 78, 58, 0, 58 }, 140, 40, { 0, 60, 80, 40 });
            arrow_variants ("arrow2-merge", _("Merge Arrow"), "join converge", { 0, 0, 30, 0, 55, 34, 70, 34, 70, 16, 100, 50, 70, 84, 70, 66, 55, 66, 30, 100, 0, 100, 34, 50 }, 120, 90, { 40, 38, 30, 24 });
            string[] cdir = { _("Right Arrow Callout"), _("Left Arrow Callout"), _("Down Arrow Callout"), _("Up Arrow Callout") };
            int[] cmode = { 0, 1, 3, 4 };
            double[] callout_pts = { 0, 0, 60, 0, 60, 30, 78, 30, 78, 16, 100, 50, 78, 84, 78, 70, 60, 70, 60, 100, 0, 100 };
            for (int i = 0; i < 4; i++) {
                var sd = Stencils.shape ("arrow2-callout-%d".printf (i + 1), cdir[i], i < 2 ? 130 : 90, i < 2 ? 80 : 120, "callout pointer")
                    .fill (StencilKit.poly (StencilKit.orient (callout_pts, cmode[i])))
                    .ports_box ();
                if (i == 0) sd.label (4, 4, 52, 92);
                else if (i == 1) sd.label (44, 4, 52, 92);
                else if (i == 2) sd.label (4, 4, 92, 52);
                else sd.label (4, 44, 92, 52);
            }
            double[] basic_arrow = { 0, 25, 62, 25, 62, 0, 100, 50, 62, 100, 62, 75, 0, 75 };
            string[] diag = { _("Diagonal Up Right Arrow"), _("Diagonal Down Right Arrow"), _("Diagonal Down Left Arrow"), _("Diagonal Up Left Arrow") };
            double[] diag_angles = { -45, 45, 135, 225 };
            for (int i = 0; i < 4; i++) {
                Stencils.shape ("arrow2-diagonal-%d".printf (i + 1), diag[i], 80, 80, "diagonal block direction")
                    .fill (StencilKit.poly (StencilKit.rotate (basic_arrow, diag_angles[i], 50, 50, 0.95)))
                    .label (0, 100, 100, 20)
                    .ports_box ();
            }
            Stencils.shape ("arrow2-uturn-left", _("Left U-Turn Arrow"), 110, 100, "return back")
                .fill ("M100 100 V45 A40 45 0 0 0 20 45 V62 H0 L30 100 L60 62 H40 V45 A20 22 0 0 1 80 45 V100 Z")
                .label (0, 100, 100, 20)
                .ports_box ();
            Stencils.shape ("arrow2-uturn-up", _("Up U-Turn Arrow"), 100, 110, "return back")
                .fill ("M0 0 H55 A45 40 0 0 1 55 80 H38 V100 L0 70 L38 40 V60 H55 A22 20 0 0 0 55 20 H0 Z")
                .label (0, 100, 100, 20)
                .ports_box ();
            Stencils.shape ("arrow2-quad-callout", _("Quad Arrow Callout"), 120, 120, "four way callout")
                .fill (StencilKit.poly ({ 30, 30, 40, 30, 40, 16, 32, 16, 50, 0, 68, 16, 60, 16, 60, 30, 70, 30, 70, 40, 84, 40, 84, 32, 100, 50, 84, 68, 84, 60, 70, 60, 70, 70, 60, 70, 60, 84, 68, 84, 50, 100, 32, 84, 40, 84, 40, 70, 30, 70, 30, 60, 16, 60, 16, 68, 0, 50, 16, 32, 16, 40, 30, 40 }))
                .label (30, 30, 40, 40)
                .ports_box ();
        }

        private static void callouts () {
            Stencils.category ("callouts", _("Callouts"), "draw-shapes-symbolic", StencilGroup.GENERAL);
            string[] rnames = { _("Rectangular Callout, Bottom Left"), _("Rectangular Callout, Bottom Right"), _("Rectangular Callout, Top Left"),
                _("Rectangular Callout, Top Right"), _("Rectangular Callout, Left"), _("Rectangular Callout, Right") };
            string[] rpaths = {
                "M0 0 H100 V72 H40 L15 100 L24 72 H0 Z",
                "M0 0 H100 V72 H76 L85 100 L60 72 H0 Z",
                "M0 28 H24 L15 0 L40 28 H100 V100 H0 Z",
                "M0 28 H60 L85 0 L76 28 H100 V100 H0 Z",
                "M22 0 H100 V100 H22 V62 L0 50 L22 40 Z",
                "M0 0 H78 V40 L100 50 L78 62 V100 H0 Z"
            };
            double[,] rlabels = { { 4, 4, 92, 64 }, { 4, 4, 92, 64 }, { 4, 32, 92, 64 }, { 4, 32, 92, 64 }, { 26, 4, 70, 92 }, { 4, 4, 70, 92 } };
            for (int i = 0; i < 6; i++) {
                Stencils.shape ("callout-rect-%d".printf (i + 1), rnames[i], 140, 90, "speech balloon comment")
                    .fill (rpaths[i])
                    .label (rlabels[i, 0], rlabels[i, 1], rlabels[i, 2], rlabels[i, 3])
                    .ports_box ();
            }
            string[] rrnames = { _("Rounded Callout, Bottom Left"), _("Rounded Callout, Bottom Right"), _("Rounded Callout, Top Left"), _("Rounded Callout, Right") };
            string[] rrpaths = {
                "M12 0 H88 A12 12 0 0 1 100 12 V60 A12 12 0 0 1 88 72 H40 L15 100 L24 72 H12 A12 12 0 0 1 0 60 V12 A12 12 0 0 1 12 0 Z",
                "M12 0 H88 A12 12 0 0 1 100 12 V60 A12 12 0 0 1 88 72 H76 L85 100 L60 72 H12 A12 12 0 0 1 0 60 V12 A12 12 0 0 1 12 0 Z",
                "M12 28 H24 L15 0 L40 28 H88 A12 12 0 0 1 100 40 V88 A12 12 0 0 1 88 100 H12 A12 12 0 0 1 0 88 V40 A12 12 0 0 1 12 28 Z",
                "M12 0 H66 A12 12 0 0 1 78 12 V40 L100 50 L78 62 V88 A12 12 0 0 1 66 100 H12 A12 12 0 0 1 0 88 V12 A12 12 0 0 1 12 0 Z"
            };
            double[,] rrlabels = { { 6, 6, 88, 60 }, { 6, 6, 88, 60 }, { 6, 34, 88, 60 }, { 6, 6, 68, 88 } };
            for (int i = 0; i < 4; i++) {
                Stencils.shape ("callout-rounded-%d".printf (i + 1), rrnames[i], 140, 90, "speech balloon comment rounded")
                    .fill (rrpaths[i])
                    .label (rrlabels[i, 0], rrlabels[i, 1], rrlabels[i, 2], rrlabels[i, 3])
                    .ports_box ();
            }
            Stencils.shape ("callout-oval-1", _("Oval Callout, Bottom Left"), 140, 90, "speech balloon ellipse")
                .fill ("M41.32 75.42 A50 38 0 1 0 25 70.91 L10 100 Z")
                .label (12, 10, 76, 56)
                .ports_box ();
            Stencils.shape ("callout-oval-2", _("Oval Callout, Bottom Right"), 140, 90, "speech balloon ellipse")
                .fill ("M75 70.91 A50 38 0 1 0 58.68 75.42 L90 100 Z")
                .label (12, 10, 76, 56)
                .ports_box ();
            string cloud = "M22 72 C6 72 2 52 14 44 C6 28 26 12 40 22 C46 4 76 4 80 22 C98 22 102 44 90 52 C100 66 86 80 72 74 C64 86 40 86 34 76 C30 76 26 74 22 72 Z";
            Stencils.shape ("callout-cloud-1", _("Thought Bubble, Left"), 140, 100, "cloud think idea")
                .fill (cloud)
                .fill (StencilKit.ellipse (18, 86, 6, 5))
                .fill (StencilKit.ellipse (8, 96, 4, 3.5))
                .label (18, 22, 66, 48)
                .ports_box ();
            Stencils.shape ("callout-cloud-2", _("Thought Bubble, Right"), 140, 100, "cloud think idea")
                .fill (cloud)
                .fill (StencilKit.ellipse (84, 86, 6, 5))
                .fill (StencilKit.ellipse (94, 96, 4, 3.5))
                .label (18, 22, 66, 48)
                .ports_box ();
            Stencils.shape ("callout-line-1", _("Line Callout"), 150, 80, "leader label annotation")
                .fill (StencilKit.rect (30, 0, 70, 60))
                .line (StencilKit.line (30, 60, 0, 100))
                .label (32, 2, 66, 56)
                .port (0, 100).port (65, 0).port (100, 30).port (65, 60);
            Stencils.shape ("callout-line-2", _("Bent Line Callout"), 150, 80, "leader label annotation")
                .fill (StencilKit.rect (30, 0, 70, 60))
                .line ("M30 30 H14 L0 100")
                .label (32, 2, 66, 56)
                .port (0, 100).port (65, 0).port (100, 30).port (65, 60);
            Stencils.shape ("callout-accent-bar", _("Accent Bar Callout"), 150, 80, "leader label annotation")
                .solid (StencilKit.rect (30, 0, 70, 60))
                .line ("M28 0 V60 M28 30 H14 L0 100")
                .defaults ("stroke-width:2")
                .label (32, 2, 66, 56)
                .port (0, 100).port (65, 0).port (100, 30).port (65, 60);
            Stencils.shape ("callout-borderless", _("Borderless Line Callout"), 150, 80, "leader label annotation")
                .line ("M30 60 L0 100 M30 60 H100")
                .defaults ("fill-kind:none")
                .label (30, 0, 70, 58)
                .port (0, 100).port (65, 60);
            Stencils.shape ("callout-note-pin", _("Pinned Note Callout"), 120, 110, "sticky note comment")
                .fill ("M0 10 H100 V78 H40 L20 100 L26 78 H0 Z")
                .dark (StencilKit.circle (50, 10, 5))
                .label (4, 18, 92, 56)
                .ports_box ();
            Stencils.shape ("callout-double-bubble", _("Conversation Callout"), 150, 100, "dialog chat reply")
                .fill ("M0 0 H70 V50 H26 L12 66 L16 50 H0 Z")
                .fill ("M30 40 H100 V90 H88 L92 100 L76 90 H30 Z")
                .label (34, 44, 62, 42)
                .ports_box ();
        }

        private static void mindmap () {
            Stencils.category ("mindmap", _("Mind Map"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            Stencils.shape ("mind-central", _("Central Topic"), 190, 90, "main idea root center")
                .fill (StencilKit.rrect (0, 0, 100, 100, 30))
                .defaults ("fill:#dcebf7;stroke:#2f5f8f;stroke-width:2.5;bold:1;font-size:16")
                .text (_("Central Topic"))
                .label (8, 8, 84, 84)
                .ports_eight ();
            Stencils.shape ("mind-main", _("Main Topic"), 150, 60, "branch idea")
                .fill (StencilKit.rrect (0, 0, 100, 100, 18))
                .defaults ("fill:#f1f8ee;stroke:#2e7d32;stroke-width:2;font-size:13")
                .text (_("Main Topic"))
                .ports_box ();
            Stencils.shape ("mind-subtopic", _("Subtopic"), 120, 34, "leaf detail underline")
                .line (StencilKit.line (0, 100, 100, 100))
                .defaults ("fill-kind:none;stroke:#2f5f8f;stroke-width:2")
                .text (_("Subtopic"))
                .label (2, 0, 96, 92)
                .port (0, 100).port (100, 100).port (50, 0);
            Stencils.shape ("mind-floating", _("Floating Topic"), 130, 50, "free idea detached")
                .fill (StencilKit.rrect (0, 0, 100, 100, 20))
                .defaults ("dash:dash;fill:#fdf4e8;stroke:#c75c12")
                .text (_("Floating Topic"))
                .ports_box ();
            Stencils.shape ("mind-idea-cloud", _("Idea Cloud"), 150, 100, "thought brainstorm")
                .fill ("M22 90 C6 90 0 70 12 60 C2 42 22 22 38 32 C44 10 74 8 80 28 C98 26 104 52 90 62 C100 78 84 96 68 88 C60 100 36 100 30 92 C27 91 25 90 22 90 Z")
                .defaults ("fill:#fff6c9;stroke:#b59a2b")
                .label (20, 32, 62, 50)
                .ports_box ();
            Stencils.shape ("mind-note", _("Topic Note"), 120, 80, "comment memo")
                .fill ("M0 0 H82 L100 18 V100 H0 Z")
                .shade ("M82 0 V18 H100 Z")
                .defaults ("fill:#fff6c9;stroke:#b59a2b;halign:left;valign:top")
                .label (6, 6, 80, 88)
                .ports_box ();
            Stencils.shape ("mind-boundary", _("Boundary"), 320, 200, "group enclose region")
                .fill (StencilKit.rrect (0, 0, 100, 100, 12))
                .defaults ("dash:dash;fill:#eef5fc80;stroke:#5b9bd5;valign:top;halign:left")
                .label (4, 3, 92, 16)
                .as_container ()
                .ports_box ();
            Stencils.shape ("mind-callout", _("Topic Callout"), 130, 70, "comment balloon")
                .fill ("M12 0 H88 A12 12 0 0 1 100 12 V60 A12 12 0 0 1 88 72 H40 L22 100 L26 72 H12 A12 12 0 0 1 0 60 V12 A12 12 0 0 1 12 0 Z")
                .defaults ("fill:#ece4f7;stroke:#5a3a8f")
                .label (6, 6, 88, 60)
                .ports_box ();
            Stencils.shape ("mind-branch", _("Branch Curve"), 120, 60, "link curve connector line")
                .line ("M0 100 C45 100 55 0 100 0")
                .defaults ("fill-kind:none;stroke:#2f5f8f;stroke-width:3")
                .label (0, 100, 100, 20)
                .port (0, 100).port (100, 0);
            string[] pr_colors = { "#c62828", "#f08a3c", "#f5c518" };
            for (int i = 0; i < 3; i++) {
                Stencils.shape ("mind-priority-%d".printf (i + 1), _("Priority %d").printf (i + 1), 28, 28, "priority marker number")
                    .fill (StencilKit.circle (50, 50, 50))
                    .defaults ("fill:%s;stroke:#ffffff;stroke-width:1.5;text-color:#ffffff;bold:1;font-size:10".printf (pr_colors[i]))
                    .text ((i + 1).to_string ())
                    .label (0, 0, 100, 100)
                    .ports_box ();
            }
            Stencils.shape ("mind-flag", _("Flag Marker"), 30, 36, "marker flag")
                .line ("M10 0 V100")
                .fill ("M10 4 H90 L74 26 L90 48 H10 Z")
                .defaults ("fill:#e5534b;stroke:#8e1c1c;stroke-width:1.5")
                .label_below ()
                .port (10, 100);
            Stencils.shape ("mind-check", _("Done Marker"), 28, 28, "task complete check")
                .fill (StencilKit.circle (50, 50, 50))
                .ink ("M26 52 L44 70 L76 32", "@light")
                .defaults ("fill:#2e7d32;stroke:#1b5e20;stroke-width:2.5")
                .label_below ()
                .ports_box ();
        }

        private static void brainstorm () {
            Stencils.category ("brainstorm", _("Brainstorming"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            Stencils.shape ("brain-main-idea", _("Main Idea"), 170, 100, "central problem topic")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .defaults ("stroke-width:3;bold:1;font-size:14;fill:#fde7d4;stroke:#c75c12")
                .text (_("Main Idea"))
                .label (15, 15, 70, 70)
                .ports_eight ();
            Stencils.shape ("brain-topic", _("Idea"), 130, 60, "topic thought")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .defaults ("fill:#fff6c9;stroke:#b59a2b")
                .label (14, 14, 72, 72)
                .ports_box ();
            string[] sticky_names = { _("Yellow Sticky Note"), _("Pink Sticky Note"), _("Blue Sticky Note"), _("Green Sticky Note") };
            string[] sticky_fill = { "#fff39a", "#f9c6d8", "#bfe0f7", "#cdeec0" };
            string[] sticky_ids = { "yellow", "pink", "blue", "green" };
            for (int i = 0; i < 4; i++) {
                Stencils.shape ("brain-sticky-%s".printf (sticky_ids[i]), sticky_names[i], 100, 100, "post-it sticky note card")
                    .fill ("M0 0 H100 V82 L82 100 H0 Z")
                    .shade ("M82 100 V82 H100 Z")
                    .defaults ("fill:%s;stroke:#8a7a3a;stroke-width:1;shadow:1;halign:left;valign:top".printf (sticky_fill[i]))
                    .label (6, 6, 88, 76)
                    .ports_box ();
            }
            Stencils.shape ("brain-lightbulb", _("Light Bulb"), 50, 70, "idea insight eureka")
                .fill ("M50 0 C22 0 6 20 6 40 C6 56 18 64 26 74 V82 H74 V74 C82 64 94 56 94 40 C94 20 78 0 50 0 Z")
                .shade (StencilKit.rect (30, 84, 40, 8))
                .shade ("M34 94 H66 L60 100 H40 Z")
                .line ("M40 74 L44 50 H56 L60 74")
                .defaults ("fill:#fff39a;stroke:#8a6d00")
                .label_below ()
                .ports_box ();
            Stencils.shape ("brain-question", _("Open Question"), 50, 50, "question ask unknown")
                .fill (StencilKit.circle (50, 50, 50))
                .defaults ("fill:#e3eefb;stroke:#1f4e79;bold:1;font-size:18;text-color:#1f4e79")
                .text ("?")
                .label (0, 0, 100, 100)
                .ports_box ();
            Stencils.shape ("brain-cluster", _("Idea Cluster"), 300, 200, "group affinity cluster")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .defaults ("dash:dash;fill:#f4f8fc80;stroke:#5b9bd5;valign:top")
                .label (20, 6, 60, 16)
                .as_container ()
                .ports_box ();
        }

        private static void infographic () {
            Stencils.category ("infographic", _("Infographics"), "draw-shapes-symbolic", StencilGroup.GENERAL);
            Stencils.shape ("info-number-circle", _("Numbered Circle"), 60, 60, "step number count")
                .fill (StencilKit.circle (50, 50, 50))
                .defaults ("fill:#3a6ea5;stroke:#1f4e79;text-color:#ffffff;bold:1;font-size:18")
                .text ("1")
                .label (0, 0, 100, 100)
                .ports_box ();
            Stencils.shape ("info-number-ring", _("Numbered Ring"), 60, 60, "step number count")
                .fill (StencilKit.ring (50, 50, 50, 40))
                .defaults ("fill:#3a6ea5;stroke:#1f4e79;text-color:#1f4e79;bold:1;font-size:18")
                .text ("1")
                .label (0, 0, 100, 100)
                .ports_box ();
            Stencils.shape ("info-step-block", _("Step Block"), 140, 60, "stage phase numbered chevron")
                .fill (StencilKit.poly ({ 0, 0, 82, 0, 100, 50, 82, 100, 0, 100 }))
                .dark (StencilKit.rect (0, 0, 22, 100))
                .label (26, 4, 56, 92)
                .ports_box ();
            Stencils.shape ("info-ribbon", _("Ribbon Banner"), 180, 60, "title banner heading")
                .shade (StencilKit.poly ({ 0, 30, 18, 30, 18, 100, 0, 100, 8, 65 }))
                .shade (StencilKit.poly ({ 100, 30, 82, 30, 82, 100, 100, 100, 92, 65 }))
                .fill (StencilKit.rect (10, 0, 80, 82))
                .label (12, 4, 76, 74)
                .ports_box ();
            string ros = StencilKit.star (20, 50, 36, 36, 36, 0.86);
            Stencils.shape ("info-rosette", _("Award Rosette"), 70, 90, "medal award badge prize")
                .fill (StencilKit.poly ({ 30, 60, 20, 100, 34, 92, 42, 100, 48, 66 }))
                .fill (StencilKit.poly ({ 70, 60, 80, 100, 66, 92, 58, 100, 52, 66 }))
                .fill (ros)
                .fill (StencilKit.circle (50, 36, 26))
                .label (26, 22, 48, 28)
                .ports_box ();
            Stencils.shape ("info-progress-3", _("Three Step Progress"), 180, 40, "stepper steps progress")
                .box (180, 40)
                .line ("M20 20 H160")
                .fill (StencilKit.circle (20, 20, 16))
                .fill (StencilKit.circle (90, 20, 16))
                .fill (StencilKit.circle (160, 20, 16))
                .label (0, 40, 180, 20)
                .port (0, 20).port (180, 20);
            Stencils.shape ("info-progress-5", _("Five Step Progress"), 240, 40, "stepper steps progress")
                .box (240, 40)
                .line ("M20 20 H220")
                .fill (StencilKit.circle (20, 20, 14))
                .fill (StencilKit.circle (70, 20, 14))
                .fill (StencilKit.circle (120, 20, 14))
                .fill (StencilKit.circle (170, 20, 14))
                .fill (StencilKit.circle (220, 20, 14))
                .label (0, 40, 240, 20)
                .port (0, 20).port (240, 20);
            double[] pct = { 25, 50, 75 };
            foreach (double p in pct) {
                double end = -90 + 360 * p / 100;
                double re = end * Math.PI / 180;
                string seg = StencilKit.arc (50, 50, 50, 50, -90, end) + " L%s %s".printf (n (50 + 34 * Math.cos (re)), n (50 + 34 * Math.sin (re)))
                    + StencilKit.arc_to (50, 50, 34, 34, end, -90) + " Z";
                Stencils.shape ("info-ring-%d".printf ((int) p), _("Progress Ring %d%%").printf ((int) p), 80, 80, "donut percent gauge kpi")
                    .fill (StencilKit.ring (50, 50, 50, 34))
                    .dark (seg)
                    .defaults ("bold:1;font-size:14")
                    .text ("%d%%".printf ((int) p))
                    .label (20, 30, 60, 40)
                    .ports_box ();
            }
            Stencils.shape ("info-tag", _("Price Tag"), 110, 60, "label tag sale")
                .fill ("M0 0 H74 L100 50 L74 100 H0 Z " + StencilKit.ellipse_rev (80, 50, 5, 8))
                .label (4, 4, 66, 92)
                .ports_box ();
            Stencils.shape ("info-pin", _("Location Pin"), 50, 70, "map marker place")
                .fill ("M50 100 C50 100 8 56 8 38 A42 38 0 1 1 92 38 C92 56 50 100 50 100 Z " + StencilKit.ellipse_rev (50, 38, 16, 14))
                .label_below ()
                .port (50, 100).port (50, 0);
            Stencils.shape ("info-shield", _("Shield"), 70, 80, "security badge protect")
                .fill ("M50 0 L100 14 V46 C100 74 76 92 50 100 C24 92 0 74 0 46 V14 Z")
                .label (14, 18, 72, 50)
                .ports_box ();
            Stencils.shape ("info-hexagon-badge", _("Hexagon Badge"), 70, 80, "badge honeycomb")
                .fill (StencilKit.regular (6, 50, 50, 50, 50, -90))
                .fill (StencilKit.regular (6, 50, 50, 38, 38, -90))
                .label (22, 30, 56, 40)
                .ports_box ();
            Stencils.shape ("info-bars", _("Bar Chart Icon"), 80, 70, "chart graph statistics")
                .line ("M0 100 H100")
                .fill (StencilKit.rect (8, 55, 20, 45))
                .fill (StencilKit.rect (40, 30, 20, 70))
                .fill (StencilKit.rect (72, 8, 20, 92))
                .label_below ()
                .ports_box ();
            Stencils.shape ("info-pie-slice", _("Exploded Pie"), 80, 80, "chart pie share")
                .fill ("M46 46 L46 2 A44 44 0 1 0 90 46 Z")
                .shade ("M54 38 L54 0 A44 44 0 0 1 98 38 Z")
                .label_below ()
                .ports_box ();
            Stencils.shape ("info-steps-3", _("Three Step Chevrons"), 240, 60, "process stages chevron")
                .box (300, 100)
                .fill (StencilKit.poly ({ 0, 0, 80, 0, 100, 50, 80, 100, 0, 100 }))
                .fill (StencilKit.poly ({ 100, 0, 180, 0, 200, 50, 180, 100, 100, 100, 120, 50 }))
                .fill (StencilKit.poly ({ 200, 0, 280, 0, 300, 50, 280, 100, 200, 100, 220, 50 }))
                .label (0, 100, 300, 24)
                .port (0, 50).port (300, 50);
            string cyc = "";
            for (int i = 0; i < 4; i++) {
                double a0 = -80 + i * 90, a1 = a0 + 60;
                double r1 = a1 * Math.PI / 180;
                double tx = -Math.sin (r1), ty = Math.cos (r1);
                double hx = 50 + 40 * Math.cos (r1), hy = 50 + 40 * Math.sin (r1);
                cyc += StencilKit.arc (50, 50, 46, 46, a0, a1) + " L%s %s L%s %s L%s %s".printf (n (50 + 54 * Math.cos (r1)), n (50 + 54 * Math.sin (r1)),
                    n (hx + tx * 16), n (hy + ty * 16), n (50 + 26 * Math.cos (r1)), n (50 + 26 * Math.sin (r1)))
                    + " L%s %s".printf (n (50 + 34 * Math.cos (r1)), n (50 + 34 * Math.sin (r1))) + StencilKit.arc_to (50, 50, 34, 34, a1, a0) + " Z ";
            }
            Stencils.shape ("info-cycle-4", _("Four Step Cycle"), 110, 110, "cycle loop pdca iteration")
                .fill (cyc.strip ())
                .label (30, 36, 40, 28)
                .ports_box ();
            Stencils.shape ("info-number-square", _("Numbered Card"), 120, 80, "fact card numbered")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .dark (StencilKit.rect (0, 0, 24, 34))
                .label (28, 6, 68, 88)
                .ports_box ();
        }
    }
}
