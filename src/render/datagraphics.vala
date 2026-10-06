namespace Singularity.Apps.Draw {

    public class DataGraphics {
        public static string[] icon_sets () {
            return { "traffic", "arrows", "flags", "stars", "checks" };
        }

        public static string icon_set_label (string id) {
            switch (id) {
                case "arrows": return _("Trend Arrows");
                case "flags": return _("Flags");
                case "stars": return _("Stars");
                case "checks": return _("Check Marks");
                default: return _("Traffic Lights");
            }
        }

        public static string[] kinds () {
            return { "text", "bar", "icon", "color" };
        }

        public static string kind_label (string id) {
            switch (id) {
                case "bar": return _("Data Bar");
                case "icon": return _("Icon Set");
                case "color": return _("Color by Value");
                default: return _("Text Callout");
            }
        }

        public static string[] positions () {
            return { "top-right", "top-left", "top-center", "bottom-center", "bottom-left", "bottom-right", "left", "right", "center" };
        }

        public static string position_label (string id) {
            switch (id) {
                case "top-left": return _("Top Left");
                case "top-center": return _("Top");
                case "bottom-center": return _("Bottom");
                case "bottom-left": return _("Bottom Left");
                case "bottom-right": return _("Bottom Right");
                case "left": return _("Left");
                case "right": return _("Right");
                case "center": return _("Center");
                default: return _("Top Right");
            }
        }

        public static DataGraphic? graphic_of (Page page, Item it) {
            if (it.data_graphic == "" || page.graphics_ref == null) return null;
            foreach (var g in page.graphics_ref) if (g.id == it.data_graphic) return g;
            return null;
        }

        private static bool num (string s, out double v) {
            string t = s.strip ().replace ("%", "").replace (",", ".");
            return double.try_parse (t, out v);
        }

        public static bool matches (DataGraphicRule r, string value) {
            double a = 0, b = 0;
            bool numeric = num (value, out a) && num (r.value, out b);
            switch (r.op) {
                case "=": return numeric ? a == b : value.casefold () == r.value.casefold ();
                case "!=": return numeric ? a != b : value.casefold () != r.value.casefold ();
                case ">": return numeric && a > b;
                case ">=": return numeric && a >= b;
                case "<": return numeric && a < b;
                case "<=": return numeric && a <= b;
                case "contains": return value.casefold ().contains (r.value.casefold ());
                default: return false;
            }
        }

        public static string? fill_override (Page page, Item it) {
            var g = graphic_of (page, it);
            if (g == null) return null;
            foreach (var gi in g.items) {
                if (gi.kind != "color") continue;
                string? v = it.get_field (gi.field);
                if (v == null) continue;
                foreach (var r in gi.rules) if (matches (r, v) && r.color != "") return r.color;
                double d = 0;
                if (gi.rules.size == 0 && num (v, out d) && gi.max > gi.min) {
                    double t = ((d - gi.min) / (gi.max - gi.min)).clamp (0, 1);
                    return Colors.rgb_hex (Colors.mix ("#ffffff", gi.color, t));
                }
            }
            return null;
        }

        public static int icon_index (DataGraphicItem gi, string value) {
            for (int i = 0; i < gi.rules.size; i++) {
                if (matches (gi.rules[i], value)) {
                    int n = int.parse (gi.rules[i].icon);
                    return gi.rules[i].icon != "" ? n : i;
                }
            }
            double d = 0;
            if (!num (value, out d) || gi.max <= gi.min) return -1;
            double t = (d - gi.min) / (gi.max - gi.min);
            if (t < 1.0 / 3) return 0;
            if (t < 2.0 / 3) return 1;
            return 2;
        }

        private static Point anchor (Rect b, string pos, double w, double h) {
            switch (pos) {
                case "top-left": return Point (b.x - w / 2, b.y - h / 2);
                case "top-center": return Point (b.cx () - w / 2, b.y - h - 4);
                case "bottom-center": return Point (b.cx () - w / 2, b.y2 () + 4);
                case "bottom-left": return Point (b.x - w / 2, b.y2 () - h / 2);
                case "bottom-right": return Point (b.x2 () - w / 2, b.y2 () - h / 2);
                case "left": return Point (b.x - w - 4, b.cy () - h / 2);
                case "right": return Point (b.x2 () + 4, b.cy () - h / 2);
                case "center": return Point (b.cx () - w / 2, b.cy () - h / 2);
                default: return Point (b.x2 () - w / 2, b.y - h / 2);
            }
        }

        public static void draw_page (Cairo.Context cr, Page page) {
            if (page.graphics_ref == null || page.graphics_ref.size == 0) return;
            foreach (var it in page.all_items ()) {
                if (it.data_graphic == "" || !page.item_visible (page.top_level (it))) continue;
                var g = graphic_of (page, it);
                if (g != null) draw_item (cr, it, g);
            }
        }

        public static void draw_item (Cairo.Context cr, Item it, DataGraphic g) {
            var b = it.bounds ();
            int stack = 0;
            foreach (var gi in g.items) {
                string? v = it.get_field (gi.field);
                if (v == null || gi.kind == "color") continue;
                cr.save ();
                switch (gi.kind) {
                    case "bar":
                        double d = 0;
                        if (!num (v, out d)) break;
                        double t = gi.max > gi.min ? ((d - gi.min) / (gi.max - gi.min)).clamp (0, 1) : 0;
                        double bw = double.max (b.w * 0.8, 40), bh = 9;
                        var p = anchor (b, gi.position == "top-right" ? "bottom-center" : gi.position, bw, bh);
                        p.y += stack * (bh + 3);
                        cr.set_source_rgba (1, 1, 1, 0.95);
                        cr.rectangle (p.x, p.y, bw, bh);
                        cr.fill ();
                        Rgba c;
                        if (Colors.parse (gi.color, out c)) c.apply (cr);
                        cr.rectangle (p.x, p.y, bw * t, bh);
                        cr.fill ();
                        cr.set_source_rgba (0.2, 0.2, 0.2, 0.8);
                        cr.set_line_width (0.8);
                        cr.rectangle (p.x, p.y, bw, bh);
                        cr.stroke ();
                        stack++;
                        break;
                    case "icon":
                        int idx = icon_index (gi, v);
                        if (idx < 0) break;
                        double sz = 16;
                        var p = anchor (b, gi.position, sz, sz);
                        draw_icon (cr, gi.icon_set, idx, p.x, p.y, sz);
                        break;
                    default:
                        var st = new Style ();
                        st.font_size = 8;
                        st.bold = true;
                        var layout = Renderer.make_layout (cr, st, v, 0, false);
                        int lw, lh;
                        layout.get_pixel_size (out lw, out lh);
                        double w = lw + 8, h = lh + 4;
                        var p = anchor (b, gi.position, w, h);
                        cr.new_path ();
                        cr.rectangle (p.x, p.y, w, h);
                        Rgba c;
                        if (!Colors.parse (gi.color, out c)) c = Rgba (0.23, 0.43, 0.65, 1);
                        c.apply (cr);
                        cr.fill ();
                        cr.set_source_rgb (1, 1, 1);
                        cr.move_to (p.x + 4, p.y + 2);
                        Pango.cairo_show_layout (cr, layout);
                        break;
                }
                cr.restore ();
            }
        }

        public static void draw_icon (Cairo.Context cr, string set, int idx, double x, double y, double sz) {
            string[] traffic = { "#c62828", "#f5c518", "#2e7d32" };
            double cx = x + sz / 2, cy = y + sz / 2, r = sz / 2;
            cr.save ();
            cr.set_line_width (1);
            switch (set) {
                case "arrows":
                    string[] cols = { "#c62828", "#b8930b", "#2e7d32" };
                    Rgba c;
                    Colors.parse (cols[idx.clamp (0, 2)], out c);
                    c.apply (cr);
                    cr.translate (cx, cy);
                    cr.rotate (idx <= 0 ? Math.PI / 2 : (idx == 1 ? 0 : -Math.PI / 2));
                    cr.move_to (-r * 0.8, -r * 0.3);
                    cr.line_to (r * 0.1, -r * 0.3);
                    cr.line_to (r * 0.1, -r * 0.8);
                    cr.line_to (r * 0.9, 0);
                    cr.line_to (r * 0.1, r * 0.8);
                    cr.line_to (r * 0.1, r * 0.3);
                    cr.line_to (-r * 0.8, r * 0.3);
                    cr.close_path ();
                    cr.fill ();
                    break;
                case "flags":
                    Rgba c;
                    Colors.parse (traffic[idx.clamp (0, 2)], out c);
                    cr.set_source_rgb (0.25, 0.25, 0.25);
                    cr.move_to (x + sz * 0.2, y + sz);
                    cr.line_to (x + sz * 0.2, y);
                    cr.stroke ();
                    c.apply (cr);
                    cr.move_to (x + sz * 0.2, y);
                    cr.line_to (x + sz * 0.95, y + sz * 0.25);
                    cr.line_to (x + sz * 0.2, y + sz * 0.5);
                    cr.close_path ();
                    cr.fill ();
                    break;
                case "stars":
                    int n = (idx + 1).clamp (1, 5);
                    double ss = sz * 0.7;
                    for (int i = 0; i < n; i++) {
                        cr.set_source_rgb (0.96, 0.77, 0.09);
                        double sx = x + i * ss * 0.9 + ss / 2, sy = cy;
                        for (int k = 0; k < 10; k++) {
                            double a = -Math.PI / 2 + k * Math.PI / 5;
                            double rr = k % 2 == 0 ? ss / 2 : ss / 5;
                            if (k == 0) cr.move_to (sx + rr * Math.cos (a), sy + rr * Math.sin (a));
                            else cr.line_to (sx + rr * Math.cos (a), sy + rr * Math.sin (a));
                        }
                        cr.close_path ();
                        cr.fill ();
                    }
                    break;
                case "checks":
                    if (idx >= 2) {
                        cr.set_source_rgb (0.18, 0.49, 0.2);
                        cr.set_line_width (sz * 0.18);
                        cr.move_to (x + sz * 0.15, cy);
                        cr.line_to (x + sz * 0.42, y + sz * 0.8);
                        cr.line_to (x + sz * 0.9, y + sz * 0.2);
                    } else if (idx == 1) {
                        cr.set_source_rgb (0.72, 0.58, 0.04);
                        cr.set_line_width (sz * 0.18);
                        cr.move_to (x + sz * 0.5, y + sz * 0.15);
                        cr.line_to (x + sz * 0.5, y + sz * 0.6);
                        cr.stroke ();
                        cr.arc (x + sz * 0.5, y + sz * 0.85, sz * 0.09, 0, 2 * Math.PI);
                        cr.fill ();
                        break;
                    } else {
                        cr.set_source_rgb (0.78, 0.16, 0.16);
                        cr.set_line_width (sz * 0.18);
                        cr.move_to (x + sz * 0.2, y + sz * 0.2);
                        cr.line_to (x + sz * 0.8, y + sz * 0.8);
                        cr.move_to (x + sz * 0.8, y + sz * 0.2);
                        cr.line_to (x + sz * 0.2, y + sz * 0.8);
                    }
                    cr.stroke ();
                    break;
                default:
                    Rgba c;
                    Colors.parse (traffic[idx.clamp (0, 2)], out c);
                    cr.arc (cx, cy, r, 0, 2 * Math.PI);
                    c.apply (cr);
                    cr.fill_preserve ();
                    cr.set_source_rgba (0, 0, 0, 0.35);
                    cr.stroke ();
                    break;
            }
            cr.restore ();
        }
    }
}
