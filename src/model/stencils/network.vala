namespace Singularity.Apps.Draw {

    public class TechPen {
        private StringBuilder sb = new StringBuilder ();
        private double ox;
        private double oy;
        private double k;

        public TechPen (double x = 0, double y = 0, double size = 24) {
            ox = x;
            oy = y;
            k = size / 24.0;
        }

        private static string n (double v) {
            return PathData.fmt (v, 2);
        }

        private void pt (double u, double v) {
            sb.append (n (ox + u * k));
            sb.append_c (' ');
            sb.append (n (oy + v * k));
            sb.append_c (' ');
        }

        public unowned TechPen m (double u, double v) {
            sb.append ("M");
            pt (u, v);
            return this;
        }

        public unowned TechPen l (double u, double v) {
            sb.append ("L");
            pt (u, v);
            return this;
        }

        public unowned TechPen c (double u1, double v1, double u2, double v2, double u, double v) {
            sb.append ("C");
            pt (u1, v1);
            pt (u2, v2);
            pt (u, v);
            return this;
        }

        public unowned TechPen q (double u1, double v1, double u, double v) {
            sb.append ("Q");
            pt (u1, v1);
            pt (u, v);
            return this;
        }

        public unowned TechPen a (double rx, double ry, bool large, bool sweep, double u, double v) {
            sb.append ("A");
            sb.append (n (rx * k));
            sb.append_c (' ');
            sb.append (n (ry * k));
            sb.append (" 0 ");
            sb.append (large ? "1 " : "0 ");
            sb.append (sweep ? "1 " : "0 ");
            pt (u, v);
            return this;
        }

        public unowned TechPen z () {
            sb.append ("Z ");
            return this;
        }

        public unowned TechPen line (double u1, double v1, double u2, double v2) {
            return m (u1, v1).l (u2, v2);
        }

        public unowned TechPen poly (double[] p, bool close = true) {
            for (int i = 0; i + 1 < p.length; i += 2) {
                if (i == 0) m (p[i], p[i + 1]);
                else l (p[i], p[i + 1]);
            }
            if (close) z ();
            return this;
        }

        public unowned TechPen rect (double u, double v, double w, double h) {
            return poly ({ u, v, u + w, v, u + w, v + h, u, v + h });
        }

        public unowned TechPen round (double u, double v, double w, double h, double r) {
            r = double.min (r, double.min (w, h) / 2);
            m (u + r, v).l (u + w - r, v).a (r, r, false, true, u + w, v + r).l (u + w, v + h - r).a (r, r, false, true, u + w - r, v + h);
            l (u + r, v + h).a (r, r, false, true, u, v + h - r).l (u, v + r).a (r, r, false, true, u + r, v).z ();
            return this;
        }

        public unowned TechPen ellipse (double cu, double cv, double rx, double ry) {
            m (cu - rx, cv).a (rx, ry, false, true, cu + rx, cv).a (rx, ry, false, true, cu - rx, cv).z ();
            return this;
        }

        public unowned TechPen circle (double cu, double cv, double r) {
            return ellipse (cu, cv, r, r);
        }

        public unowned TechPen arc (double cu, double cv, double r, double a1, double a2) {
            double x1 = cu + r * Math.cos (a1 * Math.PI / 180), y1 = cv + r * Math.sin (a1 * Math.PI / 180);
            double x2 = cu + r * Math.cos (a2 * Math.PI / 180), y2 = cv + r * Math.sin (a2 * Math.PI / 180);
            double sweep = a2 - a1;
            m (x1, y1).a (r, r, sweep.abs () > 180, sweep > 0, x2, y2);
            return this;
        }

        public unowned TechPen star (double cu, double cv, double r1, double r2, int count, double start = -90) {
            for (int i = 0; i < count * 2; i++) {
                double ang = (start + i * 180.0 / count) * Math.PI / 180;
                double r = i % 2 == 0 ? r1 : r2;
                if (i == 0) m (cu + r * Math.cos (ang), cv + r * Math.sin (ang));
                else l (cu + r * Math.cos (ang), cv + r * Math.sin (ang));
            }
            return z ();
        }

        public unowned TechPen regular (double cu, double cv, double r, int count, double start = -90) {
            for (int i = 0; i < count; i++) {
                double ang = (start + i * 360.0 / count) * Math.PI / 180;
                if (i == 0) m (cu + r * Math.cos (ang), cv + r * Math.sin (ang));
                else l (cu + r * Math.cos (ang), cv + r * Math.sin (ang));
            }
            return z ();
        }

        public unowned TechPen zigzag (double u1, double v, double u2, int teeth, double amp) {
            m (u1, v);
            double step = (u2 - u1) / (teeth * 2);
            for (int i = 0; i < teeth * 2; i++) l (u1 + step * (i + 0.5), v + (i % 2 == 0 ? -amp : amp));
            l (u2, v);
            return this;
        }

        public unowned TechPen arrow (double u1, double v1, double u2, double v2, double head = 3) {
            line (u1, v1, u2, v2);
            double ang = Math.atan2 (v2 - v1, u2 - u1);
            double a1 = ang + Math.PI * 0.8, a2 = ang - Math.PI * 0.8;
            m (u2 + head * Math.cos (a1), v2 + head * Math.sin (a1)).l (u2, v2).l (u2 + head * Math.cos (a2), v2 + head * Math.sin (a2));
            return this;
        }

        public string str () {
            return sb.str.strip ();
        }
    }

    public class TechGlyphs {
        public static string draw (string id, double x, double y, double s) {
            var p = new TechPen (x, y, s);
            switch (id) {
                case "globe":
                    p.circle (12, 12, 9).ellipse (12, 12, 4, 9).line (3, 12, 21, 12).line (5, 7.5, 19, 7.5).line (5, 16.5, 19, 16.5);
                    break;
                case "mail":
                    p.rect (3, 6, 18, 12).m (3, 6).l (12, 13).l (21, 6);
                    break;
                case "folder":
                    p.poly ({ 3, 7, 9, 7, 11, 9, 21, 9, 21, 19, 3, 19 });
                    break;
                case "database":
                    p.ellipse (12, 6, 7, 2.5).m (5, 6).l (5, 18).a (7, 2.5, false, false, 19, 18).l (19, 6).m (5, 12).a (7, 2.5, false, false, 19, 12);
                    break;
                case "gear":
                    p.star (12, 12, 9, 7, 8, -90).circle (12, 12, 3);
                    break;
                case "swap":
                    p.arrow (4, 9, 20, 9).arrow (20, 15, 4, 15);
                    break;
                case "book":
                    p.rect (5, 4, 14, 16).line (8, 4, 8, 20).line (11, 9, 16, 9).line (11, 12, 16, 12);
                    break;
                case "printer":
                    p.rect (7, 4, 10, 5).rect (3, 9, 18, 8).rect (7, 14, 10, 6);
                    break;
                case "stack":
                    p.rect (3, 9, 12, 12).poly ({ 6, 9, 6, 6, 18, 6, 18, 18, 15, 18 }, false).poly ({ 9, 6, 9, 3, 21, 3, 21, 15, 18, 15 }, false);
                    break;
                case "vm":
                    p.rect (3, 4, 18, 13).rect (7, 7, 10, 7).line (9, 21, 15, 21).line (12, 17, 12, 21);
                    break;
                case "cpu":
                    p.rect (6, 6, 12, 12).rect (9, 9, 6, 6);
                    for (int i = 0; i < 3; i++) {
                        double o = 8 + i * 4;
                        p.line (o, 3, o, 6).line (o, 18, o, 21).line (3, o, 6, o).line (18, o, 21, o);
                    }
                    break;
                case "scale":
                    p.rect (8, 8, 8, 8).arrow (8, 8, 3, 3).arrow (16, 8, 21, 3).arrow (16, 16, 21, 21).arrow (8, 16, 3, 21);
                    break;
                case "container":
                    p.rect (3, 12, 8, 8).rect (13, 12, 8, 8).rect (8, 3, 8, 8);
                    break;
                case "cluster":
                    p.regular (12, 6, 4, 6, 0).regular (6, 17, 4, 6, 0).regular (18, 17, 4, 6, 0).line (10, 9.5, 8, 13.5).line (14, 9.5, 16, 13.5).line (10, 17, 14, 17);
                    break;
                case "bolt":
                    p.poly ({ 14, 2, 5, 14, 11, 14, 9, 22, 19, 9, 13, 9 });
                    break;
                case "app":
                    p.round (3, 4, 18, 16, 2).line (3, 8, 21, 8).rect (6, 11, 5, 6).line (13, 12, 18, 12).line (13, 15, 18, 15);
                    break;
                case "layers":
                    p.poly ({ 12, 3, 21, 8, 12, 13, 3, 8 }).poly ({ 3, 12, 12, 17, 21, 12 }, false).poly ({ 3, 16, 12, 21, 21, 16 }, false);
                    break;
                case "edge":
                    p.circle (12, 12, 8).circle (12, 12, 2).circle (4, 4, 2).circle (20, 4, 2).circle (4, 20, 2).circle (20, 20, 2);
                    break;
                case "dns":
                    p.line (12, 3, 12, 21).poly ({ 5, 5, 18, 5, 21, 8, 18, 11, 5, 11 }).poly ({ 19, 13, 6, 13, 3, 16, 6, 19, 19, 19 });
                    break;
                case "balancer":
                    p.circle (12, 5, 2.5).arrow (12, 8, 4, 19).arrow (12, 8, 12, 19).arrow (12, 8, 20, 19);
                    break;
                case "api":
                    p.poly ({ 8, 5, 3, 12, 8, 19 }, false).poly ({ 16, 5, 21, 12, 16, 19 }, false).line (14, 4, 10, 20);
                    break;
                case "cloud":
                    p.m (7, 18).c (2, 18, 2, 11, 7, 11).c (7, 6, 14, 5, 15, 9).c (19, 7, 22, 11, 20, 14).c (23, 16, 21, 18, 19, 18).z ();
                    break;
                case "vpc":
                    p.m (7, 18).c (2, 18, 2, 11, 7, 11).c (7, 6, 14, 5, 15, 9).c (19, 7, 22, 11, 20, 14).c (23, 16, 21, 18, 19, 18).z ().rect (10, 13, 5, 4).arc (12.5, 13, 1.8, 180, 360);
                    break;
                case "nat":
                    p.arrow (3, 7, 21, 17).arrow (3, 17, 21, 7);
                    break;
                case "vpn":
                    p.rect (8, 11, 8, 7).arc (12, 11, 3, 180, 360).line (2, 6, 22, 6).line (2, 21, 22, 21);
                    break;
                case "link":
                    p.rect (2, 9, 6, 6).rect (16, 9, 6, 6).line (8, 12, 16, 12).line (4, 9, 4, 6).line (20, 9, 20, 6);
                    break;
                case "wall":
                    p.rect (3, 5, 18, 14).line (3, 9.7, 21, 9.7).line (3, 14.3, 21, 14.3).line (9, 5, 9, 9.7).line (15, 5, 15, 9.7).line (12, 9.7, 12, 14.3).line (6, 9.7, 6, 14.3).line (18, 9.7, 18, 14.3).line (9, 14.3, 9, 19).line (15, 14.3, 15, 19);
                    break;
                case "shield":
                    p.m (12, 3).l (20, 6).c (20, 14, 17, 19, 12, 21).c (7, 19, 4, 14, 4, 6).z ();
                    break;
                case "shieldbolt":
                    p.m (12, 3).l (20, 6).c (20, 14, 17, 19, 12, 21).c (7, 19, 4, 14, 4, 6).z ().poly ({ 13, 7, 9, 13, 12, 13, 11, 17, 15, 11, 12, 11 });
                    break;
                case "person":
                    p.circle (12, 8, 4).m (4, 21).c (4, 15, 8, 13, 12, 13).c (16, 13, 20, 15, 20, 21);
                    break;
                case "people":
                    p.circle (9, 8, 3.5).m (2, 20).c (2, 15, 5, 13, 9, 13).c (13, 13, 16, 15, 16, 20).circle (17, 7, 3).m (15, 12).c (19, 12, 22, 13, 22, 18);
                    break;
                case "iam":
                    p.circle (10, 8, 4).m (3, 21).c (3, 15, 6, 13, 10, 13).c (12, 13, 13, 13.5, 14, 14).circle (18, 15, 2.5).line (18, 17.5, 18, 22).line (18, 20, 20, 20);
                    break;
                case "key":
                    p.circle (7, 12, 4).line (11, 12, 21, 12).line (18, 12, 18, 16).line (21, 12, 21, 15);
                    break;
                case "lock":
                    p.round (5, 10, 14, 11, 1.5).m (8, 10).l (8, 7).a (4, 4, false, true, 16, 7).l (16, 10).circle (12, 15, 1.5);
                    break;
                case "certificate":
                    p.rect (3, 4, 18, 12).line (6, 8, 18, 8).line (6, 11, 13, 11).circle (16, 15, 3).poly ({ 14, 17.5, 13, 22, 16, 20, 19, 22, 18, 17.5 }, false);
                    break;
                case "bucket":
                    p.ellipse (12, 6, 8, 2.5).m (4, 6).l (6, 19).a (6, 2, false, false, 18, 19).l (20, 6);
                    break;
                case "disk":
                    p.ellipse (12, 8, 8, 3).m (4, 8).l (4, 16).a (8, 3, false, false, 20, 16).l (20, 8).circle (12, 8, 1);
                    break;
                case "archive":
                    p.rect (3, 4, 18, 5).rect (4, 9, 16, 11).line (9, 12, 15, 12);
                    break;
                case "backup":
                    p.arc (12, 12, 8, -150, 150).m (3, 5).l (5, 9).l (9, 7).line (12, 7, 12, 12).line (12, 12, 15, 14);
                    break;
                case "table":
                    p.rect (3, 4, 18, 16).line (3, 9, 21, 9).line (3, 14, 21, 14).line (9, 4, 9, 20).line (15, 4, 15, 20);
                    break;
                case "document":
                    p.poly ({ 5, 3, 15, 3, 19, 7, 19, 21, 5, 21 }).poly ({ 15, 3, 15, 7, 19, 7 }, false).line (8, 11, 16, 11).line (8, 14, 16, 14).line (8, 17, 13, 17);
                    break;
                case "cache":
                    p.rect (3, 7, 18, 10).line (6, 17, 6, 20).line (10, 17, 10, 20).line (14, 17, 14, 20).line (18, 17, 18, 20).poly ({ 13, 8, 9, 13, 12, 13, 11, 16, 15, 11, 12, 11 });
                    break;
                case "warehouse":
                    p.poly ({ 2, 10, 12, 4, 22, 10 }, false).rect (4, 10, 16, 10).rect (7, 13, 3, 7).rect (14, 13, 3, 7);
                    break;
                case "lake":
                    p.m (2, 9).q (5, 6, 8, 9).q (11, 12, 14, 9).q (17, 6, 20, 9).m (2, 14).q (5, 11, 8, 14).q (11, 17, 14, 14).q (17, 11, 20, 14).m (2, 19).q (5, 16, 8, 19).q (11, 22, 14, 19).q (17, 16, 20, 19);
                    break;
                case "pipeline":
                    p.rect (2, 9, 6, 6).rect (16, 9, 6, 6).circle (12, 12, 3).arrow (8, 12, 9, 12, 1.5).arrow (15, 12, 16, 12, 1.5);
                    break;
                case "queue":
                    p.rect (3, 8, 4, 8).rect (9, 8, 4, 8).rect (15, 8, 4, 8).arrow (1, 20, 23, 20);
                    break;
                case "broadcast":
                    p.circle (12, 12, 2).arc (12, 12, 6, -45, 45).arc (12, 12, 6, 135, 225).arc (12, 12, 10, -45, 45).arc (12, 12, 10, 135, 225);
                    break;
                case "bus":
                    p.line (2, 12, 22, 12).circle (6, 6, 2).circle (18, 6, 2).circle (6, 18, 2).circle (18, 18, 2).line (6, 8, 6, 12).line (18, 8, 18, 12).line (6, 12, 6, 16).line (18, 12, 18, 16);
                    break;
                case "bell":
                    p.m (6, 17).l (6, 11).a (6, 6, false, true, 18, 11).l (18, 17).l (20, 19).l (4, 19).z ().arc (12, 19, 2.2, 0, 180);
                    break;
                case "workflow":
                    p.rect (2, 3, 7, 5).rect (15, 10, 7, 5).rect (2, 17, 7, 5).m (9, 5.5).l (18.5, 5.5).l (18.5, 10).m (15, 12.5).l (5.5, 12.5).l (5.5, 17);
                    break;
                case "pulse":
                    p.rect (2, 4, 20, 16).poly ({ 4, 13, 8, 13, 10, 8, 13, 17, 15, 11, 16, 13, 20, 13 }, false);
                    break;
                case "log":
                    p.rect (4, 3, 16, 18).line (7, 7, 17, 7).line (7, 10, 17, 10).line (7, 13, 14, 13).line (7, 16, 16, 16);
                    break;
                case "trace":
                    p.rect (3, 4, 12, 3).rect (7, 9, 10, 3).rect (10, 14, 10, 3).rect (5, 19, 6, 2);
                    break;
                case "alert":
                    p.poly ({ 12, 3, 22, 20, 2, 20 }).line (12, 9, 12, 14).line (12, 16.5, 12, 17.5);
                    break;
                case "hub":
                    p.circle (12, 14, 4).circle (4, 6, 2).circle (20, 6, 2).circle (4, 21, 1.5).circle (20, 21, 1.5).line (6, 7.5, 9, 11).line (18, 7.5, 15, 11).line (5, 20, 9, 17).line (19, 20, 15, 17).line (12, 10, 12, 3);
                    break;
                case "iot":
                    p.rect (7, 10, 10, 10).rect (10, 13, 4, 4).arc (12, 10, 4, 225, 315).arc (12, 10, 7, 225, 315);
                    break;
                case "neural":
                    p.circle (5, 6, 2).circle (5, 18, 2).circle (12, 12, 2).circle (12, 4, 2).circle (12, 20, 2).circle (19, 12, 2);
                    p.line (7, 6, 10, 4).line (7, 6, 10, 12).line (7, 18, 10, 12).line (7, 18, 10, 20).line (14, 4, 17, 12).line (14, 12, 17, 12).line (14, 20, 17, 12);
                    break;
                case "notebook":
                    p.rect (6, 3, 14, 18).line (9, 3, 9, 21).line (4, 6, 8, 6).line (4, 10, 8, 10).line (4, 14, 8, 14).line (4, 18, 8, 18).line (12, 8, 17, 8);
                    break;
                case "chart":
                    p.line (3, 21, 21, 21).line (3, 3, 3, 21).rect (6, 12, 3, 9).rect (11, 7, 3, 14).rect (16, 14, 3, 7);
                    break;
                case "search":
                    p.circle (10, 10, 6).line (14.5, 14.5, 21, 21);
                    break;
                case "phone":
                    p.round (7, 2, 10, 20, 2).line (10, 18.5, 14, 18.5);
                    break;
                case "building":
                    p.rect (5, 3, 14, 18).rect (8, 6, 3, 3).rect (13, 6, 3, 3).rect (8, 11, 3, 3).rect (13, 11, 3, 3).rect (10, 16, 4, 5);
                    break;
                case "cube":
                    p.poly ({ 12, 3, 20, 7, 20, 17, 12, 21, 4, 17, 4, 7 }).m (4, 7).l (12, 11).l (20, 7).line (12, 11, 12, 21);
                    break;
                case "clock":
                    p.circle (12, 12, 9).line (12, 12, 12, 6).line (12, 12, 16, 14);
                    break;
                case "eye":
                    p.m (2, 12).q (12, 3, 22, 12).q (12, 21, 2, 12).z ().circle (12, 12, 3);
                    break;
                case "waves":
                    p.arc (12, 16, 3, 225, 315).arc (12, 16, 7, 225, 315).arc (12, 16, 11, 225, 315).circle (12, 17, 1);
                    break;
                case "plug":
                    p.rect (7, 8, 10, 8).line (10, 4, 10, 8).line (14, 4, 14, 8).line (12, 16, 12, 21);
                    break;
                case "flame":
                    p.m (12, 3).c (16, 8, 19, 11, 18, 16).c (17, 20, 7, 20, 6, 16).c (5, 12, 9, 10, 10, 6).c (12, 9, 13, 10, 12, 3).z ();
                    break;
                case "compress":
                    p.arrow (2, 7, 10, 11).arrow (2, 17, 10, 13).line (12, 12, 22, 12).arrow (17, 12, 22, 12);
                    break;
                case "arrows4":
                    p.arrow (12, 12, 12, 3).arrow (12, 12, 21, 12).arrow (12, 12, 12, 21).arrow (12, 12, 3, 12);
                    break;
                case "switch":
                    p.arrow (3, 8, 21, 8).arrow (21, 16, 3, 16);
                    break;
                case "router":
                    p.arrow (5, 5, 10, 10).arrow (19, 19, 14, 14).arrow (19, 5, 14, 10).arrow (5, 19, 10, 14);
                    break;
                case "grid":
                    p.rect (3, 3, 8, 8).rect (13, 3, 8, 8).rect (3, 13, 8, 8).rect (13, 13, 8, 8);
                    break;
                case "mobile":
                    p.round (7, 2, 10, 20, 2).line (10, 18.5, 14, 18.5).arc (12, 10, 3, 200, 340);
                    break;
                case "service":
                    p.round (3, 6, 18, 12, 3).circle (8, 12, 2).line (12, 10, 18, 10).line (12, 14, 16, 14);
                    break;
                case "tape":
                    p.rect (2, 6, 20, 12).circle (8, 12, 3).circle (16, 12, 3).line (8, 15, 16, 15);
                    break;
                default:
                    p.rect (4, 4, 16, 16);
                    break;
            }
            return p.str ();
        }
    }

    public class StencilsNetwork {
        private static TechPen pen () {
            return new TechPen ();
        }

        private static unowned StencilDef device (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults ("fill:#dcebf7;stroke:#2f5f8f")
                .label_below ()
                .ports_box ();
        }

        private static void server (string kind, string name, string kw, string glyph) {
            var p = pen ().round (0, 0, 50, 72, 4).str ();
            var bays = pen ().line (8, 11, 34, 11).line (8, 18, 34, 18).line (8, 25, 34, 25).str ();
            var leds = pen ().circle (41, 11, 1.6).circle (41, 18, 1.6).circle (41, 25, 1.6).str ();
            unowned StencilDef d = device (kind, name, 50, 72, kw)
                .fill (p)
                .line (bays)
                .solid (leds, "@stroke")
                .line (pen ().line (0, 33, 50, 33).str ());
            if (glyph != "") d.ink (TechGlyphs.draw (glyph, 12, 39, 26), "@stroke");
            else d.line (pen ().line (8, 45, 42, 45).line (8, 52, 42, 52).line (8, 59, 42, 59).str ());
        }

        private static void box_device (string kind, string name, double w, double h, string kw, string glyph) {
            var body = pen ().round (0, 0, w, h, 4).str ();
            double s = double.min (h - 8, 26);
            device (kind, name, w, h, kw)
                .fill (body)
                .ink (TechGlyphs.draw (glyph, (w - s) / 2, (h - s) / 2, s), "@stroke");
        }

        private static void link_shape (string kind, string name, string kw, string d, string defaults) {
            Stencils.shape (kind, name, 120, 20, kw)
                .box (120, 20)
                .defaults ("fill-kind:none;stroke:#2f5f8f;stroke-width:2;" + defaults)
                .line (d)
                .label (0, -22, 120, 20)
                .port (0, 10)
                .port (120, 10);
        }

        public static void register () {
            Stencils.use_category ("network");
            device ("net2-hub", _("Hub"), 90, 30, "concentrator ports")
                .fill (pen ().round (0, 0, 90, 30, 3).str ())
                .solid (pen ().rect (10, 12, 6, 6).rect (22, 12, 6, 6).rect (34, 12, 6, 6).rect (46, 12, 6, 6).rect (58, 12, 6, 6).rect (70, 12, 6, 6).str (), "@stroke");
            device ("net2-modem", _("Modem"), 70, 36, "dsl cable broadband")
                .fill (pen ().round (0, 6, 70, 30, 4).str ())
                .line (pen ().line (14, 6, 10, 0).line (56, 6, 60, 0).str ())
                .ink (pen ().zigzag (18, 21, 52, 4, 4).str (), "@stroke");
            device ("net2-multilayer", _("Layer 3 Switch"), 90, 40, "l3 multilayer routing switch")
                .fill (pen ().round (0, 0, 90, 40, 4).str ())
                .ink (TechGlyphs.draw ("switch", 8, 4, 32), "@stroke")
                .ink (TechGlyphs.draw ("router", 50, 4, 32), "@stroke");
            device ("net2-internet-globe", _("Internet Globe"), 60, 60, "web www world")
                .fill (pen ().circle (30, 30, 29).str ())
                .ink (TechGlyphs.draw ("globe", 3, 3, 54), "@stroke");

            Stencils.category ("network-detail", _("Detailed Network"), "draw-network-symbolic", StencilGroup.NETWORK);
            server ("net2-server-web", _("Web Server"), "http www site host", "globe");
            server ("net2-server-mail", _("Mail Server"), "email smtp exchange", "mail");
            server ("net2-server-file", _("File Server"), "share smb nfs", "folder");
            server ("net2-server-db", _("Database Server"), "sql data", "database");
            server ("net2-server-app", _("Application Server"), "middleware backend", "gear");
            server ("net2-server-proxy", _("Proxy Server"), "forward reverse cache", "swap");
            server ("net2-server-directory", _("Directory Server"), "ldap active directory identity", "book");
            server ("net2-server-print", _("Print Server"), "printing spool", "printer");
            server ("net2-server-virtual", _("Virtual Server"), "vm hypervisor virtualization", "stack");
            server ("net2-server-tower", _("Tower Server"), "server generic", "");
            device ("net2-blade", _("Blade Server"), 80, 72, "chassis enclosure")
                .fill (pen ().round (0, 0, 80, 72, 3).str ())
                .line (pen ().line (10, 6, 10, 66).line (20, 6, 20, 66).line (30, 6, 30, 66).line (40, 6, 40, 66).line (50, 6, 50, 66).line (60, 6, 60, 66).line (70, 6, 70, 66).str ())
                .solid (pen ().circle (5, 10, 1.5).circle (15, 10, 1.5).circle (25, 10, 1.5).circle (35, 10, 1.5).circle (45, 10, 1.5).circle (55, 10, 1.5).circle (65, 10, 1.5).circle (75, 10, 1.5).str (), "@stroke");
            device ("net2-mainframe", _("Mainframe"), 90, 80, "host ibm big iron")
                .fill (pen ().round (0, 0, 40, 80, 3).str ())
                .fill (pen ().round (50, 0, 40, 80, 3).str ())
                .line (pen ().line (6, 12, 34, 12).line (6, 20, 34, 20).line (56, 12, 84, 12).line (56, 20, 84, 20).line (6, 62, 34, 62).line (56, 62, 84, 62).str ())
                .shade (pen ().rect (8, 30, 24, 22).rect (58, 30, 24, 22).str ());
            device ("net2-workstation", _("Workstation"), 80, 64, "pc desktop computer")
                .fill (pen ().round (0, 0, 56, 42, 3).str ())
                .shade (pen ().rect (4, 4, 48, 32).str ())
                .fill (pen ().rect (22, 42, 12, 8).str ())
                .fill (pen ().round (12, 50, 32, 6, 2).str ())
                .fill (pen ().round (62, 8, 18, 56, 2).str ())
                .line (pen ().line (66, 16, 76, 16).line (66, 22, 76, 22).str ());
            device ("net2-thin-client", _("Thin Client"), 76, 60, "terminal vdi")
                .fill (pen ().round (0, 0, 56, 42, 3).str ())
                .shade (pen ().rect (4, 4, 48, 32).str ())
                .fill (pen ().rect (22, 42, 12, 8).str ())
                .fill (pen ().round (12, 50, 32, 6, 2).str ())
                .fill (pen ().round (62, 30, 14, 30, 2).str ());
            device ("net2-tablet", _("Tablet"), 56, 72, "ipad slate")
                .fill (pen ().round (0, 0, 56, 72, 6).str ())
                .shade (pen ().rect (5, 7, 46, 56).str ())
                .solid (pen ().circle (28, 67.5, 2).str (), "@stroke");
            device ("net2-ip-phone", _("IP Phone"), 64, 56, "voip telephone desk phone")
                .fill (pen ().poly ({ 6, 14, 58, 14, 64, 56, 0, 56 }).str ())
                .fill (pen ().round (2, 0, 20, 52, 6).str ())
                .shade (pen ().rect (30, 20, 22, 10).str ())
                .solid (pen ().circle (33, 38, 2).circle (41, 38, 2).circle (49, 38, 2).circle (33, 46, 2).circle (41, 46, 2).circle (49, 46, 2).str (), "@stroke");
            device ("net2-smart-tv", _("Smart TV"), 90, 60, "television display screen")
                .fill (pen ().round (0, 0, 90, 52, 3).str ())
                .shade (pen ().rect (4, 4, 82, 44).str ())
                .line (pen ().line (30, 60, 45, 52).line (60, 60, 45, 52).str ());
            device ("net2-projector", _("Projector"), 80, 44, "beamer presentation")
                .fill (pen ().round (0, 10, 80, 30, 5).str ())
                .fill (pen ().circle (58, 25, 10).str ())
                .line (pen ().circle (58, 25, 5).line (10, 40, 10, 44).line (70, 40, 70, 44).str ())
                .solid (pen ().circle (14, 20, 2).circle (22, 20, 2).str (), "@stroke");
            device ("net2-camera", _("Security Camera"), 76, 50, "cctv ip camera surveillance")
                .fill (pen ().poly ({ 4, 6, 60, 6, 70, 18, 70, 28, 4, 28 }).str ())
                .fill (pen ().circle (64, 23, 4).str ())
                .line (pen ().line (20, 28, 26, 42).line (10, 46, 40, 46).str ());
            device ("net2-sensor", _("IoT Sensor"), 50, 50, "internet of things device thermometer")
                .fill (pen ().round (8, 18, 34, 32, 4).str ())
                .ink (TechGlyphs.draw ("waves", 13, 0, 24), "@stroke")
                .solid (pen ().circle (25, 34, 5).str (), "@stroke");
            device ("net2-smartwatch", _("Smartwatch"), 36, 60, "wearable watch")
                .fill (pen ().rect (9, 0, 18, 60).str ())
                .fill (pen ().round (2, 14, 32, 32, 7).str ())
                .shade (pen ().round (6, 18, 24, 24, 4).str ());
            box_device ("net2-switch-l2", _("Layer 2 Switch"), 90, 34, "ethernet workgroup switch", "switch");
            box_device ("net2-switch-core", _("Core Switch"), 90, 50, "backbone chassis switch", "arrows4");
            box_device ("net2-router-box", _("Router"), 80, 36, "routing gateway edge", "router");
            device ("net2-router-wireless", _("Wireless Router"), 80, 50, "wifi home router")
                .fill (pen ().round (0, 20, 80, 30, 4).str ())
                .line (pen ().line (14, 20, 8, 0).line (66, 20, 72, 0).str ())
                .ink (TechGlyphs.draw ("router", 28, 23, 24), "@stroke");
            device ("net2-access-point", _("Access Point"), 64, 46, "wifi wireless ap ceiling")
                .fill (pen ().m (2, 46).a (30, 22, false, true, 62, 46).z ().str ())
                .ink (TechGlyphs.draw ("waves", 20, 12, 24), "@stroke");
            box_device ("net2-bridge", _("Network Bridge"), 80, 34, "bridge segment", "swap");
            device ("net2-repeater", _("Repeater"), 70, 40, "range extender booster")
                .fill (pen ().round (0, 8, 70, 32, 4).str ())
                .line (pen ().arc (35, 24, 8, 150, 210).arc (35, 24, 8, -30, 30).arc (35, 24, 14, 150, 210).arc (35, 24, 14, -30, 30).str ())
                .solid (pen ().circle (35, 24, 3).str (), "@stroke");
            box_device ("net2-load-balancer", _("Load Balancer"), 80, 40, "lb traffic distribution adc", "balancer");
            box_device ("net2-vpn", _("VPN Concentrator"), 80, 40, "vpn tunnel remote access", "lock");
            device ("net2-firewall-box", _("Firewall Appliance"), 80, 40, "security utm ngfw")
                .fill (pen ().round (0, 0, 80, 40, 4).str ())
                .ink (TechGlyphs.draw ("wall", 4, 4, 32), "@stroke")
                .ink (TechGlyphs.draw ("flame", 44, 4, 32), "#c62828");
            device ("net2-firewall-cloud", _("Cloud Firewall"), 80, 56, "security edge")
                .fill (TechGlyphs.draw ("cloud", 0, -12, 80))
                .ink (TechGlyphs.draw ("wall", 28, 24, 24), "@stroke");
            box_device ("net2-ids", _("Intrusion Detection"), 80, 40, "ids ips intrusion prevention", "eye");
            box_device ("net2-proxy-appliance", _("Proxy Appliance"), 80, 40, "web filter proxy", "swap");
            box_device ("net2-gateway", _("Gateway"), 80, 40, "border gateway edge", "arrows4");
            box_device ("net2-wan-optimizer", _("WAN Optimizer"), 80, 40, "wan acceleration compression", "compress");
            device ("net2-patch-panel", _("Patch Panel"), 110, 24, "patch ports cabling")
                .fill (pen ().round (0, 0, 110, 24, 2).str ())
                .line (pen ().rect (8, 7, 7, 10).rect (19, 7, 7, 10).rect (30, 7, 7, 10).rect (41, 7, 7, 10).rect (62, 7, 7, 10).rect (73, 7, 7, 10).rect (84, 7, 7, 10).rect (95, 7, 7, 10).str ());
            device ("net2-fiber", _("Fiber Transceiver"), 80, 36, "optical fiber media converter")
                .fill (pen ().round (0, 0, 80, 36, 4).str ())
                .ink (pen ().zigzag (10, 18, 70, 5, 5).str (), "#e07b39");
            device ("net2-satellite-dish", _("Satellite Dish"), 60, 64, "vsat satellite uplink")
                .fill (pen ().m (6, 10).q (8, 48, 48, 44).z ().str ())
                .line (pen ().line (27, 27, 44, 12).line (27, 36, 20, 64).line (10, 64, 40, 64).str ())
                .solid (pen ().circle (46, 10, 3).str (), "@stroke");
            device ("net2-antenna", _("Antenna"), 40, 70, "radio mast aerial")
                .line (pen ().line (20, 16, 20, 70).line (8, 70, 32, 70).line (4, 4, 20, 22).line (36, 4, 20, 22).str ())
                .ink (TechGlyphs.draw ("waves", 8, 0, 24), "@stroke");
            device ("net2-cell-tower", _("Cell Tower"), 50, 80, "mobile base station lte 5g")
                .line (pen ().poly ({ 10, 80, 25, 14, 40, 80 }, false).line (15, 58, 35, 58).line (19, 38, 31, 38).line (15, 58, 31, 38).line (35, 58, 19, 38).str ())
                .ink (TechGlyphs.draw ("waves", 13, -4, 24), "@stroke");
            box_device ("net2-ups", _("UPS"), 50, 70, "uninterruptible power supply battery", "bolt");
            device ("net2-pdu", _("Power Distribution Unit"), 24, 90, "pdu power strip outlets")
                .fill (pen ().round (0, 0, 24, 90, 3).str ())
                .line (pen ().rect (7, 10, 10, 8).rect (7, 26, 10, 8).rect (7, 42, 10, 8).rect (7, 58, 10, 8).rect (7, 74, 10, 8).str ());
            device ("net2-nas", _("NAS"), 60, 60, "network attached storage")
                .fill (pen ().round (0, 0, 60, 60, 4).str ())
                .shade (pen ().rect (6, 8, 10, 44).rect (19, 8, 10, 44).rect (32, 8, 10, 44).str ())
                .solid (pen ().circle (51, 12, 2).circle (51, 20, 2).str (), "@stroke");
            device ("net2-san", _("SAN"), 70, 80, "storage area network array")
                .fill (pen ().round (0, 0, 70, 80, 3).str ())
                .shade (pen ().rect (6, 6, 58, 12).rect (6, 22, 58, 12).rect (6, 38, 58, 12).rect (6, 54, 58, 12).str ())
                .line (pen ().line (0, 72, 70, 72).str ());
            device ("net2-tape-library", _("Tape Library"), 70, 80, "tape backup lto")
                .fill (pen ().round (0, 0, 70, 80, 3).str ())
                .ink (TechGlyphs.draw ("tape", 11, 8, 48), "@stroke")
                .line (pen ().rect (10, 56, 50, 16).line (22, 56, 22, 72).line (34, 56, 34, 72).line (46, 56, 46, 72).str ());
            device ("net2-disk-array", _("Disk Array"), 70, 60, "raid jbod disks")
                .fill (pen ().round (0, 0, 70, 60, 3).str ())
                .ink (TechGlyphs.draw ("disk", 4, 4, 26), "@stroke")
                .ink (TechGlyphs.draw ("disk", 38, 4, 26), "@stroke")
                .ink (TechGlyphs.draw ("disk", 4, 30, 26), "@stroke")
                .ink (TechGlyphs.draw ("disk", 38, 30, 26), "@stroke");
            device ("net2-external-disk", _("External Disk"), 50, 60, "usb drive portable")
                .fill (pen ().round (0, 0, 50, 44, 5).str ())
                .solid (pen ().circle (40, 36, 2).str (), "@stroke")
                .line (pen ().m (25, 44).l (25, 52).q (25, 60, 35, 60).str ());
            device ("net2-building", _("Building"), 60, 70, "office site headquarters")
                .fill (pen ().rect (0, 0, 60, 70).str ())
                .shade (pen ().rect (8, 8, 12, 10).rect (24, 8, 12, 10).rect (40, 8, 12, 10).rect (8, 26, 12, 10).rect (24, 26, 12, 10).rect (40, 26, 12, 10).rect (24, 50, 12, 20).str ());
            device ("net2-branch", _("Branch Office"), 70, 60, "remote office site")
                .fill (pen ().poly ({ 0, 22, 35, 0, 70, 22, 70, 60, 0, 60 }).str ())
                .shade (pen ().rect (10, 30, 14, 12).rect (46, 30, 14, 12).rect (28, 40, 14, 20).str ());
            device ("net2-datacenter", _("Data Center"), 90, 64, "dc colocation facility")
                .fill (pen ().rect (0, 10, 90, 54).str ())
                .shade (pen ().rect (8, 18, 16, 38).rect (29, 18, 16, 38).rect (50, 18, 16, 38).str ())
                .line (pen ().line (0, 10, 90, 10).line (10, 26, 22, 26).line (31, 26, 43, 26).line (52, 26, 64, 26).line (10, 34, 22, 34).line (31, 34, 43, 34).line (52, 34, 64, 34).str ())
                .ink (TechGlyphs.draw ("bolt", 70, 22, 18), "@stroke");
            device ("net2-home", _("Home Office"), 64, 60, "house remote worker")
                .fill (pen ().poly ({ 0, 26, 32, 0, 64, 26, 56, 26, 56, 60, 8, 60, 8, 26 }).str ())
                .shade (pen ().rect (26, 38, 12, 22).str ());
            device ("net2-city", _("City"), 90, 60, "metro urban town")
                .fill (pen ().poly ({ 0, 60, 0, 30, 14, 30, 14, 14, 30, 14, 30, 36, 40, 36, 40, 4, 58, 4, 58, 26, 72, 26, 72, 40, 90, 40, 90, 60 }).str ())
                .line (pen ().line (44, 12, 54, 12).line (44, 20, 54, 20).line (18, 22, 26, 22).line (76, 46, 86, 46).str ());
            device ("net2-user", _("Network User"), 46, 56, "person client employee")
                .fill (pen ().circle (23, 13, 12).str ())
                .fill (pen ().m (0, 56).c (0, 36, 10, 28, 23, 28).c (36, 28, 46, 36, 46, 56).z ().str ());
            device ("net2-users", _("User Group"), 70, 56, "people team department")
                .fill (pen ().circle (48, 12, 10).str ())
                .fill (pen ().m (28, 56).c (28, 36, 38, 26, 48, 26).c (60, 26, 70, 36, 70, 56).z ().str ())
                .fill (pen ().circle (22, 16, 12).str ())
                .fill (pen ().m (0, 56).c (0, 38, 10, 30, 22, 30).c (34, 30, 44, 38, 44, 56).z ().str ());
            device ("net2-cloud-private", _("Private Cloud"), 100, 64, "private cloud on premises")
                .fill (TechGlyphs.draw ("cloud", 0, -16, 100))
                .ink (TechGlyphs.draw ("lock", 38, 22, 26), "@stroke");
            device ("net2-cloud-hybrid", _("Hybrid Cloud"), 100, 64, "hybrid cloud connected")
                .fill (TechGlyphs.draw ("cloud", 0, -16, 100))
                .ink (TechGlyphs.draw ("link", 36, 20, 28), "@stroke");
            device ("net2-cloud-public", _("Public Cloud"), 100, 64, "public cloud provider saas")
                .fill (TechGlyphs.draw ("cloud", 0, -16, 100))
                .ink (TechGlyphs.draw ("globe", 38, 20, 28), "@stroke");
            link_shape ("net2-link-ethernet", _("Ethernet Link"), "cable lan copper", pen ().line (0, 10, 120, 10).str (), "");
            link_shape ("net2-link-fiber", _("Fiber Link"), "optical fiber cable", pen ().line (0, 10, 120, 10).str (), "stroke:#e07b39;dash:long-dash");
            link_shape ("net2-link-wireless", _("Wireless Link"), "radio wifi microwave", pen ().m (0, 10).l (48, 10).l (60, 2).l (60, 18).l (72, 10).l (120, 10).str (), "");
            link_shape ("net2-link-serial", _("Serial Link"), "rs232 console", pen ().line (0, 10, 120, 10).str (), "dash:dash");
            link_shape ("net2-link-comm", _("Communication Link"), "zigzag lightning wan", pen ().m (0, 10).l (50, 10).l (62, 2).l (58, 18).l (70, 10).l (120, 10).str (), "stroke-width:2.5");

            Stencils.category ("rack", _("Rack Diagram"), "draw-network-symbolic", StencilGroup.NETWORK);
            rack_cabinet ("rack-42u", _("Rack Cabinet 42U"), 42);
            rack_cabinet ("rack-24u", _("Rack Cabinet 24U"), 24);
            rack_cabinet ("rack-12u", _("Rack Cabinet 12U"), 12);
            rack_unit ("rack-server-1u", _("1U Server"), 1, "server pizza box", "server");
            rack_unit ("rack-server-2u", _("2U Server"), 2, "server", "server");
            rack_unit ("rack-server-4u", _("4U Server"), 4, "server", "server");
            rack_unit ("rack-blade", _("Blade Chassis"), 7, "blade enclosure", "blade");
            rack_unit ("rack-switch-1u", _("1U Switch"), 1, "switch ports", "ports");
            rack_unit ("rack-switch-2u", _("2U Switch"), 2, "switch ports", "ports");
            rack_unit ("rack-patch-24", _("Patch Panel 24 Port"), 1, "patch panel", "patch24");
            rack_unit ("rack-patch-48", _("Patch Panel 48 Port"), 2, "patch panel", "patch48");
            rack_unit ("rack-kvm", _("KVM Switch"), 1, "keyboard video mouse", "kvm");
            rack_unit ("rack-ups-2u", _("UPS 2U"), 2, "power battery", "ups");
            rack_unit ("rack-shelf", _("Shelf"), 1, "tray", "shelf");
            rack_unit ("rack-blank-1u", _("Blank Panel 1U"), 1, "filler", "blank");
            rack_unit ("rack-blank-2u", _("Blank Panel 2U"), 2, "filler", "blank");
            rack_unit ("rack-cable-manager", _("Cable Manager"), 1, "cable organizer", "cable");
            rack_unit ("rack-storage-2u", _("Storage Array 2U"), 2, "disk shelf san", "disks");
            rack_unit ("rack-storage-4u", _("Storage Array 4U"), 4, "disk shelf san", "disks");
            rack_unit ("rack-router-1u", _("1U Router"), 1, "router", "router");
            rack_unit ("rack-firewall-1u", _("1U Firewall"), 1, "firewall security", "firewall");
            rack_unit ("rack-tape", _("Tape Drive"), 2, "tape backup", "tape");
            rack_unit ("rack-monitor-tray", _("Monitor and Keyboard Tray"), 1, "console lcd drawer", "kvm");
            Stencils.shape ("rack-pdu-vertical", _("Vertical PDU"), 14, 300, "power strip zero u")
                .box (14, 300)
                .defaults ("fill:#3b4650;stroke:#1b232b")
                .fill (pen ().rect (0, 0, 14, 300).str ())
                .solid (outlets (), "#dfe6ec")
                .label_below ()
                .ports_box ();
        }

        private static string outlets () {
            var p = pen ();
            for (int i = 0; i < 14; i++) p.rect (4, 12 + i * 20, 6, 10);
            return p.str ();
        }

        private const double RACK_W = 152;
        private const double UNIT = 14;

        private static void rack_cabinet (string kind, string name, int units) {
            double inner = units * UNIT;
            double h = inner + 36;
            double w = RACK_W + 36;
            var marks = pen ();
            for (int i = 1; i < units; i++) marks.line (6, 18 + i * UNIT, 14, 18 + i * UNIT).line (w - 14, 18 + i * UNIT, w - 6, 18 + i * UNIT);
            Stencils.shape (kind, name, w, h, "rack cabinet enclosure 19 inch")
                .box (w, h)
                .defaults ("fill:#f2f4f6;stroke:#39434d;valign:top;font-size:9")
                .fill (pen ().rect (0, 0, w, h).str ())
                .shade (pen ().rect (0, 0, w, 18).rect (0, h - 18, w, 18).str ())
                .line (pen ().rect (18, 18, RACK_W, inner).str ())
                .line (marks.str ())
                .label (0, 0, w, 18)
                .text (name)
                .as_container ()
                .ports_box ();
        }

        private static void rack_unit (string kind, string name, int units, string kw, string style) {
            double h = units * UNIT;
            double w = RACK_W;
            var body = pen ().rect (0, 0, w, h).str ();
            var ears = pen ().circle (4, h / 2, 1.5).circle (w - 4, h / 2, 1.5).str ();
            unowned StencilDef d = Stencils.shape (kind, name, w, h, "rack " + kw)
                .box (w, h)
                .defaults ("fill:#5f6b76;stroke:#232b33;text-color:#ffffff;font-size:7;halign:left")
                .fill (body)
                .solid (ears, "#c9d1d8")
                .label (12, 0, 60, h)
                .ports_box ();
            var p = pen ();
            switch (style) {
                case "server":
                    for (int i = 0; i < units * 2; i++) {
                        double row = 2 + i * (h - 4) / (units * 2);
                        p.rect (76, row + 1, 12, (h - 4) / (units * 2) - 2).rect (92, row + 1, 12, (h - 4) / (units * 2) - 2).rect (108, row + 1, 12, (h - 4) / (units * 2) - 2);
                    }
                    d.solid (p.str (), "#8e9aa5");
                    d.solid (pen ().circle (134, h / 2, 2).str (), "#6fbf5a");
                    break;
                case "blade":
                    for (int i = 0; i < 14; i++) p.rect (10 + i * 9.5, 4, 7.5, h - 8);
                    d.solid (p.str (), "#8e9aa5");
                    d.label (10, h - 14, 130, 12);
                    break;
                case "ports":
                    for (int r = 0; r < units; r++) for (int i = 0; i < 12; i++) p.rect (60 + i * 7, 3 + r * UNIT, 5, UNIT - 6);
                    d.solid (p.str (), "#1b232b");
                    break;
                case "patch24":
                    for (int i = 0; i < 24; i++) p.rect (40 + i * 4.4, 4, 3.2, 6);
                    d.solid (p.str (), "#1b232b");
                    d.label (10, 0, 28, h);
                    break;
                case "patch48":
                    for (int r = 0; r < 2; r++) for (int i = 0; i < 24; i++) p.rect (40 + i * 4.4, 4 + r * UNIT, 3.2, 6);
                    d.solid (p.str (), "#1b232b");
                    d.label (10, 0, 28, h);
                    break;
                case "kvm":
                    d.solid (pen ().rect (80, 3, 50, h - 6).str (), "#2d3a46");
                    break;
                case "ups":
                    d.solid (pen ().rect (90, 4, 30, h - 8).str (), "#2d3a46");
                    d.ink (TechGlyphs.draw ("bolt", 126, 3, h - 6), "#f5c518");
                    break;
                case "shelf":
                    d.defaults ("fill:#aeb8c1");
                    d.line (pen ().line (8, h - 3, w - 8, h - 3).str ());
                    break;
                case "blank":
                    d.defaults ("fill:#3b4650");
                    break;
                case "cable":
                    for (int i = 0; i < 10; i++) p.rect (14 + i * 13, 2, 8, h - 4);
                    d.line (p.str ());
                    break;
                case "disks":
                    int n = units == 2 ? 12 : 24;
                    int per = units == 2 ? 12 : 12;
                    for (int i = 0; i < n; i++) p.rect (60 + (i % per) * 7, 3 + (i / per) * (h / 2), 5, h / (n / per) - 6);
                    d.solid (p.str (), "#8e9aa5");
                    break;
                case "router":
                    for (int i = 0; i < 6; i++) p.rect (80 + i * 8, 3, 6, UNIT - 6);
                    d.solid (p.str (), "#1b232b");
                    d.solid (pen ().circle (136, h / 2, 2).str (), "#6fbf5a");
                    break;
                case "firewall":
                    d.defaults ("fill:#8e2f2a");
                    for (int i = 0; i < 4; i++) p.rect (90 + i * 8, 3, 6, UNIT - 6);
                    d.solid (p.str (), "#1b232b");
                    break;
                case "tape":
                    d.solid (pen ().rect (84, h / 2 - 3, 44, 6).str (), "#1b232b");
                    break;
            }
        }
    }
}
