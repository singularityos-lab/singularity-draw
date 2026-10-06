using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class PaintPanel {
        public delegate void ValueCallback (double v);
        public delegate void Toggled (bool on);

        private static SpinRow spin (string title, string? subtitle, double min, double max, double step, double value, int digits, owned ValueCallback cb) {
            var row = new SpinRow (title, subtitle, min, max, step, value);
            row.spin_btn.digits = digits;
            row.notify["value"].connect (() => cb (row.value));
            return row;
        }

        private static SwitchRow switch_row (string title, string? subtitle, bool active, owned Toggled cb) {
            var row = new SwitchRow (title, subtitle, active);
            row.notify["active"].connect (() => cb (row.active));
            return row;
        }

        private static ActionRow color_row (PaintController paint) {
            var row = new ActionRow (_("Color"));
            var btn = new ColorButton (paint.color, false);
            btn.picked.connect ((c) => {
                Rgba rc;
                if (!Colors.parse (c, out rc)) return;
                paint.color = Colors.to_hex (Rgba (rc.r, rc.g, rc.b, 1));
                paint.canvas.queue_draw ();
            });
            row.add_suffix (btn);
            return row;
        }

        private static ActionRow button_row (string title, string? subtitle, string label, owned DrawWindow.ActionHandler cb) {
            var row = new ActionRow (title, subtitle);
            var b = new Button.with_label (label);
            b.valign = Align.CENTER;
            b.clicked.connect (() => cb ());
            row.add_suffix (b);
            return row;
        }

        public static void build (DrawWindow win, Box content) {
            var paint = win.paint;
            var head = new Label (paint.tool.label ());
            head.add_css_class ("title-4");
            head.halign = Align.START;
            content.append (head);
            if (paint.tool.is_brush ()) {
                content.append (stroke_group (paint));
            } else {
                switch (paint.tool) {
                    case PaintTool.FILL:
                        var g = new PreferencesGroup (_("Options"), _("Fills the connected area of similar color under the pointer."));
                        g.add_row (color_row (paint));
                        g.add_row (spin (_("Tolerance"), _("How different a color can be and still be filled"), 0, 100, 1, paint.tolerance, 0, (v) => paint.tolerance = v));
                        g.add_row (switch_row (_("Sample All Layers"), _("Stop at lines drawn on other layers"), paint.sample_merged, (on) => paint.sample_merged = on));
                        content.append (g);
                        break;
                    case PaintTool.PICKER:
                        var g = new PreferencesGroup (_("Options"), _("Click or drag on the canvas to take a color."));
                        g.add_row (color_row (paint));
                        g.add_row (switch_row (_("Sample All Layers"), _("Take the color you see instead of the active layer"), paint.sample_merged, (on) => paint.sample_merged = on));
                        content.append (g);
                        break;
                    case PaintTool.SELECT_RECT:
                    case PaintTool.SELECT_ELLIPSE:
                    case PaintTool.LASSO:
                        content.append (selection_group (paint));
                        break;
                    case PaintTool.TRANSFORM:
                        content.append (transform_group (paint));
                        break;
                    default:
                        break;
                }
            }
            content.append (layers_group (win));
            var l = paint.active_layer ();
            if (l != null && l.raster) content.append (blend_group (win, l));
            if (paint.tool.is_brush ()) content.append (pressure_group (paint));
        }

        private static PreferencesGroup stroke_group (PaintController paint) {
            var b = paint.current_brush ();
            var g = new PreferencesGroup (_("Stroke"));
            if (paint.tool != PaintTool.ERASER) g.add_row (color_row (paint));
            g.add_row (spin (_("Size"), null, 1, 500, 1, b.size, 0, (v) => {
                b.size = v;
                paint.canvas.queue_draw ();
            }));
            g.add_row (spin (_("Opacity"), null, 1, 100, 5, b.opacity * 100, 0, (v) => b.opacity = v / 100));
            if (b.kind == BrushKind.AIRBRUSH) g.add_row (spin (_("Flow"), _("How fast paint builds up while you hold still"), 1, 100, 1, b.flow * 100, 0, (v) => b.flow = v / 100));
            if (b.kind != BrushKind.PENCIL) g.add_row (spin (_("Hardness"), null, 0, 100, 5, b.hardness * 100, 0, (v) => b.hardness = v / 100));
            g.add_row (spin (_("Smoothing"), _("Steadies the line as you draw"), 0, 95, 5, b.smoothing * 100, 0, (v) => b.smoothing = v / 100));
            return g;
        }

        private static PreferencesGroup pressure_group (PaintController paint) {
            var b = paint.current_brush ();
            var g = new PreferencesGroup (_("Pen Pressure"), _("A drawing tablet changes the stroke as you press harder. A mouse paints at full pressure."));
            g.add_row (switch_row (_("Pressure Changes Size"), null, b.pressure_size, (on) => b.pressure_size = on));
            g.add_row (switch_row (_("Pressure Changes Opacity"), null, b.pressure_opacity, (on) => b.pressure_opacity = on));
            return g;
        }

        private static PreferencesGroup selection_group (PaintController paint) {
            var g = new PreferencesGroup (_("Selection"), _("Hold Shift to add to the selection and Alt to remove from it. Painting stays inside it."));
            g.add_row (button_row (_("Whole Layer"), null, _("Select All"), () => paint.select_all ()));
            g.add_row (button_row (_("Swap Selected Area"), null, _("Invert"), () => paint.invert_selection ()));
            if (paint.selection != null) {
                g.add_row (button_row (_("Selected Pixels"), null, _("Clear"), () => paint.clear_selection_pixels ()));
                g.add_row (button_row (_("Fill with Color"), null, _("Fill"), () => paint.fill_selection ()));
                g.add_row (button_row (_("Current Selection"), null, _("Deselect"), () => paint.deselect ()));
            }
            return g;
        }

        private static PreferencesGroup transform_group (PaintController paint) {
            var g = new PreferencesGroup (_("Placement"), _("Drag inside to move, a corner to scale and the round handle to rotate. Shift keeps proportions."));
            var f = paint.floating;
            double scale = f != null ? Math.round (f.sx * 100) : 100;
            double deg = f != null ? Math.round (f.angle * 180 / Math.PI) : 0;
            var sc = new SpinRow (_("Scale"), _("Percent of the original size"), 1, 1000, 5, scale);
            var rot = new SpinRow (_("Rotation"), _("Degrees"), -360, 360, 15, deg);
            sc.notify["value"].connect (() => paint.set_transform (sc.value, rot.value));
            rot.notify["value"].connect (() => paint.set_transform (sc.value, rot.value));
            g.add_row (sc);
            g.add_row (rot);
            if (f != null) {
                var row = new ActionRow (_("Finish"));
                var box = new Box (Orientation.HORIZONTAL, 6);
                box.valign = Align.CENTER;
                var cancel = new Button.with_label (_("Cancel"));
                cancel.clicked.connect (() => paint.cancel_floating ());
                var apply = new Button.with_label (_("Apply"));
                apply.add_css_class ("suggested-action");
                apply.clicked.connect (() => paint.commit_floating ());
                box.append (cancel);
                box.append (apply);
                row.add_suffix (box);
                g.add_row (row);
            }
            return g;
        }

        private static string describe (Page page, Layer l) {
            if (l.raster) {
                string mode = l.blend.label ();
                return l.opacity < 0.999 ? _("Paint, %s, %d%%").printf (mode, (int) Math.round (l.opacity * 100)) : _("Paint, %s").printf (mode);
            }
            int count = 0;
            foreach (var it in page.items) if (page.layer_of (it) == l) count++;
            return ngettext ("Shapes, %d object", "Shapes, %d objects", count).printf (count);
        }

        private static PreferencesGroup layers_group (DrawWindow win) {
            var doc = win.doc;
            var page = doc.page;
            var g = new PreferencesGroup (_("Layers"), _("Paint goes on the active paint layer."));
            var add = new Button.with_label (_("Add Layer"));
            add.valign = Align.CENTER;
            add.clicked.connect (() => win.run ("add-paint-layer"));
            g.add_header_suffix (add);
            for (int i = page.layers.size - 1; i >= 0; i--) {
                var layer = page.layers[i];
                bool is_active = layer.id == page.active_layer;
                var row = new ActionRow (layer.name, is_active ? _("Active, %s").printf (describe (page, layer)) : describe (page, layer));
                if (is_active) row.add_css_class ("draw-active-layer");
                var thumb = new DrawingArea ();
                thumb.set_size_request (36, 28);
                thumb.valign = Align.CENTER;
                thumb.add_css_class ("draw-layer-thumb");
                var paint = win.paint;
                thumb.set_draw_func ((a, cr, w, h) => draw_thumb (page, layer, paint, cr, w, h));
                ulong thumb_handler = 0;
                thumb.realize.connect (() => {
                    if (paint != null && thumb_handler == 0) thumb_handler = paint.changed.connect (() => thumb.queue_draw ());
                });
                thumb.unrealize.connect (() => {
                    if (paint != null && thumb_handler != 0) paint.disconnect (thumb_handler);
                    thumb_handler = 0;
                });
                row.add_prefix (thumb);
                var eye = new ToggleButton ();
                eye.icon_name = layer.visible ? "view-reveal-symbolic" : "view-conceal-symbolic";
                eye.active = layer.visible;
                eye.add_css_class ("flat");
                eye.valign = Align.CENTER;
                eye.tooltip_text = _("Visible");
                eye.toggled.connect (() => {
                    doc.begin (_("Layer Visibility"));
                    layer.visible = eye.active;
                    doc.commit ();
                    win.inspector.refresh_later ();
                });
                var more = new Button.from_icon_name ("view-more-symbolic");
                more.add_css_class ("flat");
                more.valign = Align.CENTER;
                more.tooltip_text = _("Layer Options");
                more.clicked.connect (() => win.layer_menu (layer, more));
                row.add_suffix (eye);
                row.add_suffix (more);
                row.activated.connect (() => {
                    win.paint.commit_floating ();
                    page.active_layer = layer.id;
                    win.inspector.refresh_later ();
                });
                g.add_row (row);
            }
            return g;
        }

        private static void draw_thumb (Page page, Layer layer, PaintController? paint, Cairo.Context cr, int w, int h) {
            double sc = double.min (w / double.max (page.width, 1), h / double.max (page.height, 1));
            double tw = page.width * sc, th = page.height * sc;
            double ox = (w - tw) / 2, oy = (h - th) / 2;
            cr.save ();
            cr.rectangle (ox, oy, tw, th);
            cr.clip ();
            double cell = 4;
            for (double y = oy; y < oy + th; y += cell) {
                for (double x = ox; x < ox + tw; x += cell) {
                    bool dark = ((int) ((x - ox) / cell) + (int) ((y - oy) / cell)) % 2 == 0;
                    cr.set_source_rgb (dark ? 0.8 : 0.95, dark ? 0.8 : 0.95, dark ? 0.8 : 0.95);
                    cr.rectangle (x, y, cell, cell);
                    cr.fill ();
                }
            }
            cr.translate (ox, oy);
            cr.scale (sc, sc);
            var opts = new RenderOptions ();
            opts.background = false;
            foreach (var it in page.items) {
                if (page.layer_of (it) != layer) continue;
                var r = it as RasterItem;
                if (r != null) Renderer.draw_raster (cr, r, 1, BlendMode.NORMAL);
                else Renderer.draw_item (cr, it, opts);
            }
            if (paint != null) paint.paint_floating (cr, layer, 1);
            cr.restore ();
            cr.set_source_rgba (0, 0, 0, 0.25);
            cr.set_line_width (1);
            cr.rectangle (ox + 0.5, oy + 0.5, tw - 1, th - 1);
            cr.stroke ();
        }

        private static PreferencesGroup blend_group (DrawWindow win, Layer l) {
            var doc = win.doc;
            var g = new PreferencesGroup (_("Blending"), _("How %s mixes with the layers below.").printf (l.name));
            var modes = BlendMode.all ();
            string[] labels = {};
            foreach (var m in modes) labels += m.label ();
            var row = new SelectionRow (_("Blend Mode"), labels, l.blend.label ());
            row.selected.connect ((item) => {
                for (int i = 0; i < labels.length; i++) {
                    if (labels[i] != item || modes[i] == l.blend) continue;
                    doc.begin (_("Blend Mode"));
                    l.blend = modes[i];
                    doc.commit ();
                    win.inspector.refresh_later ();
                }
            });
            g.add_row (row);
            g.add_row (spin (_("Opacity"), null, 0, 100, 5, Math.round (l.opacity * 100), 0, (v) => {
                if ((l.opacity * 100 - v).abs () < 0.01) return;
                doc.begin (_("Layer Opacity"));
                doc.merge_pending ();
                l.opacity = v / 100;
                doc.commit ();
            }));
            return g;
        }
    }
}
