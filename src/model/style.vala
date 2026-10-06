namespace Singularity.Apps.Draw {

    public enum FillKind {
        NONE,
        SOLID,
        LINEAR,
        RADIAL;

        public string to_id () {
            switch (this) {
                case NONE: return "none";
                case LINEAR: return "linear";
                case RADIAL: return "radial";
                default: return "solid";
            }
        }

        public static FillKind from_id (string s) {
            switch (s) {
                case "none": return NONE;
                case "linear": return LINEAR;
                case "radial": return RADIAL;
                default: return SOLID;
            }
        }
    }

    public enum DashKind {
        SOLID,
        DASH,
        DOT,
        DASH_DOT,
        LONG_DASH,
        DASH_DOT_DOT;

        public string to_id () {
            switch (this) {
                case DASH: return "dash";
                case DOT: return "dot";
                case DASH_DOT: return "dash-dot";
                case LONG_DASH: return "long-dash";
                case DASH_DOT_DOT: return "dash-dot-dot";
                default: return "solid";
            }
        }

        public static DashKind from_id (string s) {
            switch (s) {
                case "dash": return DASH;
                case "dot": return DOT;
                case "dash-dot": return DASH_DOT;
                case "long-dash": return LONG_DASH;
                case "dash-dot-dot": return DASH_DOT_DOT;
                default: return SOLID;
            }
        }

        public double[] pattern (double w) {
            double u = double.max (w, 1);
            switch (this) {
                case DASH: return { 4 * u, 3 * u };
                case DOT: return { u, 2 * u };
                case DASH_DOT: return { 5 * u, 2 * u, u, 2 * u };
                case LONG_DASH: return { 9 * u, 4 * u };
                case DASH_DOT_DOT: return { 5 * u, 2 * u, u, 2 * u, u, 2 * u };
                default: return {};
            }
        }
    }

    public enum ArrowKind {
        NONE,
        TRIANGLE,
        OPEN,
        STEALTH,
        DIAMOND,
        DIAMOND_OPEN,
        CIRCLE,
        CIRCLE_OPEN,
        BAR,
        TRIANGLE_OPEN,
        CROWS_FOOT,
        ONE;

        public string to_id () {
            switch (this) {
                case TRIANGLE: return "triangle";
                case OPEN: return "open";
                case STEALTH: return "stealth";
                case DIAMOND: return "diamond";
                case DIAMOND_OPEN: return "diamond-open";
                case CIRCLE: return "circle";
                case CIRCLE_OPEN: return "circle-open";
                case BAR: return "bar";
                case TRIANGLE_OPEN: return "triangle-open";
                case CROWS_FOOT: return "crows-foot";
                case ONE: return "one";
                default: return "none";
            }
        }

        public static ArrowKind from_id (string s) {
            switch (s) {
                case "triangle": return TRIANGLE;
                case "open": return OPEN;
                case "stealth": return STEALTH;
                case "diamond": return DIAMOND;
                case "diamond-open": return DIAMOND_OPEN;
                case "circle": return CIRCLE;
                case "circle-open": return CIRCLE_OPEN;
                case "bar": return BAR;
                case "triangle-open": return TRIANGLE_OPEN;
                case "crows-foot": return CROWS_FOOT;
                case "one": return ONE;
                default: return NONE;
            }
        }

        public static ArrowKind[] all () {
            return { NONE, TRIANGLE, OPEN, STEALTH, TRIANGLE_OPEN, DIAMOND, DIAMOND_OPEN, CIRCLE, CIRCLE_OPEN, BAR, CROWS_FOOT, ONE };
        }
    }

    public enum TextHAlign {
        LEFT,
        CENTER,
        RIGHT;

        public string to_id () {
            return this == LEFT ? "left" : (this == RIGHT ? "right" : "center");
        }

        public static TextHAlign from_id (string s) {
            return s == "left" || s == "start" ? LEFT : (s == "right" || s == "end" ? RIGHT : CENTER);
        }
    }

    public enum TextVAlign {
        TOP,
        MIDDLE,
        BOTTOM;

        public string to_id () {
            return this == TOP ? "top" : (this == BOTTOM ? "bottom" : "middle");
        }

        public static TextVAlign from_id (string s) {
            return s == "top" ? TOP : (s == "bottom" ? BOTTOM : MIDDLE);
        }
    }

    public struct Rgba {
        public double r;
        public double g;
        public double b;
        public double a;

        public Rgba (double r, double g, double b, double a = 1) {
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
        }

        public void apply (Cairo.Context cr, double opacity = 1) {
            cr.set_source_rgba (r, g, b, a * opacity);
        }
    }

    namespace Colors {
        public bool parse (string? s, out Rgba c) {
            c = Rgba (0, 0, 0, 1);
            if (s == null) return false;
            string t = s.strip ().down ();
            if (t == "" || t == "none" || t == "transparent") return false;
            if (t.has_prefix ("#")) {
                string h = t.substring (1);
                if (h.length == 3 || h.length == 4) {
                    var e = new StringBuilder ();
                    for (int i = 0; i < h.length; i++) {
                        e.append_c (h[i]);
                        e.append_c (h[i]);
                    }
                    h = e.str;
                }
                if (h.length != 6 && h.length != 8) return false;
                for (int i = 0; i < h.length; i++) if (!h[i].isxdigit ()) return false;
                c.r = hex2 (h, 0) / 255.0;
                c.g = hex2 (h, 2) / 255.0;
                c.b = hex2 (h, 4) / 255.0;
                c.a = h.length == 8 ? hex2 (h, 6) / 255.0 : 1;
                return true;
            }
            if (t.has_prefix ("rgb")) {
                int open = t.index_of ("("), close = t.index_of (")");
                if (open < 0 || close < open) return false;
                string[] parts = t.substring (open + 1, close - open - 1).replace ("/", ",").split_set (", ");
                double[] v = {};
                foreach (string p in parts) {
                    string q = p.strip ();
                    if (q == "") continue;
                    if (q.has_suffix ("%")) v += double.parse (q.substring (0, q.length - 1)) * (v.length < 3 ? 2.55 : 0.01);
                    else v += double.parse (q);
                }
                if (v.length < 3) return false;
                c.r = v[0] / 255.0;
                c.g = v[1] / 255.0;
                c.b = v[2] / 255.0;
                c.a = v.length > 3 ? v[3].clamp (0, 1) : 1;
                return true;
            }
            string? named = named_color (t);
            if (named != null) return parse (named, out c);
            return false;
        }

        private static int hex2 (string h, int i) {
            return h[i].xdigit_value () * 16 + h[i + 1].xdigit_value ();
        }

        public string to_hex (Rgba c, bool with_alpha = false) {
            int r = (int) Math.round (c.r.clamp (0, 1) * 255);
            int g = (int) Math.round (c.g.clamp (0, 1) * 255);
            int b = (int) Math.round (c.b.clamp (0, 1) * 255);
            if (with_alpha && c.a < 0.999) return "#%02x%02x%02x%02x".printf (r, g, b, (int) Math.round (c.a.clamp (0, 1) * 255));
            return "#%02x%02x%02x".printf (r, g, b);
        }

        public string rgb_hex (string s) {
            Rgba c;
            if (!parse (s, out c)) return "#000000";
            return to_hex (c, false);
        }

        public double alpha (string s) {
            Rgba c;
            if (!parse (s, out c)) return 0;
            return c.a;
        }

        public bool is_none (string? s) {
            Rgba c;
            return !parse (s, out c) || c.a <= 0;
        }

        public string mix (string a, string b, double t) {
            Rgba ca, cb;
            if (!parse (a, out ca)) return b;
            if (!parse (b, out cb)) return a;
            return to_hex (Rgba (ca.r + (cb.r - ca.r) * t, ca.g + (cb.g - ca.g) * t, ca.b + (cb.b - ca.b) * t, ca.a + (cb.a - ca.a) * t), true);
        }

        public double luminance (string s) {
            Rgba c;
            if (!parse (s, out c)) return 1;
            return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
        }

        public string? named_color (string n) {
            switch (n) {
                case "black": return "#000000";
                case "white": return "#ffffff";
                case "red": return "#ff0000";
                case "green": return "#008000";
                case "lime": return "#00ff00";
                case "blue": return "#0000ff";
                case "yellow": return "#ffff00";
                case "cyan": case "aqua": return "#00ffff";
                case "magenta": case "fuchsia": return "#ff00ff";
                case "gray": case "grey": return "#808080";
                case "silver": return "#c0c0c0";
                case "maroon": return "#800000";
                case "olive": return "#808000";
                case "navy": return "#000080";
                case "purple": return "#800080";
                case "teal": return "#008080";
                case "orange": return "#ffa500";
                case "pink": return "#ffc0cb";
                case "brown": return "#a52a2a";
                case "gold": return "#ffd700";
                case "lightgray": case "lightgrey": return "#d3d3d3";
                case "darkgray": case "darkgrey": return "#a9a9a9";
                case "lightblue": return "#add8e6";
                case "darkblue": return "#00008b";
                case "lightgreen": return "#90ee90";
                case "darkgreen": return "#006400";
                case "steelblue": return "#4682b4";
                case "tomato": return "#ff6347";
                case "coral": return "#ff7f50";
                case "salmon": return "#fa8072";
                case "khaki": return "#f0e68c";
                case "indigo": return "#4b0082";
                case "violet": return "#ee82ee";
                case "beige": return "#f5f5dc";
                case "ivory": return "#fffff0";
                case "crimson": return "#dc143c";
                case "skyblue": return "#87ceeb";
                case "slategray": case "slategrey": return "#708090";
                case "whitesmoke": return "#f5f5f5";
                case "gainsboro": return "#dcdcdc";
                default: return null;
            }
        }
    }

    public class Style : Object {
        public FillKind fill_kind = FillKind.SOLID;
        public string fill = "#ffffff";
        public string fill2 = "#cfe2f3";
        public double gradient_angle = 90;
        public string stroke = "#2e3436";
        public double stroke_width = 1.5;
        public DashKind dash = DashKind.SOLID;
        public ArrowKind arrow_start = ArrowKind.NONE;
        public ArrowKind arrow_end = ArrowKind.NONE;
        public double arrow_size = 1;
        public bool shadow = false;
        public string shadow_color = "#00000040";
        public double shadow_dx = 3;
        public double shadow_dy = 4;
        public double shadow_blur = 6;
        public double corner_radius = 0;
        public double opacity = 1;
        public string font_family = "Sans";
        public double font_size = 12;
        public bool bold = false;
        public bool italic = false;
        public bool underline = false;
        public bool strike = false;
        public string text_color = "#1e1e1e";
        public TextHAlign halign = TextHAlign.CENTER;
        public TextVAlign valign = TextVAlign.MIDDLE;
        public bool wrap = true;
        public int quick_color = -1;
        public int quick_style = -1;
        public bool theme_font = false;

        public Style copy () {
            var s = new Style ();
            s.assign (this);
            return s;
        }

        public void assign (Style o) {
            fill_kind = o.fill_kind;
            fill = o.fill;
            fill2 = o.fill2;
            gradient_angle = o.gradient_angle;
            stroke = o.stroke;
            stroke_width = o.stroke_width;
            dash = o.dash;
            arrow_start = o.arrow_start;
            arrow_end = o.arrow_end;
            arrow_size = o.arrow_size;
            shadow = o.shadow;
            shadow_color = o.shadow_color;
            shadow_dx = o.shadow_dx;
            shadow_dy = o.shadow_dy;
            shadow_blur = o.shadow_blur;
            corner_radius = o.corner_radius;
            opacity = o.opacity;
            font_family = o.font_family;
            font_size = o.font_size;
            bold = o.bold;
            italic = o.italic;
            underline = o.underline;
            strike = o.strike;
            text_color = o.text_color;
            halign = o.halign;
            valign = o.valign;
            wrap = o.wrap;
            quick_color = o.quick_color;
            quick_style = o.quick_style;
            theme_font = o.theme_font;
        }

        public void assign_appearance (Style o, bool include_arrows) {
            fill_kind = o.fill_kind;
            fill = o.fill;
            fill2 = o.fill2;
            gradient_angle = o.gradient_angle;
            stroke = o.stroke;
            stroke_width = o.stroke_width;
            dash = o.dash;
            if (include_arrows) {
                arrow_start = o.arrow_start;
                arrow_end = o.arrow_end;
                arrow_size = o.arrow_size;
            }
            shadow = o.shadow;
            shadow_color = o.shadow_color;
            shadow_dx = o.shadow_dx;
            shadow_dy = o.shadow_dy;
            shadow_blur = o.shadow_blur;
            corner_radius = o.corner_radius;
            opacity = o.opacity;
            font_family = o.font_family;
            font_size = o.font_size;
            bold = o.bold;
            italic = o.italic;
            underline = o.underline;
            strike = o.strike;
            text_color = o.text_color;
            halign = o.halign;
            valign = o.valign;
            quick_color = o.quick_color;
            quick_style = o.quick_style;
            theme_font = o.theme_font;
        }

        public bool has_stroke () {
            return stroke_width > 0 && !Colors.is_none (stroke);
        }

        public bool has_fill () {
            return fill_kind != FillKind.NONE && !(fill_kind == FillKind.SOLID && Colors.is_none (fill));
        }

        public string serialize () {
            var b = new StringBuilder ();
            add (b, "fill-kind", fill_kind.to_id ());
            add (b, "fill", fill);
            add (b, "fill2", fill2);
            add (b, "gradient-angle", PathData.fmt (gradient_angle, 3));
            add (b, "stroke", stroke);
            add (b, "stroke-width", PathData.fmt (stroke_width, 3));
            add (b, "dash", dash.to_id ());
            add (b, "arrow-start", arrow_start.to_id ());
            add (b, "arrow-end", arrow_end.to_id ());
            add (b, "arrow-size", PathData.fmt (arrow_size, 3));
            add (b, "shadow", shadow ? "1" : "0");
            add (b, "shadow-color", shadow_color);
            add (b, "shadow-dx", PathData.fmt (shadow_dx, 3));
            add (b, "shadow-dy", PathData.fmt (shadow_dy, 3));
            add (b, "shadow-blur", PathData.fmt (shadow_blur, 3));
            add (b, "corner-radius", PathData.fmt (corner_radius, 3));
            add (b, "opacity", PathData.fmt (opacity, 3));
            add (b, "font-family", font_family);
            add (b, "font-size", PathData.fmt (font_size, 3));
            add (b, "bold", bold ? "1" : "0");
            add (b, "italic", italic ? "1" : "0");
            add (b, "underline", underline ? "1" : "0");
            add (b, "strike", strike ? "1" : "0");
            add (b, "text-color", text_color);
            add (b, "halign", halign.to_id ());
            add (b, "valign", valign.to_id ());
            add (b, "wrap", wrap ? "1" : "0");
            if (quick_color >= 0) add (b, "quick-color", quick_color.to_string ());
            if (quick_style >= 0) add (b, "quick-style", quick_style.to_string ());
            if (theme_font) add (b, "theme-font", "1");
            return b.str;
        }

        private static void add (StringBuilder b, string k, string v) {
            if (b.len > 0) b.append_c (';');
            b.append (k);
            b.append_c (':');
            b.append (v.replace ("\\", "\\\\").replace (";", "\\;"));
        }

        public static Style deserialize (string text) {
            var s = new Style ();
            s.apply_serialized (text);
            return s;
        }

        public void apply_serialized (string text) {
            var parts = new Gee.ArrayList<string> ();
            var cur = new StringBuilder ();
            for (int i = 0; i < text.length; i++) {
                char c = text[i];
                if (c == '\\' && i + 1 < text.length) {
                    cur.append_c (text[++i]);
                } else if (c == ';') {
                    parts.add (cur.str);
                    cur.truncate ();
                } else {
                    cur.append_c (c);
                }
            }
            if (cur.len > 0) parts.add (cur.str);
            foreach (string p in parts) {
                int colon = p.index_of (":");
                if (colon < 0) continue;
                set_key (p.substring (0, colon), p.substring (colon + 1));
            }
        }

        public void set_key (string k, string v) {
            switch (k) {
                case "fill-kind": fill_kind = FillKind.from_id (v); break;
                case "fill": fill = v; break;
                case "fill2": fill2 = v; break;
                case "gradient-angle": gradient_angle = double.parse (v); break;
                case "stroke": stroke = v; break;
                case "stroke-width": stroke_width = double.parse (v); break;
                case "dash": dash = DashKind.from_id (v); break;
                case "arrow-start": arrow_start = ArrowKind.from_id (v); break;
                case "arrow-end": arrow_end = ArrowKind.from_id (v); break;
                case "arrow-size": arrow_size = double.parse (v); break;
                case "shadow": shadow = v == "1"; break;
                case "shadow-color": shadow_color = v; break;
                case "shadow-dx": shadow_dx = double.parse (v); break;
                case "shadow-dy": shadow_dy = double.parse (v); break;
                case "shadow-blur": shadow_blur = double.parse (v); break;
                case "corner-radius": corner_radius = double.parse (v); break;
                case "opacity": opacity = double.parse (v); break;
                case "font-family": font_family = v; break;
                case "font-size": font_size = double.parse (v); break;
                case "bold": bold = v == "1"; break;
                case "italic": italic = v == "1"; break;
                case "underline": underline = v == "1"; break;
                case "strike": strike = v == "1"; break;
                case "text-color": text_color = v; break;
                case "halign": halign = TextHAlign.from_id (v); break;
                case "valign": valign = TextVAlign.from_id (v); break;
                case "wrap": wrap = v == "1"; break;
                case "quick-color": quick_color = int.parse (v); break;
                case "quick-style": quick_style = int.parse (v); break;
                case "theme-font": theme_font = v == "1"; break;
            }
        }

        public bool equals (Style o) {
            return serialize () == o.serialize ();
        }
    }
}
