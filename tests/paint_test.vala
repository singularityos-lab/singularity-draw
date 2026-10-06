using Singularity.Apps.Draw;

bool near (double a, double b, double eps = 0.01) {
    return (a - b).abs () <= eps;
}

int alpha_of (Cairo.ImageSurface s, int x, int y) {
    s.flush ();
    return (int) ((Pixels.get (s, x, y) >> 24) & 0xff);
}

int channel (uint32 v, int shift) {
    return (int) ((v >> shift) & 0xff);
}

void test_dab_spacing () {
    var surf = Pixels.blank (200, 60);
    var b = new BrushSettings (BrushKind.BRUSH);
    b.size = 20;
    b.spacing = 0.25;
    b.pressure_size = false;
    var e = new StrokeEngine (surf, b, Rgba (0, 0, 0, 1));
    e.record = true;
    e.begin (10, 30, 1);
    e.line_to (110, 30, 1);
    assert (e.dab_count == 21);
    for (int i = 1; i < e.dabs.size; i++) assert (near (e.dabs[i].x - e.dabs[i - 1].x, 5, 1e-6));
    assert (near (e.dabs[e.dabs.size - 1].x, 110, 1e-6));

    var e2 = new StrokeEngine (Pixels.blank (200, 60), b, Rgba (0, 0, 0, 1));
    e2.record = true;
    e2.begin (10, 30, 1);
    e2.line_to (37, 30, 1);
    e2.line_to (61, 30, 1);
    e2.line_to (110, 30, 1);
    assert (e2.dab_count == 21);
    for (int i = 1; i < e2.dabs.size; i++) assert (near (e2.dabs[i].x - e2.dabs[i - 1].x, 5, 1e-6));

    var small = new BrushSettings (BrushKind.PENCIL);
    small.size = 1;
    assert (near (small.step_at (1), 0.5));
    var e3 = new StrokeEngine (Pixels.blank (200, 60), small, Rgba (0, 0, 0, 1));
    e3.begin (0, 0, 1);
    e3.line_to (10, 0, 1);
    assert (e3.dab_count == 21);
}

void test_pressure_curves () {
    var b = new BrushSettings (BrushKind.BRUSH);
    b.size = 40;
    b.min_size = 0.2;
    b.min_opacity = 0.1;
    assert (near (b.size_at (1), 40));
    assert (near (b.size_at (0), 8));
    assert (near (b.size_at (0.5), 8 + 32 * 0.5));
    assert (near (b.alpha_at (1), 1));
    assert (near (b.alpha_at (0), 0.1));
    double prev_s = -1, prev_a = -1;
    for (double p = 0; p <= 1.0001; p += 0.05) {
        assert (b.size_at (p) >= prev_s);
        assert (b.alpha_at (p) >= prev_a);
        prev_s = b.size_at (p);
        prev_a = b.alpha_at (p);
    }
    assert (near (b.size_at (2), 40) && near (b.size_at (-1), 8));
    b.gamma = 2;
    assert (near (b.size_at (0.5), 8 + 32 * 0.25));
    b.pressure_size = false;
    b.pressure_opacity = false;
    assert (near (b.size_at (0.1), 40) && near (b.alpha_at (0.1), 1));
    var air = new BrushSettings (BrushKind.AIRBRUSH);
    assert (air.alpha_at (1) <= air.flow + 1e-9);
    var marker = new BrushSettings (BrushKind.MARKER);
    assert (near (marker.size_at (0.1), marker.size_at (1)));
    assert (marker.composite () == Cairo.Operator.MULTIPLY);
    assert (new BrushSettings (BrushKind.ERASER).composite () == Cairo.Operator.DEST_OUT);
}

void test_smoothing () {
    var raw = new Stabilizer (0);
    for (int i = 0; i < 20; i++) {
        double ox, oy, op;
        raw.push (i * 5, (i % 2 == 0) ? 0 : 10, 1, out ox, out oy, out op);
        assert (near (ox, i * 5) && near (oy, (i % 2 == 0) ? 0 : 10));
    }
    var st = new Stabilizer (0.8);
    double jitter = 0;
    double last_y = 0;
    double ex = 0, ey = 0;
    for (int i = 0; i < 40; i++) {
        double ox, oy, op;
        st.push (i * 5, (i % 2 == 0) ? 0 : 10, 1, out ox, out oy, out op);
        if (i > 0) jitter += (oy - last_y).abs ();
        last_y = oy;
        ex = ox;
        ey = oy;
    }
    assert (jitter < 39 * 10 * 0.35);
    var tail = st.finish ();
    assert (tail.size > 0);
    var end = tail[tail.size - 1];
    assert (near (end.x, 39 * 5, 1e-6) && near (end.y, 10, 1e-6));
    assert (ex < 39 * 5);

    var curve = new Stabilizer (0.5);
    double ox, oy, op;
    curve.push (0, 0, 0.2, out ox, out oy, out op);
    curve.push (100, 0, 1, out ox, out oy, out op);
    assert (ox > 0 && ox < 100);
    assert (op > 0.2 && op < 1);
}

void test_airbrush_accumulation () {
    var surf = Pixels.blank (100, 100);
    var b = new BrushSettings (BrushKind.AIRBRUSH);
    b.size = 30;
    b.flow = 0.1;
    var e = new StrokeEngine (surf, b, Rgba (0, 0, 1, 1));
    e.begin (50, 50, 1);
    double a1 = e.mask_at (50, 50);
    assert (near (a1, 0.1, 0.01));
    e.tick (1.0 / 60);
    double a2 = e.mask_at (50, 50);
    e.tick (5.0 / 60);
    double a3 = e.mask_at (50, 50);
    assert (a1 < a2 && a2 < a3);
    assert (near (a2, 1 - Math.pow (0.9, 2), 0.01));
    e.tick (3);
    double a4 = e.mask_at (50, 50);
    assert (a4 > 0.99 && a4 <= 1.0);
    assert (e.mask_at (50, 60) < a4 && e.mask_at (50, 60) > 0);
    e.finish ();
    assert (alpha_of (surf, 50, 50) >= 252);

    var bs = new BrushSettings (BrushKind.BRUSH);
    bs.pressure_opacity = false;
    bs.opacity = 1;
    bs.size = 20;
    var m = new StrokeEngine (Pixels.blank (100, 100), bs, Rgba (0, 0, 0, 1));
    m.stamp (50, 50, 10, 0.4);
    m.stamp (50, 50, 10, 0.4);
    m.stamp (50, 50, 10, 0.4);
    assert (near (m.mask_at (50, 50), 0.4, 0.001));
}

void test_eraser_alpha () {
    var surf = Pixels.blank (80, 80);
    var cr = new Cairo.Context (surf);
    cr.set_source_rgba (1, 0, 0, 1);
    cr.paint ();
    surf.flush ();
    var b = new BrushSettings (BrushKind.ERASER);
    b.size = 20;
    b.hardness = 1;
    b.opacity = 1;
    var e = new StrokeEngine (surf, b, Rgba (0, 0, 0, 1));
    e.begin (40, 40, 1);
    e.finish ();
    assert (alpha_of (surf, 40, 40) == 0);
    assert (alpha_of (surf, 5, 5) == 255);
    var surf2 = Pixels.blank (80, 80);
    var cr2 = new Cairo.Context (surf2);
    cr2.set_source_rgba (1, 0, 0, 1);
    cr2.paint ();
    surf2.flush ();
    var half = b.copy ();
    half.opacity = 0.5;
    var e2 = new StrokeEngine (surf2, half, Rgba (0, 0, 0, 1));
    e2.begin (40, 40, 1);
    e2.line_to (41, 40, 1);
    e2.line_to (40, 40, 1);
    e2.finish ();
    int a = alpha_of (surf2, 40, 40);
    assert (a >= 125 && a <= 130);
    var soft = new BrushSettings (BrushKind.ERASER);
    soft.size = 20;
    soft.hardness = 0;
    soft.opacity = 1;
    var surf3 = Pixels.blank (80, 80);
    var cr3 = new Cairo.Context (surf3);
    cr3.set_source_rgba (0, 0, 0, 1);
    cr3.paint ();
    surf3.flush ();
    var e3 = new StrokeEngine (surf3, soft, Rgba (0, 0, 0, 1));
    e3.begin (40, 40, 1);
    e3.finish ();
    int center = alpha_of (surf3, 40, 40), mid = alpha_of (surf3, 45, 40), edge = alpha_of (surf3, 49, 40);
    assert (center < mid && mid < edge);
}

void test_flood_fill () {
    var s = Pixels.blank (60, 40);
    var cr = new Cairo.Context (s);
    cr.set_source_rgb (200 / 255.0, 0, 0);
    cr.rectangle (0, 0, 30, 40);
    cr.fill ();
    cr.set_source_rgb (210 / 255.0, 0, 0);
    cr.rectangle (30, 0, 30, 40);
    cr.fill ();
    s.flush ();
    var t = Pixels.copy (s);
    int n0 = FloodFill.fill (s, t, 5, 5, Rgba (0, 0, 1, 1), 0);
    assert (n0 == 30 * 40);
    assert (Pixels.get (t, 10, 10) == 0xff0000ffu);
    assert (channel (Pixels.get (t, 40, 10), 16) == 210);
    var t2 = Pixels.copy (s);
    int n1 = FloodFill.fill (s, t2, 5, 5, Rgba (0, 0, 1, 1), 5);
    assert (n1 == 30 * 40);
    var t3 = Pixels.copy (s);
    int n2 = FloodFill.fill (s, t3, 5, 5, Rgba (0, 0, 1, 1), 10);
    assert (n2 == 60 * 40);

    var barrier = Pixels.copy (s);
    var bc = new Cairo.Context (barrier);
    bc.set_source_rgb (0, 0, 0);
    bc.rectangle (15, 0, 2, 40);
    bc.fill ();
    barrier.flush ();
    int n3 = FloodFill.fill (barrier, Pixels.copy (barrier), 5, 5, Rgba (0, 1, 0, 1), 60);
    assert (n3 == 15 * 40);

    var sel = new RasterSelection (60, 40);
    sel.combine (RasterSelection.rect_path (0, 0, 10, 40), SelectOp.REPLACE);
    int n4 = FloodFill.fill (s, Pixels.copy (s), 5, 5, Rgba (0, 1, 0, 1), 255, sel.bytes ());
    assert (n4 == 10 * 40);

    var ring = Pixels.blank (40, 40);
    var rc = new Cairo.Context (ring);
    rc.set_antialias (Cairo.Antialias.NONE);
    rc.set_source_rgb (0, 0, 0);
    rc.set_line_width (2);
    rc.rectangle (10, 10, 20, 20);
    rc.stroke ();
    ring.flush ();
    var ring_t = Pixels.copy (ring);
    int inside = FloodFill.fill (ring, ring_t, 20, 20, Rgba (1, 1, 0, 1), 0);
    assert (inside == 18 * 18);
    assert (alpha_of (ring_t, 2, 2) == 0);

    var half = Pixels.blank (10, 10);
    var hc = new Cairo.Context (half);
    hc.set_source_rgb (1, 1, 1);
    hc.paint ();
    half.flush ();
    FloodFill.fill (half, half, 1, 1, Rgba (0, 0, 0, 0.5), 0);
    int r = channel (Pixels.get (half, 3, 3), 16);
    assert (r >= 126 && r <= 129);
}

Page blend_page (BlendMode mode, double opacity) {
    var doc = Raster.new_painting (4, 4, "#808080");
    var page = doc.page;
    var r = Raster.item_for (page, page.layers[0].id);
    var cr = new Cairo.Context (r.pixels ());
    cr.set_source_rgb (1, 0, 0);
    cr.paint ();
    r.sync ();
    page.layers[0].blend = mode;
    page.layers[0].opacity = opacity;
    return page;
}

void check_blend (BlendMode mode, double opacity, int er, int eg, int eb) {
    var page = blend_page (mode, opacity);
    var surf = Export.render_area (page, Rect (0, 0, 4, 4), 1, false);
    uint32 v = Pixels.get (surf, 1, 1);
    int r = channel (v, 16), g = channel (v, 8), b = channel (v, 0);
    if ((r - er).abs () > 2 || (g - eg).abs () > 2 || (b - eb).abs () > 2) {
        printerr ("blend %s: got %d,%d,%d expected %d,%d,%d\n", mode.to_id (), r, g, b, er, eg, eb);
        assert_not_reached ();
    }
}

void test_blend_modes () {
    check_blend (BlendMode.NORMAL, 1, 255, 0, 0);
    check_blend (BlendMode.MULTIPLY, 1, 128, 0, 0);
    check_blend (BlendMode.SCREEN, 1, 255, 128, 128);
    check_blend (BlendMode.DARKEN, 1, 128, 0, 0);
    check_blend (BlendMode.LIGHTEN, 1, 255, 128, 128);
    check_blend (BlendMode.OVERLAY, 1, 255, 0, 0);
    check_blend (BlendMode.DIFFERENCE, 1, 127, 128, 128);
    check_blend (BlendMode.NORMAL, 0.5, 192, 64, 64);
    check_blend (BlendMode.MULTIPLY, 0.5, 128, 64, 64);
    foreach (var m in BlendMode.all ()) {
        assert (BlendMode.from_id (m.to_id ()) == m);
        assert (BlendMode.from_id (m.to_ora ()) == m);
    }
    assert (BlendMode.from_id ("svg:src-over") == BlendMode.NORMAL);
    assert (BlendMode.from_id ("bogus") == BlendMode.NORMAL);
}

int column_extent (Cairo.ImageSurface s, int x, out int max_alpha) {
    int count = 0;
    max_alpha = 0;
    for (int y = 0; y < s.get_height (); y++) {
        int a = alpha_of (s, x, y);
        if (a > 0) count++;
        if (a > max_alpha) max_alpha = a;
    }
    return count;
}

void test_pressure_stroke () {
    var surf = Pixels.blank (400, 100);
    var b = new BrushSettings (BrushKind.BRUSH);
    b.size = 40;
    b.smoothing = 0.3;
    var e = new StrokeEngine (surf, b, Rgba (0.1, 0.2, 0.8, 1));
    var st = new Stabilizer (b.smoothing);
    double ox, oy, op;
    for (int i = 0; i <= 90; i++) {
        double x = 20 + i * 4;
        double p = 0.1 + 0.9 * i / 90.0;
        st.push (x, 50, p, out ox, out oy, out op);
        if (i == 0) e.begin (ox, oy, op);
        else e.line_to (ox, oy, op);
        if (i % 10 == 0) e.compose ();
    }
    foreach (var q in st.finish ()) e.line_to (q.x, q.y, st.pressure);
    e.finish ();
    int a1, a2, a3;
    int w1 = column_extent (surf, 60, out a1);
    int w2 = column_extent (surf, 200, out a2);
    int w3 = column_extent (surf, 340, out a3);
    assert (w1 > 0);
    assert (w1 < w2 && w2 < w3);
    assert (a1 < a2 && a2 <= a3);
    assert (w3 >= 30 && w3 <= 42);
    assert (a3 >= 200);
    assert (a1 <= 140);
    assert (alpha_of (surf, 200, 5) == 0);

    var flat = Pixels.blank (400, 100);
    var ef = new StrokeEngine (flat, b, Rgba (0, 0, 0, 1));
    ef.begin (20, 50, 1);
    ef.line_to (380, 50, 1);
    ef.finish ();
    int f1, f3;
    int fw1 = column_extent (flat, 60, out f1);
    int fw3 = column_extent (flat, 340, out f3);
    assert (fw1 == fw3 && f1 == f3);

    var pencil = new BrushSettings (BrushKind.PENCIL);
    pencil.size = 4;
    var ps = Pixels.blank (100, 20);
    var pe = new StrokeEngine (ps, pencil, Rgba (0, 0, 0, 1));
    pe.begin (10, 10, 1);
    pe.line_to (90, 10, 1);
    pe.finish ();
    for (int x = 10; x <= 90; x++) {
        for (int y = 0; y < 20; y++) {
            int a = alpha_of (ps, x, y);
            assert (a == 0 || a == 255);
        }
    }
}

void test_marker () {
    var surf = Pixels.blank (200, 40);
    var b = new BrushSettings (BrushKind.MARKER);
    b.size = 16;
    b.opacity = 0.5;
    var e = new StrokeEngine (surf, b, Rgba (1, 0.8, 0, 1));
    e.begin (20, 20, 1);
    e.line_to (180, 20, 1);
    e.line_to (20, 20, 1);
    e.line_to (180, 20, 1);
    e.finish ();
    int a1 = alpha_of (surf, 40, 20), a2 = alpha_of (surf, 100, 20);
    assert ((a1 - 128).abs () <= 2 && (a2 - 128).abs () <= 2);
}

void test_selection_and_transform () {
    var layer = Pixels.blank (100, 100);
    var sel = new RasterSelection (100, 100);
    sel.combine (RasterSelection.rect_path (10, 10, 30, 30), SelectOp.REPLACE);
    var b = new BrushSettings (BrushKind.BRUSH);
    b.size = 30;
    b.hardness = 1;
    b.pressure_opacity = false;
    var e = new StrokeEngine (layer, b, Rgba (0, 0, 0, 1), sel.bytes ());
    e.begin (30, 30, 1);
    e.finish ();
    assert (alpha_of (layer, 25, 25) == 255);
    assert (alpha_of (layer, 35, 35) == 0);
    int bx, by, bw, bh;
    assert (sel.bounds (out bx, out by, out bw, out bh));
    assert (bx == 10 && by == 10 && bw == 20 && bh == 20);
    sel.combine (RasterSelection.rect_path (10, 10, 20, 30), SelectOp.SUBTRACT);
    assert (sel.bounds (out bx, out by, out bw, out bh) && bx == 20 && bw == 10);
    sel.combine (RasterSelection.ellipse_path (60, 60, 80, 80), SelectOp.ADD);
    assert (sel.at (70, 70) == 255 && sel.at (61, 61) == 0);
    var lasso = new Gee.ArrayList<Point?> ();
    lasso.add (Point (0, 0));
    lasso.add (Point (50, 0));
    lasso.add (Point (0, 50));
    var ls = new RasterSelection (100, 100);
    ls.combine (RasterSelection.lasso_path (lasso), SelectOp.REPLACE);
    assert (ls.at (10, 10) == 255 && ls.at (40, 40) == 0);
    ls.invert ();
    assert (ls.at (10, 10) == 0 && ls.at (40, 40) == 255);

    var src = Pixels.blank (100, 100);
    var cr = new Cairo.Context (src);
    cr.set_source_rgb (0, 0.5, 0);
    cr.rectangle (10, 10, 20, 10);
    cr.fill ();
    src.flush ();
    var box = new RasterSelection (100, 100);
    box.combine (RasterSelection.rect_path (10, 10, 30, 20), SelectOp.REPLACE);
    var f = FloatingSelection.lift (src, box);
    assert (f != null && f.bw == 20 && f.bh == 10);
    assert (alpha_of (src, 15, 15) == 0);
    f.tx = 50;
    f.ty = 40;
    f.stamp (src);
    assert (alpha_of (src, 65, 55) == 255 && alpha_of (src, 15, 15) == 0);
    var moved = f.selection (100, 100);
    assert (moved.bounds (out bx, out by, out bw, out bh) && bx == 60 && by == 50 && bw == 20 && bh == 10);

    var src2 = Pixels.blank (100, 100);
    var cr2 = new Cairo.Context (src2);
    cr2.set_source_rgb (1, 0, 0);
    cr2.rectangle (40, 45, 20, 10);
    cr2.fill ();
    src2.flush ();
    var box2 = new RasterSelection (100, 100);
    box2.combine (RasterSelection.rect_path (40, 45, 60, 55), SelectOp.REPLACE);
    var f2 = FloatingSelection.lift (src2, box2);
    f2.sx = 2;
    f2.sy = 2;
    f2.stamp (src2);
    assert (alpha_of (src2, 32, 50) == 255 && alpha_of (src2, 67, 50) == 255 && alpha_of (src2, 50, 42) == 255);
    assert (alpha_of (src2, 50, 35) == 0);
    var src3 = Pixels.blank (100, 100);
    var cr3 = new Cairo.Context (src3);
    cr3.set_source_rgb (1, 0, 0);
    cr3.rectangle (40, 45, 20, 10);
    cr3.fill ();
    src3.flush ();
    var f3 = FloatingSelection.lift (src3, box2);
    f3.angle = Math.PI / 2;
    f3.stamp (src3);
    assert (alpha_of (src3, 50, 41) == 255 && alpha_of (src3, 50, 58) == 255 && alpha_of (src3, 50, 37) == 0);
    assert (alpha_of (src3, 42, 50) == 0);
    var c = f3.corners ();
    assert (near (c[0].x, 55, 0.01) && near (c[0].y, 40, 0.01));
}

void test_color_picker () {
    var page = blend_page (BlendMode.MULTIPLY, 1);
    var c = ColorSampler.sample (page, 2, 2);
    assert (near (c.r, 128 / 255.0, 0.02) && near (c.g, 0, 0.02) && near (c.a, 1, 0.01));
    var s = Pixels.blank (4, 4);
    Pixels.set (s, 1, 1, Pixels.pack (Rgba (0.2, 0.4, 0.6, 0.5)));
    var d = ColorSampler.sample_surface (s, 1, 1);
    assert (near (d.r, 0.2, 0.02) && near (d.g, 0.4, 0.02) && near (d.b, 0.6, 0.02) && near (d.a, 0.5, 0.01));
}

void test_layers_model () {
    var doc = Raster.new_painting (50, 40);
    var page = doc.page;
    assert (page.layers.size == 1 && page.layers[0].raster);
    assert (Raster.is_painting (doc));
    var l2 = Raster.add_layer (doc, page);
    assert (page.active_layer == l2.id && page.layers.size == 2);
    var r1 = Raster.item_for (page, page.layers[0].id);
    var r2 = Raster.item_for (page, l2.id);
    assert (page.items.index_of (r1) < page.items.index_of (r2));
    var rect = new Shape ("rectangle", 5, 5, 10, 10);
    doc.add_item (rect);
    assert (!Raster.is_painting (doc));
    page.layers.remove (l2);
    page.layers.insert (0, l2);
    Raster.sort_items (page);
    assert (page.items.index_of (r2) < page.items.index_of (r1));
    assert (page.items.index_of (rect) == 2);
    assert (!r1.hit (10, 10, 1));
    doc.begin ("paint");
    r1.detach ();
    var cr = new Cairo.Context (r1.pixels ());
    cr.set_source_rgb (0, 0, 0);
    cr.paint ();
    r1.sync ();
    doc.commit ();
    assert (alpha_of (Raster.item_for (doc.page, page.layers[1].id).pixels (), 3, 3) == 255);
    doc.undo ();
    var restored = Raster.item_for (doc.page, doc.page.layers[1].id);
    assert (alpha_of (restored.pixels (), 3, 3) == 0);
    doc.redo ();
    assert (alpha_of (Raster.item_for (doc.page, doc.page.layers[1].id).pixels (), 3, 3) == 255);
    Raster.remove_layer (doc.page, doc.page.layers[0]);
    assert (doc.page.layers.size == 1);
    int rasters = 0;
    foreach (var it in doc.page.items) if (it is RasterItem) rasters++;
    assert (rasters == 1);
}

void test_pixel_clipboard () {
    var layer = Pixels.blank (40, 30);
    var cr = new Cairo.Context (layer);
    cr.set_source_rgba (1, 0, 0, 1);
    cr.rectangle (10, 5, 8, 6);
    cr.fill ();
    layer.flush ();
    var sel = new RasterSelection (40, 30);
    sel.combine (RasterSelection.rect_path (8, 4, 20, 12), SelectOp.REPLACE);
    int bx, by;
    var part = sel.extract (layer, out bx, out by);
    assert (part != null);
    assert (bx == 8 && by == 4);
    assert (part.get_width () == 12 && part.get_height () == 8);
    assert (alpha_of (part, 2, 1) == 255);
    assert (alpha_of (part, 0, 0) == 0);
    assert (alpha_of (layer, 12, 7) == 255);

    var empty = new RasterSelection (40, 30);
    int ex, ey;
    assert (empty.extract (layer, out ex, out ey) == null);

    var f = FloatingSelection.from_pixels (part, 20, 15);
    assert (f.ox == 20 && f.oy == 15 && f.bw == 12 && f.bh == 8);
    var target = Pixels.blank (40, 30);
    f.stamp (target);
    assert (alpha_of (target, 22, 16) == 255);
    assert (alpha_of (target, 12, 7) == 0);
    var placed = f.selection (40, 30);
    int sx, sy, sw, sh;
    assert (placed.bounds (out sx, out sy, out sw, out sh));
    assert (sx == 20 && sy == 15 && sw == 12 && sh == 8);

    f.tx = 3;
    f.ty = -2;
    int rx, ry;
    var shot = f.rendered (out rx, out ry);
    assert (rx == 23 && ry == 13);
    assert (shot.get_width () == 12 && shot.get_height () == 8);
    assert (alpha_of (shot, 2, 1) == 255);
    f.angle = Math.PI / 2;
    var turned = f.rendered (out rx, out ry);
    assert (turned.get_width () >= 8 && turned.get_width () <= 9);
    assert (turned.get_height () >= 12 && turned.get_height () <= 13);
}

void test_ora_flattened_layers () {
    var doc = Raster.new_painting (100, 80);
    var page = doc.page;
    assert (Ora.flattened_layers (page).length == 0);
    var shapes = new Layer ("shapes", "Diagram");
    page.layers.insert (0, shapes);
    assert (Ora.flattened_layers (page).length == 0);
    var s = new Shape ("rectangle", 10, 10, 30, 20);
    s.layer_id = shapes.id;
    page.items.add (s);
    string[] names = Ora.flattened_layers (page);
    assert (names.length == 1);
    assert (names[0] == "Diagram");
}

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    test_dab_spacing ();
    test_pressure_curves ();
    test_smoothing ();
    test_airbrush_accumulation ();
    test_eraser_alpha ();
    test_flood_fill ();
    test_blend_modes ();
    test_pressure_stroke ();
    test_marker ();
    test_selection_and_transform ();
    test_color_picker ();
    test_layers_model ();
    test_pixel_clipboard ();
    test_ora_flattened_layers ();
    print ("paint: all tests passed\n");
    return 0;
}
