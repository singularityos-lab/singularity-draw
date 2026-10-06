namespace Singularity.Apps.Draw {

    public class Swimlanes {
        public const double HEADER = 30;
        public const double PHASE_HEADER = 26;

        public static bool is_pool (Shape s) {
            return s.kind == "pool" || s.kind == "pool-v" || s.kind == "bpmn-pool";
        }

        public static bool is_lane (Shape s) {
            return s.kind == "swimlane-h" || s.kind == "swimlane-v";
        }

        public static bool is_phase (Shape s) {
            return s.kind == "cff-phase" || s.kind == "cff-phase-h";
        }

        public static bool vertical (Shape pool) {
            return pool.kind == "pool-v";
        }

        public static Shape? pool_for (Page page, Shape s) {
            if (is_pool (s)) return s;
            if (s.container_id == "") return null;
            var c = page.find (s.container_id) as Shape;
            if (c == null) return null;
            if (is_pool (c)) return c;
            if (is_lane (c)) return pool_for (page, c);
            return null;
        }

        public static Gee.ArrayList<Shape> lanes (Page page, Shape pool) {
            var list = new Gee.ArrayList<Shape> ();
            foreach (var m in page.members_of (pool)) if (is_lane (m)) list.add (m);
            bool v = vertical (pool);
            list.sort ((a, b) => {
                double da = v ? a.x : a.y, db = v ? b.x : b.y;
                return da < db ? -1 : (da > db ? 1 : 0);
            });
            return list;
        }

        public static Gee.ArrayList<Shape> phases (Page page, Shape pool) {
            var list = new Gee.ArrayList<Shape> ();
            foreach (var m in page.members_of (pool)) if (is_phase (m)) list.add (m);
            bool v = vertical (pool);
            list.sort ((a, b) => {
                double da = v ? a.y : a.x, db = v ? b.y : b.x;
                return da < db ? -1 : (da > db ? 1 : 0);
            });
            return list;
        }

        private static Gee.ArrayList<Item> contents (Document doc, Shape container) {
            var list = new Gee.ArrayList<Item> ();
            foreach (var m in doc.members_recursive (container)) list.add (m);
            return list;
        }

        private static double lane_offset (Page page, Shape pool) {
            return phases (page, pool).size > 0 ? PHASE_HEADER : 0;
        }

        public static Shape make_lane (Document doc, Shape pool, string title) {
            bool v = vertical (pool);
            var lane = new Shape (v ? "swimlane-v" : "swimlane-h");
            ShapeLibrary.apply_defaults (lane);
            lane.style.bold = false;
            lane.style.fill = pool.style.fill;
            lane.text = title;
            lane.layer_id = pool.layer_id;
            Theme.style_new_item (doc, lane);
            if (lane.style.quick_color >= 0) lane.style.quick_style = QuickStyle.SUBTLE;
            return lane;
        }

        public static Shape insert (Document doc, double x, double y, bool vertical_layout, int count, string pool_title) {
            var pool = new Shape (vertical_layout ? "pool-v" : "pool");
            ShapeLibrary.apply_defaults (pool);
            pool.text = pool_title;
            double lane = vertical_layout ? 220 : 150;
            if (vertical_layout) {
                pool.set_bounds (Rect (x, y, lane * count, 520));
            } else {
                pool.set_bounds (Rect (x, y, 900, HEADER * 0 + lane * count));
            }
            doc.add_item (pool);
            Theme.style_new_item (doc, pool);
            if (pool.style.quick_color >= 0) pool.style.quick_style = QuickStyle.SUBTLE;
            for (int i = 0; i < count; i++) {
                var l = make_lane (doc, pool, _("Function %d").printf (i + 1));
                if (vertical_layout) l.set_bounds (Rect (x + i * lane, y + HEADER, lane, pool.h - HEADER));
                else l.set_bounds (Rect (x + HEADER, y + i * lane, pool.w - HEADER, lane));
                doc.add_item (l);
                l.container_id = pool.id;
            }
            return pool;
        }

        public static Shape add_lane (Document doc, Shape pool, int index, string title) {
            var page = doc.page;
            var ls = lanes (page, pool);
            bool v = vertical (pool);
            double size = v ? 220 : 150;
            if (ls.size > 0) {
                double sum = 0;
                foreach (var l in ls) sum += v ? l.w : l.h;
                size = sum / ls.size;
            }
            index = index.clamp (0, ls.size);
            double off = lane_offset (page, pool);
            double pos;
            if (ls.size == 0) pos = v ? pool.x : pool.y + off;
            else if (index >= ls.size) pos = v ? ls[ls.size - 1].x + ls[ls.size - 1].w : ls[ls.size - 1].y + ls[ls.size - 1].h;
            else pos = v ? ls[index].x : ls[index].y;
            for (int i = index; i < ls.size; i++) {
                var moved = new Gee.ArrayList<Item> ();
                moved.add (ls[i]);
                if (v) doc.move_items (moved, size, 0);
                else doc.move_items (moved, 0, size);
            }
            var lane = make_lane (doc, pool, title);
            if (v) lane.set_bounds (Rect (pos, pool.y + HEADER + off, size, pool.h - HEADER - off));
            else lane.set_bounds (Rect (pool.x + HEADER, pos, pool.w - HEADER, size));
            int zi = ls.size > 0 ? doc.page.items.index_of (ls[ls.size - 1]) + 1 : doc.page.items.index_of (pool) + 1;
            doc.add_item (lane, zi);
            lane.container_id = pool.id;
            fit_pool (page, pool);
            return lane;
        }

        public static void fit_pool (Page page, Shape pool) {
            var ls = lanes (page, pool);
            bool v = vertical (pool);
            double off = lane_offset (page, pool);
            if (ls.size > 0) {
                var last = ls[ls.size - 1];
                if (v) {
                    pool.w = double.max (last.x + last.w - pool.x, 60);
                    foreach (var l in ls) {
                        l.y = pool.y + HEADER + off;
                        l.h = pool.h - HEADER - off;
                    }
                } else {
                    pool.h = double.max (last.y + last.h - pool.y, 60);
                    foreach (var l in ls) {
                        l.x = pool.x + HEADER;
                        l.w = pool.w - HEADER;
                    }
                }
            }
            foreach (var ph in phases (page, pool)) {
                if (v) {
                    ph.x = pool.x;
                    ph.w = pool.w;
                } else {
                    ph.y = pool.y;
                    ph.h = pool.h;
                }
            }
        }

        public static void remove_lane (Document doc, Shape lane) {
            var page = doc.page;
            var pool = pool_for (page, lane);
            if (pool == null) return;
            bool v = vertical (pool);
            var ls = lanes (page, pool);
            int index = ls.index_of (lane);
            double size = v ? lane.w : lane.h;
            var doomed = new Gee.ArrayList<Item> ();
            doomed.add (lane);
            doomed.add_all (contents (doc, lane));
            doc.delete_items (doomed);
            for (int i = index + 1; i < ls.size; i++) {
                var moved = new Gee.ArrayList<Item> ();
                moved.add (ls[i]);
                if (v) doc.move_items (moved, -size, 0);
                else doc.move_items (moved, 0, -size);
            }
            if (v) pool.w -= size;
            else pool.h -= size;
            fit_pool (page, pool);
        }

        public static bool move_lane (Document doc, Shape lane, int delta) {
            var page = doc.page;
            var pool = pool_for (page, lane);
            if (pool == null) return false;
            bool v = vertical (pool);
            var ls = lanes (page, pool);
            int i = ls.index_of (lane);
            int j = i + delta;
            if (i < 0 || j < 0 || j >= ls.size) return false;
            var other = ls[j];
            var a = new Gee.ArrayList<Item> ();
            a.add (lane);
            var b = new Gee.ArrayList<Item> ();
            b.add (other);
            double sa = v ? lane.w : lane.h, sb = v ? other.w : other.h;
            if (delta > 0) {
                if (v) {
                    doc.move_items (a, sb, 0);
                    doc.move_items (b, -sa, 0);
                } else {
                    doc.move_items (a, 0, sb);
                    doc.move_items (b, 0, -sa);
                }
            } else {
                if (v) {
                    doc.move_items (a, -sb, 0);
                    doc.move_items (b, sa, 0);
                } else {
                    doc.move_items (a, 0, -sb);
                    doc.move_items (b, 0, sa);
                }
            }
            return true;
        }

        public static Shape add_phase (Document doc, Shape pool, string title) {
            var page = doc.page;
            bool v = vertical (pool);
            var ps = phases (page, pool);
            if (ps.size == 0) {
                var ls = lanes (page, pool);
                foreach (var l in ls) {
                    if (v) {
                        l.y += PHASE_HEADER;
                        l.h -= PHASE_HEADER;
                    } else {
                        var moved = new Gee.ArrayList<Item> ();
                        moved.add (l);
                        doc.move_items (moved, 0, PHASE_HEADER);
                    }
                }
                if (!v) pool.h += PHASE_HEADER;
                var first = new Shape (v ? "cff-phase-h" : "cff-phase");
                ShapeLibrary.apply_defaults (first);
                first.text = _("Phase 1");
                if (v) first.set_bounds (Rect (pool.x, pool.y + HEADER, pool.w, pool.h - HEADER));
                else first.set_bounds (Rect (pool.x + HEADER, pool.y, pool.w - HEADER, pool.h));
                doc.add_item (first);
                first.container_id = pool.id;
                ps.add (first);
            }
            double size = v ? 200 : 300;
            var last = ps[ps.size - 1];
            var ph = new Shape (v ? "cff-phase-h" : "cff-phase");
            ShapeLibrary.apply_defaults (ph);
            ph.text = title;
            if (v) {
                ph.set_bounds (Rect (pool.x, last.y + last.h, pool.w, size));
                pool.h += size;
                foreach (var l in lanes (page, pool)) l.h += size;
            } else {
                ph.set_bounds (Rect (last.x + last.w, pool.y, size, pool.h));
                pool.w += size;
                foreach (var l in lanes (page, pool)) l.w += size;
            }
            doc.add_item (ph);
            ph.container_id = pool.id;
            fit_pool (page, pool);
            return ph;
        }

        public static void set_orientation (Document doc, Shape pool, bool to_vertical) {
            if (vertical (pool) == to_vertical) return;
            var page = doc.page;
            double ox = pool.x, oy = pool.y;
            var members = doc.members_recursive (pool);
            foreach (var m in members) {
                double rx = m.cx () - ox, ry = m.cy () - oy;
                if (is_lane (m) || is_phase (m)) {
                    double w = m.w;
                    m.w = m.h;
                    m.h = w;
                    if (is_lane (m)) m.kind = to_vertical ? "swimlane-v" : "swimlane-h";
                    else m.kind = to_vertical ? "cff-phase-h" : "cff-phase";
                }
                m.x = ox + ry - m.w / 2;
                m.y = oy + rx - m.h / 2;
            }
            double pw = pool.w;
            pool.w = pool.h;
            pool.h = pw;
            pool.kind = to_vertical ? "pool-v" : "pool";
            fit_pool (page, pool);
        }
    }
}
