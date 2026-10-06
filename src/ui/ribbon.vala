using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Draw {

    public class DrawRibbon : ContextRibbon {
        private static int[] ZOOMS = { 25, 50, 75, 100, 150, 200, 400 };

        private weak DrawWindow win;
        private RibbonButton undo;
        private RibbonButton redo;
        private RibbonSelector zoom_selector;

        public DrawRibbon (DrawWindow win, bool illustration) {
            Object (orientation: Orientation.VERTICAL, spacing: 0);
            this.win = win;
            add_css_class ("draw-ribbon");
            build_home (add_context ("home", _("Home"), "go-home-symbolic"));
            build_insert (add_context ("insert", _("Insert"), "list-add-symbolic"), illustration);
            build_design (add_context ("design", _("Design"), "draw-design-symbolic"), illustration);
            if (!illustration) {
                build_data (add_context ("data", _("Data"), "draw-data-symbolic"));
                build_process (add_context ("process", _("Process"), "draw-swimlane-symbolic"));
            }
            build_review (add_context ("review", _("Review"), "draw-review-symbolic"));
            build_view (add_context ("view", _("View"), "view-reveal-symbolic"));
        }

        private delegate void Act ();

        private RibbonButton call (RibbonContext c, string icon, string label, string? tip, owned Act cb) {
            var b = c.add_button (icon, label, tip);
            b.activated.connect (() => cb ());
            return b;
        }

        private RibbonMenu menu (RibbonContext c, string icon, string label, string? tip, owned RibbonMenuBuilder build) {
            var m = c.add_menu (icon, label, tip);
            m.set_builder ((owned) build);
            return m;
        }

        private Widget anchor_for (RibbonItem item) {
            return item.widget.get_mapped () ? item.widget : (Widget) this;
        }

        private void build_home (RibbonContext c) {
            undo = c.add_button ("edit-undo-symbolic", _("Undo"), null, "win.undo");
            redo = c.add_button ("edit-redo-symbolic", _("Redo"), null, "win.redo");
            c.add_separator ();
            c.add_button ("edit-paste-symbolic", _("Paste"), null, "win.paste");
            c.add_button ("edit-cut-symbolic", _("Cut"), null, "win.cut");
            c.add_button ("edit-copy-symbolic", _("Copy"), null, "win.copy");
            c.add_button ("draw-format-painter-symbolic", _("Format Painter"), null, "win.format-painter");
            c.add_separator ();
            c.add_button ("format-text-bold-symbolic", _("Bold"), null, "win.bold");
            c.add_button ("format-text-italic-symbolic", _("Italic"), null, "win.italic");
            c.add_button ("format-text-underline-symbolic", _("Underline"), null, "win.underline");
            menu (c, "font-x-generic-symbolic", _("Font Size"), null, (m) => {
                m.add_item (_("Larger"), null, () => win.run ("font-grow"));
                m.add_item (_("Smaller"), null, () => win.run ("font-shrink"));
            });
            c.add_button ("format-justify-left-symbolic", _("Align Text Left"), null, "win.text-left");
            c.add_button ("format-justify-center-symbolic", _("Center Text"), null, "win.text-center");
            c.add_button ("format-justify-right-symbolic", _("Align Text Right"), null, "win.text-right");
            c.add_separator ();
            menu (c, "draw-design-symbolic", _("Shape Style"), null, (m) => {
                m.add_item (_("Copy Style"), "edit-copy-symbolic", () => win.run ("copy-style"));
                m.add_item (_("Paste Style"), "edit-paste-symbolic", () => win.run ("paste-style"));
                m.add_separator ();
                m.add_item (_("Shadow"), null, () => win.run ("shadow"));
                m.add_item (_("Reset Style"), "edit-clear-all-symbolic", () => win.run ("reset-style"));
            });
            menu (c, "draw-connector-symbolic", _("Connector"), _("Connector Style"), (m) => {
                m.add_item (_("Straight"), null, () => win.run ("route-straight"));
                m.add_item (_("Orthogonal"), null, () => win.run ("route-orthogonal"));
                m.add_item (_("Curved"), null, () => win.run ("route-curved"));
                m.add_separator ();
                m.add_item (_("Reset Bends"), null, () => win.run ("reset-bends"));
            });
            c.add_separator ();
            var arrange = menu (c, "draw-arrange-symbolic", _("Arrange"), null, (m) => win.fill_arrange_menu (m));
            arrange.label_in_compact = true;
            c.add_button ("draw-group-symbolic", _("Group"), null, "win.group");
            c.add_button ("draw-ungroup-symbolic", _("Ungroup"), null, "win.ungroup");
            c.add_separator ();
            c.add_button ("edit-select-all-symbolic", _("Select All"), null, "win.select-all");
            c.add_button ("edit-find-replace-symbolic", _("Replace"), null, "win.replace");
        }

        private void build_insert (RibbonContext c, bool illustration) {
            var page = c.add_button ("document-new-symbolic", _("New Page"), null, "win.insert-page");
            page.label_in_compact = true;
            c.add_button ("view-paged-symbolic", _("Background Page"), null, "win.new-background-page");
            c.add_separator ();
            c.add_button ("insert-image-symbolic", _("Picture"), null, "win.insert-image");
            c.add_button ("draw-text-symbolic", _("Text Box"), null, "win.tool-text");
            if (!illustration) {
                c.add_button ("draw-table-symbolic", _("Table"), null, "win.insert-table");
                c.add_button ("draw-swimlane-symbolic", _("Container"), null, "win.insert-container");
                c.add_button ("x-office-calendar-symbolic", _("Gantt Chart"), null, "win.insert-gantt");
            }
            c.add_button ("draw-review-symbolic", _("Callout"), null, "win.add-callout");
            c.add_button ("draw-comment-symbolic", _("Comment"), _("New Comment"), "win.add-comment");
            c.add_button ("insert-text-symbolic", _("Field"), _("Insert Field"), "win.add-field");
            c.add_separator ();
            c.add_button ("draw-layers-symbolic", _("Layer"), _("New Layer"), "win.add-layer");
            c.add_button ("draw-brush-symbolic", _("Paint Layer"), _("New Paint Layer"), "win.add-paint-layer");
            c.add_button ("image-x-generic-symbolic", _("Image as Paint Layer"), null, "win.import-layer");
            c.add_separator ();
            c.add_button ("document-open-symbolic", _("Import Drawing"), null, "win.import");
            if (!illustration) c.add_button ("x-office-spreadsheet-symbolic", _("Diagram from Data"), null, "win.import-data");
        }

        private void build_design (RibbonContext c, bool illustration) {
            RibbonButton? themes = null;
            themes = call (c, "draw-design-symbolic", _("Themes"), _("Themes and Quick Styles"), () => win.show_design (anchor_for (themes)));
            themes.label_in_compact = true;
            c.add_separator ();
            c.add_button ("document-page-setup-symbolic", _("Page Setup"), null, "win.page-setup");
            c.add_button ("zoom-fit-best-symbolic", _("Fit to Drawing"), _("Fit Page to Drawing"), "win.fit-page-to-drawing");
            menu (c, "view-paged-symbolic", _("Page"), null, (m) => {
                m.add_item (_("Duplicate Page"), "edit-copy-symbolic", () => win.run ("duplicate-page"));
                m.add_item (_("Rename Page"), null, () => win.run ("rename-page"));
                m.add_separator ();
                m.add_item (_("Previous Page"), "go-previous-symbolic", () => win.run ("prev-page"));
                m.add_item (_("Next Page"), "go-next-symbolic", () => win.run ("next-page"));
                m.add_separator ();
                m.add_item (_("Delete Page"), "user-trash-symbolic", () => win.run ("delete-page"), "destructive");
            });
            if (illustration) return;
            c.add_separator ();
            var layout = menu (c, "draw-layout-symbolic", _("Re-Layout"), _("Auto Layout"), (m) => fill_layout (m));
            layout.label_in_compact = true;
            menu (c, "draw-connector-symbolic", _("Connectors"), _("Connector Style"), (m) => {
                m.add_item (_("Straight"), null, () => win.run ("route-straight"));
                m.add_item (_("Orthogonal"), null, () => win.run ("route-orthogonal"));
                m.add_item (_("Curved"), null, () => win.run ("route-curved"));
            });
        }

        private void fill_layout (ContextMenu m) {
            m.add_item (_("Tree, Top Down"), null, () => win.run ("layout-tree"));
            m.add_item (_("Tree, Left to Right"), null, () => win.run ("layout-tree-right"));
            m.add_item (_("Hierarchical"), null, () => win.run ("layout-hierarchical"));
            m.add_item (_("Hierarchical, Left to Right"), null, () => win.run ("layout-hierarchical-right"));
            m.add_item (_("Force-Directed"), null, () => win.run ("layout-force"));
            m.add_item (_("Circle"), null, () => win.run ("layout-circle"));
            m.add_item (_("Grid"), null, () => win.run ("layout-grid"));
        }

        private void build_data (RibbonContext c) {
            var link = c.add_button ("x-office-spreadsheet-symbolic", _("Link Data"), _("Link Data to Shapes"), "win.link-data");
            link.label_in_compact = true;
            c.add_button ("draw-data-symbolic", _("Diagram from Data"), null, "win.import-data");
            c.add_button ("view-refresh-symbolic", _("Refresh All"), _("Refresh All Data"), "win.refresh-data");
            c.add_separator ();
            c.add_button ("draw-data-graphics-symbolic", _("Data Graphics"), null, "win.data-graphics");
            c.add_button ("insert-text-symbolic", _("Add Field"), _("Add a Shape Data Field"), "win.add-field");
            c.add_separator ();
            c.add_button ("x-office-document-symbolic", _("Shape Report"), null, "win.shape-report");
            c.add_button ("document-save-as-symbolic", _("Export Shape Data"), null, "win.export-data");
        }

        private void build_process (RibbonContext c) {
            var check = c.add_button ("emblem-ok-symbolic", _("Check Diagram"), null, "win.check-diagram");
            check.label_in_compact = true;
            c.add_separator ();
            c.add_button ("draw-swimlane-symbolic", _("Cross-Functional Flowchart"), null, "win.insert-cff");
            c.add_button ("draw-swimlane-symbolic", _("Swimlane"), _("Swimlane Pool"), "win.insert-swimlane");
            c.add_button ("draw-container-symbolic", _("Container"), null, "win.insert-container");
            c.add_separator ();
            c.add_button ("draw-review-symbolic", _("Callout"), null, "win.add-callout");
            c.add_button ("insert-link-symbolic", _("Attach Callout"), _("Attach Callout to Shape"), "win.attach-callout");
            c.add_separator ();
            menu (c, "draw-layout-symbolic", _("Auto Layout"), null, (m) => fill_layout (m));
        }

        private void build_review (RibbonContext c) {
            c.add_button ("tools-check-spelling-symbolic", _("Spelling"), _("Check Spelling"), "win.check-spelling");
            c.add_separator ();
            var add = c.add_button ("draw-comment-symbolic", _("New Comment"), null, "win.add-comment");
            add.label_in_compact = true;
            RibbonButton? show = null;
            show = call (c, "view-reveal-symbolic", _("Show Comments"), null, () => win.show_comments (anchor_for (show)));
            c.add_separator ();
            c.add_button ("document-open-symbolic", _("Merge Changes"), _("Merge Changes from a Copy"), "win.merge-drawing");
            c.add_button ("system-users-symbolic", _("Edit Together"), null, "win.edit-together");
        }

        private void build_view (RibbonContext c) {
            c.add_toggle ("sidebar-show-symbolic", _("Shapes"), _("Shapes Panel"), "win.show-shapes");
            c.add_toggle ("sidebar-show-right-symbolic", _("Format Panel"), null, "win.show-inspector");
            c.add_toggle ("draw-minimap-symbolic", _("Mini Map"), null, "win.show-minimap");
            c.add_separator ();
            c.add_toggle ("draw-ruler-symbolic", _("Rulers"), null, "win.show-rulers");
            c.add_toggle ("view-grid-symbolic", _("Grid"), null, "win.show-grid");
            c.add_toggle ("draw-snap-symbolic", _("Snap to Grid"), null, "win.snap-grid");
            c.add_toggle ("draw-guides-symbolic", _("Smart Guides"), null, "win.snap-objects");
            c.add_separator ();
            c.add_button ("zoom-out-symbolic", _("Zoom Out"), null, "win.zoom-out");
            zoom_selector = c.add_selector (_("Zoom"), 5);
            zoom_selector.add_option ("page", _("Fit Page"));
            zoom_selector.add_option ("selection", _("Fit Selection"));
            zoom_selector.add_separator ();
            foreach (int z in ZOOMS) zoom_selector.add_option (z.to_string (), "%d%%".printf (z));
            zoom_selector.text = "100%";
            zoom_selector.changed.connect ((id) => {
                if (id == "page") win.run ("zoom-page");
                else if (id == "selection") win.run ("zoom-selection");
                else win.zoom_percent (int.parse (id));
            });
            c.add_button ("zoom-in-symbolic", _("Zoom In"), null, "win.zoom-in");
            c.add_button ("zoom-fit-best-symbolic", _("Fit Page"), null, "win.zoom-page");
            c.add_separator ();
            var present = c.add_button ("x-office-presentation-symbolic", _("Present"), null, "win.presentation");
            present.label_in_compact = true;
            c.add_button ("view-fullscreen-symbolic", _("Full Screen"), null, "win.fullscreen");
        }

        public void sync_history (Document? d) {
            undo.tooltip = d != null && d.can_undo ? _("Undo %s").printf (d.undo_label) : _("Undo");
            redo.tooltip = d != null && d.can_redo ? _("Redo %s").printf (d.redo_label) : _("Redo");
        }

        public void sync_zoom (double zoom) {
            zoom_selector.text = "%d%%".printf ((int) Math.round (zoom * 100));
        }
    }
}
