namespace Singularity.Apps.Draw {

    public class TextLine {
        public string text;
        public double x;
        public double baseline;
        public double width;
        public int start = 0;

        public TextLine (string text, double x, double baseline, double width) {
            this.text = text;
            this.x = x;
            this.baseline = baseline;
            this.width = width;
        }
    }

    public class TextBlock {
        public Gee.ArrayList<TextLine> lines = new Gee.ArrayList<TextLine> ();
        public double width;
        public double height;
    }

    public class SvgWriter {
        private XmlWriter w;
        private StringBuilder defs = new StringBuilder ();
        private int def_id = 0;
        private int precision = -1;
        private Page? page = null;
        private static Cairo.Context? scratch = null;

        public static TextBlock measure (Style st, string text, double width, bool wrap, Gee.List<TextRun>? runs = null) {
            if (scratch == null) scratch = new Cairo.Context (new Cairo.ImageSurface (Cairo.Format.ARGB32, 4, 4));
            var layout = Renderer.make_layout (scratch, st, text, width, wrap);
            if (runs != null) RichRuns.apply (layout, runs);
            var block = new TextBlock ();
            int lw, lh;
            layout.get_pixel_size (out lw, out lh);
            block.width = lw;
            block.height = lh;
            var iter = layout.get_iter ();
            unowned string full = layout.get_text ();
            do {
                unowned Pango.LayoutLine? line = iter.get_line_readonly ();
                if (line == null) continue;
                Pango.Rectangle ink, logical;
                iter.get_line_extents (out ink, out logical);
                int start = line.start_index;
                int len = line.length;
                string t = full.substring (start, len);
                while (t.has_suffix ("\n") || t.has_suffix ("\r")) t = t.substring (0, t.length - 1);
                var tl = new TextLine (t, logical.x / (double) Pango.SCALE, iter.get_baseline () / (double) Pango.SCALE, logical.width / (double) Pango.SCALE);
                tl.start = start;
                block.lines.add (tl);
            } while (iter.next_line ());
            return block;
        }

        public static string write_page (Page page, Rect area, bool background, Gee.List<Item>? only = null, int precision = -1) {
            var sw = new SvgWriter ();
            sw.precision = precision >= 0 && precision <= 6 ? precision : -1;
            return sw.build (page, area, background, only);
        }

        public static Rect page_area (Page page) {
            return Rect (0, 0, page.width, page.height);
        }

        public static Rect content_area (Page page, Gee.List<Item>? only, double margin = 10) {
            Rect r = only != null ? Document.selection_bounds (only) : page.content_bounds ();
            if (r.is_empty ()) return Rect (0, 0, page.width, page.height);
            return r.inflate (margin);
        }

        private int digits (int fallback) {
            return precision >= 0 ? precision : fallback;
        }

        private string build (Page page, Rect area, bool background, Gee.List<Item>? only) {
            this.page = page;
            w = new XmlWriter (false, false);
            var body = new XmlWriter (false, false);
            w = body;
            if (background && !Colors.is_none (page.background)) {
                w.start ("rect").attr_num ("x", area.x, digits (3)).attr_num ("y", area.y, digits (3)).attr_num ("width", area.w, digits (3)).attr_num ("height", area.h, digits (3));
                paint_attrs ("fill", page.background);
                w.end ();
            }
            if (only == null) write_background (page, 0);
            var list = only ?? page.items;
            foreach (var it in list) {
                if (only == null && !page.item_visible (it) && !(it is RasterItem)) continue;
                write_item (it);
            }
            string content = body.finish ();
            var root = new XmlWriter (true, false);
            root.start ("svg").attr ("xmlns", "http://www.w3.org/2000/svg").attr ("xmlns:xlink", "http://www.w3.org/1999/xlink")
                .attr ("version", "1.1").attr_num ("width", area.w, digits (3)).attr_num ("height", area.h, digits (3))
                .attr ("viewBox", "%s %s %s %s".printf (PathData.fmt (area.x, digits (3)), PathData.fmt (area.y, digits (3)), PathData.fmt (area.w, digits (3)), PathData.fmt (area.h, digits (3))));
            if (defs.len > 0) root.raw ("<defs>" + defs.str + "</defs>");
            root.raw (content);
            return root.finish ();
        }

        private void paint_attrs (string prop, string color) {
            Rgba c;
            if (!Colors.parse (color, out c) || c.a <= 0) {
                w.attr (prop, "none");
                return;
            }
            w.attr (prop, Colors.to_hex (c));
            if (c.a < 0.999) w.attr (prop + "-opacity", PathData.fmt (c.a, 3));
        }

        private string next_id (string prefix) {
            return "%s%d".printf (prefix, ++def_id);
        }

        private string? gradient (Style st, Rect box) {
            if (st.fill_kind != FillKind.LINEAR && st.fill_kind != FillKind.RADIAL) return null;
            Rgba c1, c2;
            if (!Colors.parse (st.fill, out c1)) c1 = Rgba (1, 1, 1, 0);
            if (!Colors.parse (st.fill2, out c2)) c2 = Rgba (1, 1, 1, 0);
            string id = next_id ("grad");
            var g = new XmlWriter (false, false);
            if (st.fill_kind == FillKind.LINEAR) {
                double a = st.gradient_angle * Math.PI / 180;
                double dx = Math.cos (a), dy = Math.sin (a);
                double half = (box.w * dx.abs () + box.h * dy.abs ()) / 2;
                g.start ("linearGradient").attr ("id", id).attr ("gradientUnits", "userSpaceOnUse")
                    .attr_num ("x1", box.cx () - dx * half, digits (3)).attr_num ("y1", box.cy () - dy * half, digits (3))
                    .attr_num ("x2", box.cx () + dx * half, digits (3)).attr_num ("y2", box.cy () + dy * half, digits (3));
            } else {
                g.start ("radialGradient").attr ("id", id).attr ("gradientUnits", "userSpaceOnUse")
                    .attr_num ("cx", box.cx (), digits (3)).attr_num ("cy", box.cy (), digits (3)).attr_num ("r", Math.hypot (box.w, box.h) / 2, digits (3));
            }
            g.start ("stop").attr ("offset", "0").attr ("stop-color", Colors.to_hex (c1)).attr ("stop-opacity", PathData.fmt (c1.a, 3)).end ();
            g.start ("stop").attr ("offset", "1").attr ("stop-color", Colors.to_hex (c2)).attr ("stop-opacity", PathData.fmt (c2.a, 3)).end ();
            g.end ();
            defs.append (g.finish ());
            return id;
        }

        private string shadow_filter (Style st) {
            string id = next_id ("shadow");
            Rgba c;
            if (!Colors.parse (st.shadow_color, out c)) c = Rgba (0, 0, 0, 0.25);
            var f = new XmlWriter (false, false);
            f.start ("filter").attr ("id", id).attr ("x", "-20%").attr ("y", "-20%").attr ("width", "140%").attr ("height", "140%");
            f.start ("feDropShadow").attr_num ("dx", st.shadow_dx, digits (3)).attr_num ("dy", st.shadow_dy, digits (3)).attr_num ("stdDeviation", st.shadow_blur / 2, digits (3))
                .attr ("flood-color", Colors.to_hex (c)).attr ("flood-opacity", PathData.fmt (c.a, 3)).end ();
            f.end ();
            defs.append (f.finish ());
            return id;
        }

        private void stroke_attrs (Style st) {
            if (!st.has_stroke ()) {
                w.attr ("stroke", "none");
                return;
            }
            paint_attrs ("stroke", st.stroke);
            w.attr_num ("stroke-width", st.stroke_width, digits (3));
            w.attr ("stroke-linejoin", "round");
            var pat = st.dash.pattern (st.stroke_width);
            if (pat.length > 0) {
                var sb = new StringBuilder ();
                foreach (double d in pat) {
                    if (sb.len > 0) sb.append_c (' ');
                    sb.append (PathData.fmt (d, digits (2)));
                }
                w.attr ("stroke-dasharray", sb.str);
            }
        }

        private string matrix_attr (Cairo.Matrix m) {
            return "matrix(%s %s %s %s %s %s)".printf (PathData.fmt (m.xx, 6), PathData.fmt (m.yx, 6), PathData.fmt (m.xy, 6),
                PathData.fmt (m.yy, 6), PathData.fmt (m.x0, digits (3)), PathData.fmt (m.y0, digits (3)));
        }

        private void write_item (Item it) {
            bool linked = it.link != "";
            bool alt = it.alt_title != "" || it.alt_text != "";
            if (linked) {
                string href = it.link.has_prefix ("page:") ? "#" + it.link : it.link;
                w.start ("a").attr ("xlink:href", href).attr ("href", href);
                if (it.link.has_prefix ("page:")) w.attr ("data-page", it.link.substring (5));
            }
            if (alt) {
                w.start ("g").attr ("role", "img").attr ("aria-label", it.alt_title != "" ? it.alt_title : it.alt_text);
                if (it.alt_title != "") w.element ("title", it.alt_title);
                if (it.alt_text != "") w.element ("desc", it.alt_text);
            }
            write_item_body (it);
            if (alt) w.end ();
            if (linked) w.end ();
        }

        private void write_background (Page p, int depth) {
            var bg = p.back_ref;
            if (bg == null || bg == p || depth > 6) return;
            write_background (bg, depth + 1);
            var saved = page;
            page = bg;
            foreach (var it in bg.items) if (bg.item_visible (it)) write_item (it);
            page = saved;
        }

        private void write_item_body (Item it) {
            var g = it as Group;
            if (g != null) {
                w.start ("g").attr ("id", it.id);
                foreach (var c in g.children) write_item (c);
                w.end ();
                return;
            }
            var c = it as Connector;
            if (c != null) {
                write_connector (c);
                return;
            }
            var s = it as Shape;
            if (s != null) write_shape (s);
        }

        private void raster_attrs (RasterItem r) {
            Layer? l = page != null ? page.layer_of (r) : null;
            w.attr ("data-sdraw-raster", "1");
            if (l == null || !l.raster) return;
            w.attr ("data-sdraw-layer", l.name);
            if (!l.visible) w.attr ("data-sdraw-hidden", "1").attr ("display", "none");
            if (l.locked) w.attr ("data-sdraw-locked", "1");
            if (l.opacity < 0.999) w.attr ("opacity", PathData.fmt (l.opacity, 4));
            if (l.blend != BlendMode.NORMAL) w.attr ("style", "mix-blend-mode:%s".printf (l.blend.to_id ()));
        }

        private void write_shape (Shape s) {
            var st = s.style;
            var geo = s.geometry ();
            w.start ("g").attr ("id", s.id);
            if (s.name != "") w.attr ("data-name", s.name);
            if (st.opacity < 0.999) w.attr ("opacity", PathData.fmt (st.opacity, 3));
            if (st.shadow) w.attr ("filter", "url(#%s)".printf (shadow_filter (st)));
            w.start ("g").attr ("transform", matrix_attr (s.transform ()));
            var img = s as ImageShape;
            if (img != null && img.bytes.length > 0) {
                w.start ("image").attr ("x", "0").attr ("y", "0").attr_num ("width", s.w, digits (3)).attr_num ("height", s.h, digits (3))
                    .attr ("preserveAspectRatio", "none")
                    .attr ("xlink:href", "data:%s;base64,%s".printf (img.mime, Base64.encode (img.bytes)));
                var ras = img as RasterItem;
                if (ras != null) raster_attrs (ras);
                w.end ();
                if (st.has_stroke ()) {
                    w.start ("rect").attr ("width", PathData.fmt (s.w, digits (3))).attr ("height", PathData.fmt (s.h, digits (3))).attr ("fill", "none");
                    stroke_attrs (st);
                    w.end ();
                }
            } else {
                string? grad = gradient (st, Rect (0, 0, s.w, s.h));
                foreach (var part in geo.parts) {
                    w.start ("path").attr ("d", part.path.to_svg (digits (2)));
                    string? pc = part.resolve_color (st);
                    if (pc != null) {
                        if (part.mode == PartMode.STROKE) {
                            w.attr ("fill", "none");
                            paint_attrs ("stroke", pc);
                            w.attr_num ("stroke-width", st.stroke_width > 0 ? st.stroke_width : 1.5, digits (3));
                            w.attr ("stroke-linejoin", "round");
                            w.attr ("stroke-linecap", "round");
                        } else {
                            paint_attrs ("fill", pc);
                            if (part.mode == PartMode.FILL_STROKE) stroke_attrs (st);
                            else w.attr ("stroke", "none");
                        }
                        if (part.path.has_closed_subpath () && part.path.split_subpaths ().size > 1) w.attr ("fill-rule", "evenodd");
                        w.end ();
                        continue;
                    }
                    switch (part.mode) {
                        case PartMode.FILL_STROKE:
                        case PartMode.FILL_ONLY:
                            if (grad != null) w.attr ("fill", "url(#%s)".printf (grad));
                            else if (st.has_fill ()) paint_attrs ("fill", st.fill);
                            else w.attr ("fill", "none");
                            if (part.mode == PartMode.FILL_STROKE) stroke_attrs (st);
                            else w.attr ("stroke", "none");
                            break;
                        case PartMode.FILL_SHADE:
                            if (st.has_fill ()) paint_attrs ("fill", Renderer.shade_color (st));
                            else w.attr ("fill", "none");
                            stroke_attrs (st);
                            break;
                        case PartMode.FILL_DARK:
                            paint_attrs ("fill", Colors.is_none (st.stroke) ? st.fill : st.stroke);
                            w.attr ("stroke", "none");
                            break;
                        case PartMode.STROKE:
                            w.attr ("fill", "none");
                            stroke_attrs (st);
                            break;
                    }
                    if (part.path.has_closed_subpath () && part.path.split_subpaths ().size > 1) w.attr ("fill-rule", "evenodd");
                    w.end ();
                }
            }
            var ps = s as PathShape;
            if ((ps != null && !ps.is_closed ()) || s.kind == "line-shape") {
                write_arrows (ps != null ? ps.local_path () : geo.parts[0].path, st);
            }
            var tb = s as TableShape;
            if (tb != null) write_table (tb);
            w.end ();
            if (tb == null) write_shape_text (s, geo);
            w.end ();
        }

        private void write_arrows (PathData p, Style st) {
            Point tip, dir;
            if (st.arrow_start != ArrowKind.NONE) {
                Renderer.end_tangent (p, true, out tip, out dir);
                write_arrow (tip, dir, st.arrow_start, st);
            }
            if (st.arrow_end != ArrowKind.NONE) {
                Renderer.end_tangent (p, false, out tip, out dir);
                write_arrow (tip, dir, st.arrow_end, st);
            }
        }

        private void write_arrow (Point tip, Point dir, ArrowKind k, Style st) {
            bool filled, closed;
            var p = Renderer.arrow_path (tip, dir, k, st, out filled, out closed);
            w.start ("path").attr ("d", p.to_svg (digits (2)));
            if (filled) paint_attrs ("fill", st.stroke);
            else if (closed) w.attr ("fill", "#ffffff");
            else w.attr ("fill", "none");
            paint_attrs ("stroke", st.stroke);
            w.attr_num ("stroke-width", double.max (st.stroke_width, 1), digits (3));
            w.end ();
        }

        private void write_table (TableShape t) {
            var st = t.style;
            if (t.header_row && t.rows > 0) {
                w.start ("rect").attr ("x", "0").attr ("y", "0").attr_num ("width", t.w, digits (3)).attr_num ("height", t.row_y (1), digits (3));
                paint_attrs ("fill", t.header_fill);
                w.end ();
            }
            var lines = new PathData ();
            for (int r = 1; r < t.rows; r++) {
                lines.move_to (0, t.row_y (r));
                lines.line_to (t.w, t.row_y (r));
            }
            for (int c = 1; c < t.cols; c++) {
                lines.move_to (t.col_x (c), 0);
                lines.line_to (t.col_x (c), t.h);
            }
            if (!lines.is_empty () && st.has_stroke ()) {
                w.start ("path").attr ("d", lines.to_svg (digits (2))).attr ("fill", "none");
                paint_attrs ("stroke", st.stroke);
                w.attr_num ("stroke-width", double.max (st.stroke_width * 0.75, 0.5), digits (3));
                w.end ();
            }
            w.start ("rect").attr ("x", "0").attr ("y", "0").attr_num ("width", t.w, digits (3)).attr_num ("height", t.h, digits (3)).attr ("fill", "none");
            stroke_attrs (st);
            w.end ();
            for (int r = 0; r < t.rows; r++) {
                for (int c = 0; c < t.cols; c++) {
                    string v = t.get_cell (r, c);
                    if (v == "") continue;
                    var cs = st.copy ();
                    if (r == 0 && t.header_row) cs.bold = true;
                    double cx = t.col_x (c), cw = t.col_x (c + 1) - cx;
                    double ry = t.row_y (r), rh = t.row_y (r + 1) - ry;
                    var block = measure (cs, v, double.max (cw - 10, 4), true);
                    double yy = ry + (rh - block.height) / 2;
                    write_text_block (cs, block, cx + 5, yy, double.max (cw - 10, 4));
                }
            }
        }

        private void font_attrs (Style st) {
            w.attr ("font-family", st.font_family);
            w.attr_num ("font-size", st.font_size * Units.PX_PER_PT, digits (3));
            if (st.bold) w.attr ("font-weight", "bold");
            if (st.italic) w.attr ("font-style", "italic");
            if (st.underline || st.strike) w.attr ("text-decoration", (st.underline ? "underline " : "") + (st.strike ? "line-through" : ""));
            paint_attrs ("fill", st.text_color);
        }

        private void write_text_block (Style st, TextBlock block, double x, double y, double width, Gee.List<TextRun>? runs = null) {
            w.start ("text");
            font_attrs (st);
            w.attr ("xml:space", "preserve");
            foreach (var line in block.lines) {
                if (line.text == "") continue;
                double lx = x + line.x;
                w.start ("tspan").attr_num ("x", lx, digits (2)).attr_num ("y", y + line.baseline, digits (2));
                if (runs == null) {
                    w.text (line.text).end ();
                    continue;
                }
                foreach (var r in RichRuns.slice (runs, line.start, line.text.length)) {
                    if (r.is_plain ()) {
                        w.text (r.text);
                        continue;
                    }
                    w.start ("tspan");
                    run_attrs (st, r);
                    w.text (r.text).end ();
                }
                w.end ();
            }
            w.end ();
        }

        private void run_attrs (Style st, TextRun r) {
            if (r.family != "" && r.family != st.font_family) w.attr ("font-family", r.family);
            if (r.size > 0 || r.big) w.attr_num ("font-size", r.eff_size (st) * Units.PX_PER_PT, digits (3));
            if (r.eff_bold (st) != st.bold) w.attr ("font-weight", r.eff_bold (st) ? "bold" : "normal");
            if (r.eff_italic (st) != st.italic) w.attr ("font-style", r.eff_italic (st) ? "italic" : "normal");
            if (r.eff_underline (st) != st.underline || r.eff_strike (st) != st.strike) {
                string deco = (r.eff_underline (st) ? "underline " : "") + (r.eff_strike (st) ? "line-through" : "");
                w.attr ("text-decoration", deco.strip () != "" ? deco.strip () : "none");
            }
            if (r.color != "") paint_attrs ("fill", r.color);
        }

        private void write_shape_text (Shape s, Geometry geo) {
            string text = s.display_text ();
            if (text == "") return;
            var st = s.style;
            var r = Renderer.text_rect_for (s, geo);
            var m = Renderer.text_matrix (s);
            w.start ("g").attr ("transform", matrix_attr (m));
            if (s.kind == "uml-class" || s.kind == "uml-interface") {
                double y = 4;
                bool first = true;
                var sections = text.split ("\n--\n");
                for (int i = 0; i < sections.length; i++) {
                    var ls = st.copy ();
                    if (first) {
                        ls.bold = true;
                        ls.halign = TextHAlign.CENTER;
                    }
                    var block = measure (ls, sections[i], s.w - 12, true);
                    if (!first) {
                        w.start ("path").attr ("d", "M0 %s L%s %s".printf (PathData.fmt (y, digits (2)), PathData.fmt (s.w, digits (2)), PathData.fmt (y, digits (2))));
                        stroke_attrs (st);
                        w.end ();
                        y += 4;
                    }
                    write_text_block (ls, block, 6, y, s.w - 12);
                    y += block.height + 4;
                    first = false;
                }
                w.end ();
                return;
            }
            if (s.kind == "swimlane-h" || s.kind == "pool" || s.kind == "bpmn-pool") {
                var block = measure (st, text, r.h - 8, st.wrap);
                w.start ("g").attr ("transform", "translate(%s %s) rotate(-90)".printf (PathData.fmt (r.x + r.w / 2, digits (2)), PathData.fmt (r.y + r.h / 2, digits (2))));
                write_text_block (st, block, -r.h / 2 + 4, -block.height / 2, r.h - 8);
                w.end ();
                w.end ();
                return;
            }
            var runs = text == s.text ? s.rich_runs () : null;
            var tb = measure (st, text, r.w, st.wrap, runs);
            double y = r.y;
            if (st.valign == TextVAlign.MIDDLE) y = r.y + (r.h - tb.height) / 2;
            else if (st.valign == TextVAlign.BOTTOM) y = r.y + r.h - tb.height;
            double x = r.x;
            if (!st.wrap) {
                if (st.halign == TextHAlign.CENTER) x = r.x + (r.w - tb.width) / 2;
                else if (st.halign == TextHAlign.RIGHT) x = r.x + r.w - tb.width;
            }
            write_text_block (st, tb, x, y, r.w, runs);
            w.end ();
        }

        private void write_connector (Connector c) {
            var st = c.style;
            var path = c.path ();
            var drawn = Renderer.shorten (path, Renderer.arrow_length (st.arrow_start, st) * 0.8, Renderer.arrow_length (st.arrow_end, st) * 0.8);
            w.start ("g").attr ("id", c.id);
            if (st.opacity < 0.999) w.attr ("opacity", PathData.fmt (st.opacity, 3));
            if (st.shadow) w.attr ("filter", "url(#%s)".printf (shadow_filter (st)));
            w.start ("path").attr ("d", drawn.to_svg (digits (2))).attr ("fill", "none");
            stroke_attrs (st);
            w.attr ("stroke-linecap", "round");
            w.end ();
            write_arrows (path, st);
            string text = c.display_text ();
            if (text != "") {
                var p = c.label_point ();
                var cruns = text == c.text ? c.rich_runs () : null;
                var block = measure (st, text, 0, false, cruns);
                string bg = Colors.is_none (st.fill) || st.fill_kind == FillKind.NONE ? "#ffffff" : st.fill;
                w.start ("rect").attr_num ("x", p.x - block.width / 2 - 3, digits (2)).attr_num ("y", p.y - block.height / 2 - 1, digits (2))
                    .attr_num ("width", block.width + 6, digits (2)).attr_num ("height", block.height + 2, digits (2));
                paint_attrs ("fill", bg);
                w.end ();
                var ls = st.copy ();
                ls.halign = TextHAlign.LEFT;
                write_text_block (ls, block, p.x - block.width / 2, p.y - block.height / 2, block.width, cruns);
            }
            w.end ();
        }
    }
}
