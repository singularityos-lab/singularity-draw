using Singularity.Apps.Draw;

class Relay : Object {
    public DrawLiveSync a;
    public DrawLiveSync b;
    public Gee.ArrayList<Json.Object> to_a = new Gee.ArrayList<Json.Object> ();
    public Gee.ArrayList<Json.Object> to_b = new Gee.ArrayList<Json.Object> ();

    public Relay (DrawLiveSync a, DrawLiveSync b) {
        this.a = a;
        this.b = b;
        a.outgoing.connect ((m) => to_b.add (copy (m)));
        b.outgoing.connect ((m) => to_a.add (copy (m)));
    }

    private static Json.Object copy (Json.Object m) {
        var node = new Json.Node (Json.NodeType.OBJECT);
        node.set_object (m);
        var p = new Json.Parser ();
        try {
            p.load_from_data (Json.to_string (node, false));
        } catch (Error e) {
            assert_not_reached ();
        }
        return p.get_root ().get_object ();
    }

    public void flush () {
        while (to_a.size > 0 || to_b.size > 0) {
            var la = new Gee.ArrayList<Json.Object> ();
            la.add_all (to_a);
            to_a.clear ();
            var lb = new Gee.ArrayList<Json.Object> ();
            lb.add_all (to_b);
            to_b.clear ();
            foreach (var m in la) a.receive (m);
            foreach (var m in lb) b.receive (m);
        }
    }
}

string items_of (Document d) {
    var sb = new StringBuilder ();
    foreach (var p in d.pages) {
        sb.append (p.id).append (":").append (p.name).append ("[");
        foreach (var it in p.items) {
            sb.append (it.id).append ("=").append (it.text).append ("@%.0f,%.0f ".printf (it.bounds ().x, it.bounds ().y));
        }
        sb.append ("]");
    }
    return sb.str;
}

Document guest_of (DrawLiveSync host) {
    try {
        var st = host.snapshot ();
        var node = new Json.Node (Json.NodeType.OBJECT);
        node.set_object (st);
        var p = new Json.Parser ();
        p.load_from_data (Json.to_string (node, false));
        return DrawLiveSync.document_from (p.get_root ().get_object ());
    } catch (Error e) {
        error ("document_from: %s", e.message);
    }
}

void test_join_and_edit () {
    var ha = new Document ();
    ha.live_tag = "_aaa";
    ha.edit ("Add", () => {
        var s = new Shape ("rectangle", 10, 20, 100, 50);
        s.id = ha.new_id ();
        s.text = "Start";
        ha.add_item (s);
    });
    var sa = new DrawLiveSync (ha, "pa");
    var hb = guest_of (sa);
    hb.live_tag = "_bbb";
    assert (items_of (ha) == items_of (hb));
    var sb = new DrawLiveSync (hb, "pb");
    var relay = new Relay (sa, sb);

    ha.edit ("Add", () => {
        var s = new Shape ("ellipse", 200, 20, 80, 80);
        s.id = ha.new_id ();
        s.text = "From A";
        ha.add_item (s);
    });
    hb.edit ("Add", () => {
        var s = new Shape ("rectangle", 10, 200, 80, 40);
        s.id = hb.new_id ();
        s.text = "From B";
        hb.add_item (s);
    });
    relay.flush ();
    assert (items_of (ha) == items_of (hb));
    assert (ha.page.items.size == 3);
    assert (ha.page.items[0].id != ha.page.items[1].id && ha.page.items[1].id != ha.page.items[2].id);

    var first_b = hb.page.find (ha.page.items[0].id);
    hb.edit ("Move", () => hb.move_items (new Gee.ArrayList<Item>.wrap ({ first_b }), 30, 0));
    relay.flush ();
    assert (items_of (ha) == items_of (hb));
    assert ((ha.page.items[0].bounds ().x - 40).abs () < 0.01);

    var t1 = ha.page.items[1];
    var t2 = hb.page.find (t1.id);
    ha.edit ("Text", () => t1.text = "A wins?");
    hb.edit ("Text", () => t2.text = "B wins?");
    relay.flush ();
    assert (items_of (ha) == items_of (hb));
    assert (sa.conflicts_lost + sb.conflicts_lost >= 1);

    var gone = hb.page.items[2];
    hb.edit ("Delete", () => hb.delete_items (new Gee.ArrayList<Item>.wrap ({ gone })));
    relay.flush ();
    assert (items_of (ha) == items_of (hb));
    assert (ha.page.items.size == 2);

    ha.edit ("Page", () => {
        var p = ha.add_page (-1, "Second");
        var s = new Shape ("rectangle", 5, 5, 30, 30);
        s.id = ha.new_id ();
        s.text = "On page 2";
        p.items.add (s);
    });
    relay.flush ();
    assert (items_of (ha) == items_of (hb));
    assert (hb.pages.size == 2 && hb.pages[1].name == "Second");
}

void test_undo_keeps_remote () {
    var ha = new Document ();
    ha.live_tag = "_aaa";
    var sa = new DrawLiveSync (ha, "pa");
    var hb = guest_of (sa);
    hb.live_tag = "_bbb";
    var sb = new DrawLiveSync (hb, "pb");
    var relay = new Relay (sa, sb);
    ha.edit ("Add", () => {
        var s = new Shape ("rectangle", 0, 0, 50, 50);
        s.id = ha.new_id ();
        s.text = "Mine";
        ha.add_item (s);
    });
    relay.flush ();
    hb.edit ("Add", () => {
        var s = new Shape ("rectangle", 100, 0, 50, 50);
        s.id = hb.new_id ();
        s.text = "Theirs";
        hb.add_item (s);
    });
    relay.flush ();
    assert (ha.page.items.size == 2);
    ha.undo ();
    relay.flush ();
    assert (items_of (ha) == items_of (hb));
    assert (ha.page.items.size == 1 && ha.page.items[0].text == "Theirs");
}

void run_session (bool secure) {
    var loop = new MainLoop ();
    var host_doc = new Document ();
    host_doc.edit ("Add", () => {
        var s = new Shape ("rectangle", 10, 10, 60, 30);
        s.id = host_doc.new_id ();
        s.text = "Host";
        host_doc.add_item (s);
    });
    var host = new Singularity.LiveSession ("Alice", "draw-live", "/draw");
    var guest = new Singularity.LiveSession ("Bruno", "draw-live", "/draw");
    var hs = new DrawLiveSync (host_doc, host.my_id);
    hs.outgoing.connect ((m) => host.send (m));
    host.state_requested.connect (() => host.publish_state (hs.snapshot ()));
    host.message.connect ((m) => {
        if (m.get_string_member ("t") == "draw") hs.receive (m);
    });
    try {
        if (secure) host.host_secure (hs.snapshot (), 0, "127.0.0.1");
        else host.host (hs.snapshot (), 0, "127.0.0.1");
    } catch (Error e) {
        error ("host: %s", e.message);
    }
    Document? guest_doc = null;
    DrawLiveSync? gs = null;
    bool host_saw = false;
    guest.welcome.connect ((st) => {
        try {
            guest_doc = DrawLiveSync.document_from (st);
        } catch (Error e) {
            error ("welcome: %s", e.message);
        }
        guest_doc.live_tag = "_g";
        gs = new DrawLiveSync (guest_doc, guest.my_id);
        gs.load_stamps (st);
        gs.outgoing.connect ((m) => guest.send (m));
        guest_doc.edit ("Add", () => {
            var s = new Shape ("ellipse", 100, 100, 40, 40);
            s.id = guest_doc.new_id ();
            s.text = "Guest";
            guest_doc.add_item (s);
        });
    });
    hs.applied.connect (() => {
        host_saw = true;
        loop.quit ();
    });
    guest.join.begin (host.link, (o, r) => {
        try {
            guest.join.end (r);
        } catch (Error e) {
            error ("join: %s", e.message);
        }
    });
    Timeout.add_seconds (8, () => {
        loop.quit ();
        return Source.REMOVE;
    });
    loop.run ();
    assert (guest_doc != null);
    assert (host_saw);
    if (secure) {
        assert (host.link.contains ("&fp=") && guest.secure && guest.fingerprint == host.fingerprint);
    }
    assert (host_doc.page.items.size == 2);
    assert (items_of (host_doc) == items_of (guest_doc));
    guest.leave ();
    host.leave ();
}

void test_session () {
    run_session (false);
}

void test_secure_session () {
    run_session (true);
}

void test_wrong_fingerprint () {
    var loop = new MainLoop ();
    var host = new Singularity.LiveSession ("Alice", "draw-live", "/draw");
    var guest = new Singularity.LiveSession ("Eve", "draw-live", "/draw");
    try {
        host.host_secure (new Json.Object (), 0, "127.0.0.1");
    } catch (Error e) {
        error ("host: %s", e.message);
    }
    string bad = host.link.replace ("&fp=" + host.fingerprint, "&fp=" + string.nfill (64, '0'));
    bool welcomed = false, failed = false;
    guest.welcome.connect (() => welcomed = true);
    guest.join.begin (bad, (o, r) => {
        try {
            guest.join.end (r);
        } catch (Error e) {
            failed = true;
        }
        loop.quit ();
    });
    Timeout.add_seconds (8, () => {
        loop.quit ();
        return Source.REMOVE;
    });
    loop.run ();
    assert (failed && !welcomed);
    host.leave ();
}

int main (string[] args) {
    Intl.setlocale (LocaleCategory.ALL, "C");
    Test.init (ref args);
    Test.add_func ("/live/join-and-edit", test_join_and_edit);
    Test.add_func ("/live/undo-keeps-remote", test_undo_keeps_remote);
    Test.add_func ("/live/session", test_session);
    Test.add_func ("/live/secure-session", test_secure_session);
    Test.add_func ("/live/wrong-fingerprint", test_wrong_fingerprint);
    return Test.run ();
}
