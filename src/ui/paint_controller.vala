using Gtk;

namespace Singularity.Apps.Draw {

    public enum PaintTool {
        PENCIL,
        BRUSH,
        AIRBRUSH,
        MARKER,
        ERASER,
        FILL,
        PICKER,
        SELECT_RECT,
        SELECT_ELLIPSE,
        LASSO,
        TRANSFORM,
        PAN;

        public bool is_brush () {
            return this == PENCIL || this == BRUSH || this == AIRBRUSH || this == MARKER || this == ERASER;
        }

        public bool is_select () {
            return this == SELECT_RECT || this == SELECT_ELLIPSE || this == LASSO;
        }

        public BrushKind brush_kind () {
            switch (this) {
                case PENCIL: return BrushKind.PENCIL;
                case AIRBRUSH: return BrushKind.AIRBRUSH;
                case MARKER: return BrushKind.MARKER;
                case ERASER: return BrushKind.ERASER;
                default: return BrushKind.BRUSH;
            }
        }

        public string label () {
            switch (this) {
                case PENCIL: return _("Pencil");
                case BRUSH: return _("Brush");
                case AIRBRUSH: return _("Airbrush");
                case MARKER: return _("Marker");
                case ERASER: return _("Eraser");
                case FILL: return _("Fill");
                case PICKER: return _("Color Picker");
                case SELECT_RECT: return _("Rectangle Selection");
                case SELECT_ELLIPSE: return _("Ellipse Selection");
                case LASSO: return _("Lasso Selection");
                case TRANSFORM: return _("Move and Transform");
                default: return _("Pan");
            }
        }

        public string icon () {
            switch (this) {
                case PENCIL: return "draw-pencil-symbolic";
                case BRUSH: return "draw-brush-symbolic";
                case AIRBRUSH: return "draw-airbrush-symbolic";
                case MARKER: return "draw-marker-symbolic";
                case ERASER: return "draw-eraser-symbolic";
                case FILL: return "draw-bucket-symbolic";
                case PICKER: return "draw-picker-symbolic";
                case SELECT_RECT: return "draw-select-rect-symbolic";
                case SELECT_ELLIPSE: return "draw-select-ellipse-symbolic";
                case LASSO: return "draw-lasso-symbolic";
                case TRANSFORM: return "draw-transform-symbolic";
                default: return "draw-hand-symbolic";
            }
        }

        public string shortcut () {
            switch (this) {
                case PENCIL: return "N";
                case BRUSH: return "B";
                case AIRBRUSH: return "A";
                case MARKER: return "K";
                case ERASER: return "E";
                case FILL: return "G";
                case PICKER: return "I";
                case SELECT_RECT: return "M";
                case SELECT_ELLIPSE: return "O";
                case LASSO: return "L";
                case TRANSFORM: return "V";
                default: return "H";
            }
        }

        public static PaintTool[] all () {
            return { PENCIL, BRUSH, AIRBRUSH, MARKER, ERASER, FILL, PICKER, SELECT_RECT, SELECT_ELLIPSE, LASSO, TRANSFORM, PAN };
        }
    }

    public class PaintController : Object {
        public Canvas canvas { get; private set; }
        public Document doc { get; private set; }
        public bool active { get; private set; default = false; }
        public PaintTool tool { get; private set; default = PaintTool.BRUSH; }
        public string color = "#1f4e79";
        public double tolerance = 12;
        public bool sample_merged = true;
        public RasterSelection? selection = null;
        public FloatingSelection? floating = null;
        public double last_pressure = 1;
        public bool last_from_tablet = false;
        private Gee.HashMap<int, BrushSettings> brushes = new Gee.HashMap<int, BrushSettings> ();

        public signal void changed ();
        public signal void message (string text);

        private StrokeEngine? engine = null;
        private Stabilizer? stab = null;
        private RasterItem? stroke_item = null;
        private uint air_id = 0;
        private int64 air_last = 0;
        private bool hovering = false;
        private double hover_x;
        private double hover_y;
        private bool selecting = false;
        private double sel_x0;
        private double sel_y0;
        private double sel_x1;
        private double sel_y1;
        private SelectOp sel_op = SelectOp.REPLACE;
        private Gee.ArrayList<Point?> lasso = new Gee.ArrayList<Point?> ();
        private int grab = -1;
        private double grab_x;
        private double grab_y;
        private double grab_tx;
        private double grab_ty;
        private double grab_sx;
        private double grab_sy;
        private double grab_angle;
        private bool picking = false;

        public const double HANDLE = 5;

        public PaintController (Canvas canvas) {
            this.canvas = canvas;
            this.doc = canvas.doc;
            foreach (var t in PaintTool.all ()) if (t.is_brush ()) brushes[(int) t] = new BrushSettings (t.brush_kind ());
            doc.restored.connect (() => {
                floating = null;
                stop_air ();
                engine = null;
            });
        }

        public BrushSettings brush_for (PaintTool t) {
            if (!brushes.has_key ((int) t)) brushes[(int) t] = new BrushSettings (t.brush_kind ());
            return brushes[(int) t];
        }

        public BrushSettings current_brush () {
            return brush_for (tool.is_brush () ? tool : PaintTool.BRUSH);
        }

        public Rgba color_rgba () {
            Rgba c;
            if (!Colors.parse (color, out c)) c = Rgba (0, 0, 0, 1);
            return c;
        }

        public void activate () {
            if (active) return;
            active = true;
            var page = doc.page;
            var l = page.find_layer (page.active_layer);
            if (l == null || !l.raster) {
                Layer? top = null;
                foreach (var pl in page.layers) if (pl.raster) top = pl;
                if (top != null) {
                    page.active_layer = top.id;
                } else {
                    doc.begin (_("Add Paint Layer"));
                    Raster.add_layer (doc, page);
                    doc.commit ();
                }
            }
            canvas.select (new Gee.ArrayList<Item> ());
            use_tool (tool);
            changed ();
            canvas.queue_draw ();
        }

        public void deactivate () {
            if (!active) return;
            commit_floating ();
            finish_stroke ();
            selection = null;
            active = false;
            canvas.use_tool (Tool.SELECT);
            canvas.set_cursor_from_name (null);
            changed ();
            canvas.queue_draw ();
        }

        public void use_tool (PaintTool t) {
            if (t != PaintTool.TRANSFORM) commit_floating ();
            tool = t;
            if (!active) return;
            canvas.use_tool (t == PaintTool.PAN ? Tool.PAN : Tool.SELECT);
            switch (t) {
                case PaintTool.PAN: canvas.set_cursor_from_name ("grab"); break;
                case PaintTool.TRANSFORM: canvas.set_cursor_from_name ("move"); break;
                case PaintTool.PICKER: canvas.set_cursor_from_name ("crosshair"); break;
                case PaintTool.FILL: canvas.set_cursor_from_name ("cell"); break;
                default: canvas.set_cursor_from_name (t.is_brush () ? "none" : "crosshair"); break;
            }
            changed ();
            canvas.queue_draw ();
        }

        public Layer? active_layer () {
            return doc.page.find_layer (doc.page.active_layer);
        }

        public RasterItem? target () {
            var l = active_layer ();
            if (l == null || !l.raster) return null;
            return Raster.item_for (doc.page, l.id);
        }

        private RasterItem? ensure_target () {
            var r = target ();
            if (r != null) return r;
            var page = doc.page;
            var cur = active_layer ();
            int idx = cur != null ? page.layers.index_of (cur) + 1 : -1;
            Raster.add_layer (doc, page, null, null, idx);
            changed ();
            return target ();
        }

        private bool editable (Layer? l) {
            if (l == null) return false;
            if (!l.visible) {
                message (_("Show the layer to paint on it."));
                return false;
            }
            if (l.locked) {
                message (_("The layer is locked."));
                return false;
            }
            return true;
        }

        private uint8[]? selection_bytes (RasterItem r) {
            if (selection == null || selection.w != r.pixel_w || selection.h != r.pixel_h) return null;
            return selection.bytes ();
        }

        public static double pressure_of (EventController g, out bool eraser, out bool tablet) {
            eraser = false;
            tablet = false;
            var ev = g.get_current_event ();
            if (ev == null) return 1;
            var dt = ev.get_device_tool ();
            if (dt != null && dt.get_tool_type () == Gdk.DeviceToolType.ERASER) eraser = true;
            double p;
            if (ev.get_axis (Gdk.AxisUse.PRESSURE, out p)) {
                tablet = true;
                return p.clamp (0, 1);
            }
            return 1;
        }

        public bool press (EventController g, double x, double y) {
            bool eraser, tablet;
            double p = pressure_of (g, out eraser, out tablet);
            var state = g.get_current_event_state ();
            return press_at (x, y, p, eraser, tablet, state);
        }

        public void drag (EventController g, double x, double y) {
            bool eraser, tablet;
            double p = pressure_of (g, out eraser, out tablet);
            drag_to (x, y, p, g.get_current_event_state ());
        }

        public void release (EventController g, double x, double y) {
            release_at (x, y);
        }

        public bool press_at (double x, double y, double pressure, bool eraser_tip = false, bool tablet = false, Gdk.ModifierType state = 0) {
            last_pressure = pressure;
            last_from_tablet = tablet;
            if (tool.is_brush ()) return begin_stroke (x, y, pressure, eraser_tip);
            switch (tool) {
                case PaintTool.FILL:
                    fill_at (x, y);
                    return false;
                case PaintTool.PICKER:
                    pick_at (x, y);
                    picking = true;
                    return true;
                case PaintTool.SELECT_RECT:
                case PaintTool.SELECT_ELLIPSE:
                case PaintTool.LASSO:
                    commit_floating ();
                    selecting = true;
                    sel_op = SelectOp.REPLACE;
                    if ((state & Gdk.ModifierType.SHIFT_MASK) != 0) sel_op = SelectOp.ADD;
                    if ((state & (Gdk.ModifierType.ALT_MASK | Gdk.ModifierType.CONTROL_MASK)) != 0) sel_op = SelectOp.SUBTRACT;
                    sel_x0 = sel_x1 = x;
                    sel_y0 = sel_y1 = y;
                    lasso.clear ();
                    lasso.add (Point (x, y));
                    canvas.queue_draw ();
                    return true;
                case PaintTool.TRANSFORM:
                    return transform_press (x, y);
                default:
                    return false;
            }
        }

        public void drag_to (double x, double y, double pressure, Gdk.ModifierType state = 0) {
            last_pressure = pressure;
            hover_x = x;
            hover_y = y;
            hovering = true;
            if (engine != null) {
                stroke_point (x, y, pressure);
                return;
            }
            if (picking) {
                pick_at (x, y);
                return;
            }
            if (selecting) {
                sel_x1 = x;
                sel_y1 = y;
                if ((state & Gdk.ModifierType.SHIFT_MASK) != 0 && tool != PaintTool.LASSO && sel_op == SelectOp.REPLACE) {
                    double d = double.max ((sel_x1 - sel_x0).abs (), (sel_y1 - sel_y0).abs ());
                    sel_x1 = sel_x0 + (sel_x1 >= sel_x0 ? d : -d);
                    sel_y1 = sel_y0 + (sel_y1 >= sel_y0 ? d : -d);
                }
                var last = lasso[lasso.size - 1];
                if (Math.hypot (last.x - x, last.y - y) * canvas.zoom >= 2) lasso.add (Point (x, y));
                canvas.queue_draw ();
                return;
            }
            if (grab >= 0) transform_drag (x, y, state);
        }

        public void release_at (double x, double y) {
            if (engine != null) {
                finish_stroke ();
                return;
            }
            if (picking) {
                picking = false;
                return;
            }
            if (selecting) {
                selecting = false;
                finish_selection ();
                return;
            }
            if (grab >= 0) {
                grab = -1;
                changed ();
                canvas.queue_draw ();
            }
        }

        private bool begin_stroke (double x, double y, double pressure, bool eraser_tip) {
            commit_floating ();
            doc.begin (tool.label ());
            var r = ensure_target ();
            if (r == null || !editable (active_layer ())) {
                doc.cancel ();
                return false;
            }
            r.detach ();
            var settings = eraser_tip ? brush_for (PaintTool.ERASER) : current_brush ();
            var scaled = settings.copy ();
            double ps = r.pixel_scale ();
            if ((ps - 1).abs () > 1e-6) scaled.size = settings.size * ps;
            engine = new StrokeEngine (r.pixels (), scaled, color_rgba (), selection_bytes (r));
            stab = new Stabilizer (settings.smoothing);
            stroke_item = r;
            var q = r.to_pixel (x, y);
            double ox, oy, op;
            stab.push (q.x, q.y, pressure, out ox, out oy, out op);
            engine.begin (ox, oy, op);
            engine.compose ();
            if (settings.kind == BrushKind.AIRBRUSH && !eraser_tip) {
                air_last = get_monotonic_time ();
                air_id = Timeout.add (30, () => {
                    if (engine == null) {
                        air_id = 0;
                        return Source.REMOVE;
                    }
                    int64 now = get_monotonic_time ();
                    engine.tick ((now - air_last) / 1000000.0);
                    air_last = now;
                    engine.compose ();
                    canvas.queue_draw ();
                    return Source.CONTINUE;
                });
            }
            canvas.queue_draw ();
            return true;
        }

        private void stroke_point (double x, double y, double pressure) {
            var q = stroke_item.to_pixel (x, y);
            double ox, oy, op;
            stab.push (q.x, q.y, pressure, out ox, out oy, out op);
            engine.line_to (ox, oy, op);
            engine.compose ();
            air_last = get_monotonic_time ();
            canvas.queue_draw ();
        }

        private void stop_air () {
            if (air_id != 0) {
                Source.remove (air_id);
                air_id = 0;
            }
        }

        private void finish_stroke () {
            stop_air ();
            if (engine == null) return;
            foreach (var q in stab.finish ()) engine.line_to (q.x, q.y, stab.pressure);
            engine.finish ();
            engine = null;
            stab = null;
            stroke_item.sync ();
            stroke_item = null;
            doc.commit ();
            canvas.queue_draw ();
        }

        public void stroke (Point[] pts, double[] pressures) {
            if (pts.length == 0) return;
            if (!press_at (pts[0].x, pts[0].y, pressures[0], false, true)) return;
            for (int i = 1; i < pts.length; i++) drag_to (pts[i].x, pts[i].y, pressures[int.min (i, pressures.length - 1)]);
            release_at (pts[pts.length - 1].x, pts[pts.length - 1].y);
        }

        public void fill_at (double x, double y) {
            commit_floating ();
            doc.begin (_("Fill"));
            var r = ensure_target ();
            if (r == null || !editable (active_layer ())) {
                doc.cancel ();
                return;
            }
            var q = r.to_pixel (x, y);
            int px = (int) Math.floor (q.x), py = (int) Math.floor (q.y);
            if (px < 0 || py < 0 || px >= r.pixel_w || py >= r.pixel_h) {
                doc.cancel ();
                return;
            }
            r.detach ();
            Cairo.ImageSurface source = r.pixels ();
            if (sample_merged) source = Export.render_area (doc.page, Rect (r.x, r.y, r.w, r.h), r.pixel_scale (), false);
            int tol = (int) Math.round (tolerance.clamp (0, 100) * 2.55);
            int n = FloodFill.fill (source, r.pixels (), px, py, color_rgba (), tol, selection_bytes (r));
            if (n == 0) {
                doc.cancel ();
                return;
            }
            r.sync ();
            doc.commit ();
        }

        public void pick_at (double x, double y) {
            var c = ColorSampler.sample (doc.page, x, y);
            if (!sample_merged) {
                var r = target ();
                if (r != null) {
                    var q = r.to_pixel (x, y);
                    c = ColorSampler.sample_surface (r.pixels (), (int) q.x, (int) q.y);
                }
            }
            if (c.a <= 0) return;
            color = Colors.to_hex (Rgba (c.r, c.g, c.b, 1));
            changed ();
        }

        private void finish_selection () {
            var r = target ();
            if (r == null) {
                canvas.queue_draw ();
                return;
            }
            var a = r.to_pixel (sel_x0, sel_y0);
            var b = r.to_pixel (sel_x1, sel_y1);
            PathData path;
            if (tool == PaintTool.LASSO) {
                var pts = new Gee.ArrayList<Point?> ();
                foreach (var q in lasso) pts.add (r.to_pixel (q.x, q.y));
                path = RasterSelection.lasso_path (pts);
            } else if (tool == PaintTool.SELECT_ELLIPSE) {
                path = RasterSelection.ellipse_path (a.x, a.y, b.x, b.y);
            } else {
                path = RasterSelection.rect_path (Math.round (a.x), Math.round (a.y), Math.round (b.x), Math.round (b.y));
            }
            var pb = path.bounds ();
            if (path.is_empty () || pb.w < 1 || pb.h < 1) {
                if (sel_op == SelectOp.REPLACE) selection = null;
                changed ();
                canvas.queue_draw ();
                return;
            }
            if (selection == null || selection.w != r.pixel_w || selection.h != r.pixel_h) selection = new RasterSelection (r.pixel_w, r.pixel_h);
            selection.combine (path, sel_op);
            if (selection.is_empty ()) selection = null;
            changed ();
            canvas.queue_draw ();
        }

        public void select_all () {
            var r = target ();
            if (r == null) return;
            commit_floating ();
            selection = new RasterSelection (r.pixel_w, r.pixel_h);
            selection.select_all ();
            changed ();
            canvas.queue_draw ();
        }

        public void deselect () {
            commit_floating ();
            selection = null;
            changed ();
            canvas.queue_draw ();
        }

        public void invert_selection () {
            var r = target ();
            if (r == null) return;
            if (selection == null) {
                select_all ();
                return;
            }
            selection.invert ();
            if (selection.is_empty ()) selection = null;
            changed ();
            canvas.queue_draw ();
        }

        public void clear_selection_pixels () {
            var r = target ();
            if (r == null || !editable (active_layer ())) return;
            commit_floating ();
            doc.begin (_("Clear"));
            r.detach ();
            if (selection != null && selection.w == r.pixel_w && selection.h == r.pixel_h) {
                selection.clear_pixels (r.pixels ());
            } else {
                var cr = new Cairo.Context (r.pixels ());
                cr.set_operator (Cairo.Operator.CLEAR);
                cr.paint ();
            }
            r.sync ();
            doc.commit ();
        }

        public void fill_selection () {
            var r = target ();
            if (r == null || !editable (active_layer ())) return;
            commit_floating ();
            doc.begin (_("Fill"));
            r.detach ();
            var cr = new Cairo.Context (r.pixels ());
            color_rgba ().apply (cr);
            if (selection != null && selection.w == r.pixel_w) cr.mask_surface (selection.mask, 0, 0);
            else cr.paint ();
            r.pixels ().flush ();
            r.sync ();
            doc.commit ();
        }

        private Point pix_to_page (RasterItem r, double qx, double qy) {
            return r.from_pixel (qx, qy);
        }

        private int transform_hit (double x, double y) {
            var r = target ();
            if (r == null || floating == null) return -1;
            double tolp = (HANDLE + 3) / canvas.zoom;
            var c = floating.corners ();
            for (int i = 0; i < 4; i++) {
                var p = pix_to_page (r, c[i].x, c[i].y);
                if (Math.hypot (p.x - x, p.y - y) <= tolp) return i;
            }
            var knob = rotate_knob (r);
            if (Math.hypot (knob.x - x, knob.y - y) <= tolp) return 4;
            var q = r.to_pixel (x, y);
            if (floating.contains (q.x, q.y)) return 5;
            return -1;
        }

        private Point rotate_knob (RasterItem r) {
            var top = floating.map (floating.bw / 2.0, 0);
            var ctr = floating.center ();
            double dx = top.x - ctr.x, dy = top.y - ctr.y;
            double len = Math.hypot (dx, dy);
            double off = 24 / canvas.zoom * r.pixel_scale ();
            if (len < 1e-6) return pix_to_page (r, top.x, top.y - off);
            return pix_to_page (r, top.x + dx / len * off, top.y + dy / len * off);
        }

        public bool lift () {
            if (floating != null) return true;
            var r = target ();
            if (r == null || !editable (active_layer ())) return false;
            if (selection == null || selection.w != r.pixel_w || selection.h != r.pixel_h) {
                selection = new RasterSelection (r.pixel_w, r.pixel_h);
                selection.select_all ();
            }
            doc.begin (_("Transform"));
            r.detach ();
            floating = FloatingSelection.lift (r.pixels (), selection);
            if (floating == null) {
                doc.revert_pending ();
                return false;
            }
            changed ();
            canvas.queue_draw ();
            return true;
        }

        private bool transform_press (double x, double y) {
            if (floating == null) {
                var r = target ();
                if (r == null) return false;
                var q = r.to_pixel (x, y);
                if (selection != null && selection.at ((int) q.x, (int) q.y) == 0) {
                    int bx, by, bw, bh;
                    if (!selection.bounds (out bx, out by, out bw, out bh) || q.x < bx || q.y < by || q.x > bx + bw || q.y > by + bh) return false;
                }
                if (!lift ()) return false;
            }
            grab = transform_hit (x, y);
            if (grab < 0) {
                commit_floating ();
                return false;
            }
            var r = target ();
            var q = r.to_pixel (x, y);
            grab_x = q.x;
            grab_y = q.y;
            grab_tx = floating.tx;
            grab_ty = floating.ty;
            grab_sx = floating.sx;
            grab_sy = floating.sy;
            grab_angle = floating.angle;
            return true;
        }

        private void transform_drag (double x, double y, Gdk.ModifierType state) {
            var r = target ();
            if (r == null || floating == null) return;
            var q = r.to_pixel (x, y);
            bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
            var ctr = floating.center ();
            if (grab == 5) {
                floating.tx = grab_tx + q.x - grab_x;
                floating.ty = grab_ty + q.y - grab_y;
            } else if (grab == 4) {
                double a0 = Math.atan2 (grab_y - ctr.y, grab_x - ctr.x);
                double a1 = Math.atan2 (q.y - ctr.y, q.x - ctr.x);
                double ang = grab_angle + a1 - a0;
                if (shift) ang = Math.round (ang / (Math.PI / 12)) * (Math.PI / 12);
                floating.angle = ang;
            } else if (grab >= 0 && grab < 4) {
                double ca = Math.cos (-floating.angle), sa = Math.sin (-floating.angle);
                double lx = (q.x - ctr.x) * ca - (q.y - ctr.y) * sa;
                double ly = (q.x - ctr.x) * sa + (q.y - ctr.y) * ca;
                double nsx = double.max (2 * lx.abs () / double.max (floating.bw, 1), 0.02);
                double nsy = double.max (2 * ly.abs () / double.max (floating.bh, 1), 0.02);
                if (shift) {
                    double k = double.max (nsx / double.max (grab_sx, 1e-6), nsy / double.max (grab_sy, 1e-6));
                    nsx = grab_sx * k;
                    nsy = grab_sy * k;
                }
                floating.sx = nsx;
                floating.sy = nsy;
            }
            changed ();
            canvas.queue_draw ();
        }

        public void set_transform (double scale_percent, double degrees) {
            if (floating == null && !lift ()) return;
            floating.sx = floating.sy = double.max (scale_percent, 1) / 100.0;
            floating.angle = degrees * Math.PI / 180;
            changed ();
            canvas.queue_draw ();
        }

        public void commit_floating () {
            if (floating == null) return;
            var r = target ();
            var f = floating;
            floating = null;
            if (r == null) {
                doc.cancel ();
                return;
            }
            f.stamp (r.pixels ());
            selection = f.selection (r.pixel_w, r.pixel_h);
            if (selection.is_empty ()) selection = null;
            r.sync ();
            doc.commit ();
            changed ();
            canvas.queue_draw ();
        }

        public void cancel_floating () {
            if (floating == null) return;
            floating = null;
            doc.revert_pending ();
            changed ();
            canvas.queue_draw ();
        }

        public void nudge (double dx, double dy) {
            if (floating == null && !lift ()) return;
            floating.tx += dx;
            floating.ty += dy;
            changed ();
            canvas.queue_draw ();
        }

        public void delete_floating () {
            if (floating == null) return;
            floating = null;
            var r = target ();
            if (r != null) {
                r.sync ();
                doc.commit ();
            }
            selection = null;
            changed ();
            canvas.queue_draw ();
        }

        public Cairo.ImageSurface? copy_pixels (out double page_x, out double page_y) {
            page_x = 0;
            page_y = 0;
            var r = target ();
            if (r == null) return null;
            int ox = 0, oy = 0;
            Cairo.ImageSurface? out_surf;
            if (floating != null) {
                out_surf = floating.rendered (out ox, out oy);
            } else if (selection != null && selection.w == r.pixel_w && selection.h == r.pixel_h) {
                out_surf = selection.extract (r.pixels (), out ox, out oy);
            } else {
                out_surf = Pixels.copy (r.pixels ());
            }
            var p = r.from_pixel (ox, oy);
            page_x = p.x;
            page_y = p.y;
            return out_surf;
        }

        public void cut_pixels () {
            if (floating != null) delete_floating ();
            else clear_selection_pixels ();
        }

        public bool paste_pixels (Cairo.ImageSurface src, bool has_origin, double page_x, double page_y) {
            commit_floating ();
            doc.begin (_("Paste"));
            var r = ensure_target ();
            if (r == null || !editable (active_layer ())) {
                doc.cancel ();
                return false;
            }
            r.detach ();
            int w = src.get_width (), h = src.get_height ();
            var v = canvas.visible_rect ();
            int ox, oy;
            var a = has_origin ? r.to_pixel (page_x, page_y) : Point (0, 0);
            var b = r.from_pixel (a.x + w, a.y + h);
            if (has_origin && v.intersects (Rect.from_points (page_x, page_y, b.x, b.y))) {
                ox = (int) Math.round (a.x);
                oy = (int) Math.round (a.y);
            } else {
                var c = r.to_pixel (v.cx (), v.cy ());
                ox = (int) Math.round (c.x - w / 2.0);
                oy = (int) Math.round (c.y - h / 2.0);
            }
            selection = null;
            floating = FloatingSelection.from_pixels (src, ox, oy);
            use_tool (PaintTool.TRANSFORM);
            changed ();
            canvas.queue_draw ();
            return true;
        }

        public void paint_floating (Cairo.Context cr, Layer layer, double opacity) {
            if (floating == null || !active || active_layer () != layer) return;
            var r = target ();
            if (r == null) return;
            cr.save ();
            cr.transform (r.transform ());
            cr.scale (r.w / double.max (r.pixel_w, 1), r.h / double.max (r.pixel_h, 1));
            floating.paint (cr, opacity);
            cr.restore ();
        }

        public void hover (double x, double y) {
            hover_x = x;
            hover_y = y;
            hovering = true;
            if (tool == PaintTool.TRANSFORM && floating != null && grab < 0) {
                int h = transform_hit (x, y);
                canvas.set_cursor_from_name (h == 5 ? "move" : (h == 4 ? "grab" : (h >= 0 ? "nwse-resize" : "default")));
            }
            if (tool.is_brush ()) canvas.queue_draw ();
        }

        public void leave () {
            hovering = false;
            canvas.queue_draw ();
        }

        public void set_size_delta (double factor) {
            if (!tool.is_brush ()) return;
            var b = current_brush ();
            b.size = (b.size * factor).clamp (1, 500);
            changed ();
            canvas.queue_draw ();
        }

        public bool key (uint keyval, Gdk.ModifierType state) {
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
            double step = shift ? 10 : 1;
            switch (keyval) {
                case Gdk.Key.Escape:
                    if (floating != null) cancel_floating ();
                    else if (selection != null) deselect ();
                    return true;
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    commit_floating ();
                    return true;
                case Gdk.Key.Delete:
                case Gdk.Key.BackSpace:
                    if (floating != null) {
                        delete_floating ();
                    } else {
                        clear_selection_pixels ();
                    }
                    return true;
                case Gdk.Key.Left:
                    if (!ctrl) nudge (-step, 0);
                    return !ctrl;
                case Gdk.Key.Right:
                    if (!ctrl) nudge (step, 0);
                    return !ctrl;
                case Gdk.Key.Up:
                    if (!ctrl) nudge (0, -step);
                    return !ctrl;
                case Gdk.Key.Down:
                    if (!ctrl) nudge (0, step);
                    return !ctrl;
                case Gdk.Key.Tab:
                case Gdk.Key.ISO_Left_Tab:
                    return true;
                case Gdk.Key.bracketleft:
                    if (ctrl) return false;
                    set_size_delta (1 / 1.2);
                    return true;
                case Gdk.Key.bracketright:
                    if (ctrl) return false;
                    set_size_delta (1.2);
                    return true;
                default:
                    break;
            }
            if (ctrl || (state & Gdk.ModifierType.ALT_MASK) != 0) return false;
            unichar ch = Gdk.keyval_to_unicode (keyval);
            if (ch == 0) return false;
            string up = ch.to_string ().up ();
            foreach (var t in PaintTool.all ()) {
                if (t.shortcut () == up) {
                    use_tool (t);
                    return true;
                }
            }
            return false;
        }

        public void draw_overlay (Cairo.Context cr, double zoom) {
            var r = target ();
            if (r != null && (selection != null || floating != null)) {
                cr.save ();
                cr.transform (r.transform ());
                double s = r.w / double.max (r.pixel_w, 1);
                cr.scale (s, (r.h / double.max (r.pixel_h, 1)));
                double lw = 1 / (zoom * s);
                if (floating != null) {
                    var l = active_layer ();
                    floating.paint (cr, l != null ? l.opacity : 1);
                    var m = floating.matrix ();
                    foreach (var p in floating.outlines) ants (cr, p.transformed (m), lw);
                    var c = floating.corners ();
                    var box = new PathData ();
                    box.add_polygon (c, true);
                    ants (cr, box, lw);
                } else {
                    foreach (var p in selection.outlines) ants (cr, p, lw);
                }
                cr.restore ();
                if (floating != null) draw_handles (cr, r, zoom);
            }
            if (selecting) {
                PathData path;
                if (tool == PaintTool.LASSO) path = RasterSelection.lasso_path (lasso);
                else if (tool == PaintTool.SELECT_ELLIPSE) path = RasterSelection.ellipse_path (sel_x0, sel_y0, sel_x1, sel_y1);
                else path = RasterSelection.rect_path (sel_x0, sel_y0, sel_x1, sel_y1);
                if (tool == PaintTool.LASSO && lasso.size >= 2 && path.is_empty ()) {
                    path = new PathData ();
                    path.move_to (lasso[0].x, lasso[0].y);
                    for (int i = 1; i < lasso.size; i++) path.line_to (lasso[i].x, lasso[i].y);
                }
                ants (cr, path, 1 / zoom);
            }
            if (hovering && tool.is_brush () && engine == null) {
                var b = current_brush ();
                double rad = double.max (b.size_at (1) / 2, 0.5);
                if (r != null) rad /= r.pixel_scale ();
                cr.save ();
                cr.new_path ();
                cr.arc (hover_x, hover_y, rad, 0, 2 * Math.PI);
                cr.set_line_width (2.5 / zoom);
                cr.set_source_rgba (1, 1, 1, 0.85);
                cr.stroke_preserve ();
                cr.set_line_width (1 / zoom);
                cr.set_source_rgba (0, 0, 0, 0.85);
                cr.stroke ();
                cr.restore ();
            }
        }

        private static void ants (Cairo.Context cr, PathData p, double lw) {
            cr.save ();
            cr.new_path ();
            p.to_cairo (cr);
            cr.set_line_width (lw * 1.2);
            cr.set_dash (null, 0);
            cr.set_source_rgba (1, 1, 1, 0.95);
            cr.stroke_preserve ();
            double[] dash = { 4 * lw, 4 * lw };
            cr.set_dash (dash, 0);
            cr.set_source_rgba (0.05, 0.05, 0.05, 0.95);
            cr.stroke ();
            cr.restore ();
        }

        private void draw_handles (Cairo.Context cr, RasterItem r, double zoom) {
            var accent = Singularity.Style.StyleManager.get_default ().accent_hex ?? "#3584e4";
            Rgba a;
            if (!Colors.parse (accent, out a)) a = Rgba (0.21, 0.52, 0.89, 1);
            var c = floating.corners ();
            double s = HANDLE / zoom;
            var top = floating.map (floating.bw / 2.0, 0);
            var tp = pix_to_page (r, top.x, top.y);
            var knob = rotate_knob (r);
            cr.save ();
            cr.set_dash (null, 0);
            cr.set_line_width (1.2 / zoom);
            a.apply (cr);
            cr.move_to (tp.x, tp.y);
            cr.line_to (knob.x, knob.y);
            cr.stroke ();
            for (int i = 0; i < 5; i++) {
                Point p = i < 4 ? pix_to_page (r, c[i].x, c[i].y) : knob;
                cr.new_path ();
                if (i == 4) cr.arc (p.x, p.y, s, 0, 2 * Math.PI);
                else cr.rectangle (p.x - s, p.y - s, 2 * s, 2 * s);
                cr.set_source_rgb (1, 1, 1);
                cr.fill_preserve ();
                a.apply (cr);
                cr.stroke ();
            }
            cr.restore ();
        }
    }
}
