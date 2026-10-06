using Gtk;

namespace Singularity.Apps.Draw {

    public enum Tool {
        SELECT,
        PAN,
        TEXT,
        RECTANGLE,
        ELLIPSE,
        LINE,
        CONNECTOR,
        PEN,
        FREEHAND,
        STAMP,
        CONNECTION_POINT
    }

    private enum DragMode {
        NONE,
        MOVE,
        RESIZE,
        ROTATE,
        RUBBER,
        CREATE,
        CONNECT,
        ENDPOINT,
        WAYPOINT,
        PAN,
        FREEHAND,
        NODE,
        HANDLE,
        PEN_HANDLE,
        GUIDE,
        CONTROL,
        AUTOCONNECT
    }

    public class Guide {
        public bool vertical;
        public double pos;
        public double from;
        public double to;

        public Guide (bool vertical, double pos, double from, double to) {
            this.vertical = vertical;
            this.pos = pos;
            this.from = from;
            this.to = to;
        }
    }

    public class Canvas : Gtk.DrawingArea {
        public Document doc { get; private set; }
        public double zoom { get; private set; default = 1; }
        public double origin_x = -40;
        public double origin_y = -40;
        public Gee.ArrayList<Item> selection = new Gee.ArrayList<Item> ();
        public Tool tool { get; private set; default = Tool.SELECT; }
        public string stamp_kind = "rectangle";
        public bool show_grid = true;
        public bool snap_grid = true;
        public bool snap_objects = true;
        public bool show_page_breaks = true;
        public RouteKind default_route = RouteKind.ORTHOGONAL;
        public Style? painter_style = null;
        public delegate void HandleConstraint (PathData before, PathData after, int segment, int handle, bool independent);
        public HandleConstraint? handle_constraint = null;
        public PathShape? node_target = null;
        public int node_selected = -1;
        public PaintController? paint = null;
        private bool paint_drag = false;
        public bool autoconnect = true;
        public bool check_spelling = true;
#if VECTOR_REUSE
        public Object? library = null;
#else
        public LibraryPanel? library = null;
#endif
        public int selected_port = -1;
        public PageGuide? active_guide = null;
        private int hover_arrow = -1;
        private Shape? arrow_shape = null;
        private int drag_control = -1;
        private uint quick_timer = 0;
        public signal void quick_shapes_requested (Shape s, int dir, double sx, double sy);
        public signal void comment_activated (Comment c, double sx, double sy);
        public signal void hyperlink_activated (Item it, string link);

        public signal void selection_changed ();
        public signal void view_changed ();
        public signal void tool_changed ();
        public signal void pointer_moved (double x, double y);
        public signal void context_menu (double x, double y);
        public signal void edit_text_requested (Item item, int row, int col);
        public signal void painter_finished ();
        public signal void files_dropped (File[] files, double x, double y);

        private DragMode mode = DragMode.NONE;
        private double press_x;
        private double press_y;
        private double last_x;
        private double last_y;
        private double cur_x;
        private double cur_y;
        private int handle_index = -1;
        private Rect drag_start_bounds;
        private Shape? drag_shape = null;
        private Cairo.Matrix drag_matrix;
        private double drag_rotation;
        private double drag_sx;
        private double drag_sy;
        private double drag_sw;
        private double drag_sh;
        private bool dragged = false;
        private Connector? drag_connector = null;
        private bool drag_src_end = false;
        private int waypoint_index = -1;
        private Shape? hover_shape = null;
        private int hover_port = -1;
        private Gee.ArrayList<Guide> guides = new Gee.ArrayList<Guide> ();
        private Gee.ArrayList<Point?> freehand_pts = new Gee.ArrayList<Point?> ();
        private PathData? pen_path = null;
        private bool pen_dragging = false;
        private bool space_down = false;
        private Tool tool_before_pan = Tool.SELECT;
        private Gee.HashMap<Item, Rect?> start_bounds = new Gee.HashMap<Item, Rect?> ();
        private string accent = "#3584e4";
        private bool dark = false;
        private Gee.ArrayList<Item>? move_set = null;

        public const double HANDLE = 5;

        public Canvas (Document doc) {
            this.doc = doc;
            focusable = true;
            can_focus = true;
            hexpand = true;
            vexpand = true;
            set_draw_func (draw);
            accent = Singularity.Style.StyleManager.get_default ().accent_hex ?? accent;
            Singularity.Style.StyleManager.get_default ().notify["accent-hex"].connect (() => {
                accent = Singularity.Style.StyleManager.get_default ().accent_hex ?? accent;
                queue_draw ();
            });

            var drag = new GestureDrag ();
            drag.button = 0;
            drag.drag_begin.connect (on_drag_begin);
            drag.drag_update.connect (on_drag_update);
            drag.drag_end.connect (on_drag_end);
            add_controller (drag);

            var click = new GestureClick ();
            click.button = 0;
            click.pressed.connect (on_click);
            add_controller (click);

            var motion = new EventControllerMotion ();
            motion.motion.connect (on_motion);
            motion.leave.connect (() => {
                if (paint_active ()) paint.leave ();
            });
            add_controller (motion);

            var scroll = new EventControllerScroll (EventControllerScrollFlags.BOTH_AXES);
            scroll.scroll.connect (on_scroll);
            add_controller (scroll);

            var zoom_gesture = new GestureZoom ();
            double zoom_start = 1;
            zoom_gesture.begin.connect (() => zoom_start = zoom);
            zoom_gesture.scale_changed.connect ((scale) => {
                double cx, cy;
                zoom_gesture.get_bounding_box_center (out cx, out cy);
                zoom_at (zoom_start * scale, cx, cy);
            });
            add_controller (zoom_gesture);

            var keys = new EventControllerKey ();
            keys.key_pressed.connect (on_key);
            keys.key_released.connect ((keyval, code, state) => {
                if (keyval == Gdk.Key.space && space_down) {
                    space_down = false;
                    use_tool (tool_before_pan);
                }
            });
            add_controller (keys);

            var drop = new DropTarget (typeof (string), Gdk.DragAction.COPY);
            drop.drop.connect ((value, x, y) => {
                string s = value.get_string ();
                if (s.has_prefix ("sdraw-kind:")) {
                    var p = to_page (x, y);
                    insert_library_shape (s.substring (11), p.x, p.y, true);
                    grab_focus ();
                    return true;
                }
                return false;
            });
            add_controller (drop);
            var file_drop = new DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
            file_drop.drop.connect ((value, x, y) => {
                var list = (Gdk.FileList) value.get_boxed ();
                File[] files = {};
                foreach (var f in list.get_files ()) files += f;
                files_dropped (files, x, y);
                return true;
            });
            add_controller (file_drop);
            doc.changed.connect (() => {
                prune_selection ();
                queue_draw ();
                view_changed ();
            });
            doc.restored.connect (on_restored);
        }

        public Page page {
            owned get { return doc.page; }
        }

        private void on_restored (string[] ids) {
            selection.clear ();
            foreach (string id in ids) {
                var it = page.find (id);
                if (it != null && page.items.contains (it)) selection.add (it);
            }
            node_target = null;
            selection_changed ();
        }

        private void prune_selection () {
            bool changed = false;
            for (int i = selection.size - 1; i >= 0; i--) {
                if (!page.items.contains (selection[i])) {
                    selection.remove_at (i);
                    changed = true;
                }
            }
            if (node_target != null && page.find (node_target.id) != node_target) node_target = null;
            if (hover_shape != null && page.find (hover_shape.id) != hover_shape) hover_shape = null;
            if (changed) selection_changed ();
        }

        public Point to_page (double sx, double sy) {
            return Point (sx / zoom + origin_x, sy / zoom + origin_y);
        }

        public Point to_screen (double px, double py) {
            return Point ((px - origin_x) * zoom, (py - origin_y) * zoom);
        }

        public Rect visible_rect () {
            return Rect (origin_x, origin_y, get_width () / zoom, get_height () / zoom);
        }

        public void use_tool (Tool t) {
            if (t != Tool.PEN && pen_path != null) finish_pen ();
            if (t != Tool.SELECT) node_target = null;
            tool = t;
            switch (t) {
                case Tool.PAN: set_cursor_from_name ("grab"); break;
                case Tool.TEXT: set_cursor_from_name ("text"); break;
                case Tool.SELECT: set_cursor_from_name (null); break;
                default: set_cursor_from_name ("crosshair"); break;
            }
            tool_changed ();
            queue_draw ();
        }

        public void zoom_at (double z, double sx, double sy) {
            z = z.clamp (0.05, 16);
            var p = to_page (sx, sy);
            zoom = z;
            origin_x = p.x - sx / zoom;
            origin_y = p.y - sy / zoom;
            queue_draw ();
            view_changed ();
        }

        public void zoom_to (double z) {
            zoom_at (z, get_width () / 2.0, get_height () / 2.0);
        }

        public void fit_rect (Rect r, double margin = 40) {
            if (r.is_empty () || get_width () < 10) return;
            double w = double.max (r.w, 10), h = double.max (r.h, 10);
            double left = 56;
            zoom = double.min ((get_width () - 2 * margin - left) / w, (get_height () - 2 * margin) / h).clamp (0.05, 4);
            origin_x = r.cx () - (get_width () + left) / 2.0 / zoom;
            origin_y = r.cy () - get_height () / 2.0 / zoom;
            queue_draw ();
            view_changed ();
        }

        public void fit_page () {
            fit_rect (Rect (0, 0, page.width, page.height));
        }

        public void fit_selection () {
            if (selection.size == 0) {
                var r = page.content_bounds ();
                if (r.is_empty ()) fit_page ();
                else fit_rect (r);
                return;
            }
            fit_rect (Document.selection_bounds (selection));
        }

        public void center_on (double px, double py) {
            origin_x = px - get_width () / 2.0 / zoom;
            origin_y = py - get_height () / 2.0 / zoom;
            queue_draw ();
            view_changed ();
        }

        public void scroll_by (double dx, double dy) {
            origin_x += dx / zoom;
            origin_y += dy / zoom;
            queue_draw ();
            view_changed ();
        }

        public void select (Gee.Collection<Item> items) {
            selection.clear ();
            foreach (var it in items) {
                var top = page.top_level (it);
                if (!selection.contains (top)) selection.add (top);
            }
            doc.selection_hint = selection_ids ();
            node_target = null;
            selection_changed ();
            queue_draw ();
        }

        public void select_one (Item? it) {
            var list = new Gee.ArrayList<Item> ();
            if (it != null) list.add (it);
            select (list);
        }

        public string[] selection_ids () {
            string[] ids = {};
            foreach (var it in selection) ids += it.id;
            return ids;
        }

        public void select_all () {
            var list = new Gee.ArrayList<Item> ();
            foreach (var it in page.items) if (page.item_visible (it) && !page.item_locked (it) && !(it is RasterItem)) list.add (it);
            select (list);
        }

        public void reset_document (Document d) {
            doc = d;
        }

        private double tol () {
            return 4 / zoom;
        }

        private Rgba accent_rgba () {
            Rgba c;
            if (!Colors.parse (accent, out c)) c = Rgba (0.21, 0.52, 0.89, 1);
            return c;
        }

        private void draw (DrawingArea area, Cairo.Context cr, int width, int height) {
            var fg = get_color ();
            dark = fg.red + fg.green + fg.blue > 1.5;
            if (dark) cr.set_source_rgb (0.105, 0.105, 0.11);
            else cr.set_source_rgb (0.91, 0.915, 0.925);
            cr.paint ();
            cr.save ();
            cr.scale (zoom, zoom);
            cr.translate (-origin_x, -origin_y);
            cr.save ();
            cr.rectangle (4 / zoom, 5 / zoom, page.width, page.height);
            cr.set_source_rgba (0, 0, 0, dark ? 0.5 : 0.12);
            cr.fill ();
            cr.restore ();
            Rgba bg;
            if (!Colors.parse (page.background, out bg)) bg = Rgba (1, 1, 1, 1);
            if (bg.a < 1) {
                cr.set_source_rgb (1, 1, 1);
                cr.rectangle (0, 0, page.width, page.height);
                cr.fill ();
            }
            bg.apply (cr);
            cr.rectangle (0, 0, page.width, page.height);
            cr.fill ();
            if (show_grid && !paint_active ()) draw_grid (cr);
            doc.link_backgrounds ();
            var opts = new RenderOptions ();
            opts.background = false;
            opts.editing_id = editing_id;
            opts.spelling = check_spelling;
            var sc = Singularity.Text.SpellChecker.get_default ();
            if (check_spelling && sc.enabled && sc.available) Renderer.speller = (w) => sc.check (w);
            Renderer.draw_page (cr, page, opts);
            Renderer.speller = null;
            if (paint_active ()) {
                paint.draw_overlay (cr, zoom);
            } else {
                draw_guides (cr);
                draw_overlays (cr);
                draw_comment_badges (cr);
            }
            cr.restore ();
        }

        public string? editing_id = null;

        private void draw_grid (Cairo.Context cr) {
            double g = doc.grid_size;
            if (g <= 0) return;
            double step = g;
            while (step * zoom < 8) step *= 2;
            var v = visible_rect ();
            double x0 = Math.floor (v.x / step) * step, y0 = Math.floor (v.y / step) * step;
            cr.save ();
            cr.set_line_width (1 / zoom);
            double major = step * 5;
            for (double x = x0; x <= v.x2 (); x += step) {
                bool m = (Math.fmod (Math.round (x / step), 5) == 0);
                cr.set_source_rgba (0.35, 0.45, 0.6, m ? 0.18 : 0.08);
                cr.move_to (x, v.y);
                cr.line_to (x, v.y2 ());
                cr.stroke ();
            }
            for (double y = y0; y <= v.y2 (); y += step) {
                bool m = (Math.fmod (Math.round (y / step), 5) == 0);
                cr.set_source_rgba (0.35, 0.45, 0.6, m ? 0.18 : 0.08);
                cr.move_to (v.x, y);
                cr.line_to (v.x2 (), y);
                cr.stroke ();
            }
            cr.restore ();
            if (major < 0) return;
        }

        private void handle_box (Cairo.Context cr, double x, double y, bool round = false, bool filled = false) {
            double s = HANDLE / zoom;
            var a = accent_rgba ();
            cr.new_path ();
            if (round) cr.arc (x, y, s, 0, 2 * Math.PI);
            else cr.rectangle (x - s, y - s, 2 * s, 2 * s);
            if (filled) a.apply (cr);
            else cr.set_source_rgb (1, 1, 1);
            cr.fill_preserve ();
            a.apply (cr);
            cr.set_line_width (1.2 / zoom);
            cr.stroke ();
        }

        private Point[] handle_points (out bool single_rotated) {
            single_rotated = false;
            var s = single_shape ();
            if (s != null && (s.rotation != 0 || s.flip_h || s.flip_v)) {
                single_rotated = true;
                double[] lx = { 0, s.w / 2, s.w, s.w, s.w, s.w / 2, 0, 0 };
                double[] ly = { 0, 0, 0, s.h / 2, s.h, s.h, s.h, s.h / 2 };
                var m = unflipped_transform (s);
                Point[] pts = {};
                for (int i = 0; i < 8; i++) {
                    double x = lx[i], y = ly[i];
                    m.transform_point (ref x, ref y);
                    pts += Point (x, y);
                }
                return pts;
            }
            var r = Document.selection_bounds (selection);
            return { Point (r.x, r.y), Point (r.cx (), r.y), Point (r.x2 (), r.y), Point (r.x2 (), r.cy ()),
                     Point (r.x2 (), r.y2 ()), Point (r.cx (), r.y2 ()), Point (r.x, r.y2 ()), Point (r.x, r.cy ()) };
        }

        private static Cairo.Matrix unflipped_transform (Shape s) {
            var m = Cairo.Matrix.identity ();
            m.translate (s.x + s.w / 2, s.y + s.h / 2);
            if (s.rotation != 0) m.rotate (s.rotation * Math.PI / 180);
            m.translate (-s.w / 2, -s.h / 2);
            return m;
        }

        private Shape? single_shape () {
            if (selection.size != 1) return null;
            return selection[0] as Shape;
        }

        private Connector? single_connector () {
            if (selection.size != 1) return null;
            return selection[0] as Connector;
        }

        private bool selection_resizable () {
            foreach (var it in selection) if (!(it is Connector)) return true;
            return false;
        }

        private Point rotate_handle () {
            bool rot;
            var pts = handle_points (out rot);
            var top = pts[1];
            var s = single_shape ();
            double off = 22 / zoom;
            if (s != null && rot) {
                double a = s.rotation * Math.PI / 180;
                return Point (top.x + Math.sin (a) * off, top.y - Math.cos (a) * off);
            }
            return Point (top.x, top.y - off);
        }

        private void draw_overlays (Cairo.Context cr) {
            var a = accent_rgba ();
            cr.save ();
            cr.new_path ();
            cr.set_dash (null, 0);
            foreach (var it in selection) {
                if (it is Connector) continue;
                var s = it as Shape;
                a.apply (cr, 0.9);
                cr.set_line_width (1 / zoom);
                if (s != null && s.rotation != 0) {
                    cr.save ();
                    cr.transform (unflipped_transform (s));
                    cr.rectangle (0, 0, s.w, s.h);
                    cr.restore ();
                } else {
                    var b = it.bounds ();
                    cr.rectangle (b.x, b.y, b.w, b.h);
                }
                cr.stroke ();
            }
            if (selection.size > 1) {
                var r = Document.selection_bounds (selection);
                a.apply (cr, 0.6);
                cr.set_dash ({ 4 / zoom, 3 / zoom }, 0);
                cr.rectangle (r.x, r.y, r.w, r.h);
                cr.stroke ();
                cr.set_dash (null, 0);
            }
            if (node_target != null) {
                draw_node_handles (cr);
            } else if (selection.size > 0 && selection_resizable () && tool == Tool.SELECT) {
                bool rot;
                var pts = handle_points (out rot);
                bool locked = false;
                foreach (var it in selection) if (page.item_locked (it)) locked = true;
                if (!locked) {
                    var rh = rotate_handle ();
                    a.apply (cr, 0.8);
                    cr.set_line_width (1 / zoom);
                    cr.move_to (pts[1].x, pts[1].y);
                    cr.line_to (rh.x, rh.y);
                    cr.stroke ();
                    handle_box (cr, rh.x, rh.y, true, true);
                    foreach (var p in pts) handle_box (cr, p.x, p.y);
                }
            }
            var conn = single_connector ();
            if (conn != null && conn.points.length >= 2) {
                a.apply (cr, 0.5);
                cr.set_line_width (3 / zoom);
                conn.path ().to_cairo (cr);
                cr.stroke ();
                var p0 = conn.points[0];
                var p1 = conn.points[conn.points.length - 1];
                handle_box (cr, p0.x, p0.y, true, conn.src.attached ());
                handle_box (cr, p1.x, p1.y, true, conn.dst.attached ());
                foreach (var w in conn.waypoints) handle_box (cr, w.x, w.y, false, true);
                foreach (var m in segment_midpoints (conn)) {
                    cr.new_path ();
                    cr.arc (m.x, m.y, 3 / zoom, 0, 2 * Math.PI);
                    cr.set_source_rgba (1, 1, 1, 0.9);
                    cr.fill_preserve ();
                    a.apply (cr);
                    cr.set_line_width (1 / zoom);
                    cr.stroke ();
                }
            }
            if (hover_shape != null && (tool == Tool.CONNECTOR || tool == Tool.SELECT || mode == DragMode.CONNECT || mode == DragMode.ENDPOINT)) {
                var ports = hover_shape.ports ();
                for (int i = 0; i < ports.length; i++) {
                    var p = hover_shape.port_point (i);
                    cr.new_path ();
                    cr.arc (p.x, p.y, (i == hover_port ? 5 : 3.5) / zoom, 0, 2 * Math.PI);
                    if (i == hover_port) a.apply (cr);
                    else cr.set_source_rgba (1, 1, 1, 0.95);
                    cr.fill_preserve ();
                    a.apply (cr);
                    cr.set_line_width (1.2 / zoom);
                    cr.stroke ();
                }
                if ((mode == DragMode.CONNECT || mode == DragMode.ENDPOINT) && hover_port < 0) {
                    var b = hover_shape.bounds ();
                    a.apply (cr, 0.35);
                    cr.set_line_width (3 / zoom);
                    cr.rectangle (b.x, b.y, b.w, b.h);
                    cr.stroke ();
                }
            }
            if (mode == DragMode.RUBBER) {
                var r = Rect.from_points (press_x, press_y, cur_x, cur_y);
                a.apply (cr, 0.12);
                cr.rectangle (r.x, r.y, r.w, r.h);
                cr.fill_preserve ();
                a.apply (cr, 0.8);
                cr.set_line_width (1 / zoom);
                cr.stroke ();
            }
            if (mode == DragMode.CREATE) {
                var r = creation_rect ();
                a.apply (cr, 0.8);
                cr.set_line_width (1 / zoom);
                cr.set_dash ({ 4 / zoom, 3 / zoom }, 0);
                if (tool == Tool.ELLIPSE) {
                    cr.save ();
                    cr.translate (r.cx (), r.cy ());
                    cr.scale (double.max (r.w / 2, 0.01), double.max (r.h / 2, 0.01));
                    cr.arc (0, 0, 1, 0, 2 * Math.PI);
                    cr.restore ();
                } else if (tool == Tool.LINE) {
                    cr.move_to (press_x, press_y);
                    var e = line_end ();
                    cr.line_to (e.x, e.y);
                } else {
                    cr.rectangle (r.x, r.y, r.w, r.h);
                }
                cr.stroke ();
                cr.set_dash (null, 0);
            }
            if (mode == DragMode.CONNECT) {
                a.apply (cr);
                cr.set_line_width (1.5 / zoom);
                cr.set_dash ({ 5 / zoom, 3 / zoom }, 0);
                cr.move_to (press_x, press_y);
                cr.line_to (cur_x, cur_y);
                cr.stroke ();
                cr.set_dash (null, 0);
            }
            if (mode == DragMode.FREEHAND && freehand_pts.size > 1) {
                a.apply (cr);
                cr.set_line_width (1.5 / zoom);
                cr.move_to (freehand_pts[0].x, freehand_pts[0].y);
                foreach (var p in freehand_pts) cr.line_to (p.x, p.y);
                cr.stroke ();
            }
            if (pen_path != null) draw_pen_preview (cr);
            if (tool == Tool.SELECT && mode == DragMode.NONE && autoconnect) draw_autoconnect (cr);
            if (tool == Tool.SELECT) draw_controls (cr);
            if (tool == Tool.CONNECTION_POINT) draw_port_editor (cr);
            foreach (var g in guides) {
                cr.set_source_rgba (0.9, 0.2, 0.55, 0.9);
                cr.set_line_width (1 / zoom);
                if (g.vertical) {
                    cr.move_to (g.pos, g.from);
                    cr.line_to (g.pos, g.to);
                } else {
                    cr.move_to (g.from, g.pos);
                    cr.line_to (g.to, g.pos);
                }
                cr.stroke ();
            }
            cr.restore ();
        }

        private void draw_guides (Cairo.Context cr) {
            if (page.guides.size == 0) return;
            var v = visible_rect ();
            var a = accent_rgba ();
            cr.save ();
            cr.set_line_width (1 / zoom);
            cr.set_dash ({ 6 / zoom, 4 / zoom }, 0);
            foreach (var g in page.guides) {
                a.apply (cr, g == active_guide ? 1 : 0.55);
                if (g.vertical) {
                    cr.move_to (g.pos, v.y);
                    cr.line_to (g.pos, v.y2 ());
                } else {
                    cr.move_to (v.x, g.pos);
                    cr.line_to (v.x2 (), g.pos);
                }
                cr.stroke ();
            }
            cr.restore ();
        }

        public Rect comment_badge (Comment c) {
            double s = 18 / zoom;
            if (c.item_id != "") {
                var it = page.find (c.item_id);
                if (it != null) {
                    var b = it.bounds ();
                    return Rect (b.x2 () - s * 0.3, b.y - s * 0.7, s, s);
                }
            }
            return Rect (c.x, c.y - s, s, s);
        }

        private void draw_comment_badges (Cairo.Context cr) {
            foreach (var c in page.comments) {
                if (c.resolved) continue;
                var r = comment_badge (c);
                cr.save ();
                cr.new_path ();
                double rad = r.w * 0.22;
                cr.move_to (r.x + rad, r.y);
                cr.line_to (r.x2 () - rad, r.y);
                cr.arc (r.x2 () - rad, r.y + rad, rad, -Math.PI / 2, 0);
                cr.line_to (r.x2 (), r.y2 () - rad);
                cr.arc (r.x2 () - rad, r.y2 () - rad, rad, 0, Math.PI / 2);
                cr.line_to (r.x + r.w * 0.45, r.y2 ());
                cr.line_to (r.x + r.w * 0.15, r.y2 () + r.h * 0.3);
                cr.line_to (r.x + r.w * 0.25, r.y2 ());
                cr.arc (r.x + rad, r.y2 () - rad, rad, Math.PI / 2, Math.PI);
                cr.line_to (r.x, r.y + rad);
                cr.arc (r.x + rad, r.y + rad, rad, Math.PI, 3 * Math.PI / 2);
                cr.close_path ();
                cr.set_source_rgb (0.96, 0.77, 0.09);
                cr.fill_preserve ();
                cr.set_source_rgba (0, 0, 0, 0.45);
                cr.set_line_width (1 / zoom);
                cr.stroke ();
                var layout = Pango.cairo_create_layout (cr);
                var fd = new Pango.FontDescription ();
                fd.set_family ("Sans");
                fd.set_weight (Pango.Weight.BOLD);
                fd.set_absolute_size (r.h * 0.5 * Pango.SCALE);
                layout.set_font_description (fd);
                layout.set_text (c.initials != "" ? c.initials : "?", -1);
                int lw, lh;
                layout.get_pixel_size (out lw, out lh);
                cr.set_source_rgb (0.15, 0.12, 0.02);
                cr.move_to (r.cx () - lw / 2.0, r.cy () - lh / 2.0);
                Pango.cairo_show_layout (cr, layout);
                cr.restore ();
            }
        }

        public Comment? comment_at (double x, double y) {
            for (int i = page.comments.size - 1; i >= 0; i--) {
                var c = page.comments[i];
                if (c.resolved) continue;
                if (comment_badge (c).inflate (2 / zoom).contains (x, y)) return c;
            }
            return null;
        }

        private Point[] arrow_points (Shape s) {
            var b = s.bounds ();
            double off = 22 / zoom;
            return { Point (b.cx (), b.y - off), Point (b.x2 () + off, b.cy ()), Point (b.cx (), b.y2 () + off), Point (b.x - off, b.cy ()) };
        }

        private int arrow_at (double x, double y) {
            if (arrow_shape == null) return -1;
            var pts = arrow_points (arrow_shape);
            for (int i = 0; i < 4; i++) if (point_near (pts[i], x, y, 10)) return i;
            return -1;
        }

        private void draw_autoconnect (Cairo.Context cr) {
            if (arrow_shape == null) return;
            var pts = arrow_points (arrow_shape);
            var a = accent_rgba ();
            double sz = 9 / zoom;
            for (int i = 0; i < 4; i++) {
                cr.save ();
                cr.translate (pts[i].x, pts[i].y);
                cr.rotate ((i - 1) * Math.PI / 2);
                cr.move_to (sz, 0);
                cr.line_to (-sz * 0.4, -sz * 0.85);
                cr.line_to (-sz * 0.1, 0);
                cr.line_to (-sz * 0.4, sz * 0.85);
                cr.close_path ();
                a.apply (cr, i == hover_arrow ? 1 : 0.45);
                cr.fill ();
                cr.restore ();
            }
        }

        private void draw_controls (Cairo.Context cr) {
            var s = single_shape ();
            if (s == null) return;
            var pts = SheetEval.control_points (s);
            double r = 5 / zoom;
            foreach (var p in pts) {
                cr.new_path ();
                cr.move_to (p.x, p.y - r);
                cr.line_to (p.x + r, p.y);
                cr.line_to (p.x, p.y + r);
                cr.line_to (p.x - r, p.y);
                cr.close_path ();
                cr.set_source_rgb (0.99, 0.84, 0.1);
                cr.fill_preserve ();
                cr.set_source_rgba (0, 0, 0, 0.6);
                cr.set_line_width (1 / zoom);
                cr.stroke ();
            }
        }

        private int control_at (double x, double y) {
            var s = single_shape ();
            if (s == null || page.item_locked (s)) return -1;
            var pts = SheetEval.control_points (s);
            for (int i = 0; i < pts.length; i++) if (point_near (pts[i], x, y, 7)) return i;
            return -1;
        }

        private void draw_port_editor (Cairo.Context cr) {
            Shape? s = hover_shape;
            if (s == null) s = single_shape ();
            if (s == null) return;
            var a = accent_rgba ();
            double r = 4 / zoom;
            for (int i = 0; i < s.ports ().length; i++) {
                var p = s.port_point (i);
                cr.new_path ();
                cr.move_to (p.x - r, p.y - r);
                cr.line_to (p.x + r, p.y + r);
                cr.move_to (p.x + r, p.y - r);
                cr.line_to (p.x - r, p.y + r);
                if (s == single_shape () && i == selected_port) cr.set_source_rgb (0.89, 0.2, 0.3);
                else a.apply (cr);
                cr.set_line_width (2 / zoom);
                cr.stroke ();
            }
        }

        private void draw_pen_preview (Cairo.Context cr) {
            var a = accent_rgba ();
            cr.save ();
            a.apply (cr);
            cr.set_line_width (1.5 / zoom);
            pen_path.to_cairo (cr);
            if (!pen_dragging && pen_path.segs.size > 0) {
                cr.line_to (cur_x, cur_y);
            }
            cr.stroke ();
            foreach (var s in pen_path.segs) {
                if (s.kind == SegKind.CLOSE) continue;
                handle_box (cr, s.x, s.y, false, true);
            }
            var last = pen_path.segs.size > 0 ? pen_path.segs[pen_path.segs.size - 1] : null;
            if (last != null && pen_out_valid) {
                a.apply (cr, 0.7);
                cr.set_line_width (1 / zoom);
                cr.move_to (2 * last.x - pen_out_x, 2 * last.y - pen_out_y);
                cr.line_to (pen_out_x, pen_out_y);
                cr.stroke ();
                handle_box (cr, pen_out_x, pen_out_y, true);
                handle_box (cr, 2 * last.x - pen_out_x, 2 * last.y - pen_out_y, true);
            }
            cr.restore ();
        }

        private void draw_node_handles (Cairo.Context cr) {
            var path = node_target.page_path ();
            var a = accent_rgba ();
            cr.save ();
            a.apply (cr, 0.6);
            cr.set_line_width (1 / zoom);
            path.to_cairo (cr);
            cr.stroke ();
            PathSeg? prev = null;
            for (int i = 0; i < path.segs.size; i++) {
                var s = path.segs[i];
                if (s.kind == SegKind.CURVE && prev != null) {
                    a.apply (cr, 0.7);
                    cr.move_to (prev.x, prev.y);
                    cr.line_to (s.x1, s.y1);
                    cr.move_to (s.x, s.y);
                    cr.line_to (s.x2, s.y2);
                    cr.stroke ();
                    handle_box (cr, s.x1, s.y1, true);
                    handle_box (cr, s.x2, s.y2, true);
                }
                if (s.kind != SegKind.CLOSE) prev = s;
            }
            for (int i = 0; i < path.segs.size; i++) {
                var s = path.segs[i];
                if (s.kind == SegKind.CLOSE) continue;
                handle_box (cr, s.x, s.y, false, i == node_selected);
            }
            cr.restore ();
        }

        private Point[] segment_midpoints (Connector c) {
            Point[] mids = {};
            if (c.route == RouteKind.CURVED) return mids;
            for (int i = 1; i < c.points.length; i++) {
                var a = c.points[i - 1];
                var b = c.points[i];
                if (a.distance (b) * zoom < 30) continue;
                mids += Point ((a.x + b.x) / 2, (a.y + b.y) / 2);
            }
            return mids;
        }

        private Rect creation_rect () {
            double x2 = cur_x, y2 = cur_y;
            if ((modifiers & Gdk.ModifierType.SHIFT_MASK) != 0) {
                double d = double.max ((x2 - press_x).abs (), (y2 - press_y).abs ());
                x2 = press_x + (x2 >= press_x ? d : -d);
                y2 = press_y + (y2 >= press_y ? d : -d);
            }
            return Rect.from_points (press_x, press_y, x2, y2);
        }

        private Point line_end () {
            double dx = cur_x - press_x, dy = cur_y - press_y;
            if ((modifiers & Gdk.ModifierType.SHIFT_MASK) != 0) {
                double ang = Math.atan2 (dy, dx);
                double snap = Math.round (ang / (Math.PI / 4)) * (Math.PI / 4);
                double len = Math.hypot (dx, dy);
                return Point (press_x + Math.cos (snap) * len, press_y + Math.sin (snap) * len);
            }
            return Point (cur_x, cur_y);
        }

        private Gdk.ModifierType modifiers = 0;

        private double snap_value (double v) {
            if (!snap_grid || (modifiers & Gdk.ModifierType.ALT_MASK) != 0) return v;
            double g = doc.grid_size;
            return Math.round (v / g) * g;
        }

        private Point snap_point (double x, double y) {
            return Point (snap_value (x), snap_value (y));
        }

        private bool point_near (Point a, double x, double y, double r = 7) {
            return Math.hypot (a.x - x, a.y - y) <= r / zoom;
        }

        private int hit_handle (double x, double y) {
            if (selection.size == 0 || !selection_resizable () || node_target != null) return -1;
            foreach (var it in selection) if (page.item_locked (it)) return -1;
            if (point_near (rotate_handle (), x, y)) return 8;
            bool rot;
            var pts = handle_points (out rot);
            for (int i = 0; i < pts.length; i++) if (point_near (pts[i], x, y)) return i;
            return -1;
        }

        private Shape? shape_at (double x, double y, Item? exclude = null) {
            for (int i = page.items.size - 1; i >= 0; i--) {
                var it = page.items[i];
                if (it == exclude || !page.item_visible (it) || it is Connector) continue;
                var g = it as Group;
                if (g != null) {
                    for (int j = g.children.size - 1; j >= 0; j--) {
                        var cs = g.children[j] as Shape;
                        if (cs != null && cs != exclude && cs.hit (x, y, tol ())) return cs;
                    }
                    continue;
                }
                var s = it as Shape;
                if (s != null && s.hit (x, y, tol ())) return s;
            }
            return null;
        }

        private int port_at (Shape s, double x, double y) {
            var ports = s.ports ();
            for (int i = 0; i < ports.length; i++) if (point_near (s.port_point (i), x, y, 9)) return i;
            return -1;
        }

        private void on_motion (double sx, double sy) {
            var p = to_page (sx, sy);
            cur_x = p.x;
            cur_y = p.y;
            pointer_moved (p.x, p.y);
            if (paint_active ()) {
                paint.hover (p.x, p.y);
                return;
            }
            if (mode != DragMode.NONE) return;
            var old = hover_shape;
            int old_port = hover_port;
            hover_shape = null;
            hover_port = -1;
            if (tool == Tool.CONNECTOR || tool == Tool.SELECT) {
                var s = shape_at (p.x, p.y);
                if (s == null && tool == Tool.SELECT && old != null && old.bounds ().inflate (12 / zoom).contains (p.x, p.y)) s = old;
                bool selected = tool == Tool.SELECT && selection.contains (page.top_level (s ?? old ?? new Shape ()));
                if (s != null && !selected && !page.item_locked (page.top_level (s))) {
                    hover_shape = s;
                    hover_port = port_at (s, p.x, p.y);
                }
            }
            if (tool == Tool.CONNECTION_POINT) {
                var s = shape_at (p.x, p.y);
                if (s == null && old != null && old.bounds ().inflate (10 / zoom).contains (p.x, p.y)) s = old;
                hover_shape = s;
                hover_port = s != null ? port_at (s, p.x, p.y) : -1;
            }
            if (tool == Tool.SELECT) update_arrows (p.x, p.y);
            if (tool == Tool.SELECT) {
                int h = hit_handle (p.x, p.y);
                if (hover_arrow >= 0) set_cursor_from_name ("pointer");
                else if (control_at (p.x, p.y) >= 0) set_cursor_from_name ("pointer");
                else if (guide_at (p.x, p.y) != null) set_cursor_from_name (guide_at (p.x, p.y).vertical ? "ew-resize" : "ns-resize");
                else if (h == 8) set_cursor_from_name ("grab");
                else if (h >= 0) set_cursor_from_name (resize_cursor (h));
                else if (hover_port >= 0) set_cursor_from_name ("crosshair");
                else if (item_at (p.x, p.y) != null) set_cursor_from_name ("move");
                else set_cursor_from_name (null);
            }
            if (old != hover_shape || old_port != hover_port || pen_path != null) queue_draw ();
        }

        private void update_arrows (double x, double y) {
            var old_shape = arrow_shape;
            int old_arrow = hover_arrow;
            if (!autoconnect || mode != DragMode.NONE) {
                arrow_shape = null;
                hover_arrow = -1;
            } else {
                hover_arrow = arrow_at (x, y);
                if (hover_arrow < 0) {
                    var s = shape_at (x, y);
                    if (s != null && (s.is_container () || s.kind == "text" || s is ImageShape || s is TableShape || s is GanttShape || page.item_locked (page.top_level (s)))) s = null;
                    if (s == null && arrow_shape != null && arrow_shape.bounds ().inflate (34 / zoom).contains (x, y) && page.find (arrow_shape.id) == arrow_shape) s = arrow_shape;
                    arrow_shape = s;
                }
            }
            if (hover_arrow != old_arrow) {
                if (quick_timer != 0) {
                    Source.remove (quick_timer);
                    quick_timer = 0;
                }
                if (hover_arrow >= 0 && arrow_shape != null) {
                    var shape = arrow_shape;
                    int dir = hover_arrow;
                    quick_timer = Timeout.add (500, () => {
                        quick_timer = 0;
                        if (arrow_shape == shape && hover_arrow == dir && mode == DragMode.NONE) {
                            var pt = arrow_points (shape)[dir];
                            var sp = to_screen (pt.x, pt.y);
                            quick_shapes_requested (shape, dir, sp.x, sp.y);
                        }
                        return Source.REMOVE;
                    });
                }
            }
            if (old_shape != arrow_shape || old_arrow != hover_arrow) queue_draw ();
        }

        public void simulate_hover (double x, double y) {
            cur_x = x;
            cur_y = y;
            foreach (var it in page.items) {
                var s = it as Shape;
                if (s != null && !s.is_container () && s.bounds ().inflate (34 / zoom).contains (x, y)) arrow_shape = s;
            }
            hover_arrow = -1;
            update_arrows (x, y);
            queue_draw ();
        }

        public PageGuide? guide_at (double x, double y) {
            foreach (var g in page.guides) {
                if (g.vertical && (g.pos - x).abs () * zoom < 4) return g;
                if (!g.vertical && (g.pos - y).abs () * zoom < 4) return g;
            }
            return null;
        }

        private static string resize_cursor (int h) {
            switch (h) {
                case 0: case 4: return "nwse-resize";
                case 2: case 6: return "nesw-resize";
                case 1: case 5: return "ns-resize";
                default: return "ew-resize";
            }
        }

        private Item? item_at (double x, double y) {
            for (int i = page.items.size - 1; i >= 0; i--) {
                var it = page.items[i];
                if (!page.item_visible (it)) continue;
                if (it.hit (x, y, tol ())) return it;
            }
            foreach (var it in page.items) {
                var c = it as Connector;
                if (c == null || c.text == "") continue;
                var lp = c.label_point ();
                if (Math.hypot (lp.x - x, lp.y - y) < 12 / zoom) return c;
            }
            return null;
        }

        private bool on_scroll (EventControllerScroll ctl, double dx, double dy) {
            var state = ctl.get_current_event_state ();
            if ((state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                double mx = cur_x, my = cur_y;
                var sp = to_screen (mx, my);
                zoom_at (zoom * Math.pow (1.1, -dy), sp.x, sp.y);
                return true;
            }
            if ((state & Gdk.ModifierType.SHIFT_MASK) != 0 && dx == 0) {
                dx = dy;
                dy = 0;
            }
            var unit = ctl.get_unit ();
            double factor = unit == Gdk.ScrollUnit.WHEEL ? 40 : 1;
            scroll_by (dx * factor, dy * factor);
            return true;
        }

        public bool paint_active () {
            return paint != null && paint.active;
        }

        private void on_click (GestureClick g, int n, double sx, double sy) {
            grab_focus ();
            if (paint_active ()) return;
            var p = to_page (sx, sy);
            uint button = g.get_current_button ();
            modifiers = g.get_current_event_state ();
            if (button == Gdk.BUTTON_SECONDARY) {
                if (pen_path != null) {
                    finish_pen ();
                    return;
                }
                var it = item_at (p.x, p.y);
                if (it != null && !selection.contains (page.top_level (it))) select_one (it);
                else if (it == null) select (new Gee.ArrayList<Item> ());
                context_menu (sx, sy);
                return;
            }
            if (button != Gdk.BUTTON_PRIMARY) return;
            if (tool == Tool.PEN) {
                if (n == 2) finish_pen ();
                return;
            }
            if (n == 2 && tool == Tool.SELECT) {
                if (node_target != null) {
                    insert_node_at (p.x, p.y);
                    return;
                }
                var conn = single_connector ();
                if (conn != null) {
                    for (int i = 0; i < conn.waypoints.length; i++) {
                        if (point_near (conn.waypoints[i], p.x, p.y)) {
                            doc.begin (_("Remove Bend"));
                            Point[] w = {};
                            for (int k = 0; k < conn.waypoints.length; k++) if (k != i) w += conn.waypoints[k];
                            conn.waypoints = w;
                            doc.commit ();
                            return;
                        }
                    }
                }
                var target = deep_item_at (p.x, p.y);
                if (target == null) return;
                var ps = target as PathShape;
                if (ps != null && ps.text == "") {
                    enter_node_edit (ps);
                    return;
                }
                var tb = target as TableShape;
                if (tb != null) {
                    var l = tb.to_local (p.x, p.y);
                    int row, col;
                    if (tb.cell_at (l.x, l.y, out row, out col)) {
                        edit_text_requested (tb, row, col);
                        return;
                    }
                }
                if (!(target is ImageShape)) edit_text_requested (target, -1, -1);
            }
        }

        public Item? deep_item_at (double x, double y) {
            var s = shape_at (x, y);
            if (s != null) return s;
            return item_at (x, y);
        }

        private void on_drag_begin (GestureDrag g, double sx, double sy) {
            grab_focus ();
            uint button = g.get_current_button ();
            modifiers = g.get_current_event_state ();
            var p = to_page (sx, sy);
            press_x = p.x;
            press_y = p.y;
            last_x = p.x;
            last_y = p.y;
            cur_x = p.x;
            cur_y = p.y;
            dragged = false;
            guides.clear ();
            if (button == Gdk.BUTTON_MIDDLE || tool == Tool.PAN || space_down) {
                mode = DragMode.PAN;
                set_cursor_from_name ("grabbing");
                return;
            }
            if (paint_active ()) {
                mode = DragMode.NONE;
                if (button == Gdk.BUTTON_PRIMARY) paint_drag = paint.press (g, p.x, p.y);
                return;
            }
            if (button != Gdk.BUTTON_PRIMARY) {
                mode = DragMode.NONE;
                return;
            }
            switch (tool) {
                case Tool.RECTANGLE:
                case Tool.ELLIPSE:
                case Tool.STAMP:
                case Tool.TEXT:
                case Tool.LINE:
                    var sp = tool == Tool.LINE ? Point (press_x, press_y) : snap_point (press_x, press_y);
                    press_x = sp.x;
                    press_y = sp.y;
                    mode = DragMode.CREATE;
                    return;
                case Tool.CONNECTOR:
                    begin_connect (p.x, p.y);
                    return;
                case Tool.FREEHAND:
                    mode = DragMode.FREEHAND;
                    freehand_pts.clear ();
                    freehand_pts.add (p);
                    return;
                case Tool.PEN:
                    pen_press (p.x, p.y);
                    return;
                case Tool.CONNECTION_POINT:
                    mode = DragMode.NONE;
                    edit_port_at (p.x, p.y);
                    return;
                default:
                    break;
            }
            var badge = comment_at (p.x, p.y);
            if (badge != null) {
                mode = DragMode.NONE;
                var bs = to_screen (comment_badge (badge).cx (), comment_badge (badge).y2 ());
                comment_activated (badge, bs.x, bs.y);
                return;
            }
            if ((modifiers & Gdk.ModifierType.CONTROL_MASK) != 0) {
                var linked = deep_item_at (p.x, p.y);
                if (linked != null && page.top_level (linked).link != "") linked = page.top_level (linked);
                if (linked != null && linked.link != "") {
                    mode = DragMode.NONE;
                    hyperlink_activated (linked, linked.link);
                    return;
                }
            }
            int ctl = control_at (p.x, p.y);
            if (ctl >= 0) {
                drag_control = ctl;
                drag_shape = single_shape ();
                doc.begin (_("Adjust Shape"));
                mode = DragMode.CONTROL;
                return;
            }
            if (arrow_shape != null && arrow_at (p.x, p.y) >= 0) {
                hover_arrow = arrow_at (p.x, p.y);
                if (quick_timer != 0) {
                    Source.remove (quick_timer);
                    quick_timer = 0;
                }
                mode = DragMode.AUTOCONNECT;
                return;
            }
            var guide = guide_at (p.x, p.y);
            if (guide != null && hit_handle (p.x, p.y) < 0) {
                active_guide = guide;
                doc.begin (_("Move Guide"));
                mode = DragMode.GUIDE;
                return;
            }
            if (node_target != null) {
                if (node_press (p.x, p.y)) return;
                node_target = null;
                queue_draw ();
            }
            var conn = single_connector ();
            if (conn != null && conn.points.length >= 2 && !page.item_locked (conn)) {
                if (point_near (conn.points[0], p.x, p.y) || point_near (conn.points[conn.points.length - 1], p.x, p.y)) {
                    drag_connector = conn;
                    drag_src_end = point_near (conn.points[0], p.x, p.y);
                    doc.begin (_("Move Connector End"));
                    mode = DragMode.ENDPOINT;
                    return;
                }
                for (int i = 0; i < conn.waypoints.length; i++) {
                    if (point_near (conn.waypoints[i], p.x, p.y)) {
                        drag_connector = conn;
                        waypoint_index = i;
                        doc.begin (_("Move Bend"));
                        mode = DragMode.WAYPOINT;
                        return;
                    }
                }
                var mids = segment_midpoints (conn);
                for (int i = 0; i < mids.length; i++) {
                    if (point_near (mids[i], p.x, p.y)) {
                        drag_connector = conn;
                        doc.begin (_("Add Bend"));
                        insert_waypoint (conn, mids[i]);
                        mode = DragMode.WAYPOINT;
                        return;
                    }
                }
            }
            int h = hit_handle (p.x, p.y);
            if (h >= 0) {
                handle_index = h;
                begin_transform ();
                mode = h == 8 ? DragMode.ROTATE : DragMode.RESIZE;
                doc.begin (h == 8 ? _("Rotate") : _("Resize"));
                return;
            }
            if (hover_shape != null && hover_port >= 0 && (modifiers & Gdk.ModifierType.SHIFT_MASK) == 0) {
                begin_connect (p.x, p.y);
                return;
            }
            var it = item_at (p.x, p.y);
            if (it != null) {
                var top = page.top_level (it);
                if ((modifiers & (Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK)) != 0) {
                    var list = new Gee.ArrayList<Item> ();
                    list.add_all (selection);
                    if (list.contains (top)) list.remove (top);
                    else list.add (top);
                    select (list);
                    mode = DragMode.NONE;
                    return;
                }
                if (!selection.contains (top)) select_one (top);
                if (painter_style != null) {
                    apply_painter (top);
                    mode = DragMode.NONE;
                    return;
                }
                bool locked = false;
                foreach (var s in selection) if (page.item_locked (s)) locked = true;
                if (locked) {
                    mode = DragMode.NONE;
                    return;
                }
                begin_transform ();
                mode = DragMode.MOVE;
                doc.begin (_("Move"));
                return;
            }
            if ((modifiers & (Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK)) == 0 && selection.size > 0) select (new Gee.ArrayList<Item> ());
            mode = DragMode.RUBBER;
        }

        private void insert_waypoint (Connector c, Point p) {
            Point[] w = {};
            if (c.waypoints.length == 0) {
                w += p;
                c.waypoints = w;
                waypoint_index = 0;
                return;
            }
            double best = double.INFINITY;
            int best_i = c.waypoints.length;
            Point[] chain = { c.points[0] };
            foreach (var wp in c.waypoints) chain += wp;
            chain += c.points[c.points.length - 1];
            for (int i = 1; i < chain.length; i++) {
                double d = PathData.segment_distance (chain[i - 1], chain[i], p.x, p.y);
                if (d < best) {
                    best = d;
                    best_i = i - 1;
                }
            }
            for (int i = 0; i < c.waypoints.length; i++) {
                if (i == best_i) w += p;
                w += c.waypoints[i];
            }
            if (best_i >= c.waypoints.length) w += p;
            c.waypoints = w;
            waypoint_index = int.min (best_i, c.waypoints.length - 1);
        }

        private void begin_transform () {
            start_bounds.clear ();
            move_set = new Gee.ArrayList<Item> ();
            move_set.add_all (selection);
            foreach (var it in selection) {
                var s = it as Shape;
                if (s != null && s.is_container ()) {
                    foreach (var m in doc.members_recursive (s)) if (!move_set.contains (m)) move_set.add (m);
                }
            }
            var ids = new Gee.HashSet<string> ();
            foreach (var it in move_set) ids.add (it.id);
            foreach (var it in page.all_items ()) {
                var cs = it as Shape;
                if (cs != null && cs.callout_target != "" && ids.contains (cs.callout_target) && !move_set.contains (cs)) move_set.add (cs);
            }
            drag_start_bounds = Document.selection_bounds (selection);
            applied_rotation = 0;
            drag_shape = single_shape ();
            if (drag_shape != null) {
                drag_matrix = unflipped_transform (drag_shape);
                drag_rotation = drag_shape.rotation;
                drag_sx = drag_shape.x;
                drag_sy = drag_shape.y;
                drag_sw = drag_shape.w;
                drag_sh = drag_shape.h;
            }
            doc.selection_hint = selection_ids ();
        }

        private void begin_connect (double x, double y) {
            mode = DragMode.CONNECT;
            var s = shape_at (x, y);
            drag_connector = new Connector ();
            drag_connector.route = default_route;
            if (s != null) {
                drag_connector.src.item_id = s.id;
                int port = port_at (s, x, y);
                drag_connector.src.port = port;
                var anchor = port >= 0 ? s.port_point (port) : Point (s.cx (), s.cy ());
                press_x = anchor.x;
                press_y = anchor.y;
            } else {
                var sp = snap_point (x, y);
                press_x = sp.x;
                press_y = sp.y;
            }
            drag_connector.src.x = press_x;
            drag_connector.src.y = press_y;
        }

        private void on_drag_update (GestureDrag g, double ox, double oy) {
            double sx, sy;
            g.get_start_point (out sx, out sy);
            modifiers = g.get_current_event_state ();
            if (mode == DragMode.PAN) {
                double dx = ox - prev_ox, dy = oy - prev_oy;
                prev_ox = ox;
                prev_oy = oy;
                scroll_by (-dx, -dy);
                return;
            }
            var p = to_page (sx + ox, sy + oy);
            cur_x = p.x;
            cur_y = p.y;
            pointer_moved (p.x, p.y);
            if (paint_drag) {
                paint.drag (g, p.x, p.y);
                return;
            }
            if (Math.hypot (ox, oy) > 3) dragged = true;
            switch (mode) {
                case DragMode.MOVE: drag_move (); break;
                case DragMode.RESIZE: drag_resize (); break;
                case DragMode.ROTATE: drag_rotate (); break;
                case DragMode.CONNECT:
                case DragMode.ENDPOINT:
                    update_hover_for_connect (p.x, p.y);
                    if (mode == DragMode.ENDPOINT) drag_endpoint ();
                    break;
                case DragMode.WAYPOINT:
                    if (drag_connector != null && waypoint_index >= 0 && waypoint_index < drag_connector.waypoints.length) {
                        var sp = snap_point (p.x, p.y);
                        drag_connector.waypoints[waypoint_index] = sp;
                        Router.route (page, drag_connector);
                    }
                    break;
                case DragMode.FREEHAND:
                    var last = freehand_pts[freehand_pts.size - 1];
                    if (Math.hypot (last.x - p.x, last.y - p.y) * zoom > 2) freehand_pts.add (p);
                    break;
                case DragMode.NODE:
                case DragMode.HANDLE:
                    drag_node (p.x, p.y);
                    break;
                case DragMode.PEN_HANDLE:
                    pen_drag (p.x, p.y);
                    break;
                case DragMode.GUIDE:
                    if (active_guide != null) active_guide.pos = active_guide.vertical ? snap_value (p.x) : snap_value (p.y);
                    break;
                case DragMode.CONTROL:
                    if (drag_shape != null && drag_control >= 0) {
                        SheetEval.move_control (drag_shape, drag_control, p.x, p.y);
                        reroute_selection ();
                    }
                    break;
                case DragMode.AUTOCONNECT:
                    update_hover_for_connect (p.x, p.y);
                    if (hover_shape == arrow_shape) hover_shape = null;
                    break;
                default:
                    break;
            }
            last_x = p.x;
            last_y = p.y;
            queue_draw ();
        }

        private double prev_ox = 0;
        private double prev_oy = 0;

        private double applied_rotation = 0;

        private void update_hover_for_connect (double x, double y) {
            Item? exclude = null;
            if (mode == DragMode.ENDPOINT && drag_connector != null) exclude = null;
            var s = shape_at (x, y, exclude);
            hover_shape = s;
            hover_port = s != null ? port_at (s, x, y) : -1;
        }

        private void drag_endpoint () {
            var c = drag_connector;
            var e = drag_src_end ? c.src : c.dst;
            if (hover_shape != null && hover_shape.id != (drag_src_end ? c.dst.item_id : c.src.item_id)) {
                e.item_id = hover_shape.id;
                e.port = hover_port;
            } else {
                e.item_id = "";
                e.port = -1;
                var sp = snap_point (cur_x, cur_y);
                e.x = sp.x;
                e.y = sp.y;
            }
            Router.route (page, c);
        }

        private void drag_move () {
            double dx = cur_x - press_x, dy = cur_y - press_y;
            var target = Rect (drag_start_bounds.x + dx, drag_start_bounds.y + dy, drag_start_bounds.w, drag_start_bounds.h);
            guides.clear ();
            if ((modifiers & Gdk.ModifierType.SHIFT_MASK) != 0) {
                if (dx.abs () > dy.abs ()) target.y = drag_start_bounds.y;
                else target.x = drag_start_bounds.x;
            }
            if ((modifiers & Gdk.ModifierType.ALT_MASK) == 0) {
                bool sx = false, sy = false;
                if (snap_objects) smart_snap (ref target, out sx, out sy, true);
                if (snap_grid) {
                    if (!sx) target.x = snap_value (target.x);
                    if (!sy) target.y = snap_value (target.y);
                }
            }
            var now = Document.selection_bounds (selection);
            double mx = target.x - now.x, my = target.y - now.y;
            if (mx == 0 && my == 0) return;
            foreach (var it in move_set) it.move_by (mx, my);
            reroute_selection ();
            view_changed ();
        }

        private void reroute_selection () {
            var ids = new Gee.HashSet<string> ();
            foreach (var it in move_set ?? selection) {
                ids.add (it.id);
                var g = it as Group;
                if (g != null) {
                    var all = new Gee.ArrayList<Item> ();
                    g.collect (all);
                    foreach (var a in all) ids.add (a.id);
                }
            }
            if (page.connectors ().size < 150) Router.route_all (page);
            else Router.route_attached (page, ids);
        }

        private void smart_snap (ref Rect r, out bool snapped_x, out bool snapped_y, bool edges) {
            snapped_x = false;
            snapped_y = false;
            double threshold = 6 / zoom;
            double[] mine_x = { r.x, r.cx (), r.x2 () };
            double[] mine_y = { r.y, r.cy (), r.y2 () };
            double best_dx = threshold + 1, best_dy = threshold + 1;
            double gx = 0, gy = 0;
            Rect? gxr = null, gyr = null;
            var others = new Gee.ArrayList<Rect?> ();
            foreach (var it in page.items) {
                if (selection.contains (it) || (move_set != null && move_set.contains (it)) || it is Connector || !page.item_visible (it)) continue;
                var b = it.bounds ();
                if (!b.inflate (600 / zoom).intersects (r)) continue;
                others.add (b);
            }
            others.add (Rect (0, 0, page.width, page.height));
            foreach (var b in others) {
                double[] ox = { b.x, b.cx (), b.x2 () };
                double[] oy = { b.y, b.cy (), b.y2 () };
                for (int i = 0; i < 3; i++) {
                    for (int j = 0; j < 3; j++) {
                        double d = ox[j] - mine_x[i];
                        if (d.abs () < best_dx.abs () && d.abs () <= threshold) {
                            best_dx = d;
                            gx = ox[j];
                            gxr = b;
                        }
                        double e = oy[j] - mine_y[i];
                        if (e.abs () < best_dy.abs () && e.abs () <= threshold) {
                            best_dy = e;
                            gy = oy[j];
                            gyr = b;
                        }
                    }
                }
            }
            foreach (var pg in page.guides) {
                if (pg.vertical) {
                    for (int i = 0; i < 3; i++) {
                        double d = pg.pos - mine_x[i];
                        if (d.abs () < best_dx.abs () && d.abs () <= threshold) {
                            best_dx = d;
                            gx = pg.pos;
                            gxr = Rect (pg.pos, r.y, 0, r.h);
                        }
                    }
                } else {
                    for (int i = 0; i < 3; i++) {
                        double e = pg.pos - mine_y[i];
                        if (e.abs () < best_dy.abs () && e.abs () <= threshold) {
                            best_dy = e;
                            gy = pg.pos;
                            gyr = Rect (r.x, pg.pos, r.w, 0);
                        }
                    }
                }
            }
            if (best_dx.abs () <= threshold) {
                r.x += best_dx;
                snapped_x = true;
                guides.add (new Guide (true, gx, double.min (r.y, gxr.y) - 10 / zoom, double.max (r.y2 (), gxr.y2 ()) + 10 / zoom));
            }
            if (best_dy.abs () <= threshold) {
                r.y += best_dy;
                snapped_y = true;
                guides.add (new Guide (false, gy, double.min (r.x, gyr.x) - 10 / zoom, double.max (r.x2 (), gyr.x2 ()) + 10 / zoom));
            }
        }

        private void drag_resize () {
            bool keep = (modifiers & Gdk.ModifierType.SHIFT_MASK) != 0;
            int h = handle_index;
            bool left = h == 0 || h == 6 || h == 7;
            bool right = h == 2 || h == 3 || h == 4;
            bool top = h == 0 || h == 1 || h == 2;
            bool bottom = h == 4 || h == 5 || h == 6;
            if (drag_shape != null && (drag_rotation != 0 || drag_shape.flip_h || drag_shape.flip_v)) {
                var inv = drag_matrix;
                inv.invert ();
                double lx = cur_x, ly = cur_y;
                inv.transform_point (ref lx, ref ly);
                double x1 = 0, y1 = 0, x2 = drag_sw, y2 = drag_sh;
                if (left) x1 = double.min (lx, x2 - 1);
                if (right) x2 = double.max (lx, x1 + 1);
                if (top) y1 = double.min (ly, y2 - 1);
                if (bottom) y2 = double.max (ly, y1 + 1);
                if (keep && drag_sw > 0 && drag_sh > 0) {
                    double ratio = drag_sw / drag_sh;
                    if ((left || right) && !(top || bottom)) {
                        double nh = (x2 - x1) / ratio;
                        y1 = drag_sh / 2 - nh / 2;
                        y2 = y1 + nh;
                    } else if ((x2 - x1) / (y2 - y1) > ratio) {
                        double nw = (y2 - y1) * ratio;
                        if (left) x1 = x2 - nw;
                        else x2 = x1 + nw;
                    } else {
                        double nh = (x2 - x1) / ratio;
                        if (top) y1 = y2 - nh;
                        else y2 = y1 + nh;
                    }
                }
                double cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
                var m = drag_matrix;
                m.transform_point (ref cx, ref cy);
                drag_shape.w = x2 - x1;
                drag_shape.h = y2 - y1;
                drag_shape.x = cx - drag_shape.w / 2;
                drag_shape.y = cy - drag_shape.h / 2;
                reroute_selection ();
                view_changed ();
                return;
            }
            var r0 = drag_start_bounds;
            double nx1 = r0.x, ny1 = r0.y, nx2 = r0.x2 (), ny2 = r0.y2 ();
            double px = cur_x, py = cur_y;
            if ((modifiers & Gdk.ModifierType.ALT_MASK) == 0 && snap_grid) {
                px = snap_value (px);
                py = snap_value (py);
            }
            if (left) nx1 = double.min (px, nx2 - 1);
            if (right) nx2 = double.max (px, nx1 + 1);
            if (top) ny1 = double.min (py, ny2 - 1);
            if (bottom) ny2 = double.max (py, ny1 + 1);
            if (keep && r0.w > 0 && r0.h > 0) {
                double ratio = r0.w / double.max (r0.h, 1e-6);
                if ((left || right) && !(top || bottom)) {
                    double nh = (nx2 - nx1) / ratio;
                    ny1 = r0.cy () - nh / 2;
                    ny2 = ny1 + nh;
                } else if ((top || bottom) && !(left || right)) {
                    double nw = (ny2 - ny1) * ratio;
                    nx1 = r0.cx () - nw / 2;
                    nx2 = nx1 + nw;
                } else if ((nx2 - nx1) / (ny2 - ny1) > ratio) {
                    double nw = (ny2 - ny1) * ratio;
                    if (left) nx1 = nx2 - nw;
                    else nx2 = nx1 + nw;
                } else {
                    double nh = (nx2 - nx1) / ratio;
                    if (top) ny1 = ny2 - nh;
                    else ny2 = ny1 + nh;
                }
            }
            var target = Rect (nx1, ny1, nx2 - nx1, ny2 - ny1);
            var now = Document.selection_bounds (selection);
            doc.scale_items (selection, now, target);
            reroute_selection ();
            view_changed ();
        }

        private void drag_rotate () {
            var c = Point (drag_start_bounds.cx (), drag_start_bounds.cy ());
            double a0 = Math.atan2 (press_y - c.y, press_x - c.x);
            double a1 = Math.atan2 (cur_y - c.y, cur_x - c.x);
            double deg = (a1 - a0) * 180 / Math.PI;
            if (drag_shape != null) {
                double target = drag_rotation + deg;
                if ((modifiers & Gdk.ModifierType.SHIFT_MASK) != 0 || (modifiers & Gdk.ModifierType.ALT_MASK) == 0) {
                    double step = (modifiers & Gdk.ModifierType.SHIFT_MASK) != 0 ? 15 : 1;
                    target = Math.round (target / step) * step;
                    foreach (double snap in new double[] { 0, 90, 180, 270, 360 }) if ((target - snap).abs () < 3) target = snap;
                }
                drag_shape.rotation = Document.normalize_angle (target);
            } else {
                if ((modifiers & Gdk.ModifierType.SHIFT_MASK) != 0) deg = Math.round (deg / 15) * 15;
                double delta = deg - applied_rotation;
                applied_rotation = deg;
                foreach (var it in selection) doc.rotate_item (it, delta, c.x, c.y, true);
            }
            reroute_selection ();
            view_changed ();
        }

        private void on_drag_end (GestureDrag g, double ox, double oy) {
            if (paint_drag) {
                paint_drag = false;
                double bx, by;
                g.get_start_point (out bx, out by);
                var pe = to_page (bx + ox, by + oy);
                paint.release (g, pe.x, pe.y);
                return;
            }
            var m = mode;
            mode = DragMode.NONE;
            guides.clear ();
            prev_ox = 0;
            prev_oy = 0;
            switch (m) {
                case DragMode.PAN:
                    use_tool (tool);
                    break;
                case DragMode.MOVE:
                case DragMode.RESIZE:
                case DragMode.ROTATE:
                    if (dragged) {
                        if (m == DragMode.MOVE || m == DragMode.RESIZE) {
                            foreach (var it in selection) {
                                var s = it as Shape;
                                if (s != null) doc.assign_container (s);
                            }
                        }
                        if (m == DragMode.MOVE && selection.size == 1 && selection[0] is Shape) split_connector_with ((Shape) selection[0]);
                        doc.commit ();
                    } else {
                        doc.cancel ();
                        if (m == DragMode.MOVE) {
                            var it = item_at (press_x, press_y);
                            if (it != null) select_one (page.top_level (it));
                        }
                    }
                    selection_changed ();
                    break;
                case DragMode.RUBBER:
                    var r = Rect.from_points (press_x, press_y, cur_x, cur_y);
                    var list = new Gee.ArrayList<Item> ();
                    if ((modifiers & (Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK)) != 0) list.add_all (selection);
                    if (r.w > 1 || r.h > 1) {
                        foreach (var it in page.items) {
                            if (!page.item_visible (it) || page.item_locked (it) || it is RasterItem) continue;
                            if (r.contains_rect (it.bounds ()) && !list.contains (it)) list.add (it);
                        }
                    }
                    select (list);
                    break;
                case DragMode.CREATE:
                    finish_create ();
                    break;
                case DragMode.CONNECT:
                    finish_connect ();
                    break;
                case DragMode.ENDPOINT:
                case DragMode.WAYPOINT:
                    if (dragged) doc.commit ();
                    else doc.cancel ();
                    drag_connector = null;
                    hover_shape = null;
                    selection_changed ();
                    break;
                case DragMode.FREEHAND:
                    finish_freehand ();
                    break;
                case DragMode.NODE:
                case DragMode.HANDLE:
                    if (dragged) doc.commit ();
                    else doc.cancel ();
                    break;
                case DragMode.PEN_HANDLE:
                    pen_dragging = false;
                    break;
                case DragMode.GUIDE:
                    if (active_guide != null) {
                        var sp = to_screen (active_guide.pos, active_guide.pos);
                        if (dragged && ((active_guide.vertical && sp.x < 8) || (!active_guide.vertical && sp.y < 8))) page.guides.remove (active_guide);
                    }
                    if (dragged) doc.commit ();
                    else doc.cancel ();
                    break;
                case DragMode.CONTROL:
                    if (dragged) doc.commit ();
                    else doc.cancel ();
                    drag_control = -1;
                    break;
                case DragMode.AUTOCONNECT:
                    finish_autoconnect ();
                    break;
                default:
                    break;
            }
            queue_draw ();
            view_changed ();
        }

        private void finish_autoconnect () {
            var src = arrow_shape;
            int dir = hover_arrow;
            if (src == null || dir < 0) return;
            if (!dragged) {
                autoconnect_add (src, dir, null);
                return;
            }
            var c = new Connector ();
            c.route = default_route;
            c.src.item_id = src.id;
            c.src.port = port_toward (src, dir);
            if (hover_shape != null && hover_shape != src) {
                c.dst.item_id = hover_shape.id;
                c.dst.port = hover_port;
            } else {
                var sp = snap_point (cur_x, cur_y);
                c.dst.x = sp.x;
                c.dst.y = sp.y;
            }
            doc.begin (_("Add Connector"));
            doc.add_item (c);
            Theme.style_new_item (doc, c);
            doc.commit ();
            hover_shape = null;
            select_one (c);
        }

        private int port_toward (Shape s, int dir) {
            var ports = s.ports ();
            int best = -1;
            double best_score = -double.INFINITY;
            double[] dx = { 0, 1, 0, -1 };
            double[] dy = { -1, 0, 1, 0 };
            for (int i = 0; i < ports.length; i++) {
                var d = s.port_direction (i);
                var pp = s.port_point (i);
                double score = d.x * dx[dir] + d.y * dy[dir] + ((pp.x - s.cx ()) * dx[dir] + (pp.y - s.cy ()) * dy[dir]) / double.max (s.w + s.h, 1);
                if (score > best_score) {
                    best_score = score;
                    best = i;
                }
            }
            return best;
        }

        public Shape? autoconnect_add (Shape src, int dir, string? kind) {
            double[] dx = { 0, 1, 0, -1 };
            double[] dy = { -1, 0, 1, 0 };
            double gap = 60;
            Shape? existing = null;
            double best = double.INFINITY;
            foreach (var it in page.items) {
                var o = it as Shape;
                if (o == null || o == src || o.is_container () || !page.item_visible (o)) continue;
                double ox = o.cx () - src.cx (), oy = o.cy () - src.cy ();
                double along = ox * dx[dir] + oy * dy[dir];
                double across = (ox * dy[dir] - oy * dx[dir]).abs ();
                double reach = (dir % 2 == 0 ? src.h + o.h : src.w + o.w) / 2 + gap * 2.2;
                double tol_across = (dir % 2 == 0 ? double.max (src.w, o.w) : double.max (src.h, o.h)) / 2;
                if (along > 0 && along < reach && across < tol_across && along < best) {
                    best = along;
                    existing = o;
                }
            }
            doc.begin (_("AutoConnect"));
            Shape target;
            if (existing != null && kind == null) {
                target = existing;
            } else {
                string k = kind ?? src.kind;
                Shape ns;
                if (kind == null) {
                    ns = (Shape) src.clone ();
                    ns.id = "";
                    ns.text = ShapeLibrary.default_text (ns.kind);
                    ns.fields.clear ();
                    ns.sheet = null;
                    ns.data_key = "";
                } else {
                    var e = ShapeLibrary.find (k);
                    ns = create_shape (k, Rect (0, 0, e != null ? e.w : 120, e != null ? e.h : 60));
                }
                double ncx = src.cx () + dx[dir] * ((dir % 2 == 1 ? src.w + ns.w : src.h + ns.h) / 2 + gap);
                double ncy = src.cy () + dy[dir] * ((dir % 2 == 1 ? src.w + ns.w : src.h + ns.h) / 2 + gap);
                ns.x = snap_value (ncx - ns.w / 2);
                ns.y = snap_value (ncy - ns.h / 2);
                if (dir % 2 == 0) ns.x = src.cx () - ns.w / 2;
                else ns.y = src.cy () - ns.h / 2;
                doc.add_item (ns);
                if (kind != null) Theme.style_new_item (doc, ns);
                target = ns;
            }
            var c = new Connector ();
            c.route = default_route;
            c.src.item_id = src.id;
            c.dst.item_id = target.id;
            c.src.port = port_toward (src, dir);
            c.dst.port = port_toward (target, (dir + 2) % 4);
            doc.add_item (c);
            Theme.style_new_item (doc, c);
            doc.commit ();
            arrow_shape = null;
            hover_arrow = -1;
            select_one (target);
            return target;
        }

        private void edit_port_at (double x, double y) {
            var s = shape_at (x, y);
            if (s == null && hover_shape != null && hover_shape.bounds ().inflate (10 / zoom).contains (x, y)) s = hover_shape;
            if (s == null) {
                select (new Gee.ArrayList<Item> ());
                selected_port = -1;
                return;
            }
            int existing = port_at (s, x, y);
            if (existing >= 0) {
                select_one (page.top_level (s));
                selected_port = existing;
                queue_draw ();
                return;
            }
            var local = s.to_local (x, y);
            var outline = s.outline ();
            double best = double.INFINITY;
            Point snapped = local;
            foreach (var poly in outline.flatten (0.5)) {
                int n = poly.pts.length;
                for (int i = 0; i < n; i++) {
                    var a = poly.pts[i];
                    var b = poly.pts[(i + 1) % n];
                    double lx = b.x - a.x, ly = b.y - a.y;
                    double l2 = lx * lx + ly * ly;
                    double t = l2 > 0 ? (((local.x - a.x) * lx + (local.y - a.y) * ly) / l2).clamp (0, 1) : 0;
                    var q = Point (a.x + lx * t, a.y + ly * t);
                    double d = q.distance (local);
                    if (d < best) {
                        best = d;
                        snapped = q;
                    }
                }
            }
            if (best * zoom < 10) local = snapped;
            doc.begin (_("Add Connection Point"));
            Point[] pts = s.ports ();
            pts += Point (s.w > 0 ? local.x / s.w : 0.5, s.h > 0 ? local.y / s.h : 0.5);
            s.custom_ports = pts;
            doc.commit ();
            select_one (page.top_level (s));
            selected_port = pts.length - 1;
            queue_draw ();
        }

        public bool delete_selected_port () {
            var s = single_shape ();
            if (tool != Tool.CONNECTION_POINT || s == null || selected_port < 0 || selected_port >= s.ports ().length) return false;
            doc.begin (_("Delete Connection Point"));
            Point[] pts = {};
            var old = s.ports ();
            for (int i = 0; i < old.length; i++) if (i != selected_port) pts += old[i];
            s.custom_ports = pts;
            foreach (var c in page.connectors_of (s.id)) {
                foreach (var e in new Endpoint[] { c.src, c.dst }) {
                    if (e.item_id != s.id) continue;
                    if (e.port == selected_port) e.port = -1;
                    else if (e.port > selected_port) e.port--;
                }
            }
            doc.commit ();
            selected_port = -1;
            return true;
        }

        public void reset_ports (Shape s) {
            doc.begin (_("Reset Connection Points"));
            int n = ShapeLibrary.ports (s.kind, s.w, s.h).length;
            s.custom_ports = null;
            foreach (var c in page.connectors_of (s.id)) {
                if (c.src.item_id == s.id && c.src.port >= n) c.src.port = -1;
                if (c.dst.item_id == s.id && c.dst.port >= n) c.dst.port = -1;
            }
            doc.commit ();
        }

        public bool split_connector_with (Shape s) {
            return doc.split_connector (s, double.max (6 / zoom, 3));
        }

        private void finish_create () {
            var r = creation_rect ();
            bool click = r.w * zoom < 4 && r.h * zoom < 4;
            if (tool == Tool.LINE) {
                var e = line_end ();
                if (click) return;
                var ps = new PathShape ();
                var path = new PathData ();
                path.move_to (press_x, press_y);
                path.line_to (e.x, e.y);
                ps.set_page_path (path);
                ps.style.fill_kind = FillKind.NONE;
                doc.begin (_("Draw Line"));
                doc.add_item (ps);
                doc.commit ();
                select_one (ps);
                use_tool (Tool.SELECT);
                return;
            }
            string kind = tool == Tool.RECTANGLE ? "rectangle" : (tool == Tool.ELLIPSE ? "ellipse" : (tool == Tool.TEXT ? "text" : stamp_kind));
            var entry = ShapeLibrary.find (kind);
            if (click) {
                double w = entry != null ? entry.w : 120, h = entry != null ? entry.h : 60;
                if (tool == Tool.TEXT) {
                    w = 160;
                    h = 30;
                }
                r = Rect (press_x - (tool == Tool.TEXT ? 0 : w / 2), press_y - (tool == Tool.TEXT ? h / 2 : h / 2), w, h);
                if (tool != Tool.TEXT) r = Rect (snap_value (r.x), snap_value (r.y), w, h);
            } else if (snap_grid) {
                r = Rect (r.x, r.y, double.max (snap_value (r.w), doc.grid_size), double.max (snap_value (r.h), doc.grid_size));
            }
            var s = create_shape (kind, r);
            doc.begin (_("Insert Shape"));
            doc.add_item (s);
            doc.commit ();
            select_one (s);
            var was = tool;
            use_tool (Tool.SELECT);
            if (was == Tool.TEXT) edit_text_requested (s, -1, -1);
        }

        public Shape create_shape (string kind, Rect r) {
            Shape s;
            if (kind == "table") s = new TableShape (3, 3);
            else if (kind == "gantt") s = GanttShape.sample ();
            else s = new Shape (kind);
            s.set_bounds (r);
            if (kind != "table" && kind != "gantt") ShapeLibrary.apply_defaults (s);
            s.text = ShapeLibrary.default_text (kind);
            if (kind == "text") s.text = "";
            Theme.style_new_item (doc, s);
            return s;
        }

        private Shape? insert_master (string kind, double cx, double cy, bool at_point) {
            var m = UserStencils.find_master (kind);
            if (m == null) return null;
            var items = doc.clone_with_new_ids (m.items ());
            if (items.size == 0) return null;
            if (!at_point) {
                var v = visible_rect ();
                cx = v.cx ();
                cy = v.cy ();
            }
            var b = Document.selection_bounds (items);
            foreach (var it in items) it.move_by (snap_value (cx - b.w / 2) - b.x, snap_value (cy - b.h / 2) - b.y);
            doc.begin (_("Insert %s").printf (m.name));
            Item top;
            if (items.size == 1) {
                top = items[0];
                doc.add_item (top);
            } else {
                foreach (var it in items) doc.add_item (it);
                var grp = doc.group (items);
                top = grp != null ? (Item) grp : items[0];
            }
            doc.commit ();
            select_one (top);
            return top as Shape;
        }

        public Shape? insert_library_shape (string kind, double cx, double cy, bool at_point) {
            if (kind.has_prefix ("master:")) return insert_master (kind, cx, cy, at_point);
            var entry = ShapeLibrary.find (kind);
            double w = entry != null ? entry.w : 120, h = entry != null ? entry.h : 60;
            var def = Stencils.find (kind);
            if (def != null && def.world_size != "" && page.has_scale ()) {
                string[] parts = def.world_size.split ("x");
                if (parts.length == 2) {
                    double ww = Units.parse_length (parts[0]) / Units.PX_PER_MM, hh = Units.parse_length (parts[1]) / Units.PX_PER_MM;
                    double wr = page.from_world (ww / Units.mm_per (page.scale_units)), hr = page.from_world (hh / Units.mm_per (page.scale_units));
                    if (wr > 1 && hr > 1) {
                        w = wr;
                        h = hr;
                    }
                }
            }
            if (!at_point) {
                var v = visible_rect ();
                cx = v.cx ();
                cy = v.cy ();
            }
            var r = Rect (snap_value (cx - w / 2), snap_value (cy - h / 2), w, h);
            var s = create_shape (kind, r);
            doc.begin (_("Insert %s").printf (ShapeLibrary.display_name (kind)));
            doc.add_item (s);
            if (!at_point && selection.size == 1 && selection[0] is Shape && !(selection[0] as Shape).is_container ()) {
                var prev = selection[0] as Shape;
                s.x = snap_value (prev.x + prev.w / 2 - w / 2);
                s.y = snap_value (prev.y + prev.h + 60);
                var c = new Connector ();
                c.route = default_route;
                c.src.item_id = prev.id;
                c.dst.item_id = s.id;
                doc.add_item (c);
                Theme.style_new_item (doc, c);
                doc.assign_container (s);
            }
            if (at_point) split_connector_with (s);
            doc.commit ();
            select_one (s);
            return s;
        }

        private void finish_connect () {
            var c = drag_connector;
            drag_connector = null;
            if (c == null) return;
            double len = Math.hypot (cur_x - press_x, cur_y - press_y);
            if (len * zoom < 6) {
                hover_shape = null;
                return;
            }
            if (hover_shape != null && hover_shape.id != c.src.item_id) {
                c.dst.item_id = hover_shape.id;
                c.dst.port = hover_port;
            } else {
                var sp = snap_point (cur_x, cur_y);
                c.dst.x = sp.x;
                c.dst.y = sp.y;
            }
            doc.begin (_("Add Connector"));
            doc.add_item (c);
            doc.commit ();
            hover_shape = null;
            select_one (c);
            if (tool == Tool.CONNECTOR && (modifiers & Gdk.ModifierType.CONTROL_MASK) == 0) use_tool (Tool.SELECT);
        }

        private void finish_freehand () {
            if (freehand_pts.size < 2) return;
            Point[] pts = {};
            foreach (var p in freehand_pts) pts += p;
            freehand_pts.clear ();
            var simple = rdp (pts, 1.5 / zoom);
            bool closed = simple.length > 3 && simple[0].distance (simple[simple.length - 1]) * zoom < 12;
            var path = fit_curve (simple, closed);
            var ps = new PathShape ();
            ps.set_page_path (path);
            if (!closed) ps.style.fill_kind = FillKind.NONE;
            doc.begin (_("Freehand"));
            doc.add_item (ps);
            doc.commit ();
            select_one (ps);
        }

        public static Point[] rdp (Point[] pts, double eps) {
            if (pts.length < 3) return pts;
            double dmax = 0;
            int index = 0;
            for (int i = 1; i < pts.length - 1; i++) {
                double d = PathData.segment_distance (pts[0], pts[pts.length - 1], pts[i].x, pts[i].y);
                if (d > dmax) {
                    dmax = d;
                    index = i;
                }
            }
            if (dmax > eps) {
                var a = rdp (pts[0:index + 1], eps);
                var b = rdp (pts[index:pts.length], eps);
                Point[] res = {};
                for (int i = 0; i < a.length - 1; i++) res += a[i];
                foreach (var p in b) res += p;
                return res;
            }
            return { pts[0], pts[pts.length - 1] };
        }

        public static PathData fit_curve (Point[] pts, bool closed) {
            var p = new PathData ();
            int n = pts.length;
            if (n == 0) return p;
            p.move_to (pts[0].x, pts[0].y);
            if (n == 2) {
                p.line_to (pts[1].x, pts[1].y);
                return p;
            }
            int last = closed ? n - 1 : n;
            for (int i = 1; i < last; i++) {
                var p0 = i - 2 >= 0 ? pts[i - 2] : (closed ? pts[(i - 2 + n - 1) % (n - 1)] : pts[i - 1]);
                var p1 = pts[i - 1];
                var p2 = pts[i];
                var p3 = i + 1 < n ? pts[i + 1] : (closed ? pts[1] : pts[i]);
                p.curve_to (p1.x + (p2.x - p0.x) / 6, p1.y + (p2.y - p0.y) / 6, p2.x - (p3.x - p1.x) / 6, p2.y - (p3.y - p1.y) / 6, p2.x, p2.y);
            }
            if (closed) p.close ();
            return p;
        }

        private double pen_out_x;
        private double pen_out_y;
        private bool pen_out_valid = false;

        private void pen_press (double x, double y) {
            if (pen_path == null) {
                pen_path = new PathData ();
                pen_path.move_to (x, y);
                pen_out_valid = false;
            } else {
                var first = pen_path.segs[0];
                if (pen_path.segs.size > 2 && point_near (Point (first.x, first.y), x, y, 8)) {
                    add_pen_segment (first.x, first.y);
                    pen_path.close ();
                    finish_pen ();
                    return;
                }
                add_pen_segment (x, y);
            }
            pen_dragging = true;
            mode = DragMode.PEN_HANDLE;
            queue_draw ();
        }

        private void add_pen_segment (double x, double y) {
            var last = pen_path.segs[pen_path.segs.size - 1];
            if (pen_out_valid) pen_path.curve_to (pen_out_x, pen_out_y, x, y, x, y);
            else pen_path.line_to (x, y);
            pen_out_valid = false;
            if (last == null) return;
        }

        private void pen_drag (double x, double y) {
            var last = pen_path.segs[pen_path.segs.size - 1];
            if (Math.hypot (x - last.x, y - last.y) * zoom < 3) return;
            pen_out_x = x;
            pen_out_y = y;
            pen_out_valid = true;
            if (last.kind == SegKind.CURVE) {
                last.x2 = 2 * last.x - x;
                last.y2 = 2 * last.y - y;
            } else if (last.kind == SegKind.LINE && pen_path.segs.size >= 2) {
                var prev = pen_path.segs[pen_path.segs.size - 2];
                last.kind = SegKind.CURVE;
                last.x1 = prev.x;
                last.y1 = prev.y;
                last.x2 = 2 * last.x - x;
                last.y2 = 2 * last.y - y;
            }
        }

        public void finish_pen () {
            var path = pen_path;
            pen_path = null;
            pen_out_valid = false;
            if (path == null || path.node_count () < 2) {
                queue_draw ();
                return;
            }
            var ps = new PathShape ();
            ps.set_page_path (path);
            if (!path.has_closed_subpath ()) ps.style.fill_kind = FillKind.NONE;
            doc.begin (_("Draw Path"));
            doc.add_item (ps);
            doc.commit ();
            tool = Tool.SELECT;
            use_tool (Tool.SELECT);
            select_one (ps);
        }

        public void cancel_pen () {
            pen_path = null;
            pen_out_valid = false;
            queue_draw ();
        }

        public bool pen_active () {
            return pen_path != null;
        }

        public void enter_node_edit (PathShape ps) {
            ps.normalize ();
            node_target = ps;
            node_selected = -1;
            select_one (ps);
            node_target = ps;
            queue_draw ();
        }

        public void exit_node_edit () {
            node_target = null;
            queue_draw ();
        }

        private int drag_seg = -1;
        private int drag_which = 0;

        private bool node_press (double x, double y) {
            var path = node_target.page_path ();
            for (int i = 0; i < path.segs.size; i++) {
                var s = path.segs[i];
                if (s.kind == SegKind.CURVE) {
                    if (point_near (Point (s.x1, s.y1), x, y)) {
                        drag_seg = i;
                        drag_which = 1;
                        mode = DragMode.HANDLE;
                        doc.begin (_("Edit Points"));
                        return true;
                    }
                    if (point_near (Point (s.x2, s.y2), x, y)) {
                        drag_seg = i;
                        drag_which = 2;
                        mode = DragMode.HANDLE;
                        doc.begin (_("Edit Points"));
                        return true;
                    }
                }
            }
            for (int i = 0; i < path.segs.size; i++) {
                var s = path.segs[i];
                if (s.kind == SegKind.CLOSE) continue;
                if (point_near (Point (s.x, s.y), x, y)) {
                    drag_seg = i;
                    drag_which = 0;
                    node_selected = i;
                    mode = DragMode.NODE;
                    doc.begin (_("Edit Points"));
                    return true;
                }
            }
            if (node_target.hit (x, y, tol ())) {
                node_selected = -1;
                return true;
            }
            return false;
        }

        private void drag_node (double x, double y) {
            if (node_target == null || drag_seg < 0) return;
            var path = node_target.page_path ();
            if (drag_seg >= path.segs.size) return;
            var before = handle_constraint != null && drag_which != 0 ? path.copy () : null;
            var s = path.segs[drag_seg];
            if (drag_which == 0) {
                double dx = x - s.x, dy = y - s.y;
                s.x = x;
                s.y = y;
                if (s.kind == SegKind.CURVE) {
                    s.x2 += dx;
                    s.y2 += dy;
                }
                if (drag_seg + 1 < path.segs.size && path.segs[drag_seg + 1].kind == SegKind.CURVE) {
                    path.segs[drag_seg + 1].x1 += dx;
                    path.segs[drag_seg + 1].y1 += dy;
                }
                if (s.kind == SegKind.MOVE) {
                    int close_i = -1;
                    for (int i = drag_seg + 1; i < path.segs.size; i++) {
                        if (path.segs[i].kind == SegKind.MOVE) break;
                        if (path.segs[i].kind == SegKind.CLOSE) close_i = i;
                    }
                    if (close_i > 0) {
                        var lastn = path.segs[close_i - 1];
                        if ((lastn.x - (x - dx)).abs () < 0.01 && (lastn.y - (y - dy)).abs () < 0.01) {
                            lastn.x = x;
                            lastn.y = y;
                            if (lastn.kind == SegKind.CURVE) {
                                lastn.x2 += dx;
                                lastn.y2 += dy;
                            }
                        }
                    }
                }
            } else if (drag_which == 1) {
                s.x1 = x;
                s.y1 = y;
                if ((modifiers & Gdk.ModifierType.ALT_MASK) == 0 && drag_seg - 1 >= 0) {
                    var prev = path.segs[drag_seg - 1];
                    if (prev.kind == SegKind.CURVE) {
                        double len = Math.hypot (prev.x2 - prev.x, prev.y2 - prev.y);
                        double ang = Math.atan2 (y - prev.y, x - prev.x) + Math.PI;
                        prev.x2 = prev.x + Math.cos (ang) * len;
                        prev.y2 = prev.y + Math.sin (ang) * len;
                    }
                }
            } else {
                s.x2 = x;
                s.y2 = y;
                if ((modifiers & Gdk.ModifierType.ALT_MASK) == 0 && drag_seg + 1 < path.segs.size) {
                    var next = path.segs[drag_seg + 1];
                    if (next.kind == SegKind.CURVE) {
                        double len = Math.hypot (next.x1 - s.x, next.y1 - s.y);
                        double ang = Math.atan2 (y - s.y, x - s.x) + Math.PI;
                        next.x1 = s.x + Math.cos (ang) * len;
                        next.y1 = s.y + Math.sin (ang) * len;
                    }
                }
            }
            if (before != null) handle_constraint (before, path, drag_seg, drag_which, (modifiers & Gdk.ModifierType.ALT_MASK) != 0);
            node_target.set_page_path (path);
            view_changed ();
        }

        private void insert_node_at (double x, double y) {
            var path = node_target.page_path ();
            double cx = 0, cy = 0, sx = 0, sy = 0;
            int best_i = -1;
            double best_t = 0, best_d = double.INFINITY;
            for (int i = 0; i < path.segs.size; i++) {
                var s = path.segs[i];
                if (s.kind == SegKind.MOVE) {
                    cx = sx = s.x;
                    cy = sy = s.y;
                    continue;
                }
                double ex = s.kind == SegKind.CLOSE ? sx : s.x, ey = s.kind == SegKind.CLOSE ? sy : s.y;
                for (int k = 0; k <= 40; k++) {
                    double t = k / 40.0;
                    Point p = s.kind == SegKind.CURVE ? PathData.bezier_point (cx, cy, s.x1, s.y1, s.x2, s.y2, ex, ey, t) : Point (cx + (ex - cx) * t, cy + (ey - cy) * t);
                    double d = Math.hypot (p.x - x, p.y - y);
                    if (d < best_d) {
                        best_d = d;
                        best_i = i;
                        best_t = t;
                    }
                }
                cx = ex;
                cy = ey;
            }
            if (best_i < 0 || best_d * zoom > 10 || best_t <= 0.01 || best_t >= 0.99) return;
            doc.begin (_("Add Point"));
            double px = 0, py = 0;
            for (int i = best_i - 1; i >= 0; i--) {
                if (path.segs[i].kind != SegKind.CLOSE) {
                    px = path.segs[i].x;
                    py = path.segs[i].y;
                    break;
                }
            }
            var s = path.segs[best_i];
            if (s.kind == SegKind.CURVE) {
                double t = best_t;
                double ax = px + (s.x1 - px) * t, ay = py + (s.y1 - py) * t;
                double bx = s.x1 + (s.x2 - s.x1) * t, by = s.y1 + (s.y2 - s.y1) * t;
                double c2x = s.x2 + (s.x - s.x2) * t, c2y = s.y2 + (s.y - s.y2) * t;
                double dx = ax + (bx - ax) * t, dy = ay + (by - ay) * t;
                double ex = bx + (c2x - bx) * t, ey = by + (c2y - by) * t;
                double mx = dx + (ex - dx) * t, my = dy + (ey - dy) * t;
                var first = new PathSeg (SegKind.CURVE, mx, my);
                first.x1 = ax;
                first.y1 = ay;
                first.x2 = dx;
                first.y2 = dy;
                s.x1 = ex;
                s.y1 = ey;
                s.x2 = c2x;
                s.y2 = c2y;
                path.segs.insert (best_i, first);
            } else if (s.kind == SegKind.LINE) {
                path.segs.insert (best_i, new PathSeg (SegKind.LINE, px + (s.x - px) * best_t, py + (s.y - py) * best_t));
            } else {
                return;
            }
            node_target.set_page_path (path);
            node_selected = best_i;
            doc.commit ();
        }

        public void delete_selected_node () {
            if (node_target == null || node_selected < 0) return;
            var path = node_target.page_path ();
            if (path.node_count () <= 2) return;
            var s = path.segs[node_selected];
            if (s.kind == SegKind.MOVE) {
                if (node_selected + 1 < path.segs.size && path.segs[node_selected + 1].kind != SegKind.CLOSE) {
                    var next = path.segs[node_selected + 1];
                    next.kind = SegKind.MOVE;
                }
            }
            doc.begin (_("Delete Point"));
            path.segs.remove_at (node_selected);
            node_target.set_page_path (path);
            node_selected = -1;
            doc.commit ();
        }

        public void toggle_node_smooth () {
            if (node_target == null || node_selected < 0) return;
            var path = node_target.page_path ();
            var s = path.segs[node_selected];
            if (s.kind == SegKind.CLOSE) return;
            double px = s.x, py = s.y;
            PathSeg? prev_node = null;
            for (int i = node_selected - 1; i >= 0; i--) if (path.segs[i].kind != SegKind.CLOSE) {
                prev_node = path.segs[i];
                break;
            }
            PathSeg? next = node_selected + 1 < path.segs.size ? path.segs[node_selected + 1] : null;
            doc.begin (_("Smooth Point"));
            bool smooth = s.kind == SegKind.CURVE && next != null && next.kind == SegKind.CURVE;
            if (smooth) {
                s.x2 = px;
                s.y2 = py;
                next.x1 = px;
                next.y1 = py;
            } else {
                double ax = prev_node != null ? prev_node.x : px, ay = prev_node != null ? prev_node.y : py;
                double bx = next != null && next.kind != SegKind.CLOSE ? next.x : px, by = next != null && next.kind != SegKind.CLOSE ? next.y : py;
                double tx = (bx - ax) / 4, ty = (by - ay) / 4;
                if (s.kind == SegKind.LINE && prev_node != null) {
                    s.kind = SegKind.CURVE;
                    s.x1 = prev_node.x;
                    s.y1 = prev_node.y;
                }
                if (s.kind == SegKind.CURVE) {
                    s.x2 = px - tx;
                    s.y2 = py - ty;
                }
                if (next != null && next.kind == SegKind.LINE) {
                    next.kind = SegKind.CURVE;
                    next.x2 = next.x;
                    next.y2 = next.y;
                }
                if (next != null && next.kind == SegKind.CURVE) {
                    next.x1 = px + tx;
                    next.y1 = py + ty;
                }
            }
            node_target.set_page_path (path);
            doc.commit ();
        }

        public void apply_painter (Item target) {
            if (painter_style == null) return;
            doc.begin (_("Paste Style"));
            target.style.assign_appearance (painter_style, target is Connector || target is PathShape);
            doc.commit ();
            painter_style = null;
            set_cursor_from_name (null);
            painter_finished ();
        }

        public void nudge (double dx, double dy) {
            if (selection.size == 0) return;
            doc.begin (_("Move"));
            doc.move_items (selection, dx, dy);
            doc.commit ();
        }

        private bool on_key (uint keyval, uint code, Gdk.ModifierType state) {
            if (paint_active () && paint.key (keyval, state)) return true;
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
            double step = shift ? doc.grid_size : 1;
            switch (keyval) {
                case Gdk.Key.space:
                    if (!space_down && mode == DragMode.NONE && !ctrl) {
                        space_down = true;
                        tool_before_pan = tool;
                        set_cursor_from_name ("grab");
                    }
                    return true;
                case Gdk.Key.Escape:
                    if (pen_path != null) {
                        finish_pen ();
                        return true;
                    }
                    if (painter_style != null) {
                        painter_style = null;
                        set_cursor_from_name (null);
                        painter_finished ();
                        return true;
                    }
                    if (node_target != null) {
                        exit_node_edit ();
                        return true;
                    }
                    if (tool != Tool.SELECT) {
                        use_tool (Tool.SELECT);
                        return true;
                    }
                    if (selection.size > 0) {
                        select (new Gee.ArrayList<Item> ());
                        return true;
                    }
                    return false;
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    if (pen_path != null) {
                        finish_pen ();
                        return true;
                    }
                    if (ctrl) return false;
                    if (selection.size == 1) {
                        var ps = selection[0] as PathShape;
                        if (ps != null && ps.text == "" && node_target == null) {
                            enter_node_edit (ps);
                            return true;
                        }
                        edit_text_requested (selection[0], -1, -1);
                        return true;
                    }
                    return false;
                case Gdk.Key.F2:
                    if (selection.size == 1) {
                        edit_text_requested (selection[0], -1, -1);
                        return true;
                    }
                    return false;
                case Gdk.Key.Delete:
                case Gdk.Key.BackSpace:
                    if (delete_selected_port ()) return true;
                    if (node_target != null) {
                        delete_selected_node ();
                        return true;
                    }
                    if (selection.size > 0) {
                        activate_action ("win.delete", null);
                        return true;
                    }
                    return false;
                case Gdk.Key.Left:
                    if (ctrl) return false;
                    nudge (-step, 0);
                    return true;
                case Gdk.Key.Right:
                    if (ctrl) return false;
                    nudge (step, 0);
                    return true;
                case Gdk.Key.Up:
                    if (ctrl) return false;
                    nudge (0, -step);
                    return true;
                case Gdk.Key.Down:
                    if (ctrl) return false;
                    nudge (0, step);
                    return true;
                case Gdk.Key.Tab:
                case Gdk.Key.ISO_Left_Tab:
                    if (page.items.size == 0) return true;
                    int idx = selection.size == 1 ? page.items.index_of (selection[0]) : -1;
                    int n = page.items.size;
                    idx = shift || keyval == Gdk.Key.ISO_Left_Tab ? (idx <= 0 ? n - 1 : idx - 1) : (idx + 1) % n;
                    select_one (page.items[idx]);
                    return true;
                default:
                    break;
            }
            if (!ctrl && (state & Gdk.ModifierType.ALT_MASK) == 0 && selection.size == 1 && tool == Tool.SELECT && node_target == null) {
                unichar ch = Gdk.keyval_to_unicode (keyval);
                if (ch != 0 && !ch.iscntrl () && !(selection[0] is ImageShape)) {
                    initial_text = ch.to_string ();
                    edit_text_requested (selection[0], -1, -1);
                    return true;
                }
            }
            return false;
        }

        public string? initial_text = null;

        public Gdk.Rectangle screen_rect (Rect r) {
            var a = to_screen (r.x, r.y);
            var b = to_screen (r.x2 (), r.y2 ());
            var rect = Gdk.Rectangle ();
            rect.x = (int) a.x;
            rect.y = (int) a.y;
            rect.width = int.max (1, (int) (b.x - a.x));
            rect.height = int.max (1, (int) (b.y - a.y));
            return rect;
        }
    }
}
