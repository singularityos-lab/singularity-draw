namespace Singularity.Apps.Draw {

    public class GanttTask {
        public string name = "";
        public string start = "";
        public int duration = 1;
        public double progress = 0;
        public string depends = "";
        public int level = 0;
        public string resource = "";

        public GanttTask copy () {
            var t = new GanttTask ();
            t.name = name;
            t.start = start;
            t.duration = duration;
            t.progress = progress;
            t.depends = depends;
            t.level = level;
            t.resource = resource;
            return t;
        }

        public bool milestone () {
            return duration <= 0;
        }

        public Date? start_date () {
            return GanttShape.parse_date (start);
        }

        public Date? finish_date () {
            var d = start_date ();
            if (d == null) return null;
            if (duration > 1) d.add_days (duration - 1);
            return d;
        }

        public int[] dependencies () {
            int[] list = {};
            foreach (string p in depends.split (",")) {
                string t = p.strip ();
                if (t == "") continue;
                int v = int.parse (t);
                if (v > 0) list += v - 1;
            }
            return list;
        }
    }

    public class GanttShape : Shape {
        public Gee.ArrayList<GanttTask> tasks = new Gee.ArrayList<GanttTask> ();
        public string scale = "week";
        public double name_width = 180;
        public double row_height = 26;
        public double header_height = 40;
        public string bar_color = "#3a6ea5";
        public string done_color = "#1f4e79";
        public string milestone_color = "#c62828";

        public GanttShape () {
            base ("gantt");
            style.fill = "#ffffff";
            style.stroke = "#8a95a1";
            style.stroke_width = 1;
            style.font_size = 9;
            style.halign = TextHAlign.LEFT;
        }

        public override Item clone () {
            var g = new GanttShape ();
            copy_shape (g);
            foreach (var t in tasks) g.tasks.add (t.copy ());
            g.scale = scale;
            g.name_width = name_width;
            g.row_height = row_height;
            g.header_height = header_height;
            g.bar_color = bar_color;
            g.done_color = done_color;
            g.milestone_color = milestone_color;
            return g;
        }

        public override Geometry geometry () {
            var g = new Geometry ();
            g.parts.add (new GeomPart (new PathData.rect (0, 0, w, h), PartMode.FILL_STROKE));
            g.text_rect = Rect (0, -24, w, 20);
            return g;
        }

        public static Date? parse_date (string s) {
            string t = s.strip ();
            if (t == "") return null;
            string[] p = t.split ("-");
            if (p.length != 3) {
                p = t.split ("/");
                if (p.length != 3) return null;
                if (p[2].length == 4) {
                    string y = p[2];
                    p = { y, p[1], p[0] };
                }
            }
            int y = int.parse (p[0]), m = int.parse (p[1]), d = int.parse (p[2]);
            if (y < 1 || m < 1 || m > 12 || d < 1 || d > 31) return null;
            var date = Date ();
            date.set_dmy ((DateDay) d, m, (DateYear) y);
            if (!date.valid ()) return null;
            return date;
        }

        public static string format_date (Date d) {
            return "%04d-%02d-%02d".printf (d.get_year (), d.get_month (), d.get_day ());
        }

        public bool range (out Date first, out Date last) {
            first = Date ();
            last = Date ();
            bool any = false;
            foreach (var t in tasks) {
                var s = t.start_date ();
                var f = t.finish_date ();
                if (s == null || f == null) continue;
                if (!any || s.compare (first) < 0) first = s;
                if (!any || f.compare (last) > 0) last = f;
                any = true;
            }
            return any;
        }

        public int total_days () {
            Date a, b;
            if (!range (out a, out b)) return 0;
            return a.days_between (b) + 1;
        }

        public void fit_height () {
            h = header_height + row_height * int.max (tasks.size, 1);
        }

        public void schedule () {
            for (int pass = 0; pass < tasks.size; pass++) {
                bool changed = false;
                for (int i = 0; i < tasks.size; i++) {
                    var t = tasks[i];
                    foreach (int d in t.dependencies ()) {
                        if (d < 0 || d >= tasks.size || d == i) continue;
                        var pf = tasks[d].finish_date ();
                        if (pf == null) continue;
                        var earliest = pf;
                        earliest.add_days (tasks[d].milestone () ? 0 : 1);
                        var s = t.start_date ();
                        if (s == null || s.compare (earliest) < 0) {
                            t.start = format_date (earliest);
                            changed = true;
                        }
                    }
                }
                if (!changed) break;
            }
        }

        private double day_width (int days) {
            double avail = double.max (w - name_width, 40);
            return avail / double.max (days, 1);
        }

        private void text (Cairo.Context cr, string t, double x, double y, double maxw, bool bold, double size) {
            var st = style.copy ();
            st.bold = bold;
            st.font_size = size;
            st.halign = TextHAlign.LEFT;
            var layout = Renderer.make_layout (cr, st, t, 0, false);
            layout.set_width ((int) (double.max (maxw, 4) * Pango.SCALE));
            layout.set_ellipsize (Pango.EllipsizeMode.END);
            int lw, lh;
            layout.get_pixel_size (out lw, out lh);
            Rgba tc;
            if (!Colors.parse (style.text_color, out tc)) tc = Rgba (0, 0, 0, 1);
            tc.apply (cr, style.opacity);
            cr.move_to (x, y - lh / 2.0);
            Pango.cairo_show_layout (cr, layout);
        }

        public void draw_content (Cairo.Context cr) {
            Date first, last;
            bool has = range (out first, out last);
            int days = has ? first.days_between (last) + 1 : 7;
            if (has && scale == "week") {
                while (first.get_weekday () != DateWeekday.MONDAY) {
                    first.subtract_days (1);
                    days++;
                }
            }
            double dw = day_width (days);
            Rgba grid;
            if (!Colors.parse (style.stroke, out grid)) grid = Rgba (0.5, 0.5, 0.5, 1);
            cr.save ();
            cr.set_line_width (0.6);
            grid.apply (cr, 0.5);
            cr.move_to (name_width, 0);
            cr.line_to (name_width, h);
            cr.move_to (0, header_height);
            cr.line_to (w, header_height);
            cr.move_to (name_width, header_height / 2);
            cr.line_to (w, header_height / 2);
            cr.stroke ();
            text (cr, _("Task"), 6, header_height / 2, name_width - 12, true, style.font_size + 1);
            if (has) {
                var d = first;
                int step = scale == "day" ? 1 : (scale == "month" ? 0 : 7);
                int i = 0;
                string last_top = "";
                while (i < days) {
                    double x = name_width + i * dw;
                    string top = "%s %d".printf (month_name (d.get_month ()), d.get_year ());
                    if (top != last_top) {
                        grid.apply (cr, 0.5);
                        cr.move_to (x, 0);
                        cr.line_to (x, header_height / 2);
                        cr.stroke ();
                        text (cr, top, x + 4, header_height / 4, double.max (w - x - 8, 10), true, style.font_size);
                        last_top = top;
                    }
                    int span = step;
                    if (step == 0) span = (int) d.get_days_in_month (d.get_month (), d.get_year ()) - d.get_day () + 1;
                    grid.apply (cr, 0.25);
                    cr.move_to (x, header_height / 2);
                    cr.line_to (x, h);
                    cr.stroke ();
                    string lbl = step == 0 ? month_name (d.get_month ()) : "%d".printf (d.get_day ());
                    if (span * dw > 14) text (cr, lbl, x + 3, header_height * 0.75, span * dw - 4, false, style.font_size - 1);
                    d.add_days (span);
                    i += span;
                }
            }
            for (int r = 0; r < tasks.size; r++) {
                var t = tasks[r];
                double y = header_height + r * row_height;
                if (r % 2 == 1) {
                    cr.set_source_rgba (grid.r, grid.g, grid.b, 0.06);
                    cr.rectangle (0, y, w, row_height);
                    cr.fill ();
                }
                text (cr, t.name, 6 + t.level * 12, y + row_height / 2, name_width - 12 - t.level * 12, t.level == 0 && has_children (r), style.font_size);
                var s = t.start_date ();
                if (!has || s == null) continue;
                double x = name_width + first.days_between (s) * dw;
                if (t.milestone ()) {
                    Rgba mc;
                    Colors.parse (milestone_color, out mc);
                    mc.apply (cr);
                    double m = row_height * 0.32;
                    cr.move_to (x, y + row_height / 2 - m);
                    cr.line_to (x + m, y + row_height / 2);
                    cr.line_to (x, y + row_height / 2 + m);
                    cr.line_to (x - m, y + row_height / 2);
                    cr.close_path ();
                    cr.fill ();
                    continue;
                }
                double bw = t.duration * dw;
                double by = y + row_height * 0.22, bh = row_height * 0.56;
                Rgba bc, dc;
                Colors.parse (bar_color, out bc);
                Colors.parse (done_color, out dc);
                if (has_children (r)) {
                    dc.apply (cr);
                    cr.rectangle (x, by + bh * 0.3, bw, bh * 0.4);
                    cr.fill ();
                    continue;
                }
                bc.apply (cr, 0.85);
                cr.rectangle (x, by, bw, bh);
                cr.fill ();
                if (t.progress > 0) {
                    dc.apply (cr);
                    cr.rectangle (x, by + bh * 0.3, bw * t.progress, bh * 0.4);
                    cr.fill ();
                }
            }
            if (has) {
                cr.set_line_width (0.9);
                grid.apply (cr, 0.9);
                for (int r = 0; r < tasks.size; r++) {
                    var t = tasks[r];
                    var s = t.start_date ();
                    if (s == null) continue;
                    double tx = name_width + first.days_between (s) * dw, ty = header_height + r * row_height + row_height / 2;
                    foreach (int d in t.dependencies ()) {
                        if (d < 0 || d >= tasks.size) continue;
                        var pf = tasks[d].start_date ();
                        if (pf == null) continue;
                        double fx = name_width + (first.days_between (pf) + int.max (tasks[d].duration, 0)) * dw;
                        double fy = header_height + d * row_height + row_height / 2;
                        cr.move_to (fx, fy);
                        cr.line_to (fx + 6, fy);
                        cr.line_to (fx + 6, ty);
                        cr.line_to (tx - 2, ty);
                        cr.stroke ();
                        cr.move_to (tx - 2, ty);
                        cr.line_to (tx - 7, ty - 3);
                        cr.line_to (tx - 7, ty + 3);
                        cr.close_path ();
                        cr.fill ();
                    }
                }
            }
            cr.restore ();
        }

        public bool has_children (int index) {
            return index + 1 < tasks.size && tasks[index + 1].level > tasks[index].level;
        }

        private static string month_name (DateMonth m) {
            string[] names = { _("Jan"), _("Feb"), _("Mar"), _("Apr"), _("May"), _("Jun"), _("Jul"), _("Aug"), _("Sep"), _("Oct"), _("Nov"), _("Dec") };
            int i = (int) m - 1;
            return i >= 0 && i < 12 ? names[i] : "";
        }

        public static GanttShape sample () {
            var g = new GanttShape ();
            var today = Date ();
            today.set_time_t ((time_t) new DateTime.now_local ().to_unix ());
            string[] names = { _("Planning"), _("Requirements"), _("Design"), _("Build"), _("Testing"), _("Launch") };
            int[] durs = { 0, 5, 7, 12, 6, 0 };
            int[] levels = { 0, 1, 1, 1, 1, 0 };
            var d = today;
            for (int i = 0; i < names.length; i++) {
                var t = new GanttTask ();
                t.name = names[i];
                t.duration = durs[i];
                t.level = levels[i];
                t.start = format_date (d);
                if (i > 1) t.depends = "%d".printf (i);
                g.tasks.add (t);
            }
            g.tasks[0].duration = 30;
            g.tasks[5].depends = "5";
            g.schedule ();
            g.w = 720;
            g.fit_height ();
            return g;
        }

        public void write_extra (XmlWriter w) {
            w.start ("gantt").attr ("scale", scale).attr_num ("name-width", name_width, 2).attr_num ("row-height", row_height, 2)
                .attr_num ("header-height", header_height, 2).attr ("bar-color", bar_color).attr ("done-color", done_color)
                .attr ("milestone-color", milestone_color);
            foreach (var t in tasks) {
                w.start ("task").attr ("name", t.name).attr ("start", t.start).attr ("duration", t.duration.to_string ())
                    .attr_num ("progress", t.progress, 4).attr ("depends", t.depends).attr ("level", t.level.to_string ())
                    .attr ("resource", t.resource).end ();
            }
            w.end ();
        }

        public void read_extra (Xml.Node* n) {
            var gn = XmlUtil.child (n, "gantt");
            if (gn == null) return;
            scale = XmlUtil.attr_or (gn, "scale", "week");
            name_width = XmlUtil.attr_double (gn, "name-width", 180);
            row_height = XmlUtil.attr_double (gn, "row-height", 26);
            header_height = XmlUtil.attr_double (gn, "header-height", 40);
            bar_color = XmlUtil.attr_or (gn, "bar-color", bar_color);
            done_color = XmlUtil.attr_or (gn, "done-color", done_color);
            milestone_color = XmlUtil.attr_or (gn, "milestone-color", milestone_color);
            tasks.clear ();
            foreach (var tn in XmlUtil.children (gn, "task")) {
                var t = new GanttTask ();
                t.name = XmlUtil.attr_or (tn, "name", "");
                t.start = XmlUtil.attr_or (tn, "start", "");
                t.duration = int.parse (XmlUtil.attr_or (tn, "duration", "1"));
                t.progress = XmlUtil.attr_double (tn, "progress", 0).clamp (0, 1);
                t.depends = XmlUtil.attr_or (tn, "depends", "");
                t.level = int.parse (XmlUtil.attr_or (tn, "level", "0"));
                t.resource = XmlUtil.attr_or (tn, "resource", "");
                tasks.add (t);
            }
        }
    }
}
