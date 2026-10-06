namespace Singularity.Apps.Draw {

    public class SheetCell {
        public string name;
        public string value = "";
        public string? formula = null;
        public string? unit = null;
        public bool inherited = false;

        public SheetCell (string name, string value = "", string? formula = null, string? unit = null) {
            this.name = name;
            this.value = value;
            this.formula = formula;
            this.unit = unit;
        }

        public SheetCell copy () {
            var c = new SheetCell (name, value, formula, unit);
            c.inherited = inherited;
            return c;
        }

        public bool has_formula () {
            return formula != null && formula != "" && formula != "Inh" && formula != "No Formula";
        }

        public double number (double fallback = 0) {
            double d;
            if (double.try_parse (value.strip (), out d)) return d;
            return fallback;
        }
    }

    public class SheetRow {
        public string? name = null;
        public string? kind = null;
        public int ix = 0;
        public bool deleted = false;
        public Gee.ArrayList<SheetCell> cells = new Gee.ArrayList<SheetCell> ();

        public SheetRow copy () {
            var r = new SheetRow ();
            r.name = name;
            r.kind = kind;
            r.ix = ix;
            r.deleted = deleted;
            foreach (var c in cells) r.cells.add (c.copy ());
            return r;
        }

        public SheetCell? get_cell (string n) {
            foreach (var c in cells) if (c.name == n) return c;
            return null;
        }

        public SheetCell set_cell (string n, string value, string? formula = null, string? unit = null) {
            var c = get_cell (n);
            if (c == null) {
                c = new SheetCell (n, value, formula, unit);
                cells.add (c);
            } else {
                c.value = value;
                c.formula = formula;
                if (unit != null) c.unit = unit;
            }
            return c;
        }
    }

    public class SheetSection {
        public string name;
        public int ix = -1;
        public Gee.ArrayList<SheetCell> cells = new Gee.ArrayList<SheetCell> ();
        public Gee.ArrayList<SheetRow> rows = new Gee.ArrayList<SheetRow> ();

        public SheetSection (string name, int ix = -1) {
            this.name = name;
            this.ix = ix;
        }

        public SheetSection copy () {
            var s = new SheetSection (name, ix);
            foreach (var c in cells) s.cells.add (c.copy ());
            foreach (var r in rows) s.rows.add (r.copy ());
            return s;
        }

        public SheetCell? get_cell (string n) {
            foreach (var c in cells) if (c.name == n) return c;
            return null;
        }

        public SheetRow? row_named (string n) {
            foreach (var r in rows) if (r.name == n) return r;
            return null;
        }

        public SheetRow? row_at (int ix) {
            foreach (var r in rows) if (r.ix == ix) return r;
            return null;
        }
    }

    public class ShapeSheet {
        public Gee.ArrayList<SheetCell> cells = new Gee.ArrayList<SheetCell> ();
        public Gee.ArrayList<SheetSection> sections = new Gee.ArrayList<SheetSection> ();
        public int sheet_id = -1;
        public bool nested = false;
        public double ppi = 96;

        public ShapeSheet copy () {
            var s = new ShapeSheet ();
            s.sheet_id = sheet_id;
            s.nested = nested;
            s.ppi = ppi;
            foreach (var c in cells) s.cells.add (c.copy ());
            foreach (var sec in sections) s.sections.add (sec.copy ());
            return s;
        }

        public bool is_empty () {
            return cells.size == 0 && sections.size == 0;
        }

        public SheetCell? get_cell (string n) {
            foreach (var c in cells) if (c.name == n) return c;
            return null;
        }

        public SheetCell set_cell (string n, string value, string? formula = null, string? unit = null) {
            var c = get_cell (n);
            if (c == null) {
                c = new SheetCell (n, value, formula, unit);
                cells.add (c);
            } else {
                c.value = value;
                c.formula = formula;
                if (unit != null) c.unit = unit;
            }
            return c;
        }

        public SheetSection? section (string name, int ix = -1) {
            foreach (var s in sections) if (s.name == name && s.ix == ix) return s;
            return null;
        }

        public SheetSection ensure_section (string name, int ix = -1) {
            var s = section (name, ix);
            if (s == null) {
                s = new SheetSection (name, ix);
                sections.add (s);
            }
            return s;
        }

        public Gee.ArrayList<SheetSection> sections_named (string name) {
            var list = new Gee.ArrayList<SheetSection> ();
            foreach (var s in sections) if (s.name == name) list.add (s);
            list.sort ((a, b) => a.ix - b.ix);
            return list;
        }

        private static void write_cell (XmlWriter w, SheetCell c) {
            w.start ("cell").attr ("n", c.name).attr ("v", c.value);
            if (c.formula != null) w.attr ("f", c.formula);
            if (c.unit != null) w.attr ("u", c.unit);
            w.end ();
        }

        public void write (XmlWriter w) {
            w.start ("sheet");
            if (sheet_id >= 0) w.attr ("id", sheet_id.to_string ());
            if (nested) w.attr ("nested", "1");
            if (ppi != 96) w.attr_num ("ppi", ppi, 6);
            foreach (var c in cells) write_cell (w, c);
            foreach (var s in sections) {
                w.start ("section").attr ("n", s.name);
                if (s.ix >= 0) w.attr ("ix", s.ix.to_string ());
                foreach (var c in s.cells) write_cell (w, c);
                foreach (var r in s.rows) {
                    w.start ("row").attr ("ix", r.ix.to_string ());
                    if (r.name != null) w.attr ("n", r.name);
                    if (r.kind != null) w.attr ("t", r.kind);
                    if (r.deleted) w.attr ("del", "1");
                    foreach (var c in r.cells) write_cell (w, c);
                    w.end ();
                }
                w.end ();
            }
            w.end ();
        }

        private static SheetCell read_cell (Xml.Node* n) {
            return new SheetCell (XmlUtil.attr_or (n, "n", ""), XmlUtil.attr_or (n, "v", ""), XmlUtil.attr (n, "f"), XmlUtil.attr (n, "u"));
        }

        public static ShapeSheet read (Xml.Node* node) {
            var sh = new ShapeSheet ();
            sh.sheet_id = int.parse (XmlUtil.attr_or (node, "id", "-1"));
            sh.nested = XmlUtil.attr_or (node, "nested", "0") == "1";
            sh.ppi = XmlUtil.attr_double (node, "ppi", 96);
            foreach (var c in XmlUtil.children (node)) {
                if (c->name == "cell") {
                    sh.cells.add (read_cell (c));
                } else if (c->name == "section") {
                    var s = new SheetSection (XmlUtil.attr_or (c, "n", ""), int.parse (XmlUtil.attr_or (c, "ix", "-1")));
                    foreach (var rc in XmlUtil.children (c)) {
                        if (rc->name == "cell") {
                            s.cells.add (read_cell (rc));
                        } else if (rc->name == "row") {
                            var r = new SheetRow ();
                            r.ix = int.parse (XmlUtil.attr_or (rc, "ix", "0"));
                            r.name = XmlUtil.attr (rc, "n");
                            r.kind = XmlUtil.attr (rc, "t");
                            r.deleted = XmlUtil.attr_or (rc, "del", "0") == "1";
                            foreach (var cc in XmlUtil.children (rc, "cell")) r.cells.add (read_cell (cc));
                            s.rows.add (r);
                        }
                    }
                    sh.sections.add (s);
                }
            }
            return sh;
        }

        public static void recalc_page (Page page) {
            SheetEval.recalc_page (page);
        }
    }

    public class SheetShape : Shape {
        public SheetShape () {
            base ("sheet");
        }

        public override Item clone () {
            var s = new SheetShape ();
            copy_shape (s);
            return s;
        }

        public override Geometry geometry () {
            return SheetEval.geometry (this);
        }
    }
}
