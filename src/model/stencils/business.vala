namespace Singularity.Apps.Draw {

    public class StencilsBusiness {
        private static string n (double v) {
            return StencilKit.n (v);
        }

        public static void register () {
            flowchart ();
            crossfunctional ();
            org ();
            value_stream ();
            tqm ();
            epc ();
            idef0 ();
            dfd ();
            workflow ();
        }

        private static void flowchart () {
            Stencils.use_category ("flowchart");
            Stencils.shape ("flow-parallel-mode", _("Parallel Mode"), 140, 30, "synchronization parallel iso")
                .box (100, 30)
                .line ("M0 5 H100 M0 25 H100")
                .defaults ("fill-kind:none")
                .label (0, 30, 100, 20)
                .port (50, 5).port (100, 15).port (50, 25).port (0, 15);
            Stencils.shape ("flow-auxiliary-operation", _("Auxiliary Operation"), 80, 80, "offline operation square iso")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .ports_box ();
            Stencils.shape ("flow-offline-storage", _("Offline Storage"), 90, 80, "archive file triangle")
                .fill (StencilKit.poly ({ 0, 0, 100, 0, 50, 100 }))
                .line ("M38 76 H62")
                .label (20, 6, 60, 40)
                .port (50, 0).port (75, 50).port (50, 100).port (25, 50);
            Stencils.shape ("flow-magnetic-tape", _("Sequential Access Storage"), 80, 80, "magnetic tape reel")
                .fill ("M50 100 A50 50 0 1 1 100 50 V100 Z")
                .label (15, 15, 70, 70)
                .port (50, 0).port (100, 50).port (50, 100).port (0, 50);
            Stencils.shape ("flow-comm-link", _("Communication Link"), 140, 60, "transmission lightning line")
                .line (StencilKit.poly ({ 0, 30, 58, 30, 42, 70, 100, 70 }, false))
                .fill (StencilKit.poly ({ 100, 70, 84, 58, 86, 80 }))
                .defaults ("fill-kind:none")
                .label (0, 80, 100, 20)
                .port (0, 30).port (100, 70);
            Stencils.shape ("flow-transfer", _("Transfer"), 120, 60, "move transport")
                .fill (StencilKit.poly ({ 0, 30, 60, 30, 60, 0, 100, 50, 60, 100, 60, 70, 0, 70 }))
                .label (4, 32, 58, 36)
                .ports_box ();
            Stencils.shape ("flow-hexagon-long", _("Long Preparation"), 160, 60, "initialization setup")
                .fill (StencilKit.poly ({ 12, 0, 88, 0, 100, 50, 88, 100, 12, 100, 0, 50 }))
                .label (12, 4, 76, 92)
                .ports_box ();
            Stencils.shape ("flow-start-circle", _("Start Circle"), 60, 60, "begin terminal")
                .fill (StencilKit.circle (50, 50, 50))
                .defaults ("fill:#d7f0e0;stroke:#2e7d32")
                .label (10, 10, 80, 80)
                .ports_box ();
        }

        private static void crossfunctional () {
            Stencils.category ("cff", _("Cross-Functional Flowchart"), "draw-swimlane-symbolic", StencilGroup.BUSINESS);
            Stencils.shape ("cff-divider-v", _("Vertical Phase Separator"), 30, 400, "phase stage divider column")
                .box (30, 100)
                .line ("M15 0 V100")
                .shade (StencilKit.rect (0, 0, 30, 8))
                .defaults ("dash:dash;fill:#e6ecf2")
                .label (-60, 0, 150, 8)
                .port (15, 0).port (15, 100);
            Stencils.shape ("cff-divider-h", _("Horizontal Phase Separator"), 600, 30, "phase stage divider row")
                .box (100, 30)
                .line ("M0 15 H100")
                .shade (StencilKit.rect (0, 0, 5, 30))
                .defaults ("dash:dash;fill:#e6ecf2")
                .label (6, 0, 60, 14)
                .port (0, 15).port (100, 15);
            Stencils.shape ("cff-lane-header-h", _("Lane Header"), 40, 160, "swimlane title band")
                .shade (StencilKit.rect (0, 0, 100, 100))
                .defaults ("fill:#dde9f1;bold:1")
                .ports_box ();
            Stencils.shape ("cff-lane-header-v", _("Column Header"), 200, 34, "swimlane title band")
                .shade (StencilKit.rect (0, 0, 100, 100))
                .defaults ("fill:#dde9f1;bold:1")
                .ports_box ();
            Stencils.shape ("cff-title-band", _("Title Bar"), 600, 36, "flowchart title header")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("fill:#3a6ea5;stroke:#1f4e79;text-color:#ffffff;bold:1;font-size:14")
                .text (_("Process Title"))
                .ports_box ();
            Stencils.shape ("cff-phase-header", _("Phase Header"), 200, 34, "phase stage title")
                .fill (StencilKit.poly ({ 0, 0, 92, 0, 100, 50, 92, 100, 0, 100 }))
                .defaults ("fill:#f1f8ee;stroke:#2e7d32;bold:1")
                .text (_("Phase"))
                .ports_box ();
        }

        private static string avatar (double x, double y, double s) {
            return StencilKit.circle (x + s / 2, y + s * 0.34, s * 0.2);
        }

        private static string shoulders (double x, double y, double s) {
            return "M%s %s C%s %s %s %s %s %s C%s %s %s %s %s %s Z".printf (
                n (x + s * 0.12), n (y + s * 0.92), n (x + s * 0.16), n (y + s * 0.62), n (x + s * 0.34), n (y + s * 0.58), n (x + s * 0.5), n (y + s * 0.58),
                n (x + s * 0.66), n (y + s * 0.58), n (x + s * 0.84), n (y + s * 0.62), n (x + s * 0.88), n (y + s * 0.92));
        }

        private static unowned StencilDef org_card (string kind, string name, string keywords, string text_default) {
            unowned StencilDef d = Stencils.shape (kind, name, 180, 64, keywords)
                .box (180, 64)
                .fill (StencilKit.rrect (0, 0, 180, 64, 8))
                .shade (StencilKit.circle (32, 32, 22))
                .solid (avatar (10, 10, 44), "@light")
                .solid (shoulders (10, 10, 44), "@light")
                .text (text_default)
                .defaults ("halign:left")
                .label (62, 4, 114, 56)
                .ports_box ();
            return d;
        }

        private static void org () {
            Stencils.use_category ("org");
            org_card ("org2-executive", _("Executive"), "ceo director head chief", _("Name\nExecutive"))
                .solid (StencilKit.rrect (0, 0, 180, 10, 4), "@dark")
                .defaults ("fill:#e3eefb;stroke:#1f4e79;stroke-width:2");
            org_card ("org2-manager", _("Department Manager"), "manager lead head", _("Name\nManager"))
                .solid (StencilKit.rect (0, 58, 180, 6), "@dark")
                .defaults ("fill:#eef5fc;stroke:#3a6ea5");
            org_card ("org2-consultant", _("Consultant"), "external advisor contractor", _("Name\nConsultant"))
                .defaults ("dash:dash;fill:#f7f2fc;stroke:#5a3a8f");
            org_card ("org2-vacancy", _("Vacancy"), "open position hiring", _("Vacant\nPosition"))
                .defaults ("dash:dash;fill:#f2f2f2;stroke:#7f7f7f;text-color:#595959;italic:1");
            org_card ("org2-staff", _("Staff Member"), "employee worker", _("Name\nRole"))
                .defaults ("fill:#ffffff;stroke:#595959");
            org_card ("org2-assistant", _("Staff Assistant"), "assistant secretary support", _("Name\nAssistant"))
                .line ("M0 56 H180")
                .defaults ("fill:#fdf4e8;stroke:#c75c12");
            Stencils.shape ("org2-three-positions", _("Three Positions"), 200, 110, "multiple positions team stack")
                .box (200, 110)
                .fill (StencilKit.rrect (20, 0, 180, 70, 6))
                .fill (StencilKit.rrect (10, 20, 180, 70, 6))
                .fill (StencilKit.rrect (0, 40, 180, 70, 6))
                .text (_("Position\n3 people"))
                .label (8, 44, 164, 62)
                .port (90, 40).port (190, 55).port (90, 110).port (0, 75);
            Stencils.shape ("org2-team-frame", _("Team Frame"), 400, 220, "team group department box")
                .fill (StencilKit.rrect (0, 0, 100, 100, 4))
                .defaults ("dash:dash;fill:#f4f8fc80;stroke:#3a6ea5;valign:top;halign:left;bold:1")
                .text (_("Team"))
                .label (3, 2, 94, 12)
                .as_container ()
                .ports_box ();
            Stencils.shape ("org2-photo-card", _("Photo Card"), 110, 140, "person picture portrait employee")
                .box (110, 140)
                .fill (StencilKit.rrect (0, 0, 110, 140, 8))
                .shade (StencilKit.circle (55, 44, 34))
                .solid (StencilKit.circle (55, 34, 13), "@light")
                .solid ("M31 72 C33 58 43 54 55 54 C67 54 77 58 79 72 C72 76 63 78 55 78 C47 78 38 76 31 72 Z", "@light")
                .text (_("Name\nTitle"))
                .label (4, 82, 102, 54)
                .ports_box ();
            Stencils.shape ("org2-compact", _("Compact Position"), 140, 40, "small box role")
                .fill (StencilKit.rrect (0, 0, 100, 100, 12))
                .defaults ("font-size:10")
                .text (_("Name"))
                .ports_box ();
            Stencils.shape ("org2-top-band", _("Banded Position"), 170, 80, "card header title")
                .box (170, 80)
                .fill (StencilKit.rect (0, 0, 170, 80))
                .solid (StencilKit.rect (0, 0, 170, 22), "@dark")
                .text (_("Name\nTitle"))
                .label (6, 26, 158, 50)
                .ports_box ();
        }

        private static string factory () {
            return StencilKit.poly ({ 0, 100, 0, 30, 25, 10, 25, 30, 50, 10, 50, 30, 75, 10, 75, 0, 90, 0, 90, 30, 100, 30, 100, 100 });
        }

        private static void value_stream () {
            Stencils.category ("vsm", _("Value Stream Map"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            Stencils.shape ("vsm-process", _("Process Box"), 120, 90, "operation step lean")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M0 28 H100")
                .text (_("Process"))
                .label (4, 2, 92, 24)
                .ports_box ();
            Stencils.shape ("vsm-data-box", _("Data Box"), 120, 100, "cycle time uptime metrics")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("halign:left;valign:top;font-size:9")
                .text (_("C/T =\nC/O =\nUptime =\nShifts ="))
                .label (4, 2, 92, 96)
                .ports_box ();
            Stencils.shape ("vsm-supplier", _("Supplier"), 100, 80, "outside source company factory")
                .fill (factory ())
                .text (_("Supplier"))
                .label (4, 40, 92, 56)
                .ports_box ();
            Stencils.shape ("vsm-customer", _("Customer"), 100, 80, "outside company factory")
                .fill (factory ())
                .text (_("Customer"))
                .label (4, 40, 92, 56)
                .ports_box ();
            Stencils.shape ("vsm-inventory", _("Inventory"), 60, 54, "stock wip triangle")
                .fill (StencilKit.poly ({ 50, 0, 100, 100, 0, 100 }))
                .defaults ("fill:#fff6c9;stroke:#b8930b;bold:1")
                .text ("I")
                .label (30, 40, 40, 56)
                .port (50, 0).port (75, 50).port (50, 100).port (25, 50);
            Stencils.shape ("vsm-push-arrow", _("Push Arrow"), 140, 40, "push material flow striped")
                .fill (StencilKit.rect (0, 30, 10, 40) + " " + StencilKit.rect (18, 30, 10, 40) + " " + StencilKit.rect (36, 30, 10, 40) + " " + StencilKit.poly ({ 54, 30, 76, 30, 76, 0, 100, 50, 76, 100, 76, 70, 54, 70 }))
                .defaults ("fill:#1e1e1e")
                .label (0, 100, 100, 20)
                .port (0, 50).port (100, 50);
            Stencils.shape ("vsm-supermarket", _("Supermarket"), 70, 70, "kanban pull stock")
                .line ("M0 0 H100 V100 H0 M100 33 H0 M100 66 H0")
                .defaults ("fill-kind:none;stroke-width:2")
                .label_below ()
                .ports_box ();
            Stencils.shape ("vsm-fifo", _("FIFO Lane"), 160, 50, "first in first out lane")
                .line ("M0 5 H100 M0 95 H100")
                .defaults ("fill-kind:none;stroke-width:2;bold:1")
                .text (_("FIFO"))
                .label (0, 10, 100, 80)
                .port (0, 50).port (100, 50);
            Stencils.shape ("vsm-kaizen", _("Kaizen Burst"), 110, 80, "improvement lightning burst")
                .fill (StencilKit.star (12, 50, 50, 50, 50, 0.72))
                .defaults ("fill:#fff1cc;stroke:#c62828;stroke-width:2")
                .label (22, 26, 56, 48)
                .ports_box ();
            Stencils.shape ("vsm-truck", _("Truck Shipment"), 110, 60, "delivery lorry transport")
                .box (110, 60)
                .fill (StencilKit.rect (0, 2, 70, 42))
                .fill ("M72 14 H92 L110 30 V44 H72 Z")
                .fill (StencilKit.circle (20, 50, 9))
                .fill (StencilKit.circle (90, 50, 9))
                .label (2, 4, 66, 38)
                .ports_box ();
            Stencils.shape ("vsm-operator", _("Operator"), 40, 40, "worker person staff")
                .fill (StencilKit.circle (50, 30, 22))
                .line ("M8 100 A42 42 0 0 1 92 100")
                .label_below ()
                .ports_box ();
            Stencils.shape ("vsm-timeline", _("Timeline Segment"), 160, 40, "lead time value added")
                .line ("M0 20 H50 V80 H100")
                .defaults ("fill-kind:none;stroke-width:2")
                .label (0, 80, 100, 20)
                .port (0, 20).port (100, 80);
            Stencils.shape ("vsm-withdrawal", _("Withdrawal"), 90, 60, "pull material arrow")
                .line ("M10 80 A40 55 0 1 1 90 80")
                .fill (StencilKit.poly ({ 90, 100, 78, 70, 100, 72 }))
                .defaults ("fill-kind:none;stroke-width:3")
                .label_below ()
                .port (10, 80).port (90, 100);
            Stencils.shape ("vsm-electronic-info", _("Electronic Information Flow"), 140, 50, "edi signal zigzag")
                .line (StencilKit.poly ({ 0, 30, 45, 30, 55, 70, 88, 70 }, false))
                .fill (StencilKit.poly ({ 100, 70, 84, 58, 84, 82 }))
                .defaults ("fill-kind:none;stroke-width:2")
                .label (0, 80, 100, 20)
                .port (0, 30).port (100, 70);
            Stencils.shape ("vsm-manual-info", _("Manual Information Flow"), 140, 30, "paper information arrow")
                .line ("M0 50 H88")
                .fill (StencilKit.poly ({ 100, 50, 84, 20, 84, 80 }))
                .defaults ("fill-kind:none;stroke-width:2")
                .label (0, 80, 100, 20)
                .port (0, 50).port (100, 50);
            Stencils.shape ("vsm-production-kanban", _("Production Kanban"), 70, 50, "card signal")
                .fill ("M0 0 H82 L100 18 V100 H0 Z")
                .label (4, 20, 92, 76)
                .ports_box ();
            Stencils.shape ("vsm-withdrawal-kanban", _("Withdrawal Kanban"), 70, 50, "card move")
                .fill ("M0 0 H82 L100 18 V100 H0 Z")
                .solid (StencilKit.rect (0, 36, 100, 28), "@shade")
                .label (4, 4, 92, 30)
                .ports_box ();
            Stencils.shape ("vsm-signal-kanban", _("Signal Kanban"), 60, 54, "batch signal triangle")
                .fill (StencilKit.poly ({ 0, 0, 100, 0, 50, 100 }))
                .label (20, 6, 60, 40)
                .port (50, 0).port (50, 100);
            Stencils.shape ("vsm-kanban-post", _("Kanban Post"), 50, 60, "collection box")
                .line ("M0 0 V60 H100 V0 M50 60 V100 M30 100 H70")
                .defaults ("fill-kind:none;stroke-width:2")
                .label_below ()
                .port (50, 100).port (50, 0);
            Stencils.shape ("vsm-safety-stock", _("Safety Stock"), 50, 60, "buffer stock")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M0 20 H100 M0 40 H100 M0 60 H100 M0 80 H100")
                .label_below ()
                .ports_box ();
            Stencils.shape ("vsm-pull-circle", _("Physical Pull"), 60, 60, "pull circular arrow")
                .line (StencilKit.arc (50, 50, 40, 40, -60, 240))
                .fill (StencilKit.poly ({ 30, 16, 12, 22, 22, 4 }))
                .defaults ("fill-kind:none;stroke-width:3")
                .label_below ()
                .ports_box ();
            Stencils.shape ("vsm-go-see", _("Go See Scheduling"), 70, 40, "glasses observe")
                .fill (StencilKit.circle (25, 55, 22) + " " + StencilKit.circle (75, 55, 22))
                .line ("M47 50 Q50 42 53 50 M3 50 L0 30 M97 50 L100 30")
                .label_below ()
                .ports_box ();
            Stencils.shape ("vsm-control", _("Production Control"), 120, 70, "scheduling department")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("bold:1")
                .text (_("Production Control"))
                .ports_box ();
            Stencils.shape ("vsm-load-leveling", _("Load Leveling"), 90, 40, "heijunka balance")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M0 50 H100")
                .dark (StencilKit.rect (6, 12, 12, 26) + " " + StencilKit.rect (26, 12, 12, 26) + " " + StencilKit.rect (6, 62, 12, 26) + " " + StencilKit.rect (46, 62, 12, 26))
                .label_below ()
                .ports_box ();
        }

        private static void tqm () {
            Stencils.category ("tqm", _("Quality and Cause and Effect"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            Stencils.shape ("tqm-sipoc", _("SIPOC Table"), 500, 200, "suppliers inputs process outputs customers")
                .box (500, 200)
                .fill (StencilKit.rect (0, 0, 500, 200))
                .shade (StencilKit.rect (0, 0, 500, 32))
                .line ("M100 0 V200 M200 0 V200 M300 0 V200 M400 0 V200")
                .defaults ("bold:1;valign:top")
                .text (_("Suppliers        Inputs        Process        Outputs        Customers"))
                .label (0, 4, 500, 26)
                .ports_box ();
            Stencils.shape ("tqm-control-chart", _("Control Chart"), 300, 180, "spc ucl lcl process control")
                .line ("M0 0 V100 H100")
                .ink (StencilKit.dashed_line (0, 20, 100, 20, 3, 2) + " " + StencilKit.dashed_line (0, 80, 100, 80, 3, 2), "#c62828")
                .ink ("M0 50 H100", "#2e7d32")
                .ink (StencilKit.poly ({ 5, 55, 15, 40, 25, 60, 35, 45, 45, 52, 55, 30, 65, 58, 75, 48, 85, 66, 95, 42 }, false), "#1f4e79")
                .defaults ("fill-kind:none;halign:left;valign:top;font-size:9")
                .text ("UCL")
                .label (2, 8, 30, 10)
                .ports_box ();
            Stencils.shape ("tqm-pareto", _("Pareto Chart"), 260, 180, "pareto bar cumulative")
                .line ("M0 0 V100 H100")
                .fill (StencilKit.rect (6, 20, 14, 80) + " " + StencilKit.rect (24, 45, 14, 55) + " " + StencilKit.rect (42, 65, 14, 35) + " " + StencilKit.rect (60, 80, 14, 20) + " " + StencilKit.rect (78, 90, 14, 10))
                .ink (StencilKit.poly ({ 13, 20, 31, 8, 49, 3, 67, 1, 85, 0 }, false), "#c62828")
                .label (0, 100, 100, 14)
                .ports_box ();
            Stencils.shape ("tqm-fishbone-head", _("Fishbone Head"), 120, 90, "cause effect problem ishikawa")
                .fill ("M0 0 H55 C85 0 100 30 100 50 C100 70 85 100 55 100 H0 Z")
                .defaults ("fill:#fdecea;stroke:#b3261e;bold:1")
                .text (_("Problem"))
                .label (4, 6, 80, 88)
                .port (0, 50).port (100, 50);
            Stencils.shape ("tqm-fishbone-spine", _("Fishbone Spine"), 400, 30, "backbone cause effect")
                .line ("M0 50 H100")
                .defaults ("fill-kind:none;stroke-width:4")
                .label (0, 100, 100, 30)
                .port (0, 50).port (100, 50);
            Stencils.shape ("tqm-fishbone-bone-up", _("Cause Bone, Upper"), 120, 100, "cause category rib")
                .line ("M0 0 L100 100")
                .defaults ("fill-kind:none;stroke-width:2.5;halign:left;valign:top")
                .label (0, -24, 100, 20)
                .port (0, 0).port (100, 100);
            Stencils.shape ("tqm-fishbone-bone-down", _("Cause Bone, Lower"), 120, 100, "cause category rib")
                .line ("M0 100 L100 0")
                .defaults ("fill-kind:none;stroke-width:2.5;halign:left;valign:bottom")
                .label (0, 104, 100, 20)
                .port (0, 100).port (100, 0);
            Stencils.shape ("tqm-category-box", _("Cause Category"), 120, 40, "man machine method material measurement environment")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("fill:#e3eefb;stroke:#1f4e79;bold:1")
                .text (_("Category"))
                .ports_box ();
            Stencils.shape ("tqm-cause", _("Cause"), 120, 26, "sub cause reason")
                .line ("M0 100 H100")
                .defaults ("fill-kind:none;halign:left;font-size:10")
                .label (2, 0, 96, 96)
                .port (0, 100).port (100, 100);
            string pdca = "";
            string[] q = {
                StencilKit.arc (50, 50, 50, 50, 180, 270) + " L50 50 Z",
                StencilKit.arc (50, 50, 50, 50, 270, 360) + " L50 50 Z",
                StencilKit.arc (50, 50, 50, 50, 0, 90) + " L50 50 Z",
                StencilKit.arc (50, 50, 50, 50, 90, 180) + " L50 50 Z"
            };
            foreach (string part in q) pdca += part + " ";
            Stencils.shape ("tqm-pdca", _("PDCA Cycle"), 120, 120, "plan do check act deming")
                .solid (q[0], "#5b9bd5")
                .solid (q[1], "#6fbf5a")
                .solid (q[2], "#f5c518")
                .solid (q[3], "#e5534b")
                .line (pdca.strip ())
                .defaults ("bold:1;font-size:10")
                .text (_("Plan  Do\nAct  Check"))
                .label (15, 25, 70, 50)
                .ports_box ();
            Stencils.shape ("tqm-checklist", _("Check Sheet"), 80, 100, "checklist tally audit")
                .fill ("M0 0 H100 V100 H0 Z")
                .line ("M30 20 H90 M30 45 H90 M30 70 H90")
                .line (StencilKit.rect (8, 12, 14, 14) + " " + StencilKit.rect (8, 37, 14, 14) + " " + StencilKit.rect (8, 62, 14, 14))
                .ink ("M10 19 L15 24 L22 12 M10 44 L15 49 L22 37", "#2e7d32")
                .label_below ()
                .ports_box ();
            Stencils.shape ("tqm-histogram", _("Histogram"), 200, 140, "distribution frequency")
                .line ("M0 0 V100 H100")
                .fill (StencilKit.rect (8, 80, 12, 20) + " " + StencilKit.rect (20, 55, 12, 45) + " " + StencilKit.rect (32, 25, 12, 75) + " " + StencilKit.rect (44, 10, 12, 90) + " " + StencilKit.rect (56, 30, 12, 70) + " " + StencilKit.rect (68, 60, 12, 40) + " " + StencilKit.rect (80, 85, 12, 15))
                .label (0, 100, 100, 14)
                .ports_box ();
        }

        private static void epc () {
            Stencils.category ("epc", _("Event-Driven Process Chain"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            Stencils.shape ("epc-event", _("Event"), 130, 60, "state trigger hexagon")
                .fill (StencilKit.poly ({ 14, 0, 86, 0, 100, 50, 86, 100, 14, 100, 0, 50 }))
                .defaults ("fill:#f7d6e6;stroke:#8e1c5a")
                .label (12, 4, 76, 92)
                .ports_box ();
            Stencils.shape ("epc-function", _("Function"), 130, 60, "activity task")
                .fill (StencilKit.rrect (0, 0, 100, 100, 14))
                .defaults ("fill:#d7f0e0;stroke:#2e7d32")
                .ports_box ();
            string[] conn_names = { _("XOR Connector"), _("AND Connector"), _("OR Connector") };
            string[] conn_ids = { "xor", "and", "or" };
            string[] conn_text = { "XOR", "AND", "OR" };
            for (int i = 0; i < 3; i++) {
                Stencils.shape ("epc-%s".printf (conn_ids[i]), conn_names[i], 40, 40, "rule connector operator %s".printf (conn_ids[i]))
                    .fill (StencilKit.circle (50, 50, 50))
                    .defaults ("bold:1;font-size:8")
                    .text (conn_text[i])
                    .label (0, 0, 100, 100)
                    .ports_box ();
            }
            Stencils.shape ("epc-process-path", _("Process Path"), 130, 60, "process interface link")
                .fill (StencilKit.rrect (0, 0, 100, 100, 14))
                .fill (StencilKit.poly ({ 30, 60, 80, 60, 90, 80, 80, 100, 30, 100, 40, 80 }))
                .defaults ("fill:#d7f0e0;stroke:#2e7d32")
                .label (4, 4, 92, 52)
                .ports_box ();
            Stencils.shape ("epc-org-unit", _("Organizational Unit"), 130, 60, "department role responsible")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .line ("M14 14 V86")
                .defaults ("fill:#fff6c9;stroke:#b8930b")
                .label (18, 12, 72, 76)
                .ports_box ();
            Stencils.shape ("epc-information", _("Information Object"), 130, 60, "data document input output")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("fill:#e3eefb;stroke:#1f4e79")
                .ports_box ();
            Stencils.shape ("epc-application", _("Application System"), 130, 60, "software system it")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M8 0 V100 M92 0 V100")
                .defaults ("fill:#ece4f7;stroke:#5a3a8f")
                .label (10, 4, 80, 92)
                .ports_box ();
            Stencils.shape ("epc-position", _("Position"), 130, 60, "role job person")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .line ("M14 14 V86 M20 14 V86")
                .defaults ("fill:#fff6c9;stroke:#b8930b")
                .label (22, 12, 68, 76)
                .ports_box ();
        }

        private static void idef0 () {
            Stencils.category ("idef0", _("IDEF0"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            Stencils.shape ("idef0-function", _("Activity Box"), 160, 90, "function icom input control output mechanism")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("fill:#ffffff;stroke:#1e1e1e;stroke-width:2")
                .text (_("Activity\nA0"))
                .label (4, 4, 92, 92)
                .port (0, 30).port (0, 70).port (30, 0).port (70, 0).port (100, 30).port (100, 70).port (30, 100).port (70, 100);
            Stencils.shape ("idef0-tunnel-start", _("Tunneled Arrow Start"), 60, 30, "tunnel hidden arrow")
                .line ("M20 50 H100 M4 20 A18 30 0 0 0 4 80 M14 20 A18 30 0 0 0 14 80")
                .defaults ("fill-kind:none")
                .label (0, 80, 100, 20)
                .port (0, 50).port (100, 50);
            Stencils.shape ("idef0-tunnel-end", _("Tunneled Arrow End"), 60, 30, "tunnel hidden arrow")
                .line ("M0 50 H78 M86 20 A18 30 0 0 1 86 80 M96 20 A18 30 0 0 1 96 80")
                .defaults ("fill-kind:none")
                .label (0, 80, 100, 20)
                .port (0, 50).port (100, 50);
            Stencils.shape ("idef0-frame", _("Diagram Frame"), 700, 480, "context border title block node")
                .box (700, 480)
                .fill (StencilKit.rect (0, 0, 700, 480))
                .line ("M0 440 H700 M110 440 V480 M560 440 V480")
                .defaults ("fill:#ffffff;halign:left;valign:top")
                .text (_("NODE:        TITLE:                                                                  NUMBER:"))
                .label (6, 446, 688, 30)
                .as_container ()
                .ports_box ();
        }

        private static void dfd () {
            Stencils.category ("dfd", _("Data Flow Diagram"), "draw-shapes-symbolic", StencilGroup.SOFTWARE);
            Stencils.shape ("dfd-gs-process", _("Process (Gane-Sarson)"), 110, 120, "process transform function")
                .fill (StencilKit.rrect (0, 0, 100, 100, 10))
                .line ("M0 22 H100 M0 82 H100")
                .text (_("Process"))
                .label (4, 24, 92, 56)
                .ports_box ();
            Stencils.shape ("dfd-gs-entity", _("External Entity (Gane-Sarson)"), 110, 70, "source sink terminator")
                .shade ("M8 8 H100 V100 H8 Z")
                .fill (StencilKit.rect (0, 0, 92, 92))
                .label (4, 4, 84, 84)
                .ports_box ();
            Stencils.shape ("dfd-gs-store", _("Data Store (Gane-Sarson)"), 150, 44, "file database store")
                .solid (StencilKit.rect (0, 0, 100, 100), "@fill")
                .line ("M100 0 H0 V100 H100 M18 0 V100")
                .text (_("D1  Store"))
                .label (20, 4, 76, 92)
                .ports_box ();
            Stencils.shape ("dfd-yd-process", _("Process (Yourdon)"), 100, 100, "bubble process circle demarco")
                .fill (StencilKit.circle (50, 50, 50))
                .text (_("Process"))
                .label (14, 14, 72, 72)
                .ports_box ();
            Stencils.shape ("dfd-yd-entity", _("External Entity (Yourdon)"), 110, 60, "terminator source sink")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .ports_box ();
            Stencils.shape ("dfd-yd-store", _("Data Store (Yourdon)"), 150, 40, "file database two lines")
                .solid (StencilKit.rect (0, 0, 100, 100), "@fill")
                .line ("M0 0 H100 M0 100 H100")
                .text (_("Data Store"))
                .port (0, 50).port (100, 50).port (50, 0).port (50, 100);
            Stencils.shape ("dfd-control-process", _("Control Process"), 100, 100, "control transform dashed")
                .solid (StencilKit.circle (50, 50, 50), "@fill")
                .line (StencilKit.dashed_ellipse (50, 50, 50, 50, 16))
                .label (14, 14, 72, 72)
                .ports_box ();
            Stencils.shape ("dfd-multiple-process", _("Multiple Process"), 100, 100, "process group composite")
                .fill (StencilKit.circle (50, 50, 50))
                .line (StencilKit.circle (50, 50, 44))
                .label (16, 16, 68, 68)
                .ports_box ();
        }

        private static void workflow () {
            Stencils.category ("workflow", _("Workflow and Audit"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            Stencils.shape ("wf-approve", _("Approval"), 50, 50, "approved accept ok check")
                .fill (StencilKit.circle (50, 50, 50))
                .ink ("M26 52 L44 70 L76 32", "@light")
                .defaults ("fill:#2e7d32;stroke:#1b5e20;stroke-width:3")
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-reject", _("Rejection"), 50, 50, "rejected deny cancel")
                .fill (StencilKit.circle (50, 50, 50))
                .ink ("M32 32 L68 68 M68 32 L32 68", "@light")
                .defaults ("fill:#c62828;stroke:#8e1c1c;stroke-width:3")
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-asme-operation", _("Operation (ASME)"), 50, 50, "asme operation circle")
                .fill (StencilKit.circle (50, 50, 50))
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-asme-transport", _("Transport (ASME)"), 70, 40, "asme move arrow")
                .fill (StencilKit.poly ({ 0, 30, 60, 30, 60, 0, 100, 50, 60, 100, 60, 70, 0, 70 }))
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-asme-inspection", _("Inspection (ASME)"), 50, 50, "asme check square")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-asme-delay", _("Delay (ASME)"), 60, 50, "asme wait d")
                .fill ("M0 0 H50 A50 50 0 0 1 50 100 H0 Z")
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-asme-storage", _("Storage (ASME)"), 60, 50, "asme store inverted triangle")
                .fill (StencilKit.poly ({ 0, 0, 100, 0, 50, 100 }))
                .label_below ()
                .port (50, 0).port (50, 100);
            Stencils.shape ("wf-asme-combined", _("Operation and Inspection"), 50, 50, "asme combined")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .fill (StencilKit.circle (50, 50, 44))
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-person", _("Person"), 40, 60, "user actor role")
                .fill (StencilKit.circle (50, 22, 20))
                .fill ("M8 100 V74 C8 54 26 46 50 46 C74 46 92 54 92 74 V100 Z")
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-email", _("Email"), 60, 44, "mail message envelope notification")
                .fill (StencilKit.envelope_body (0, 0, 100, 100))
                .line (StencilKit.envelope_flap (0, 0, 100, 100))
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-system", _("System"), 70, 60, "computer application screen")
                .fill (StencilKit.rrect (0, 0, 100, 76, 4))
                .shade (StencilKit.rect (8, 8, 84, 60))
                .fill ("M38 76 H62 L66 92 H34 Z M20 92 H80 V100 H20 Z")
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-signature", _("Signature"), 110, 44, "sign approve pen")
                .line ("M0 90 H100")
                .ink ("M6 70 C14 40 22 40 24 64 C26 84 34 30 44 50 C52 66 58 58 64 48 C70 38 76 60 86 54", "@stroke")
                .defaults ("fill-kind:none")
                .label_below ()
                .port (0, 90).port (100, 90);
            Stencils.shape ("wf-timer", _("Wait Timer"), 50, 50, "clock timeout schedule")
                .fill (StencilKit.circle (50, 50, 50))
                .line ("M50 18 V50 L72 62")
                .label_below ()
                .ports_box ();
            Stencils.shape ("wf-database", _("Records"), 50, 60, "records ledger archive")
                .fill ("M0 12 V88 A50 12 0 0 0 100 88 V12 A50 12 0 0 0 0 12 Z")
                .line ("M0 12 A50 12 0 0 0 100 12 M0 40 A50 12 0 0 0 100 40 M0 64 A50 12 0 0 0 100 64")
                .label_below ()
                .ports_box ();
        }
    }
}
