using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class DrawLiveState : Object {
        public LiveSession? session;
        public DrawLiveSync? sync;
        public Button chip;
        public Box dots;
        public Label count;
        public DrawingArea? layer;
        public Canvas? drawn;
        public ulong selection_handler;
        public ulong view_handler;
        public bool loading = false;
        public bool installed = false;
        public GLib.Settings? settings;
    }

    public class DrawLive {
        public const string SCHEME = "draw-live";
        public const string PATH = "/draw";

        public static DrawLiveState state_of (DrawWindow win) {
            var st = win.get_data<DrawLiveState> ("draw-live");
            if (st == null) {
                st = new DrawLiveState ();
                win.set_data<DrawLiveState> ("draw-live", st);
            }
            return st;
        }

        public static bool active (DrawWindow win) {
            return state_of (win).session != null;
        }

        private static void install (DrawWindow win) {
            var st = state_of (win);
            if (st.installed) return;
            st.installed = true;
            var src = SettingsSchemaSource.get_default ();
            if (src != null) {
                var schema = src.lookup ("dev.sinty.draw", true);
                if (schema != null && schema.has_key ("author-name")) {
                    st.settings = new GLib.Settings ("dev.sinty.draw");
                    Comment.author_name = st.settings.get_string ("author-name");
                    st.settings.changed["author-name"].connect (() => Comment.author_name = st.settings.get_string ("author-name"));
                }
            }
            var a = new SimpleAction ("edit-together", null);
            a.activate.connect (() => {
                if (win.doc != null) dialog (win);
            });
            win.add_action (a);
            var box = new Box (Orientation.HORIZONTAL, 6);
            st.dots = new Box (Orientation.HORIZONTAL, 3);
            st.count = new Label ("");
            box.append (st.dots);
            box.append (st.count);
            st.chip = new Button ();
            st.chip.child = box;
            st.chip.add_css_class ("flat");
            st.chip.tooltip_text = _("People editing this drawing");
            st.chip.clicked.connect (() => dialog (win));
            st.chip.visible = false;
            win.add_bubble_widget (st.chip);
        }

        public static void attach (DrawWindow win, Overlay overlay) {
            install (win);
            var st = state_of (win);
            if (!st.loading && st.sync != null && st.sync.doc != win.doc) stop (win, false);
            var layer = new DrawingArea ();
            layer.can_target = false;
            layer.can_focus = false;
            layer.hexpand = layer.vexpand = true;
            layer.set_draw_func ((area, cr, w, h) => draw (win, cr));
            overlay.add_overlay (layer);
            st.layer = layer;
            if (st.drawn != null) {
                if (st.selection_handler != 0) st.drawn.disconnect (st.selection_handler);
                if (st.view_handler != 0) st.drawn.disconnect (st.view_handler);
            }
            st.drawn = win.canvas;
            st.selection_handler = win.canvas.selection_changed.connect (() => send_presence (win));
            st.view_handler = win.canvas.view_changed.connect (() => {
                if (st.layer != null) st.layer.queue_draw ();
            });
        }

        private static void rgb (Cairo.Context cr, string hex, double alpha) {
            var c = Gdk.RGBA ();
            if (!c.parse (hex)) c.parse ("#1c71d8");
            cr.set_source_rgba (c.red, c.green, c.blue, alpha);
        }

        private static void draw (DrawWindow win, Cairo.Context cr) {
            var st = state_of (win);
            if (st.session == null || win.canvas == null || win.doc == null) return;
            var page = win.doc.page;
            foreach (var p in st.session.peers.values) {
                if (p.info == null || !p.info.has_member ("page") || p.info.get_string_member ("page") != page.id) continue;
                if (!p.info.has_member ("sel")) continue;
                bool labelled = false;
                foreach (var n in p.info.get_array_member ("sel").get_elements ()) {
                    var it = page.find (n.get_string ());
                    if (it == null) continue;
                    var b = it.bounds ();
                    var a = win.canvas.to_screen (b.x, b.y);
                    var z = win.canvas.to_screen (b.x + b.w, b.y + b.h);
                    double x = double.min (a.x, z.x) - 4, y = double.min (a.y, z.y) - 4;
                    double w = (a.x - z.x).abs () + 8, h = (a.y - z.y).abs () + 8;
                    cr.save ();
                    rgb (cr, p.color, 1);
                    cr.set_line_width (2);
                    cr.set_dash ({ 6, 3 }, 0);
                    cr.rectangle (x, y, w, h);
                    cr.stroke ();
                    if (!labelled) {
                        labelled = true;
                        var layout = Pango.cairo_create_layout (cr);
                        layout.set_text (p.name, -1);
                        layout.set_font_description (Pango.FontDescription.from_string ("Sans Bold 8"));
                        int tw, th;
                        layout.get_pixel_size (out tw, out th);
                        double ly = y - th - 4 < 0 ? y + h : y - th - 4;
                        cr.set_dash ({}, 0);
                        cr.rectangle (x, ly, tw + 8, th + 4);
                        cr.fill ();
                        cr.set_source_rgb (1, 1, 1);
                        cr.move_to (x + 4, ly + 2);
                        Pango.cairo_show_layout (cr, layout);
                    }
                    cr.restore ();
                }
            }
        }

        private static void send_presence (DrawWindow win) {
            var st = state_of (win);
            if (st.session == null || win.doc == null || win.canvas == null) return;
            var info = new Json.Object ();
            info.set_string_member ("page", win.doc.page.id);
            var sel = new Json.Array ();
            foreach (var it in win.canvas.selection) sel.add_string_element (it.id);
            info.set_array_member ("sel", sel);
            st.session.presence (info);
        }

        private static void update_chip (DrawWindow win) {
            var st = state_of (win);
            Widget? c;
            while ((c = st.dots.get_first_child ()) != null) st.dots.remove (c);
            if (st.session == null) {
                st.chip.visible = false;
                return;
            }
            var colors = new Gee.ArrayList<string> ();
            colors.add (st.session.color);
            foreach (var p in st.session.peers.values) colors.add (p.color);
            int shown = 0;
            foreach (string col in colors) {
                if (shown++ >= 5) break;
                var dot = new DrawingArea ();
                dot.set_size_request (10, 10);
                dot.valign = Align.CENTER;
                string cc = col;
                dot.set_draw_func ((area, cr, w, h) => {
                    rgb (cr, cc, 1);
                    cr.arc (w / 2.0, h / 2.0, double.min (w, h) / 2.0, 0, 2 * Math.PI);
                    cr.fill ();
                });
                st.dots.append (dot);
            }
            int n = colors.size;
            st.count.label = ngettext ("%d person", "%d people", n).printf (n);
            st.chip.visible = true;
        }

        private static void toast (DrawWindow win, string text) {
            win.add_toast (new Toast (text));
        }

        private static void wire (DrawWindow win, LiveSession s) {
            var st = state_of (win);
            st.session = s;
            s.message.connect ((o) => {
                if (st.sync != null && o.has_member ("t") && o.get_string_member ("t") == "draw") st.sync.receive (o);
            });
            s.peers_changed.connect (() => {
                update_chip (win);
                if (st.layer != null) st.layer.queue_draw ();
            });
            s.peer_joined.connect ((p) => toast (win, _("%s joined").printf (p.name)));
            s.peer_left.connect ((p) => toast (win, _("%s left").printf (p.name)));
            s.ended.connect ((reason) => {
                if (st.session != s) return;
                toast (win, reason);
                stop (win, true);
            });
            s.state_requested.connect (() => {
                if (st.sync != null) s.publish_state (st.sync.snapshot ());
            });
            update_chip (win);
        }

        private static void attach_sync (DrawWindow win, Json.Object? stamps) {
            var st = state_of (win);
            if (st.sync != null) st.sync.detach ();
            win.doc.live_tag = "_" + random_tag ();
            var sy = new DrawLiveSync (win.doc, st.session.my_id);
            if (stamps != null) sy.load_stamps (stamps);
            sy.outgoing.connect ((m) => {
                if (st.session != null) st.session.send (m);
            });
            sy.applied.connect (() => {
                if (st.layer != null) st.layer.queue_draw ();
                win.inspector.refresh ();
            });
            st.sync = sy;
            send_presence (win);
        }

        private static string random_tag () {
            string letters = "abcdefghijkmnpqrstuvwxyz";
            var sb = new StringBuilder ();
            for (int i = 0; i < 3; i++) sb.append_c (letters[Random.int_range (0, letters.length)]);
            return sb.str;
        }

        private static string me () {
            return Comment.current_author ();
        }

        public static void start_host (DrawWindow win) throws Error {
            var s = new LiveSession (me (), SCHEME, PATH);
            wire (win, s);
            attach_sync (win, null);
            s.host_secure (state_of (win).sync.snapshot ());
        }

        private static void load_shared (DrawWindow win, Json.Object state) throws Error {
            var d = DrawLiveSync.document_from (state);
            var st = state_of (win);
            st.loading = true;
            win.load_document (d);
            st.loading = false;
            attach_sync (win, state);
            update_chip (win);
        }

        public static void join (DrawWindow win, string link) {
            var s = new LiveSession (me (), SCHEME, PATH);
            wire (win, s);
            s.welcome.connect ((state) => {
                try {
                    load_shared (win, state);
                    toast (win, _("Joined the live drawing."));
                } catch (Error e) {
                    toast (win, e.message);
                    stop (win, true);
                }
            });
            s.join.begin (link, (o, res) => {
                try {
                    s.join.end (res);
                } catch (Error e) {
                    toast (win, e.message);
                    stop (win, true);
                }
            });
        }

        private static string doc_title (DrawWindow win) {
            string t = win.title ?? "";
            return t != "" ? t : _("Drawing");
        }

        public static void start_collab (DrawWindow win, Singularity.Collab.Person person) {
            var st = state_of (win);
            if (st.session != null && st.session.mode == LiveMode.COLLAB) {
                st.session.host_collab.begin (new Json.Object (), person, "Drawing", doc_title (win), (o, res) => {
                    try {
                        st.session.host_collab.end (res);
                        toast (win, _("Invitation sent to %s.").printf (person.name));
                    } catch (Error e) {
                        toast (win, e.message);
                    }
                });
                return;
            }
            if (st.session != null) stop (win, true);
            var s = new LiveSession (me (), SCHEME, PATH);
            wire (win, s);
            attach_sync (win, null);
            s.host_collab.begin (state_of (win).sync.snapshot (), person, "Drawing", doc_title (win), (o, res) => {
                try {
                    s.host_collab.end (res);
                    update_chip (win);
                    toast (win, _("Invitation sent to %s.").printf (person.name));
                } catch (Error e) {
                    toast (win, e.message);
                    stop (win, true);
                }
            });
        }

        public static void join_collab (DrawWindow win, string session, string snapshot, string from) {
            var s = new LiveSession (me (), SCHEME, PATH);
            wire (win, s);
            s.welcome.connect ((state) => {
                try {
                    load_shared (win, state);
                    toast (win, _("You are drawing with %s.").printf (from));
                } catch (Error e) {
                    toast (win, e.message);
                    stop (win, true);
                }
            });
            s.join_collab (session, snapshot);
        }

        private static void people_group (DrawWindow win, Box box, AppDialog dlg, bool inviting) {
            if (!Singularity.Collab.Client.installed ()) return;
            var client = Singularity.Collab.Client.get_default ();
            var g = new PreferencesGroup (inviting ? _("Invite More People") : _("People Nearby"),
                _("They are asked to accept, then they draw with you in real time."));
            box.prepend (g);
            client.refresh_people.begin ((o, res) => {
                client.refresh_people.end (res);
                int shown = 0;
                foreach (var p in client.people) {
                    if (!p.can_join) continue;
                    var person = p;
                    var row = new ActionRow (p.name, p.provider_name, p.icon_name);
                    row.activatable = true;
                    row.activated.connect (() => {
                        dlg.close ();
                        start_collab (win, person);
                    });
                    g.add_row (row);
                    shown++;
                }
                if (shown == 0) {
                    var none = new ActionRow (_("Nobody Is Reachable"), _("Pair a computer in Settings, Connected Devices"), "network-offline-symbolic");
                    none.activatable = false;
                    g.add_row (none);
                }
            });
        }

        public static void start_folder (DrawWindow win, string dir, bool create) throws Error {
            var s = new LiveSession (me (), SCHEME, PATH);
            wire (win, s);
            if (create) {
                attach_sync (win, null);
                s.start_folder (dir, state_of (win).sync.snapshot ());
                return;
            }
            bool loaded = false;
            Error? failure = null;
            s.welcome.connect ((state) => {
                try {
                    load_shared (win, state);
                    loaded = true;
                } catch (Error e) {
                    failure = e;
                }
            });
            s.start_folder (dir, null);
            if (failure != null) throw failure;
            if (!loaded) throw new IOError.FAILED (_("The shared folder could not be read."));
        }

        public static void stop (DrawWindow win, bool quiet) {
            var st = state_of (win);
            if (st.sync != null) st.sync.detach ();
            st.sync = null;
            if (win.doc != null) win.doc.live_tag = "";
            if (st.session != null) {
                var s = st.session;
                st.session = null;
                s.leave ();
                if (!quiet) toast (win, _("You left the live session."));
            }
            update_chip (win);
            if (st.layer != null) st.layer.queue_draw ();
        }

        private static AppDialog make (DrawWindow win, string title) {
            var dlg = new AppDialog ((Gtk.Application) win.application, true);
            dlg.set_title (title);
            dlg.transient_for = win;
            dlg.set_default_size (500, 560);
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

        private static Box footer (AppDialog dlg) {
            var bar = new Box (Orientation.HORIZONTAL, 8);
            bar.margin_start = bar.margin_end = 18;
            bar.margin_bottom = 16;
            bar.margin_top = 4;
            var spacer = new Box (Orientation.HORIZONTAL, 0);
            spacer.hexpand = true;
            bar.append (spacer);
            var close = new Button.with_label (_("Close"));
            close.add_css_class ("suggested-action");
            close.clicked.connect (() => dlg.close ());
            bar.append (close);
            dlg.content_box.append (bar);
            return bar;
        }

        private static Button row_button (string label) {
            var b = new Button.with_label (label);
            b.valign = Align.CENTER;
            return b;
        }

        public static void dialog (DrawWindow win) {
            var st = state_of (win);
            var dlg = make (win, _("Edit Together"));
            var box = body (dlg);
            if (st.session != null) {
                var s = st.session;
                var g = new PreferencesGroup (s.mode == LiveMode.FOLDER ? _("Shared through a folder") : _("Live session"));
                if (s.mode == LiveMode.COLLAB) {
                    g.add_row (new ActionRow (_("Shared with People Nearby"), s.collab_hosting ? _("You started this session") : _("You joined this session")));
                } else if (s.mode == LiveMode.HOST) {
                    var link = new ActionRow (_("Link"), s.link);
                    var copy = new Button.from_icon_name ("edit-copy-symbolic");
                    copy.tooltip_text = _("Copy Link");
                    copy.valign = Align.CENTER;
                    copy.add_css_class ("flat");
                    copy.clicked.connect (() => {
                        copy.get_clipboard ().set_text (s.link);
                        toast (win, _("Link copied."));
                    });
                    link.add_suffix (copy);
                    g.add_row (link);
                } else {
                    g.add_row (new ActionRow (s.mode == LiveMode.FOLDER ? _("Folder") : _("Link"), s.link));
                }
                box.append (g);
                var pg = new PreferencesGroup (_("People"));
                pg.add_row (new ActionRow (s.name, _("You")));
                foreach (var p in s.peers.values) {
                    string where = "";
                    if (p.info != null && p.info.has_member ("page")) {
                        var page = win.doc.find_page (p.info.get_string_member ("page"));
                        if (page != null) where = page.name;
                    }
                    pg.add_row (new ActionRow (p.name, where));
                }
                box.append (pg);
                var bar = footer (dlg);
                var stop_btn = new Button.with_label (_("Stop Sharing"));
                stop_btn.add_css_class ("destructive-action");
                stop_btn.clicked.connect (() => {
                    stop (win, false);
                    dlg.close ();
                });
                bar.prepend (stop_btn);
                if (s.mode == LiveMode.COLLAB && s.collab_hosting) people_group (win, box, dlg, true);
                dlg.open_dialog ();
                return;
            }
            people_group (win, box, dlg, false);
            var hg = new PreferencesGroup (_("On this network"), _("Others join with the link and its key. Every change merges shape by shape, and everyone sees what the others select."));
            var start = new ActionRow (_("Start a Live Session"), _("Creates a link to share"));
            var sb = row_button (_("Start"));
            sb.clicked.connect (() => {
                try {
                    start_host (win);
                    dlg.close ();
                    dialog (win);
                } catch (Error e) {
                    toast (win, e.message);
                }
            });
            start.add_suffix (sb);
            hg.add_row (start);
            var join_row = new EntryRow (_("Join with a Link"));
            var jb = row_button (_("Join"));
            jb.clicked.connect (() => {
                string l = join_row.text.strip ();
                if (l == "") return;
                dlg.close ();
                join (win, l);
            });
            join_row.entry_activated.connect (() => jb.clicked ());
            join_row.add_suffix (jb);
            hg.add_row (join_row);
            box.append (hg);
            var cg = new PreferencesGroup (_("Through a cloud folder"), _("Choose a folder of an online account that everyone can open. The session is kept in it, so it also works across networks."));
            var fstart = new ActionRow (_("Share in a Folder"), _("Start editing together in a folder"));
            var fjoin = new ActionRow (_("Join from a Folder"), _("Open a drawing someone shared in a folder"));
            var fsb = row_button (_("Share"));
            var fjb = row_button (_("Join"));
            fstart.add_suffix (fsb);
            fjoin.add_suffix (fjb);
            cg.add_row (fstart);
            cg.add_row (fjoin);
            box.append (cg);
            foreach (var b in new Button[] { fsb, fjb }) {
                bool create = b == fsb;
                b.clicked.connect (() => {
                    var fd = new FileDialog ();
                    fd.title = create ? _("Choose a Shared Folder") : _("Choose the Shared Folder");
                    string cloud = Path.build_filename (Environment.get_home_dir (), "Cloud");
                    if (FileUtils.test (cloud, FileTest.IS_DIR)) fd.initial_folder = File.new_for_path (cloud);
                    fd.select_folder.begin (win, null, (o, res) => {
                        try {
                            var folder = fd.select_folder.end (res);
                            if (folder == null || folder.get_path () == null) return;
                            start_folder (win, Path.build_filename (folder.get_path (), ".draw-live"), create);
                            dlg.close ();
                            toast (win, create ? _("The drawing is shared in the folder.") : _("Joined the shared drawing."));
                        } catch (Error e) {
                            if (!(e is DialogError.DISMISSED)) toast (win, e.message);
                        }
                    });
                });
            }
            footer (dlg);
            dlg.open_dialog ();
        }
    }
}
