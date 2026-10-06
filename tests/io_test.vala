using Singularity.Apps.Draw;

bool near (double a, double b, double eps = 0.01) {
    return (a - b).abs () <= eps;
}

string scratch (string name) {
    return Path.build_filename (Environment.get_tmp_dir (), "draw-io-" + name);
}

Document rich () {
    var d = new Document ();
    var a = new Shape ("process", 40, 40, 120, 60);
    a.text = "Alpha & <beta>";
    a.style.fill_kind = FillKind.LINEAR;
    a.style.fill2 = "#ff000080";
    a.style.shadow = true;
    a.rotation = 30;
    a.flip_v = true;
    a.set_field ("Owner", "Ada");
    a.link = "https://example.org";
    a.name = "First";
    d.add_item (a);
    var b = new Shape ("uml-class", 300, 200, 160, 110);
    b.text = ShapeLibrary.default_text ("uml-class");
    ShapeLibrary.apply_defaults (b);
    d.add_item (b);
    var c = new Connector ();
    c.src.item_id = a.id;
    c.src.port = 1;
    c.dst.item_id = b.id;
    c.text = "uses";
    c.waypoints = { Point (250, 120) };
    c.style.arrow_start = ArrowKind.DIAMOND;
    c.style.dash = DashKind.DASH;
    d.add_item (c);
    var p = new PathShape ();
    var path = PathData.parse_svg ("M500 50 C550 0 600 100 650 50 L650 120");
    p.set_page_path (path);
    p.style.arrow_end = ArrowKind.TRIANGLE;
    d.add_item (p);
    var t = new TableShape (2, 3);
    t.x = 40;
    t.y = 300;
    t.w = 240;
    t.h = 60;
    t.set_cell (1, 2, "cell");
    d.add_item (t);
    var img = new ImageShape ();
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 8, 6);
    var cr = new Cairo.Context (surf);
    cr.set_source_rgb (1, 0, 0);
    cr.paint ();
    img.bytes = Export.png_bytes (surf);
    img.x = 700;
    img.y = 300;
    img.w = 80;
    img.h = 60;
    d.add_item (img);
    var g1 = new Shape ("ellipse", 500, 300, 60, 40);
    var g2 = new Shape ("diamond", 580, 300, 60, 40);
    d.add_item (g1);
    d.add_item (g2);
    d.group (new Gee.ArrayList<Item>.wrap ({ g1, g2 }));
    var l2 = new Layer ("layer2", "Notes");
    l2.locked = true;
    l2.printable = false;
    d.page.layers.add (l2);
    var note = new Shape ("note", 800, 40, 100, 80);
    note.layer_id = "layer2";
    note.text = "Hidden in print";
    d.add_item (note);
    note.layer_id = "layer2";
    var p2 = d.add_page (-1, "Second");
    p2.background = "#f0f0f0";
    d.page_index = 1;
    var s2 = new Shape ("star", 10, 10, 80, 80);
    d.add_item (s2);
    d.page_index = 0;
    Router.route_all (d.page);
    return d;
}

void test_native_roundtrip () throws Error {
    var d = rich ();
    string xml = NativeFormat.serialize_document (d);
    var e = NativeFormat.parse_document (xml);
    assert (e.pages.size == 2);
    assert (e.pages[1].name == "Second" && e.pages[1].background == "#f0f0f0");
    var p = e.pages[0];
    assert (p.items.size == d.pages[0].items.size);
    assert (p.layers.size == 2 && p.layers[1].locked && !p.layers[1].printable);
    var a = p.items[0] as Shape;
    var a0 = d.pages[0].items[0] as Shape;
    assert (a.kind == "process" && a.text == "Alpha & <beta>" && near (a.rotation, 30) && a.flip_v);
    assert (a.style.equals (a0.style));
    assert (a.get_field ("Owner") == "Ada" && a.link == "https://example.org" && a.name == "First");
    var c = p.items[2] as Connector;
    assert (c != null && c.src.item_id == a.id && c.src.port == 1 && c.text == "uses" && c.waypoints.length == 1);
    var ps = p.items[3] as PathShape;
    assert (ps != null && ps.path.segs.size == 3 && ps.path.segs[1].kind == SegKind.CURVE);
    var t = p.items[4] as TableShape;
    assert (t != null && t.rows == 2 && t.cols == 3 && t.get_cell (1, 2) == "cell");
    var img = p.items[5] as ImageShape;
    assert (img != null && img.bytes.length == (d.pages[0].items[5] as ImageShape).bytes.length);
    var g = p.items[6] as Group;
    assert (g != null && g.children.size == 2);
    assert (p.items[7].layer_id == "layer2");
    string items_xml = NativeFormat.serialize_items (new Gee.ArrayList<Item>.wrap ({ a, g }));
    var back = NativeFormat.parse_items (items_xml);
    assert (back.size == 2 && back[1] is Group);
    var fresh = e.clone_with_new_ids (back);
    assert (fresh[0].id != a.id);
}

void test_sniff () throws Error {
    assert (Formats.kind_for_path ("a.ODG") == FileKind.ODG);
    assert (Formats.kind_for_path ("a.vsdx") == FileKind.VSDX);
    assert (Formats.kind_for_path ("a.drawio") == FileKind.DRAWIO);
    assert (Formats.kind_for_path ("a.svg") == FileKind.SVG);
    assert (Formats.kind_for_path ("a.fodg") == FileKind.FODG);
    assert (Formats.sniff ("<mxfile><diagram/></mxfile>".data, "x.xml") == FileKind.DRAWIO);
    assert (Formats.sniff ("<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\"/>".data, "noext") == FileKind.SVG);
    assert (Formats.sniff ("<sdraw/>".data, "noext") == FileKind.NATIVE);
    var z = new ZipWriter ();
    z.add_text ("visio/document.xml", "<VisioDocument/>");
    assert (Formats.sniff (z.finish (), "file.bin") == FileKind.VSDX);
    var z2 = new ZipWriter ();
    z2.add_text ("mimetype", "application/vnd.oasis.opendocument.graphics", false);
    z2.add_text ("content.xml", "<x/>");
    assert (Formats.sniff (z2.finish (), "file.bin") == FileKind.ODG);
    string path = scratch ("native.sdraw");
    var d = rich ();
    Formats.save (d, path);
    var e = Formats.load (path);
    assert (e.path == path && !e.modified && e.pages.size == 2);
    var png = scratch ("pic.png");
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 50, 40);
    surf.write_to_png (png);
    var imgdoc = Formats.load (png);
    var im = imgdoc.page.items[0] as ImageShape;
    assert (im != null && near (im.w, 50) && near (im.h, 40) && imgdoc.path == null);
}

void test_svg_writer () throws Error {
    var d = rich ();
    string svg = SvgWriter.write_page (d.page, SvgWriter.page_area (d.page), true);
    FileUtils.set_contents (scratch ("rich.svg"), svg);
    Xml.Doc* x = XmlUtil.parse (svg);
    var root = x->get_root_element ();
    assert (root->name == "svg");
    assert (XmlUtil.attr (root, "viewBox") != null);
    int paths = 0, texts = 0, images = 0, grads = 0;
    count (root, ref paths, ref texts, ref images, ref grads);
    assert (paths > 10 && texts >= 4 && images == 1 && grads >= 1);
    delete x;
    assert (svg.contains ("Alpha &amp;") && svg.contains ("&lt;beta&gt;"));
    FileUtils.set_contents (scratch ("rich.svg"), svg);
    var only = new Gee.ArrayList<Item>.wrap ({ d.page.items[0] });
    string part = SvgWriter.write_page (d.page, SvgWriter.content_area (d.page, only), false, only);
    assert (!part.contains ("uses"));
}

void count (Xml.Node* n, ref int paths, ref int texts, ref int images, ref int grads) {
    for (Xml.Node* c = n->children; c != null; c = c->next) {
        if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
        if (c->name == "path") paths++;
        else if (c->name == "text") texts++;
        else if (c->name == "image") images++;
        else if (c->name == "linearGradient") grads++;
        count (c, ref paths, ref texts, ref images, ref grads);
    }
}

void test_png_pdf () throws Error {
    var d = rich ();
    string png = scratch ("rich.png");
    Export.png (d.page, png, Rect (0, 0, d.page.width, d.page.height), 1.0, false);
    var surf = new Cairo.ImageSurface.from_png (png);
    assert (surf.get_width () == (int) Math.ceil (d.page.width));
    string png2 = scratch ("rich2x.png");
    Export.png (d.page, png2, SvgWriter.content_area (d.page, null), 2.0, true);
    var s2 = new Cairo.ImageSurface.from_png (png2);
    assert (s2.get_width () > 1000);
    string pdf = scratch ("rich.pdf");
    Export.pdf (d, pdf, true);
    uint8[] data;
    FileUtils.get_data (pdf, out data);
    assert (data.length > 1000 && data[0] == '%' && data[1] == 'P' && data[2] == 'D' && data[3] == 'F');
    string single = scratch ("single.pdf");
    Export.pdf (d, single, false);
    uint8[] one;
    FileUtils.get_data (single, out one);
    assert (one.length > 500 && one.length < data.length);
}

void test_visual_sheets () throws Error {
    var lib = new Document ();
    int i = 0;
    foreach (var e in ShapeLibrary.entries ()) {
        double cx = 20 + (i % 20) * 180, cy = 20 + (i / 20) * 170;
        double sc = double.min (1, double.min (130 / e.w, 110 / double.max (e.h, 1)));
        var s = new Shape (e.kind, cx, cy, e.w * sc, double.max (e.h * sc, 1));
        ShapeLibrary.apply_defaults (s);
        string dt = ShapeLibrary.default_text (e.kind);
        s.text = dt != "" ? dt : e.name;
        s.style.font_size = 8;
        lib.add_item (s);
        i++;
    }
    lib.page.width = 3620;
    lib.page.height = 20 + ((i + 19) / 20) * 170;
    Export.png (lib.page, scratch ("library.png"), Rect (0, 0, lib.page.width, lib.page.height), 1.0, false);
    foreach (var info in Templates.list ()) {
        var d = Templates.build (info.id);
        Export.png (d.page, scratch ("tpl-" + info.id + ".png"), Rect (0, 0, d.page.width, d.page.height), 1.0, false);
    }
}

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    try {
        test_native_roundtrip ();
        test_sniff ();
        test_svg_writer ();
        test_png_pdf ();
        test_visual_sheets ();
    } catch (Error e) {
        printerr ("io: %s\n", e.message);
        return 1;
    }
    print ("io: all tests passed\n");
    return 0;
}
