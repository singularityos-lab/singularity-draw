using Singularity.Apps.Draw;

bool near (double a, double b, double eps = 0.01) {
    return (a - b).abs () <= eps;
}

string tmp (string name) {
    return Path.build_filename (Environment.get_tmp_dir (), "draw-raster-" + name);
}

bool same_pixels (Cairo.ImageSurface a, Cairo.ImageSurface b, int tolerance = 0) {
    if (a.get_width () != b.get_width () || a.get_height () != b.get_height ()) return false;
    a.flush ();
    b.flush ();
    for (int y = 0; y < a.get_height (); y++) {
        for (int x = 0; x < a.get_width (); x++) {
            uint32 p = Pixels.get (a, x, y), q = Pixels.get (b, x, y);
            for (int s = 0; s < 32; s += 8) {
                if ((((int) ((p >> s) & 0xff)) - ((int) ((q >> s) & 0xff))).abs () > tolerance) return false;
            }
        }
    }
    return true;
}

Document sample_doc () {
    var doc = new Document ();
    var page = doc.page;
    page.width = 120;
    page.height = 80;
    var rect = new Shape ("rectangle", 10, 10, 40, 20);
    rect.style.fill = "#3a6ea5";
    doc.add_item (rect);
    var l1 = Raster.add_layer (doc, page, "Sketch");
    var r1 = Raster.item_for (page, l1.id);
    var cr = new Cairo.Context (r1.pixels ());
    cr.set_source_rgba (0.9, 0.1, 0.1, 1);
    cr.arc (60, 40, 20, 0, 2 * Math.PI);
    cr.fill ();
    cr.set_source_rgba (0.1, 0.8, 0.2, 0.5);
    cr.rectangle (0, 0, 30, 30);
    cr.fill ();
    r1.sync ();
    l1.opacity = 0.6;
    l1.blend = BlendMode.MULTIPLY;
    var l2 = Raster.add_layer (doc, page, "Hidden Glaze");
    var r2 = Raster.item_for (page, l2.id);
    var cr2 = new Cairo.Context (r2.pixels ());
    cr2.set_source_rgba (0, 0, 1, 1);
    cr2.rectangle (80, 50, 30, 20);
    cr2.fill ();
    r2.sync ();
    l2.visible = false;
    l2.blend = BlendMode.SCREEN;
    return doc;
}

void check_raster_doc (Document orig, Document back, bool vector_expected) {
    var po = orig.page, pb = back.page;
    int rasters = 0;
    foreach (var l in pb.layers) if (l.raster) rasters++;
    if (rasters != 2) printerr ("raster layers: %d of %d\n", rasters, pb.layers.size);
    assert (rasters == 2);
    foreach (var lo in po.layers) {
        if (!lo.raster) continue;
        Layer? lb = null;
        foreach (var l in pb.layers) if (l.raster && l.name == lo.name) lb = l;
        assert (lb != null);
        assert (near (lb.opacity, lo.opacity, 0.001));
        assert (lb.blend == lo.blend);
        assert (lb.visible == lo.visible);
        var ro = Raster.item_for (po, lo.id);
        var rb = Raster.item_for (pb, lb.id);
        assert (rb != null);
        assert (rb.bytes.length > 0);
        assert (same_pixels (ro.pixels (), rb.pixels (), 1));
        assert (near (rb.x, ro.x) && near (rb.y, ro.y) && near (rb.w, ro.w) && near (rb.h, ro.h));
    }
    int vectors = 0;
    foreach (var it in pb.items) if (!(it is RasterItem)) vectors++;
    if (vector_expected) assert (vectors == 1);
    var ia = Export.render_area (po, Rect (0, 0, 120, 80), 1, false);
    var ib = Export.render_area (pb, Rect (0, 0, 120, 80), 1, false);
    assert (same_pixels (ia, ib, 2));
}

void test_odg_round_trip () throws Error {
    var doc = sample_doc ();
    var data = Odg.save (doc);
    var zip = new ZipReader (data);
    int pics = 0;
    foreach (string n in zip.names ()) if (n.has_prefix ("Pictures/") && n.has_suffix (".png")) pics++;
    assert (pics == 2);
    string content = zip.read_text ("content.xml");
    assert (content.contains ("draw:image") && content.contains ("sdraw:kind=\"raster\""));
    var back = Odg.load (data);
    check_raster_doc (doc, back, true);
    var flat = Odg.load_flat (Odg.save_flat (doc));
    check_raster_doc (doc, flat, true);
    var path = tmp ("rt.odg");
    Formats.save (doc, path);
    var loaded = Formats.load (path);
    check_raster_doc (doc, loaded, true);
    assert (!loaded.modified);
}

void test_svg_round_trip () throws Error {
    var doc = sample_doc ();
    string svg = SvgWriter.write_page (doc.page, SvgWriter.page_area (doc.page), false);
    assert (svg.contains ("data:image/png;base64,"));
    assert (svg.contains ("mix-blend-mode:multiply"));
    assert (svg.contains ("data-sdraw-raster=\"1\""));
    var back = SvgReader.load (svg);
    check_raster_doc (doc, back, true);
}

void test_native_round_trip () throws Error {
    var doc = sample_doc ();
    var back = NativeFormat.parse_document (NativeFormat.serialize_document (doc));
    check_raster_doc (doc, back, true);
}

void test_ora () throws Error {
    var doc = sample_doc ();
    var data = Ora.save (doc);
    assert (data.length > 60);
    var head = new StringBuilder ();
    for (int i = 30; i < 30 + 8; i++) head.append_c ((char) data[i]);
    assert (head.str == "mimetype");
    var mt = new StringBuilder ();
    for (int i = 38; i < 38 + 16; i++) mt.append_c ((char) data[i]);
    assert (mt.str == "image/openraster");
    assert (data[8] == 0 && data[9] == 0);
    var zip = new ZipReader (data);
    assert (zip.has ("stack.xml") && zip.has ("mergedimage.png") && zip.has ("Thumbnails/thumbnail.png"));
    string stack = zip.read_text ("stack.xml");
    assert (stack.contains ("composite-op=\"svg:multiply\""));
    assert (stack.contains ("visibility=\"hidden\""));
    assert (stack.contains ("name=\"Sketch\""));
    int layers = 0;
    foreach (string n in zip.names ()) if (n.has_prefix ("data/") && n.has_suffix (".png")) layers++;
    assert (layers == 4);
    var thumb = Pixels.decode (zip.read ("Thumbnails/thumbnail.png"));
    assert (thumb != null && int.max (thumb.get_width (), thumb.get_height ()) <= 256);
    var merged = Pixels.decode (zip.read ("mergedimage.png"));
    assert (merged.get_width () == 120 && merged.get_height () == 80);
    var expect = Export.render_area (doc.page, Rect (0, 0, 120, 80), 1, false);
    assert (same_pixels (merged, expect, 2));

    var back = Ora.load (data);
    assert (back.page.background == "#ffffff");
    assert (Raster.is_painting (back));
    int rasters = 0;
    foreach (var l in back.page.layers) if (l.raster) rasters++;
    assert (rasters == 3);
    var names = new Gee.ArrayList<string> ();
    foreach (var l in back.page.layers) names.add (l.name);
    assert (names[0] == "Layer 1" && names[1] == "Sketch" && names[2] == "Hidden Glaze");
    foreach (var l in back.page.layers) {
        if (l.name == "Sketch") {
            assert (near (l.opacity, 0.6, 0.001) && l.blend == BlendMode.MULTIPLY && l.visible);
            var src = Raster.item_for (doc.page, doc.page.layers[1].id);
            assert (same_pixels (src.pixels (), Raster.item_for (back.page, l.id).pixels (), 1));
        }
        if (l.name == "Hidden Glaze") assert (!l.visible && l.blend == BlendMode.SCREEN);
    }
    var again = Export.render_area (back.page, Rect (0, 0, 120, 80), 1, false);
    assert (same_pixels (again, expect, 2));

    var path = tmp ("rt.ora");
    Formats.save (back, path);
    uint8[] disk;
    FileUtils.get_data (path, out disk);
    assert (Formats.sniff (disk, "x.bin") == FileKind.ORA);
    var reloaded = Formats.load (path);
    assert (reloaded.path == path);
    assert (reloaded.page.layers.size == 3);
}

void test_images () throws Error {
    var s = Pixels.blank (30, 20);
    var cr = new Cairo.Context (s);
    cr.set_source_rgba (0.2, 0.4, 0.6, 0.8);
    cr.rectangle (5, 5, 10, 10);
    cr.fill ();
    s.flush ();
    var png = Pixels.png (s);
    var doc = Formats.load_data (png, "shot.png");
    assert (Raster.is_painting (doc));
    assert (near (doc.page.width, 30) && near (doc.page.height, 20));
    var r = Raster.item_for (doc.page, doc.page.layers[0].id);
    assert (same_pixels (r.pixels (), s, 1));
    var jpg = Pixels.jpeg (s, 95);
    assert (jpg.length > 2 && jpg[0] == 0xff && jpg[1] == 0xd8);
    var jd = Formats.load_data (jpg, "shot.jpg");
    var jr = Raster.item_for (jd.page, jd.page.layers[0].id);
    uint32 inside = Pixels.get (jr.pixels (), 10, 10);
    int red = (int) ((inside >> 16) & 0xff);
    int expect = (int) Math.round ((0.2 * 0.8 + 0.2) * 255);
    assert ((red - expect).abs () < 8);
    assert (((inside >> 24) & 0xff) == 255);
}

void test_backward_compat () throws Error {
    var layers = new Gee.ArrayList<Layer> ();
    Odg.decode_layers ("layer1,Layer%201,1,0,1;layer2,Notes,0,1,1", layers);
    assert (layers.size == 2 && !layers[0].raster && !layers[1].raster && !layers[1].visible);
    var fixtures = Environment.get_variable ("DRAW_FIXTURES");
    if (fixtures != null) {
        var d = Formats.load (Path.build_filename (fixtures, "odg", "lo-sample.fodg"));
        assert (!Raster.has_raster (d.page));
        foreach (var it in d.page.items) assert (!(it is RasterItem));
        var svg = Formats.load (Path.build_filename (fixtures, "svg", "shapes.svg"));
        assert (!Raster.has_raster (svg.page));
    }
    var doc = new Document ();
    var img = Formats.image_item (Pixels.png (Pixels.blank (8, 8)));
    doc.add_item (img);
    var back = Odg.load (Odg.save (doc));
    assert (back.page.items[0] is ImageShape && !(back.page.items[0] is RasterItem));
}

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    try {
        test_odg_round_trip ();
        test_svg_round_trip ();
        test_native_round_trip ();
        test_ora ();
        test_images ();
        test_backward_compat ();
    } catch (Error e) {
        printerr ("%s\n", e.message);
        return 1;
    }
    print ("raster-io: all tests passed\n");
    return 0;
}
