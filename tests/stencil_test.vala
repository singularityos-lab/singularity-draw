using Singularity.Apps.Draw;

bool finite (double v) {
    return !v.is_nan () && v.is_infinity () == 0;
}

void check_geometry () {
    var seen = new Gee.HashSet<string> ();
    int count = 0;
    foreach (var e in ShapeLibrary.entries ()) {
        assert (!seen.contains (e.kind));
        seen.add (e.kind);
        var s = new Shape (e.kind, 0, 0, e.w, double.max (e.h, 1));
        ShapeLibrary.apply_defaults (s);
        var g = s.geometry ();
        if (e.kind != "text") assert (g.parts.size > 0);
        foreach (var part in g.parts) {
            var b = part.path.control_bounds ();
            assert (finite (b.x) && finite (b.y) && finite (b.w) && finite (b.h));
            assert (b.x >= -s.w * 0.6 - 2 && b.x2 () <= s.w * 1.6 + 2);
            assert (b.y >= -s.h * 0.6 - 2 && b.y2 () <= s.h * 1.6 + 2);
        }
        foreach (var p in s.ports ()) assert (finite (p.x) && finite (p.y));
        count++;
    }
    print ("stencil shapes: %d\n", count);
    assert (count > 100);
}

void contact_sheets () {
    string dir = Path.build_filename (Environment.get_tmp_dir (), "stencils");
    DirUtils.create_with_parents (dir, 0755);
    foreach (var cat in ShapeLibrary.categories ()) {
        var list = new Gee.ArrayList<LibEntry> ();
        foreach (var e in ShapeLibrary.entries ()) if (e.category == cat.id) list.add (e);
        if (list.size == 0) continue;
        int cols = 8;
        int rows = (list.size + cols - 1) / cols;
        double tw = 150, th = 130;
        var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) (cols * tw), (int) (rows * th + 30));
        var cr = new Cairo.Context (surf);
        cr.set_source_rgb (1, 1, 1);
        cr.paint ();
        cr.set_source_rgb (0, 0, 0);
        cr.move_to (8, 20);
        cr.set_font_size (14);
        cr.show_text ("%s (%d)".printf (cat.name, list.size));
        for (int i = 0; i < list.size; i++) {
            var e = list[i];
            double x0 = (i % cols) * tw, y0 = 30 + (i / cols) * th;
            var s = new Shape (e.kind, 0, 0, e.w, double.max (e.h, 1));
            ShapeLibrary.apply_defaults (s);
            s.text = ShapeLibrary.default_text (e.kind);
            double box = 90;
            double sc = double.min (box / double.max (s.w, 1), box / double.max (s.h, 1));
            sc = double.min (sc, 1.5);
            cr.save ();
            cr.translate (x0 + (tw - s.w * sc) / 2, y0 + 8 + (box - s.h * sc) / 2);
            cr.scale (sc, sc);
            Renderer.draw_shape (cr, s, new RenderOptions ());
            cr.restore ();
            cr.set_source_rgb (0.2, 0.2, 0.2);
            cr.set_font_size (9);
            cr.move_to (x0 + 4, y0 + th - 8);
            string n = e.name.length > 26 ? e.name.substring (0, 26) : e.name;
            cr.show_text (n);
        }
        surf.write_to_png (Path.build_filename (dir, "%s.png".printf (cat.id)));
    }
}

void svg_export_all () {
    var doc = new Document ();
    double x = 0;
    foreach (var e in ShapeLibrary.entries ()) {
        var s = new Shape (e.kind, x, 0, e.w, double.max (e.h, 1));
        ShapeLibrary.apply_defaults (s);
        doc.add_item (s);
        x += 10;
    }
    string svg = SvgWriter.write_page (doc.page, SvgWriter.page_area (doc.page), true);
    assert (svg.contains ("<svg"));
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/stencil/geometry", check_geometry);
    Test.add_func ("/stencil/contact", contact_sheets);
    Test.add_func ("/stencil/svg", svg_export_all);
    return Test.run ();
}
