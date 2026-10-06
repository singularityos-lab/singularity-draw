namespace Singularity.Apps.Draw {

    public class LiveStamp {
        public int64 clock;
        public string peer;

        public LiveStamp (int64 clock, string peer) {
            this.clock = clock;
            this.peer = peer;
        }

        public bool newer_than (int64 c, string p) {
            return clock > c || (clock == c && strcmp (peer, p) > 0);
        }
    }

    public class DrawLiveSync : Object {
        public signal void outgoing (Json.Object message);
        public signal void applied ();

        public Document doc;
        public string peer;
        public int64 clock = 0;
        public int conflicts_lost = 0;
        private Gee.HashMap<string, string> state;
        private Gee.HashMap<string, LiveStamp> stamps = new Gee.HashMap<string, LiveStamp> ();
        private Gee.ArrayList<Json.Object> queued = new Gee.ArrayList<Json.Object> ();
        private bool applying = false;
        private ulong handler = 0;

        public DrawLiveSync (Document doc, string peer) {
            this.doc = doc;
            this.peer = peer;
            state = keys_of (doc);
            handler = doc.changed.connect (on_changed);
        }

        public void detach () {
            if (handler != 0) doc.disconnect (handler);
            handler = 0;
        }

        public static string item_key (string page, string item) {
            return "item/%s/%s".printf (page, item);
        }

        private static string join_ids (Gee.Iterable<string> ids) {
            var sb = new StringBuilder ();
            foreach (string id in ids) {
                if (sb.len > 0) sb.append_c ('\n');
                sb.append (id);
            }
            return sb.str;
        }

        public static string header_of (Document d) {
            var t = new Document ();
            t.pages.clear ();
            t.grid_size = d.grid_size;
            t.units = d.units;
            t.title = d.title;
            t.theme_id = d.theme_id;
            t.theme_variant = d.theme_variant;
            t.validation_rules = d.validation_rules;
            t.custom_theme = d.custom_theme;
            t.ignored_issues.add_all (d.ignored_issues);
            t.data_sources.add_all (d.data_sources);
            t.data_graphics.add_all (d.data_graphics);
            t.page_index = 0;
            return NativeFormat.serialize_document (t);
        }

        public static string page_header_of (Page p) {
            var keep = p.items;
            p.items = new Gee.ArrayList<Item> ();
            var w = new XmlWriter (true);
            w.start ("sdraw").attr ("xmlns", NativeFormat.NS).attr ("version", "1");
            NativeFormat.write_page (w, p);
            string s = w.finish ();
            p.items = keep;
            return s;
        }

        public static void add_page_keys (Gee.Map<string, string> map, Page p) {
            map["page/" + p.id] = page_header_of (p);
            var ids = new Gee.ArrayList<string> ();
            foreach (var it in p.items) {
                ids.add (it.id);
                var one = new Gee.ArrayList<Item> ();
                one.add (it);
                map[item_key (p.id, it.id)] = NativeFormat.serialize_items (one);
            }
            map["order/" + p.id] = join_ids (ids);
        }

        public static Gee.HashMap<string, string> keys_of (Document d) {
            var map = new Gee.HashMap<string, string> ();
            map["doc"] = header_of (d);
            var ids = new Gee.ArrayList<string> ();
            foreach (var p in d.pages) {
                ids.add (p.id);
                add_page_keys (map, p);
            }
            map["pages"] = join_ids (ids);
            return map;
        }

        public Json.Object snapshot () {
            var o = new Json.Object ();
            o.set_int_member ("clock", clock);
            var st = new Json.Object ();
            foreach (var e in state.entries) st.set_string_member (e.key, e.value);
            o.set_object_member ("state", st);
            var sp = new Json.Object ();
            foreach (var e in stamps.entries) {
                var a = new Json.Array ();
                a.add_int_element (e.value.clock);
                a.add_string_element (e.value.peer);
                sp.set_array_member (e.key, a);
            }
            o.set_object_member ("stamps", sp);
            o.set_string_member ("format", "sdraw-live-1");
            return o;
        }

        public void load_stamps (Json.Object st) {
            if (st.has_member ("clock")) clock = int64.max (clock, st.get_int_member ("clock"));
            if (!st.has_member ("stamps")) return;
            var sp = st.get_object_member ("stamps");
            foreach (string k in sp.get_members ()) {
                var a = sp.get_array_member (k);
                if (a.get_length () == 2) stamps[k] = new LiveStamp (a.get_int_element (0), a.get_string_element (1));
            }
        }

        public static Gee.HashMap<string, string> map_from (Json.Object st) {
            var map = new Gee.HashMap<string, string> ();
            if (!st.has_member ("state")) return map;
            var o = st.get_object_member ("state");
            foreach (string k in o.get_members ()) map[k] = o.get_string_member (k);
            return map;
        }

        public static Document document_from (Json.Object st) throws Error {
            var map = map_from (st);
            if (!map.has_key ("doc") || !map.has_key ("pages")) throw new FormatError.INVALID (_("The live drawing is not complete."));
            var d = NativeFormat.parse_document (map["doc"]);
            d.pages.clear ();
            var changed = new Gee.HashSet<string> ();
            changed.add_all (map.keys);
            materialize (d, d.pages, map, changed, true);
            d.page_index = 0;
            d.ensure_ids ();
            d.sync_ids ();
            d.clear_history ();
            d.modified = false;
            return d;
        }

        private static Page? parse_page_header (string xml) {
            try {
                var hd = NativeFormat.parse_document (xml);
                return hd.pages.size > 0 ? hd.pages[0] : null;
            } catch (Error e) {
                return null;
            }
        }

        private static Item? parse_item (string xml) {
            try {
                var list = NativeFormat.parse_items (xml);
                return list.size > 0 ? list[0] : null;
            } catch (Error e) {
                return null;
            }
        }

        private static string[] split_ids (string? s) {
            string[] out_ids = {};
            if (s == null) return out_ids;
            foreach (string id in s.split ("\n")) if (id != "") out_ids += id;
            return out_ids;
        }

        public static void materialize (Document? header_target, Gee.ArrayList<Page> pages, Gee.Map<string, string> map, Gee.Set<string> changed, bool all) {
            if (header_target != null && changed.contains ("doc") && map.has_key ("doc")) {
                try {
                    var hd = NativeFormat.parse_document (map["doc"]);
                    header_target.grid_size = hd.grid_size;
                    header_target.units = hd.units;
                    header_target.title = hd.title;
                    header_target.theme_id = hd.theme_id;
                    header_target.theme_variant = hd.theme_variant;
                    header_target.validation_rules = hd.validation_rules;
                    header_target.custom_theme = hd.custom_theme;
                    header_target.ignored_issues.clear ();
                    header_target.ignored_issues.add_all (hd.ignored_issues);
                    header_target.data_sources.clear ();
                    header_target.data_sources.add_all (hd.data_sources);
                    header_target.data_graphics.clear ();
                    header_target.data_graphics.add_all (hd.data_graphics);
                } catch (Error e) {
                    warning ("draw live: %s", e.message);
                }
            }
            var existing = new Gee.HashMap<string, Page> ();
            foreach (var p in pages) existing[p.id] = p;
            string[] order = map.has_key ("pages") ? split_ids (map["pages"]) : new string[0];
            if (order.length == 0) foreach (var p in pages) order += p.id;
            var result = new Gee.ArrayList<Page> ();
            foreach (string pid in order) {
                if (!map.has_key ("page/" + pid) && !existing.has_key (pid)) continue;
                Page? page = existing[pid];
                if (page == null || (changed.contains ("page/" + pid) && map.has_key ("page/" + pid))) {
                    var parsed = map.has_key ("page/" + pid) ? parse_page_header (map["page/" + pid]) : null;
                    if (parsed != null) {
                        parsed.id = pid;
                        if (page != null) parsed.items = page.items;
                        page = parsed;
                    }
                }
                if (page == null) continue;
                string prefix = "item/%s/".printf (pid);
                bool touched = all || changed.contains ("order/" + pid);
                if (!touched) foreach (string k in changed) if (k.has_prefix (prefix)) {
                    touched = true;
                    break;
                }
                if (touched) {
                    var current = new Gee.HashMap<string, Item> ();
                    foreach (var it in page.items) current[it.id] = it;
                    var items = new Gee.ArrayList<Item> ();
                    var placed = new Gee.HashSet<string> ();
                    string[] ids = map.has_key ("order/" + pid) ? split_ids (map["order/" + pid]) : new string[0];
                    foreach (string iid in ids) {
                        if (placed.contains (iid)) continue;
                        string key = prefix + iid;
                        Item? it = null;
                        if (map.has_key (key)) {
                            if (all || changed.contains (key) || !current.has_key (iid)) it = parse_item (map[key]);
                            else it = current[iid];
                        } else if (!changed.contains (key)) {
                            it = current[iid];
                        }
                        if (it == null) continue;
                        it.id = iid;
                        items.add (it);
                        placed.add (iid);
                    }
                    foreach (var it in page.items) {
                        if (placed.contains (it.id)) continue;
                        string key = prefix + it.id;
                        if (changed.contains (key) && !map.has_key (key)) continue;
                        Item? keep = it;
                        if (changed.contains (key) && map.has_key (key)) keep = parse_item (map[key]);
                        if (keep == null) continue;
                        items.add (keep);
                        placed.add (it.id);
                    }
                    foreach (string k in changed) {
                        if (!k.has_prefix (prefix) || !map.has_key (k)) continue;
                        string iid = k.substring (prefix.length);
                        if (placed.contains (iid)) continue;
                        var it = parse_item (map[k]);
                        if (it == null) continue;
                        it.id = iid;
                        items.add (it);
                        placed.add (iid);
                    }
                    page.items = items;
                }
                result.add (page);
            }
            pages.clear ();
            pages.add_all (result);
            foreach (var p in pages) Router.route_all (p);
        }

        private void on_changed () {
            if (applying) return;
            var now = keys_of (doc);
            var changes = new Json.Array ();
            clock++;
            foreach (var e in now.entries) {
                string? old = state[e.key];
                if (old == e.value) continue;
                changes.add_object_element (change_json (e.key, e.value));
            }
            foreach (string k in state.keys) {
                if (now.has_key (k)) continue;
                changes.add_object_element (change_json (k, null));
            }
            state = now;
            if (changes.get_length () > 0) {
                var m = new Json.Object ();
                m.set_string_member ("t", "draw");
                m.set_array_member ("changes", changes);
                outgoing (m);
            }
            if (queued.size > 0 && !doc.in_edit ()) {
                var list = new Gee.ArrayList<Json.Object> ();
                list.add_all (queued);
                queued.clear ();
                foreach (var q in list) receive (q);
            }
        }

        private Json.Object change_json (string key, string? value) {
            stamps[key] = new LiveStamp (clock, peer);
            var c = new Json.Object ();
            c.set_string_member ("k", key);
            if (value != null) c.set_string_member ("v", value);
            else c.set_null_member ("v");
            c.set_int_member ("c", clock);
            c.set_string_member ("p", peer);
            return c;
        }

        public void receive (Json.Object m) {
            if (!m.has_member ("changes")) return;
            if (doc.in_edit ()) {
                queued.add (m);
                return;
            }
            var accepted = new Gee.HashMap<string, string?> ();
            foreach (var n in m.get_array_member ("changes").get_elements ()) {
                var c = n.get_object ();
                string k = c.get_string_member ("k");
                int64 cl = c.get_int_member ("c");
                string p = c.get_string_member ("p");
                if (p == peer) continue;
                clock = int64.max (clock, cl);
                var mine = stamps[k];
                if (mine != null && mine.newer_than (cl, p)) {
                    conflicts_lost++;
                    continue;
                }
                stamps[k] = new LiveStamp (cl, p);
                var vn = c.get_member ("v");
                accepted[k] = vn != null && vn.get_node_type () == Json.NodeType.VALUE ? c.get_string_member ("v") : null;
            }
            if (accepted.size == 0) return;
            apply (accepted);
        }

        private void apply (Gee.Map<string, string?> accepted) {
            var changed = new Gee.HashSet<string> ();
            changed.add_all (accepted.keys);
            var map = new Gee.HashMap<string, string> ();
            map.set_all (state);
            foreach (var e in accepted.entries) {
                if (e.value != null) map[e.key] = e.value;
                else map.unset (e.key);
            }
            string current_page = doc.page.id;
            applying = true;
            materialize (doc, doc.pages, map, changed, false);
            foreach (var s in doc.history ()) patch_snapshot (s, accepted);
            int idx = 0;
            for (int i = 0; i < doc.pages.size; i++) if (doc.pages[i].id == current_page) idx = i;
            doc.page_index = idx;
            doc.ensure_ids ();
            doc.sync_ids ();
            doc.link_backgrounds ();
            doc.modified = true;
            doc.pages_changed ();
            doc.changed ();
            applying = false;
            state = keys_of (doc);
            applied ();
        }

        private static void patch_snapshot (Snapshot s, Gee.Map<string, string?> accepted) {
            var map = new Gee.HashMap<string, string> ();
            var ids = new Gee.ArrayList<string> ();
            foreach (var p in s.pages) {
                ids.add (p.id);
                add_page_keys (map, p);
            }
            map["pages"] = join_ids (ids);
            var changed = new Gee.HashSet<string> ();
            foreach (var e in accepted.entries) {
                if (e.key == "doc") continue;
                changed.add (e.key);
                if (e.value != null) map[e.key] = e.value;
                else map.unset (e.key);
            }
            if (changed.size == 0) return;
            materialize (null, s.pages, map, changed, false);
            s.page_index = s.page_index.clamp (0, int.max (0, s.pages.size - 1));
        }
    }
}
