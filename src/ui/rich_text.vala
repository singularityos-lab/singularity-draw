using Gtk;

namespace Singularity.Apps.Draw {

    public class RichText {
        public static double zoom = 1;

        public static void setup (TextBuffer buffer) {
            var table = buffer.tag_table;
            if (table.lookup ("bold") != null) return;
            buffer.create_tag ("bold", "weight", Pango.Weight.BOLD);
            buffer.create_tag ("italic", "style", Pango.Style.ITALIC);
            buffer.create_tag ("underline", "underline", Pango.Underline.SINGLE);
            buffer.create_tag ("strike", "strikethrough", true);
            buffer.create_tag ("big", "scale", 1.3);
        }

        public static void toggle (TextBuffer buffer, string name) {
            setup (buffer);
            TextIter a, b;
            if (!buffer.get_selection_bounds (out a, out b)) return;
            var tag = buffer.tag_table.lookup (name);
            if (tag == null) return;
            bool all = true;
            var it = a;
            while (it.compare (b) < 0) {
                if (!it.has_tag (tag)) {
                    all = false;
                    break;
                }
                it.forward_char ();
            }
            if (all) buffer.remove_tag (tag, a, b);
            else buffer.apply_tag (tag, a, b);
        }

        private static TextTag value_tag (TextBuffer buffer, string prefix, string value) {
            string name = prefix + value;
            var tag = buffer.tag_table.lookup (name);
            if (tag != null) return tag;
            switch (prefix) {
                case "fg:":
                    var c = Gdk.RGBA ();
                    c.parse (value);
                    tag = buffer.create_tag (name, "foreground-rgba", c);
                    break;
                case "fam:":
                    tag = buffer.create_tag (name, "family", value);
                    break;
                default:
                    tag = buffer.create_tag (name, "size-points", double.parse (value) * zoom);
                    break;
            }
            return tag;
        }

        private static void clear_prefix (TextBuffer buffer, string prefix, TextIter a, TextIter b) {
            var doomed = new Gee.ArrayList<TextTag> ();
            buffer.tag_table.foreach ((t) => {
                if (t.name != null && t.name.has_prefix (prefix)) doomed.add (t);
            });
            foreach (var t in doomed) buffer.remove_tag (t, a, b);
        }

        public static bool apply_value (TextBuffer buffer, string prefix, string value) {
            setup (buffer);
            TextIter a, b;
            if (!buffer.get_selection_bounds (out a, out b)) return false;
            clear_prefix (buffer, prefix, a, b);
            if (value != "") buffer.apply_tag (value_tag (buffer, prefix, value), a, b);
            return true;
        }

        public static bool set_color (TextBuffer buffer, string color) {
            return apply_value (buffer, "fg:", color == "" ? "" : Colors.rgb_hex (color));
        }

        public static bool set_family (TextBuffer buffer, string family) {
            return apply_value (buffer, "fam:", family);
        }

        public static bool set_size (TextBuffer buffer, double pt) {
            return apply_value (buffer, "sz:", pt > 0 ? RichRuns.fmt_size (pt) : "");
        }

        private static void read_format (TextIter it, TextRun r) {
            foreach (var t in it.get_tags ()) {
                string? n = t.name;
                if (n == null) continue;
                switch (n) {
                    case "bold": r.bold = true; break;
                    case "italic": r.italic = true; break;
                    case "underline": r.underline = true; break;
                    case "strike": r.strike = true; break;
                    case "big": r.big = true; break;
                    default:
                        if (n.has_prefix ("fg:")) r.color = n.substring (3);
                        else if (n.has_prefix ("fam:")) r.family = n.substring (4);
                        else if (n.has_prefix ("sz:")) r.size = double.parse (n.substring (3));
                        break;
                }
            }
        }

        public static Gee.ArrayList<TextRun> runs (TextBuffer buffer) {
            setup (buffer);
            var list = new Gee.ArrayList<TextRun> ();
            TextIter it;
            buffer.get_start_iter (out it);
            while (!it.is_end ()) {
                var r = new TextRun ();
                read_format (it, r);
                r.text = it.get_char ().to_string ();
                if (list.size > 0 && list[list.size - 1].same_format (r)) list[list.size - 1].text += r.text;
                else list.add (r);
                it.forward_char ();
            }
            return list;
        }

        public static TextRun? selection_format (TextBuffer buffer) {
            TextIter a, b;
            if (!buffer.get_selection_bounds (out a, out b)) {
                buffer.get_iter_at_mark (out a, buffer.get_insert ());
                if (!a.is_start ()) a.backward_char ();
            }
            var r = new TextRun ();
            read_format (a, r);
            return r;
        }

        public static string to_markup (TextBuffer buffer) {
            return RichRuns.markup_from (runs (buffer), buffer.text);
        }

        public static void load (TextBuffer buffer, string markup) {
            setup (buffer);
            var list = RichRuns.parse (markup);
            buffer.text = RichRuns.plain_text (list);
            int pos = 0;
            foreach (var r in list) {
                int n = r.text.char_count ();
                TextIter a, b;
                buffer.get_iter_at_offset (out a, pos);
                buffer.get_iter_at_offset (out b, pos + n);
                pos += n;
                if (r.bold) buffer.apply_tag_by_name ("bold", a, b);
                if (r.italic) buffer.apply_tag_by_name ("italic", a, b);
                if (r.underline) buffer.apply_tag_by_name ("underline", a, b);
                if (r.strike) buffer.apply_tag_by_name ("strike", a, b);
                if (r.big) buffer.apply_tag_by_name ("big", a, b);
                if (r.color != "") buffer.apply_tag (value_tag (buffer, "fg:", Colors.rgb_hex (r.color)), a, b);
                if (r.family != "") buffer.apply_tag (value_tag (buffer, "fam:", r.family), a, b);
                if (r.size > 0) buffer.apply_tag (value_tag (buffer, "sz:", RichRuns.fmt_size (r.size)), a, b);
            }
        }
    }
}
