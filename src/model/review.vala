namespace Singularity.Apps.Draw {

    public class Comment {
        public string id = "";
        public string author = "";
        public string initials = "";
        public int64 time = 0;
        public string text = "";
        public string item_id = "";
        public double x = 0;
        public double y = 0;
        public bool resolved = false;
        public Gee.ArrayList<Comment> replies = new Gee.ArrayList<Comment> ();

        public Comment copy () {
            var c = new Comment ();
            c.id = id;
            c.author = author;
            c.initials = initials;
            c.time = time;
            c.text = text;
            c.item_id = item_id;
            c.x = x;
            c.y = y;
            c.resolved = resolved;
            foreach (var r in replies) c.replies.add (r.copy ());
            return c;
        }

        public static string author_name = "";

        public static string current_author () {
            if (author_name.strip () != "") return author_name.strip ();
            string n = Environment.get_real_name ();
            if (n == null || n == "" || n == "Unknown") n = Environment.get_user_name ();
            return n;
        }

        public static string initials_of (string name) {
            var sb = new StringBuilder ();
            foreach (string part in name.split (" ")) {
                string p = part.strip ();
                if (p == "") continue;
                sb.append_unichar (p.get_char (0).toupper ());
                if (sb.str.char_count () >= 2) break;
            }
            return sb.str;
        }

        public static Comment create (string text) {
            var c = new Comment ();
            c.author = current_author ();
            c.initials = initials_of (c.author);
            c.time = new DateTime.now_utc ().to_unix ();
            c.text = text;
            return c;
        }

        public Comment? find (string cid) {
            if (id == cid) return this;
            foreach (var r in replies) {
                var f = r.find (cid);
                if (f != null) return f;
            }
            return null;
        }
    }
}
