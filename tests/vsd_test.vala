using Singularity.Apps.Draw;

string fixture (string name) {
    return Path.build_filename (Environment.get_variable ("DRAW_FIXTURES") ?? "tests/fixtures", "vsd", name);
}

uint8[] bytes_of (string name) {
    uint8[] data;
    try {
        FileUtils.get_data (fixture (name), out data);
    } catch (Error e) {
        error ("%s: %s", name, e.message);
    }
    return data;
}

Document load (string name) {
    try {
        return Formats.load (fixture (name));
    } catch (Error e) {
        error ("%s: %s", name, e.message);
    }
}

string all_text (Document d) {
    var sb = new StringBuilder ();
    foreach (var p in d.pages) {
        foreach (var it in p.all_items ()) {
            sb.append (it.text);
            sb.append_c ('\n');
        }
    }
    return sb.str;
}

int count_kind (Page p, Type t) {
    int n = 0;
    foreach (var it in p.all_items ()) if (it.get_type ().is_a (t)) n++;
    return n;
}

Item? item_with_text (Page p, string text) {
    foreach (var it in p.all_items ()) if (it.text == text) return it;
    return null;
}

bool on_page (Page p, Item it) {
    var b = it.bounds ();
    return b.x > -5 && b.y > -5 && b.x2 () < p.width + 5 && b.y2 () < p.height + 5;
}

void render (Document d, string name) {
    string dir = Path.build_filename (Environment.get_tmp_dir (), "vsd-render");
    DirUtils.create_with_parents (dir, 0755);
    int i = 0;
    foreach (var p in d.pages) {
        Router.route_all (p);
        var surf = Export.render_area (p, Rect (0, 0, p.width, p.height), 1, false);
        surf.write_to_png (Path.build_filename (dir, "%s-%d.png".printf (name, i++)));
    }
}

void test_sniff () {
    var data = bytes_of ("Test_Visio-Some_Random_Text.vsd");
    assert (Formats.sniff (data, "drawing.bin") == FileKind.VSD);
    assert (Formats.kind_for_path ("a.vss") == FileKind.VSD);
    assert (Formats.kind_for_path ("a.vdx") == FileKind.VSD);
    assert (Vsd.version_of (data) == 11);
    assert (Vsd.version_of (bytes_of ("v6-non-utf16le.vsd")) == 6);
    assert (Vsd.version_of (bytes_of ("v5_Connection_Types.vsd")) == 5);
}

void test_v11_text () {
    var d = load ("Test_Visio-Some_Random_Text.vsd");
    render (d, "random-text");
    assert (d.pages.size == 1);
    var p = d.pages[0];
    assert (p.name == "Page-1");
    assert ((p.width - 793.7).abs () < 2 && (p.height - 1122.5).abs () < 2);
    string t = all_text (d);
    assert (t.contains ("Test View"));
    assert (t.contains ("I am a test view"));
    assert (t.contains ("Some random text, on a page"));
    assert (count_kind (p, typeof (Group)) == 1);
    var head = item_with_text (p, "Test View") as Shape;
    assert (head != null);
    assert (Colors.rgb_hex (head.style.fill) == "#c0c0c0");
    assert (head.style.font_family == "Arial");
    assert ((head.style.font_size - 10).abs () < 0.1);
    foreach (var it in p.all_items ()) assert (on_page (p, it));
    var loose = item_with_text (p, "Some random text, on a page") as Shape;
    assert (loose != null && loose.style.stroke == "none");
}

void test_v6_connector () {
    var d = load ("v6-non-utf16le.vsd");
    render (d, "v6");
    var p = d.pages[0];
    string t = all_text (d);
    assert (t.contains ("PropertySheet"));
    assert (t.contains ("PropertySheetField"));
    var conns = p.connectors ();
    assert (conns.size == 1);
    var c = conns[0];
    assert (c.src.attached () && c.dst.attached ());
    assert (p.find (c.src.item_id) is Group);
    assert (p.find (c.dst.item_id) is Group);
    assert (c.style.arrow_end != ArrowKind.NONE);
    var sheet = item_with_text (p, "PropertySheet") as Shape;
    assert (Colors.rgb_hex (sheet.style.fill) == "#cdcdcd");
}

void test_v5 () {
    var d = load ("v5_Connection_Types.vsd");
    render (d, "v5");
    var p = d.pages[0];
    assert (p.all_items ().size == 15);
    assert (count_kind (p, typeof (Group)) == 3);
    string t = all_text (d);
    assert (t.contains ("Static to Static"));
    assert (t.contains ("Dynamic to Dynamic"));
    assert (t.contains ("Dynamic to Static"));
    var label = item_with_text (p, "Static to Static");
    assert (label.style.bold && label.style.italic);
    assert ((label.style.font_size - 36).abs () < 0.1);
    foreach (var it in p.all_items ()) {
        var s = it as Shape;
        if (s != null) assert (s.geometry ().parts.size > 0);
    }
}

void test_ansi_and_boxes () {
    var d = load ("44501.vsd");
    render (d, "44501");
    string t = all_text (d);
    assert (t.contains ("Penible"));
    assert (t.contains ("Nouveau farine"));
    var box = item_with_text (d.pages[0], "Penible") as Shape;
    assert (box.kind == "rectangle");
    assert (box.w > 200 && box.h > 200);
}

void test_embedded () {
    var d = load ("visio_with_embeded.vsd");
    render (d, "embedded");
    assert (d.pages.size == 2);
    assert (d.pages[0].name == "Қўллаб, одиннацать, aileron");
    assert (d.pages[1].name == "Ҳар, двенадцать, dyadic");
    string t = all_text (d);
    assert (t.contains ("Иқтисодиёт1, четырнадцать1, zoic1"));
    assert (t.contains ("Ҳужжат1, семнадцать1, zonal1"));
    int decoded = 0;
    int images = 0;
    foreach (var it in d.pages[0].all_items ()) {
        var img = it as ImageShape;
        if (img == null) continue;
        images++;
        if (Renderer.pixbuf_for (img) != null) decoded++;
    }
    assert (images >= 5);
    assert (decoded >= 1);
    bool ellipse = false;
    foreach (var it in d.pages[0].all_items ()) {
        var ps = it as PathShape;
        if (ps != null && ps.path.segs.size > 4) ellipse = true;
    }
    assert (ellipse);
}

void test_stencil_masters () {
    UserStencil st;
    try {
        st = Vsd.load_stencil (bytes_of ("44594.vsd"));
    } catch (Error e) {
        error ("%s", e.message);
    }
    assert (st.masters.size >= 4);
    foreach (var m in st.masters) {
        assert (m.name != "");
        assert (m.items ().size > 0);
        assert (m.w > 1 && m.h > 1);
    }
    var d = load ("44594.vsd");
    assert (d.pages.size == 1 && d.pages[0].items.size == 0);
}

void test_vdx () {
    var d = load ("sample.vdx");
    render (d, "vdx");
    assert (d.pages.size == 2);
    var fg = d.pages[0];
    var bg = d.pages[1];
    assert (fg.name == "Overview");
    assert (bg.is_background && !fg.is_background);
    assert (fg.back_page == bg.id);
    assert (d.page_index == 0);
    assert ((fg.height - 6 * 96).abs () < 0.5);
    assert (fg.layers.size == 2 && fg.layers[1].name == "Notes" && !fg.layers[1].printable);
    var order = item_with_text (fg, "Receive order") as Shape;
    assert (order != null);
    assert (order.kind == "process");
    assert (Colors.rgb_hex (order.style.fill) == "#3a6ea5");
    assert (order.get_field ("Cost") == "120");
    assert (order.link == "https://example.org");
    assert (order.layer_id == fg.layers[0].id);
    assert ((order.x - 0.75 * 96).abs () < 0.5 && (order.y - (6 - 4.875) * 96).abs () < 0.5);
    var ship = item_with_text (fg, "Ship goods") as Shape;
    assert ((ship.rotation - 330).abs () < 0.1);
    assert (ship.style.bold && ship.style.italic);
    assert (Colors.rgb_hex (ship.style.text_color) == "#c62828");
    assert ((ship.style.font_size - 18).abs () < 0.1);
    var conns = fg.connectors ();
    assert (conns.size == 1);
    var c = conns[0];
    assert (c.text == "then");
    assert (c.src.item_id == order.id && c.dst.item_id == ship.id);
    assert (c.style.dash == DashKind.DASH);
    assert (c.style.arrow_end == ArrowKind.TRIANGLE);
    assert (count_kind (fg, typeof (Group)) == 1);
    var wave = fg.find ("v1_9") as PathShape;
    assert (wave != null);
    assert (wave.path.segs.size > 10);
    assert ((wave.w - 3 * 96).abs () < 0.5);
    var wb = wave.page_path ().bounds ();
    assert (wb.h > 20 && wb.w > 250);
    assert (all_text (d).contains ("Company footer"));
    UserStencil st;
    try {
        st = Vsd.load_stencil (bytes_of ("sample.vdx"));
    } catch (Error e) {
        error ("%s", e.message);
    }
    assert (st.masters.size == 2);
    assert (st.masters[0].name == "Process");
}

void test_fuzz () {
    string[] files = { "Test_Visio-Some_Random_Text.vsd", "v6-non-utf16le.vsd", "v5_Connection_Types.vsd", "44501.vsd", "sample.vdx" };
    var rand = new Rand.with_seed (1234);
    int loaded = 0, rejected = 0;
    foreach (string f in files) {
        var orig = bytes_of (f);
        for (int round = 0; round < 40; round++) {
            uint8[] data = orig;
            if (round % 4 == 0) {
                data = orig[0:rand.int_range (0, orig.length)];
            } else {
                int flips = rand.int_range (1, 64);
                for (int k = 0; k < flips; k++) data[rand.int_range (0, data.length)] = (uint8) rand.int_range (0, 256);
            }
            try {
                var d = Formats.load_data (data, f);
                foreach (var p in d.pages) foreach (var it in p.all_items ()) it.bounds ();
                loaded++;
            } catch (Error e) {
                rejected++;
            }
        }
    }
    print ("fuzz: %d loaded, %d rejected\n", loaded, rejected);
    assert (loaded + rejected == files.length * 40);
}

public static int main (string[] args) {
    Test.init (ref args);
    Test.add_func ("/vsd/sniff", test_sniff);
    Test.add_func ("/vsd/v11-text", test_v11_text);
    Test.add_func ("/vsd/v6-connector", test_v6_connector);
    Test.add_func ("/vsd/v5", test_v5);
    Test.add_func ("/vsd/ansi-boxes", test_ansi_and_boxes);
    Test.add_func ("/vsd/embedded", test_embedded);
    Test.add_func ("/vsd/stencil", test_stencil_masters);
    Test.add_func ("/vsd/vdx", test_vdx);
    Test.add_func ("/vsd/fuzz", test_fuzz);
    return Test.run ();
}
