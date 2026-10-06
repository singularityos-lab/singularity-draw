using Singularity.Apps.Draw;

int checks = 0;

void check (bool ok, string what) {
    checks++;
    if (!ok) {
        stderr.printf ("FAILED: %s\n", what);
        Process.exit (1);
    }
}

bool near (double a, double b, double eps = 0.01) {
    return (a - b).abs () <= eps;
}

uint8[] make_png () {
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 6, 4);
    var cr = new Cairo.Context (surf);
    cr.set_source_rgb (0.9, 0.2, 0.1);
    cr.paint ();
    var buf = new ByteArray ();
    surf.write_to_png_stream ((data) => {
        buf.append (data);
        return Cairo.Status.SUCCESS;
    });
    return buf.steal ();
}

Document build_sample () {
    var d = new Document ();
    d.grid_size = 12;
    d.units = "mm";
    d.title = "Sample & <Title>";
    var p = d.page;
    p.name = "Main \"page\"";
    p.width = 900;
    p.height = 640.5;
    p.background = "#fdf6e3";
    var notes = new Layer ("notes", "Notes");
    notes.visible = false;
    notes.locked = true;
    notes.printable = false;
    p.layers.add (notes);
    p.active_layer = "notes";
    int i = 0;
    foreach (var e in ShapeLibrary.entries ()) {
        var s = new Shape (e.kind, 10 + (i % 10) * 90, 10 + (i / 10) * 70, e.w, e.h);
        ShapeLibrary.apply_defaults (s);
        s.text = ShapeLibrary.default_text (e.kind);
        if (i % 3 == 0) s.rotation = 30 + i;
        if (i % 4 == 1) s.flip_h = true;
        if (i % 5 == 2) s.flip_v = true;
        d.add_item (s);
        i++;
    }
    var fancy = new Shape ("rounded-rectangle", 100.25, 200.5, 150.75, 80.125);
    fancy.style.fill_kind = FillKind.LINEAR;
    fancy.style.fill = "#ff0000";
    fancy.style.fill2 = "#0000ff80";
    fancy.style.gradient_angle = 33;
    fancy.style.dash = DashKind.DASH_DOT;
    fancy.style.shadow = true;
    fancy.style.shadow_color = "#11223344";
    fancy.style.shadow_blur = 9;
    fancy.style.corner_radius = 7;
    fancy.style.opacity = 0.6;
    fancy.style.font_family = "DejaVu Serif";
    fancy.style.font_size = 17.5;
    fancy.style.bold = true;
    fancy.style.italic = true;
    fancy.style.underline = true;
    fancy.style.strike = true;
    fancy.style.text_color = "#336699";
    fancy.style.halign = TextHAlign.RIGHT;
    fancy.style.valign = TextVAlign.BOTTOM;
    fancy.style.wrap = false;
    fancy.text = "  leading\ttab  double  space &<>\"'\n\nünïcödé trailing  ";
    fancy.name = "Fancy";
    fancy.locked = true;
    fancy.link = "https://example.org/?a=1&b=2";
    fancy.set_field ("Owner", "Ada; Lovelace=1");
    fancy.set_field ("Cost", "12,5 %");
    fancy.layer_id = "notes";
    d.add_item (fancy);
    fancy.id = "fancy-one";
    var radial = new Shape ("ellipse", 400, 300, 80, 60);
    radial.style.fill_kind = FillKind.RADIAL;
    radial.style.fill = "#ffffff";
    radial.style.fill2 = "#00aa00";
    radial.style.stroke = "none";
    d.add_item (radial);
    var path = new PathShape ();
    var pd = new PathData ();
    pd.move_to (0, 0);
    pd.curve_to (20, -30, 60, 30, 80, 0);
    pd.line_to (100, 40);
    path.set_page_path (pd);
    path.move_by (300, 400);
    path.w = 150;
    path.style.arrow_start = ArrowKind.DIAMOND_OPEN;
    path.style.arrow_end = ArrowKind.STEALTH;
    path.style.arrow_size = 1.5;
    path.style.dash = DashKind.DOT;
    d.add_item (path);
    var closed = new PathShape ();
    var cp = new PathData ();
    cp.move_to (0, 0);
    cp.line_to (50, 0);
    cp.line_to (25, 40);
    cp.close ();
    cp.move_to (10, 5);
    cp.line_to (40, 5);
    cp.line_to (25, 30);
    cp.close ();
    closed.set_page_path (cp);
    closed.move_by (500, 500);
    closed.rotation = 45;
    d.add_item (closed);
    var hline = new PathShape ();
    var hl = new PathData ();
    hl.move_to (0, 0);
    hl.line_to (100, 0);
    hline.set_page_path (hl);
    hline.move_by (20, 600);
    d.add_item (hline);
    var img = new ImageShape ();
    img.bytes = make_png ();
    img.x = 600;
    img.y = 50;
    img.w = 60;
    img.h = 40;
    img.rotation = 15;
    img.style.stroke = "#000000";
    img.style.stroke_width = 2;
    d.add_item (img);
    var t = new TableShape (3, 2);
    t.x = 50;
    t.y = 450;
    t.w = 200;
    t.h = 90;
    t.set_cell (0, 0, "Name");
    t.set_cell (0, 1, "Value");
    t.set_cell (1, 0, "multi\nline");
    t.set_cell (2, 1, "  x  ");
    t.col_fracs = { 0.3, 0.7 };
    t.row_fracs = { 0.2, 0.5, 0.3 };
    t.header_fill = "#ffcc00";
    d.add_item (t);
    var t2 = new TableShape (2, 2);
    t2.header_row = false;
    t2.x = 300;
    t2.y = 450;
    d.add_item (t2);
    var a1 = new Shape ("process", 700, 300, 80, 40);
    var a2 = new Shape ("process", 700, 400, 80, 40);
    var inner = new Group ();
    var a3 = new Shape ("ellipse", 820, 300, 30, 30);
    inner.children.add (a3);
    inner.id = "inner";
    var g = new Group ();
    g.children.add (a1);
    g.children.add (a2);
    g.children.add (inner);
    g.name = "Outer group";
    g.set_field ("k", "v");
    d.add_item (g);
    a1.id = d.new_id ();
    a2.id = d.new_id ();
    a3.id = d.new_id ();
    var pool = new Shape ("pool", 10, 700, 500, 150);
    d.add_item (pool);
    var member = new Shape ("process", 100, 720, 80, 40);
    d.add_item (member);
    check (member.container_id == pool.id, "container assigned");
    var c1 = new Connector ();
    c1.src.item_id = a1.id;
    c1.src.port = 2;
    c1.dst.item_id = fancy.id;
    c1.dst.port = -1;
    c1.route = RouteKind.CURVED;
    c1.text = "yes & no";
    c1.label_pos = 0.25;
    c1.waypoints = { Point (500.5, 250.25), Point (520, 260) };
    c1.style.arrow_start = ArrowKind.CROWS_FOOT;
    c1.style.arrow_end = ArrowKind.ONE;
    c1.jumps = true;
    d.add_item (c1);
    var c2 = new Connector ();
    c2.src.x = 10;
    c2.src.y = 10;
    c2.dst.item_id = a3.id;
    c2.dst.port = 1;
    c2.route = RouteKind.STRAIGHT;
    c2.style.arrow_end = ArrowKind.CIRCLE_OPEN;
    d.add_item (c2);
    var c3 = new Connector ();
    c3.src.item_id = member.id;
    c3.dst.item_id = radial.id;
    c3.style.arrow_end = ArrowKind.BAR;
    c3.style.arrow_start = ArrowKind.TRIANGLE_OPEN;
    d.add_item (c3);
    var p2 = d.add_page (-1, "Second");
    p2.width = 500;
    p2.height = 1000;
    p2.background = "none";
    var t3 = new Shape ("text", 10, 10, 200, 40);
    ShapeLibrary.apply_defaults (t3);
    t3.text = "Hello second page";
    p2.items.add (t3);
    t3.layer_id = p2.active_layer;
    t3.id = d.new_id ();
    var ca = new Shape ("circle", 100, 100, 50, 50);
    ca.id = d.new_id ();
    ca.layer_id = p2.active_layer;
    p2.items.add (ca);
    var cc = new Connector ();
    cc.id = d.new_id ();
    cc.src.item_id = t3.id;
    cc.src.port = 0;
    cc.dst.item_id = ca.id;
    cc.dst.port = 3;
    cc.layer_id = p2.active_layer;
    p2.items.add (cc);
    d.page_index = 1;
    foreach (var pg in d.pages) Router.route_all (pg);
    return d;
}

void compare_style (Style a, Style b, string where) {
    check (a.serialize () == b.serialize (), "style " + where + ": " + a.serialize () + " != " + b.serialize ());
}

void compare_item (Item a, Item b) {
    string w = "item " + a.id;
    check (a.get_type () == b.get_type (), w + " type");
    check (a.id == b.id, w + " id " + b.id);
    check (a.name == b.name, w + " name");
    check (a.layer_id == b.layer_id, w + " layer " + a.layer_id + " vs " + b.layer_id);
    check (a.text == b.text, w + " text [" + a.text + "] vs [" + b.text + "]");
    check (a.locked == b.locked, w + " locked");
    check (a.container_id == b.container_id, w + " container");
    check (a.link == b.link, w + " link");
    check (a.fields.size == b.fields.size, w + " fields");
    for (int i = 0; i < a.fields.size; i++) check (a.fields[i].key == b.fields[i].key && a.fields[i].value == b.fields[i].value, w + " field value");
    compare_style (a.style, b.style, w);
    var sa = a as Shape;
    if (sa != null) {
        var sb = (Shape) b;
        check (sa.kind == sb.kind, w + " kind");
        check (near (sa.x, sb.x, 0.001) && near (sa.y, sb.y, 0.001) && near (sa.w, sb.w, 0.001) && near (sa.h, sb.h, 0.001), w + " box");
        check (near (sa.rotation, sb.rotation, 1e-5), w + " rotation");
        check (sa.flip_h == sb.flip_h && sa.flip_v == sb.flip_v, w + " flip");
    }
    var pa = a as PathShape;
    if (pa != null) {
        var pb = (PathShape) b;
        check (pa.path.segs.size == pb.path.segs.size, w + " path segs");
        for (int i = 0; i < pa.path.segs.size; i++) {
            check (pa.path.segs[i].kind == pb.path.segs[i].kind, w + " seg kind");
            check (near (pa.path.segs[i].x, pb.path.segs[i].x, 0.001) && near (pa.path.segs[i].y, pb.path.segs[i].y, 0.001), w + " seg pos");
            check (near (pa.path.segs[i].x1, pb.path.segs[i].x1, 0.001) && near (pa.path.segs[i].y2, pb.path.segs[i].y2, 0.001), w + " seg ctrl");
        }
        check (near (pa.natural_w, pb.natural_w, 0.001) && near (pa.natural_h, pb.natural_h, 0.001), w + " natural");
    }
    var ia = a as ImageShape;
    if (ia != null) {
        var ib = (ImageShape) b;
        check (ia.mime == ib.mime, w + " mime");
        check (ia.bytes.length == ib.bytes.length && Memory.cmp (ia.bytes, ib.bytes, ia.bytes.length) == 0, w + " image bytes");
    }
    var ta = a as TableShape;
    if (ta != null) {
        var tb = (TableShape) b;
        check (ta.rows == tb.rows && ta.cols == tb.cols, w + " table size");
        for (int i = 0; i < ta.cells.size; i++) check (ta.cells[i] == tb.cells[i], w + " cell [" + ta.cells[i] + "] vs [" + tb.cells[i] + "]");
        for (int i = 0; i < ta.cols; i++) check (near (ta.col_fracs[i], tb.col_fracs[i], 1e-6), w + " col frac");
        for (int i = 0; i < ta.rows; i++) check (near (ta.row_fracs[i], tb.row_fracs[i], 1e-6), w + " row frac");
        check (ta.header_row == tb.header_row && ta.header_fill == tb.header_fill, w + " header");
    }
    var ga = a as Group;
    if (ga != null) {
        var gb = (Group) b;
        check (ga.children.size == gb.children.size, w + " children");
        for (int i = 0; i < ga.children.size; i++) compare_item (ga.children[i], gb.children[i]);
    }
    var ca = a as Connector;
    if (ca != null) {
        var cb = (Connector) b;
        check (ca.route == cb.route, w + " route");
        check (ca.src.item_id == cb.src.item_id && ca.src.port == cb.src.port, w + " src");
        check (ca.dst.item_id == cb.dst.item_id && ca.dst.port == cb.dst.port, w + " dst");
        check (near (ca.src.x, cb.src.x, 0.001) && near (ca.dst.y, cb.dst.y, 0.001), w + " endpoint pos");
        check (ca.waypoints.length == cb.waypoints.length, w + " waypoints");
        for (int i = 0; i < ca.waypoints.length; i++) check (near (ca.waypoints[i].x, cb.waypoints[i].x, 0.001) && near (ca.waypoints[i].y, cb.waypoints[i].y, 0.001), w + " waypoint");
        check (near (ca.label_pos, cb.label_pos, 1e-6), w + " label pos");
        check (ca.jumps == cb.jumps, w + " jumps");
    }
}

void compare_docs (Document a, Document b) {
    check (a.pages.size == b.pages.size, "page count");
    check (near (a.grid_size, b.grid_size), "grid");
    check (a.units == b.units, "units");
    check (a.title == b.title, "title");
    check (a.page_index == b.page_index, "page index");
    for (int i = 0; i < a.pages.size; i++) {
        var pa = a.pages[i];
        var pb = b.pages[i];
        check (pa.id == pb.id && pa.name == pb.name, "page id/name " + pb.name);
        check (near (pa.width, pb.width, 0.001) && near (pa.height, pb.height, 0.001), "page size");
        check (pa.background == pb.background, "page background");
        check (pa.active_layer == pb.active_layer, "active layer");
        check (pa.layers.size == pb.layers.size, "layer count");
        for (int l = 0; l < pa.layers.size; l++) {
            var la = pa.layers[l];
            var lb = pb.layers[l];
            check (la.id == lb.id && la.name == lb.name && la.visible == lb.visible && la.locked == lb.locked && la.printable == lb.printable, "layer " + la.id);
        }
        check (pa.items.size == pb.items.size, "item count");
        for (int k = 0; k < pa.items.size; k++) compare_item (pa.items[k], pb.items[k]);
    }
}

string scratch () {
    string dir = Path.build_filename (Environment.get_tmp_dir (), "odg-test");
    DirUtils.create_with_parents (dir, 0755);
    return dir;
}

void test_roundtrip () throws Error {
    var d = build_sample ();
    var data = Odg.save (d);
    check (data.length > 100, "zip written");
    check (data[30] == 'm' && data[31] == 'i' && data[37] == 'e', "mimetype first");
    check (data[8] == 0 && data[9] == 0, "mimetype stored");
    var zip = new ZipReader (data);
    check (zip.read_text ("mimetype") == "application/vnd.oasis.opendocument.graphics", "mimetype content");
    foreach (string part in new string[] { "content.xml", "styles.xml", "meta.xml", "META-INF/manifest.xml" }) check (zip.has (part), "part " + part);
    string manifest = zip.read_text ("META-INF/manifest.xml");
    check (manifest.contains ("Pictures/image1.png"), "manifest picture");
    check (zip.has ("Pictures/image1.png"), "picture stored");
    string content = zip.read_text ("content.xml");
    check (content.contains ("draw:custom-shape") && content.contains ("draw:connector") && content.contains ("table:table") && content.contains ("draw:enhanced-path"), "odf elements");
    check (content.contains ("draw:start-shape"), "connector glue");
    string styles = zip.read_text ("styles.xml");
    check (styles.contains ("draw:gradient") && styles.contains ("draw:marker") && styles.contains ("draw:stroke-dash") && styles.contains ("draw:layer-set"), "style defs");
    check (styles.contains ("fo:page-width"), "page layout");
    string dir = scratch ();
    FileUtils.set_contents (Path.build_filename (dir, "content.xml"), content);
    FileUtils.set_contents (Path.build_filename (dir, "styles.xml"), styles);
    FileUtils.set_data (Path.build_filename (dir, "sample.odg"), data);
    var back = Odg.load (data);
    compare_docs (d, back);
    var again = Odg.save (back);
    var back2 = Odg.load (again);
    compare_docs (d, back2);
    var loaded = Formats.load (Path.build_filename (dir, "sample.odg"));
    compare_docs (d, loaded);
    check (loaded.path != null, "odg keeps path");
}

void test_flat_roundtrip () throws Error {
    var d = build_sample ();
    string flat = Odg.save_flat (d);
    check (flat.contains ("office:mimetype=\"application/vnd.oasis.opendocument.graphics\""), "flat mimetype");
    check (flat.contains ("office:binary-data"), "flat image data");
    FileUtils.set_contents (Path.build_filename (scratch (), "sample.fodg"), flat);
    var back = Odg.load_flat (flat);
    compare_docs (d, back);
    var via = Formats.load_data (flat.data, "x.fodg");
    compare_docs (d, via);
}

void add_dir (ZipWriter zip, string root, string rel) throws Error {
    var dir = Dir.open (Path.build_filename (root, rel));
    string? name;
    var names = new Gee.ArrayList<string> ();
    while ((name = dir.read_name ()) != null) names.add (name);
    names.sort ();
    foreach (string n in names) {
        string r = rel == "" ? n : rel + "/" + n;
        if (r == "mimetype") continue;
        string full = Path.build_filename (root, r);
        if (FileUtils.test (full, FileTest.IS_DIR)) {
            add_dir (zip, root, r);
        } else {
            uint8[] data;
            FileUtils.get_data (full, out data);
            zip.add (r, data);
        }
    }
}

uint8[] zip_fixture (string dir) throws Error {
    var zip = new ZipWriter ();
    string mt;
    FileUtils.get_contents (Path.build_filename (dir, "mimetype"), out mt);
    zip.add_text ("mimetype", mt.strip (), false);
    add_dir (zip, dir, "");
    return zip.finish ();
}

Item? by_name (Page p, string name) {
    foreach (var it in p.all_items ()) if (it.name == name) return it;
    return null;
}

void check_lo_doc (Document d, string label) {
    check (d.pages.size == 2, label + " two pages");
    var p = d.pages[0];
    check (p.name == "Flow", label + " page name");
    check (near (p.width, 28 * Units.PX_PER_CM, 0.1) && near (p.height, 21 * Units.PX_PER_CM, 0.1), label + " page size");
    check (d.pages[1].name == "Details", label + " second page name");
    check (p.layers.size == 2 && p.layers[1].name == "Annotations", label + " layers");
    check (p.layers[1].visible && p.layers[1].locked, label + " layer flags");
    var start = by_name (p, "Start") as Shape;
    check (start != null && start.kind == "terminator", label + " terminator kind");
    check (near (start.x, 2 * Units.PX_PER_CM, 0.1) && near (start.y, 1 * Units.PX_PER_CM, 0.1), label + " start pos");
    check (near (start.w, 4 * Units.PX_PER_CM, 0.1) && near (start.h, 1.5 * Units.PX_PER_CM, 0.1), label + " start size");
    check (start.text == "Begin here", label + " start text [" + start.text + "]");
    check (Colors.rgb_hex (start.style.fill) == "#b3e5fc", label + " start fill " + start.style.fill);
    check (Colors.rgb_hex (start.style.stroke) == "#01579b", label + " start stroke");
    check (start.style.bold, label + " start bold from span");
    check (near (start.style.font_size, 14, 0.01), label + " font size");
    var dec = by_name (p, "Check") as Shape;
    check (dec != null && dec.kind == "decision", label + " decision");
    check (near (dec.rotation, 30, 0.01), label + " decision rotation " + dec.rotation.to_string ());
    check (near (dec.cx (), 8 * Units.PX_PER_CM, 0.2) && near (dec.cy (), 6 * Units.PX_PER_CM, 0.2), label + " decision center");
    check (dec.text == "Ok?\nReally", label + " decision text");
    check (dec.style.fill_kind == FillKind.LINEAR, label + " gradient fill");
    check (dec.style.shadow, label + " shadow");
    var rect = by_name (p, "Box") as Shape;
    check (rect != null && rect.kind == "rectangle" && near (rect.style.corner_radius, 0.5 * Units.PX_PER_CM, 0.1), label + " rounded rect");
    check (rect.style.dash == DashKind.DASH, label + " dash");
    check (Colors.rgb_hex (rect.style.fill) == "#729fcf", label + " default style fill inheritance " + rect.style.fill);
    check (rect.layer_id == p.layers[1].id, label + " rect on annotations layer");
    var ell = by_name (p, "Oval") as Shape;
    check (ell != null && ell.kind == "ellipse", label + " ellipse");
    check (ell.style.fill_kind == FillKind.NONE, label + " fill none");
    var conn = by_name (p, "Link") as Connector;
    check (conn != null, label + " connector");
    check (conn.src.item_id == start.id && conn.src.port == 2, label + " connector src");
    check (conn.dst.item_id == dec.id && conn.dst.port == 0, label + " connector dst");
    check (conn.style.arrow_end == ArrowKind.TRIANGLE && conn.style.arrow_start == ArrowKind.NONE, label + " arrow");
    check (conn.route == RouteKind.ORTHOGONAL, label + " route");
    check (conn.text == "go", label + " connector text");
    var free_line = by_name (p, "Rule") as PathShape;
    check (free_line != null && free_line.path.segs.size == 2, label + " line");
    var pp = free_line.page_path ();
    check (near (pp.segs[0].x, 1 * Units.PX_PER_CM, 0.1) && near (pp.segs[1].x, 10 * Units.PX_PER_CM, 0.1) && near (pp.segs[1].y, 12 * Units.PX_PER_CM, 0.1), label + " line points");
    check (free_line.style.arrow_end == ArrowKind.OPEN, label + " line arrow");
    var poly = by_name (p, "Tri") as PathShape;
    check (poly != null && poly.is_closed (), label + " polygon");
    var tpp = poly.page_path ();
    check (near (tpp.segs[1].x, 14 * Units.PX_PER_CM, 0.1) && near (tpp.segs[1].y, 10 * Units.PX_PER_CM, 0.1), label + " polygon point");
    var custom = by_name (p, "Blob") as PathShape;
    check (custom != null, label + " enhanced path shape");
    var cb = custom.page_path ().bounds ();
    check (near (cb.x, 15 * Units.PX_PER_CM, 0.5) && near (cb.w, 4 * Units.PX_PER_CM, 0.5), label + " enhanced path bounds " + cb.x.to_string () + " " + cb.w.to_string ());
    var group = by_name (p, "Pair") as Group;
    check (group != null && group.children.size == 2, label + " group");
    var img = by_name (p, "Logo") as ImageShape;
    check (img != null && img.bytes.length > 0 && img.mime == "image/png", label + " image");
    check (Renderer.pixbuf_for (img) != null, label + " image decodes");
    var tb = by_name (p, "Grid") as TableShape;
    check (tb != null && tb.rows == 3 && tb.cols == 2, label + " table size");
    check (tb.get_cell (0, 0) == "Item" && tb.get_cell (2, 1) == "42", label + " table cells");
    check (tb.header_row, label + " table header");
    check (near (tb.col_fracs[0], 0.25, 0.01), label + " column widths");
    var tbox = by_name (p, "Caption") as Shape;
    check (tbox != null && tbox.kind == "text" && tbox.text == "A caption  with spaces", label + " text box [" + (tbox != null ? tbox.text : "") + "]");
    var p2 = d.pages[1];
    var arrow = by_name (p2, "Next") as Shape;
    check (arrow != null && arrow.kind == "arrow-right", label + " arrow shape");
    check (arrow.flip_h, label + " mirrored");
    var cyl = by_name (p2, "Store") as Shape;
    check (cyl != null && cyl.kind == "database", label + " magnetic disk");
}

void test_libreoffice_fixture () throws Error {
    string root = Environment.get_variable ("DRAW_FIXTURES") ?? "tests/fixtures";
    var data = zip_fixture (Path.build_filename (root, "odg", "lo-sample"));
    var d = Odg.load (data);
    check_lo_doc (d, "zip");
    string flat;
    FileUtils.get_contents (Path.build_filename (root, "odg", "lo-sample.fodg"), out flat);
    var f = Odg.load_flat (flat);
    check_lo_doc (f, "flat");
    var again = Odg.load (Odg.save (d));
    check (again.pages.size == 2 && again.pages[0].items.size == d.pages[0].items.size, "reexport keeps items");
}

void test_formulas () {
    var eqs = new Gee.HashMap<string, string> ();
    eqs["f0"] = "$0 * 2";
    eqs["f1"] = "?f0 + width / 4";
    eqs["f2"] = "max(?f1, 10) - min(3, 4)";
    eqs["f3"] = "if(-1, 5, sqrt(16))";
    eqs["f4"] = "cos(pi) * -(2 + 3)";
    eqs["f5"] = "?f5 + 1";
    var g = new EnhancedGeometry.simple (Rect (0, 0, 100, 200), { 7.0 }, eqs);
    check (near (g.equation ("f0"), 14), "f0");
    check (near (g.equation ("f1"), 39), "f1");
    check (near (g.equation ("f2"), 36), "f2");
    check (near (g.equation ("f3"), 4), "f3");
    check (near (g.equation ("f4"), 5), "f4");
    check (near (g.equation ("f5"), 1), "recursive guard");
    var p = g.build_path ("M 0 0 L ?f0 0 100 200 Z N", 50, 100);
    check (p.segs.size == 4, "path segs");
    check (near (p.segs[1].x, 7) && near (p.segs[2].x, 50) && near (p.segs[2].y, 100), "path scale");
    var arc = g.build_path ("U 50 100 50 100 0 360 Z N", 100, 200);
    var b = arc.bounds ();
    check (near (b.w, 100, 0.5) && near (b.h, 200, 0.5), "angle ellipse");
    var wa = g.build_path ("M 0 100 W 0 0 100 200 0 100 100 100 Z", 100, 200);
    var wb = wa.bounds ();
    check (near (wb.y, 0, 0.5) && near (wb.h, 100, 0.5), "clockwise arc goes up " + wb.y.to_string () + " " + wb.h.to_string ());
    var m = Odg.parse_transform ("rotate (1.5707963) translate (2cm 1cm)");
    double x = 10, y = 0;
    m.transform_point (ref x, ref y);
    check (near (x, 2 * Units.PX_PER_CM, 0.01) && near (y, 1 * Units.PX_PER_CM - 10, 0.01), "transform order");
}

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    try {
        test_formulas ();
        test_roundtrip ();
        test_flat_roundtrip ();
        test_libreoffice_fixture ();
    } catch (Error e) {
        stderr.printf ("error: %s\n", e.message);
        return 1;
    }
    print ("odg: %d checks passed\n", checks);
    return 0;
}
