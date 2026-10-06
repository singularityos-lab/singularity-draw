using Singularity.Accounts;

namespace Singularity.Apps.Draw {

    public class DrawCloudSync : Object {
        public CloudDrive drive { get; construct; }
        public CloudEntry entry { get; set; }
        public string local_path { get; construct; }
        public string base_etag { get; private set; default = ""; }

        public DrawCloudSync (CloudDrive drive, CloudEntry entry, string local_path) {
            Object (drive: drive, entry: entry, local_path: local_path);
            load_state ();
        }

        public static bool is_cloud_copy (string path) {
            return CloudFile.for_local (File.new_for_path (path)) != null;
        }

        public static async DrawCloudSync? for_local (string path) {
            var cf = CloudFile.for_local (File.new_for_path (path));
            if (cf == null) return null;
            try {
                yield Manager.get_default ().load ();
            } catch (Error e) {
                return null;
            }
            var drive = cf.get_drive ();
            if (drive == null) return null;
            return new DrawCloudSync (drive, cf.entry, path);
        }

        private string side (string suffix) {
            return Path.build_filename (Path.get_dirname (local_path), "." + Path.get_basename (local_path) + suffix);
        }

        private void load_state () {
            try {
                string t;
                if (FileUtils.get_contents (side (".sync"), out t)) base_etag = t.strip ();
            } catch (Error e) {
                base_etag = "";
            }
        }

        public bool has_base () {
            return FileUtils.test (side (".syncbase"), FileTest.EXISTS);
        }

        private void record_base (uint8[] data, string etag) throws Error {
            FileUtils.set_data (side (".syncbase"), data);
            FileUtils.set_contents (side (".sync"), etag);
            base_etag = etag;
        }

        private Document? base_document () {
            try {
                uint8[] data;
                if (!FileUtils.get_data (side (".syncbase"), out data)) return null;
                return Formats.load_data (data, local_path);
            } catch (Error e) {
                return null;
            }
        }

        private static bool same_bytes (uint8[] a, uint8[] b) {
            if (a.length != b.length) return false;
            return Memory.cmp (a, b, a.length) == 0;
        }

        private bool same_drawing (uint8[] a, uint8[] b) {
            try {
                var da = Formats.load_data (a, local_path);
                var db = Formats.load_data (b, local_path);
                return NativeFormat.serialize_document (da) == NativeFormat.serialize_document (db);
            } catch (Error e) {
                return false;
            }
        }

        public async void attach (Cancellable? cancellable = null) throws Error {
            if (has_base () && base_etag != "") return;
            var remote = yield drive.stat (entry.id, cancellable);
            uint8[] data;
            FileUtils.get_data (local_path, out data);
            record_base (data, remote.etag);
            entry = remote;
        }

        public async bool remote_changed (Cancellable? cancellable = null) throws Error {
            var remote = yield drive.stat (entry.id, cancellable);
            return remote.etag != base_etag;
        }

        private async uint8[] download_bytes (CloudEntry e, Cancellable? cancellable) throws Error {
            var mem = new MemoryOutputStream.resizable ();
            yield drive.download_to (e, mem, cancellable);
            mem.close ();
            var bytes = mem.steal_as_bytes ();
            return bytes.get_data ();
        }

        private async CloudEntry upload (string expected, Cancellable? cancellable) throws Error {
            var f = File.new_for_path (local_path);
            try {
                return yield drive.replace_if_match (entry, f, expected, cancellable);
            } catch (IOError.NOT_SUPPORTED e) {
                return yield drive.replace (entry, f, cancellable);
            } catch (IOError.INVALID_ARGUMENT e) {
                return yield drive.replace (entry, f, cancellable);
            }
        }

        public async SyncReport sync (Document doc, bool upload_changes, ConflictPolicy policy, Cancellable? cancellable = null) throws Error {
            var report = new SyncReport ();
            if (!has_base ()) yield attach (cancellable);
            for (int attempt = 0; attempt < 4; attempt++) {
                var remote = yield drive.stat (entry.id, cancellable);
                if (remote.etag != base_etag) {
                    report.remote_changed = true;
                    uint8[] theirs_data = yield download_bytes (remote, cancellable);
                    var theirs = Formats.load_data (theirs_data, local_path);
                    var r = ThreeWayMerge.merge (base_document (), doc, theirs, policy);
                    report.added += r.added;
                    report.changed += r.changed;
                    report.removed += r.removed;
                    report.pages += r.pages;
                    report.comments += r.comments;
                    report.conflicts.add_all (r.conflicts);
                    record_base (theirs_data, remote.etag);
                    entry = remote;
                }
                if (!upload_changes) return report;
                Formats.save (doc, local_path);
                uint8[] mine;
                FileUtils.get_data (local_path, out mine);
                uint8[] base_data;
                FileUtils.get_data (side (".syncbase"), out base_data);
                if (same_bytes (mine, base_data) || same_drawing (mine, base_data)) return report;
                try {
                    var up = yield upload (base_etag, cancellable);
                    if (up.etag == "") up = yield drive.stat (entry.id, cancellable);
                    entry = up;
                    record_base (mine, up.etag);
                    report.uploaded = true;
                    return report;
                } catch (Error e) {
                    var now = yield drive.stat (entry.id, cancellable);
                    if (now.etag == base_etag) throw e;
                }
            }
            throw new IOError.BUSY (_("The online copy keeps changing; try again in a moment"));
        }
    }
}
