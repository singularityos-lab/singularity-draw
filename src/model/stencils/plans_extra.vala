namespace Singularity.Apps.Draw {

    public class StencilsPlansExtra {
        private const double PLAN = 0.756;
        private const double SITE = 0.189;
        private const string FURNITURE = "fill:#ffffff;stroke:#333333;stroke-width:1";
        private const string GREEN = "fill:#a5d6a7;stroke:#2e7d32;stroke-width:1";

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

        private static string chair_at (double x, double y, double s, double rot) {
            var p = new TechPen (x - s / 2, y - s / 2, s);
            if (rot == 0) p.round (3, 6, 18, 16, 2).round (3, 2, 18, 5, 1.5);
            else if (rot == 180) p.round (3, 2, 18, 16, 2).round (3, 17, 18, 5, 1.5);
            else if (rot == 90) p.round (2, 3, 16, 18, 2).round (17, 3, 5, 18, 1.5);
            else p.round (6, 3, 16, 18, 2).round (2, 3, 5, 18, 1.5);
            return p.str ();
        }

        private static void round_table (int seats) {
            double d = 60 + seats * 12;
            double size = d + 80;
            double c = size / 2;
            var chairs = new StringBuilder ();
            for (int i = 0; i < seats; i++) {
                double a = (-90 + i * 360.0 / seats) * Math.PI / 180;
                double cx = c + (d / 2 + 18) * Math.cos (a), cy = c + (d / 2 + 18) * Math.sin (a);
                chairs.append (pen ().circle (cx, cy, 18).str ()).append (" ");
            }
            fp ("fpx-round-table-%d".printf (seats), _("Round Table, %d Seats").printf (seats), size, size, "round dining meeting table chairs")
                .fill (chairs.str.strip ())
                .fill (pen ().circle (c, c, d / 2).str ());
        }

        private static void rect_table (int seats) {
            int per_side = seats / 2;
            double w = per_side * 60 + 20, h = 90;
            double tw = w + 0, th = h + 100;
            var chairs = new StringBuilder ();
            for (int i = 0; i < per_side; i++) {
                double x = 10 + i * 60 + 30;
                chairs.append (chair_at (x, 22, 44, 180)).append (" ");
                chairs.append (chair_at (x, th - 22, 44, 0)).append (" ");
            }
            fp ("fpx-table-%d".printf (seats), _("Rectangular Table, %d Seats").printf (seats), tw, th, "dining meeting table chairs")
                .fill (chairs.str.strip ())
                .fill (pen ().rect (0, 50, w, h).str ());
        }

        private static void register_furniture () {
            Stencils.category ("furniture", _("Office and Home Furniture"), "draw-shapes-symbolic", StencilGroup.PLANS);
            fp ("fpx-desk-l", _("L-Shaped Desk"), 180, 160, "corner l desk workstation")
                .fill (pen ().poly ({ 0, 0, 180, 0, 180, 70, 70, 70, 70, 160, 0, 160 }).str ());
            fp ("fpx-desk-corner", _("Corner Desk"), 140, 140, "corner desk")
                .fill (pen ().poly ({ 0, 0, 140, 0, 140, 60, 60, 140, 0, 140 }).str ());
            fp ("fpx-desk-executive", _("Executive Desk"), 200, 100, "executive desk manager")
                .fill (pen ().rect (0, 0, 200, 100).str ())
                .line (pen ().rect (10, 60, 50, 36).rect (140, 60, 50, 36).str ());
            fp ("fpx-desk-standing", _("Standing Desk"), 160, 80, "sit stand desk height adjustable")
                .fill (pen ().round (0, 0, 160, 80, 4).str ())
                .line (pen ().rect (20, 72, 20, 8).rect (120, 72, 20, 8).str ());
            for (int k = 4; k <= 6; k += 2) {
                double w = (k / 2) * 140;
                var desks = pen ();
                for (int i = 0; i < k / 2; i++) desks.rect (i * 140, 0, 140, 70).rect (i * 140, 70, 140, 70);
                var chairs = new StringBuilder ();
                for (int i = 0; i < k / 2; i++) {
                    chairs.append (chair_at (i * 140 + 70, -26, 44, 180)).append (" ");
                    chairs.append (chair_at (i * 140 + 70, 166, 44, 0)).append (" ");
                }
                fp ("fpx-bench-%d".printf (k), _("Bench Desking, %d Places").printf (k), w, 140, "bench desk open plan office")
                    .fill (desks.str ())
                    .fill (chairs.str.strip ());
            }
            round_table (4);
            round_table (6);
            round_table (8);
            rect_table (4);
            rect_table (6);
            rect_table (8);
            rect_table (10);
            rect_table (12);
            rect_table (16);
            for (int k = 2; k <= 4; k++) {
                var drawers = pen ().rect (0, 0, 50, 60);
                for (int i = 1; i < k; i++) drawers.line (0, i * 60.0 / k, 50, i * 60.0 / k);
                fp ("fpx-filing-%d".printf (k), _("Filing Cabinet, %d Drawers").printf (k), 50, 60, "filing cabinet drawers storage")
                    .fill (drawers.str ());
            }
            fp ("fpx-pedestal", _("Pedestal"), 40, 60, "mobile pedestal drawer unit")
                .fill (pen ().rect (0, 0, 40, 60).str ())
                .solid (pen ().circle (6, 54, 3).circle (34, 54, 3).str (), "@stroke");
            fp ("fpx-credenza", _("Credenza"), 180, 50, "credenza sideboard storage")
                .fill (pen ().rect (0, 0, 180, 50).str ())
                .line (pen ().line (60, 0, 60, 50).line (120, 0, 120, 50).str ());
            fp ("fpx-lockers", _("Lockers"), 120, 50, "lockers staff storage")
                .fill (pen ().rect (0, 0, 120, 50).str ())
                .line (pen ().line (30, 0, 30, 50).line (60, 0, 60, 50).line (90, 0, 90, 50).str ());
            fp ("fpx-coat-rack", _("Coat Rack"), 50, 50, "coat stand hanger")
                .fill (pen ().circle (25, 25, 24).str ())
                .line (pen ().circle (25, 25, 6).line (25, 1, 25, 49).line (1, 25, 49, 25).str ());
            fp ("fpx-sofa-l", _("L-Shaped Sofa"), 260, 200, "corner sofa sectional couch")
                .fill (pen ().poly ({ 0, 0, 260, 0, 260, 90, 90, 90, 90, 200, 0, 200 }).str ())
                .line (pen ().poly ({ 20, 20, 260, 20, 260, 90, 90, 90, 90, 200, 20, 200 }).line (150, 20, 150, 90).line (20, 110, 90, 110).str ());
            fp ("fpx-loveseat", _("Loveseat"), 150, 90, "loveseat two seat sofa small")
                .fill (pen ().round (0, 0, 150, 90, 8).str ())
                .line (pen ().rect (16, 20, 118, 66).line (75, 20, 75, 86).str ());
            fp ("fpx-recliner", _("Recliner"), 90, 110, "recliner lounge chair")
                .fill (pen ().round (0, 0, 90, 110, 10).str ())
                .line (pen ().rect (14, 22, 62, 84).line (14, 70, 76, 70).str ());
            fp ("fpx-ottoman", _("Ottoman"), 60, 60, "ottoman footstool pouf")
                .fill (pen ().round (0, 0, 60, 60, 10).str ());
            fp ("fpx-bar-stool", _("Bar Stool"), 40, 40, "bar stool counter seat")
                .fill (pen ().circle (20, 20, 19).str ())
                .line (pen ().circle (20, 20, 12).str ());
            fp ("fpx-bench", _("Bench"), 150, 40, "bench seat")
                .fill (pen ().rect (0, 0, 150, 40).str ())
                .line (pen ().line (0, 20, 150, 20).str ());
            fp ("fpx-side-table", _("Side Table"), 50, 50, "side end table lamp table")
                .fill (pen ().rect (0, 0, 50, 50).str ())
                .line (pen ().circle (25, 25, 10).str ());
            fp ("fpx-console-table", _("Console Table"), 120, 35, "console hallway table")
                .fill (pen ().rect (0, 0, 120, 35).str ());
            fp ("fpx-tv-unit", _("TV Unit"), 180, 45, "tv stand media console")
                .fill (pen ().rect (0, 0, 180, 45).str ())
                .shade (pen ().rect (30, 10, 120, 8).str ());
            fp ("fpx-bunk-bed", _("Bunk Bed"), 100, 200, "bunk bed children")
                .fill (pen ().rect (0, 0, 100, 200).str ())
                .line (pen ().rect (6, 6, 88, 36).line (0, 0, 100, 200).line (100, 0, 0, 200).str ());
            fp ("fpx-crib", _("Crib"), 70, 130, "crib cot baby")
                .fill (pen ().rect (0, 0, 70, 130).str ())
                .line (pen ().line (10, 0, 10, 130).line (20, 0, 20, 130).line (30, 0, 30, 130).line (40, 0, 40, 130).line (50, 0, 50, 130).line (60, 0, 60, 130).str ());
            fp ("fpx-floor-lamp", _("Floor Lamp"), 40, 40, "floor lamp standing light")
                .fill (pen ().circle (20, 20, 19).str ())
                .line (pen ().circle (20, 20, 4).line (20, 1, 20, 12).line (20, 28, 20, 39).line (1, 20, 12, 20).line (28, 20, 39, 20).str ());
            fp ("fpx-shelving", _("Shelving Unit"), 100, 40, "shelves shelving unit")
                .fill (pen ().rect (0, 0, 100, 40).str ())
                .line (pen ().line (0, 0, 100, 40).line (25, 0, 25, 40).line (50, 0, 50, 40).line (75, 0, 75, 40).str ());
            fp ("fpx-shoe-rack", _("Shoe Rack"), 80, 30, "shoe rack cabinet entry")
                .fill (pen ().rect (0, 0, 80, 30).str ())
                .line (pen ().line (0, 15, 80, 15).str ());
            fp ("fpx-kitchen-island", _("Kitchen Island"), 200, 100, "kitchen island counter")
                .fill (pen ().rect (0, 0, 200, 100).str ())
                .line (pen ().rect (10, 10, 70, 50).circle (45, 35, 4).str ())
                .shade (pen ().rect (120, 20, 60, 50).str ());
            fp ("fpx-microwave", _("Microwave"), 50, 40, "microwave oven")
                .fill (pen ().rect (0, 0, 50, 40).str ())
                .line (pen ().rect (4, 4, 32, 32).line (42, 8, 46, 8).line (42, 16, 46, 16).str ());
            fp ("fpx-range-hood", _("Range Hood"), 90, 50, "extractor hood range")
                .fill (pen ().poly ({ 0, 0, 90, 0, 80, 50, 10, 50 }).str ())
                .line (pen ().rect (30, 0, 30, 20).str ());
            fp ("fpx-wine-cooler", _("Wine Cooler"), 60, 60, "wine fridge cooler")
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().circle (15, 15, 6).circle (30, 15, 6).circle (45, 15, 6).circle (15, 35, 6).circle (30, 35, 6).circle (45, 35, 6).str ());
            fp ("fpx-freezer", _("Chest Freezer"), 120, 70, "chest freezer")
                .fill (pen ().rect (0, 0, 120, 70).str ())
                .line (pen ().line (6, 6, 114, 6).str ())
                .text ("FZ");
            fp ("fpx-corner-sink", _("Corner Kitchen Sink"), 110, 110, "corner sink kitchen")
                .fill (pen ().poly ({ 0, 0, 110, 0, 110, 60, 60, 110, 0, 110 }).str ())
                .line (pen ().round (10, 10, 40, 40, 6).round (10, 60, 40, 40, 6).str ());
            fp ("fpx-kitchen-table-2", _("Kitchen Table, 2 Seats"), 80, 150, "bistro table two chairs")
                .fill (pen ().str () + chair_at (40, 22, 44, 180) + " " + chair_at (40, 128, 44, 0))
                .fill (pen ().rect (0, 45, 80, 60).str ());
            fp ("fpx-toilet-wall", _("Wall-Hung Toilet"), 40, 55, "wall hung toilet wc")
                .fill (pen ().rect (0, 0, 40, 10).str ())
                .fill (pen ().m (4, 10).l (36, 10).q (38, 55, 20, 55).q (2, 55, 4, 10).z ().str ());
            fp ("fpx-corner-bath", _("Corner Bath"), 150, 150, "corner bathtub")
                .fill (pen ().poly ({ 0, 0, 150, 0, 150, 80, 80, 150, 0, 150 }).str ())
                .line (pen ().m (12, 12).l (138, 12).l (138, 70).q (90, 90, 70, 138).l (12, 138).z ().str ());
            fp ("fpx-walk-in-shower", _("Walk-In Shower"), 150, 90, "walk in shower glass screen")
                .fill (pen ().rect (0, 0, 150, 90).str ())
                .line (pen ().line (0, 86, 100, 86).circle (120, 45, 5).str ());
            fp ("fpx-double-vanity", _("Double Vanity"), 160, 55, "double basin vanity")
                .fill (pen ().rect (0, 0, 160, 55).str ())
                .line (pen ().ellipse (40, 28, 26, 18).ellipse (120, 28, 26, 18).str ());
            fp ("fpx-towel-rail", _("Heated Towel Rail"), 60, 12, "towel radiator rail")
                .fill (pen ().rect (0, 0, 60, 12).str ())
                .line (pen ().line (10, 0, 10, 12).line (20, 0, 20, 12).line (30, 0, 30, 12).line (40, 0, 40, 12).line (50, 0, 50, 12).str ());
            fp ("fpx-washer-dryer", _("Stacked Washer and Dryer"), 60, 60, "stacked washer dryer laundry")
                .fill (pen ().rect (0, 0, 60, 60).str ())
                .line (pen ().circle (30, 30, 20).line (0, 6, 60, 6).str ())
                .text ("W/D");
            fp ("fpx-ironing-board", _("Ironing Board"), 120, 35, "ironing board laundry")
                .fill (pen ().m (0, 5).l (100, 5).q (120, 17.5, 100, 30).l (0, 30).z ().str ());
            fp ("fpx-desk-chair-set", _("Desk with Chair"), 120, 110, "home office desk chair")
                .fill (pen ().rect (0, 0, 120, 60).str ())
                .fill (chair_at (60, 86, 48, 0));
            fp ("fpx-meeting-pod", _("Meeting Booth"), 200, 160, "meeting booth acoustic pod")
                .fill (pen ().rect (0, 0, 200, 160).str ())
                .line (pen ().rect (10, 10, 180, 40).rect (10, 110, 180, 40).rect (60, 60, 80, 40).str ());
            fp ("fpx-reception-l", _("Reception Counter"), 240, 160, "reception desk counter lobby")
                .fill (pen ().m (0, 0).l (240, 0).l (240, 60).l (80, 60).l (80, 160).l (0, 160).z ().str ())
                .line (pen ().m (0, 20).l (220, 20).l (220, 40).str ());
            fp ("fpx-planter-box", _("Planter Box"), 100, 30, "planter indoor plants")
                .fill (pen ().rect (0, 0, 100, 30).str ())
                .solid (pen ().circle (15, 15, 10).circle (40, 15, 10).circle (65, 15, 10).circle (88, 15, 10).str (), "#6fbf5a");
            fp ("fpx-aquarium", _("Aquarium"), 120, 45, "fish tank aquarium")
                .fill (pen ().rect (0, 0, 120, 45).str ())
                .solid (pen ().rect (4, 4, 112, 37).str (), "#b7d3f4");
        }

        private static unowned StencilDef garden (string kind, string name, double w, double h, string kw, string style = GREEN) {
            return fp (kind, name, w, h, kw, SITE, style);
        }

        private static void register_garden () {
            Stencils.category ("garden", _("Garden and Landscape"), "draw-shapes-symbolic", StencilGroup.PLANS);
            garden ("gdn-flower-bed", _("Flower Bed"), 400, 200, "flower bed border planting")
                .fill (pen ().round (0, 0, 400, 200, 80).str ())
                .solid (pen ().circle (80, 70, 18).circle (160, 120, 18).circle (240, 70, 18).circle (320, 120, 18).str (), "#e5534b")
                .solid (pen ().circle (120, 140, 14).circle (200, 60, 14).circle (280, 140, 14).str (), "#f5c518");
            garden ("gdn-vegetable-patch", _("Vegetable Patch"), 400, 300, "vegetable garden rows allotment", "fill:#c49a6c;stroke:#6d4c2b;stroke-width:1")
                .fill (pen ().rect (0, 0, 400, 300).str ())
                .solid (pen ().rect (20, 30, 360, 20).rect (20, 100, 360, 20).rect (20, 170, 360, 20).rect (20, 240, 360, 20).str (), "#6fbf5a");
            garden ("gdn-raised-bed", _("Raised Bed"), 240, 120, "raised bed planter", "fill:#a5d6a7;stroke:#6d4c2b;stroke-width:2")
                .fill (pen ().rect (0, 0, 240, 120).str ())
                .line (pen ().rect (10, 10, 220, 100).str ());
            garden ("gdn-pond", _("Pond"), 400, 260, "garden pond water feature", "fill:#90caf9;stroke:#1f5fae;stroke-width:1")
                .fill (pen ().m (40, 130).q (20, 20, 160, 20).q (300, 0, 370, 80).q (420, 200, 280, 240).q (120, 280, 40, 130).z ().str ());
            garden ("gdn-patio", _("Patio"), 400, 300, "patio paving terrace", "fill:#e0d6c8;stroke:#8d7b68;stroke-width:1")
                .fill (pen ().rect (0, 0, 400, 300).str ())
                .line (pen ().line (100, 0, 100, 300).line (200, 0, 200, 300).line (300, 0, 300, 300).line (0, 100, 400, 100).line (0, 200, 400, 200).str ());
            garden ("gdn-deck", _("Deck"), 400, 300, "wood deck decking", "fill:#d7a86e;stroke:#8d5a2b;stroke-width:1")
                .fill (pen ().rect (0, 0, 400, 300).str ())
                .line (pen ().line (0, 30, 400, 30).line (0, 60, 400, 60).line (0, 90, 400, 90).line (0, 120, 400, 120).line (0, 150, 400, 150).line (0, 180, 400, 180).line (0, 210, 400, 210).line (0, 240, 400, 240).line (0, 270, 400, 270).str ());
            garden ("gdn-pergola", _("Pergola"), 400, 300, "pergola arbor", "fill-kind:none;stroke:#6d4c2b;stroke-width:3")
                .line (pen ().rect (0, 0, 400, 300).line (0, 50, 400, 50).line (0, 100, 400, 100).line (0, 150, 400, 150).line (0, 200, 400, 200).line (0, 250, 400, 250).str ())
                .solid (pen ().rect (0, 0, 20, 20).rect (380, 0, 20, 20).rect (0, 280, 20, 20).rect (380, 280, 20, 20).str (), "#6d4c2b");
            garden ("gdn-gazebo", _("Gazebo"), 360, 360, "gazebo pavilion", "fill:#ffffff;stroke:#6d4c2b;stroke-width:2")
                .fill (pen ().regular (180, 180, 178, 8, -67.5).str ())
                .line (pen ().line (180, 2, 180, 358).line (2, 180, 358, 180).line (54, 54, 306, 306).line (306, 54, 54, 306).str ());
            garden ("gdn-shed", _("Garden Shed"), 300, 240, "shed outbuilding storage", "fill:#d7ccc8;stroke:#5d4037;stroke-width:2")
                .fill (pen ().rect (0, 0, 300, 240).str ())
                .line (pen ().line (0, 120, 300, 120).line (0, 0, 150, 120).line (300, 0, 150, 120).line (0, 240, 150, 120).line (300, 240, 150, 120).str ());
            garden ("gdn-greenhouse", _("Greenhouse"), 300, 240, "greenhouse glasshouse", "fill:#e3f2fd;stroke:#1f5fae;stroke-width:1.5")
                .fill (pen ().rect (0, 0, 300, 240).str ())
                .line (pen ().line (0, 120, 300, 120).line (60, 0, 60, 240).line (120, 0, 120, 240).line (180, 0, 180, 240).line (240, 0, 240, 240).str ());
            garden ("gdn-trampoline", _("Trampoline"), 360, 360, "trampoline play", "fill:#1e1e1e;stroke:#1f5fae;stroke-width:6")
                .fill (pen ().circle (180, 180, 176).str ())
                .solid (pen ().circle (180, 180, 150).str (), "#424242");
            garden ("gdn-playground", _("Play Area"), 400, 300, "playground swings slide", "fill:#fff3e0;stroke:#e65100;stroke-width:2")
                .fill (pen ().round (0, 0, 400, 300, 20).str ())
                .line (pen ().rect (40, 40, 120, 20).line (60, 60, 60, 100).line (140, 60, 140, 100).rect (240, 60, 40, 180).circle (320, 220, 40).str ());
            garden ("gdn-sandbox", _("Sandpit"), 200, 200, "sandbox sandpit", "fill:#ffe0b2;stroke:#8d6e63;stroke-width:3")
                .fill (pen ().rect (0, 0, 200, 200).str ());
            garden ("gdn-bbq", _("Barbecue"), 120, 80, "bbq grill barbecue", "fill:#424242;stroke:#1e1e1e;stroke-width:1")
                .fill (pen ().round (0, 0, 120, 80, 10).str ())
                .ink (pen ().line (20, 20, 100, 20).line (20, 40, 100, 40).line (20, 60, 100, 60).str (), "#bdbdbd");
            garden ("gdn-fire-pit", _("Fire Pit"), 160, 160, "fire pit outdoor", "fill:#9e9e9e;stroke:#424242;stroke-width:2")
                .fill (pen ().circle (80, 80, 78).str ())
                .solid (pen ().circle (80, 80, 50).str (), "#f08a3c");
            garden ("gdn-sun-lounger", _("Sun Lounger"), 200, 70, "sun lounger deck chair", "fill:#ffffff;stroke:#333333;stroke-width:1")
                .fill (pen ().round (0, 0, 200, 70, 8).str ())
                .line (pen ().line (60, 0, 60, 70).str ());
            garden ("gdn-parasol", _("Parasol"), 300, 300, "umbrella parasol shade", "fill:#f5c518;stroke:#b8930b;stroke-width:2")
                .fill (pen ().regular (150, 150, 148, 8, -67.5).str ())
                .line (pen ().line (150, 2, 150, 298).line (2, 150, 298, 150).line (45, 45, 255, 255).line (255, 45, 45, 255).str ());
            garden ("gdn-table-set", _("Garden Table Set"), 240, 240, "garden table chairs outdoor", "fill:#ffffff;stroke:#5d4037;stroke-width:2")
                .fill (pen ().circle (120, 30, 26).circle (210, 120, 26).circle (120, 210, 26).circle (30, 120, 26).str ())
                .fill (pen ().circle (120, 120, 64).str ());
            garden ("gdn-birdbath", _("Birdbath"), 80, 80, "bird bath", "fill:#e0e0e0;stroke:#616161;stroke-width:2")
                .fill (pen ().circle (40, 40, 38).str ())
                .solid (pen ().circle (40, 40, 26).str (), "#90caf9");
            garden ("gdn-stepping-stones", _("Stepping Stones"), 400, 100, "stepping stones path", "fill:#bdbdbd;stroke:#616161;stroke-width:1")
                .fill (pen ().ellipse (40, 50, 34, 28).ellipse (130, 40, 32, 26).ellipse (220, 58, 34, 28).ellipse (310, 44, 32, 26).ellipse (380, 56, 18, 22).str ());
            garden ("gdn-rockery", _("Rockery"), 300, 200, "rock garden rockery", "fill:#bdbdbd;stroke:#616161;stroke-width:1")
                .fill (pen ().poly ({ 20, 120, 60, 60, 120, 70, 130, 140 }).poly ({ 140, 90, 200, 30, 260, 80, 240, 160, 160, 170 }).poly ({ 40, 160, 100, 150, 120, 190, 50, 196 }).str ());
            garden ("gdn-compost", _("Compost Bin"), 100, 100, "compost bin heap", "fill:#795548;stroke:#3e2723;stroke-width:2")
                .fill (pen ().rect (0, 0, 100, 100).str ())
                .line (pen ().line (0, 25, 100, 25).line (0, 50, 100, 50).line (0, 75, 100, 75).str ());
            garden ("gdn-water-butt", _("Water Butt"), 80, 80, "rain water barrel", "fill:#2e7d32;stroke:#1b5e20;stroke-width:2")
                .fill (pen ().circle (40, 40, 38).str ())
                .line (pen ().circle (40, 40, 26).str ());
            garden ("gdn-flower-pot", _("Flower Pot"), 60, 60, "flower pot planter", "fill:#d7896b;stroke:#8d4f37;stroke-width:2")
                .fill (pen ().circle (30, 30, 28).str ())
                .solid (pen ().star (30, 30, 20, 9, 6).str (), "#e5534b");
            garden ("gdn-cactus", _("Cactus"), 80, 80, "cactus succulent", "fill:#66bb6a;stroke:#2e7d32;stroke-width:2")
                .fill (pen ().star (40, 40, 38, 24, 10).str ())
                .line (pen ().circle (40, 40, 8).str ());
            garden ("gdn-rose", _("Rose Bush"), 120, 120, "rose bush shrub flowers", "fill:#81c784;stroke:#2e7d32;stroke-width:1")
                .fill (pen ().circle (60, 60, 58).str ())
                .solid (pen ().circle (40, 40, 10).circle (80, 44, 10).circle (60, 80, 10).circle (30, 76, 8).circle (88, 80, 8).str (), "#d81b60");
            garden ("gdn-ornamental-grass", _("Ornamental Grass"), 120, 120, "grass clump ornamental", "fill-kind:none;stroke:#558b2f;stroke-width:2")
                .line (pen ().line (60, 60, 10, 20).line (60, 60, 30, 4).line (60, 60, 60, 0).line (60, 60, 90, 4).line (60, 60, 110, 20).line (60, 60, 4, 60).line (60, 60, 116, 60).line (60, 60, 20, 104).line (60, 60, 100, 104).str ());
            garden ("gdn-lawn-edge", _("Lawn Edging"), 400, 40, "lawn edging border", "fill:#9e9e9e;stroke:#616161;stroke-width:1")
                .fill (pen ().rect (0, 14, 400, 12).str ());
            garden ("gdn-irrigation", _("Sprinkler"), 80, 80, "lawn sprinkler irrigation", "fill-kind:none;stroke:#1f5fae;stroke-width:2")
                .line (pen ().circle (40, 40, 6).arc (40, 40, 20, 200, 340).arc (40, 40, 30, 200, 340).arc (40, 40, 38, 200, 340).str ());
            garden ("gdn-hedge-row", _("Hedge Row"), 400, 80, "hedge row bushes", "fill:#66bb6a;stroke:#2e7d32;stroke-width:1")
                .fill (pen ().circle (40, 40, 38).circle (100, 40, 38).circle (160, 40, 38).circle (220, 40, 38).circle (280, 40, 38).circle (340, 40, 38).str ());
        }

        private static unowned StencilDef poi (string kind, string name, string kw, string glyph, string color) {
            return Stencils.shape (kind, name, 50, 60, kw)
                .box (100, 120)
                .icon ()
                .defaults ("fill:%s;stroke:#ffffff;stroke-width:2.5;font-size:9".printf (color))
                .label_below ()
                .fill (pen ().m (50, 118).l (18, 76).q (2, 56, 2, 46).q (2, 2, 50, 2).q (98, 2, 98, 46).q (98, 56, 82, 76).z ().str ())
                .ink (glyph, "#ffffff")
                .port (50, 118);
        }

        private static string g (string id) {
            var p = new TechPen (20, 16, 60);
            switch (id) {
                case "train": p.round (5, 2, 14, 16, 3).rect (7, 5, 10, 5).circle (8.5, 14, 1.5).circle (15.5, 14, 1.5).line (7, 22, 9, 18).line (17, 22, 15, 18); break;
                case "tram": p.round (5, 5, 14, 14, 3).rect (7, 8, 10, 4).line (12, 5, 12, 1).line (9, 1, 15, 1).circle (9, 16, 1.2).circle (15, 16, 1.2); break;
                case "ferry": p.m (3, 14).l (21, 14).l (18, 20).l (6, 20).z ().rect (7, 8, 10, 6).rect (11, 4, 2, 4); break;
                case "taxi": p.m (4, 12).l (6, 7).l (18, 7).l (20, 12).l (20, 17).l (4, 17).z ().rect (10, 4, 4, 3).circle (7, 17, 2).circle (17, 17, 2); break;
                case "bike": p.circle (6, 15, 4).circle (18, 15, 4).m (6, 15).l (10, 8).l (16, 8).l (18, 15).m (10, 8).l (12, 15).l (16, 8); break;
                case "ev": p.round (5, 3, 10, 18, 2).rect (7, 5, 6, 5).m (10, 12).l (8, 16).l (11, 16).l (9, 20).m (15, 8).l (18, 8).l (18, 16).l (20, 16); break;
                case "toilets": p.circle (7, 4, 2).rect (5, 7, 4, 7).rect (5, 14, 1.5, 6).rect (7.5, 14, 1.5, 6).circle (17, 4, 2).poly ({ 17, 7, 20, 15, 14, 15 }).rect (15, 15, 1.5, 5).rect (17.5, 15, 1.5, 5).line (12, 2, 12, 22); break;
                case "restaurant": p.line (7, 3, 7, 21).line (5, 3, 5, 9).line (9, 3, 9, 9).m (5, 9).q (7, 11, 9, 9).m (16, 21).l (16, 3).q (20, 6, 19, 13).l (16, 13); break;
                case "cafe": p.m (4, 8).l (16, 8).l (15, 18).l (5, 18).z ().m (16, 10).q (21, 10, 20, 14).q (19, 16, 15.5, 15).line (3, 21, 17, 21); break;
                case "hotel": p.rect (3, 12, 18, 6).rect (3, 8, 3, 10).circle (9, 10, 2).line (3, 18, 3, 21).line (21, 18, 21, 21); break;
                case "pharmacy": p.rect (10, 4, 4, 16).rect (4, 10, 16, 4); break;
                case "police": p.m (12, 2).l (20, 5).l (19, 14).q (17, 19, 12, 22).q (7, 19, 5, 14).l (4, 5).z ().star (12, 11, 4, 2, 5); break;
                case "post": p.rect (3, 6, 18, 12).m (3, 6).l (12, 13).l (21, 6); break;
                case "bank": p.poly ({ 2, 9, 12, 3, 22, 9 }).rect (4, 10, 2, 8).rect (9, 10, 2, 8).rect (13, 10, 2, 8).rect (18, 10, 2, 8).rect (2, 19, 20, 2); break;
                case "atm": p.rect (3, 4, 18, 12).rect (6, 7, 12, 4).rect (8, 16, 8, 5); break;
                case "museum": p.poly ({ 2, 8, 12, 2, 22, 8 }).rect (4, 9, 2, 9).rect (11, 9, 2, 9).rect (18, 9, 2, 9).rect (2, 19, 20, 2); break;
                case "church": p.rect (11, 1, 2, 7).rect (8, 3, 8, 2).poly ({ 5, 12, 12, 8, 19, 12, 19, 21, 5, 21 }).rect (10, 15, 4, 6); break;
                case "mosque": p.m (6, 12).q (6, 4, 12, 3).q (18, 4, 18, 12).z ().rect (5, 12, 14, 9).rect (20, 6, 2, 15).rect (2, 6, 2, 15); break;
                case "synagogue": p.poly ({ 12, 2, 20, 16, 4, 16 }).poly ({ 12, 22, 4, 8, 20, 8 }); break;
                case "library": p.rect (4, 4, 4, 16).rect (9, 4, 4, 16).poly ({ 14, 5, 18, 4, 21, 19, 17, 20 }); break;
                case "stadium": p.ellipse (12, 12, 10, 7).ellipse (12, 12, 5, 3); break;
                case "cinema": p.rect (3, 8, 14, 10).poly ({ 17, 11, 21, 8, 21, 18, 17, 15 }).circle (6, 5, 3).circle (13, 5, 3); break;
                case "theatre": p.m (3, 4).l (11, 4).l (11, 10).q (11, 15, 7, 15).q (3, 15, 3, 10).z ().m (13, 9).l (21, 9).l (21, 15).q (21, 20, 17, 20).q (13, 20, 13, 15).z (); break;
                case "shopping": p.m (5, 8).l (19, 8).l (18, 21).l (6, 21).z ().m (9, 8).q (9, 3, 12, 3).q (15, 3, 15, 8); break;
                case "supermarket": p.m (2, 4).l (5, 4).l (8, 15).l (19, 15).l (21, 7).l (6, 7).circle (9, 19, 1.5).circle (17, 19, 1.5); break;
                case "camping": p.poly ({ 12, 3, 22, 20, 2, 20 }).poly ({ 12, 12, 15, 20, 9, 20 }); break;
                case "viewpoint": p.circle (7, 12, 4).circle (17, 12, 4).rect (10, 10, 4, 3).rect (5, 5, 4, 4).rect (15, 5, 4, 4); break;
                case "beach": p.m (3, 11).q (12, 1, 21, 11).z ().line (12, 6, 16, 20).m (2, 21).q (7, 18, 12, 21).q (17, 24, 22, 21); break;
                case "peak": p.poly ({ 2, 20, 9, 7, 13, 13, 16, 9, 22, 20 }); break;
                case "lighthouse": p.poly ({ 9, 21, 10, 7, 14, 7, 15, 21 }).rect (9, 3, 6, 4).line (16, 5, 22, 3).line (16, 5, 22, 7).line (8, 5, 2, 3).line (8, 5, 2, 7); break;
                case "harbour": p.circle (12, 4, 2).line (12, 6, 12, 20).line (8, 9, 16, 9).m (4, 14).q (5, 20, 12, 20).q (19, 20, 20, 14); break;
                case "castle": p.poly ({ 3, 21, 3, 6, 6, 6, 6, 9, 9, 9, 9, 6, 15, 6, 15, 9, 18, 9, 18, 6, 21, 6, 21, 21 }).rect (10, 14, 4, 7); break;
                case "monument": p.poly ({ 10, 4, 12, 2, 14, 4, 15, 18, 9, 18 }).rect (6, 18, 12, 3); break;
                case "zoo": p.circle (12, 14, 6).circle (6, 7, 2.5).circle (18, 7, 2.5).circle (9, 3, 2).circle (15, 3, 2); break;
                case "university": p.poly ({ 2, 8, 12, 3, 22, 8, 12, 13 }).m (6, 10).l (6, 16).q (12, 20, 18, 16).l (18, 10).line (21, 8, 21, 15); break;
                case "fire-station": p.m (12, 22).c (5, 22, 4, 14, 8, 9).c (9, 12, 10, 13, 11, 13).c (10, 8, 12, 4, 15, 2).c (15, 7, 20, 10, 20, 16).c (20, 20, 17, 22, 12, 22).z (); break;
                case "embassy": p.rect (5, 3, 2, 18).poly ({ 7, 4, 19, 4, 16, 8, 19, 12, 7, 12 }); break;
                case "wifi": p.circle (12, 18, 2).arc (12, 18, 6, 225, 315).arc (12, 18, 10, 225, 315).arc (12, 18, 14, 225, 315); break;
                case "accessible": p.circle (11, 3, 2).circle (11, 16, 5).line (11, 6, 11, 12).line (11, 12, 18, 12).line (18, 12, 20, 18).line (8, 9, 14, 9); break;
                default: p.circle (12, 12, 8); break;
            }
            return p.str ();
        }

        private static void register_poi () {
            Stencils.category ("points-of-interest", _("Points of Interest"), "draw-shapes-symbolic", StencilGroup.PLANS);
            string[,] list = {
                { "train", "Railway Station Pin", "train railway station", "#1f5fae" },
                { "tram", "Tram Stop", "tram streetcar light rail", "#1f5fae" },
                { "ferry", "Ferry Terminal", "ferry boat terminal", "#1f5fae" },
                { "taxi", "Taxi Rank", "taxi cab rank", "#f5a300" },
                { "bike", "Bicycle Rental", "bike share bicycle rental", "#2e7d32" },
                { "ev", "Charging Station", "ev charging electric vehicle", "#2e7d32" },
                { "toilets", "Toilets", "toilets restroom wc", "#5a3a8f" },
                { "restaurant", "Restaurant", "restaurant food dining", "#e65100" },
                { "cafe", "Cafe", "cafe coffee", "#8d5a2b" },
                { "hotel", "Hotel", "hotel accommodation lodging", "#5a3a8f" },
                { "pharmacy", "Pharmacy", "pharmacy chemist drugstore", "#2e7d32" },
                { "police", "Police", "police station", "#1f4e79" },
                { "post", "Post Office", "post office mail", "#c62828" },
                { "bank", "Bank", "bank finance", "#3a3a3a" },
                { "atm", "Cash Machine", "atm cash machine", "#3a3a3a" },
                { "museum", "Museum", "museum gallery", "#6d4c41" },
                { "church", "Church", "church chapel worship", "#6d4c41" },
                { "mosque", "Mosque", "mosque worship", "#6d4c41" },
                { "synagogue", "Synagogue", "synagogue worship", "#6d4c41" },
                { "library", "Library", "library books", "#6d4c41" },
                { "stadium", "Stadium", "stadium arena sports", "#2e7d32" },
                { "cinema", "Cinema", "cinema movie theatre film", "#ad1457" },
                { "theatre", "Theatre", "theatre performing arts", "#ad1457" },
                { "shopping", "Shopping", "shopping mall store", "#ad1457" },
                { "supermarket", "Supermarket", "supermarket grocery", "#e65100" },
                { "camping", "Campsite", "camping campsite tent", "#2e7d32" },
                { "viewpoint", "Viewpoint", "viewpoint scenic lookout", "#2e7d32" },
                { "beach", "Beach", "beach seaside", "#0288d1" },
                { "peak", "Mountain Peak", "mountain peak summit", "#5d4037" },
                { "lighthouse", "Lighthouse", "lighthouse coast", "#0288d1" },
                { "harbour", "Harbour", "harbour port marina anchor", "#0288d1" },
                { "castle", "Castle", "castle fortress historic", "#6d4c41" },
                { "monument", "Monument", "monument memorial obelisk", "#6d4c41" },
                { "zoo", "Zoo", "zoo animals park", "#2e7d32" },
                { "university", "University", "university college campus", "#1f4e79" },
                { "fire-station", "Fire Station", "fire station brigade", "#c62828" },
                { "embassy", "Embassy", "embassy consulate", "#1f4e79" },
                { "wifi", "Free Wi-Fi", "wifi internet hotspot", "#1f5fae" },
                { "accessible", "Accessible Entrance", "wheelchair accessible entrance", "#1f5fae" }
            };
            for (int i = 0; i < list.length[0]; i++) poi ("poi-" + list[i, 0], _(list[i, 1]), list[i, 2], g (list[i, 0]), list[i, 3]);
        }

        public static void register () {
            register_furniture ();
            register_garden ();
            register_poi ();
        }
    }
}
