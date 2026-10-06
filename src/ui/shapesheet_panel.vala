using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class ShapeSheetPanel {
        private static string show_number (string v) {
            double d;
            if (double.try_parse (v.strip (), out d)) return PathData.fmt (d, 4);
            return v;
        }

        private static ShapeSheet ensure_sheet (Item it) {
            if (it.sheet == null) it.sheet = new ShapeSheet ();
            return it.sheet;
        }

        private static double core_value (Item it, string name, Document doc) {
            var s = it as Shape;
            double ppi = it.sheet != null && it.sheet.ppi > 0 ? it.sheet.ppi : Units.PX_PER_IN;
            if (it.sheet != null) {
                var c = it.sheet.get_cell (name);
                if (c != null) return c.number (0);
            }
            if (s == null) return 0;
            switch (name) {
                case "PinX": return s.cx () / ppi;
                case "PinY": return (doc.page.height - s.cy ()) / ppi;
                case "Width": return s.w / ppi;
                case "Height": return s.h / ppi;
                case "Angle": return -s.rotation * Math.PI / 180;
                default: return 0;
            }
        }

        private static bool apply (DrawWindow win, SheetCell cell, string text) {
            string t = text.strip ();
            if (t.has_prefix ("=")) t = t.substring (1).strip ();
            double d;
            if (t == "") {
                cell.formula = null;
            } else if (double.try_parse (t, out d)) {
                cell.formula = null;
                cell.value = Vsdx.num (d);
            } else {
                if (!SheetEval.parses (t)) {
                    win.add_toast (new Toast (_("This formula is not valid")));
                    return false;
                }
                cell.formula = t;
            }
            cell.inherited = false;
            return true;
        }

        private static EntryRow formula_row (DrawWindow win, Item it, string title, SheetCell? existing, string value, owned CellFactory factory) {
            var row = new EntryRow (title);
            row.text = existing != null && existing.has_formula () ? existing.formula : "";
            var val = new Label (value);
            val.add_css_class ("dim-label");
            val.add_css_class ("numeric");
            val.valign = Align.CENTER;
            row.add_suffix (val);
            row.entry_activated.connect (() => {
                var doc = win.doc;
                if (doc == null) return;
                doc.begin (_("Edit Formula"));
                var cell = factory ();
                if (!apply (win, cell, row.text)) {
                    doc.cancel ();
                    return;
                }
                doc.commit ();
                val.label = show_number (cell.value);
            });
            return row;
        }

        public delegate SheetCell CellFactory ();

        public static Gtk.Widget build (DrawWindow win, Item it) {
            var doc = win.doc;
            var g = new PreferencesGroup (_("ShapeSheet"), _("Type a formula such as Height*2 or User.Size, or a number to fix a value."));
            var add = new Button.with_label (_("Add Cell"));
            add.valign = Align.CENTER;
            add.clicked.connect (() => {
                if (win.doc == null) return;
                win.doc.begin (_("Add Cell"));
                var sec = ensure_sheet (it).ensure_section ("User");
                int n = sec.rows.size + 1;
                while (sec.row_named ("Cell%d".printf (n)) != null) n++;
                var r = new SheetRow ();
                r.name = "Cell%d".printf (n);
                r.ix = sec.rows.size;
                r.set_cell ("Value", "0");
                r.set_cell ("Prompt", "", null, "STR");
                sec.rows.add (r);
                win.doc.commit ();
                win.inspector.refresh ();
            });
            g.add_header_suffix (add);
            if (it is Shape) {
                string[] names = { "PinX", "PinY", "Width", "Height", "Angle" };
                foreach (string n in names) {
                    string name = n;
                    var existing = it.sheet != null ? it.sheet.get_cell (name) : null;
                    double v = core_value (it, name, doc);
                    string shown = name == "Angle" ? "%s deg".printf (PathData.fmt (-v * 180 / Math.PI, 2)) : "%s in".printf (PathData.fmt (v, 4));
                    g.add_row (formula_row (win, it, name, existing, shown, () => {
                        var sh = ensure_sheet (it);
                        var c = sh.get_cell (name);
                        if (c == null) c = sh.set_cell (name, Vsdx.num (core_value (it, name, doc)));
                        return c;
                    }));
                }
            }
            if (it.sheet != null) {
                foreach (var sec in it.sheet.sections) {
                    string prefix;
                    string cell_name;
                    switch (sec.name) {
                        case "User": prefix = "User"; cell_name = "Value"; break;
                        case "Property": prefix = "Prop"; cell_name = "Value"; break;
                        case "Scratch": prefix = "Scratch"; cell_name = "X"; break;
                        case "Controls": prefix = "Controls"; cell_name = "X"; break;
                        default: continue;
                    }
                    foreach (var r in sec.rows) {
                        if (r.deleted || (r.name != null && r.name.has_prefix ("SDraw"))) continue;
                        string rn = r.name ?? "%d".printf (r.ix + 1);
                        string[] cells = sec.name == "Controls" ? new string[] { "X", "Y" } : new string[] { cell_name };
                        foreach (string cn in cells) {
                            var row = r;
                            string cname = cn;
                            var c = row.get_cell (cname);
                            string title = sec.name == "Controls" ? "%s.%s.%s".printf (prefix, rn, cname) : "%s.%s".printf (prefix, rn);
                            g.add_row (formula_row (win, it, title, c, c != null ? show_number (c.value) : "", () => {
                                var cc = row.get_cell (cname);
                                if (cc == null) cc = row.set_cell (cname, "0");
                                return cc;
                            }));
                        }
                    }
                }
            }
            return g;
        }
    }
}
