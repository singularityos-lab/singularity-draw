using Singularity.Apps.Draw;

bool near (double a, double b, double eps = 0.01) {
    return (a - b).abs () <= eps;
}

void test_path_parse () {
    var p = PathData.parse_svg ("M10 20 L30 40 h10 v-5 C1 2 3 4 5 6 s1 1 2 2 Q 0 0 10 10 t5 5 A5 5 0 0 1 20 20 z");
    assert (p.segs[0].kind == SegKind.MOVE && near (p.segs[0].x, 10) && near (p.segs[0].y, 20));
    assert (p.segs[1].kind == SegKind.LINE && near (p.segs[1].x, 30));
    assert (near (p.segs[2].x, 40) && near (p.segs[2].y, 40));
    assert (near (p.segs[3].x, 40) && near (p.segs[3].y, 35));
    assert (p.segs[4].kind == SegKind.CURVE && near (p.segs[4].x, 5) && near (p.segs[4].y, 6));
    assert (p.segs[p.segs.size - 1].kind == SegKind.CLOSE);
    var arc_end = p.segs[p.segs.size - 2];
    assert (near (arc_end.x, 20) && near (arc_end.y, 20));
    var q = PathData.parse_svg (p.to_svg (4));
    assert (q.segs.size == p.segs.size);
    for (int i = 0; i < q.segs.size; i++) {
        assert (q.segs[i].kind == p.segs[i].kind);
        assert (near (q.segs[i].x, p.segs[i].x, 0.001) && near (q.segs[i].y, p.segs[i].y, 0.001));
    }
    var implicit = PathData.parse_svg ("M0 0 10 0 10 10z m5 5 1 1");
    assert (implicit.segs[1].kind == SegKind.LINE && near (implicit.segs[1].x, 10));
    assert (implicit.segs[4].kind == SegKind.MOVE && near (implicit.segs[4].x, 5));
    assert (implicit.segs[5].kind == SegKind.LINE && near (implicit.segs[5].x, 6));
    var compact = PathData.parse_svg ("M.5.5l1-1e1");
    assert (near (compact.segs[0].x, 0.5) && near (compact.segs[0].y, 0.5));
    assert (near (compact.segs[1].x, 1.5) && near (compact.segs[1].y, -9.5));
}

void test_path_geometry () {
    var r = new PathData.rect (0, 0, 100, 50);
    assert (r.contains (10, 10));
    assert (!r.contains (110, 10));
    var b = r.bounds ();
    assert (near (b.w, 100) && near (b.h, 50));
    var e = new PathData.ellipse (50, 50, 50, 25);
    var eb = e.bounds ();
    assert (near (eb.x, 0, 0.1) && near (eb.w, 100, 0.2) && near (eb.h, 50, 0.2));
    assert (e.contains (50, 50));
    assert (!e.contains (2, 2));
    double area = 0;
    foreach (var poly in e.flatten (0.1)) area += poly.area ().abs ();
    assert (near (area, Math.PI * 50 * 25, 30));
    assert (near (r.distance_to (50, -10), 10));
    var ring = new PathData.ellipse (0, 0, 10, 10);
    var hole = new PathData.ellipse (0, 0, 5, 5);
    hole.reverse ();
    ring.append (hole);
    assert (!ring.contains (0, 0));
    assert (ring.contains (7, 0));
    var m = Cairo.Matrix.identity ();
    m.translate (5, 5);
    var t = r.transformed (m);
    assert (near (t.segs[0].x, 5) && near (t.segs[2].y, 55));
    assert (PathData.fmt (1.50) == "1.5");
    assert (PathData.fmt (-0.0001) == "0");
    assert (PathData.fmt (12.0) == "12");
    assert (near (Units.parse_length ("2.54cm"), 96));
    assert (near (Units.parse_length ("1in"), 96));
    assert (near (Units.parse_length ("72pt"), 96));
    assert (near (Units.parse_length ("15"), 15));
}

void test_colors_and_style () {
    Rgba c;
    assert (Colors.parse ("#ff8000", out c) && near (c.r, 1) && near (c.g, 128 / 255.0) && near (c.b, 0));
    assert (Colors.parse ("#f80", out c) && near (c.g, 136 / 255.0));
    assert (Colors.parse ("#ff000080", out c) && near (c.a, 128 / 255.0));
    assert (Colors.parse ("rgb(0, 255, 0)", out c) && near (c.g, 1));
    assert (Colors.parse ("rgba(0,0,255,0.5)", out c) && near (c.a, 0.5));
    assert (Colors.parse ("steelblue", out c));
    assert (!Colors.parse ("none", out c));
    assert (Colors.is_none ("transparent"));
    assert (Colors.to_hex (Rgba (1, 0, 0, 1)) == "#ff0000");
    var s = new Style ();
    s.fill = "#123456";
    s.fill_kind = FillKind.LINEAR;
    s.dash = DashKind.DASH_DOT;
    s.arrow_end = ArrowKind.DIAMOND_OPEN;
    s.font_family = "Serif;odd\\name";
    s.bold = true;
    s.shadow = true;
    s.valign = TextVAlign.BOTTOM;
    var s2 = Style.deserialize (s.serialize ());
    assert (s2.fill == "#123456" && s2.fill_kind == FillKind.LINEAR && s2.dash == DashKind.DASH_DOT);
    assert (s2.arrow_end == ArrowKind.DIAMOND_OPEN && s2.font_family == "Serif;odd\\name");
    assert (s2.bold && s2.shadow && s2.valign == TextVAlign.BOTTOM);
    assert (s.equals (s2));
    foreach (var k in ArrowKind.all ()) assert (ArrowKind.from_id (k.to_id ()) == k);
}

void test_library () {
    var st = new Style ();
    int count = 0;
    foreach (var e in ShapeLibrary.entries ()) {
        var g = ShapeLibrary.build (e.kind, e.w, double.max (e.h, 1), st);
        if (e.kind != "text") assert (g.parts.size > 0);
        foreach (var part in g.parts) {
            var b = part.path.control_bounds ();
            assert (!b.is_empty ());
            assert (b.x >= -e.w && b.x2 () <= e.w * 2 + 1);
        }
        var s = new Shape (e.kind, 0, 0, e.w, double.max (e.h, 1));
        ShapeLibrary.apply_defaults (s);
        assert (s.ports ().length >= (Stencils.find (e.kind) != null ? 1 : 3));
        count++;
    }
    assert (count > 100);
    var cats = new Gee.HashSet<string> ();
    foreach (var e in ShapeLibrary.entries ()) cats.add (e.category);
    foreach (var cat in ShapeLibrary.categories ()) assert (cats.contains (cat.id));
    assert (ShapeLibrary.is_container ("swimlane-h"));
    assert (!ShapeLibrary.is_container ("process"));
}

void test_shape_transform () {
    var s = new Shape ("rectangle", 100, 100, 100, 50);
    var p = s.to_page (0, 0);
    assert (near (p.x, 100) && near (p.y, 100));
    s.rotation = 90;
    p = s.to_page (0, 0);
    assert (near (p.x, 175) && near (p.y, 75));
    var b = s.bounds ();
    assert (near (b.w, 50) && near (b.h, 100));
    var l = s.to_local (175, 75);
    assert (near (l.x, 0) && near (l.y, 0));
    s.rotation = 0;
    s.flip_h = true;
    p = s.to_page (0, 0);
    assert (near (p.x, 200));
    assert (s.hit (150, 125, 2));
    assert (!s.hit (90, 90, 2));
    var ps = new PathShape ();
    var path = new PathData ();
    path.move_to (10, 10);
    path.line_to (110, 60);
    ps.set_page_path (path);
    assert (near (ps.x, 10) && near (ps.w, 100) && near (ps.h, 50));
    ps.w = 200;
    var pp = ps.page_path ();
    assert (near (pp.segs[1].x, 210));
    var d = new Document ();
    var dup = d.clone_with_new_ids (new Gee.ArrayList<Item>.wrap ({ ps }));
    assert (dup[0].id != ps.id);
    var ps2 = dup[0] as PathShape;
    assert (ps2 != null && ps2.path.segs.size == 2);
}

void test_display_text () {
    var s = new Shape ();
    s.text = "{Name}\n{Title} {Missing}";
    s.set_field ("Name", "Ada");
    s.set_field ("Title", "CEO");
    assert (s.display_text () == "Ada\nCEO {Missing}");
    s.set_field ("Name", "Bob");
    assert (s.get_field ("Name") == "Bob");
    s.remove_field ("Name");
    assert (s.get_field ("Name") == null);
}

Document sample_doc (out Shape a, out Shape b, out Connector c) {
    var d = new Document ();
    a = new Shape ("process", 0, 0, 100, 60);
    b = new Shape ("process", 300, 200, 100, 60);
    d.add_item (a);
    d.add_item (b);
    c = new Connector ();
    c.src.item_id = a.id;
    c.dst.item_id = b.id;
    d.add_item (c);
    Router.route_all (d.page);
    return d;
}

void test_document_undo () {
    Shape a, b;
    Connector c;
    var d = sample_doc (out a, out b, out c);
    assert (d.page.items.size == 3);
    assert (a.id != b.id && b.id != c.id);
    d.begin ("Move");
    var sel = new Gee.ArrayList<Item> ();
    sel.add (a);
    d.move_items (sel, 10, 20);
    d.commit ();
    assert (d.can_undo && d.undo_label == "Move");
    var a2 = d.page.find (a.id) as Shape;
    assert (near (a2.x, 10) && near (a2.y, 20));
    d.undo ();
    a2 = d.page.find (a.id) as Shape;
    assert (near (a2.x, 0) && near (a2.y, 0));
    assert (d.can_redo);
    d.redo ();
    a2 = d.page.find (a.id) as Shape;
    assert (near (a2.x, 10));
    d.begin ("Delete");
    d.delete_items (new Gee.ArrayList<Item>.wrap ({ d.page.find (a.id) }));
    d.commit ();
    var c2 = d.page.find (c.id) as Connector;
    assert (c2 != null && !c2.src.attached ());
    d.undo ();
    c2 = d.page.find (c.id) as Connector;
    assert (c2.src.item_id == a.id);
    var p2 = d.add_page ();
    assert (d.pages.size == 2 && p2.id != d.pages[0].id);
    var dup = d.duplicate_page (d.pages[0]);
    assert (d.pages.size == 3 && dup.items.size == 3);
    var dc = dup.connectors ()[0];
    assert (dup.find (dc.src.item_id) != null);
    assert (d.pages[0].find (dc.src.item_id) == null);
}

void test_arrange () {
    var d = new Document ();
    var s1 = new Shape ("rectangle", 0, 0, 50, 50);
    var s2 = new Shape ("rectangle", 100, 30, 50, 20);
    var s3 = new Shape ("rectangle", 400, 60, 50, 80);
    d.add_item (s1);
    d.add_item (s2);
    d.add_item (s3);
    var sel = new Gee.ArrayList<Item>.wrap ({ s1, s2, s3 });
    d.align (sel, AlignKind.TOP);
    assert (near (s1.y, 0) && near (s2.y, 0) && near (s3.y, 0));
    d.align (sel, AlignKind.RIGHT);
    assert (near (s1.x, 400) && near (s2.x, 400));
    s1.x = 0;
    s2.x = 10;
    s3.x = 400;
    d.distribute (sel, true);
    assert (near (s2.x, 200));
    d.reorder (new Gee.ArrayList<Item>.wrap ({ s1 }), 2);
    assert (d.page.items[2] == s1);
    d.reorder (new Gee.ArrayList<Item>.wrap ({ s1 }), -2);
    assert (d.page.items[0] == s1);
    d.reorder (new Gee.ArrayList<Item>.wrap ({ s1 }), 1);
    assert (d.page.items[1] == s1);
    d.reorder (new Gee.ArrayList<Item>.wrap ({ s1 }), -1);
    assert (d.page.items[0] == s1);
    var g = d.group (new Gee.ArrayList<Item>.wrap ({ s1, s2 }));
    assert (g != null && d.page.items.size == 2 && g.children.size == 2);
    assert (d.page.parent_of (s1) == g);
    assert (d.page.find (s2.id) == s2);
    var gb = g.bounds ();
    d.move_items (new Gee.ArrayList<Item>.wrap ({ g }), 5, 5);
    assert (near (g.bounds ().x, gb.x + 5));
    var released = d.ungroup (new Gee.ArrayList<Item>.wrap ({ g }));
    assert (released.size == 2 && d.page.items.size == 3);
    var r = new Shape ("rectangle", 0, 0, 100, 50);
    d.add_item (r);
    d.rotate_items (new Gee.ArrayList<Item>.wrap ({ r }), 90);
    assert (near (r.rotation, 90));
    d.rotate_items (new Gee.ArrayList<Item>.wrap ({ r }), -180);
    assert (near (r.rotation, 270));
    d.flip_items (new Gee.ArrayList<Item>.wrap ({ r }), true);
    assert (r.flip_h);
    var a = new Shape ("rectangle", 0, 0, 10, 10);
    var b = new Shape ("rectangle", 90, 0, 10, 10);
    d.add_item (a);
    d.add_item (b);
    d.flip_items (new Gee.ArrayList<Item>.wrap ({ a, b }), true);
    assert (near (a.x, 90) && near (b.x, 0));
    d.scale_items (new Gee.ArrayList<Item>.wrap ({ a, b }), Rect (0, 0, 100, 10), Rect (0, 0, 200, 20));
    assert (near (b.w, 20) && near (a.x, 180));
}

void test_containers () {
    var d = new Document ();
    var pool = new Shape ("pool", 0, 0, 500, 200);
    d.add_item (pool);
    var task = new Shape ("process", 100, 50, 80, 40);
    d.add_item (task);
    assert (task.container_id == pool.id);
    var outside = new Shape ("process", 600, 50, 80, 40);
    d.add_item (outside);
    assert (outside.container_id == "");
    d.move_items (new Gee.ArrayList<Item>.wrap ({ pool }), 30, 10);
    assert (near (task.x, 130) && near (task.y, 60));
    assert (near (outside.x, 600));
    var lane = new Shape ("swimlane-h", 0, 0, 480, 100);
    lane.x = 40;
    lane.y = 20;
    d.add_item (lane);
    assert (lane.container_id == pool.id);
    d.delete_items (new Gee.ArrayList<Item>.wrap ({ pool }));
    assert (lane.container_id == "");
}

void test_router () {
    Shape a, b;
    Connector c;
    var d = sample_doc (out a, out b, out c);
    assert (c.points.length >= 2);
    var first = c.points[0];
    var last = c.points[c.points.length - 1];
    assert (a.box ().inflate (0.5).contains (first.x, first.y));
    assert (b.box ().inflate (0.5).contains (last.x, last.y));
    for (int i = 1; i < c.points.length; i++) {
        bool ortho = near (c.points[i].x, c.points[i - 1].x) || near (c.points[i].y, c.points[i - 1].y);
        assert (ortho);
    }
    var wall = new Shape ("rectangle", 160, -200, 60, 600);
    d.add_item (wall);
    Router.route_all (d.page);
    foreach (var poly in c.path ().flatten (1)) {
        foreach (var p in poly.pts) assert (!(p.x > wall.x + 1 && p.x < wall.x + wall.w - 1 && p.y > wall.y + 1 && p.y < wall.y + wall.h - 1));
    }
    for (int i = 1; i < c.points.length; i++) {
        var p = c.points[i - 1];
        var q = c.points[i];
        for (int k = 1; k < 20; k++) {
            double x = p.x + (q.x - p.x) * k / 20.0, y = p.y + (q.y - p.y) * k / 20.0;
            assert (!(x > wall.x + 1 && x < wall.x + wall.w - 1 && y > wall.y + 1 && y < wall.y + wall.h - 1));
        }
    }
    c.route = RouteKind.STRAIGHT;
    Router.route (d.page, c);
    assert (c.points.length == 2);
    var sp = c.points[0];
    assert (near (sp.x, 100, 0.6) || near (sp.y, 60, 0.6));
    c.route = RouteKind.CURVED;
    Router.route (d.page, c);
    var cp = c.path ();
    assert (cp.segs.size >= 2);
    c.src.port = 1;
    c.route = RouteKind.ORTHOGONAL;
    d.page.items.remove (wall);
    Router.route (d.page, c);
    assert (near (c.points[0].x, 100) && near (c.points[0].y, 30));
    var lp = c.label_point ();
    assert (d.page.content_bounds ().inflate (1).contains (lp.x, lp.y));
    c.src.item_id = "";
    c.src.x = -50;
    c.src.y = -50;
    Router.route (d.page, c);
    assert (near (c.points[0].x, -50) && near (c.points[0].y, -50));
}

void test_find_replace () {
    Shape a, b;
    Connector c;
    var d = sample_doc (out a, out b, out c);
    a.text = "Start process";
    b.text = "End Process";
    c.text = "yes";
    Gee.ArrayList<Page> pages;
    var hits = d.find_text ("process", false, false, out pages);
    assert (hits.size == 2);
    hits = d.find_text ("Process", true, false, out pages);
    assert (hits.size == 1 && hits[0] == b);
    int n = d.replace_text ("process", "step", false, true);
    assert (n == 2);
    assert (a.text == "Start step" && b.text == "End step");
}

void test_render_smoke () {
    Shape a, b;
    Connector c;
    var d = sample_doc (out a, out b, out c);
    a.text = "Hello";
    a.style.shadow = true;
    a.style.fill_kind = FillKind.LINEAR;
    c.text = "label";
    c.style.arrow_start = ArrowKind.DIAMOND;
    foreach (var e in ShapeLibrary.entries ()) {
        var s = new Shape (e.kind, 500, 0, e.w, double.max (e.h, 1));
        ShapeLibrary.apply_defaults (s);
        s.text = ShapeLibrary.default_text (e.kind) != "" ? ShapeLibrary.default_text (e.kind) : "Text";
        d.add_item (s);
    }
    var t = new TableShape (3, 2);
    t.set_cell (0, 0, "Head");
    d.add_item (t);
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 400, 300);
    var cr = new Cairo.Context (surf);
    Renderer.draw_page (cr, d.page, new RenderOptions ());
    surf.flush ();
    assert (cr.status () == Cairo.Status.SUCCESS);
    unowned uchar[] data = surf.get_data ();
    int stride = surf.get_stride ();
    bool non_white = false;
    for (int y = 0; y < 60 && !non_white; y++) {
        for (int x = 0; x < 100; x++) {
            uchar bb = data[y * stride + x * 4];
            if (bb < 250) {
                non_white = true;
                break;
            }
        }
    }
    assert (non_white);
}


void test_boolean () {
    var a = new PathData.rect (0, 0, 100, 100);
    var b = new PathData.rect (50, 50, 100, 100);
    var u = PathBoolean.apply (a, b, BoolOp.UNION);
    assert (near (PathBoolean.area (u), 17500, 1));
    var i = PathBoolean.apply (a, b, BoolOp.INTERSECT);
    assert (near (PathBoolean.area (i), 2500, 1));
    var s = PathBoolean.apply (a, b, BoolOp.SUBTRACT);
    assert (near (PathBoolean.area (s), 7500, 1));
    assert (s.contains (10, 10) && !s.contains (75, 75));
    var x = PathBoolean.apply (a, b, BoolOp.EXCLUDE);
    assert (near (PathBoolean.area (x), 15000, 1));
    assert (x.contains (10, 10) && !x.contains (75, 75) && x.contains (120, 120));
    var inner = new PathData.rect (25, 25, 50, 50);
    var hole = PathBoolean.apply (a, inner, BoolOp.SUBTRACT);
    assert (near (PathBoolean.area (hole), 7500, 1));
    assert (!hole.contains (50, 50) && hole.contains (10, 50));
    var c1 = new PathData.ellipse (0, 0, 50, 50);
    var c2 = new PathData.ellipse (60, 0, 50, 50);
    var cu = PathBoolean.apply (c1, c2, BoolOp.UNION);
    double ca = PathBoolean.area (c1);
    double lens = PathBoolean.area (PathBoolean.apply (c1, c2, BoolOp.INTERSECT));
    assert (near (PathBoolean.area (cu), 2 * ca - lens, 20));
    assert (lens > 100);
    var far = new PathData.rect (500, 500, 10, 10);
    var disjoint = PathBoolean.apply (a, far, BoolOp.UNION);
    assert (near (PathBoolean.area (disjoint), 10100, 1));
    assert (PathBoolean.apply (a, far, BoolOp.INTERSECT).is_empty ());
    var touching = new PathData.rect (100, 0, 100, 100);
    assert (near (PathBoolean.area (PathBoolean.apply (a, touching, BoolOp.UNION)), 20000, 1));
}

void test_layout () {
    var d = new Document ();
    var root = new Shape ("process", 0, 0, 100, 50);
    d.add_item (root);
    var kids = new Gee.ArrayList<Shape> ();
    for (int i = 0; i < 3; i++) {
        var k = new Shape ("process", 500, 500, 100, 50);
        d.add_item (k);
        kids.add (k);
        var c = new Connector ();
        c.src.item_id = root.id;
        c.dst.item_id = k.id;
        d.add_item (c);
    }
    var g = new Shape ("process", 500, 500, 100, 50);
    d.add_item (g);
    var c2 = new Connector ();
    c2.src.item_id = kids[0].id;
    c2.dst.item_id = g.id;
    d.add_item (c2);
    var all = new Gee.ArrayList<Item> ();
    all.add_all (d.page.items);
    assert (AutoLayout.apply (d.page, all, LayoutKind.TREE_DOWN));
    foreach (var k in kids) assert (k.y > root.y + root.h);
    assert (g.y > kids[0].y + kids[0].h);
    assert (near (kids[0].y, kids[1].y) && near (kids[1].y, kids[2].y));
    assert (kids[0].x + kids[0].w <= kids[1].x && kids[1].x + kids[1].w <= kids[2].x);
    double mid = (kids[0].cx () + kids[2].cx ()) / 2;
    assert ((root.cx () - mid).abs () < 60);
    assert (AutoLayout.apply (d.page, all, LayoutKind.TREE_RIGHT));
    foreach (var k in kids) assert (k.x > root.x + root.w);
    assert (AutoLayout.apply (d.page, all, LayoutKind.HIERARCHICAL));
    foreach (var k in kids) assert (k.y > root.y + root.h);
    assert (g.y > kids[0].y);
    var cyc = new Connector ();
    cyc.src.item_id = g.id;
    cyc.dst.item_id = root.id;
    d.add_item (cyc);
    all.add (cyc);
    assert (AutoLayout.apply (d.page, all, LayoutKind.HIERARCHICAL));
    assert (AutoLayout.apply (d.page, all, LayoutKind.FORCE));
    var shapes = new Gee.ArrayList<Shape>.wrap ({ root, kids[0], kids[1], kids[2], g });
    for (int i = 0; i < shapes.size; i++) {
        for (int j = i + 1; j < shapes.size; j++) assert (!shapes[i].box ().inflate (-1).intersects (shapes[j].box ().inflate (-1)));
    }
    assert (AutoLayout.apply (d.page, all, LayoutKind.CIRCLE));
    assert (AutoLayout.apply (d.page, all, LayoutKind.GRID));
    for (int i = 0; i < shapes.size; i++) {
        for (int j = i + 1; j < shapes.size; j++) assert (!shapes[i].box ().inflate (-1).intersects (shapes[j].box ().inflate (-1)));
    }
}

void test_csv () {
    var t = CsvTable.parse ("Name,Title,Manager\r\nAda,\"CEO, founder\",\nBob,\"CTO \"\"tech\"\"\",Ada\n\nEve,Dev,Bob\n");
    assert (t.header.size == 3 && t.header[1] == "Title");
    assert (t.rows.size == 3);
    assert (t.rows[0][1] == "CEO, founder");
    assert (t.rows[1][1] == "CTO \"tech\"");
    assert (t.column ("manager") == 2);
    var semi = CsvTable.parse ("a;b\n1;2\n");
    assert (semi.header[1] == "b" && semi.rows[0][1] == "2");
    var tab = CsvTable.parse ("a\tb\n1\t2");
    assert (tab.rows[0][1] == "2");
    var d = new Document ();
    var items = DataImport.org_chart (d, t, 0, 2, 0, 1, 0, 0);
    int shapes = 0, conns = 0;
    foreach (var it in items) {
        if (it is Connector) conns++;
        else shapes++;
    }
    assert (shapes == 3 && conns == 2);
    Shape? ada = null;
    foreach (var it in items) if (it is Shape && it.get_field ("Name") == "Ada") ada = (Shape) it;
    assert (ada != null && ada.display_text () == "Ada\nCEO, founder");
    var d2 = new Document ();
    var created = DataImport.shapes_from_table (d2, t, "process", "{Name}", 0, 0);
    assert (created.size == 3 && created[2].display_text () == "Eve");
    var plain = new Shape ("rectangle");
    plain.text = "Bob";
    d2.add_item (plain);
    assert (DataImport.link_table (d2.page, t, 0) >= 1);
    assert (plain.get_field ("Title") == "CTO \"tech\"");
    string csv = DataImport.to_csv (created);
    assert (csv.contains ("\"CEO, founder\""));
}

void test_templates () {
    foreach (var info in Templates.list ()) {
        var d = Templates.build (info.id);
        assert (d.page.items.size > (info.id == "gantt" ? 1 : 3));
        assert (!d.modified && !d.can_undo);
        foreach (var c in d.page.connectors ()) assert (c.points.length >= 2);
    }
}

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    test_path_parse ();
    test_path_geometry ();
    test_colors_and_style ();
    test_library ();
    test_shape_transform ();
    test_display_text ();
    test_document_undo ();
    test_arrange ();
    test_containers ();
    test_router ();
    test_find_replace ();
    test_render_smoke ();
    test_boolean ();
    test_layout ();
    test_csv ();
    test_templates ();
    print ("model: all tests passed\n");
    return 0;
}
