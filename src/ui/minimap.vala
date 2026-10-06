using Gtk;

namespace Singularity.Apps.Draw {

    public class MiniMap : Gtk.DrawingArea {
        private Canvas canvas;
        private double scale = 1;
        private Rect world;
        private uint redraw_id = 0;

        public MiniMap (Canvas canvas) {
            this.canvas = canvas;
            add_css_class ("draw-minimap");
            set_size_request (180, 116);
            halign = Align.END;
            valign = Align.END;
            margin_end = 12;
            margin_bottom = 12;
            set_draw_func (draw);
            tooltip_text = _("Mini Map");
            canvas.view_changed.connect (schedule);
            if (canvas.paint != null) canvas.paint.changed.connect (schedule);
            var drag = new GestureDrag ();
            drag.drag_begin.connect ((x, y) => navigate (x, y));
            drag.drag_update.connect ((ox, oy) => {
                double sx, sy;
                drag.get_start_point (out sx, out sy);
                navigate (sx + ox, sy + oy);
            });
            add_controller (drag);
        }

        private void schedule () {
            if (redraw_id != 0) return;
            redraw_id = Timeout.add (60, () => {
                redraw_id = 0;
                queue_draw ();
                return Source.REMOVE;
            });
        }

        private void compute (int width, int height) {
            var page = canvas.doc.page;
            world = Rect (0, 0, page.width, page.height).union (page.content_bounds ()).union (canvas.visible_rect ()).inflate (20);
            scale = double.min ((width - 8) / world.w, (height - 8) / world.h);
        }

        private void navigate (double x, double y) {
            compute (get_width (), get_height ());
            double ox = (get_width () - world.w * scale) / 2, oy = (get_height () - world.h * scale) / 2;
            canvas.center_on (world.x + (x - ox) / scale, world.y + (y - oy) / scale);
        }

        private void draw (DrawingArea area, Cairo.Context cr, int width, int height) {
            compute (width, height);
            var page = canvas.doc.page;
            double ox = (width - world.w * scale) / 2, oy = (height - world.h * scale) / 2;
            cr.save ();
            cr.translate (ox, oy);
            cr.scale (scale, scale);
            cr.translate (-world.x, -world.y);
            cr.set_source_rgb (1, 1, 1);
            cr.rectangle (0, 0, page.width, page.height);
            cr.fill ();
            var opts = new RenderOptions ();
            opts.background = false;
            Renderer.draw_page (cr, page, opts);
            var paint = canvas.paint;
            if (paint != null && paint.floating != null) {
                var l = paint.active_layer ();
                if (l != null && l.visible) paint.paint_floating (cr, l, l.opacity);
            }
            var v = canvas.visible_rect ();
            cr.set_source_rgba (0.21, 0.52, 0.89, 0.15);
            cr.rectangle (v.x, v.y, v.w, v.h);
            cr.fill_preserve ();
            cr.set_source_rgba (0.21, 0.52, 0.89, 0.9);
            cr.set_line_width (1.5 / scale);
            cr.stroke ();
            cr.restore ();
        }
    }
}
