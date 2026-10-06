namespace Singularity.Apps.Draw {

    public class Vsd {
        public const uint32 NONE = uint32.MAX;

        public static Document load (uint8[] data) throws Error {
            return parse (data).build_document ();
        }

        public static UserStencil load_stencil (uint8[] data) throws Error {
            return parse (data).build_stencil ();
        }

        public static int version_of (uint8[] data) {
            try {
                var cfb = new CompoundFile (data);
                var s = cfb.read ("VisioDocument");
                if (s == null || s.length <= 0x1a) return -1;
                return s[0x1a];
            } catch (Error e) {
                return -1;
            }
        }

        private static bool is_xml (uint8[] data) {
            for (int i = 0; i < int.min (data.length, 64); i++) {
                if (data[i] == '<') return true;
                if (data[i] != ' ' && data[i] != '\n' && data[i] != '\r' && data[i] != '\t' && data[i] != 0xef && data[i] != 0xbb && data[i] != 0xbf) return false;
            }
            return false;
        }

        private static VsdModel parse (uint8[] data) throws Error {
            if (is_xml (data)) return VdxParser.parse (Formats.as_text (data));
            var cfb = new CompoundFile (data);
            var stream = cfb.read ("VisioDocument");
            if (stream == null || stream.length < 0x40) throw new FormatError.INVALID (_("This is not a Visio drawing."));
            var parser = new VsdParser (stream);
            parser.parse ();
            return parser.model;
        }

        public static string ansi (uint8[] bytes) {
            var sb = new StringBuilder ();
            foreach (uint8 b in bytes) {
                if (b == 0) break;
                sb.append_c ((char) b);
            }
            try {
                return convert (sb.str, -1, "UTF-8", "WINDOWS-1252");
            } catch (Error e) {
                return sb.str.make_valid ();
            }
        }

        public static string utf16 (uint8[] bytes) {
            var sb = new StringBuilder ();
            int i = 0;
            while (i + 1 < bytes.length) {
                uint c = bytes[i] | (bytes[i + 1] << 8);
                i += 2;
                if (c == 0) break;
                if (c >= 0xd800 && c < 0xdc00 && i + 1 < bytes.length) {
                    uint lo = bytes[i] | (bytes[i + 1] << 8);
                    if (lo >= 0xdc00 && lo < 0xe000) {
                        i += 2;
                        sb.append_unichar ((unichar) (0x10000 + ((c - 0xd800) << 10) + (lo - 0xdc00)));
                        continue;
                    }
                }
                if (c >= 0xd800 && c < 0xe000) continue;
                sb.append_unichar ((unichar) c);
            }
            return sb.str;
        }
    }

    private class VsdBuf {
        public uint8[] d;
        public long pos = 0;

        public VsdBuf (owned uint8[] d) {
            this.d = (owned) d;
        }

        public long length {
            get { return d.length; }
        }

        public bool at_end () {
            return pos >= d.length;
        }

        public void seek (long p) {
            pos = p < 0 ? 0 : (p > d.length ? d.length : p);
        }

        public void skip (long n) {
            seek (pos + n);
        }

        public long remaining () {
            return d.length - pos;
        }

        public uint8 u8 () {
            if (pos >= d.length) {
                pos = d.length;
                return 0;
            }
            return d[pos++];
        }

        public uint32 u16 () {
            uint32 a = u8 ();
            uint32 b = u8 ();
            return a | (b << 8);
        }

        public uint32 u32 () {
            uint32 a = u16 ();
            uint32 b = u16 ();
            return a | (b << 16);
        }

        public int s16 () {
            return (int) (int16) u16 ();
        }

        public int s32 () {
            return (int) (int32) u32 ();
        }

        public double dbl () {
            uint64 lo = u32 ();
            uint64 hi = u32 ();
            uint64 bits = lo | (hi << 32);
            double* p = (double*) (&bits);
            double v = *p;
            if (v.is_nan () || v.is_infinity () != 0 || v.abs () > 1e12) return 0;
            return v;
        }

        public uint8[] bytes (long n) {
            if (n < 0) n = 0;
            if (n > remaining ()) n = remaining ();
            var r = new uint8[n];
            for (long i = 0; i < n; i++) r[i] = d[pos + i];
            pos += n;
            return r;
        }
    }

    private class VsdProps {
        public bool has_line = false;
        public double line_width = 0.01;
        public string line_color = "#000000";
        public double line_trans = 0;
        public int line_pattern = 1;
        public int begin_arrow = 0;
        public int end_arrow = 0;
        public double arrow_size = 2;
        public double rounding = 0;
        public bool has_fill = false;
        public string fill_color = "#ffffff";
        public double fill_trans = 0;
        public string fill_bg = "#ffffff";
        public int fill_pattern = 1;
        public int shadow_pattern = 0;
        public string shadow_color = "#000000";
        public bool has_char = false;
        public double font_size = 12.0 / 72.0;
        public string text_color = "#000000";
        public double text_trans = 0;
        public int char_style = 0;
        public bool strike = false;
        public string font = "";
        public bool has_para = false;
        public int align = 1;
        public bool has_block = false;
        public int valign = 1;
    }

    private class VsdRow {
        public int kind;
        public uint32 id;
        public double x;
        public double y;
        public double a;
        public double b;
        public double c;
        public double d;
        public double[] pts = {};
        public double[] knots = {};
        public double[] weights = {};
        public int degree = 3;
        public int xtype = 1;
        public int ytype = 1;
        public uint32 data_id = Vsd.NONE;
        public double knot = 0;
        public double knot_prev = 0;
        public double weight = 1;
        public double weight_prev = 1;
    }

    private class VsdGeom {
        public bool no_fill = false;
        public bool no_line = false;
        public bool no_show = false;
        public Gee.ArrayList<VsdRow> rows = new Gee.ArrayList<VsdRow> ();
        public uint32[] order = {};

        public Gee.ArrayList<VsdRow> ordered () {
            if (order.length == 0) {
                var list = new Gee.ArrayList<VsdRow> ();
                list.add_all (rows);
                list.sort ((a, b) => a.id < b.id ? -1 : (a.id > b.id ? 1 : 0));
                return list;
            }
            var list = new Gee.ArrayList<VsdRow> ();
            foreach (uint32 id in order) foreach (var r in rows) if (r.id == id && !list.contains (r)) list.add (r);
            foreach (var r in rows) if (!list.contains (r)) list.add (r);
            return list;
        }
    }

    private class VsdPolyData {
        public bool nurbs = false;
        public int xtype = 1;
        public int ytype = 1;
        public int degree = 3;
        public double last_knot = 0;
        public double[] pts = {};
        public double[] knots = {};
        public double[] weights = {};
    }

    private class VsdShape {
        public uint32 id = Vsd.NONE;
        public uint32 type = 0x48;
        public uint32 parent = 0;
        public uint32 master_page = Vsd.NONE;
        public uint32 master_shape = Vsd.NONE;
        public uint32 line_style = Vsd.NONE;
        public uint32 fill_style = Vsd.NONE;
        public uint32 text_style = Vsd.NONE;
        public bool has_xform = false;
        public double pin_x;
        public double pin_y;
        public double width;
        public double height;
        public double loc_x;
        public double loc_y;
        public double angle;
        public bool flip_x;
        public bool flip_y;
        public bool one_d = false;
        public double bx;
        public double by;
        public double ex;
        public double ey;
        public uint32 begin_id = Vsd.NONE;
        public uint32 end_id = Vsd.NONE;
        public VsdProps props = new VsdProps ();
        public Gee.ArrayList<VsdGeom> geoms = new Gee.ArrayList<VsdGeom> ();
        public string? text = null;
        public uint8[]? foreign = null;
        public int foreign_type = -1;
        public int foreign_format = 0;
        public uint32[] order = {};
        public Gee.ArrayList<DataField> fields = new Gee.ArrayList<DataField> ();
        public string link = "";
        public string name = "";
        public string layers = "";
        public Gee.HashMap<uint32, string> names = new Gee.HashMap<uint32, string> ();
        public Gee.HashMap<uint32, VsdPolyData> data = new Gee.HashMap<uint32, VsdPolyData> ();
    }

    private class VsdConnect {
        public uint32 from;
        public bool begin;
        public uint32 to;
    }

    private class VsdLayer {
        public uint32 id;
        public string name = "";
        public bool visible = true;
        public bool printable = true;
    }

    private class VsdPage {
        public uint32 id;
        public string name = "";
        public bool background = false;
        public uint32 back_id = Vsd.NONE;
        public double width = 8.5;
        public double height = 11;
        public Gee.ArrayList<VsdShape> shapes = new Gee.ArrayList<VsdShape> ();
        public uint32[] order = {};
        public Gee.ArrayList<VsdLayer> layers = new Gee.ArrayList<VsdLayer> ();
        public Gee.ArrayList<VsdConnect> connects = new Gee.ArrayList<VsdConnect> ();

        public VsdShape? find (uint32 id) {
            foreach (var s in shapes) if (s.id == id) return s;
            return null;
        }

        public bool is_top (VsdShape s) {
            return s.parent == 0 || s.parent == Vsd.NONE || s.parent == s.id || find (s.parent) == null;
        }

        private Gee.ArrayList<VsdShape> sort_by (Gee.ArrayList<VsdShape> list, uint32[] ids) {
            if (ids.length == 0) return list;
            var result = new Gee.ArrayList<VsdShape> ();
            foreach (uint32 id in ids) foreach (var s in list) if (s.id == id && !result.contains (s)) result.add (s);
            foreach (var s in list) if (!result.contains (s)) result.add (s);
            return result;
        }

        public Gee.ArrayList<VsdShape> top () {
            var list = new Gee.ArrayList<VsdShape> ();
            foreach (var s in shapes) if (is_top (s)) list.add (s);
            return sort_by (list, order);
        }

        public Gee.ArrayList<VsdShape> children_of (VsdShape g) {
            var list = new Gee.ArrayList<VsdShape> ();
            foreach (var s in shapes) if (s != g && s.parent == g.id && s.id != g.id) list.add (s);
            return sort_by (list, g.order);
        }

        public VsdShape? first () {
            var t = top ();
            return t.size > 0 ? t[0] : null;
        }
    }

    private class VsdModel {
        public int version = 11;
        public Gee.ArrayList<VsdPage> pages = new Gee.ArrayList<VsdPage> ();
        public Gee.ArrayList<VsdPage> masters = new Gee.ArrayList<VsdPage> ();
        public Gee.HashMap<uint32, VsdShape> styles = new Gee.HashMap<uint32, VsdShape> ();

        public VsdPage? master (uint32 id) {
            foreach (var m in masters) if (m.id == id) return m;
            return null;
        }

        public Document build_document () throws Error {
            var b = new VsdBuilder (this);
            return b.document ();
        }

        public UserStencil build_stencil () throws Error {
            var b = new VsdBuilder (this);
            return b.stencil ();
        }
    }

    private class VsdPtr {
        public uint32 type;
        public uint32 offset;
        public uint32 length;
        public uint32 format;
    }

    private class VsdParser {
        private uint8[] doc;
        private int version = 11;
        public VsdModel model = new VsdModel ();
        private uint32 h_type = 0;
        private uint32 h_id = 0;
        private uint32 h_list = 0;
        private long h_len = 0;
        private uint32 h_level = 0;
        private uint32 h_unknown = 0;
        private long h_trailer = 0;
        private uint32 cur_level = 0;
        private uint32 shape_level = 0;
        private VsdShape? cur = null;
        private int cur_role = 0;
        private VsdGeom? cur_geom = null;
        private bool in_styles = false;
        private VsdPage? page = null;
        private uint32 cur_shape_id = Vsd.NONE;
        private string[] colors = {};
        private Gee.HashMap<uint32, string> fonts = new Gee.HashMap<uint32, string> ();
        private Gee.HashMap<uint32, string> names = new Gee.HashMap<uint32, string> ();
        private Gee.HashMap<uint32, Gee.HashMap<uint32, string>> name_maps = new Gee.HashMap<uint32, Gee.HashMap<uint32, string>> ();
        private Gee.HashSet<uint32> visited = new Gee.HashSet<uint32> ();
        private int depth = 0;
        private int stream_count = 0;
        private string page_name = "";

        public VsdParser (uint8[] doc) {
            this.doc = doc;
        }

        public void parse () throws Error {
            int v = doc[0x1a];
            if (v == 11) version = 11;
            else if (v == 6) version = 6;
            else if (v >= 1 && v <= 5) version = 5;
            else throw new FormatError.UNSUPPORTED (_("This version of Visio drawings is not supported."));
            model.version = version;
            var b = new VsdBuf (doc);
            b.seek (0x24);
            var ptr = read_pointer (b);
            bool compressed = (ptr.format & 2) == 2;
            var trailer = new VsdBuf (decompress (ptr.offset, ptr.length, compressed));
            if (trailer.length == 0) throw new FormatError.INVALID (_("This Visio drawing is damaged."));
            handle_streams (trailer, 0x14, compressed ? 4 : 0, 0);
            level_change (0);
            flush ();
        }

        private uint8[] decompress (uint32 offset, uint32 length, bool compressed) {
            if (offset >= doc.length) return new uint8[0];
            long len = long.min (length, doc.length - offset);
            if (len < 2) return new uint8[0];
            if (!compressed) {
                var r = new uint8[len];
                for (long i = 0; i < len; i++) r[i] = doc[offset + i];
                return r;
            }
            var out_buf = new ByteArray ();
            var ring = new uint8[4096];
            uint pos = 0;
            long o = offset;
            long end = offset + len;
            while (o < end && out_buf.len < 64 * 1024 * 1024) {
                uint flag = doc[o++];
                if (o > end - 1) break;
                uint mask = 1;
                for (int bit = 0; bit < 8 && o < end; bit++) {
                    if ((flag & mask) != 0) {
                        uint8 c = doc[o++];
                        ring[pos & 4095] = c;
                        out_buf.append ({ c });
                        pos++;
                    } else {
                        if (o > end - 2) break;
                        uint a1 = doc[o++];
                        uint a2 = doc[o++];
                        uint length_c = (a2 & 15) + 3;
                        uint pointer = ((a2 & 0xf0) << 4) | a1;
                        if (pointer > 4078) pointer -= 4078;
                        else pointer += 18;
                        for (uint j = 0; j < length_c; j++) {
                            uint8 c = ring[(pointer + j) & 4095];
                            ring[(pos + j) & 4095] = c;
                            out_buf.append ({ c });
                        }
                        pos += length_c;
                    }
                    mask <<= 1;
                }
            }
            return out_buf.steal ();
        }

        private VsdPtr read_pointer (VsdBuf b) {
            var p = new VsdPtr ();
            if (version == 5) {
                p.type = b.u16 () & 0xff;
                p.format = b.u16 () & 0xff;
                b.skip (4);
                p.offset = b.u32 ();
                p.length = b.u32 ();
            } else {
                p.type = b.u32 ();
                b.skip (4);
                p.offset = b.u32 ();
                p.length = b.u32 ();
                p.format = b.u16 ();
            }
            return p;
        }

        private uint32 get_uint (VsdBuf b) {
            if (version == 5) return (uint32) b.s16 ();
            return b.u32 ();
        }

        private void handle_streams (VsdBuf b, uint32 ptr_type, int shift, uint32 level) {
            if (depth > 48 || stream_count > 200000) return;
            depth++;
            uint32 list_size = 0;
            int count = 0;
            if (version == 5) {
                long at;
                switch (ptr_type) {
                    case 0x14: at = 0x82; break;
                    case 0x15: at = 0x42; break;
                    case 0x18: at = 0x2e; break;
                    case 0x1a: at = 0x12; break;
                    case 0x1d:
                    case 0x4e: at = 0x1e; break;
                    case 0x1e: at = 0x36; break;
                    default: at = ptr_type > 0x45 ? 0x1e : 0xa; break;
                }
                b.seek (shift + at);
                count = b.s16 ();
            } else {
                b.seek (shift);
                long off = b.u32 ();
                b.seek (off + shift - 4);
                list_size = b.u32 ();
                count = b.s32 ();
                b.skip (4);
            }
            if (count < 0 || count > 20000) count = 0;
            var ptrs = new Gee.TreeMap<int, VsdPtr> ();
            var name_lists = new Gee.TreeMap<int, VsdPtr> ();
            var name_idx = new Gee.TreeMap<int, VsdPtr> ();
            var faces = new Gee.TreeMap<int, VsdPtr> ();
            for (int i = 0; i < count && !b.at_end (); i++) {
                var p = read_pointer (b);
                if (p.type == 0) continue;
                if (p.type == 0xd8) faces[i] = p;
                else if (p.type == 0x32) name_lists[i] = p;
                else if (p.type == 0xc9 || p.type == 0x34) name_idx[i] = p;
                else ptrs[i] = p;
            }
            uint32[] order = {};
            if (list_size > 1 && list_size < 20000) {
                for (uint32 i = 0; i < list_size && !b.at_end (); i++) order += b.u32 ();
            }
            foreach (var e in name_lists.entries) handle_stream (e.value, e.key, level + 1);
            foreach (var e in name_idx.entries) handle_stream (e.value, e.key, level + 1);
            foreach (var e in faces.entries) handle_stream (e.value, e.key, level + 1);
            foreach (uint32 j in order) {
                if (ptrs.has_key ((int) j)) {
                    var p = ptrs[(int) j];
                    ptrs.unset ((int) j);
                    handle_stream (p, (int) j, level + 1);
                }
            }
            foreach (var e in ptrs.entries) handle_stream (e.value, e.key, level + 1);
            depth--;
        }

        private string name_for (uint32 idx, uint32 level) {
            if (name_maps.has_key (level)) {
                var m = name_maps[level];
                if (m.has_key (idx)) return m[idx];
            }
            return "";
        }

        private void handle_stream (VsdPtr ptr, int idx, uint32 level) {
            if (++stream_count > 200000) return;
            h_level = level;
            h_id = idx;
            h_type = ptr.type;
            level_change (level);
            switch (ptr.type) {
                case 0x1a:
                    in_styles = true;
                    break;
                case 0x15:
                    flush ();
                    page = new VsdPage ();
                    page.id = idx;
                    page.background = (ptr.format & 1) == 0;
                    page.name = name_for (idx, level + 1);
                    model.pages.add (page);
                    break;
                case 0x1e:
                    flush ();
                    page = new VsdPage ();
                    page.id = idx;
                    page.name = name_for (idx, level + 1);
                    model.masters.add (page);
                    break;
                case 0x47:
                case 0x48:
                case 0x4e:
                    cur_shape_id = idx;
                    break;
            }
            bool compressed = (ptr.format & 2) == 2;
            var data = new VsdBuf (decompress (ptr.offset, ptr.length, compressed));
            h_len = data.length;
            int shift = compressed ? 4 : 0;
            uint32 kind = (ptr.format >> 4) & 0xf;
            if (kind == 4 || kind == 5 || kind == 0) {
                handle_blob (data, shift, level + 1);
                if (kind == 5 && ptr.type != 0x16 && !visited.contains (ptr.offset)) {
                    visited.add (ptr.offset);
                    handle_streams (data, ptr.type, shift, level + 1);
                }
            } else if (kind == 0xd || kind == 0xc || kind == 8) {
                handle_chunks (data, level + 1);
            }
            switch (ptr.type) {
                case 0x1a:
                    level_change (0);
                    flush ();
                    in_styles = false;
                    break;
                case 0x15:
                case 0x1e:
                    level_change (0);
                    flush ();
                    page = null;
                    break;
            }
        }

        private void handle_blob (VsdBuf b, int shift, uint32 level) {
            h_level = level;
            b.seek (shift);
            h_len -= shift;
            h_trailer = 0;
            level_change (level);
            handle_chunk (b);
        }

        private bool chunk_header (VsdBuf b) {
            uint8 c = 0;
            while (!b.at_end () && c == 0) c = b.u8 ();
            if (b.at_end () && c == 0) return false;
            b.skip (-1);
            if (version == 5) {
                h_type = get_uint (b);
                h_id = get_uint (b);
                h_level = b.u8 ();
                h_unknown = b.u8 ();
                h_trailer = 0;
                h_list = get_uint (b);
                h_len = b.u32 ();
                return true;
            }
            h_type = b.u32 ();
            h_id = b.u32 ();
            h_list = b.u32 ();
            h_trailer = 0;
            if (version == 6) {
                uint32[] with_trailer = { 0x76, 0x73, 0x72, 0x71, 0x70, 0x6f, 0x6e, 0x6d, 0x6c, 0x6b, 0x6a, 0x69, 0x68, 0x67, 0x66, 0x65, 0x64, 0x2c, 0xd };
                if (h_list != 0 || h_type in with_trailer) h_trailer += 8;
                h_len = b.u32 ();
                h_level = b.u16 ();
                h_unknown = b.u8 ();
                if (h_type == 0x1f || h_type == 0xc9) h_trailer = 0;
                return true;
            }
            uint32[] eight = { 0x71, 0x70, 0x6b, 0x6a, 0x69, 0x66, 0x65, 0x2c };
            if (h_list != 0 || h_type in eight) h_trailer += 8;
            h_len = b.u32 ();
            h_level = b.u16 ();
            h_unknown = b.u8 ();
            if (h_list != 0 || (h_level == 2 && h_unknown == 0x55) || (h_level == 2 && h_unknown == 0x54 && h_type == 0xaa)
                || (h_level == 3 && h_unknown != 0x50 && h_unknown != 0x54)) {
                h_trailer += 4;
            }
            uint32[] extra = { 0x64, 0x65, 0x66, 0x69, 0x6a, 0x6b, 0x6f, 0x71, 0x92, 0xa9, 0xb4, 0xb6, 0xb9, 0xc7 };
            if (h_type in extra && h_trailer != 12 && h_trailer != 4) h_trailer += 4;
            if (h_type == 0x1f || h_type == 0xc9 || h_type == 0x2d || h_type == 0xd1) h_trailer = 0;
            return true;
        }

        private void handle_chunks (VsdBuf b, uint32 level) {
            int guard = 0;
            while (!b.at_end () && guard++ < 1000000) {
                long before = b.pos;
                if (!chunk_header (b)) return;
                h_level += level;
                if (h_len < 0 || h_len > b.length) h_len = b.remaining ();
                long end = b.pos + h_len + h_trailer;
                level_change (h_level);
                long start = b.pos;
                handle_chunk (b);
                if (end <= before) break;
                b.seek (end);
                if (b.pos <= start && h_len == 0 && h_trailer == 0 && b.pos <= before) break;
            }
        }

        private void handle_records (VsdBuf b) {
            long start = b.pos;
            long end = start + h_len;
            if (end > b.length) end = b.length;
            b.seek (end - 4);
            uint32 n = b.u16 ();
            long header_pos = end - 4 * ((long) n + 1);
            if (header_pos <= start) return;
            long end_offset = b.u16 ();
            if (end_offset > header_pos - start) end_offset = header_pos - start;
            var records = new Gee.TreeMap<long, uint32> ();
            var lengths = new Gee.HashMap<long, long> ();
            b.seek (header_pos);
            for (uint32 i = 0; i < n; i++) {
                uint32 type = b.u16 ();
                long offset = b.u16 ();
                long tmp = offset;
                while (tmp % 4 != 0) tmp++;
                if (tmp < end_offset) {
                    records[tmp] = type;
                    lengths[tmp] = end_offset - tmp;
                    end_offset = offset;
                }
            }
            uint32 level = h_level + 1;
            uint32 id = 0;
            foreach (var e in records.entries) {
                h_type = e.value;
                h_len = lengths[e.key];
                h_level = level;
                h_id = id++;
                h_trailer = 0;
                b.seek (start + e.key);
                handle_chunk (b);
            }
        }

        private void level_change (uint32 level) {
            if (level == cur_level) return;
            if (cur != null && level <= shape_level) flush ();
            cur_level = level;
        }

        private void flush () {
            if (cur == null) return;
            if (cur_role == 1) {
                model.styles[cur.id] = cur;
            } else if (cur_role == 0 && page != null) {
                page.shapes.add (cur);
            }
            cur = null;
            cur_geom = null;
            shape_level = 0;
        }

        private string color_from_index (uint idx) {
            if (idx < colors.length) return colors[idx];
            return "#000000";
        }

        private static string hex (uint r, uint g, uint b) {
            return "#%02x%02x%02x".printf (r & 0xff, g & 0xff, b & 0xff);
        }

        private string read_text_bytes (VsdBuf b, long n) {
            var bytes = b.bytes (n);
            if (version == 11) return Vsd.utf16 (bytes);
            return Vsd.ansi (bytes);
        }

        private uint32[] read_order (VsdBuf b) {
            uint32[] ids = {};
            if (h_trailer == 0) return ids;
            uint32 sub = b.u32 ();
            uint32 children = b.u32 ();
            b.skip (sub);
            if (children > b.remaining ()) children = (uint32) b.remaining ();
            for (uint32 i = 0; i < children / 4; i++) ids += b.u32 ();
            return ids;
        }

        private VsdGeom geom () {
            if (cur_geom == null) {
                cur_geom = new VsdGeom ();
                if (cur != null) cur.geoms.add (cur_geom);
            }
            return cur_geom;
        }

        private void add_row (VsdRow r) {
            if (cur == null) return;
            r.id = h_id;
            geom ().rows.add (r);
        }

        private void handle_chunk (VsdBuf b) {
            long start = b.pos;
            switch (h_type) {
                case 0x47:
                case 0x48:
                case 0x4e:
                    read_shape (b);
                    break;
                case 0x4a:
                    flush ();
                    cur = new VsdShape ();
                    cur.id = h_id;
                    cur_role = 1;
                    shape_level = h_level;
                    if (version == 5) {
                        b.skip (10);
                        cur.line_style = get_uint (b);
                        cur.fill_style = get_uint (b);
                        cur.text_style = get_uint (b);
                    } else {
                        b.skip (0x22);
                        cur.line_style = b.u32 ();
                        b.skip (4);
                        cur.fill_style = b.u32 ();
                        b.skip (4);
                        cur.text_style = b.u32 ();
                    }
                    break;
                case 0x46:
                    flush ();
                    cur = new VsdShape ();
                    cur_role = 2;
                    shape_level = h_level;
                    break;
                case 0x9b:
                    if (cur == null) break;
                    b.skip (1);
                    cur.pin_x = b.dbl ();
                    b.skip (1);
                    cur.pin_y = b.dbl ();
                    b.skip (1);
                    cur.width = b.dbl ();
                    b.skip (1);
                    cur.height = b.dbl ();
                    b.skip (1);
                    cur.loc_x = b.dbl ();
                    b.skip (1);
                    cur.loc_y = b.dbl ();
                    b.skip (1);
                    cur.angle = b.dbl ();
                    cur.flip_x = b.u8 () != 0;
                    cur.flip_y = b.u8 () != 0;
                    cur.has_xform = true;
                    break;
                case 0x9d:
                    if (cur == null) break;
                    b.skip (1);
                    cur.bx = b.dbl ();
                    b.skip (1);
                    cur.by = b.dbl ();
                    b.skip (1);
                    cur.ex = b.dbl ();
                    b.skip (1);
                    cur.ey = b.dbl ();
                    cur.one_d = true;
                    break;
                case 0x65:
                    if (version == 5) {
                        handle_records (b);
                        break;
                    }
                    var ids = read_order (b);
                    if (ids.length == 0) break;
                    if (cur != null && cur_role == 0) cur.order = ids;
                    else if (page != null) page.order = ids;
                    break;
                case 0x83:
                    uint32 sid = get_uint (b);
                    if (cur != null && cur_role == 0) {
                        uint32[] o = cur.order;
                        o += sid;
                        cur.order = o;
                    } else if (page != null) {
                        uint32[] o = page.order;
                        o += sid;
                        page.order = o;
                    }
                    break;
                case 0x85:
                    read_line (b);
                    break;
                case 0x86:
                    read_fill (b);
                    break;
                case 0x6c:
                    if (cur == null) break;
                    cur_geom = new VsdGeom ();
                    cur.geoms.add (cur_geom);
                    if (version == 5) handle_records (b);
                    else cur_geom.order = read_order (b);
                    break;
                case 0x89:
                    if (cur == null) break;
                    uint8 flags = b.u8 ();
                    var g = geom ();
                    g.no_fill = (flags & 1) != 0;
                    g.no_line = (flags & 2) != 0;
                    g.no_show = (flags & 4) != 0;
                    break;
                case 0x8a:
                case 0x8b:
                    var r = new VsdRow ();
                    r.kind = (int) h_type;
                    b.skip (1);
                    r.x = b.dbl ();
                    b.skip (1);
                    r.y = b.dbl ();
                    add_row (r);
                    break;
                case 0x8c:
                    var r = new VsdRow ();
                    r.kind = 0x8c;
                    b.skip (1);
                    r.x = b.dbl ();
                    b.skip (1);
                    r.y = b.dbl ();
                    b.skip (1);
                    r.a = b.dbl ();
                    add_row (r);
                    break;
                case 0x8f:
                case 0x90:
                case 0x8d:
                    var r = new VsdRow ();
                    r.kind = (int) h_type;
                    b.skip (1);
                    r.x = b.dbl ();
                    b.skip (1);
                    r.y = b.dbl ();
                    b.skip (1);
                    r.a = b.dbl ();
                    b.skip (1);
                    r.b = b.dbl ();
                    if (h_type != 0x8d) {
                        b.skip (1);
                        r.c = b.dbl ();
                        b.skip (1);
                        r.d = b.dbl ();
                    }
                    add_row (r);
                    break;
                case 0xa5:
                case 0xa6:
                    var r = new VsdRow ();
                    r.kind = (int) h_type;
                    b.skip (1);
                    r.x = b.dbl ();
                    b.skip (1);
                    r.y = b.dbl ();
                    add_row (r);
                    break;
                case 0xc3:
                    read_nurbs (b, start);
                    break;
                case 0xc1:
                    read_polyline (b, start);
                    break;
                case 0xd1:
                    read_shape_data (b);
                    break;
                case 0x98:
                    if (cur == null) break;
                    b.skip (1);
                    b.dbl ();
                    b.skip (1);
                    b.dbl ();
                    b.skip (1);
                    b.dbl ();
                    b.skip (1);
                    b.dbl ();
                    int ftype = (int) b.u16 ();
                    uint32 map_mode = b.u16 ();
                    if (map_mode == 8) ftype = 4;
                    b.skip (9);
                    cur.foreign_type = ftype;
                    cur.foreign_format = (int) b.u32 ();
                    break;
                case 0x0c:
                    if (cur != null) cur.foreign = b.bytes (h_len);
                    break;
                case 0x1f:
                    if (cur != null && cur.foreign == null) cur.foreign = b.bytes (h_len);
                    break;
                case 0xc9:
                    read_name_idx (b);
                    break;
                case 0x34:
                    var map = new Gee.HashMap<uint32, string> ();
                    long stop = b.pos + h_len;
                    while (!b.at_end () && b.pos < stop) {
                        uint32 nid = get_uint (b);
                        uint32 eid = get_uint (b);
                        if (names.has_key (nid)) map[eid] = names[nid];
                    }
                    name_maps[h_level] = map;
                    break;
                case 0x92:
                    b.skip (1);
                    double pw = b.dbl ();
                    b.skip (1);
                    double ph = b.dbl ();
                    if (page != null && pw > 0 && ph > 0) {
                        page.width = pw;
                        page.height = ph;
                    }
                    break;
                case 0x69:
                case 0x6a:
                case 0x6b:
                case 0x66:
                case 0x68:
                case 0x6f:
                    if (version == 5) handle_records (b);
                    break;
                case 0x0e:
                    if (cur == null) break;
                    b.skip (8);
                    cur.text = read_text_bytes (b, h_len - 8);
                    break;
                case 0x94:
                    read_char (b);
                    break;
                case 0x95:
                    if (cur == null || cur.props.has_para) break;
                    b.skip (version == 5 ? 2 : 4);
                    b.skip (54);
                    cur.props.align = b.u8 ();
                    cur.props.has_para = true;
                    break;
                case 0x87:
                    if (cur == null || cur.props.has_block) break;
                    b.skip (36);
                    cur.props.valign = b.u8 ();
                    cur.props.has_block = true;
                    break;
                case 0x19:
                    long fstart = b.pos;
                    b.skip (2);
                    get_uint (b);
                    long left = h_len - (b.pos - fstart);
                    var fname = new StringBuilder ();
                    for (long i = 0; i < left && i < 128; i++) {
                        uint8 ch = b.u8 ();
                        if (ch == 0) break;
                        fname.append_c ((char) ch);
                    }
                    fonts[h_id] = Vsd.ansi (fname.str.data);
                    break;
                case 0xd7:
                    b.skip (4);
                    fonts[h_id] = Vsd.utf16 (b.bytes (64));
                    break;
                case 0x15:
                    if (page == null) break;
                    if (version == 5) {
                        page.back_id = get_uint (b);
                    } else {
                        b.skip (8);
                        page.back_id = b.u32 ();
                    }
                    break;
                case 0x2c:
                    if (cur != null) cur.names.clear ();
                    break;
                case 0x32:
                    if (version == 5) handle_records (b);
                    break;
                case 0x2d:
                    if (cur != null) cur.names[h_id] = read_text_bytes (b, h_len);
                    break;
                case 0x33:
                    if (version == 11) {
                        b.skip (4);
                        var nb = new ByteArray ();
                        for (int i = 0; i < 1024 && !b.at_end (); i++) {
                            uint32 u = b.u16 ();
                            if (u == 0) break;
                            nb.append ({ (uint8) (u & 0xff), (uint8) (u >> 8) });
                        }
                        names[h_id] = Vsd.utf16 (nb.data);
                    } else {
                        b.skip (version == 5 ? 2 : 4);
                        var nb = new StringBuilder ();
                        for (int i = 0; i < 1024 && !b.at_end (); i++) {
                            uint8 ch = b.u8 ();
                            if (ch == 0) break;
                            nb.append_c ((char) ch);
                        }
                        names[h_id] = Vsd.ansi (nb.str.data);
                    }
                    break;
                case 0x16:
                    b.skip (2);
                    uint n = b.u8 ();
                    b.skip (1);
                    string[] list = {};
                    for (uint i = 0; i < n; i++) {
                        uint cr = b.u8 ();
                        uint cg = b.u8 ();
                        uint cb = b.u8 ();
                        b.u8 ();
                        list += hex (cr, cg, cb);
                    }
                    colors = list;
                    break;
                case 0xa4:
                    read_misc (b, start);
                    break;
                case 0xa8:
                    if (page == null || version == 5) break;
                    var l = new VsdLayer ();
                    l.id = h_id;
                    b.skip (8);
                    uint8 cid = b.u8 ();
                    b.skip (4);
                    if (cid == 0xff) cid = 0;
                    b.skip (1);
                    l.visible = b.u8 () != 0;
                    l.printable = b.u8 () != 0;
                    if (cur != null && cur.names.has_key (h_id)) l.name = cur.names[h_id];
                    page.layers.add (l);
                    break;
                case 0xa7:
                    if (cur == null) break;
                    b.skip (13);
                    uint tl = b.u8 ();
                    cur.layers = version == 11 ? Vsd.utf16 (b.bytes (tl * 2)) : Vsd.ansi (b.bytes (tl));
                    break;
                default:
                    break;
            }
        }

        private void read_shape (VsdBuf b) {
            flush ();
            cur_geom = null;
            if (h_id != Vsd.NONE) cur_shape_id = h_id;
            shape_level = h_level;
            var s = new VsdShape ();
            s.type = h_type;
            if (version == 5) {
                b.skip (2);
                s.parent = get_uint (b);
                b.skip (2);
                s.master_page = get_uint (b);
                s.master_shape = get_uint (b);
                s.line_style = get_uint (b);
                s.fill_style = get_uint (b);
                s.text_style = get_uint (b);
            } else {
                b.skip (10);
                s.parent = b.u32 ();
                b.skip (4);
                s.master_page = b.u32 ();
                b.skip (4);
                s.master_shape = b.u32 ();
                b.skip (4);
                s.fill_style = b.u32 ();
                b.skip (4);
                s.line_style = b.u32 ();
                b.skip (4);
                s.text_style = b.u32 ();
            }
            s.id = cur_shape_id;
            cur_shape_id = Vsd.NONE;
            cur = s;
            cur_role = 0;
        }

        private void read_line (VsdBuf b) {
            if (cur == null) return;
            var p = cur.props;
            b.skip (1);
            p.line_width = b.dbl ();
            if (version == 5) {
                p.line_color = color_from_index (b.u8 ());
                p.line_trans = 0;
            } else {
                b.skip (1);
                uint r = b.u8 ();
                uint g = b.u8 ();
                uint bl = b.u8 ();
                uint a = b.u8 ();
                p.line_color = hex (r, g, bl);
                p.line_trans = a / 255.0;
            }
            p.line_pattern = b.u8 ();
            b.skip (1);
            p.rounding = b.dbl ();
            b.skip (1);
            p.begin_arrow = b.u8 ();
            p.end_arrow = b.u8 ();
            p.has_line = true;
        }

        private void read_fill (VsdBuf b) {
            if (cur == null) return;
            var p = cur.props;
            if (version == 5) {
                p.fill_color = color_from_index (b.u8 ());
                p.fill_bg = color_from_index (b.u8 ());
                p.fill_pattern = b.u8 ();
                p.shadow_color = color_from_index (b.u8 ());
                b.skip (1);
                p.shadow_pattern = b.u8 ();
                p.fill_trans = 0;
                p.has_fill = true;
                return;
            }
            uint fi = b.u8 ();
            uint fr = b.u8 (), fg = b.u8 (), fb = b.u8 (), fa = b.u8 ();
            uint bi = b.u8 ();
            uint br = b.u8 (), bg = b.u8 (), bb = b.u8 (), ba = b.u8 ();
            if ((fr | fg | fb | fa | br | bg | bb | ba) == 0) {
                p.fill_color = color_from_index (fi);
                p.fill_bg = color_from_index (bi);
                p.fill_trans = 0;
            } else {
                p.fill_color = hex (fr, fg, fb);
                p.fill_bg = hex (br, bg, bb);
                p.fill_trans = fa / 255.0;
            }
            p.fill_pattern = b.u8 ();
            uint si = b.u8 ();
            uint sr = b.u8 (), sg = b.u8 (), sb = b.u8 ();
            b.u8 ();
            b.skip (5);
            p.shadow_color = (sr | sg | sb) == 0 ? color_from_index (si) : hex (sr, sg, sb);
            p.shadow_pattern = b.u8 ();
            p.has_fill = true;
        }

        private void read_char (VsdBuf b) {
            if (cur == null || cur.props.has_char) return;
            var p = cur.props;
            if (version == 5) b.u16 ();
            else b.u32 ();
            uint32 fid = b.u16 ();
            if (fonts.has_key (fid)) p.font = fonts[fid];
            if (version == 5) {
                p.text_color = color_from_index (b.u8 ());
            } else {
                b.skip (1);
                uint r = b.u8 (), g = b.u8 (), bl = b.u8 (), a = b.u8 ();
                p.text_color = hex (r, g, bl);
                p.text_trans = a / 255.0;
            }
            uint m1 = b.u8 ();
            b.u8 ();
            b.u8 ();
            p.char_style = (int) (m1 & 7);
            b.u16 ();
            b.skip (2);
            double size = b.dbl ();
            if (size > 0) p.font_size = size;
            if (version != 5) {
                uint m4 = b.u8 ();
                p.strike = (m4 & 4) != 0;
            }
            p.has_char = true;
        }

        private void read_name_idx (VsdBuf b) {
            var map = new Gee.HashMap<uint32, string> ();
            if (version == 5) {
                uint32 n = b.u16 ();
                if (n > b.remaining () / 4) n = (uint32) (b.remaining () / 4);
                for (uint32 i = 0; i < n; i++) {
                    uint32 nid = b.u16 ();
                    uint32 eid = b.u16 ();
                    if (names.has_key (nid)) map[eid] = names[nid];
                }
            } else {
                uint32 n = b.u32 ();
                if (n > b.remaining () / 13) n = (uint32) (b.remaining () / 13);
                for (uint32 i = 0; i < n; i++) {
                    uint32 nid = b.u32 ();
                    b.u32 ();
                    uint32 eid = b.u32 ();
                    b.skip (1);
                    if (names.has_key (nid)) map[eid] = names[nid];
                }
            }
            name_maps[h_level] = map;
        }

        private void read_misc (VsdBuf b, long start) {
            if (cur == null || version == 5) return;
            b.seek (start + (version == 11 ? 45 : 23));
            long stop = start + h_len + h_trailer;
            int guard = 0;
            while (!b.at_end () && b.pos < stop && guard++ < 1000) {
                long at = b.pos;
                uint32 len = b.u32 ();
                if (len == 0) break;
                uint32 block = b.u8 ();
                b.skip (1);
                if (block == 2 && b.u8 () == 0x74 && b.u32 () == 0x6000004e) {
                    uint32 sid = b.u32 ();
                    if (b.u8 () == 0x7a && b.u32 () == 0x40000073) {
                        if (cur.begin_id == Vsd.NONE) cur.begin_id = sid;
                        else if (cur.end_id == Vsd.NONE) cur.end_id = sid;
                    }
                }
                b.seek (at + len);
            }
        }

        private void read_nurbs (VsdBuf b, long start) {
            if (cur == null) return;
            var r = new VsdRow ();
            r.kind = 0xc3;
            b.skip (1);
            r.x = b.dbl ();
            b.skip (1);
            r.y = b.dbl ();
            r.knot = b.dbl ();
            r.weight = b.dbl ();
            r.knot_prev = b.dbl ();
            r.weight_prev = b.dbl ();
            b.skip (1);
            uint use_data = b.u8 ();
            if (use_data == 0x8a) {
                b.skip (3);
                r.data_id = b.u32 ();
                add_row (r);
                return;
            }
            b.seek (start + 0x50);
            long read = 0x50;
            uint cell = 0;
            long length = 0;
            long at = b.pos;
            int guard = 0;
            while (cell != 6 && !b.at_end () && h_len - read > 4 && guard++ < 1000) {
                length = b.u32 ();
                b.skip (1);
                cell = b.u8 ();
                if (cell < 6) {
                    if (length < 6) break;
                    b.skip (length - 6);
                }
                read += b.pos - at;
                at = b.pos;
            }
            if (cell != 6 || b.at_end ()) {
                r.kind = 0x8b;
                add_row (r);
                return;
            }
            uint param = b.u8 ();
            double last = 0;
            uint reps = 0;
            if (param == 0x8a) {
                last = b.dbl ();
                r.degree = (int) b.u16 ();
                r.xtype = b.u8 ();
                r.ytype = b.u8 ();
                reps = b.u32 ();
            } else {
                last = param == 0x20 ? b.dbl () : b.u16 ();
                b.skip (1);
                r.degree = (int) b.u16 ();
                b.skip (1);
                r.xtype = (int) b.u16 ();
                b.skip (1);
                r.ytype = (int) b.u16 ();
            }
            double[] pts = {};
            double[] knots = { r.knot_prev };
            double[] weights = { r.weight_prev };
            long block = b.pos - at;
            uint flag = param != 0x8a ? b.u8 () : 0;
            int count = 0;
            while ((param == 0x8a ? reps > 0 : flag != 0x81) && block < length && !b.at_end () && count++ < 10000) {
                long p0 = b.pos;
                double cx, cy, k = 0, wgt = 0;
                if (param == 0x8a) {
                    cx = b.dbl ();
                    cy = b.dbl ();
                    k = b.dbl ();
                    wgt = b.dbl ();
                    reps--;
                } else {
                    cx = flag == 0x20 ? b.dbl () : b.u16 ();
                    uint t = b.u8 ();
                    cy = t == 0x20 ? b.dbl () : b.u16 ();
                    t = b.u8 ();
                    if (t == 0x20) k = b.dbl ();
                    else if (t == 0x62) k = b.u16 ();
                    t = b.u8 ();
                    if (t == 0x20) wgt = b.dbl ();
                    else if (t == 0x62) wgt = b.u16 ();
                    flag = b.u8 ();
                }
                pts += cx;
                pts += cy;
                knots += k;
                weights += wgt;
                block += b.pos - p0;
            }
            knots += r.knot;
            knots += last;
            weights += r.weight;
            r.pts = pts;
            r.knots = knots;
            r.weights = weights;
            add_row (r);
        }

        private void read_polyline (VsdBuf b, long start) {
            if (cur == null) return;
            var r = new VsdRow ();
            r.kind = 0xc1;
            b.skip (1);
            r.x = b.dbl ();
            b.skip (1);
            r.y = b.dbl ();
            b.skip (1);
            uint use_data = b.u8 ();
            if (use_data == 0x8b) {
                b.skip (3);
                r.data_id = b.u32 ();
                add_row (r);
                return;
            }
            b.seek (start + 0x30);
            long read = 0x30;
            uint cell = 0;
            long length = 0;
            long at = b.pos;
            int guard = 0;
            while (cell != 2 && !b.at_end () && h_len - read > 4 && guard++ < 1000) {
                length = b.u32 ();
                if (length == 0) break;
                b.skip (1);
                cell = b.u8 ();
                if (cell < 2) {
                    if (length < 6) break;
                    b.skip (length - 6);
                }
                read += b.pos - at;
                at = b.pos;
            }
            if (cell != 2 || b.at_end ()) {
                r.kind = 0x8b;
                add_row (r);
                return;
            }
            long block = 6;
            at = b.pos;
            b.skip (1);
            r.xtype = (int) (b.u16 () & 0xff);
            b.skip (1);
            r.ytype = (int) (b.u16 () & 0xff);
            uint flag = b.u8 ();
            block += b.pos - at;
            double[] pts = {};
            int count = 0;
            while (flag != 0x81 && block < length && !b.at_end () && count++ < 10000) {
                long p0 = b.pos;
                double px = flag == 0x20 ? b.dbl () : b.u16 ();
                uint t = b.u8 ();
                double py = t == 0x20 ? b.dbl () : b.u16 ();
                pts += px;
                pts += py;
                flag = b.u8 ();
                block += b.pos - p0;
            }
            r.pts = pts;
            add_row (r);
        }

        private void read_shape_data (VsdBuf b) {
            if (cur == null) return;
            uint type = b.u8 ();
            b.skip (15);
            var d = new VsdPolyData ();
            if (type == 0x80) {
                d.xtype = b.u8 ();
                d.ytype = b.u8 ();
                uint32 n = b.u32 ();
                if (n > b.remaining () / 16) n = (uint32) (b.remaining () / 16);
                double[] pts = {};
                for (uint32 i = 0; i < n; i++) {
                    pts += b.dbl ();
                    pts += b.dbl ();
                }
                d.pts = pts;
                cur.data[h_id] = d;
            } else if (type == 0x82) {
                d.nurbs = true;
                d.last_knot = b.dbl ();
                d.degree = (int) b.u16 ();
                d.xtype = b.u8 ();
                d.ytype = b.u8 ();
                uint32 n = b.u32 ();
                if (n > b.remaining () / 32) n = (uint32) (b.remaining () / 32);
                double[] pts = {};
                double[] knots = {};
                double[] weights = {};
                for (uint32 i = 0; i < n; i++) {
                    pts += b.dbl ();
                    pts += b.dbl ();
                    knots += b.dbl ();
                    weights += b.dbl ();
                }
                d.pts = pts;
                d.knots = knots;
                d.weights = weights;
                cur.data[h_id] = d;
            }
        }
    }

    private class VdxParser {
        private VsdModel model = new VsdModel ();
        private Gee.HashMap<string, string> colors = new Gee.HashMap<string, string> ();
        private Gee.HashMap<string, string> faces = new Gee.HashMap<string, string> ();

        public static VsdModel parse (string text) throws Error {
            Xml.Doc* x = XmlUtil.parse (text);
            var root = x->get_root_element ();
            if (root->name != "VisioDocument") {
                delete x;
                throw new FormatError.INVALID (_("This is not a Visio drawing."));
            }
            var p = new VdxParser ();
            p.read (root);
            delete x;
            return p.model;
        }

        private static double num (string? s, double fallback = 0) {
            if (s == null) return fallback;
            double d;
            if (double.try_parse (s.strip (), out d)) return d;
            return fallback;
        }

        private static uint32 id_attr (Xml.Node* n, string name) {
            string? v = XmlUtil.attr (n, name);
            if (v == null || v.strip () == "") return Vsd.NONE;
            return (uint32) int.parse (v);
        }

        private static string? cell (Xml.Node* n, string name) {
            var c = XmlUtil.child (n, name);
            if (c == null) return null;
            return XmlUtil.text (c);
        }

        private string color (string? v, string fallback) {
            if (v == null) return fallback;
            string t = v.strip ();
            if (t.has_prefix ("#") && t.length >= 7) return t.substring (0, 7).down ();
            if (colors.has_key (t)) return colors[t];
            double d;
            if (double.try_parse (t, out d)) {
                string[] palette = { "#000000", "#ffffff", "#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff",
                    "#800000", "#008000", "#000080", "#808000", "#800080", "#008080", "#c0c0c0", "#e6e6e6", "#cdcdcd",
                    "#b3b3b3", "#9a9a9a", "#808080", "#666666", "#4d4d4d", "#333333", "#1a1a1a" };
                int i = (int) d;
                if (i >= 0 && i < palette.length) return palette[i];
            }
            return fallback;
        }

        private void read (Xml.Node* root) {
            foreach (var c in XmlUtil.children (XmlUtil.child (root, "Colors"), "ColorEntry")) {
                colors[XmlUtil.attr_or (c, "IX", "")] = XmlUtil.attr_or (c, "RGB", "#000000").down ();
            }
            foreach (var f in XmlUtil.children (XmlUtil.child (root, "FaceNames"), "FaceName")) {
                faces[XmlUtil.attr_or (f, "ID", "")] = XmlUtil.attr_or (f, "Name", "");
            }
            foreach (var sn in XmlUtil.children (XmlUtil.child (root, "StyleSheets"), "StyleSheet")) {
                var s = new VsdShape ();
                s.id = id_attr (sn, "ID");
                s.line_style = id_attr (sn, "LineStyle");
                s.fill_style = id_attr (sn, "FillStyle");
                s.text_style = id_attr (sn, "TextStyle");
                read_props (sn, s.props);
                model.styles[s.id] = s;
            }
            foreach (var mn in XmlUtil.children (XmlUtil.child (root, "Masters"), "Master")) {
                var p = new VsdPage ();
                p.id = id_attr (mn, "ID");
                p.name = XmlUtil.attr (mn, "NameU") ?? XmlUtil.attr_or (mn, "Name", "");
                read_shapes (XmlUtil.child (mn, "Shapes"), p, 0);
                model.masters.add (p);
            }
            foreach (var pn in XmlUtil.children (XmlUtil.child (root, "Pages"), "Page")) {
                var p = new VsdPage ();
                p.id = id_attr (pn, "ID");
                p.name = XmlUtil.attr (pn, "Name") ?? XmlUtil.attr_or (pn, "NameU", "");
                p.background = XmlUtil.attr_or (pn, "Background", "0") == "1";
                p.back_id = id_attr (pn, "BackPage");
                var ps = XmlUtil.child (pn, "PageSheet");
                if (ps != null) {
                    var props = XmlUtil.child (ps, "PageProps");
                    if (props != null) {
                        p.width = num (cell (props, "PageWidth"), 8.5);
                        p.height = num (cell (props, "PageHeight"), 11);
                    }
                    foreach (var ln in XmlUtil.children (ps, "Layer")) {
                        var l = new VsdLayer ();
                        l.id = id_attr (ln, "IX");
                        l.name = cell (ln, "Name") ?? "";
                        l.visible = num (cell (ln, "Visible"), 1) != 0;
                        l.printable = num (cell (ln, "Print"), 1) != 0;
                        p.layers.add (l);
                    }
                }
                read_shapes (XmlUtil.child (pn, "Shapes"), p, 0);
                foreach (var cn in XmlUtil.children (XmlUtil.child (pn, "Connects"), "Connect")) {
                    string fc = XmlUtil.attr_or (cn, "FromCell", "");
                    if (fc != "BeginX" && fc != "EndX") continue;
                    var c = new VsdConnect ();
                    c.from = id_attr (cn, "FromSheet");
                    c.to = id_attr (cn, "ToSheet");
                    c.begin = fc == "BeginX";
                    p.connects.add (c);
                }
                model.pages.add (p);
            }
        }

        private void read_props (Xml.Node* n, VsdProps p) {
            var line = XmlUtil.child (n, "Line");
            if (line != null) {
                p.has_line = true;
                p.line_width = num (cell (line, "LineWeight"), 0.01);
                p.line_color = color (cell (line, "LineColor"), "#000000");
                p.line_trans = num (cell (line, "LineColorTrans"), 0);
                p.line_pattern = (int) num (cell (line, "LinePattern"), 1);
                p.rounding = num (cell (line, "Rounding"), 0);
                p.begin_arrow = (int) num (cell (line, "BeginArrow"), 0);
                p.end_arrow = (int) num (cell (line, "EndArrow"), 0);
                p.arrow_size = num (cell (line, "EndArrowSize"), 2);
            }
            var fill = XmlUtil.child (n, "Fill");
            if (fill != null) {
                p.has_fill = true;
                p.fill_color = color (cell (fill, "FillForegnd"), "#ffffff");
                p.fill_bg = color (cell (fill, "FillBkgnd"), "#ffffff");
                p.fill_trans = num (cell (fill, "FillForegndTrans"), 0);
                p.fill_pattern = (int) num (cell (fill, "FillPattern"), 1);
                p.shadow_pattern = (int) num (cell (fill, "ShdwPattern"), 0);
                p.shadow_color = color (cell (fill, "ShdwForegnd"), "#000000");
            }
            foreach (var ch in XmlUtil.children (n, "Char")) {
                if (XmlUtil.attr_or (ch, "IX", "0") != "0") continue;
                p.has_char = true;
                string? f = cell (ch, "Font");
                if (f != null && faces.has_key (f.strip ())) p.font = faces[f.strip ()];
                p.text_color = color (cell (ch, "Color"), "#000000");
                p.text_trans = num (cell (ch, "ColorTrans"), 0);
                p.char_style = (int) num (cell (ch, "Style"), 0);
                p.strike = num (cell (ch, "Strikethru"), 0) != 0;
                double size = num (cell (ch, "Size"), 0);
                if (size > 0) p.font_size = size;
            }
            foreach (var pa in XmlUtil.children (n, "Para")) {
                if (XmlUtil.attr_or (pa, "IX", "0") != "0") continue;
                p.has_para = true;
                p.align = (int) num (cell (pa, "HorzAlign"), 1);
            }
            var tb = XmlUtil.child (n, "TextBlock");
            if (tb != null && cell (tb, "VerticalAlign") != null) {
                p.has_block = true;
                p.valign = (int) num (cell (tb, "VerticalAlign"), 1);
            }
        }

        private static double[] formula_numbers (string? f) {
            double[] out_v = {};
            if (f == null) return out_v;
            int open = f.index_of ("(");
            int close = f.last_index_of (")");
            if (open < 0 || close < open) return out_v;
            foreach (string part in f.substring (open + 1, close - open - 1).split (",")) {
                string t = part.strip ();
                int sp = t.index_of (" ");
                if (sp > 0) t = t.substring (0, sp);
                double d = 0;
                out_v += double.try_parse (t, out d) ? d : 0;
            }
            return out_v;
        }

        private void read_shapes (Xml.Node* container, VsdPage page, uint32 parent) {
            if (container == null) return;
            foreach (var sn in XmlUtil.children (container, "Shape")) {
                if (XmlUtil.attr_or (sn, "Del", "0") == "1") continue;
                var s = new VsdShape ();
                s.id = id_attr (sn, "ID");
                s.parent = parent;
                string type = XmlUtil.attr_or (sn, "Type", "Shape");
                s.type = type == "Group" ? 0x47 : (type == "Foreign" ? 0x4e : (type == "Guide" ? 0x4d : 0x48));
                s.master_page = id_attr (sn, "Master");
                s.master_shape = id_attr (sn, "MasterShape");
                s.line_style = id_attr (sn, "LineStyle");
                s.fill_style = id_attr (sn, "FillStyle");
                s.text_style = id_attr (sn, "TextStyle");
                s.name = XmlUtil.attr (sn, "Name") ?? XmlUtil.attr_or (sn, "NameU", "");
                var xf = XmlUtil.child (sn, "XForm");
                if (xf != null) {
                    s.has_xform = true;
                    s.width = num (cell (xf, "Width"), 0);
                    s.height = num (cell (xf, "Height"), 0);
                    s.pin_x = num (cell (xf, "PinX"), 0);
                    s.pin_y = num (cell (xf, "PinY"), 0);
                    s.loc_x = num (cell (xf, "LocPinX"), s.width / 2);
                    s.loc_y = num (cell (xf, "LocPinY"), s.height / 2);
                    s.angle = num (cell (xf, "Angle"), 0);
                    s.flip_x = num (cell (xf, "FlipX"), 0) != 0;
                    s.flip_y = num (cell (xf, "FlipY"), 0) != 0;
                }
                var x1 = XmlUtil.child (sn, "XForm1D");
                if (x1 != null) {
                    s.one_d = true;
                    s.bx = num (cell (x1, "BeginX"), 0);
                    s.by = num (cell (x1, "BeginY"), 0);
                    s.ex = num (cell (x1, "EndX"), 0);
                    s.ey = num (cell (x1, "EndY"), 0);
                }
                read_props (sn, s.props);
                foreach (var gn in XmlUtil.children (sn, "Geom")) {
                    if (XmlUtil.attr_or (gn, "Del", "0") == "1") continue;
                    var g = new VsdGeom ();
                    g.no_fill = num (cell (gn, "NoFill"), 0) != 0;
                    g.no_line = num (cell (gn, "NoLine"), 0) != 0;
                    g.no_show = num (cell (gn, "NoShow"), 0) != 0;
                    foreach (var rn in XmlUtil.children (gn)) {
                        if (XmlUtil.attr_or (rn, "Del", "0") == "1") continue;
                        var r = new VsdRow ();
                        r.id = id_attr (rn, "IX");
                        r.x = num (cell (rn, "X"), 0);
                        r.y = num (cell (rn, "Y"), 0);
                        r.a = num (cell (rn, "A"), 0);
                        r.b = num (cell (rn, "B"), 0);
                        r.c = num (cell (rn, "C"), 0);
                        r.d = num (cell (rn, "D"), 1);
                        switch (rn->name) {
                            case "MoveTo": r.kind = 0x8a; break;
                            case "LineTo": r.kind = 0x8b; break;
                            case "ArcTo": r.kind = 0x8c; break;
                            case "Ellipse": r.kind = 0x8f; break;
                            case "EllipticalArcTo": r.kind = 0x90; break;
                            case "InfiniteLine": r.kind = 0x8d; break;
                            case "SplineStart": r.kind = 0xa5; break;
                            case "SplineKnot": r.kind = 0xa6; break;
                            case "PolylineTo":
                                r.kind = 0xc1;
                                var an = XmlUtil.child (rn, "A");
                                var pn = formula_numbers (an != null ? XmlUtil.attr (an, "F") : null);
                                if (pn.length >= 2) {
                                    r.xtype = (int) pn[0];
                                    r.ytype = (int) pn[1];
                                    r.pts = pn[2:pn.length];
                                }
                                break;
                            case "NURBSTo":
                                r.kind = 0xc3;
                                var en = XmlUtil.child (rn, "E");
                                var nn = formula_numbers (en != null ? XmlUtil.attr (en, "F") : null);
                                if (nn.length >= 4) {
                                    r.degree = (int) nn[1];
                                    r.xtype = (int) nn[2];
                                    r.ytype = (int) nn[3];
                                    double[] pts = {};
                                    double[] knots = { r.c };
                                    double[] weights = { num (cell (rn, "D"), 1) };
                                    for (int i = 4; i + 3 < nn.length; i += 4) {
                                        pts += nn[i];
                                        pts += nn[i + 1];
                                        knots += nn[i + 2];
                                        weights += nn[i + 3];
                                    }
                                    knots += r.a;
                                    knots += nn[0];
                                    weights += r.b;
                                    r.pts = pts;
                                    r.knots = knots;
                                    r.weights = weights;
                                } else {
                                    r.kind = 0x8b;
                                }
                                break;
                            default: continue;
                        }
                        g.rows.add (r);
                    }
                    s.geoms.add (g);
                }
                var tn = XmlUtil.child (sn, "Text");
                if (tn != null) s.text = XmlUtil.text (tn);
                foreach (var pr in XmlUtil.children (sn, "Prop")) {
                    string key = cell (pr, "Label") ?? XmlUtil.attr (pr, "NameU") ?? XmlUtil.attr_or (pr, "Name", "");
                    if (key.strip () == "") continue;
                    s.fields.add (new DataField (key, cell (pr, "Value") ?? ""));
                }
                var hl = XmlUtil.child (sn, "Hyperlink");
                if (hl != null) s.link = cell (hl, "Address") ?? "";
                var lm = XmlUtil.child (sn, "LayerMem");
                if (lm != null) s.layers = cell (lm, "LayerMember") ?? "";
                var fd = XmlUtil.child (sn, "ForeignData");
                if (fd != null) {
                    string ft = XmlUtil.attr_or (fd, "ForeignType", "Bitmap");
                    s.foreign_type = ft == "Bitmap" ? 1 : 0;
                    s.foreign_format = 4;
                    s.foreign = Base64.decode (XmlUtil.text (fd).strip ());
                    s.type = 0x4e;
                }
                page.shapes.add (s);
                read_shapes (XmlUtil.child (sn, "Shapes"), page, s.id);
            }
        }
    }

    private class VsdBuilder {
        private VsdModel m;
        private double page_h = 11;
        private int page_no = 0;
        private string prefix = "v";
        private Gee.HashMap<uint32, Item> items = new Gee.HashMap<uint32, Item> ();
        private Gee.ArrayList<VsdShape> connector_shapes = new Gee.ArrayList<VsdShape> ();
        private Gee.ArrayList<Layer> layers = new Gee.ArrayList<Layer> ();
        private VsdPage? layer_page = null;

        public VsdBuilder (VsdModel m) {
            this.m = m;
        }

        public Document document () throws Error {
            var doc = new Document ();
            doc.pages.clear ();
            var map = new Gee.HashMap<uint32, Page> ();
            foreach (var vp in m.pages) {
                page_no++;
                var p = build_page (vp, "page%d".printf (page_no));
                map[vp.id] = p;
                doc.pages.add (p);
            }
            foreach (var vp in m.pages) {
                if (vp.back_id == Vsd.NONE || vp.back_id == vp.id || !map.has_key (vp.back_id)) continue;
                var bg = map[vp.back_id];
                if (!bg.is_background) continue;
                map[vp.id].back_page = bg.id;
            }
            if (doc.pages.size == 0) {
                var p = new Page (_("Page 1"));
                p.id = "page1";
                doc.pages.add (p);
            }
            int first = 0;
            for (int i = 0; i < doc.pages.size; i++) {
                if (!doc.pages[i].is_background) {
                    first = i;
                    break;
                }
            }
            doc.page_index = first;
            return doc;
        }

        public UserStencil stencil () throws Error {
            var st = new UserStencil ();
            st.name = "";
            int n = 0;
            foreach (var mp in m.masters) {
                n++;
                page_no = n;
                prefix = "m";
                items.clear ();
                connector_shapes.clear ();
                page_h = mp.height;
                var list = new Gee.ArrayList<Item> ();
                foreach (var s in mp.top ()) {
                    var it = build_item (s, mp, Cairo.Matrix.identity (), null);
                    if (it != null) list.add (it);
                }
                if (list.size == 0) continue;
                var master = StencilMaster.from_items (mp.name != "" ? mp.name : _("Master %d").printf (n), list);
                master.id = st.new_master_id ();
                master.keywords = mp.name.down ();
                st.masters.add (master);
            }
            if (st.masters.size == 0) throw new FormatError.INVALID (_("This file has no masters."));
            return st;
        }

        private Page build_page (VsdPage vp, string id) {
            var page = new Page (vp.name != "" ? vp.name : (vp.background ? _("Background %d").printf (page_no) : _("Page %d").printf (page_no)));
            page.id = id;
            page.is_background = vp.background;
            page.width = vp.width * Units.PX_PER_IN;
            page.height = vp.height * Units.PX_PER_IN;
            page_h = vp.height;
            items.clear ();
            connector_shapes.clear ();
            layers.clear ();
            layer_page = vp;
            if (vp.layers.size > 0) {
                page.layers.clear ();
                int i = 0;
                foreach (var vl in vp.layers) {
                    var l = new Layer ("layer%d".printf (i + 1), vl.name != "" ? vl.name : _("Layer %d").printf (i + 1));
                    l.visible = vl.visible;
                    l.printable = vl.printable;
                    page.layers.add (l);
                    layers.add (l);
                    i++;
                }
                page.active_layer = page.layers[0].id;
            }
            foreach (var s in vp.top ()) {
                var it = build_item (s, vp, Cairo.Matrix.identity (), null);
                if (it != null) page.items.add (it);
            }
            foreach (var s in connector_shapes) {
                var c = items[s.id] as Connector;
                if (c == null) continue;
                attach (c.src, s.begin_id);
                attach (c.dst, s.end_id);
            }
            foreach (var cn in vp.connects) {
                if (!items.has_key (cn.from)) continue;
                var c = items[cn.from] as Connector;
                if (c == null) continue;
                attach (cn.begin ? c.src : c.dst, cn.to);
            }
            foreach (var it in items.values) {
                var c = it as Connector;
                if (c == null) continue;
                if (!c.src.attached ()) glue_near (c.src, c);
                if (!c.dst.attached ()) glue_near (c.dst, c);
            }
            return page;
        }

        private void glue_near (Endpoint e, Connector c) {
            Shape? best = null;
            double best_area = double.INFINITY;
            foreach (var it in items.values) {
                var s = it as Shape;
                if (s == null || it == c) continue;
                var b = s.bounds ();
                if (!b.inflate (2).contains (e.x, e.y)) continue;
                double d = double.min (double.min ((e.x - b.x).abs (), (e.x - b.x2 ()).abs ()), double.min ((e.y - b.y).abs (), (e.y - b.y2 ()).abs ()));
                if (d > 3) continue;
                double area = b.w * b.h;
                if (area < best_area) {
                    best = s;
                    best_area = area;
                }
            }
            if (best == null) return;
            e.item_id = best.id;
            e.port = -1;
        }

        private void attach (Endpoint e, uint32 target) {
            if (target == Vsd.NONE || !items.has_key (target)) return;
            var t = items[target];
            if (t is Connector) return;
            e.item_id = t.id;
            e.port = -1;
        }

        private Cairo.Matrix to_px () {
            return Cairo.Matrix (Units.PX_PER_IN, 0, 0, -Units.PX_PER_IN, 0, page_h * Units.PX_PER_IN);
        }

        private static Cairo.Matrix mul (Cairo.Matrix a, Cairo.Matrix b) {
            var r = Cairo.Matrix.identity ();
            r.multiply (a, b);
            return r;
        }

        private VsdShape? master_of (VsdShape s, VsdPage? scope) {
            if (s.master_page != Vsd.NONE) {
                var mp = m.master (s.master_page);
                if (mp == null) return null;
                if (s.master_shape == Vsd.NONE) return mp.first ();
                return mp.find (s.master_shape);
            }
            if (scope != null && s.master_shape != Vsd.NONE) return scope.find (s.master_shape);
            return null;
        }

        private VsdProps? style_prop (uint32 id, int kind, int depth) {
            if (id == Vsd.NONE || depth > 16 || !m.styles.has_key (id)) return null;
            var st = m.styles[id];
            bool has = kind == 0 ? st.props.has_line : (kind == 1 ? st.props.has_fill : (kind == 2 ? st.props.has_char : (kind == 3 ? st.props.has_para : st.props.has_block)));
            if (has) return st.props;
            uint32 parent = kind == 0 ? st.line_style : (kind == 1 ? st.fill_style : st.text_style);
            if (parent == id) return null;
            return style_prop (parent, kind, depth + 1);
        }

        private VsdProps? prop (VsdShape s, VsdShape? master, int kind) {
            VsdShape?[] chain = { s, master };
            foreach (var c in chain) {
                if (c == null) continue;
                var p = c.props;
                bool has = kind == 0 ? p.has_line : (kind == 1 ? p.has_fill : (kind == 2 ? p.has_char : (kind == 3 ? p.has_para : p.has_block)));
                if (has) return p;
            }
            foreach (var c in chain) {
                if (c == null) continue;
                uint32 sid = kind == 0 ? c.line_style : (kind == 1 ? c.fill_style : c.text_style);
                var r = style_prop (sid, kind, 0);
                if (r != null) return r;
            }
            return null;
        }

        private static string with_alpha (string c, double trans) {
            if (trans <= 0.001) return c;
            Rgba rgba;
            if (!Colors.parse (c, out rgba)) return c;
            rgba.a = (1 - trans).clamp (0, 1);
            return Colors.to_hex (rgba, true);
        }

        private void apply_style (VsdShape s, VsdShape? master, Style st, bool one_d) {
            var lp = prop (s, master, 0);
            if (lp != null) {
                if (lp.line_pattern == 0) {
                    st.stroke = "none";
                } else {
                    st.stroke = with_alpha (lp.line_color, lp.line_trans);
                    st.stroke_width = double.max (lp.line_width * Units.PX_PER_IN, 0.5);
                    st.dash = Vsdx.dash_from_visio (lp.line_pattern);
                }
                st.corner_radius = lp.rounding * Units.PX_PER_IN;
                st.arrow_start = Vsdx.arrow_from_visio (lp.begin_arrow);
                st.arrow_end = Vsdx.arrow_from_visio (lp.end_arrow);
                st.arrow_size = double.max (lp.arrow_size / 2.0, 0.5);
            } else {
                st.stroke = "#000000";
                st.stroke_width = 1;
            }
            var fp = prop (s, master, 1);
            if (one_d || (fp != null && fp.fill_pattern == 0)) {
                st.fill_kind = FillKind.NONE;
            } else if (fp != null) {
                st.fill_kind = FillKind.SOLID;
                st.fill = with_alpha (fp.fill_color, fp.fill_trans);
                st.fill2 = fp.fill_bg;
                if (fp.fill_pattern >= 25 && fp.fill_pattern <= 40) {
                    st.fill_kind = FillKind.LINEAR;
                    st.gradient_angle = 90;
                }
            } else {
                st.fill_kind = FillKind.SOLID;
                st.fill = "#ffffff";
            }
            if (fp != null && fp.shadow_pattern != 0 && !one_d) {
                st.shadow = true;
                st.shadow_color = with_alpha (fp.shadow_color, 0.6);
            }
            var cp = prop (s, master, 2);
            if (cp != null) {
                st.font_size = cp.font_size * 72;
                st.text_color = with_alpha (cp.text_color, cp.text_trans);
                st.bold = (cp.char_style & 1) != 0;
                st.italic = (cp.char_style & 2) != 0;
                st.underline = (cp.char_style & 4) != 0;
                st.strike = cp.strike;
                if (cp.font != "" && cp.font != "Themed") st.font_family = cp.font;
            }
            var pp = prop (s, master, 3);
            if (pp != null) st.halign = pp.align == 0 ? TextHAlign.LEFT : (pp.align == 2 ? TextHAlign.RIGHT : TextHAlign.CENTER);
            var bp = prop (s, master, 4);
            if (bp != null) st.valign = bp.valign == 0 ? TextVAlign.TOP : (bp.valign == 2 ? TextVAlign.BOTTOM : TextVAlign.MIDDLE);
        }

        private static string clean_text (string? t) {
            if (t == null) return "";
            var sb = new StringBuilder ();
            int i = 0;
            unichar c;
            while (t.get_next_char (ref i, out c)) {
                if (c == 0xfffc || c == 0) continue;
                if (c == '\r' || c == 0x2028 || c == 0x2029 || c == 0x0b) c = '\n';
                sb.append_unichar (c);
            }
            string r = sb.str.replace ("\n\n", "\n");
            while (r.has_suffix ("\n")) r = r.substring (0, r.length - 1);
            return r;
        }

        private Cairo.Matrix local_matrix (VsdShape x) {
            var mt = Cairo.Matrix.identity ();
            mt.translate (x.pin_x, x.pin_y);
            if (x.angle != 0) mt.rotate (x.angle);
            mt.scale (x.flip_x ? -1 : 1, x.flip_y ? -1 : 1);
            mt.translate (-x.loc_x, -x.loc_y);
            return mt;
        }

        private static void decompose (Cairo.Matrix a, Shape shape) {
            double det = a.xx * a.yy - a.xy * a.yx;
            bool flip = det < 0;
            double fx = flip ? -1 : 1;
            double r = Math.atan2 (fx * a.yx, fx * a.xx) * 180 / Math.PI;
            if (r.abs () < 1e-7) r = 0;
            shape.flip_h = flip;
            shape.flip_v = false;
            shape.rotation = Document.normalize_angle (r);
            if ((shape.rotation - 360).abs () < 1e-6) shape.rotation = 0;
            double cx = shape.w / 2, cy = shape.h / 2;
            a.transform_point (ref cx, ref cy);
            shape.x = cx - shape.w / 2;
            shape.y = cy - shape.h / 2;
        }

        private static string? kind_for_master (string name) {
            string n = name.down ().strip ();
            int dot = n.last_index_of (".");
            double d;
            if (dot > 0 && double.try_parse (n.substring (dot + 1), out d)) n = n.substring (0, dot);
            switch (n) {
                case "rectangle": case "square": return "rectangle";
                case "rounded rectangle": return "rounded-rectangle";
                case "ellipse": return "ellipse";
                case "circle": return "circle";
                case "process": return "process";
                case "decision": return "decision";
                case "start/end": case "terminator": return "terminator";
                case "data": return "data";
                case "document": return "document";
                case "multiple documents": return "multi-document";
                case "database": return "database";
                case "stored data": return "stored-data";
                case "predefined process": case "subprocess": return "predefined-process";
                case "manual input": return "manual-input";
                case "manual operation": return "manual-operation";
                case "preparation": return "preparation";
                case "display": return "display";
                case "delay": return "delay";
                case "internal storage": return "internal-storage";
                case "card": return "card";
                case "paper tape": return "punched-tape";
                case "off-page reference": return "off-page";
                case "on-page reference": return "on-page";
                case "loop limit": return "loop-limit";
                case "triangle": return "triangle";
                case "pentagon": return "pentagon";
                case "hexagon": return "hexagon";
                case "octagon": return "octagon";
                case "diamond": return "diamond";
                case "parallelogram": return "parallelogram";
                case "trapezoid": return "trapezoid";
                case "cross": return "cross";
                case "5-point star": case "star": return "star";
                case "cloud": return "cloud";
                case "cube": return "cube";
                case "cylinder": return "cylinder";
                case "heart": return "heart";
                default: return null;
            }
        }

        private Item? build_item (VsdShape s, VsdPage owner, Cairo.Matrix parent, VsdPage? scope) {
            if (s.type == 0x4d) return null;
            var master = master_of (s, scope);
            VsdPage? child_scope = s.master_page != Vsd.NONE ? m.master (s.master_page) : scope;
            var xf = s.has_xform || master == null || !master.has_xform ? s : master;
            bool one_d = s.one_d || (master != null && master.one_d && !s.has_xform);
            var local = mul (local_matrix (xf), parent);
            Item? it = null;
            var kids = owner.children_of (s);
            if (one_d) {
                it = build_connector (s, master, xf, parent, local);
                connector_shapes.add (s);
            } else if (s.type == 0x47 || kids.size > 0) {
                var g = new Group ();
                apply_style (s, master, g.style, false);
                g.text = clean_text (s.text ?? (master != null ? master.text : null));
                foreach (var c in kids) {
                    var ci = build_item (c, owner, local, child_scope);
                    if (ci != null) g.children.add (ci);
                }
                if (kids.size == 0 && master != null && child_scope != null) {
                    foreach (var c in child_scope.children_of (master)) {
                        var ci = build_item (c, child_scope, local, child_scope);
                        if (ci != null) g.children.add (ci);
                    }
                }
                if (g.children.size == 0) {
                    it = build_shape (s, master, xf, local);
                } else {
                    it = g;
                }
            } else {
                it = build_shape (s, master, xf, local);
            }
            if (it == null) return null;
            it.id = "%s%d_%u".printf (prefix, page_no, s.id);
            if (s.name != "") it.name = s.name;
            if (s.link != "") it.link = s.link;
            foreach (var f in s.fields) it.fields.add (new DataField (f.key, f.value));
            if (it.fields.size == 0 && master != null) foreach (var f in master.fields) it.fields.add (new DataField (f.key, f.value));
            string lm = s.layers != "" ? s.layers : (master != null ? master.layers : "");
            if (layers.size > 0) {
                int li = 0;
                if (lm.strip () != "") li = int.parse (lm.split (";")[0]);
                it.layer_id = li >= 0 && li < layers.size ? layers[li].id : layers[0].id;
            }
            items[s.id] = it;
            return it;
        }

        private Gee.ArrayList<GeomPart> geometry (VsdShape s, VsdShape? master, VsdShape xf, out bool from_master) {
            from_master = false;
            var src = s;
            double sx = 1, sy = 1;
            if (s.geoms.size == 0 && master != null && master.geoms.size > 0) {
                src = master;
                from_master = true;
                if (master.width.abs () > 1e-9) sx = xf.width / master.width;
                if (master.height.abs () > 1e-9) sy = xf.height / master.height;
            }
            var parts = new Gee.ArrayList<GeomPart> ();
            var to_local = Cairo.Matrix (Units.PX_PER_IN * sx, 0, 0, -Units.PX_PER_IN * sy, 0, xf.height * Units.PX_PER_IN);
            foreach (var g in src.geoms) {
                if (g.no_show || (g.no_fill && g.no_line)) continue;
                var path = build_path (g, src, src == s ? xf.width : src.width, src == s ? xf.height : src.height);
                if (path.is_empty ()) continue;
                path.transform (to_local);
                bool closed = path.has_closed_subpath ();
                PartMode mode;
                if (!closed || g.no_fill) mode = PartMode.STROKE;
                else if (g.no_line) mode = PartMode.FILL_ONLY;
                else mode = PartMode.FILL_STROKE;
                parts.add (new GeomPart (path, mode));
            }
            return parts;
        }

        private Shape? build_shape (VsdShape s, VsdShape? master, VsdShape xf, Cairo.Matrix local) {
            double wi = xf.width, hi = xf.height;
            double wpx = wi * Units.PX_PER_IN, hpx = hi * Units.PX_PER_IN;
            var lm = Cairo.Matrix (1.0 / Units.PX_PER_IN, 0, 0, -1.0 / Units.PX_PER_IN, 0, hi);
            var a = mul (mul (lm, local), to_px ());
            bool foreign = s.type == 0x4e || (master != null && master.type == 0x4e);
            uint8[]? fdata = s.foreign ?? (master != null ? master.foreign : null);
            string text = clean_text (s.text ?? (master != null ? master.text : null));
            Shape shape;
            bool fm;
            var parts = foreign ? new Gee.ArrayList<GeomPart> () : geometry (s, master, xf, out fm);
            string mname = "";
            if (s.master_page != Vsd.NONE) {
                var mp = m.master (s.master_page);
                if (mp != null) mname = mp.name;
            }
            string? mapped = kind_for_master (mname);
            if (foreign && fdata != null && fdata.length > 0) {
                var img = new ImageShape ();
                int ftype = s.foreign_type >= 0 ? s.foreign_type : (master != null ? master.foreign_type : 1);
                int fformat = s.foreign_type >= 0 ? s.foreign_format : (master != null ? master.foreign_format : 0);
                img.bytes = image_bytes (fdata, ftype, fformat);
                img.mime = ImageShape.sniff_mime (img.bytes);
                shape = img;
            } else if (mapped != null && parts.size > 0) {
                shape = new Shape (mapped);
            } else if (parts.size == 0) {
                if (text == "") return null;
                shape = new Shape ("text");
            } else if (parts.size == 1 && is_box (parts[0].path, wpx, hpx) && parts[0].mode == PartMode.FILL_STROKE) {
                shape = new Shape ("rectangle");
            } else {
                var ps = new PathShape ();
                var path = new PathData ();
                bool any_fill = false, any_line = false;
                foreach (var part in parts) {
                    path.append (part.path);
                    if (part.mode != PartMode.STROKE) any_fill = true;
                    if (part.mode != PartMode.FILL_ONLY) any_line = true;
                }
                ps.path = path;
                ps.natural_w = double.max (wpx, 1e-3);
                ps.natural_h = double.max (hpx, 1e-3);
                shape = ps;
                apply_style (s, master, shape.style, false);
                if (!any_fill) shape.style.fill_kind = FillKind.NONE;
                if (!any_line) shape.style.stroke = "none";
                shape.w = wpx;
                shape.h = hpx;
                decompose (a, shape);
                shape.text = text;
                return shape;
            }
            shape.w = wpx;
            shape.h = hpx;
            decompose (a, shape);
            apply_style (s, master, shape.style, false);
            if (shape.kind == "text" && !(shape is ImageShape)) {
                shape.style.fill_kind = FillKind.NONE;
                shape.style.stroke = "none";
            }
            if (shape is ImageShape) {
                shape.style.fill_kind = FillKind.NONE;
                shape.style.stroke = "none";
            } else {
                shape.text = text;
            }
            return shape;
        }

        private static uint8[] image_bytes (uint8[] data, int type, int format) {
            if (type == 1 && (format == 0 || format == 255) && data.length > 16 && !(data[0] == 'B' && data[1] == 'M')) {
                uint32 header = data[0] | (data[1] << 8) | (data[2] << 16) | ((uint32) data[3] << 24);
                uint32 bits = data.length > 15 ? (data[14] | (data[15] << 8)) : 24;
                uint32 used = data.length > 35 ? (data[32] | (data[33] << 8) | (data[34] << 16) | ((uint32) data[35] << 24)) : 0;
                if (header == 12) {
                    bits = data.length > 11 ? (data[10] | (data[11] << 8)) : 24;
                    used = 0;
                }
                uint32 colors = used > 0 ? used : (bits <= 8 ? (1u << bits) : 0);
                uint32 off = 14 + header + colors * (header == 12 ? 3 : 4);
                uint32 size = data.length + 14;
                var buf = new ByteArray ();
                buf.append ({ 'B', 'M', (uint8) (size & 0xff), (uint8) ((size >> 8) & 0xff), (uint8) ((size >> 16) & 0xff), (uint8) (size >> 24),
                    0, 0, 0, 0, (uint8) (off & 0xff), (uint8) ((off >> 8) & 0xff), (uint8) ((off >> 16) & 0xff), (uint8) (off >> 24) });
                buf.append (data);
                return buf.steal ();
            }
            return data;
        }

        private static bool is_box (PathData p, double w, double h) {
            var polys = p.flatten (0.5);
            if (polys.size != 1 || !polys[0].closed || polys[0].pts.length != 4) return false;
            foreach (var pt in polys[0].pts) {
                bool okx = pt.x.abs () < 0.5 || (pt.x - w).abs () < 0.5;
                bool oky = pt.y.abs () < 0.5 || (pt.y - h).abs () < 0.5;
                if (!okx || !oky) return false;
            }
            return true;
        }

        private Point page_point (Cairo.Matrix parent, double x, double y) {
            var mt = mul (parent, to_px ());
            mt.transform_point (ref x, ref y);
            return Point (x, y);
        }

        private Connector build_connector (VsdShape s, VsdShape? master, VsdShape xf, Cairo.Matrix parent, Cairo.Matrix local) {
            var c = new Connector ();
            apply_style (s, master, c.style, true);
            c.style.fill_kind = FillKind.NONE;
            var src = s.one_d ? s : master;
            var b = page_point (parent, src.bx, src.by);
            var e = page_point (parent, src.ex, src.ey);
            c.src.x = b.x;
            c.src.y = b.y;
            c.dst.x = e.x;
            c.dst.y = e.y;
            Point[] pts = {};
            var mt = mul (local, to_px ());
            var gsrc = s.geoms.size > 0 ? s : master;
            if (gsrc != null) {
                foreach (var g in gsrc.geoms) {
                    if (g.no_show) continue;
                    var path = build_path (g, gsrc, xf.width, xf.height);
                    path.transform (mt);
                    foreach (var poly in path.flatten (0.5)) foreach (var p in poly.pts) pts += p;
                    break;
                }
            }
            bool ortho = pts.length > 2;
            for (int i = 1; i < pts.length; i++) {
                if ((pts[i].x - pts[i - 1].x).abs () > 0.5 && (pts[i].y - pts[i - 1].y).abs () > 0.5) ortho = false;
            }
            string mname = "";
            if (s.master_page != Vsd.NONE) {
                var mp = m.master (s.master_page);
                if (mp != null) mname = mp.name.down ();
            }
            if (mname.contains ("dynamic connector") || ortho) c.route = RouteKind.ORTHOGONAL;
            else c.route = RouteKind.STRAIGHT;
            c.points = pts.length >= 2 ? pts : new Point[] { b, e };
            if (c.route == RouteKind.STRAIGHT && pts.length > 2) {
                Point[] wp = {};
                for (int i = 1; i < pts.length - 1; i++) wp += pts[i];
                c.waypoints = wp;
            }
            c.text = clean_text (s.text ?? (master != null ? master.text : null));
            return c;
        }

        private static void arc3 (PathData p, double sx, double sy, double mx, double my, double ex, double ey) {
            double d = 2 * (sx * (my - ey) + mx * (ey - sy) + ex * (sy - my));
            if (d.abs () < 1e-12) {
                p.line_to (ex, ey);
                return;
            }
            double s2 = sx * sx + sy * sy, m2 = mx * mx + my * my, e2 = ex * ex + ey * ey;
            double cx = (s2 * (my - ey) + m2 * (ey - sy) + e2 * (sy - my)) / d;
            double cy = (s2 * (ex - mx) + m2 * (sx - ex) + e2 * (mx - sx)) / d;
            double r = Math.hypot (sx - cx, sy - cy);
            double a0 = Math.atan2 (sy - cy, sx - cx);
            double am = Math.atan2 (my - cy, mx - cx);
            double a1 = Math.atan2 (ey - cy, ex - cx);
            double d1 = norm (a1 - a0), dm = norm (am - a0);
            double sweep = dm <= d1 ? d1 : d1 - 2 * Math.PI;
            int n = int.max (4, (int) Math.ceil (sweep.abs () / (Math.PI / 12)));
            for (int i = 1; i <= n; i++) {
                double t = a0 + sweep * i / n;
                if (i == n) p.line_to (ex, ey);
                else p.line_to (cx + r * Math.cos (t), cy + r * Math.sin (t));
            }
        }

        private static double norm (double a) {
            if (a.is_nan () || a.is_infinity () != 0) return 0;
            while (a < 0) a += 2 * Math.PI;
            while (a >= 2 * Math.PI) a -= 2 * Math.PI;
            return a;
        }

        private static void ell_arc (PathData p, double sx, double sy, double ax, double ay, double ex, double ey, double angle, double ratio) {
            if (ratio.abs () < 1e-9) ratio = 1;
            double ca = Math.cos (-angle), sa = Math.sin (-angle);
            double tsx = (sx * ca - sy * sa), tsy = (sx * sa + sy * ca) * ratio;
            double tax = (ax * ca - ay * sa), tay = (ax * sa + ay * ca) * ratio;
            double tex = (ex * ca - ey * sa), tey = (ex * sa + ey * ca) * ratio;
            var tmp = new PathData ();
            tmp.move_to (tsx, tsy);
            arc3 (tmp, tsx, tsy, tax, tay, tex, tey);
            double cb = Math.cos (angle), sb = Math.sin (angle);
            for (int i = 1; i < tmp.segs.size; i++) {
                var s = tmp.segs[i];
                double x = s.x, y = s.y / ratio;
                p.line_to (x * cb - y * sb, x * sb + y * cb);
            }
            var last = p.segs[p.segs.size - 1];
            last.x = ex;
            last.y = ey;
        }

        private static void add_ellipse (PathData p, double x, double y, double a, double b, double c, double d) {
            double ux = a - x, uy = b - y, vx = c - x, vy = d - y;
            double k = PathData.KAPPA;
            p.move_to (x + ux, y + uy);
            p.curve_to (x + ux + k * vx, y + uy + k * vy, x + vx + k * ux, y + vy + k * uy, x + vx, y + vy);
            p.curve_to (x + vx - k * ux, y + vy - k * uy, x - ux + k * vx, y - uy + k * vy, x - ux, y - uy);
            p.curve_to (x - ux - k * vx, y - uy - k * vy, x - vx - k * ux, y - vy - k * uy, x - vx, y - vy);
            p.curve_to (x - vx + k * ux, y - vy + k * uy, x + ux - k * vx, y + uy - k * vy, x + ux, y + uy);
            p.close ();
        }

        private static void nurbs (PathData p, double sx, double sy, double[] ctrl, double[] knots_in, double[] weights_in, int degree, double ex, double ey) {
            double[] cx = { sx };
            double[] cy = { sy };
            for (int i = 0; i + 1 < ctrl.length; i += 2) {
                cx += ctrl[i];
                cy += ctrl[i + 1];
            }
            cx += ex;
            cy += ey;
            int n = cx.length;
            if (degree < 1) degree = 1;
            if (degree > 10) degree = 10;
            if (degree >= n) degree = n - 1;
            double[] w = {};
            for (int i = 0; i < n; i++) w += i < weights_in.length && weights_in[i] > 1e-9 ? weights_in[i] : 1;
            double[] k = {};
            foreach (double v in knots_in) {
                if (v.is_nan () || v.is_infinity () != 0) {
                    p.line_to (ex, ey);
                    return;
                }
                k += k.length > 0 && v < k[k.length - 1] ? k[k.length - 1] : v;
            }
            if (k.length == 0 || n < 2 || degree < 1) {
                p.line_to (ex, ey);
                return;
            }
            int lead = 0;
            while (lead < k.length && k[lead] == k[0]) lead++;
            while (lead < degree + 1 && k.length < n + degree + 1) {
                double[] pre = { k[0] };
                foreach (double v in k) pre += v;
                k = pre;
                lead++;
            }
            while (k.length < n + degree + 1) k += k[k.length - 1];
            double k0 = k[degree], k1 = k[n];
            if (k1 - k0 < 1e-12) {
                for (int i = 1; i < n; i++) p.line_to (cx[i], cy[i]);
                return;
            }
            int steps = int.min (200, int.max (16, n * 8));
            for (int s = 1; s <= steps; s++) {
                double t = k0 + (k1 - k0) * s / steps;
                if (s == steps) {
                    p.line_to (ex, ey);
                    break;
                }
                int span = degree;
                while (span < n - 1 && t >= k[span + 1]) span++;
                double[] dx = new double[degree + 1];
                double[] dy = new double[degree + 1];
                double[] dw = new double[degree + 1];
                for (int j = 0; j <= degree; j++) {
                    int idx = (span - degree + j).clamp (0, n - 1);
                    dw[j] = w[idx];
                    dx[j] = cx[idx] * w[idx];
                    dy[j] = cy[idx] * w[idx];
                }
                for (int r = 1; r <= degree; r++) {
                    for (int j = degree; j >= r; j--) {
                        int i = span - degree + j;
                        double denom = k[(i + degree - r + 1).clamp (0, k.length - 1)] - k[i.clamp (0, k.length - 1)];
                        double alpha = denom.abs () < 1e-12 ? 0 : (t - k[i.clamp (0, k.length - 1)]) / denom;
                        dx[j] = (1 - alpha) * dx[j - 1] + alpha * dx[j];
                        dy[j] = (1 - alpha) * dy[j - 1] + alpha * dy[j];
                        dw[j] = (1 - alpha) * dw[j - 1] + alpha * dw[j];
                    }
                }
                double ww = dw[degree].abs () < 1e-12 ? 1 : dw[degree];
                p.line_to (dx[degree] / ww, dy[degree] / ww);
            }
        }

        private PathData build_path (VsdGeom g, VsdShape owner, double w, double h) {
            var p = new PathData ();
            double cx = 0, cy = 0, sx = 0, sy = 0;
            bool started = false;
            foreach (var r in g.ordered ()) {
                double x = r.x, y = r.y;
                switch (r.kind) {
                    case 0x8a:
                        close_if (p, cx, cy, sx, sy, started);
                        p.move_to (x, y);
                        cx = sx = x;
                        cy = sy = y;
                        started = true;
                        continue;
                    case 0x8b:
                    case 0xa5:
                    case 0xa6:
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        p.line_to (x, y);
                        break;
                    case 0x8c:
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        double dx = x - cx, dy = y - cy, len = Math.hypot (dx, dy);
                        if (r.a.abs () < 1e-9 || len < 1e-9) {
                            p.line_to (x, y);
                        } else {
                            double mx = (cx + x) / 2 + r.a * dy / len, my = (cy + y) / 2 - r.a * dx / len;
                            arc3 (p, cx, cy, mx, my, x, y);
                        }
                        break;
                    case 0x90:
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        ell_arc (p, cx, cy, r.a, r.b, x, y, r.c, r.d);
                        break;
                    case 0x8f:
                        close_if (p, cx, cy, sx, sy, started);
                        add_ellipse (p, x, y, r.a, r.b, r.c, r.d);
                        started = false;
                        cx = sx = x;
                        cy = sy = y;
                        continue;
                    case 0x8d:
                        continue;
                    case 0xc1:
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        double[] pts = r.pts;
                        int xt = r.xtype, yt = r.ytype;
                        if (r.data_id != Vsd.NONE && owner.data.has_key (r.data_id)) {
                            var d = owner.data[r.data_id];
                            pts = d.pts;
                            xt = d.xtype;
                            yt = d.ytype;
                        }
                        for (int i = 0; i + 1 < pts.length; i += 2) p.line_to (xt == 0 ? pts[i] * w : pts[i], yt == 0 ? pts[i + 1] * h : pts[i + 1]);
                        p.line_to (x, y);
                        break;
                    case 0xc3:
                        ensure_start (p, ref started, cx, cy, ref sx, ref sy);
                        double[] ctrl = r.pts;
                        double[] knots = r.knots;
                        double[] weights = r.weights;
                        int deg = r.degree, nxt = r.xtype, nyt = r.ytype;
                        if (r.data_id != Vsd.NONE && owner.data.has_key (r.data_id)) {
                            var d = owner.data[r.data_id];
                            ctrl = d.pts;
                            deg = d.degree;
                            nxt = d.xtype;
                            nyt = d.ytype;
                            double[] kn = { r.knot_prev };
                            foreach (double v in d.knots) kn += v;
                            kn += r.knot;
                            kn += d.last_knot;
                            knots = kn;
                            double[] wt = { r.weight_prev };
                            foreach (double v in d.weights) wt += v;
                            wt += r.weight;
                            weights = wt;
                        }
                        double[] abs_ctrl = {};
                        for (int i = 0; i + 1 < ctrl.length; i += 2) {
                            abs_ctrl += nxt == 0 ? ctrl[i] * w : ctrl[i];
                            abs_ctrl += nyt == 0 ? ctrl[i + 1] * h : ctrl[i + 1];
                        }
                        if (abs_ctrl.length == 0) p.line_to (x, y);
                        else nurbs (p, cx, cy, abs_ctrl, knots, weights, deg, x, y);
                        break;
                    default:
                        continue;
                }
                cx = x;
                cy = y;
            }
            close_if (p, cx, cy, sx, sy, started);
            return p;
        }

        private static void ensure_start (PathData p, ref bool started, double cx, double cy, ref double sx, ref double sy) {
            if (started) return;
            p.move_to (cx, cy);
            sx = cx;
            sy = cy;
            started = true;
        }

        private static void close_if (PathData p, double cx, double cy, double sx, double sy, bool started) {
            if (!started || p.segs.size < 2) return;
            var last = p.segs[p.segs.size - 1];
            if (last.kind == SegKind.CLOSE || last.kind == SegKind.MOVE) return;
            if ((cx - sx).abs () < 1e-7 && (cy - sy).abs () < 1e-7) p.close ();
        }
    }
}
