namespace Singularity.Apps.Draw {

    public class CfbEntry {
        public string name = "";
        public int kind = 0;
        public uint32 left = uint32.MAX;
        public uint32 right = uint32.MAX;
        public uint32 child = uint32.MAX;
        public uint32 start = 0;
        public uint64 size = 0;
    }

    public class CompoundFile {
        private const uint32 END = uint32.MAX - 1;
        private const uint32 FREE = uint32.MAX;
        private uint8[] data;
        private int sector_size = 512;
        private int mini_size = 64;
        private uint32 cutoff = 4096;
        private uint32[] fat = {};
        private uint32[] minifat = {};
        private uint8[] ministream = {};
        public Gee.ArrayList<CfbEntry> entries = new Gee.ArrayList<CfbEntry> ();

        public CompoundFile (uint8[] data) throws Error {
            this.data = data;
            if (data.length < 512 || data[0] != 0xd0 || data[1] != 0xcf || data[2] != 0x11 || data[3] != 0xe0) {
                throw new FormatError.INVALID (_("This is not a compound document."));
            }
            int shift = u16 (0x1e);
            if (shift < 7 || shift > 16) throw new FormatError.INVALID (_("This is not a compound document."));
            sector_size = 1 << shift;
            int mshift = u16 (0x20);
            mini_size = mshift >= 2 && mshift <= 12 ? 1 << mshift : 64;
            uint32 fat_sectors = u32 (0x2c);
            uint32 first_dir = u32 (0x30);
            cutoff = u32 (0x38);
            if (cutoff == 0) cutoff = 4096;
            uint32 first_minifat = u32 (0x3c);
            uint32 first_difat = u32 (0x44);
            uint32 difat_count = u32 (0x48);
            uint32[] difat = {};
            for (int i = 0; i < 109; i++) {
                uint32 s = u32 (0x4c + i * 4);
                if (s != FREE && s != END) difat += s;
            }
            uint32 next = first_difat;
            int per = sector_size / 4 - 1;
            for (uint32 k = 0; k < difat_count && next != END && next != FREE && k < 100000; k++) {
                long off = sector_offset (next);
                if (off < 0) break;
                for (int i = 0; i < per; i++) {
                    uint32 s = u32 (off + i * 4);
                    if (s != FREE && s != END) difat += s;
                }
                next = u32 (off + per * 4);
            }
            uint32[] table = {};
            int count = 0;
            foreach (uint32 s in difat) {
                if (count++ >= fat_sectors && fat_sectors > 0) break;
                long off = sector_offset (s);
                if (off < 0) continue;
                for (int i = 0; i < sector_size / 4; i++) table += u32 (off + i * 4);
            }
            fat = table;
            var dir = chain (first_dir, uint64.MAX);
            for (int i = 0; i + 128 <= dir.length; i += 128) {
                var e = new CfbEntry ();
                int len = (int) (dir[i + 0x40] | (dir[i + 0x41] << 8));
                len = int.min (len, 64);
                var sb = new StringBuilder ();
                for (int k = 0; k + 1 < len; k += 2) {
                    uint c = dir[i + k] | (dir[i + k + 1] << 8);
                    if (c == 0) break;
                    sb.append_unichar ((unichar) c);
                }
                e.name = sb.str;
                e.kind = dir[i + 0x42];
                e.left = le32 (dir, i + 0x44);
                e.right = le32 (dir, i + 0x48);
                e.child = le32 (dir, i + 0x4c);
                e.start = le32 (dir, i + 0x74);
                e.size = le32 (dir, i + 0x78);
                if (sector_size == 4096) e.size |= ((uint64) le32 (dir, i + 0x7c)) << 32;
                entries.add (e);
            }
            if (entries.size == 0 || entries[0].kind != 5) throw new FormatError.INVALID (_("This is not a compound document."));
            var mf = chain (first_minifat, uint64.MAX);
            uint32[] mtable = {};
            for (int i = 0; i + 4 <= mf.length; i += 4) mtable += le32 (mf, i);
            minifat = mtable;
            ministream = chain (entries[0].start, entries[0].size);
        }

        private static uint32 le32 (uint8[] d, int o) {
            if (o < 0 || o + 4 > d.length) return 0;
            return d[o] | (d[o + 1] << 8) | (d[o + 2] << 16) | ((uint32) d[o + 3] << 24);
        }

        private int u16 (long o) {
            if (o < 0 || o + 2 > data.length) return 0;
            return data[o] | (data[o + 1] << 8);
        }

        private uint32 u32 (long o) {
            if (o < 0 || o + 4 > data.length) return 0;
            return data[o] | (data[o + 1] << 8) | (data[o + 2] << 16) | ((uint32) data[o + 3] << 24);
        }

        private long sector_offset (uint32 s) {
            long off = ((long) s + 1) * sector_size;
            if (off < 0 || off + sector_size > data.length) return -1;
            return off;
        }

        private uint8[] chain (uint32 start, uint64 size) {
            var buf = new ByteArray ();
            uint32 s = start;
            int guard = 0;
            while (s != END && s != FREE && guard++ <= fat.length + 1) {
                long off = sector_offset (s);
                if (off < 0) break;
                buf.append (data[off:off + sector_size]);
                if (buf.len >= size) break;
                if (s >= fat.length) break;
                s = fat[s];
            }
            if (size != uint64.MAX && buf.len > size) buf.set_size ((uint) size);
            return buf.steal ();
        }

        private uint8[] mini_chain (uint32 start, uint64 size) {
            var buf = new ByteArray ();
            uint32 s = start;
            int guard = 0;
            while (s != END && s != FREE && guard++ <= minifat.length + 1) {
                long off = (long) s * mini_size;
                if (off < 0 || off + mini_size > ministream.length) break;
                buf.append (ministream[off:off + mini_size]);
                if (buf.len >= size) break;
                if (s >= minifat.length) break;
                s = minifat[s];
            }
            if (buf.len > size) buf.set_size ((uint) size);
            return buf.steal ();
        }

        public CfbEntry? find (string name) {
            foreach (var e in entries) if (e.kind == 2 && e.name.down () == name.down ()) return e;
            return null;
        }

        public bool has (string name) {
            return find (name) != null;
        }

        public uint8[]? read (string name) {
            var e = find (name);
            if (e == null) return null;
            return read_entry (e);
        }

        public uint8[] read_entry (CfbEntry e) {
            if (e.size < cutoff) return mini_chain (e.start, e.size);
            return chain (e.start, e.size);
        }
    }
}
