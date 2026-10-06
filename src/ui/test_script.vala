namespace Singularity.Apps.Draw {

    public class TestScript : Object {
        private static bool started = false;
        private DrawWindow win;
        private string[] lines;
        private int index = 0;

        public static void maybe_run (DrawWindow win) {
            string? path = Environment.get_variable ("SINGULARITY_DRAW_TEST_SCRIPT");
            if (path == null || started) return;
            started = true;
            string text;
            try {
                FileUtils.get_contents (path, out text);
            } catch (Error e) {
                printerr ("script: %s\n", e.message);
                return;
            }
            var s = new TestScript ();
            s.win = win;
            s.lines = text.split ("\n");
            s.ref ();
            Timeout.add (800, () => {
                s.step ();
                return Source.REMOVE;
            });
        }

        private void step () {
            while (index < lines.length) {
                string line = lines[index++].strip ();
                if (line == "" || line.has_prefix ("#")) continue;
                uint wait = 350;
                try {
                    wait = run (line);
                } catch (Error e) {
                    printerr ("script: %s failed: %s\n", line, e.message);
                }
                printerr ("script: ok %s\n", line);
                Timeout.add (wait, () => {
                    step ();
                    return Source.REMOVE;
                });
                return;
            }
            printerr ("script: finished\n");
            unref ();
        }

        private static Point point (string s) {
            string[] v = s.split (",");
            return Point (double.parse (v[0]), double.parse (v.length > 1 ? v[1] : "0"));
        }

        private uint run (string line) throws Error {
            string[] a = line.split (" ");
            var paint = win.paint;
            switch (a[0]) {
                case "sleep":
                    return (uint) int.parse (a[1]);
                case "maximize":
                    win.maximize ();
                    return 900;
                case "new-painting":
                    win.new_painting ();
                    return 700;
                case "new-drawing":
                    win.new_document ();
                    return 700;
                case "open":
                    win.load_document (Formats.load (a[1]));
                    return 900;
                case "mode":
                    win.set_paint_mode (a[1] == "paint");
                    return 600;
                case "action":
                    win.run (a[1]);
                    return 900;
                case "fit":
                    win.canvas.fit_page ();
                    return 400;
                case "zoom":
                    win.canvas.zoom_to (double.parse (a[1]));
                    return 400;
                case "tool":
                    foreach (var t in PaintTool.all ()) if (t.icon () == "draw-%s-symbolic".printf (a[1])) paint.use_tool (t);
                    return 300;
                case "color":
                    paint.color = a[1];
                    paint.changed ();
                    return 200;
                case "size":
                    paint.current_brush ().size = double.parse (a[1]);
                    paint.changed ();
                    return 200;
                case "hardness":
                    paint.current_brush ().hardness = double.parse (a[1]);
                    return 100;
                case "stroke":
                    Point[] pts = {};
                    double[] ps = {};
                    for (int i = 1; i < a.length; i++) {
                        string[] v = a[i].split (",");
                        if (v.length < 2) continue;
                        pts += Point (double.parse (v[0]), double.parse (v[1]));
                        ps += v.length > 2 ? double.parse (v[2]) : 1.0;
                    }
                    Point[] dense = {};
                    double[] dp = {};
                    for (int i = 0; i + 1 < pts.length; i++) {
                        for (int k = 0; k < 24; k++) {
                            double t = k / 24.0;
                            dense += Point (pts[i].x + (pts[i + 1].x - pts[i].x) * t, pts[i].y + (pts[i + 1].y - pts[i].y) * t);
                            dp += ps[i] + (ps[i + 1] - ps[i]) * t;
                        }
                    }
                    dense += pts[pts.length - 1];
                    dp += ps[ps.length - 1];
                    paint.stroke (dense, dp);
                    return 400;
                case "select":
                    var p0 = point (a[1]);
                    var p1 = point (a[2]);
                    paint.press_at (p0.x, p0.y, 1);
                    for (int i = 1; i <= 10; i++) paint.drag_to (p0.x + (p1.x - p0.x) * i / 10, p0.y + (p1.y - p0.y) * i / 10, 1);
                    paint.release_at (p1.x, p1.y);
                    return 400;
                case "lasso":
                    for (int i = 1; i < a.length; i++) {
                        var p = point (a[i]);
                        if (i == 1) paint.press_at (p.x, p.y, 1);
                        else paint.drag_to (p.x, p.y, 1);
                    }
                    var last = point (a[a.length - 1]);
                    paint.release_at (last.x, last.y);
                    return 400;
                case "transform":
                    paint.use_tool (PaintTool.TRANSFORM);
                    if (!paint.lift ()) throw new IOError.FAILED ("nothing to transform");
                    paint.floating.sx = paint.floating.sy = double.parse (a[1]) / 100.0;
                    paint.floating.angle = double.parse (a[2]) * Math.PI / 180;
                    if (a.length > 4) {
                        paint.floating.tx = double.parse (a[3]);
                        paint.floating.ty = double.parse (a[4]);
                    }
                    paint.changed ();
                    win.canvas.queue_draw ();
                    return 500;
                case "commit":
                    paint.commit_floating ();
                    return 300;
                case "floating":
                    var fl = paint.floating;
                    if (fl == null) printerr ("floating none\n");
                    else printerr ("floating origin=%d,%d size=%dx%d offset=%.1f,%.1f\n", fl.ox, fl.oy, fl.bw, fl.bh, fl.tx, fl.ty);
                    return 50;
                case "deselect":
                    paint.deselect ();
                    return 300;
                case "fill":
                    var fp = point (a[1]);
                    paint.fill_at (fp.x, fp.y);
                    return 400;
                case "pick":
                    var pp = point (a[1]);
                    paint.pick_at (pp.x, pp.y);
                    return 300;
                case "add-layer":
                    win.run ("add-paint-layer");
                    return 400;
                case "layer":
                    var page = win.doc.page;
                    foreach (var l in page.layers) if (l.name == line.substring (6)) page.active_layer = l.id;
                    win.inspector.refresh ();
                    return 300;
                case "rename":
                    var al = paint.active_layer ();
                    if (al != null) al.name = line.substring (7);
                    win.inspector.refresh ();
                    return 200;
                case "blend":
                    var bl = paint.active_layer ();
                    win.doc.begin (_("Blend Mode"));
                    bl.blend = BlendMode.from_id (a[1]);
                    win.doc.commit ();
                    win.inspector.refresh ();
                    return 400;
                case "opacity":
                    var ol = paint.active_layer ();
                    win.doc.begin (_("Layer Opacity"));
                    ol.opacity = double.parse (a[1]);
                    win.doc.commit ();
                    win.inspector.refresh ();
                    return 400;
                case "export-ora":
                    Formats.write_atomic (a[1], Ora.save (win.doc));
                    return 300;
                case "save":
                    Formats.save (win.doc, a[1]);
                    return 300;
                case "export-svg":
                    Formats.write_atomic (a[1], SvgWriter.write_page (win.doc.page, SvgWriter.page_area (win.doc.page), true).data);
                    return 300;
                case "probe":
                    var q = point (a[1]);
                    var c = ColorSampler.sample (win.doc.page, q.x, q.y);
                    var r = paint.target ();
                    int alpha = -1;
                    if (r != null) {
                        var px = r.to_pixel (q.x, q.y);
                        alpha = (int) ((Pixels.get (r.pixels (), (int) px.x, (int) px.y) >> 24) & 0xff);
                    }
                    printerr ("probe %s composite=%s layer-alpha=%d\n", a[1], Colors.to_hex (c, true), alpha);
                    return 50;
                case "column":
                    var cr = paint.target ();
                    int x = int.parse (a[1]);
                    int count = 0, maxa = 0;
                    for (int y = 0; y < cr.pixel_h; y++) {
                        int av = (int) ((Pixels.get (cr.pixels (), x, y) >> 24) & 0xff);
                        if (av > 0) count++;
                        if (av > maxa) maxa = av;
                    }
                    printerr ("column x=%d painted=%d max-alpha=%d\n", x, count, maxa);
                    return 50;
                case "shot":
                    string output;
                    int status;
                    Process.spawn_sync (null, { "grim", a[1] }, null, SpawnFlags.SEARCH_PATH, null, out output, null, out status);
                    printerr ("shot %s status=%d\n", a[1], status);
                    return 100;
                case "where":
                    var wp = point (a[1]);
                    var sp = win.canvas.to_screen (wp.x, wp.y);
                    Graphene.Point gp = { (float) sp.x, (float) sp.y };
                    Graphene.Point rp;
                    win.canvas.compute_point (win, gp, out rp);
                    printerr ("where %s screen=%d,%d\n", a[1], (int) rp.x, (int) rp.y);
                    return 50;
                case "layers":
                    foreach (var l in win.doc.page.layers) printerr ("layer %s raster=%s blend=%s opacity=%.2f visible=%s\n", l.name, l.raster.to_string (), l.blend.to_id (), l.opacity, l.visible.to_string ());
                    return 50;
                case "template":
                    win.load_document (Templates.build (a[1]));
                    return 900;
                case "select-kind":
                    foreach (var it in win.doc.page.all_items ()) {
                        var sk = it as Shape;
                        if (sk != null && sk.kind == a[1]) {
                            win.canvas.select_one (it);
                            break;
                        }
                    }
                    return 400;
                case "select-text":
                    string needle = line.substring (12);
                    foreach (var it in win.doc.page.all_items ()) {
                        if (it.display_text () == needle) {
                            win.canvas.select_one (it);
                            break;
                        }
                    }
                    return 400;
                case "open-stencil":
                    win.open_stencil (a[1]);
                    return 500;
                case "draw-tool":
                    win.canvas.use_tool (a[1] == "points" ? Tool.CONNECTION_POINT : Tool.SELECT);
                    return 300;
                case "design":
                    win.open_design ();
                    return 700;
                case "hover":
                    var hp = point (a[1]);
                    win.canvas.simulate_hover (hp.x, hp.y);
                    return 700;
                case "inspector-end":
                    win.inspector.scroll_to_end ();
                    return 400;
                case "rich-bold":
                    win.rich_demo (int.parse (a[1]));
                    return 500;
                case "print-tiles":
                    win.doc.page.print_tiles_x = int.parse (a[1]);
                    win.doc.page.print_tiles_y = int.parse (a[2]);
                    return 100;
                case "comment":
                    var cm = Comment.create (line.substring (8));
                    cm.id = "c%d".printf (win.doc.page.comments.size + 1);
                    if (win.canvas.selection.size > 0) cm.item_id = win.canvas.selection[0].id;
                    win.doc.begin ("Comment");
                    win.doc.page.comments.add (cm);
                    win.doc.commit ();
                    return 300;
                case "demo-data":
                    var ds = new DataSource ();
                    ds.id = DataSources.new_id (win.doc);
                    ds.path = a[1];
                    ds.kind = DataSources.kind_for_path (a[1]);
                    ds.name = Path.get_basename (a[1]);
                    ds.key_column = a[2];
                    ds.table = DataSources.load (ds);
                    win.doc.begin ("Link Data");
                    win.doc.data_sources.add (ds);
                    DataSources.auto_link (win.doc.page, ds);
                    var dg = new DataGraphic ();
                    dg.id = "dg1";
                    dg.name = "Status";
                    var bar = new DataGraphicItem ();
                    bar.field = a[3];
                    bar.kind = "bar";
                    dg.items.add (bar);
                    var ic = new DataGraphicItem ();
                    ic.field = a[3];
                    ic.kind = "icon";
                    dg.items.add (ic);
                    var tx = new DataGraphicItem ();
                    tx.field = a[4];
                    tx.kind = "text";
                    tx.position = "top-left";
                    dg.items.add (tx);
                    win.doc.data_graphics.add (dg);
                    foreach (var it in win.doc.page.all_items ()) if (it.data_source == ds.id) it.data_graphic = "dg1";
                    win.doc.commit ();
                    return 400;
                case "rich-select":
                    win.rich_select (int.parse (a[1]), int.parse (a[2]));
                    return 600;
                case "rich-apply":
                    win.rich_apply (a[1], a.length > 2 ? line.substring (a[0].length + a[1].length + 2) : "");
                    return 300;
                case "end-edit":
                    win.end_text_edit (true);
                    return 300;
                case "add-shape":
                    var box = point (a[2]);
                    var size = point (a[3]);
                    var ns = new Shape (a[1], box.x, box.y, size.x, size.y);
                    ShapeLibrary.apply_defaults (ns);
                    ns.text = a.length > 4 ? line.substring (line.index_of (a[3]) + a[3].length + 1) : "";
                    win.doc.begin ("Add");
                    win.doc.add_item (ns);
                    win.doc.commit ();
                    win.canvas.select_one (ns);
                    return 300;
                case "snippet":
                    var sp0 = point (a[1]);
                    var sp1 = point (a[2]);
                    win.doc.page.snippets.add (new Snippet (line.substring (line.index_of (a[2]) + a[2].length + 1), Rect (sp0.x, sp0.y, sp1.x, sp1.y)));
                    return 100;
                case "export-pptx":
                    Formats.write_atomic (a[1], Pptx.save (win.doc));
                    return 300;
                case "run":
                    win.run (a[1]);
                    return 900;
                case "center":
                    var cp = point (a[1]);
                    win.canvas.center_on (cp.x, cp.y);
                    return 300;
                default:
                    throw new IOError.INVALID_ARGUMENT ("unknown command");
            }
        }
    }
}
