namespace Singularity.Apps.Draw {

    public errordomain FormatError {
        INVALID,
        UNSUPPORTED
    }

    public class XmlWriter {
        private StringBuilder sb = new StringBuilder ();
        private Gee.ArrayList<string> stack = new Gee.ArrayList<string> ();
        private bool tag_open = false;
        private bool pretty;
        private bool had_children = false;
        private Gee.ArrayList<bool> text_inside = new Gee.ArrayList<bool> ();

        public XmlWriter (bool declaration = true, bool pretty = false) {
            this.pretty = pretty;
            if (declaration) sb.append ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
        }

        public static string escape (string s, bool attribute = true) {
            var b = new StringBuilder.sized (s.length + 8);
            unichar c;
            int i = 0;
            while (s.get_next_char (ref i, out c)) {
                switch (c) {
                    case '&': b.append ("&amp;"); break;
                    case '<': b.append ("&lt;"); break;
                    case '>': b.append ("&gt;"); break;
                    case '"':
                        if (attribute) b.append ("&quot;");
                        else b.append_c ('"');
                        break;
                    case '\n':
                        if (attribute) b.append ("&#10;");
                        else b.append_c ('\n');
                        break;
                    case '\r':
                        b.append ("&#13;");
                        break;
                    case '\t':
                        if (attribute) b.append ("&#9;");
                        else b.append_c ('\t');
                        break;
                    default:
                        if (c < 0x20) break;
                        b.append_unichar (c);
                        break;
                }
            }
            return b.str;
        }

        private void close_open () {
            if (tag_open) {
                sb.append_c ('>');
                tag_open = false;
            }
        }

        private void indent () {
            if (!pretty) return;
            if (text_inside.size > 0 && text_inside[text_inside.size - 1]) return;
            if (sb.len > 0 && sb.str[sb.len - 1] != '\n') sb.append_c ('\n');
            for (int i = 0; i < stack.size; i++) sb.append ("  ");
        }

        public XmlWriter start (string name) {
            close_open ();
            indent ();
            sb.append_c ('<');
            sb.append (name);
            stack.add (name);
            text_inside.add (false);
            tag_open = true;
            had_children = false;
            return this;
        }

        public XmlWriter attr (string name, string? value) {
            if (value == null) return this;
            sb.append_c (' ');
            sb.append (name);
            sb.append ("=\"");
            sb.append (escape (value));
            sb.append_c ('"');
            return this;
        }

        public XmlWriter attr_num (string name, double value, int decimals = 4) {
            return attr (name, PathData.fmt (value, decimals));
        }

        public XmlWriter text (string t) {
            close_open ();
            sb.append (escape (t, false));
            if (text_inside.size > 0) text_inside[text_inside.size - 1] = true;
            return this;
        }

        public XmlWriter raw (string t) {
            close_open ();
            sb.append (t);
            return this;
        }

        public XmlWriter end () {
            string name = stack.remove_at (stack.size - 1);
            bool had_text = text_inside.remove_at (text_inside.size - 1);
            if (tag_open) {
                sb.append ("/>");
                tag_open = false;
                return this;
            }
            if (pretty && !had_text) {
                sb.append_c ('\n');
                for (int i = 0; i < stack.size; i++) sb.append ("  ");
            }
            sb.append ("</");
            sb.append (name);
            sb.append_c ('>');
            return this;
        }

        public XmlWriter element (string name, string? text_value) {
            start (name);
            if (text_value != null && text_value != "") text (text_value);
            return end ();
        }

        public string finish () {
            while (stack.size > 0) end ();
            return sb.str;
        }
    }

    namespace XmlUtil {
        public Xml.Doc* parse (string text) throws FormatError {
            Xml.Doc* doc = Xml.Parser.read_memory (text, text.length, null, null,
                Xml.ParserOption.NONET | Xml.ParserOption.NOBLANKS | Xml.ParserOption.HUGE | Xml.ParserOption.RECOVER | Xml.ParserOption.NOERROR | Xml.ParserOption.NOWARNING);
            if (doc == null || doc->get_root_element () == null) {
                if (doc != null) delete doc;
                throw new FormatError.INVALID ("The file is not valid XML.");
            }
            return doc;
        }

        public unowned string local (Xml.Node* n) {
            return n->name;
        }

        public string? ns (Xml.Node* n) {
            return n->ns != null ? n->ns->href : null;
        }

        public bool is (Xml.Node* n, string name, string? ns_href = null) {
            if (n == null || n->type != Xml.ElementType.ELEMENT_NODE) return false;
            if (n->name != name) return false;
            if (ns_href == null) return true;
            return n->ns != null && n->ns->href == ns_href;
        }

        public string? attr (Xml.Node* n, string name, string? ns_href = null) {
            for (Xml.Attr* a = n->properties; a != null; a = a->next) {
                if (a->name != name) continue;
                if (ns_href != null && (a->ns == null || a->ns->href != ns_href)) continue;
                return a->children != null ? a->children->get_content () : "";
            }
            return null;
        }

        public string attr_or (Xml.Node* n, string name, string fallback, string? ns_href = null) {
            return attr (n, name, ns_href) ?? fallback;
        }

        public double attr_double (Xml.Node* n, string name, double fallback, string? ns_href = null) {
            string? v = attr (n, name, ns_href);
            if (v == null || v.strip () == "") return fallback;
            return double.parse (v);
        }

        public Gee.ArrayList<Xml.Node*> children (Xml.Node* n, string? name = null, string? ns_href = null) {
            var list = new Gee.ArrayList<Xml.Node*> ();
            if (n == null) return list;
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
                if (name != null && c->name != name) continue;
                if (ns_href != null && (c->ns == null || c->ns->href != ns_href)) continue;
                list.add (c);
            }
            return list;
        }

        public Xml.Node* child (Xml.Node* n, string name, string? ns_href = null) {
            if (n == null) return null;
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE || c->name != name) continue;
                if (ns_href != null && (c->ns == null || c->ns->href != ns_href)) continue;
                return c;
            }
            return null;
        }

        public Xml.Node* find (Xml.Node* n, string name, string? ns_href = null) {
            if (n == null) return null;
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
                if (c->name == name && (ns_href == null || (c->ns != null && c->ns->href == ns_href))) return c;
                var r = find (c, name, ns_href);
                if (r != null) return r;
            }
            return null;
        }

        public string text (Xml.Node* n) {
            if (n == null) return "";
            string? t = n->get_content ();
            return t ?? "";
        }
    }
}
