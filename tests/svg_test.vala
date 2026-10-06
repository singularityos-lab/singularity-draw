using Singularity.Apps.Draw;

int checks = 0;

void check (bool cond, string what) {
    checks++;
    if (!cond) {
        stderr.printf ("FAILED: %s\n", what);
        Process.exit (1);
    }
}

bool near (double a, double b, double eps = 0.05) {
    return (a - b).abs () <= eps;
}

string fixture (string name) {
    string root = Environment.get_variable ("DRAW_FIXTURES") ?? "tests/fixtures";
    return Path.build_filename (root, "svg", name);
}

void test_fixture () throws Error {
    string text;
    FileUtils.get_contents (fixture ("shapes.svg"), out text);
    var d = SvgReader.load (text);
    double s = 200 * 96 / 25.4 / 400;
    var p = d.page;
    check (near (p.width, 400 * s, 0.01) && near (p.height, 200 * s, 0.01), "viewport size");
    var items = p.items;
    check (items.size == 14, "top level count %d".printf (items.size));
    var ids = new Gee.HashSet<string> ();
    foreach (var it in p.all_items ()) {
        check (it.id != "" && !ids.contains (it.id), "unique ids");
        ids.add (it.id);
    }

    var r1 = items[0] as Shape;
    check (r1 != null && r1.kind == "rectangle" && !(r1 is PathShape), "rect kind");
    check (near (r1.x, 10 * s) && near (r1.y, 10 * s) && near (r1.w, 60 * s) && near (r1.h, 30 * s), "rect geometry");
    check (r1.style.fill == "#0000ff" && r1.style.stroke == "#000080" && near (r1.style.stroke_width, 2 * s), "css class style");
    check (r1.style.dash == DashKind.DASH, "css tag.class dash");

    var sp = items[1] as Shape;
    check (sp.kind == "rounded-rectangle" && near (sp.style.corner_radius, 5 * s), "rounded rect");
    check (sp.style.fill == "#00ff00" && !sp.style.has_stroke (), "id selector and inline style");

    var g = items[2] as Group;
    check (g != null && g.children.size == 2, "outer group");
    var gr = g.children[0] as Shape;
    check (gr.kind == "rectangle" && near (gr.x, 150 * s) && near (gr.y, 10 * s) && near (gr.w, 40 * s) && near (gr.h, 20 * s), "scaled rect");
    check (gr.style.fill == "#ffa500" && near (gr.style.opacity, 0.5) && near (gr.style.stroke_width, 2 * s) && gr.style.stroke == "#000000", "inherited group style");
    var inner = g.children[1] as Group;
    check (inner != null && inner.children.size == 2, "nested group");
    var circ = inner.children[0] as Shape;
    check (circ.kind == "ellipse" && near (circ.x, (150 + 50) * s) && near (circ.w, 20 * s), "nested transform circle");
    check (circ.style.fill == "#ffa50080", "fill-opacity %s".printf (circ.style.fill));
    var ell = inner.children[1] as Shape;
    check (ell.style.fill_kind == FillKind.RADIAL && ell.style.fill == "#ffffff" && ell.style.fill2 == "#000000", "radial gradient");
    check (near (ell.w, 32 * s) && near (ell.h, 16 * s), "ellipse size");

    var rot = items[3] as Shape;
    check (rot.kind == "rectangle" && !(rot is PathShape) && near (rot.rotation, 45), "rotation kept editable");
    check (near (rot.cx (), 270 * s) && near (rot.cy (), 20 * s) && near (rot.w, 40 * s), "rotated center");
    check (rot.style.fill_kind == FillKind.LINEAR && rot.style.fill == "#ff0000" && rot.style.fill2 == "#0000ff80" && near (rot.style.gradient_angle, 90), "linear gradient");

    var skew = items[4] as PathShape;
    check (skew != null && skew.is_closed (), "skewed rect becomes path");
    check (skew.style.fill_kind == FillKind.LINEAR && near (skew.style.gradient_angle, 0) && skew.style.fill == "#ff0000", "gradient href inheritance");
    var sb = skew.bounds ();
    check (near (sb.x, (300 + 10 * Math.tan (20 * Math.PI / 180)) * s, 0.2), "skew applied");

    var pl = items[5] as PathShape;
    check (pl != null && !pl.is_closed () && pl.style.fill_kind == FillKind.NONE && pl.style.stroke == "#ff0000", "polyline");
    check (near (pl.style.stroke_width, 3 * s) && pl.style.arrow_end == ArrowKind.TRIANGLE && pl.style.arrow_start == ArrowKind.NONE, "marker arrow");
    check (pl.path.node_count () == 3 && near (pl.x, 10 * s) && near (pl.h, 20 * s), "polyline points");

    var pg = items[6] as PathShape;
    check (pg.is_closed () && pg.style.fill == "#008000", "polygon currentColor");

    var arc = items[7] as PathShape;
    check (arc.is_closed () && !arc.style.has_fill () && arc.style.dash == DashKind.DOT, "arc path");
    var ab = arc.bounds ();
    check (near (ab.w, 40 * s, 0.3) && near (ab.h, 20 * s, 0.3), "arc bounds %f %f".printf (ab.w, ab.h));

    var ln = items[8] as PathShape;
    check (ln != null && ln.path.node_count () == 2 && near (ln.w, 40 * s) && near (ln.h, 30 * s), "line");

    var t1 = items[9] as Shape;
    check (t1.kind == "text" && t1.text == "Hello", "text content");
    check (t1.style.bold && t1.style.font_family == "DejaVu Sans" && near (t1.style.font_size, 20 * s * 0.75) && t1.style.text_color == "#333333", "text style");
    check (near (t1.x, 10 * s, 1) && t1.y < 120 * s && t1.y + t1.h > 110 * s, "text position");
    check (!t1.style.has_fill () && !t1.style.has_stroke (), "text has no box");

    var t2 = items[10] as Shape;
    check (t2.text == "Line one\nLine two" && t2.style.italic && t2.style.halign == TextHAlign.CENTER, "tspan lines");
    check (near (t2.cx (), 200 * s, 2), "middle anchor");

    var use1 = items[11] as Group;
    check (use1 != null && use1.children.size == 2, "symbol use");
    var ur = use1.children[0] as Shape;
    check (near (ur.x, 300 * s) && near (ur.y, 100 * s) && near (ur.w, 20 * s) && ur.style.fill == "#123456", "symbol viewbox");

    var use2 = items[12] as Shape;
    check (use2.kind == "ellipse" && near (use2.cx (), 350 * s) && near (use2.cy (), 150 * s) && use2.style.fill == "#ff00ff", "use of element");

    var img = items[13] as ImageShape;
    check (img != null && img.mime == "image/png" && img.bytes.length > 20 && near (img.w, 40 * s) && near (img.x, 10 * s), "data uri image");
    check (Renderer.pixbuf_for (img) != null && img.pixel_width == 2, "image decodes");

    var extra = new Document ();
    var pasted = SvgReader.import_items (text, extra);
    check (pasted.size == 14 && pasted[0].id != "", "import items");
    var seen = new Gee.HashSet<string> ();
    foreach (var it in pasted) {
        check (!seen.contains (it.id), "fresh ids");
        seen.add (it.id);
    }
}

void test_small_cases () throws Error {
    var d = SvgReader.load ("<svg xmlns='http://www.w3.org/2000/svg' width='100' height='50'><g><rect width='10' height='10'/></g><path d='M0 0 L10 10' stroke='blue'/><foreignObject/><unknown/></svg>");
    check (d.page.items.size == 2 && near (d.page.width, 100) && near (d.page.height, 50), "single child group flattened");
    var r = d.page.items[0] as Shape;
    check (r.style.fill == "#000000" && !r.style.has_stroke (), "svg defaults");
    var d2 = SvgReader.load ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 20' width='100' height='100'><rect width='10' height='20'/></svg>");
    var r2 = d2.page.items[0] as Shape;
    check (near (r2.w, 50) && near (r2.h, 100) && near (r2.x, 25), "meet alignment");
    var d3 = SvgReader.load ("<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 10 20' width='100' height='100' preserveAspectRatio='none'><rect width='10' height='20'/></svg>");
    var r3 = d3.page.items[0] as Shape;
    check (near (r3.w, 100) && near (r3.h, 100) && near (r3.x, 0), "aspect none");
    var m = SvgReader.parse_transform ("translate(10,0) scale(2)");
    double x = 1, y = 0;
    m.transform_point (ref x, ref y);
    check (near (x, 12) && near (y, 0), "transform order");
    m = SvgReader.parse_transform ("rotate(90 10 10)");
    x = 20;
    y = 10;
    m.transform_point (ref x, ref y);
    check (near (x, 10) && near (y, 20), "rotate about center");
    m = SvgReader.parse_transform ("matrix(1 0 0 1 5 6)");
    x = 0;
    y = 0;
    m.transform_point (ref x, ref y);
    check (near (x, 5) && near (y, 6), "matrix");
    bool failed = false;
    try {
        SvgReader.load ("<html/>");
    } catch (Error e) {
        failed = true;
    }
    check (failed, "rejects non svg");
}

Document rich () {
    var d = new Document ();
    var a = new Shape ("process", 40, 40, 140, 70);
    a.text = "Alpha";
    a.style.fill = "#dae8fc";
    a.style.stroke = "#6c8ebf";
    d.add_item (a);
    var b = new Shape ("ellipse", 300, 40, 120, 80);
    b.text = "Beta";
    b.style.fill = "#ffe0a0";
    b.rotation = 20;
    d.add_item (b);
    var c = new Connector ();
    c.src.item_id = a.id;
    c.dst.item_id = b.id;
    c.text = "go";
    d.add_item (c);
    var t = new Shape ("text", 40, 200, 150, 30);
    ShapeLibrary.apply_defaults (t);
    t.text = "Caption";
    t.style.text_color = "#aa0000";
    d.add_item (t);
    var g = new Shape ("rounded-rectangle", 500, 200, 100, 60);
    g.style.fill_kind = FillKind.LINEAR;
    g.style.fill = "#ffffff";
    g.style.fill2 = "#0000ff";
    d.add_item (g);
    Router.route_all (d.page);
    return d;
}

void test_round_trip () throws Error {
    var d = rich ();
    string svg = SvgWriter.write_page (d.page, SvgWriter.page_area (d.page), true);
    string out_path = Path.build_filename (Environment.get_tmp_dir (), "svg-roundtrip.svg");
    FileUtils.set_contents (out_path, svg);
    var back = SvgReader.load (svg);
    FileUtils.remove (out_path);
    check (near (back.page.width, d.page.width, 0.01) && near (back.page.height, d.page.height, 0.01), "page size");
    check (back.page.items.size == d.page.items.size + 1, "item count %d".printf (back.page.items.size));
    var bg = back.page.items[0] as Shape;
    check (bg != null && near (bg.w, d.page.width) && bg.style.fill == "#ffffff", "background rect");
    for (int i = 0; i < d.page.items.size; i++) {
        var orig = d.page.items[i];
        var got = back.page.items[i + 1];
        var ob = orig.bounds ();
        var gb = got.bounds ();
        bool is_text = orig is Shape && ((Shape) orig).kind == "text";
        if (orig is Connector) {
            check (gb.inflate (1).contains_rect (ob), "connector bounds %d".printf (i));
        } else if (!is_text) {
            check (near (ob.cx (), gb.cx (), 3) && near (ob.cy (), gb.cy (), 3), "center of item %d: %f,%f vs %f,%f".printf (i, ob.cx (), ob.cy (), gb.cx (), gb.cy ()));
        }
    }
    var texts = new Gee.ArrayList<string> ();
    var fills = new Gee.HashSet<string> ();
    foreach (var it in back.page.all_items ()) {
        var s = it as Shape;
        if (s == null) continue;
        if (s.kind == "text") texts.add (s.text);
        if (s.style.has_fill ()) fills.add (s.style.fill);
    }
    check (texts.contains ("Alpha") && texts.contains ("Beta") && texts.contains ("go") && texts.contains ("Caption"), "texts survive");
    check (fills.contains ("#dae8fc") && fills.contains ("#ffe0a0"), "fills survive");
    bool gradient = false;
    foreach (var it in back.page.all_items ()) {
        var s = it as Shape;
        if (s != null && s.style.fill_kind == FillKind.LINEAR && s.style.fill2 == "#0000ff") gradient = true;
    }
    check (gradient, "gradient survives");
    Shape? caption = null;
    foreach (var it in back.page.all_items ()) {
        var s = it as Shape;
        if (s != null && s.text == "Caption") caption = s;
    }
    check (caption.style.text_color == "#aa0000", "text color");
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 200, 200);
    var cr = new Cairo.Context (surf);
    Renderer.draw_page (cr, back.page, new RenderOptions ());
    check (cr.status () == Cairo.Status.SUCCESS, "renders imported page");
    string keep = Environment.get_variable ("DRAW_SVG_KEEP") ?? "";
    if (keep != "") FileUtils.set_contents (keep, svg);
}

int main () {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    try {
        test_fixture ();
        test_small_cases ();
        test_round_trip ();
    } catch (Error e) {
        stderr.printf ("error: %s\n", e.message);
        return 1;
    }
    print ("svg: %d checks passed\n", checks);
    return 0;
}
