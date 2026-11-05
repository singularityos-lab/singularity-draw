namespace Singularity.Apps.Draw {

    internal class DrawIntents : Object {
        private const string NONE = "{\"type\":\"object\",\"properties\":{}}";
        private const string KINDS = "process, decision, terminator, data, document, database, predefined-process, manual-operation, delay, preparation, off-page, rectangle, ellipse";

        private static string text (Json.Object args, string key) {
            return args.has_member (key) && args.get_member (key).get_value_type () == typeof (string) ? args.get_string_member (key) : "";
        }

        private static DrawWindow window (DrawApp app) throws Error {
            var w = app.get_active_window () as DrawWindow;
            if (w == null || w.doc == null) {
                foreach (var x in app.get_windows ()) {
                    if (x is DrawWindow && ((DrawWindow) x).doc != null) {
                        w = (DrawWindow) x;
                        break;
                    }
                }
            }
            if (w == null) {
                foreach (var x in app.get_windows ()) {
                    if (x is DrawWindow) {
                        w = (DrawWindow) x;
                        break;
                    }
                }
            }
            if (w == null) {
                app.activate ();
                w = app.get_active_window () as DrawWindow;
                if (w == null) foreach (var x in app.get_windows ()) if (x is DrawWindow) w = (DrawWindow) x;
                if (w == null) throw new IOError.FAILED ("the window did not open");
            }
            if (w.doc == null) w.new_document ();
            if (w.doc == null) throw new IOError.FAILED ("Draw has no open drawing");
            return w;
        }

        private static Item? find (Page page, string id) {
            foreach (var it in page.all_items ()) if (it.id == id) return it;
            return null;
        }

        private static Json.Node item_node (Item it) {
            var b = new Json.Builder ();
            b.begin_object ();
            b.set_member_name ("id").add_string_value (it.id);
            b.set_member_name ("text").add_string_value (it.display_text ());
            if (it is Shape) {
                var s = (Shape) it;
                b.set_member_name ("type").add_string_value (s.kind);
                b.set_member_name ("x").add_double_value (Math.round (s.x));
                b.set_member_name ("y").add_double_value (Math.round (s.y));
                b.set_member_name ("w").add_double_value (Math.round (s.w));
                b.set_member_name ("h").add_double_value (Math.round (s.h));
                b.set_member_name ("fill").add_string_value (s.style.fill);
            } else if (it is Connector) {
                var c = (Connector) it;
                b.set_member_name ("type").add_string_value ("connector");
                b.set_member_name ("from").add_string_value (c.src.item_id);
                b.set_member_name ("to").add_string_value (c.dst.item_id);
            }
            b.end_object ();
            return b.get_root ();
        }

        private static Json.Node scene (Document doc) {
            var b = new Json.Builder ();
            b.begin_object ();
            b.set_member_name ("page").add_string_value (doc.page.name);
            b.set_member_name ("pages").add_int_value (doc.pages.size);
            b.set_member_name ("items");
            b.begin_array ();
            foreach (var it in doc.page.all_items ()) b.add_value (item_node (it));
            b.end_array ();
            b.end_object ();
            return b.get_root ();
        }

        private static Shape make_node (Document doc, string label, string type, double x, double y) {
            string kind = DataSources.kind_for_type (type);
            var e = ShapeLibrary.find (kind);
            var s = new Shape (kind, x, y, e != null ? e.w : 120, e != null ? e.h : 60);
            ShapeLibrary.apply_defaults (s);
            Theme.style_new_item (doc, s);
            s.text = label;
            doc.add_item (s);
            return s;
        }

        private static Connector make_edge (Document doc, Shape from, Shape to, string label) {
            var c = new Connector ();
            c.src.item_id = from.id;
            c.dst.item_id = to.id;
            c.text = label;
            doc.add_item (c);
            Theme.style_new_item (doc, c);
            return c;
        }

        private static double right_edge (Page page) {
            double right = 0;
            foreach (var it in page.items) {
                var r = it.bounds ();
                right = double.max (right, r.x + r.w);
            }
            return right;
        }

        private static LayoutKind layout_kind (string name) {
            switch (name) {
                case "right": return LayoutKind.HIERARCHICAL_RIGHT;
                case "tree": return LayoutKind.TREE_DOWN;
                case "tree-right": return LayoutKind.TREE_RIGHT;
                case "circle": return LayoutKind.CIRCLE;
                case "grid": return LayoutKind.GRID;
                case "force": return LayoutKind.FORCE;
                default: return LayoutKind.HIERARCHICAL;
            }
        }

        private static void show (DrawWindow w, Gee.Collection<Item> items) {
            if (w.canvas == null) return;
            w.canvas.selection.clear ();
            w.canvas.selection.add_all (items);
            w.canvas.selection_changed ();
            w.canvas.queue_draw ();
            DrawLive.agent_touch (w, items);
        }

        private static Json.Node verified (Json.Node n, bool ok) {
            n.get_object ().set_boolean_member ("verified", ok);
            return n;
        }

        internal static void install (DrawApp app) {
            var agent = app.agent;
            agent.add_intent ("draw_scene", "Read the open drawing: every shape with id, type, text, position, size and fill, and every connector with the ids it joins.", NONE,
                Singularity.AppIntentRisk.READ, (args) => scene (window (app).doc));
            agent.add_intent ("draw_flow_create", "Draw a whole flowchart in one step from nodes and edges. Node types: " + KINDS + ". Edges join node ids and may carry a label such as yes or no. layout is down (default), right, tree, tree-right, circle or grid. Answers with the id of each shape created.",
                "{\"type\":\"object\",\"properties\":{\"nodes\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"string\"},\"text\":{\"type\":\"string\"},\"type\":{\"type\":\"string\"}},\"required\":[\"id\",\"text\"]}},\"edges\":{\"type\":\"array\",\"items\":{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\"},\"to\":{\"type\":\"string\"},\"label\":{\"type\":\"string\"}},\"required\":[\"from\",\"to\"]}},\"layout\":{\"type\":\"string\"}},\"required\":[\"nodes\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var w = window (app);
                    var doc = w.doc;
                    if (!args.has_member ("nodes")) throw new IOError.INVALID_ARGUMENT ("nodes is required");
                    var nodes = args.get_array_member ("nodes");
                    var edges = args.has_member ("edges") ? args.get_array_member ("edges") : new Json.Array ();
                    var by_id = new Gee.HashMap<string, Shape> ();
                    var made = new Gee.ArrayList<Item> ();
                    double x0 = right_edge (doc.page) + 80;
                    string missing = "";
                    doc.edit (_("Draw Flowchart"), () => {
                        for (uint i = 0; i < nodes.get_length (); i++) {
                            var n = nodes.get_object_element (i);
                            string key = text (n, "id");
                            var s = make_node (doc, text (n, "text"), text (n, "type"), x0 + i * 40, 40 + i * 40);
                            by_id[key] = s;
                            made.add (s);
                        }
                        for (uint i = 0; i < edges.get_length (); i++) {
                            var e = edges.get_object_element (i);
                            var from = by_id[text (e, "from")];
                            var to = by_id[text (e, "to")];
                            if (from == null || to == null) {
                                missing += " %s>%s".printf (text (e, "from"), text (e, "to"));
                                continue;
                            }
                            made.add (make_edge (doc, from, to, text (e, "label")));
                        }
                        AutoLayout.apply (doc.page, made, layout_kind (text (args, "layout")), 50, 60);
                    });
                    show (w, made);
                    var b = new Json.Builder ();
                    b.begin_object ();
                    b.set_member_name ("shapes");
                    b.begin_object ();
                    int found = 0;
                    foreach (var key in by_id.keys) {
                        b.set_member_name (key).add_string_value (by_id[key].id);
                        if (find (doc.page, by_id[key].id) != null) found++;
                    }
                    b.end_object ();
                    b.set_member_name ("items").add_int_value (made.size);
                    if (missing != "") b.set_member_name ("edges_skipped").add_string_value (missing.strip ());
                    b.end_object ();
                    return verified (b.get_root (), found == by_id.size && found == (int) nodes.get_length ());
                });
            agent.add_intent ("draw_node_add", "Add one shape with text. Types: " + KINDS + ". Give x and y, or after (a shape id) to place it below that shape and connect it.",
                "{\"type\":\"object\",\"properties\":{\"text\":{\"type\":\"string\"},\"type\":{\"type\":\"string\"},\"x\":{\"type\":\"number\"},\"y\":{\"type\":\"number\"},\"after\":{\"type\":\"string\"},\"label\":{\"type\":\"string\"}},\"required\":[\"text\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var w = window (app);
                    var doc = w.doc;
                    Shape? prev = null;
                    if (text (args, "after") != "") {
                        prev = find (doc.page, text (args, "after")) as Shape;
                        if (prev == null) throw new IOError.NOT_FOUND ("no shape %s".printf (text (args, "after")));
                    }
                    double x = args.has_member ("x") ? args.get_double_member ("x") : (prev != null ? prev.x : right_edge (doc.page) + 80);
                    double y = args.has_member ("y") ? args.get_double_member ("y") : (prev != null ? prev.y + prev.h + 60 : 40);
                    Shape? s = null;
                    var made = new Gee.ArrayList<Item> ();
                    doc.edit (_("Add Shape"), () => {
                        s = make_node (doc, text (args, "text"), text (args, "type"), x, y);
                        made.add (s);
                        if (prev != null) made.add (make_edge (doc, prev, s, text (args, "label")));
                    });
                    show (w, made);
                    return verified (item_node (s), find (doc.page, s.id) != null);
                });
            agent.add_intent ("draw_connect", "Connect two shapes by id with an arrow, with an optional label.",
                "{\"type\":\"object\",\"properties\":{\"from\":{\"type\":\"string\"},\"to\":{\"type\":\"string\"},\"label\":{\"type\":\"string\"}},\"required\":[\"from\",\"to\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var w = window (app);
                    var doc = w.doc;
                    var from = find (doc.page, text (args, "from")) as Shape;
                    var to = find (doc.page, text (args, "to")) as Shape;
                    if (from == null || to == null) throw new IOError.NOT_FOUND ("both from and to must be shape ids from draw_scene");
                    Connector? c = null;
                    doc.edit (_("Connect"), () => c = make_edge (doc, from, to, text (args, "label")));
                    var made = new Gee.ArrayList<Item> ();
                    made.add (c);
                    show (w, made);
                    return verified (item_node (c), find (doc.page, c.id) != null);
                });
            agent.add_intent ("draw_update", "Change a shape by id: text, type, x, y, w, h, fill (#rrggbb) or text_color.",
                "{\"type\":\"object\",\"properties\":{\"id\":{\"type\":\"string\"},\"text\":{\"type\":\"string\"},\"type\":{\"type\":\"string\"},\"x\":{\"type\":\"number\"},\"y\":{\"type\":\"number\"},\"w\":{\"type\":\"number\"},\"h\":{\"type\":\"number\"},\"fill\":{\"type\":\"string\"},\"text_color\":{\"type\":\"string\"}},\"required\":[\"id\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var w = window (app);
                    var doc = w.doc;
                    var it = find (doc.page, text (args, "id"));
                    if (it == null) throw new IOError.NOT_FOUND ("no item %s".printf (text (args, "id")));
                    doc.edit (_("Change Shape"), () => {
                        if (args.has_member ("text")) it.text = text (args, "text");
                        if (text (args, "fill") != "") it.style.fill = text (args, "fill");
                        if (text (args, "text_color") != "") it.style.text_color = text (args, "text_color");
                        var s = it as Shape;
                        if (s != null) {
                            if (text (args, "type") != "") s.kind = DataSources.kind_for_type (text (args, "type"));
                            if (args.has_member ("x")) s.x = args.get_double_member ("x");
                            if (args.has_member ("y")) s.y = args.get_double_member ("y");
                            if (args.has_member ("w")) s.w = args.get_double_member ("w");
                            if (args.has_member ("h")) s.h = args.get_double_member ("h");
                        }
                    });
                    var shown = new Gee.ArrayList<Item> ();
                    shown.add (it);
                    show (w, shown);
                    bool ok = !args.has_member ("text") || it.text == text (args, "text");
                    return verified (item_node (it), ok);
                });
            agent.add_intent ("draw_delete", "Delete shapes or connectors by id. Undoable with Ctrl+Z.",
                "{\"type\":\"object\",\"properties\":{\"ids\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}},\"required\":[\"ids\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var w = window (app);
                    var doc = w.doc;
                    var doomed = new Gee.ArrayList<Item> ();
                    var ids = args.get_array_member ("ids");
                    for (uint i = 0; i < ids.get_length (); i++) {
                        var it = find (doc.page, ids.get_string_element (i));
                        if (it != null) doomed.add (it);
                    }
                    if (doomed.size == 0) throw new IOError.NOT_FOUND ("none of these ids is on the page");
                    doc.edit (_("Delete"), () => doc.delete_items (doomed));
                    if (w.canvas != null) {
                        w.canvas.selection.clear ();
                        w.canvas.queue_draw ();
                    }
                    int left = 0;
                    foreach (var it in doomed) if (find (doc.page, it.id) != null) left++;
                    var n = scene (doc);
                    n.get_object ().set_int_member ("deleted", doomed.size - left);
                    return verified (n, left == 0);
                });
            agent.add_intent ("draw_save", "Save the open drawing without asking. path is optional: absolute, or a file name placed in Documents; its extension picks the format (odg, svg, vsdx, drawio, fodg, ora). Without path it saves to its own file, or to Documents when it has none. Answers with the saved path.",
                "{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"}}}",
                Singularity.AppIntentRisk.IRREVERSIBLE, (args) => {
                    var w = window (app);
                    var saved = w.save_quietly (text (args, "path"));
                    var n = scene (w.doc);
                    n.get_object ().set_string_member ("path", saved);
                    return verified (n, FileUtils.test (saved, FileTest.EXISTS));
                });
            agent.add_intent ("draw_export", "Export the open drawing to PNG, PDF, SVG or PowerPoint; the extension of path picks the format. PNG and SVG export the current page, PDF every page.",
                "{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"},\"scale\":{\"type\":\"number\"},\"transparent\":{\"type\":\"boolean\"},\"fit_content\":{\"type\":\"boolean\"}},\"required\":[\"path\"]}",
                Singularity.AppIntentRisk.IRREVERSIBLE, (args) => {
                    var w = window (app);
                    var doc = w.doc;
                    string path = text (args, "path");
                    if (!Path.is_absolute (path)) path = Path.build_filename (Environment.get_user_special_dir (UserDirectory.DOCUMENTS) ?? Environment.get_home_dir (), path);
                    string low = path.down ();
                    bool fit = args.has_member ("fit_content") && args.get_boolean_member ("fit_content");
                    if (low.has_suffix (".pdf")) {
                        Export.pdf (doc, path, true, fit);
                    } else if (low.has_suffix (".svg")) {
                        var area = fit ? SvgWriter.content_area (doc.page, null) : SvgWriter.page_area (doc.page);
                        Formats.write_atomic (path, SvgWriter.write_page (doc.page, area, true, null).data);
                    } else if (low.has_suffix (".png")) {
                        var area = fit ? SvgWriter.content_area (doc.page, null) : SvgWriter.page_area (doc.page);
                        double scale = args.has_member ("scale") ? args.get_double_member ("scale").clamp (0.1, 8) : 1;
                        Export.png (doc.page, path, area, scale, args.has_member ("transparent") && args.get_boolean_member ("transparent"), null);
                    } else if (low.has_suffix (".pptx")) {
                        Formats.write_atomic (path, Pptx.save (doc));
                    } else {
                        throw new IOError.INVALID_ARGUMENT ("use a .png, .pdf, .svg or .pptx path");
                    }
                    var n = new Json.Object ();
                    n.set_string_member ("path", path);
                    var node = new Json.Node (Json.NodeType.OBJECT);
                    node.set_object (n);
                    return verified (node, FileUtils.test (path, FileTest.EXISTS));
                });
            agent.add_intent ("draw_layout", "Arrange shapes and their connectors without overlaps: down, right, tree, tree-right, circle, grid or force. Without ids it arranges the whole page.",
                "{\"type\":\"object\",\"properties\":{\"layout\":{\"type\":\"string\"},\"ids\":{\"type\":\"array\",\"items\":{\"type\":\"string\"}}}}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var w = window (app);
                    var doc = w.doc;
                    var items = new Gee.ArrayList<Item> ();
                    if (args.has_member ("ids")) {
                        var ids = args.get_array_member ("ids");
                        for (uint i = 0; i < ids.get_length (); i++) {
                            var it = find (doc.page, ids.get_string_element (i));
                            if (it != null) items.add (it);
                        }
                    } else {
                        items.add_all (doc.page.items);
                    }
                    bool moved = false;
                    doc.edit (_("Arrange"), () => moved = AutoLayout.apply (doc.page, items, layout_kind (text (args, "layout")), 50, 60));
                    show (w, items);
                    return verified (scene (doc), moved);
                });
        }
    }
}
