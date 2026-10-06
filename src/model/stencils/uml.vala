namespace Singularity.Apps.Draw {

    public class StencilsUml {
        public static void register () {
            class_diagram ();
            component_diagram ();
            usecase_diagram ();
            activity_diagram ();
            state_diagram ();
            sequence_diagram ();
            composite_diagram ();
        }

        private static unowned StencilDef classifier (string kind, string name, string keywords, string text_default, bool three = true) {
            unowned StencilDef d = Stencils.shape (kind, name, 170, 120, keywords)
                .box (170, 120)
                .fill (StencilKit.rect (0, 0, 170, 120))
                .line (three ? "M0 36 H170 M0 78 H170" : "M0 36 H170")
                .defaults ("bold:1")
                .text (text_default)
                .label (4, 2, 162, 32)
                .ports_eight ();
            return d;
        }

        private static void class_diagram () {
            Stencils.category ("uml-class", _("UML Class and Object"), "draw-uml-symbolic", StencilGroup.SOFTWARE);
            classifier ("uml2-abstract-class", _("Abstract Class"), "abstract class italic", _("AbstractClass"))
                .defaults ("italic:1");
            classifier ("uml2-enumeration", _("Enumeration"), "enum enumeration literals", _("«enumeration»\nName"), false);
            classifier ("uml2-datatype", _("Data Type"), "datatype value type", _("«dataType»\nName"));
            classifier ("uml2-primitive", _("Primitive Type"), "primitive type", _("«primitive»\nName"), false);
            classifier ("uml2-stereotype", _("Stereotype"), "stereotype profile", _("«stereotype»\nName"), false);
            classifier ("uml2-metaclass", _("Metaclass"), "metaclass profile", _("«metaclass»\nName"), false);
            Stencils.shape ("uml2-class-template", _("Template Class"), 180, 130, "template generic parameter class")
                .box (180, 130)
                .fill (StencilKit.rect (0, 12, 164, 118))
                .line ("M0 46 H164 M0 88 H164")
                .solid (StencilKit.rect (120, 0, 60, 24), "@fill")
                .line (StencilKit.dashed_rect (120, 0, 60, 24, 4, 3))
                .defaults ("bold:1")
                .text (_("TemplateClass"))
                .label (4, 14, 116, 30)
                .ports_eight ();
            Stencils.shape ("uml2-compartment", _("Compartment"), 170, 50, "attributes operations list members")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("halign:left;valign:top")
                .text (_("+ member: Type"))
                .label (3, 4, 94, 92)
                .ports_box ();
            Stencils.shape ("uml2-class-simple", _("Class (Name Only)"), 140, 44, "class collapsed name")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("bold:1")
                .text (_("ClassName"))
                .ports_box ();
            Stencils.shape ("uml2-interface-ball", _("Interface (Ball)"), 30, 30, "interface lollipop provided")
                .fill (StencilKit.circle (50, 50, 50))
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-object", _("Object Instance"), 150, 44, "object instance underline")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("underline:1")
                .text (_("object : Class"))
                .ports_box ();
            Stencils.shape ("uml2-object-slots", _("Object with Slots"), 160, 90, "object instance slots values")
                .box (160, 90)
                .fill (StencilKit.rect (0, 0, 160, 90))
                .line ("M0 30 H160")
                .defaults ("underline:1")
                .text (_("object : Class"))
                .label (4, 2, 152, 26)
                .ports_eight ();
            Stencils.shape ("uml2-package-tab", _("Package (Name in Tab)"), 180, 120, "package namespace folder")
                .box (180, 120)
                .fill (StencilKit.rect (0, 0, 72, 22))
                .fill (StencilKit.rect (0, 22, 180, 98))
                .defaults ("font-size:10;bold:1")
                .text (_("package"))
                .label (4, 1, 64, 20)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-model", _("Model"), 180, 120, "model package triangle")
                .box (180, 120)
                .fill (StencilKit.rect (0, 0, 72, 22))
                .fill (StencilKit.rect (0, 22, 180, 98))
                .line (StencilKit.poly ({ 160, 30, 170, 44, 150, 44 }))
                .defaults ("valign:top;bold:1")
                .text (_("Model"))
                .label (4, 26, 140, 22)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-constraint", _("Constraint"), 140, 30, "constraint ocl rule braces")
                .solid (StencilKit.rect (0, 0, 100, 100), "#ffffff00")
                .defaults ("italic:1")
                .text ("{constraint}")
                .label (0, 0, 100, 100)
                .ports_box ();
            Stencils.shape ("uml2-note-anchor", _("Note with Anchor"), 150, 90, "comment note anchored")
                .box (150, 90)
                .fill ("M40 0 H134 L150 16 V64 H40 Z")
                .shade ("M134 0 V16 H150 Z")
                .line (StencilKit.dashed_line (40, 64, 0, 90, 4, 3))
                .defaults ("fill:#fff6c9;stroke:#b59a2b;halign:left")
                .label (44, 4, 100, 58)
                .port (0, 90).port (95, 0).port (150, 40);
        }

        private static string component_icon (double x, double y) {
            return StencilKit.rect (x + 4, y, 16, 20) + " " + StencilKit.rect (x, y + 4, 8, 4) + " " + StencilKit.rect (x, y + 12, 8, 4);
        }

        private static void component_diagram () {
            Stencils.category ("uml-component", _("UML Component and Deployment"), "draw-uml-symbolic", StencilGroup.SOFTWARE);
            Stencils.shape ("uml2-component", _("Component"), 170, 90, "component module service")
                .box (170, 90)
                .fill (StencilKit.rect (0, 0, 170, 90))
                .fill (component_icon (138, 8))
                .defaults ("bold:1")
                .text (_("«component»\nName"))
                .label (6, 6, 128, 78)
                .ports_eight ();
            Stencils.shape ("uml2-component-classic", _("Component (UML 1)"), 170, 90, "component classic tabs")
                .box (170, 90)
                .fill (StencilKit.rect (12, 0, 158, 90))
                .fill (StencilKit.rect (0, 20, 24, 14))
                .fill (StencilKit.rect (0, 56, 24, 14))
                .text (_("Component"))
                .label (28, 4, 138, 82)
                .ports_box ();
            Stencils.shape ("uml2-subsystem", _("Subsystem"), 200, 130, "subsystem component container")
                .box (200, 130)
                .fill (StencilKit.rect (0, 0, 200, 130))
                .fill (component_icon (168, 8))
                .defaults ("valign:top;bold:1")
                .text (_("«subsystem»\nName"))
                .label (6, 4, 156, 36)
                .as_container ()
                .ports_eight ();
            Stencils.shape ("uml2-provided-interface", _("Provided Interface"), 90, 30, "lollipop provided interface ball")
                .box (90, 30)
                .line ("M0 15 H60")
                .fill (StencilKit.circle (75, 15, 14))
                .label (40, 30, 70, 18)
                .port (0, 15).port (89, 15);
            Stencils.shape ("uml2-required-interface", _("Required Interface"), 90, 34, "socket required interface")
                .box (90, 34)
                .line ("M0 17 H70 M86 2 A15 15 0 0 0 86 32")
                .defaults ("fill-kind:none")
                .label (40, 34, 70, 18)
                .port (0, 17).port (71, 17);
            Stencils.shape ("uml2-assembly", _("Assembly Connector"), 120, 34, "ball socket assembly")
                .box (120, 34)
                .line ("M0 17 H48 M72 17 H120 M68 2 A15 15 0 0 0 68 32")
                .fill (StencilKit.circle (60, 17, 11))
                .label (30, 34, 60, 18)
                .port (0, 17).port (120, 17);
            Stencils.shape ("uml2-port", _("Port"), 18, 18, "port interaction point")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-artifact", _("Artifact"), 160, 80, "artifact file executable jar")
                .box (160, 80)
                .fill (StencilKit.rect (0, 0, 160, 80))
                .fill ("M134 8 H146 L152 14 V30 H134 Z")
                .line ("M146 8 V14 H152")
                .text (_("«artifact»\nfile.jar"))
                .label (6, 6, 124, 68)
                .ports_eight ();
            Stencils.shape ("uml2-device", _("Device"), 170, 110, "device node hardware 3d")
                .box (170, 110)
                .fill ("M0 16 H154 V110 H0 Z")
                .shade ("M0 16 L16 0 H170 L154 16 Z")
                .shade ("M154 16 L170 0 V94 L154 110 Z")
                .defaults ("bold:1")
                .text (_("«device»\nName"))
                .label (6, 20, 142, 86)
                .ports_eight ();
            Stencils.shape ("uml2-exec-env", _("Execution Environment"), 170, 110, "execution environment runtime container node")
                .box (170, 110)
                .fill ("M0 16 H154 V110 H0 Z")
                .shade ("M0 16 L16 0 H170 L154 16 Z")
                .shade ("M154 16 L170 0 V94 L154 110 Z")
                .defaults ("valign:top")
                .text (_("«executionEnvironment»\nName"))
                .label (6, 20, 142, 40)
                .as_container ()
                .ports_eight ();
            Stencils.shape ("uml2-node-instance", _("Node Instance"), 170, 110, "node instance underline")
                .box (170, 110)
                .fill ("M0 16 H154 V110 H0 Z")
                .shade ("M0 16 L16 0 H170 L154 16 Z")
                .shade ("M154 16 L170 0 V94 L154 110 Z")
                .defaults ("underline:1")
                .text (_("server : Node"))
                .label (6, 20, 142, 86)
                .ports_eight ();
            Stencils.shape ("uml2-deployment-spec", _("Deployment Specification"), 150, 80, "deployment spec descriptor")
                .box (150, 80)
                .fill ("M0 0 H130 L150 20 V80 H0 Z")
                .line ("M130 0 V20 H150")
                .text (_("«deployment spec»\nName"))
                .label (6, 6, 120, 68)
                .ports_box ();
        }

        private static string stick_figure (double cx, double top, double h) {
            double hr = h * 0.13;
            return "%s M%s %s V%s M%s %s H%s M%s %s L%s %s L%s %s".printf (StencilKit.circle (cx, top + hr, hr),
                StencilKit.n (cx), StencilKit.n (top + 2 * hr), StencilKit.n (top + h * 0.64),
                StencilKit.n (cx - h * 0.25), StencilKit.n (top + h * 0.38), StencilKit.n (cx + h * 0.25),
                StencilKit.n (cx - h * 0.25), StencilKit.n (top + h), StencilKit.n (cx), StencilKit.n (top + h * 0.64),
                StencilKit.n (cx + h * 0.25), StencilKit.n (top + h));
        }

        private static void usecase_diagram () {
            Stencils.category ("uml-usecase", _("UML Use Case"), "draw-uml-symbolic", StencilGroup.SOFTWARE);
            Stencils.shape ("uml2-actor-box", _("Actor (Classifier)"), 150, 70, "actor classifier box")
                .box (150, 70)
                .fill (StencilKit.rect (0, 0, 150, 70))
                .line (stick_figure (134, 6, 30))
                .text (_("«actor»\nName"))
                .label (6, 4, 112, 62)
                .ports_box ();
            Stencils.shape ("uml2-actor-system", _("System Actor"), 50, 50, "system actor external computer")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M20 30 H80 V64 H20 Z M50 64 V78 M34 80 H66")
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-usecase-ext", _("Use Case with Extension Points"), 170, 100, "use case extension points")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .line ("M4 40 H96")
                .text (_("Use Case"))
                .label (15, 10, 70, 28)
                .ports_eight ();
            Stencils.shape ("uml2-usecase-rect", _("Use Case (Classifier)"), 160, 70, "use case classifier rectangle")
                .box (160, 70)
                .fill (StencilKit.rect (0, 0, 160, 70))
                .line (StencilKit.ellipse (140, 16, 14, 8))
                .text (_("Use Case"))
                .label (6, 4, 118, 62)
                .ports_box ();
            Stencils.shape ("uml2-system-boundary", _("System Boundary"), 320, 400, "system boundary subject container")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("valign:top;bold:1")
                .text (_("System"))
                .label (2, 1, 96, 8)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-actor-hidden", _("Actor (Filled Head)"), 40, 80, "actor person user")
                .box (40, 80)
                .dark (StencilKit.circle (20, 11, 10))
                .line ("M20 21 V52 M0 32 H40 M0 80 L20 52 L40 80")
                .defaults ("fill-kind:none")
                .label_below ()
                .ports_box ();
        }

        private static void activity_diagram () {
            Stencils.category ("uml-activity", _("UML Activity"), "draw-uml-symbolic", StencilGroup.SOFTWARE);
            Stencils.shape ("uml2-action", _("Action"), 130, 60, "action activity step")
                .fill (StencilKit.rrect (0, 0, 100, 100, 20))
                .ports_box ();
            Stencils.shape ("uml2-call-behavior", _("Call Behavior Action"), 130, 60, "call behavior rake")
                .box (130, 60)
                .fill (StencilKit.rrect (0, 0, 130, 60, 12))
                .line ("M112 38 V54 M104 46 H120 M104 46 V54 M120 46 V54")
                .label (6, 4, 100, 52)
                .ports_box ();
            Stencils.shape ("uml2-object-node", _("Object Node"), 120, 50, "object node data flow")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .ports_box ();
            Stencils.shape ("uml2-datastore-node", _("Data Store Node"), 130, 60, "datastore object node")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .text (_("«datastore»\nName"))
                .ports_box ();
            Stencils.shape ("uml2-central-buffer", _("Central Buffer Node"), 130, 60, "central buffer node")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .text (_("«centralBuffer»\nName"))
                .ports_box ();
            Stencils.shape ("uml2-pin", _("Pin"), 14, 14, "pin input output action")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-activity-param", _("Activity Parameter Node"), 90, 34, "parameter activity input output")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .ports_box ();
            Stencils.shape ("uml2-send-signal", _("Send Signal Action"), 130, 60, "send signal event pentagon")
                .fill (StencilKit.poly ({ 0, 0, 80, 0, 100, 50, 80, 100, 0, 100 }))
                .label (4, 4, 76, 92)
                .ports_box ();
            Stencils.shape ("uml2-accept-event", _("Accept Event Action"), 130, 60, "accept event receive signal")
                .fill (StencilKit.poly ({ 0, 0, 100, 0, 100, 100, 0, 100, 20, 50 }))
                .label (22, 4, 74, 92)
                .ports_box ();
            Stencils.shape ("uml2-accept-time", _("Accept Time Event"), 34, 44, "time event hourglass wait")
                .fill (StencilKit.poly ({ 0, 0, 100, 0, 0, 100, 100, 100 }))
                .label_below ()
                .port (50, 0).port (50, 100);
            Stencils.shape ("uml2-flow-final", _("Flow Final"), 30, 30, "flow final end x")
                .fill (StencilKit.circle (50, 50, 50))
                .line ("M15 15 L85 85 M85 15 L15 85")
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-join-v", _("Fork or Join (Vertical)"), 8, 140, "fork join synchronization bar")
                .dark (StencilKit.rect (0, 0, 100, 100))
                .label (0, -20, 100, 18)
                .port (50, 0).port (100, 25).port (100, 50).port (100, 75).port (50, 100).port (0, 25).port (0, 50).port (0, 75);
            Stencils.shape ("uml2-partition-v", _("Activity Partition (Vertical)"), 200, 480, "partition swimlane column")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M0 7 H100")
                .defaults ("bold:1")
                .text (_("Partition"))
                .label (2, 0, 96, 7)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-partition-h", _("Activity Partition (Horizontal)"), 560, 150, "partition swimlane row")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M5 0 V100")
                .defaults ("valign:top;halign:left;bold:1")
                .text (_("Partition"))
                .label (6, 3, 60, 20)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-interruptible", _("Interruptible Region"), 300, 180, "interruptible activity region dashed")
                .solid (StencilKit.rrect (0, 0, 100, 100, 8), "@fill")
                .line (StencilKit.dashed_rect (1, 1, 98, 98, 3, 2))
                .defaults ("fill:#f7f9fb;valign:top;halign:left")
                .label (3, 3, 94, 14)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-expansion-region", _("Expansion Region"), 300, 180, "expansion region iterative parallel")
                .box (300, 180)
                .solid (StencilKit.rrect (0, 10, 300, 170, 12), "@fill")
                .line (StencilKit.dashed_rect (2, 12, 296, 166, 6, 4))
                .fill ("M20 0 H80 V20 H20 Z M35 0 V20 M50 0 V20 M65 0 V20")
                .defaults ("valign:top;halign:left")
                .text ("«iterative»")
                .label (8, 22, 284, 18)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-expansion-node", _("Expansion Node"), 60, 18, "expansion node collection")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M25 0 V100 M50 0 V100 M75 0 V100")
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-activity-frame", _("Activity Frame"), 480, 320, "activity frame diagram border")
                .fill (StencilKit.rrect (0, 0, 100, 100, 3))
                .defaults ("valign:top;halign:left;bold:1")
                .text (_("Activity Name"))
                .label (2, 1, 96, 8)
                .as_container ()
                .ports_box ();
        }

        private static void state_diagram () {
            Stencils.category ("uml-state", _("UML State Machine"), "draw-uml-symbolic", StencilGroup.SOFTWARE);
            Stencils.shape ("uml2-state-detail", _("State with Activities"), 160, 90, "state entry do exit")
                .box (160, 90)
                .fill (StencilKit.rrect (0, 0, 160, 90, 14))
                .line ("M0 30 H160")
                .defaults ("bold:1")
                .text (_("State"))
                .label (6, 2, 148, 26)
                .ports_eight ();
            Stencils.shape ("uml2-state-composite", _("Composite State"), 320, 200, "composite state region container")
                .box (320, 200)
                .fill (StencilKit.rrect (0, 0, 320, 200, 14))
                .line ("M0 30 H320")
                .defaults ("bold:1")
                .text (_("Composite State"))
                .label (6, 2, 308, 26)
                .as_container ()
                .ports_eight ();
            Stencils.shape ("uml2-submachine", _("Submachine State"), 160, 70, "submachine reference")
                .box (160, 70)
                .fill (StencilKit.rrect (0, 0, 160, 70, 14))
                .line (StencilKit.ellipse (130, 56, 6, 4) + " " + StencilKit.ellipse (148, 56, 6, 4) + " M136 56 H142")
                .text (_("sub : Machine"))
                .label (6, 4, 148, 44)
                .ports_eight ();
            Stencils.shape ("uml2-choice", _("Choice"), 30, 30, "choice pseudostate decision")
                .fill (StencilKit.poly ({ 50, 0, 100, 50, 50, 100, 0, 50 }))
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-junction", _("Junction"), 16, 16, "junction pseudostate dot")
                .dark (StencilKit.circle (50, 50, 50))
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-history-shallow", _("Shallow History"), 30, 30, "history pseudostate h")
                .fill (StencilKit.circle (50, 50, 50))
                .line ("M34 26 V74 M66 26 V74 M34 50 H66")
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-history-deep", _("Deep History"), 30, 30, "deep history pseudostate h star")
                .fill (StencilKit.circle (50, 50, 50))
                .line ("M26 28 V72 M52 28 V72 M26 50 H52 M70 24 V46 M60 30 L80 40 M80 30 L60 40")
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-entry-point", _("Entry Point"), 20, 20, "entry point pseudostate")
                .fill (StencilKit.circle (50, 50, 50))
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-exit-point", _("Exit Point"), 20, 20, "exit point pseudostate x")
                .fill (StencilKit.circle (50, 50, 50))
                .line ("M18 18 L82 82 M82 18 L18 82")
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-terminate", _("Terminate"), 26, 26, "terminate pseudostate x")
                .line ("M0 0 L100 100 M100 0 L0 100")
                .defaults ("fill-kind:none;stroke-width:2")
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-state-final-region", _("Region Separator"), 300, 10, "orthogonal region divider dashed")
                .line (StencilKit.dashed_line (0, 50, 100, 50, 3, 2))
                .defaults ("fill-kind:none")
                .label (0, 100, 100, 200)
                .port (0, 50).port (100, 50);
        }

        private static unowned StencilDef lifeline_icon (string kind, string name, string keywords) {
            unowned StencilDef d = Stencils.shape (kind, name, 90, 300, keywords)
                .box (90, 300)
                .line (StencilKit.dashed_line (45, 60, 45, 300, 6, 5))
                .label (0, 60, 90, 20)
                .port (45, 0).port (45, 300);
            return d;
        }

        private static string fragment_tab (double w) {
            return "M0 0 H%s V14 L%s 22 H0".printf (StencilKit.n (w), StencilKit.n (w - 8));
        }

        private static void sequence_diagram () {
            Stencils.category ("uml-sequence", _("UML Sequence and Interaction"), "draw-uml-symbolic", StencilGroup.SOFTWARE);
            lifeline_icon ("uml2-lifeline-actor", _("Actor Lifeline"), "actor lifeline sequence")
                .line (stick_figure (45, 0, 50));
            lifeline_icon ("uml2-lifeline-boundary", _("Boundary Lifeline"), "boundary interface lifeline")
                .fill (StencilKit.circle (52, 26, 20))
                .line ("M18 10 V42 M18 26 H32");
            lifeline_icon ("uml2-lifeline-control", _("Control Lifeline"), "control controller lifeline")
                .fill (StencilKit.circle (45, 30, 22))
                .line ("M40 2 L48 8 L40 14");
            lifeline_icon ("uml2-lifeline-entity", _("Entity Lifeline"), "entity data lifeline")
                .fill (StencilKit.circle (45, 26, 22))
                .line ("M20 52 H70");
            Stencils.shape ("uml2-destruction", _("Destruction"), 24, 24, "destroy delete x lifeline")
                .line ("M0 0 L100 100 M100 0 L0 100")
                .defaults ("fill-kind:none;stroke-width:2.5")
                .label_below ()
                .ports_box ();
            string[] ops = { "alt", "opt", "loop", "par", "break", "critical", "neg", "strict", "seq", "ignore", "consider", "assert" };
            foreach (string op in ops) {
                unowned StencilDef d = Stencils.shape ("uml2-fragment-%s".printf (op), _("Combined Fragment (%s)").printf (op), 360, 200, "combined fragment interaction operator %s".printf (op))
                    .box (360, 200)
                    .solid (StencilKit.rect (0, 0, 360, 200), "@fill")
                    .line (StencilKit.rect (0, 0, 360, 200))
                    .line (fragment_tab (64))
                    .defaults ("fill:#ffffff00;bold:1;font-size:10;halign:left")
                    .text (op)
                    .label (4, 1, 52, 18)
                    .as_container ()
                    .ports_box ();
                if (op == "alt" || op == "par") d.line (StencilKit.dashed_line (0, 100, 360, 100, 6, 4));
            }
            Stencils.shape ("uml2-interaction-use", _("Interaction Use"), 300, 70, "interaction use ref reference")
                .box (300, 70)
                .fill (StencilKit.rect (0, 0, 300, 70))
                .line (fragment_tab (44))
                .text (_("ref  Interaction"))
                .label (48, 14, 248, 52)
                .ports_box ();
            Stencils.shape ("uml2-sequence-frame", _("Sequence Diagram Frame"), 520, 400, "sd frame interaction diagram")
                .box (520, 400)
                .solid (StencilKit.rect (0, 0, 520, 400), "@fill")
                .line (StencilKit.rect (0, 0, 520, 400))
                .line (fragment_tab (140))
                .defaults ("fill:#ffffff00;halign:left;font-size:10;bold:1")
                .text (_("sd Interaction"))
                .label (4, 1, 128, 18)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-interaction-overview", _("Interaction Overview Frame"), 520, 400, "interaction overview frame")
                .box (520, 400)
                .solid (StencilKit.rect (0, 0, 520, 400), "@fill")
                .line (StencilKit.rect (0, 0, 520, 400))
                .line (fragment_tab (140))
                .defaults ("fill:#ffffff00;halign:left;font-size:10;bold:1")
                .text (_("interaction Overview"))
                .label (4, 1, 128, 18)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-gate", _("Gate"), 12, 12, "gate message point")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .label_below ()
                .ports_box ();
            Stencils.shape ("uml2-state-invariant", _("State Invariant"), 110, 34, "state invariant condition lifeline")
                .fill (StencilKit.rrect (0, 0, 100, 100, 30))
                .text ("{condition}")
                .ports_box ();
            Stencils.shape ("uml2-continuation", _("Continuation"), 130, 34, "continuation label")
                .fill (StencilKit.rrect (0, 0, 100, 100, 50))
                .ports_box ();
            Stencils.shape ("uml2-duration-constraint", _("Duration Constraint"), 40, 120, "duration time constraint interval")
                .line ("M0 0 H40 M0 100 H40 M20 0 V100 M12 12 L20 0 L28 12 M12 88 L20 100 L28 88")
                .defaults ("fill-kind:none;halign:left")
                .text ("{d..3d}")
                .label (46, 40, 200, 20)
                .port (0, 0).port (0, 100);
            Stencils.shape ("uml2-message-marker", _("Message Direction Marker"), 50, 16, "communication message arrow")
                .line ("M0 50 H90")
                .dark (StencilKit.poly ({ 100, 50, 80, 10, 80, 90 }))
                .defaults ("fill-kind:none")
                .label (-20, -130, 140, 110)
                .port (0, 50).port (100, 50);
            Stencils.shape ("uml2-timing-frame", _("Timing Diagram Frame"), 520, 260, "timing diagram frame lifeline states")
                .box (520, 260)
                .solid (StencilKit.rect (0, 0, 520, 260), "@fill")
                .line (StencilKit.rect (0, 0, 520, 260))
                .line (fragment_tab (100))
                .line ("M30 22 V260 M30 140 H520")
                .defaults ("fill:#ffffff00;halign:left;font-size:10;bold:1")
                .text (_("timing Name"))
                .label (4, 1, 90, 18)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-timing-state", _("State Timeline"), 300, 60, "timing state lifeline step")
                .box (300, 100)
                .line ("M0 20 H80 V80 H180 V20 H240 V50 H300")
                .defaults ("fill-kind:none;stroke-width:2")
                .label (0, 100, 300, 30)
                .port (0, 20).port (300, 50);
            Stencils.shape ("uml2-timing-value", _("Value Lifeline"), 300, 40, "timing value hexagon band")
                .fill ("M0 50 L8 0 H92 L100 50 L92 100 H8 Z")
                .label (8, 4, 84, 92)
                .port (0, 50).port (100, 50);
        }

        private static void composite_diagram () {
            Stencils.category ("uml-composite", _("UML Composite Structure and Profile"), "draw-uml-symbolic", StencilGroup.SOFTWARE);
            Stencils.shape ("uml2-structured-class", _("Structured Class"), 320, 200, "structured classifier parts container")
                .box (320, 200)
                .fill (StencilKit.rect (0, 0, 320, 200))
                .line ("M0 32 H320")
                .defaults ("bold:1")
                .text (_("StructuredClass"))
                .label (4, 2, 312, 28)
                .as_container ()
                .ports_eight ();
            Stencils.shape ("uml2-part", _("Part"), 140, 50, "part property role")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .text (_("part : Type"))
                .ports_box ();
            Stencils.shape ("uml2-part-reference", _("Part Reference"), 140, 50, "reference property dashed")
                .solid (StencilKit.rect (0, 0, 100, 100), "@fill")
                .line (StencilKit.dashed_rect (0, 0, 100, 100, 5, 3))
                .text (_("ref : Type"))
                .ports_box ();
            Stencils.shape ("uml2-collaboration", _("Collaboration"), 260, 160, "collaboration dashed ellipse")
                .solid (StencilKit.ellipse (50, 50, 50, 50), "@fill")
                .line (StencilKit.dashed_ellipse (50, 50, 50, 50, 28))
                .line (StencilKit.dashed_line (6, 30, 94, 30, 3, 2))
                .defaults ("valign:top")
                .text (_("Collaboration"))
                .label (20, 8, 60, 20)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-collaboration-use", _("Collaboration Use"), 150, 70, "collaboration use dashed ellipse")
                .solid (StencilKit.ellipse (50, 50, 50, 50), "@fill")
                .line (StencilKit.dashed_ellipse (50, 50, 50, 50, 20))
                .text (_("use : Collaboration"))
                .label (12, 12, 76, 76)
                .ports_box ();
            Stencils.shape ("uml2-profile", _("Profile"), 180, 120, "profile package stereotype")
                .box (180, 120)
                .fill (StencilKit.rect (0, 0, 72, 22))
                .fill (StencilKit.rect (0, 22, 180, 98))
                .defaults ("valign:top")
                .text (_("«profile»\nName"))
                .label (4, 26, 172, 36)
                .as_container ()
                .ports_box ();
            Stencils.shape ("uml2-extension", _("Extension Arrow"), 120, 20, "extension metaclass arrow filled")
                .line ("M0 50 H84")
                .dark (StencilKit.poly ({ 100, 50, 84, 5, 84, 95 }))
                .defaults ("fill-kind:none")
                .label (0, 100, 100, 100)
                .port (0, 50).port (100, 50);
        }
    }
}
