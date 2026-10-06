namespace Singularity.Apps.Draw {

    public class StencilsDatabase {
        public static void register () {
            Stencils.category ("er", _("Entity Relationship"), "draw-shapes-symbolic", StencilGroup.SOFTWARE);
            chen ();
            tables ();
            objects ();
        }

        private static void chen () {
            Stencils.shape ("er-entity", _("Entity"), 130, 60, "entity chen strong")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("bold:1")
                .text (_("Entity"))
                .ports_eight ();
            Stencils.shape ("er-weak-entity", _("Weak Entity"), 130, 60, "weak entity chen double")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line (StencilKit.rect (4, 8, 92, 84))
                .defaults ("bold:1")
                .text (_("Weak Entity"))
                .label (6, 10, 88, 80)
                .ports_eight ();
            Stencils.shape ("er-attribute", _("Attribute"), 110, 50, "attribute property chen ellipse")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .text (_("attribute"))
                .label (12, 12, 76, 76)
                .ports_box ();
            Stencils.shape ("er-key-attribute", _("Key Attribute"), 110, 50, "primary key attribute underline")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .defaults ("underline:1")
                .text (_("id"))
                .label (12, 12, 76, 76)
                .ports_box ();
            Stencils.shape ("er-partial-key", _("Partial Key Attribute"), 110, 50, "discriminator partial key weak")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .line (StencilKit.dashed_line (30, 70, 70, 70, 4, 3))
                .text (_("key"))
                .label (12, 12, 76, 56)
                .ports_box ();
            Stencils.shape ("er-multivalued", _("Multivalued Attribute"), 110, 50, "multivalued attribute double ellipse")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .line (StencilKit.ellipse (50, 50, 45, 40))
                .text (_("values"))
                .label (14, 14, 72, 72)
                .ports_box ();
            Stencils.shape ("er-derived", _("Derived Attribute"), 110, 50, "derived computed attribute dashed")
                .solid (StencilKit.ellipse (50, 50, 50, 50), "@fill")
                .line (StencilKit.dashed_ellipse (50, 50, 50, 50, 18))
                .text (_("derived"))
                .label (12, 12, 76, 76)
                .ports_box ();
            Stencils.shape ("er-composite-attribute", _("Composite Attribute"), 110, 50, "composite attribute parts")
                .fill (StencilKit.ellipse (50, 50, 50, 50))
                .line ("M50 100 V120")
                .text (_("address"))
                .label (12, 12, 76, 76)
                .ports_box ();
            Stencils.shape ("er-relationship", _("Relationship"), 120, 70, "relationship chen diamond association")
                .fill (StencilKit.poly ({ 50, 0, 100, 50, 50, 100, 0, 50 }))
                .text (_("relates"))
                .label (20, 20, 60, 60)
                .ports_box ();
            Stencils.shape ("er-identifying", _("Identifying Relationship"), 120, 70, "identifying weak relationship double diamond")
                .fill (StencilKit.poly ({ 50, 0, 100, 50, 50, 100, 0, 50 }))
                .line (StencilKit.poly ({ 50, 10, 88, 50, 50, 90, 12, 50 }))
                .text (_("owns"))
                .label (24, 24, 52, 52)
                .ports_box ();
            Stencils.shape ("er-isa", _("Specialization (ISA)"), 70, 60, "isa inheritance subtype generalization")
                .fill (StencilKit.poly ({ 50, 100, 100, 0, 0, 0 }))
                .defaults ("font-size:10;bold:1")
                .text ("ISA")
                .label (25, 5, 50, 45)
                .port (50, 0).port (50, 100).port (75, 50).port (25, 50);
            Stencils.shape ("er-associative", _("Associative Entity"), 160, 80, "associative entity diamond in box")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line (StencilKit.poly ({ 50, 4, 96, 50, 50, 96, 4, 50 }))
                .text (_("Enrollment"))
                .label (18, 24, 64, 52)
                .ports_eight ();
        }

        private static unowned StencilDef table (string kind, string name, string keywords, int rows, bool keys) {
            double h = 30 + rows * 16;
            unowned StencilDef d = Stencils.shape (kind, name, 180, h, keywords)
                .box (180, h)
                .fill (StencilKit.rect (0, 0, 180, h))
                .shade (StencilKit.rect (0, 0, 180, 24))
                .defaults ("halign:left;valign:top;font-size:10")
                .label (6, 4, 170, h - 6)
                .ports_eight ();
            if (keys) {
                d.line (StencilKit.line (32, 24, 32, h));
                d.label (4, 4, 172, h - 6);
            }
            var t = new StringBuilder (_("Table"));
            for (int i = 0; i < rows; i++) {
                t.append_c ('\n');
                if (keys) t.append (i == 0 ? "PK   id" : (i == 1 ? "FK   ref_id" : "        column"));
                else t.append (i == 0 ? "id" : "column");
            }
            d.text (t.str);
            return d;
        }

        private static void tables () {
            table ("er-table-3", _("Table, 3 Columns"), "table entity crow foot ie columns", 3, true);
            table ("er-table-5", _("Table, 5 Columns"), "table entity crow foot ie columns", 5, true);
            table ("er-table-8", _("Table, 8 Columns"), "table entity crow foot ie columns", 8, true);
            table ("er-table-plain", _("Table without Keys"), "table entity simple columns", 4, false);
            Stencils.shape ("er-table-header", _("Table Header"), 180, 26, "table title entity name")
                .shade (StencilKit.rect (0, 0, 100, 100))
                .defaults ("bold:1")
                .text (_("Table"))
                .ports_box ();
            Stencils.shape ("er-table-row", _("Table Row"), 180, 20, "column row field")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M18 0 V100")
                .defaults ("halign:left;font-size:10")
                .text ("         column")
                .label (1, 0, 98, 100)
                .port (0, 50).port (100, 50);
        }

        private static void objects () {
            Stencils.shape ("er-view", _("View"), 160, 110, "view virtual table query")
                .solid (StencilKit.rect (0, 0, 100, 100), "@fill")
                .line (StencilKit.dashed_rect (0, 0, 100, 100, 5, 3))
                .shade (StencilKit.rect (0, 0, 100, 22))
                .defaults ("halign:left;valign:top;font-size:10")
                .text (_("«view»\nName"))
                .label (3, 2, 94, 96)
                .ports_eight ();
            Stencils.shape ("er-procedure", _("Stored Procedure"), 150, 60, "stored procedure function routine")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line ("M8 0 V100 M92 0 V100")
                .text (_("procedure()"))
                .label (10, 4, 80, 92)
                .ports_box ();
            Stencils.shape ("er-index", _("Index"), 120, 44, "index key lookup")
                .fill (StencilKit.rrect (0, 0, 100, 100, 20))
                .line (StencilKit.circle (14, 50, 7) + " M21 50 H34 M30 50 V60")
                .text (_("idx_name"))
                .label (36, 4, 60, 92)
                .ports_box ();
            Stencils.shape ("er-trigger", _("Trigger"), 120, 44, "trigger event database")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .line (StencilKit.poly ({ 16, 20, 10, 52, 17, 52, 12, 80, 26, 42, 18, 42, 22, 20 }))
                .text (_("trigger"))
                .label (30, 4, 66, 92)
                .ports_box ();
            Stencils.shape ("er-sequence", _("Sequence"), 120, 44, "sequence counter autoincrement")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("italic:1")
                .text (_("seq_name"))
                .ports_box ();
            Stencils.shape ("er-schema", _("Schema"), 400, 280, "schema database namespace container")
                .box (400, 280)
                .fill (StencilKit.rect (0, 0, 120, 26))
                .fill (StencilKit.rect (0, 26, 400, 254))
                .defaults ("bold:1;font-size:10")
                .text (_("schema"))
                .label (4, 2, 112, 22)
                .as_container ()
                .ports_box ();
            Stencils.shape ("er-database", _("Database"), 70, 80, "database server storage")
                .fill ("M0 14 V86 A50 14 0 0 0 100 86 V14 A50 14 0 0 0 0 14 Z")
                .line ("M0 14 A50 14 0 0 0 100 14")
                .label_below ()
                .ports_box ();
            Stencils.shape ("er-category", _("Category Discriminator"), 60, 40, "idef1x category subtype complete")
                .line (StencilKit.circle (50, 30, 26) + " M0 72 H100 M0 86 H100 M50 0 V4")
                .defaults ("fill-kind:none")
                .label_below ()
                .port (50, 0).port (50, 86);
            Stencils.shape ("er-note", _("Database Note"), 150, 80, "comment note remark")
                .fill ("M0 0 H130 L150 20 V80 H0 Z")
                .shade ("M130 0 V20 H150 Z")
                .box (150, 80)
                .defaults ("fill:#fff6c9;stroke:#b59a2b;halign:left;valign:top")
                .label (6, 4, 122, 72)
                .ports_box ();
        }
    }
}
