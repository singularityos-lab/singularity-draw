namespace Singularity.Apps.Draw {

    public class RefreshResult {
        public int updated = 0;
        public int unchanged = 0;
        public int missing = 0;
        public int added = 0;
        public int removed = 0;
    }

    public class DataSources {
        public static string kind_for_path (string path) {
            string low = path.down ();
            if (low.has_suffix (".xlsx") || low.has_suffix (".xlsm")) return "xlsx";
            if (low.has_suffix (".ods")) return "ods";
            if (low.has_suffix (".db") || low.has_suffix (".sqlite") || low.has_suffix (".sqlite3")) return "sqlite";
            return "csv";
        }

        public static string kind_label (string kind) {
            switch (kind) {
                case "xlsx": return _("Excel Workbook");
                case "ods": return _("OpenDocument Spreadsheet");
                case "sqlite": return _("SQLite Database");
                default: return _("CSV File");
            }
        }

        public static CsvTable load (DataSource d) throws Error {
            switch (d.kind) {
                case "xlsx": return read_xlsx (d.path, d.sheet);
                case "ods": return read_ods (d.path, d.sheet);
                case "sqlite": return read_sqlite (d.path, d.query != "" ? d.query : (d.sheet != "" ? "SELECT * FROM \"%s\"".printf (d.sheet.replace ("\"", "\"\"")) : ""));
                default:
                    string text;
                    FileUtils.get_contents (d.path, out text);
                    return CsvTable.parse (text);
            }
        }

        private static int column_index (string cellref) {
            int col = 0;
            for (int i = 0; i < cellref.length; i++) {
                char c = cellref[i];
                if (c >= 'A' && c <= 'Z') col = col * 26 + (c - 'A' + 1);
                else if (c >= 'a' && c <= 'z') col = col * 26 + (c - 'a' + 1);
                else break;
            }
            return col - 1;
        }

        public static string[] sheets (string path) throws Error {
            string[] names = {};
            string kind = kind_for_path (path);
            uint8[] data;
            FileUtils.get_data (path, out data);
            if (kind == "xlsx") {
                var zip = new ZipReader (data);
                string? wb = zip.read_text ("xl/workbook.xml");
                if (wb == null) throw new FormatError.INVALID (_("This is not an Excel workbook."));
                Xml.Doc* x = XmlUtil.parse (wb);
                var sn = XmlUtil.find (x->get_root_element (), "sheets");
                foreach (var s in XmlUtil.children (sn, "sheet")) names += XmlUtil.attr_or (s, "name", "");
                delete x;
            } else if (kind == "ods") {
                var zip = new ZipReader (data);
                string? content = zip.read_text ("content.xml");
                if (content == null) throw new FormatError.INVALID (_("This is not a spreadsheet."));
                Xml.Doc* x = XmlUtil.parse (content);
                var ss = XmlUtil.find (x->get_root_element (), "spreadsheet");
                foreach (var t in XmlUtil.children (ss, "table")) names += XmlUtil.attr_or (t, "name", "");
                delete x;
            } else if (kind == "sqlite") {
                Sqlite.Database db;
                if (Sqlite.Database.open_v2 (path, out db, Sqlite.OPEN_READONLY) != Sqlite.OK) throw new FormatError.INVALID (_("The database could not be opened."));
                Sqlite.Statement st;
                if (db.prepare_v2 ("SELECT name FROM sqlite_master WHERE type IN ('table','view') AND name NOT LIKE 'sqlite_%' ORDER BY name", -1, out st) == Sqlite.OK) {
                    while (st.step () == Sqlite.ROW) names += st.column_text (0) ?? "";
                }
            }
            return names;
        }

        private static string xlsx_sheet_path (ZipReader zip, string sheet) throws Error {
            string? wb = zip.read_text ("xl/workbook.xml");
            if (wb == null) throw new FormatError.INVALID (_("This is not an Excel workbook."));
            Xml.Doc* x = XmlUtil.parse (wb);
            string rid = "";
            var sn = XmlUtil.find (x->get_root_element (), "sheets");
            foreach (var s in XmlUtil.children (sn, "sheet")) {
                string name = XmlUtil.attr_or (s, "name", "");
                if (sheet == "" || name == sheet) {
                    rid = XmlUtil.attr_or (s, "id", "");
                    break;
                }
            }
            delete x;
            string? rels = zip.read_text ("xl/_rels/workbook.xml.rels");
            if (rels != null && rid != "") {
                Xml.Doc* r = XmlUtil.parse (rels);
                foreach (var rel in XmlUtil.children (r->get_root_element (), "Relationship")) {
                    if (XmlUtil.attr_or (rel, "Id", "") != rid) continue;
                    string target = XmlUtil.attr_or (rel, "Target", "");
                    delete r;
                    if (target.has_prefix ("/")) return target.substring (1);
                    return "xl/" + target;
                }
                delete r;
            }
            return "xl/worksheets/sheet1.xml";
        }

        private static CsvTable rows_to_table (Gee.ArrayList<Gee.ArrayList<string>> rows) {
            var t = new CsvTable ();
            int start = 0;
            while (start < rows.size) {
                bool empty = true;
                foreach (string c in rows[start]) if (c.strip () != "") empty = false;
                if (!empty) break;
                start++;
            }
            if (start >= rows.size) return t;
            foreach (string h in rows[start]) t.header.add (h.strip ());
            while (t.header.size > 0 && t.header[t.header.size - 1] == "") t.header.remove_at (t.header.size - 1);
            for (int i = 0; i < t.header.size; i++) if (t.header[i] == "") t.header[i] = _("Column %d").printf (i + 1);
            for (int i = start + 1; i < rows.size; i++) {
                bool empty = true;
                foreach (string c in rows[i]) if (c.strip () != "") empty = false;
                if (!empty) t.rows.add (rows[i]);
            }
            return t;
        }

        public static CsvTable read_xlsx (string path, string sheet) throws Error {
            uint8[] data;
            FileUtils.get_data (path, out data);
            var zip = new ZipReader (data);
            var shared = new Gee.ArrayList<string> ();
            string? sst = zip.read_text ("xl/sharedStrings.xml");
            if (sst != null) {
                Xml.Doc* sx = XmlUtil.parse (sst);
                foreach (var si in XmlUtil.children (sx->get_root_element (), "si")) shared.add (XmlUtil.text (si));
                delete sx;
            }
            string? text = zip.read_text (xlsx_sheet_path (zip, sheet));
            if (text == null) throw new FormatError.INVALID (_("The worksheet could not be read."));
            Xml.Doc* x = XmlUtil.parse (text);
            var rows = new Gee.ArrayList<Gee.ArrayList<string>> ();
            var data_node = XmlUtil.find (x->get_root_element (), "sheetData");
            foreach (var rn in XmlUtil.children (data_node, "row")) {
                int rix = int.parse (XmlUtil.attr_or (rn, "r", "%d".printf (rows.size + 1))) - 1;
                while (rows.size < rix && rows.size < 100000) rows.add (new Gee.ArrayList<string> ());
                var row = new Gee.ArrayList<string> ();
                foreach (var cn in XmlUtil.children (rn, "c")) {
                    int col = column_index (XmlUtil.attr_or (cn, "r", ""));
                    if (col < 0) col = row.size;
                    if (col > 2000) continue;
                    while (row.size < col) row.add ("");
                    string type = XmlUtil.attr_or (cn, "t", "n");
                    string v = "";
                    var vn = XmlUtil.child (cn, "v");
                    if (type == "inlineStr") v = XmlUtil.text (XmlUtil.child (cn, "is"));
                    else if (vn != null) v = XmlUtil.text (vn);
                    if (type == "s") {
                        int idx = int.parse (v);
                        v = idx >= 0 && idx < shared.size ? shared[idx] : "";
                    } else if (type == "b") {
                        v = v == "1" ? "TRUE" : "FALSE";
                    }
                    row.add (v);
                }
                rows.add (row);
            }
            delete x;
            return rows_to_table (rows);
        }

        public static CsvTable read_ods (string path, string sheet) throws Error {
            uint8[] data;
            FileUtils.get_data (path, out data);
            var zip = new ZipReader (data);
            string? content = zip.read_text ("content.xml");
            if (content == null) throw new FormatError.INVALID (_("This is not a spreadsheet."));
            Xml.Doc* x = XmlUtil.parse (content);
            var ss = XmlUtil.find (x->get_root_element (), "spreadsheet");
            Xml.Node* table = null;
            foreach (var t in XmlUtil.children (ss, "table")) {
                if (sheet == "" || XmlUtil.attr_or (t, "name", "") == sheet) {
                    table = t;
                    break;
                }
            }
            var rows = new Gee.ArrayList<Gee.ArrayList<string>> ();
            if (table != null) {
                var row_nodes = new Gee.ArrayList<Xml.Node*> ();
                foreach (var c in XmlUtil.children (table)) {
                    if (c->name == "table-row") row_nodes.add (c);
                    else if (c->name == "table-rows" || c->name == "table-header-rows" || c->name == "table-row-group") row_nodes.add_all (XmlUtil.children (c, "table-row"));
                }
                foreach (var rn in row_nodes) {
                    int rrep = int.parse (XmlUtil.attr_or (rn, "number-rows-repeated", "1")).clamp (1, 1000);
                    var row = new Gee.ArrayList<string> ();
                    foreach (var cn in XmlUtil.children (rn)) {
                        if (cn->name != "table-cell" && cn->name != "covered-table-cell") continue;
                        int crep = int.parse (XmlUtil.attr_or (cn, "number-columns-repeated", "1")).clamp (1, 1000);
                        string v = "";
                        var parts = new Gee.ArrayList<string> ();
                        foreach (var p in XmlUtil.children (cn, "p")) parts.add (XmlUtil.text (p));
                        if (parts.size > 0) v = DataImport.join ("\n", parts);
                        else v = XmlUtil.attr_or (cn, "value", "");
                        for (int k = 0; k < crep && row.size < 2000; k++) row.add (v);
                    }
                    while (row.size > 0 && row[row.size - 1] == "") row.remove_at (row.size - 1);
                    bool empty = row.size == 0;
                    for (int k = 0; k < (empty ? int.min (rrep, 1) : rrep) && rows.size < 100000; k++) rows.add (row);
                }
            }
            delete x;
            return rows_to_table (rows);
        }

        public static CsvTable read_sqlite (string path, string query) throws Error {
            Sqlite.Database db;
            if (Sqlite.Database.open_v2 (path, out db, Sqlite.OPEN_READONLY) != Sqlite.OK) throw new FormatError.INVALID (_("The database could not be opened."));
            string q = query;
            if (q.strip () == "") {
                var names = sheets (path);
                if (names.length == 0) throw new FormatError.INVALID (_("The database has no tables."));
                q = "SELECT * FROM \"%s\"".printf (names[0].replace ("\"", "\"\""));
            }
            Sqlite.Statement st;
            if (db.prepare_v2 (q, -1, out st) != Sqlite.OK) throw new FormatError.INVALID (_("The query failed: %s").printf (db.errmsg ()));
            var t = new CsvTable ();
            for (int i = 0; i < st.column_count (); i++) t.header.add (st.column_name (i) ?? _("Column %d").printf (i + 1));
            int guard = 0;
            while (st.step () == Sqlite.ROW && guard++ < 100000) {
                var row = new Gee.ArrayList<string> ();
                for (int i = 0; i < st.column_count (); i++) row.add (st.column_text (i) ?? "");
                t.rows.add (row);
            }
            return t;
        }

        public static string new_id (Document doc) {
            int n = doc.data_sources.size + 1;
            while (doc.find_source ("ds%d".printf (n)) != null) n++;
            return "ds%d".printf (n);
        }

        private static Gee.ArrayList<string>? row_for (CsvTable t, int key_col, string key) {
            if (key_col < 0) return null;
            string k = key.strip ().casefold ();
            foreach (var row in t.rows) if (t.cell (row, key_col).strip ().casefold () == k) return row;
            return null;
        }

        public static void apply_row (Item it, CsvTable t, Gee.ArrayList<string> row) {
            for (int c = 0; c < t.header.size; c++) it.set_field (t.header[c], t.cell (row, c));
        }

        public static int auto_link (Page page, DataSource d) {
            if (d.table == null) return 0;
            int key_col = d.table.column (d.key_column);
            if (key_col < 0) return 0;
            int linked = 0;
            foreach (var it in page.all_items ()) {
                if (it is Connector || it is Group) continue;
                string key = it.data_key != "" && it.data_source == d.id ? it.data_key : it.display_text ().strip ();
                if (key == "") key = it.get_field (d.key_column) ?? it.name;
                if (key == "") continue;
                var row = row_for (d.table, key_col, key);
                if (row == null) continue;
                it.data_source = d.id;
                it.data_key = d.table.cell (row, key_col);
                apply_row (it, d.table, row);
                linked++;
            }
            return linked;
        }

        public static void link_item (Item it, DataSource d, Gee.ArrayList<string> row) {
            if (d.table == null) return;
            int key_col = d.table.column (d.key_column);
            it.data_source = d.id;
            it.data_key = key_col >= 0 ? d.table.cell (row, key_col) : "";
            apply_row (it, d.table, row);
        }

        public static void unlink (Item it) {
            it.data_source = "";
            it.data_key = "";
        }

        public static RefreshResult refresh (Document doc, DataSource d) throws Error {
            var r = new RefreshResult ();
            var t = load (d);
            d.table = t;
            d.refreshed = new DateTime.now_utc ().to_unix ();
            int key_col = t.column (d.key_column);
            foreach (var p in doc.pages) {
                foreach (var it in p.all_items ()) {
                    if (it.data_source != d.id) continue;
                    var row = row_for (t, key_col, it.data_key);
                    if (row == null) {
                        r.missing++;
                        continue;
                    }
                    var before = new StringBuilder ();
                    foreach (var f in it.fields) before.append ("%s=%s;".printf (f.key, f.value));
                    apply_row (it, t, row);
                    var after = new StringBuilder ();
                    foreach (var f in it.fields) after.append ("%s=%s;".printf (f.key, f.value));
                    if (before.str != after.str) r.updated++;
                    else r.unchanged++;
                }
                if (p != doc.page) continue;
                if (d.name.has_prefix ("process:")) sync_process (doc, p, d, r);
                else if (d.name.has_prefix ("org:")) sync_org (doc, p, d, r);
            }
            return r;
        }

        public class ProcessMap {
            public int id_col = -1;
            public int text_col = -1;
            public int next_col = -1;
            public int label_col = -1;
            public int type_col = -1;
            public int lane_col = -1;

            public static ProcessMap guess (CsvTable t) {
                var m = new ProcessMap ();
                for (int i = 0; i < t.header.size; i++) {
                    string h = t.header[i].casefold ();
                    if (m.id_col < 0 && (h.contains ("id") && !h.contains ("next"))) m.id_col = i;
                    else if (m.next_col < 0 && h.contains ("next")) m.next_col = i;
                    else if (m.label_col < 0 && (h.contains ("label") || h.contains ("connector"))) m.label_col = i;
                    else if (m.type_col < 0 && (h.contains ("type") || h.contains ("shape"))) m.type_col = i;
                    else if (m.lane_col < 0 && (h.contains ("function") || h.contains ("lane") || h.contains ("swimlane") || h.contains ("owner"))) m.lane_col = i;
                    else if (m.text_col < 0 && (h.contains ("desc") || h.contains ("name") || h.contains ("step") || h.contains ("text"))) m.text_col = i;
                }
                if (m.id_col < 0) m.id_col = 0;
                if (m.text_col < 0) m.text_col = t.header.size > 1 ? 1 : 0;
                return m;
            }
        }

        public static string kind_for_type (string type) {
            string t = type.strip ().casefold ();
            if (t == "") return "process";
            if (t.contains ("decision") || t.contains ("condition")) return "decision";
            if (t.contains ("start") || t.contains ("end") || t.contains ("terminator")) return "terminator";
            if (t.contains ("document")) return "document";
            if (t.contains ("data") && !t.contains ("database")) return "data";
            if (t.contains ("database") || t.contains ("store")) return "database";
            if (t.contains ("subprocess") || t.contains ("predefined")) return "predefined-process";
            if (t.contains ("manual")) return "manual-operation";
            if (t.contains ("delay") || t.contains ("wait")) return "delay";
            if (t.contains ("preparation")) return "preparation";
            if (t.contains ("off-page") || t.contains ("off page")) return "off-page";
            var e = ShapeLibrary.find (t);
            return e != null ? t : "process";
        }

        private static Gee.ArrayList<Item> source_items (Page p, DataSource d) {
            var list = new Gee.ArrayList<Item> ();
            foreach (var it in p.all_items ()) if (it.data_source == d.id) list.add (it);
            return list;
        }

        public static Gee.ArrayList<Item> build_process (Document doc, DataSource d, ProcessMap m, double x0, double y0) {
            var t = d.table;
            var items = new Gee.ArrayList<Item> ();
            if (t == null) return items;
            d.name = "process:" + d.name;
            d.key_column = m.id_col >= 0 && m.id_col < t.header.size ? t.header[m.id_col] : "";
            var lanes = new Gee.ArrayList<string> ();
            if (m.lane_col >= 0) foreach (var row in t.rows) {
                string l = t.cell (row, m.lane_col).strip ();
                if (l != "" && !lanes.contains (l)) lanes.add (l);
            }
            Shape? pool = null;
            var lane_shapes = new Gee.HashMap<string, Shape> ();
            if (lanes.size > 0) {
                pool = Swimlanes.insert (doc, x0, y0, false, lanes.size, _("Process"));
                var ls = Swimlanes.lanes (doc.page, pool);
                for (int i = 0; i < ls.size && i < lanes.size; i++) {
                    ls[i].text = lanes[i];
                    lane_shapes[lanes[i]] = ls[i];
                }
                items.add (pool);
                items.add_all (ls);
            }
            var by_id = new Gee.HashMap<string, Shape> ();
            int col = 0;
            foreach (var row in t.rows) {
                string kind = kind_for_type (m.type_col >= 0 ? t.cell (row, m.type_col) : "");
                var e = ShapeLibrary.find (kind);
                var s = new Shape (kind, x0 + 60 + col * 180, y0 + 30, e != null ? e.w : 120, e != null ? e.h : 60);
                ShapeLibrary.apply_defaults (s);
                Theme.style_new_item (doc, s);
                s.text = t.cell (row, m.text_col);
                link_item (s, d, row);
                if (m.lane_col >= 0) {
                    string l = t.cell (row, m.lane_col).strip ();
                    if (lane_shapes.has_key (l)) {
                        var ln = lane_shapes[l];
                        s.y = ln.y + (ln.h - s.h) / 2;
                        s.x = ln.x + 40 + col * 170;
                    }
                }
                doc.add_item (s);
                if (pool != null) doc.assign_container (s);
                items.add (s);
                by_id[t.cell (row, m.id_col).strip ()] = s;
                col++;
            }
            if (pool != null) {
                double right = 0;
                foreach (var s in by_id.values) right = double.max (right, s.x + s.w);
                pool.w = double.max (pool.w, right - pool.x + 60);
                Swimlanes.fit_pool (doc.page, pool);
            }
            connect_process (doc, d, m, by_id, items);
            if (pool == null) {
                var tops = new Gee.ArrayList<Item> ();
                foreach (var s in by_id.values) tops.add (s);
                foreach (var it in items) if (it is Connector) tops.add (it);
                AutoLayout.apply (doc.page, tops, LayoutKind.HIERARCHICAL, 50, 60);
            }
            return items;
        }

        private static void connect_process (Document doc, DataSource d, ProcessMap m, Gee.HashMap<string, Shape> by_id, Gee.List<Item> items) {
            var t = d.table;
            if (m.next_col < 0) return;
            foreach (var row in t.rows) {
                var from = by_id[t.cell (row, m.id_col).strip ()];
                if (from == null) continue;
                string[] nexts = t.cell (row, m.next_col).split_set (",;");
                string[] labels = m.label_col >= 0 ? t.cell (row, m.label_col).split_set (",;") : new string[0];
                for (int i = 0; i < nexts.length; i++) {
                    var to = by_id[nexts[i].strip ()];
                    if (to == null) continue;
                    var c = new Connector ();
                    c.src.item_id = from.id;
                    c.dst.item_id = to.id;
                    c.text = i < labels.length ? labels[i].strip () : "";
                    c.data_source = d.id;
                    c.data_key = "%s>%s".printf (t.cell (row, m.id_col).strip (), nexts[i].strip ());
                    doc.add_item (c);
                    Theme.style_new_item (doc, c);
                    items.add (c);
                }
            }
        }

        private static void sync_process (Document doc, Page page, DataSource d, RefreshResult r) {
            var t = d.table;
            var m = ProcessMap.guess (t);
            m.id_col = t.column (d.key_column) >= 0 ? t.column (d.key_column) : m.id_col;
            var by_id = new Gee.HashMap<string, Shape> ();
            var ids = new Gee.HashSet<string> ();
            foreach (var row in t.rows) ids.add (t.cell (row, m.id_col).strip ());
            var doomed = new Gee.ArrayList<Item> ();
            foreach (var it in source_items (page, d)) {
                if (it is Connector) {
                    doomed.add (it);
                    continue;
                }
                var s = it as Shape;
                if (s == null) continue;
                if (!ids.contains (s.data_key.strip ())) {
                    doomed.add (s);
                    r.removed++;
                    continue;
                }
                by_id[s.data_key.strip ()] = s;
            }
            if (by_id.size == 0 && doomed.size == 0) return;
            foreach (var row in t.rows) {
                string id = t.cell (row, m.id_col).strip ();
                var s = by_id[id];
                string text = t.cell (row, m.text_col);
                if (s == null) {
                    string kind = kind_for_type (m.type_col >= 0 ? t.cell (row, m.type_col) : "");
                    var e = ShapeLibrary.find (kind);
                    var b = page.content_bounds ();
                    s = new Shape (kind, b.is_empty () ? 40 : b.x2 () + 40, b.is_empty () ? 40 : b.y, e != null ? e.w : 120, e != null ? e.h : 60);
                    ShapeLibrary.apply_defaults (s);
                    Theme.style_new_item (doc, s);
                    doc.add_item (s);
                    by_id[id] = s;
                    r.added++;
                } else {
                    string kind = kind_for_type (m.type_col >= 0 ? t.cell (row, m.type_col) : "");
                    if (m.type_col >= 0 && kind != s.kind) {
                        s.kind = kind;
                        ShapeLibrary.apply_defaults (s);
                        Theme.style_new_item (doc, s);
                    }
                }
                s.text = text;
                link_item (s, d, row);
            }
            doc.delete_items (doomed);
            var items = new Gee.ArrayList<Item> ();
            connect_process (doc, d, m, by_id, items);
        }

        private static void sync_org (Document doc, Page page, DataSource d, RefreshResult r) {
            var t = d.table;
            int key_col = t.column (d.key_column);
            int parent_col = -1;
            for (int i = 0; i < t.header.size; i++) {
                string h = t.header[i].casefold ();
                if (h.contains ("manager") || h.contains ("parent") || h.contains ("reports") || h.contains ("boss")) parent_col = i;
            }
            var by_id = new Gee.HashMap<string, Shape> ();
            var keys = new Gee.HashSet<string> ();
            foreach (var row in t.rows) keys.add (t.cell (row, key_col).strip ());
            var doomed = new Gee.ArrayList<Item> ();
            foreach (var it in source_items (page, d)) {
                var s = it as Shape;
                if (it is Connector) {
                    doomed.add (it);
                } else if (s != null) {
                    if (!keys.contains (s.data_key.strip ())) {
                        doomed.add (s);
                        r.removed++;
                    } else {
                        by_id[s.data_key.strip ()] = s;
                    }
                }
            }
            if (by_id.size == 0 && doomed.size == 0) return;
            string template = "";
            foreach (var s in by_id.values) {
                template = s.text;
                break;
            }
            foreach (var row in t.rows) {
                string key = t.cell (row, key_col).strip ();
                if (by_id.has_key (key)) continue;
                var s = new Shape ("org-person", 40, 40, 180, 64);
                ShapeLibrary.apply_defaults (s);
                s.text = template != "" ? template : key;
                doc.add_item (s);
                link_item (s, d, row);
                by_id[key] = s;
                r.added++;
            }
            doc.delete_items (doomed);
            var all = new Gee.ArrayList<Item> ();
            all.add_all (by_id.values);
            if (parent_col >= 0) {
                foreach (var row in t.rows) {
                    var child = by_id[t.cell (row, key_col).strip ()];
                    var parent = by_id[t.cell (row, parent_col).strip ()];
                    if (child == null || parent == null) continue;
                    var c = new Connector ();
                    c.src.item_id = parent.id;
                    c.dst.item_id = child.id;
                    c.src.port = 2;
                    c.dst.port = 0;
                    c.style.arrow_end = ArrowKind.NONE;
                    c.data_source = d.id;
                    doc.add_item (c, 0);
                    all.add (c);
                }
            }
            if (r.added > 0 || r.removed > 0) AutoLayout.apply (page, all, LayoutKind.TREE_DOWN, 30, 50);
        }
    }
}
