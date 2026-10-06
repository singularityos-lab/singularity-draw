using Gtk;

namespace Singularity.Apps.Draw {

    public class DrawClipboard {
        public static void copy (Gdk.Clipboard clipboard, Page page, Gee.List<Item> items) {
            if (items.size == 0) return;
            var ordered = new Gee.ArrayList<Item> ();
            foreach (var it in page.items) if (items.contains (it)) ordered.add (it);
            string native = NativeFormat.serialize_items (ordered);
            var area = SvgWriter.content_area (page, ordered, 4);
            string svg = SvgWriter.write_page (page, area, false, ordered);
            var surf = Export.render_area (page, area, 2.0, true, ordered);
            uint8[] png = Export.png_bytes (surf);
            var text = new StringBuilder ();
            foreach (var it in ordered) {
                string t = it.display_text ();
                if (t == "") continue;
                if (text.len > 0) text.append_c ('\n');
                text.append (t);
            }
            Gdk.ContentProvider[] providers = {
                new Gdk.ContentProvider.for_bytes (NativeFormat.MIME, new Bytes (native.data)),
                new Gdk.ContentProvider.for_bytes ("image/svg+xml", new Bytes (svg.data)),
                new Gdk.ContentProvider.for_bytes ("image/png", new Bytes (png))
            };
            if (text.len > 0) providers += new Gdk.ContentProvider.for_bytes ("text/plain;charset=utf-8", new Bytes (text.str.data));
            clipboard.set_content (new Gdk.ContentProvider.union (providers));
        }

        public const string PIXELS_MIME = "application/x-sinty-draw-pixels";

        public class PastedPixels {
            public Cairo.ImageSurface surface;
            public bool has_origin = false;
            public double x = 0;
            public double y = 0;
        }

        public static void copy_pixels (Gdk.Clipboard clipboard, Cairo.ImageSurface surf, double page_x, double page_y) {
            uint8[] png = Export.png_bytes (surf);
            string origin = "%s %s".printf (PathData.fmt (page_x, 3), PathData.fmt (page_y, 3));
            Gdk.ContentProvider[] providers = {
                new Gdk.ContentProvider.for_bytes (PIXELS_MIME, new Bytes (origin.data)),
                new Gdk.ContentProvider.for_bytes ("image/png", new Bytes (png))
            };
            clipboard.set_content (new Gdk.ContentProvider.union (providers));
        }

        public static async PastedPixels? paste_pixels (Gdk.Clipboard clipboard, Page page) {
            var formats = clipboard.get_formats ();
            var result = new PastedPixels ();
            if (formats.contain_mime_type (NativeFormat.MIME)) {
                var data = yield read_mime (clipboard, NativeFormat.MIME);
                if (data != null) {
                    Gee.ArrayList<Item>? items = null;
                    try {
                        items = NativeFormat.parse_items (Formats.as_text (data));
                    } catch (Error e) {
                        items = null;
                    }
                    if (items != null && items.size > 0) {
                        var area = SvgWriter.content_area (page, items, 0);
                        var r = Raster.item_for (page, page.active_layer);
                        double scale = r != null ? r.pixel_scale () : 1;
                        result.surface = Export.render_area (page, area, scale, true, items);
                        result.has_origin = true;
                        result.x = area.x;
                        result.y = area.y;
                        return result;
                    }
                }
            }
            foreach (string mime in new string[] { "image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp" }) {
                if (!formats.contain_mime_type (mime)) continue;
                var data = yield read_mime (clipboard, mime);
                if (data == null) continue;
                var surf = Pixels.decode (data);
                if (surf == null) continue;
                result.surface = surf;
                if (formats.contain_mime_type (PIXELS_MIME)) {
                    var origin = yield read_mime (clipboard, PIXELS_MIME);
                    string[] v = origin != null ? Formats.as_text (origin).strip ().split (" ") : new string[0];
                    if (v.length == 2) {
                        result.has_origin = true;
                        result.x = double.parse (v[0]);
                        result.y = double.parse (v[1]);
                    }
                }
                return result;
            }
            if (formats.contain_gtype (typeof (Gdk.Texture))) {
                try {
                    var tex = yield clipboard.read_texture_async (null);
                    if (tex != null) {
                        var surf = Pixels.decode (tex.save_to_png_bytes ().get_data ());
                        if (surf != null) {
                            result.surface = surf;
                            return result;
                        }
                    }
                } catch (Error e) {
                    return null;
                }
            }
            return null;
        }

        private static async uint8[]? read_mime (Gdk.Clipboard clipboard, string mime) {
            try {
                string out_mime;
                var stream = yield clipboard.read_async ({ mime }, Priority.DEFAULT, null, out out_mime);
                var mem = new MemoryOutputStream.resizable ();
                yield mem.splice_async (stream, OutputStreamSpliceFlags.CLOSE_SOURCE | OutputStreamSpliceFlags.CLOSE_TARGET, Priority.DEFAULT, null);
                uint8[] data = mem.steal_data ();
                data.length = (int) mem.get_data_size ();
                return data;
            } catch (Error e) {
                return null;
            }
        }

        public static async Gee.ArrayList<Item>? paste (Gdk.Clipboard clipboard, Document doc) {
            var formats = clipboard.get_formats ();
            try {
                if (formats.contain_mime_type (NativeFormat.MIME)) {
                    var data = yield read_mime (clipboard, NativeFormat.MIME);
                    if (data != null) return doc.clone_with_new_ids (NativeFormat.parse_items (Formats.as_text (data)));
                }
                if (formats.contain_mime_type ("image/svg+xml")) {
                    var data = yield read_mime (clipboard, "image/svg+xml");
                    if (data != null) return SvgReader.import_items (Formats.as_text (data), doc);
                }
                foreach (string mime in new string[] { "image/png", "image/jpeg", "image/gif", "image/webp", "image/bmp" }) {
                    if (!formats.contain_mime_type (mime)) continue;
                    var data = yield read_mime (clipboard, mime);
                    if (data == null) continue;
                    var list = new Gee.ArrayList<Item> ();
                    list.add (Formats.image_item (data, 0, 0));
                    return list;
                }
                if (formats.contain_gtype (typeof (Gdk.Texture))) {
                    var tex = yield clipboard.read_texture_async (null);
                    if (tex != null) {
                        var list = new Gee.ArrayList<Item> ();
                        list.add (Formats.image_item (tex.save_to_png_bytes ().get_data (), 0, 0));
                        return list;
                    }
                }
                string? text = yield clipboard.read_text_async (null);
                if (text == null || text.strip () == "") return null;
                string t = text.strip ();
                if (t.has_prefix ("<svg") || (t.has_prefix ("<?xml") && t.contains ("<svg"))) return SvgReader.import_items (t, doc);
                if (t.has_prefix ("<mxfile") || t.has_prefix ("<mxGraphModel")) {
                    var d = Drawio.load (t);
                    return doc.clone_with_new_ids (d.page.items);
                }
                var s = new Shape ("text", 0, 0, 200, 30);
                ShapeLibrary.apply_defaults (s);
                s.text = t;
                s.style.halign = TextHAlign.LEFT;
                var block = SvgWriter.measure (s.style, t, 400, true);
                s.w = double.max (block.width + 12, 40);
                s.h = double.max (block.height + 8, 24);
                var list = new Gee.ArrayList<Item> ();
                list.add (s);
                return list;
            } catch (Error e) {
                return null;
            }
        }
    }
}
