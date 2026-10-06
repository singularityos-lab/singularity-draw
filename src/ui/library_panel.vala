using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class ShapeTile : Button {
        public LibEntry entry;
        public signal void context_requested (ShapeTile tile, double x, double y);

        public ShapeTile (LibEntry entry) {
            this.entry = entry;
            add_css_class ("flat");
            add_css_class ("draw-tile");
            tooltip_text = entry.name;
            var area = new DrawingArea ();
            area.set_size_request (46, 38);
            area.set_draw_func ((a, cr, w, h) => paint_preview (cr, entry.kind, w, h, a.get_color ()));
            child = area;
            update_property (AccessibleProperty.LABEL, entry.name, -1);
            var source = new DragSource ();
            source.actions = Gdk.DragAction.COPY;
            source.prepare.connect ((x, y) => new Gdk.ContentProvider.for_value ("sdraw-kind:" + entry.kind));
            source.drag_begin.connect ((drag) => {
                var snap = new Gtk.Snapshot ();
                var bounds = Graphene.Rect ();
                bounds.init (0, 0, 60, 50);
                var cr = snap.append_cairo (bounds);
                paint_preview (cr, entry.kind, 60, 50, area.get_color ());
                var paintable = snap.free_to_paintable (null);
                source.set_icon (paintable, 30, 25);
            });
            add_controller (source);
            var right = new GestureClick ();
            right.button = Gdk.BUTTON_SECONDARY;
            right.pressed.connect ((n, x, y) => context_requested (this, x, y));
            add_controller (right);
        }

        public static void paint_preview (Cairo.Context cr, string kind, double w, double h, Gdk.RGBA fg) {
            var master = UserStencils.find_master (kind);
            if (master != null) {
                paint_master (cr, master, w, h);
                return;
            }
            var e = ShapeLibrary.find (kind);
            double ew = e != null ? e.w : 100, eh = e != null ? double.max (e.h, 1) : 60;
            var s = new Shape (kind, 0, 0, ew, eh);
            ShapeLibrary.apply_defaults (s);
            string ink = Colors.to_hex (Rgba (fg.red, fg.green, fg.blue, 1));
            bool colored = false;
            var probe = s.geometry ();
            foreach (var part in probe.parts) if (part.color != null && part.color.has_prefix ("#")) colored = true;
            if (!colored) {
                s.style.stroke = ink;
                if (s.style.fill_kind != FillKind.NONE) {
                    s.style.fill_kind = FillKind.SOLID;
                    s.style.fill = Colors.to_hex (Rgba (fg.red, fg.green, fg.blue, 0.1), true);
                }
            }
            if (kind == "text") {
                cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.8);
                var layout = Pango.cairo_create_layout (cr);
                layout.set_font_description (Pango.FontDescription.from_string ("Serif Bold 16"));
                layout.set_text ("Aa", -1);
                int lw, lh;
                layout.get_pixel_size (out lw, out lh);
                cr.move_to ((w - lw) / 2, (h - lh) / 2);
                Pango.cairo_show_layout (cr, layout);
                return;
            }
            var g = s.geometry ();
            var bounds = Rect.empty ();
            foreach (var part in g.parts) bounds = bounds.union (part.path.control_bounds ());
            if (bounds.is_empty ()) return;
            double sc = double.min ((w - 6) / double.max (bounds.w, 1), (h - 6) / double.max (bounds.h, 1));
            cr.save ();
            cr.translate ((w - bounds.w * sc) / 2, (h - bounds.h * sc) / 2);
            cr.scale (sc, sc);
            cr.translate (-bounds.x, -bounds.y);
            s.style.stroke_width = 1.4 / sc;
            var opts = new RenderOptions ();
            opts.editing_id = s.id;
            Renderer.draw_shape (cr, s, opts);
            cr.restore ();
        }

        private static void paint_master (Cairo.Context cr, StencilMaster m, double w, double h) {
            var items = m.items ();
            var b = Document.selection_bounds (items);
            if (b.is_empty ()) return;
            double sc = double.min ((w - 6) / double.max (b.w, 1), (h - 6) / double.max (b.h, 1));
            cr.save ();
            cr.translate ((w - b.w * sc) / 2, (h - b.h * sc) / 2);
            cr.scale (sc, sc);
            cr.translate (-b.x, -b.y);
            var page = new Page ();
            foreach (var it in items) page.items.add (it);
            Router.route_all (page);
            var opts = new RenderOptions ();
            opts.background = false;
            opts.draw_hidden_text = false;
            Renderer.draw_page (cr, page, opts);
            cr.restore ();
        }
    }

    private class StencilSection : Box {
        public LibCategory category;
        public FlowBox flow;
        private Revealer revealer;
        private bool filled = false;
        private Image arrow;
        public signal void close_requested ();
        public signal void tile_created (ShapeTile tile);
        public signal void collapsed_changed (bool collapsed);
        public signal void menu_requested (Widget anchor);

        public StencilSection (LibCategory category, bool collapsed) {
            Object (orientation: Orientation.VERTICAL, spacing: 0);
            this.category = category;
            var header = new Box (Orientation.HORIZONTAL, 2);
            header.add_css_class ("draw-stencil-header");
            var toggle = new Button ();
            toggle.add_css_class ("flat");
            toggle.add_css_class ("draw-stencil-toggle");
            toggle.hexpand = true;
            var tbox = new Box (Orientation.HORIZONTAL, 6);
            arrow = new Image.from_icon_name (collapsed ? "pan-end-symbolic" : "pan-down-symbolic");
            tbox.append (arrow);
            var label = new Label (category.name);
            label.halign = Align.START;
            label.hexpand = true;
            label.ellipsize = Pango.EllipsizeMode.END;
            label.add_css_class ("heading");
            tbox.append (label);
            toggle.child = tbox;
            toggle.tooltip_text = category.name;
            toggle.clicked.connect (() => set_collapsed (revealer.reveal_child));
            header.append (toggle);
            if (category.user) {
                var more = new Button.from_icon_name ("view-more-symbolic");
                more.add_css_class ("flat");
                more.valign = Align.CENTER;
                more.tooltip_text = _("Stencil Options");
                more.clicked.connect (() => menu_requested (more));
                header.append (more);
            }
            var close = new Button.from_icon_name ("window-close-symbolic");
            close.add_css_class ("flat");
            close.valign = Align.CENTER;
            close.tooltip_text = _("Close Stencil");
            close.clicked.connect (() => close_requested ());
            header.append (close);
            append (header);
            flow = new FlowBox ();
            flow.selection_mode = SelectionMode.NONE;
            flow.homogeneous = true;
            flow.max_children_per_line = 8;
            flow.min_children_per_line = 3;
            flow.column_spacing = 2;
            flow.row_spacing = 2;
            flow.add_css_class ("draw-tiles");
            revealer = new Revealer ();
            revealer.transition_type = RevealerTransitionType.SLIDE_DOWN;
            revealer.transition_duration = 160;
            revealer.child = flow;
            revealer.reveal_child = !collapsed;
            append (revealer);
            if (!collapsed) fill ();
        }

        public void set_collapsed (bool c) {
            if (!c) fill ();
            revealer.reveal_child = !c;
            arrow.icon_name = c ? "pan-end-symbolic" : "pan-down-symbolic";
            collapsed_changed (c);
        }

        public void refill () {
            Widget? child;
            while ((child = flow.get_first_child ()) != null) flow.remove (child);
            filled = false;
            if (revealer.reveal_child) fill ();
        }

        private void fill () {
            if (filled) return;
            filled = true;
            foreach (var e in ShapeLibrary.all_entries ()) {
                if (e.category != category.id) continue;
                var tile = new ShapeTile (e);
                tile_created (tile);
                flow.append (tile);
            }
            if (flow.get_first_child () == null) {
                var hint = new Label (category.user ? _("Drag shapes here, or use Add Selection to Stencil.") : _("No shapes"));
                hint.add_css_class ("dim-label");
                hint.wrap = true;
                hint.margin_start = hint.margin_end = 8;
                hint.margin_bottom = 8;
                flow.append (hint);
            }
        }
    }

    public class LibraryPanel : AppSidebar {
        private DrawWindow? win = null;
        private Canvas? canvas;
        private Box sections;
        private Box results_box;
        private FlowBox results;
        private StatusPage empty;
        private Gee.ArrayList<string> open_ids = new Gee.ArrayList<string> ();
        private Gee.HashSet<string> collapsed = new Gee.HashSet<string> ();
        private Gee.HashMap<string, StencilSection> section_map = new Gee.HashMap<string, StencilSection> ();
        private string query = "";
        public string last_category = "flowchart";
        public signal void shape_chosen (string kind);

        public LibraryPanel () {
            base (240);
            Singularity.Widgets.apply_titlebar_inset (box);
            var search = add_bubble_search (_("Search Shapes"), (text) => filter (text));
            search.entry.input_hints = InputHints.NO_SPELLCHECK | InputHints.NO_EMOJI;
            var bar = new Box (Orientation.HORIZONTAL, 6);
            bar.margin_start = bar.margin_end = 6;
            bar.margin_bottom = 6;
            var more = new Button.with_label (_("More Shapes"));
            more.hexpand = true;
            more.add_css_class ("draw-more-shapes");
            more.clicked.connect (() => more_menu (more));
            bar.append (more);
            var mine = new Button.from_icon_name ("list-add-symbolic");
            mine.tooltip_text = _("My Shapes");
            mine.clicked.connect (() => my_shapes_menu (mine));
            bar.append (mine);
            box.append (bar);
            results_box = new Box (Orientation.VERTICAL, 4);
            results_box.visible = false;
            results_box.append (new SidebarSectionLabel (_("Search Results")));
            results = new FlowBox ();
            results.selection_mode = SelectionMode.NONE;
            results.homogeneous = true;
            results.max_children_per_line = 8;
            results.min_children_per_line = 3;
            results.column_spacing = 2;
            results.row_spacing = 2;
            results.add_css_class ("draw-tiles");
            results_box.append (results);
            box.append (results_box);
            sections = new Box (Orientation.VERTICAL, 2);
            box.append (sections);
            empty = new StatusPage ();
            empty.icon_name = "edit-find";
            empty.title = _("No Shapes Found");
            empty.description = _("Try a different name, such as process, server or actor.");
            empty.visible = false;
            box.append (empty);
            var settings = DrawApp.settings ();
            if (settings != null) {
                foreach (string id in settings.get_strv ("open-stencils")) open_ids.add (id);
                foreach (string id in settings.get_strv ("collapsed-stencils")) collapsed.add (id);
            } else {
                foreach (string id in new string[] { "basic", "arrows", "flowchart", "containers" }) open_ids.add (id);
            }
            rebuild ();
        }

        public void set_window (DrawWindow w) {
            win = w;
        }

        public void set_canvas (Canvas c) {
            canvas = c;
        }

        private LibCategory? category (string id) {
            foreach (var c in ShapeLibrary.categories ()) if (c.id == id) return c;
            return null;
        }

        private void save_state () {
            var settings = DrawApp.settings ();
            if (settings == null) return;
            string[] open = {};
            foreach (string id in open_ids) open += id;
            string[] closed = {};
            foreach (string id in collapsed) closed += id;
            settings.set_strv ("open-stencils", open);
            settings.set_strv ("collapsed-stencils", closed);
        }

        public bool is_open (string id) {
            return open_ids.contains (id);
        }

        public void open_stencil (string id, bool scroll = true) {
            open_ids.remove (id);
            open_ids.insert (0, id);
            collapsed.remove (id);
            save_state ();
            rebuild ();
            last_category = id;
        }

        public void close_stencil (string id) {
            open_ids.remove (id);
            save_state ();
            rebuild ();
        }

        public void rebuild () {
            Widget? child;
            while ((child = sections.get_first_child ()) != null) sections.remove (child);
            section_map.clear ();
            foreach (string id in open_ids) {
                var cat = category (id);
                if (cat == null) continue;
                var sec = new StencilSection (cat, collapsed.contains (id));
                sec.tile_created.connect (hook_tile);
                sec.close_requested.connect (() => close_stencil (cat.id));
                sec.collapsed_changed.connect ((c) => {
                    if (c) collapsed.add (cat.id);
                    else collapsed.remove (cat.id);
                    save_state ();
                });
                sec.menu_requested.connect ((anchor) => user_stencil_menu (cat.id.substring (5), anchor));
                section_map[id] = sec;
                sections.append (sec);
            }
            if (query != "") filter (query);
        }

        private void hook_tile (ShapeTile tile) {
            tile.clicked.connect (() => {
                last_category = tile.entry.category;
                shape_chosen (tile.entry.kind);
            });
            tile.context_requested.connect ((t, x, y) => tile_menu (t));
        }

        public string[] quick_kinds () {
            string[] kinds = {};
            foreach (var e in ShapeLibrary.all_entries ()) {
                if (e.category != last_category) continue;
                if (e.kind == "text" || e.kind == "line-shape") continue;
                var s = new Shape (e.kind);
                if (s.is_container ()) continue;
                kinds += e.kind;
                if (kinds.length >= 4) break;
            }
            if (kinds.length == 0) kinds = { "process", "decision", "terminator", "data" };
            return kinds;
        }

        private void filter (string text) {
            query = text.strip ().casefold ();
            Widget? child;
            while ((child = results.get_first_child ()) != null) results.remove (child);
            if (query == "") {
                results_box.visible = false;
                sections.visible = true;
                empty.visible = false;
                return;
            }
            int shown = 0;
            foreach (var e in ShapeLibrary.all_entries ()) {
                bool match = e.name.casefold ().contains (query) || e.kind.contains (query) || e.keywords.casefold ().contains (query);
                if (!match) {
                    var cat = category (e.category);
                    match = cat != null && cat.name.casefold ().contains (query);
                }
                if (!match) continue;
                var tile = new ShapeTile (e);
                string cname = category (e.category) != null ? category (e.category).name : "";
                tile.tooltip_text = cname != "" ? "%s (%s)".printf (e.name, cname) : e.name;
                hook_tile (tile);
                results.append (tile);
                if (++shown >= 240) break;
            }
            results_box.visible = shown > 0;
            sections.visible = false;
            empty.visible = shown == 0;
        }

        private void more_menu (Widget anchor) {
            var menu = new ContextMenu (anchor);
            foreach (string group in StencilGroup.order ()) {
                var cats = new Gee.ArrayList<LibCategory> ();
                foreach (var c in ShapeLibrary.categories ()) if (c.group == group) cats.add (c);
                if (cats.size == 0 && group != StencilGroup.CUSTOM) continue;
                var sub = menu.add_submenu (StencilGroup.label (group), null);
                foreach (var c in cats) {
                    var cat = c;
                    bool open = open_ids.contains (cat.id);
                    sub.add_item (cat.name, open ? "object-select-symbolic" : null, () => {
                        if (open_ids.contains (cat.id)) close_stencil (cat.id);
                        else open_stencil (cat.id);
                    });
                }
                if (group == StencilGroup.CUSTOM) {
                    if (cats.size > 0) sub.add_separator ();
                    sub.add_item (_("New Stencil"), "list-add-symbolic", () => new_stencil ());
                    sub.add_item (_("Import Stencil…"), "document-open-symbolic", () => import_stencil ());
                }
            }
            menu.add_separator ();
            menu.add_item (_("Open All Stencils"), null, () => {
                foreach (var c in ShapeLibrary.categories ()) if (!open_ids.contains (c.id)) open_ids.add (c.id);
                foreach (var c in ShapeLibrary.categories ()) collapsed.add (c.id);
                save_state ();
                rebuild ();
            });
            menu.add_item (_("Close All Stencils"), null, () => {
                open_ids.clear ();
                save_state ();
                rebuild ();
            });
            DrawWindow.popup_menu (menu);
        }

        private void my_shapes_menu (Widget anchor) {
            var menu = new ContextMenu (anchor);
            bool has_sel = canvas != null && canvas.selection.size > 0;
            if (has_sel) {
                menu.add_item (_("Add Selection to Favorites"), "starred-symbolic", () => add_selection (UserStencils.my_shapes ()));
                var others = new Gee.ArrayList<UserStencil> ();
                foreach (var s in UserStencils.stencils ()) if (s.id != UserStencils.MY_SHAPES) others.add (s);
                if (others.size > 0) {
                    var sub = menu.add_submenu (_("Add Selection to Stencil"), "list-add-symbolic");
                    foreach (var s in others) {
                        var st = s;
                        sub.add_item (st.name, null, () => add_selection (st));
                    }
                }
                menu.add_separator ();
            }
            menu.add_item (_("New Stencil"), "list-add-symbolic", () => new_stencil ());
            menu.add_item (_("Import Stencil…"), "document-open-symbolic", () => import_stencil ());
            DrawWindow.popup_menu (menu);
        }

        private void user_stencil_menu (string stencil_id, Widget anchor) {
            var st = UserStencils.find (stencil_id);
            if (st == null || win == null) return;
            var menu = new ContextMenu (anchor);
            if (canvas != null && canvas.selection.size > 0) menu.add_item (_("Add Selection"), "list-add-symbolic", () => add_selection (st));
            menu.add_item (_("Rename"), "document-edit-symbolic", () => Dialogs.rename (win, _("Rename Stencil"), st.name, (n) => {
                st.name = n;
                persist (st);
                rebuild ();
            }));
            menu.add_item (_("Export as Visio Stencil…"), "document-save-as-symbolic", () => win.export_stencil.begin (st));
            menu.add_separator ();
            menu.add_item (_("Delete Stencil"), "user-trash-symbolic", () => {
                var dlg = new ConfirmDialog ((Gtk.Application) win.application, _("Delete Stencil?"), "user-trash-symbolic",
                    _("\"%s\" and its shapes will be deleted.").printf (st.name), _("Delete"), ConfirmDialog.ActionStyle.DESTRUCTIVE);
                dlg.transient_for = win;
                dlg.response.connect ((r) => {
                    if (r != ConfirmDialog.Response.PRIMARY) return;
                    UserStencils.remove (st);
                    open_ids.remove ("user:" + st.id);
                    save_state ();
                    rebuild ();
                });
                dlg.present ();
            }, "destructive");
            DrawWindow.popup_menu (menu);
        }

        private void tile_menu (ShapeTile tile) {
            if (win == null) return;
            var menu = new ContextMenu (tile);
            string kind = tile.entry.kind;
            menu.add_item (_("Insert"), "list-add-symbolic", () => shape_chosen (kind));
            string sid, mid;
            if (UserStencils.split_kind (kind, out sid, out mid)) {
                var st = UserStencils.find (sid);
                var m = UserStencils.find_master (kind);
                if (st != null && m != null) {
                    menu.add_item (_("Rename"), "document-edit-symbolic", () => Dialogs.rename (win, _("Rename Shape"), m.name, (n) => {
                        m.name = n;
                        persist (st);
                        refresh_section ("user:" + st.id);
                    }));
                    menu.add_item (_("Remove from Stencil"), "user-trash-symbolic", () => {
                        st.masters.remove (m);
                        persist (st);
                        refresh_section ("user:" + st.id);
                    }, "destructive");
                }
            } else {
                menu.add_item (_("Add to Favorites"), "starred-symbolic", () => {
                    var fav = UserStencils.my_shapes ();
                    var s = new Shape (kind);
                    var e = ShapeLibrary.find (kind);
                    s.w = e != null ? e.w : 120;
                    s.h = e != null ? e.h : 60;
                    ShapeLibrary.apply_defaults (s);
                    s.text = ShapeLibrary.default_text (kind);
                    var list = new Gee.ArrayList<Item> ();
                    list.add (s);
                    var m = StencilMaster.from_items (tile.entry.name, list);
                    m.id = fav.new_master_id ();
                    m.keywords = tile.entry.keywords;
                    fav.masters.add (m);
                    persist (fav);
                    open_stencil ("user:" + fav.id);
                });
            }
            DrawWindow.popup_menu (menu);
        }

        private void persist (UserStencil st) {
            try {
                UserStencils.save (st);
            } catch (Error e) {
                if (win != null) win.show_error (_("Could Not Save Stencil"), e.message);
            }
        }

        private void refresh_section (string id) {
            if (section_map.has_key (id)) section_map[id].refill ();
        }

        public void add_selection (UserStencil st) {
            if (canvas == null || canvas.selection.size == 0 || win == null) return;
            var items = new Gee.ArrayList<Item> ();
            foreach (var it in canvas.selection) if (!(it is RasterItem)) items.add (it);
            if (items.size == 0) return;
            string name = items.size == 1 ? (items[0].name != "" ? items[0].name : (items[0].text != "" ? items[0].display_text ().split ("\n")[0] : describe (items[0]))) : _("Group");
            var m = StencilMaster.from_items (name, items);
            m.id = st.new_master_id ();
            st.masters.add (m);
            persist (st);
            open_stencil ("user:" + st.id);
            refresh_section ("user:" + st.id);
            win.add_toast (new Toast (_("Added to %s").printf (st.name)));
        }

        private static string describe (Item it) {
            var s = it as Shape;
            if (s != null) return ShapeLibrary.display_name (s.kind);
            return _("Shape");
        }

        private void new_stencil () {
            if (win == null) return;
            Dialogs.rename (win, _("New Stencil"), _("My Stencil"), (n) => {
                var st = UserStencils.create (n);
                persist (st);
                open_stencil ("user:" + st.id);
            });
        }

        private void import_stencil () {
            if (win == null) return;
            var dialog = new FileDialog ();
            dialog.title = _("Import Stencil");
            var filters = new GLib.ListStore (typeof (FileFilter));
            var f = new FileFilter ();
            f.name = _("Stencils");
            foreach (string s in new string[] { "vssx", "vssm", "vss", "vsdx", "vsd", "sdstencil", "xml", "mxlibrary", "svg" }) f.add_suffix (s);
            filters.append (f);
            dialog.filters = filters;
            dialog.open_multiple.begin (win, null, (obj, res) => {
                try {
                    var files = dialog.open_multiple.end (res);
                    if (files == null || files.get_n_items () == 0) return;
                    string[] svgs = {};
                    string? other = null;
                    for (uint i = 0; i < files.get_n_items (); i++) {
                        var gf = (File) files.get_item (i);
                        string p = gf.get_path ();
                        if (p.down ().has_suffix (".svg")) svgs += p;
                        else if (other == null) other = p;
                    }
                    var st = svgs.length > 0 ? UserStencils.import_svg_files (svgs) : UserStencils.import_file (other);
                    open_stencil ("user:" + st.id);
                    win.add_toast (new Toast (ngettext ("Imported %d shape", "Imported %d shapes", st.masters.size).printf (st.masters.size)));
                } catch (Error e) {
                    if (!(e is Gtk.DialogError.DISMISSED)) win.show_error (_("Could Not Import Stencil"), e.message);
                }
            });
        }
    }
}
