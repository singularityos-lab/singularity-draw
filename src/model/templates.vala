namespace Singularity.Apps.Draw {

    public class TemplateInfo {
        public string id;
        public string name;
        public string description;

        public TemplateInfo (string id, string name, string description) {
            this.id = id;
            this.name = name;
            this.description = description;
        }
    }

    public class Templates {
        public static Gee.ArrayList<TemplateInfo> list () {
            var l = new Gee.ArrayList<TemplateInfo> ();
            l.add (new TemplateInfo ("flowchart", _("Flowchart"), _("Steps, decisions and outcomes of a process")));
            l.add (new TemplateInfo ("swimlanes", _("Cross-Functional Flowchart"), _("A process split into lanes by team")));
            l.add (new TemplateInfo ("org", _("Org Chart"), _("Teams and reporting lines")));
            l.add (new TemplateInfo ("network", _("Network Diagram"), _("Devices, servers and connections")));
            l.add (new TemplateInfo ("uml", _("UML Class Diagram"), _("Classes, interfaces and relations")));
            l.add (new TemplateInfo ("bpmn", _("BPMN Process"), _("Events, tasks and gateways in a pool")));
            l.add (new TemplateInfo ("mindmap", _("Mind Map"), _("Ideas branching from a central topic")));
            l.add (new TemplateInfo ("er", _("Database Diagram"), _("Tables and their relationships")));
            l.add (new TemplateInfo ("sequence", _("Sequence Diagram"), _("Messages between participants over time")));
            l.add (new TemplateInfo ("cff-vertical", _("Vertical Cross-Functional Flowchart"), _("A process with functions as columns and phases as rows")));
            l.add (new TemplateInfo ("cloud-aws", _("AWS Style Architecture"), _("A web application in a region with two availability zones")));
            l.add (new TemplateInfo ("cloud-azure", _("Azure Style Architecture"), _("An app service with database, cache and monitoring")));
            l.add (new TemplateInfo ("cloud-gcp", _("Google Cloud Style Architecture"), _("A data pipeline from ingestion to analytics")));
            l.add (new TemplateInfo ("network-detail", _("Detailed Network"), _("Branch office, datacenter and internet links")));
            l.add (new TemplateInfo ("rack", _("Rack Diagram"), _("Servers, switches and power in a 42U rack")));
            l.add (new TemplateInfo ("floor-plan", _("Office Floor Plan"), _("Rooms, doors and furniture at 1:50 scale")));
            l.add (new TemplateInfo ("circuit", _("Electrical Circuit"), _("A powered LED circuit with a switch")));
            l.add (new TemplateInfo ("logic", _("Logic Circuit"), _("Gates wired into a half adder")));
            l.add (new TemplateInfo ("pid", _("Process and Instrumentation"), _("Tank, pump, valves and instruments")));
            l.add (new TemplateInfo ("wireframe", _("Wireframe"), _("A sign-in screen mockup")));
            l.add (new TemplateInfo ("fault-tree", _("Fault Tree"), _("Events combined through logic gates")));
            l.add (new TemplateInfo ("gantt", _("Project Schedule"), _("Tasks, durations and dependencies on a timeline")));
            return l;
        }

        private static Shape add (Document d, string kind, double x, double y, string text, string? fill = null, double w = 0, double h = 0) {
            var e = ShapeLibrary.find (kind);
            var s = new Shape (kind, x, y, w > 0 ? w : (e != null ? e.w : 120), h > 0 ? h : (e != null ? e.h : 60));
            ShapeLibrary.apply_defaults (s);
            s.text = text;
            if (fill != null) s.style.fill = fill;
            d.add_item (s);
            return s;
        }

        private static Connector link (Document d, Item a, Item b, string label = "", RouteKind route = RouteKind.ORTHOGONAL, int src_port = -1, int dst_port = -1) {
            var c = new Connector ();
            c.src.item_id = a.id;
            c.dst.item_id = b.id;
            c.src.port = src_port;
            c.dst.port = dst_port;
            c.route = route;
            c.text = label;
            c.style.stroke = "#4a5561";
            d.add_item (c);
            return c;
        }

        private static Document finish (Document d, string title) {
            d.title = title;
            foreach (var p in d.pages) Router.route_all (p);
            d.modified = false;
            d.clear_history ();
            return d;
        }

        public static Document build (string id) {
            switch (id) {
                case "flowchart": return flowchart ();
                case "swimlanes": return swimlanes ();
                case "org": return org ();
                case "network": return network ();
                case "uml": return uml ();
                case "bpmn": return bpmn ();
                case "mindmap": return mindmap ();
                case "er": return er ();
                case "sequence": return sequence ();
                case "cff-vertical": return cff_vertical ();
                case "cloud-aws": return cloud ("aws-");
                case "cloud-azure": return cloud ("az-");
                case "cloud-gcp": return cloud_pipeline ();
                case "network-detail": return network_detail ();
                case "rack": return rack ();
                case "floor-plan": return floor_plan ();
                case "circuit": return circuit ();
                case "logic": return logic ();
                case "pid": return pid ();
                case "wireframe": return wireframe ();
                case "fault-tree": return fault_tree ();
                case "gantt": return gantt ();
                default: return new Document ();
            }
        }

        public static Document flowchart () {
            var d = new Document ();
            var start = add (d, "terminator", 380, 40, _("Order received"), "#d7f0e0");
            var check = add (d, "process", 380, 130, _("Check stock"));
            var dec = add (d, "decision", 380, 230, _("In stock?"), "#fff1cc", 120, 90);
            var ship = add (d, "process", 380, 370, _("Pack and ship"));
            var inv = add (d, "document", 380, 470, _("Send invoice"));
            var end = add (d, "terminator", 380, 580, _("Done"), "#d7f0e0");
            var order = add (d, "process", 620, 245, _("Order from supplier"));
            var wait = add (d, "delay", 630, 360, _("Wait for delivery"), null, 100, 60);
            var db = add (d, "database", 170, 120, _("Inventory"), "#e6e0f5", 100, 90);
            link (d, start, check);
            link (d, check, dec);
            link (d, dec, ship, _("Yes"));
            link (d, dec, order, _("No"));
            link (d, order, wait);
            link (d, wait, ship, "", RouteKind.ORTHOGONAL, 3, 1);
            link (d, ship, inv);
            link (d, inv, end);
            var q = link (d, check, db);
            q.style.dash = DashKind.DASH;
            q.style.arrow_end = ArrowKind.OPEN;
            var title = add (d, "text", 60, 30, _("Order Fulfilment"), null, 260, 40);
            title.style.font_size = 20;
            title.style.bold = true;
            title.style.halign = TextHAlign.LEFT;
            return finish (d, _("Flowchart"));
        }

        public static Document swimlanes () {
            var d = new Document ();
            add (d, "pool", 40, 40, _("Customer Support"), null, 1000, 480);
            string[] lanes = { _("Customer"), _("Support"), _("Engineering") };
            string[] fills = { "#eef5fc", "#f1f8ee", "#fdf4e8" };
            for (int i = 0; i < 3; i++) {
                var lane = add (d, "swimlane-h", 70, 40 + i * 160, lanes[i], fills[i], 970, 160);
                lane.style.bold = false;
            }
            var a = add (d, "terminator", 130, 95, _("Report issue"), "#d7f0e0");
            var b = add (d, "process", 330, 250, _("Triage ticket"));
            var c = add (d, "decision", 530, 240, _("Bug?"), "#fff1cc", 110, 80);
            var e = add (d, "process", 700, 410, _("Fix and release"));
            var f = add (d, "process", 700, 250, _("Answer customer"));
            var g = add (d, "terminator", 880, 95, _("Issue closed"), "#d7f0e0");
            link (d, a, b);
            link (d, b, c);
            link (d, c, e, _("Yes"));
            link (d, c, f, _("No"));
            link (d, e, f);
            link (d, f, g);
            d.page.width = 1122.52;
            return finish (d, _("Cross-Functional Flowchart"));
        }

        public static Document org () {
            var d = new Document ();
            var ceo = add (d, "org-manager", 0, 0, _("Ada Rossi\nChief Executive"));
            var asst = add (d, "org-assistant", 0, 0, _("Luca Bianchi\nExecutive Assistant"));
            string[] heads = { _("Sara Conti\nEngineering"), _("Marco Galli\nSales"), _("Giulia Ferri\nOperations") };
            string[,] staff = {
                { _("Paolo Neri\nBackend"), _("Elena Riva\nFrontend") },
                { _("Anna Costa\nAccounts"), _("Diego Serra\nPartners") },
                { _("Irene Fontana\nLogistics"), _("Omar Villa\nFacilities") }
            };
            var items = new Gee.ArrayList<Item> ();
            items.add (ceo);
            for (int i = 0; i < 3; i++) {
                var h = add (d, "org-person", 0, 0, heads[i]);
                items.add (h);
                var l = link (d, ceo, h, "", RouteKind.ORTHOGONAL, 2, 0);
                l.style.arrow_end = ArrowKind.NONE;
                for (int j = 0; j < 2; j++) {
                    var s = add (d, "org-person", 0, 0, staff[i, j]);
                    s.style.fill = "#f7f9fb";
                    items.add (s);
                    var sl = link (d, h, s, "", RouteKind.ORTHOGONAL, 2, 0);
                    sl.style.arrow_end = ArrowKind.NONE;
                }
            }
            foreach (var it in items) {
                var s = it as Shape;
                s.x = 200;
                s.y = 80;
                s.w = 160;
                s.h = 56;
                s.style.font_size = 10;
            }
            AutoLayout.apply (d.page, items, LayoutKind.TREE_DOWN, 20, 50);
            var cb = Document.selection_bounds (items);
            double dx = (d.page.width - cb.w) / 2 - cb.x, dy = 60 - cb.y;
            d.move_items (items, dx, dy);
            asst.w = 160;
            asst.h = 50;
            asst.style.font_size = 10;
            asst.x = ceo.x + ceo.w + 60;
            asst.y = ceo.y + 3;
            var al = link (d, ceo, asst, "", RouteKind.ORTHOGONAL, 1, 3);
            al.style.arrow_end = ArrowKind.NONE;
            al.style.dash = DashKind.DASH;
            cb = Document.selection_bounds (d.page.items);
            if (cb.x2 () + 40 > d.page.width) d.page.width = cb.x2 () + 40;
            return finish (d, _("Org Chart"));
        }

        public static Document network () {
            var d = new Document ();
            var cloud = add (d, "net-cloud", 460, 30, _("Internet"), null, 150, 90);
            var fw = add (d, "net-firewall", 500, 170, _("Firewall"));
            var router = add (d, "net-router", 500, 280, _("Router"));
            var sw = add (d, "net-switch", 490, 390, _("Core Switch"));
            var web = add (d, "net-server", 220, 500, _("Web Server"));
            var dbs = add (d, "net-database", 330, 500, _("Database"));
            var nas = add (d, "net-storage", 440, 500, _("Storage"));
            var pc1 = add (d, "net-desktop", 600, 505, _("Office PC"));
            var lap = add (d, "net-laptop", 720, 510, _("Laptop"));
            var ap = add (d, "net-wireless", 850, 390, _("Wi-Fi"));
            var ph = add (d, "net-phone", 870, 520, _("Phone"));
            var pr = add (d, "net-printer", 820, 250, _("Printer"));
            var dmz = add (d, "container", 190, 470, _("Server Room"), "#f3f6f9", 330, 150);
            d.page.items.remove (dmz);
            d.page.items.insert (0, dmz);
            foreach (var s in new Shape[] { web, dbs, nas }) s.container_id = dmz.id;
            Shape[] from = { cloud, fw, router, sw, sw, sw, sw, sw, sw, ap, sw };
            Shape[] to = { fw, router, sw, web, dbs, nas, pc1, lap, ap, ph, pr };
            for (int i = 0; i < from.length; i++) {
                var c = link (d, from[i], to[i], "", RouteKind.STRAIGHT);
                c.style.arrow_end = ArrowKind.NONE;
                c.style.stroke = "#2f5f8f";
                c.style.stroke_width = 2;
                if (to[i] == ph) c.style.dash = DashKind.DASH;
            }
            return finish (d, _("Network Diagram"));
        }

        public static Document uml () {
            var d = new Document ();
            var shape = add (d, "uml-interface", 420, 40, "«interface»\nShape\n--\n+ area(): double\n+ draw(canvas: Canvas)", "#eef5fc", 200, 100);
            var circle = add (d, "uml-class", 220, 240, "Circle\n--\n- radius: double\n--\n+ area(): double", "#ffffff", 180, 110);
            var rect = add (d, "uml-class", 460, 240, "Rectangle\n--\n- width: double\n- height: double\n--\n+ area(): double", "#ffffff", 180, 130);
            var square = add (d, "uml-class", 460, 440, "Square\n--\n+ Square(side: double)", "#ffffff", 180, 80);
            var canvas = add (d, "uml-class", 760, 40, "Canvas\n--\n- shapes: List<Shape>\n--\n+ add(s: Shape)\n+ render()", "#ffffff", 200, 120);
            var note = add (d, "uml-note", 760, 260, _("Shapes are drawn in the order they were added."), null, 190, 70);
            var r1 = link (d, circle, shape);
            r1.style.arrow_end = ArrowKind.TRIANGLE_OPEN;
            r1.style.dash = DashKind.DASH;
            var r2 = link (d, rect, shape);
            r2.style.arrow_end = ArrowKind.TRIANGLE_OPEN;
            r2.style.dash = DashKind.DASH;
            var r3 = link (d, square, rect);
            r3.style.arrow_end = ArrowKind.TRIANGLE_OPEN;
            var r4 = link (d, canvas, shape, "0..*");
            r4.style.arrow_start = ArrowKind.DIAMOND_OPEN;
            r4.style.arrow_end = ArrowKind.OPEN;
            var r5 = link (d, note, canvas, "", RouteKind.STRAIGHT);
            r5.style.dash = DashKind.DOT;
            r5.style.arrow_end = ArrowKind.NONE;
            return finish (d, _("UML Class Diagram"));
        }

        public static Document bpmn () {
            var d = new Document ();
            add (d, "bpmn-pool", 40, 60, _("Online Shop"), "#f7f9fb", 1020, 260);
            var start = add (d, "bpmn-start", 110, 170, _("Order placed"));
            var t1 = add (d, "bpmn-task", 200, 150, _("Check payment"), "#eef5fc");
            var gw = add (d, "bpmn-gateway", 370, 165, _("Paid?"));
            var t2 = add (d, "bpmn-task", 480, 150, _("Prepare parcel"), "#eef5fc");
            var t3 = add (d, "bpmn-subprocess", 480, 240, _("Send reminder"), "#fdf4e8", 120, 64);
            var timer = add (d, "bpmn-timer", 660, 256, _("3 days"));
            var t4 = add (d, "bpmn-task", 650, 150, _("Ship order"), "#eef5fc");
            var msg = add (d, "bpmn-message", 830, 170, _("Notify customer"));
            var end = add (d, "bpmn-end", 950, 170, _("Order done"));
            var store = add (d, "bpmn-data-store", 220, 20, _("Orders"));
            d.page.items.remove (store);
            d.page.items.add (store);
            store.y = 250;
            link (d, start, t1);
            link (d, t1, gw);
            link (d, gw, t2, _("Yes"));
            link (d, gw, t3, _("No"), RouteKind.ORTHOGONAL, 2, 3);
            link (d, t3, timer);
            link (d, timer, t1, "", RouteKind.ORTHOGONAL, 2, 2);
            link (d, t2, t4);
            link (d, t4, msg);
            link (d, msg, end);
            var assoc = link (d, t1, store, "", RouteKind.STRAIGHT);
            assoc.style.dash = DashKind.DOT;
            assoc.style.arrow_end = ArrowKind.NONE;
            return finish (d, _("BPMN Process"));
        }

        public static Document mindmap () {
            var d = new Document ();
            var center = add (d, "ellipse", 470, 330, _("Product Launch"), "#3a6ea5", 190, 90);
            center.style.text_color = "#ffffff";
            center.style.bold = true;
            center.style.font_size = 15;
            center.style.stroke = "#2a5585";
            string[] topics = { _("Marketing"), _("Design"), _("Engineering"), _("Support"), _("Sales"), _("Legal") };
            string[] colors = { "#e8f3e0", "#fdebd9", "#e3eefb", "#f4e3f4", "#fff4cc", "#e6e6e6" };
            string[] strokes = { "#5b9a3b", "#d9822b", "#3a6ea5", "#9b4f9b", "#c9a227", "#777777" };
            string[,] leaves = {
                { _("Campaign"), _("Press kit") }, { _("Brand"), _("Website") }, { _("Beta"), _("Release") },
                { _("FAQ"), _("Training") }, { _("Pricing"), _("Partners") }, { _("Terms"), _("Privacy") }
            };
            for (int i = 0; i < topics.length; i++) {
                double a = -Math.PI / 2 + i * 2 * Math.PI / topics.length;
                double tx = 565 + Math.cos (a) * 290 - 70, ty = 375 + Math.sin (a) * 220 - 24;
                var t = add (d, "rounded-rectangle", tx, ty, topics[i], colors[i], 140, 48);
                t.style.stroke = strokes[i];
                t.style.corner_radius = 24;
                t.style.bold = true;
                var c = link (d, center, t, "", RouteKind.CURVED);
                c.style.arrow_end = ArrowKind.NONE;
                c.style.stroke = strokes[i];
                c.style.stroke_width = 3;
                for (int j = 0; j < 2; j++) {
                    double b = a + (j == 0 ? -0.28 : 0.28);
                    double lx = 565 + Math.cos (b) * 440 - 50, ly = 375 + Math.sin (b) * 320 - 16;
                    var leaf = add (d, "rounded-rectangle", lx, ly, leaves[i, j], "#ffffff", 100, 32);
                    leaf.style.stroke = strokes[i];
                    leaf.style.corner_radius = 16;
                    var lc = link (d, t, leaf, "", RouteKind.CURVED);
                    lc.style.arrow_end = ArrowKind.NONE;
                    lc.style.stroke = strokes[i];
                }
            }
            d.page.width = 1122.52;
            d.page.height = 793.7;
            var all = new Gee.ArrayList<Item> ();
            all.add_all (d.page.items);
            var b0 = Document.selection_bounds (all);
            d.move_items (all, (d.page.width - b0.w) / 2 - b0.x, (d.page.height - b0.h) / 2 - b0.y);
            return finish (d, _("Mind Map"));
        }

        private static TableShape table (Document d, double x, double y, string title, string[] rows) {
            var t = new TableShape (rows.length + 1, 2);
            t.x = x;
            t.y = y;
            t.w = 220;
            t.h = 26 * (rows.length + 1);
            t.set_cell (0, 0, title);
            t.set_cell (0, 1, "");
            for (int i = 0; i < rows.length; i++) {
                string[] parts = rows[i].split (" ", 2);
                t.set_cell (i + 1, 0, parts[0]);
                t.set_cell (i + 1, 1, parts.length > 1 ? parts[1] : "");
            }
            t.col_fracs = { 0.55, 0.45 };
            t.header_fill = "#cfe0f3";
            t.style.text_color = "#1e1e1e";
            d.add_item (t);
            return t;
        }

        public static Document er () {
            var d = new Document ();
            var cust = table (d, 80, 80, "customer", { "id INTEGER", "name TEXT", "email TEXT" });
            var ord = table (d, 420, 80, "order", { "id INTEGER", "customer_id INTEGER", "created DATE", "total DECIMAL" });
            var item = table (d, 420, 330, "order_item", { "order_id INTEGER", "product_id INTEGER", "quantity INTEGER" });
            var prod = table (d, 760, 330, "product", { "id INTEGER", "name TEXT", "price DECIMAL" });
            foreach (var t in new TableShape[] { cust, ord, item, prod }) {
                t.style.bold = false;
            }
            var r1 = link (d, cust, ord);
            r1.style.arrow_start = ArrowKind.ONE;
            r1.style.arrow_end = ArrowKind.CROWS_FOOT;
            var r2 = link (d, ord, item);
            r2.style.arrow_start = ArrowKind.ONE;
            r2.style.arrow_end = ArrowKind.CROWS_FOOT;
            var r3 = link (d, prod, item);
            r3.style.arrow_start = ArrowKind.ONE;
            r3.style.arrow_end = ArrowKind.CROWS_FOOT;
            return finish (d, _("Database Diagram"));
        }

        public static Document sequence () {
            var d = new Document ();
            string[] names = { ":Browser", ":Web Server", ":Auth Service", ":Database" };
            var lines = new Gee.ArrayList<Shape> ();
            for (int i = 0; i < names.length; i++) {
                var l = add (d, "uml-lifeline", 90 + i * 230, 40, names[i], "#eef5fc", 130, 520);
                lines.add (l);
            }
            string[] msgs = { _("POST /login"), _("verify(user, password)"), _("SELECT user"), _("row"), _("token"), _("200 OK") };
            int[] from = { 0, 1, 2, 3, 2, 1 };
            int[] to = { 1, 2, 3, 2, 1, 0 };
            for (int i = 0; i < msgs.length; i++) {
                double y = 130 + i * 60;
                var a = lines[from[i]];
                var b = lines[to[i]];
                var c = new Connector ();
                c.route = RouteKind.STRAIGHT;
                c.src.x = a.cx ();
                c.src.y = y;
                c.dst.x = b.cx ();
                c.dst.y = y;
                c.text = msgs[i];
                c.style.stroke = "#4a5561";
                if (i >= 3) {
                    c.style.dash = DashKind.DASH;
                    c.style.arrow_end = ArrowKind.OPEN;
                }
                d.add_item (c);
            }
            for (int i = 1; i < 4; i++) {
                var act = add (d, "uml-activation", lines[i].cx () - 7, 120 + (i - 1) * 60, "", "#ffffff", 14, 60 * (7 - 2 * i) + 20);
                act.y = 120 + (i - 1) * 60;
            }
            return finish (d, _("Sequence Diagram"));
        }

        private static Shape put (Document d, string kind, double x, double y, string text) {
            var e = ShapeLibrary.find (kind);
            return add (d, kind, x, y, text, null, e != null ? e.w : 0, e != null ? e.h : 0);
        }

        private static void to_back (Document d, Shape s) {
            d.page.items.remove (s);
            d.page.items.insert (0, s);
        }

        private static void contain (Document d, Shape box, Shape[] members) {
            foreach (var m in members) m.container_id = box.id;
        }

        public static Document cff_vertical () {
            var d = new Document ();
            var pool = Swimlanes.insert (d, 60, 40, true, 3, _("Hiring"));
            var ls = Swimlanes.lanes (d.page, pool);
            string[] names = { _("Manager"), _("Recruiting"), _("Candidate") };
            for (int i = 0; i < 3; i++) ls[i].text = names[i];
            Swimlanes.add_phase (d, pool, _("Selection"));
            var ph = Swimlanes.phases (d.page, pool);
            if (ph.size > 0) ph[0].text = _("Request");
            var a = put (d, "terminator", ls[0].x + 50, pool.y + 90, _("Need a role"));
            var b = put (d, "process", ls[1].x + 50, pool.y + 190, _("Publish job"));
            var c = put (d, "process", ls[2].x + 50, pool.y + 300, _("Apply"));
            var e = put (d, "decision", ls[1].x + 50, pool.y + 430, _("Good fit?"));
            var f = put (d, "terminator", ls[0].x + 50, pool.y + 580, _("Hire"));
            foreach (var s in new Shape[] { a, b, c, e, f }) d.assign_container (s);
            link (d, a, b);
            link (d, b, c);
            link (d, c, e);
            link (d, e, f, _("Yes"));
            d.page.width = double.max (d.page.width, pool.x + pool.w + 60);
            d.page.height = double.max (d.page.height, pool.y + pool.h + 60);
            return finish (d, _("Vertical Cross-Functional Flowchart"));
        }

        public static Document cloud (string p) {
            var d = new Document ();
            var region = put (d, p + "region", 40, 40, _("Region"));
            region.w = 1000;
            region.h = 620;
            var vpc = put (d, p + "vpc", 220, 90, _("Virtual Network"));
            vpc.w = 800;
            vpc.h = 540;
            var za = put (d, p + "zone", 250, 140, _("Zone A"));
            za.w = 360;
            za.h = 460;
            var zb = put (d, p + "zone", 630, 140, _("Zone B"));
            zb.w = 360;
            zb.h = 460;
            var user = put (d, p + "user", 80, 110, _("Users"));
            var cdn = put (d, p + "cdn", 80, 260, _("CDN"));
            var dns = put (d, p + "dns", 80, 420, _("DNS"));
            var lb = put (d, p + "load-balancer", 590, 170, _("Load Balancer"));
            var app1 = put (d, p + "vm", 390, 300, _("App Server"));
            var app2 = put (d, p + "vm", 770, 300, _("App Server"));
            var db1 = put (d, p + "sql-db", 390, 450, _("Primary Database"));
            var db2 = put (d, p + "sql-db", 770, 450, _("Replica"));
            var bucket = put (d, p + "object-storage", 80, 560, _("Static Files"));
            var mon = put (d, p + "monitoring", 880, 60, _("Monitoring"));
            contain (d, region, { vpc, cdn, dns, bucket, mon });
            contain (d, vpc, { za, zb, lb });
            contain (d, za, { app1, db1 });
            contain (d, zb, { app2, db2 });
            to_back (d, za);
            to_back (d, zb);
            to_back (d, vpc);
            to_back (d, region);
            link (d, user, cdn);
            link (d, cdn, lb);
            link (d, lb, app1);
            link (d, lb, app2);
            link (d, app1, db1);
            link (d, app2, db2);
            var rep = link (d, db1, db2, _("replication"));
            rep.style.dash = DashKind.DASH;
            link (d, cdn, bucket);
            d.page.width = 1122.52;
            d.page.height = 740;
            return finish (d, _("Cloud Architecture"));
        }

        public static Document cloud_pipeline () {
            var d = new Document ();
            string p = "gcp-";
            string[] kinds = { "iot-device", "pubsub", "function", "etl", "data-lake", "warehouse", "analytics" };
            string[] names = { _("Devices"), _("Ingestion Topic"), _("Validate"), _("Transform"), _("Raw Data"), _("Warehouse"), _("Dashboards") };
            Shape? prev = null;
            Shape? store = null;
            var project = put (d, p + "vpc", 180, 120, _("Project"));
            project.w = 860;
            project.h = 300;
            for (int i = 0; i < kinds.length; i++) {
                var s = put (d, p + kinds[i], 60 + i * 150, 220, names[i]);
                if (i > 0) s.container_id = project.id;
                if (prev != null) link (d, prev, s);
                if (i == 5) store = s;
                prev = s;
            }
            to_back (d, project);
            var ml = put (d, p + "ml", 810, 470, _("Forecast Model"));
            if (store != null) link (d, store, ml);
            return finish (d, _("Data Pipeline"));
        }

        public static Document network_detail () {
            var d = new Document ();
            var inet = put (d, "net2-internet-globe", 500, 40, _("Internet"));
            var dc = add (d, "container", 40, 200, _("Datacenter"), "#f3f6f9", 560, 400);
            var br = add (d, "container", 660, 200, _("Branch Office"), "#f6f3f9", 420, 400);
            var fw = put (d, "net2-firewall-box", 290, 240, _("Firewall"));
            var core = put (d, "net2-switch-core", 280, 340, _("Core Switch"));
            var web = put (d, "net2-server-web", 80, 470, _("Web"));
            var app = put (d, "net2-server-app", 200, 470, _("App"));
            var db = put (d, "net2-server-db", 320, 470, _("Database"));
            var san = put (d, "net2-san", 460, 470, _("SAN"));
            var vpn = put (d, "net2-vpn", 840, 240, _("VPN Gateway"));
            var sw = put (d, "net2-switch-l2", 840, 340, _("Access Switch"));
            var ws = put (d, "net2-workstation", 700, 470, _("Workstations"));
            var ph = put (d, "net2-ip-phone", 840, 470, _("IP Phones"));
            var ap = put (d, "net2-access-point", 960, 470, _("Wi-Fi"));
            contain (d, dc, { fw, core, web, app, db, san });
            contain (d, br, { vpn, sw, ws, ph, ap });
            to_back (d, br);
            to_back (d, dc);
            link (d, inet, fw);
            var tunnel = link (d, inet, vpn, _("site-to-site VPN"));
            tunnel.style.dash = DashKind.DASH;
            link (d, fw, core);
            foreach (var s in new Shape[] { web, app, db, san }) link (d, core, s);
            link (d, vpn, sw);
            foreach (var s in new Shape[] { ws, ph, ap }) link (d, sw, s);
            return finish (d, _("Detailed Network"));
        }

        public static Document rack () {
            var d = new Document ();
            d.page.width = 793.7;
            d.page.height = 1122.52;
            var r = put (d, "rack-42u", 300, 60, _("Rack A01"));
            string[] kinds = { "rack-patch-24", "rack-switch-1u", "rack-switch-1u", "rack-cable-manager", "rack-firewall-1u", "rack-router-1u", "rack-blank-1u", "rack-server-2u", "rack-server-2u", "rack-server-1u", "rack-server-1u", "rack-storage-4u", "rack-blank-2u", "rack-kvm", "rack-ups-2u" };
            string[] names = { _("Patch Panel"), _("Switch 1"), _("Switch 2"), "", _("Firewall"), _("Router"), "", _("Hypervisor 1"), _("Hypervisor 2"), _("Web 1"), _("Web 2"), _("Storage Array"), "", _("KVM"), _("UPS") };
            double y = r.y + 30;
            double inner = r.w * 0.84;
            foreach (int i in new int[] { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 }) {
                var e = ShapeLibrary.find (kinds[i]);
                if (e == null) continue;
                var s = put (d, kinds[i], r.x + (r.w - inner) / 2, y, names[i]);
                s.w = inner;
                y += s.h;
                s.container_id = r.id;
            }
            var pdu = put (d, "rack-pdu-vertical", r.x + r.w + 20, r.y + 30, _("PDU"));
            pdu.h = double.max (pdu.h, r.h - 60);
            return finish (d, _("Rack Diagram"));
        }

        public static Document floor_plan () {
            var d = new Document ();
            var pg = d.page;
            pg.scale_paper = 1;
            pg.scale_paper_units = "cm";
            pg.scale_world = 0.5;
            pg.scale_units = "m";
            double m = pg.from_world (1);
            var room = put (d, "fp-room", 60, 60, _("Open Office"));
            room.w = 12 * m;
            room.h = 7 * m;
            var meet = put (d, "fp-room", 60 + 12 * m, 60, _("Meeting Room"));
            meet.w = 5 * m;
            meet.h = 7 * m;
            var door = put (d, "fp-door", 60 + 5 * m, 60 + 7 * m - 0.2 * m, "");
            door.w = 0.9 * m;
            door.h = 0.9 * m;
            var mdoor = put (d, "fp-door", 60 + 12 * m - 0.45 * m, 60 + 3 * m, "");
            mdoor.w = 0.9 * m;
            mdoor.h = 0.9 * m;
            mdoor.rotation = 90;
            for (int i = 0; i < 4; i++) {
                for (int j = 0; j < 2; j++) {
                    var desk = put (d, "fp-desk", 60 + (1 + i * 2.7) * m, 60 + (1 + j * 3) * m, "");
                    desk.w = 1.6 * m;
                    desk.h = 0.8 * m;
                    var ch = put (d, "fp-office-chair", 60 + (1.5 + i * 2.7) * m, 60 + (1.9 + j * 3) * m, "");
                    ch.w = 0.6 * m;
                    ch.h = 0.6 * m;
                }
            }
            var table = put (d, "fp-conference", 60 + 13 * m, 60 + 2 * m, "");
            table.w = 3 * m;
            table.h = 1.4 * m;
            var plant = put (d, "fp-plant", 60 + 11 * m, 60 + 6 * m, "");
            plant.w = 0.6 * m;
            plant.h = 0.6 * m;
            put (d, "fp-north-arrow", 60 + 17.5 * m, 60 + 7.5 * m, "");
            var dim = put (d, "fp-dimension", 60, 60 + 7.4 * m, _("12 m"));
            dim.w = 12 * m;
            to_back (d, meet);
            to_back (d, room);
            pg.width = double.max (pg.width, 60 + 19 * m);
            return finish (d, _("Office Floor Plan"));
        }

        public static Document circuit () {
            var d = new Document ();
            var bat = put (d, "elec-battery", 120, 260, _("9 V"));
            var sw = put (d, "elec-switch-spst", 300, 120, _("S1"));
            var res = put (d, "elec-resistor-iec", 520, 120, _("470 Ω"));
            var led = put (d, "elec-led", 700, 260, _("LED1"));
            var gnd = put (d, "elec-ground", 420, 420, "");
            var c1 = link (d, bat, sw);
            var c2 = link (d, sw, res);
            var c3 = link (d, res, led);
            var c4 = link (d, led, gnd);
            var c5 = link (d, gnd, bat);
            foreach (var c in new Connector[] { c1, c2, c3, c4, c5 }) {
                c.style.arrow_end = ArrowKind.NONE;
                c.style.stroke = "#1e1e1e";
            }
            return finish (d, _("Electrical Circuit"));
        }

        public static Document logic () {
            var d = new Document ();
            var a = put (d, "elec-terminal", 80, 160, "A");
            var b = put (d, "elec-terminal", 80, 320, "B");
            var xor = put (d, "logic-xor", 300, 140, "");
            var and = put (d, "logic-and", 300, 320, "");
            var s = put (d, "elec-terminal", 560, 160, _("Sum"));
            var c = put (d, "elec-terminal", 560, 340, _("Carry"));
            foreach (var pair in new Shape[] { a, b }) {
                var l1 = link (d, pair, xor);
                var l2 = link (d, pair, and);
                l1.style.arrow_end = ArrowKind.NONE;
                l2.style.arrow_end = ArrowKind.NONE;
            }
            link (d, xor, s).style.arrow_end = ArrowKind.NONE;
            link (d, and, c).style.arrow_end = ArrowKind.NONE;
            return finish (d, _("Half Adder"));
        }

        public static Document pid () {
            var d = new Document ();
            var tank = put (d, "pid-tank-vertical", 100, 140, _("T-101"));
            var v1 = put (d, "pid-gate-valve", 300, 330, "");
            var pump = put (d, "pid-pump", 440, 310, _("P-101"));
            var fv = put (d, "pid-control-valve", 620, 320, _("FV-101"));
            var hx = put (d, "pid-hx-shell", 780, 300, _("E-101"));
            var ft = put (d, "pid-flow-transmitter", 560, 170, _("FT"));
            var fic = put (d, "pid-instrument-dcs", 700, 110, _("FIC"));
            var lt = put (d, "pid-level-transmitter", 240, 120, _("LT"));
            link (d, tank, v1);
            link (d, v1, pump);
            link (d, pump, fv);
            link (d, fv, hx);
            foreach (var c in new Connector[] { link (d, ft, fic), link (d, fic, fv), link (d, lt, tank) }) {
                c.style.dash = DashKind.DASH;
                c.style.arrow_end = ArrowKind.NONE;
            }
            return finish (d, _("Process and Instrumentation"));
        }

        public static Document wireframe () {
            var d = new Document ();
            var win = put (d, "ui-browser", 200, 40, _("Sign In"));
            win.w = 720;
            win.h = 520;
            var head = put (d, "ui-heading", 420, 140, _("Welcome back"));
            var user = put (d, "ui-text-field", 420, 210, _("Email"));
            var pass = put (d, "ui-text-field", 420, 270, _("Password"));
            var rem = put (d, "ui-checkbox", 420, 330, _("Remember me"));
            var btn = put (d, "ui-button", 420, 380, _("Sign In"));
            var lnk = put (d, "ui-link", 420, 440, _("Forgot password?"));
            foreach (var s in new Shape[] { head, user, pass, rem, btn, lnk }) s.container_id = win.id;
            to_back (d, win);
            return finish (d, _("Wireframe"));
        }

        public static Document fault_tree () {
            var d = new Document ();
            var top = put (d, "ft-intermediate", 420, 40, _("Server outage"));
            var or = put (d, "ft-or", 460, 150, "");
            var power = put (d, "ft-intermediate", 220, 250, _("Power lost"));
            var hw = put (d, "ft-basic", 640, 250, _("Disk failure"));
            var and = put (d, "ft-and", 260, 360, "");
            var grid = put (d, "ft-basic", 120, 460, _("Grid failure"));
            var ups = put (d, "ft-basic", 360, 460, _("UPS failure"));
            link (d, top, or).style.arrow_end = ArrowKind.NONE;
            link (d, or, power).style.arrow_end = ArrowKind.NONE;
            link (d, or, hw).style.arrow_end = ArrowKind.NONE;
            link (d, power, and).style.arrow_end = ArrowKind.NONE;
            link (d, and, grid).style.arrow_end = ArrowKind.NONE;
            link (d, and, ups).style.arrow_end = ArrowKind.NONE;
            return finish (d, _("Fault Tree"));
        }

        public static Document gantt () {
            var d = new Document ();
            var g = GanttShape.sample ();
            g.x = 60;
            g.y = 80;
            g.w = 980;
            d.add_item (g);
            var title = add (d, "text", 60, 30, _("Project Schedule"), null, 400, 36);
            title.style.font_size = 18;
            title.style.bold = true;
            title.style.halign = TextHAlign.LEFT;
            return finish (d, _("Project Schedule"));
        }
    }
}
