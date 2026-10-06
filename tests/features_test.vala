using Singularity.Apps.Draw;

string tmp (string name) {
    return Path.build_filename (Environment.get_tmp_dir (), name);
}

Shape shape (Document d, string kind, double x, double y, string text = "") {
    var e = ShapeLibrary.find (kind);
    var s = new Shape (kind, x, y, e != null ? e.w : 120, e != null ? e.h : 60);
    ShapeLibrary.apply_defaults (s);
    s.text = text;
    d.add_item (s);
    return s;
}

Connector join_items (Document d, Item a, Item b, string text = "") {
    var c = new Connector ();
    c.src.item_id = a.id;
    c.dst.item_id = b.id;
    c.text = text;
    d.add_item (c);
    return c;
}

void test_jumps () {
    var d = new Document ();
    var a = new Connector ();
    a.route = RouteKind.STRAIGHT;
    a.src.x = 0;
    a.src.y = 100;
    a.dst.x = 400;
    a.dst.y = 100;
    d.add_item (a);
    var b = new Connector ();
    b.route = RouteKind.STRAIGHT;
    b.src.x = 200;
    b.src.y = 0;
    b.dst.x = 200;
    b.dst.y = 300;
    d.add_item (b);
    Router.route_all (d.page);
    var jm = LineJumps.compute (d.page);
    assert (jm.total () == 1);
    assert (jm.get_jumps (a) != null && jm.get_jumps (a).size == 1);
    var p = LineJumps.jumped_path (a, jm.get_jumps (a), JumpStyle.ARC, 6);
    bool curve = false;
    foreach (var seg in p.segs) if (seg.kind == SegKind.CURVE) curve = true;
    assert (curve);
    var gap = LineJumps.jumped_path (a, jm.get_jumps (a), JumpStyle.GAP, 6);
    int moves = 0;
    foreach (var seg in gap.segs) if (seg.kind == SegKind.MOVE) moves++;
    assert (moves == 2);
    d.page.jumps_vertical = true;
    jm = LineJumps.compute (d.page);
    assert (jm.get_jumps (b) != null && jm.get_jumps (b).size == 1);
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 400, 300);
    var cr = new Cairo.Context (surf);
    cr.set_source_rgb (1, 1, 1);
    cr.paint ();
    d.page.jumps_vertical = false;
    Renderer.draw_page (cr, d.page, new RenderOptions ());
    surf.write_to_png (tmp ("feature-jumps.png"));
}

void test_validation () {
    var d = new Document ();
    var start = shape (d, "terminator", 0, 0, "Start");
    var dec = shape (d, "decision", 0, 100, "Ok?");
    var step = shape (d, "process", 0, 250, "");
    var lonely = shape (d, "process", 400, 400, "Alone");
    join_items (d, start, dec);
    join_items (d, dec, step);
    var dangling = new Connector ();
    dangling.src.item_id = step.id;
    dangling.dst.x = 500;
    dangling.dst.y = 500;
    d.add_item (dangling);
    Router.route_all (d.page);
    var issues = Validator.run (d);
    var rules = new Gee.HashSet<string> ();
    foreach (var i in issues) rules.add (i.rule);
    assert (rules.contains ("flow-decision-branches"));
    assert (rules.contains ("flow-unconnected"));
    assert (rules.contains ("flow-no-text"));
    assert (rules.contains ("dangling-connector"));
    d.ignored_issues.add ("rule:flow-unconnected");
    foreach (var i in Validator.run (d)) assert (i.rule != "flow-unconnected");
    if (lonely.id == "") assert_not_reached ();

    var b = new Document ();
    var s = shape (b, "bpmn-start", 0, 0);
    var t = shape (b, "bpmn-task", 100, 0, "Work");
    var e = shape (b, "bpmn-end", 300, 0);
    join_items (b, t, s);
    join_items (b, t, e);
    var gw = shape (b, "bpmn-gateway", 200, 200);
    join_items (b, t, gw);
    join_items (b, gw, e);
    var br = new Gee.HashSet<string> ();
    foreach (var i in Validator.run (b)) br.add (i.rule);
    assert (br.contains ("bpmn-start-incoming"));
    assert (br.contains ("bpmn-gateway-useless"));
    assert (Validator.detect (b).contains ("bpmn"));

    var u = new Document ();
    var c1 = shape (u, "uml-class", 0, 0, "Shape");
    var c2 = shape (u, "uml-class", 300, 0, "Shape");
    var g1 = join_items (u, c1, c2);
    g1.style.arrow_end = ArrowKind.TRIANGLE_OPEN;
    var g2 = join_items (u, c2, c1);
    g2.style.arrow_end = ArrowKind.TRIANGLE_OPEN;
    var ur = new Gee.HashSet<string> ();
    foreach (var i in Validator.run (u)) ur.add (i.rule);
    assert (ur.contains ("uml-duplicate-class"));
    assert (ur.contains ("uml-generalization-cycle"));
}

void test_swimlanes () {
    var d = new Document ();
    var pool = Swimlanes.insert (d, 0, 0, false, 3, "Process");
    var lanes = Swimlanes.lanes (d.page, pool);
    assert (lanes.size == 3);
    double h0 = pool.h;
    var step = shape (d, "process", lanes[1].x + 40, lanes[1].y + 30, "Step");
    d.assign_container (step);
    assert (step.container_id == lanes[1].id);
    double y_before = step.y;
    Swimlanes.add_lane (d, pool, 1, "New");
    lanes = Swimlanes.lanes (d.page, pool);
    assert (lanes.size == 4);
    assert (lanes[1].text == "New");
    assert (pool.h > h0);
    assert (step.y > y_before);
    Swimlanes.move_lane (d, lanes[1], 1);
    lanes = Swimlanes.lanes (d.page, pool);
    assert (lanes[2].text == "New");
    Swimlanes.remove_lane (d, lanes[2]);
    assert (Swimlanes.lanes (d.page, pool).size == 3);
    var ph = Swimlanes.add_phase (d, pool, "Later");
    assert (Swimlanes.phases (d.page, pool).size == 2);
    assert (ph.h == pool.h);
    Swimlanes.set_orientation (d, pool, true);
    assert (pool.kind == "pool-v");
    foreach (var l in Swimlanes.lanes (d.page, pool)) assert (l.kind == "swimlane-v");
}

void write_xlsx (string path) throws Error {
    var z = new ZipWriter ();
    z.add_text ("[Content_Types].xml", "<?xml version=\"1.0\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"/>");
    z.add_text ("xl/workbook.xml", "<?xml version=\"1.0\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets><sheet name=\"Staff\" sheetId=\"1\" r:id=\"rId1\"/></sheets></workbook>");
    z.add_text ("xl/_rels/workbook.xml.rels", "<?xml version=\"1.0\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"worksheet\" Target=\"worksheets/sheet1.xml\"/></Relationships>");
    z.add_text ("xl/sharedStrings.xml", "<?xml version=\"1.0\"?><sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><si><t>Name</t></si><si><t>Load</t></si><si><t>Web</t></si><si><t>Db</t></si></sst>");
    z.add_text ("xl/worksheets/sheet1.xml", "<?xml version=\"1.0\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetData><row r=\"1\"><c r=\"A1\" t=\"s\"><v>0</v></c><c r=\"B1\" t=\"s\"><v>1</v></c></row><row r=\"2\"><c r=\"A2\" t=\"s\"><v>2</v></c><c r=\"B2\"><v>80</v></c></row><row r=\"3\"><c r=\"A3\" t=\"s\"><v>3</v></c><c r=\"B3\"><v>35</v></c></row></sheetData></worksheet>");
    Formats.write_atomic (path, z.finish ());
}

void write_ods (string path) throws Error {
    var z = new ZipWriter ();
    z.add_text ("mimetype", "application/vnd.oasis.opendocument.spreadsheet", false);
    z.add_text ("content.xml", "<?xml version=\"1.0\"?><office:document-content xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" xmlns:table=\"urn:oasis:names:tc:opendocument:xmlns:table:1.0\" xmlns:text=\"urn:oasis:names:tc:opendocument:xmlns:text:1.0\"><office:body><office:spreadsheet><table:table table:name=\"Sheet1\"><table:table-row><table:table-cell><text:p>Name</text:p></table:table-cell><table:table-cell><text:p>Load</text:p></table:table-cell></table:table-row><table:table-row><table:table-cell><text:p>Web</text:p></table:table-cell><table:table-cell office:value=\"42\"><text:p>42</text:p></table:table-cell></table:table-row></table:table></office:spreadsheet></office:body></office:document-content>");
    Formats.write_atomic (path, z.finish ());
}

void test_data_sources () {
    try {
        string csv = tmp ("feature-data.csv");
        FileUtils.set_contents (csv, "Name,Load,Owner\nWeb,80,Ops\nDb,35,Data\n");
        var d = new Document ();
        var web = shape (d, "process", 0, 0, "Web");
        var db = shape (d, "process", 200, 0, "Db");
        var src = new DataSource ();
        src.id = "ds1";
        src.kind = DataSources.kind_for_path (csv);
        src.path = csv;
        src.name = "data.csv";
        src.key_column = "Name";
        src.table = DataSources.load (src);
        d.data_sources.add (src);
        assert (DataSources.auto_link (d.page, src) == 2);
        assert (web.get_field ("Load") == "80");
        assert (web.data_source == "ds1" && web.data_key == "Web");
        FileUtils.set_contents (csv, "Name,Load,Owner\nWeb,95,Ops\nCache,10,Ops\n");
        var r = DataSources.refresh (d, src);
        assert (r.updated == 1);
        assert (r.missing == 1);
        assert (web.get_field ("Load") == "95");
        if (db.id == "") assert_not_reached ();

        string xlsx = tmp ("feature-data.xlsx");
        write_xlsx (xlsx);
        var sheets = DataSources.sheets (xlsx);
        assert (sheets.length == 1 && sheets[0] == "Staff");
        var xt = DataSources.read_xlsx (xlsx, "Staff");
        assert (xt.header.size == 2 && xt.header[1] == "Load");
        assert (xt.rows.size == 2 && xt.cell (xt.rows[1], 0) == "Db" && xt.cell (xt.rows[1], 1) == "35");

        string ods = tmp ("feature-data.ods");
        write_ods (ods);
        var ot = DataSources.read_ods (ods, "");
        assert (ot.rows.size == 1 && ot.cell (ot.rows[0], 1) == "42");

        string dbp = tmp ("feature-data.db");
        FileUtils.remove (dbp);
        Sqlite.Database sdb;
        assert (Sqlite.Database.open (dbp, out sdb) == Sqlite.OK);
        assert (sdb.exec ("CREATE TABLE servers (name TEXT, load INTEGER); INSERT INTO servers VALUES ('Web', 70), ('Db', 20);") == Sqlite.OK);
        var st = DataSources.read_sqlite (dbp, "SELECT name, load FROM servers ORDER BY name");
        assert (st.header[0] == "name" && st.rows.size == 2 && st.cell (st.rows[0], 0) == "Db");
        assert (DataSources.sheets (dbp)[0] == "servers");

        var proc = new DataSource ();
        proc.id = "ds2";
        proc.name = "steps";
        proc.table = CsvTable.parse ("ID,Description,Next Step ID,Shape Type,Function\n1,Start,2,Start,Sales\n2,Check,3,Decision,Ops\n3,Ship,,Process,Ops\n");
        var pd = new Document ();
        pd.data_sources.add (proc);
        var m = DataSources.ProcessMap.guess (proc.table);
        var items = DataSources.build_process (pd, proc, m, 0, 0);
        int shapes = 0, conns = 0;
        foreach (var it in items) {
            if (it is Connector) conns++;
            else if (it.data_source == "ds2") shapes++;
        }
        assert (shapes == 3 && conns == 2);
        proc.table = CsvTable.parse ("ID,Description,Next Step ID,Shape Type,Function\n1,Start,2,Start,Sales\n2,Check again,4,Decision,Ops\n4,Deliver,,Process,Ops\n");
        string proc_csv = tmp ("feature-proc.csv");
        FileUtils.set_contents (proc_csv, DataImport.to_csv_table (proc.table));
        proc.path = proc_csv;
        proc.kind = "csv";
        var pr = DataSources.refresh (pd, proc);
        assert (pr.added == 1 && pr.removed == 1);
        bool found = false;
        foreach (var it in pd.page.all_items ()) if (it.text == "Check again") found = true;
        assert (found);
    } catch (Error e) {
        error ("data: %s", e.message);
    }
}

void test_graphics () {
    var d = new Document ();
    var s = shape (d, "process", 20, 20, "Web");
    s.set_field ("Load", "80");
    s.set_field ("State", "Down");
    var g = new DataGraphic ();
    g.id = "dg1";
    g.name = "Health";
    var bar = new DataGraphicItem ();
    bar.field = "Load";
    bar.kind = "bar";
    g.items.add (bar);
    var icon = new DataGraphicItem ();
    icon.field = "Load";
    icon.kind = "icon";
    g.items.add (icon);
    var color = new DataGraphicItem ();
    color.field = "State";
    color.kind = "color";
    var rule = new DataGraphicRule ();
    rule.op = "=";
    rule.value = "down";
    rule.color = "#e5534b";
    color.rules.add (rule);
    g.items.add (color);
    d.data_graphics.add (g);
    s.data_graphic = "dg1";
    d.link_backgrounds ();
    assert (DataGraphics.fill_override (d.page, s) == "#e5534b");
    assert (DataGraphics.icon_index (icon, "80") == 2);
    assert (DataGraphics.icon_index (icon, "10") == 0);
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 220, 160);
    var cr = new Cairo.Context (surf);
    Renderer.draw_page (cr, d.page, new RenderOptions ());
    surf.flush ();
    unowned uchar[] px = surf.get_data ();
    int stride = surf.get_stride ();
    int off = (int) (s.cy ()) * stride + (int) (s.x + 10) * 4;
    assert (px[off + 2] > 200 && px[off + 1] < 120);
    surf.write_to_png (tmp ("feature-graphics.png"));
    string xml = NativeFormat.serialize_document (d);
    var back = NativeFormat.parse_document (xml);
    assert (back.data_graphics.size == 1 && back.data_graphics[0].items.size == 3);
    assert (back.page.items[0].data_graphic == "dg1");
}

void test_native_roundtrip () {
    var d = new Document ();
    var a = shape (d, "process", 0, 0, "A");
    a.markup = "<b>A</b>";
    a.alt_title = "Alt title";
    a.alt_text = "Longer description";
    a.custom_ports = { Point (0.25, 0), Point (1, 0.75) };
    var callout = shape (d, "rectangle", 200, 0, "Note");
    callout.callout_target = a.id;
    var c = Comment.create ("Looks good");
    c.id = "c1";
    c.item_id = a.id;
    c.replies.add (Comment.create ("Thanks"));
    d.page.comments.add (c);
    d.page.guides.add (new PageGuide (true, 120));
    d.page.scale_units = "m";
    d.page.scale_world = 1;
    d.page.scale_paper = 1;
    d.page.jump_style = JumpStyle.GAP;
    d.page.print_tiles_x = 2;
    d.page.print_tiles_y = 3;
    var bg = d.add_page (-1, "Letterhead");
    bg.is_background = true;
    d.page.back_page = bg.id;
    d.theme_id = "harbor";
    d.theme_variant = 2;
    var g = GanttShape.sample ();
    d.add_item (g);
    var back = NativeFormat.parse_document (NativeFormat.serialize_document (d));
    var p = back.pages[0];
    var ra = p.find (a.id) as Shape;
    assert (ra.alt_title == "Alt title" && ra.alt_text == "Longer description");
    assert (ra.markup == "<b>A</b>" && ra.has_rich_text ());
    ra.text = "B";
    assert (!ra.has_rich_text ());
    assert (ra.custom_ports != null && ra.custom_ports.length == 2 && ra.ports ()[1].y == 0.75);
    assert ((p.find (callout.id) as Shape).callout_target == a.id);
    assert (p.comments.size == 1 && p.comments[0].replies.size == 1 && p.comments[0].text == "Looks good");
    assert (p.guides.size == 1 && p.guides[0].vertical && p.guides[0].pos == 120);
    assert (p.has_scale () && p.jump_style == JumpStyle.GAP && p.print_tiles_y == 3);
    assert (back.pages[1].is_background && p.back_page == back.pages[1].id);
    assert (back.theme_id == "harbor" && back.theme_variant == 2);
    GanttShape? rg = null;
    foreach (var it in p.items) if (it is GanttShape) rg = (GanttShape) it;
    assert (rg != null && rg.tasks.size == g.tasks.size && rg.tasks[2].depends == g.tasks[2].depends);
}

void test_background_render () {
    var d = new Document ();
    d.page.width = 200;
    d.page.height = 100;
    var bg = d.add_page (-1, "Background");
    bg.is_background = true;
    d.page.back_page = bg.id;
    var r = new Shape ("rectangle", 0, 0, 200, 100);
    r.style.fill = "#ff0000";
    r.style.stroke = "none";
    bg.items.add (r);
    d.link_backgrounds ();
    var surf = Export.render_area (d.page, Rect (0, 0, 200, 100), 1, false);
    unowned uchar[] px = surf.get_data ();
    int off = 50 * surf.get_stride () + 100 * 4;
    assert (px[off + 2] > 240 && px[off + 1] < 20);
    string svg = SvgWriter.write_page (d.page, SvgWriter.page_area (d.page), true);
    assert (svg.contains ("#ff0000"));
    Export.pdf (d, tmp ("feature-bg.pdf"), true);
    uint8[] pdf;
    FileUtils.get_data (tmp ("feature-bg.pdf"), out pdf);
    assert (pdf.length > 200 && pdf[0] == '%');
    assert (d.foreground_pages ().size == 1);
}

void test_theme () {
    var d = new Document ();
    var s = shape (d, "process", 0, 0, "A");
    d.theme_id = "ember";
    Theme.style_new_item (d, s);
    var t = Theme.find ("ember");
    assert (s.style.quick_color == 1);
    assert (s.style.fill == t.accents[0]);
    s.style.quick_style = QuickStyle.SUBTLE;
    d.theme_variant = 1;
    Theme.apply_document (d);
    assert (s.style.stroke == t.variant (1).accents[0]);
    var dark = t.variant (3);
    assert (Colors.luminance (dark.background) < 0.3);
}

void test_shape_ops () {
    var a = new Shape ("rectangle", 0, 0, 100, 100);
    var b = new Shape ("rectangle", 50, 0, 100, 100);
    var list = new Gee.ArrayList<Shape> ();
    list.add (a);
    list.add (b);
    var frags = ShapeOps.fragment (list);
    assert (frags.size == 3);
    double total = 0;
    foreach (var f in frags) total += PathBoolean.area (f).abs ();
    assert ((total - 15000).abs () < 50);
    var comb = ShapeOps.combine (list);
    assert ((PathBoolean.area (comb).abs () - 10000).abs () < 100);
    var off = ShapeOps.offset (a, 10);
    var ob = off.bounds ();
    assert ((ob.w - 120).abs () < 1 && (ob.x + 10).abs () < 1);
    var inner = ShapeOps.offset (a, -10);
    assert ((inner.bounds ().w - 80).abs () < 1);
    var line = new PathShape ();
    var lp = new PathData ();
    lp.move_to (-20, 50);
    lp.line_to (170, 50);
    line.set_page_path (lp);
    var tl = new Gee.ArrayList<Shape> ();
    tl.add (line);
    tl.add (a);
    int open = 0;
    foreach (var p in ShapeOps.trim (tl)) if (!p.has_closed_subpath ()) open++;
    assert (open == 3);
}

void test_report_merge_html () {
    var d = new Document ();
    var a = shape (d, "process", 0, 0, "A");
    a.set_field ("Cost", "10");
    a.set_field ("Team", "X");
    var b = shape (d, "process", 200, 0, "B");
    b.set_field ("Cost", "30");
    b.set_field ("Team", "X");
    var fields = new Gee.ArrayList<string> ();
    fields.add ("Cost");
    var rep = ShapeReport.build (d.page.all_items (), true, false, fields, "Team", true);
    assert (rep.rows.size == 5);
    assert (rep.rows[2][2] == "40");
    assert (rep.to_html ().contains ("<table>"));
    assert (rep.to_table ().rows == 6);

    var other = NativeFormat.parse_document (NativeFormat.serialize_document (d));
    (other.page.find (a.id)).text = "A changed";
    var added = new Shape ("ellipse", 400, 0, 50, 50);
    added.id = "zz1";
    other.page.items.add (added);
    var res = DrawingMerge.compare (d, other);
    assert (res.added == 1 && res.changed == 1);
    DrawingMerge.apply (d, other, res);
    assert (d.page.find (a.id).text == "A changed");
    assert (d.page.find ("zz1") != null);

    d.page.find (a.id).link = "https://example.org";
    b.link = "page:Page 1";
    b.alt_title = "Box B";
    string html = HtmlExport.write (d);
    assert (html.contains ("<!DOCTYPE html>"));
    assert (html.contains ("href=\"https://example.org\""));
    assert (html.contains ("data-page=\"Page 1\""));
    assert (html.contains ("<title>Box B</title>"));
    assert (html.contains ("\"Cost\":\"30\""));
    FileUtils.set_contents (tmp ("feature-export.html"), html);
}

void test_user_stencils () {
    UserStencils.dir_override = tmp ("stencils-user");
    DirUtils.create_with_parents (UserStencils.dir_override, 0755);
    UserStencils.reload ();
    var st = UserStencils.create ("Team Kit");
    var items = new Gee.ArrayList<Item> ();
    var s = new Shape ("process", 100, 100, 120, 60);
    s.text = "Step";
    items.add (s);
    var m = StencilMaster.from_items ("My Step", items);
    m.id = st.new_master_id ();
    st.masters.add (m);
    UserStencils.save (st);
    UserStencils.reload ();
    var again = UserStencils.find (st.id);
    assert (again != null && again.masters.size == 1);
    string kind = UserStencils.kind_for (again, again.masters[0]);
    var e = ShapeLibrary.find (kind);
    assert (e != null && e.name == "My Step");
    var its = again.masters[0].items ();
    assert (its.size == 1 && its[0].text == "Step" && (its[0] as Shape).x == 0);
    bool listed = false;
    foreach (var c in ShapeLibrary.categories ()) if (c.id == "user:" + st.id) listed = true;
    assert (listed);
}

void test_gantt () {
    var g = new GanttShape ();
    var a = new GanttTask ();
    a.name = "A";
    a.start = "2026-01-05";
    a.duration = 5;
    var b = new GanttTask ();
    b.name = "B";
    b.start = "2026-01-01";
    b.duration = 3;
    b.depends = "1";
    g.tasks.add (a);
    g.tasks.add (b);
    g.schedule ();
    assert (b.start == "2026-01-10");
    assert (g.total_days () == 8);
    g.w = 600;
    g.fit_height ();
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 620, 140);
    var cr = new Cairo.Context (surf);
    cr.set_source_rgb (1, 1, 1);
    cr.paint ();
    Renderer.draw_shape (cr, g, new RenderOptions ());
    surf.write_to_png (tmp ("feature-gantt.png"));
}

void test_split_and_autoconnect () {
    var d = new Document ();
    var a = shape (d, "process", 0, 0, "A");
    var b = shape (d, "process", 400, 0, "B");
    var c = join_items (d, a, b);
    Router.route_all (d.page);
    var mid = shape (d, "decision", 200, 0, "M");
    mid.x = 260 - mid.w / 2;
    mid.y = 30 - mid.h / 2;
    assert (d.split_connector (mid, 6));
    Router.route_all (d.page);
    assert (d.page.connectors ().size == 2);
    assert (c.src.item_id == a.id && c.dst.item_id == mid.id);
    bool found = false;
    foreach (var cc in d.page.connectors ()) if (cc.src.item_id == mid.id && cc.dst.item_id == b.id) found = true;
    assert (found);
    assert (!d.split_connector (mid, 6));
}

void test_templates () {
    foreach (var info in Templates.list ()) {
        var d = Templates.build (info.id);
        assert (d.page.items.size > 0);
        var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 560, 400);
        var cr = new Cairo.Context (surf);
        cr.set_source_rgb (1, 1, 1);
        cr.paint ();
        d.link_backgrounds ();
        Renderer.draw_thumbnail (cr, d.page, 560, 400, true);
        surf.write_to_png (tmp ("feature-template-%s.png".printf (info.id)));
    }
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/features/jumps", test_jumps);
    Test.add_func ("/features/validation", test_validation);
    Test.add_func ("/features/swimlanes", test_swimlanes);
    Test.add_func ("/features/data-sources", test_data_sources);
    Test.add_func ("/features/graphics", test_graphics);
    Test.add_func ("/features/native", test_native_roundtrip);
    Test.add_func ("/features/background", test_background_render);
    Test.add_func ("/features/theme", test_theme);
    Test.add_func ("/features/shape-ops", test_shape_ops);
    Test.add_func ("/features/report-merge-html", test_report_merge_html);
    Test.add_func ("/features/user-stencils", test_user_stencils);
    Test.add_func ("/features/gantt", test_gantt);
    Test.add_func ("/features/split-connector", test_split_and_autoconnect);
    Test.add_func ("/features/templates", test_templates);
    return Test.run ();
}
