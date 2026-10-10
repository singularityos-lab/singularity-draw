using Gtk;

namespace Singularity.Apps.Draw {

    public class DrawApp : Singularity.Application {
        private static GLib.Settings? _settings = null;
        private static bool settings_checked = false;
        private static string settings_id = "dev.sinty.draw";
        public string product_name { get; private set; default = "Draw"; }
        public string product_icon { get; private set; default = "dev.sinty.draw"; }
        public string product_subtitle { get; private set; default = "Diagrams, flowcharts and vector drawings"; }
        public bool illustration_mode { get; private set; default = false; }

        public DrawApp (string id = "dev.sinty.draw", string name = "Draw", string icon = "dev.sinty.draw", string subtitle = "Diagrams, flowcharts and vector drawings", bool illustration = false) {
            Object (application_id: id, flags: ApplicationFlags.HANDLES_OPEN);
            settings_id = id;
            settings_checked = false;
            _settings = null;
            product_name = name;
            product_icon = icon;
            product_subtitle = subtitle;
            illustration_mode = illustration;
            add_main_option ("new", 0, OptionFlags.NONE, OptionArg.NONE, _("Start a new drawing"), null);
            add_main_option ("new-painting", 0, OptionFlags.NONE, OptionArg.NONE, _("Start a new painting"), null);
        }

        private uint collab_bus_id = 0;

        public override bool dbus_register (DBusConnection connection, string object_path) throws Error {
            if (!base.dbus_register (connection, object_path)) return false;
            collab_bus_id = connection.register_object ("/dev/sinty/draw/Collab", new DrawCollabBus (this));
            return true;
        }

        public override void dbus_unregister (DBusConnection connection, string object_path) {
            if (collab_bus_id != 0) connection.unregister_object (collab_bus_id);
            collab_bus_id = 0;
            base.dbus_unregister (connection, object_path);
        }

        public static GLib.Settings? settings () {
            if (!settings_checked) {
                settings_checked = true;
                var source = SettingsSchemaSource.get_default ();
                if (source != null && source.lookup (settings_id, true) != null) _settings = new GLib.Settings (settings_id);
            }
            return _settings;
        }

        protected override int handle_local_options (VariantDict options) {
            bool painting = options.contains ("new-painting");
            if (!options.contains ("new") && !painting) return -1;
            try {
                register (null);
            } catch (Error e) {
                warning ("draw: %s", e.message);
                return 1;
            }
            activate_action (painting ? "new-painting" : "new", null);
            return get_is_remote () ? 0 : -1;
        }

        protected override void startup () {
            base.startup ();
            about_version = "0.1.0";
            about_license = _("GNU General Public License, version 3 only");
            IconTheme.get_for_display (Gdk.Display.get_default ()).add_resource_path ("/dev/sinty/draw/icons");
            add_app_css (CSS);
            var new_action = new SimpleAction ("new", null);
            new_action.activate.connect (() => {
                var w = get_active_window () as DrawWindow;
                if (w != null && w.doc == null) w.new_document ();
                else {
                    var nw = new DrawWindow (this);
                    nw.present ();
                    nw.new_document ();
                }
            });
            add_action (new_action);
            var painting = new SimpleAction ("new-painting", null);
            painting.activate.connect (() => {
                var w = get_active_window () as DrawWindow;
                if (w != null && w.is_empty ()) w.new_painting ();
                else {
                    var nw = new DrawWindow (this);
                    nw.present ();
                    nw.new_painting ();
                }
            });
            add_action (painting);
            var tpl = new SimpleAction ("new-from-template", VariantType.STRING);
            tpl.activate.connect ((p) => {
                var w = get_active_window () as DrawWindow;
                var d = Templates.build (p.get_string ());
                if (w != null && w.is_empty ()) w.load_document (d);
                else {
                    var nw = new DrawWindow (this);
                    nw.present ();
                    nw.load_document (d);
                }
            });
            add_action (tpl);
            var open_action = new SimpleAction ("open", null);
            open_action.activate.connect (() => {
                var w = get_active_window () as DrawWindow;
                if (w == null) {
                    w = new DrawWindow (this);
                    w.present ();
                }
                choose_file (w);
            });
            add_action (open_action);
            var open_online = new SimpleAction ("open-online", null);
            open_online.activate.connect (() => {
                var w = get_active_window () as DrawWindow;
                if (w == null) {
                    w = new DrawWindow (this);
                    w.present ();
                }
                CloudActions.open.begin (w, (f) => open_file (f, w));
            });
            add_action (open_online);
            var quit = new SimpleAction ("quit", null);
            quit.activate.connect (() => {
                var windows = new Gee.ArrayList<Gtk.Window> ();
                foreach (var w in get_windows ()) windows.add (w);
                foreach (var w in windows) w.close ();
            });
            add_action (quit);
            var settings_action = new SimpleAction ("settings", null);
            settings_action.activate.connect (() => {
                try {
                    Singularity.Shell.ShellService shell = Bus.get_proxy_sync (BusType.SESSION, "dev.sinty.desktop", "/dev/sinty/Shell");
                    shell.open_app_settings (application_id);
                } catch (Error e) {
                    warning ("Failed to open settings: %s", e.message);
                }
            });
            add_action (settings_action);
            build_menu ();
            string[,] accels = {
                { "app.quit", "<Control>q" }, { "app.new", "<Control>n" }, { "app.open", "<Control>o" },
                { "win.save", "<Control>s" }, { "win.save-as", "<Control><Shift>s" }, { "win.print", "<Control>p" },
                { "win.export-pdf", "<Control><Shift>e" }, { "win.close-doc", "<Control>w" }, { "win.close", "<Control><Shift>w" },
                { "app.settings", "<Control>comma" }, { "win.undo", "<Control>z" },
                { "win.cut", "<Control>x" }, { "win.copy", "<Control>c" }, { "win.paste", "<Control>v" },
                { "win.duplicate", "<Control>d" }, { "win.select-all", "<Control>a" },
                { "win.select-none", "<Control><Shift>a" }, { "win.find", "<Control>f" }, { "win.replace", "<Control><Shift>h" },
                { "win.copy-style", "<Control><Shift>c" }, { "win.paste-style", "<Control><Shift>v" },
                { "win.zoom-reset", "<Control>0" }, { "win.zoom-page", "<Control><Shift>w" }, { "win.zoom-selection", "<Control><Shift>j" },
                { "win.show-shapes", "F9" }, { "win.show-inspector", "F4" }, { "win.fullscreen", "F11" },
                { "win.tool-select", "<Control>1" }, { "win.tool-text", "<Control>2" }, { "win.tool-connector", "<Control>3" },
                { "win.tool-freehand", "<Control>4" }, { "win.tool-pen", "<Control>5" }, { "win.tool-line", "<Control>6" },
                { "win.tool-rectangle", "<Control>8" }, { "win.tool-ellipse", "<Control>9" },
                { "win.insert-image", "<Control><Shift>i" }, { "win.insert-page", "<Shift>F11" },
                { "win.bold", "<Control>b" }, { "win.italic", "<Control>i" }, { "win.underline", "<Control>u" },
                { "win.text-left", "<Control><Shift>l" }, { "win.text-center", "<Control><Shift>e" }, { "win.text-right", "<Control><Shift>r" },
                { "win.font-grow", "<Control>bracketright" }, { "win.font-shrink", "<Control>bracketleft" },
                { "win.bring-front", "<Control><Shift>f" }, { "win.send-back", "<Control><Shift>b" },
                { "win.bring-forward", "<Control><Alt>f" }, { "win.send-backward", "<Control><Alt>b" },
                { "win.group", "<Control>g" }, { "win.rotate-right", "<Control>r" }, { "win.rotate-left", "<Control>l" },
                { "win.flip-h", "<Control>h" }, { "win.flip-v", "<Control>j" }, { "win.edit-text", "F2" },
                { "win.next-page", "<Control>Page_Down" }, { "win.prev-page", "<Control>Page_Up" },
                { "win.lock", "<Control><Shift>k" }, { "win.show-grid", "<Control><Shift>apostrophe" },
                { "win.tool-connection-point", "<Control>7" }, { "win.check-spelling", "F7" }, { "win.add-comment", "<Control><Alt>m" },
                { "win.check-diagram", "<Control><Shift>F7" }, { "win.refresh-data", "<Control><Alt>r" }, { "win.presentation", "F5" }
            };
            for (int i = 0; i < accels.length[0]; i++) set_accels_for_action (accels[i, 0], { accels[i, 1] });
            set_accels_for_action ("win.redo", { "<Control><Shift>z", "<Control>y" });
            set_accels_for_action ("win.ungroup", { "<Control><Shift>u", "<Control><Shift>g" });
            set_accels_for_action ("win.zoom-in", { "<Control>equal", "<Control>KP_Add" });
            set_accels_for_action ("win.zoom-out", { "<Control>underscore", "<Control>KP_Subtract" });
        }

        private static GLib.Menu section (string[,] items) {
            var m = new GLib.Menu ();
            for (int i = 0; i < items.length[0]; i++) m.append (items[i, 0], items[i, 1]);
            return m;
        }

        private static GLib.Menu sub (string label, GLib.Menu menu) {
            var s = new GLib.Menu ();
            s.append_submenu (label, menu);
            return s;
        }

        private void build_menu () {
            var menu = new GLib.Menu ();

            var file = new GLib.Menu ();
            var templates = new GLib.Menu ();
            foreach (var info in Templates.list ()) templates.append (info.name, "app.new-from-template::" + info.id);
            var new_section = section ({ { _("New"), "app.new" }, { _("New Painting"), "app.new-painting" } });
            new_section.append_submenu (_("New from Template"), templates);
            new_section.append (_("Open…"), "app.open");
            new_section.append (_("Open from Online Account…"), "app.open-online");
            file.append_section (null, new_section);
            file.append_section (null, section ({ { _("Save"), "win.save" }, { _("Save As…"), "win.save-as" }, { _("Save to Online Account…"), "win.save-online" }, { _("Sync with Online Account"), "win.sync-online" } }));
            file.append_section (null, section ({ { _("Import Drawing…"), "win.import" }, { _("Import Data…"), "win.import-data" } }));
            var export = section ({
                { _("PDF…"), "win.export-pdf" }, { _("SVG…"), "win.export-svg" }, { _("PNG Image…"), "win.export-png" },
                { _("JPEG Image…"), "win.export-jpeg" }, { _("OpenRaster Image…"), "win.export-ora" },
                { _("Visio Drawing…"), "win.export-vsdx" }, { _("OpenDocument Drawing…"), "win.export-odg" },
                { _("Flat OpenDocument Drawing…"), "win.export-fodg" }, { _("draw.io Diagram…"), "win.export-drawio" },
                { _("Web Page…"), "win.export-html" }, { _("PowerPoint Presentation…"), "win.export-pptx" },
                { _("Slide Snippets…"), "win.slide-snippets" }, { _("Shape Data as CSV…"), "win.export-data" }
            });
            var export_section = sub (_("Export As"), export);
            export_section.append (_("Print…"), "win.print");
            export_section.append (_("Share…"), "win.share");
            file.append_section (null, export_section);
            file.append_section (null, section ({ { _("Close Drawing"), "win.close-doc" } }));
            file.append_section (null, section ({ { _("Close Window"), "win.close" }, { _("Quit"), "app.quit" } }));
            menu.append_submenu (_("File"), file);

            var edit = new GLib.Menu ();
            edit.append_section (null, section ({ { _("Undo"), "win.undo" }, { _("Redo"), "win.redo" } }));
            edit.append_section (null, section ({ { _("Cut"), "win.cut" }, { _("Copy"), "win.copy" }, { _("Paste"), "win.paste" }, { _("Duplicate"), "win.duplicate" }, { _("Delete"), "win.delete" } }));
            edit.append_section (null, section ({ { _("Copy Style"), "win.copy-style" }, { _("Paste Style"), "win.paste-style" }, { _("Format Painter"), "win.format-painter" } }));
            edit.append_section (null, section ({ { _("Select All"), "win.select-all" }, { _("Select None"), "win.select-none" }, { _("Find…"), "win.find" }, { _("Replace…"), "win.replace" } }));
            edit.append_section (null, section ({ { _("Edit Text"), "win.edit-text" }, { _("Edit Points"), "win.edit-points" }, { _("Smooth or Corner Point"), "win.smooth-point" } }));
            edit.append_section (null, section ({ { _("Settings"), "app.settings" } }));
            menu.append_submenu (_("Edit"), edit);

            var view = new GLib.Menu ();
            view.append_section (null, section ({ { _("Zoom In"), "win.zoom-in" }, { _("Zoom Out"), "win.zoom-out" }, { _("Actual Size"), "win.zoom-reset" }, { _("Fit Page"), "win.zoom-page" }, { _("Fit Selection"), "win.zoom-selection" } }));
            view.append_section (null, section ({ { _("Shapes"), "win.show-shapes" }, { _("Format Panel"), "win.show-inspector" }, { _("Rulers"), "win.show-rulers" }, { _("Mini Map"), "win.show-minimap" } }));
            view.append_section (null, section ({ { _("Grid"), "win.show-grid" }, { _("Snap to Grid"), "win.snap-grid" }, { _("Smart Guides"), "win.snap-objects" } }));
            view.append_section (null, section ({ { _("Paint Mode"), "win.paint-mode" }, { _("Present"), "win.presentation" }, { _("Full Screen"), "win.fullscreen" } }));
            menu.append_submenu (_("View"), view);

            var insert = new GLib.Menu ();
            var tools = section ({
                { _("Select"), "win.tool-select" }, { _("Pan"), "win.tool-hand" }, { _("Text"), "win.tool-text" }, { _("Connector"), "win.tool-connector" },
                { _("Rectangle"), "win.tool-rectangle" }, { _("Ellipse"), "win.tool-ellipse" }, { _("Line"), "win.tool-line" },
                { _("Pen"), "win.tool-pen" }, { _("Freehand"), "win.tool-freehand" }
            });
            insert.append_section (null, sub (_("Tool"), tools));
            insert.append_section (null, section ({ { _("Image…"), "win.insert-image" }, { _("Table…"), "win.insert-table" }, { _("Container"), "win.insert-container" }, { _("Swimlane Pool"), "win.insert-swimlane" } }));
            insert.append_section (null, section ({ { _("Page"), "win.insert-page" }, { _("Layer"), "win.add-layer" }, { _("Paint Layer"), "win.add-paint-layer" }, { _("Image as Paint Layer…"), "win.import-layer" }, { _("Field…"), "win.add-field" } }));
            menu.append_submenu (_("Insert"), insert);

            var format = new GLib.Menu ();
            var text = section ({ { _("Bold"), "win.bold" }, { _("Italic"), "win.italic" }, { _("Underline"), "win.underline" }, { _("Larger"), "win.font-grow" }, { _("Smaller"), "win.font-shrink" } });
            var align = section ({ { _("Left"), "win.text-left" }, { _("Center"), "win.text-center" }, { _("Right"), "win.text-right" } });
            var route = section ({ { _("Straight"), "win.route-straight" }, { _("Orthogonal"), "win.route-orthogonal" }, { _("Curved"), "win.route-curved" }, { _("Reset Bends"), "win.reset-bends" } });
            var subs = new GLib.Menu ();
            subs.append_submenu (_("Text"), text);
            subs.append_submenu (_("Text Alignment"), align);
            subs.append_submenu (_("Connector Style"), route);
            format.append_section (null, subs);
            format.append_section (null, section ({ { _("Shadow"), "win.shadow" }, { _("Reset Style"), "win.reset-style" } }));
            menu.append_submenu (_("Format"), format);

            var arrange = new GLib.Menu ();
            var order = section ({ { _("Bring to Front"), "win.bring-front" }, { _("Bring Forward"), "win.bring-forward" }, { _("Send Backward"), "win.send-backward" }, { _("Send to Back"), "win.send-back" } });
            var al = section ({ { _("Left"), "win.align-left" }, { _("Center"), "win.align-center" }, { _("Right"), "win.align-right" }, { _("Top"), "win.align-top" }, { _("Middle"), "win.align-middle" }, { _("Bottom"), "win.align-bottom" } });
            var dist = section ({ { _("Horizontally"), "win.distribute-h" }, { _("Vertically"), "win.distribute-v" }, { _("Same Width"), "win.same-width" }, { _("Same Height"), "win.same-height" } });
            var rot = section ({ { _("Rotate Right 90°"), "win.rotate-right" }, { _("Rotate Left 90°"), "win.rotate-left" }, { _("Flip Horizontal"), "win.flip-h" }, { _("Flip Vertical"), "win.flip-v" } });
            var arr_subs = new GLib.Menu ();
            arr_subs.append_submenu (_("Order"), order);
            arr_subs.append_submenu (_("Align"), al);
            arr_subs.append_submenu (_("Distribute and Size"), dist);
            arr_subs.append_submenu (_("Rotate and Flip"), rot);
            arrange.append_section (null, arr_subs);
            arrange.append_section (null, section ({ { _("Group"), "win.group" }, { _("Ungroup"), "win.ungroup" }, { _("Lock"), "win.lock" } }));
            var ops = section ({ { _("Union"), "win.path-union" }, { _("Subtract"), "win.path-subtract" }, { _("Intersect"), "win.path-intersect" }, { _("Exclude"), "win.path-exclude" }, { _("Convert to Path"), "win.convert-path" } });
            var lay = section ({ { _("Tree, Top Down"), "win.layout-tree" }, { _("Tree, Left to Right"), "win.layout-tree-right" }, { _("Hierarchical"), "win.layout-hierarchical" }, { _("Hierarchical, Left to Right"), "win.layout-hierarchical-right" }, { _("Force-Directed"), "win.layout-force" }, { _("Circle"), "win.layout-circle" }, { _("Grid"), "win.layout-grid" } });
            var arr2 = new GLib.Menu ();
            arr2.append_submenu (_("Shape Operations"), ops);
            arr2.append_submenu (_("Auto Layout"), lay);
            arrange.append_section (null, arr2);
            menu.append_submenu (_("Arrange"), arrange);

            var page = new GLib.Menu ();
            page.append_section (null, section ({ { _("New Page"), "win.insert-page" }, { _("Duplicate Page"), "win.duplicate-page" }, { _("Rename Page"), "win.rename-page" }, { _("Delete Page"), "win.delete-page" } }));
            page.append_section (null, section ({ { _("Next Page"), "win.next-page" }, { _("Previous Page"), "win.prev-page" } }));
            page.append_section (null, section ({ { _("Page Setup"), "win.page-setup" }, { _("Fit Page to Drawing"), "win.fit-page-to-drawing" } }));
            menu.append_submenu (_("Page"), page);

            var data = new GLib.Menu ();
            data.append_section (null, section ({ { _("Import Data…"), "win.import-data" }, { _("Export Shape Data…"), "win.export-data" }, { _("Add Field…"), "win.add-field" } }));
            menu.append_submenu (_("Data"), data);

            set_menubar (menu);
        }

        public override void activate () {
            var w = get_active_window ();
            if (w == null) w = new DrawWindow (this);
            w.present ();
            var dw = w as DrawWindow;
            if (dw != null) TestScript.maybe_run (dw);
        }

        public override void open (File[] files, string hint) {
            foreach (var f in files) open_file (f, null);
        }

        public void open_file (File file, DrawWindow? target) {
            string? path = file.get_path ();
            if (path == null) return;
            foreach (var w in get_windows ()) {
                var dw = w as DrawWindow;
                if (dw != null && dw.doc != null && dw.doc.path == path) {
                    dw.present ();
                    return;
                }
            }
            DrawWindow? win = target != null && target.is_empty () ? target : null;
            if (win == null) {
                foreach (var w in get_windows ()) {
                    var dw = w as DrawWindow;
                    if (dw != null && dw.is_empty ()) win = dw;
                }
            }
            if (win == null) win = new DrawWindow (this);
            win.present ();
            try {
                var d = Formats.load (path);
                win.load_document (d);
                if (Singularity.Runtime.file_history_enabled ()) RecentManager.get_default ().add_item (file.get_uri ());
            } catch (Error e) {
                win.show_error (_("Could Not Open"), _("\"%s\" could not be opened: %s").printf (file.get_basename (), e.message));
            }
        }

        public void choose_file (DrawWindow parent) {
            var dialog = new FileDialog ();
            dialog.title = _("Open Drawing");
            var filters = new GLib.ListStore (typeof (FileFilter));
            var all = new FileFilter ();
            all.name = _("Drawings");
            foreach (string s in Formats.open_suffixes ()) all.add_suffix (s);
            filters.append (all);
            dialog.filters = filters;
            dialog.open.begin (parent, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file != null) open_file (file, parent);
                } catch (Error e) {
                }
            });
        }

        private const string CSS = """
.draw-canvas-frame {
    margin: 0 0 0 12px;
    border-radius: 12px 12px 0 0;
    border: 1px solid alpha(@window_fg_color, 0.1);
    border-bottom: none;
}

.draw-ruler,
.draw-ruler-corner {
    background-color: alpha(@window_fg_color, 0.04);
}

.draw-ruler-corner {
    border-top-left-radius: 12px;
}

.draw-tools {
    background-color: @popover_bg_color;
    border-radius: 14px;
    padding: 4px;
    box-shadow: 0 2px 10px alpha(black, 0.18), 0 0 0 1px alpha(@window_fg_color, 0.08);
}

.draw-tool {
    min-width: 32px;
    min-height: 32px;
    padding: 0;
    border-radius: 10px;
}

.draw-tool:checked {
    background-color: @accent_bg_color;
    color: @accent_fg_color;
}

.draw-tools-separator {
    margin: 3px 6px;
    background-color: alpha(@window_fg_color, 0.12);
    min-height: 1px;
}

.draw-layer-thumb {
    border-radius: 4px;
    margin-right: 4px;
}

.draw-active-layer {
    background-color: alpha(@accent_bg_color, 0.12);
}

.draw-minimap {
    background-color: @popover_bg_color;
    border-radius: 12px;
    box-shadow: 0 2px 10px alpha(black, 0.18), 0 0 0 1px alpha(@window_fg_color, 0.08);
}

.draw-inspector {
    border-left: 1px solid alpha(@window_fg_color, 0.08);
}

.draw-tile {
    padding: 3px;
    border-radius: 8px;
}

.draw-tiles {
    margin-bottom: 8px;
}

.draw-stencil-header {
    margin: 2px 4px 0 4px;
}

.draw-stencil-toggle {
    padding: 4px 6px;
    border-radius: 8px;
}

.draw-more-shapes {
    border-radius: 99px;
}

.draw-theme-button {
    padding: 2px;
    border-radius: 8px;
}

.draw-theme-active {
    box-shadow: 0 0 0 2px @accent_bg_color;
}

.draw-quick-style {
    padding: 1px;
    border-radius: 6px;
}

.draw-comment {
    padding: 6px 8px;
    border-radius: 10px;
    background-color: alpha(#f5c518, 0.14);
}

.draw-presentation {
    background-color: #0f0f12;
}

.draw-status {
    font-feature-settings: "tnum";
    font-size: 12px;
    margin: 0 8px;
}

.draw-zoom {
    border-radius: 99px;
    font-feature-settings: "tnum";
    font-size: 12px;
    min-height: 26px;
    padding: 0 10px;
}

.draw-template-card {
    padding: 8px;
    border-radius: 12px;
}

.draw-template-thumb {
    border-radius: 8px;
    box-shadow: 0 0 0 1px alpha(@window_fg_color, 0.12);
}

.draw-recent-list {
    border-radius: 14px;
}

.draw-recent-row {
    border-radius: 10px;
    padding: 8px 10px;
}

.draw-present-bar {
    background-color: alpha(black, 0.55);
    border-radius: 12px;
    padding: 6px;
}

.draw-present-bar button {
    background: alpha(white, 0.14);
    box-shadow: none;
    border: none;
}

.draw-present-bar button label {
    color: white;
}

.draw-rich-bar {
    background-color: @popover_bg_color;
    border-radius: 10px;
    padding: 4px;
    box-shadow: 0 0 0 1px alpha(black, 0.12), 0 6px 18px alpha(black, 0.18);
}

.draw-text-frame {
    background-color: alpha(white, 0.96);
    border-radius: 4px;
    box-shadow: 0 0 0 2px @accent_bg_color, 0 6px 18px alpha(black, 0.18);
}

textview.draw-text-editor,
textview.draw-text-editor text {
    background-color: transparent;
    color: #1e1e1e;
}

.draw-color-button {
    padding: 4px;
    min-height: 0;
}

.draw-swatch {
    padding: 2px;
    min-width: 0;
    min-height: 0;
    border-radius: 99px;
    background: transparent;
    box-shadow: none;
}

.draw-swatch:hover {
    background-color: alpha(@window_fg_color, 0.1);
}

.draw-toggle {
    min-width: 26px;
    min-height: 26px;
    padding: 2px;
    border-radius: 8px;
}

.draw-toggle:checked {
    background-color: alpha(@accent_bg_color, 0.2);
}
""";
    }

#if !VECTOR_REUSE
    public static int main (string[] args) {
        Intl.setlocale (LocaleCategory.ALL, "");
        string locale_dir = "/usr/share/locale";
        try {
            string exe = FileUtils.read_link ("/proc/self/exe");
            locale_dir = Path.build_filename (Path.get_dirname (Path.get_dirname (exe)), "share", "locale");
        } catch (Error e) {
        }
        Intl.bindtextdomain ("singularity-draw", locale_dir);
        Intl.bind_textdomain_codeset ("singularity-draw", "UTF-8");
        Intl.textdomain ("singularity-draw");
        return new DrawApp ().run (args);
    }
#endif
}
