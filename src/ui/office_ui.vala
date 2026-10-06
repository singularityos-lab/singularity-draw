using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class OfficeUi {
        private static AppDialog make (DrawWindow win, string title, int width, int height) {
            var dlg = new AppDialog ((Gtk.Application) win.application, true);
            dlg.set_title (title);
            dlg.transient_for = win;
            dlg.set_default_size (width, height);
            dlg.add_css_class ("draw-dialog");
            return dlg;
        }

        private static Box body (AppDialog dlg) {
            var scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.vexpand = true;
            var box = new Box (Orientation.VERTICAL, 14);
            box.margin_start = box.margin_end = 18;
            box.margin_top = 6;
            box.margin_bottom = 12;
            scroll.child = box;
            dlg.content_box.append (scroll);
            return box;
        }

        private static Box footer_bar (AppDialog dlg) {
            var bar = new Box (Orientation.HORIZONTAL, 8);
            bar.margin_start = bar.margin_end = 18;
            bar.margin_bottom = 16;
            bar.margin_top = 4;
            var spacer = new Box (Orientation.HORIZONTAL, 0);
            spacer.hexpand = true;
            bar.append (spacer);
            dlg.content_box.append (bar);
            return bar;
        }

        private static Button footer (AppDialog dlg, string label, owned Dialogs.Apply apply) {
            var bar = footer_bar (dlg);
            var cancel = new Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => dlg.close ());
            dlg.set_cancel_button (cancel);
            var ok = new Button.with_label (label);
            ok.add_css_class ("suggested-action");
            ok.clicked.connect (() => {
                apply ();
                dlg.close ();
            });
            bar.append (cancel);
            bar.append (ok);
            dlg.default_widget = ok;
            return ok;
        }

        private static Button close_footer (AppDialog dlg) {
            var bar = footer_bar (dlg);
            var done = new Button.with_label (_("Done"));
            done.add_css_class ("suggested-action");
            done.clicked.connect (() => dlg.close ());
            bar.append (done);
            dlg.default_widget = done;
            return done;
        }

        private static Popover popover_at (Widget parent, double x, double y) {
            var pop = new Popover ();
            pop.set_parent (parent);
            var rect = Gdk.Rectangle ();
            rect.x = (int) x;
            rect.y = (int) y;
            rect.width = 1;
            rect.height = 1;
            pop.pointing_to = rect;
            pop.closed.connect (() => Idle.add (() => {
                pop.unparent ();
                return Source.REMOVE;
            }));
            return pop;
        }

        private static Box pad_box (int spacing = 10) {
            var box = new Box (Orientation.VERTICAL, spacing);
            box.margin_top = box.margin_bottom = 10;
            box.margin_start = box.margin_end = 10;
            return box;
        }

        private static Label heading (string text) {
            var l = new Label (text);
            l.add_css_class ("heading");
            l.halign = Align.START;
            return l;
        }

        public static void quick_shapes (DrawWindow win, Shape src, int dir, double sx, double sy) {
            var canvas = win.canvas;
            if (canvas == null) return;
            var pop = popover_at (canvas, sx, sy);
            pop.position = dir == 0 ? PositionType.TOP : (dir == 1 ? PositionType.RIGHT : (dir == 2 ? PositionType.BOTTOM : PositionType.LEFT));
            var box = new Box (Orientation.HORIZONTAL, 2);
            box.margin_top = box.margin_bottom = box.margin_start = box.margin_end = 4;
            string[] kinds = win.quick_kinds ();
            foreach (string k in kinds) {
                var e = ShapeLibrary.find (k);
                if (e == null) continue;
                var tile = new ShapeTile (e);
                string kind = k;
                tile.clicked.connect (() => {
                    pop.popdown ();
                    canvas.autoconnect_add (src, dir, kind);
                });
                box.append (tile);
            }
            pop.child = box;
            pop.popup ();
        }

        private static DrawingArea theme_swatch (Theme? t, int variant, int w, int h) {
            var area = new DrawingArea ();
            area.set_size_request (w, h);
            area.set_draw_func ((a, cr, ww, hh) => {
                var th = t != null ? t.variant (variant) : null;
                string bg = th != null ? (variant == 3 ? th.background : "#ffffff") : "#ffffff";
                Rgba c;
                Colors.parse (bg, out c);
                c.apply (cr);
                cr.rectangle (0, 0, ww, hh);
                cr.fill ();
                if (th == null) {
                    cr.set_source_rgb (0.3, 0.3, 0.3);
                    cr.set_line_width (1.2);
                    cr.rectangle (ww * 0.15, hh * 0.3, ww * 0.3, hh * 0.4);
                    cr.stroke ();
                    cr.arc (ww * 0.7, hh * 0.5, hh * 0.2, 0, 2 * Math.PI);
                    cr.stroke ();
                } else {
                    double bw = ww / 6.0;
                    for (int i = 0; i < 6; i++) {
                        Colors.parse (th.accents[i], out c);
                        c.apply (cr);
                        cr.rectangle (i * bw, hh * 0.62, bw, hh * 0.38);
                        cr.fill ();
                    }
                    Colors.parse (th.accents[0], out c);
                    c.apply (cr);
                    cr.rectangle (ww * 0.12, hh * 0.14, ww * 0.34, hh * 0.34);
                    cr.fill ();
                    Colors.parse (th.line, out c);
                    c.apply (cr);
                    cr.set_line_width (1.5);
                    cr.move_to (ww * 0.46, hh * 0.31);
                    cr.line_to (ww * 0.6, hh * 0.31);
                    cr.stroke ();
                    Colors.parse (th.accents[1], out c);
                    c.apply (cr);
                    cr.arc (ww * 0.74, hh * 0.31, hh * 0.18, 0, 2 * Math.PI);
                    cr.fill ();
                }
                cr.set_source_rgba (0, 0, 0, 0.25);
                cr.set_line_width (1);
                cr.rectangle (0.5, 0.5, ww - 1, hh - 1);
                cr.stroke ();
            });
            return area;
        }

        public static void apply_theme (DrawWindow win, string id, int variant) {
            var doc = win.doc;
            doc.begin (_("Theme"));
            bool first = doc.theme_id == "";
            doc.theme_id = id;
            doc.theme_variant = variant;
            var t = doc.theme ();
            if (t != null) {
                foreach (var p in doc.pages) {
                    var saved = doc.page_index;
                    foreach (var it in p.all_items ()) {
                        if (it is Group || it is RasterItem || it is ImageShape) continue;
                        if (it.style.quick_color < 0 && (first || it.style.theme_font)) {
                            var s = it as Shape;
                            if (s != null && (s.kind == "text" || s.kind == "line-shape")) {
                                it.style.theme_font = true;
                                continue;
                            }
                            it.style.quick_color = (it is Connector) ? 0 : 1;
                            it.style.quick_style = (it is Connector) ? 0 : (s != null && s.is_container () ? QuickStyle.SUBTLE : QuickStyle.BALANCED);
                            it.style.theme_font = true;
                        }
                    }
                    doc.page_index = saved;
                    if (variant == 3) p.background = t.background;
                    else if (Colors.luminance (p.background) < 0.5) p.background = "#ffffff";
                }
                Theme.apply_document (doc);
            }
            doc.commit ();
            win.inspector.refresh ();
        }

        public static void design_popover (DrawWindow win, Widget anchor) {
            var doc = win.doc;
            if (doc == null) return;
            var pop = new Popover ();
            pop.set_parent (anchor);
            pop.closed.connect (() => Idle.add (() => {
                pop.unparent ();
                return Source.REMOVE;
            }));
            var box = pad_box ();
            box.append (heading (_("Themes")));
            var flow = new FlowBox ();
            flow.selection_mode = SelectionMode.NONE;
            flow.max_children_per_line = 5;
            flow.min_children_per_line = 5;
            flow.column_spacing = 6;
            flow.row_spacing = 6;
            var themes = new Gee.ArrayList<Theme?> ();
            themes.add (null);
            themes.add_all (Theme.builtin ());
            if (doc.custom_theme != null) themes.add (doc.custom_theme);
            foreach (var t in themes) {
                var b = new Button ();
                b.add_css_class ("flat");
                b.add_css_class ("draw-theme-button");
                b.child = theme_swatch (t, 0, 64, 42);
                b.tooltip_text = t != null ? t.name : _("No Theme");
                string tid = t != null ? t.id : "";
                if (tid == doc.theme_id) b.add_css_class ("draw-theme-active");
                b.clicked.connect (() => {
                    pop.popdown ();
                    apply_theme (win, tid, 0);
                });
                flow.append (b);
            }
            box.append (flow);
            var cur = doc.theme ();
            if (cur != null) {
                box.append (heading (_("Variants")));
                var vbox = new Box (Orientation.HORIZONTAL, 6);
                string[] labels = Theme.variant_labels ();
                for (int v = 0; v < 4; v++) {
                    int variant = v;
                    var b = new Button ();
                    b.add_css_class ("flat");
                    b.add_css_class ("draw-theme-button");
                    b.child = theme_swatch (doc.theme_id == "file" ? doc.custom_theme : Theme.find (doc.theme_id), v, 64, 42);
                    b.tooltip_text = labels[v];
                    if (v == doc.theme_variant) b.add_css_class ("draw-theme-active");
                    b.clicked.connect (() => {
                        pop.popdown ();
                        apply_theme (win, doc.theme_id, variant);
                    });
                    vbox.append (b);
                }
                box.append (vbox);
            }
            box.append (heading (_("Quick Styles")));
            var qs_hint = new Label (win.canvas.selection.size > 0 ? _("Applies to the selected shapes") : _("Select shapes to style them"));
            qs_hint.add_css_class ("dim-label");
            qs_hint.halign = Align.START;
            box.append (qs_hint);
            var grid = new Grid ();
            grid.row_spacing = 4;
            grid.column_spacing = 4;
            var th = cur ?? Theme.builtin ()[0];
            var styles = QuickStyle.all ();
            for (int r = 0; r < styles.length; r++) {
                for (int c = 0; c < 7; c++) {
                    int qs = (int) styles[r], qc = c;
                    var st = new Style ();
                    st.quick_color = qc;
                    st.quick_style = qs;
                    th.apply (st, false);
                    var b = new Button ();
                    b.add_css_class ("flat");
                    b.add_css_class ("draw-quick-style");
                    b.tooltip_text = "%s %d".printf (styles[r].label (), c);
                    var area = new DrawingArea ();
                    area.set_size_request (30, 22);
                    area.set_draw_func ((a, cr, w, h) => {
                        var s = new Shape ("rounded-rectangle", 2, 2, w - 4, h - 4);
                        s.style = st;
                        s.style.corner_radius = 4;
                        s.style.shadow = false;
                        s.text = "Ab";
                        s.style.font_size = 7;
                        Renderer.draw_shape (cr, s, new RenderOptions ());
                    });
                    b.child = area;
                    b.sensitive = win.canvas.selection.size > 0;
                    b.clicked.connect (() => {
                        pop.popdown ();
                        apply_quick_style (win, qc, qs);
                    });
                    grid.attach (b, c, r);
                }
            }
            box.append (grid);
            var page_btn = new Button.with_label (_("Page Setup"));
            page_btn.clicked.connect (() => {
                pop.popdown ();
                win.run ("page-setup");
            });
            box.append (page_btn);
            var scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.propagate_natural_height = true;
            scroll.max_content_height = 640;
            scroll.child = box;
            pop.child = scroll;
            pop.popup ();
        }

        public static void apply_quick_style (DrawWindow win, int color, int style) {
            var doc = win.doc;
            var th = doc.theme () ?? Theme.builtin ()[0];
            doc.begin (_("Quick Style"));
            foreach (var it in win.canvas.selection) {
                var list = new Gee.ArrayList<Item> ();
                var g = it as Group;
                if (g != null) g.collect (list);
                else list.add (it);
                foreach (var x in list) {
                    if (x is Group) continue;
                    x.style.quick_color = color;
                    x.style.quick_style = style;
                    th.apply (x.style, x is Connector);
                }
            }
            doc.commit ();
            win.inspector.refresh ();
        }

        public static void validate (DrawWindow win) {
            var doc = win.doc;
            var dlg = make (win, _("Check Diagram"), 520, 600);
            var box = body (dlg);
            var sets = Validator.active_sets (doc);
            var rules_group = new PreferencesGroup (_("Rules"), _("Rules are chosen from the shapes on the drawing. Turn sets on or off to check against other notations."));
            var issues_group = new PreferencesGroup (_("Issues"));
            Dialogs.Apply fill = null;
            fill = () => {
                issues_group.clear ();
                var issues = Validator.run (doc, sets);
                issues_group.description = issues.size == 0 ? _("No issues found.") : ngettext ("%d issue", "%d issues", issues.size).printf (issues.size);
                int shown = 0;
                foreach (var issue in issues) {
                    if (shown++ > 300) break;
                    var page = doc.find_page (issue.page_id);
                    string where = page != null ? page.name : "";
                    var row = new ActionRow (issue.message, "%s, %s, %s".printf (issue.severity.label (), Validator.rule_set_label (issue.rule_set), where),
                        issue.severity == IssueSeverity.ERROR ? "dialog-error-symbolic" : "dialog-warning-symbolic");
                    var show = new Button.with_label (_("Show"));
                    show.valign = Align.CENTER;
                    show.clicked.connect (() => {
                        if (page != null && page != doc.page) win.switch_page (page);
                        var it = doc.page.find (issue.item_id);
                        if (it != null) {
                            win.canvas.select_one (it);
                            var b = it.bounds ();
                            win.canvas.center_on (b.cx (), b.cy ());
                        }
                    });
                    var ignore = new Button.with_label (_("Ignore"));
                    ignore.valign = Align.CENTER;
                    ignore.clicked.connect (() => {
                        doc.ignored_issues.add (issue.key ());
                        doc.modified = true;
                        fill ();
                    });
                    row.add_suffix (show);
                    row.add_suffix (ignore);
                    issues_group.add_row (row);
                }
            };
            foreach (string set in Validator.rule_sets ()) {
                string sid = set;
                var sw = new SwitchRow (Validator.rule_set_label (set), null, sets.contains (set));
                sw.notify["active"].connect (() => {
                    if (sw.active && !sets.contains (sid)) sets.add (sid);
                    if (!sw.active) sets.remove (sid);
                    doc.validation_rules = DataImport.join (",", sets);
                    if (doc.validation_rules == "") doc.validation_rules = "none";
                    doc.modified = true;
                    fill ();
                });
                rules_group.add_row (sw);
            }
            var clear = new Button.with_label (_("Show Ignored Issues"));
            clear.valign = Align.CENTER;
            clear.clicked.connect (() => {
                doc.ignored_issues.clear ();
                fill ();
            });
            rules_group.add_header_suffix (clear);
            box.append (rules_group);
            box.append (issues_group);
            fill ();
            close_footer (dlg);
            dlg.open_dialog ();
        }

        private class Misspelling {
            public Item item;
            public Page page;
            public string word;
            public int table_cell = -1;
        }

        private static bool word_char (unichar c) {
            return c.isalpha () || c == '\'' || c == '-';
        }

        public static Gee.ArrayList<string> words_of (string text) {
            var list = new Gee.ArrayList<string> ();
            var cur = new StringBuilder ();
            int i = 0;
            unichar c;
            while (true) {
                bool more = text.get_next_char (ref i, out c);
                if (more && word_char (c)) {
                    cur.append_unichar (c);
                    continue;
                }
                string w = cur.str;
                while (w.has_prefix ("'") || w.has_prefix ("-")) w = w.substring (1);
                while (w.has_suffix ("'") || w.has_suffix ("-")) w = w.substring (0, w.length - 1);
                if (w.char_count () > 1) list.add (w);
                cur.truncate ();
                if (!more) break;
            }
            return list;
        }

        public static void spelling (DrawWindow win) {
            var doc = win.doc;
            var sc = Singularity.Text.SpellChecker.get_default ();
            if (!sc.available) {
                win.show_error (_("No Dictionary"), _("Install a spelling dictionary for your language to check spelling."));
                return;
            }
            var found = new Gee.ArrayList<Misspelling> ();
            var ignored = new Gee.HashSet<string> ();
            foreach (var p in doc.pages) {
                foreach (var it in p.all_items ()) {
                    var texts = new Gee.ArrayList<string> ();
                    texts.add (it.text);
                    var tb = it as TableShape;
                    if (tb != null) texts.add_all (tb.cells);
                    foreach (string t in texts) {
                        foreach (string w in words_of (t)) {
                            if (sc.check (w)) continue;
                            var m = new Misspelling ();
                            m.item = it;
                            m.page = p;
                            m.word = w;
                            found.add (m);
                        }
                    }
                }
            }
            if (found.size == 0) {
                win.add_toast (new Toast (_("No spelling mistakes found")));
                return;
            }
            var dlg = make (win, _("Check Spelling"), 440, 520);
            var box = body (dlg);
            var group = new PreferencesGroup (_("Not in Dictionary"));
            var word_row = new ActionRow ("");
            group.add_row (word_row);
            var change = new EntryRow (_("Change To"));
            group.add_row (change);
            box.append (group);
            var sugg = new PreferencesGroup (_("Suggestions"));
            box.append (sugg);
            int index = -1;
            Dialogs.Apply next = null;
            var bar = footer_bar (dlg);
            var ignore = new Button.with_label (_("Ignore"));
            var ignore_all = new Button.with_label (_("Ignore All"));
            var add = new Button.with_label (_("Add to Dictionary"));
            var apply = new Button.with_label (_("Change"));
            apply.add_css_class ("suggested-action");
            bar.append (ignore);
            bar.append (ignore_all);
            bar.append (add);
            bar.append (apply);
            next = () => {
                index++;
                while (index < found.size && (ignored.contains (found[index].word) || sc.check (found[index].word))) index++;
                if (index >= found.size) {
                    dlg.close ();
                    win.add_toast (new Toast (_("Spelling check complete")));
                    return;
                }
                var m = found[index];
                if (m.page != doc.page) win.switch_page (m.page);
                win.canvas.select_one (m.item);
                var b = m.item.bounds ();
                win.canvas.center_on (b.cx (), b.cy ());
                word_row.title = m.word;
                word_row.subtitle = m.item.display_text ().replace ("\n", " ");
                sugg.clear ();
                string[] list = sc.suggest (m.word, 6);
                change.text = list.length > 0 ? list[0] : m.word;
                foreach (string s in list) {
                    string cand = s;
                    var r = new ActionRow (s);
                    var use = new Button.with_label (_("Use"));
                    use.valign = Align.CENTER;
                    use.clicked.connect (() => change.text = cand);
                    r.add_suffix (use);
                    sugg.add_row (r);
                }
            };
            ignore.clicked.connect (() => next ());
            ignore_all.clicked.connect (() => {
                ignored.add (found[index].word);
                next ();
            });
            add.clicked.connect (() => {
                sc.add_to_dictionary (found[index].word);
                next ();
            });
            apply.clicked.connect (() => {
                var m = found[index];
                string repl = change.text;
                doc.begin (_("Correct Spelling"));
                int n;
                m.item.text = Document.replace_in (m.item.text, m.word, repl, true, out n);
                var tb = m.item as TableShape;
                if (tb != null) for (int i = 0; i < tb.cells.size; i++) tb.cells[i] = Document.replace_in (tb.cells[i], m.word, repl, true, out n);
                doc.commit ();
                next ();
            });
            dlg.open_dialog ();
            next ();
        }

        public static void add_comment (DrawWindow win) {
            var doc = win.doc;
            var canvas = win.canvas;
            Item? target = canvas.selection.size > 0 ? canvas.selection[0] : null;
            var v = canvas.visible_rect ();
            Dialogs.rename (win, _("New Comment"), "", (text) => {
                var c = Comment.create (text);
                c.id = "c%d".printf ((int) (GLib.get_real_time () % 1000000000));
                if (target != null) c.item_id = target.id;
                else {
                    c.x = v.cx ();
                    c.y = v.cy ();
                }
                doc.begin (_("Add Comment"));
                doc.page.comments.add (c);
                doc.commit ();
            });
        }

        private static string when (int64 t) {
            var d = new DateTime.from_unix_local (t);
            return d.format ("%x %H:%M");
        }

        private static Widget comment_card (DrawWindow win, Comment root, Comment c, Popover? pop, bool reply) {
            var card = new Box (Orientation.VERTICAL, 2);
            card.add_css_class ("draw-comment");
            if (reply) card.margin_start = 18;
            var head = new Box (Orientation.HORIZONTAL, 6);
            var who = new Label (c.author);
            who.add_css_class ("heading");
            who.halign = Align.START;
            head.append (who);
            var time = new Label (when (c.time));
            time.add_css_class ("dim-label");
            time.add_css_class ("caption");
            time.hexpand = true;
            time.halign = Align.START;
            head.append (time);
            card.append (head);
            var text = new Label (c.text);
            text.wrap = true;
            text.wrap_mode = Pango.WrapMode.WORD_CHAR;
            text.xalign = 0;
            text.max_width_chars = 40;
            card.append (text);
            return card;
        }

        public static Widget thread (DrawWindow win, Comment c, Popover? pop) {
            var doc = win.doc;
            var box = new Box (Orientation.VERTICAL, 8);
            box.append (comment_card (win, c, c, pop, false));
            foreach (var r in c.replies) box.append (comment_card (win, c, r, pop, true));
            var entry = new Entry ();
            entry.placeholder_text = _("Reply");
            entry.activate.connect (() => {
                string t = entry.text.strip ();
                if (t == "") return;
                var r = Comment.create (t);
                r.id = c.id + "r%d".printf (c.replies.size + 1);
                doc.begin (_("Reply"));
                c.replies.add (r);
                doc.commit ();
                if (pop != null) pop.popdown ();
            });
            box.append (entry);
            var actions = new Box (Orientation.HORIZONTAL, 6);
            var resolve = new Button.with_label (c.resolved ? _("Reopen") : _("Resolve"));
            resolve.clicked.connect (() => {
                doc.begin (c.resolved ? _("Reopen Comment") : _("Resolve Comment"));
                c.resolved = !c.resolved;
                doc.commit ();
                if (pop != null) pop.popdown ();
            });
            var del = new Button.with_label (_("Delete"));
            del.add_css_class ("destructive-action");
            del.clicked.connect (() => {
                doc.begin (_("Delete Comment"));
                foreach (var p in doc.pages) p.comments.remove (c);
                doc.commit ();
                if (pop != null) pop.popdown ();
            });
            actions.append (resolve);
            actions.append (del);
            box.append (actions);
            return box;
        }

        public static void comment_popover (DrawWindow win, Comment c, double sx, double sy) {
            var pop = popover_at (win.canvas, sx, sy);
            var box = pad_box ();
            box.set_size_request (300, -1);
            box.append (thread (win, c, pop));
            pop.child = box;
            pop.popup ();
        }

        public static void comments_popover (DrawWindow win, Widget anchor) {
            var doc = win.doc;
            var pop = new Popover ();
            pop.set_parent (anchor);
            pop.closed.connect (() => Idle.add (() => {
                pop.unparent ();
                return Source.REMOVE;
            }));
            var box = pad_box ();
            box.set_size_request (320, -1);
            var top = new Box (Orientation.HORIZONTAL, 6);
            var title = heading (_("Comments"));
            title.hexpand = true;
            top.append (title);
            var add = new Button.with_label (_("New Comment"));
            add.clicked.connect (() => {
                pop.popdown ();
                add_comment (win);
            });
            top.append (add);
            box.append (top);
            int count = 0;
            foreach (var p in doc.pages) {
                foreach (var c in p.comments) {
                    count++;
                    var page = p;
                    var head = new Button.with_label (p == doc.page ? (c.resolved ? _("Resolved") : _("Open")) : _("On page %s").printf (p.name));
                    head.add_css_class ("flat");
                    head.halign = Align.START;
                    head.clicked.connect (() => {
                        if (page != doc.page) win.switch_page (page);
                        var it = doc.page.find (c.item_id);
                        if (it != null) win.canvas.select_one (it);
                    });
                    box.append (head);
                    box.append (thread (win, c, pop));
                    box.append (new Separator (Orientation.HORIZONTAL));
                }
            }
            if (count == 0) {
                var empty = new Label (_("No comments yet. Select a shape and add a comment."));
                empty.add_css_class ("dim-label");
                empty.wrap = true;
                box.append (empty);
            }
            var scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.propagate_natural_height = true;
            scroll.max_content_height = 560;
            scroll.child = box;
            pop.child = scroll;
            pop.popup ();
        }

        public static void open_link (DrawWindow win, string link) {
            if (link.has_prefix ("page:")) {
                string name = link.substring (5);
                foreach (var p in win.doc.pages) {
                    if (p.name == name || p.id == name) {
                        win.switch_page (p);
                        return;
                    }
                }
                win.add_toast (new Toast (_("There is no page named %s").printf (name)));
                return;
            }
            string uri = link;
            if (!uri.contains ("://") && !uri.has_prefix ("mailto:")) {
                if (uri.has_prefix ("/")) uri = File.new_for_path (uri).get_uri ();
                else uri = "https://" + uri;
            }
            var launcher = new UriLauncher (uri);
            launcher.launch.begin (win, null, (obj, res) => {
                try {
                    launcher.launch.end (res);
                } catch (Error e) {
                    win.show_error (_("Could Not Open Link"), e.message);
                }
            });
        }

        public static void choose_data_file (DrawWindow win, bool link_only) {
            var dialog = new FileDialog ();
            dialog.title = _("Choose Data Source");
            var filters = new GLib.ListStore (typeof (FileFilter));
            var f = new FileFilter ();
            f.name = _("Spreadsheets, CSV Files and Databases");
            foreach (string s in new string[] { "csv", "tsv", "txt", "xlsx", "xlsm", "ods", "db", "sqlite", "sqlite3" }) f.add_suffix (s);
            filters.append (f);
            dialog.filters = filters;
            dialog.open.begin (win, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file == null) return;
                    source_options (win, file.get_path (), link_only);
                } catch (Error e) {
                    if (!(e is Gtk.DialogError.DISMISSED)) win.show_error (_("Could Not Import"), e.message);
                }
            });
        }

        private static void source_options (DrawWindow win, string path, bool link_only) throws Error {
            var d = new DataSource ();
            d.id = DataSources.new_id (win.doc);
            d.kind = DataSources.kind_for_path (path);
            d.path = path;
            d.name = Path.get_basename (path);
            string[] sheets = d.kind == "csv" ? new string[0] : DataSources.sheets (path);
            if (sheets.length <= 1 && d.kind != "sqlite") {
                if (sheets.length == 1) d.sheet = sheets[0];
                d.table = DataSources.load (d);
                finish_source (win, d, link_only);
                return;
            }
            var dlg = make (win, _("Choose Data"), 440, 380);
            var box = body (dlg);
            var g = new PreferencesGroup (DataSources.kind_label (d.kind), d.name);
            SelectionRow? sheet_row = null;
            if (sheets.length > 0) {
                sheet_row = new SelectionRow (d.kind == "sqlite" ? _("Table") : _("Sheet"), sheets, sheets[0]);
                g.add_row (sheet_row);
            }
            EntryRow? query = null;
            if (d.kind == "sqlite") {
                query = new EntryRow (_("Query (optional)"));
                g.add_row (query);
            }
            box.append (g);
            footer (dlg, _("Continue"), () => {
                if (sheet_row != null) d.sheet = sheet_row.current_value;
                if (query != null) d.query = query.text.strip ();
                try {
                    d.table = DataSources.load (d);
                    finish_source (win, d, link_only);
                } catch (Error e) {
                    win.show_error (_("Could Not Import"), e.message);
                }
            });
            dlg.open_dialog ();
        }

        private static void finish_source (DrawWindow win, DataSource d, bool link_only) {
            if (d.table == null || d.table.rows.size == 0) {
                win.show_error (_("No Data Found"), _("The source has no rows to import."));
                return;
            }
            Dialogs.data_import_source (win, d, link_only);
        }

        public static void choose_row (DrawWindow win, Item it) {
            var doc = win.doc;
            var dlg = make (win, _("Link to a Row"), 460, 560);
            var box = body (dlg);
            foreach (var src in doc.data_sources) {
                if (src.table == null) continue;
                var s = src;
                var g = new PreferencesGroup (s.name, ngettext ("%d row", "%d rows", s.table.rows.size).printf (s.table.rows.size));
                int shown = 0;
                int key = s.table.column (s.key_column);
                foreach (var row in s.table.rows) {
                    if (shown++ >= 200) break;
                    var r = row;
                    string title = s.table.cell (row, key >= 0 ? key : 0);
                    var parts = new Gee.ArrayList<string> ();
                    for (int c = 0; c < s.table.header.size && parts.size < 3; c++) if (c != key) parts.add (s.table.cell (row, c));
                    var ar = new ActionRow (title, DataImport.join (", ", parts));
                    var use = new Button.with_label (_("Link"));
                    use.valign = Align.CENTER;
                    use.clicked.connect (() => {
                        doc.begin (_("Link Data"));
                        DataSources.link_item (it, s, r);
                        doc.commit ();
                        dlg.close ();
                        win.inspector.refresh ();
                    });
                    ar.add_suffix (use);
                    g.add_row (ar);
                }
                box.append (g);
            }
            close_footer (dlg);
            dlg.open_dialog ();
        }

        public static void refresh_data (DrawWindow win) {
            var doc = win.doc;
            if (doc.data_sources.size == 0) {
                win.add_toast (new Toast (_("This drawing has no linked data")));
                return;
            }
            doc.begin (_("Refresh Data"));
            int updated = 0, missing = 0, added = 0, removed = 0;
            var errors = new Gee.ArrayList<string> ();
            foreach (var d in doc.data_sources) {
                try {
                    var r = DataSources.refresh (doc, d);
                    updated += r.updated;
                    missing += r.missing;
                    added += r.added;
                    removed += r.removed;
                } catch (Error e) {
                    errors.add ("%s: %s".printf (d.name, e.message));
                }
            }
            doc.commit ();
            win.inspector.refresh ();
            if (errors.size > 0) win.show_error (_("Could Not Refresh All Data"), DataImport.join ("\n", errors));
            string msg = _("%d shapes updated").printf (updated);
            if (added > 0 || removed > 0) msg += ", " + _("%d added, %d removed").printf (added, removed);
            if (missing > 0) msg += ", " + _("%d rows no longer found").printf (missing);
            win.add_toast (new Toast (msg));
        }

        public static void data_graphics (DrawWindow win) {
            var doc = win.doc;
            var dlg = make (win, _("Data Graphics"), 520, 660);
            var box = body (dlg);
            var fields = new Gee.ArrayList<string> ();
            foreach (var p in doc.pages) foreach (var it in p.all_items ()) foreach (var f in it.fields) if (!fields.contains (f.key)) fields.add (f.key);
            if (fields.size == 0) {
                var st = new StatusPage ();
                st.icon_name = "x-office-spreadsheet";
                st.title = _("No Shape Data");
                st.description = _("Link data to shapes or add shape data fields first.");
                box.append (st);
                close_footer (dlg);
                dlg.open_dialog ();
                return;
            }
            DataGraphic g;
            if (doc.data_graphics.size > 0) g = doc.data_graphics[0].copy ();
            else {
                g = new DataGraphic ();
                g.id = "dg1";
                g.name = _("Data Graphic 1");
            }
            string[] field_arr = fields.to_array ();
            var name_group = new PreferencesGroup (_("Graphic"));
            var name = new EntryRow (_("Name"));
            name.text = g.name;
            name_group.add_row (name);
            box.append (name_group);
            var items_box = new Box (Orientation.VERTICAL, 12);
            box.append (items_box);
            Dialogs.Apply rebuild = null;
            rebuild = () => {
                Widget? child;
                while ((child = items_box.get_first_child ()) != null) items_box.remove (child);
                for (int i = 0; i < g.items.size; i++) {
                    var gi = g.items[i];
                    var ig = new PreferencesGroup (_("Item %d").printf (i + 1));
                    var rm = new Button.with_label (_("Remove"));
                    rm.valign = Align.CENTER;
                    rm.clicked.connect (() => {
                        g.items.remove (gi);
                        rebuild ();
                    });
                    ig.add_header_suffix (rm);
                    int fcur = 0;
                    for (int k = 0; k < field_arr.length; k++) if (field_arr[k] == gi.field) fcur = k;
                    if (gi.field == "") gi.field = field_arr[0];
                    var fr = new SelectionRow (_("Field"), field_arr, field_arr[fcur]);
                    fr.selected.connect ((v) => gi.field = v);
                    ig.add_row (fr);
                    string[] kinds = DataGraphics.kinds ();
                    string[] kind_labels = {};
                    foreach (string k in kinds) kind_labels += DataGraphics.kind_label (k);
                    int kcur = 0;
                    for (int k = 0; k < kinds.length; k++) if (kinds[k] == gi.kind) kcur = k;
                    var kr = new SelectionRow (_("Show As"), kind_labels, kind_labels[kcur]);
                    kr.selected.connect ((v) => {
                        for (int k = 0; k < kinds.length; k++) if (kind_labels[k] == v) gi.kind = kinds[k];
                        rebuild ();
                    });
                    ig.add_row (kr);
                    if (gi.kind != "color") {
                        string[] pos = DataGraphics.positions ();
                        string[] pos_labels = {};
                        foreach (string p in pos) pos_labels += DataGraphics.position_label (p);
                        int pc = 0;
                        for (int k = 0; k < pos.length; k++) if (pos[k] == gi.position) pc = k;
                        var pr = new SelectionRow (_("Position"), pos_labels, pos_labels[pc]);
                        pr.selected.connect ((v) => {
                            for (int k = 0; k < pos.length; k++) if (pos_labels[k] == v) gi.position = pos[k];
                        });
                        ig.add_row (pr);
                    }
                    if (gi.kind == "bar" || gi.kind == "icon" || gi.kind == "color") {
                        var mn = new SpinRow (_("Minimum"), null, -1000000, 1000000, 1, gi.min);
                        mn.notify["value"].connect (() => gi.min = mn.value);
                        var mx = new SpinRow (_("Maximum"), null, -1000000, 1000000, 1, gi.max);
                        mx.notify["value"].connect (() => gi.max = mx.value);
                        ig.add_row (mn);
                        ig.add_row (mx);
                    }
                    if (gi.kind == "icon") {
                        string[] sets = DataGraphics.icon_sets ();
                        string[] set_labels = {};
                        foreach (string s in sets) set_labels += DataGraphics.icon_set_label (s);
                        int sc = 0;
                        for (int k = 0; k < sets.length; k++) if (sets[k] == gi.icon_set) sc = k;
                        var sr = new SelectionRow (_("Icons"), set_labels, set_labels[sc]);
                        sr.selected.connect ((v) => {
                            for (int k = 0; k < sets.length; k++) if (set_labels[k] == v) gi.icon_set = sets[k];
                        });
                        ig.add_row (sr);
                    }
                    if (gi.kind != "icon") {
                        var cr = new ActionRow (gi.kind == "color" ? _("Highest Value Color") : _("Color"));
                        var cb = new ColorButton (gi.color, false);
                        cb.picked.connect ((c) => gi.color = c);
                        cr.add_suffix (cb);
                        ig.add_row (cr);
                    }
                    if (gi.kind == "color") {
                        for (int r = 0; r < gi.rules.size; r++) {
                            var rule = gi.rules[r];
                            var rr = new ActionRow (_("When value %s %s").printf (rule.op, rule.value));
                            var rc = new ColorButton (rule.color, false);
                            rc.picked.connect ((c) => rule.color = c);
                            rr.add_suffix (rc);
                            var rdel = new Button.from_icon_name ("user-trash-symbolic");
                            rdel.add_css_class ("flat");
                            rdel.valign = Align.CENTER;
                            rdel.clicked.connect (() => {
                                gi.rules.remove (rule);
                                rebuild ();
                            });
                            rr.add_suffix (rdel);
                            ig.add_row (rr);
                        }
                        var add_rule = new EntryRow (_("Add Rule, for example >= 50 or = Done"));
                        add_rule.entry_activated.connect (() => {
                            string t = add_rule.text.strip ();
                            var rule = new DataGraphicRule ();
                            foreach (string op in new string[] { ">=", "<=", "!=", ">", "<", "=" }) {
                                if (t.has_prefix (op)) {
                                    rule.op = op;
                                    rule.value = t.substring (op.length).strip ();
                                    break;
                                }
                            }
                            if (rule.value == "") {
                                rule.op = "=";
                                rule.value = t;
                            }
                            rule.color = "#e5534b";
                            gi.rules.add (rule);
                            rebuild ();
                        });
                        ig.add_row (add_rule);
                    }
                    items_box.append (ig);
                }
            };
            rebuild ();
            var add_item = new Button.with_label (_("Add Item"));
            add_item.halign = Align.START;
            add_item.clicked.connect (() => {
                var gi = new DataGraphicItem ();
                gi.field = field_arr[0];
                g.items.add (gi);
                rebuild ();
            });
            box.append (add_item);
            footer (dlg, _("Apply"), () => {
                g.name = name.text.strip () != "" ? name.text.strip () : g.name;
                doc.begin (_("Data Graphics"));
                bool found = false;
                for (int i = 0; i < doc.data_graphics.size; i++) {
                    if (doc.data_graphics[i].id == g.id) {
                        doc.data_graphics[i] = g;
                        found = true;
                    }
                }
                if (!found) doc.data_graphics.add (g);
                var targets = win.canvas.selection.size > 0 ? win.canvas.selection : doc.page.all_items ();
                foreach (var it in targets) {
                    var list = new Gee.ArrayList<Item> ();
                    var grp = it as Group;
                    if (grp != null) grp.collect (list);
                    else list.add (it);
                    foreach (var x in list) if (x.fields.size > 0) x.data_graphic = g.id;
                }
                doc.link_backgrounds ();
                doc.commit ();
            });
            dlg.open_dialog ();
        }

        public static void report (DrawWindow win) {
            var doc = win.doc;
            var dlg = make (win, _("Shape Report"), 480, 600);
            var box = body (dlg);
            var fields = new Gee.ArrayList<string> ();
            foreach (var p in doc.pages) foreach (var it in p.all_items ()) foreach (var f in it.fields) if (!fields.contains (f.key)) fields.add (f.key);
            var g = new PreferencesGroup (_("Contents"));
            string[] scopes = { _("Current Page"), _("All Pages"), _("Selection") };
            var scope = new SelectionRow (_("Shapes"), win.canvas.selection.size > 0 ? scopes : scopes[0:2], scopes[win.canvas.selection.size > 0 ? 2 : 0]);
            g.add_row (scope);
            string[] group_opts = { _("None"), _("Shape Type") };
            foreach (string f in fields) group_opts += f;
            var group_by = new SelectionRow (_("Group By"), group_opts, group_opts[0]);
            g.add_row (group_by);
            var totals = new SwitchRow (_("Totals for Numbers"), _("Sum and average of number fields"), true);
            g.add_row (totals);
            box.append (g);
            var fg = new PreferencesGroup (_("Columns"));
            var picks = new Gee.ArrayList<SwitchRow> ();
            var text_col = new SwitchRow (_("Text"), null, true);
            fg.add_row (text_col);
            var type_col = new SwitchRow (_("Shape Type"), null, true);
            fg.add_row (type_col);
            foreach (string f in fields) {
                var sw = new SwitchRow (f, null, true);
                picks.add (sw);
                fg.add_row (sw);
            }
            box.append (fg);
            var out_g = new PreferencesGroup (_("Output"));
            string[] outs = { _("Table on the Page"), _("CSV File"), _("Web Page") };
            var output = new SelectionRow (_("Create"), outs, outs[0]);
            out_g.add_row (output);
            box.append (out_g);
            footer (dlg, _("Create Report"), () => {
                var items = new Gee.ArrayList<Item> ();
                if (scope.current_value == scopes[2]) {
                    foreach (var it in win.canvas.selection) {
                        var grp = it as Group;
                        if (grp != null) grp.collect (items);
                        else items.add (it);
                    }
                } else if (scope.current_value == scopes[1]) {
                    foreach (var p in doc.pages) items.add_all (p.all_items ());
                } else {
                    items.add_all (doc.page.all_items ());
                }
                var cols = new Gee.ArrayList<string> ();
                foreach (var sw in picks) if (sw.active) cols.add (sw.title);
                var rep = ShapeReport.build (items, text_col.active, type_col.active, cols, group_by.current_value == group_opts[0] ? "" : (group_by.current_value == group_opts[1] ? "@type" : group_by.current_value), totals.active);
                if (output.current_value == outs[0]) win.insert_report (rep);
                else win.save_report.begin (rep, output.current_value == outs[2]);
            });
            dlg.open_dialog ();
        }

        public static void snippets (DrawWindow win) {
            var doc = win.doc;
            var dlg = make (win, _("Slide Snippets"), 480, 560);
            var box = body (dlg);
            var intro = new Label (_("Each snippet is an area of a page that becomes one slide when you export to PowerPoint. Without snippets every page becomes a slide."));
            intro.wrap = true;
            intro.xalign = 0;
            intro.add_css_class ("dim-label");
            box.append (intro);
            var g = new PreferencesGroup (_("Snippets"));
            box.append (g);
            var rows = new Gee.ArrayList<Widget> ();
            Dialogs.Apply rebuild = null;
            rebuild = () => {
                foreach (var r in rows) g.remove_row (r);
                rows.clear ();
                int n = 0;
                foreach (var p in doc.pages) {
                    for (int i = 0; i < p.snippets.size; i++) {
                        var sn = p.snippets[i];
                        var row = new ActionRow (sn.name != "" ? sn.name : _("Snippet %d").printf (n + 1), _("%s, %d by %d").printf (p.name, (int) sn.area.w, (int) sn.area.h));
                        var page_ref = p;
                        int idx = i;
                        var up = new Button.from_icon_name ("go-up-symbolic");
                        up.tooltip_text = _("Move Up");
                        up.add_css_class ("flat");
                        up.valign = Align.CENTER;
                        up.sensitive = idx > 0;
                        up.clicked.connect (() => {
                            doc.begin (_("Move Snippet"));
                            var a = page_ref.snippets[idx];
                            page_ref.snippets[idx] = page_ref.snippets[idx - 1];
                            page_ref.snippets[idx - 1] = a;
                            doc.commit ();
                            rebuild ();
                        });
                        var del = new Button.from_icon_name ("user-trash-symbolic");
                        del.tooltip_text = _("Remove Snippet");
                        del.add_css_class ("flat");
                        del.valign = Align.CENTER;
                        del.clicked.connect (() => {
                            doc.begin (_("Remove Snippet"));
                            page_ref.snippets.remove_at (idx);
                            doc.commit ();
                            rebuild ();
                        });
                        row.add_suffix (up);
                        row.add_suffix (del);
                        g.add_row (row);
                        rows.add (row);
                        n++;
                    }
                }
                if (n == 0) {
                    var empty = new ActionRow (_("No snippets yet"), _("Every page will become one slide"));
                    g.add_row (empty);
                    rows.add (empty);
                }
            };
            rebuild ();
            var add_g = new PreferencesGroup (_("Add"));
            var name = new EntryRow (_("Name"));
            add_g.add_row (name);
            var from_sel = new ActionRow (_("From Selection"), _("The area around the selected shapes"));
            var sel_btn = new Button.with_label (_("Add"));
            sel_btn.valign = Align.CENTER;
            sel_btn.sensitive = win.canvas.selection.size > 0;
            sel_btn.clicked.connect (() => {
                var r = Document.selection_bounds (win.canvas.selection).inflate (16);
                add_snippet (doc, name.text.strip (), r);
                name.text = "";
                rebuild ();
            });
            from_sel.add_suffix (sel_btn);
            add_g.add_row (from_sel);
            var from_view = new ActionRow (_("Current View"), _("What is visible in the window now"));
            var view_btn = new Button.with_label (_("Add"));
            view_btn.valign = Align.CENTER;
            view_btn.clicked.connect (() => {
                add_snippet (doc, name.text.strip (), win.canvas.visible_rect ());
                name.text = "";
                rebuild ();
            });
            from_view.add_suffix (view_btn);
            add_g.add_row (from_view);
            var from_page = new ActionRow (_("Whole Page"), doc.page.name);
            var page_btn = new Button.with_label (_("Add"));
            page_btn.valign = Align.CENTER;
            page_btn.clicked.connect (() => {
                add_snippet (doc, name.text.strip (), Rect (0, 0, doc.page.width, doc.page.height));
                name.text = "";
                rebuild ();
            });
            from_page.add_suffix (page_btn);
            add_g.add_row (from_page);
            box.append (add_g);
            footer (dlg, _("Export to PowerPoint"), () => win.export_pptx.begin ());
            dlg.open_dialog ();
        }

        private static void add_snippet (Document doc, string name, Rect r) {
            var page = doc.page;
            var clip = Rect.from_points (double.max (r.x, 0), double.max (r.y, 0), double.min (r.x2 (), page.width), double.min (r.y2 (), page.height));
            if (clip.w < 4 || clip.h < 4) clip = r;
            doc.begin (_("Add Snippet"));
            int n = 0;
            foreach (var p in doc.pages) n += p.snippets.size;
            page.snippets.add (new Snippet (name != "" ? name : _("Snippet %d").printf (n + 1), clip));
            doc.commit ();
        }

        public static void presentation (DrawWindow win) {
            var doc = win.doc;
            var pages = doc.foreground_pages ();
            if (pages.size == 0) return;
            doc.link_backgrounds ();
            var w = new Gtk.Window ();
            w.transient_for = win;
            w.title = _("Presentation");
            w.add_css_class ("draw-presentation");
            int index = pages.index_of (doc.page).clamp (0, pages.size - 1);
            var area = new DrawingArea ();
            area.hexpand = true;
            area.vexpand = true;
            area.set_draw_func ((a, cr, ww, hh) => {
                cr.set_source_rgb (0.06, 0.06, 0.07);
                cr.paint ();
                var p = pages[index];
                double sc = double.min (ww / p.width, hh / p.height) * 0.96;
                cr.translate ((ww - p.width * sc) / 2, (hh - p.height * sc) / 2);
                cr.scale (sc, sc);
                var opts = new RenderOptions ();
                opts.print = true;
                Renderer.draw_page (cr, p, opts);
            });
            var keys = new EventControllerKey ();
            keys.key_pressed.connect ((kv, code, state) => {
                switch (kv) {
                    case Gdk.Key.Escape:
                        w.close ();
                        return true;
                    case Gdk.Key.Right:
                    case Gdk.Key.Down:
                    case Gdk.Key.Page_Down:
                    case Gdk.Key.space:
                        if (index < pages.size - 1) index++;
                        area.queue_draw ();
                        return true;
                    case Gdk.Key.Left:
                    case Gdk.Key.Up:
                    case Gdk.Key.Page_Up:
                    case Gdk.Key.BackSpace:
                        if (index > 0) index--;
                        area.queue_draw ();
                        return true;
                    case Gdk.Key.Home:
                        index = 0;
                        area.queue_draw ();
                        return true;
                    case Gdk.Key.End:
                        index = pages.size - 1;
                        area.queue_draw ();
                        return true;
                }
                return false;
            });
            ((Gtk.Widget) w).add_controller (keys);
            var click = new GestureClick ();
            click.pressed.connect ((n, x, y) => {
                var p = pages[index];
                double ww = area.get_width (), hh = area.get_height ();
                double sc = double.min (ww / p.width, hh / p.height) * 0.96;
                double px = (x - (ww - p.width * sc) / 2) / sc, py = (y - (hh - p.height * sc) / 2) / sc;
                var it = p.hit (px, py, 4 / sc);
                if (it != null && it.link != "") {
                    if (it.link.has_prefix ("page:")) {
                        string name = it.link.substring (5);
                        for (int i = 0; i < pages.size; i++) if (pages[i].name == name) index = i;
                        area.queue_draw ();
                    } else {
                        open_link (win, it.link);
                    }
                    return;
                }
                if (index < pages.size - 1) index++;
                area.queue_draw ();
            });
            area.add_controller (click);
            var overlay = new Overlay ();
            overlay.child = area;
            var bar = new Box (Orientation.HORIZONTAL, 8);
            bar.add_css_class ("draw-present-bar");
            bar.halign = Align.END;
            bar.valign = Align.END;
            bar.margin_end = 18;
            bar.margin_bottom = 18;
            var export_btn = new Button.with_label (_("Export to PowerPoint"));
            export_btn.focus_on_click = false;
            export_btn.clicked.connect (() => {
                w.close ();
                win.export_pptx.begin ();
            });
            var close_btn = new Button.with_label (_("End Show"));
            close_btn.focus_on_click = false;
            close_btn.clicked.connect (() => w.close ());
            bar.append (export_btn);
            bar.append (close_btn);
            overlay.add_overlay (bar);
            var motion = new EventControllerMotion ();
            uint hide_id = 0;
            hide_id = Timeout.add (3000, () => {
                bar.opacity = 0;
                hide_id = 0;
                return Source.REMOVE;
            });
            motion.motion.connect ((mx, my) => {
                bar.opacity = 1;
                if (hide_id != 0) Source.remove (hide_id);
                hide_id = 0;
                hide_id = Timeout.add (2500, () => {
                    bar.opacity = 0;
                    hide_id = 0;
                    return Source.REMOVE;
                });
            });
            overlay.add_controller (motion);
            w.close_request.connect (() => {
                if (hide_id != 0) Source.remove (hide_id);
                hide_id = 0;
                return false;
            });
            w.child = overlay;
            w.fullscreen ();
            w.present ();
        }
    }
}
