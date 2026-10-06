namespace Singularity.Apps.Draw {

    public class CsvTable {
        public Gee.ArrayList<string> header = new Gee.ArrayList<string> ();
        public Gee.ArrayList<Gee.ArrayList<string>> rows = new Gee.ArrayList<Gee.ArrayList<string>> ();

        public int column (string name) {
            for (int i = 0; i < header.size; i++) if (header[i].casefold () == name.casefold ()) return i;
            return -1;
        }

        public string cell (Gee.ArrayList<string> row, int col) {
            return col >= 0 && col < row.size ? row[col] : "";
        }

        public static char detect_delimiter (string text) {
            string first = text.split ("\n", 2)[0];
            int commas = 0, semis = 0, tabs = 0;
            bool quoted = false;
            for (int i = 0; i < first.length; i++) {
                char c = first[i];
                if (c == '"') quoted = !quoted;
                if (quoted) continue;
                if (c == ',') commas++;
                else if (c == ';') semis++;
                else if (c == '\t') tabs++;
            }
            if (tabs > commas && tabs > semis) return '\t';
            if (semis > commas) return ';';
            return ',';
        }

        public static CsvTable parse (string raw, bool has_header = true) {
            string text = raw;
            if (text.has_prefix ("\xef\xbb\xbf")) text = text.substring (3);
            char delim = detect_delimiter (text);
            var t = new CsvTable ();
            var all = new Gee.ArrayList<Gee.ArrayList<string>> ();
            var row = new Gee.ArrayList<string> ();
            var field = new StringBuilder ();
            bool quoted = false;
            bool field_started = false;
            int i = 0;
            while (i < text.length) {
                char c = text[i];
                if (quoted) {
                    if (c == '"') {
                        if (i + 1 < text.length && text[i + 1] == '"') {
                            field.append_c ('"');
                            i += 2;
                            continue;
                        }
                        quoted = false;
                        i++;
                        continue;
                    }
                    field.append_c (c);
                    i++;
                    continue;
                }
                if (c == '"' && !field_started) {
                    quoted = true;
                    field_started = true;
                    i++;
                    continue;
                }
                if (c == delim) {
                    row.add (field.str);
                    field.truncate ();
                    field_started = false;
                    i++;
                    continue;
                }
                if (c == '\r' || c == '\n') {
                    row.add (field.str);
                    field.truncate ();
                    field_started = false;
                    all.add (row);
                    row = new Gee.ArrayList<string> ();
                    if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
                    i++;
                    continue;
                }
                field.append_c (c);
                field_started = true;
                i++;
            }
            if (field.len > 0 || row.size > 0 || field_started) {
                row.add (field.str);
                all.add (row);
            }
            var cleaned = new Gee.ArrayList<Gee.ArrayList<string>> ();
            foreach (var r in all) {
                bool empty = true;
                foreach (string f in r) if (f.strip () != "") empty = false;
                if (!empty) cleaned.add (r);
            }
            if (cleaned.size == 0) return t;
            if (has_header) {
                foreach (string h in cleaned[0]) t.header.add (h.strip ());
                for (int k = 1; k < cleaned.size; k++) t.rows.add (cleaned[k]);
            } else {
                for (int k = 0; k < cleaned[0].size; k++) t.header.add (_("Column %d").printf (k + 1));
                t.rows.add_all (cleaned);
            }
            return t;
        }
    }

    public class DataImport {
        public static Gee.ArrayList<Item> shapes_from_table (Document doc, CsvTable table, string kind, string text_template, double x0, double y0) {
            var items = new Gee.ArrayList<Item> ();
            var entry = ShapeLibrary.find (kind);
            double w = entry != null ? entry.w : 140, h = entry != null ? entry.h : 70;
            int cols = int.max (1, (int) Math.ceil (Math.sqrt (table.rows.size)));
            int i = 0;
            foreach (var row in table.rows) {
                var s = new Shape (kind, x0 + (i % cols) * (w + 40), y0 + (i / cols) * (h + 40), w, h);
                ShapeLibrary.apply_defaults (s);
                for (int c = 0; c < table.header.size; c++) s.set_field (table.header[c], table.cell (row, c));
                s.text = text_template;
                doc.add_item (s);
                items.add (s);
                i++;
            }
            return items;
        }

        public static int link_table (Page page, CsvTable table, int key_col) {
            int linked = 0;
            if (key_col < 0) return 0;
            foreach (var it in page.all_items ()) {
                if (it is Connector || it is Group) continue;
                string key = it.display_text ().strip ();
                if (key == "") key = it.name;
                foreach (var row in table.rows) {
                    if (table.cell (row, key_col).strip ().casefold () != key.casefold ()) continue;
                    for (int c = 0; c < table.header.size; c++) it.set_field (table.header[c], table.cell (row, c));
                    linked++;
                    break;
                }
            }
            return linked;
        }

        public static Gee.ArrayList<Item> org_chart (Document doc, CsvTable table, int id_col, int parent_col, int name_col, int title_col, double x0, double y0) {
            var items = new Gee.ArrayList<Item> ();
            var by_key = new Gee.HashMap<string, Shape> ();
            var parents = new Gee.HashMap<Shape, string> ();
            foreach (var row in table.rows) {
                string key = table.cell (row, id_col >= 0 ? id_col : name_col).strip ();
                string parent = table.cell (row, parent_col).strip ();
                bool top = parent == "";
                var s = new Shape (top ? "org-manager" : "org-person", x0, y0, 180, 64);
                ShapeLibrary.apply_defaults (s);
                for (int c = 0; c < table.header.size; c++) s.set_field (table.header[c], table.cell (row, c));
                string name_key = name_col >= 0 && name_col < table.header.size ? table.header[name_col] : "";
                string title_key = title_col >= 0 && title_col < table.header.size ? table.header[title_col] : "";
                s.text = (name_key != "" ? "{" + name_key + "}" : key) + (title_key != "" ? "\n{" + title_key + "}" : "");
                doc.add_item (s);
                items.add (s);
                if (key != "") by_key[key] = s;
                if (!top) parents[s] = parent;
            }
            foreach (var e in parents.entries) {
                if (!by_key.has_key (e.value)) continue;
                var c = new Connector ();
                c.src.item_id = by_key[e.value].id;
                c.dst.item_id = e.key.id;
                c.src.port = 2;
                c.dst.port = 0;
                c.style.arrow_end = ArrowKind.NONE;
                doc.add_item (c, 0);
                items.add (c);
            }
            AutoLayout.apply (doc.page, items, LayoutKind.TREE_DOWN, 30, 50);
            return items;
        }

        public static string to_csv (Gee.List<Item> items) {
            var keys = new Gee.ArrayList<string> ();
            foreach (var it in items) foreach (var f in it.fields) if (!keys.contains (f.key)) keys.add (f.key);
            var sb = new StringBuilder ();
            sb.append (quote (_("Text")));
            foreach (string k in keys) {
                sb.append_c (',');
                sb.append (quote (k));
            }
            sb.append_c ('\n');
            foreach (var it in items) {
                if (it is Group) continue;
                sb.append (quote (it.display_text ()));
                foreach (string k in keys) {
                    sb.append_c (',');
                    sb.append (quote (it.get_field (k) ?? ""));
                }
                sb.append_c ('\n');
            }
            return sb.str;
        }

        public static string join (string sep, Gee.Collection<string> parts) {
            var sb = new StringBuilder ();
            bool first = true;
            foreach (string p in parts) {
                if (!first) sb.append (sep);
                sb.append (p);
                first = false;
            }
            return sb.str;
        }

        public static string to_csv_table (CsvTable t) {
            var sb = new StringBuilder ();
            for (int i = 0; i < t.header.size; i++) {
                if (i > 0) sb.append_c (',');
                sb.append (quote (t.header[i]));
            }
            sb.append_c ('\n');
            foreach (var row in t.rows) {
                for (int i = 0; i < t.header.size; i++) {
                    if (i > 0) sb.append_c (',');
                    sb.append (quote (t.cell (row, i)));
                }
                sb.append_c ('\n');
            }
            return sb.str;
        }

        private static string quote (string s) {
            if (s.contains (",") || s.contains ("\"") || s.contains ("\n")) return "\"" + s.replace ("\"", "\"\"") + "\"";
            return s;
        }
    }
}
