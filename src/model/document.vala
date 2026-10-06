namespace Singularity.Apps.Draw {

    public enum AlignKind {
        LEFT,
        CENTER,
        RIGHT,
        TOP,
        MIDDLE,
        BOTTOM
    }

    public class Snapshot {
        public Gee.ArrayList<Page> pages = new Gee.ArrayList<Page> ();
        public int page_index;
        public string label;
        public string[] selection = {};
        public bool mergeable = false;
        public int64 time = 0;
        public string theme_id = "";
        public int theme_variant = 0;
        public Gee.ArrayList<DataSource> data_sources = new Gee.ArrayList<DataSource> ();
        public Gee.ArrayList<DataGraphic> data_graphics = new Gee.ArrayList<DataGraphic> ();
    }

    public class Document : Object {
        public Gee.ArrayList<Page> pages = new Gee.ArrayList<Page> ();
        public string? path = null;
        public bool modified { get; set; default = false; }
        public int page_index = 0;
        public double grid_size = 10;
        public string units = "px";
        public string title = "";
        public string theme_id = "";
        public int theme_variant = 0;
        public Theme? custom_theme = null;
        public Gee.ArrayList<DataSource> data_sources = new Gee.ArrayList<DataSource> ();
        public Gee.ArrayList<DataGraphic> data_graphics = new Gee.ArrayList<DataGraphic> ();
        public string validation_rules = "";
        public Gee.HashSet<string> ignored_issues = new Gee.HashSet<string> ();
        private int next_id = 1;
        private Gee.ArrayList<Snapshot> undo_stack = new Gee.ArrayList<Snapshot> ();
        private Gee.ArrayList<Snapshot> redo_stack = new Gee.ArrayList<Snapshot> ();
        private Snapshot? pending = null;
        public string[] selection_hint = {};
        public const int UNDO_LIMIT = 200;
        public string live_tag = "";

        public signal void changed ();
        public signal void pages_changed ();
        public signal void restored (string[] selection);

        public Document () {
            var p = new Page (_("Page 1"));
            p.id = "page1";
            pages.add (p);
        }

        public Page page {
            owned get {
                if (page_index < 0 || page_index >= pages.size) page_index = 0;
                return pages[page_index];
            }
        }

        public bool can_undo {
            get { return undo_stack.size > 0; }
        }

        public bool can_redo {
            get { return redo_stack.size > 0; }
        }

        public string undo_label {
            owned get { return undo_stack.size > 0 ? undo_stack[undo_stack.size - 1].label : ""; }
        }

        public string redo_label {
            owned get { return redo_stack.size > 0 ? redo_stack[redo_stack.size - 1].label : ""; }
        }

        public string new_id (string prefix = "s") {
            while (true) {
                string id = prefix + (next_id++).to_string () + live_tag;
                bool used = false;
                foreach (var p in pages) {
                    if (p.find (id) != null) {
                        used = true;
                        break;
                    }
                }
                if (!used) return id;
            }
        }

        public void sync_ids () {
            int max = 0;
            foreach (var p in pages) {
                foreach (var it in p.all_items ()) {
                    string digits = "";
                    for (int i = it.id.length - 1; i >= 0 && it.id[i].isdigit (); i--) digits = it.id[i].to_string () + digits;
                    if (digits != "" && digits.length < 9) max = int.max (max, int.parse (digits));
                }
            }
            next_id = max + 1;
        }

        public void ensure_ids () {
            var seen = new Gee.HashSet<string> ();
            foreach (var p in pages) {
                foreach (var it in p.all_items ()) {
                    if (it.id == "" || seen.contains (it.id)) it.id = new_id ();
                    seen.add (it.id);
                }
            }
        }

        public Snapshot take_snapshot (string label) {
            var s = new Snapshot ();
            s.label = label;
            s.page_index = page_index;
            foreach (var p in pages) s.pages.add (p.clone ());
            s.selection = selection_hint;
            s.theme_id = theme_id;
            s.theme_variant = theme_variant;
            foreach (var d in data_sources) s.data_sources.add (d.copy ());
            foreach (var g in data_graphics) s.data_graphics.add (g.copy ());
            return s;
        }

        public void begin (string label) {
            if (pending == null) pending = take_snapshot (label);
        }

        public void merge_pending () {
            if (pending != null) pending.mergeable = true;
        }

        public bool in_edit () {
            return pending != null;
        }

        public void commit () {
            if (pending == null) return;
            int64 now = get_monotonic_time ();
            pending.time = now;
            bool merge = false;
            if (pending.mergeable && undo_stack.size > 0) {
                var last = undo_stack[undo_stack.size - 1];
                merge = last.mergeable && last.label == pending.label && now - last.time < 1500000;
                if (merge) last.time = now;
            }
            if (!merge) undo_stack.add (pending);
            while (undo_stack.size > UNDO_LIMIT) undo_stack.remove_at (0);
            redo_stack.clear ();
            pending = null;
            ShapeSheet.recalc_page (page);
            Router.route_all (page);
            link_backgrounds ();
            modified = true;
            changed ();
        }

        public void cancel () {
            pending = null;
        }

        public void revert_pending () {
            if (pending == null) return;
            var s = pending;
            pending = null;
            restore (s);
        }

        public void edit (string label, owned Callback cb) {
            begin (label);
            cb ();
            commit ();
        }

        public delegate void Callback ();

        private void restore (Snapshot s) {
            pages.clear ();
            foreach (var p in s.pages) pages.add (p.clone ());
            page_index = s.page_index.clamp (0, pages.size - 1);
            theme_id = s.theme_id;
            theme_variant = s.theme_variant;
            data_sources.clear ();
            foreach (var d in s.data_sources) data_sources.add (d.copy ());
            data_graphics.clear ();
            foreach (var g in s.data_graphics) data_graphics.add (g.copy ());
            foreach (var p in pages) Router.route_all (p);
            link_backgrounds ();
            pages_changed ();
            restored (s.selection);
            changed ();
        }

        public void undo () {
            if (undo_stack.size == 0) return;
            var s = undo_stack.remove_at (undo_stack.size - 1);
            redo_stack.add (take_snapshot (s.label));
            restore (s);
            modified = true;
        }

        public void redo () {
            if (redo_stack.size == 0) return;
            var s = redo_stack.remove_at (redo_stack.size - 1);
            undo_stack.add (take_snapshot (s.label));
            restore (s);
            modified = true;
        }

        public Gee.ArrayList<Snapshot> history () {
            var list = new Gee.ArrayList<Snapshot> ();
            list.add_all (undo_stack);
            list.add_all (redo_stack);
            if (pending != null) list.add (pending);
            return list;
        }

        public void clear_history () {
            undo_stack.clear ();
            redo_stack.clear ();
            pending = null;
        }

        public void notify_changed () {
            Router.route_all (page);
            changed ();
        }

        public Page add_page (int index = -1, string? name = null) {
            var p = new Page (name ?? _("Page %d").printf (pages.size + 1));
            p.id = new_page_id ();
            var cur = page;
            p.width = cur.width;
            p.height = cur.height;
            if (index < 0 || index > pages.size) index = pages.size;
            pages.insert (index, p);
            return p;
        }

        public string new_page_id () {
            int n = 1;
            while (true) {
                string id = "page%d".printf (n++) + live_tag;
                bool used = false;
                foreach (var p in pages) if (p.id == id) used = true;
                if (!used) return id;
            }
        }

        public Page duplicate_page (Page src) {
            var p = src.clone ();
            p.id = new_page_id ();
            p.name = _("%s (Copy)").printf (src.name);
            var map = new Gee.HashMap<string, string> ();
            foreach (var it in p.all_items ()) {
                string nid = new_id ();
                map[it.id] = nid;
            }
            remap_ids (p.all_items (), map);
            pages.insert (pages.index_of (src) + 1, p);
            return p;
        }

        public static void remap_ids (Gee.List<Item> items, Gee.Map<string, string> map) {
            foreach (var it in items) {
                if (map.has_key (it.id)) it.id = map[it.id];
                if (it.container_id != "" && map.has_key (it.container_id)) it.container_id = map[it.container_id];
                var c = it as Connector;
                if (c != null) {
                    if (c.src.item_id != "") c.src.item_id = map.has_key (c.src.item_id) ? map[c.src.item_id] : "";
                    if (c.dst.item_id != "") c.dst.item_id = map.has_key (c.dst.item_id) ? map[c.dst.item_id] : "";
                }
            }
        }

        public Gee.ArrayList<Item> clone_with_new_ids (Gee.List<Item> src) {
            var out_items = new Gee.ArrayList<Item> ();
            foreach (var it in src) out_items.add (it.clone ());
            var all = new Gee.ArrayList<Item> ();
            foreach (var it in out_items) {
                all.add (it);
                var g = it as Group;
                if (g != null) g.collect (all);
            }
            var map = new Gee.HashMap<string, string> ();
            foreach (var it in all) map[it.id] = new_id ();
            remap_ids (all, map);
            return out_items;
        }

        public void add_item (Item item, int index = -1) {
            if (item.id == "") item.id = new_id ();
            if (item.layer_id == "" || page.find_layer (item.layer_id) == null) item.layer_id = page.active_layer;
            var sh = item as Shape;
            if (sh != null) assign_container (sh);
            if (index < 0 || index > page.items.size) page.items.add (item);
            else page.items.insert (index, item);
        }

        public void assign_container (Shape s) {
            s.container_id = "";
            Shape? best = null;
            var b = s.bounds ();
            foreach (var it in page.items) {
                var c = it as Shape;
                if (c == null || c == s || !c.is_container () || c.rotation != 0) continue;
                if (c.w * c.h <= s.w * s.h) continue;
                if (c.box ().contains_rect (b) && (best == null || c.w * c.h < best.w * best.h)) best = c;
            }
            if (best != null) s.container_id = best.id;
        }

        public void delete_items (Gee.Collection<Item> sel) {
            var ids = new Gee.HashSet<string> ();
            foreach (var it in sel) {
                ids.add (it.id);
                var g = it as Group;
                if (g != null) {
                    var all = new Gee.ArrayList<Item> ();
                    g.collect (all);
                    foreach (var a in all) ids.add (a.id);
                }
            }
            foreach (var it in sel) page.remove (it);
            foreach (var c in page.connectors ()) {
                if (ids.contains (c.src.item_id)) {
                    c.src.item_id = "";
                    c.src.port = -1;
                }
                if (ids.contains (c.dst.item_id)) {
                    c.dst.item_id = "";
                    c.dst.port = -1;
                }
            }
            foreach (var it in page.all_items ()) if (ids.contains (it.container_id)) it.container_id = "";
        }

        public void move_items (Gee.Collection<Item> sel, double dx, double dy) {
            var moved = new Gee.HashSet<Item> ();
            foreach (var it in sel) {
                if (moved.contains (it)) continue;
                it.move_by (dx, dy);
                moved.add (it);
                var s = it as Shape;
                if (s != null && s.is_container ()) {
                    foreach (var m in members_recursive (s)) {
                        if (moved.contains (m) || sel.contains (m)) continue;
                        m.move_by (dx, dy);
                        moved.add (m);
                    }
                }
            }
            var ids = new Gee.HashSet<string> ();
            foreach (var it in moved) ids.add (it.id);
            foreach (var it in page.all_items ()) {
                var cs = it as Shape;
                if (cs != null && cs.callout_target != "" && ids.contains (cs.callout_target) && !moved.contains (cs)) {
                    cs.move_by (dx, dy);
                    moved.add (cs);
                }
            }
        }

        public Gee.ArrayList<Shape> members_recursive (Shape container) {
            var list = new Gee.ArrayList<Shape> ();
            var queue = new Gee.ArrayList<Shape> ();
            queue.add (container);
            while (queue.size > 0) {
                var c = queue.remove_at (0);
                foreach (var m in page.members_of (c)) {
                    if (list.contains (m) || m == container) continue;
                    list.add (m);
                    if (m.is_container ()) queue.add (m);
                }
            }
            return list;
        }

        public void reorder (Gee.Collection<Item> sel, int mode) {
            var list = page.items;
            var chosen = new Gee.ArrayList<Item> ();
            foreach (var it in list) if (sel.contains (it)) chosen.add (it);
            if (chosen.size == 0) return;
            switch (mode) {
                case 2:
                    foreach (var it in chosen) list.remove (it);
                    list.add_all (chosen);
                    break;
                case -2:
                    foreach (var it in chosen) list.remove (it);
                    list.insert_all (0, chosen);
                    break;
                case 1:
                    for (int i = list.size - 2; i >= 0; i--) {
                        if (chosen.contains (list[i]) && !chosen.contains (list[i + 1])) {
                            var tmp = list[i + 1];
                            list[i + 1] = list[i];
                            list[i] = tmp;
                        }
                    }
                    break;
                case -1:
                    for (int i = 1; i < list.size; i++) {
                        if (chosen.contains (list[i]) && !chosen.contains (list[i - 1])) {
                            var tmp = list[i - 1];
                            list[i - 1] = list[i];
                            list[i] = tmp;
                        }
                    }
                    break;
            }
        }

        public static Rect selection_bounds (Gee.Collection<Item> sel) {
            var r = Rect.empty ();
            foreach (var it in sel) r = r.union (it.bounds ());
            return r;
        }

        public void align (Gee.Collection<Item> sel, AlignKind kind, Rect? reference = null) {
            var movable = new Gee.ArrayList<Item> ();
            foreach (var it in sel) if (!(it is Connector)) movable.add (it);
            if (movable.size == 0) return;
            Rect r = reference ?? selection_bounds (movable);
            foreach (var it in movable) {
                var b = it.bounds ();
                double dx = 0, dy = 0;
                switch (kind) {
                    case AlignKind.LEFT: dx = r.x - b.x; break;
                    case AlignKind.CENTER: dx = r.cx () - b.cx (); break;
                    case AlignKind.RIGHT: dx = r.x2 () - b.x2 (); break;
                    case AlignKind.TOP: dy = r.y - b.y; break;
                    case AlignKind.MIDDLE: dy = r.cy () - b.cy (); break;
                    case AlignKind.BOTTOM: dy = r.y2 () - b.y2 (); break;
                }
                var one = new Gee.ArrayList<Item> ();
                one.add (it);
                move_items (one, dx, dy);
            }
        }

        public void distribute (Gee.Collection<Item> sel, bool horizontal) {
            var list = new Gee.ArrayList<Item> ();
            foreach (var it in sel) if (!(it is Connector)) list.add (it);
            if (list.size < 3) return;
            if (horizontal) list.sort ((a, b) => a.bounds ().cx () < b.bounds ().cx () ? -1 : (a.bounds ().cx () > b.bounds ().cx () ? 1 : 0));
            else list.sort ((a, b) => a.bounds ().cy () < b.bounds ().cy () ? -1 : (a.bounds ().cy () > b.bounds ().cy () ? 1 : 0));
            var first = list[0].bounds ();
            var last = list[list.size - 1].bounds ();
            double total = 0;
            foreach (var it in list) total += horizontal ? it.bounds ().w : it.bounds ().h;
            double span = horizontal ? last.x2 () - first.x : last.y2 () - first.y;
            double gap = (span - total) / (list.size - 1);
            double pos = horizontal ? first.x : first.y;
            foreach (var it in list) {
                var b = it.bounds ();
                var one = new Gee.ArrayList<Item> ();
                one.add (it);
                if (horizontal) {
                    move_items (one, pos - b.x, 0);
                    pos += b.w + gap;
                } else {
                    move_items (one, 0, pos - b.y);
                    pos += b.h + gap;
                }
            }
        }

        public void match_size (Gee.Collection<Item> sel, bool width, bool height, Shape reference) {
            foreach (var it in sel) {
                var s = it as Shape;
                if (s == null || s == reference) continue;
                double cx = s.cx (), cy = s.cy ();
                if (width) s.w = reference.w;
                if (height) s.h = reference.h;
                s.x = cx - s.w / 2;
                s.y = cy - s.h / 2;
            }
        }

        public Group? group (Gee.Collection<Item> sel) {
            var chosen = new Gee.ArrayList<Item> ();
            foreach (var it in page.items) if (sel.contains (it)) chosen.add (it);
            if (chosen.size < 2) return null;
            int index = page.items.index_of (chosen[chosen.size - 1]);
            var g = new Group ();
            g.id = new_id ("g");
            g.layer_id = chosen[0].layer_id;
            foreach (var it in chosen) {
                page.items.remove (it);
                g.children.add (it);
            }
            index = int.min (index - chosen.size + 1, page.items.size);
            page.items.insert (int.max (index, 0), g);
            return g;
        }

        public Gee.ArrayList<Item> ungroup (Gee.Collection<Item> sel) {
            var released = new Gee.ArrayList<Item> ();
            foreach (var it in sel) {
                var g = it as Group;
                if (g == null || !page.items.contains (g)) continue;
                int index = page.items.index_of (g);
                page.items.remove (g);
                foreach (var c in g.children) {
                    page.items.insert (index++, c);
                    released.add (c);
                }
            }
            return released;
        }

        public void rotate_items (Gee.Collection<Item> sel, double degrees) {
            var r = selection_bounds (sel);
            double cx = r.cx (), cy = r.cy ();
            foreach (var it in sel) rotate_item (it, degrees, cx, cy, sel.size > 1);
        }

        public void rotate_item (Item it, double degrees, double cx, double cy, bool around) {
            var g = it as Group;
            if (g != null) {
                foreach (var c in g.children) rotate_item (c, degrees, cx, cy, true);
                return;
            }
            var s = it as Shape;
            if (s != null) {
                if (around) {
                    double a = degrees * Math.PI / 180;
                    double ox = s.cx () - cx, oy = s.cy () - cy;
                    double nx = cx + ox * Math.cos (a) - oy * Math.sin (a);
                    double ny = cy + ox * Math.sin (a) + oy * Math.cos (a);
                    s.x = nx - s.w / 2;
                    s.y = ny - s.h / 2;
                }
                s.rotation = normalize_angle (s.rotation + degrees);
                return;
            }
            var c = it as Connector;
            if (c != null && around) {
                double a = degrees * Math.PI / 180;
                if (!c.src.attached ()) rotate_point (ref c.src.x, ref c.src.y, cx, cy, a);
                if (!c.dst.attached ()) rotate_point (ref c.dst.x, ref c.dst.y, cx, cy, a);
                for (int i = 0; i < c.waypoints.length; i++) rotate_point (ref c.waypoints[i].x, ref c.waypoints[i].y, cx, cy, a);
            }
        }

        private static void rotate_point (ref double x, ref double y, double cx, double cy, double a) {
            double ox = x - cx, oy = y - cy;
            x = cx + ox * Math.cos (a) - oy * Math.sin (a);
            y = cy + ox * Math.sin (a) + oy * Math.cos (a);
        }

        public static double normalize_angle (double a) {
            a = Math.fmod (a, 360);
            if (a < 0) a += 360;
            if ((a - 360).abs () < 1e-9) a = 0;
            return a;
        }

        public void flip_items (Gee.Collection<Item> sel, bool horizontal) {
            var r = selection_bounds (sel);
            foreach (var it in sel) flip_item (it, horizontal, r, sel.size > 1);
        }

        private void flip_item (Item it, bool horizontal, Rect r, bool around) {
            var g = it as Group;
            if (g != null) {
                foreach (var c in g.children) flip_item (c, horizontal, r, true);
                return;
            }
            var s = it as Shape;
            if (s != null) {
                if (around) {
                    if (horizontal) s.x = r.x + r.x2 () - s.x - s.w;
                    else s.y = r.y + r.y2 () - s.y - s.h;
                }
                if (horizontal) s.flip_h = !s.flip_h;
                else s.flip_v = !s.flip_v;
                if (s.rotation != 0) s.rotation = normalize_angle (-s.rotation);
                return;
            }
            var c = it as Connector;
            if (c != null) {
                if (!c.src.attached ()) {
                    if (horizontal) c.src.x = r.x + r.x2 () - c.src.x;
                    else c.src.y = r.y + r.y2 () - c.src.y;
                }
                if (!c.dst.attached ()) {
                    if (horizontal) c.dst.x = r.x + r.x2 () - c.dst.x;
                    else c.dst.y = r.y + r.y2 () - c.dst.y;
                }
                for (int i = 0; i < c.waypoints.length; i++) {
                    if (horizontal) c.waypoints[i].x = r.x + r.x2 () - c.waypoints[i].x;
                    else c.waypoints[i].y = r.y + r.y2 () - c.waypoints[i].y;
                }
            }
        }

        public void scale_items (Gee.Collection<Item> sel, Rect from, Rect to) {
            double sx = from.w > 1e-6 ? to.w / from.w : 1;
            double sy = from.h > 1e-6 ? to.h / from.h : 1;
            foreach (var it in sel) scale_item (it, from, to, sx, sy);
        }

        public static void scale_item (Item it, Rect from, Rect to, double sx, double sy) {
            var g = it as Group;
            if (g != null) {
                foreach (var c in g.children) scale_item (c, from, to, sx, sy);
                return;
            }
            var s = it as Shape;
            if (s != null) {
                double ncx = to.x + (s.cx () - from.x) * sx;
                double ncy = to.y + (s.cy () - from.y) * sy;
                bool swap = rotated_quarter (s.rotation);
                double nw = s.w * (swap ? sy : sx), nh = s.h * (swap ? sx : sy);
                s.w = nw.abs ();
                s.h = nh.abs ();
                s.x = ncx - s.w / 2;
                s.y = ncy - s.h / 2;
                return;
            }
            var c = it as Connector;
            if (c != null) {
                if (!c.src.attached ()) {
                    c.src.x = to.x + (c.src.x - from.x) * sx;
                    c.src.y = to.y + (c.src.y - from.y) * sy;
                }
                if (!c.dst.attached ()) {
                    c.dst.x = to.x + (c.dst.x - from.x) * sx;
                    c.dst.y = to.y + (c.dst.y - from.y) * sy;
                }
                for (int i = 0; i < c.waypoints.length; i++) {
                    c.waypoints[i].x = to.x + (c.waypoints[i].x - from.x) * sx;
                    c.waypoints[i].y = to.y + (c.waypoints[i].y - from.y) * sy;
                }
            }
        }

        private static bool rotated_quarter (double r) {
            double m = Math.fmod (normalize_angle (r), 180);
            return (m - 90).abs () < 45;
        }

        public Gee.ArrayList<Item> find_text (string needle, bool case_sensitive, bool all_pages, out Gee.ArrayList<Page> in_pages) {
            var result = new Gee.ArrayList<Item> ();
            in_pages = new Gee.ArrayList<Page> ();
            if (needle == "") return result;
            string n = case_sensitive ? needle : needle.casefold ();
            var list = all_pages ? pages : new Gee.ArrayList<Page>.wrap ({ page });
            foreach (var p in list) {
                foreach (var it in p.all_items ()) {
                    bool hit = false;
                    string t = case_sensitive ? it.display_text () : it.display_text ().casefold ();
                    if (t.contains (n)) hit = true;
                    var tb = it as TableShape;
                    if (!hit && tb != null) {
                        foreach (string cell in tb.cells) {
                            if ((case_sensitive ? cell : cell.casefold ()).contains (n)) hit = true;
                        }
                    }
                    if (!hit) {
                        foreach (var f in it.fields) {
                            if ((case_sensitive ? f.value : f.value.casefold ()).contains (n)) hit = true;
                        }
                    }
                    if (hit) {
                        result.add (it);
                        in_pages.add (p);
                    }
                }
            }
            return result;
        }

        public int replace_text (string needle, string replacement, bool case_sensitive, bool all_pages) {
            if (needle == "") return 0;
            int count = 0;
            var list = all_pages ? pages : new Gee.ArrayList<Page>.wrap ({ page });
            foreach (var p in list) {
                foreach (var it in p.all_items ()) {
                    int n;
                    it.text = replace_in (it.text, needle, replacement, case_sensitive, out n);
                    count += n;
                    var tb = it as TableShape;
                    if (tb != null) {
                        for (int i = 0; i < tb.cells.size; i++) {
                            tb.cells[i] = replace_in (tb.cells[i], needle, replacement, case_sensitive, out n);
                            count += n;
                        }
                    }
                }
            }
            return count;
        }

        public static string replace_in (string text, string needle, string replacement, bool case_sensitive, out int count) {
            count = 0;
            if (needle == "") return text;
            var sb = new StringBuilder ();
            string hay = case_sensitive ? text : text.down ();
            string nd = case_sensitive ? needle : needle.down ();
            int i = 0;
            while (true) {
                int j = hay.index_of (nd, i);
                if (j < 0 || hay.length != text.length) {
                    if (j >= 0 && hay.length != text.length) {
                        string r = text.replace (needle, replacement);
                        count = r != text ? 1 : 0;
                        return r;
                    }
                    break;
                }
                sb.append (text.substring (i, j - i));
                sb.append (replacement);
                i = j + nd.length;
                count++;
            }
            sb.append (text.substring (i));
            return sb.str;
        }

        public Theme? theme () {
            if (theme_id == "") return null;
            if (theme_id == "file" && custom_theme != null) return theme_variant > 0 ? custom_theme.variant (theme_variant) : custom_theme;
            return Theme.find (theme_id, theme_variant);
        }

        public Page? find_page (string id) {
            foreach (var p in pages) if (p.id == id) return p;
            return null;
        }

        public Page? background_of (Page p) {
            if (p.back_page == "") return null;
            var bg = find_page (p.back_page);
            if (bg == null || bg == p) return null;
            return bg;
        }

        public void link_backgrounds () {
            foreach (var p in pages) {
                p.back_ref = background_of (p);
                p.graphics_ref = data_graphics;
            }
        }

        public Gee.ArrayList<Page> foreground_pages () {
            var list = new Gee.ArrayList<Page> ();
            foreach (var p in pages) if (!p.is_background) list.add (p);
            return list;
        }

        public DataSource? find_source (string id) {
            foreach (var d in data_sources) if (d.id == id) return d;
            return null;
        }

        public DataGraphic? find_graphic (string id) {
            foreach (var g in data_graphics) if (g.id == id) return g;
            return null;
        }

        public bool split_connector (Shape s, double tolerance) {
            if (s.is_container () || page.connectors_of (s.id).size > 0) return false;
            Connector? hit = null;
            foreach (var c in page.connectors ()) {
                if (c.src.item_id == s.id || c.dst.item_id == s.id) continue;
                if (c.path ().distance_to (s.cx (), s.cy ()) <= tolerance) {
                    hit = c;
                    break;
                }
            }
            if (hit == null) return false;
            var second = (Connector) hit.clone ();
            second.id = new_id ();
            second.text = "";
            second.waypoints = {};
            second.src = new Endpoint ();
            second.src.item_id = s.id;
            second.dst = hit.dst.copy ();
            hit.dst = new Endpoint ();
            hit.dst.item_id = s.id;
            hit.waypoints = {};
            var list = page.list_of (hit);
            int index = list.index_of (hit);
            second.layer_id = hit.layer_id;
            list.insert (index >= 0 ? index + 1 : list.size, second);
            return true;
        }

        public void mark_saved (string p) {
            path = p;
            modified = false;
        }
    }
}
