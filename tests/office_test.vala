using Singularity.Apps.Draw;

int checks = 0;

void check (bool ok, string what) {
    checks++;
    if (!ok) {
        stderr.printf ("FAILED: %s\n", what);
        Process.exit (1);
    }
}

string tmp (string name) {
    return Path.build_filename (Environment.get_variable ("TMPDIR") ?? Environment.get_tmp_dir (), name);
}

Gee.ArrayList<TextRun> sample_runs () {
    var runs = new Gee.ArrayList<TextRun> ();
    runs.add (new TextRun ("Plain "));
    var red = new TextRun ("red serif");
    red.color = "#c62828";
    red.family = "Serif";
    runs.add (red);
    runs.add (new TextRun (" and "));
    var big = new TextRun ("big bold");
    big.size = 20;
    big.bold = true;
    runs.add (big);
    runs.add (new TextRun ("\nsecond "));
    var mono = new TextRun ("mono");
    mono.family = "Monospace";
    mono.italic = true;
    mono.underline = true;
    mono.color = "#1f4e79";
    runs.add (mono);
    return runs;
}

Shape rich_shape (Document d) {
    var s = new Shape ("rectangle", 40, 40, 360, 120);
    var runs = sample_runs ();
    s.text = RichRuns.plain_text (runs);
    s.markup = RichRuns.to_markup (runs);
    s.style.font_family = "Sans";
    s.style.font_size = 12;
    d.add_item (s);
    return s;
}

TextRun? run_with (Gee.List<TextRun> runs, string text) {
    foreach (var r in runs) if (r.text.contains (text)) return r;
    return null;
}

void check_runs (Item it, string where) {
    check (it.has_rich_text (), where + ": rich text kept");
    var runs = it.rich_runs ();
    check (runs != null, where + ": runs parse");
    var red = run_with (runs, "red serif");
    check (red != null && red.color.down () == "#c62828" && red.family == "Serif", where + ": colour and font of run");
    var big = run_with (runs, "big bold");
    check (big != null && big.bold && Math.fabs (big.size - 20) < 0.05, where + ": size and bold of run");
    var mono = run_with (runs, "mono");
    check (mono != null && mono.family == "Monospace" && mono.italic && mono.underline && mono.color.down () == "#1f4e79", where + ": second line run");
    var plain = run_with (runs, "Plain");
    check (plain != null && plain.is_plain (), where + ": plain run stays plain");
}

Item? find_text (Page p, string prefix) {
    foreach (var it in p.items) {
        if (it.text.has_prefix (prefix)) return it;
        var g = it as Group;
        if (g != null) foreach (var c in g.children) if (c.text.has_prefix (prefix)) return c;
    }
    return null;
}

void test_rich_model () {
    var runs = sample_runs ();
    string m = RichRuns.to_markup (runs);
    var back = RichRuns.parse (m);
    check (RichRuns.plain_text (back) == RichRuns.plain_text (runs), "markup keeps text");
    check (back.size == runs.size, "markup keeps run count");
    for (int i = 0; i < runs.size; i++) check (back[i].same_format (runs[i]), "markup keeps run %d".printf (i));
    var lines = RichRuns.split_lines (runs);
    check (lines.size == 2 && lines[1].size == 2 && lines[1][1].text == "mono", "split lines");
    var sl = RichRuns.slice (runs, 3, 8);
    check (RichRuns.plain_text (sl) == "in red s" && sl.size == 2, "slice");
    var legacy = RichRuns.parse ("<b>A</b>B");
    check (legacy.size == 2 && legacy[0].bold && legacy[1].is_plain (), "legacy markup");
}

void test_rich_render () {
    var d = new Document ();
    var s = rich_shape (d);
    s.style.fill = "#ffffff";
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 440, 200);
    var cr = new Cairo.Context (surf);
    cr.set_source_rgb (1, 1, 1);
    cr.paint ();
    Renderer.draw_page (cr, d.page, new RenderOptions ());
    surf.flush ();
    unowned uchar[] px = surf.get_data ();
    int stride = surf.get_stride ();
    int reds = 0, blues = 0;
    for (int y = 0; y < 200; y++) for (int x = 0; x < 440; x++) {
        int o = y * stride + x * 4;
        int b = px[o], g = px[o + 1], r = px[o + 2];
        if (r > 150 && g < 90 && b < 90) reds++;
        if (b > 90 && r < 70 && g < 110 && b > r + 40) blues++;
    }
    surf.write_to_png (tmp ("rich-render.png"));
    check (reds > 20, "red run drawn in red (%d px)".printf (reds));
    check (blues > 10, "blue run drawn in blue (%d px)".printf (blues));
}

void test_rich_formats () throws Error {
    var d = new Document ();
    rich_shape (d);
    var native = NativeFormat.parse_document (NativeFormat.serialize_document (d));
    check_runs (find_text (native.page, "Plain"), "native");

    var odg = Odg.load (Odg.save (d));
    check_runs (find_text (odg.page, "Plain"), "odg");
    string flat = Odg.save_flat (d);
    check (flat.contains ("<text:span text:style-name=\"T"), "odg writes text spans");
    check (flat.contains ("fo:color=\"#c62828\""), "odg span colour");
    var stripped = flat.replace (" sdraw:markup=", " sdraw:unused=");
    int k = stripped.index_of (" sdraw:style=\"");
    while (k >= 0) {
        int e = stripped.index_of ("\"", k + 14);
        stripped = stripped.substring (0, k) + stripped.substring (e + 1);
        k = stripped.index_of (" sdraw:style=\"");
    }
    var foreign = Odg.load_flat (stripped);
    check_runs (find_text (foreign.page, "Plain"), "odg spans without native data");

    uint8[] vdata = Vsdx.save (d);
    var vsdx = Vsdx.load (vdata);
    check_runs (find_text (vsdx.page, "Plain"), "vsdx");
    var zr = new ZipReader (vdata);
    var zw = new ZipWriter ();
    foreach (string name in zr.names ()) {
        uint8[] part = zr.read (name);
        if (name == "visio/pages/page1.xml") {
            string xml = (string) part;
            int a = xml.index_of ("<Section N=\"User\">");
            while (a >= 0) {
                int b = xml.index_of ("</Section>", a);
                xml = xml.substring (0, a) + xml.substring (b + 10);
                a = xml.index_of ("<Section N=\"User\">");
            }
            check (xml.contains ("<cp IX=\"1\"/>"), "vsdx text has character runs");
            zw.add_text (name, xml);
        } else {
            zw.add (name, part);
        }
    }
    var fv = Vsdx.load (zw.finish ());
    check_runs (find_text (fv.page, "Plain"), "vsdx without native data");

    string svg = SvgWriter.write_page (d.page, SvgWriter.page_area (d.page), false);
    check (svg.contains ("fill=\"#c62828\"") && svg.contains ("font-family=\"Serif\""), "svg tspans carry run style");
    var sd = SvgReader.load (svg);
    var first = find_text (sd.page, "Plain");
    check (first != null, "svg text found");
    var runs = first.rich_runs ();
    check (runs != null, "svg runs read");
    var red = run_with (runs, "red serif");
    check (red != null && red.color.down () == "#c62828" && red.family == "Serif", "svg colour and font");
    var big = run_with (runs, "big bold");
    check (big != null && big.bold && Math.fabs (big.size - 20) < 0.1, "svg size and bold");
}


uint8[] tiny_png () {
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 8, 6);
    var cr = new Cairo.Context (surf);
    cr.set_source_rgb (0.2, 0.5, 0.9);
    cr.paint ();
    return Export.png_bytes (surf);
}

string part_text (ZipReader z, string name) throws Error {
    uint8[] d = z.read (name);
    var b = new ByteArray ();
    b.append (d);
    b.append ({ 0 });
    return (string) b.data;
}

void test_pptx () throws Error {
    var d = new Document ();
    var a = rich_shape (d);
    var e = new Shape ("ellipse", 520, 60, 160, 90);
    ShapeLibrary.apply_defaults (e);
    e.text = "Ellipse";
    e.style.fill_kind = FillKind.LINEAR;
    e.style.fill = "#f5c518";
    e.style.fill2 = "#c62828";
    e.rotation = 30;
    d.add_item (e);
    var c = new Connector ();
    c.route = RouteKind.STRAIGHT;
    c.src.item_id = a.id;
    c.dst.item_id = e.id;
    c.style.arrow_end = ArrowKind.TRIANGLE;
    c.text = "flows";
    d.add_item (c);
    var t = new TableShape (2, 2);
    t.x = 60;
    t.y = 320;
    t.w = 240;
    t.h = 80;
    t.set_cell (0, 0, "Name");
    t.set_cell (1, 1, "42");
    d.add_item (t);
    var img = new ImageShape ();
    img.bytes = tiny_png ();
    img.mime = "image/png";
    img.x = 420;
    img.y = 320;
    img.w = 80;
    img.h = 60;
    d.add_item (img);
    var gantt = GanttShape.sample ();
    gantt.x = 600;
    gantt.y = 400;
    d.add_item (gantt);
    Router.route_all (d.page);
    var p2 = d.add_page (-1, "Second");
    var on2 = new Shape ("rectangle", 100, 100, 200, 100);
    on2.text = "Second page";
    p2.items.add (on2);
    d.page_index = 0;
    var data = Pptx.save (d);
    FileUtils.set_data (tmp ("office-pages.pptx"), data);
    var z = new ZipReader (data);
    string ct = part_text (z, "[Content_Types].xml");
    check (ct.contains ("/ppt/slides/slide2.xml") && !ct.contains ("/ppt/slides/slide3.xml"), "one slide per page");
    foreach (string name in z.names ()) {
        if (!name.has_suffix (".rels")) continue;
        string rels = part_text (z, name);
        string dir = Path.get_dirname (Path.get_dirname (name));
        int i = rels.index_of ("Target=\"");
        while (i >= 0) {
            int e2 = rels.index_of ("\"", i + 8);
            string target = rels.substring (i + 8, e2 - i - 8);
            string full = dir == "." ? target : Path.build_filename (dir, target);
            var parts = new Gee.ArrayList<string> ();
            foreach (string seg in full.split ("/")) {
                if (seg == "..") parts.remove_at (parts.size - 1);
                else if (seg != "" && seg != ".") parts.add (seg);
            }
            string resolved = string.joinv ("/", parts.to_array ());
            check (z.has (resolved), "relationship target %s from %s exists".printf (resolved, name));
            i = rels.index_of ("Target=\"", e2);
        }
    }
    int k = ct.index_of ("PartName=\"/");
    while (k >= 0) {
        int e3 = ct.index_of ("\"", k + 11);
        string pn = ct.substring (k + 11, e3 - k - 11);
        check (z.has (pn), "content type part %s exists".printf (pn));
        k = ct.index_of ("PartName=\"/", e3);
    }
    string s1 = part_text (z, "ppt/slides/slide1.xml");
    check (s1.contains ("<a:custGeom>") && s1.contains ("<a:cubicBezTo>"), "native geometry with curves");
    check (s1.contains ("<a:t>red serif</a:t>") && s1.contains ("<a:srgbClr val=\"C62828\"/>") && s1.contains ("typeface=\"Cambria\""), "rich runs become DrawingML runs");
    check (s1.contains ("<a:gradFill") && s1.contains ("rot=\"1800000\""), "gradient and rotation");
    check (s1.contains ("<p:cxnSp>") && s1.contains ("<a:tailEnd type=\"triangle\""), "connector with arrow");
    check (s1.contains ("<a:t>flows</a:t>"), "connector label");
    check (s1.contains ("<a:tbl>") && s1.contains ("<a:t>Name</a:t>") && s1.contains ("<a:gridCol"), "native table");
    check (s1.contains ("<p:pic>") && z.has ("ppt/media/image1.png"), "picture for image");
    check (z.has ("ppt/media/image2.png"), "picture fallback for gantt");
    string s2 = part_text (z, "ppt/slides/slide2.xml");
    check (s2.contains ("<a:t>Second page</a:t>"), "second slide content");
    var xs = Xml.Parser.read_memory (s1, s1.length);
    check (xs != null, "slide xml is well formed");
    delete xs;

    d.page.snippets.add (new Snippet ("Left part", Rect (20, 20, 420, 200)));
    d.page.snippets.add (new Snippet ("Table", Rect (40, 300, 300, 120)));
    var slides = Pptx.slides_for (d);
    check (slides.size == 2 && slides[0].name == "Left part", "snippets drive slides");
    var sd = Pptx.save (d, slides);
    FileUtils.set_data (tmp ("office-snippets.pptx"), sd);
    var z2 = new ZipReader (sd);
    string f1 = part_text (z2, "ppt/slides/slide1.xml");
    string f2 = part_text (z2, "ppt/slides/slide2.xml");
    check (f1.contains ("name=\"Left part\"") && f1.contains ("<a:t>red serif</a:t>") && !f1.contains ("<a:tbl>"), "first snippet holds only its region");
    check (f2.contains ("<a:tbl>") && !f2.contains ("red serif"), "second snippet holds the table");
    var back = NativeFormat.parse_document (NativeFormat.serialize_document (d));
    check (back.page.snippets.size == 2 && back.page.snippets[1].name == "Table" && back.page.snippets[1].area.w == 300, "snippets saved in native format");
}


string json_str (string v) {
    var node = new Json.Node (Json.NodeType.VALUE);
    node.set_string (v);
    return Json.to_string (node, false);
}

void test_stencil_import () throws Error {
    string raw = "<mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/><mxCell id=\"2\" value=\"Pump\" style=\"ellipse;fillColor=#dae8fc;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"0\" y=\"0\" width=\"60\" height=\"60\" as=\"geometry\"/></mxCell></root></mxGraphModel>";
    string two = "<mxGraphModel><root><mxCell id=\"0\"/><mxCell id=\"1\" parent=\"0\"/><mxCell id=\"2\" value=\"Tank\" style=\"rounded=1;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"10\" y=\"10\" width=\"80\" height=\"40\" as=\"geometry\"/></mxCell><mxCell id=\"3\" value=\"\" style=\"rhombus;\" vertex=\"1\" parent=\"1\"><mxGeometry x=\"100\" y=\"10\" width=\"40\" height=\"40\" as=\"geometry\"/></mxCell></root></mxGraphModel>";
    string svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"40\" height=\"40\"><circle cx=\"20\" cy=\"20\" r=\"18\" fill=\"#e5534b\"/></svg>";
    string svg_uri = "data:image/svg+xml;base64," + Base64.encode (svg.data);
    string png_uri = "data:image/png;base64," + Base64.encode (tiny_png ());
    string json = "[{\"xml\":%s,\"w\":60,\"h\":60,\"title\":\"Pump\"},{\"xml\":%s,\"w\":130,\"h\":40,\"title\":\"Tank and Valve\"},{\"data\":%s,\"w\":40,\"h\":40,\"title\":\"Red Dot\"},{\"data\":%s,\"w\":16,\"h\":12,\"title\":\"Bitmap\"}]".printf (
        json_str (raw), json_str (Drawio.deflate (two)), json_str (svg_uri), json_str (png_uri));
    string lib = "<mxlibrary>" + json.replace ("&", "&amp;").replace ("<", "&lt;").replace (">", "&gt;") + "</mxlibrary>";
    check (StencilImport.is_mxlibrary (lib.data), "mxlibrary detected");
    var st = StencilImport.load (lib.data, "library.xml");
    check (st.masters.size == 4, "four masters from the library (%d)".printf (st.masters.size));
    check (st.masters[0].name == "Pump" && st.masters[0].items ().size == 1 && st.masters[0].items ()[0].text == "Pump", "raw xml entry");
    check (st.masters[1].items ().size == 2, "compressed xml entry keeps both cells");
    check (st.masters[2].items ().size >= 1, "svg data entry");
    check (st.masters[3].items ()[0] is ImageShape, "bitmap data entry");
    string dir = tmp ("svgset");
    DirUtils.create_with_parents (dir, 0755);
    string[] files = {};
    for (int i = 0; i < 3; i++) {
        string f = Path.build_filename (dir, "icon_%d.svg".printf (i));
        FileUtils.set_contents (f, svg.replace ("#e5534b", i == 0 ? "#3a6ea5" : (i == 1 ? "#6fbf5a" : "#f5c518")));
        files += f;
    }
    var set = StencilImport.from_svg_files (files, "svgset");
    check (set.masters.size == 3 && set.masters[1].name == "icon 1", "svg folder becomes a stencil");
    check (ShapeLibrary.entries ().size >= 2000, "built-in library holds %d shapes".printf (ShapeLibrary.entries ().size));
    int cats = ShapeLibrary.categories ().size;
    check (cats >= 60, "built-in library has %d stencils".printf (cats));
}

int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/office/rich-model", test_rich_model);
    Test.add_func ("/office/rich-render", test_rich_render);
    Test.add_func ("/office/rich-formats", () => {
        try {
            test_rich_formats ();
        } catch (Error e) {
            check (false, e.message);
        }
    });
    Test.add_func ("/office/pptx", () => {
        try {
            test_pptx ();
        } catch (Error e) {
            check (false, e.message);
        }
    });
    Test.add_func ("/office/stencil-import", () => {
        try {
            test_stencil_import ();
        } catch (Error e) {
            check (false, e.message);
        }
    });
    int r = Test.run ();
    print ("%d checks\n", checks);
    return r;
}
