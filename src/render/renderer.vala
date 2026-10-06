namespace Singularity.Apps.Draw {

    public class RenderOptions {
        public bool background = true;
        public bool print = false;
        public bool draw_hidden_text = true;
        public string? editing_id = null;
        public bool decorations = true;
        public JumpMap? jumps = null;
        public Document? doc = null;
        public bool spelling = false;
    }

    public delegate bool SpellFunc (string word);

    public class Renderer {
        public static SpellFunc? speller = null;

        public static void draw_page (Cairo.Context cr, Page page, RenderOptions opts) {
            if (opts.background && !Colors.is_none (page.background)) {
                Rgba bg;
                Colors.parse (page.background, out bg);
                bg.apply (cr);
                cr.rectangle (0, 0, page.width, page.height);
                cr.fill ();
            }
            draw_background_pages (cr, page, opts, 0);
            draw_page_items (cr, page, opts);
            if (opts.decorations) draw_decorations (cr, page, opts);
        }

        private static void draw_background_pages (Cairo.Context cr, Page page, RenderOptions opts, int depth) {
            var bg = page.back_ref;
            if (bg == null || bg == page || depth > 6) return;
            draw_background_pages (cr, bg, opts, depth + 1);
            var o = new RenderOptions ();
            o.background = false;
            o.print = opts.print;
            o.decorations = false;
            draw_page_items (cr, bg, o);
        }

        public static void draw_page_items (Cairo.Context cr, Page page, RenderOptions opts) {
            JumpMap? jumps = page.jump_style != JumpStyle.NONE ? LineJumps.compute (page) : null;
            opts.jumps = jumps;
            draw_callout_leaders (cr, page);
            foreach (var it in page.items) {
                if (opts.print ? !page.item_printable (it) : !page.item_visible (it)) continue;
                var ras = it as RasterItem;
                if (ras != null) {
                    var l = page.layer_of (ras);
                    draw_raster (cr, ras, l != null ? l.opacity : 1, l != null ? l.blend : BlendMode.NORMAL);
                    continue;
                }
                string? over = DataGraphics.fill_override (page, it);
                if (over != null) {
                    var saved = it.style;
                    var tmp = saved.copy ();
                    tmp.fill = over;
                    if (tmp.fill_kind == FillKind.NONE || tmp.fill_kind == FillKind.LINEAR || tmp.fill_kind == FillKind.RADIAL) tmp.fill_kind = FillKind.SOLID;
                    it.style = tmp;
                    draw_item (cr, it, opts);
                    it.style = saved;
                } else {
                    draw_item (cr, it, opts);
                }
            }
        }

        public static void draw_raster (Cairo.Context cr, RasterItem r, double opacity, BlendMode blend) {
            var surf = r.pixels ();
            cr.save ();
            cr.transform (r.transform ());
            cr.rectangle (0, 0, r.w, r.h);
            cr.clip ();
            cr.scale (r.w / surf.get_width (), r.h / surf.get_height ());
            cr.set_source_surface (surf, 0, 0);
            double dx = 1, dy = 0;
            cr.user_to_device_distance (ref dx, ref dy);
            double zoom = Math.hypot (dx, dy);
            cr.get_source ().set_filter (zoom >= 2 ? Cairo.Filter.NEAREST : Cairo.Filter.GOOD);
            cr.set_operator (blend.to_operator ());
            cr.paint_with_alpha ((opacity * r.style.opacity).clamp (0, 1));
            cr.restore ();
        }

        public static void draw_items (Cairo.Context cr, Gee.List<Item> items, RenderOptions opts) {
            foreach (var it in items) draw_item (cr, it, opts);
        }

        public static void draw_item (Cairo.Context cr, Item it, RenderOptions opts) {
            var ras = it as RasterItem;
            if (ras != null) {
                draw_raster (cr, ras, 1, BlendMode.NORMAL);
                return;
            }
            var g = it as Group;
            if (g != null) {
                foreach (var c in g.children) draw_item (cr, c, opts);
                if (g.text != "" && opts.editing_id != g.id) draw_group_text (cr, g);
                return;
            }
            var c = it as Connector;
            if (c != null) {
                draw_connector (cr, c, opts);
                return;
            }
            var s = it as Shape;
            if (s != null) draw_shape (cr, s, opts);
        }

        public static Cairo.Pattern? fill_pattern (Style st, Rect box) {
            Rgba c1, c2;
            if (st.fill_kind == FillKind.NONE) return null;
            if (!Colors.parse (st.fill, out c1)) {
                if (st.fill_kind == FillKind.SOLID) return null;
                c1 = Rgba (1, 1, 1, 0);
            }
            if (st.fill_kind == FillKind.SOLID) return new Cairo.Pattern.rgba (c1.r, c1.g, c1.b, c1.a);
            if (!Colors.parse (st.fill2, out c2)) c2 = Rgba (1, 1, 1, 0);
            Cairo.Pattern pat;
            if (st.fill_kind == FillKind.LINEAR) {
                double a = st.gradient_angle * Math.PI / 180;
                double dx = Math.cos (a), dy = Math.sin (a);
                double half = (box.w * dx.abs () + box.h * dy.abs ()) / 2;
                double cx = box.cx (), cy = box.cy ();
                pat = new Cairo.Pattern.linear (cx - dx * half, cy - dy * half, cx + dx * half, cy + dy * half);
            } else {
                double rad = Math.hypot (box.w, box.h) / 2;
                pat = new Cairo.Pattern.radial (box.cx (), box.cy (), 0, box.cx (), box.cy (), rad);
            }
            pat.add_color_stop_rgba (0, c1.r, c1.g, c1.b, c1.a);
            pat.add_color_stop_rgba (1, c2.r, c2.g, c2.b, c2.a);
            return pat;
        }

        public static string shade_color (Style st) {
            string base_color = Colors.is_none (st.fill) ? "#ffffff" : st.fill;
            return Colors.mix (base_color, "#1f2a36", 0.16);
        }

        private static void set_stroke (Cairo.Context cr, Style st, double opacity) {
            Rgba sc;
            Colors.parse (st.stroke, out sc);
            sc.apply (cr, opacity);
            cr.set_line_width (st.stroke_width);
            cr.set_line_join (Cairo.LineJoin.ROUND);
            cr.set_line_cap (st.dash == DashKind.DOT ? Cairo.LineCap.ROUND : Cairo.LineCap.BUTT);
            var pat = st.dash.pattern (st.stroke_width);
            cr.set_dash (pat, 0);
        }

        private static void draw_shadow (Cairo.Context cr, Style st, Gee.List<PathData> paths, bool closed) {
            Rgba sc;
            if (!Colors.parse (st.shadow_color, out sc)) return;
            cr.save ();
            int passes = st.shadow_blur > 0.5 ? 4 : 1;
            for (int i = passes; i >= 1; i--) {
                double grow = st.shadow_blur * i / passes;
                double alpha = sc.a * st.opacity / passes * (passes > 1 ? 1.4 : 1);
                cr.new_path ();
                foreach (var p in paths) p.to_cairo (cr);
                cr.set_source_rgba (sc.r, sc.g, sc.b, alpha.clamp (0, 1));
                if (closed) cr.fill_preserve ();
                cr.set_line_width (st.stroke_width + grow * 2);
                cr.set_line_join (Cairo.LineJoin.ROUND);
                cr.set_dash (null, 0);
                cr.stroke ();
            }
            cr.restore ();
        }

        public static void draw_shape (Cairo.Context cr, Shape s, RenderOptions opts) {
            var st = s.style;
            var geo = s.geometry ();
            double op = st.opacity.clamp (0, 1);
            if (st.shadow) {
                var shadow_paths = new Gee.ArrayList<PathData> ();
                bool any_closed = false;
                foreach (var part in geo.parts) {
                    if (part.mode == PartMode.STROKE) continue;
                    shadow_paths.add (part.path);
                    any_closed = true;
                }
                if (shadow_paths.size == 0) foreach (var part in geo.parts) shadow_paths.add (part.path);
                cr.save ();
                cr.translate (st.shadow_dx, st.shadow_dy);
                cr.transform (s.transform ());
                draw_shadow (cr, st, shadow_paths, any_closed || s is ImageShape || s is TableShape);
                cr.restore ();
            }
            cr.save ();
            cr.transform (s.transform ());
            var img = s as ImageShape;
            if (img != null) {
                draw_image (cr, img, op);
            }
            var box = Rect (0, 0, s.w, s.h);
            foreach (var part in geo.parts) {
                cr.new_path ();
                part.path.to_cairo (cr);
                cr.set_fill_rule (Cairo.FillRule.WINDING);
                string? pc = part.resolve_color (st);
                if (pc != null) {
                    Rgba pcol;
                    if (Colors.parse (pc, out pcol)) {
                        if (part.mode == PartMode.STROKE) {
                            set_stroke (cr, st, op);
                            if (st.stroke_width <= 0) cr.set_line_width (1.5);
                            cr.set_line_cap (Cairo.LineCap.ROUND);
                            pcol.apply (cr, op);
                            cr.stroke_preserve ();
                        } else {
                            pcol.apply (cr, op);
                            cr.fill_preserve ();
                            if (part.mode == PartMode.FILL_STROKE && st.has_stroke ()) {
                                set_stroke (cr, st, op);
                                cr.stroke_preserve ();
                            }
                        }
                    }
                    cr.new_path ();
                    continue;
                }
                switch (part.mode) {
                    case PartMode.FILL_STROKE:
                    case PartMode.FILL_ONLY:
                        var pat = fill_pattern (st, box);
                        if (pat != null) {
                            if (op < 1) {
                                cr.push_group ();
                                cr.set_source (pat);
                                cr.fill_preserve ();
                                cr.pop_group_to_source ();
                                cr.paint_with_alpha (op);
                            } else {
                                cr.set_source (pat);
                                cr.fill_preserve ();
                            }
                        }
                        if (part.mode == PartMode.FILL_STROKE && st.has_stroke () && !(img != null)) {
                            set_stroke (cr, st, op);
                            cr.stroke_preserve ();
                        }
                        break;
                    case PartMode.FILL_SHADE:
                        if (st.has_fill ()) {
                            Rgba sh;
                            Colors.parse (shade_color (st), out sh);
                            sh.apply (cr, op);
                            cr.fill_preserve ();
                        }
                        if (st.has_stroke ()) {
                            set_stroke (cr, st, op);
                            cr.stroke_preserve ();
                        }
                        break;
                    case PartMode.FILL_DARK:
                        Rgba dk;
                        if (!Colors.parse (st.stroke, out dk)) Colors.parse (st.fill, out dk);
                        dk.apply (cr, op);
                        cr.fill_preserve ();
                        break;
                    case PartMode.STROKE:
                        if (st.has_stroke ()) {
                            set_stroke (cr, st, op);
                            cr.stroke_preserve ();
                        }
                        break;
                }
                cr.new_path ();
            }
            if (img != null && st.has_stroke ()) {
                cr.rectangle (0, 0, s.w, s.h);
                set_stroke (cr, st, op);
                cr.stroke ();
            }
            var ps = s as PathShape;
            if ((ps != null && !ps.is_closed ()) || s.kind == "line-shape") {
                PathData p = ps != null ? ps.local_path () : geo.parts[0].path;
                draw_path_arrows (cr, p, st, op);
            }
            var tb = s as TableShape;
            if (tb != null) draw_table (cr, tb, op);
            var gantt = s as GanttShape;
            if (gantt != null) gantt.draw_content (cr);
            if (s.kind.has_prefix ("org-")) draw_org_photo (cr, s);
            cr.restore ();
            if (tb == null && opts.editing_id != s.id) draw_shape_text (cr, s, geo);
        }

        public static void draw_decorations (Cairo.Context cr, Page page, RenderOptions opts) {
            DataGraphics.draw_page (cr, page);
        }

        public static void draw_callout_leaders (Cairo.Context cr, Page page) {
            foreach (var it in page.all_items ()) {
                var s = it as Shape;
                if (s == null || s.callout_target == "" || !page.item_visible (page.top_level (s))) continue;
                var t = page.find (s.callout_target) as Shape;
                if (t == null) continue;
                var tb = t.bounds ();
                var from = Router.perimeter_rect (s.bounds (), Point (tb.cx (), tb.cy ()));
                var to = Router.perimeter (t, Point (s.cx (), s.cy ()));
                Rgba sc;
                if (!Colors.parse (Colors.is_none (s.style.stroke) ? "#4a5561" : s.style.stroke, out sc)) continue;
                cr.save ();
                sc.apply (cr, s.style.opacity);
                cr.set_line_width (double.max (s.style.stroke_width, 1));
                cr.set_dash (null, 0);
                cr.move_to (from.x, from.y);
                cr.line_to (to.x, to.y);
                cr.stroke ();
                cr.arc (to.x, to.y, 2.5, 0, 2 * Math.PI);
                cr.fill ();
                cr.restore ();
            }
        }

        public static void draw_image (Cairo.Context cr, ImageShape img, double op) {
            var pix = pixbuf_for (img);
            if (pix == null) {
                cr.rectangle (0, 0, img.w, img.h);
                cr.set_source_rgba (0.5, 0.5, 0.5, 0.2);
                cr.fill ();
                cr.move_to (0, 0);
                cr.line_to (img.w, img.h);
                cr.move_to (img.w, 0);
                cr.line_to (0, img.h);
                cr.set_source_rgba (0.5, 0.5, 0.5, 0.6);
                cr.set_line_width (1);
                cr.stroke ();
                return;
            }
            cr.save ();
            cr.rectangle (0, 0, img.w, img.h);
            cr.clip ();
            double sx = img.w / pix.width, sy = img.h / pix.height;
            cr.scale (sx, sy);
            Gdk.cairo_set_source_pixbuf (cr, pix, 0, 0);
            var pat = cr.get_source ();
            pat.set_filter (sx < 1 || sy < 1 ? Cairo.Filter.GOOD : Cairo.Filter.BILINEAR);
            cr.paint_with_alpha (op);
            cr.restore ();
        }

        public static Gdk.Pixbuf? pixbuf_for (ImageShape img) {
            var cached = img.cache as Gdk.Pixbuf;
            if (cached != null) return cached;
            if (img.bytes.length == 0) return null;
            try {
                var loader = new Gdk.PixbufLoader ();
                loader.write (img.bytes);
                loader.close ();
                var pix = loader.get_pixbuf ();
                if (pix != null) {
                    img.cache = pix;
                    img.pixel_width = pix.width;
                    img.pixel_height = pix.height;
                }
                return pix;
            } catch (Error e) {
                return null;
            }
        }

        private static Gee.HashMap<string, Gdk.Pixbuf?>? photos = null;

        public static string? photo_path (Item it) {
            foreach (string k in new string[] { "Photo", "Picture", "Image", "photo", "picture", "image" }) {
                string? v = it.get_field (k);
                if (v != null && v.strip () != "") return v.strip ();
            }
            return null;
        }

        private static void draw_org_photo (Cairo.Context cr, Shape s) {
            string? path = photo_path (s);
            if (path == null) return;
            if (path.has_prefix ("file://")) path = File.new_for_uri (path).get_path () ?? path;
            if (photos == null) photos = new Gee.HashMap<string, Gdk.Pixbuf?> ();
            if (!photos.has_key (path)) {
                Gdk.Pixbuf? pb = null;
                try {
                    pb = new Gdk.Pixbuf.from_file_at_size (path, 160, 160);
                } catch (Error e) {
                }
                photos[path] = pb;
            }
            var pix = photos[path];
            if (pix == null) return;
            double av = double.min (s.h - 16, 40);
            double cx = 12 + av / 2, cy = s.h / 2, r = av / 2;
            cr.save ();
            cr.new_path ();
            cr.arc (cx, cy, r, 0, 2 * Math.PI);
            cr.clip ();
            double sc = av / double.min (pix.width, pix.height);
            cr.translate (cx - pix.width * sc / 2, cy - pix.height * sc / 2);
            cr.scale (sc, sc);
            Gdk.cairo_set_source_pixbuf (cr, pix, 0, 0);
            cr.paint ();
            cr.restore ();
        }

        public static void draw_group_text (Cairo.Context cr, Group g) {
            string text = g.display_text ();
            var b = g.bounds ();
            if (text == "" || b.is_empty ()) return;
            var st = g.style;
            var layout = item_layout (cr, g, st, text, b.w - 8, st.wrap);
            int lw, lh;
            layout.get_pixel_size (out lw, out lh);
            double y = b.y + (b.h - lh) / 2;
            if (st.valign == TextVAlign.TOP) y = b.y + 4;
            else if (st.valign == TextVAlign.BOTTOM) y = b.y2 () - lh - 4;
            Rgba tc;
            if (!Colors.parse (st.text_color, out tc)) tc = Rgba (0, 0, 0, 1);
            cr.save ();
            tc.apply (cr, st.opacity);
            cr.move_to (b.x + 4, y);
            Pango.cairo_show_layout (cr, layout);
            cr.restore ();
        }

        public static Pango.FontDescription font_for (Style st) {
            var fd = new Pango.FontDescription ();
            fd.set_family (st.font_family != "" ? st.font_family : "Sans");
            fd.set_absolute_size (double.max (st.font_size, 1) * Units.PX_PER_PT * Pango.SCALE);
            fd.set_weight (st.bold ? Pango.Weight.BOLD : Pango.Weight.NORMAL);
            fd.set_style (st.italic ? Pango.Style.ITALIC : Pango.Style.NORMAL);
            return fd;
        }

        public static Pango.Layout make_layout (Cairo.Context cr, Style st, string text, double width, bool wrap) {
            var layout = Pango.cairo_create_layout (cr);
            var fo = new Cairo.FontOptions ();
            fo.set_hint_metrics (Cairo.HintMetrics.OFF);
            fo.set_hint_style (Cairo.HintStyle.NONE);
            Pango.cairo_context_set_font_options (layout.get_context (), fo);
            layout.context_changed ();
            layout.set_font_description (font_for (st));
            if (wrap && width > 0) {
                layout.set_width ((int) (width * Pango.SCALE));
                layout.set_wrap (Pango.WrapMode.WORD_CHAR);
            }
            switch (st.halign) {
                case TextHAlign.LEFT: layout.set_alignment (Pango.Alignment.LEFT); break;
                case TextHAlign.RIGHT: layout.set_alignment (Pango.Alignment.RIGHT); break;
                default: layout.set_alignment (Pango.Alignment.CENTER); break;
            }
            var attrs = new Pango.AttrList ();
            attrs.insert (Pango.attr_insert_hyphens_new (false));
            if (st.underline) attrs.insert (Pango.attr_underline_new (Pango.Underline.SINGLE));
            if (st.strike) attrs.insert (Pango.attr_strikethrough_new (true));
            layout.set_attributes (attrs);
            layout.set_text (text, -1);
            return layout;
        }

        public static Pango.Layout item_layout (Cairo.Context cr, Item it, Style st, string text, double width, bool wrap) {
            var layout = make_layout (cr, st, text, width, wrap);
            var runs = text == it.text ? it.rich_runs () : null;
            if (runs != null) RichRuns.apply (layout, runs);
            return layout;
        }

        public static Cairo.Matrix text_matrix (Shape s) {
            var m = Cairo.Matrix.identity ();
            m.translate (s.x + s.w / 2, s.y + s.h / 2);
            if (s.rotation != 0) m.rotate (s.rotation * Math.PI / 180);
            m.translate (-s.w / 2, -s.h / 2);
            return m;
        }

        public static Rect text_rect_for (Shape s, Geometry geo) {
            var r = geo.text_rect;
            if (s.flip_h) r.x = s.w - r.x - r.w;
            if (s.flip_v) r.y = s.h - r.y - r.h;
            return r;
        }

        public static void draw_shape_text (Cairo.Context cr, Shape s, Geometry geo) {
            string text = s.display_text ();
            if (text == "") return;
            var st = s.style;
            cr.save ();
            cr.transform (text_matrix (s));
            var r = text_rect_for (s, geo);
            Rgba tc;
            if (!Colors.parse (st.text_color, out tc)) tc = Rgba (0, 0, 0, 1);
            if (s.kind == "uml-class" || s.kind == "uml-interface") {
                draw_compartments (cr, s, text, tc);
                cr.restore ();
                return;
            }
            if (s.kind == "swimlane-h" || s.kind == "pool" || s.kind == "bpmn-pool" || s.kind == "cff-phase-h") {
                cr.translate (r.x + r.w / 2, r.y + r.h / 2);
                cr.rotate (-Math.PI / 2);
                r = Rect (-r.h / 2 + 4, -r.w / 2, r.h - 8, r.w);
            }
            if (s.kind == "org-manager" || s.kind == "org-person" || s.kind == "org-assistant" || s.kind == "org-team") {
                draw_org_text (cr, s, text, r, tc);
                cr.restore ();
                return;
            }
            var layout = make_layout (cr, st, text, r.w, st.wrap);
            var runs = text == s.text ? s.rich_runs () : null;
            if (runs != null) RichRuns.apply (layout, runs);
            int lw, lh;
            layout.get_pixel_size (out lw, out lh);
            double y = r.y;
            if (st.valign == TextVAlign.MIDDLE) y = r.y + (r.h - lh) / 2;
            else if (st.valign == TextVAlign.BOTTOM) y = r.y + r.h - lh;
            double x = r.x;
            if (!st.wrap) {
                if (st.halign == TextHAlign.CENTER) x = r.x + (r.w - lw) / 2;
                else if (st.halign == TextHAlign.RIGHT) x = r.x + r.w - lw;
            }
            tc.apply (cr, st.opacity);
            cr.move_to (x, y);
            Pango.cairo_show_layout (cr, layout);
            if (speller != null) underline_misspelled (cr, layout, text, x, y);
            cr.restore ();
        }

        private static void underline_misspelled (Cairo.Context cr, Pango.Layout layout, string text, double x, double y) {
            int i = 0;
            int start = -1;
            unichar c;
            int prev = 0;
            while (true) {
                prev = i;
                bool more = text.get_next_char (ref i, out c);
                bool letter = more && (c.isalpha () || c == '\'');
                if (letter && start < 0) start = prev;
                if (!letter && start >= 0) {
                    string w = text.substring (start, prev - start);
                    while (w.has_suffix ("'")) w = w.substring (0, w.length - 1);
                    if (w.char_count () > 1 && !speller (w)) {
                        var a = layout.index_to_pos (start);
                        var b = layout.index_to_pos (start + w.length - 1);
                        double x1 = x + a.x / (double) Pango.SCALE, x2 = x + (b.x + b.width) / (double) Pango.SCALE;
                        double yy = y + (a.y + a.height) / (double) Pango.SCALE - 1;
                        if (x2 < x1) {
                            double t = x1;
                            x1 = x2;
                            x2 = t;
                        }
                        cr.save ();
                        cr.set_source_rgba (0.86, 0.15, 0.15, 0.9);
                        cr.set_line_width (0.8);
                        cr.move_to (x1, yy);
                        bool up = true;
                        for (double xx = x1 + 2; xx <= x2; xx += 2) {
                            cr.line_to (xx, up ? yy - 1.5 : yy);
                            up = !up;
                        }
                        cr.stroke ();
                        cr.restore ();
                    }
                    start = -1;
                }
                if (!more) break;
            }
        }

        private static void draw_org_text (Cairo.Context cr, Shape s, string text, Rect r, Rgba tc) {
            string[] lines = text.split ("\n", 2);
            var st = s.style;
            var title_style = st.copy ();
            title_style.bold = true;
            title_style.halign = TextHAlign.LEFT;
            var sub_style = st.copy ();
            sub_style.font_size = st.font_size * 0.85;
            sub_style.halign = TextHAlign.LEFT;
            var l1 = make_layout (cr, title_style, lines[0], r.w, true);
            l1.set_ellipsize (Pango.EllipsizeMode.END);
            Pango.Layout? l2 = lines.length > 1 ? make_layout (cr, sub_style, lines[1], r.w, true) : null;
            int w1, h1, w2 = 0, h2 = 0;
            l1.get_pixel_size (out w1, out h1);
            if (l2 != null) l2.get_pixel_size (out w2, out h2);
            double total = h1 + (l2 != null ? h2 + 2 : 0);
            double y = r.y + (r.h - total) / 2;
            tc.apply (cr, st.opacity);
            cr.move_to (r.x, y);
            Pango.cairo_show_layout (cr, l1);
            if (l2 != null) {
                cr.set_source_rgba (tc.r, tc.g, tc.b, tc.a * st.opacity * 0.72);
                cr.move_to (r.x, y + h1 + 2);
                Pango.cairo_show_layout (cr, l2);
            }
        }

        private static void draw_compartments (Cairo.Context cr, Shape s, string text, Rgba tc) {
            var st = s.style;
            var sections = new Gee.ArrayList<string> ();
            var cur = new StringBuilder ();
            foreach (string line in text.split ("\n")) {
                if (line.strip () == "--" || line.strip () == "---") {
                    sections.add (cur.str);
                    cur.truncate ();
                    continue;
                }
                if (cur.len > 0) cur.append_c ('\n');
                cur.append (line);
            }
            sections.add (cur.str);
            double y = 4;
            double pad = 6;
            for (int i = 0; i < sections.size; i++) {
                var ls = st.copy ();
                if (i == 0) {
                    ls.bold = true;
                    ls.halign = TextHAlign.CENTER;
                }
                var layout = make_layout (cr, ls, sections[i], s.w - 2 * pad, true);
                int lw, lh;
                layout.get_pixel_size (out lw, out lh);
                if (i > 0) {
                    Rgba sc;
                    if (Colors.parse (st.stroke, out sc)) {
                        sc.apply (cr, st.opacity);
                        cr.set_line_width (st.stroke_width);
                        cr.set_dash (null, 0);
                        cr.move_to (s.w, y);
                        cr.line_to (0, y);
                        cr.stroke ();
                    }
                    y += 4;
                }
                tc.apply (cr, st.opacity);
                cr.move_to (pad, y);
                Pango.cairo_show_layout (cr, layout);
                y += lh + 4;
            }
        }

        private static void draw_table (Cairo.Context cr, TableShape t, double op) {
            var st = t.style;
            if (t.header_row && t.rows > 0) {
                Rgba hf;
                if (Colors.parse (t.header_fill, out hf)) {
                    hf.apply (cr, op);
                    cr.rectangle (0, 0, t.w, t.row_y (1));
                    cr.fill ();
                }
            }
            Rgba sc;
            if (Colors.parse (st.stroke, out sc) && st.stroke_width > 0) {
                sc.apply (cr, op);
                cr.set_line_width (double.max (st.stroke_width * 0.75, 0.5));
                cr.set_dash (null, 0);
                for (int r = 1; r < t.rows; r++) {
                    cr.move_to (0, t.row_y (r));
                    cr.line_to (t.w, t.row_y (r));
                }
                for (int c = 1; c < t.cols; c++) {
                    cr.move_to (t.col_x (c), 0);
                    cr.line_to (t.col_x (c), t.h);
                }
                cr.stroke ();
                cr.set_line_width (st.stroke_width);
                cr.rectangle (0, 0, t.w, t.h);
                cr.stroke ();
            }
            Rgba tc;
            if (!Colors.parse (st.text_color, out tc)) tc = Rgba (0, 0, 0, 1);
            for (int r = 0; r < t.rows; r++) {
                for (int c = 0; c < t.cols; c++) {
                    string v = t.get_cell (r, c);
                    if (v == "") continue;
                    var cs = st;
                    if (r == 0 && t.header_row) {
                        cs = st.copy ();
                        cs.bold = true;
                    }
                    double cx = t.col_x (c), cw = t.col_x (c + 1) - cx;
                    double ry = t.row_y (r), rh = t.row_y (r + 1) - ry;
                    var layout = make_layout (cr, cs, v, double.max (cw - 10, 4), true);
                    int lw, lh;
                    layout.get_pixel_size (out lw, out lh);
                    cr.save ();
                    cr.rectangle (cx, ry, cw, rh);
                    cr.clip ();
                    tc.apply (cr, op);
                    double yy = ry + (rh - lh) / 2;
                    if (cs.valign == TextVAlign.TOP) yy = ry + 4;
                    else if (cs.valign == TextVAlign.BOTTOM) yy = ry + rh - lh - 4;
                    cr.move_to (cx + 5, yy);
                    Pango.cairo_show_layout (cr, layout);
                    cr.restore ();
                }
            }
        }

        public static double arrow_length (ArrowKind k, Style st) {
            double sz = (6 + st.stroke_width * 2.2) * st.arrow_size;
            switch (k) {
                case ArrowKind.NONE: return 0;
                case ArrowKind.DIAMOND:
                case ArrowKind.DIAMOND_OPEN:
                    return sz * 1.6;
                case ArrowKind.CIRCLE:
                case ArrowKind.CIRCLE_OPEN:
                    return sz * 0.9;
                case ArrowKind.BAR:
                case ArrowKind.OPEN:
                case ArrowKind.CROWS_FOOT:
                case ArrowKind.ONE:
                    return 0;
                default:
                    return sz;
            }
        }

        public static void end_tangent (PathData p, bool at_start, out Point tip, out Point dir) {
            tip = Point (0, 0);
            dir = Point (1, 0);
            var segs = p.segs;
            if (segs.size == 0) return;
            if (at_start) {
                var first = segs[0];
                tip = Point (first.x, first.y);
                for (int i = 1; i < segs.size; i++) {
                    var s = segs[i];
                    if (s.kind == SegKind.CLOSE || s.kind == SegKind.MOVE) break;
                    double ox = s.kind == SegKind.CURVE ? s.x1 : s.x, oy = s.kind == SegKind.CURVE ? s.y1 : s.y;
                    if (Math.hypot (ox - tip.x, oy - tip.y) < 1e-6 && s.kind == SegKind.CURVE) {
                        ox = s.x2;
                        oy = s.y2;
                    }
                    if (Math.hypot (ox - tip.x, oy - tip.y) < 1e-6) {
                        ox = s.x;
                        oy = s.y;
                    }
                    double l = Math.hypot (tip.x - ox, tip.y - oy);
                    if (l > 1e-6) {
                        dir = Point ((tip.x - ox) / l, (tip.y - oy) / l);
                        return;
                    }
                }
                return;
            }
            int last = segs.size - 1;
            while (last > 0 && segs[last].kind == SegKind.CLOSE) last--;
            var ls = segs[last];
            tip = Point (ls.x, ls.y);
            for (int i = last; i >= 1; i--) {
                var s = segs[i];
                double ox, oy;
                if (i == last && s.kind == SegKind.CURVE) {
                    ox = s.x2;
                    oy = s.y2;
                    if (Math.hypot (ox - tip.x, oy - tip.y) < 1e-6) {
                        ox = s.x1;
                        oy = s.y1;
                    }
                } else {
                    var prev = segs[i - 1];
                    ox = prev.x;
                    oy = prev.y;
                }
                if (i == last && s.kind == SegKind.LINE) {
                    var prev = segs[i - 1];
                    ox = prev.x;
                    oy = prev.y;
                }
                double l = Math.hypot (tip.x - ox, tip.y - oy);
                if (l > 1e-6) {
                    dir = Point ((tip.x - ox) / l, (tip.y - oy) / l);
                    return;
                }
            }
        }

        public static PathData shorten (PathData p, double start_cut, double end_cut) {
            var q = p.copy ();
            if (q.segs.size < 2) return q;
            if (start_cut > 0) {
                Point tip, dir;
                end_tangent (q, true, out tip, out dir);
                var first = q.segs[0];
                first.x = tip.x - dir.x * start_cut;
                first.y = tip.y - dir.y * start_cut;
            }
            if (end_cut > 0) {
                Point tip, dir;
                end_tangent (q, false, out tip, out dir);
                int last = q.segs.size - 1;
                while (last > 0 && q.segs[last].kind == SegKind.CLOSE) last--;
                var ls = q.segs[last];
                double nx = tip.x - dir.x * end_cut, ny = tip.y - dir.y * end_cut;
                if (ls.kind == SegKind.CURVE) {
                    ls.x2 += nx - ls.x;
                    ls.y2 += ny - ls.y;
                }
                ls.x = nx;
                ls.y = ny;
            }
            return q;
        }

        public static void draw_path_arrows (Cairo.Context cr, PathData p, Style st, double op) {
            if (st.arrow_start == ArrowKind.NONE && st.arrow_end == ArrowKind.NONE) return;
            Point tip, dir;
            if (st.arrow_start != ArrowKind.NONE) {
                end_tangent (p, true, out tip, out dir);
                draw_arrow (cr, tip, dir, st.arrow_start, st, op);
            }
            if (st.arrow_end != ArrowKind.NONE) {
                end_tangent (p, false, out tip, out dir);
                draw_arrow (cr, tip, dir, st.arrow_end, st, op);
            }
        }

        public static PathData arrow_path (Point tip, Point dir, ArrowKind k, Style st, out bool filled, out bool closed) {
            double sz = (6 + st.stroke_width * 2.2) * st.arrow_size;
            double px = -dir.y, py = dir.x;
            var p = new PathData ();
            filled = true;
            closed = true;
            double bx = tip.x - dir.x * sz, by = tip.y - dir.y * sz;
            switch (k) {
                case ArrowKind.TRIANGLE:
                case ArrowKind.TRIANGLE_OPEN:
                    p.add_polygon ({ tip, Point (bx + px * sz * 0.45, by + py * sz * 0.45), Point (bx - px * sz * 0.45, by - py * sz * 0.45) });
                    filled = k == ArrowKind.TRIANGLE;
                    break;
                case ArrowKind.STEALTH:
                    double mx = tip.x - dir.x * sz * 0.7, my = tip.y - dir.y * sz * 0.7;
                    p.add_polygon ({ tip, Point (bx + px * sz * 0.45, by + py * sz * 0.45), Point (mx, my), Point (bx - px * sz * 0.45, by - py * sz * 0.45) });
                    break;
                case ArrowKind.OPEN:
                    p.move_to (bx + px * sz * 0.45, by + py * sz * 0.45);
                    p.line_to (tip.x, tip.y);
                    p.line_to (bx - px * sz * 0.45, by - py * sz * 0.45);
                    filled = false;
                    closed = false;
                    break;
                case ArrowKind.DIAMOND:
                case ArrowKind.DIAMOND_OPEN:
                    double l = sz * 1.6;
                    double mdx = tip.x - dir.x * l / 2, mdy = tip.y - dir.y * l / 2;
                    p.add_polygon ({ tip, Point (mdx + px * sz * 0.4, mdy + py * sz * 0.4), Point (tip.x - dir.x * l, tip.y - dir.y * l), Point (mdx - px * sz * 0.4, mdy - py * sz * 0.4) });
                    filled = k == ArrowKind.DIAMOND;
                    break;
                case ArrowKind.CIRCLE:
                case ArrowKind.CIRCLE_OPEN:
                    double rr = sz * 0.45;
                    p.add_ellipse (tip.x - dir.x * rr, tip.y - dir.y * rr, rr, rr);
                    filled = k == ArrowKind.CIRCLE;
                    break;
                case ArrowKind.BAR:
                    p.move_to (tip.x + px * sz * 0.5, tip.y + py * sz * 0.5);
                    p.line_to (tip.x - px * sz * 0.5, tip.y - py * sz * 0.5);
                    filled = false;
                    closed = false;
                    break;
                case ArrowKind.CROWS_FOOT:
                    p.move_to (tip.x + px * sz * 0.55, tip.y + py * sz * 0.55);
                    p.line_to (bx, by);
                    p.line_to (tip.x - px * sz * 0.55, tip.y - py * sz * 0.55);
                    p.move_to (tip.x, tip.y);
                    p.line_to (bx, by);
                    p.move_to (bx - dir.x * 3 + px * sz * 0.45, by - dir.y * 3 + py * sz * 0.45);
                    p.line_to (bx - dir.x * 3 - px * sz * 0.45, by - dir.y * 3 - py * sz * 0.45);
                    filled = false;
                    closed = false;
                    break;
                case ArrowKind.ONE:
                    double ox = tip.x - dir.x * sz * 0.6, oy = tip.y - dir.y * sz * 0.6;
                    p.move_to (ox + px * sz * 0.5, oy + py * sz * 0.5);
                    p.line_to (ox - px * sz * 0.5, oy - py * sz * 0.5);
                    double ox2 = tip.x - dir.x * sz, oy2 = tip.y - dir.y * sz;
                    p.move_to (ox2 + px * sz * 0.5, oy2 + py * sz * 0.5);
                    p.line_to (ox2 - px * sz * 0.5, oy2 - py * sz * 0.5);
                    filled = false;
                    closed = false;
                    break;
                default:
                    break;
            }
            return p;
        }

        public static void draw_arrow (Cairo.Context cr, Point tip, Point dir, ArrowKind k, Style st, double op) {
            bool filled, closed;
            var p = arrow_path (tip, dir, k, st, out filled, out closed);
            Rgba sc;
            if (!Colors.parse (st.stroke, out sc)) return;
            cr.save ();
            cr.new_path ();
            p.to_cairo (cr);
            cr.set_dash (null, 0);
            cr.set_line_join (Cairo.LineJoin.MITER);
            cr.set_line_width (double.max (st.stroke_width, 1));
            if (filled) {
                sc.apply (cr, op);
                cr.fill_preserve ();
                cr.stroke ();
            } else {
                if (closed) {
                    cr.set_source_rgba (1, 1, 1, op);
                    cr.fill_preserve ();
                }
                sc.apply (cr, op);
                cr.stroke ();
            }
            cr.restore ();
        }

        public static void draw_connector (Cairo.Context cr, Connector c, RenderOptions opts) {
            var st = c.style;
            double op = st.opacity.clamp (0, 1);
            var path = c.path ();
            var drawn = shorten (path, arrow_length (st.arrow_start, st) * 0.8, arrow_length (st.arrow_end, st) * 0.8);
            var jl = opts.jumps != null ? opts.jumps.get_jumps (c) : null;
            if (jl != null && jl.size > 0 && c.points.length >= 2 && c.route != RouteKind.CURVED) {
                double r = (4 + st.stroke_width * 1.5) * opts.jumps.size;
                var jp = LineJumps.jumped_path (c, jl, opts.jumps.style, r);
                drawn = shorten (jp, arrow_length (st.arrow_start, st) * 0.8, arrow_length (st.arrow_end, st) * 0.8);
            }
            if (st.shadow) {
                var list = new Gee.ArrayList<PathData> ();
                list.add (drawn);
                cr.save ();
                cr.translate (st.shadow_dx, st.shadow_dy);
                draw_shadow (cr, st, list, false);
                cr.restore ();
            }
            if (st.has_stroke ()) {
                cr.save ();
                cr.new_path ();
                drawn.to_cairo (cr);
                set_stroke (cr, st, op);
                cr.set_line_cap (Cairo.LineCap.ROUND);
                cr.stroke ();
                cr.restore ();
                draw_path_arrows (cr, path, st, op);
            }
            if (opts.editing_id != c.id) draw_connector_label (cr, c);
        }

        public static Rect connector_label_rect (Cairo.Context cr, Connector c) {
            string text = c.display_text ();
            var p = c.label_point ();
            if (text == "") return Rect (p.x, p.y, 0, 0);
            var layout = item_layout (cr, c, c.style, text, 0, false);
            int lw, lh;
            layout.get_pixel_size (out lw, out lh);
            return Rect (p.x - lw / 2.0 - 4, p.y - lh / 2.0 - 2, lw + 8, lh + 4);
        }

        public static void draw_connector_label (Cairo.Context cr, Connector c) {
            string text = c.display_text ();
            if (text == "") return;
            var st = c.style;
            var p = c.label_point ();
            var layout = item_layout (cr, c, st, text, 0, false);
            int lw, lh;
            layout.get_pixel_size (out lw, out lh);
            cr.save ();
            Rgba bg;
            string label_bg = Colors.is_none (st.fill) || st.fill_kind == FillKind.NONE ? "#ffffff" : st.fill;
            if (Colors.parse (label_bg, out bg)) {
                bg.apply (cr, st.opacity * 0.92);
                cr.rectangle (p.x - lw / 2.0 - 3, p.y - lh / 2.0 - 1, lw + 6, lh + 2);
                cr.fill ();
            }
            Rgba tc;
            if (!Colors.parse (st.text_color, out tc)) tc = Rgba (0, 0, 0, 1);
            tc.apply (cr, st.opacity);
            cr.move_to (p.x - lw / 2.0, p.y - lh / 2.0);
            Pango.cairo_show_layout (cr, layout);
            cr.restore ();
        }

        public static void draw_thumbnail (Cairo.Context cr, Page page, double width, double height, bool content_only = false) {
            var bounds = content_only ? page.content_bounds () : Rect (0, 0, page.width, page.height);
            if (bounds.is_empty () || bounds.w < 1 || bounds.h < 1) bounds = Rect (0, 0, page.width, page.height);
            bounds = content_only ? bounds.inflate (20) : bounds;
            double sc = double.min (width / bounds.w, height / bounds.h);
            cr.save ();
            cr.translate ((width - bounds.w * sc) / 2, (height - bounds.h * sc) / 2);
            cr.scale (sc, sc);
            cr.translate (-bounds.x, -bounds.y);
            var opts = new RenderOptions ();
            opts.background = !content_only;
            draw_page (cr, page, opts);
            cr.restore ();
        }
    }
}
