using Singularity.Apps.Draw;

bool near (double a, double b, double eps = 1e-6) {
    return (a - b).abs () <= eps;
}

double eval_num (string f, ShapeSheet? sh = null) {
    var ctx = new SheetContext (sh ?? new ShapeSheet (), null, null);
    var v = SheetEval.evaluate (f, ctx);
    assert (v != null);
    return v.as_number ();
}

string eval_str (string f, ShapeSheet? sh = null) {
    var ctx = new SheetContext (sh ?? new ShapeSheet (), null, null);
    var v = SheetEval.evaluate (f, ctx);
    assert (v != null);
    return v.as_string ();
}

void test_arithmetic () {
    assert (near (eval_num ("2+3*4"), 14));
    assert (near (eval_num ("(2+3)*4"), 20));
    assert (near (eval_num ("2^3"), 8));
    assert (near (eval_num ("-2+5"), 3));
    assert (near (eval_num ("50%"), 0.5));
    assert (near (eval_num ("=10/4"), 2.5));
    assert (near (eval_num ("1 in + 25.4 mm"), 2));
    assert (near (eval_num ("2.54CM"), 1));
    assert (near (eval_num ("72PT"), 1));
    assert (near (eval_num ("1 ft"), 12));
    assert (near (eval_num ("90 deg"), Math.PI / 2));
    assert (near (eval_num ("180DA"), Math.PI));
    assert (near (eval_num ("3>2"), 1));
    assert (near (eval_num ("3<=2"), 0));
    assert (near (eval_num ("2<>2"), 0));
    assert (eval_str ("IF(1>2,\"a\",\"b\")") == "b");
    assert (eval_str ("\"ab\"&\"cd\"") == "abcd");
    assert (eval_str ("\"say \"\"hi\"\"\"") == "say \"hi\"");
    assert (near (eval_num ("MAX(1,7,3)"), 7));
    assert (near (eval_num ("MIN(4,-2,3)"), -2));
    assert (near (eval_num ("SUM(1,2,3)"), 6));
    assert (near (eval_num ("ROUND(1.2345,2)"), 1.23));
    assert (near (eval_num ("MODULUS(-1,3)"), 2));
    assert (near (eval_num ("INT(-1.5)"), -2));
    assert (near (eval_num ("ABS(-4)+SQRT(9)+SIGN(-3)"), 6));
    assert (near (eval_num ("ATAN2(1,1)"), Math.PI / 4));
    assert (near (eval_num ("DEG(PI())"), 180));
    assert (near (eval_num ("AND(TRUE,1,NOT(0))"), 1));
    assert (near (eval_num ("OR(FALSE,0)"), 0));
    assert (eval_str ("INDEX(1,\"a;b;c\")") == "b");
    assert (near (eval_num ("LOOKUP(\"c\",\"a;b;c\")"), 2));
    assert (near (eval_num ("STRSAME(\"Ab\",\"ab\",1)"), 1));
    assert (eval_str ("LEFT(\"hello\",2)&MID(\"hello\",2,3)&RIGHT(\"hello\",1)&UPPER(\"x\")") == "heelloX");
    assert (near (eval_num ("LEN(\"abc\")"), 3));
    assert (near (eval_num ("BOUND(15,0,FALSE,0,10)"), 10));
    assert (eval_str ("RGB(255,0,128)") == "#ff0080");
    assert (near (eval_num ("CEILING(1.2)+FLOOR(1.8)"), 3));
    assert (!SheetEval.parses ("1+"));
    assert (!SheetEval.parses ("MAX(1,"));
    var ctx = new SheetContext (new ShapeSheet (), null, null);
    assert (SheetEval.evaluate ("THEMEVAL(\"FillColor\")", ctx) == null);
}

ShapeSheet sample_sheet () {
    var sh = new ShapeSheet ();
    sh.set_cell ("Width", "1.5");
    sh.set_cell ("Height", "0.5");
    var user = sh.ensure_section ("User");
    var r = new SheetRow ();
    r.name = "Size";
    r.set_cell ("Value", "2");
    r.set_cell ("Prompt", "Size of things");
    user.rows.add (r);
    var prop = sh.ensure_section ("Property");
    var pr = new SheetRow ();
    pr.name = "Cost";
    pr.set_cell ("Value", "40");
    pr.set_cell ("Label", "Cost");
    prop.rows.add (pr);
    var ctl = sh.ensure_section ("Controls");
    var cr = new SheetRow ();
    cr.name = "Row_1";
    cr.set_cell ("X", "0.375", "Width*0.25");
    cr.set_cell ("Y", "0.5", "Height");
    ctl.rows.add (cr);
    var scratch = sh.ensure_section ("Scratch");
    var sr = new SheetRow ();
    sr.ix = 0;
    sr.set_cell ("X", "0", "User.Size*3");
    sr.set_cell ("A", "0", "Prop.Cost+2");
    scratch.rows.add (sr);
    return sh;
}

void test_references () {
    var sh = sample_sheet ();
    assert (near (eval_num ("Width*2", sh), 3));
    assert (near (eval_num ("GUARD(Width*2)", sh), 3));
    assert (near (eval_num ("User.Size*10", sh), 20));
    assert (eval_str ("User.Size.Prompt", sh) == "Size of things");
    assert (near (eval_num ("Prop.Cost", sh), 40));
    assert (eval_str ("Prop.Cost.Label", sh) == "Cost");
    assert (near (eval_num ("Controls.Row_1", sh), 0.375));
    assert (near (eval_num ("Controls.Row_1.Y", sh), 0.5));
    assert (near (eval_num ("Controls.X1", sh), 0.375));
    assert (near (eval_num ("Scratch.X1+Scratch.A1", sh), 48));
    var ctx = new SheetContext (sh, null, null);
    ctx.w_override = 4;
    assert (near (SheetEval.evaluate ("Controls.Row_1", ctx).as_number (), 1));
}

void test_sheet_reference_and_page () {
    var page = new Page ();
    page.width = 960;
    page.height = 480;
    var a = new Shape ("rectangle", 0, 0, 192, 96);
    a.sheet = new ShapeSheet ();
    a.sheet.sheet_id = 5;
    a.sheet.set_cell ("Width", "2");
    var b = new Shape ("rectangle", 300, 0, 96, 96);
    b.sheet = new ShapeSheet ();
    b.sheet.sheet_id = 6;
    b.sheet.set_cell ("Width", "1", "Sheet.5!Width*2");
    page.items.add (a);
    page.items.add (b);
    var ctx = new SheetContext (b.sheet, b, page);
    assert (near (SheetEval.evaluate ("Sheet.5!Width", ctx).as_number (), 2));
    assert (near (SheetEval.evaluate ("ThePage!PageWidth", ctx).as_number (), 10));
    SheetEval.recalc_page (page);
    assert (near (b.w, 4 * 96, 1e-6));
    assert (near (b.cx (), 348, 1e-6));
}

void test_recalc_drives_model () {
    var page = new Page ();
    var s = new Shape ("rectangle", 100, 100, 50, 48);
    s.sheet = new ShapeSheet ();
    s.sheet.set_cell ("Width", "0", "Height*2");
    s.sheet.set_cell ("Height", "0");
    double cx = s.cx ();
    page.items.add (s);
    SheetEval.recalc_page (page);
    assert (near (s.w, 96, 1e-6));
    assert (near (s.cx (), cx, 1e-6));
    s.h = 96;
    SheetEval.recalc_page (page);
    assert (near (s.w, 192, 1e-6));
    s.sheet.set_cell ("Angle", "0", "30 deg");
    SheetEval.recalc_page (page);
    assert (near (s.rotation, 330, 1e-6));
    var d = new Document ();
    var t = new Shape ("rectangle", 10, 10, 96, 40);
    t.sheet = new ShapeSheet ();
    t.sheet.set_cell ("Height", "0", "Width*0.5");
    d.begin ("x");
    d.add_item (t);
    d.commit ();
    assert (near (t.h, 48, 1e-6));
}

ShapeSheet triangle_sheet () {
    var sh = new ShapeSheet ();
    sh.set_cell ("Width", "1");
    sh.set_cell ("Height", "1");
    var ctl = sh.ensure_section ("Controls");
    var cr = new SheetRow ();
    cr.name = "Row_1";
    cr.set_cell ("X", "0.5", "Width*0.5");
    cr.set_cell ("Y", "1", "Height*1");
    ctl.rows.add (cr);
    var g = sh.ensure_section ("Geometry", 0);
    g.cells.add (new SheetCell ("NoFill", "0"));
    string[] kinds = { "MoveTo", "LineTo", "LineTo", "LineTo" };
    string?[] xf = { "Width*0", "Width*1", "Controls.Row_1", "Geometry1.X1" };
    string?[] yf = { "Height*0", "Height*0", "Controls.Row_1.Y", "Geometry1.Y1" };
    for (int i = 0; i < 4; i++) {
        var r = new SheetRow ();
        r.ix = i + 1;
        r.kind = kinds[i];
        r.set_cell ("X", "0", xf[i]);
        r.set_cell ("Y", "0", yf[i]);
        g.rows.add (r);
    }
    return sh;
}

void test_sheet_shape_geometry () {
    var s = new SheetShape ();
    s.sheet = triangle_sheet ();
    s.x = 0;
    s.y = 0;
    s.w = 96;
    s.h = 96;
    var g = s.geometry ();
    assert (g.parts.size == 1);
    var b = g.parts[0].path.bounds ();
    assert (near (b.w, 96, 0.01) && near (b.h, 96, 0.01));
    var apex = g.parts[0].path.segs[2];
    assert (near (apex.x, 48, 0.01) && near (apex.y, 0, 0.01));
    s.w = 192;
    s.h = 48;
    g = s.geometry ();
    b = g.parts[0].path.bounds ();
    assert (near (b.w, 192, 0.01) && near (b.h, 48, 0.01));
    apex = g.parts[0].path.segs[2];
    assert (near (apex.x, 96, 0.01) && near (apex.y, 0, 0.01));
    assert (g.parts[0].path.has_closed_subpath ());
    var pts = SheetEval.control_points (s);
    assert (pts.length == 1);
    assert (near (pts[0].x, 96, 0.01) && near (pts[0].y, 0, 0.01));
    SheetEval.move_control (s, 0, 48, 24);
    var row = s.sheet.section ("Controls").row_named ("Row_1");
    assert (row.get_cell ("X").formula == "Width*0.25");
    assert (row.get_cell ("Y").formula == "Height*0.5");
    g = s.geometry ();
    apex = g.parts[0].path.segs[2];
    assert (near (apex.x, 48, 0.01) && near (apex.y, 24, 0.01));
    s.w = 400;
    g = s.geometry ();
    apex = g.parts[0].path.segs[2];
    assert (near (apex.x, 100, 0.01));
    var r = s.clone () as SheetShape;
    assert (r != null && r.sheet != s.sheet && r.sheet.section ("Controls") != null);
}

void test_native_round_trip () {
    var d = new Document ();
    var s = new SheetShape ();
    s.sheet = triangle_sheet ();
    s.sheet.sheet_id = 12;
    s.sheet.nested = true;
    s.w = 120;
    s.h = 80;
    d.add_item (s);
    var plain = new Shape ("process", 200, 10, 100, 50);
    plain.sheet = sample_sheet ();
    d.add_item (plain);
    string text = NativeFormat.serialize_document (d);
    Document r;
    try {
        r = NativeFormat.parse_document (text);
    } catch (Error e) {
        error ("parse: %s", e.message);
    }
    var rs = r.page.items[0] as SheetShape;
    assert (rs != null && rs.sheet != null);
    assert (rs.sheet.sheet_id == 12 && rs.sheet.nested);
    var geo = rs.geometry ();
    assert (geo.parts.size == 1 && near (geo.parts[0].path.bounds ().w, 120, 0.01));
    var rp = r.page.items[1];
    assert (rp.sheet != null);
    var sr = rp.sheet.section ("Scratch").row_at (0);
    assert (sr.get_cell ("X").formula == "User.Size*3");
    var ctx = new SheetContext (rp.sheet, rp, r.page);
    assert (near (SheetEval.evaluate ("Scratch.X1", ctx).as_number (), 6));
}

public static int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "C.UTF-8");
    Test.init (ref args);
    Test.add_func ("/shapesheet/arithmetic", test_arithmetic);
    Test.add_func ("/shapesheet/references", test_references);
    Test.add_func ("/shapesheet/sheet-reference", test_sheet_reference_and_page);
    Test.add_func ("/shapesheet/recalc", test_recalc_drives_model);
    Test.add_func ("/shapesheet/geometry", test_sheet_shape_geometry);
    Test.add_func ("/shapesheet/native", test_native_round_trip);
    return Test.run ();
}
