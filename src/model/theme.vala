namespace Singularity.Apps.Draw {

    public enum QuickStyle {
        SUBTLE,
        REFINED,
        BALANCED,
        MODERATE,
        FOCUSED,
        INTENSE,
        OUTLINE;

        public string label () {
            switch (this) {
                case SUBTLE: return _("Subtle");
                case REFINED: return _("Refined");
                case BALANCED: return _("Balanced");
                case MODERATE: return _("Moderate");
                case FOCUSED: return _("Focused");
                case INTENSE: return _("Intense");
                default: return _("Outline");
            }
        }

        public static QuickStyle[] all () {
            return { SUBTLE, REFINED, BALANCED, MODERATE, FOCUSED, INTENSE, OUTLINE };
        }
    }

    public class Theme {
        public string id;
        public string name;
        public string dark = "#1e1e1e";
        public string light = "#ffffff";
        public string line = "#4a5561";
        public string[] accents = { "#3a6ea5", "#e07b39", "#5b9a4b", "#c44d58", "#8a63c9", "#2a9d8f" };
        public string font = "Sans";
        public string heading_font = "Sans";
        public int effects = 0;
        public string background = "#ffffff";
        public int variant_index = 0;

        public Theme (string id, string name) {
            this.id = id;
            this.name = name;
        }

        public Theme copy () {
            var t = new Theme (id, name);
            t.dark = dark;
            t.light = light;
            t.line = line;
            t.accents = accents;
            t.font = font;
            t.heading_font = heading_font;
            t.effects = effects;
            t.background = background;
            t.variant_index = variant_index;
            return t;
        }

        public static string[] variant_labels () {
            return { _("Standard"), _("Shifted"), _("Soft"), _("Dark") };
        }

        public Theme variant (int v) {
            var t = copy ();
            t.variant_index = v;
            switch (v) {
                case 1:
                    string[] rot = {};
                    for (int i = 0; i < 6; i++) rot += accents[(i + 2) % 6];
                    t.accents = rot;
                    break;
                case 2:
                    string[] soft = {};
                    foreach (string a in accents) soft += Colors.rgb_hex (Colors.mix (a, "#ffffff", 0.3));
                    t.accents = soft;
                    t.line = Colors.rgb_hex (Colors.mix (line, "#ffffff", 0.2));
                    t.effects = 0;
                    break;
                case 3:
                    string[] bright = {};
                    foreach (string a in accents) bright += Colors.rgb_hex (Colors.mix (a, "#ffffff", 0.15));
                    t.accents = bright;
                    t.background = Colors.rgb_hex (Colors.mix (dark, "#000000", 0.25));
                    t.line = Colors.rgb_hex (Colors.mix (light, dark, 0.25));
                    string d = t.dark;
                    t.dark = t.light;
                    t.light = d;
                    break;
            }
            return t;
        }

        public string color_at (int index) {
            if (index <= 0) return line;
            return accents[(index - 1) % 6];
        }

        public string[] palette () {
            string[] p = { dark, light, line };
            foreach (string a in accents) p += a;
            return p;
        }

        private static string shade (string c, double t) {
            return Colors.rgb_hex (Colors.mix (c, "#000000", t));
        }

        private string tint (string c, double t) {
            return Colors.rgb_hex (Colors.mix (c, light, t));
        }

        private string text_on (string fill) {
            return Colors.luminance (fill) > 0.55 ? (Colors.luminance (dark) < 0.5 ? dark : "#1e1e1e") : "#ffffff";
        }

        public void apply (Style st, bool connector) {
            if (st.theme_font) st.font_family = font;
            if (st.quick_color < 0) return;
            string accent = color_at (st.quick_color);
            if (connector) {
                st.stroke = st.quick_color == 0 ? line : accent;
                st.text_color = dark;
                if (st.quick_style >= QuickStyle.FOCUSED) st.stroke_width = double.max (st.stroke_width, 2);
                return;
            }
            var qs = (QuickStyle) st.quick_style.clamp (0, 6);
            st.shadow = false;
            switch (qs) {
                case QuickStyle.SUBTLE:
                    st.fill_kind = FillKind.SOLID;
                    st.fill = tint (accent, 0.82);
                    st.stroke = accent;
                    st.text_color = dark;
                    break;
                case QuickStyle.REFINED:
                    st.fill_kind = FillKind.SOLID;
                    st.fill = tint (accent, 0.6);
                    st.stroke = shade (accent, 0.2);
                    st.text_color = dark;
                    break;
                case QuickStyle.BALANCED:
                    st.fill_kind = FillKind.SOLID;
                    st.fill = accent;
                    st.stroke = shade (accent, 0.25);
                    st.text_color = text_on (accent);
                    break;
                case QuickStyle.MODERATE:
                    st.fill_kind = FillKind.LINEAR;
                    st.fill = tint (accent, 0.25);
                    st.fill2 = shade (accent, 0.1);
                    st.gradient_angle = 90;
                    st.stroke = shade (accent, 0.3);
                    st.text_color = text_on (accent);
                    break;
                case QuickStyle.FOCUSED:
                    st.fill_kind = FillKind.SOLID;
                    st.fill = shade (accent, 0.2);
                    st.stroke = shade (accent, 0.45);
                    st.text_color = "#ffffff";
                    st.shadow = true;
                    break;
                case QuickStyle.INTENSE:
                    st.fill_kind = FillKind.LINEAR;
                    st.fill = accent;
                    st.fill2 = shade (accent, 0.4);
                    st.gradient_angle = 90;
                    st.stroke = dark;
                    st.text_color = "#ffffff";
                    st.shadow = true;
                    break;
                default:
                    st.fill_kind = FillKind.SOLID;
                    st.fill = light;
                    st.stroke = accent;
                    st.stroke_width = double.max (st.stroke_width, 2);
                    st.text_color = shade (accent, 0.3);
                    break;
            }
            if (effects == 1 && qs >= QuickStyle.BALANCED) st.shadow = true;
            if (effects == 2 && qs >= QuickStyle.BALANCED && st.fill_kind == FillKind.SOLID) {
                st.fill_kind = FillKind.LINEAR;
                st.fill2 = shade (st.fill, 0.18);
                st.gradient_angle = 90;
            }
            if (st.shadow) st.shadow_color = "#00000040";
        }

        private static Theme make (string id, string name, string dark, string line, string[] accents, string font, int effects) {
            var t = new Theme (id, name);
            t.dark = dark;
            t.line = line;
            t.accents = accents;
            t.font = font;
            t.heading_font = font;
            t.effects = effects;
            return t;
        }

        private static Gee.ArrayList<Theme>? _all = null;

        public static Gee.ArrayList<Theme> builtin () {
            if (_all != null) return _all;
            var l = new Gee.ArrayList<Theme> ();
            l.add (make ("classic", _("Classic"), "#1e2a36", "#4a5561", { "#3a6ea5", "#e07b39", "#5b9a4b", "#c44d58", "#8a63c9", "#2a9d8f" }, "Sans", 0));
            l.add (make ("harbor", _("Harbor"), "#173042", "#3f5a6b", { "#1f6f8b", "#e6a400", "#0e9aa7", "#99a8b2", "#3da4ab", "#d1603d" }, "Sans", 1));
            l.add (make ("meadow", _("Meadow"), "#23351f", "#4f6448", { "#4c9a2a", "#a4c639", "#2e7d32", "#c5a100", "#6d8b3a", "#7fb685" }, "Sans", 0));
            l.add (make ("sunset", _("Sunset"), "#3a1f2b", "#6b4453", { "#e4572e", "#f3a712", "#a8201a", "#76323f", "#ec9a29", "#5e2b50" }, "Serif", 2));
            l.add (make ("graphite", _("Graphite"), "#1c1c1c", "#555555", { "#4d4d4d", "#7a7a7a", "#2b7bb9", "#a0a0a0", "#333333", "#e0a800" }, "Sans", 0));
            l.add (make ("orchid", _("Orchid"), "#2d1b36", "#5d4a6b", { "#8e44ad", "#d35d9b", "#5b3a8f", "#e384b7", "#b085f5", "#6c5b7b" }, "Sans", 1));
            l.add (make ("citrus", _("Citrus"), "#2b2a14", "#5c5a33", { "#e3b505", "#7cb518", "#f08a24", "#fb6107", "#5c8001", "#c9a227" }, "Sans", 2));
            l.add (make ("ocean", _("Ocean"), "#0b2239", "#34506b", { "#006494", "#13293d", "#1b98e0", "#247ba0", "#00a6a6", "#5bc0eb" }, "Sans", 1));
            l.add (make ("retro", _("Retro"), "#2e2a24", "#6d6457", { "#d9822b", "#3d7068", "#b56b45", "#8f8f45", "#43a2a4", "#a64942" }, "Serif", 0));
            l.add (make ("nordic", _("Nordic"), "#2e3440", "#4c566a", { "#5e81ac", "#88c0d0", "#a3be8c", "#bf616a", "#b48ead", "#d08770" }, "Sans", 0));
            l.add (make ("ember", _("Ember"), "#2a1414", "#5a3a3a", { "#b3261e", "#e25822", "#f2a541", "#7d1d1d", "#c9563c", "#8c4a2f" }, "Sans", 2));
            l.add (make ("blueprint", _("Blueprint"), "#0d2c54", "#2a4f7f", { "#1d4e89", "#00b2ca", "#7dcfb6", "#f79256", "#2e86ab", "#4a6fa5" }, "Monospace", 0));
            _all = l;
            return l;
        }

        public static Theme? find (string id, int variant = 0) {
            foreach (var t in builtin ()) if (t.id == id) return variant > 0 ? t.variant (variant) : t;
            return null;
        }

        public static void apply_document (Document doc) {
            var t = doc.theme ();
            if (t == null) return;
            foreach (var p in doc.pages) {
                foreach (var it in p.all_items ()) {
                    if (it is Group) continue;
                    t.apply (it.style, it is Connector);
                }
            }
        }

        public static void style_new_item (Document doc, Item it) {
            var t = doc.theme ();
            if (t == null) return;
            var s = it as Shape;
            if (it is Connector) {
                it.style.quick_color = 0;
                it.style.quick_style = 0;
            } else if (s != null) {
                if (s.kind == "text" || s is ImageShape || s.kind == "line-shape" || s is RasterItem) return;
                it.style.quick_color = 1;
                it.style.quick_style = s.is_container () ? QuickStyle.SUBTLE : QuickStyle.BALANCED;
            } else {
                return;
            }
            it.style.theme_font = true;
            t.apply (it.style, it is Connector);
        }
    }
}
