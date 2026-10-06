namespace Singularity.Apps.Draw {

    public enum FileKind {
        ODG,
        FODG,
        VSDX,
        DRAWIO,
        SVG,
        NATIVE,
        IMAGE,
        ORA,
        VSD,
        UNKNOWN;

        public bool can_save () {
            return this == ODG || this == FODG || this == VSDX || this == DRAWIO || this == SVG || this == NATIVE || this == ORA;
        }
    }

    public delegate Document SvgLoader (string text) throws Error;
    public delegate string SvgDocumentWriter (Document document) throws Error;

    public class Formats {
        public static SvgLoader? svg_loader = null;
        public static SvgDocumentWriter? svg_writer = null;

        public static string[] open_suffixes () {
            return { "odg", "otg", "fodg", "vsdx", "vstx", "vsdm", "vssx", "vsd", "vss", "vst", "vdx", "drawio", "dio", "xml", "svg", "sdraw", "ora", "png", "jpg", "jpeg", "gif", "webp", "bmp" };
        }

        public static FileKind kind_for_path (string path) {
            string low = path.down ();
            if (low.has_suffix (".odg") || low.has_suffix (".otg")) return FileKind.ODG;
            if (low.has_suffix (".fodg")) return FileKind.FODG;
            if (low.has_suffix (".vsdx") || low.has_suffix (".vstx") || low.has_suffix (".vsdm") || low.has_suffix (".vssx") || low.has_suffix (".vssm") || low.has_suffix (".vstm")) return FileKind.VSDX;
            if (low.has_suffix (".vsd") || low.has_suffix (".vss") || low.has_suffix (".vst") || low.has_suffix (".vdx") || low.has_suffix (".vsx") || low.has_suffix (".vtx")) return FileKind.VSD;
            if (low.has_suffix (".drawio") || low.has_suffix (".dio") || low.has_suffix (".drawio.xml")) return FileKind.DRAWIO;
            if (low.has_suffix (".svg")) return FileKind.SVG;
            if (low.has_suffix (".sdraw")) return FileKind.NATIVE;
            if (low.has_suffix (".ora")) return FileKind.ORA;
            if (low.has_suffix (".png") || low.has_suffix (".jpg") || low.has_suffix (".jpeg") || low.has_suffix (".gif") || low.has_suffix (".webp") || low.has_suffix (".bmp")) return FileKind.IMAGE;
            if (low.has_suffix (".xml")) return FileKind.DRAWIO;
            return FileKind.UNKNOWN;
        }

        public static FileKind sniff (uint8[] data, string path) {
            var k = kind_for_path (path);
            if (data.length >= 4 && data[0] == 'P' && data[1] == 'K') {
                try {
                    var zip = new ZipReader (data);
                    if (zip.has ("visio/document.xml")) return FileKind.VSDX;
                    if (zip.has ("stack.xml")) return FileKind.ORA;
                    if (zip.has ("content.xml")) return FileKind.ODG;
                } catch (Error e) {
                }
                return k;
            }
            if (data.length >= 8 && data[0] == 0xd0 && data[1] == 0xcf && data[2] == 0x11 && data[3] == 0xe0) return FileKind.VSD;
            var head = new StringBuilder ();
            for (int i = 0; i < int.min (data.length, 2048); i++) head.append_c ((char) data[i]);
            string h = head.str;
            if (h.contains ("<mxfile") || h.contains ("<mxGraphModel")) return FileKind.DRAWIO;
            if (h.contains ("<VisioDocument")) return FileKind.VSD;
            if (h.contains ("<sdraw")) return FileKind.NATIVE;
            if (h.contains ("<office:document")) return FileKind.FODG;
            if (h.contains ("<svg")) return FileKind.SVG;
            return k;
        }

        public static Document load (string path) throws Error {
            uint8[] data;
            FileUtils.get_data (path, out data);
            var doc = load_data (data, path);
            var k = sniff (data, path);
            doc.path = k.can_save () && k != FileKind.FODG ? path : null;
            if (doc.path == null) doc.title = Path.get_basename (path);
            doc.modified = false;
            doc.clear_history ();
            return doc;
        }

        public static string as_text (uint8[] data) {
            var sb = new StringBuilder.sized (data.length + 1);
            sb.append_len ((string) data, data.length);
            return sb.str;
        }

        public static Document load_data (uint8[] data, string path) throws Error {
            Document doc;
            switch (sniff (data, path)) {
                case FileKind.ODG:
                    doc = Odg.load (data);
                    break;
                case FileKind.FODG:
                    doc = Odg.load_flat (as_text (data));
                    break;
                case FileKind.VSDX:
                    doc = Vsdx.load (data);
                    break;
                case FileKind.DRAWIO:
                    doc = Drawio.load (as_text (data));
                    break;
                case FileKind.SVG:
                    doc = svg_loader != null ? svg_loader (as_text (data)) : SvgReader.load (as_text (data));
                    break;
                case FileKind.NATIVE:
                    doc = NativeFormat.parse_document (as_text (data));
                    break;
                case FileKind.IMAGE:
                    doc = Raster.from_image (data);
                    break;
                case FileKind.ORA:
                    doc = Ora.load (data);
                    break;
                case FileKind.VSD:
                    doc = Vsd.load (data);
                    break;
                default:
                    throw new FormatError.UNSUPPORTED (_("This file type is not supported."));
            }
            doc.sync_ids ();
            doc.ensure_ids ();
            foreach (var p in doc.pages) Router.route_all (p);
            return doc;
        }

        public static ImageShape image_item (uint8[] data, double x = 40, double y = 40) {
            var img = new ImageShape ();
            img.bytes = data;
            img.mime = ImageShape.sniff_mime (data);
            var pix = Renderer.pixbuf_for (img);
            double w = 200, h = 150;
            if (pix != null) {
                w = pix.width;
                h = pix.height;
                double max = 800;
                if (w > max || h > max) {
                    double sc = max / double.max (w, h);
                    w *= sc;
                    h *= sc;
                }
            }
            img.x = x;
            img.y = y;
            img.w = w;
            img.h = h;
            return img;
        }

        public static void save (Document doc, string path) throws Error {
            uint8[] data;
            switch (kind_for_path (path)) {
                case FileKind.VSDX:
                    data = Vsdx.save (doc);
                    break;
                case FileKind.DRAWIO:
                    data = Drawio.save (doc).data;
                    break;
                case FileKind.NATIVE:
                    data = NativeFormat.serialize_document (doc).data;
                    break;
                case FileKind.FODG:
                    data = Odg.save_flat (doc).data;
                    break;
                case FileKind.SVG:
                    data = (svg_writer != null ? svg_writer (doc) : SvgWriter.write_page (doc.page, SvgWriter.page_area (doc.page), true)).data;
                    break;
                case FileKind.ORA:
                    data = Ora.save (doc);
                    break;
                default:
                    data = Odg.save (doc);
                    break;
            }
            write_atomic (path, data);
        }

        public static void write_atomic (string path, uint8[] data) throws Error {
            var file = File.new_for_path (path);
            file.replace_contents (data, null, false, FileCreateFlags.REPLACE_DESTINATION, null);
        }
    }
}
