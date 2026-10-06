namespace Singularity.Apps.Draw {

    public class StencilsPlans {
        private const double PLAN = 0.756;
        private const double SITE = 0.189;
        private const string FURNITURE = "fill:#ffffff;stroke:#333333;stroke-width:1";
        private const string WALL = "fill:#4a4a4a;stroke:#2b2b2b;stroke-width:1";

        private static TechPen pen () {
            return new TechPen ();
        }

        private static unowned StencilDef fp (string kind, string name, double w, double h, string kw, double factor = PLAN, string style = FURNITURE) {
            return Stencils.shape (kind, name, Math.round (w * factor), Math.round (h * factor), kw)
                .box (w, h)
                .defaults (style)
                .real_size ("%sx%scm".printf (PathData.fmt (w, 0), PathData.fmt (h, 0)))
                .ports_box ();
        }

        private static string chair (double x, double y, double s, double rot) {
            var p = new TechPen (x - s / 2, y - s / 2, s);
            if (rot == 0) p.round (3, 6, 18, 16, 2).round (3, 2, 18, 5, 1.5);
            else if (rot == 180) p.round (3, 2, 18, 16, 2).round (3, 17, 18, 5, 1.5);
            else if (rot == 90) p.round (2, 3, 16, 18, 2).round (17, 3, 5, 18, 1.5);
            else p.round (6, 3, 16, 18, 2).round (2, 3, 5, 18, 1.5);
            return p.str ();
        }

        private static void bed (string kind, string name, double w) {
            fp (kind, name, w, 200, "bed sleep bedroom")
                .fill (pen ().rect (0, 0, w, 200).str ())
                .shade (pen ().rect (0, 0, w, 14).str ())
                .line (pen ().round (8, 20, w / 2 - 12, 30, 6).round (w / 2 + 4, 20, w / 2 - 12, 30, 6).m (0, 70).l (w, 70).m (0, 70).q (w / 2, 90, w, 70).str ());
        }

        private static void register_floor () {
            Stencils.category ("floor-plan", _("Floor Plan"), "draw-shapes-symbolic", StencilGroup.PLANS);
            fp ("fp-wall", _("Wall Segment"), 300, 20, "wall exterior structure", PLAN, WALL)
                .dark (pen ().rect (0, 0, 300, 20).str ())
                .port (0, 10)
                .port (300, 10);
            fp ("fp-wall-interior", _("Interior Wall"), 300, 10, "wall partition interior", PLAN, WALL)
                .dark (pen ().rect (0, 0, 300, 10).str ())
                .port (0, 5)
                .port (300, 5);
            fp ("fp-room", _("Room"), 400, 300, "room space walls", PLAN, "fill:#ffffff;stroke:#2b2b2b;stroke-width:1;font-size:10")
                .fill (pen ().rect (0, 0, 400, 300).str ())
                .dark (pen ().poly ({ 0, 0, 400, 0, 400, 300, 0, 300, 0, 0, 15, 15, 15, 285, 385, 285, 385, 15, 15, 15 }).str ())
                .label (15, 15, 370, 270)
                .text (_("Room"))
                .as_container ();
            fp ("fp-door", _("Door"), 90, 95, "door swing single hinged")
                .solid (pen ().rect (0, 0, 90, 95).str (), "#ffffff00")
                .line (pen ().line (0, 95, 0, 5).arc (0, 95, 90, -90, 0).line (0, 95, 90, 95).str ())
                .dark (pen ().rect (0, 5, 4, 90).str ());
            fp ("fp-door-double", _("Double Door"), 180, 95, "double door french")
                .solid (pen ().rect (0, 0, 180, 95).str (), "#ffffff00")
                .line (pen ().arc (0, 95, 90, -90, 0).arc (180, 95, 90, 180, 270).line (0, 95, 180, 95).str ())
                .dark (pen ().rect (0, 5, 4, 90).rect (176, 5, 4, 90).str ());
            fp ("fp-door-sliding", _("Sliding Door"), 180, 20, "sliding door patio")
                .fill (pen ().rect (0, 2, 95, 7).str ())
                .fill (pen ().rect (85, 11, 95, 7).str ())
                .line (pen ().line (0, 0, 0, 20).line (180, 0, 180, 20).str ());
            fp ("fp-door-pocket", _("Pocket Door"), 180, 20, "pocket door recessed")
                .dark (pen ().rect (0, 0, 180, 3).rect (0, 17, 180, 3).str ())
                .fill (pen ().rect (40, 7, 90, 6).str ())
                .ink (pen ().line (130, 10, 175, 10).str ());
            fp ("fp-door-bifold", _("Bifold Door"), 90, 40, "bifold folding door closet")
                .line (pen ().poly ({ 0, 40, 20, 5, 45, 40, 70, 5, 90, 40 }, false).str ());
            fp ("fp-opening", _("Opening"), 90, 20, "opening doorway passage")
                .line (pen ().line (0, 0, 0, 20).line (90, 0, 90, 20).str ())
                .ink (pen ().line (0, 10, 90, 10).str (), "#999999");
            fp ("fp-window", _("Window"), 120, 20, "window glazing")
                .fill (pen ().rect (0, 0, 120, 20).str ())
                .line (pen ().line (0, 8, 120, 8).line (0, 12, 120, 12).str ());
            fp ("fp-window-double", _("Double Window"), 240, 20, "double window casement")
                .fill (pen ().rect (0, 0, 240, 20).str ())
                .line (pen ().line (0, 8, 240, 8).line (0, 12, 240, 12).line (120, 0, 120, 20).str ());
            fp ("fp-window-bay", _("Bay Window"), 240, 70, "bay window projecting")
                .fill (pen ().poly ({ 0, 0, 240, 0, 190, 70, 50, 70 }).str ())
                .line (pen ().poly ({ 12, 6, 228, 6, 184, 64, 56, 64 }, false).str ());
            var treads = pen ().rect (0, 0, 100, 300);
            for (int i = 1; i < 12; i++) treads.line (0, i * 25, 100, i * 25);
            fp ("fp-stairs", _("Straight Stairs"), 100, 300, "stairs staircase steps")
                .fill (treads.str ())
                .ink (pen ().arrow (50, 280, 50, 20, 12).str ());
            var l = pen ().poly ({ 0, 0, 200, 0, 200, 200, 100, 200, 100, 100, 0, 100 });
            for (int i = 1; i < 4; i++) l.line (i * 25, 0, i * 25, 100).line (100, 100 + i * 25, 200, 100 + i * 25);
            l.line (100, 0, 100, 100).line (100, 100, 200, 100).line (100, 100, 200, 0);
            fp ("fp-stairs-l", _("L-Shaped Stairs"), 200, 200, "stairs landing l shaped")
                .fill (l.str ());
            var sp = pen ().circle (80, 80, 80).circle (80, 80, 12);
            for (int i = 0; i < 12; i++) {
                double ang = i * Math.PI / 6;
                sp.line (80 + 12 * Math.cos (ang), 80 + 12 * Math.sin (ang), 80 + 80 * Math.cos (ang), 80 + 80 * Math.sin (ang));
            }
            fp ("fp-stairs-spiral", _("Spiral Stairs"), 160, 160, "spiral stairs helical").fill (sp.str ());
            fp ("fp-elevator", _("Elevator"), 180, 180, "elevator lift")
                .fill (pen ().rect (0, 0, 180, 180).str ())
                .line (pen ().line (10, 10, 170, 170).line (170, 10, 10, 170).rect (10, 10, 160, 160).str ());
            fp ("fp-column-round", _("Round Column"), 40, 40, "column pillar round", PLAN, WALL).dark (pen ().circle (20, 20, 20).str ());
            fp ("fp-column-square", _("Square Column"), 40, 40, "column pillar square", PLAN, WALL).dark (pen ().rect (0, 0, 40, 40).str ());
            fp ("fp-fireplace", _("Fireplace"), 150, 60, "fireplace hearth chimney")
                .fill (pen ().rect (0, 0, 150, 60).str ())
                .shade (pen ().poly ({ 25, 0, 125, 0, 110, 40, 40, 40 }).str ());
            fp ("fp-desk", _("Desk"), 150, 75, "desk office table")
                .fill (pen ().rect (0, 0, 150, 75).str ())
                .line (pen ().rect (100, 5, 45, 30).str ());
            fp ("fp-office-chair", _("Office Chair"), 60, 60, "office chair swivel")
                .fill (pen ().circle (30, 32, 26).str ())
                .shade (pen ().round (10, 2, 40, 12, 5).str ());
            fp ("fp-chair", _("Chair"), 50, 50, "chair seat").fill (chair (25, 25, 50, 0));
            fp ("fp-armchair", _("Armchair"), 85, 85, "armchair lounge chair")
                .fill (pen ().round (0, 0, 85, 85, 8).str ())
                .line (pen ().rect (15, 20, 55, 60).line (0, 20, 85, 20).str ());
            fp ("fp-sofa-2", _("Sofa, Two Seats"), 160, 90, "sofa couch loveseat")
                .fill (pen ().round (0, 0, 160, 90, 8).str ())
                .line (pen ().rect (18, 22, 62, 62).rect (80, 22, 62, 62).line (0, 22, 160, 22).str ());
            fp ("fp-sofa-3", _("Sofa, Three Seats"), 220, 90, "sofa couch")
                .fill (pen ().round (0, 0, 220, 90, 8).str ())
                .line (pen ().rect (18, 22, 61, 62).rect (79, 22, 62, 62).rect (141, 22, 61, 62).line (0, 22, 220, 22).str ());
            fp ("fp-coffee-table", _("Coffee Table"), 110, 60, "coffee table low").fill (pen ().round (0, 0, 110, 60, 6).str ());
            fp ("fp-dining-round", _("Round Dining Table"), 180, 180, "dining table round chairs")
                .fill (chair (90, 18, 45, 0) + " " + chair (90, 162, 45, 180) + " " + chair (18, 90, 45, 270) + " " + chair (162, 90, 45, 90))
                .fill (pen ().circle (90, 90, 60).str ());
            fp ("fp-dining-rect", _("Dining Table"), 240, 170, "dining table rectangular chairs")
                .fill (chair (60, 18, 45, 0) + " " + chair (120, 18, 45, 0) + " " + chair (180, 18, 45, 0) + " " + chair (60, 152, 45, 180) + " " + chair (120, 152, 45, 180) + " " + chair (180, 152, 45, 180))
                .fill (pen ().rect (20, 40, 200, 90).str ());
            var conf = new StringBuilder ();
            for (int i = 0; i < 5; i++) {
                conf.append (chair (60 + i * 60, 20, 45, 0)).append (" ");
                conf.append (chair (60 + i * 60, 180, 45, 180)).append (" ");
            }
            fp ("fp-conference", _("Conference Table"), 360, 200, "conference meeting table chairs")
                .fill (conf.str)
                .fill (pen ().round (20, 45, 320, 110, 50).str ());
            bed ("fp-bed-single", _("Single Bed"), 90);
            bed ("fp-bed-double", _("Double Bed"), 140);
            bed ("fp-bed-queen", _("Queen Bed"), 160);
            bed ("fp-bed-king", _("King Bed"), 180);
            fp ("fp-nightstand", _("Nightstand"), 50, 40, "nightstand bedside table")
                .fill (pen ().rect (0, 0, 50, 40).str ())
                .line (pen ().circle (25, 20, 8).str ());
            fp ("fp-wardrobe", _("Wardrobe"), 120, 60, "wardrobe closet armoire")
                .fill (pen ().rect (0, 0, 120, 60).str ())
                .line (pen ().line (60, 0, 60, 60).line (5, 30, 115, 30).str ());
            fp ("fp-dresser", _("Dresser"), 120, 50, "dresser chest drawers")
                .fill (pen ().rect (0, 0, 120, 50).str ())
                .line (pen ().line (40, 0, 40, 50).line (80, 0, 80, 50).str ());
            fp ("fp-bookcase", _("Bookcase"), 90, 35, "bookcase shelf library")
                .fill (pen ().rect (0, 0, 90, 35).str ())
                .line (pen ().line (0, 30, 90, 30).line (30, 0, 30, 30).line (60, 0, 60, 30).str ());
            fp ("fp-cabinet", _("Cabinet"), 80, 60, "cabinet storage")
                .fill (pen ().rect (0, 0, 80, 60).str ())
                .line (pen ().line (0, 0, 80, 60).line (80, 0, 0, 60).str ());
            fp ("fp-counter", _("Kitchen Counter"), 240, 60, "kitchen counter worktop base cabinet")
                .fill (pen ().rect (0, 0, 240, 60).str ())
                .line (pen ().line (0, 55, 240, 55).str ());
            fp ("fp-sink", _("Kitchen Sink"), 80, 55, "sink kitchen basin")
                .fill (pen ().rect (0, 0, 80, 55).str ())
                .line (pen ().round (10, 12, 60, 36, 6).circle (40, 7, 3).str ());
            fp ("fp-sink-double", _("Double Sink"), 120, 55, "double sink kitchen")
                .fill (pen ().rect (0, 0, 120, 55).str ())
                .line (pen ().round (8, 12, 48, 36, 6).round (64, 12, 48, 36, 6).circle (60, 7, 3).str ());
            fp ("fp-stove", _("Cooktop"), 60, 60, "stove cooktop range hob burners")
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().circle (17, 17, 10).circle (43, 17, 8).circle (17, 43, 8).circle (43, 43, 10).str ());
            fp ("fp-oven", _("Oven"), 60, 60, "oven range")
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().rect (8, 12, 44, 40).line (8, 6, 52, 6).str ());
            fp ("fp-fridge", _("Refrigerator"), 70, 70, "refrigerator fridge freezer")
                .fill (pen ().rect (0, 0, 70, 70).str ())
                .line (pen ().line (0, 60, 70, 60).line (35, 0, 35, 60).str ());
            fp ("fp-dishwasher", _("Dishwasher"), 60, 60, "dishwasher appliance")
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().line (0, 8, 60, 8).line (25, 3, 35, 3).str ());
            fp ("fp-washer", _("Washing Machine"), 60, 60, "washing machine laundry washer")
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().circle (30, 32, 20).line (0, 8, 60, 8).str ());
            fp ("fp-dryer", _("Dryer"), 60, 60, "dryer laundry tumble")
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().circle (30, 32, 20).circle (30, 32, 12).line (0, 8, 60, 8).str ());
            fp ("fp-toilet", _("Toilet"), 40, 70, "toilet wc bathroom")
                .fill (pen ().rect (0, 0, 40, 18).str ())
                .fill (pen ().m (4, 18).l (36, 18).c (40, 40, 36, 70, 20, 70).c (4, 70, 0, 40, 4, 18).z ().str ());
            fp ("fp-bathtub", _("Bathtub"), 170, 75, "bathtub bath tub")
                .fill (pen ().rect (0, 0, 170, 75).str ())
                .line (pen ().round (8, 8, 154, 59, 25).circle (150, 37, 3).str ());
            fp ("fp-shower", _("Shower"), 90, 90, "shower stall")
                .fill (pen ().rect (0, 0, 90, 90).str ())
                .line (pen ().line (0, 0, 90, 90).line (90, 0, 0, 90).circle (45, 45, 5).str ());
            fp ("fp-bath-sink", _("Bathroom Sink"), 55, 45, "sink washbasin lavatory")
                .fill (pen ().rect (0, 0, 55, 45).str ())
                .line (pen ().ellipse (27.5, 25, 20, 14).circle (27.5, 6, 2).str ());
            fp ("fp-vanity", _("Vanity"), 120, 55, "vanity double sink bathroom")
                .fill (pen ().rect (0, 0, 120, 55).str ())
                .line (pen ().ellipse (32, 30, 20, 14).ellipse (88, 30, 20, 14).str ());
            fp ("fp-plant", _("Plant"), 50, 50, "plant potted indoor")
                .fill (pen ().star (25, 25, 25, 12, 8).str ())
                .line (pen ().circle (25, 25, 6).str ());
            fp ("fp-piano", _("Piano"), 150, 60, "piano upright music")
                .fill (pen ().rect (0, 0, 150, 60).str ())
                .shade (pen ().rect (5, 40, 140, 16).str ());
            fp ("fp-tv", _("Television"), 120, 15, "tv television screen")
                .fill (pen ().rect (0, 0, 120, 8).str ())
                .line (pen ().rect (45, 8, 30, 7).str ());
            fp ("fp-rug", _("Rug"), 200, 140, "rug carpet")
                .fill (pen ().rect (0, 0, 200, 140).str ())
                .line (pen ().rect (10, 10, 180, 120).str ())
                .defaults ("fill:#f3ead8;dash:dash");
            fp ("fp-cubicle", _("Cubicle"), 180, 180, "cubicle workstation office")
                .dark (pen ().poly ({ 0, 0, 180, 0, 180, 5, 5, 5, 5, 180, 0, 180 }).str ())
                .fill (pen ().poly ({ 5, 5, 175, 5, 175, 65, 65, 65, 65, 175, 5, 175 }).str ())
                .fill (chair (110, 110, 50, 180));
            fp ("fp-reception", _("Reception Desk"), 250, 120, "reception desk front")
                .fill (pen ().m (0, 120).l (0, 60).q (125, -20, 250, 60).l (250, 120).l (200, 120).l (200, 75).q (125, 30, 50, 75).l (50, 120).z ().str ());
            fp ("fp-whiteboard", _("Whiteboard"), 180, 10, "whiteboard board")
                .fill (pen ().rect (0, 0, 180, 10).str ());
            fp ("fp-printer", _("Printer"), 60, 50, "printer copier")
                .fill (pen ().rect (0, 0, 60, 50).str ())
                .line (pen ().rect (10, 5, 40, 15).str ());
            fp ("fp-water-heater", _("Water Heater"), 60, 60, "water heater boiler tank")
                .fill (pen ().circle (30, 30, 30).str ())
                .line (pen ().circle (30, 30, 8).str ());
            Stencils.shape ("fp-dimension", _("Dimension Line"), 200, 30, "dimension measure length")
                .box (200, 30)
                .defaults ("fill-kind:none;stroke:#333333;stroke-width:1;font-size:9")
                .line (pen ().line (0, 20, 200, 20).line (0, 10, 0, 30).line (200, 10, 200, 30).arrow (100, 20, 2, 20, 6).arrow (100, 20, 198, 20, 6).str ())
                .label (0, 0, 200, 18)
                .port (0, 20)
                .port (200, 20);
            Stencils.shape ("fp-north-arrow", _("North Arrow"), 50, 70, "north arrow orientation")
                .box (50, 70)
                .defaults ("fill:#ffffff;stroke:#333333;stroke-width:1;font-size:10;bold:1")
                .fill (pen ().poly ({ 25, 18, 45, 68, 25, 56, 5, 68 }).str ())
                .dark (pen ().poly ({ 25, 18, 25, 56, 5, 68 }).str ())
                .label (0, 0, 50, 18)
                .text ("N");
            var bar = pen ();
            Stencils.shape ("fp-scale-bar", _("Scale Bar"), 200, 30, "scale bar graphic scale")
                .box (200, 30)
                .defaults ("fill:#ffffff;stroke:#333333;stroke-width:1;font-size:8")
                .fill (bar.rect (0, 0, 200, 8).str ())
                .dark (pen ().rect (0, 0, 50, 8).rect (100, 0, 50, 8).str ())
                .label (0, 10, 200, 18)
                .text ("0  1  2  3  4 m");
            Stencils.shape ("fp-space-label", _("Space Label"), 120, 50, "room label area name")
                .box (120, 50)
                .defaults ("fill:#ffffff;stroke:#333333;stroke-width:0.75;font-size:10")
                .fill (pen ().rect (0, 0, 120, 50).str ())
                .line (pen ().line (10, 25, 110, 25).str ())
                .text (_("Room\n12 m²"));
            Stencils.shape ("fp-section-marker", _("Section Marker"), 70, 60, "section cut marker elevation")
                .box (70, 60)
                .defaults ("fill:#ffffff;stroke:#333333;stroke-width:1;font-size:10;bold:1")
                .dark (pen ().poly ({ 48, 16, 68, 30, 48, 44 }).str ())
                .fill (pen ().circle (30, 30, 22).str ())
                .line (pen ().line (8, 30, 52, 30).str ())
                .label (10, 8, 40, 22)
                .text ("A")
                .port (0, 30)
                .port (68, 30);
        }

        private static void tree (string kind, string name, string kw, string body) {
            fp (kind, name, 400, 400, kw, SITE, "fill:#cfe6c0;stroke:#4f7a3a;stroke-width:1")
                .fill (body)
                .solid (pen ().circle (200, 200, 12).str (), "@stroke");
        }

        private static void register_site () {
            Stencils.category ("site-plan", _("Site Plan"), "draw-shapes-symbolic", StencilGroup.PLANS);
            var decid = pen ();
            for (int i = 0; i < 9; i++) {
                double ang = i * 2 * Math.PI / 9;
                decid.circle (200 + 110 * Math.cos (ang), 200 + 110 * Math.sin (ang), 90);
            }
            tree ("site-tree", _("Deciduous Tree"), "tree deciduous landscape", pen ().circle (200, 200, 195).str ());
            fp ("site-tree-canopy", _("Tree Canopy"), 400, 400, "tree canopy landscape", SITE, "fill:#cfe6c0;stroke:#4f7a3a;stroke-width:1")
                .fill (decid.str ())
                .solid (pen ().circle (200, 200, 150).str (), "@fill");
            tree ("site-conifer", _("Conifer"), "conifer pine evergreen tree", pen ().star (200, 200, 195, 120, 12).str ());
            tree ("site-palm", _("Palm Tree"), "palm tree tropical", pen ().star (200, 200, 195, 40, 7).str ());
            fp ("site-shrub", _("Shrub"), 120, 120, "shrub bush", SITE, "fill:#dbeccd;stroke:#4f7a3a;stroke-width:1")
                .fill (pen ().star (60, 60, 58, 42, 10).str ());
            fp ("site-hedge", _("Hedge"), 400, 80, "hedge row bushes", SITE, "fill:#cfe6c0;stroke:#4f7a3a;stroke-width:1")
                .fill (pen ().round (0, 0, 400, 80, 40).str ());
            fp ("site-lawn", _("Lawn Area"), 800, 600, "lawn grass garden", SITE, "fill:#e2f1d6;stroke:#6b9a4b;stroke-width:1")
                .fill (pen ().round (0, 0, 800, 600, 60).str ())
                .as_container ();
            fp ("site-parking", _("Parking Space"), 250, 500, "parking stall car space", SITE, "fill-kind:none;stroke:#333333;stroke-width:1")
                .line (pen ().poly ({ 0, 0, 0, 500, 250, 500, 250, 0 }, false).str ());
            fp ("site-car", _("Car"), 180, 450, "car vehicle auto", SITE)
                .fill (pen ().round (0, 0, 180, 450, 40).str ())
                .shade (pen ().round (20, 110, 140, 80, 15).round (20, 300, 140, 60, 15).str ());
            fp ("site-pool", _("Swimming Pool"), 400, 800, "pool swimming", SITE, "fill:#bfe3f5;stroke:#2f6f93;stroke-width:1")
                .fill (pen ().round (0, 0, 400, 800, 40).str ())
                .line (pen ().round (20, 20, 360, 760, 30).str ());
            var fence = pen ().line (0, 10, 400, 10);
            for (int i = 0; i <= 8; i++) fence.rect (i * 50 - 5 < 0 ? 0 : (i == 8 ? 390 : i * 50 - 5), 0, 10, 20);
            fp ("site-fence", _("Fence"), 400, 20, "fence boundary", SITE, "fill:#ffffff;stroke:#333333;stroke-width:1")
                .fill (fence.str ())
                .port (0, 10)
                .port (400, 10);
            fp ("site-gate", _("Gate"), 300, 150, "gate entrance", SITE)
                .line (pen ().arc (0, 150, 150, -90, 0).arc (300, 150, 150, 180, 270).line (0, 150, 0, 0).line (300, 150, 300, 0).str ())
                .fill (pen ().rect (0, 145, 300, 5).str ());
            fp ("site-path", _("Path"), 300, 120, "path walkway pavement", SITE, "fill:#eee6d6;stroke:#8a7a5a;stroke-width:1")
                .fill (pen ().rect (0, 0, 300, 120).str ())
                .port (0, 60)
                .port (300, 60);
            fp ("site-road", _("Road"), 800, 700, "road street", SITE, "fill:#bdbdbd;stroke:#555555;stroke-width:1")
                .fill (pen ().rect (0, 0, 800, 700).str ())
                .ink (pen ().line (0, 350, 120, 350).line (240, 350, 360, 350).line (480, 350, 600, 350).line (720, 350, 800, 350).str (), "#ffffff");
            fp ("site-building", _("Building Footprint"), 1000, 800, "building footprint house", SITE, "fill:#d9d4ca;stroke:#333333;stroke-width:2;font-size:10")
                .fill (pen ().poly ({ 0, 0, 1000, 0, 1000, 500, 600, 500, 600, 800, 0, 800 }).str ())
                .text (_("Building"));
            fp ("site-bench", _("Bench"), 150, 50, "bench seat park", SITE)
                .fill (pen ().rect (0, 0, 150, 50).str ())
                .line (pen ().line (0, 25, 150, 25).str ());
            fp ("site-lamp", _("Lamp Post"), 40, 40, "lamp post street light", SITE)
                .fill (pen ().circle (20, 20, 20).str ())
                .solid (pen ().circle (20, 20, 8).str (), "#f5c518");
            fp ("site-fountain", _("Fountain"), 300, 300, "fountain water feature", SITE, "fill:#bfe3f5;stroke:#2f6f93;stroke-width:1")
                .fill (pen ().circle (150, 150, 150).str ())
                .line (pen ().circle (150, 150, 110).circle (150, 150, 30).str ());
        }

        private static unowned StencilDef map_sign (string kind, string name, string kw, string color, string glyph_path, string text = "") {
            unowned StencilDef d = Stencils.shape (kind, name, 50, 50, kw)
                .box (50, 50)
                .defaults ("fill:%s;stroke:#ffffff;stroke-width:2;text-color:#ffffff;bold:1;font-size:16".printf (color))
                .fill (pen ().round (1, 1, 48, 48, 8).str ())
                .ports_box ();
            if (glyph_path != "") d.ink (glyph_path, "#ffffff");
            if (text != "") d.label (1, 1, 48, 48).text (text);
            else d.label_below ();
            return d;
        }

        private static unowned StencilDef road (string kind, string name, string kw) {
            return Stencils.shape (kind, name, 120, 120, kw)
                .box (120, 120)
                .defaults ("fill:#9e9e9e;stroke:#6d6d6d;stroke-width:1");
        }

        private static void register_maps () {
            Stencils.category ("maps", _("Maps and Directions"), "draw-shapes-symbolic", StencilGroup.PLANS);
            road ("map-road", _("Road"), "road street straight")
                .fill (pen ().rect (40, 0, 40, 120).str ())
                .ink (pen ().line (60, 4, 60, 116).str (), "#ffffff")
                .port (60, 0)
                .port (60, 120);
            road ("map-road-curve", _("Road Curve"), "road curve bend")
                .fill (pen ().m (40, 120).l (40, 90).a (50, 50, false, true, 90, 40).l (120, 40).l (120, 80).l (90, 80).a (10, 10, false, false, 80, 90).l (80, 120).z ().str ())
                .ink (pen ().m (60, 120).l (60, 90).a (30, 30, false, true, 90, 60).l (120, 60).str (), "#ffffff")
                .port (60, 120)
                .port (120, 60);
            road ("map-intersection", _("Intersection"), "intersection crossroads junction")
                .fill (pen ().poly ({ 40, 0, 80, 0, 80, 40, 120, 40, 120, 80, 80, 80, 80, 120, 40, 120, 40, 80, 0, 80, 0, 40, 40, 40 }).str ())
                .ink (pen ().line (60, 4, 60, 36).line (60, 84, 60, 116).line (4, 60, 36, 60).line (84, 60, 116, 60).str (), "#ffffff")
                .port (60, 0)
                .port (120, 60)
                .port (60, 120)
                .port (0, 60);
            road ("map-roundabout", _("Roundabout"), "roundabout traffic circle")
                .fill (pen ().rect (45, 0, 30, 120).rect (0, 45, 120, 30).circle (60, 60, 40).str ())
                .solid (pen ().circle (60, 60, 20).str (), "#8bc34a")
                .port (60, 0)
                .port (120, 60)
                .port (60, 120)
                .port (0, 60);
            road ("map-highway", _("Highway"), "highway motorway freeway")
                .fill (pen ().rect (20, 0, 80, 120).str ())
                .ink (pen ().line (60, 0, 60, 120).line (40, 4, 40, 116).line (80, 4, 80, 116).str (), "#ffffff")
                .defaults ("fill:#7d7d7d")
                .port (60, 0)
                .port (60, 120);
            var rail = pen ().line (50, 0, 50, 120).line (70, 0, 70, 120);
            for (int i = 0; i < 12; i++) rail.line (42, 5 + i * 10, 78, 5 + i * 10);
            Stencils.shape ("map-railway", _("Railway"), 120, 120, "railway train tracks")
                .box (120, 120)
                .defaults ("fill-kind:none;stroke:#333333;stroke-width:2")
                .line (rail.str ())
                .port (60, 0)
                .port (60, 120);
            Stencils.shape ("map-river", _("River"), 160, 60, "river stream water")
                .box (160, 60)
                .defaults ("fill:#9fd3f0;stroke:#4a90c0;stroke-width:1")
                .fill (pen ().m (0, 20).q (40, 0, 80, 20).q (120, 40, 160, 20).l (160, 45).q (120, 65, 80, 45).q (40, 25, 0, 45).z ().str ())
                .port (0, 32)
                .port (160, 32);
            Stencils.shape ("map-bridge", _("Bridge"), 100, 60, "bridge crossing")
                .box (100, 60)
                .defaults ("fill:#9e9e9e;stroke:#555555;stroke-width:1.5")
                .fill (pen ().rect (0, 18, 100, 24).str ())
                .line (pen ().m (0, 12).l (10, 12).l (18, 18).l (82, 18).l (90, 12).l (100, 12).m (0, 48).l (10, 48).l (18, 42).l (82, 42).l (90, 48).l (100, 48).str ())
                .ports_box ();
            Stencils.shape ("map-building", _("Map Building"), 50, 50, "building house map")
                .box (50, 50)
                .defaults ("fill:#d9d4ca;stroke:#6d6250;stroke-width:1")
                .fill (pen ().poly ({ 0, 20, 25, 0, 50, 20, 50, 50, 0, 50 }).str ())
                .label_below ()
                .ports_box ();
            Stencils.shape ("map-landmark", _("Landmark"), 40, 56, "landmark pin location marker")
                .box (40, 56)
                .defaults ("fill:#e53935;stroke:#8e1c1c;stroke-width:1")
                .fill (pen ().m (20, 56).c (10, 40, 0, 32, 0, 20).a (20, 20, false, true, 40, 20).c (40, 32, 30, 40, 20, 56).z ().str ())
                .solid (pen ().circle (20, 20, 7).str (), "#ffffff")
                .label_below ()
                .port (20, 56);
            map_sign ("map-airport", _("Airport"), "airport plane flight", "#1f4e79", pen ().m (25, 8).l (27, 20).l (42, 28).l (42, 32).l (27, 28).l (26, 38).l (31, 42).l (31, 44).l (25, 42).l (19, 44).l (19, 42).l (24, 38).l (23, 28).l (8, 32).l (8, 28).l (23, 20).z ().str ());
            map_sign ("map-train", _("Train Station"), "train station railway", "#1f4e79", pen ().round (14, 8, 22, 26, 5).rect (17, 12, 16, 9).circle (19, 28, 1.5).circle (31, 28, 1.5).line (17, 34, 13, 42).line (33, 34, 37, 42).str ());
            map_sign ("map-bus", _("Bus Stop"), "bus stop transit", "#1f4e79", pen ().round (13, 9, 24, 28, 3).rect (16, 13, 18, 10).line (16, 30, 18, 30).line (32, 30, 34, 30).line (17, 37, 17, 41).line (33, 37, 33, 41).str ());
            map_sign ("map-parking", _("Parking"), "parking p sign", "#1565c0", "", "P");
            map_sign ("map-hospital", _("Hospital"), "hospital medical h", "#c62828", "", "H");
            map_sign ("map-school", _("School"), "school education", "#6d4c41", pen ().poly ({ 8, 22, 25, 12, 42, 22 }).rect (12, 22, 26, 18).rect (22, 30, 6, 10).str ());
            map_sign ("map-park", _("Park"), "park green tree", "#2e7d32", pen ().circle (25, 20, 11).line (25, 31, 25, 42).line (18, 42, 32, 42).str ());
            map_sign ("map-info", _("Information"), "information tourist i", "#00796b", "", "i");
            map_sign ("map-fuel", _("Fuel Station"), "fuel gas petrol station", "#455a64", pen ().rect (14, 12, 16, 28).rect (17, 16, 10, 8).m (30, 20).l (36, 24).l (36, 36).str ());
            Stencils.shape ("map-north-arrow", _("Map North Arrow"), 40, 60, "north arrow")
                .box (40, 60)
                .defaults ("fill:#ffffff;stroke:#333333;stroke-width:1;bold:1;font-size:10")
                .fill (pen ().poly ({ 20, 16, 38, 58, 20, 48, 2, 58 }).str ())
                .dark (pen ().poly ({ 20, 16, 20, 48, 38, 58 }).str ())
                .label (0, 0, 40, 16)
                .text ("N");
            var rose = pen ().circle (60, 60, 30);
            Stencils.shape ("map-compass", _("Compass Rose"), 120, 120, "compass rose directions")
                .box (120, 120)
                .defaults ("fill:#ffffff;stroke:#333333;stroke-width:1")
                .line (rose.str ())
                .fill (pen ().star (60, 60, 58, 12, 4).str ())
                .dark (pen ().poly ({ 60, 2, 60, 60, 70, 50 }).poly ({ 118, 60, 60, 60, 70, 70 }).poly ({ 60, 118, 60, 60, 50, 70 }).poly ({ 2, 60, 60, 60, 50, 50 }).str ())
                .fill (pen ().star (60, 60, 30, 8, 4, -45).str ());
            Stencils.shape ("map-sign", _("Directional Sign"), 100, 90, "direction sign post signpost")
                .box (100, 90)
                .defaults ("fill:#2e7d32;stroke:#1b4d1e;stroke-width:1;text-color:#ffffff;font-size:9;bold:1")
                .line (pen ().line (50, 10, 50, 90).str ())
                .fill (pen ().poly ({ 50, 8, 90, 8, 100, 20, 90, 32, 50, 32 }).str ())
                .fill (pen ().poly ({ 50, 40, 10, 40, 0, 52, 10, 64, 50, 64 }).str ())
                .label (50, 8, 40, 24)
                .port (50, 90);
        }

        public static void register () {
            register_floor ();
            register_site ();
            register_maps ();
        }
    }
}
