using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class Dialogs {
        public delegate void Apply ();

        private static AppDialog make (DrawWindow win, string title, int width, int height) {
            var dlg = new AppDialog ((Gtk.Application) win.application, true);
            dlg.set_title (title);
            dlg.transient_for = win;
            dlg.set_default_size (width, height);
            dlg.add_css_class ("draw-dialog");
            return dlg;
        }

        private static Box body (AppDialog dlg) {
            var scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.vexpand = true;
            var box = new Box (Orientation.VERTICAL, 14);
            box.margin_start = box.margin_end = 18;
            box.margin_top = 6;
            box.margin_bottom = 12;
            scroll.child = box;
            dlg.content_box.append (scroll);
            return box;
        }

        private static Button footer (AppDialog dlg, string label, owned Apply apply) {
            var bar = new Box (Orientation.HORIZONTAL, 8);
            bar.margin_start = bar.margin_end = 18;
            bar.margin_bottom = 16;
            bar.margin_top = 4;
            var spacer = new Box (Orientation.HORIZONTAL, 0);
            spacer.hexpand = true;
            bar.append (spacer);
            var cancel = new Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => dlg.close ());
            dlg.set_cancel_button (cancel);
            var ok = new Button.with_label (label);
            ok.add_css_class ("suggested-action");
            ok.clicked.connect (() => {
                apply ();
                dlg.close ();
            });
            bar.append (cancel);
            bar.append (ok);
            dlg.content_box.append (bar);
            dlg.default_widget = ok;
            return ok;
        }

        public static void export_image (DrawWindow win, int format = 0) {
            var dlg = make (win, _("Export as Image"), 420, 560);
            var box = body (dlg);
            string[] formats = { _("PNG"), _("JPEG"), _("OpenRaster") };
            var fg = new PreferencesGroup (_("Format"), _("PNG keeps every detail and transparency. JPEG makes smaller files for photos. OpenRaster keeps paint layers for other painting apps."));
            var fmt = new SelectionRow (_("File Type"), formats, formats[format.clamp (0, 2)]);
            fg.add_row (fmt);
            var quality = new SpinRow (_("JPEG Quality"), _("Higher keeps more detail"), 10, 100, 5, 90);
            quality.spin_btn.digits = 0;
            fg.add_row (quality);
            box.append (fg);
            var g = new PreferencesGroup (_("Image"));
            string[] areas = { _("Whole Page"), _("Drawing Only"), _("Selection") };
            var area = new SelectionRow (_("Area"), win.canvas.selection.size > 0 ? areas : areas[0:2], win.canvas.selection.size > 0 ? areas[2] : areas[0]);
            g.add_row (area);
            var scale = new SpinRow (_("Scale"), _("2 doubles the resolution"), 0.25, 8, 0.25, 2);
            scale.spin_btn.digits = 2;
            g.add_row (scale);
            var transparent = new SwitchRow (_("Transparent Background"), null, false);
            g.add_row (transparent);
            box.append (g);
            int current = format.clamp (0, 2);
            DrawWindow.ActionHandler sync = () => {
                quality.visible = current == 1;
                transparent.visible = current == 0;
                g.visible = current != 2;
            };
            sync ();
            fmt.selected.connect ((item) => {
                for (int i = 0; i < formats.length; i++) if (formats[i] == item) current = i;
                sync ();
            });
            footer (dlg, _("Export"), () => {
                int mode = 0;
                for (int i = 0; i < areas.length; i++) if (areas[i] == area.current_value) mode = i;
                win.export_image.begin (current, mode, scale.value, transparent.active, (int) quality.value);
            });
            dlg.open_dialog ();
        }

        public static void insert_table (DrawWindow win) {
            var dlg = make (win, _("Insert Table"), 380, 320);
            var box = body (dlg);
            var g = new PreferencesGroup (_("Table Size"));
            var rows = new SpinRow (_("Rows"), null, 1, 200, 1, 4);
            var cols = new SpinRow (_("Columns"), null, 1, 50, 1, 3);
            var header = new SwitchRow (_("Header Row"), null, true);
            g.add_row (rows);
            g.add_row (cols);
            g.add_row (header);
            box.append (g);
            footer (dlg, _("Insert"), () => win.insert_table ((int) rows.value, (int) cols.value, header.active));
            dlg.open_dialog ();
        }

        public static void add_field (DrawWindow win, Item it) {
            var dlg = make (win, _("Add Field"), 380, 300);
            var box = body (dlg);
            var g = new PreferencesGroup (_("Field"), _("Fields are kept with the shape and exported to Visio and draw.io."));
            var key = new EntryRow (_("Name"));
            var value = new EntryRow (_("Value"));
            g.add_row (key);
            g.add_row (value);
            box.append (g);
            footer (dlg, _("Add"), () => {
                string k = key.text.strip ();
                if (k == "") return;
                win.doc.begin (_("Shape Data"));
                it.set_field (k, value.text);
                win.doc.commit ();
                win.inspector.refresh ();
            });
            dlg.open_dialog ();
            key.grab_focus ();
        }

        public static void rename (DrawWindow win, string title, string current, owned RenameCallback cb) {
            var dlg = make (win, title, 380, 240);
            var box = body (dlg);
            var g = new PreferencesGroup (_("Name"));
            var entry = new EntryRow (_("Name"));
            entry.text = current;
            g.add_row (entry);
            box.append (g);
            footer (dlg, _("Rename"), () => {
                string n = entry.text.strip ();
                if (n != "") cb (n);
            });
            entry.entry_activated.connect (() => {
                string n = entry.text.strip ();
                if (n != "") cb (n);
                dlg.close ();
            });
            dlg.open_dialog ();
            entry.grab_focus ();
        }

        public delegate void RenameCallback (string name);

        public static void data_import (DrawWindow win, CsvTable table, string file_name) {
            var dlg = make (win, _("Import Data"), 460, 620);
            var box = body (dlg);
            string[] modes = { _("Org Chart"), _("One Shape per Row"), _("Link to Existing Shapes") };
            var g = new PreferencesGroup (_("Data"), _("%d rows from %s").printf (table.rows.size, file_name));
            var mode = new SelectionRow (_("Create"), modes, modes[0]);
            g.add_row (mode);
            box.append (g);
            string[] cols = {};
            foreach (string h in table.header) cols += h;
            string[] none_cols = { _("None") };
            foreach (string h in table.header) none_cols += h;
            var gc = new PreferencesGroup (_("Columns"), _("Pick which columns identify each row."));
            var id_row = new SelectionRow (_("Identifier"), cols, guess (table, { "id", "name", "employee" }, 0));
            var parent_row = new SelectionRow (_("Reports To"), none_cols, guess_none (table, { "parent", "manager", "reports to", "reports_to", "boss" }));
            var name_row = new SelectionRow (_("Name"), cols, guess (table, { "name", "full name", "title" }, 0));
            var title_row = new SelectionRow (_("Subtitle"), none_cols, guess_none (table, { "title", "role", "position", "job" }));
            gc.add_row (id_row);
            gc.add_row (parent_row);
            gc.add_row (name_row);
            gc.add_row (title_row);
            box.append (gc);
            var gs = new PreferencesGroup (_("Shapes"));
            string[] kinds = { "process", "rounded-rectangle", "ellipse", "org-person", "note", "net-server", "net-desktop" };
            string[] kind_names = {};
            foreach (string k in kinds) kind_names += ShapeLibrary.display_name (k);
            var kind_row = new SelectionRow (_("Shape"), kind_names, kind_names[0]);
            var template = new EntryRow (_("Text"));
            template.text = table.header.size > 0 ? "{" + table.header[0] + "}" : "";
            gs.add_row (kind_row);
            gs.add_row (template);
            box.append (gs);
            mode.selected.connect ((m) => {
                bool org = m == modes[0];
                parent_row.visible = org;
                title_row.visible = org;
                name_row.visible = org;
                gs.visible = m == modes[1];
                id_row.title = m == modes[2] ? _("Match Shape Text With") : _("Identifier");
            });
            gs.visible = false;
            footer (dlg, _("Import"), () => {
                int m = 0;
                for (int i = 0; i < modes.length; i++) if (modes[i] == mode.current_value) m = i;
                int id_col = table.column (id_row.current_value);
                int parent_col = table.column (parent_row.current_value);
                int name_col = table.column (name_row.current_value);
                int title_col = table.column (title_row.current_value);
                string kind = kinds[0];
                for (int i = 0; i < kinds.length; i++) if (kind_names[i] == kind_row.current_value) kind = kinds[i];
                win.import_data (table, m, id_col, parent_col, name_col, title_col, kind, template.text);
            });
            dlg.open_dialog ();
        }

        public static void data_import_source (DrawWindow win, DataSource src, bool link_only) {
            var table = src.table;
            var dlg = make (win, link_only ? _("Link Data to Shapes") : _("Diagram from Data"), 460, 660);
            var box = body (dlg);
            string[] modes = { _("Process Diagram"), _("Org Chart"), _("One Shape per Row"), _("Link to Existing Shapes") };
            var g = new PreferencesGroup (_("Data"), _("%d rows from %s. The drawing keeps a link to the source so you can refresh it.").printf (table.rows.size, src.name));
            var mode = new SelectionRow (_("Create"), modes, modes[link_only ? 3 : 0]);
            g.add_row (mode);
            box.append (g);
            string[] cols = {};
            foreach (string h in table.header) cols += h;
            string[] none_cols = { _("None") };
            foreach (string h in table.header) none_cols += h;
            var gc = new PreferencesGroup (_("Columns"), _("Pick which columns identify each row."));
            var id_row = new SelectionRow (_("Identifier"), cols, guess (table, { "id", "step id", "process step id", "name", "employee" }, 0));
            var parent_row = new SelectionRow (_("Reports To"), none_cols, guess_none (table, { "parent", "manager", "reports to", "reports_to", "boss" }));
            var name_row = new SelectionRow (_("Name"), cols, guess (table, { "name", "full name", "description", "process step description", "title" }, table.header.size > 1 ? 1 : 0));
            var title_row = new SelectionRow (_("Subtitle"), none_cols, guess_none (table, { "title", "role", "position", "job" }));
            var next_row = new SelectionRow (_("Next Step"), none_cols, guess_none (table, { "next step id", "next", "next step", "next id" }));
            var label_row = new SelectionRow (_("Connector Label"), none_cols, guess_none (table, { "connector label", "label" }));
            var type_row = new SelectionRow (_("Shape Type"), none_cols, guess_none (table, { "shape type", "type", "shape" }));
            var lane_row = new SelectionRow (_("Function or Lane"), none_cols, guess_none (table, { "function", "swimlane", "lane", "owner", "department" }));
            foreach (var r in new ActionRow[] { id_row, parent_row, name_row, title_row, next_row, label_row, type_row, lane_row }) gc.add_row (r);
            box.append (gc);
            var gs = new PreferencesGroup (_("Shapes"));
            string[] kinds = { "process", "rounded-rectangle", "ellipse", "org-person", "note", "net-server", "net-desktop" };
            string[] kind_names = {};
            foreach (string k in kinds) kind_names += ShapeLibrary.display_name (k);
            var kind_row = new SelectionRow (_("Shape"), kind_names, kind_names[0]);
            var template = new EntryRow (_("Text"));
            template.text = table.header.size > 0 ? "{" + table.header[0] + "}" : "";
            gs.add_row (kind_row);
            gs.add_row (template);
            box.append (gs);
            DrawWindow.ActionHandler sync = () => {
                string m = mode.current_value;
                bool org = m == modes[1];
                bool proc = m == modes[0];
                parent_row.visible = org;
                title_row.visible = org;
                name_row.visible = org || proc;
                next_row.visible = proc;
                label_row.visible = proc;
                type_row.visible = proc;
                lane_row.visible = proc;
                gs.visible = m == modes[2];
                id_row.title = m == modes[3] ? _("Match Shape Text With") : _("Identifier");
            };
            sync ();
            mode.selected.connect ((m) => sync ());
            footer (dlg, link_only ? _("Link") : _("Create"), () => {
                int m = 0;
                for (int i = 0; i < modes.length; i++) if (modes[i] == mode.current_value) m = i;
                var pm = new DataSources.ProcessMap ();
                pm.id_col = table.column (id_row.current_value);
                pm.text_col = table.column (name_row.current_value);
                pm.next_col = table.column (next_row.current_value);
                pm.label_col = table.column (label_row.current_value);
                pm.type_col = table.column (type_row.current_value);
                pm.lane_col = table.column (lane_row.current_value);
                string kind = kinds[0];
                for (int i = 0; i < kinds.length; i++) if (kind_names[i] == kind_row.current_value) kind = kinds[i];
                win.import_source (src, m, pm, table.column (parent_row.current_value), table.column (title_row.current_value), kind, template.text);
            });
            dlg.open_dialog ();
        }

        private static string guess (CsvTable t, string[] names, int fallback) {
            foreach (string n in names) {
                int c = t.column (n);
                if (c >= 0) return t.header[c];
            }
            return t.header.size > fallback ? t.header[fallback] : "";
        }

        private static string guess_none (CsvTable t, string[] names) {
            foreach (string n in names) {
                int c = t.column (n);
                if (c >= 0) return t.header[c];
            }
            return _("None");
        }
    }
}
