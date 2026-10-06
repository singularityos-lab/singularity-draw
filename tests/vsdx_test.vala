using Singularity.Apps.Draw;

bool near (double a, double b, double eps = 0.01) {
    return (a - b).abs () <= eps;
}

uint8[] tiny_png () {
    var pix = new Gdk.Pixbuf (Gdk.Colorspace.RGB, true, 8, 4, 3);
    pix.fill (0x3366ccff);
    uint8[] buf;
    try {
        pix.save_to_buffer (out buf, "png");
    } catch (Error e) {
        assert_not_reached ();
    }
    return buf;
}

Document rich_doc () {
    var d = new Document ();
    d.title = "Visio Round Trip";
    d.grid_size = 12;
    var p = d.page;
    p.name = "Main";
    p.width = 1056;
    p.height = 816;
    p.background = "#fafafa";
    p.layers.add (new Layer ("layer2", "Notes"));
    p.layers[1].locked = true;
    p.layers[1].printable = false;
    p.active_layer = "layer2";
    var a = new Shape ("process", 100, 120, 140, 70);
    a.text = "Start {Name}";
    a.style.fill = "#ffeeaa";
    a.style.stroke = "#aa3300";
    a.style.stroke_width = 2.5;
    a.style.dash = DashKind.DASH;
    a.style.bold = true;
    a.style.italic = true;
    a.style.font_size = 14;
    a.style.font_family = "Serif";
    a.style.halign = TextHAlign.LEFT;
    a.style.valign = TextVAlign.TOP;
    a.style.shadow = true;
    a.set_field ("Name", "Ada & <Co>");
    a.set_field ("Cost", "12.5");
    d.add_item (a);
    var b = new Shape ("decision", 420, 300, 120, 90);
    b.rotation = 30;
    b.flip_h = true;
    b.style.fill_kind = FillKind.LINEAR;
    b.style.fill = "#ff0000";
    b.style.fill2 = "#0000ff80";
    b.style.gradient_angle = 45;
    b.layer_id = "layer2";
    b.text = "Line one\nLine two";
    d.add_item (b);
    var c = new Connector ();
    c.src.item_id = a.id;
    c.src.port = 1;
    c.dst.item_id = b.id;
    c.text = "yes";
    c.style.arrow_start = ArrowKind.DIAMOND_OPEN;
    c.style.arrow_end = ArrowKind.TRIANGLE;
    c.label_pos = 0.3;
    d.add_item (c);
    var free = new Connector ();
    free.route = RouteKind.STRAIGHT;
    free.src.x = 700;
    free.src.y = 100;
    free.dst.x = 800;
    free.dst.y = 200;
    free.waypoints = { Point (760, 110) };
    d.add_item (free);
    var curved = new Connector ();
    curved.route = RouteKind.CURVED;
    curved.src.item_id = b.id;
    curved.dst.x = 900;
    curved.dst.y = 500;
    d.add_item (curved);
    var ps = new PathShape ();
    var path = new PathData ();
    path.move_to (600, 600);
    path.curve_to (620, 560, 680, 560, 700, 600);
    path.line_to (650, 680);
    path.close ();
    ps.set_page_path (path);
    ps.style.fill = "#00ff00";
    d.add_item (ps);
    var line = new PathShape ();
    var lp = new PathData ();
    lp.move_to (50, 700);
    lp.line_to (300, 700);
    line.set_page_path (lp);
    line.style.arrow_end = ArrowKind.OPEN;
    d.add_item (line);
    var g1 = new Shape ("ellipse", 100, 500, 60, 40);
    var g2 = new Shape ("star", 200, 520, 50, 50);
    g2.flip_v = true;
    d.add_item (g1);
    d.add_item (g2);
    var grp = d.group (new Gee.ArrayList<Item>.wrap ({ g1, g2 }));
    grp.name = "Pair";
    var img = new ImageShape ();
    img.bytes = tiny_png ();
    img.x = 820;
    img.y = 600;
    img.w = 80;
    img.h = 60;
    d.add_item (img);
    var tb = new TableShape (2, 3);
    tb.x = 300;
    tb.y = 40;
    tb.w = 240;
    tb.h = 60;
    tb.set_cell (0, 0, "Head");
    tb.set_cell (1, 2, "Val");
    d.add_item (tb);
    var lane = new Shape ("swimlane-h", 20, 20, 900, 260);
    lane.text = "Lane";
    lane.locked = true;
    d.add_item (lane, 0);
    a.container_id = lane.id;
    a.link = "https://example.org";
    var p2 = d.add_page (-1, "Second");
    d.page_index = 1;
    var s2 = new Shape ("cylinder", 10, 10, 80, 100);
    s2.text = "DB";
    d.add_item (s2);
    d.page_index = 0;
    p2.height = 500;
    foreach (var pg in d.pages) Router.route_all (pg);
    return d;
}

void compare_items (Item x, Item y) {
    assert (x.get_type () == y.get_type ());
    assert (x.id == y.id);
    assert (x.name == y.name);
    assert (x.layer_id == y.layer_id);
    assert (x.text == y.text);
    assert (x.locked == y.locked);
    assert (x.container_id == y.container_id);
    assert (x.link == y.link);
    assert (x.style.serialize () == y.style.serialize ());
    assert (x.fields.size == y.fields.size);
    for (int i = 0; i < x.fields.size; i++) {
        assert (x.fields[i].key == y.fields[i].key);
        assert (x.fields[i].value == y.fields[i].value);
    }
    var sx = x as Shape;
    if (sx != null) {
        var sy = (Shape) y;
        assert (sx.kind == sy.kind);
        assert (near (sx.x, sy.x) && near (sx.y, sy.y) && near (sx.w, sy.w) && near (sx.h, sy.h));
        assert (near (sx.rotation, sy.rotation) && sx.flip_h == sy.flip_h && sx.flip_v == sy.flip_v);
    }
    var px = x as PathShape;
    if (px != null) {
        var py = (PathShape) y;
        assert (px.path.segs.size == py.path.segs.size);
        for (int i = 0; i < px.path.segs.size; i++) assert (near (px.path.segs[i].x, py.path.segs[i].x) && near (px.path.segs[i].y, py.path.segs[i].y));
        assert (near (px.natural_w, py.natural_w) && near (px.natural_h, py.natural_h));
    }
    var ix = x as ImageShape;
    if (ix != null) {
        var iy = (ImageShape) y;
        assert (ix.bytes.length == iy.bytes.length);
        for (int i = 0; i < ix.bytes.length; i++) assert (ix.bytes[i] == iy.bytes[i]);
        assert (ix.mime == iy.mime);
    }
    var tx = x as TableShape;
    if (tx != null) {
        var ty = (TableShape) y;
        assert (tx.rows == ty.rows && tx.cols == ty.cols);
        for (int i = 0; i < tx.cells.size; i++) assert (tx.cells[i] == ty.cells[i]);
        assert (tx.header_row == ty.header_row && tx.header_fill == ty.header_fill);
    }
    var cx = x as Connector;
    if (cx != null) {
        var cy = (Connector) y;
        assert (cx.route == cy.route);
        assert (cx.src.item_id == cy.src.item_id && cx.src.port == cy.src.port);
        assert (cx.dst.item_id == cy.dst.item_id && cx.dst.port == cy.dst.port);
        if (!cx.src.attached ()) assert (near (cx.src.x, cy.src.x) && near (cx.src.y, cy.src.y));
        if (!cx.dst.attached ()) assert (near (cx.dst.x, cy.dst.x) && near (cx.dst.y, cy.dst.y));
        assert (cx.waypoints.length == cy.waypoints.length);
        for (int i = 0; i < cx.waypoints.length; i++) assert (near (cx.waypoints[i].x, cy.waypoints[i].x) && near (cx.waypoints[i].y, cy.waypoints[i].y));
        assert (near (cx.label_pos, cy.label_pos));
    }
    var gx = x as Group;
    if (gx != null) {
        var gy = (Group) y;
        assert (gx.children.size == gy.children.size);
        for (int i = 0; i < gx.children.size; i++) compare_items (gx.children[i], gy.children[i]);
    }
}

void test_round_trip () {
    var d = rich_doc ();
    uint8[] data;
    try {
        data = Vsdx.save (d);
    } catch (Error e) {
        error ("save: %s", e.message);
    }
    string dir = Path.build_filename (Environment.get_tmp_dir (), "vsdx-out");
    DirUtils.create_with_parents (dir, 0755);
    try {
        FileUtils.set_data (Path.build_filename (dir, "roundtrip.vsdx"), data);
    } catch (Error e) {
    }
    ZipReader zip;
    try {
        zip = new ZipReader (data);
    } catch (Error e) {
        error ("zip: %s", e.message);
    }
    assert (zip.has ("[Content_Types].xml"));
    assert (zip.has ("visio/document.xml"));
    assert (zip.has ("visio/pages/page1.xml") && zip.has ("visio/pages/page2.xml"));
    assert (zip.has ("visio/media/image1.png"));
    assert (zip.has ("visio/pages/_rels/page1.xml.rels"));
    string page1 = "";
    try {
        page1 = zip.read_text ("visio/pages/page1.xml");
    } catch (Error e) {
        error ("read: %s", e.message);
    }
    assert (page1.contains ("<Connects>") && page1.contains ("Connections.X2"));
    assert (page1.contains ("RelCubBezTo"));
    Document r;
    try {
        r = Vsdx.load (data);
    } catch (Error e) {
        error ("load: %s", e.message);
    }
    assert (r.title == d.title && near (r.grid_size, 12));
    assert (r.pages.size == 2);
    assert (r.page_index == 0);
    for (int pi = 0; pi < 2; pi++) {
        var a = d.pages[pi];
        var b = r.pages[pi];
        assert (a.id == b.id && a.name == b.name && a.background == b.background);
        assert (near (a.width, b.width) && near (a.height, b.height));
        assert (a.layers.size == b.layers.size);
        for (int i = 0; i < a.layers.size; i++) {
            assert (a.layers[i].id == b.layers[i].id && a.layers[i].name == b.layers[i].name);
            assert (a.layers[i].visible == b.layers[i].visible && a.layers[i].locked == b.layers[i].locked);
            assert (a.layers[i].printable == b.layers[i].printable);
        }
        assert (a.active_layer == b.active_layer);
        assert (a.items.size == b.items.size);
        for (int i = 0; i < a.items.size; i++) compare_items (a.items[i], b.items[i]);
    }
}

void test_real_file_shapes () {
    var d = new Document ();
    var s = new Shape ("rectangle", 96, 96, 192, 96);
    s.rotation = 90;
    s.style.fill = "#336699";
    s.text = "Box";
    d.add_item (s);
    var t = new Shape ("triangle", 400, 400, 100, 80);
    t.flip_h = true;
    d.add_item (t);
    uint8[] data;
    try {
        data = Vsdx.save (d);
    } catch (Error e) {
        error ("save: %s", e.message);
    }
    var w = new ZipWriter ();
    string stripped = "";
    try {
        var zip = new ZipReader (data);
        stripped = zip.read_text ("visio/pages/page1.xml");
        foreach (string n in zip.names ()) {
            if (n == "visio/document.xml") {
                string doc = zip.read_text (n);
                int a = doc.index_of ("<DocumentSheet");
                int b = doc.index_of ("</DocumentSheet>");
                doc = doc.substring (0, a) + doc.substring (b + "</DocumentSheet>".length);
                w.add_text (n, doc);
            } else {
                w.add (n, zip.read (n));
            }
        }
    } catch (Error e) {
        error ("zip: %s", e.message);
    }
    Document r;
    try {
        r = Vsdx.load (w.finish ());
    } catch (Error e) {
        error ("load: %s", e.message);
    }
    assert (stripped != "");
    assert (r.page.items.size == 2);
    var rs = r.page.items[0] as Shape;
    assert (rs != null && rs.kind == "rectangle");
    assert (near (rs.x, 96, 0.05) && near (rs.y, 96, 0.05) && near (rs.w, 192, 0.05) && near (rs.h, 96, 0.05));
    assert (near (rs.rotation, 90, 0.01));
    assert (rs.style.fill == "#336699");
    assert (rs.text == "Box");
    var rt = r.page.items[1] as Shape;
    assert (rt != null && rt.kind == "triangle");
    assert (near (rt.x, 400, 0.05) && near (rt.y, 400, 0.05));
    assert (rt.flip_h);
    var pp = rt.page_outline ();
    var tp = t.page_outline ();
    assert (near (pp.segs[0].x, tp.segs[0].x, 0.05) && near (pp.segs[0].y, tp.segs[0].y, 0.05));
    assert (near (pp.segs[1].x, tp.segs[1].x, 0.05) && near (pp.segs[1].y, tp.segs[1].y, 0.05));
}

void add_tree (ZipWriter w, string root, string rel) throws Error {
    var dir = Dir.open (Path.build_filename (root, rel));
    string? name;
    while ((name = dir.read_name ()) != null) {
        string r = rel == "" ? name : rel + "/" + name;
        string full = Path.build_filename (root, r);
        if (FileUtils.test (full, FileTest.IS_DIR)) {
            add_tree (w, root, r);
        } else {
            uint8[] data;
            FileUtils.get_data (full, out data);
            w.add (r, data);
        }
    }
}

Item? by_name (Gee.List<Item> items, string prefix) {
    foreach (var it in items) if (it.name.has_prefix (prefix)) return it;
    return null;
}

void test_fixture () {
    string? root = Environment.get_variable ("DRAW_FIXTURES");
    assert (root != null);
    var w = new ZipWriter ();
    try {
        add_tree (w, Path.build_filename (root, "vsdx", "flowchart"), "");
    } catch (Error e) {
        error ("fixture: %s", e.message);
    }
    Document d;
    try {
        d = Formats.load_data (w.finish (), "flowchart.vsdx");
    } catch (Error e) {
        error ("load: %s", e.message);
    }
    assert (d.pages.size == 3);
    assert (d.pages[2].is_background && d.pages[2].name == "Background-1");
    assert (!d.pages[0].is_background && !d.pages[1].is_background);
    var p = d.pages[0];
    assert (p.name == "Process Flow");
    assert (near (p.width, 11 * 96) && near (p.height, 8.5 * 96));
    assert (p.layers.size == 2 && p.layers[1].name == "Annotations" && !p.layers[1].visible);
    var start = by_name (p.items, "Start") as Shape;
    assert (start != null && start.kind == "terminator");
    assert (near (start.w, 1.5 * 96, 0.1) && near (start.h, 0.75 * 96, 0.1));
    assert (near (start.x, (2 - 0.75) * 96, 0.1) && near (start.y, (8.5 - 7 - 0.375) * 96, 0.1));
    assert (start.text == "Begin");
    assert (start.style.fill == "#c6e0b4");
    assert (start.style.bold);
    assert (near (start.style.font_size, 14, 0.01));
    var check = by_name (p.items, "Check") as Shape;
    assert (check != null && check.kind == "decision");
    assert (check.text == "OK?");
    assert (near (check.style.stroke_width, 0.02083333 * 96, 0.01));
    assert (check.style.stroke == "#1f4e79");
    assert (check.style.text_color == "#333333");
    assert (near (check.style.font_size, 10, 0.01));
    assert (start.style.text_color == "#333333");
    var tri = by_name (p.items, "Tri") as PathShape;
    assert (tri != null);
    assert (tri.path.segs.size == 5);
    assert (near (tri.path.segs[2].x, 0.8 * 96, 0.01) && near (tri.path.segs[2].y, 0, 0.01));
    assert (tri.style.fill == "#ffc000");
    var custom = by_name (p.items, "Custom") as PathShape;
    assert (custom != null);
    assert (near (custom.rotation, 360 - 45, 0.01));
    var cb = custom.bounds ();
    assert (!cb.is_empty ());
    assert (custom.path.segs.size >= 5);
    assert (custom.text == "Custom\nshape");
    assert (custom.style.fill_kind == FillKind.NONE || custom.style.fill_kind == FillKind.SOLID);
    var arc = by_name (p.items, "Arcs") as PathShape;
    assert (arc != null);
    var ab = arc.page_path ().bounds ();
    assert (ab.w > 40 && ab.h > 20);
    var conn = by_name (p.items, "Dynamic connector") as Connector;
    assert (conn != null);
    assert (conn.src.item_id == start.id && conn.dst.item_id == check.id);
    assert (conn.route == RouteKind.ORTHOGONAL);
    assert (conn.style.arrow_end != ArrowKind.NONE);
    assert (conn.text == "go");
    var line = by_name (p.items, "Line") as Connector;
    assert (line != null && line.route == RouteKind.STRAIGHT);
    assert (near (line.src.x, 1 * 96, 0.1) && near (line.src.y, (8.5 - 1) * 96, 0.1));
    assert (near (line.dst.x, 4 * 96, 0.1) && near (line.dst.y, (8.5 - 1) * 96, 0.1));
    var grp = by_name (p.items, "Legend") as Group;
    assert (grp != null && grp.children.size == 2);
    var gc = grp.children[0] as Shape;
    assert (gc != null && gc.kind == "ellipse");
    assert (near (gc.cx (), (8 - 1 + 0.5) * 96, 0.1) && near (gc.cy (), (8.5 - (1.5 - 0.5 + 0.5)) * 96, 0.1));
    var gt = grp.children[1] as Shape;
    assert (gt != null && gt.text == "Legend text");
    var note = by_name (p.items, "Note") as Shape;
    assert (note != null && note.layer_id == p.layers[1].id);
    assert (note.get_field ("Owner") == "Bob");
    assert (note.get_field ("Cost") == "42");
    var img = by_name (p.items, "Picture") as ImageShape;
    assert (img != null && img.bytes.length > 0 && img.mime == "image/png");
    assert (near (img.w, 96, 0.1));
    var p2 = d.pages[1];
    assert (p2.name == "Second" && p2.items.size == 1);
    var circle = p2.items[0] as Shape;
    assert (circle != null && circle.kind == "ellipse");
}

uint8[] strip_own (uint8[] data) {
    var w = new ZipWriter ();
    try {
        var zip = new ZipReader (data);
        foreach (string n in zip.names ()) {
            if (n == "visio/document.xml") {
                string doc = zip.read_text (n);
                int a = doc.index_of ("<DocumentSheet");
                int b = doc.index_of ("</DocumentSheet>");
                doc = doc.substring (0, a) + doc.substring (b + "</DocumentSheet>".length);
                w.add_text (n, doc);
            } else {
                w.add (n, zip.read (n));
            }
        }
        return w.finish ();
    } catch (Error e) {
        error ("strip: %s", e.message);
    }
}

string part (uint8[] data, string name) {
    try {
        var zip = new ZipReader (data);
        return zip.read_text (name) ?? "";
    } catch (Error e) {
        return "";
    }
}

uint8[] fixture (string name) {
    string? root = Environment.get_variable ("DRAW_FIXTURES");
    assert (root != null);
    uint8[] data;
    try {
        FileUtils.get_data (Path.build_filename (root, "vsdx", "poi", name), out data);
    } catch (Error e) {
        error ("fixture %s: %s", name, e.message);
    }
    return data;
}

void render_pages (Document d, string prefix) {
    string dir = Path.build_filename (Environment.get_tmp_dir (), "vsdx-out");
    DirUtils.create_with_parents (dir, 0755);
    d.link_backgrounds ();
    for (int i = 0; i < d.pages.size; i++) {
        var p = d.pages[i];
        double sc = double.min (1, 1400 / double.max (p.width, p.height));
        var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) (p.width * sc) + 1, (int) (p.height * sc) + 1);
        var cr = new Cairo.Context (surf);
        cr.scale (sc, sc);
        Renderer.draw_page (cr, p, new RenderOptions ());
        surf.write_to_png (Path.build_filename (dir, "%s-p%d.png".printf (prefix, i + 1)));
    }
}

int count_formulas (Document d, out int sheet_shapes) {
    int n = 0;
    sheet_shapes = 0;
    foreach (var p in d.pages) {
        foreach (var it in p.all_items ()) {
            if (it is SheetShape) sheet_shapes++;
            if (it.sheet == null) continue;
            foreach (var c in it.sheet.cells) if (c.has_formula ()) n++;
            foreach (var sec in it.sheet.sections) foreach (var r in sec.rows) foreach (var c in r.cells) if (c.has_formula ()) n++;
        }
    }
    return n;
}

void test_poi_files () {
    string[] names = { "test.vsdx", "60973.vsdx", "60489.vsdx", "github260.vsdx", "test_text_extraction.vsdx" };
    foreach (string name in names) {
        Document d;
        try {
            d = Formats.load_data (fixture (name), name);
        } catch (Error e) {
            error ("load %s: %s", name, e.message);
        }
        int smart;
        int formulas = count_formulas (d, out smart);
        int items = 0;
        foreach (var p in d.pages) items += p.all_items ().size;
        print ("vsdx: %s pages=%d items=%d formulas=%d smart=%d theme=%s\n", name, d.pages.size, items, formulas, smart, d.theme_id);
        assert (items > 0);
        render_pages (d, name.replace (".vsdx", ""));
        var again = Vsdx.load (Vsdx.save (d));
        assert (again.pages.size == d.pages.size);
    }
    var t = Formats.load_data (fixture ("test.vsdx"), "test.vsdx");
    assert (t.theme_id == "file" && t.custom_theme != null);
    assert (t.custom_theme.accents[0] == "#5b9bd5");
    assert (t.custom_theme.font != "");
    int smart;
    assert (count_formulas (t, out smart) > 10);
    var th = Formats.load_data (fixture ("60489.vsdx"), "60489.vsdx");
    foreach (var p in th.pages) foreach (var it in p.all_items ()) assert (it.style.font_family != "Themed");
    var big = Formats.load_data (fixture ("60973.vsdx"), "60973.vsdx");
    var sizes = new Gee.ArrayList<double?> ();
    foreach (var p in big.pages) foreach (var it in p.all_items ()) sizes.add (it.bounds ().w);
    int64 t0 = get_monotonic_time ();
    foreach (var p in big.pages) SheetEval.recalc_page (p);
    int64 t1 = get_monotonic_time ();
    print ("vsdx: 60973 recalc of all pages %.1f ms\n", (t1 - t0) / 1000.0);
    int k = 0, moved = 0;
    foreach (var p in big.pages) foreach (var it in p.all_items ()) if ((it.bounds ().w - sizes[k++]).abs () > 0.5) moved++;
    print ("vsdx: 60973 items resized by recalc %d\n", moved);
    assert (moved == 0);
    var st = Vsdx.load_stencil (fixture ("60973.vsdx"));
    print ("vsdx: 60973 masters as stencil=%d\n", st.masters.size);
    assert (st.masters.size > 3);
    foreach (var m in st.masters) {
        assert (m.name != "");
        assert (m.items ().size > 0);
    }
}

Document feature_doc () {
    var d = new Document ();
    d.theme_id = "harbor";
    d.theme_variant = 2;
    var p = d.page;
    p.name = "Front";
    p.scale_paper = 1;
    p.scale_paper_units = "cm";
    p.scale_world = 1;
    p.scale_units = "m";
    p.jump_style = JumpStyle.SQUARE;
    p.jumps_vertical = true;
    p.jump_size = 1.5;
    p.guides.add (new PageGuide (true, 192));
    p.guides.add (new PageGuide (false, 288));
    var a = new Shape ("process", 96, 96, 192, 96);
    a.text = "Alpha";
    a.alt_title = "Alpha box";
    a.alt_text = "First step of the process";
    a.link = "https://example.org/doc";
    a.custom_ports = { Point (0.25, 0), Point (1, 0.75) };
    a.style.quick_color = 2;
    a.style.quick_style = 2;
    d.add_item (a);
    var b = new Shape ("decision", 480, 96, 144, 96);
    b.link = "page:Back";
    d.add_item (b);
    var c = new Connector ();
    c.src.item_id = a.id;
    c.src.port = 1;
    c.dst.item_id = b.id;
    d.add_item (c);
    var sm = new SheetShape ();
    sm.sheet = new ShapeSheet ();
    sm.sheet.set_cell ("Width", "1");
    sm.sheet.set_cell ("Height", "1", "Width*0.5");
    var g = sm.sheet.ensure_section ("Geometry", 0);
    string[] k = { "MoveTo", "LineTo", "LineTo", "LineTo" };
    string[] xf = { "Width*0", "Width*1", "Width*0.5", "Width*0" };
    string[] yf = { "Height*0", "Height*0", "Height*1", "Height*0" };
    for (int i = 0; i < 4; i++) {
        var r = new SheetRow ();
        r.ix = i + 1;
        r.kind = k[i];
        r.set_cell ("X", "0", xf[i]);
        r.set_cell ("Y", "0", yf[i]);
        g.rows.add (r);
    }
    sm.x = 96;
    sm.y = 400;
    sm.w = 192;
    sm.h = 96;
    d.add_item (sm);
    var cm = Comment.create ("Check this step");
    cm.id = "c1";
    cm.author = "Ada Lovelace";
    cm.item_id = a.id;
    cm.x = 300;
    cm.y = 90;
    var reply = Comment.create ("Done");
    reply.id = "c2";
    reply.author = "Alan Turing";
    cm.replies.add (reply);
    p.comments.add (cm);
    var back = d.add_page (-1, "Back");
    back.is_background = true;
    var logo = new Shape ("ellipse", 20, 20, 60, 60);
    d.page_index = 1;
    d.add_item (logo);
    d.page_index = 0;
    p.back_page = back.id;
    ShapeSheet.recalc_page (p);
    return d;
}

void check_features (Document r, bool own) {
    assert (r.pages.size == 2);
    var p = r.pages[0];
    var back = r.pages[1];
    assert (back.is_background && !p.is_background);
    assert (p.back_page == back.id);
    assert (p.has_scale () && p.scale_units == "m" && p.scale_paper_units == "cm");
    assert (near (p.scale_ratio (), 100, 1e-6));
    assert (p.jump_style == JumpStyle.SQUARE && p.jumps_vertical);
    assert (near (p.jump_size, 1.5, 0.01));
    assert (p.guides.size == 2);
    bool gv = false, gh = false;
    foreach (var gd in p.guides) {
        if (gd.vertical && near (gd.pos, 192, 0.1)) gv = true;
        if (!gd.vertical && near (gd.pos, 288, 0.1)) gh = true;
    }
    assert (gv && gh);
    Shape? a = null, b = null, sm = null;
    foreach (var it in p.items) {
        var s = it as Shape;
        if (s == null) continue;
        if (s.text == "Alpha") a = s;
        else if (s.sheet != null && s.sheet.get_cell ("Height") != null && s.sheet.get_cell ("Height").has_formula ()) sm = s;
        else if (s.kind == "decision") b = s;
    }
    assert (a != null && b != null && sm != null);
    assert (own ? sm is SheetShape : sm is PathShape);
    assert (a.kind == "process");
    assert (near (a.x, 96, 0.05) && near (a.w, 192, 0.05) && near (a.h, 96, 0.05));
    assert (a.alt_title == "Alpha box" && a.alt_text == "First step of the process");
    assert (a.link == "https://example.org/doc");
    assert (b.link == "page:Back");
    assert (a.custom_ports != null && a.custom_ports.length == 2);
    assert (near (a.custom_ports[1].x, 1, 0.001) && near (a.custom_ports[1].y, 0.75, 0.001));
    assert (a.style.quick_color == 2 && a.style.quick_style == 2);
    assert (near (sm.w, 192, 0.05) && near (sm.h, 96, 0.05));
    assert (sm.sheet.get_cell ("Height").formula == "Width*0.5");
    sm.w = 384;
    ShapeSheet.recalc_page (p);
    assert (near (sm.h, 192, 0.05));
    var geo = sm.geometry ();
    assert (near (geo.parts[0].path.bounds ().w, 384, 0.05));
    Connector? c = null;
    foreach (var it in p.items) if (it is Connector) c = (Connector) it;
    assert (c != null && c.src.item_id == a.id && c.dst.item_id == b.id);
    assert (c.src.port == 1);
    assert (p.comments.size >= 1);
    var cm = p.comments[0];
    assert (cm.text == "Check this step" && cm.author == "Ada Lovelace");
    assert (cm.item_id == a.id);
    if (own) {
        assert (cm.replies.size == 1 && cm.replies[0].author == "Alan Turing");
        assert (r.theme_id == "harbor" && r.theme_variant == 2);
    } else {
        assert (p.comments.size == 2);
        assert (r.theme_id == "file" && r.custom_theme != null);
        var ht = Theme.find ("harbor", 2);
        assert (r.custom_theme.accents[0] == ht.accents[0]);
    }
}

void test_writer_features () {
    var d = feature_doc ();
    uint8[] data;
    try {
        data = Vsdx.save (d);
    } catch (Error e) {
        error ("save: %s", e.message);
    }
    string dir = Path.build_filename (Environment.get_tmp_dir (), "vsdx-out");
    DirUtils.create_with_parents (dir, 0755);
    try {
        FileUtils.set_data (Path.build_filename (dir, "features.vsdx"), data);
    } catch (Error e) {
    }
    string ct = part (data, "[Content_Types].xml");
    assert (ct.contains ("/visio/masters/masters.xml") && ct.contains ("application/vnd.ms-visio.master+xml"));
    assert (ct.contains ("/visio/theme/theme1.xml") && ct.contains ("/visio/comments.xml"));
    string masters = part (data, "visio/masters/masters.xml");
    assert (masters.contains ("NameU=\"Process\"") && masters.contains ("NameU=\"Dynamic connector\""));
    string m1 = part (data, "visio/masters/master1.xml");
    assert (m1.contains ("F=\"Width*") && m1.contains ("F=\"Height*"));
    string page1 = part (data, "visio/pages/page1.xml");
    assert (page1.contains ("Master=\"1\"") && page1.contains ("Type=\"Guide\""));
    assert (page1.contains ("<Data1>Alpha box</Data1>") && page1.contains ("N=\"Hyperlink\""));
    assert (page1.contains ("F=\"Width*0.5\""));
    int alpha = page1.index_of ("Alpha</Text>");
    int proc = page1.index_of ("Master=\"1\"");
    assert (alpha > proc);
    string seg = page1.substring (proc, alpha - proc);
    assert (!seg.contains ("N=\"Geometry\""));
    string rels = part (data, "visio/pages/_rels/page1.xml.rels");
    assert (rels.contains ("masters/master1.xml"));
    string pages = part (data, "visio/pages/pages.xml");
    assert (pages.contains ("Background=\"1\"") && pages.contains ("BackPage=\"1\""));
    assert (pages.contains ("N=\"DrawingScale\"") && pages.contains ("U=\"M\""));
    string theme = part (data, "visio/theme/theme1.xml");
    assert (theme.contains ("a:clrScheme") && theme.contains (Colors.rgb_hex (Theme.find ("harbor", 2).accents[0]).substring (1).up ()));
    string comments = part (data, "visio/comments.xml");
    assert (comments.contains ("Ada Lovelace") && comments.contains ("Check this step"));
    Document own, foreign;
    try {
        own = Vsdx.load (data);
        foreign = Vsdx.load (strip_own (data));
    } catch (Error e) {
        error ("load: %s", e.message);
    }
    check_features (own, true);
    check_features (foreign, false);
    render_pages (foreign, "features-foreign");
}

void test_stencil_round_trip () {
    var st = new UserStencil ();
    st.name = "Team Shapes";
    var a = new Shape ("process", 0, 0, 120, 60);
    a.text = "Step";
    a.style.fill = "#ffcc00";
    var list = new Gee.ArrayList<Item> ();
    list.add (a);
    var m1 = StencilMaster.from_items ("Yellow Step", list);
    m1.id = "m1";
    m1.keywords = "step yellow";
    st.masters.add (m1);
    var e1 = new Shape ("ellipse", 0, 0, 40, 40);
    var e2 = new Shape ("rectangle", 50, 0, 40, 40);
    var two = new Gee.ArrayList<Item> ();
    two.add (e1);
    two.add (e2);
    var m2 = StencilMaster.from_items ("Pair", two);
    m2.id = "m2";
    st.masters.add (m2);
    uint8[] data;
    try {
        data = Vsdx.save_stencil (st);
    } catch (Error e) {
        error ("save stencil: %s", e.message);
    }
    string ct = part (data, "[Content_Types].xml");
    assert (ct.contains ("application/vnd.ms-visio.stencil.main+xml"));
    assert (!ct.contains ("pages.xml"));
    UserStencil r;
    try {
        r = Vsdx.load_stencil (data);
    } catch (Error e) {
        error ("load stencil: %s", e.message);
    }
    assert (r.name == "Team Shapes");
    assert (r.masters.size == 2);
    assert (r.masters[0].name == "Yellow Step" && r.masters[0].keywords == "step yellow");
    var items = r.masters[0].items ();
    assert (items.size == 1);
    var s = items[0] as Shape;
    assert (s != null && s.kind == "process" && s.text == "Step" && s.style.fill == "#ffcc00");
    assert (near (s.w, 120, 0.05) && near (s.h, 60, 0.05));
    var pair = r.masters[1].items ();
    assert (pair.size == 1 && pair[0] is Group && ((Group) pair[0]).children.size == 2);
}

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    test_round_trip ();
    print ("vsdx: round trip ok\n");
    test_real_file_shapes ();
    print ("vsdx: geometry import ok\n");
    test_fixture ();
    print ("vsdx: fixture import ok\n");
    test_poi_files ();
    print ("vsdx: real files ok\n");
    test_writer_features ();
    print ("vsdx: masters, theme, comments, scale, guides, ports, alt text ok\n");
    test_stencil_round_trip ();
    print ("vsdx: stencil round trip ok\n");
    print ("vsdx: all tests passed\n");
    return 0;
}
