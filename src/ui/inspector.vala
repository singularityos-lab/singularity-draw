using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class ColorButton : Button {
        private string _value = "#000000";
        private DrawingArea swatch;
        private bool allow_none;
        public signal void picked (string color);

        public const string[] PALETTE = {
            "#ffffff", "#f2f2f2", "#d9d9d9", "#a6a6a6", "#7f7f7f", "#595959", "#3a3a3a", "#1e1e1e",
            "#fdecea", "#fbd3d0", "#f4a19b", "#e5534b", "#c62828", "#8e1c1c", "#fde7d4", "#f9b98a",
            "#f08a3c", "#c75c12", "#fff6c9", "#ffe98a", "#f5c518", "#b8930b", "#e8f5e0", "#bfe3b0",
            "#6fbf5a", "#2e7d32", "#dff4f1", "#a3dfd6", "#35a797", "#1b6e63", "#e3eefb", "#b7d3f4",
            "#5b9bd5", "#3a6ea5", "#1f4e79", "#ece4f7", "#c9b3ec", "#8a63c9", "#5a3a8f", "#f7e1ef"
        };

        public ColorButton (string value, bool allow_none = true) {
            this.allow_none = allow_none;
            _value = value;
            add_css_class ("draw-color-button");
            valign = Align.CENTER;
            swatch = new DrawingArea ();
            swatch.set_size_request (34, 18);
            swatch.set_draw_func ((a, cr, w, h) => {
                Rgba c;
                if (Colors.parse (_value, out c) && c.a > 0) {
                    cr.set_source_rgb (1, 1, 1);
                    cr.rectangle (1, 1, w - 2, h - 2);
                    cr.fill ();
                    c.apply (cr);
                    cr.rectangle (1, 1, w - 2, h - 2);
                    cr.fill ();
                } else {
                    cr.set_source_rgb (1, 1, 1);
                    cr.rectangle (1, 1, w - 2, h - 2);
                    cr.fill ();
                    cr.set_source_rgb (0.85, 0.2, 0.2);
                    cr.set_line_width (1.5);
                    cr.move_to (2, h - 2);
                    cr.line_to (w - 2, 2);
                    cr.stroke ();
                }
                cr.set_source_rgba (0, 0, 0, 0.3);
                cr.set_line_width (1);
                cr.rectangle (1.5, 1.5, w - 3, h - 3);
                cr.stroke ();
            });
            child = swatch;
            clicked.connect (open_palette);
        }

        public string value {
            get { return _value; }
            set {
                _value = value;
                swatch.queue_draw ();
            }
        }

        private void open_palette () {
            var pop = new Popover ();
            pop.add_css_class ("draw-palette");
            var box = new Box (Orientation.VERTICAL, 8);
            box.margin_top = 8;
            box.margin_bottom = 8;
            box.margin_start = 8;
            box.margin_end = 8;
            var grid = new Grid ();
            grid.row_spacing = 4;
            grid.column_spacing = 4;
            for (int i = 0; i < PALETTE.length; i++) {
                string c = PALETTE[i];
                var b = new Button ();
                b.add_css_class ("draw-swatch");
                b.tooltip_text = c;
                var dot = new DrawingArea ();
                dot.set_size_request (20, 20);
                dot.set_draw_func ((a, cr, w, h) => {
                    Rgba rc;
                    Colors.parse (c, out rc);
                    rc.apply (cr);
                    cr.arc (w / 2.0, h / 2.0, w / 2.0 - 1, 0, 2 * Math.PI);
                    cr.fill_preserve ();
                    cr.set_source_rgba (0, 0, 0, 0.25);
                    cr.set_line_width (1);
                    cr.stroke ();
                });
                b.child = dot;
                b.clicked.connect (() => {
                    pop.popdown ();
                    set_and_emit (c);
                });
                grid.attach (b, i % 8, i / 8);
            }
            box.append (grid);
            var recent = new Singularity.Widgets.RecentColorsRow (8);
            recent.picked.connect ((h) => {
                pop.popdown ();
                set_and_emit (h);
            });
            box.append (recent);
            var row = new Box (Orientation.HORIZONTAL, 6);
            if (allow_none) {
                var none = new Button.with_label (_("No Color"));
                none.hexpand = true;
                none.clicked.connect (() => {
                    pop.popdown ();
                    set_and_emit ("none");
                });
                row.append (none);
            }
            var custom = new Button.with_label (_("Custom…"));
            custom.hexpand = true;
            custom.clicked.connect (() => {
                pop.popdown ();
                open_custom ();
            });
            row.append (custom);
            box.append (row);
            pop.child = box;
            pop.set_parent (this);
            pop.closed.connect (() => Idle.add (() => {
                pop.unparent ();
                return Source.REMOVE;
            }));
            pop.popup ();
        }

        private void open_custom () {
            var pop = new Popover ();
            var box = new Box (Orientation.VERTICAL, 8);
            box.margin_top = 8;
            box.margin_bottom = 8;
            box.margin_start = 8;
            box.margin_end = 8;
            var chooser = new ColorChooserWidget ();
            chooser.use_alpha = true;
            chooser.show_editor = true;
            Rgba c;
            var g = Gdk.RGBA ();
            if (Colors.parse (_value, out c)) {
                g.red = (float) c.r;
                g.green = (float) c.g;
                g.blue = (float) c.b;
                g.alpha = (float) c.a;
            } else {
                g.parse ("#3a6ea5");
            }
            chooser.rgba = g;
            box.append (chooser);
            var apply = new Button.with_label (_("Apply"));
            apply.add_css_class ("suggested-action");
            apply.halign = Align.END;
            apply.clicked.connect (() => {
                var v = chooser.rgba;
                pop.popdown ();
                set_and_emit (Colors.to_hex (Rgba (v.red, v.green, v.blue, v.alpha), true));
            });
            box.append (apply);
            pop.child = box;
            pop.set_parent (this);
            pop.closed.connect (() => Idle.add (() => {
                pop.unparent ();
                return Source.REMOVE;
            }));
            pop.popup ();
        }

        private void set_and_emit (string c) {
            value = c;
            picked (c);
        }
    }

    public class Inspector : Box {
        private DrawWindow win;
        private Box content;
        private ScrolledWindow scroll;
        private bool updating = false;

        public Inspector (DrawWindow win) {
            Object (orientation: Orientation.VERTICAL, spacing: 0);
            this.win = win;
            add_css_class ("draw-inspector");
            set_size_request (300, -1);
            hexpand = false;
            scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.vexpand = true;
            scroll.hexpand = false;
            scroll.propagate_natural_width = false;
            content = new Box (Orientation.VERTICAL, 18);
            content.margin_start = 14;
            content.margin_end = 14;
            content.margin_top = 12;
            content.margin_bottom = 24;
            scroll.child = content;
            append (scroll);
        }

        private Document doc {
            get { return win.doc; }
        }

        public void scroll_to_end () {
            scroll.vadjustment.value = scroll.vadjustment.upper;
        }

        private Canvas canvas {
            get { return win.canvas; }
        }

        private Gee.ArrayList<Item> leaves () {
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

        public delegate void StyleEdit (Style st, Item it);

        private void edit_style (string label, owned StyleEdit fn) {
            if (updating) return;
            doc.begin (label);
            doc.merge_pending ();
            foreach (var it in leaves ()) fn (it.style, it);
            doc.commit ();
            if (label == _("Fill") || label == _("Shadow")) refresh_later ();
        }

        private uint refresh_id = 0;

        public void refresh_later () {
            if (refresh_id != 0) return;
            refresh_id = Idle.add (() => {
                refresh_id = 0;
                refresh ();
                return Source.REMOVE;
            });
        }

        private bool last_empty = true;

        public void refresh () {
            if (win.doc == null) return;
            bool empty = canvas.selection.size == 0;
            double keep = empty == last_empty ? scroll.vadjustment.value : 0;
            last_empty = empty;
            Idle.add (() => {
                scroll.vadjustment.value = keep;
                return Source.REMOVE;
            });
            updating = true;
            Widget? child;
            while ((child = content.get_first_child ()) != null) content.remove (child);
            if (win.paint != null && win.paint.active) PaintPanel.build (win, content);
            else if (canvas.selection.size == 0) build_page ();
            else build_selection ();
            updating = false;
        }

        private ActionRow color_row (string title, string value, bool allow_none, owned ColorCallback cb) {
            var row = new ActionRow (title);
            var btn = new ColorButton (value, allow_none);
            btn.picked.connect ((c) => cb (c));
            row.add_suffix (btn);
            return row;
        }

        public delegate void ColorCallback (string c);

        private SpinRow spin_row (string title, double min, double max, double step, double value, int digits, owned SpinCallback cb) {
            var row = new SpinRow (title, null, min, max, step, value);
            row.spin_btn.digits = digits;
            row.notify["value"].connect (() => {
                if (!updating) cb (row.value);
            });
            return row;
        }

        public delegate void SpinCallback (double v);

        private SelectionRow choice_row (string title, owned string[] labels, int current, owned ChoiceCallback cb) {
            var row = new SelectionRow (title, labels, labels[current.clamp (0, labels.length - 1)]);
            row.selected.connect ((item) => {
                if (updating) return;
                for (int i = 0; i < labels.length; i++) if (labels[i] == item) cb (i);
            });
            return row;
        }

        public delegate void ChoiceCallback (int index);

        private SwitchRow switch_row (string title, bool active, owned ToggleCallback cb) {
            var row = new SwitchRow (title, null, active);
            row.notify["active"].connect (() => {
                if (!updating) cb (row.active);
            });
            return row;
        }

        public delegate void ToggleCallback (bool on);

        private static string[] fill_labels () {
            return { _("None"), _("Solid"), _("Linear Gradient"), _("Radial Gradient") };
        }

        public static string[] dash_labels () {
            return { _("Solid"), _("Dashed"), _("Dotted"), _("Dash Dot"), _("Long Dash"), _("Dash Dot Dot") };
        }

        public static string[] arrow_labels () {
            return { _("None"), _("Filled Triangle"), _("Open Arrow"), _("Stealth"), _("Hollow Triangle"), _("Filled Diamond"), _("Hollow Diamond"), _("Filled Circle"), _("Hollow Circle"), _("Bar"), _("Crow's Foot"), _("One") };
        }

        private static int arrow_index (ArrowKind k) {
            var all = ArrowKind.all ();
            for (int i = 0; i < all.length; i++) if (all[i] == k) return i;
            return 0;
        }

        private void build_selection () {
            var items = leaves ();
            if (items.size == 0) return;
            var first = items[0];
            var st = first.style;
            bool any_shape = false, any_line = false, any_conn = false, any_table = false;
            foreach (var it in items) {
                if (it is Connector) {
                    any_conn = true;
                    any_line = true;
                } else if (it is PathShape && !((PathShape) it).is_closed ()) {
                    any_line = true;
                } else if (it is Shape) {
                    any_shape = true;
                    if ((it as Shape).kind == "line-shape") any_line = true;
                }
                if (it is TableShape) any_table = true;
            }
            string what = items.size == 1 ? describe (first) : _("%d Objects").printf (items.size);
            var head = new Label (what);
            head.add_css_class ("title-4");
            head.halign = Align.START;
            content.append (head);

            if (any_shape) {
                var fill = new PreferencesGroup (_("Fill"));
                fill.add_row (choice_row (_("Type"), fill_labels (), (int) st.fill_kind, (i) => edit_style (_("Fill"), (s) => s.fill_kind = (FillKind) i)));
                fill.add_row (color_row (_("Color"), st.fill, true, (c) => edit_style (_("Fill Color"), (s) => {
                    s.fill = c;
                    if (s.fill_kind == FillKind.NONE && !Colors.is_none (c)) s.fill_kind = FillKind.SOLID;
                })));
                if (st.fill_kind == FillKind.LINEAR || st.fill_kind == FillKind.RADIAL) {
                    fill.add_row (color_row (_("Second Color"), st.fill2, true, (c) => edit_style (_("Gradient"), (s) => s.fill2 = c)));
                    if (st.fill_kind == FillKind.LINEAR) fill.add_row (spin_row (_("Angle"), 0, 360, 15, st.gradient_angle, 0, (v) => edit_style (_("Gradient"), (s) => s.gradient_angle = v)));
                }
                content.append (fill);
            }

            var line = new PreferencesGroup (any_conn ? _("Connector") : _("Line"));
            line.add_row (color_row (_("Color"), st.stroke, true, (c) => edit_style (_("Line Color"), (s) => s.stroke = c)));
            line.add_row (spin_row (_("Width"), 0, 40, 0.5, st.stroke_width, 1, (v) => edit_style (_("Line Width"), (s) => s.stroke_width = v)));
            line.add_row (choice_row (_("Dash"), dash_labels (), (int) st.dash, (i) => edit_style (_("Dash"), (s) => s.dash = (DashKind) i)));
            if (any_line) {
                var all = ArrowKind.all ();
                line.add_row (choice_row (_("Start"), arrow_labels (), arrow_index (st.arrow_start), (i) => edit_style (_("Arrowhead"), (s) => s.arrow_start = all[i])));
                line.add_row (choice_row (_("End"), arrow_labels (), arrow_index (st.arrow_end), (i) => edit_style (_("Arrowhead"), (s) => s.arrow_end = all[i])));
                line.add_row (spin_row (_("Arrow Size"), 0.5, 4, 0.25, st.arrow_size, 2, (v) => edit_style (_("Arrowhead"), (s) => s.arrow_size = v)));
            }
            if (any_conn) {
                var c = first as Connector;
                if (c != null) {
                    string[] routes = { _("Straight"), _("Orthogonal"), _("Curved") };
                    line.add_row (choice_row (_("Routing"), routes, (int) c.route, (i) => edit_style (_("Routing"), (s, it) => {
                        var cc = it as Connector;
                        if (cc != null) {
                            cc.route = (RouteKind) i;
                            if (cc.route != RouteKind.STRAIGHT) cc.waypoints = {};
                        }
                    })));
                    line.add_row (spin_row (_("Label Position"), 0, 100, 5, c.label_pos * 100, 0, (v) => edit_style (_("Label Position"), (s, it) => {
                        var cc = it as Connector;
                        if (cc != null) cc.label_pos = v / 100;
                    })));
                }
            }
            if (any_shape) line.add_row (spin_row (_("Corner Radius"), 0, 200, 1, st.corner_radius, 0, (v) => edit_style (_("Corner Radius"), (s) => s.corner_radius = v)));
            content.append (line);

            content.append (text_group (st));

            var fx = new PreferencesGroup (_("Effects"));
            fx.add_row (switch_row (_("Shadow"), st.shadow, (on) => edit_style (_("Shadow"), (s) => s.shadow = on)));
            if (st.shadow) {
                fx.add_row (color_row (_("Shadow Color"), st.shadow_color, false, (c) => edit_style (_("Shadow"), (s) => s.shadow_color = c)));
                fx.add_row (spin_row (_("Blur"), 0, 40, 1, st.shadow_blur, 0, (v) => edit_style (_("Shadow"), (s) => s.shadow_blur = v)));
                fx.add_row (spin_row (_("Offset"), -40, 40, 1, st.shadow_dy, 0, (v) => edit_style (_("Shadow"), (s) => {
                    s.shadow_dx = v * 0.75;
                    s.shadow_dy = v;
                })));
            }
            fx.add_row (spin_row (_("Opacity"), 0, 100, 5, st.opacity * 100, 0, (v) => edit_style (_("Opacity"), (s) => s.opacity = v / 100)));
            content.append (fx);

            if (any_table && items.size == 1) content.append (table_group (first as TableShape));

            if (canvas.selection.size == 1) {
                var sel = canvas.selection[0];
                var sh = sel as Shape;
                var b = sel.bounds ();
                var arrange = new PreferencesGroup (_("Position and Size"), _("In %s, measured from the top left corner of the page.").printf (unit_name ()));
                double u = unit_px ();
                if (sh != null) {
                    arrange.add_row (spin_row (_("X"), -100000, 100000, 1, sh.x / u, 2, (v) => geometry_edit ((s) => s.x = v * u)));
                    arrange.add_row (spin_row (_("Y"), -100000, 100000, 1, sh.y / u, 2, (v) => geometry_edit ((s) => s.y = v * u)));
                    arrange.add_row (spin_row (_("Width"), 0, 100000, 1, sh.w / u, 2, (v) => geometry_edit ((s) => s.w = v * u)));
                    arrange.add_row (spin_row (_("Height"), 0, 100000, 1, sh.h / u, 2, (v) => geometry_edit ((s) => s.h = v * u)));
                    arrange.add_row (spin_row (_("Rotation"), 0, 359, 1, sh.rotation, 0, (v) => geometry_edit ((s) => s.rotation = v)));
                    arrange.add_row (switch_row (_("Locked"), sh.locked, (on) => {
                        doc.begin (on ? _("Lock") : _("Unlock"));
                        sel.locked = on;
                        doc.commit ();
                    }));
                } else {
                    var info = new ActionRow (_("Bounds"), "%s × %s %s".printf (PathData.fmt (b.w / u, 1), PathData.fmt (b.h / u, 1), unit_name ()));
                    arrange.add_row (info);
                }
                content.append (arrange);
                content.append (data_group (sel));
                content.append (linked_data_group (sel));
                content.append (alt_text_group (sel));
                content.append (ShapeSheetPanel.build (win, sel));
                if (sh != null) {
                    var lane_pool = Swimlanes.pool_for (doc.page, sh);
                    if (lane_pool != null) content.append (swimlane_group (sh, lane_pool));
                    var gs = sh as GanttShape;
                    if (gs != null) content.append (gantt_group (gs));
                    content.append (points_group (sh));
                    if (sh.callout_target != "") content.append (callout_group (sh));
                }
                if (sel.link != "" || sh != null) {
                    var lg = new PreferencesGroup (_("Hyperlink"));
                    var entry = new EntryRow (_("Address"));
                    entry.text = sel.link;
                    entry.entry_activated.connect (() => {
                        doc.begin (_("Hyperlink"));
                        sel.link = entry.text.strip ();
                        doc.commit ();
                    });
                    lg.add_row (entry);
                    content.append (lg);
                }
            }
        }

        public delegate void GeometryEdit (Shape s);

        private void geometry_edit (owned GeometryEdit fn) {
            if (updating || canvas.selection.size != 1) return;
            var s = canvas.selection[0] as Shape;
            if (s == null) return;
            doc.begin (_("Position and Size"));
            doc.merge_pending ();
            fn (s);
            doc.commit ();
        }

        private string describe (Item it) {
            if (it is Connector) return _("Connector");
            if (it is Group) return _("Group");
            var s = it as Shape;
            if (s != null) return ShapeLibrary.display_name (s.kind);
            return _("Object");
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

        private string unit_name () {
            switch (doc.units) {
                case "mm": return _("millimeters");
                case "cm": return _("centimeters");
                case "in": return _("inches");
                case "pt": return _("points");
                default: return _("pixels");
            }
        }

        private PreferencesGroup text_group (Style st) {
            var g = new PreferencesGroup (_("Text"));
            string[] families = { "Sans", "Serif", "Monospace", "Inter", "Cantarell", "DejaVu Sans", "Liberation Sans", "Liberation Serif", "Noto Sans", "Noto Serif" };
            string[] fam = families;
            bool found = false;
            foreach (string f in families) if (f == st.font_family) found = true;
            if (!found) {
                string[] extended = { st.font_family };
                foreach (string f in families) extended += f;
                fam = extended;
            }
            int cur = 0;
            for (int i = 0; i < fam.length; i++) if (fam[i] == st.font_family) cur = i;
            string[] fam_copy = fam;
            g.add_row (choice_row (_("Font"), fam, cur, (i) => edit_style (_("Font"), (s) => s.font_family = fam_copy[i])));
            g.add_row (spin_row (_("Size"), 4, 144, 1, st.font_size, 1, (v) => edit_style (_("Font Size"), (s) => s.font_size = v)));
            var fmt = new ActionRow (_("Style"));
            var fbox = new Box (Orientation.HORIZONTAL, 4);
            fbox.valign = Align.CENTER;
            fbox.append (toggle ("format-text-bold-symbolic", _("Bold (Ctrl+B)"), st.bold, (on) => edit_style (_("Bold"), (s) => s.bold = on)));
            fbox.append (toggle ("format-text-italic-symbolic", _("Italic (Ctrl+I)"), st.italic, (on) => edit_style (_("Italic"), (s) => s.italic = on)));
            fbox.append (toggle ("format-text-underline-symbolic", _("Underline (Ctrl+U)"), st.underline, (on) => edit_style (_("Underline"), (s) => s.underline = on)));
            fbox.append (toggle ("format-text-strikethrough-symbolic", _("Strikethrough"), st.strike, (on) => edit_style (_("Strikethrough"), (s) => s.strike = on)));
            fmt.add_suffix (fbox);
            g.add_row (fmt);
            var align = new ActionRow (_("Alignment"));
            var abox = new Box (Orientation.HORIZONTAL, 4);
            abox.valign = Align.CENTER;
            abox.append (toggle ("format-justify-left-symbolic", _("Align Left"), st.halign == TextHAlign.LEFT, (on) => edit_style (_("Align"), (s) => s.halign = TextHAlign.LEFT), true));
            abox.append (toggle ("format-justify-center-symbolic", _("Center"), st.halign == TextHAlign.CENTER, (on) => edit_style (_("Align"), (s) => s.halign = TextHAlign.CENTER), true));
            abox.append (toggle ("format-justify-right-symbolic", _("Align Right"), st.halign == TextHAlign.RIGHT, (on) => edit_style (_("Align"), (s) => s.halign = TextHAlign.RIGHT), true));
            align.add_suffix (abox);
            g.add_row (align);
            string[] valigns = { _("Top"), _("Middle"), _("Bottom") };
            g.add_row (choice_row (_("Vertical Position"), valigns, (int) st.valign, (i) => edit_style (_("Align"), (s) => s.valign = (TextVAlign) i)));
            g.add_row (color_row (_("Color"), st.text_color, false, (c) => edit_style (_("Text Color"), (s) => s.text_color = c)));
            g.add_row (switch_row (_("Wrap Text"), st.wrap, (on) => edit_style (_("Wrap Text"), (s) => s.wrap = on)));
            return g;
        }

        private ToggleButton toggle (string icon, string tip, bool active, owned ToggleCallback cb, bool radio = false) {
            var b = new ToggleButton ();
            b.icon_name = icon;
            b.tooltip_text = tip;
            b.active = active;
            b.add_css_class ("flat");
            b.add_css_class ("draw-toggle");
            b.toggled.connect (() => {
                if (updating) return;
                if (radio && !b.active) {
                    updating = true;
                    b.active = true;
                    updating = false;
                    return;
                }
                cb (b.active);
            });
            return b;
        }

        private PreferencesGroup table_group (TableShape t) {
            var g = new PreferencesGroup (_("Table"));
            g.add_row (spin_row (_("Rows"), 1, 200, 1, t.rows, 0, (v) => {
                doc.begin (_("Table Size"));
                doc.merge_pending ();
                t.resize_grid ((int) v, t.cols);
                doc.commit ();
            }));
            g.add_row (spin_row (_("Columns"), 1, 50, 1, t.cols, 0, (v) => {
                doc.begin (_("Table Size"));
                doc.merge_pending ();
                t.resize_grid (t.rows, (int) v);
                doc.commit ();
            }));
            g.add_row (switch_row (_("Header Row"), t.header_row, (on) => {
                doc.begin (_("Header Row"));
                t.header_row = on;
                doc.commit ();
            }));
            g.add_row (color_row (_("Header Color"), t.header_fill, true, (c) => {
                doc.begin (_("Header Color"));
                t.header_fill = c;
                doc.commit ();
            }));
            return g;
        }

        private PreferencesGroup data_group (Item it) {
            var g = new PreferencesGroup (_("Shape Data"), _("Use {Name} in the text to show a field."));
            var add = new Button.with_label (_("Add Field"));
            add.valign = Align.CENTER;
            add.clicked.connect (() => win.add_field_dialog (it));
            g.add_header_suffix (add);
            foreach (var f in it.fields) {
                var field = f;
                var row = new EntryRow (f.key);
                row.text = f.value;
                row.entry_activated.connect (() => {
                    doc.begin (_("Shape Data"));
                    it.set_field (field.key, row.text);
                    doc.commit ();
                });
                var rm = new Button.from_icon_name ("user-trash-symbolic");
                rm.add_css_class ("flat");
                rm.valign = Align.CENTER;
                rm.tooltip_text = _("Remove Field");
                rm.clicked.connect (() => {
                    doc.begin (_("Remove Field"));
                    it.remove_field (field.key);
                    doc.commit ();
                });
                row.add_suffix (rm);
                g.add_row (row);
            }
            if (it.fields.size == 0) {
                var none = new ActionRow (_("No Fields"), _("Add a field or link data from a CSV file."));
                g.add_row (none);
            }
            return g;
        }

        private PreferencesGroup linked_data_group (Item it) {
            var g = new PreferencesGroup (_("Linked Data"), _("Rows linked from a spreadsheet, CSV file or database refresh with the source."));
            var src = doc.find_source (it.data_source);
            if (src == null) {
                if (doc.data_sources.size == 0) {
                    var row = new ActionRow (_("No Data Source"), _("Link a spreadsheet, CSV file or database from the Data menu."));
                    g.add_row (row);
                    return g;
                }
                string[] names = {};
                foreach (var d in doc.data_sources) names += d.name.has_prefix ("process:") || d.name.has_prefix ("org:") ? d.name.substring (d.name.index_of (":") + 1) : d.name;
                var pick = new ActionRow (_("Link to a Row"), _("Choose a row of a data source for this shape."));
                var btn = new Button.with_label (_("Choose"));
                btn.valign = Align.CENTER;
                btn.clicked.connect (() => OfficeUi.choose_row (win, it));
                pick.add_suffix (btn);
                g.add_row (pick);
                return g;
            }
            var info = new ActionRow (src.name.has_prefix ("process:") || src.name.has_prefix ("org:") ? src.name.substring (src.name.index_of (":") + 1) : src.name,
                "%s: %s".printf (src.key_column != "" ? src.key_column : _("Row"), it.data_key));
            var unlink = new Button.with_label (_("Unlink"));
            unlink.valign = Align.CENTER;
            unlink.clicked.connect (() => {
                doc.begin (_("Unlink Data"));
                DataSources.unlink (it);
                doc.commit ();
                refresh_later ();
            });
            info.add_suffix (unlink);
            g.add_row (info);
            string[] names = { _("None") };
            string[] ids = { "" };
            foreach (var dg in doc.data_graphics) {
                names += dg.name;
                ids += dg.id;
            }
            int cur = 0;
            for (int i = 0; i < ids.length; i++) if (ids[i] == it.data_graphic) cur = i;
            if (names.length > 1) {
                g.add_row (choice_row (_("Data Graphic"), names, cur, (i) => {
                    doc.begin (_("Data Graphic"));
                    foreach (var x in leaves ()) x.data_graphic = ids[i];
                    doc.commit ();
                }));
            }
            return g;
        }

        private PreferencesGroup alt_text_group (Item it) {
            var g = new PreferencesGroup (_("Alt Text"), _("Describes the shape for screen readers and in exported web pages, PDF and SVG files."));
            var title = new EntryRow (_("Title"));
            title.text = it.alt_title;
            title.entry_activated.connect (() => {
                doc.begin (_("Alt Text"));
                it.alt_title = title.text.strip ();
                doc.commit ();
            });
            var desc = new EntryRow (_("Description"));
            desc.text = it.alt_text;
            desc.entry_activated.connect (() => {
                doc.begin (_("Alt Text"));
                it.alt_text = desc.text.strip ();
                doc.commit ();
            });
            g.add_row (title);
            g.add_row (desc);
            return g;
        }

        private PreferencesGroup points_group (Shape s) {
            var g = new PreferencesGroup (_("Connection Points"));
            var row = new ActionRow (ngettext ("%d point", "%d points", s.ports ().length).printf (s.ports ().length),
                s.custom_ports != null ? _("Custom points") : _("Standard points of the shape"));
            var edit = new Button.with_label (_("Edit"));
            edit.valign = Align.CENTER;
            edit.tooltip_text = _("Click the outline to add a point, select a point and press Delete to remove it");
            edit.clicked.connect (() => canvas.use_tool (Tool.CONNECTION_POINT));
            row.add_suffix (edit);
            if (s.custom_ports != null) {
                var reset = new Button.with_label (_("Reset"));
                reset.valign = Align.CENTER;
                reset.clicked.connect (() => {
                    canvas.reset_ports (s);
                    refresh_later ();
                });
                row.add_suffix (reset);
            }
            g.add_row (row);
            return g;
        }

        private PreferencesGroup callout_group (Shape s) {
            var g = new PreferencesGroup (_("Callout"));
            var target = doc.page.find (s.callout_target);
            string what = target != null ? (target.display_text ().strip () != "" ? target.display_text ().split ("\n")[0] : describe (target)) : _("Missing shape");
            var row = new ActionRow (_("Attached To"), what);
            var detach = new Button.with_label (_("Detach"));
            detach.valign = Align.CENTER;
            detach.clicked.connect (() => {
                doc.begin (_("Detach Callout"));
                s.callout_target = "";
                doc.commit ();
                refresh_later ();
            });
            row.add_suffix (detach);
            g.add_row (row);
            return g;
        }

        private Button small_button (string label, owned Singularity.Widgets.Window.BubbleAction action) {
            var b = new Button.with_label (label);
            b.valign = Align.CENTER;
            b.clicked.connect (() => action ());
            return b;
        }

        private PreferencesGroup swimlane_group (Shape sel, Shape pool) {
            var g = new PreferencesGroup (_("Cross-Functional Flowchart"), _("Lanes hold the steps of one function; phases split the process in stages."));
            bool lane = Swimlanes.is_lane (sel);
            var lanes_row = new ActionRow (_("Lanes"), ngettext ("%d lane", "%d lanes", Swimlanes.lanes (doc.page, pool).size).printf (Swimlanes.lanes (doc.page, pool).size));
            lanes_row.add_suffix (small_button (_("Add Lane"), () => {
                doc.begin (_("Add Lane"));
                var ls = Swimlanes.lanes (doc.page, pool);
                int idx = lane ? ls.index_of (sel) + 1 : ls.size;
                var nl = Swimlanes.add_lane (doc, pool, idx, _("Function %d").printf (ls.size + 1));
                doc.commit ();
                canvas.select_one (nl);
            }));
            g.add_row (lanes_row);
            if (lane) {
                var lr = new ActionRow (_("This Lane"));
                lr.add_suffix (small_button (_("Up"), () => {
                    doc.begin (_("Move Lane"));
                    if (Swimlanes.move_lane (doc, sel, -1)) doc.commit ();
                    else doc.cancel ();
                }));
                lr.add_suffix (small_button (_("Down"), () => {
                    doc.begin (_("Move Lane"));
                    if (Swimlanes.move_lane (doc, sel, 1)) doc.commit ();
                    else doc.cancel ();
                }));
                lr.add_suffix (small_button (_("Delete"), () => {
                    doc.begin (_("Delete Lane"));
                    Swimlanes.remove_lane (doc, sel);
                    doc.commit ();
                    canvas.select_one (pool);
                }));
                g.add_row (lr);
            }
            var ph = new ActionRow (_("Phases"), ngettext ("%d phase", "%d phases", Swimlanes.phases (doc.page, pool).size).printf (Swimlanes.phases (doc.page, pool).size));
            ph.add_suffix (small_button (_("Add Phase"), () => {
                doc.begin (_("Add Phase"));
                Swimlanes.add_phase (doc, pool, _("Phase %d").printf (Swimlanes.phases (doc.page, pool).size + 1));
                doc.commit ();
                refresh_later ();
            }));
            g.add_row (ph);
            string[] orient = { _("Horizontal"), _("Vertical") };
            g.add_row (choice_row (_("Orientation"), orient, Swimlanes.vertical (pool) ? 1 : 0, (i) => {
                doc.begin (_("Orientation"));
                Swimlanes.set_orientation (doc, pool, i == 1);
                doc.commit ();
                refresh_later ();
            }));
            return g;
        }

        private PreferencesGroup gantt_group (GanttShape gs) {
            var g = new PreferencesGroup (_("Gantt Chart"), _("Dates as YYYY-MM-DD, duration in days (0 for a milestone), predecessors as task numbers."));
            string[] scales = { _("Days"), _("Weeks"), _("Months") };
            string[] scale_ids = { "day", "week", "month" };
            int sc = 1;
            for (int i = 0; i < 3; i++) if (scale_ids[i] == gs.scale) sc = i;
            g.add_row (choice_row (_("Timescale"), scales, sc, (i) => {
                doc.begin (_("Gantt Chart"));
                gs.scale = scale_ids[i];
                doc.commit ();
            }));
            for (int i = 0; i < gs.tasks.size; i++) {
                var t = gs.tasks[i];
                int index = i;
                var exp = new ExpanderRow ("%d. %s".printf (i + 1, t.name), t.milestone () ? _("Milestone on %s").printf (t.start) : _("%s, %d days, %d%% done").printf (t.start, t.duration, (int) Math.round (t.progress * 100)));
                var name = new EntryRow (_("Task"));
                name.text = t.name;
                name.entry_activated.connect (() => gantt_edit (gs, () => t.name = name.text));
                var start = new EntryRow (_("Start"));
                start.text = t.start;
                start.entry_activated.connect (() => gantt_edit (gs, () => {
                    if (GanttShape.parse_date (start.text) != null) t.start = start.text.strip ();
                }));
                var dur = new SpinRow (_("Duration"), null, 0, 3650, 1, t.duration);
                dur.notify["value"].connect (() => gantt_edit (gs, () => t.duration = (int) dur.value));
                var prog = new SpinRow (_("Complete"), null, 0, 100, 5, t.progress * 100);
                prog.notify["value"].connect (() => gantt_edit (gs, () => t.progress = prog.value / 100));
                var deps = new EntryRow (_("Predecessors"));
                deps.text = t.depends;
                deps.entry_activated.connect (() => gantt_edit (gs, () => t.depends = deps.text));
                var lvl = new SpinRow (_("Outline Level"), null, 0, 5, 1, t.level);
                lvl.notify["value"].connect (() => gantt_edit (gs, () => t.level = (int) lvl.value));
                var rm = new ActionRow (_("Remove Task"));
                rm.add_suffix (small_button (_("Remove"), () => gantt_edit (gs, () => gs.tasks.remove_at (index), true)));
                exp.add_row (name);
                exp.add_row (start);
                exp.add_row (dur);
                exp.add_row (prog);
                exp.add_row (deps);
                exp.add_row (lvl);
                exp.add_row (rm);
                g.add_row (exp);
            }
            g.add_header_suffix (small_button (_("Add Task"), () => gantt_edit (gs, () => {
                var t = new GanttTask ();
                t.name = _("New Task");
                Date first, last;
                if (gs.range (out first, out last)) t.start = GanttShape.format_date (last);
                else {
                    var d = Date ();
                    d.set_time_t ((time_t) new DateTime.now_local ().to_unix ());
                    t.start = GanttShape.format_date (d);
                }
                t.duration = 5;
                gs.tasks.add (t);
            }, true)));
            return g;
        }

        private void gantt_edit (GanttShape gs, owned Singularity.Widgets.Window.BubbleAction fn, bool structural = false) {
            if (updating) return;
            doc.begin (_("Gantt Chart"));
            doc.merge_pending ();
            fn ();
            gs.schedule ();
            gs.fit_height ();
            doc.commit ();
            if (structural) refresh_later ();
        }

        private void build_page () {
            var page = doc.page;
            var head = new Label (page.name);
            head.add_css_class ("title-4");
            head.halign = Align.START;
            content.append (head);
            var pg = new PreferencesGroup (_("Page"));
            var name = new EntryRow (_("Name"));
            name.text = page.name;
            name.entry_activated.connect (() => {
                string n = name.text.strip ();
                if (n == "" || n == page.name) return;
                doc.begin (_("Rename Page"));
                page.name = n;
                doc.commit ();
                doc.pages_changed ();
            });
            pg.add_row (name);
            string[] sizes = { _("A4"), _("A3"), _("A5"), _("Letter"), _("Legal"), _("Tabloid"), _("Screen 16:9"), _("Custom") };
            double[] ws = { 793.7, 1122.52, 559.37, 816, 816, 1056, 1280 };
            double[] hs = { 1122.52, 1587.4, 793.7, 1056, 1344, 1632, 720 };
            double shortside = double.min (page.width, page.height), longside = double.max (page.width, page.height);
            int cur = sizes.length - 1;
            for (int i = 0; i < ws.length; i++) {
                if ((double.min (ws[i], hs[i]) - shortside).abs () < 1 && (double.max (ws[i], hs[i]) - longside).abs () < 1) cur = i;
            }
            pg.add_row (choice_row (_("Size"), sizes, cur, (i) => {
                if (i >= ws.length) return;
                bool land = page.width > page.height;
                doc.begin (_("Page Size"));
                page.width = land ? double.max (ws[i], hs[i]) : double.min (ws[i], hs[i]);
                page.height = land ? double.min (ws[i], hs[i]) : double.max (ws[i], hs[i]);
                doc.commit ();
                refresh ();
            }));
            string[] orient = { _("Portrait"), _("Landscape") };
            pg.add_row (choice_row (_("Orientation"), orient, page.width > page.height ? 1 : 0, (i) => {
                bool land = i == 1;
                if (land == (page.width > page.height)) return;
                doc.begin (_("Orientation"));
                double w = page.width;
                page.width = page.height;
                page.height = w;
                doc.commit ();
            }));
            double u = unit_px ();
            pg.add_row (spin_row (_("Width"), 10, 100000, 1, page.width / u, 2, (v) => {
                doc.begin (_("Page Size"));
                doc.merge_pending ();
                page.width = v * u;
                doc.commit ();
            }));
            pg.add_row (spin_row (_("Height"), 10, 100000, 1, page.height / u, 2, (v) => {
                doc.begin (_("Page Size"));
                doc.merge_pending ();
                page.height = v * u;
                doc.commit ();
            }));
            pg.add_row (color_row (_("Background"), page.background, true, (c) => {
                doc.begin (_("Background"));
                page.background = c;
                doc.commit ();
            }));
            var fit = new ActionRow (_("Fit Page to Drawing"), _("Resize the page around everything on it."));
            var fit_btn = new Button.with_label (_("Fit"));
            fit_btn.valign = Align.CENTER;
            fit_btn.clicked.connect (() => win.run ("fit-page-to-drawing"));
            fit.add_suffix (fit_btn);
            pg.add_row (fit);
            content.append (pg);

            var grid = new PreferencesGroup (_("Grid and Guides"));
            grid.add_row (switch_row (_("Show Grid"), canvas.show_grid, (on) => win.set_toggle ("show-grid", on)));
            grid.add_row (switch_row (_("Snap to Grid"), canvas.snap_grid, (on) => win.set_toggle ("snap-grid", on)));
            grid.add_row (switch_row (_("Smart Guides"), canvas.snap_objects, (on) => win.set_toggle ("snap-objects", on)));
            grid.add_row (spin_row (_("Grid Size"), 2, 200, 1, doc.grid_size, 0, (v) => {
                doc.grid_size = v;
                doc.modified = true;
                canvas.queue_draw ();
            }));
            string[] unit_labels = { _("Pixels"), _("Millimeters"), _("Centimeters"), _("Inches"), _("Points") };
            string[] unit_ids = { "px", "mm", "cm", "in", "pt" };
            int ucur = 0;
            for (int i = 0; i < unit_ids.length; i++) if (unit_ids[i] == doc.units) ucur = i;
            grid.add_row (choice_row (_("Units"), unit_labels, ucur, (i) => {
                doc.units = unit_ids[i];
                doc.modified = true;
                win.units_changed ();
                refresh ();
            }));
            content.append (grid);
            content.append (background_group ());
            content.append (scale_group ());
            content.append (jumps_group ());
            content.append (print_group ());
            content.append (layers_group ());
        }

        private PreferencesGroup background_group () {
            var page = doc.page;
            var g = new PreferencesGroup (_("Background Page"), _("A background page shows behind the pages that use it, like a letterhead or a title block."));
            g.add_row (switch_row (_("Use as Background Page"), page.is_background, (on) => {
                doc.begin (_("Background Page"));
                page.is_background = on;
                if (on) {
                    page.back_page = "";
                    foreach (var p in doc.pages) if (p.back_page == page.id && !on) p.back_page = "";
                } else {
                    foreach (var p in doc.pages) if (p.back_page == page.id) p.back_page = "";
                }
                doc.commit ();
                doc.pages_changed ();
                refresh_later ();
            }));
            if (!page.is_background) {
                string[] names = { _("None") };
                string[] ids = { "" };
                foreach (var p in doc.pages) {
                    if (!p.is_background || p == page) continue;
                    names += p.name;
                    ids += p.id;
                }
                int cur = 0;
                for (int i = 0; i < ids.length; i++) if (ids[i] == page.back_page) cur = i;
                if (names.length > 1) {
                    g.add_row (choice_row (_("Background"), names, cur, (i) => {
                        doc.begin (_("Background Page"));
                        page.back_page = ids[i];
                        doc.commit ();
                    }));
                }
                var add = new ActionRow (_("New Background Page"), _("Create a background page and assign it here."));
                var btn = new Button.with_label (_("Create"));
                btn.valign = Align.CENTER;
                btn.clicked.connect (() => win.run ("new-background-page"));
                add.add_suffix (btn);
                g.add_row (add);
            }
            return g;
        }

        private PreferencesGroup scale_group () {
            var page = doc.page;
            var g = new PreferencesGroup (_("Drawing Scale"), _("Measure the page in real-world units, for floor plans and technical drawings."));
            string[] presets = { _("No Scale"), "1:10", "1:20", "1:50", "1:100", "1:200", "1:500", _("1 cm = 1 m"), _("1/4 in = 1 ft"), _("1/8 in = 1 ft"), _("Custom") };
            int cur = 0;
            if (page.has_scale ()) {
                cur = presets.length - 1;
                double r = page.scale_ratio ();
                double[] ratios = { 10, 20, 50, 100, 200, 500 };
                for (int i = 0; i < ratios.length; i++) if ((r - ratios[i]).abs () < 1e-6 && page.scale_units == "m") cur = i + 1;
                if ((r - 100).abs () < 1e-6 && page.scale_units == "m" && page.scale_paper_units == "cm" && page.scale_paper == 1 && page.scale_world == 1) cur = 7;
                if ((r - 48).abs () < 1e-6 && page.scale_units == "ft") cur = 8;
                if ((r - 96).abs () < 1e-6 && page.scale_units == "ft") cur = 9;
            }
            g.add_row (choice_row (_("Scale"), presets, cur, (i) => {
                doc.begin (_("Drawing Scale"));
                switch (i) {
                    case 0:
                        page.scale_units = "";
                        break;
                    case 7:
                        page.scale_paper = 1;
                        page.scale_paper_units = "cm";
                        page.scale_world = 1;
                        page.scale_units = "m";
                        break;
                    case 8:
                    case 9:
                        page.scale_paper = i == 8 ? 0.25 : 0.125;
                        page.scale_paper_units = "in";
                        page.scale_world = 1;
                        page.scale_units = "ft";
                        break;
                    case 10:
                        if (!page.has_scale ()) {
                            page.scale_paper = 1;
                            page.scale_paper_units = "cm";
                            page.scale_world = 1;
                            page.scale_units = "m";
                        }
                        break;
                    default:
                        double[] ratios = { 10, 20, 50, 100, 200, 500 };
                        page.scale_paper = 1;
                        page.scale_paper_units = "mm";
                        page.scale_world = ratios[i - 1] / 1000;
                        page.scale_units = "m";
                        break;
                }
                doc.commit ();
                win.units_changed ();
                refresh_later ();
            }));
            if (page.has_scale ()) {
                string[] units = { "mm", "cm", "m", "km", "in", "ft", "yd", "mi" };
                string[] unit_names = { _("Millimeters"), _("Centimeters"), _("Meters"), _("Kilometers"), _("Inches"), _("Feet"), _("Yards"), _("Miles") };
                int pu = 1, wu = 2;
                for (int i = 0; i < units.length; i++) {
                    if (units[i] == page.scale_paper_units) pu = i;
                    if (units[i] == page.scale_units) wu = i;
                }
                g.add_row (spin_row (_("Page Length"), 0.001, 10000, 0.1, page.scale_paper, 3, (v) => {
                    doc.begin (_("Drawing Scale"));
                    doc.merge_pending ();
                    page.scale_paper = v;
                    doc.commit ();
                    win.units_changed ();
                }));
                g.add_row (choice_row (_("Page Units"), unit_names, pu, (i) => {
                    doc.begin (_("Drawing Scale"));
                    page.scale_paper_units = units[i];
                    doc.commit ();
                    win.units_changed ();
                }));
                g.add_row (spin_row (_("Real Length"), 0.001, 1000000, 1, page.scale_world, 3, (v) => {
                    doc.begin (_("Drawing Scale"));
                    doc.merge_pending ();
                    page.scale_world = v;
                    doc.commit ();
                    win.units_changed ();
                }));
                g.add_row (choice_row (_("Real Units"), unit_names, wu, (i) => {
                    doc.begin (_("Drawing Scale"));
                    page.scale_units = units[i];
                    doc.commit ();
                    win.units_changed ();
                }));
            }
            return g;
        }

        private PreferencesGroup jumps_group () {
            var page = doc.page;
            var g = new PreferencesGroup (_("Line Jumps"), _("Where connectors cross, one of them hops over the other."));
            string[] styles = { _("None"), _("Arc"), _("Gap"), _("Square") };
            g.add_row (choice_row (_("Style"), styles, (int) page.jump_style, (i) => {
                doc.begin (_("Line Jumps"));
                page.jump_style = (JumpStyle) i;
                doc.commit ();
                refresh_later ();
            }));
            if (page.jump_style != JumpStyle.NONE) {
                string[] dirs = { _("Horizontal Lines"), _("Vertical Lines") };
                g.add_row (choice_row (_("Jumps On"), dirs, page.jumps_vertical ? 1 : 0, (i) => {
                    doc.begin (_("Line Jumps"));
                    page.jumps_vertical = i == 1;
                    doc.commit ();
                }));
                g.add_row (spin_row (_("Size"), 0.5, 4, 0.25, page.jump_size, 2, (v) => {
                    doc.begin (_("Line Jumps"));
                    doc.merge_pending ();
                    page.jump_size = v;
                    doc.commit ();
                }));
            }
            return g;
        }

        private PreferencesGroup print_group () {
            var page = doc.page;
            var g = new PreferencesGroup (_("Printing"), _("Large pages can be printed at their real size across several sheets."));
            string[] modes = { _("Fit on One Sheet"), _("Actual Size"), _("Across Sheets") };
            int cur = page.print_tiles_x > 0 ? 2 : (page.print_zoom > 0 ? 1 : 0);
            g.add_row (choice_row (_("Print"), modes, cur, (i) => {
                doc.begin (_("Print Setup"));
                page.print_tiles_x = i == 2 ? 2 : 0;
                page.print_tiles_y = i == 2 ? 1 : 0;
                page.print_zoom = i == 1 ? 1 : 0;
                doc.commit ();
                refresh_later ();
            }));
            if (page.print_tiles_x > 0) {
                g.add_row (spin_row (_("Sheets Across"), 1, 20, 1, page.print_tiles_x, 0, (v) => {
                    doc.begin (_("Print Setup"));
                    doc.merge_pending ();
                    page.print_tiles_x = (int) v;
                    doc.commit ();
                }));
                g.add_row (spin_row (_("Sheets Down"), 1, 20, 1, int.max (page.print_tiles_y, 1), 0, (v) => {
                    doc.begin (_("Print Setup"));
                    doc.merge_pending ();
                    page.print_tiles_y = (int) v;
                    doc.commit ();
                }));
            } else if (page.print_zoom > 0) {
                g.add_row (spin_row (_("Zoom"), 10, 400, 5, page.print_zoom * 100, 0, (v) => {
                    doc.begin (_("Print Setup"));
                    doc.merge_pending ();
                    page.print_zoom = v / 100;
                    doc.commit ();
                }));
            }
            return g;
        }

        private PreferencesGroup layers_group () {
            var page = doc.page;
            var g = new PreferencesGroup (_("Layers"), _("New shapes go on the active layer."));
            var add = new Button.with_label (_("Add Layer"));
            add.valign = Align.CENTER;
            add.clicked.connect (() => win.run ("add-layer"));
            g.add_header_suffix (add);
            for (int i = page.layers.size - 1; i >= 0; i--) {
                var layer = page.layers[i];
                int count = 0;
                foreach (var it in page.items) if (page.layer_of (it) == layer) count++;
                var row = new ActionRow (layer.name, layer.id == page.active_layer ? _("Active, %d objects").printf (count) : ngettext ("%d object", "%d objects", count).printf (count));
                var eye = new ToggleButton ();
                eye.icon_name = layer.visible ? "view-reveal-symbolic" : "view-conceal-symbolic";
                eye.active = layer.visible;
                eye.add_css_class ("flat");
                eye.valign = Align.CENTER;
                eye.tooltip_text = _("Visible");
                eye.toggled.connect (() => {
                    if (updating) return;
                    doc.begin (_("Layer Visibility"));
                    layer.visible = eye.active;
                    doc.commit ();
                    refresh ();
                });
                var lock_btn = new ToggleButton ();
                lock_btn.icon_name = layer.locked ? "changes-prevent-symbolic" : "changes-allow-symbolic";
                lock_btn.active = layer.locked;
                lock_btn.add_css_class ("flat");
                lock_btn.valign = Align.CENTER;
                lock_btn.tooltip_text = _("Locked");
                lock_btn.toggled.connect (() => {
                    if (updating) return;
                    doc.begin (_("Lock Layer"));
                    layer.locked = lock_btn.active;
                    doc.commit ();
                    refresh ();
                });
                var more = new Button.from_icon_name ("view-more-symbolic");
                more.add_css_class ("flat");
                more.valign = Align.CENTER;
                more.tooltip_text = _("Layer Options");
                more.clicked.connect (() => win.layer_menu (layer, more));
                row.add_suffix (eye);
                row.add_suffix (lock_btn);
                row.add_suffix (more);
                row.activated.connect (() => {
                    page.active_layer = layer.id;
                    refresh ();
                });
                g.add_row (row);
            }
            return g;
        }
    }
}
