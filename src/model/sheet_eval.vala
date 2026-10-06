namespace Singularity.Apps.Draw {

    public class SheetValue {
        public bool is_text = false;
        public double num = 0;
        public string str = "";

        public SheetValue.number (double v) {
            num = v;
        }

        public SheetValue.text (string s) {
            is_text = true;
            str = s;
        }

        public static SheetValue from_cell (string v) {
            double d = 0;
            string t = v.strip ();
            if (t != "" && double.try_parse (t, out d)) return new SheetValue.number (d);
            if (t.down () == "true") return new SheetValue.number (1);
            if (t.down () == "false") return new SheetValue.number (0);
            return new SheetValue.text (v);
        }

        public double as_number () {
            if (!is_text) return num;
            double d;
            if (double.try_parse (str.strip (), out d)) return d;
            return 0;
        }

        public bool as_bool () {
            if (!is_text) return num != 0;
            string t = str.strip ().down ();
            return t != "" && t != "0" && t != "false";
        }

        public string as_string () {
            if (is_text) return str;
            return PathData.fmt (num, 10);
        }
    }

    private enum SheetNodeKind {
        NUM,
        STR,
        REF,
        CALL,
        BIN,
        NEG,
        PCT
    }

    private class SheetNode {
        public SheetNodeKind kind;
        public double num = 0;
        public string text = "";
        public Gee.ArrayList<SheetNode> args = new Gee.ArrayList<SheetNode> ();

        public SheetNode (SheetNodeKind kind) {
            this.kind = kind;
        }
    }

    private class SheetFormulaParser {
        private string s;
        private int pos = 0;
        private bool failed = false;

        public SheetFormulaParser (string s) {
            this.s = s;
        }

        public static SheetNode? parse (string formula) {
            string f = formula.strip ();
            if (f.has_prefix ("=")) f = f.substring (1);
            var p = new SheetFormulaParser (f);
            var n = p.expr ();
            p.ws ();
            if (p.failed || n == null || p.pos < p.s.length) return null;
            return n;
        }

        private void ws () {
            while (pos < s.length && (s[pos] == ' ' || s[pos] == '\t' || s[pos] == '\n' || s[pos] == '\r')) pos++;
        }

        private bool accept (string tok) {
            ws ();
            if (s.substring (pos).has_prefix (tok)) {
                pos += tok.length;
                return true;
            }
            return false;
        }

        private SheetNode bin (string op, SheetNode a, SheetNode b) {
            var n = new SheetNode (SheetNodeKind.BIN);
            n.text = op;
            n.args.add (a);
            n.args.add (b);
            return n;
        }

        private SheetNode? expr () {
            var a = concat ();
            while (a != null && !failed) {
                ws ();
                string? op = null;
                foreach (string o in new string[] { "<>", "<=", ">=", "=", "<", ">" }) {
                    if (s.substring (pos).has_prefix (o)) {
                        op = o;
                        break;
                    }
                }
                if (op == null) break;
                pos += op.length;
                var b = concat ();
                if (b == null) {
                    failed = true;
                    return null;
                }
                a = bin (op, a, b);
            }
            return a;
        }

        private SheetNode? concat () {
            var a = add ();
            while (a != null && !failed && accept ("&")) {
                var b = add ();
                if (b == null) {
                    failed = true;
                    return null;
                }
                a = bin ("&", a, b);
            }
            return a;
        }

        private SheetNode? add () {
            var a = mul ();
            while (a != null && !failed) {
                ws ();
                if (pos >= s.length || (s[pos] != '+' && s[pos] != '-')) break;
                string op = s[pos].to_string ();
                pos++;
                var b = mul ();
                if (b == null) {
                    failed = true;
                    return null;
                }
                a = bin (op, a, b);
            }
            return a;
        }

        private SheetNode? mul () {
            var a = power ();
            while (a != null && !failed) {
                ws ();
                if (pos >= s.length || (s[pos] != '*' && s[pos] != '/')) break;
                string op = s[pos].to_string ();
                pos++;
                var b = power ();
                if (b == null) {
                    failed = true;
                    return null;
                }
                a = bin (op, a, b);
            }
            return a;
        }

        private SheetNode? power () {
            var a = unary ();
            while (a != null && !failed && accept ("^")) {
                var b = unary ();
                if (b == null) {
                    failed = true;
                    return null;
                }
                a = bin ("^", a, b);
            }
            return a;
        }

        private SheetNode? unary () {
            ws ();
            if (pos < s.length && s[pos] == '-') {
                pos++;
                var a = unary ();
                if (a == null) return null;
                var n = new SheetNode (SheetNodeKind.NEG);
                n.args.add (a);
                return n;
            }
            if (pos < s.length && s[pos] == '+') {
                pos++;
                return unary ();
            }
            var p = primary ();
            if (p != null && accept ("%")) {
                var n = new SheetNode (SheetNodeKind.PCT);
                n.args.add (p);
                return n;
            }
            return p;
        }

        private static bool ident_char (char c) {
            return c.isalnum () || c == '_' || c == '.' || c == '!' || (uchar) c >= 0x80;
        }

        public static double unit_factor (string u, out bool ok) {
            ok = true;
            switch (u.down ()) {
                case "in": case "in.": case "inch": case "inches": case "dl": case "dp": return 1;
                case "ft": case "ft.": case "feet": return 12;
                case "yd": return 36;
                case "mi": return 63360;
                case "mm": return 1 / 25.4;
                case "cm": return 1 / 2.54;
                case "m": return 39.37007874;
                case "km": return 39370.07874;
                case "pt": case "dt": return 1.0 / 72;
                case "p": case "pc": return 1.0 / 6;
                case "da": case "deg": case "ad": case "°": return Math.PI / 180;
                case "rad": return 1;
                case "min": return Math.PI / 10800;
                case "sec": return Math.PI / 648000;
                case "ed": case "em": return 1;
                case "d": case "c": return 1.0 / 72;
                case "u": return 1;
                default:
                    ok = false;
                    return 1;
            }
        }

        private SheetNode? primary () {
            ws ();
            if (pos >= s.length) {
                failed = true;
                return null;
            }
            char c = s[pos];
            if (c == '(') {
                pos++;
                var e = expr ();
                if (!accept (")")) {
                    failed = true;
                    return null;
                }
                return e;
            }
            if (c == '"') {
                pos++;
                var sb = new StringBuilder ();
                while (pos < s.length) {
                    if (s[pos] == '"') {
                        if (pos + 1 < s.length && s[pos + 1] == '"') {
                            sb.append_c ('"');
                            pos += 2;
                            continue;
                        }
                        break;
                    }
                    sb.append_c (s[pos]);
                    pos++;
                }
                if (pos >= s.length) {
                    failed = true;
                    return null;
                }
                pos++;
                var n = new SheetNode (SheetNodeKind.STR);
                n.text = sb.str;
                return n;
            }
            if (c.isdigit () || c == '.') {
                int start = pos;
                while (pos < s.length && (s[pos].isdigit () || s[pos] == '.')) pos++;
                if (pos < s.length && (s[pos] == 'e' || s[pos] == 'E') && pos + 1 < s.length && (s[pos + 1].isdigit () || ((s[pos + 1] == '-' || s[pos + 1] == '+') && pos + 2 < s.length && s[pos + 2].isdigit ()))) {
                    pos += 2;
                    while (pos < s.length && s[pos].isdigit ()) pos++;
                }
                double v;
                if (!double.try_parse (s.substring (start, pos - start), out v)) {
                    failed = true;
                    return null;
                }
                int save = pos;
                while (pos < s.length && s[pos] == ' ') pos++;
                int us = pos;
                if (s.substring (pos).has_prefix ("°")) {
                    pos += "°".length;
                    v *= Math.PI / 180;
                } else {
                    while (pos < s.length && s[pos].isalpha ()) pos++;
                    if (pos < s.length && s[pos] == '.' && pos > us) pos++;
                    string unit = s.substring (us, pos - us);
                    bool ok = false;
                    double f = unit != "" ? unit_factor (unit, out ok) : 1;
                    if (unit != "" && ok && (pos >= s.length || !ident_char (s[pos]) || s[pos] == '.')) v *= f;
                    else pos = save;
                }
                var n = new SheetNode (SheetNodeKind.NUM);
                n.num = v;
                return n;
            }
            if (c.isalpha () || c == '_' || (uchar) c >= 0x80 || c == '\'') {
                var sb = new StringBuilder ();
                if (c == '\'') {
                    pos++;
                    while (pos < s.length && s[pos] != '\'') sb.append_c (s[pos++]);
                    if (pos >= s.length) {
                        failed = true;
                        return null;
                    }
                    pos++;
                }
                while (pos < s.length && ident_char (s[pos])) sb.append_c (s[pos++]);
                string name = sb.str;
                ws ();
                if (pos < s.length && s[pos] == '(') {
                    pos++;
                    var n = new SheetNode (SheetNodeKind.CALL);
                    n.text = name.up ();
                    ws ();
                    if (accept (")")) return n;
                    while (true) {
                        ws ();
                        if (pos < s.length && (s[pos] == ',' || s[pos] == ')')) {
                            n.args.add (new SheetNode (SheetNodeKind.STR));
                        } else {
                            var a = expr ();
                            if (a == null) {
                                failed = true;
                                return null;
                            }
                            n.args.add (a);
                        }
                        if (accept (",")) continue;
                        if (accept (")")) break;
                        failed = true;
                        return null;
                    }
                    return n;
                }
                var r = new SheetNode (SheetNodeKind.REF);
                r.text = name;
                return r;
            }
            failed = true;
            return null;
        }
    }

    public class SheetContext {
        public ShapeSheet sheet;
        public Item? item;
        public Page? page;
        public double w_override = double.NAN;
        public double h_override = double.NAN;
        public bool evaluate_all = true;
        public int depth = 0;
        internal Gee.HashMap<string, SheetValue?> memo = new Gee.HashMap<string, SheetValue?> ();
        internal Gee.HashSet<string> visiting = new Gee.HashSet<string> ();

        public SheetContext (ShapeSheet sheet, Item? item, Page? page) {
            this.sheet = sheet;
            this.item = item;
            this.page = page;
        }

        public double ppi () {
            return sheet.ppi > 0 ? sheet.ppi : Units.PX_PER_IN;
        }
    }

    public class SheetEval {
        private static Gee.HashMap<string, SheetNode?>? cache = null;
        private static SheetNode failed_marker;

        private static SheetNode? parsed (string formula) {
            if (cache == null) {
                cache = new Gee.HashMap<string, SheetNode?> ();
                failed_marker = new SheetNode (SheetNodeKind.STR);
            }
            if (cache.has_key (formula)) {
                var n = cache[formula];
                return n == failed_marker ? null : n;
            }
            var node = SheetFormulaParser.parse (formula);
            if (cache.size > 20000) cache.clear ();
            cache[formula] = node ?? failed_marker;
            return node;
        }

        public static bool parses (string formula) {
            return parsed (formula) != null;
        }

        public static SheetValue? evaluate (string formula, SheetContext ctx) {
            var n = parsed (formula);
            if (n == null) return null;
            return eval (n, ctx);
        }

        public static SheetValue? eval_cell (SheetContext ctx, SheetCell cell, string key) {
            if (ctx.memo.has_key (key)) return ctx.memo[key];
            SheetValue? v = null;
            if (cell.has_formula () && (ctx.evaluate_all || cell.inherited) && !ctx.visiting.contains (key) && ctx.depth < 64) {
                ctx.visiting.add (key);
                ctx.depth++;
                v = evaluate (cell.formula, ctx);
                ctx.depth--;
                ctx.visiting.remove (key);
            }
            if (v == null) v = SheetValue.from_cell (cell.value);
            ctx.memo[key] = v;
            return v;
        }

        private static Shape? shape_of (SheetContext ctx) {
            return ctx.item as Shape;
        }

        private static SheetValue? core (SheetContext ctx, string name) {
            var s = shape_of (ctx);
            double ppi = ctx.ppi ();
            switch (name) {
                case "Width":
                    if (!ctx.w_override.is_nan ()) return new SheetValue.number (ctx.w_override);
                    break;
                case "Height":
                    if (!ctx.h_override.is_nan ()) return new SheetValue.number (ctx.h_override);
                    break;
            }
            var c = ctx.sheet.get_cell (name);
            if (c != null) return eval_cell (ctx, c, "@" + name);
            if (s == null) return null;
            switch (name) {
                case "Width": return new SheetValue.number (s.w / ppi);
                case "Height": return new SheetValue.number (s.h / ppi);
                case "PinX": return new SheetValue.number (s.cx () / ppi);
                case "PinY": return new SheetValue.number (ctx.page != null ? (ctx.page.height - s.cy ()) / ppi : 0);
                case "LocPinX": return new SheetValue.number (num (core (ctx, "Width")) / 2);
                case "LocPinY": return new SheetValue.number (num (core (ctx, "Height")) / 2);
                case "Angle": return new SheetValue.number (-s.rotation * Math.PI / 180);
                case "FlipX": return new SheetValue.number (s.flip_h ? 1 : 0);
                case "FlipY": return new SheetValue.number (s.flip_v ? 1 : 0);
                default: return null;
            }
        }

        private static double num (SheetValue? v, double fallback = 0) {
            return v != null ? v.as_number () : fallback;
        }

        private static bool split_index (string token, out string letters, out int number) {
            letters = "";
            number = 0;
            int i = 0;
            while (i < token.length && token[i].isalpha ()) i++;
            if (i == 0 || i >= token.length) return false;
            for (int k = i; k < token.length; k++) if (!token[k].isdigit ()) return false;
            letters = token.substring (0, i);
            number = int.parse (token.substring (i));
            return true;
        }

        private static SheetValue? row_cell (SheetContext ctx, SheetSection? sec, SheetRow? row, string cell) {
            if (sec == null || row == null || row.deleted) return null;
            var c = row.get_cell (cell);
            if (c == null) return null;
            return eval_cell (ctx, c, "%s#%d/%d/%s/%s".printf (sec.name, sec.ix, row.ix, row.name ?? "", cell));
        }

        public static SheetValue? resolve (SheetContext ctx, string name) {
            int bang = name.last_index_of ("!");
            if (bang > 0) {
                string prefix = name.substring (0, bang), cell = name.substring (bang + 1);
                if (prefix == "ThePage") return page_cell (ctx, cell);
                if (prefix == "TheDoc") return null;
                if (prefix.has_prefix ("Sheet.") && ctx.page != null) {
                    int id = int.parse (prefix.substring (6));
                    foreach (var it in ctx.page.all_items ()) {
                        if (it.sheet == null || it.sheet.sheet_id != id) continue;
                        var sub = new SheetContext (it.sheet, it, ctx.page);
                        sub.evaluate_all = ctx.evaluate_all;
                        sub.depth = ctx.depth + 1;
                        if (sub.depth > 8) return null;
                        return resolve (sub, cell);
                    }
                }
                return null;
            }
            switch (name.up ()) {
                case "TRUE": return new SheetValue.number (1);
                case "FALSE": return new SheetValue.number (0);
                case "THETEXT": return new SheetValue.text (ctx.item != null ? ctx.item.display_text () : "");
            }
            switch (name) {
                case "Width": case "Height": case "PinX": case "PinY": case "LocPinX": case "LocPinY": case "Angle": case "FlipX": case "FlipY":
                    return core (ctx, name);
            }
            string[] parts = name.split (".");
            if (parts.length >= 2) {
                var sh = ctx.sheet;
                string head = parts[0];
                string rest = parts[1];
                string? sub_cell = parts.length > 2 ? parts[2] : null;
                switch (head) {
                    case "User":
                    case "Prop":
                    case "Actions":
                    case "Hyperlink":
                        string sname = head == "Prop" ? "Property" : head;
                        var sec = sh.section (sname);
                        string def_cell = head == "Actions" ? "Action" : (head == "Hyperlink" ? "Address" : "Value");
                        return row_cell (ctx, sec, sec != null ? sec.row_named (rest) : null, sub_cell ?? def_cell);
                    case "Controls":
                    case "Connections":
                    case "Scratch":
                        string sname2 = head == "Connections" ? "Connection" : head;
                        var sec2 = sh.section (sname2);
                        if (sec2 == null) return null;
                        string letters;
                        int n;
                        if (split_index (rest, out letters, out n) && sub_cell == null) return row_cell (ctx, sec2, sec2.row_at (n - 1), letters);
                        return row_cell (ctx, sec2, sec2.row_named (rest), sub_cell ?? "X");
                    case "Char":
                    case "Para":
                        var sec3 = sh.section (head == "Char" ? "Character" : "Paragraph");
                        return row_cell (ctx, sec3, sec3 != null ? sec3.row_at (0) : null, rest);
                }
                if (head.has_prefix ("Geometry")) {
                    int gi = int.parse (head.substring (8));
                    if (gi <= 0) return null;
                    var gs = sh.section ("Geometry", gi - 1);
                    if (gs == null) return null;
                    string letters;
                    int n;
                    if (split_index (rest, out letters, out n)) return row_cell (ctx, gs, gs.row_at (n), letters);
                    var sc = gs.get_cell (rest);
                    if (sc != null) return eval_cell (ctx, sc, "%s#%d/%s".printf (gs.name, gs.ix, rest));
                    return null;
                }
            }
            var top = ctx.sheet.get_cell (name);
            if (top != null) return eval_cell (ctx, top, "@" + name);
            return null;
        }

        private static SheetValue? page_cell (SheetContext ctx, string cell) {
            if (ctx.page == null) return null;
            double ppi = ctx.ppi ();
            switch (cell) {
                case "PageWidth": return new SheetValue.number (ctx.page.width / ppi);
                case "PageHeight": return new SheetValue.number (ctx.page.height / ppi);
                case "PageScale":
                    return new SheetValue.number (ctx.page.has_scale () ? ctx.page.scale_paper * Units.mm_per (ctx.page.scale_paper_units) / 25.4 : 1);
                case "DrawingScale":
                    return new SheetValue.number (ctx.page.has_scale () ? ctx.page.scale_world * Units.mm_per (ctx.page.scale_units) / 25.4 : 1);
                default: return null;
            }
        }

        private static SheetValue? eval (SheetNode n, SheetContext ctx) {
            switch (n.kind) {
                case SheetNodeKind.NUM: return new SheetValue.number (n.num);
                case SheetNodeKind.STR: return new SheetValue.text (n.text);
                case SheetNodeKind.REF: return resolve (ctx, n.text);
                case SheetNodeKind.NEG:
                    var a = eval (n.args[0], ctx);
                    return a != null ? new SheetValue.number (-a.as_number ()) : null;
                case SheetNodeKind.PCT:
                    var p = eval (n.args[0], ctx);
                    return p != null ? new SheetValue.number (p.as_number () / 100) : null;
                case SheetNodeKind.BIN:
                    return binary (n.text, eval (n.args[0], ctx), eval (n.args[1], ctx));
                case SheetNodeKind.CALL:
                    return call (n, ctx);
            }
            return null;
        }

        private static SheetValue? binary (string op, SheetValue? a, SheetValue? b) {
            if (a == null || b == null) return null;
            if (op == "&") return new SheetValue.text (a.as_string () + b.as_string ());
            double x = a.as_number (), y = b.as_number ();
            bool text_cmp = a.is_text && b.is_text;
            switch (op) {
                case "+": return new SheetValue.number (x + y);
                case "-": return new SheetValue.number (x - y);
                case "*": return new SheetValue.number (x * y);
                case "/": return y != 0 ? new SheetValue.number (x / y) : null;
                case "^": return new SheetValue.number (Math.pow (x, y));
                case "=": return new SheetValue.number (text_cmp ? (a.str.casefold () == b.str.casefold () ? 1 : 0) : ((x - y).abs () < 1e-12 ? 1 : 0));
                case "<>": return new SheetValue.number (text_cmp ? (a.str.casefold () != b.str.casefold () ? 1 : 0) : ((x - y).abs () >= 1e-12 ? 1 : 0));
                case "<": return new SheetValue.number (x < y ? 1 : 0);
                case ">": return new SheetValue.number (x > y ? 1 : 0);
                case "<=": return new SheetValue.number (x <= y ? 1 : 0);
                case ">=": return new SheetValue.number (x >= y ? 1 : 0);
            }
            return null;
        }

        private static SheetValue? arg (SheetNode n, int i, SheetContext ctx) {
            if (i >= n.args.size) return null;
            return eval (n.args[i], ctx);
        }

        private static double narg (SheetNode n, int i, SheetContext ctx, double fallback = 0) {
            var v = arg (n, i, ctx);
            return v != null ? v.as_number () : fallback;
        }

        private static SheetValue number (double v) {
            return new SheetValue.number (v);
        }

        private static bool parse_color (SheetValue? v, out Rgba c) {
            c = Rgba (0, 0, 0, 1);
            if (v == null) return false;
            return Colors.parse (v.as_string (), out c);
        }

        private static string hsl_hex (double h, double s, double l) {
            h = h / 240.0 * 360;
            s /= 240.0;
            l /= 240.0;
            double c = (1 - (2 * l - 1).abs ()) * s;
            double hp = h / 60;
            double x = c * (1 - (Math.fmod (hp, 2) - 1).abs ());
            double r = 0, g = 0, b = 0;
            if (hp < 1) { r = c; g = x; }
            else if (hp < 2) { r = x; g = c; }
            else if (hp < 3) { g = c; b = x; }
            else if (hp < 4) { g = x; b = c; }
            else if (hp < 5) { r = x; b = c; }
            else { r = c; b = x; }
            double m = l - c / 2;
            return Colors.to_hex (Rgba (r + m, g + m, b + m, 1));
        }

        private static SheetValue? call (SheetNode n, SheetContext ctx) {
            switch (n.text) {
                case "IF":
                    var c = arg (n, 0, ctx);
                    if (c == null) return null;
                    return c.as_bool () ? arg (n, 1, ctx) : (n.args.size > 2 ? arg (n, 2, ctx) : number (0));
                case "AND":
                    foreach (var a in n.args) {
                        var v = eval (a, ctx);
                        if (v == null) return null;
                        if (!v.as_bool ()) return number (0);
                    }
                    return number (1);
                case "OR":
                    foreach (var a in n.args) {
                        var v = eval (a, ctx);
                        if (v == null) return null;
                        if (v.as_bool ()) return number (1);
                    }
                    return number (0);
                case "NOT":
                    var nv = arg (n, 0, ctx);
                    return nv != null ? number (nv.as_bool () ? 0 : 1) : null;
                case "GUARD":
                case "THEMEGUARD":
                case "SETATREF":
                case "SETATREFEXPR":
                case "SETATREFEVAL":
                case "EVALTEXT":
                    return n.args.size > 0 ? arg (n, 0, ctx) : null;
                case "MIN":
                case "MAX":
                case "SUM":
                    if (n.args.size == 0) return null;
                    double acc = n.text == "SUM" ? 0 : (n.text == "MIN" ? double.MAX : -double.MAX);
                    foreach (var a in n.args) {
                        var v = eval (a, ctx);
                        if (v == null) return null;
                        double d = v.as_number ();
                        if (n.text == "SUM") acc += d;
                        else if (n.text == "MIN") acc = double.min (acc, d);
                        else acc = double.max (acc, d);
                    }
                    return number (acc);
                case "ABS": return n.args.size > 0 ? number (narg (n, 0, ctx).abs ()) : null;
                case "SQRT": return number (Math.sqrt (narg (n, 0, ctx)));
                case "SIN": return number (Math.sin (narg (n, 0, ctx)));
                case "COS": return number (Math.cos (narg (n, 0, ctx)));
                case "TAN": return number (Math.tan (narg (n, 0, ctx)));
                case "ASIN": return number (Math.asin (narg (n, 0, ctx)));
                case "ACOS": return number (Math.acos (narg (n, 0, ctx)));
                case "ATAN": return number (Math.atan (narg (n, 0, ctx)));
                case "ATAN2": return number (Math.atan2 (narg (n, 0, ctx), narg (n, 1, ctx)));
                case "PI": return number (Math.PI);
                case "INT": return number (Math.floor (narg (n, 0, ctx)));
                case "TRUNC":
                    double tp = Math.pow (10, narg (n, 1, ctx));
                    double tv = narg (n, 0, ctx) * tp;
                    return number ((tv < 0 ? Math.ceil (tv) : Math.floor (tv)) / tp);
                case "ROUND":
                    double rp = Math.pow (10, narg (n, 1, ctx));
                    return number (Math.round (narg (n, 0, ctx) * rp) / rp);
                case "CEILING":
                    double cm = n.args.size > 1 ? narg (n, 1, ctx) : 1;
                    return number (cm != 0 ? Math.ceil (narg (n, 0, ctx) / cm) * cm : 0);
                case "FLOOR":
                    double fm = n.args.size > 1 ? narg (n, 1, ctx) : 1;
                    return number (fm != 0 ? Math.floor (narg (n, 0, ctx) / fm) * fm : 0);
                case "MODULUS":
                    double mb = narg (n, 1, ctx);
                    double ma = narg (n, 0, ctx);
                    return mb != 0 ? number (ma - mb * Math.floor (ma / mb)) : null;
                case "SIGN":
                    double sv = narg (n, 0, ctx);
                    return number (sv > 0 ? 1 : (sv < 0 ? -1 : 0));
                case "LN": return number (Math.log (narg (n, 0, ctx)));
                case "LOG10": return number (Math.log10 (narg (n, 0, ctx)));
                case "EXP": return number (Math.exp (narg (n, 0, ctx)));
                case "POW": return number (Math.pow (narg (n, 0, ctx), narg (n, 1, ctx)));
                case "DEG": return number (narg (n, 0, ctx) * 180 / Math.PI);
                case "RAD": return number (narg (n, 0, ctx) * Math.PI / 180);
                case "ANG360":
                    double an = Math.fmod (narg (n, 0, ctx), 2 * Math.PI);
                    return number (an < 0 ? an + 2 * Math.PI : an);
                case "MAGNITUDE":
                    if (n.args.size >= 4) return number (Math.hypot (narg (n, 0, ctx) * narg (n, 1, ctx), narg (n, 2, ctx) * narg (n, 3, ctx)));
                    return number (Math.hypot (narg (n, 0, ctx), narg (n, 1, ctx)));
                case "BOUND":
                    var bv = arg (n, 0, ctx);
                    if (bv == null) return null;
                    if (n.args.size >= 5) {
                        double lo = narg (n, 3, ctx), hi = narg (n, 4, ctx);
                        return number (bv.as_number ().clamp (double.min (lo, hi), double.max (lo, hi)));
                    }
                    return bv;
                case "INDEX":
                    int idx = (int) narg (n, 0, ctx);
                    var list = arg (n, 1, ctx);
                    if (list == null) return null;
                    string delim = n.args.size > 2 ? (arg (n, 2, ctx) ?? new SheetValue.text (";")).as_string () : ";";
                    if (delim == "") delim = ";";
                    string[] items = list.as_string ().split (delim);
                    if (idx < 0 || idx >= items.length) return n.args.size > 3 ? arg (n, 3, ctx) : new SheetValue.text ("");
                    return SheetValue.from_cell (items[idx]);
                case "LOOKUP":
                    var key = arg (n, 0, ctx);
                    var lst = arg (n, 1, ctx);
                    if (key == null || lst == null) return null;
                    string ld = n.args.size > 2 ? (arg (n, 2, ctx) ?? new SheetValue.text (";")).as_string () : ";";
                    if (ld == "") ld = ";";
                    string[] li = lst.as_string ().split (ld);
                    for (int i = 0; i < li.length; i++) if (li[i].casefold () == key.as_string ().casefold ()) return number (i);
                    return number (-1);
                case "STRSAME":
                    var s1 = arg (n, 0, ctx);
                    var s2 = arg (n, 1, ctx);
                    if (s1 == null || s2 == null) return null;
                    bool ic = n.args.size > 2 && narg (n, 2, ctx) != 0;
                    return number ((ic ? s1.as_string ().casefold () == s2.as_string ().casefold () : s1.as_string () == s2.as_string ()) ? 1 : 0);
                case "LEN":
                    var lv = arg (n, 0, ctx);
                    return lv != null ? number (lv.as_string ().char_count ()) : null;
                case "LEFT":
                case "RIGHT":
                case "MID":
                    var tv2 = arg (n, 0, ctx);
                    if (tv2 == null) return null;
                    string t = tv2.as_string ();
                    int cc = t.char_count ();
                    int start = 0, count = cc;
                    if (n.text == "LEFT") count = (int) narg (n, 1, ctx, 1);
                    else if (n.text == "RIGHT") {
                        count = (int) narg (n, 1, ctx, 1);
                        start = cc - count;
                    } else {
                        start = (int) narg (n, 1, ctx, 1) - 1;
                        count = (int) narg (n, 2, ctx, cc);
                    }
                    start = start.clamp (0, cc);
                    count = count.clamp (0, cc - start);
                    return new SheetValue.text (t.substring (t.index_of_nth_char (start), t.index_of_nth_char (start + count) - t.index_of_nth_char (start)));
                case "UPPER":
                    var uv = arg (n, 0, ctx);
                    return uv != null ? new SheetValue.text (uv.as_string ().up ()) : null;
                case "LOWER":
                    var dv = arg (n, 0, ctx);
                    return dv != null ? new SheetValue.text (dv.as_string ().down ()) : null;
                case "CHAR":
                    return new SheetValue.text (((unichar) (int) narg (n, 0, ctx)).to_string ());
                case "FORMAT":
                case "FORMATEX":
                    var fv = arg (n, 0, ctx);
                    return fv != null ? new SheetValue.text (fv.as_string ()) : null;
                case "RGB":
                    return new SheetValue.text (Colors.to_hex (Rgba (narg (n, 0, ctx).clamp (0, 255) / 255, narg (n, 1, ctx).clamp (0, 255) / 255, narg (n, 2, ctx).clamp (0, 255) / 255, 1)));
                case "HSL":
                    return new SheetValue.text (hsl_hex (narg (n, 0, ctx), narg (n, 1, ctx), narg (n, 2, ctx)));
                case "LUM":
                    Rgba lc;
                    if (!parse_color (arg (n, 0, ctx), out lc)) return null;
                    return number (Math.round ((double.max (double.max (lc.r, lc.g), lc.b) + double.min (double.min (lc.r, lc.g), lc.b)) / 2 * 240));
                case "TINT":
                case "SHADE":
                    Rgba tc;
                    var colv = arg (n, 0, ctx);
                    if (!parse_color (colv, out tc)) return null;
                    double amt = (narg (n, 1, ctx) / 240).clamp (0, 1);
                    return new SheetValue.text (Colors.rgb_hex (Colors.mix (Colors.to_hex (tc), n.text == "TINT" ? "#ffffff" : "#000000", amt)));
                case "BLEND":
                    Rgba b1, b2;
                    bool ok1 = parse_color (arg (n, 0, ctx), out b1);
                    bool ok2 = parse_color (arg (n, 1, ctx), out b2);
                    if (!ok1 || !ok2) return null;
                    return new SheetValue.text (Colors.rgb_hex (Colors.mix (Colors.to_hex (b1), Colors.to_hex (b2), narg (n, 2, ctx, 0.5).clamp (0, 1))));
                case "TEXTWIDTH":
                case "TEXTHEIGHT":
                    var txt = arg (n, 0, ctx);
                    if (txt == null) return null;
                    double cs = num (resolve (ctx, "Char.Size"), 12.0 / 72);
                    if (cs <= 0) cs = 12.0 / 72;
                    string[] lines = txt.as_string ().split ("\n");
                    int longest = 0;
                    foreach (string l in lines) longest = int.max (longest, l.char_count ());
                    double tw = longest * cs * 0.55;
                    if (n.text == "TEXTWIDTH") return number (n.args.size > 1 ? double.min (tw, narg (n, 1, ctx, tw)) : tw);
                    double wrap = n.args.size > 1 ? narg (n, 1, ctx, tw) : tw;
                    int rows = 0;
                    foreach (string l in lines) rows += int.max (1, (int) Math.ceil (l.char_count () * cs * 0.55 / double.max (wrap, 0.01)));
                    return number (rows * cs * 1.2);
                case "DEPENDSON":
                case "USE":
                case "OPENTEXTWIN":
                case "OPENGROUPWIN":
                case "OPENSHEETWIN":
                case "RUNADDON":
                case "RUNMACRO":
                case "DOCMD":
                case "CALLTHIS":
                case "PLAYSOUND":
                case "SHEETREF":
                case "RECALCTIME":
                    return number (0);
                case "BITAND":
                case "BITOR":
                case "BITXOR":
                    var ba = arg (n, 0, ctx);
                    var bb = arg (n, 1, ctx);
                    if (ba == null || bb == null) return null;
                    int64 ia = (int64) ba.as_number (), ib = (int64) bb.as_number ();
                    return number (n.text == "BITAND" ? (ia & ib) : (n.text == "BITOR" ? (ia | ib) : (ia ^ ib)));
                case "BITNOT":
                    var bn = arg (n, 0, ctx);
                    return bn != null ? number (~((int64) bn.as_number ())) : null;
                case "INTUP":
                    return number (Math.ceil (narg (n, 0, ctx)));
                case "LUMDIFF":
                    Rgba l1, l2;
                    bool okl1 = parse_color (arg (n, 0, ctx), out l1);
                    bool okl2 = parse_color (arg (n, 1, ctx), out l2);
                    if (!okl1 || !okl2) return null;
                    double y1 = (double.max (double.max (l1.r, l1.g), l1.b) + double.min (double.min (l1.r, l1.g), l1.b)) / 2 * 240;
                    double y2 = (double.max (double.max (l2.r, l2.g), l2.b) + double.min (double.min (l2.r, l2.g), l2.b)) / 2 * 240;
                    return number (y1 - y2);
                case "NOW":
                    return number (new DateTime.now_local ().to_unix () / 86400.0 + 25569);
                default:
                    return null;
            }
        }

        public static double cell_number (SheetContext ctx, SheetSection sec, SheetRow row, string name, double fallback) {
            var v = row_cell (ctx, sec, row, name);
            if (v == null) return fallback;
            if (v.is_text) {
                double d;
                if (!double.try_parse (v.str.strip (), out d)) return fallback;
                return d;
            }
            return v.num;
        }

        private static double section_number (SheetContext ctx, SheetSection sec, string name, double fallback) {
            var c = sec.get_cell (name);
            if (c == null) return fallback;
            var v = eval_cell (ctx, c, "%s#%d/%s".printf (sec.name, sec.ix, name));
            return v != null ? v.as_number () : fallback;
        }

        public static void arc3 (PathData p, double sx, double sy, double mx, double my, double ex, double ey) {
            double d = 2 * (sx * (my - ey) + mx * (ey - sy) + ex * (sy - my));
            if (d.abs () < 1e-12) {
                p.line_to (ex, ey);
                return;
            }
            double s2 = sx * sx + sy * sy, m2 = mx * mx + my * my, e2 = ex * ex + ey * ey;
            double cx = (s2 * (my - ey) + m2 * (ey - sy) + e2 * (sy - my)) / d;
            double cy = (s2 * (ex - mx) + m2 * (sx - ex) + e2 * (mx - sx)) / d;
            double r = Math.hypot (sx - cx, sy - cy);
            double a0 = Math.atan2 (sy - cy, sx - cx);
            double am = Math.atan2 (my - cy, mx - cx);
            double a1 = Math.atan2 (ey - cy, ex - cx);
            double d1 = norm (a1 - a0), dm = norm (am - a0);
            double sweep = dm <= d1 ? d1 : d1 - 2 * Math.PI;
            int n = int.max (4, (int) Math.ceil (sweep.abs () / (Math.PI / 12)));
            for (int i = 1; i <= n; i++) {
                double t = a0 + sweep * i / n;
                if (i == n) p.line_to (ex, ey);
                else p.line_to (cx + r * Math.cos (t), cy + r * Math.sin (t));
            }
        }

        private static double norm (double a) {
            while (a < 0) a += 2 * Math.PI;
            while (a >= 2 * Math.PI) a -= 2 * Math.PI;
            return a;
        }

        public static void ell_arc (PathData p, double sx, double sy, double ax, double ay, double ex, double ey, double angle, double ratio) {
            if (ratio.abs () < 1e-9) ratio = 1;
            double ca = Math.cos (-angle), sa = Math.sin (-angle);
            double tsx = (sx * ca - sy * sa), tsy = (sx * sa + sy * ca) * ratio;
            double tax = (ax * ca - ay * sa), tay = (ax * sa + ay * ca) * ratio;
            double tex = (ex * ca - ey * sa), tey = (ex * sa + ey * ca) * ratio;
            var tmp = new PathData ();
            tmp.move_to (tsx, tsy);
            arc3 (tmp, tsx, tsy, tax, tay, tex, tey);
            double cb = Math.cos (angle), sb = Math.sin (angle);
            for (int i = 1; i < tmp.segs.size; i++) {
                var s = tmp.segs[i];
                double x = s.x, y = s.y / ratio;
                p.line_to (x * cb - y * sb, x * sb + y * cb);
            }
            var last = p.segs[p.segs.size - 1];
            last.x = ex;
            last.y = ey;
        }

        public static double[] formula_numbers (string? f) {
            double[] out_v = {};
            if (f == null) return out_v;
            int open = f.index_of ("(");
            int close = f.last_index_of (")");
            if (open < 0 || close < open) return out_v;
            foreach (string part in f.substring (open + 1, close - open - 1).split (",")) {
                string t = part.strip ();
                int sp = t.index_of (" ");
                if (sp > 0) t = t.substring (0, sp);
                double d = 0;
                if (double.try_parse (t, out d)) out_v += d;
                else out_v += 0;
            }
            return out_v;
        }

        private static void ensure_start (PathData p, ref bool started, double cx, double cy, ref double sx, ref double sy) {
            if (started) return;
            p.move_to (cx, cy);
            sx = cx;
            sy = cy;
            started = true;
        }

        private static void close_if (PathData p, double cx, double cy, double sx, double sy, bool started) {
            if (!started || p.segs.size < 2) return;
            var last = p.segs[p.segs.size - 1];
            if (last.kind == SegKind.CLOSE || last.kind == SegKind.MOVE) return;
            if ((cx - sx).abs () < 1e-7 && (cy - sy).abs () < 1e-7) p.close ();
        }

        public static void add_ellipse (PathData p, double x, double y, double a, double b, double c, double d) {
            double ux = a - x, uy = b - y, vx = c - x, vy = d - y;
            double k = PathData.KAPPA;
            p.move_to (x + ux, y + uy);
            p.curve_to (x + ux + k * vx, y + uy + k * vy, x + vx + k * ux, y + vy + k * uy, x + vx, y + vy);
            p.curve_to (x + vx - k * ux, y + vy - k * uy, x - ux + k * vx, y - uy + k * vy, x - ux, y - uy);
            p.curve_to (x - ux - k * vx, y - uy - k * vy, x - vx - k * ux, y - vy - k * uy, x - vx, y - vy);
            p.curve_to (x - vx + k * ux, y - vy + k * uy, x + ux - k * vx, y + uy - k * vy, x + ux, y + uy);
            p.close ();
        }

        private static string? raw_formula (SheetRow r, string name) {
            var c = r.get_cell (name);
            if (c == null) return null;
            return c.formula ?? c.value;
        }

        public static PathData section_path (SheetContext ctx, SheetSection sec, double w, double h) {
            var p = new PathData ();
            double cx = 0, cy = 0, sx = 0, sy = 0;
            bool started = false;
            var rows = new Gee.ArrayList<SheetRow> ();
            rows.add_all (sec.rows);
            rows.sort ((a, b) => a.ix - b.ix);
            foreach (var r in rows) {
                if (r.deleted || r.kind == null) continue;
                double x = cell_number (ctx, sec, r, "X", 0), y = cell_number (ctx, sec, r, "Y", 0);
                switch (r.kind) {
                    case "MoveTo":
                    case "RelMoveTo":
                        if (r.kind == "RelMoveTo") {
                            x *= w;
                            y *= h;
                        }
                        close_if (p, cx, cy, sx, sy, started);
                        p.move_to (x, y);
                        cx = sx = x;
                        cy = sy = y;
                        started = true;
                        continue;
                    case "LineTo":
                    case "RelLineTo":
                    case "SplineStart":
                    case "SplineKnot":
                        if (r.kind == "RelLineTo") {
                            x *= w;
                            y *= h;
                        }
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        p.line_to (x, y);
                        break;
                    case "ArcTo":
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        double bow = cell_number (ctx, sec, r, "A", 0);
                        double dx = x - cx, dy = y - cy, len = Math.hypot (dx, dy);
                        if (bow.abs () < 1e-9 || len < 1e-9) {
                            p.line_to (x, y);
                        } else {
                            double mx = (cx + x) / 2 + bow * dy / len, my = (cy + y) / 2 - bow * dx / len;
                            arc3 (p, cx, cy, mx, my, x, y);
                        }
                        break;
                    case "EllipticalArcTo":
                    case "RelEllipticalArcTo":
                        double ax = cell_number (ctx, sec, r, "A", 0), ay = cell_number (ctx, sec, r, "B", 0);
                        if (r.kind == "RelEllipticalArcTo") {
                            x *= w;
                            y *= h;
                            ax *= w;
                            ay *= h;
                        }
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        ell_arc (p, cx, cy, ax, ay, x, y, cell_number (ctx, sec, r, "C", 0), cell_number (ctx, sec, r, "D", 1));
                        break;
                    case "CubBezTo":
                    case "RelCubBezTo":
                        double a1 = cell_number (ctx, sec, r, "A", 0), b1 = cell_number (ctx, sec, r, "B", 0);
                        double c1 = cell_number (ctx, sec, r, "C", 0), d1 = cell_number (ctx, sec, r, "D", 0);
                        if (r.kind == "RelCubBezTo") {
                            x *= w;
                            y *= h;
                            a1 *= w;
                            b1 *= h;
                            c1 *= w;
                            d1 *= h;
                        }
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        p.curve_to (a1, b1, c1, d1, x, y);
                        break;
                    case "QuadBezTo":
                    case "RelQuadBezTo":
                        double qa = cell_number (ctx, sec, r, "A", 0), qb = cell_number (ctx, sec, r, "B", 0);
                        if (r.kind == "RelQuadBezTo") {
                            x *= w;
                            y *= h;
                            qa *= w;
                            qb *= h;
                        }
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        p.curve_to (cx + 2.0 / 3 * (qa - cx), cy + 2.0 / 3 * (qb - cy), x + 2.0 / 3 * (qa - x), y + 2.0 / 3 * (qb - y), x, y);
                        break;
                    case "NURBSTo":
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        var nums = formula_numbers (raw_formula (r, "E"));
                        if (nums.length >= 4) {
                            bool xrel = nums[2] == 0, yrel = nums[3] == 0;
                            for (int i = 4; i + 1 < nums.length; i += 4) p.line_to (xrel ? nums[i] * w : nums[i], yrel ? nums[i + 1] * h : nums[i + 1]);
                        }
                        p.line_to (x, y);
                        break;
                    case "PolylineTo":
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        var pn = formula_numbers (raw_formula (r, "A"));
                        if (pn.length >= 2) {
                            bool xrel = pn[0] == 0, yrel = pn[1] == 0;
                            for (int i = 2; i + 1 < pn.length; i += 2) p.line_to (xrel ? pn[i] * w : pn[i], yrel ? pn[i + 1] * h : pn[i + 1]);
                        }
                        p.line_to (x, y);
                        break;
                    case "Ellipse":
                        close_if (p, cx, cy, sx, sy, started);
                        add_ellipse (p, x, y, cell_number (ctx, sec, r, "A", 0), cell_number (ctx, sec, r, "B", 0), cell_number (ctx, sec, r, "C", 0), cell_number (ctx, sec, r, "D", 0));
                        started = false;
                        cx = sx = x;
                        cy = sy = y;
                        continue;
                    default:
                        continue;
                }
                cx = x;
                cy = y;
            }
            close_if (p, cx, cy, sx, sy, started);
            return p;
        }

        public static Gee.ArrayList<GeomPart> geometry_parts (SheetContext ctx, double w, double h, double ppi) {
            var parts = new Gee.ArrayList<GeomPart> ();
            var to_local = Cairo.Matrix (ppi, 0, 0, -ppi, 0, h * ppi);
            foreach (var sec in ctx.sheet.sections_named ("Geometry")) {
                if (section_number (ctx, sec, "NoShow", 0) != 0) continue;
                bool no_fill = section_number (ctx, sec, "NoFill", 0) != 0;
                bool no_line = section_number (ctx, sec, "NoLine", 0) != 0;
                if (no_fill && no_line) continue;
                var path = section_path (ctx, sec, w, h);
                if (path.is_empty ()) continue;
                path.transform (to_local);
                bool closed = path.has_closed_subpath ();
                PartMode mode;
                if (!closed || no_fill) mode = PartMode.STROKE;
                else if (no_line) mode = PartMode.FILL_ONLY;
                else mode = PartMode.FILL_STROKE;
                parts.add (new GeomPart (path, mode));
            }
            return parts;
        }

        public static bool is_smart_formula (string? f) {
            if (f == null) return false;
            foreach (string k in new string[] { "Controls.", "Scratch.", "User.", "Prop.", "Sheet.", "Geometry", "Actions.", "Connections.", "IF(", "BOUND(", "INDEX(", "MIN(", "MAX(" }) {
                if (f.contains (k)) return true;
            }
            return false;
        }

        public static bool needs_sheet_shape (ShapeSheet sheet) {
            var ctl = sheet.section ("Controls");
            if (ctl != null && ctl.rows.size > 0) return true;
            foreach (var sec in sheet.sections_named ("Geometry")) {
                foreach (var c in sec.cells) if (c.has_formula () && is_smart_formula (c.formula)) return true;
                foreach (var r in sec.rows) foreach (var c in r.cells) if (c.has_formula () && is_smart_formula (c.formula)) return true;
            }
            return false;
        }

        public static Geometry geometry (SheetShape s) {
            var g = new Geometry ();
            var sheet = s.sheet;
            double pad = 4;
            g.text_rect = Rect (pad, pad, double.max (s.w - 2 * pad, 1), double.max (s.h - 2 * pad, 1));
            if (sheet == null) {
                g.add (new PathData.rect (0, 0, s.w, s.h));
                return g;
            }
            var ctx = new SheetContext (sheet, s, null);
            double ppi = ctx.ppi ();
            double w = s.w / ppi, h = s.h / ppi;
            ctx.w_override = w;
            ctx.h_override = h;
            g.parts.add_all (geometry_parts (ctx, w, h, ppi));
            if (sheet.get_cell ("TxtWidth") != null) {
                double tw = num (resolve (ctx, "TxtWidth"), w), th = num (resolve (ctx, "TxtHeight"), h);
                double tpx = num (resolve (ctx, "TxtPinX"), w / 2), tpy = num (resolve (ctx, "TxtPinY"), h / 2);
                double tlx = num (resolve (ctx, "TxtLocPinX"), tw / 2), tly = num (resolve (ctx, "TxtLocPinY"), th / 2);
                if (tw > 0 && th > 0) g.text_rect = Rect ((tpx - tlx) * ppi, (h - (tpy - tly + th)) * ppi, tw * ppi, th * ppi);
            }
            return g;
        }

        private static bool set_if_plain (ShapeSheet sh, string name, double v) {
            var c = sh.get_cell (name);
            if (c == null || c.has_formula ()) return false;
            c.value = Vsdx.num (v);
            c.inherited = false;
            return true;
        }

        private static bool approximate (string f) {
            return f.contains ("TEXTWIDTH") || f.contains ("TEXTHEIGHT") || f.contains ("THEMEVAL") || f.contains ("EndX") || f.contains ("BeginX");
        }

        public static void recalc_item (Item it, Page? page) {
            var sh = it.sheet;
            if (sh == null) return;
            var s = it as Shape;
            if (it is Connector || it is Group) s = null;
            double ppi = sh.ppi > 0 ? sh.ppi : Units.PX_PER_IN;
            if (s != null) {
                set_if_plain (sh, "Width", s.w / ppi);
                set_if_plain (sh, "Height", s.h / ppi);
                if (!sh.nested) {
                    set_if_plain (sh, "Angle", -s.rotation * Math.PI / 180);
                    set_if_plain (sh, "FlipX", s.flip_h ? 1 : 0);
                    set_if_plain (sh, "FlipY", s.flip_v ? 1 : 0);
                }
            }
            var ctx = new SheetContext (sh, it, page);
            foreach (var c in sh.cells) {
                if (!c.has_formula ()) continue;
                var v = eval_cell (ctx, c, "@" + c.name);
                if (v != null) c.value = v.as_string ();
            }
            foreach (var sec in sh.sections) {
                foreach (var c in sec.cells) {
                    if (!c.has_formula ()) continue;
                    var v = eval_cell (ctx, c, "%s#%d/%s".printf (sec.name, sec.ix, c.name));
                    if (v != null) c.value = v.as_string ();
                }
                foreach (var r in sec.rows) {
                    if (r.deleted) continue;
                    foreach (var c in r.cells) {
                        if (!c.has_formula ()) continue;
                        var v = row_cell (ctx, sec, r, c.name);
                        if (v != null) c.value = v.as_string ();
                    }
                }
            }
            if (s == null) return;
            var wc = sh.get_cell ("Width");
            var hc = sh.get_cell ("Height");
            double cxp = s.cx (), cyp = s.cy ();
            bool moved = false;
            if (!sh.nested && wc != null && wc.has_formula () && !approximate (wc.formula)) {
                double nw = wc.number (s.w / ppi) * ppi;
                if (nw > 0 && (nw - s.w).abs () > 1e-6) {
                    s.w = nw;
                    moved = true;
                }
            }
            if (!sh.nested && hc != null && hc.has_formula () && !approximate (hc.formula)) {
                double nh = hc.number (s.h / ppi) * ppi;
                if (nh > 0 && (nh - s.h).abs () > 1e-6) {
                    s.h = nh;
                    moved = true;
                }
            }
            if (!sh.nested) {
                var ac = sh.get_cell ("Angle");
                if (ac != null && ac.has_formula ()) s.rotation = Document.normalize_angle (-ac.number (0) * 180 / Math.PI);
                var px = sh.get_cell ("PinX");
                var py = sh.get_cell ("PinY");
                if (px != null && px.has_formula ()) {
                    cxp = px.number (cxp / ppi) * ppi;
                    moved = true;
                }
                if (py != null && py.has_formula () && page != null) {
                    cyp = page.height - py.number ((page.height - cyp) / ppi) * ppi;
                    moved = true;
                }
            }
            if (moved) {
                s.x = cxp - s.w / 2;
                s.y = cyp - s.h / 2;
            }
            if (!sh.nested) {
                set_if_plain (sh, "PinX", s.cx () / ppi);
                if (page != null) set_if_plain (sh, "PinY", (page.height - s.cy ()) / ppi);
            }
        }

        public static void recalc_page (Page page) {
            foreach (var it in page.all_items ()) {
                if (it.sheet != null && !it.sheet.is_empty ()) recalc_item (it, page);
            }
        }

        public static Point[] control_points (Shape s) {
            Point[] pts = {};
            if (s.sheet == null) return pts;
            var sec = s.sheet.section ("Controls");
            if (sec == null) return pts;
            var ctx = new SheetContext (s.sheet, s, null);
            double ppi = ctx.ppi ();
            double w = s.w / ppi, h = s.h / ppi;
            ctx.w_override = w;
            ctx.h_override = h;
            foreach (var r in sec.rows) {
                if (r.deleted) continue;
                double x = cell_number (ctx, sec, r, "X", 0), y = cell_number (ctx, sec, r, "Y", 0);
                pts += s.to_page (x * ppi, (h - y) * ppi);
            }
            return pts;
        }

        private static string? proportional (string? f, string dim, double v, double size) {
            if (f == null || size.abs () < 1e-9) return null;
            string t = f.strip ();
            if (!t.has_prefix (dim + "*")) return null;
            double d;
            if (!double.try_parse (t.substring (dim.length + 1).strip (), out d)) return null;
            return "%s*%s".printf (dim, PathData.fmt (v / size, 8));
        }

        private static void write_control (SheetRow r, string name, double v, string dim, double size) {
            var c = r.get_cell (name);
            if (c == null) {
                r.set_cell (name, Vsdx.num (v));
                return;
            }
            if (c.formula != null && c.formula.has_prefix ("GUARD")) return;
            c.formula = proportional (c.formula, dim, v, size);
            c.value = Vsdx.num (v);
            c.inherited = false;
        }

        public static void move_control (Shape s, int index, double page_x, double page_y) {
            if (s.sheet == null) return;
            var sec = s.sheet.section ("Controls");
            if (sec == null) return;
            var rows = new Gee.ArrayList<SheetRow> ();
            foreach (var r in sec.rows) if (!r.deleted) rows.add (r);
            if (index < 0 || index >= rows.size) return;
            var row = rows[index];
            double ppi = s.sheet.ppi > 0 ? s.sheet.ppi : Units.PX_PER_IN;
            double w = s.w / ppi, h = s.h / ppi;
            var l = s.to_local (page_x, page_y);
            double x = l.x / ppi, y = h - l.y / ppi;
            write_control (row, "X", x, "Width", w);
            write_control (row, "Y", y, "Height", h);
            recalc_item (s, null);
        }
    }
}
