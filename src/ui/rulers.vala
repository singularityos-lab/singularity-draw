using Gtk;

namespace Singularity.Apps.Draw {

    public class Ruler : Gtk.DrawingArea {
        public const int SIZE = 20;
        private Canvas canvas;
        private bool vertical;
        private double pointer = double.NAN;
        public string units = "px";

        public Ruler (Canvas canvas, bool vertical) {
            this.canvas = canvas;
            this.vertical = vertical;
            add_css_class ("draw-ruler");
            if (vertical) {
                set_size_request (SIZE, -1);
                vexpand = true;
            } else {
                set_size_request (-1, SIZE);
                hexpand = true;
            }
            set_draw_func (draw);
            canvas.view_changed.connect (queue_draw);
            canvas.selection_changed.connect (queue_draw);
            canvas.pointer_moved.connect ((x, y) => {
                pointer = vertical ? y : x;
                queue_draw ();
            });
            tooltip_text = vertical ? _("Drag to add a vertical guide") : _("Drag to add a horizontal guide");
            var drag = new GestureDrag ();
            PageGuide? guide = null;
            drag.drag_begin.connect ((x, y) => {
                if (canvas.paint_active ()) return;
                guide = new PageGuide (vertical, 0);
                canvas.doc.begin (_("Add Guide"));
                canvas.page.guides.add (guide);
                canvas.active_guide = guide;
            });
            drag.drag_update.connect ((ox, oy) => {
                if (guide == null) return;
                double sx, sy;
                drag.get_start_point (out sx, out sy);
                double cx, cy;
                translate_coordinates (canvas, sx + ox, sy + oy, out cx, out cy);
                var p = canvas.to_page (cx, cy);
                guide.pos = Math.round (vertical ? p.x : p.y);
                canvas.queue_draw ();
            });
            drag.drag_end.connect ((ox, oy) => {
                if (guide == null) return;
                double sx, sy;
                drag.get_start_point (out sx, out sy);
                double lx = sx + ox, ly = sy + oy;
                bool inside = vertical ? lx < SIZE : ly < SIZE;
                if (inside || Math.hypot (ox, oy) < 3) {
                    canvas.page.guides.remove (guide);
                    canvas.doc.cancel ();
                } else {
                    canvas.doc.commit ();
                }
                canvas.active_guide = null;
                guide = null;
                canvas.queue_draw ();
            });
            add_controller (drag);
        }

        private double unit_px () {
            switch (units) {
                case "mm": return Units.PX_PER_MM;
                case "cm": return Units.PX_PER_CM;
                case "in": return Units.PX_PER_IN;
                case "pt": return Units.PX_PER_PT;
                default: return 1;
            }
        }

        private void draw (DrawingArea area, Cairo.Context cr, int width, int height) {
            var fg = get_color ();
            double len = vertical ? height : width;
            double zoom = canvas.zoom;
            double origin = vertical ? canvas.origin_y : canvas.origin_x;
            double offset = 0;
            double u = unit_px ();
            var page = canvas.page;
            if (page.has_scale ()) u = page.from_world (1);
            double[] steps = { 0.01, 0.02, 0.05, 0.1, 0.2, 0.25, 0.5, 1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 5000, 10000, 20000, 50000, 100000 };
            double major = 100;
            foreach (double s in steps) {
                if (s * u * zoom >= 60) {
                    major = s;
                    break;
                }
            }
            double minor = major / 10;
            if (minor * u * zoom < 5) minor = major / 5;
            if (minor * u * zoom < 5) minor = major / 2;
            var sel = canvas.selection.size > 0 ? Document.selection_bounds (canvas.selection) : Rect.empty ();
            if (!sel.is_empty ()) {
                double a = ((vertical ? sel.y : sel.x) - origin) * zoom - offset;
                double b = ((vertical ? sel.y2 () : sel.x2 ()) - origin) * zoom - offset;
                cr.set_source_rgba (0.21, 0.52, 0.89, 0.22);
                if (vertical) cr.rectangle (0, a, SIZE, b - a);
                else cr.rectangle (a, 0, b - a, SIZE);
                cr.fill ();
            }
            double start_units = Math.floor ((origin + offset / zoom) / (minor * u)) * minor;
            cr.set_line_width (1);
            var layout = Pango.cairo_create_layout (cr);
            var fd = Pango.FontDescription.from_string ("Sans 7");
            layout.set_font_description (fd);
            for (double v = start_units; ; v += minor) {
                double pos = (v * u - origin) * zoom - offset;
                if (pos > len) break;
                double r = v / major;
                bool is_major = (r - Math.round (r)).abs () < 1e-6;
                double tick = is_major ? SIZE * 0.6 : SIZE * 0.25;
                cr.set_source_rgba (fg.red, fg.green, fg.blue, is_major ? 0.55 : 0.3);
                if (vertical) {
                    cr.move_to (SIZE - tick, Math.round (pos) + 0.5);
                    cr.line_to (SIZE, Math.round (pos) + 0.5);
                } else {
                    cr.move_to (Math.round (pos) + 0.5, SIZE - tick);
                    cr.line_to (Math.round (pos) + 0.5, SIZE);
                }
                cr.stroke ();
                if (is_major) {
                    layout.set_text (PathData.fmt (v, 2), -1);
                    cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.7);
                    if (vertical) {
                        cr.save ();
                        cr.move_to (2, pos + 2);
                        cr.rotate (Math.PI / 2);
                        cr.translate (0, -SIZE + 4);
                        Pango.cairo_show_layout (cr, layout);
                        cr.restore ();
                    } else {
                        cr.move_to (pos + 3, 1);
                        Pango.cairo_show_layout (cr, layout);
                    }
                }
            }
            if (pointer.is_finite ()) {
                double pp = (pointer - origin) * zoom - offset;
                cr.set_source_rgba (0.89, 0.2, 0.3, 0.9);
                if (vertical) {
                    cr.move_to (0, pp);
                    cr.line_to (SIZE, pp);
                } else {
                    cr.move_to (pp, 0);
                    cr.line_to (pp, SIZE);
                }
                cr.stroke ();
            }
        }
    }
}
