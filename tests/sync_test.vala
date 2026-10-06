using Singularity.Apps.Draw;
using Singularity.Accounts;

int checks = 0;

void check (bool ok, string what) {
    checks++;
    if (!ok) {
        stderr.printf ("FAILED: %s\n", what);
        Process.exit (1);
    }
    print ("ok   %s\n", what);
}

public class MemDrive : Object, CloudDrive {
    private Account acc;
    public Gee.HashMap<string, Bytes> files = new Gee.HashMap<string, Bytes> ();
    public Gee.HashMap<string, int> versions = new Gee.HashMap<string, int> ();
    public int uploads = 0;

    public MemDrive () {
        acc = (Account) Object.new (typeof (Account), "id", "mem");
    }

    public Account account { get { return acc; } }
    public string root_id { get { return "/"; } }

    private CloudEntry entry_for (string id) throws Error {
        if (!files.has_key (id)) throw new IOError.NOT_FOUND ("missing " + id);
        var e = new CloudEntry ();
        e.id = id;
        e.parent_id = "/";
        e.name = Path.get_basename (id);
        e.size = files[id].length;
        e.etag = "\"v%d\"".printf (versions[id]);
        return e;
    }

    public void put (string id, uint8[] data) {
        files[id] = new Bytes (data);
        versions[id] = (versions.has_key (id) ? versions[id] : 0) + 1;
    }

    public async Gee.List<CloudEntry> list (string folder_id, Cancellable? cancellable = null) throws Error {
        var l = new Gee.ArrayList<CloudEntry> ();
        foreach (var k in files.keys) l.add (entry_for (k));
        return l;
    }

    public async CloudEntry stat (string id, Cancellable? cancellable = null) throws Error {
        return entry_for (id);
    }

    public async void download_to (CloudEntry entry, OutputStream output, Cancellable? cancellable = null, TransferProgress? progress = null) throws Error {
        size_t w;
        output.write_all (files[entry.id].get_data (), out w, cancellable);
    }

    public async void download (CloudEntry entry, File destination, Cancellable? cancellable = null, TransferProgress? progress = null) throws Error {
        FileUtils.set_data (destination.get_path (), files[entry.id].get_data ());
    }

    public async CloudEntry upload (string folder_id, string name, File source, Cancellable? cancellable = null, TransferProgress? progress = null) throws Error {
        uint8[] d;
        FileUtils.get_data (source.get_path (), out d);
        put ("/" + name, d);
        uploads++;
        return entry_for ("/" + name);
    }

    public async CloudEntry replace (CloudEntry entry, File source, Cancellable? cancellable = null, TransferProgress? progress = null) throws Error {
        uint8[] d;
        FileUtils.get_data (source.get_path (), out d);
        put (entry.id, d);
        uploads++;
        return entry_for (entry.id);
    }

    public async CloudEntry replace_if_match (CloudEntry entry, File source, string expected_etag, Cancellable? cancellable = null, TransferProgress? progress = null) throws Error {
        if (entry_for (entry.id).etag != expected_etag) throw new IOError.FAILED ("412 Precondition Failed");
        return yield replace (entry, source, cancellable, progress);
    }

    public async CloudEntry rename (CloudEntry entry, string new_name, Cancellable? cancellable = null) throws Error {
        throw new IOError.NOT_SUPPORTED ("no");
    }

    public async CloudEntry move (CloudEntry entry, string folder_id, string? new_name = null, Cancellable? cancellable = null) throws Error {
        throw new IOError.NOT_SUPPORTED ("no");
    }

    public async void delete (CloudEntry entry, Cancellable? cancellable = null) throws Error {
        files.unset (entry.id);
    }

    public async CloudEntry create_folder (string parent_id, string name, Cancellable? cancellable = null) throws Error {
        throw new IOError.NOT_SUPPORTED ("no");
    }
}

string scratch;

Shape add_box (Document d, string text, double x, double y) {
    var s = new Shape ("rectangle", x, y, 120, 60);
    s.text = text;
    d.add_item (s);
    return s;
}

Item? by_text (Document d, string text) {
    foreach (var it in d.page.items) if (it.text == text) return it;
    return null;
}

int count_text (Document d, string text) {
    int n = 0;
    foreach (var it in d.page.items) if (it.text == text) n++;
    return n;
}

int uploads_of (CloudDrive drive) {
    var m = drive as MemDrive;
    return m != null ? m.uploads : -1;
}

async void scenario (CloudDrive drive, string ext) throws Error {
    var start = new Document ();
    var a1 = add_box (start, "Start", 40, 40);
    add_box (start, "Review", 240, 40);
    add_box (start, "Ship", 440, 40);
    string seed = Path.build_filename (scratch, "seed." + ext);
    Formats.save (start, seed);
    uint8[] seed_data;
    FileUtils.get_data (seed, out seed_data);
    var entry = yield drive.upload (drive.root_id, "plan." + ext, File.new_for_path (seed));
    int base_uploads = uploads_of (drive);
    print ("remote %s etag %s\n", entry.id, entry.etag);

    string dir_a = Path.build_filename (scratch, ext + "-a");
    string dir_b = Path.build_filename (scratch, ext + "-b");
    DirUtils.create_with_parents (dir_a, 0700);
    DirUtils.create_with_parents (dir_b, 0700);
    string pa = Path.build_filename (dir_a, "plan." + ext);
    string pb = Path.build_filename (dir_b, "plan." + ext);
    foreach (string d in new string[] { dir_a, dir_b }) {
        foreach (string sfx in new string[] { ".sync", ".syncbase" }) FileUtils.remove (Path.build_filename (d, ".plan." + ext + sfx));
    }
    FileUtils.set_data (pa, seed_data);
    FileUtils.set_data (pb, seed_data);
    var sa = new DrawCloudSync (drive, entry, pa);
    var sb = new DrawCloudSync (drive, entry, pb);
    yield sa.attach ();
    yield sb.attach ();
    var da = Formats.load (pa);
    var db = Formats.load (pb);

    var r = yield sa.sync (da, true, ConflictPolicy.KEEP_BOTH);
    print ("first sync uploaded=%s remote=%s uploads=%d base=%d\n", r.uploaded.to_string (), r.remote_changed.to_string (), uploads_of (drive), base_uploads);
    check (!r.uploaded && !r.remote_changed && uploads_of (drive) == base_uploads, ext + ": nothing to do when nothing changed");

    by_text (da, "Review").move_by (0, 100);
    add_box (da, "Added on A", 40, 300);
    r = yield sa.sync (da, true, ConflictPolicy.KEEP_BOTH);
    check (r.uploaded && !r.remote_changed, ext + ": A uploads its edit on save");
    check (yield sb.remote_changed (), ext + ": B detects the remote change by entity tag");

    var ship = by_text (db, "Ship");
    ship.style.fill = "#c62828";
    var start_b = by_text (db, "Start");
    db.page.items.remove (start_b);
    r = yield sb.sync (db, true, ConflictPolicy.KEEP_BOTH);
    check (r.remote_changed && r.uploaded, ext + ": B pulls, merges and uploads");
    check (r.conflicts.size == 0, ext + ": edits to different shapes do not conflict");
    var rv = (Shape) by_text (db, "Review");
    check (rv != null && Math.fabs (rv.y - 140) < 0.5, ext + ": B got the move made on A");
    check (by_text (db, "Added on A") != null, ext + ": B got the shape added on A");
    check (by_text (db, "Start") == null, ext + ": B keeps its own deletion");
    check (((Shape) by_text (db, "Ship")).style.fill.down ().has_prefix ("#c62828"), ext + ": B keeps its own colour change");

    r = yield sa.sync (da, true, ConflictPolicy.KEEP_BOTH);
    check (r.remote_changed && !r.uploaded, ext + ": A pulls without uploading again");
    check (by_text (da, "Start") == null && ((Shape) by_text (da, "Ship")).style.fill.down ().has_prefix ("#c62828"), ext + ": A now matches B");

    var on_disk = Formats.load (pa);
    check (by_text (on_disk, "Added on A") != null && by_text (on_disk, "Start") == null, ext + ": merged drawing saved to the working copy");

    by_text (da, "Review").text = "Review by A";
    by_text (db, "Review").text = "Review by B";
    r = yield sa.sync (da, true, ConflictPolicy.KEEP_BOTH);
    check (r.uploaded, ext + ": A uploads its text");
    r = yield sb.sync (db, true, ConflictPolicy.KEEP_BOTH);
    check (r.conflicts.size == 1 && r.conflicts[0].label.has_prefix ("Review"), ext + ": same shape changed on both sides is reported");
    check (count_text (db, "Review by B") == 1 && count_text (db, "Review by A") == 1, ext + ": both versions kept");

    by_text (da, "Ship").text = "Ship it";
    r = yield sb.sync (db, false, ConflictPolicy.KEEP_BOTH);
    check (!r.remote_changed && !r.uploaded, ext + ": pull only does not upload");
    int before = uploads_of (drive);
    by_text (db, "Ship").move_by (10, 0);
    r = yield sa.sync (da, true, ConflictPolicy.KEEP_LOCAL);
    check (r.remote_changed && r.uploaded && (before < 0 || uploads_of (drive) == before + 1), ext + ": A merges B's conflict copy then uploads");
    check (count_text (da, "Review by A") == 1 && count_text (da, "Review by B") == 1, ext + ": A sees both versions");
    a1 = null;
}

int main (string[] args) {
    scratch = Path.build_filename (Environment.get_variable ("TMPDIR") ?? Environment.get_tmp_dir (), "draw-sync-scratch");
    DirUtils.create_with_parents (scratch, 0700);
    var loop = new MainLoop ();
    string[] formats = { "odg", "vsdx", "sdraw" };
    int failed = 0;
    string? account_id = Environment.get_variable ("DRAW_SYNC_ACCOUNT");
    run_all.begin (formats, account_id, (o, res) => {
        try {
            run_all.end (res);
        } catch (Error e) {
            stderr.printf ("FAILED: %s\n", e.message);
            failed = 1;
        }
        loop.quit ();
    });
    loop.run ();
    print ("%d checks\n", checks);
    return failed;
}

async void run_all (string[] formats, string? account_id) throws Error {
    CloudDrive drive = new MemDrive ();
    if (account_id != null) {
        var mgr = Manager.get_default ();
        yield mgr.load ();
        var account = mgr.get_account (account_id);
        if (account == null) throw new IOError.NOT_FOUND ("no account " + account_id);
        drive = CloudDrive.for_account (account);
        print ("drive %s for %s\n", drive.get_type ().name (), account.display_name);
    }
    foreach (string f in formats) yield scenario (drive, f);
}
