using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class DrawWindow : Singularity.Widgets.Window {
        public Document? doc { get; private set; }
        public Canvas? canvas { get; private set; }
        public Inspector inspector { get; private set; }
        public PaintController? paint { get; private set; }
        private DrawApp app;
        private Box paint_tool_box;
        private Gee.HashMap<PaintTool, ToggleButton> paint_buttons = new Gee.HashMap<PaintTool, ToggleButton> ();
        private BubbleSwitcher mode_switch;
        private bool switching_mode = false;
        private bool shapes_before_paint = false;
        private Stack content_stack;
        private Box doc_page;
        private Box recent_list;
        private Label recent_empty;
        private LibraryPanel library;
        private Revealer inspector_revealer;
        private ChipBar page_chips;
        private Gee.ArrayList<Page> chip_pages = new Gee.ArrayList<Page> ();
        private Label status_label;
        private Button zoom_button;
        private Gee.ArrayList<Widget> doc_bubbles = new Gee.ArrayList<Widget> ();
        public DrawRibbon ribbon;
        private Button share_bubble;
        private Ruler hruler;
        private Ruler vruler;
        private Widget corner;
        private MiniMap minimap;
        private Overlay canvas_overlay;
        private Box tool_box;
        private Gee.HashMap<Tool, ToggleButton> tool_buttons = new Gee.HashMap<Tool, ToggleButton> ();
        private FindReplaceBar find_bar;
        private bool close_confirmed = false;
        private Widget? text_editor = null;
        private Box? rich_bar = null;
        private bool rich_bar_sync = false;
        private Item? editing_item = null;
        private int editing_row = -1;
        private int editing_col = -1;
        private Style? copied_style = null;
        private int find_index = -1;
        private GLib.Settings? settings = null;

        public DrawWindow (DrawApp app) {
            Object (application: app);
            this.app = app;
            set_default_size (1320, 860);
            set_title (app.product_name);
            settings = DrawApp.settings ();
            content_stack = new Stack ();
            content_stack.transition_type = StackTransitionType.CROSSFADE;
            content_stack.add_named (build_welcome (), "welcome");
            doc_page = new Box (Orientation.VERTICAL, 0);
            doc_page.add_css_class ("draw-doc");
            apply_view_edge (doc_page);
            ribbon = new DrawRibbon (this, app.illustration_mode);
            content_stack.add_named (doc_page, "document");
            library = new LibraryPanel ();
            library.set_window (this);
            library.shape_chosen.connect ((kind) => {
                if (canvas != null) {
                    canvas.insert_library_shape (kind, 0, 0, false);
                    canvas.grab_focus ();
                }
            });
            set_sidebar (library);
            set_sidebar_visible (false);
            inspector = new Inspector (this);
            build_bubbles ();
            set_content (content_stack);
            install_actions ();
            close_request.connect (on_close_request);
            var drop = new DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
            drop.drop.connect ((value, x, y) => {
                var list = (Gdk.FileList) value.get_boxed ();
                foreach (var file in list.get_files ()) {
                    app.open_file (file, this);
                    break;
                }
                return true;
            });
            content_stack.get_child_by_name ("welcome").add_controller (drop);
            show_welcome ();
        }

        public bool is_empty () {
            return doc == null || (!doc.modified && doc.path == null && doc.pages.size == 1 && doc.page.items.size == 0);
        }

        private Widget build_welcome () {
            var wp = new WelcomePage ();
            wp.app_icon_name = app.product_icon;
            wp.title = app.product_name;
            wp.subtitle = app.product_subtitle;
            wp.add_action ("x-office-drawing", app.illustration_mode ? _("New Illustration") : _("New Drawing"), _("Start from a blank page"), () => new_document ());
            if (app.illustration_mode) {
                wp.add_action ("folder-open", _("Open"), _("Open SVG and vector artwork"), () => app.choose_file (this));
            } else {
                wp.add_action ("draw-paint", _("New Painting"), _("Paint with brushes on layers"), () => new_painting ());
                wp.add_action ("folder-open", _("Open"), _("OpenDocument, Visio, draw.io, SVG and OpenRaster files"), () => app.choose_file (this));
                wp.add_action ("x-office-spreadsheet", _("Diagram from Data"), _("Build an org chart or shapes from a CSV file"), () => {
                    new_document ();
                    run ("import-data");
                });
            }
            var extra = new Box (Orientation.VERTICAL, 18);
            if (!app.illustration_mode) {
                var tpl_title = new Label (_("Templates"));
                tpl_title.add_css_class ("title-2");
                tpl_title.halign = Align.START;
                extra.append (tpl_title);
                var flow = new FlowBox ();
                flow.selection_mode = SelectionMode.NONE;
                flow.homogeneous = true;
                flow.max_children_per_line = 3;
                flow.min_children_per_line = 2;
                flow.column_spacing = 10;
                flow.row_spacing = 10;
                flow.add_css_class ("draw-templates");
                foreach (var info in Templates.list ()) flow.append (template_card (info));
                extra.append (flow);
            }
            var recent_title = new Label (_("Recent"));
            recent_title.add_css_class ("title-2");
            recent_title.halign = Align.START;
            recent_title.margin_top = 6;
            recent_list = new Box (Orientation.VERTICAL, 0);
            recent_list.add_css_class ("draw-recent-list");
            recent_empty = new Label (_("Drawings you open appear here."));
            recent_empty.add_css_class ("dim-label");
            recent_empty.halign = Align.START;
            extra.append (recent_title);
            extra.append (recent_list);
            extra.append (recent_empty);
            wp.set_extra_widget (extra);
            return wp;
        }

        private Widget template_card (TemplateInfo info) {
            var btn = new Button ();
            btn.add_css_class ("draw-template-card");
            btn.tooltip_text = info.description;
            var box = new Box (Orientation.VERTICAL, 6);
            var thumb = new DrawingArea ();
            thumb.set_size_request (150, 96);
            thumb.add_css_class ("draw-template-thumb");
            Document? cache = null;
            thumb.set_draw_func ((a, cr, w, h) => {
                if (cache == null) cache = Templates.build (info.id);
                cr.set_source_rgb (1, 1, 1);
                cr.rectangle (0, 0, w, h);
                cr.fill ();
                Renderer.draw_thumbnail (cr, cache.page, w, h, true);
            });
            box.append (thumb);
            var name = new Label (info.name);
            name.add_css_class ("heading");
            name.ellipsize = Pango.EllipsizeMode.END;
            name.halign = Align.START;
            box.append (name);
            btn.child = box;
            btn.clicked.connect (() => {
                if (doc != null && !is_empty ()) {
                    var w = new DrawWindow (app);
                    w.present ();
                    w.load_document (Templates.build (info.id));
                } else {
                    load_document (Templates.build (info.id));
                }
            });
            return btn;
        }

        public static bool is_draw_file (string uri, bool include_svg = false) {
            string u = uri.down ();
            foreach (string s in new string[] { ".odg", ".otg", ".fodg", ".vsdx", ".vstx", ".drawio", ".dio", ".sdraw", ".svg" }) if (u.has_suffix (s) && (include_svg || s != ".svg")) return true;
            return false;
        }

        private void fill_recent () {
            Widget? child;
            while ((child = recent_list.get_first_child ()) != null) recent_list.remove (child);
            var items = new Gee.ArrayList<RecentInfo> ();
            if (Singularity.Runtime.file_history_enabled ()) {
                foreach (var info in RecentManager.get_default ().get_items ()) {
                    if (is_draw_file (info.get_uri (), app.illustration_mode) && info.exists ()) items.add (info);
                }
            }
            items.sort ((a, b) => b.get_modified ().compare (a.get_modified ()));
            int count = 0;
            foreach (var info in items) {
                if (count++ >= 6) break;
                var file = File.new_for_uri (info.get_uri ());
                var row = new Button ();
                row.add_css_class ("flat");
                row.add_css_class ("draw-recent-row");
                var box = new Box (Orientation.HORIZONTAL, 12);
                var icon = new Image.from_icon_name ("x-office-drawing-symbolic");
                icon.pixel_size = 20;
                box.append (icon);
                var texts = new Box (Orientation.VERTICAL, 2);
                texts.hexpand = true;
                var name = new Label (file.get_basename ());
                name.halign = Align.START;
                name.ellipsize = Pango.EllipsizeMode.MIDDLE;
                name.add_css_class ("heading");
                var path = new Label (friendly_folder (file));
                path.halign = Align.START;
                path.ellipsize = Pango.EllipsizeMode.START;
                path.add_css_class ("caption");
                path.add_css_class ("dim-label");
                texts.append (name);
                texts.append (path);
                box.append (texts);
                row.child = box;
                row.clicked.connect (() => app.open_file (file, this));
                recent_list.append (row);
            }
            recent_list.visible = count > 0;
            recent_empty.visible = count == 0;
        }

        private static string friendly_folder (File file) {
            var parent = file.get_parent ();
            if (parent == null) return "";
            string p = parent.get_path () ?? parent.get_uri ();
            string home = Environment.get_home_dir ();
            if (p.has_prefix (home)) p = "~" + p.substring (home.length);
            return p;
        }

        private void show_welcome () {
            content_stack.visible_child_name = "welcome";
            foreach (var w in doc_bubbles) w.visible = false;
            set_sidebar_visible (false);
            fill_recent ();
            set_title (app.product_name);
            sync_actions ();
        }

        private Widget track (Widget w) {
            doc_bubbles.add (w);
            return w;
        }

        public static void popup_menu (ContextMenu menu) {
            menu.closed.connect (() => Idle.add (() => {
                menu.unparent ();
                return Source.REMOVE;
            }));
            menu.popup ();
        }

        private void build_bubbles () {
            track (add_bubble_icon ("go-previous-symbolic", _("Close Drawing"), () => close_document ()));
            mode_switch = new BubbleSwitcher ();
            mode_switch.add_option ("draw", app.illustration_mode ? _("Illustration") : _("Draw"));
            mode_switch.add_option ("paint", app.illustration_mode ? _("Brush") : _("Paint"));
            mode_switch.tooltip_text = app.illustration_mode ? _("Switch between vector tools and brushes") : _("Switch between shapes and painting");
            mode_switch.selected.connect ((name) => {
                if (!switching_mode) set_paint_mode (name == "paint");
            });
            add_bubble_widget (mode_switch);
            track (mode_switch);
            track (add_bubble_icon ("sidebar-show-symbolic", _("Shapes (F9)"), () => run ("show-shapes")));
            ribbon.attach (this);
            track (ribbon.tabs);
            track (add_bubble_icon ("edit-find-symbolic", _("Find and Replace (Ctrl+F)"), () => run ("find")));
            share_bubble = add_bubble_icon ("singularity-share-symbolic", _("Share"), () => run ("share"));
            track (share_bubble);
        }

        public void fill_arrange_menu (ContextMenu menu) {
            var order = menu.add_submenu (_("Order"), "draw-front-symbolic");
            order.add_item (_("Bring to Front"), null, () => run ("bring-front"));
            order.add_item (_("Bring Forward"), null, () => run ("bring-forward"));
            order.add_item (_("Send Backward"), null, () => run ("send-backward"));
            order.add_item (_("Send to Back"), null, () => run ("send-back"));
            var align = menu.add_submenu (_("Align"), "draw-align-left-symbolic");
            align.add_item (_("Left"), "draw-align-left-symbolic", () => run ("align-left"));
            align.add_item (_("Center"), "draw-align-center-symbolic", () => run ("align-center"));
            align.add_item (_("Right"), "draw-align-right-symbolic", () => run ("align-right"));
            align.add_item (_("Top"), "draw-align-top-symbolic", () => run ("align-top"));
            align.add_item (_("Middle"), "draw-align-middle-symbolic", () => run ("align-middle"));
            align.add_item (_("Bottom"), "draw-align-bottom-symbolic", () => run ("align-bottom"));
            var dist = menu.add_submenu (_("Distribute"), "draw-distribute-symbolic");
            dist.add_item (_("Horizontally"), null, () => run ("distribute-h"));
            dist.add_item (_("Vertically"), null, () => run ("distribute-v"));
            var rot = menu.add_submenu (_("Rotate and Flip"), "object-rotate-right-symbolic");
            rot.add_item (_("Rotate Right 90°"), "object-rotate-right-symbolic", () => run ("rotate-right"));
            rot.add_item (_("Rotate Left 90°"), "object-rotate-left-symbolic", () => run ("rotate-left"));
            rot.add_item (_("Flip Horizontal"), "object-flip-horizontal-symbolic", () => run ("flip-h"));
            rot.add_item (_("Flip Vertical"), "object-flip-vertical-symbolic", () => run ("flip-v"));
            menu.add_separator ();
            menu.add_item (_("Group"), "draw-group-symbolic", () => run ("group"));
            menu.add_item (_("Ungroup"), "draw-ungroup-symbolic", () => run ("ungroup"));
            var ops = menu.add_submenu (_("Shape Operations"), "draw-union-symbolic");
            ops.add_item (_("Union"), "draw-union-symbolic", () => run ("path-union"));
            ops.add_item (_("Combine"), "draw-exclude-symbolic", () => run ("path-combine"));
            ops.add_item (_("Fragment"), null, () => run ("path-fragment"));
            ops.add_item (_("Intersect"), "draw-intersect-symbolic", () => run ("path-intersect"));
            ops.add_item (_("Subtract"), "draw-subtract-symbolic", () => run ("path-subtract"));
            ops.add_item (_("Exclude"), "draw-exclude-symbolic", () => run ("path-exclude"));
            ops.add_item (_("Join"), null, () => run ("path-join"));
            ops.add_item (_("Trim"), null, () => run ("path-trim"));
            ops.add_item (_("Offset…"), null, () => run ("path-offset"));
            ops.add_item (_("Convert to Path"), null, () => run ("convert-path"));
            var lay = menu.add_submenu (_("Auto Layout"), "draw-layout-symbolic");
            lay.add_item (_("Tree, Top Down"), null, () => run ("layout-tree"));
            lay.add_item (_("Tree, Left to Right"), null, () => run ("layout-tree-right"));
            lay.add_item (_("Hierarchical"), null, () => run ("layout-hierarchical"));
            lay.add_item (_("Hierarchical, Left to Right"), null, () => run ("layout-hierarchical-right"));
            lay.add_item (_("Force-Directed"), null, () => run ("layout-force"));
            lay.add_item (_("Circle"), null, () => run ("layout-circle"));
            lay.add_item (_("Grid"), null, () => run ("layout-grid"));
        }

        public void new_document () {
            var d = new Document ();
            if (app.illustration_mode) {
                d.title = _("Untitled illustration");
                d.page.name = _("Artboard 1");
                d.page.width = 1200;
                d.page.height = 800;
            }
            load_document (d);
        }

        public void new_painting () {
            load_document (Raster.new_painting (1600, 1000));
        }

        public void load_document (Document d) {
            if (doc != null) {
                doc.changed.disconnect (on_doc_changed);
                doc.pages_changed.disconnect (rebuild_pages);
            }
            end_text_edit (false);
            doc = d;
            doc.changed.connect (on_doc_changed);
            doc.pages_changed.connect (rebuild_pages);
            doc.notify["modified"].connect (update_title);
            Widget? child;
            while ((child = doc_page.get_first_child ()) != null) doc_page.remove (child);
            doc_page.append (ribbon);
            if (paint != null) paint.changed.disconnect (on_paint_changed);
            canvas = new Canvas (doc);
            paint = new PaintController (canvas);
            canvas.paint = paint;
            paint.changed.connect (on_paint_changed);
            paint.message.connect ((text) => add_toast (new Toast (text)));
            if (settings != null) {
                canvas.show_grid = settings.get_boolean ("show-grid");
                canvas.snap_grid = settings.get_boolean ("snap-to-grid");
                canvas.snap_objects = settings.get_boolean ("smart-guides");
                string r = settings.get_string ("default-routing");
                canvas.default_route = RouteKind.from_id (r);
            }
            library.set_canvas (canvas);
            canvas.library = library;
            if (settings != null) {
                canvas.autoconnect = settings.get_boolean ("autoconnect");
                canvas.check_spelling = settings.get_boolean ("check-spelling");
            }
            canvas.quick_shapes_requested.connect ((shape, dir, sx, sy) => OfficeUi.quick_shapes (this, shape, dir, sx, sy));
            canvas.comment_activated.connect ((c, sx, sy) => OfficeUi.comment_popover (this, c, sx, sy));
            canvas.hyperlink_activated.connect ((it, link) => OfficeUi.open_link (this, link));
            canvas.selection_changed.connect (on_selection_changed);
            canvas.edit_text_requested.connect (begin_text_edit);
            canvas.context_menu.connect (show_context_menu);
            canvas.view_changed.connect (on_view_changed);
            canvas.tool_changed.connect (sync_tools);
            canvas.pointer_moved.connect ((x, y) => update_status (x, y));
            canvas.painter_finished.connect (() => { });
            canvas.files_dropped.connect (on_files_dropped);
            doc.restored.connect ((ids) => Idle.add (() => {
                inspector.refresh ();
                return Source.REMOVE;
            }));

            var main_row = new Box (Orientation.HORIZONTAL, 0);
            main_row.vexpand = true;
            var grid = new Grid ();
            grid.hexpand = true;
            grid.vexpand = true;
            grid.add_css_class ("draw-canvas-frame");
            corner = new Box (Orientation.HORIZONTAL, 0);
            corner.add_css_class ("draw-ruler-corner");
            corner.set_size_request (Ruler.SIZE, Ruler.SIZE);
            hruler = new Ruler (canvas, false);
            vruler = new Ruler (canvas, true);
            hruler.units = doc.units;
            vruler.units = doc.units;
            canvas_overlay = new Overlay ();
            canvas_overlay.child = canvas;
            canvas_overlay.hexpand = true;
            canvas_overlay.vexpand = true;
            canvas_overlay.add_overlay (build_tool_palette ());
            canvas_overlay.add_overlay (build_paint_palette ());
            minimap = new MiniMap (canvas);
            canvas_overlay.add_overlay (minimap);
            DrawLive.attach (this, canvas_overlay);
            grid.attach (corner, 0, 0);
            grid.attach (hruler, 1, 0);
            grid.attach (vruler, 0, 1);
            grid.attach (canvas_overlay, 1, 1);
            main_row.append (grid);
            var old_revealer = inspector.get_parent () as Revealer;
            if (old_revealer != null) old_revealer.child = null;
            inspector_revealer = new Revealer ();
            inspector_revealer.transition_type = RevealerTransitionType.SLIDE_LEFT;
            inspector_revealer.transition_duration = 200;
            inspector_revealer.child = inspector;
            inspector_revealer.hexpand = false;
            inspector_revealer.reveal_child = settings == null || settings.get_boolean ("show-format-panel");
            main_row.append (inspector_revealer);
            doc_page.append (main_row);
            find_bar = new FindReplaceBar ();
            find_bar.find_next.connect ((q) => find_step (q, 1));
            find_bar.find_prev.connect ((q) => find_step (q, -1));
            find_bar.replace_all.connect ((q, r) => {
                doc.begin (_("Replace All"));
                int n = doc.replace_text (q, r, false, true);
                doc.commit ();
                var toast = new Toast (ngettext ("Replaced %d occurrence", "Replaced %d occurrences", n).printf (n));
                add_toast (toast);
            });
            find_bar.replace_one.connect ((q, r) => replace_current (q, r));
            find_bar.closed.connect (() => canvas.grab_focus ());
            doc_page.append (find_bar);
            doc_page.append (build_bottom_bar ());
            bool rulers = settings == null || settings.get_boolean ("show-rulers");
            hruler.visible = vruler.visible = corner.visible = rulers;
            minimap.visible = settings == null || settings.get_boolean ("show-minimap");
            content_stack.visible_child_name = "document";
            foreach (var w in doc_bubbles) w.visible = true;
            set_sidebar_visible (settings == null || settings.get_boolean ("show-shapes"));
            rebuild_pages ();
            update_title ();
            sync_actions ();
            sync_toggles ();
            apply_mode (Raster.is_painting (doc));
            inspector.refresh ();
            Idle.add (() => {
                if (canvas != null) {
                    var cb = doc.page.content_bounds ();
                    var pr = Rect (0, 0, doc.page.width, doc.page.height);
                    canvas.fit_rect (cb.is_empty () ? pr : pr.union (cb), 30);
                    if (canvas.zoom > 1) canvas.zoom_to (1);
                }
                return Source.REMOVE;
            });
            canvas.grab_focus ();
        }

        private Widget build_paint_palette () {
            paint_tool_box = new Box (Orientation.VERTICAL, 2);
            paint_tool_box.add_css_class ("draw-tools");
            paint_tool_box.halign = Align.START;
            paint_tool_box.valign = Align.CENTER;
            paint_tool_box.margin_start = 10;
            paint_tool_box.visible = false;
            paint_buttons.clear ();
            foreach (var t in PaintTool.all ()) {
                var b = new ToggleButton ();
                var tool = t;
                b.icon_name = t.icon ();
                string tip = "%s (%s)".printf (t.label (), t.shortcut ());
                b.tooltip_text = tip;
                b.add_css_class ("flat");
                b.add_css_class ("draw-tool");
                b.update_property (AccessibleProperty.LABEL, tip, -1);
                b.toggled.connect (() => {
                    if (paint == null) return;
                    if (b.active && paint.tool != tool) paint.use_tool (tool);
                    else if (!b.active && paint.tool == tool) b.active = true;
                });
                paint_buttons[t] = b;
                if (t == PaintTool.FILL || t == PaintTool.SELECT_RECT || t == PaintTool.PAN) {
                    var sep = new Separator (Orientation.HORIZONTAL);
                    sep.add_css_class ("draw-tools-separator");
                    paint_tool_box.append (sep);
                }
                paint_tool_box.append (b);
            }
            return paint_tool_box;
        }

        private void sync_paint_tools () {
            if (paint == null) return;
            foreach (var e in paint_buttons.entries) e.value.active = paint.tool == e.key;
        }

        private PaintTool last_panel_tool = PaintTool.BRUSH;
        private bool last_panel_floating = false;
        private bool last_panel_selection = false;

        private void on_paint_changed () {
            sync_paint_tools ();
            if (paint == null || !paint.active) return;
            bool structural = paint.tool != last_panel_tool || (paint.floating != null) != last_panel_floating || (paint.selection != null) != last_panel_selection;
            last_panel_tool = paint.tool;
            last_panel_floating = paint.floating != null;
            last_panel_selection = paint.selection != null;
            if (structural || paint.tool == PaintTool.PICKER || paint.tool.is_brush () || paint.tool == PaintTool.FILL) inspector.refresh_later ();
        }

        private void apply_mode (bool painting) {
            if (painting) {
                set_paint_mode (true);
                return;
            }
            paint_tool_box.visible = false;
            tool_box.visible = true;
            switching_mode = true;
            mode_switch.set_active ("draw");
            switching_mode = false;
        }

        public void set_paint_mode (bool on) {
            if (canvas == null || paint == null) return;
            switching_mode = true;
            mode_switch.set_active (on ? "paint" : "draw");
            switching_mode = false;
            if (on == paint.active) return;
            end_text_edit (true);
            if (on) {
                shapes_before_paint = get_sidebar_visible ();
                set_sidebar_visible (false);
                paint.activate ();
                tool_box.visible = false;
                paint_tool_box.visible = true;
                Singularity.Motion.reveal (paint_tool_box, Singularity.Motion.Preset.FADE);
                set_toggle ("show-inspector", true);
            } else {
                paint.deactivate ();
                paint_tool_box.visible = false;
                tool_box.visible = true;
                Singularity.Motion.reveal (tool_box, Singularity.Motion.Preset.FADE);
                set_sidebar_visible (shapes_before_paint);
                sync_tools ();
            }
            last_panel_tool = paint.tool;
            sync_paint_tools ();
            sync_actions ();
            inspector.refresh ();
            canvas.grab_focus ();
        }

        private void choose_layer_image () {
            var dialog = new FileDialog ();
            dialog.title = _("Image as Paint Layer");
            var filters = new GLib.ListStore (typeof (FileFilter));
            filters.append (filter (_("Images"), { "png", "jpg", "jpeg", "gif", "webp", "bmp" }));
            dialog.filters = filters;
            dialog.open.begin (this, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file == null) return;
                    uint8[] data;
                    FileUtils.get_data (file.get_path (), out data);
                    var surf = Pixels.decode (data);
                    if (surf == null) throw new FormatError.INVALID (_("The image could not be read."));
                    add_image_layer (surf, file.get_basename ());
                } catch (Error e) {
                    if (!(e is Gtk.DialogError.DISMISSED)) show_error (_("Could Not Insert"), e.message);
                }
            });
        }

        public void add_image_layer (Cairo.ImageSurface surf, string name) {
            var page = doc.page;
            double sc = double.min (1, double.min (page.width / surf.get_width (), page.height / surf.get_height ()));
            var item = new RasterItem.from_surface (surf);
            item.w = surf.get_width () * sc;
            item.h = surf.get_height () * sc;
            item.x = (page.width - item.w) / 2;
            item.y = (page.height - item.h) / 2;
            string label = name;
            int dot = label.last_index_of (".");
            if (dot > 0) label = label.substring (0, dot);
            if (paint != null) paint.commit_floating ();
            var cur = page.find_layer (page.active_layer);
            doc.begin (_("Image as Paint Layer"));
            Raster.add_layer (doc, page, label, item, cur != null ? page.layers.index_of (cur) + 1 : -1);
            doc.commit ();
            if (!canvas.paint_active ()) set_paint_mode (true);
            inspector.refresh ();
        }

        public enum OraChoice {
            CANCEL,
            ORA,
            ODG
        }

        public async OraChoice confirm_ora () {
            string[] names = Ora.flattened_layers (doc.page);
            if (names.length == 0) return OraChoice.ORA;
            string[] quoted = {};
            foreach (string n in names) quoted += _("“%s”").printf (n);
            string list = string.joinv (", ", quoted);
            string body = ngettext (
                "OpenRaster keeps only pixels. The shapes on the layer %s will be turned into pixels and can no longer be edited as shapes. Save as ODG to keep them editable.",
                "OpenRaster keeps only pixels. The shapes on the layers %s will be turned into pixels and can no longer be edited as shapes. Save as ODG to keep them editable.",
                names.length).printf (list);
            var dlg = new ConfirmDialog (app, _("Flatten Shape Layers?"), "dialog-warning", body,
                _("Save as ODG"), ConfirmDialog.ActionStyle.SUGGESTED);
            dlg.set_secondary (_("Flatten and Save"), ConfirmDialog.ActionStyle.DESTRUCTIVE);
            dlg.transient_for = this;
            var choice = OraChoice.CANCEL;
            dlg.response.connect ((r) => {
                if (r == ConfirmDialog.Response.PRIMARY) choice = OraChoice.ODG;
                else if (r == ConfirmDialog.Response.SECONDARY) choice = OraChoice.ORA;
                Idle.add (confirm_ora.callback);
            });
            dlg.present ();
            yield;
            return choice;
        }

        public async void export_ora () {
            if (doc == null) return;
            if (paint != null) paint.commit_floating ();
            var choice = yield confirm_ora ();
            if (choice == OraChoice.CANCEL) return;
            if (choice == OraChoice.ODG) {
                yield save (true);
                return;
            }
            string? path = yield ask_export_path (_("Export as OpenRaster"), "ora", _("OpenRaster Image"));
            if (path == null) return;
            try {
                Formats.write_atomic (path, Ora.save (doc));
                add_toast (new Toast (_("Exported %s").printf (Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        public async void export_image (int format, int mode, double scale, bool transparent, int quality) {
            if (format == 2) {
                yield export_ora ();
                return;
            }
            if (paint != null) paint.commit_floating ();
            bool jpeg = format == 1;
            string? path = yield ask_export_path (_("Export as Image"), jpeg ? "jpg" : "png", jpeg ? _("JPEG Image") : _("PNG Image"));
            if (path == null) return;
            try {
                Gee.List<Item>? only = mode == 2 ? canvas.selection : null;
                Rect area = mode == 0 ? SvgWriter.page_area (doc.page) : SvgWriter.content_area (doc.page, only);
                var surf = Export.render_area (doc.page, area, scale, !jpeg && transparent, only);
                Formats.write_atomic (path, jpeg ? Pixels.jpeg (surf, quality) : Pixels.png (surf));
                add_toast (new Toast (_("Exported %s").printf (Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        private Widget build_tool_palette () {
            tool_box = new Box (Orientation.VERTICAL, 2);
            tool_box.add_css_class ("draw-tools");
            tool_box.halign = Align.START;
            tool_box.valign = Align.CENTER;
            tool_box.margin_start = 10;
            add_tool (Tool.SELECT, "draw-pointer-symbolic", _("Select (Ctrl+1)"));
            add_tool (Tool.PAN, "draw-hand-symbolic", _("Pan (hold Space)"));
            add_tool (Tool.TEXT, "draw-text-symbolic", _("Text (Ctrl+2)"));
            add_tool (Tool.CONNECTOR, "draw-connector-symbolic", _("Connector (Ctrl+3)"));
            add_tool (Tool.RECTANGLE, "draw-rectangle-symbolic", _("Rectangle (Ctrl+8)"));
            add_tool (Tool.ELLIPSE, "draw-ellipse-symbolic", _("Ellipse (Ctrl+9)"));
            add_tool (Tool.LINE, "draw-line-symbolic", _("Line (Ctrl+6)"));
            add_tool (Tool.PEN, "draw-pen-symbolic", _("Pen (Ctrl+5)"));
            add_tool (Tool.FREEHAND, "draw-freehand-symbolic", _("Freehand (Ctrl+4)"));
            add_tool (Tool.CONNECTION_POINT, "draw-point-symbolic", _("Connection Points (Ctrl+7)"));
            return tool_box;
        }

        private void add_tool (Tool t, string icon, string tip) {
            var b = new ToggleButton ();
            b.icon_name = icon;
            b.tooltip_text = tip;
            b.add_css_class ("flat");
            b.add_css_class ("draw-tool");
            b.update_property (AccessibleProperty.LABEL, tip, -1);
            b.toggled.connect (() => {
                if (canvas == null) return;
                if (b.active && canvas.tool != t) canvas.use_tool (t);
                else if (!b.active && canvas.tool == t) b.active = true;
            });
            tool_buttons[t] = b;
            tool_box.append (b);
        }

        private void sync_tools () {
            foreach (var e in tool_buttons.entries) e.value.active = canvas.tool == e.key;
        }

        private Widget build_bottom_bar () {
            page_chips = new ChipBar ();
            page_chips.hexpand = true;
            page_chips.reorderable = true;
            page_chips.max_label_chars = 24;
            page_chips.close_tooltip = _("Delete Page");
            page_chips.chip_activated.connect ((id) => {
                var p = page_for_chip (id);
                if (p != null) switch_page (p);
            });
            page_chips.chip_closed.connect ((id) => {
                var p = page_for_chip (id);
                if (p != null && doc.pages.size > 1) delete_page (p);
            });
            page_chips.chips_reordered.connect (on_chips_reordered);
            page_chips.chip_double_activated.connect ((id) => page_chips.begin_rename (id));
            page_chips.chip_renamed.connect ((id, name) => {
                var p = page_for_chip (id);
                string n = name.strip ();
                if (p == null || n == "" || n == p.name) return;
                doc.begin (_("Rename Page"));
                p.name = n;
                doc.commit ();
                rebuild_pages ();
            });
            page_chips.chip_context_requested.connect ((id) => {
                var p = page_for_chip (id);
                var chip = page_chips.get_chip_widget (id);
                if (p != null && chip != null) show_page_menu (p, chip);
            });
            var add = new Button.from_icon_name ("list-add-symbolic");
            add.add_css_class ("flat");
            add.add_css_class ("circular");
            add.valign = Align.CENTER;
            add.margin_start = 8;
            add.tooltip_text = _("New Page (Shift+F11)");
            add.clicked.connect (() => run ("insert-page"));
            page_chips.prepend (add);
            status_label = new Label ("");
            status_label.add_css_class ("draw-status");
            status_label.add_css_class ("dim-label");
            page_chips.append (status_label);
            zoom_button = new Button.with_label ("100%");
            zoom_button.add_css_class ("flat");
            zoom_button.add_css_class ("draw-zoom");
            zoom_button.valign = Align.CENTER;
            zoom_button.margin_end = 8;
            zoom_button.tooltip_text = _("Zoom");
            zoom_button.clicked.connect (() => {
                var menu = new ContextMenu (zoom_button);
                menu.add_item (_("Fit Page"), "zoom-fit-best-symbolic", () => canvas.fit_page ());
                menu.add_item (_("Fit Selection"), "zoom-fit-best-symbolic", () => canvas.fit_selection ());
                menu.add_separator ();
                int[] levels = { 25, 50, 75, 100, 150, 200, 400 };
                foreach (int l in levels) {
                    int lv = l;
                    menu.add_item ("%d%%".printf (lv), null, () => canvas.zoom_to (lv / 100.0));
                }
                popup_menu (menu);
            });
            page_chips.append (zoom_button);
            return page_chips;
        }

        private Page? page_for_chip (string id) {
            int i = int.parse (id);
            if (i < 0 || i >= chip_pages.size) return null;
            var p = chip_pages[i];
            return doc.pages.contains (p) ? p : null;
        }

        private void rebuild_pages () {
            if (doc == null || page_chips == null) return;
            for (int i = 0; i < chip_pages.size; i++) page_chips.remove_chip (i.to_string ());
            chip_pages.clear ();
            chip_pages.add_all (doc.pages);
            for (int i = 0; i < chip_pages.size; i++) {
                string id = i.to_string ();
                page_chips.add_chip (id, chip_pages[i].is_background ? _("%s (Background)").printf (chip_pages[i].name) : chip_pages[i].name);
                page_chips.set_chip_closable (id, chip_pages.size > 1);
            }
            page_chips.set_active (doc.page_index.to_string ());
        }

        private void on_chips_reordered (string[] ids) {
            var order = new Gee.ArrayList<Page> ();
            foreach (string id in ids) {
                var p = page_for_chip (id);
                if (p != null) order.add (p);
            }
            if (order.size != doc.pages.size) {
                rebuild_pages ();
                return;
            }
            var current = doc.page;
            doc.begin (_("Reorder Pages"));
            doc.pages.clear ();
            doc.pages.add_all (order);
            doc.page_index = doc.pages.index_of (current);
            doc.commit ();
            rebuild_pages ();
        }

        public void switch_page (Page p) {
            end_text_edit (true);
            if (paint != null && paint.active) {
                paint.commit_floating ();
                paint.selection = null;
            }
            int i = doc.pages.index_of (p);
            if (i < 0) return;
            doc.page_index = i;
            canvas.select (new Gee.ArrayList<Item> ());
            Router.route_all (doc.page);
            page_chips.set_active (i.to_string ());
            canvas.queue_draw ();
            canvas.view_changed ();
            inspector.refresh ();
        }

        private void show_page_menu (Page p, Widget chip) {
            var menu = new ContextMenu (chip);
            menu.add_item (_("Rename"), "document-edit-symbolic", () => {
                int i = chip_pages.index_of (p);
                if (i >= 0) page_chips.begin_rename (i.to_string ());
            });
            menu.add_item (_("Duplicate"), "edit-copy-symbolic", () => {
                doc.begin (_("Duplicate Page"));
                var np = doc.duplicate_page (p);
                doc.commit ();
                rebuild_pages ();
                switch_page (np);
            });
            menu.add_item (_("Insert Page"), "list-add-symbolic", () => {
                doc.begin (_("New Page"));
                var np = doc.add_page (doc.pages.index_of (p) + 1);
                doc.commit ();
                rebuild_pages ();
                switch_page (np);
            });
            if (doc.pages.size > 1) {
                menu.add_separator ();
                menu.add_item (_("Delete"), "user-trash-symbolic", () => delete_page (p), "destructive");
            }
            popup_menu (menu);
        }

        private void delete_page (Page p) {
            var dlg = new ConfirmDialog (app, _("Delete Page?"), "user-trash-symbolic",
                _("\"%s\" and everything on it will be deleted. You can undo this.").printf (p.name),
                _("Delete"), ConfirmDialog.ActionStyle.DESTRUCTIVE);
            dlg.transient_for = this;
            dlg.response.connect ((r) => {
                if (r != ConfirmDialog.Response.PRIMARY) return;
                int i = doc.pages.index_of (p);
                doc.begin (_("Delete Page"));
                doc.pages.remove (p);
                doc.page_index = int.max (0, i - 1);
                doc.commit ();
                rebuild_pages ();
                switch_page (doc.page);
            });
            dlg.present ();
        }

        private void on_doc_changed () {
            update_title ();
            if (doc.pages.size != chip_pages.size) rebuild_pages ();
            else page_chips.set_active (doc.page_index.to_string ());
            update_status (double.NAN, double.NAN);
        }

        private void on_selection_changed () {
            inspector.refresh ();
            sync_actions ();
            update_status (double.NAN, double.NAN);
        }

        private void on_view_changed () {
            if (zoom_button != null && canvas != null) zoom_button.label = "%d%%".printf ((int) Math.round (canvas.zoom * 100));
            if (canvas != null) ribbon.sync_zoom (canvas.zoom);
            if (text_editor != null) position_text_editor ();
        }

        private double last_px = double.NAN;
        private double last_py = double.NAN;

        private void update_status (double x, double y) {
            if (status_label == null || canvas == null) return;
            if (!x.is_nan ()) {
                last_px = x;
                last_py = y;
            }
            double u = unit_px ();
            var page = doc.page;
            bool scaled = page.has_scale ();
            string uname = scaled ? page.scale_units : doc.units;
            string pos = last_px.is_nan () ? "" : "%s, %s %s".printf (PathData.fmt (scaled ? page.to_world (last_px) : last_px / u, 2), PathData.fmt (scaled ? page.to_world (last_py) : last_py / u, 2), uname);
            string sel = "";
            if (canvas.selection.size > 0) {
                var b = Document.selection_bounds (canvas.selection);
                sel = "    " + ngettext ("%d selected", "%d selected", canvas.selection.size).printf (canvas.selection.size) + "    %s × %s %s".printf (PathData.fmt (scaled ? page.to_world (b.w) : b.w / u, 2), PathData.fmt (scaled ? page.to_world (b.h) : b.h / u, 2), uname);
            }
            status_label.label = pos + sel;
        }

        private double unit_px () {
            switch (doc.units) {
                case "mm": return Units.PX_PER_MM;
                case "cm": return Units.PX_PER_CM;
                case "in": return Units.PX_PER_IN;
                case "pt": return Units.PX_PER_PT;
                default: return 1;
            }
        }

        public void units_changed () {
            hruler.units = doc.units;
            vruler.units = doc.units;
            hruler.queue_draw ();
            vruler.queue_draw ();
            update_status (double.NAN, double.NAN);
        }

        private DrawCloudSync? cloud_sync = null;
        private uint cloud_timer = 0;
        private bool cloud_busy = false;

        private void cloud_watch () {
            if (doc == null || doc.path == null) return;
            if (cloud_sync != null && cloud_sync.local_path == doc.path) return;
            if (!DrawCloudSync.is_cloud_copy (doc.path)) {
                cloud_sync = null;
                return;
            }
            cloud_attach.begin ();
        }

        private string cloud_pending = "";

        private async void cloud_attach () {
            if (doc == null || doc.path == null || cloud_pending == doc.path) return;
            string path = doc.path;
            cloud_pending = path;
            var s = yield DrawCloudSync.for_local (path);
            cloud_pending = "";
            if (s == null || doc == null || doc.path != path) return;
            cloud_sync = s;
            if (cloud_timer != 0) {
                Source.remove (cloud_timer);
                cloud_timer = 0;
            }
            try {
                yield s.attach ();
            } catch (Error e) {
                warning ("draw sync: %s", e.message);
            }
            cloud_timer = Timeout.add_seconds (30, () => {
                if (cloud_sync == null) {
                    cloud_timer = 0;
                    return Source.REMOVE;
                }
                cloud_poll.begin ();
                return Source.CONTINUE;
            });
        }

        private async void cloud_poll () {
            if (cloud_busy || cloud_sync == null || text_editor != null) return;
            try {
                if (!(yield cloud_sync.remote_changed ())) return;
            } catch (Error e) {
                return;
            }
            yield cloud_sync_now (false);
        }

        public async void cloud_sync_now (bool upload) {
            if (doc == null || doc.path == null) return;
            if (cloud_sync == null || cloud_sync.local_path != doc.path) {
                cloud_sync = null;
                yield cloud_attach ();
            }
            if (cloud_sync == null) {
                if (DrawCloudSync.is_cloud_copy (doc.path)) add_toast (new Toast (_("The online account of this drawing is not available")));
                return;
            }
            if (cloud_busy) return;
            cloud_busy = true;
            end_text_edit (true);
            var target = doc;
            bool was_modified = doc.modified;
            target.begin (_("Online Changes"));
            try {
                var r = yield cloud_sync.sync (target, upload || !was_modified, ConflictPolicy.KEEP_BOTH);
                if (r.pulled () > 0 || r.conflicts.size > 0) {
                    target.commit ();
                    target.link_backgrounds ();
                    canvas.queue_draw ();
                    inspector.refresh ();
                } else {
                    target.cancel ();
                }
                if (upload || !was_modified) target.mark_saved (cloud_sync.local_path);
                update_title ();
                string where = CloudActions.account_label (File.new_for_path (cloud_sync.local_path));
                if (r.conflicts.size > 0) {
                    add_toast (new Toast (ngettext ("%d shape was changed here and online; both versions are kept", "%d shapes were changed here and online; both versions are kept", r.conflicts.size).printf (r.conflicts.size)));
                } else if (r.remote_changed && r.pulled () > 0) {
                    add_toast (new Toast (_("Updated with changes from %s").printf (where)));
                } else if (r.uploaded) {
                    add_toast (new Toast (_("Saved to %s").printf (where)));
                }
            } catch (Error e) {
                target.cancel ();
                add_toast (new Toast (_("Not synced with the online account: %s").printf (e.message)));
            }
            cloud_busy = false;
        }

        private void update_title () {
            if (doc == null) return;
            cloud_watch ();
            string name = doc.path != null ? Path.get_basename (doc.path) : (doc.title != "" ? doc.title : _("Untitled Drawing"));
            set_title ((doc.modified ? "* " : "") + name);
            ribbon.sync_history (doc);
            var ua = lookup_action ("undo") as SimpleAction;
            var ra = lookup_action ("redo") as SimpleAction;
            if (ua != null) ua.set_enabled (doc.can_undo);
            if (ra != null) ra.set_enabled (doc.can_redo);
            sync_share ();
        }

        public void rich_demo (int chars) {
            if (canvas.selection.size != 1) return;
            begin_text_edit (canvas.selection[0], -1, -1);
            var frame = text_editor as ScrolledWindow;
            var view = frame != null ? frame.child as TextView : null;
            if (view == null) return;
            TextIter a, b;
            view.buffer.get_start_iter (out a);
            view.buffer.get_iter_at_offset (out b, chars);
            view.buffer.select_range (a, b);
            run ("bold");
            run ("italic");
            end_text_edit (true);
        }

        public void rich_select (int start, int end) {
            if (canvas.selection.size != 1) return;
            begin_text_edit (canvas.selection[0], -1, -1);
            var frame = text_editor as ScrolledWindow;
            var view = frame != null ? frame.child as TextView : null;
            if (view == null) return;
            TextIter a, b;
            view.buffer.get_iter_at_offset (out a, start);
            view.buffer.get_iter_at_offset (out b, end);
            view.buffer.select_range (a, b);
        }

        public void rich_apply (string what, string value) {
            var frame = text_editor as ScrolledWindow;
            var view = frame != null ? frame.child as TextView : null;
            if (view == null) return;
            switch (what) {
                case "color": RichText.set_color (view.buffer, value); break;
                case "family": RichText.set_family (view.buffer, value); break;
                case "size": RichText.set_size (view.buffer, double.parse (value)); break;
                default: RichText.toggle (view.buffer, what); break;
            }
        }

        private bool rich_toggle (string tag) {
            if (text_editor == null) return false;
            var frame = text_editor as ScrolledWindow;
            var view = frame != null ? frame.child as TextView : null;
            if (view == null) return false;
            RichText.toggle (view.buffer, tag);
            return true;
        }

        public void begin_text_edit (Item item, int row, int col) {
            end_text_edit (true);
            if (canvas.doc.page.item_locked (canvas.doc.page.top_level (item))) return;
            editing_item = item;
            editing_row = row;
            editing_col = col;
            string text = item.text;
            var tb = item as TableShape;
            if (tb != null && row >= 0) text = tb.get_cell (row, col);
            if (canvas.initial_text != null) {
                text = canvas.initial_text;
                canvas.initial_text = null;
            }
            var view = new TextView ();
            view.wrap_mode = WrapMode.WORD_CHAR;
            view.add_css_class ("draw-text-editor");
            RichText.zoom = canvas.zoom;
            RichText.setup (view.buffer);
            if (tb == null && item.has_rich_text () && canvas.initial_text == null && text == item.text) RichText.load (view.buffer, item.markup);
            else view.buffer.text = text;
            view.accepts_tab = false;
            apply_editor_font (view, item.style);
            var keys = new EventControllerKey ();
            keys.key_pressed.connect ((keyval, code, state) => {
                if (keyval == Gdk.Key.Escape || ((keyval == Gdk.Key.Return || keyval == Gdk.Key.KP_Enter) && (state & Gdk.ModifierType.CONTROL_MASK) != 0)) {
                    end_text_edit (true);
                    canvas.grab_focus ();
                    return true;
                }
                if (keyval == Gdk.Key.Tab && tb != null && editing_row >= 0) {
                    int r = editing_row, c = editing_col + 1;
                    if (c >= tb.cols) {
                        c = 0;
                        r++;
                    }
                    end_text_edit (true);
                    if (r < tb.rows) begin_text_edit (tb, r, c);
                    return true;
                }
                return false;
            });
            view.add_controller (keys);
            var focus = new EventControllerFocus ();
            focus.leave.connect (() => Idle.add (() => {
                if (text_editor != null && ((ScrolledWindow) text_editor).child == view && !view.has_focus && !focus_in_rich_bar ()) end_text_edit (true);
                return Source.REMOVE;
            }));
            view.add_controller (focus);
            var frame = new ScrolledWindow ();
            frame.add_css_class ("draw-text-frame");
            frame.hscrollbar_policy = PolicyType.NEVER;
            frame.vscrollbar_policy = PolicyType.NEVER;
            frame.child = view;
            frame.halign = Align.START;
            frame.valign = Align.START;
            text_editor = frame;
            canvas_overlay.add_overlay (frame);
            if (tb == null) show_rich_bar (view, item.style);
            canvas.editing_id = item.id;
            if (tb != null) canvas.editing_id = null;
            position_text_editor ();
            canvas.queue_draw ();
            view.grab_focus ();
            TextIter end, start;
            view.buffer.get_end_iter (out end);
            view.buffer.get_start_iter (out start);
            if (text != item.text || item.text == "") view.buffer.place_cursor (end);
            else view.buffer.select_range (end, start);
        }

        private delegate void BarSync ();

        private bool focus_in_rich_bar () {
            if (rich_bar == null) return false;
            var f = get_focus ();
            return f != null && (f == rich_bar || f.is_ancestor (rich_bar));
        }

        private void show_rich_bar (TextView view, Style st) {
            var bar = new Box (Orientation.HORIZONTAL, 4);
            bar.add_css_class ("draw-rich-bar");
            bar.halign = Align.START;
            bar.valign = Align.START;
            string[] families = { "Sans", "Serif", "Monospace", "Inter", "Cantarell", "DejaVu Sans", "DejaVu Serif", "Liberation Sans", "Liberation Serif", "Liberation Mono", "Noto Sans", "Noto Serif" };
            string[] fam = {};
            bool found = false;
            foreach (string f in families) if (f == st.font_family) found = true;
            if (!found && st.font_family != "") fam += st.font_family;
            foreach (string f in families) fam += f;
            var font = new DropDown.from_strings (fam);
            font.tooltip_text = _("Font");
            font.add_css_class ("flat");
            var size = new SpinButton.with_range (4, 400, 1);
            size.tooltip_text = _("Font Size");
            size.digits = 0;
            size.width_chars = 3;
            var color = new ColorButton (st.text_color, true);
            color.tooltip_text = _("Text Color");
            BarSync sync = () => {
                var r = RichText.selection_format (view.buffer);
                rich_bar_sync = true;
                string cur = r.eff_family (st);
                for (uint i = 0; i < fam.length; i++) if (fam[i] == cur) font.selected = i;
                size.value = r.size > 0 ? r.size : st.font_size;
                color.value = r.color != "" ? r.color : st.text_color;
                rich_bar_sync = false;
            };
            font.notify["selected"].connect (() => {
                if (rich_bar_sync || font.selected >= fam.length) return;
                string f = fam[font.selected];
                RichText.set_family (view.buffer, f == st.font_family ? "" : f);
                view.grab_focus ();
            });
            size.value_changed.connect (() => {
                if (rich_bar_sync) return;
                RichText.set_size (view.buffer, Math.fabs (size.value - st.font_size) < 0.01 ? 0 : size.value);
            });
            color.picked.connect ((c) => {
                RichText.set_color (view.buffer, Colors.is_none (c) ? "" : c);
                view.grab_focus ();
            });
            bar.append (font);
            bar.append (size);
            bar.append (color);
            string[,] toggles = {
                { "bold", "format-text-bold-symbolic", _("Bold (Ctrl+B)") },
                { "italic", "format-text-italic-symbolic", _("Italic (Ctrl+I)") },
                { "underline", "format-text-underline-symbolic", _("Underline (Ctrl+U)") },
                { "strike", "format-text-strikethrough-symbolic", _("Strikethrough") }
            };
            for (int i = 0; i < 4; i++) {
                var b = new Button.from_icon_name (toggles[i, 1]);
                b.tooltip_text = toggles[i, 2];
                b.add_css_class ("flat");
                b.focus_on_click = false;
                string tag = toggles[i, 0];
                b.clicked.connect (() => {
                    RichText.toggle (view.buffer, tag);
                    view.grab_focus ();
                });
                bar.append (b);
            }
            view.buffer.mark_set.connect ((loc, mark) => {
                if (mark == view.buffer.get_insert ()) sync ();
            });
            sync ();
            var focus = new EventControllerFocus ();
            focus.leave.connect (() => Idle.add (() => {
                if (text_editor != null && ((ScrolledWindow) text_editor).child == view && !view.has_focus && !focus_in_rich_bar ()) end_text_edit (true);
                return Source.REMOVE;
            }));
            bar.add_controller (focus);
            rich_bar = bar;
            canvas_overlay.add_overlay (bar);
        }

        private void apply_editor_font (TextView view, Style st) {
            var provider = new CssProvider ();
            double px = st.font_size * Units.PX_PER_PT * (canvas != null ? canvas.zoom : 1);
            string align = st.halign == TextHAlign.LEFT ? "left" : (st.halign == TextHAlign.RIGHT ? "right" : "center");
            view.justification = st.halign == TextHAlign.LEFT ? Justification.LEFT : (st.halign == TextHAlign.RIGHT ? Justification.RIGHT : Justification.CENTER);
            provider.load_from_string ("textview.draw-text-editor, textview.draw-text-editor text { font-family: \"%s\"; font-size: %spx; font-weight: %s; font-style: %s; }".printf (
                st.font_family, PathData.fmt (px, 1), st.bold ? "bold" : "normal", st.italic ? "italic" : "normal"));
            view.get_style_context ().add_provider (provider, STYLE_PROVIDER_PRIORITY_APPLICATION + 2);
            if (align == "") return;
        }

        private void position_text_editor () {
            if (text_editor == null || editing_item == null || canvas == null) return;
            Rect r;
            var tb = editing_item as TableShape;
            var s = editing_item as Shape;
            var c = editing_item as Connector;
            if (tb != null && editing_row >= 0) {
                double x = tb.x + tb.col_x (editing_col), y = tb.y + tb.row_y (editing_row);
                r = Rect (x, y, tb.col_x (editing_col + 1) - tb.col_x (editing_col), tb.row_y (editing_row + 1) - tb.row_y (editing_row));
            } else if (s != null) {
                var geo = s.geometry ();
                var tr = Renderer.text_rect_for (s, geo);
                var m = Renderer.text_matrix (s);
                double cx = tr.x + tr.w / 2, cy = tr.y + tr.h / 2;
                m.transform_point (ref cx, ref cy);
                double w = double.max (tr.w, 80), h = double.max (tr.h, 26);
                if (s.kind == "swimlane-h" || s.kind == "pool" || s.kind == "bpmn-pool" || s.kind == "cff-phase-h") {
                    w = double.max (s.h, 120);
                    h = 30;
                }
                r = Rect (cx - w / 2, cy - h / 2, w, h);
            } else if (c != null) {
                var p = c.label_point ();
                r = Rect (p.x - 70, p.y - 14, 140, 28);
            } else {
                r = editing_item.bounds ();
            }
            var sr = canvas.screen_rect (r);
            text_editor.margin_start = int.max (sr.x, 0);
            text_editor.margin_top = int.max (sr.y, 0);
            text_editor.set_size_request (int.max (sr.width, 60), int.max (sr.height, 24));
            if (rich_bar != null) {
                rich_bar.margin_start = int.max (sr.x, 0);
                rich_bar.margin_top = sr.y > 52 ? sr.y - 48 : sr.y + int.max (sr.height, 24) + 6;
            }
        }

        public void end_text_edit (bool commit) {
            if (text_editor == null) return;
            var frame = text_editor as ScrolledWindow;
            var view = frame.child as TextView;
            string text = view.buffer.text;
            var item = editing_item;
            text_editor = null;
            editing_item = null;
            canvas_overlay.remove_overlay (frame);
            if (rich_bar != null) {
                canvas_overlay.remove_overlay (rich_bar);
                rich_bar = null;
            }
            canvas.editing_id = null;
            if (commit && item != null && doc.page.find (item.id) == item) {
                var tb = item as TableShape;
                if (tb != null && editing_row >= 0) {
                    if (tb.get_cell (editing_row, editing_col) != text) {
                        doc.begin (_("Edit Table"));
                        tb.set_cell (editing_row, editing_col, text);
                        doc.commit ();
                    }
                } else if (item.text != text || RichText.to_markup (view.buffer) != (item.has_rich_text () ? item.markup : "")) {
                    doc.begin (_("Edit Text"));
                    item.text = text;
                    item.markup = RichText.to_markup (view.buffer);
                    var s = item as Shape;
                    if (s != null && s.kind == "text") {
                        var block = SvgWriter.measure (s.style, text, double.max (s.w, 400), true);
                        if (block.height + 8 > s.h) s.h = block.height + 8;
                    }
                    doc.commit ();
                }
            }
            canvas.queue_draw ();
        }

        private void show_context_menu (double x, double y) {
            var menu = new ContextMenu (canvas);
            var rect = Gdk.Rectangle ();
            rect.x = (int) x;
            rect.y = (int) y;
            rect.width = 1;
            rect.height = 1;
            menu.pointing_to = rect;
            var sel = canvas.selection;
            if (sel.size > 0) {
                menu.add_item (_("Cut"), "edit-cut-symbolic", () => run ("cut"));
                menu.add_item (_("Copy"), "edit-copy-symbolic", () => run ("copy"));
                menu.add_item (_("Paste"), "edit-paste-symbolic", () => run ("paste"));
                menu.add_item (_("Duplicate"), "edit-copy-symbolic", () => run ("duplicate"));
                menu.add_separator ();
                if (sel.size == 1 && !(sel[0] is ImageShape)) menu.add_item (_("Edit Text"), "document-edit-symbolic", () => begin_text_edit (sel[0], -1, -1));
                if (sel.size == 1 && sel[0] is PathShape) menu.add_item (_("Edit Points"), "draw-pen-symbolic", () => run ("edit-points"));
                if (sel.size == 1 && sel[0].link != "") {
                    var linked = sel[0];
                    menu.add_item (_("Open Hyperlink"), "web-browser-symbolic", () => OfficeUi.open_link (this, linked.link));
                }
                menu.add_item (_("Add Comment"), "draw-review-symbolic", () => run ("add-comment"));
                if (sel.size == 1 && sel[0] is Shape) menu.add_item (_("Add Callout"), "draw-review-symbolic", () => run ("add-callout"));
                if (sel.size == 2 && sel[0] is Shape && sel[1] is Shape) menu.add_item (_("Attach Callout"), "draw-connector-symbolic", () => run ("attach-callout"));
                if (sel.size > 0) menu.add_item (_("Add to Favorites"), "starred-symbolic", () => library.add_selection (UserStencils.my_shapes ()));
                menu.add_item (_("Copy Style"), "draw-format-painter-symbolic", () => run ("copy-style"));
                if (copied_style != null) menu.add_item (_("Paste Style"), "draw-format-painter-symbolic", () => run ("paste-style"));
                menu.add_separator ();
                fill_arrange_menu (menu);
                if (sel.size == 1 && sel[0] is Connector) {
                    var route = menu.add_submenu (_("Connector Style"), "draw-connector-symbolic");
                    route.add_item (_("Straight"), null, () => run ("route-straight"));
                    route.add_item (_("Orthogonal"), null, () => run ("route-orthogonal"));
                    route.add_item (_("Curved"), null, () => run ("route-curved"));
                    route.add_item (_("Reset Bends"), null, () => run ("reset-bends"));
                }
                if (doc.page.layers.size > 1) {
                    var mv = menu.add_submenu (_("Move to Layer"), "draw-layers-symbolic");
                    foreach (var l in doc.page.layers) {
                        var layer = l;
                        mv.add_item (layer.name, null, () => {
                            doc.begin (_("Move to Layer"));
                            foreach (var it in canvas.selection) it.layer_id = layer.id;
                            doc.commit ();
                        });
                    }
                }
                menu.add_separator ();
                menu.add_item (_("Delete"), "user-trash-symbolic", () => run ("delete"), "destructive");
            } else {
                menu.add_item (_("Paste"), "edit-paste-symbolic", () => run ("paste"));
                menu.add_item (_("Select All"), "edit-select-all-symbolic", () => run ("select-all"));
                menu.add_separator ();
                menu.add_item (_("Fit Page"), "zoom-fit-best-symbolic", () => run ("zoom-page"));
                menu.add_item (_("Page Setup"), "document-properties-symbolic", () => run ("page-setup"));
                menu.add_item (_("Show Grid"), "view-grid-symbolic", () => run ("show-grid"));
            }
            popup_menu (menu);
        }

        public void layer_menu (Layer layer, Widget anchor) {
            var menu = new ContextMenu (anchor);
            var page = doc.page;
            menu.add_item (_("Make Active"), "object-select-symbolic", () => {
                page.active_layer = layer.id;
                inspector.refresh ();
            });
            menu.add_item (_("Rename"), "document-edit-symbolic", () => Dialogs.rename (this, _("Rename Layer"), layer.name, (n) => {
                doc.begin (_("Rename Layer"));
                layer.name = n;
                doc.commit ();
                inspector.refresh ();
            }));
            menu.add_item (layer.printable ? _("Do Not Print") : _("Print"), "document-print-symbolic", () => {
                doc.begin (_("Layer Printing"));
                layer.printable = !layer.printable;
                doc.commit ();
            });
            menu.add_item (_("Select Objects"), "edit-select-all-symbolic", () => {
                var list = new Gee.ArrayList<Item> ();
                foreach (var it in page.items) if (page.layer_of (it) == layer) list.add (it);
                canvas.select (list);
            });
            if (canvas.selection.size > 0) menu.add_item (_("Move Selection Here"), "draw-layers-symbolic", () => {
                doc.begin (_("Move to Layer"));
                foreach (var it in canvas.selection) it.layer_id = layer.id;
                doc.commit ();
                inspector.refresh ();
            });
            int idx = page.layers.index_of (layer);
            if (idx < page.layers.size - 1) menu.add_item (_("Move Up"), "go-up-symbolic", () => {
                doc.begin (_("Reorder Layers"));
                page.layers.remove (layer);
                page.layers.insert (idx + 1, layer);
                Raster.sort_items (page);
                doc.commit ();
                inspector.refresh ();
            });
            if (idx > 0) menu.add_item (_("Move Down"), "go-down-symbolic", () => {
                doc.begin (_("Reorder Layers"));
                page.layers.remove (layer);
                page.layers.insert (idx - 1, layer);
                Raster.sort_items (page);
                doc.commit ();
                inspector.refresh ();
            });
            if (page.layers.size > 1) {
                menu.add_separator ();
                menu.add_item (_("Delete Layer"), "user-trash-symbolic", () => {
                    doc.begin (_("Delete Layer"));
                    var fallback = page.layers[idx == 0 ? 1 : 0];
                    if (layer.raster) {
                        if (paint != null) paint.commit_floating ();
                        Raster.remove_layer (page, layer);
                        if (page.active_layer == layer.id) page.active_layer = fallback.id;
                        doc.commit ();
                        inspector.refresh ();
                        return;
                    }
                    foreach (var it in page.items) if (it.layer_id == layer.id || (it.layer_id == "" && idx == 0)) it.layer_id = fallback.id;
                    page.layers.remove (layer);
                    if (page.active_layer == layer.id) page.active_layer = fallback.id;
                    doc.commit ();
                    inspector.refresh ();
                }, "destructive");
            }
            popup_menu (menu);
        }

        public void add_field_dialog (Item it) {
            Dialogs.add_field (this, it);
        }

        private void on_files_dropped (File[] files, double x, double y) {
            var p = canvas.to_page (x, y);
            doc.begin (_("Insert"));
            var inserted = new Gee.ArrayList<Item> ();
            foreach (var f in files) {
                string? path = f.get_path ();
                if (path == null) continue;
                try {
                    uint8[] data;
                    FileUtils.get_data (path, out data);
                    var kind = Formats.sniff (data, path);
                    if (kind == FileKind.IMAGE) {
                        var img = Formats.image_item (data, p.x, p.y);
                        img.x -= img.w / 2;
                        img.y -= img.h / 2;
                        doc.add_item (img);
                        inserted.add (img);
                    } else {
                        var items = import_items_from (data, path);
                        place_items (items, p.x, p.y);
                        foreach (var it in items) {
                            doc.add_item (it);
                            inserted.add (it);
                        }
                    }
                } catch (Error e) {
                    show_error (_("Could Not Insert"), e.message);
                }
            }
            doc.commit ();
            canvas.select (inserted);
        }

        private Gee.ArrayList<Item> import_items_from (uint8[] data, string path) throws Error {
            var kind = Formats.sniff (data, path);
            if (kind == FileKind.SVG) return SvgReader.import_items (Formats.as_text (data), doc);
            var d = Formats.load_data (data, path);
            return doc.clone_with_new_ids (d.page.items);
        }

        private void place_items (Gee.List<Item> items, double cx, double cy) {
            var b = Document.selection_bounds (items);
            if (b.is_empty ()) return;
            foreach (var it in items) it.move_by (cx - b.cx (), cy - b.cy ());
        }

        public void close_document () {
            if (doc == null) {
                show_welcome ();
                return;
            }
            confirm_discard (() => {
                end_text_edit (false);
                doc = null;
                canvas = null;
                Widget? child;
                while ((child = doc_page.get_first_child ()) != null) doc_page.remove (child);
                show_welcome ();
            });
        }

        public delegate void ActionHandler ();

        private void confirm_discard (owned ActionHandler then) {
            end_text_edit (true);
            if (doc == null || !doc.modified) {
                then ();
                return;
            }
            var dlg = new ConfirmDialog (app, _("Save Changes?"), "dialog-warning",
                _("Your changes will be lost if you do not save them."),
                _("Discard"), ConfirmDialog.ActionStyle.DESTRUCTIVE);
            dlg.set_secondary (_("Save"), ConfirmDialog.ActionStyle.SUGGESTED);
            dlg.transient_for = this;
            dlg.response.connect ((r) => {
                if (r == ConfirmDialog.Response.CANCEL) return;
                if (r == ConfirmDialog.Response.SECONDARY) {
                    save.begin (false, (obj, res) => {
                        if (save.end (res)) then ();
                    });
                    return;
                }
                then ();
            });
            dlg.present ();
        }

        private bool on_close_request () {
            if (close_confirmed || doc == null || !doc.modified) return false;
            confirm_discard (() => {
                close_confirmed = true;
                close ();
            });
            return true;
        }

        private static FileFilter filter (string name, string[] suffixes) {
            var f = new FileFilter ();
            f.name = name;
            foreach (string s in suffixes) f.add_suffix (s);
            return f;
        }

        private string base_name () {
            string b = doc.path != null ? Path.get_basename (doc.path) : (doc.title != "" ? doc.title : (app.illustration_mode ? _("Illustration") : _("Drawing")));
            int dot = b.last_index_of (".");
            if (dot > 0) b = b.substring (0, dot);
            return b;
        }

        public async bool save (bool save_as) {
            if (doc == null) return false;
            end_text_edit (true);
            string? target = save_as ? null : doc.path;
            if (target != null && !Formats.kind_for_path (target).can_save ()) target = null;
            if (target == null) {
                var dialog = new FileDialog ();
                dialog.title = app.illustration_mode ? _("Save Illustration") : _("Save Drawing");
                dialog.initial_name = base_name () + (app.illustration_mode ? ".svg" : ".odg");
                var filters = new GLib.ListStore (typeof (FileFilter));
                if (app.illustration_mode) {
                    filters.append (filter (_("Scalable Vector Graphics (.svg)"), { "svg" }));
                    filters.append (filter (_("OpenDocument Drawing (.odg)"), { "odg" }));
                } else {
                    filters.append (filter (_("OpenDocument Drawing (.odg)"), { "odg" }));
                    filters.append (filter (_("Visio Drawing (.vsdx)"), { "vsdx" }));
                    filters.append (filter (_("draw.io Diagram (.drawio)"), { "drawio" }));
                    filters.append (filter (_("Flat OpenDocument Drawing (.fodg)"), { "fodg" }));
                    filters.append (filter (_("OpenRaster Image (.ora)"), { "ora" }));
                }
                dialog.filters = filters;
                try {
                    var file = yield dialog.save (this, null);
                    if (file == null) return false;
                    target = file.get_path ();
                    if (Formats.kind_for_path (target) == FileKind.UNKNOWN || !Formats.kind_for_path (target).can_save ()) target += app.illustration_mode ? ".svg" : ".odg";
                } catch (Error e) {
                    return false;
                }
            }
            if (Formats.kind_for_path (target) == FileKind.ORA) {
                if (paint != null) paint.commit_floating ();
                var choice = yield confirm_ora ();
                if (choice == OraChoice.CANCEL) return false;
                if (choice == OraChoice.ODG) return yield save (true);
            }
            try {
                Formats.save (doc, target);
                doc.mark_saved (target);
                if (Singularity.Runtime.file_history_enabled ()) RecentManager.get_default ().add_item (File.new_for_path (target).get_uri ());
                update_title ();
                add_toast (new Toast (_("Saved as %s").printf (Path.get_basename (target))));
                cloud_sync_now.begin (true);
                return true;
            } catch (Error e) {
                show_error (_("Could Not Save"), e.message);
                return false;
            }
        }

        private async string? ask_export_path (string title, string suffix, string filter_name) {
            var dialog = new FileDialog ();
            dialog.title = title;
            dialog.initial_name = base_name () + "." + suffix;
            var filters = new GLib.ListStore (typeof (FileFilter));
            filters.append (filter (filter_name, { suffix }));
            dialog.filters = filters;
            try {
                var file = yield dialog.save (this, null);
                if (file == null) return null;
                string p = file.get_path ();
                if (!p.down ().has_suffix ("." + suffix)) p += "." + suffix;
                return p;
            } catch (Error e) {
                return null;
            }
        }

        public async void export_as (string suffix) {
            if (doc == null) return;
            end_text_edit (true);
            string title, fname;
            switch (suffix) {
                case "pdf": title = _("Export as PDF"); fname = _("PDF Document"); break;
                case "svg": title = _("Export as SVG"); fname = _("SVG Image"); break;
                case "vsdx": title = _("Export as Visio"); fname = _("Visio Drawing (.vsdx)"); break;
                case "drawio": title = _("Export as draw.io"); fname = _("draw.io Diagram"); break;
                case "fodg": title = _("Export as Flat OpenDocument"); fname = _("Flat OpenDocument Drawing"); break;
                default: title = _("Export as OpenDocument"); fname = _("OpenDocument Drawing"); break;
            }
            string? path = yield ask_export_path (title, suffix, fname);
            if (path == null) return;
            try {
                switch (suffix) {
                    case "pdf":
                        Export.pdf (doc, path, true);
                        break;
                    case "svg":
                        var only = canvas.selection.size > 0 ? canvas.selection : null;
                        var area = only != null ? SvgWriter.content_area (doc.page, only) : SvgWriter.page_area (doc.page);
                        Formats.write_atomic (path, SvgWriter.write_page (doc.page, area, only == null, only).data);
                        break;
                    default:
                        Formats.save (doc, path);
                        break;
                }
                add_toast (new Toast (_("Exported %s").printf (Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        public async void export_pptx () {
            if (doc == null) return;
            end_text_edit (true);
            string? path = yield ask_export_path (_("Export as PowerPoint"), "pptx", _("PowerPoint Presentation"));
            if (path == null) return;
            try {
                Formats.write_atomic (path, Pptx.save (doc));
                int n = Pptx.slides_for (doc).size;
                add_toast (new Toast (ngettext ("Exported %d slide to %s", "Exported %d slides to %s", n).printf (n, Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        public async void export_png (int mode, double scale, bool transparent) {
            string? path = yield ask_export_path (_("Export as Image"), "png", _("PNG Image"));
            if (path == null) return;
            try {
                Gee.List<Item>? only = mode == 2 ? canvas.selection : null;
                Rect area = mode == 0 ? SvgWriter.page_area (doc.page) : SvgWriter.content_area (doc.page, only);
                Export.png (doc.page, path, area, scale, transparent, only);
                add_toast (new Toast (_("Exported %s").printf (Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        private void print_document () {
            end_text_edit (true);
            var source = new DrawPrintSource (doc, base_name ());
            var opts = Singularity.Print.PresetStore.get_default ().last_used ("dev.sinty.draw") ?? new Singularity.Print.JobOptions ();
            opts.landscape = doc.page.width > doc.page.height;
            Singularity.Print.run_source.begin (this, source, opts);
        }

        public void show_error (string title, string message) {
            var dlg = new ConfirmDialog (app, title, "dialog-error", message, _("OK"), ConfirmDialog.ActionStyle.SUGGESTED);
            dlg.transient_for = this;
            dlg.present ();
        }

        private void choose_import () {
            var dialog = new FileDialog ();
            dialog.title = _("Import Drawing");
            var filters = new GLib.ListStore (typeof (FileFilter));
            filters.append (filter (_("Drawings and Images"), Formats.open_suffixes ()));
            dialog.filters = filters;
            dialog.open.begin (this, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file == null) return;
                    var v = canvas.visible_rect ();
                    on_files_dropped ({ file }, canvas.get_width () / 2.0, canvas.get_height () / 2.0);
                    if (v.w < 0) return;
                } catch (Error e) {
                }
            });
        }

        private void choose_image () {
            var dialog = new FileDialog ();
            dialog.title = _("Insert Image");
            var filters = new GLib.ListStore (typeof (FileFilter));
            filters.append (filter (_("Images"), { "png", "jpg", "jpeg", "gif", "webp", "bmp", "svg" }));
            dialog.filters = filters;
            dialog.open.begin (this, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file == null) return;
                    uint8[] data;
                    FileUtils.get_data (file.get_path (), out data);
                    var v = canvas.visible_rect ();
                    var img = Formats.image_item (data, 0, 0);
                    img.x = v.cx () - img.w / 2;
                    img.y = v.cy () - img.h / 2;
                    doc.begin (_("Insert Image"));
                    doc.add_item (img);
                    doc.commit ();
                    canvas.select_one (img);
                } catch (Error e) {
                    if (!(e is Gtk.DialogError.DISMISSED)) show_error (_("Could Not Insert"), e.message);
                }
            });
        }

        public void import_data (CsvTable table, int mode, int id_col, int parent_col, int name_col, int title_col, string kind, string template) {
            var v = canvas.visible_rect ();
            v.x = double.max (v.x, 0);
            v.y = double.max (v.y, 0);
            doc.begin (_("Import Data"));
            Gee.ArrayList<Item>? items = null;
            if (mode == 0) {
                items = DataImport.org_chart (doc, table, id_col, parent_col, name_col, title_col, v.x + 40, v.y + 40);
            } else if (mode == 1) {
                items = DataImport.shapes_from_table (doc, table, kind, template, v.x + 40, v.y + 40);
            } else {
                int n = DataImport.link_table (doc.page, table, id_col);
                doc.commit ();
                add_toast (new Toast (ngettext ("Linked data to %d shape", "Linked data to %d shapes", n).printf (n)));
                inspector.refresh ();
                return;
            }
            var b = Document.selection_bounds (items);
            if (!b.is_empty ()) doc.move_items (items, v.x + 40 - b.x, v.y + 40 - b.y);
            doc.commit ();
            var tops = new Gee.ArrayList<Item> ();
            foreach (var it in items) if (!(it is Connector)) tops.add (it);
            canvas.select (tops);
            canvas.fit_selection ();
        }

        public void import_source (DataSource src, int mode, DataSources.ProcessMap pm, int parent_col, int title_col, string kind, string template) {
            var table = src.table;
            var v = canvas.visible_rect ();
            v.x = double.max (v.x, 0);
            v.y = double.max (v.y, 0);
            doc.begin (_("Import Data"));
            src.key_column = pm.id_col >= 0 && pm.id_col < table.header.size ? table.header[pm.id_col] : "";
            src.refreshed = new DateTime.now_utc ().to_unix ();
            doc.data_sources.add (src);
            Gee.ArrayList<Item>? items = null;
            switch (mode) {
                case 0:
                    items = DataSources.build_process (doc, src, pm, v.x + 40, v.y + 40);
                    break;
                case 1:
                    src.name = "org:" + src.name;
                    items = DataImport.org_chart (doc, table, pm.id_col, parent_col, pm.text_col, title_col, v.x + 40, v.y + 40);
                    int i = 0;
                    foreach (var it in items) {
                        if (it is Connector) {
                            it.data_source = src.id;
                            continue;
                        }
                        if (i < table.rows.size) DataSources.link_item (it, src, table.rows[i]);
                        i++;
                    }
                    break;
                case 2:
                    items = DataImport.shapes_from_table (doc, table, kind, template, v.x + 40, v.y + 40);
                    for (int i = 0; i < items.size && i < table.rows.size; i++) DataSources.link_item (items[i], src, table.rows[i]);
                    break;
                default:
                    int n = DataSources.auto_link (doc.page, src);
                    doc.commit ();
                    add_toast (new Toast (ngettext ("Linked data to %d shape", "Linked data to %d shapes", n).printf (n)));
                    inspector.refresh ();
                    return;
            }
            if (mode != 0) {
                var b = Document.selection_bounds (items);
                if (!b.is_empty ()) doc.move_items (items, v.x + 40 - b.x, v.y + 40 - b.y);
            }
            doc.commit ();
            var tops = new Gee.ArrayList<Item> ();
            foreach (var it in items) if (!(it is Connector) && doc.page.items.contains (it)) tops.add (it);
            canvas.select (tops);
            canvas.fit_selection ();
        }

        public void insert_table (int rows, int cols, bool header) {
            var v = canvas.visible_rect ();
            var t = new TableShape (rows, cols);
            t.header_row = header;
            t.w = 110 * cols;
            t.h = 30 * rows;
            t.x = Math.round (v.cx () - t.w / 2);
            t.y = Math.round (v.cy () - t.h / 2);
            doc.begin (_("Insert Table"));
            doc.add_item (t);
            doc.commit ();
            canvas.select_one (t);
        }

        private void find_step (string q, int dir) {
            if (doc == null || q == "") return;
            Gee.ArrayList<Page> pages;
            var hits = doc.find_text (q, false, true, out pages);
            if (hits.size == 0) {
                find_bar.set_match_info (0, 0);
                return;
            }
            find_index = (find_index + dir + hits.size) % hits.size;
            var p = pages[find_index];
            if (p != doc.page) switch_page (p);
            canvas.select_one (hits[find_index]);
            var b = hits[find_index].bounds ();
            canvas.center_on (b.cx (), b.cy ());
            find_bar.set_match_info (find_index + 1, hits.size);
        }

        private void replace_current (string q, string r) {
            if (canvas.selection.size == 1) {
                var it = canvas.selection[0];
                int n;
                string t = Document.replace_in (it.text, q, r, false, out n);
                if (n > 0) {
                    doc.begin (_("Replace"));
                    it.text = t;
                    doc.commit ();
                }
            }
            find_step (q, 1);
        }

        private delegate void Act ();

        private string[] doc_actions = {};
        private string[] sel_actions = {};

        private static string? text_action (string name) {
            switch (name) {
                case "copy": return "clipboard.copy";
                case "cut": return "clipboard.cut";
                case "paste": return "clipboard.paste";
                case "select-all": return "selection.select-all";
                case "undo": return "text.undo";
                case "redo": return "text.redo";
                case "delete": return "text.delete";
                default: return null;
            }
        }

        private bool focus_in_text () {
            var f = get_focus ();
            return f != null && (f is Gtk.Text || f is Gtk.TextView);
        }

        private void act (string name, owned Act handler, bool needs_doc = true, bool needs_sel = false) {
            var a = new SimpleAction (name, null);
            if (needs_doc) doc_actions += name;
            if (needs_sel) sel_actions += name;
            string? forward = text_action (name);
            a.activate.connect (() => {
                if (forward != null && focus_in_text ()) {
                    get_focus ().activate_action_variant (forward, null);
                    return;
                }
                if (needs_doc && (doc == null || canvas == null)) return;
                if (needs_sel && canvas.selection.size == 0) return;
                handler ();
            });
            add_action (a);
        }

        private void toggle (string name, bool initial, owned ToggleHandler handler) {
            var a = new SimpleAction.stateful (name, null, new Variant.boolean (initial));
            doc_actions += name;
            a.activate.connect (() => {
                if (doc == null || canvas == null) return;
                bool v = !a.get_state ().get_boolean ();
                a.set_state (new Variant.boolean (v));
                handler (v);
            });
            add_action (a);
        }

        private delegate void ToggleHandler (bool on);

        public void set_toggle (string name, bool on) {
            var a = lookup_action (name) as SimpleAction;
            if (a == null) return;
            if (a.get_state ().get_boolean () != on) a.activate (null);
        }

        private void sync_toggles () {
            if (canvas == null) return;
            set_state ("show-grid", canvas.show_grid);
            set_state ("snap-grid", canvas.snap_grid);
            set_state ("snap-objects", canvas.snap_objects);
            set_state ("show-rulers", hruler.visible);
            set_state ("show-minimap", minimap.visible);
            set_state ("show-inspector", inspector_revealer.reveal_child);
            set_state ("show-shapes", get_sidebar_visible ());
        }

        private void set_state (string name, bool v) {
            var a = lookup_action (name) as SimpleAction;
            if (a != null) a.set_state (new Variant.boolean (v));
        }

        private void save_setting (string key, bool v) {
            if (settings != null) settings.set_boolean (key, v);
        }

        private void sync_actions () {
            foreach (string name in doc_actions) {
                var a = lookup_action (name) as SimpleAction;
                if (a != null) a.set_enabled (doc != null);
            }
            bool has_sel = canvas != null && canvas.selection.size > 0;
            foreach (string name in sel_actions) {
                var a = lookup_action (name) as SimpleAction;
                if (a != null) a.set_enabled (doc != null && has_sel);
            }
            foreach (string name in new string[] { "cut", "copy" }) {
                var a = lookup_action (name) as SimpleAction;
                if (a != null) a.set_enabled (doc != null && (has_sel || (canvas != null && canvas.paint_active ())));
            }
            sync_share ();
            if (doc != null) update_title ();
        }

        private void sync_share () {
            var a = lookup_action ("share") as SimpleAction;
            bool can = doc != null && doc.path != null;
            if (a != null) a.set_enabled (can);
            if (share_bubble != null) share_bubble.sensitive = can;
            var sync = lookup_action ("sync-online") as SimpleAction;
            if (sync != null) sync.set_enabled (can && DrawCloudSync.is_cloud_copy (doc.path));
        }

        public void run (string name) {
            activate_action (name, null);
        }

        private Gee.ArrayList<Item> sel () {
            var l = new Gee.ArrayList<Item> ();
            l.add_all (canvas.selection);
            return l;
        }

        private void edit_sel (string label, owned Act fn) {
            if (canvas.selection.size == 0) return;
            doc.begin (label);
            fn ();
            doc.commit ();
            canvas.select (sel ());
        }

        private void style_toggle (string label, owned StyleFlag get, owned StyleSet setter) {
            if (canvas.selection.size == 0) return;
            bool on = !get (canvas.selection[0].style);
            doc.begin (label);
            foreach (var it in all_leaves ()) setter (it.style, on);
            doc.commit ();
            inspector.refresh ();
        }

        private delegate bool StyleFlag (Style s);
        private delegate void StyleSet (Style s, bool on);

        private Gee.ArrayList<Item> all_leaves () {
            var list = new Gee.ArrayList<Item> ();
            foreach (var it in canvas.selection) {
                var g = it as Group;
                if (g != null) {
                    var all = new Gee.ArrayList<Item> ();
                    g.collect (all);
                    foreach (var a in all) if (!(a is Group)) list.add (a);
                } else {
                    list.add (it);
                }
            }
            return list;
        }

        private void boolean_op (BoolOp op) {
            var shapes = new Gee.ArrayList<Shape> ();
            foreach (var it in canvas.selection) {
                var s = it as Shape;
                if (s != null && !(s is ImageShape) && !(s is TableShape)) shapes.add (s);
            }
            if (shapes.size < 2) {
                add_toast (new Toast (_("Select two or more shapes first")));
                return;
            }
            var order = new Gee.ArrayList<Shape> ();
            foreach (var it in doc.page.items) if (shapes.contains (it as Shape)) order.add ((Shape) it);
            var result = outline_of (order[0]);
            for (int i = 1; i < order.size; i++) {
                var other = outline_of (order[i]);
                if (op == BoolOp.SUBTRACT) result = PathBoolean.apply (result, other, BoolOp.SUBTRACT);
                else result = PathBoolean.apply (result, other, op);
            }
            if (result.is_empty ()) {
                add_toast (new Toast (_("The shapes do not overlap")));
                return;
            }
            var ps = new PathShape ();
            ps.set_page_path (result);
            ps.style = order[0].style.copy ();
            ps.text = order[0].text;
            ps.layer_id = order[0].layer_id;
            int index = doc.page.items.index_of (order[0]);
            doc.begin (_("Shape Operation"));
            doc.delete_items (order);
            doc.add_item (ps, int.min (index, doc.page.items.size));
            doc.commit ();
            canvas.select_one (ps);
        }

        private static PathData outline_of (Shape s) {
            var ps = s as PathShape;
            if (ps != null) return ps.page_path ();
            return s.page_outline ();
        }

        private void convert_to_path () {
            var created = new Gee.ArrayList<Item> ();
            doc.begin (_("Convert to Path"));
            foreach (var it in sel ()) {
                var s = it as Shape;
                if (s == null || s is PathShape || s is ImageShape || s is TableShape) continue;
                var g = s.geometry ();
                var path = new PathData ();
                foreach (var part in g.parts) path.append (part.path);
                path.transform (s.transform ());
                var ps = new PathShape ();
                ps.set_page_path (path);
                ps.style = s.style.copy ();
                ps.text = s.text;
                ps.layer_id = s.layer_id;
                ps.id = s.id;
                int idx = doc.page.items.index_of (s);
                doc.page.items.remove (s);
                doc.page.items.insert (idx, ps);
                created.add (ps);
            }
            doc.commit ();
            canvas.select (created);
        }

        private void layout (LayoutKind kind) {
            doc.begin (_("Auto Layout"));
            if (!AutoLayout.apply (doc.page, sel (), kind)) {
                doc.cancel ();
                add_toast (new Toast (_("Select at least two connected shapes")));
                return;
            }
            doc.commit ();
            canvas.fit_selection ();
        }

        private void copy_pixels (bool cut) {
            double x, y;
            var surf = paint.copy_pixels (out x, out y);
            if (surf == null) return;
            DrawClipboard.copy_pixels (get_clipboard (), surf, x, y);
            if (cut) paint.cut_pixels ();
        }

        private void paste_pixels () {
            var page = doc.page;
            DrawClipboard.paste_pixels.begin (get_clipboard (), page, (obj, res) => {
                var got = DrawClipboard.paste_pixels.end (res);
                if (got == null) {
                    add_toast (new Toast (_("There is no image to paste")));
                    return;
                }
                if (paint == null || !canvas.paint_active () || doc.page != page) return;
                paint.paste_pixels (got.surface, got.has_origin, got.x, got.y);
            });
        }

        private void paste () {
            if (canvas.paint_active ()) {
                paste_pixels ();
                return;
            }
            var clipboard = get_clipboard ();
            DrawClipboard.paste.begin (clipboard, doc, (obj, res) => {
                var items = DrawClipboard.paste.end (res);
                if (items == null || items.size == 0) return;
                var v = canvas.visible_rect ();
                var b = Document.selection_bounds (items);
                bool local_copy = pasted_from_self (items);
                if (local_copy) {
                    foreach (var it in items) it.move_by (20 * paste_count, 20 * paste_count);
                } else if (!v.contains_rect (b)) {
                    place_items (items, v.cx (), v.cy ());
                }
                doc.begin (_("Paste"));
                foreach (var it in items) doc.add_item (it);
                doc.commit ();
                canvas.select (items);
            });
        }

        private int paste_count = 1;
        private string last_copy_signature = "";

        private bool pasted_from_self (Gee.List<Item> items) {
            var b = Document.selection_bounds (items);
            string sig = "%s:%s:%d".printf (PathData.fmt (b.x, 1), PathData.fmt (b.y, 1), items.size);
            if (sig == last_copy_signature) {
                paste_count++;
                return true;
            }
            return false;
        }

        private void copy_selection (bool cut) {
            if (canvas.paint_active ()) {
                copy_pixels (cut);
                return;
            }
            var items = sel ();
            if (items.size == 0) return;
            DrawClipboard.copy (get_clipboard (), doc.page, items);
            var b = Document.selection_bounds (items);
            last_copy_signature = "%s:%s:%d".printf (PathData.fmt (b.x, 1), PathData.fmt (b.y, 1), items.size);
            paste_count = cut ? 0 : 1;
            if (cut) {
                doc.begin (_("Cut"));
                doc.delete_items (items);
                doc.commit ();
                canvas.select (new Gee.ArrayList<Item> ());
            }
        }

        private void install_actions () {
            act ("save", () => save.begin (false));
            act ("save-as", () => save.begin (true));
            act ("save-online", () => CloudActions.save_document (this));
            act ("sync-online", () => cloud_sync_now.begin (true));
            act ("export-pdf", () => export_as.begin ("pdf"));
            act ("export-svg", () => export_as.begin ("svg"));
            act ("export-png", () => Dialogs.export_image (this));
            act ("export-vsdx", () => export_as.begin ("vsdx"));
            act ("export-odg", () => export_as.begin ("odg"));
            act ("export-fodg", () => export_as.begin ("fodg"));
            act ("export-drawio", () => export_as.begin ("drawio"));
            act ("import", () => choose_import ());
            act ("import-data", () => OfficeUi.choose_data_file (this, false));
            act ("export-data", () => {
                var items = canvas.selection.size > 0 ? all_leaves () : doc.page.all_items ();
                export_csv.begin (items);
            });
            act ("print", () => print_document ());
            Singularity.Share.add_action (this, this, () => {
                return doc != null && doc.path != null ? new Singularity.ShareContent.for_files ({ File.new_for_path (doc.path) }) : null;
            });
            act ("close-doc", () => close_document ());
            act ("undo", () => {
                end_text_edit (true);
                doc.undo ();
            });
            act ("redo", () => doc.redo ());
            act ("cut", () => copy_selection (true));
            act ("copy", () => copy_selection (false));
            act ("paste", () => paste ());
            act ("duplicate", () => {
                var items = doc.clone_with_new_ids (sel ());
                foreach (var it in items) it.move_by (20, 20);
                doc.begin (_("Duplicate"));
                foreach (var it in items) doc.add_item (it);
                doc.commit ();
                canvas.select (items);
            }, true, true);
            act ("delete", () => {
                if (canvas.node_target != null) {
                    canvas.delete_selected_node ();
                    return;
                }
                edit_sel (_("Delete"), () => doc.delete_items (sel ()));
            }, true, true);
            act ("select-all", () => {
                if (canvas.paint_active ()) paint.select_all ();
                else canvas.select_all ();
            });
            act ("select-none", () => {
                if (canvas.paint_active ()) paint.deselect ();
                else canvas.select (new Gee.ArrayList<Item> ());
            });
            act ("paint-mode", () => set_paint_mode (!canvas.paint_active ()));
            act ("add-paint-layer", () => {
                if (paint != null) paint.commit_floating ();
                var page = doc.page;
                var cur = page.find_layer (page.active_layer);
                doc.begin (_("Add Paint Layer"));
                Raster.add_layer (doc, page, null, null, cur != null ? page.layers.index_of (cur) + 1 : -1);
                doc.commit ();
                if (!canvas.paint_active ()) set_paint_mode (true);
                inspector.refresh ();
            });
            act ("import-layer", () => choose_layer_image ());
            act ("export-ora", () => export_ora.begin ());
            act ("export-jpeg", () => Dialogs.export_image (this, 1));
            act ("find", () => {
                find_bar.reveal_child = true;
                find_bar.open_find ();
            });
            act ("replace", () => {
                find_bar.reveal_child = true;
                find_bar.open_replace ();
            });
            act ("edit-text", () => {
                if (canvas.selection.size == 1) begin_text_edit (canvas.selection[0], -1, -1);
            }, true, true);
            act ("edit-points", () => {
                var ps = canvas.selection.size == 1 ? canvas.selection[0] as PathShape : null;
                if (ps != null) canvas.enter_node_edit (ps);
                else add_toast (new Toast (_("Select a path first, or convert a shape to a path")));
            }, true, true);
            act ("smooth-point", () => canvas.toggle_node_smooth ());
            act ("copy-style", () => {
                copied_style = canvas.selection[0].style.copy ();
                add_toast (new Toast (_("Style copied")));
            }, true, true);
            act ("paste-style", () => {
                if (copied_style == null) return;
                doc.begin (_("Paste Style"));
                foreach (var it in all_leaves ()) it.style.assign_appearance (copied_style, it is Connector || it is PathShape);
                doc.commit ();
                inspector.refresh ();
            }, true, true);
            act ("format-painter", () => {
                if (canvas.selection.size == 0) {
                    add_toast (new Toast (_("Select the shape whose style you want to copy")));
                    return;
                }
                canvas.painter_style = canvas.selection[0].style.copy ();
                copied_style = canvas.painter_style;
                canvas.set_cursor_from_name ("copy");
                add_toast (new Toast (_("Click a shape to apply the style")));
            });
            act ("reset-style", () => edit_sel (_("Reset Style"), () => {
                foreach (var it in all_leaves ()) {
                    var fresh = new Style ();
                    if (it is Connector) {
                        fresh.fill_kind = FillKind.NONE;
                        fresh.arrow_end = ArrowKind.TRIANGLE;
                    }
                    it.style = fresh;
                }
            }), true, true);
            act ("zoom-in", () => canvas.zoom_to (canvas.zoom * 1.25));
            act ("zoom-out", () => canvas.zoom_to (canvas.zoom / 1.25));
            act ("zoom-reset", () => canvas.zoom_to (1));
            act ("zoom-page", () => canvas.fit_page ());
            act ("zoom-selection", () => canvas.fit_selection ());
            toggle ("show-grid", true, (on) => {
                canvas.show_grid = on;
                canvas.queue_draw ();
                save_setting ("show-grid", on);
                inspector.refresh ();
            });
            toggle ("snap-grid", true, (on) => {
                canvas.snap_grid = on;
                save_setting ("snap-to-grid", on);
            });
            toggle ("snap-objects", true, (on) => {
                canvas.snap_objects = on;
                save_setting ("smart-guides", on);
            });
            toggle ("show-rulers", true, (on) => {
                hruler.visible = vruler.visible = corner.visible = on;
                save_setting ("show-rulers", on);
            });
            toggle ("show-minimap", true, (on) => {
                minimap.visible = on;
                save_setting ("show-minimap", on);
            });
            toggle ("show-inspector", true, (on) => {
                inspector_revealer.reveal_child = on;
                save_setting ("show-format-panel", on);
            });
            toggle ("show-shapes", true, (on) => {
                set_sidebar_visible (on);
                save_setting ("show-shapes", on);
            });
            act ("fullscreen", () => {
                if (fullscreened) unfullscreen ();
                else fullscreen ();
            }, false);
            act ("tool-select", () => canvas.use_tool (Tool.SELECT));
            act ("tool-hand", () => canvas.use_tool (Tool.PAN));
            act ("tool-text", () => canvas.use_tool (Tool.TEXT));
            act ("tool-connector", () => canvas.use_tool (Tool.CONNECTOR));
            act ("tool-freehand", () => canvas.use_tool (Tool.FREEHAND));
            act ("tool-pen", () => canvas.use_tool (Tool.PEN));
            act ("tool-line", () => canvas.use_tool (Tool.LINE));
            act ("tool-rectangle", () => canvas.use_tool (Tool.RECTANGLE));
            act ("tool-ellipse", () => canvas.use_tool (Tool.ELLIPSE));
            act ("insert-image", () => choose_image ());
            act ("insert-table", () => Dialogs.insert_table (this));
            act ("insert-container", () => canvas.insert_library_shape ("container", 0, 0, false));
            act ("insert-swimlane", () => canvas.insert_library_shape ("pool", 0, 0, false));
            act ("insert-page", () => {
                doc.begin (_("New Page"));
                var p = doc.add_page (doc.page_index + 1);
                doc.commit ();
                rebuild_pages ();
                switch_page (p);
            });
            act ("duplicate-page", () => {
                doc.begin (_("Duplicate Page"));
                var p = doc.duplicate_page (doc.page);
                doc.commit ();
                rebuild_pages ();
                switch_page (p);
            });
            act ("rename-page", () => {
                page_chips.begin_rename (doc.page_index.to_string ());
            });
            act ("delete-page", () => {
                if (doc.pages.size > 1) delete_page (doc.page);
            });
            act ("next-page", () => {
                if (doc.page_index < doc.pages.size - 1) switch_page (doc.pages[doc.page_index + 1]);
            });
            act ("prev-page", () => {
                if (doc.page_index > 0) switch_page (doc.pages[doc.page_index - 1]);
            });
            act ("page-setup", () => {
                canvas.select (new Gee.ArrayList<Item> ());
                set_toggle ("show-inspector", true);
            });
            act ("fit-page-to-drawing", () => {
                var b = doc.page.content_bounds ();
                if (b.is_empty ()) return;
                b = b.inflate (40);
                doc.begin (_("Fit Page to Drawing"));
                var all = new Gee.ArrayList<Item> ();
                all.add_all (doc.page.items);
                doc.move_items (all, -b.x, -b.y);
                doc.page.width = b.w;
                doc.page.height = b.h;
                doc.commit ();
                canvas.fit_page ();
                inspector.refresh ();
            });
            act ("add-layer", () => {
                var page = doc.page;
                int n = page.layers.size + 1;
                string id = "layer%d".printf (n);
                while (page.find_layer (id) != null) id = "layer%d".printf (++n);
                doc.begin (_("Add Layer"));
                var l = new Layer (id, _("Layer %d").printf (n));
                page.layers.add (l);
                page.active_layer = id;
                doc.commit ();
                canvas.select (new Gee.ArrayList<Item> ());
                set_toggle ("show-inspector", true);
                inspector.refresh ();
            });
            act ("bold", () => {
                if (rich_toggle ("bold")) return;
                style_toggle (_("Bold"), (s) => s.bold, (s, on) => s.bold = on);
            }, true, true);
            act ("italic", () => {
                if (rich_toggle ("italic")) return;
                style_toggle (_("Italic"), (s) => s.italic, (s, on) => s.italic = on);
            }, true, true);
            act ("underline", () => {
                if (rich_toggle ("underline")) return;
                style_toggle (_("Underline"), (s) => s.underline, (s, on) => s.underline = on);
            }, true, true);
            act ("text-left", () => edit_sel (_("Align Text"), () => { foreach (var it in all_leaves ()) it.style.halign = TextHAlign.LEFT; }), true, true);
            act ("text-center", () => edit_sel (_("Align Text"), () => { foreach (var it in all_leaves ()) it.style.halign = TextHAlign.CENTER; }), true, true);
            act ("text-right", () => edit_sel (_("Align Text"), () => { foreach (var it in all_leaves ()) it.style.halign = TextHAlign.RIGHT; }), true, true);
            act ("font-grow", () => edit_sel (_("Font Size"), () => { foreach (var it in all_leaves ()) it.style.font_size = Math.round (it.style.font_size * 1.15 + 0.5); }), true, true);
            act ("font-shrink", () => edit_sel (_("Font Size"), () => { foreach (var it in all_leaves ()) it.style.font_size = double.max (4, Math.round (it.style.font_size / 1.15 - 0.5)); }), true, true);
            act ("shadow", () => style_toggle (_("Shadow"), (s) => s.shadow, (s, on) => s.shadow = on), true, true);
            act ("bring-front", () => edit_sel (_("Bring to Front"), () => doc.reorder (sel (), 2)), true, true);
            act ("bring-forward", () => edit_sel (_("Bring Forward"), () => doc.reorder (sel (), 1)), true, true);
            act ("send-backward", () => edit_sel (_("Send Backward"), () => doc.reorder (sel (), -1)), true, true);
            act ("send-back", () => edit_sel (_("Send to Back"), () => doc.reorder (sel (), -2)), true, true);
            act ("align-left", () => edit_sel (_("Align"), () => doc.align (sel (), AlignKind.LEFT, align_ref ())), true, true);
            act ("align-center", () => edit_sel (_("Align"), () => doc.align (sel (), AlignKind.CENTER, align_ref ())), true, true);
            act ("align-right", () => edit_sel (_("Align"), () => doc.align (sel (), AlignKind.RIGHT, align_ref ())), true, true);
            act ("align-top", () => edit_sel (_("Align"), () => doc.align (sel (), AlignKind.TOP, align_ref ())), true, true);
            act ("align-middle", () => edit_sel (_("Align"), () => doc.align (sel (), AlignKind.MIDDLE, align_ref ())), true, true);
            act ("align-bottom", () => edit_sel (_("Align"), () => doc.align (sel (), AlignKind.BOTTOM, align_ref ())), true, true);
            act ("distribute-h", () => edit_sel (_("Distribute"), () => doc.distribute (sel (), true)), true, true);
            act ("distribute-v", () => edit_sel (_("Distribute"), () => doc.distribute (sel (), false)), true, true);
            act ("same-width", () => {
                var r = canvas.selection[0] as Shape;
                if (r != null) edit_sel (_("Same Width"), () => doc.match_size (sel (), true, false, r));
            }, true, true);
            act ("same-height", () => {
                var r = canvas.selection[0] as Shape;
                if (r != null) edit_sel (_("Same Height"), () => doc.match_size (sel (), false, true, r));
            }, true, true);
            act ("group", () => {
                if (canvas.selection.size < 2) return;
                doc.begin (_("Group"));
                var g = doc.group (sel ());
                doc.commit ();
                if (g != null) canvas.select_one (g);
            }, true, true);
            act ("ungroup", () => {
                doc.begin (_("Ungroup"));
                var released = doc.ungroup (sel ());
                if (released.size == 0) {
                    doc.cancel ();
                    return;
                }
                doc.commit ();
                canvas.select (released);
            }, true, true);
            act ("rotate-right", () => edit_sel (_("Rotate"), () => doc.rotate_items (sel (), 90)), true, true);
            act ("rotate-left", () => edit_sel (_("Rotate"), () => doc.rotate_items (sel (), -90)), true, true);
            act ("flip-h", () => edit_sel (_("Flip Horizontal"), () => doc.flip_items (sel (), true)), true, true);
            act ("flip-v", () => edit_sel (_("Flip Vertical"), () => doc.flip_items (sel (), false)), true, true);
            act ("lock", () => {
                bool on = !canvas.selection[0].locked;
                edit_sel (on ? _("Lock") : _("Unlock"), () => { foreach (var it in sel ()) it.locked = on; });
                inspector.refresh ();
            }, true, true);
            act ("path-union", () => boolean_op (BoolOp.UNION), true, true);
            act ("path-subtract", () => boolean_op (BoolOp.SUBTRACT), true, true);
            act ("path-intersect", () => boolean_op (BoolOp.INTERSECT), true, true);
            act ("path-exclude", () => boolean_op (BoolOp.EXCLUDE), true, true);
            act ("convert-path", () => convert_to_path (), true, true);
            act ("layout-tree", () => layout (LayoutKind.TREE_DOWN));
            act ("layout-tree-right", () => layout (LayoutKind.TREE_RIGHT));
            act ("layout-hierarchical", () => layout (LayoutKind.HIERARCHICAL));
            act ("layout-hierarchical-right", () => layout (LayoutKind.HIERARCHICAL_RIGHT));
            act ("layout-force", () => layout (LayoutKind.FORCE));
            act ("layout-circle", () => layout (LayoutKind.CIRCLE));
            act ("layout-grid", () => layout (LayoutKind.GRID));
            act ("route-straight", () => set_route (RouteKind.STRAIGHT), true, true);
            act ("route-orthogonal", () => set_route (RouteKind.ORTHOGONAL), true, true);
            act ("route-curved", () => set_route (RouteKind.CURVED), true, true);
            act ("reset-bends", () => edit_sel (_("Reset Bends"), () => {
                foreach (var it in sel ()) {
                    var c = it as Connector;
                    if (c != null) c.waypoints = {};
                }
            }), true, true);
            act ("add-field", () => Dialogs.add_field (this, canvas.selection[0]), true, true);
            act ("tool-connection-point", () => canvas.use_tool (Tool.CONNECTION_POINT));
            act ("export-html", () => export_html.begin ());
            act ("presentation", () => OfficeUi.presentation (this));
            act ("slide-snippets", () => OfficeUi.snippets (this));
            act ("export-pptx", () => export_pptx.begin ());
            act ("check-diagram", () => OfficeUi.validate (this));
            act ("check-spelling", () => {
                end_text_edit (true);
                OfficeUi.spelling (this);
            });
            act ("add-comment", () => OfficeUi.add_comment (this));
            act ("link-data", () => OfficeUi.choose_data_file (this, true));
            act ("refresh-data", () => OfficeUi.refresh_data (this));
            act ("data-graphics", () => OfficeUi.data_graphics (this));
            act ("shape-report", () => OfficeUi.report (this));
            act ("merge-drawing", () => choose_merge ());
            act ("new-background-page", () => {
                var cur = doc.page;
                doc.begin (_("New Background Page"));
                var p = doc.add_page (doc.pages.size, _("Background %d").printf (count_backgrounds () + 1));
                p.is_background = true;
                if (!cur.is_background) cur.back_page = p.id;
                doc.commit ();
                rebuild_pages ();
                switch_page (p);
            });
            act ("insert-gantt", () => canvas.insert_library_shape ("gantt", 0, 0, false));
            act ("insert-cff", () => {
                var v = canvas.visible_rect ();
                doc.begin (_("Cross-Functional Flowchart"));
                var pool = Swimlanes.insert (doc, Math.round (v.x + 40), Math.round (v.y + 40), false, 3, _("Process"));
                doc.commit ();
                canvas.select_one (pool);
            });
            act ("add-callout", () => {
                var target = canvas.selection.size == 1 ? canvas.selection[0] as Shape : null;
                var v = canvas.visible_rect ();
                var c = canvas.create_shape ("callout", Rect (0, 0, 130, 70));
                c.style.fill = "#fff6c9";
                c.style.stroke = "#b59a2b";
                c.text = _("Callout");
                if (target != null) {
                    c.kind = "rectangle";
                    c.style.corner_radius = 6;
                    c.x = target.x + target.w + 40;
                    c.y = target.y - c.h - 20;
                    c.callout_target = target.id;
                } else {
                    c.x = v.cx () - c.w / 2;
                    c.y = v.cy () - c.h / 2;
                }
                doc.begin (_("Add Callout"));
                doc.add_item (c);
                doc.commit ();
                canvas.select_one (c);
                begin_text_edit (c, -1, -1);
            });
            act ("attach-callout", () => {
                if (canvas.selection.size != 2) return;
                var a = canvas.selection[0] as Shape;
                var b = canvas.selection[1] as Shape;
                if (a == null || b == null) return;
                doc.begin (_("Attach Callout"));
                if (b.w * b.h < a.w * a.h) b.callout_target = a.id;
                else a.callout_target = b.id;
                doc.commit ();
            }, true, true);
            act ("path-combine", () => shape_op ("combine"), true, true);
            act ("path-fragment", () => shape_op ("fragment"), true, true);
            act ("path-join", () => shape_op ("join"), true, true);
            act ("path-trim", () => shape_op ("trim"), true, true);
            act ("path-offset", () => {
                var target = canvas.selection.size >= 1 ? canvas.selection[0] as Shape : null;
                if (target == null) return;
                Dialogs.rename (this, _("Offset"), "10", (v) => {
                    double d = double.parse (v);
                    if (d == 0) return;
                    doc.begin (_("Offset"));
                    var made = new Gee.ArrayList<Item> ();
                    foreach (double dd in new double[] { d, -d }) {
                        var path = ShapeOps.offset (target, dd);
                        if (path.is_empty ()) continue;
                        var ps = new PathShape ();
                        ps.set_page_path (path);
                        ps.style = target.style.copy ();
                        ps.style.fill_kind = FillKind.NONE;
                        ps.layer_id = target.layer_id;
                        doc.add_item (ps);
                        made.add (ps);
                    }
                    doc.commit ();
                    canvas.select (made);
                });
            }, true, true);
            act ("close", () => close (), false);
            sync_actions ();
        }

        public async void export_stencil (UserStencil st) {
            string? path = yield ask_export_path (_("Export Stencil"), "vssx", _("Visio Stencil (.vssx)"));
            if (path == null) return;
            try {
                Formats.write_atomic (path, Vsdx.save_stencil (st));
                add_toast (new Toast (_("Exported %s").printf (Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        private int count_backgrounds () {
            int n = 0;
            foreach (var p in doc.pages) if (p.is_background) n++;
            return n;
        }

        public void open_stencil (string id) {
            set_sidebar_visible (true);
            library.open_stencil (id);
        }

        public void open_design () {
            Widget? anchor = null;
            foreach (var w in doc_bubbles) if (w.tooltip_text == _("Design: Themes and Quick Styles")) anchor = w;
            if (anchor != null) OfficeUi.design_popover (this, anchor);
        }

        public string[] quick_kinds () {
            return library.quick_kinds ();
        }

        private void shape_op (string op) {
            var shapes = new Gee.ArrayList<Shape> ();
            foreach (var it in doc.page.items) {
                if (!canvas.selection.contains (it)) continue;
                var s = it as Shape;
                if (s != null && !(s is ImageShape) && !(s is TableShape) && !(s is GanttShape)) shapes.add (s);
            }
            if (shapes.size < (op == "join" ? 1 : 2)) {
                add_toast (new Toast (_("Select two or more shapes first")));
                return;
            }
            var paths = new Gee.ArrayList<PathData> ();
            switch (op) {
                case "combine": paths.add (ShapeOps.combine (shapes)); break;
                case "join": paths.add (ShapeOps.join (shapes)); break;
                case "trim": paths.add_all (ShapeOps.trim (shapes)); break;
                default: paths.add_all (ShapeOps.fragment (shapes)); break;
            }
            var made = new Gee.ArrayList<Item> ();
            int index = doc.page.items.index_of (shapes[0]);
            doc.begin (_("Shape Operation"));
            doc.delete_items (shapes);
            foreach (var p in paths) {
                if (p.is_empty ()) continue;
                var ps = new PathShape ();
                ps.set_page_path (p);
                ps.style = shapes[0].style.copy ();
                if (op == "join" || !ps.is_closed ()) ps.style.fill_kind = op == "join" && ps.is_closed () ? ps.style.fill_kind : FillKind.NONE;
                ps.layer_id = shapes[0].layer_id;
                doc.add_item (ps, int.min (index++, doc.page.items.size));
                made.add (ps);
            }
            doc.commit ();
            canvas.select (made);
        }

        public void insert_report (ShapeReport rep) {
            var t = rep.to_table ();
            var v = canvas.visible_rect ();
            t.x = Math.round (v.cx () - t.w / 2);
            t.y = Math.round (v.cy () - t.h / 2);
            doc.begin (_("Shape Report"));
            doc.add_item (t);
            doc.commit ();
            canvas.select_one (t);
        }

        public async void save_report (ShapeReport rep, bool html) {
            string? path = yield ask_export_path (_("Save Report"), html ? "html" : "csv", html ? _("Web Page") : _("CSV File"));
            if (path == null) return;
            try {
                Formats.write_atomic (path, (html ? rep.to_html () : rep.to_csv ()).data);
                add_toast (new Toast (_("Exported %s").printf (Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        public async void export_html () {
            string? path = yield ask_export_path (_("Export as Web Page"), "html", _("Web Page"));
            if (path == null) return;
            try {
                Formats.write_atomic (path, HtmlExport.write (doc).data);
                add_toast (new Toast (_("Exported %s").printf (Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        private void choose_merge () {
            var dialog = new FileDialog ();
            dialog.title = _("Merge Changes from a Copy");
            var filters = new GLib.ListStore (typeof (FileFilter));
            filters.append (filter (_("Drawings"), Formats.open_suffixes ()));
            dialog.filters = filters;
            dialog.open.begin (this, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file == null) return;
                    var other = Formats.load (file.get_path ());
                    var result = DrawingMerge.compare (doc, other);
                    if (result.total () == 0) {
                        add_toast (new Toast (_("The copy has no changes")));
                        return;
                    }
                    doc.begin (_("Merge Changes"));
                    DrawingMerge.apply (doc, other, result);
                    doc.commit ();
                    rebuild_pages ();
                    add_toast (new Toast (_("Merged %d added, %d changed and %d removed shapes").printf (result.added, result.changed, result.removed)));
                } catch (Error e) {
                    if (!(e is Gtk.DialogError.DISMISSED)) show_error (_("Could Not Merge"), e.message);
                }
            });
        }

        private async void export_csv (Gee.List<Item> items) {
            string? path = yield ask_export_path (_("Export Shape Data"), "csv", _("CSV File"));
            if (path == null) return;
            try {
                Formats.write_atomic (path, DataImport.to_csv (items).data);
                add_toast (new Toast (_("Exported %s").printf (Path.get_basename (path))));
            } catch (Error e) {
                show_error (_("Could Not Export"), e.message);
            }
        }

        private Rect? align_ref () {
            if (canvas.selection.size == 1) return Rect (0, 0, doc.page.width, doc.page.height);
            return null;
        }

        private void set_route (RouteKind r) {
            edit_sel (_("Connector Style"), () => {
                foreach (var it in all_leaves ()) {
                    var c = it as Connector;
                    if (c != null) {
                        c.route = r;
                        c.waypoints = {};
                    }
                }
            });
            inspector.refresh ();
        }

        public void show_design (Widget anchor) {
            if (doc == null) return;
            end_text_edit (true);
            OfficeUi.design_popover (this, anchor);
        }

        public void show_comments (Widget anchor) {
            if (doc == null) return;
            OfficeUi.comments_popover (this, anchor);
        }

        public void zoom_percent (int percent) {
            if (canvas != null) canvas.zoom_to (percent / 100.0);
        }
    }
}
