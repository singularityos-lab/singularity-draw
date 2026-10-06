namespace Singularity.Apps.Draw {

    public class ShapeReport {
        public string title = "";
        public Gee.ArrayList<string> header = new Gee.ArrayList<string> ();
        public Gee.ArrayList<Gee.ArrayList<string>> rows = new Gee.ArrayList<Gee.ArrayList<string>> ();
        public Gee.HashSet<int> summary_rows = new Gee.HashSet<int> ();

        private static bool number (string s, out double v) {
            v = 0;
            string t = s.strip ().replace (",", ".");
            if (t == "") return false;
            return double.try_parse (t, out v);
        }

        private delegate string KeyFunc (Item it);
        private delegate void Flush ();

        private static string fmt (double v) {
            return PathData.fmt (v, 2);
        }

        public static ShapeReport build (Gee.List<Item> items, bool with_text, bool with_type, Gee.List<string> fields, string group, bool totals) {
            var r = new ShapeReport ();
            r.title = _("Shape Report");
            if (group != "") r.header.add (group == "@type" ? _("Shape Type") : group);
            if (with_text) r.header.add (_("Text"));
            if (with_type) r.header.add (_("Shape Type"));
            r.header.add_all (fields);
            var entries = new Gee.ArrayList<Item> ();
            foreach (var it in items) {
                if (it is Group || it is Connector || it is RasterItem) continue;
                bool any = with_text && it.display_text ().strip () != "";
                foreach (string f in fields) if (it.get_field (f) != null) any = true;
                if (any) entries.add (it);
            }
            KeyFunc key_of = (it) => {
                if (group == "") return "";
                if (group == "@type") {
                    var s = it as Shape;
                    return s != null ? ShapeLibrary.display_name (s.kind) : "";
                }
                return it.get_field (group) ?? "";
            };
            entries.sort ((a, b) => strcmp (key_of (a), key_of (b)));
            string? current = null;
            int count = 0;
            var sums = new double[fields.size];
            var nums = new int[fields.size];
            var gsums = new double[fields.size];
            var gnums = new int[fields.size];
            Flush flush_group = () => {
                if (current == null || group == "" || !totals) return;
                var row = new Gee.ArrayList<string> ();
                row.add (_("%s total").printf (current != "" ? current : _("(empty)")));
                if (with_text) row.add (ngettext ("%d shape", "%d shapes", count).printf (count));
                if (with_type) row.add ("");
                for (int i = 0; i < fields.size; i++) row.add (gnums[i] > 0 ? fmt (gsums[i]) : "");
                r.summary_rows.add (r.rows.size);
                r.rows.add (row);
            };
            foreach (var it in entries) {
                string k = key_of (it);
                if (current == null || k != current) {
                    flush_group ();
                    current = k;
                    count = 0;
                    for (int i = 0; i < fields.size; i++) {
                        gsums[i] = 0;
                        gnums[i] = 0;
                    }
                }
                var row = new Gee.ArrayList<string> ();
                if (group != "") row.add (k);
                if (with_text) row.add (it.display_text ().replace ("\n", " "));
                if (with_type) {
                    var s = it as Shape;
                    row.add (s != null ? ShapeLibrary.display_name (s.kind) : "");
                }
                for (int i = 0; i < fields.size; i++) {
                    string v = it.get_field (fields[i]) ?? "";
                    row.add (v);
                    double d;
                    if (number (v, out d)) {
                        sums[i] += d;
                        nums[i]++;
                        gsums[i] += d;
                        gnums[i]++;
                    }
                }
                r.rows.add (row);
                count++;
            }
            flush_group ();
            if (totals) {
                var total = new Gee.ArrayList<string> ();
                var avg = new Gee.ArrayList<string> ();
                if (group != "") {
                    total.add (_("Total"));
                    avg.add (_("Average"));
                }
                if (with_text) {
                    total.add (group == "" ? _("Total, %d shapes").printf (entries.size) : ngettext ("%d shape", "%d shapes", entries.size).printf (entries.size));
                    avg.add (group == "" ? _("Average") : "");
                }
                if (with_type) {
                    total.add ("");
                    avg.add ("");
                }
                bool any = false;
                for (int i = 0; i < fields.size; i++) {
                    total.add (nums[i] > 0 ? fmt (sums[i]) : "");
                    avg.add (nums[i] > 0 ? fmt (sums[i] / nums[i]) : "");
                    if (nums[i] > 0) any = true;
                }
                r.summary_rows.add (r.rows.size);
                r.rows.add (total);
                if (any) {
                    r.summary_rows.add (r.rows.size);
                    r.rows.add (avg);
                }
            }
            return r;
        }

        public string to_csv () {
            var t = new CsvTable ();
            t.header.add_all (header);
            t.rows.add_all (rows);
            return DataImport.to_csv_table (t);
        }

        public string to_html () {
            var sb = new StringBuilder ();
            sb.append ("<!DOCTYPE html>\n<html><head><meta charset=\"utf-8\"><title>%s</title>".printf (XmlWriter.escape (title)));
            sb.append ("<style>body{font-family:sans-serif;margin:24px}table{border-collapse:collapse}th,td{border:1px solid #ccd;padding:4px 8px;text-align:left}th{background:#dde9f1}tr.sum td{font-weight:bold;background:#f4f6f8}</style></head><body>\n");
            sb.append ("<h1>%s</h1>\n<table>\n<tr>".printf (XmlWriter.escape (title)));
            foreach (string h in header) sb.append ("<th>%s</th>".printf (XmlWriter.escape (h)));
            sb.append ("</tr>\n");
            for (int i = 0; i < rows.size; i++) {
                sb.append (summary_rows.contains (i) ? "<tr class=\"sum\">" : "<tr>");
                foreach (string c in rows[i]) sb.append ("<td>%s</td>".printf (XmlWriter.escape (c)));
                sb.append ("</tr>\n");
            }
            sb.append ("</table>\n</body></html>\n");
            return sb.str;
        }

        public TableShape to_table () {
            int nrows = rows.size + 1;
            int ncols = int.max (header.size, 1);
            var t = new TableShape (nrows, ncols);
            for (int c = 0; c < header.size; c++) t.set_cell (0, c, header[c]);
            for (int r = 0; r < rows.size; r++) for (int c = 0; c < ncols && c < rows[r].size; c++) t.set_cell (r + 1, c, rows[r][c]);
            t.w = double.min (140 * ncols, 900);
            t.h = 26 * nrows;
            return t;
        }
    }
}
