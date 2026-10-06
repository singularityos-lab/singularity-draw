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
    return Path.build_filename (root, "drawio", name);
}

uint8[] tiny_png () {
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 4, 3);
    var cr = new Cairo.Context (surf);
    cr.set_source_rgb (0.2, 0.4, 0.9);
    cr.paint ();
    string path = Path.build_filename (Environment.get_tmp_dir (), "drawio-tiny.png");
    surf.write_to_png (path);
    uint8[] data;
    try {
        FileUtils.get_data (path, out data);
    } catch (Error e) {
        data = {};
    }
    FileUtils.remove (path);
    return data;
}

Document rich (out uint8[] png) {
    var d = new Document ();
    var p = d.page;
    p.name = "Main";
    p.width = 1400;
    p.height = 900;
    p.background = "#fdf6e3";
    var l2 = new Layer ("layer2", "Annotations");
    l2.visible = false;
    l2.locked = true;
    p.layers.add (l2);

    var a = new Shape ("process", 40, 40, 140, 70);
    a.text = "Receive\norder";
    a.style.fill = "#dae8fc";
    a.style.stroke = "#6c8ebf";
    a.style.stroke_width = 2.5;
    a.style.dash = DashKind.DASH_DOT;
    a.style.shadow = true;
    a.style.bold = true;
    a.style.italic = true;
    a.style.underline = true;
    a.style.font_size = 14;
    a.style.font_family = "Serif";
    a.style.text_color = "#112233";
    a.style.halign = TextHAlign.LEFT;
    a.style.valign = TextVAlign.TOP;
    a.rotation = 30;
    a.flip_h = true;
    a.set_field ("Owner", "Ada");
    a.set_field ("Cost Center", "42");
    a.link = "https://example.org";
    d.add_item (a);

    var b = new Shape ("decision", 300, 40, 120, 80);
    b.text = "OK?";
    d.add_item (b);

    var r = new Shape ("rounded-rectangle", 500, 40, 120, 60);
    r.style.corner_radius = 6;
    r.style.fill_kind = FillKind.LINEAR;
    r.style.fill = "#ffffff";
    r.style.fill2 = "#7ea6e0";
    r.style.gradient_angle = 45;
    r.style.opacity = 0.8;
    d.add_item (r);

    var t = new Shape ("triangle", 700, 40, 80, 60);
    t.flip_v = true;
    d.add_item (t);

    var e = new Shape ("ellipse", 820, 40, 90, 50);
    e.style.fill = "#ff000080";
    e.style.stroke = "none";
    d.add_item (e);

    var txt = new Shape ("text", 40, 200, 160, 30);
    ShapeLibrary.apply_defaults (txt);
    txt.text = "Free text";
    d.add_item (txt);

    var uml = new Shape ("uml-class", 1000, 40, 160, 110);
    ShapeLibrary.apply_defaults (uml);
    uml.text = ShapeLibrary.default_text ("uml-class");
    d.add_item (uml);

    var c1 = new Connector ();
    c1.src.item_id = a.id;
    c1.src.port = 1;
    c1.dst.item_id = b.id;
    c1.dst.port = 3;
    c1.text = "next";
    c1.label_pos = 0.25;
    c1.style.arrow_start = ArrowKind.DIAMOND_OPEN;
    c1.style.arrow_end = ArrowKind.TRIANGLE;
    c1.style.dash = DashKind.DASH;
    c1.style.stroke = "#aa0000";
    c1.style.stroke_width = 2;
    d.add_item (c1);

    var c2 = new Connector ();
    c2.route = RouteKind.STRAIGHT;
    c2.src.x = 100;
    c2.src.y = 400;
    c2.dst.x = 300;
    c2.dst.y = 450;
    c2.waypoints = { Point (200, 380), Point (250, 420) };
    c2.style.arrow_end = ArrowKind.CROWS_FOOT;
    c2.style.arrow_start = ArrowKind.ONE;
    d.add_item (c2);

    var c3 = new Connector ();
    c3.route = RouteKind.CURVED;
    c3.src.item_id = b.id;
    c3.dst.item_id = r.id;
    c3.style.arrow_end = ArrowKind.STEALTH;
    c3.style.fill_kind = FillKind.SOLID;
    c3.style.fill = "#ffffcc";
    d.add_item (c3);

    var g1 = new Shape ("rectangle", 400, 300, 60, 40);
    var g2 = new Shape ("star", 480, 320, 50, 50);
    d.add_item (g1);
    d.add_item (g2);
    var grp = d.group (new Gee.ArrayList<Item>.wrap ({ g1, g2 }));
    check (grp != null, "group created");

    png = tiny_png ();
    var img = new ImageShape ();
    img.bytes = png;
    img.mime = "image/png";
    img.x = 600;
    img.y = 300;
    img.w = 40;
    img.h = 30;
    d.add_item (img);

    var tb = new TableShape (2, 3);
    tb.x = 40;
    tb.y = 500;
    tb.w = 300;
    tb.h = 80;
    tb.set_cell (0, 0, "Item");
    tb.set_cell (0, 1, "Qty");
    tb.set_cell (1, 2, "9.50");
    tb.col_fracs = { 0.5, 0.25, 0.25 };
    tb.header_fill = "#ccddee";
    d.add_item (tb);

    var ps = new PathShape ();
    var path = new PathData ();
    path.move_to (700, 300);
    path.curve_to (720, 260, 760, 260, 780, 300);
    path.line_to (740, 340);
    path.close ();
    ps.set_page_path (path);
    ps.style.fill = "#00ff00";
    d.add_item (ps);

    var hidden = new Shape ("note", 1000, 300, 100, 60);
    hidden.text = "secret";
    d.add_item (hidden);
    hidden.layer_id = "layer2";

    var p2 = d.add_page (-1, "Lanes");
    d.page_index = 1;
    var pool = new Shape ("pool", 0, 0, 500, 200);
    pool.text = "Pool";
    d.add_item (pool);
    var task = new Shape ("bpmn-task", 100, 50, 100, 60);
    task.text = "Task";
    d.add_item (task);
    var gw = new Shape ("bpmn-gateway-parallel", 300, 60, 50, 50);
    d.add_item (gw);
    d.page_index = 0;
    Router.route_all (d.pages[0]);
    Router.route_all (p2);
    return d;
}

void test_round_trip () throws Error {
    uint8[] png;
    var d = rich (out png);
    string xml = Drawio.save (d);
    check (xml.has_prefix ("<?xml") && xml.contains ("<mxfile host=\"Singularity\""), "mxfile header");
    check (xml.contains ("shape=mxgraph.flowchart.decision"), "flowchart shape name");
    check (xml.contains ("<object "), "object wrapper");
    string path = Path.build_filename (Environment.get_tmp_dir (), "roundtrip.drawio");
    FileUtils.set_contents (path, xml);
    var back = Formats.load (path);
    FileUtils.remove (path);
    check (back.pages.size == 2, "pages");
    var p = back.pages[0];
    check (p.name == "Main" && near (p.width, 1400) && near (p.height, 900), "page props");
    check (p.background == "#fdf6e3", "background");
    check (p.layers.size == 2 && p.layers[1].name == "Annotations" && !p.layers[1].visible && p.layers[1].locked, "layers");
    var orig = d.pages[0];
    foreach (var it in orig.all_items ()) {
        var got = p.find (it.id);
        check (got != null, "item %s present".printf (it.id));
        check (got.layer_id == it.layer_id || (it.layer_id == "" && got.layer_id == p.layers[0].id), "layer of %s".printf (it.id));
        check (got.text == it.text, "text of %s: '%s' vs '%s'".printf (it.id, got.text, it.text));
        var s = it as Shape;
        if (s != null) {
            var gs = got as Shape;
            check (gs != null && gs.kind == s.kind, "kind of %s: %s".printf (it.id, gs != null ? gs.kind : "?"));
            check (near (gs.x, s.x) && near (gs.y, s.y) && near (gs.w, s.w) && near (gs.h, s.h), "geometry of %s".printf (it.id));
            check (near (gs.rotation, s.rotation) && gs.flip_h == s.flip_h && gs.flip_v == s.flip_v, "transform of %s".printf (it.id));
            if (!(s is ImageShape) && !(s is TableShape)) {
                check (gs.style.has_fill () == s.style.has_fill (), "fill presence %s".printf (it.id));
                if (s.style.has_fill ()) check (gs.style.fill == Colors.to_hex (parse (s.style.fill), true), "fill of %s: %s vs %s".printf (it.id, gs.style.fill, s.style.fill));
                check (gs.style.fill_kind == s.style.fill_kind, "fill kind of %s".printf (it.id));
                check (gs.style.has_stroke () == s.style.has_stroke (), "stroke presence %s".printf (it.id));
                if (s.style.has_stroke ()) check (gs.style.stroke == s.style.stroke, "stroke of %s".printf (it.id));
                check (near (gs.style.stroke_width, s.style.stroke_width), "stroke width %s".printf (it.id));
                check (gs.style.dash == s.style.dash, "dash %s".printf (it.id));
                check (near (gs.style.font_size, s.style.font_size), "font size %s".printf (it.id));
                check (gs.style.font_family == s.style.font_family, "font family %s".printf (it.id));
                check (gs.style.bold == s.style.bold && gs.style.italic == s.style.italic && gs.style.underline == s.style.underline, "font flags %s".printf (it.id));
                check (gs.style.halign == s.style.halign && gs.style.valign == s.style.valign, "align %s".printf (it.id));
                check (gs.style.text_color == s.style.text_color, "text color %s".printf (it.id));
                check (gs.style.shadow == s.style.shadow, "shadow %s".printf (it.id));
                check (near (gs.style.corner_radius, s.style.corner_radius), "radius %s".printf (it.id));
                check (near (gs.style.opacity, s.style.opacity, 0.01), "opacity %s".printf (it.id));
            }
        }
        check (got.fields.size == it.fields.size, "field count %s".printf (it.id));
        foreach (var f in it.fields) {
            string key = f.key.replace (" ", "_");
            check (got.get_field (key) == f.value, "field %s of %s".printf (f.key, it.id));
        }
        check (got.link == it.link, "link %s".printf (it.id));
        var c = it as Connector;
        if (c != null) {
            var gc = got as Connector;
            check (gc != null, "connector type");
            check (gc.route == c.route, "route of %s".printf (it.id));
            check (gc.src.item_id == c.src.item_id && gc.dst.item_id == c.dst.item_id, "attachment %s".printf (it.id));
            check (gc.src.port == c.src.port && gc.dst.port == c.dst.port, "ports %s: %d/%d".printf (it.id, gc.src.port, gc.dst.port));
            check (gc.style.arrow_start == c.style.arrow_start && gc.style.arrow_end == c.style.arrow_end, "arrows %s".printf (it.id));
            check (gc.style.dash == c.style.dash && gc.style.stroke == c.style.stroke && near (gc.style.stroke_width, c.style.stroke_width), "edge stroke %s".printf (it.id));
            check (near (gc.label_pos, c.label_pos, 0.001), "label pos %s".printf (it.id));
            check (gc.waypoints.length == c.waypoints.length, "waypoints %s".printf (it.id));
            for (int i = 0; i < c.waypoints.length; i++) check (near (gc.waypoints[i].x, c.waypoints[i].x) && near (gc.waypoints[i].y, c.waypoints[i].y), "waypoint pos");
            if (!c.src.attached ()) check (near (gc.src.x, c.src.x) && near (gc.src.y, c.src.y), "free source");
            check ((gc.style.fill_kind == FillKind.NONE) == (c.style.fill_kind == FillKind.NONE), "label background %s".printf (it.id));
        }
    }
    var grp = p.items[orig.items.index_of (orig.items.first_match ((i) => i is Group))] as Group;
    check (grp != null && grp.children.size == 2, "group preserved in order");
    ImageShape? img = null;
    TableShape? tb = null;
    PathShape? ps = null;
    foreach (var it in p.all_items ()) {
        if (it is ImageShape) img = (ImageShape) it;
        if (it is TableShape) tb = (TableShape) it;
        if (it is PathShape) ps = (PathShape) it;
    }
    check (img != null && img.bytes.length == png.length && img.mime == "image/png", "image bytes");
    for (int i = 0; i < png.length; i++) check (img.bytes[i] == png[i], "image byte");
    check (tb != null && tb.rows == 2 && tb.cols == 3 && tb.get_cell (0, 1) == "Qty" && tb.get_cell (1, 2) == "9.50", "table cells");
    check (near (tb.col_fracs[0], 0.5, 0.001) && tb.header_row && tb.header_fill == "#ccddee", "table layout");
    check (ps != null && ps.is_closed () && ps.path.segs.size == 4 && ps.path.segs[1].kind == SegKind.CURVE, "path shape");
    var uml = p.all_items ().first_match ((i) => i is Shape && ((Shape) i).kind == "uml-class") as Shape;
    check (uml != null && uml.text == ShapeLibrary.default_text ("uml-class"), "uml class sections");
    var p2 = back.pages[1];
    check (p2.name == "Lanes" && p2.items.size == 3, "second page");
    var task = p2.items[1] as Shape;
    check (task.kind == "bpmn-task" && task.container_id == p2.items[0].id, "container membership");
    check (((Shape) p2.items[2]).kind == "bpmn-gateway-parallel", "gateway kind");
    string again = Drawio.save (back);
    var back2 = Drawio.load (again);
    check (back2.pages[0].all_items ().size == p.all_items ().size, "second round trip stable");
}

Rgba parse (string s) {
    Rgba c;
    Colors.parse (s, out c);
    return c;
}

void test_fixture () throws Error {
    var d = Formats.load (fixture ("flow.drawio"));
    check (d.pages.size == 2, "fixture pages");
    var p = d.pages[0];
    check (p.name == "Order Flow" && near (p.width, 1169) && near (p.height, 827), "fixture page size");
    check (p.background == "#fafafa", "fixture background");
    check (p.layers.size == 2 && p.layers[0].name == "Main" && p.layers[1].id == "notes" && !p.layers[1].visible && p.layers[1].locked, "fixture layers");
    var start = p.find ("start") as Shape;
    check (start != null && start.kind == "terminator" && start.text == "Start", "terminator");
    check (start.style.fill == "#d5e8d4" && start.style.stroke == "#82b366" && start.style.bold && near (start.style.font_size, 12), "terminator style");
    var chk = p.find ("check") as Shape;
    check (chk.kind == "diamond" && near (chk.w, 120) && near (chk.h, 80), "rhombus");
    var ship = p.find ("ship") as Shape;
    check (ship.kind == "rounded-rectangle" && near (ship.style.corner_radius, 12), "rounded arc size");
    check (ship.text == "Ship\norder now", "html label stripped: '%s'".printf (ship.text));
    check (ship.style.fill_kind == FillKind.LINEAR && ship.style.fill2 == "#7ea6e0" && near (ship.style.gradient_angle, 90), "gradient");
    check (ship.style.dash == DashKind.DASH && ship.style.shadow && near (ship.rotation, 15), "dash shadow rotation");
    check (ship.style.halign == TextHAlign.LEFT && ship.style.valign == TextVAlign.TOP && ship.style.text_color == "#333333", "text align");
    check ((p.find ("db") as Shape).kind == "cylinder", "cylinder");
    var doc_shape = p.find ("doc") as Shape;
    check (doc_shape.kind == "document" && doc_shape.flip_h, "document flip");
    var tri = p.find ("tri") as Shape;
    check (tri.kind == "triangle" && near (tri.rotation, 90) && near (tri.w, 80) && near (tri.h, 60) && near (tri.cx (), 630) && near (tri.cy (), 80), "triangle direction");
    var person = p.find ("person") as Shape;
    check (person != null && person.text == "Ada Lovelace" && person.get_field ("Department") == "Research" && person.get_field ("Phone") == "555-0100", "object fields");
    check (person.link == "https://example.org/ada" && person.fields.size == 2, "object link");
    var e1 = p.find ("e1") as Connector;
    check (e1 != null && e1.route == RouteKind.ORTHOGONAL && e1.src.item_id == "start" && e1.dst.item_id == "check", "edge e1");
    check (e1.src.port == 2 && e1.dst.port == 0, "exit entry ports");
    check (e1.style.arrow_end == ArrowKind.STEALTH && e1.style.arrow_start == ArrowKind.NONE, "default arrows");
    var e2 = p.find ("e2") as Connector;
    check (e2.text == "yes" && e2.style.arrow_end == ArrowKind.TRIANGLE_OPEN && e2.style.arrow_start == ArrowKind.CIRCLE, "e2 arrows");
    check (e2.style.dash == DashKind.DOT && near (e2.style.stroke_width, 2) && e2.style.stroke == "#ff0000", "e2 stroke");
    check (e2.waypoints.length == 1 && near (e2.waypoints[0].x, 210) && e2.src.port == 1 && e2.dst.port == 3, "e2 points");
    var e3 = p.find ("e3") as Connector;
    check (e3.route == RouteKind.CURVED && e3.style.arrow_end == ArrowKind.DIAMOND && e3.text == "query stock" && near (e3.label_pos, 0.25), "edge label child");
    check (p.find ("e3label") == null, "label cell consumed");
    var e4 = p.find ("e4") as Connector;
    check (e4.route == RouteKind.STRAIGHT && !e4.src.attached () && near (e4.src.x, 40) && near (e4.dst.y, 440) && e4.style.arrow_end == ArrowKind.NONE, "free edge");
    var lane = p.find ("lane") as Shape;
    check (lane.kind == "swimlane-h", "swimlane horizontal=0");
    var pick = p.find ("pick") as Shape;
    check (near (pick.x, 100) && near (pick.y, 540) && pick.container_id == "lane", "container child absolute");
    var e5 = p.find ("e5") as Connector;
    check (e5.src.item_id == "pick" && e5.dst.item_id == "pack", "edge in container");
    var grp = p.find ("grp") as Group;
    check (grp != null && grp.children.size == 2, "group");
    var g1 = p.find ("g1") as Shape;
    check (g1.kind == "circle" && near (g1.x, 700) && near (g1.y, 300), "group child absolute");
    var g2 = p.find ("g2") as Shape;
    check (g2.kind == "data" && near (g2.x, 800) && near (g2.y, 340), "group child 2");
    var hidden = p.find ("hidden") as Shape;
    check (hidden.layer_id == "notes" && hidden.kind == "note" && !p.item_visible (hidden), "hidden layer item");
    var cls = p.find ("cls") as Shape;
    check (cls.kind == "uml-class" && cls.text == "Order\n--\n+ id: int\n--\n+ total(): float", "uml stack: '%s'".printf (cls.text));
    check (p.find ("cls-a") == null, "stack children consumed");
    check ((p.find ("gw") as Shape).kind == "bpmn-gateway-parallel", "bpmn gateway2");
    var lbl = p.find ("lbl") as Shape;
    check (lbl.kind == "text" && !lbl.style.has_fill () && !lbl.style.has_stroke () && lbl.style.font_family == "Courier New" && near (lbl.style.font_size, 9), "text cell");
    var p2 = d.pages[1];
    check (p2.name == "Second" && p2.find ("start") == null && p2.find ("p2_start") != null, "duplicate ids renamed: %s".printf (p2.items[0].id));
    var other = p2.items[0] as Shape;
    check (other.kind == "ellipse" && !other.style.has_fill (), "fill none");
    var pic = p2.find ("pic") as ImageShape;
    check (pic != null && pic.mime == "image/svg+xml" && Formats.as_text (pic.bytes).contains ("<svg"), "svg image");
    var tbl = p2.find ("tbl") as TableShape;
    check (tbl != null && tbl.rows == 2 && tbl.cols == 2 && tbl.get_cell (0, 0) == "Name" && tbl.get_cell (1, 1) == "3", "table import");
    check (near (tbl.col_fracs[1], 2.0 / 3, 0.01) && tbl.header_row && tbl.header_fill == "#e6e6e6", "table widths");
    Router.route_all (p);
    check (e1.points.length >= 2, "routes after load");
}

void test_compressed () throws Error {
    var d = Formats.load (fixture ("compressed.drawio"));
    check (d.pages.size == 1 && d.pages[0].name == "Compressed", "compressed page");
    var p = d.pages[0];
    check (near (p.width, 600) && near (p.height, 400), "compressed size");
    var a = p.find ("a") as Shape;
    check (a != null && a.text == "Café & Crème" && a.kind == "ellipse" && a.style.fill == "#f8cecc", "compressed shape: %s".printf (a != null ? a.text : "null"));
    var b = p.find ("b") as Shape;
    check (b.kind == "terminator", "compressed terminator");
    var c = p.find ("c") as Connector;
    check (c.text == "100% sure" && c.src.item_id == "a" && c.dst.item_id == "b", "compressed edge");
    string packed = Drawio.deflate ("<mxGraphModel><root><mxCell id=\"0\"/></root></mxGraphModel>");
    check (Drawio.inflate (packed).has_prefix ("<mxGraphModel>"), "deflate inflate");
    var bare = Drawio.load ("<mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/><mxCell id=\"x\" value=\"Hi\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"1\" y=\"2\" width=\"3\" height=\"4\" as=\"geometry\"/></mxCell></root></mxGraphModel>");
    check (bare.pages.size == 1 && bare.pages[0].items.size == 1 && ((Shape) bare.pages[0].items[0]).kind == "rectangle", "bare model");
    check (Drawio.strip_html ("a&lt;b&gt;<br/>c&#233;&#x41;") == "a<b>\ncéA", "entities");
    bool failed = false;
    try {
        Drawio.load ("<html/>");
    } catch (Error e) {
        failed = true;
    }
    check (failed, "rejects non drawio");
}

int main () {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    try {
        test_round_trip ();
        test_fixture ();
        test_compressed ();
    } catch (Error e) {
        stderr.printf ("error: %s\n", e.message);
        return 1;
    }
    print ("drawio: %d checks passed\n", checks);
    return 0;
}
