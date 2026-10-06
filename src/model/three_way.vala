namespace Singularity.Apps.Draw {

    public enum ConflictPolicy {
        KEEP_LOCAL,
        TAKE_REMOTE,
        KEEP_BOTH
    }

    public class SyncConflict {
        public string page;
        public string item_id;
        public string label;

        public SyncConflict (string page, string item_id, string label) {
            this.page = page;
            this.item_id = item_id;
            this.label = label;
        }
    }

    public class SyncReport {
        public int added = 0;
        public int changed = 0;
        public int removed = 0;
        public int pages = 0;
        public int comments = 0;
        public bool remote_changed = false;
        public bool uploaded = false;
        public Gee.ArrayList<SyncConflict> conflicts = new Gee.ArrayList<SyncConflict> ();

        public int pulled () {
            return added + changed + removed + pages + comments;
        }
    }

    public class ThreeWayMerge {
        private static string sig (Item? it) {
            if (it == null) return "";
            var list = new Gee.ArrayList<Item> ();
            list.add (it);
            return NativeFormat.serialize_items (list);
        }

        private static string page_sig (Page p) {
            return "%s|%s|%s|%s|%d".printf (p.name, PathData.fmt (p.width, 3), PathData.fmt (p.height, 3), p.background, (int) p.is_background);
        }

        private static Page? find_page (Document d, string id) {
            foreach (var p in d.pages) if (p.id == id) return p;
            return null;
        }

        private static string label_of (Item it) {
            string t = it.display_text ().strip ();
            if (t != "") return t.length > 40 ? t.substring (0, t.index_of_nth_char (40)) : t;
            if (it.name != "") return it.name;
            var s = it as Shape;
            return s != null ? s.kind : it.id;
        }

        public static SyncReport merge (Document? base_doc, Document ours, Document theirs, ConflictPolicy policy) {
            var r = new SyncReport ();
            var base_eff = base_doc ?? new Document ();
            if (base_doc == null) base_eff.pages.clear ();
            foreach (var tp in theirs.pages) {
                var op = find_page (ours, tp.id);
                var bp = find_page (base_eff, tp.id);
                if (op == null) {
                    if (bp == null) {
                        ours.pages.add (tp.clone ());
                        r.pages++;
                    } else if (bp != null && page_sig (bp) != page_sig (tp)) {
                        if (policy != ConflictPolicy.KEEP_LOCAL) {
                            ours.pages.add (tp.clone ());
                            r.pages++;
                        }
                        r.conflicts.add (new SyncConflict (tp.name, "", tp.name));
                    }
                    continue;
                }
                merge_page (bp, op, tp, policy, r);
            }
            var drop = new Gee.ArrayList<Page> ();
            foreach (var op in ours.pages) {
                if (find_page (theirs, op.id) != null) continue;
                var bp = find_page (base_eff, op.id);
                if (bp == null) continue;
                bool untouched = page_sig (bp) == page_sig (op) && bp.items.size == op.items.size;
                if (untouched) foreach (var it in op.items) if (sig (it) != sig (bp.find (it.id))) untouched = false;
                if (untouched && ours.pages.size - drop.size > 1) {
                    drop.add (op);
                    r.pages++;
                } else if (!untouched) {
                    r.conflicts.add (new SyncConflict (op.name, "", op.name));
                }
            }
            foreach (var p in drop) ours.pages.remove (p);
            if (ours.page_index >= ours.pages.size) ours.page_index = 0;
            ours.sync_ids ();
            return r;
        }

        private static void merge_page (Page? bp, Page op, Page tp, ConflictPolicy policy, SyncReport r) {
            if (bp != null && page_sig (bp) == page_sig (op) && page_sig (bp) != page_sig (tp)) {
                op.name = tp.name;
                op.width = tp.width;
                op.height = tp.height;
                op.background = tp.background;
                r.changed++;
            }
            var ids = new Gee.ArrayList<string> ();
            foreach (var it in tp.items) ids.add (it.id);
            foreach (var it in op.items) if (!ids.contains (it.id)) ids.add (it.id);
            if (bp != null) foreach (var it in bp.items) if (!ids.contains (it.id)) ids.add (it.id);
            foreach (string id in ids) {
                Item? b = bp != null ? find_top (bp, id) : null;
                Item? o = find_top (op, id);
                Item? t = find_top (tp, id);
                string sb = sig (b), so = sig (o), st = sig (t);
                if (so == st) continue;
                if (sb == so) {
                    apply_theirs (op, tp, o, t, r);
                    continue;
                }
                if (sb == st) continue;
                var any = o ?? t;
                r.conflicts.add (new SyncConflict (op.name, id, label_of (any)));
                switch (policy) {
                    case ConflictPolicy.TAKE_REMOTE:
                        apply_theirs (op, tp, o, t, r);
                        break;
                    case ConflictPolicy.KEEP_BOTH:
                        if (o == null && t != null) {
                            apply_theirs (op, tp, o, t, r);
                        } else if (o != null && t != null) {
                            var copy = t.clone ();
                            copy.id = id + "-online";
                            int n = 2;
                            while (op.find (copy.id) != null) copy.id = "%s-online%d".printf (id, n++);
                            copy.move_by (24, 24);
                            if (copy.name == "") copy.name = _("Online version");
                            op.items.add (copy);
                            r.added++;
                        }
                        break;
                    default:
                        break;
                }
            }
            foreach (var c in tp.comments) {
                bool found = false;
                foreach (var oc in op.comments) {
                    if (oc.id != c.id) continue;
                    found = true;
                    foreach (var rep in c.replies) {
                        bool have = false;
                        foreach (var orep in oc.replies) if (orep.id == rep.id) have = true;
                        if (!have) {
                            oc.replies.add (rep.copy ());
                            r.comments++;
                        }
                    }
                }
                if (found) continue;
                bool was_deleted = false;
                if (bp != null) foreach (var bc in bp.comments) if (bc.id == c.id) was_deleted = true;
                if (!was_deleted) {
                    op.comments.add (c.copy ());
                    r.comments++;
                }
            }
        }

        private static Item? find_top (Page p, string id) {
            foreach (var it in p.items) if (it.id == id) return it;
            return null;
        }

        private static void apply_theirs (Page op, Page tp, Item? o, Item? t, SyncReport r) {
            if (t == null) {
                if (o != null) {
                    op.items.remove (o);
                    r.removed++;
                }
                return;
            }
            if (o != null) {
                int idx = op.items.index_of (o);
                op.items[idx] = t.clone ();
                r.changed++;
                return;
            }
            int ti = tp.items.index_of (t);
            int at = op.items.size;
            for (int i = ti + 1; i < tp.items.size; i++) {
                var next = find_top (op, tp.items[i].id);
                if (next != null) {
                    at = op.items.index_of (next);
                    break;
                }
            }
            op.items.insert (at, t.clone ());
            r.added++;
        }
    }
}
