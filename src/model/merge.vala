namespace Singularity.Apps.Draw {

    public class MergeResult {
        public int added = 0;
        public int changed = 0;
        public int removed = 0;
        public int pages = 0;
        public int comments = 0;
        public Gee.HashSet<string> changed_ids = new Gee.HashSet<string> ();
        public Gee.HashSet<string> added_ids = new Gee.HashSet<string> ();

        public int total () {
            return added + changed + pages + comments;
        }
    }

    public class DrawingMerge {
        private static string signature (Item it) {
            var list = new Gee.ArrayList<Item> ();
            list.add (it);
            return NativeFormat.serialize_items (list);
        }

        private static Page? match_page (Document doc, Page p) {
            foreach (var q in doc.pages) if (q.id == p.id) return q;
            foreach (var q in doc.pages) if (q.name == p.name) return q;
            return null;
        }

        public static MergeResult compare (Document ours, Document theirs) {
            var r = new MergeResult ();
            foreach (var tp in theirs.pages) {
                var op = match_page (ours, tp);
                if (op == null) {
                    r.pages++;
                    continue;
                }
                foreach (var it in tp.items) {
                    var mine = op.find (it.id);
                    if (mine == null) {
                        r.added++;
                        r.added_ids.add (it.id);
                    } else if (signature (mine) != signature (it)) {
                        r.changed++;
                        r.changed_ids.add (it.id);
                    }
                }
                foreach (var it in op.items) if (tp.find (it.id) == null) r.removed++;
                foreach (var c in tp.comments) {
                    bool found = false;
                    foreach (var oc in op.comments) if (oc.id == c.id) found = true;
                    if (!found) r.comments++;
                }
            }
            return r;
        }

        public static void apply (Document ours, Document theirs, MergeResult r) {
            foreach (var tp in theirs.pages) {
                var op = match_page (ours, tp);
                if (op == null) {
                    var np = tp.clone ();
                    if (ours.find_page (np.id) != null) np.id = ours.new_page_id ();
                    ours.pages.add (np);
                    continue;
                }
                for (int i = 0; i < tp.items.size; i++) {
                    var it = tp.items[i];
                    if (r.added_ids.contains (it.id)) {
                        op.items.insert (int.min (i, op.items.size), it.clone ());
                    } else if (r.changed_ids.contains (it.id)) {
                        var mine = op.find (it.id);
                        var list = op.list_of (mine);
                        int idx = list.index_of (mine);
                        if (idx >= 0) list[idx] = it.clone ();
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
                            if (!have) oc.replies.add (rep.copy ());
                        }
                    }
                    if (!found) op.comments.add (c.copy ());
                }
            }
            ours.sync_ids ();
        }
    }
}
