namespace Singularity.Apps.Draw {

    public class TextRun {
        public string text = "";
        public bool bold = false;
        public bool italic = false;
        public bool underline = false;
        public bool strike = false;
        public bool big = false;
        public string color = "";
        public string family = "";
        public double size = 0;

        public TextRun (string text = "") {
            this.text = text;
        }

        public TextRun copy_format (string text) {
            var r = new TextRun (text);
            r.bold = bold;
            r.italic = italic;
            r.underline = underline;
            r.strike = strike;
            r.big = big;
            r.color = color;
            r.family = family;
            r.size = size;
            return r;
        }

        public bool same_format (TextRun o) {
            return bold == o.bold && italic == o.italic && underline == o.underline && strike == o.strike && big == o.big
                && color.down () == o.color.down () && family == o.family && Math.fabs (size - o.size) < 0.01;
        }

        public bool is_plain () {
            return !bold && !italic && !underline && !strike && !big && color == "" && family == "" && size <= 0;
        }

        public string format_key () {
            return "%d%d%d%d%d|%s|%s|%.2f".printf ((int) bold, (int) italic, (int) underline, (int) strike, (int) big, color.down (), family, size);
        }

        public bool eff_bold (Style st) {
            return bold || st.bold;
        }

        public bool eff_italic (Style st) {
            return italic || st.italic;
        }

        public bool eff_underline (Style st) {
            return underline || st.underline;
        }

        public bool eff_strike (Style st) {
            return strike || st.strike;
        }

        public string eff_color (Style st) {
            return color != "" ? color : st.text_color;
        }

        public string eff_family (Style st) {
            return family != "" ? family : st.font_family;
        }

        public double eff_size (Style st) {
            double s = size > 0 ? size : st.font_size;
            return big ? s * 1.3 : s;
        }
    }

    namespace RichRuns {

        public Gee.ArrayList<TextRun> parse (string markup) {
            var runs = new Gee.ArrayList<TextRun> ();
            Pango.AttrList attrs;
            string plain;
            try {
                Pango.parse_markup (markup, -1, 0, out attrs, out plain, null);
            } catch (Error e) {
                runs.add (new TextRun (markup));
                return runs;
            }
            if (plain == "") return runs;
            var iter = attrs.get_iterator ();
            int covered = 0;
            do {
                int start, end;
                iter.range (out start, out end);
                if (end > plain.length) end = plain.length;
                if (start < covered) start = covered;
                if (start >= end) continue;
                if (start > covered) runs.add (new TextRun (plain.substring (covered, start - covered)));
                var r = new TextRun (plain.substring (start, end - start));
                foreach (unowned Pango.Attribute at in iter.get_attrs ()) {
                    switch (at.klass.type) {
                        case Pango.AttrType.WEIGHT:
                            r.bold = ((Pango.AttrInt) at).value >= Pango.Weight.SEMIBOLD;
                            break;
                        case Pango.AttrType.STYLE:
                            r.italic = ((Pango.AttrInt) at).value != Pango.Style.NORMAL;
                            break;
                        case Pango.AttrType.UNDERLINE:
                            r.underline = ((Pango.AttrInt) at).value != Pango.Underline.NONE;
                            break;
                        case Pango.AttrType.STRIKETHROUGH:
                            r.strike = ((Pango.AttrInt) at).value != 0;
                            break;
                        case Pango.AttrType.SCALE:
                            r.big = ((Pango.AttrFloat) at).value > 1.01;
                            break;
                        case Pango.AttrType.FOREGROUND:
                            unowned Pango.AttrColor ac = (Pango.AttrColor) at;
                            r.color = "#%02x%02x%02x".printf (ac.color.red >> 8, ac.color.green >> 8, ac.color.blue >> 8);
                            break;
                        case Pango.AttrType.FAMILY:
                            r.family = ((Pango.AttrString) at).value;
                            break;
                        case Pango.AttrType.SIZE:
                            r.size = ((Pango.AttrSize) at).size / (double) Pango.SCALE;
                            break;
                        case Pango.AttrType.ABSOLUTE_SIZE:
                            r.size = ((Pango.AttrSize) at).size / (double) Pango.SCALE / Units.PX_PER_PT;
                            break;
                        default:
                            break;
                    }
                }
                runs.add (r);
                covered = end;
            } while (iter.next ());
            if (covered < plain.length) runs.add (new TextRun (plain.substring (covered)));
            return normalize (runs);
        }

        public Gee.ArrayList<TextRun> normalize (Gee.List<TextRun> runs) {
            var out_runs = new Gee.ArrayList<TextRun> ();
            foreach (var r in runs) {
                if (r.text == "") continue;
                if (out_runs.size > 0 && out_runs[out_runs.size - 1].same_format (r)) {
                    out_runs[out_runs.size - 1].text += r.text;
                    continue;
                }
                out_runs.add (r.copy_format (r.text));
            }
            return out_runs;
        }

        public string plain_text (Gee.List<TextRun> runs) {
            var sb = new StringBuilder ();
            foreach (var r in runs) sb.append (r.text);
            return sb.str;
        }

        public bool any_format (Gee.List<TextRun> runs) {
            foreach (var r in runs) if (!r.is_plain ()) return true;
            return false;
        }

        public string to_markup (Gee.List<TextRun> runs) {
            var sb = new StringBuilder ();
            foreach (var r in normalize (runs)) {
                if (r.is_plain ()) {
                    sb.append (Markup.escape_text (r.text));
                    continue;
                }
                var span = new StringBuilder ();
                if (r.color != "") span.append (" foreground=\"%s\"".printf (Markup.escape_text (Colors.rgb_hex (r.color))));
                if (r.family != "") span.append (" font_family=\"%s\"".printf (Markup.escape_text (r.family)));
                if (r.size > 0) span.append (" size=\"%spt\"".printf (fmt_size (r.size)));
                string open = "", close = "";
                if (span.len > 0) {
                    open += "<span" + span.str + ">";
                    close = "</span>" + close;
                }
                if (r.bold) { open += "<b>"; close = "</b>" + close; }
                if (r.italic) { open += "<i>"; close = "</i>" + close; }
                if (r.underline) { open += "<u>"; close = "</u>" + close; }
                if (r.strike) { open += "<s>"; close = "</s>" + close; }
                if (r.big) { open += "<big>"; close = "</big>" + close; }
                sb.append (open).append (Markup.escape_text (r.text)).append (close);
            }
            return sb.str;
        }

        public string fmt_size (double v) {
            string s = "%.2f".printf (v);
            if (s.contains (".")) {
                while (s.has_suffix ("0")) s = s.substring (0, s.length - 1);
                if (s.has_suffix (".")) s = s.substring (0, s.length - 1);
            }
            return s;
        }

        public string markup_from (Gee.List<TextRun> runs, string text) {
            var n = normalize (runs);
            if (!any_format (n) || plain_text (n) != text) return "";
            return to_markup (n);
        }

        public Gee.ArrayList<TextRun> slice (Gee.List<TextRun> runs, int start, int len) {
            var out_runs = new Gee.ArrayList<TextRun> ();
            int pos = 0;
            int end = start + len;
            foreach (var r in runs) {
                int rs = pos, re = pos + r.text.length;
                pos = re;
                int a = int.max (rs, start), b = int.min (re, end);
                if (a >= b) continue;
                out_runs.add (r.copy_format (r.text.substring (a - rs, b - a)));
            }
            return out_runs;
        }

        public Gee.ArrayList<Gee.ArrayList<TextRun>> split_lines (Gee.List<TextRun> runs) {
            var lines = new Gee.ArrayList<Gee.ArrayList<TextRun>> ();
            var cur = new Gee.ArrayList<TextRun> ();
            foreach (var r in runs) {
                string[] parts = r.text.split ("\n");
                for (int i = 0; i < parts.length; i++) {
                    if (i > 0) {
                        lines.add (cur);
                        cur = new Gee.ArrayList<TextRun> ();
                    }
                    if (parts[i] != "") cur.add (r.copy_format (parts[i]));
                }
            }
            lines.add (cur);
            return lines;
        }

        private void put (Pango.AttrList list, owned Pango.Attribute at, uint s, uint e) {
            at.start_index = s;
            at.end_index = e;
            list.change ((owned) at);
        }

        public void apply (Pango.Layout layout, Gee.List<TextRun> runs) {
            var attrs = layout.get_attributes ();
            var list = attrs != null ? attrs.copy () : new Pango.AttrList ();
            int pos = 0;
            foreach (var r in runs) {
                uint s = pos, e = pos + r.text.length;
                pos += r.text.length;
                if (r.is_plain ()) continue;
                if (r.bold) put (list, Pango.attr_weight_new (Pango.Weight.BOLD), s, e);
                if (r.italic) put (list, Pango.attr_style_new (Pango.Style.ITALIC), s, e);
                if (r.underline) put (list, Pango.attr_underline_new (Pango.Underline.SINGLE), s, e);
                if (r.strike) put (list, Pango.attr_strikethrough_new (true), s, e);
                if (r.color != "") {
                    Rgba c;
                    if (Colors.parse (r.color, out c)) put (list, Pango.attr_foreground_new ((uint16) (c.r * 65535), (uint16) (c.g * 65535), (uint16) (c.b * 65535)), s, e);
                }
                if (r.family != "") put (list, Pango.attr_family_new (r.family), s, e);
                if (r.size > 0) put (list, Pango.AttrSize.new_absolute ((int) (r.size * Units.PX_PER_PT * Pango.SCALE)), s, e);
                if (r.big) put (list, Pango.attr_scale_new (1.3), s, e);
            }
            layout.set_attributes (list);
        }
    }
}
