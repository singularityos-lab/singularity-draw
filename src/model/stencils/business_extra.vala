namespace Singularity.Apps.Draw {

    public class StencilsBusinessExtra {
        private const string[] PALETTE = { "#3a6ea5", "#e5534b", "#6fbf5a", "#f5c518", "#8a63c9", "#35a797", "#f08a3c", "#5b9bd5" };
        private const string DIAGRAM = "stroke:#ffffff;stroke-width:1.5;text-color:#ffffff;bold:1;font-size:11";

        private static string n (double v) {
            return PathData.fmt (v, 2);
        }

        private static TechPen pen () {
            return new TechPen ();
        }

        private static string color (int i) {
            return PALETTE[i % PALETTE.length];
        }

        private static unowned StencilDef diagram (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (100, 100)
                .defaults (DIAGRAM)
                .ports_box ();
        }

        private static string wedge (double cx, double cy, double ro, double ri, double a1, double a2) {
            double r1 = a1 * Math.PI / 180, r2 = a2 * Math.PI / 180;
            bool large = (a2 - a1) > 180;
            var sb = new StringBuilder ();
            sb.append ("M%s %s ".printf (n (cx + ro * Math.cos (r1)), n (cy + ro * Math.sin (r1))));
            sb.append ("A%s %s 0 %d 1 %s %s ".printf (n (ro), n (ro), large ? 1 : 0, n (cx + ro * Math.cos (r2)), n (cy + ro * Math.sin (r2))));
            if (ri <= 0) {
                sb.append ("L%s %s Z".printf (n (cx), n (cy)));
            } else {
                sb.append ("L%s %s ".printf (n (cx + ri * Math.cos (r2)), n (cy + ri * Math.sin (r2))));
                sb.append ("A%s %s 0 %d 0 %s %s Z".printf (n (ri), n (ri), large ? 1 : 0, n (cx + ri * Math.cos (r1)), n (cy + ri * Math.sin (r1))));
            }
            return sb.str;
        }

        private static void register_diagrams () {
            Stencils.category ("business-diagrams", _("Business Diagrams"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            for (int k = 2; k <= 4; k++) {
                unowned StencilDef d = diagram ("biz-venn-%d".printf (k), _("Venn Diagram, %d Sets").printf (k), 200, 180, "venn overlap sets intersection");
                double r = k == 2 ? 30 : 28;
                for (int i = 0; i < k; i++) {
                    double ang = (-90 + i * 360.0 / k) * Math.PI / 180;
                    double off = k == 2 ? 18 : 16;
                    double cx = 50 + (k == 2 ? (i == 0 ? -off : off) : off * Math.cos (ang)), cy = 50 + (k == 2 ? 0 : off * Math.sin (ang));
                    d.solid (StencilKit.circle (cx, cy, r), color (i));
                }
                for (int i = 0; i < k; i++) {
                    double ang = (-90 + i * 360.0 / k) * Math.PI / 180;
                    double off = k == 2 ? 18 : 16;
                    double cx = 50 + (k == 2 ? (i == 0 ? -off : off) : off * Math.cos (ang)), cy = 50 + (k == 2 ? 0 : off * Math.sin (ang));
                    d.line (StencilKit.circle (cx, cy, r));
                }
            }
            for (int k = 3; k <= 6; k++) {
                unowned StencilDef d = diagram ("biz-pyramid-%d".printf (k), _("Pyramid, %d Levels").printf (k), 200, 180, "pyramid hierarchy levels");
                unowned StencilDef inv = diagram ("biz-pyramid-inverted-%d".printf (k), _("Inverted Pyramid, %d Levels").printf (k), 200, 180, "inverted pyramid funnel levels");
                for (int i = 0; i < k; i++) {
                    double y1 = i * 100.0 / k, y2 = (i + 1) * 100.0 / k;
                    double g = i == 0 ? 0 : 1.5;
                    d.solid (StencilKit.poly ({ 50 - y1 / 2, y1 + g, 50 + y1 / 2, y1 + g, 50 + y2 / 2, y2, 50 - y2 / 2, y2 }), color (i));
                    double iy1 = i * 100.0 / k, iy2 = (i + 1) * 100.0 / k;
                    inv.solid (StencilKit.poly ({ iy1 / 2, iy1 + g, 100 - iy1 / 2, iy1 + g, 100 - iy2 / 2, iy2, iy2 / 2, iy2 }), color (i));
                }
            }
            for (int k = 3; k <= 6; k++) {
                unowned StencilDef d = diagram ("biz-funnel-%d".printf (k), _("Funnel, %d Stages").printf (k), 200, 200, "sales funnel conversion stages");
                for (int i = 0; i < k; i++) {
                    double y1 = i * 80.0 / k, y2 = (i + 1) * 80.0 / k - 1.5;
                    double w1 = 50 - y1 * 0.45, w2 = 50 - y2 * 0.45;
                    d.solid (StencilKit.poly ({ 50 - w1, y1, 50 + w1, y1, 50 + w2, y2, 50 - w2, y2 }), color (i));
                }
                d.solid (StencilKit.rect (50 - (50 - 80 * 0.45), 80, 2 * (50 - 80 * 0.45), 20), color (k));
            }
            int[] cycles = { 3, 5, 6, 7, 8 };
            foreach (int k in cycles) {
                unowned StencilDef d = diagram ("biz-cycle-%d".printf (k), _("Cycle, %d Steps").printf (k), 200, 200, "cycle loop circular process");
                double span = 360.0 / k;
                for (int i = 0; i < k; i++) {
                    double a1 = -90 + i * span + 3, a2 = -90 + (i + 1) * span - 3;
                    d.solid (wedge (50, 50, 48, 30, a1, a2), color (i));
                    double tip = (a2 + 2) * Math.PI / 180, base_a = (a2 - 6) * Math.PI / 180;
                    d.solid (StencilKit.poly ({ 50 + 26 * Math.cos (base_a), 50 + 26 * Math.sin (base_a), 50 + 39 * Math.cos (tip), 50 + 39 * Math.sin (tip), 50 + 52 * Math.cos (base_a), 50 + 52 * Math.sin (base_a) }), color (i));
                }
            }
            for (int k = 4; k <= 8; k++) {
                unowned StencilDef d = Stencils.shape ("biz-chevrons-%d".printf (k), _("Chevron Process, %d Steps").printf (k), 70 * k, 60, "chevron process steps flow")
                    .box (100 * k, 100)
                    .defaults (DIAGRAM)
                    .ports_box ();
                for (int i = 0; i < k; i++) {
                    double x = i * 100;
                    double[] pts = i == 0 ? new double[] { x, 0, x + 80, 0, x + 100, 50, x + 80, 100, x, 100 } : new double[] { x, 0, x + 80, 0, x + 100, 50, x + 80, 100, x, 100, x + 20, 50 };
                    d.solid (StencilKit.poly (pts), color (i));
                }
            }
            for (int k = 2; k <= 5; k++) {
                unowned StencilDef d = diagram ("biz-target-%d".printf (k), _("Target, %d Rings").printf (k), 180, 180, "target bullseye concentric goals");
                for (int i = 0; i < k; i++) d.solid (StencilKit.circle (50, 50, 50 - i * 50.0 / k), color (i));
                for (int i = 0; i < k; i++) d.line (StencilKit.circle (50, 50, 50 - i * 50.0 / k));
            }
            unowned StencilDef m2 = diagram ("biz-matrix-2x2", _("Matrix, 2 by 2"), 200, 200, "swot matrix quadrant");
            for (int i = 0; i < 4; i++) m2.solid (StencilKit.rect ((i % 2) * 50 + 1, (i / 2) * 50 + 1, 48, 48), color (i));
            unowned StencilDef m3 = diagram ("biz-matrix-3x3", _("Matrix, 3 by 3"), 220, 220, "nine box grid matrix");
            for (int i = 0; i < 9; i++) m3.solid (StencilKit.rect ((i % 3) * 33.3 + 1, (i / 3) * 33.3 + 1, 31.3, 31.3), color (i));
            for (int k = 3; k <= 8; k++) {
                unowned StencilDef d = diagram ("biz-radial-%d".printf (k), _("Radial, %d Nodes").printf (k), 220, 220, "radial hub spoke central idea");
                var spokes = new StringBuilder ();
                for (int i = 0; i < k; i++) {
                    double a = (-90 + i * 360.0 / k) * Math.PI / 180;
                    spokes.append (StencilKit.line (50 + 16 * Math.cos (a), 50 + 16 * Math.sin (a), 50 + 30 * Math.cos (a), 50 + 30 * Math.sin (a))).append (" ");
                }
                d.ink (spokes.str.strip (), "#7f7f7f");
                d.solid (StencilKit.circle (50, 50, 16), color (0));
                for (int i = 0; i < k; i++) {
                    double a = (-90 + i * 360.0 / k) * Math.PI / 180;
                    d.solid (StencilKit.circle (50 + 38 * Math.cos (a), 50 + 38 * Math.sin (a), 11), color (i + 1));
                }
            }
            for (int k = 3; k <= 6; k++) {
                unowned StencilDef d = diagram ("biz-staircase-%d".printf (k), _("Staircase, %d Steps").printf (k), 220, 180, "staircase steps growth ascending");
                for (int i = 0; i < k; i++) {
                    double w = 100.0 / k;
                    double h = (i + 1) * 100.0 / k;
                    d.solid (StencilKit.rect (i * w + 1, 100 - h, w - 2, h), color (i));
                }
            }
            for (int k = 3; k <= 8; k++) {
                unowned StencilDef d = diagram ("biz-segmented-ring-%d".printf (k), _("Segmented Ring, %d Parts").printf (k), 180, 180, "donut ring segments parts");
                for (int i = 0; i < k; i++) d.solid (wedge (50, 50, 50, 28, -90 + i * 360.0 / k + 1.5, -90 + (i + 1) * 360.0 / k - 1.5), color (i));
            }
            for (int k = 2; k <= 3; k++) {
                unowned StencilDef d = Stencils.shape ("biz-gears-%d".printf (k), _("Gear Process, %d Gears").printf (k), 90 * k, 100, "gears process interlocking mechanism")
                    .box (90 * k, 100)
                    .defaults (DIAGRAM)
                    .ports_box ();
                for (int i = 0; i < k; i++) {
                    double cx = 45 + i * 80, cy = i % 2 == 0 ? 55 : 45;
                    d.solid (pen ().star (cx, cy, 44, 36, 10, i % 2 == 0 ? -90 : -72).str (), color (i));
                    d.ink (pen ().circle (cx, cy, 12).str (), "#ffffff");
                }
            }
            unowned StencilDef conv = diagram ("biz-converging-3", _("Converging Arrows"), 200, 160, "converging arrows merge combine");
            conv.solid (StencilKit.poly ({ 0, 4, 46, 30, 52, 22, 60, 46, 36, 46, 42, 38, 0, 16 }), color (0));
            conv.solid (StencilKit.poly ({ 0, 44, 50, 44, 50, 36, 64, 50, 50, 64, 50, 56, 0, 56 }), color (1));
            conv.solid (StencilKit.poly ({ 0, 96, 46, 70, 52, 78, 60, 54, 36, 54, 42, 62, 0, 84 }), color (2));
            conv.solid (StencilKit.circle (80, 50, 18), color (3));
            unowned StencilDef div = diagram ("biz-diverging-3", _("Diverging Arrows"), 200, 160, "diverging arrows split branch");
            div.solid (StencilKit.circle (20, 50, 18), color (3));
            div.solid (StencilKit.poly ({ 100, 4, 54, 30, 48, 22, 40, 46, 64, 46, 58, 38, 100, 16 }), color (0));
            div.solid (StencilKit.poly ({ 40, 44, 86, 44, 86, 36, 100, 50, 86, 64, 86, 56, 40, 56 }), color (1));
            div.solid (StencilKit.poly ({ 100, 96, 54, 70, 48, 78, 40, 54, 64, 54, 58, 62, 100, 84 }), color (2));
            unowned StencilDef bal = diagram ("biz-balance", _("Balance"), 200, 160, "balance scale pros cons compare");
            bal.solid (StencilKit.poly ({ 44, 100, 56, 100, 52, 30, 48, 30 }), "#595959");
            bal.solid (StencilKit.poly ({ 6, 24, 94, 32, 94, 36, 6, 28 }), "#595959");
            bal.solid (pen ().m (0, 60).l (30, 60).q (15, 76, 0, 60).z ().str (), color (0));
            bal.solid (pen ().m (70, 66).l (100, 66).q (85, 82, 70, 66).z ().str (), color (1));
            bal.ink (pen ().line (15, 26, 2, 60).line (15, 26, 28, 60).line (85, 34, 72, 66).line (85, 34, 98, 66).str (), "#595959");
            for (int k = 3; k <= 6; k++) {
                unowned StencilDef d = Stencils.shape ("biz-milestones-%d".printf (k), _("Milestone Line, %d Points").printf (k), 70 * k, 60, "milestones roadmap timeline points")
                    .box (100 * k, 100)
                    .defaults (DIAGRAM)
                    .ports_box ();
                d.solid (StencilKit.rect (0, 46, 100 * k, 8), "#a6a6a6");
                for (int i = 0; i < k; i++) d.solid (StencilKit.circle (50 + i * 100, 50, 22), color (i));
            }
        }

        private static unowned StencilDef chart (string kind, string name, string kw) {
            return Stencils.shape (kind, name, 160, 120, kw)
                .box (100, 75)
                .defaults ("fill:#ffffff;stroke:#595959;stroke-width:1;font-size:9")
                .label_below ()
                .ports_box ();
        }

        private static void register_charts () {
            Stencils.category ("charts", _("Charts and Graphs"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            string axes = StencilKit.lines ({ 8, 4, 8, 68, 8, 68, 96, 68 });
            double[] vals = { 30, 52, 40, 62, 46 };
            unowned StencilDef col = chart ("chart-column", _("Column Chart"), "bar column chart vertical");
            for (int i = 0; i < 5; i++) col.solid (StencilKit.rect (16 + i * 16, 68 - vals[i], 10, vals[i]), color (0));
            col.line (axes);
            unowned StencilDef bar = chart ("chart-bar", _("Bar Chart"), "horizontal bar chart");
            for (int i = 0; i < 5; i++) bar.solid (StencilKit.rect (8, 8 + i * 12, vals[i] * 1.3, 8), color (0));
            bar.line (axes);
            unowned StencilDef cl = chart ("chart-column-clustered", _("Clustered Column Chart"), "grouped column chart series");
            for (int i = 0; i < 4; i++) {
                cl.solid (StencilKit.rect (14 + i * 20, 68 - vals[i], 7, vals[i]), color (0));
                cl.solid (StencilKit.rect (21 + i * 20, 68 - vals[i + 1] * 0.7, 7, vals[i + 1] * 0.7), color (1));
            }
            cl.line (axes);
            unowned StencilDef st = chart ("chart-column-stacked", _("Stacked Column Chart"), "stacked column chart");
            for (int i = 0; i < 5; i++) {
                st.solid (StencilKit.rect (16 + i * 16, 68 - vals[i] * 0.6, 10, vals[i] * 0.6), color (0));
                st.solid (StencilKit.rect (16 + i * 16, 68 - vals[i], 10, vals[i] * 0.4), color (1));
            }
            st.line (axes);
            unowned StencilDef line = chart ("chart-line", _("Line Chart"), "line graph trend");
            line.line (axes);
            line.ink (StencilKit.poly ({ 14, 50, 32, 36, 50, 42, 68, 20, 88, 28 }, false), color (0));
            line.ink (StencilKit.poly ({ 14, 60, 32, 52, 50, 56, 68, 44, 88, 40 }, false), color (1));
            unowned StencilDef area = chart ("chart-area", _("Area Chart"), "area chart filled");
            area.solid (StencilKit.poly ({ 8, 68, 8, 50, 30, 36, 52, 44, 74, 22, 96, 30, 96, 68 }), color (0));
            area.line (axes);
            unowned StencilDef pie = chart ("chart-pie", _("Pie Chart"), "pie chart share");
            double[] shares = { 0.4, 0.25, 0.2, 0.15 };
            double a = -90;
            for (int i = 0; i < 4; i++) {
                pie.solid (wedge (50, 37, 34, 0, a, a + shares[i] * 360), color (i));
                a += shares[i] * 360;
            }
            unowned StencilDef dn = chart ("chart-doughnut", _("Doughnut Chart"), "doughnut ring chart");
            a = -90;
            for (int i = 0; i < 4; i++) {
                dn.solid (wedge (50, 37, 34, 20, a, a + shares[i] * 360), color (i));
                a += shares[i] * 360;
            }
            unowned StencilDef sc = chart ("chart-scatter", _("Scatter Plot"), "scatter xy plot points");
            sc.line (axes);
            double[] px = { 18, 26, 34, 40, 48, 56, 62, 70, 78, 86 };
            double[] py = { 58, 50, 54, 44, 40, 42, 30, 32, 22, 18 };
            var dots = new StringBuilder ();
            for (int i = 0; i < px.length; i++) dots.append (StencilKit.circle (px[i], py[i], 2.5)).append (" ");
            sc.solid (dots.str.strip (), color (0));
            unowned StencilDef bub = chart ("chart-bubble", _("Bubble Chart"), "bubble chart sizes");
            bub.line (axes);
            bub.solid (StencilKit.circle (26, 48, 8), color (0));
            bub.solid (StencilKit.circle (50, 34, 12), color (1));
            bub.solid (StencilKit.circle (76, 26, 6), color (2));
            bub.solid (StencilKit.circle (70, 52, 9), color (3));
            unowned StencilDef radar = chart ("chart-radar", _("Radar Chart"), "radar spider web chart");
            radar.line (StencilKit.regular (6, 50, 37, 34, 34) + " " + StencilKit.regular (6, 50, 37, 22, 22) + " " + StencilKit.regular (6, 50, 37, 11, 11));
            radar.solid (StencilKit.poly ({ 50, 9, 76, 25, 70, 50, 50, 58, 26, 46, 32, 25 }), color (0));
            unowned StencilDef gauge = chart ("chart-gauge", _("Gauge"), "gauge speedometer dial kpi");
            gauge.solid (wedge (50, 62, 44, 28, 180, 240), color (1));
            gauge.solid (wedge (50, 62, 44, 28, 240, 300), color (3));
            gauge.solid (wedge (50, 62, 44, 28, 300, 360), color (2));
            gauge.ink (pen ().line (50, 62, 72, 34).str (), "#1e1e1e");
            gauge.solid (StencilKit.circle (50, 62, 4), "#1e1e1e");
            unowned StencilDef wf = chart ("chart-waterfall", _("Waterfall Chart"), "waterfall bridge chart");
            wf.line (axes);
            wf.solid (StencilKit.rect (14, 30, 12, 38), color (0));
            wf.solid (StencilKit.rect (30, 18, 12, 12), color (2));
            wf.solid (StencilKit.rect (46, 18, 12, 20), color (1));
            wf.solid (StencilKit.rect (62, 26, 12, 12), color (2));
            wf.solid (StencilKit.rect (78, 26, 12, 42), color (0));
            unowned StencilDef box = chart ("chart-box", _("Box Plot"), "box whisker plot statistics");
            box.line (axes);
            for (int i = 0; i < 3; i++) {
                double x = 22 + i * 26;
                box.line (StencilKit.lines ({ x + 6, 10 + i * 6, x + 6, 22 + i * 4, x + 6, 46 - i * 2, x + 6, 60 - i * 4, x, 10 + i * 6, x + 12, 10 + i * 6, x, 60 - i * 4, x + 12, 60 - i * 4 }));
                box.solid (StencilKit.rect (x, 22 + i * 4, 12, 24 - i * 6), color (i));
            }
            unowned StencilDef heat = chart ("chart-heatmap", _("Heat Map"), "heat map grid intensity");
            string[] heat_cols = { "#fdecea", "#f4a19b", "#e5534b", "#c62828" };
            for (int r = 0; r < 4; r++) for (int c = 0; c < 6; c++) heat.solid (StencilKit.rect (8 + c * 14.5, 6 + r * 15.5, 14, 15), heat_cols[(r * 3 + c * 2) % 4]);
            unowned StencilDef hist = chart ("chart-histogram-bins", _("Histogram"), "histogram distribution bins");
            double[] hv = { 8, 20, 38, 56, 44, 26, 12 };
            for (int i = 0; i < 7; i++) hist.solid (StencilKit.rect (10 + i * 12, 68 - hv[i], 12, hv[i]), color (5));
            hist.line (axes);
            unowned StencilDef spark = Stencils.shape ("chart-sparkline", _("Sparkline"), 120, 30, "sparkline mini trend")
                .box (100, 25)
                .defaults ("fill-kind:none;stroke:#3a6ea5;stroke-width:1.5")
                .ports_box ();
            spark.line (StencilKit.poly ({ 0, 18, 12, 12, 24, 16, 36, 8, 48, 14, 60, 6, 72, 10, 84, 4, 100, 8 }, false));
            unowned StencilDef kpi = Stencils.shape ("chart-kpi", _("KPI Tile"), 160, 90, "kpi metric tile number dashboard")
                .box (160, 90)
                .defaults ("fill:#ffffff;stroke:#d9d9d9;font-size:22;bold:1;text-color:#1e1e1e")
                .text ("42%")
                .label (10, 20, 140, 40)
                .ports_box ();
            kpi.fill (StencilKit.rrect (0, 0, 160, 90, 8));
            kpi.solid (StencilKit.poly ({ 130, 70, 140, 60, 150, 70 }), color (2));
            unowned StencilDef legend = Stencils.shape ("chart-legend", _("Chart Legend"), 120, 70, "legend key series")
                .box (120, 70)
                .defaults ("fill:#ffffff;stroke:#d9d9d9;font-size:9")
                .ports_box ();
            legend.fill (StencilKit.rect (0, 0, 120, 70));
            for (int i = 0; i < 3; i++) {
                legend.solid (StencilKit.rect (10, 12 + i * 18, 12, 10), color (i));
                legend.ink (StencilKit.line (30, 17 + i * 18, 100, 17 + i * 18), "#a6a6a6");
            }
            unowned StencilDef trend_up = Stencils.shape ("chart-trend-up", _("Trend Up"), 60, 60, "trend increase growth arrow")
                .box (100, 100)
                .defaults ("fill-kind:none;stroke:#2e7d32;stroke-width:3")
                .ports_box ();
            trend_up.line (pen ().poly ({ 4, 86, 36, 54, 56, 70, 92, 24 }, false).str ());
            trend_up.solid (StencilKit.poly ({ 70, 18, 98, 14, 94, 42 }), "#2e7d32");
            unowned StencilDef trend_down = Stencils.shape ("chart-trend-down", _("Trend Down"), 60, 60, "trend decrease decline arrow")
                .box (100, 100)
                .defaults ("fill-kind:none;stroke:#c62828;stroke-width:3")
                .ports_box ();
            trend_down.line (pen ().poly ({ 4, 14, 36, 46, 56, 30, 92, 76 }, false).str ());
            trend_down.solid (StencilKit.poly ({ 70, 82, 98, 86, 94, 58 }), "#c62828");
            unowned StencilDef axis = Stencils.shape ("chart-axes", _("Chart Axes"), 160, 120, "axis x y grid")
                .box (100, 75)
                .defaults ("fill-kind:none;stroke:#595959;stroke-width:1")
                .ports_box ();
            axis.line (axes + " " + StencilKit.lines ({ 8, 52, 96, 52, 8, 36, 96, 36, 8, 20, 96, 20 }));
            unowned StencilDef pareto = chart ("chart-pareto-line", _("Combo Chart"), "combo column line chart");
            for (int i = 0; i < 5; i++) pareto.solid (StencilKit.rect (16 + i * 16, 68 - vals[i], 10, vals[i]), color (0));
            pareto.ink (StencilKit.poly ({ 21, 40, 37, 24, 53, 30, 69, 12, 85, 18 }, false), color (1));
            pareto.line (axes);
        }

        private static unowned StencilDef sign (string kind, string name, string kw) {
            return Stencils.shape (kind, name, 70, 70, kw)
                .box (100, 100)
                .icon ()
                .defaults ("stroke:#1e1e1e;stroke-width:1;font-size:9")
                .label_below ()
                .ports_box ();
        }

        private static void warning (string kind, string name, string kw, string glyph) {
            sign (kind, name, kw)
                .solid (StencilKit.poly ({ 50, 4, 98, 90, 2, 90 }), "#1e1e1e")
                .solid (StencilKit.poly ({ 50, 14, 89, 84, 11, 84 }), "#f5c518")
                .solid (glyph, "#1e1e1e");
        }

        private static void prohibition (string kind, string name, string kw, string glyph) {
            sign (kind, name, kw)
                .solid (StencilKit.circle (50, 50, 48), "#ffffff")
                .solid (glyph, "#1e1e1e")
                .solid (StencilKit.ring (50, 50, 48, 39), "#c62828")
                .solid (StencilKit.poly ({ 19, 25, 25, 19, 81, 75, 75, 81 }), "#c62828");
        }

        private static void mandatory (string kind, string name, string kw, string glyph) {
            sign (kind, name, kw)
                .solid (StencilKit.circle (50, 50, 48), "#1f5fae")
                .solid (glyph, "#ffffff");
        }

        private static void safe (string kind, string name, string kw, string glyph) {
            sign (kind, name, kw)
                .solid (StencilKit.rrect (2, 2, 96, 96, 6), "#2e8b57")
                .solid (glyph, "#ffffff");
        }

        private static void fire (string kind, string name, string kw, string glyph) {
            sign (kind, name, kw)
                .solid (StencilKit.rrect (2, 2, 96, 96, 6), "#c62828")
                .solid (glyph, "#ffffff");
        }

        private static string person (double x, double y, double s) {
            var p = new TechPen (x, y, s);
            p.circle (12, 4, 3).m (8, 9).l (16, 9).l (17, 18).l (15, 18).l (15, 24).l (9, 24).l (9, 18).l (7, 18).z ();
            return p.str ();
        }

        private static string flame (double x, double y, double s) {
            var p = new TechPen (x, y, s);
            p.m (12, 22).c (5, 22, 4, 14, 8, 9).c (9, 12, 10, 13, 11, 13).c (10, 8, 12, 4, 15, 2).c (15, 7, 20, 10, 20, 16).c (20, 20, 17, 22, 12, 22).z ();
            return p.str ();
        }

        private static void register_safety () {
            Stencils.category ("safety-signs", _("Safety Signs"), "draw-shapes-symbolic", StencilGroup.PLANS);
            warning ("sign-warn-general", _("General Warning"), "warning caution danger", pen ().rect (46, 34, 8, 30).rect (46, 70, 8, 8).str ());
            warning ("sign-warn-electric", _("Electricity Warning"), "high voltage electric shock", pen ().poly ({ 56, 30, 40, 58, 50, 58, 44, 80, 62, 50, 52, 50 }).str ());
            warning ("sign-warn-flammable", _("Flammable Material"), "flammable fire hazard", flame (32, 38, 36));
            warning ("sign-warn-toxic", _("Toxic Material"), "toxic poison skull", pen ().circle (50, 52, 12).rect (42, 62, 16, 10).str ());
            warning ("sign-warn-corrosive", _("Corrosive Substance"), "corrosive acid", pen ().poly ({ 30, 48, 48, 48, 44, 56, 30, 56 }).poly ({ 52, 48, 70, 48, 70, 56, 56, 56 }).rect (30, 70, 40, 6).str ());
            warning ("sign-warn-radiation", _("Radiation Hazard"), "radioactive ionizing", pen ().circle (50, 60, 4).str () + " " + wedge (50, 60, 18, 7, -120, -60) + " " + wedge (50, 60, 18, 7, 0, 60) + " " + wedge (50, 60, 18, 7, 120, 180));
            warning ("sign-warn-laser", _("Laser Beam"), "laser radiation", pen ().circle (40, 60, 6).rect (46, 59, 30, 2).rect (24, 59, 10, 2).str ());
            warning ("sign-warn-biohazard", _("Biological Hazard"), "biohazard infectious", pen ().circle (50, 50, 8).circle (41, 66, 8).circle (59, 66, 8).str ());
            warning ("sign-warn-slippery", _("Slippery Surface"), "slippery wet floor", person (34, 34, 30) + " " + pen ().rect (26, 76, 48, 3).str ());
            warning ("sign-warn-hot", _("Hot Surface"), "hot surface burn", pen ().rect (28, 74, 44, 4).m (36, 70).q (32, 60, 36, 50).q (40, 42, 36, 36).l (40, 36).q (44, 42, 40, 50).q (36, 60, 40, 70).z ().m (56, 70).q (52, 60, 56, 50).q (60, 42, 56, 36).l (60, 36).q (64, 42, 60, 50).q (56, 60, 60, 70).z ().str ());
            warning ("sign-warn-forklift", _("Forklift Trucks"), "forklift industrial vehicles", pen ().rect (34, 54, 24, 16).rect (40, 42, 12, 12).rect (60, 40, 3, 30).rect (63, 66, 12, 3).circle (40, 74, 4).circle (54, 74, 4).str ());
            warning ("sign-warn-falling", _("Falling Objects"), "falling objects overhead", pen ().rect (40, 36, 12, 12).rect (52, 52, 10, 10).rect (30, 74, 40, 4).str ());
            warning ("sign-warn-obstacle", _("Floor Level Obstacle"), "trip hazard obstacle", person (36, 34, 28) + " " + pen ().rect (54, 70, 16, 8).str ());
            warning ("sign-warn-magnetic", _("Magnetic Field"), "magnetic field magnet", pen ().m (36, 44).l (44, 44).l (44, 62).q (44, 68, 50, 68).q (56, 68, 56, 62).l (56, 44).l (64, 44).l (64, 62).q (64, 76, 50, 76).q (36, 76, 36, 62).z ().str ());
            prohibition ("sign-no-smoking", _("No Smoking"), "no smoking prohibited cigarette", pen ().rect (22, 48, 48, 8).rect (72, 48, 6, 8).str ());
            prohibition ("sign-no-entry", _("No Entry"), "no access unauthorized", person (32, 22, 36));
            prohibition ("sign-no-flames", _("No Open Flames"), "no naked flames fire", flame (30, 24, 40));
            prohibition ("sign-no-phones", _("No Mobile Phones"), "no mobile phone cell", pen ().round (38, 24, 24, 50, 4).str ());
            prohibition ("sign-no-pedestrians", _("No Pedestrians"), "no walking pedestrians", person (32, 20, 36));
            prohibition ("sign-no-drinking", _("Not Drinking Water"), "not drinking water", pen ().poly ({ 34, 30, 66, 30, 62, 74, 38, 74 }).str ());
            prohibition ("sign-no-touch", _("Do Not Touch"), "do not touch hand", pen ().round (38, 30, 24, 42, 8).rect (40, 20, 5, 16).rect (47, 18, 5, 16).rect (54, 20, 5, 16).str ());
            prohibition ("sign-no-food", _("No Food or Drink"), "no eating drinking", pen ().poly ({ 32, 34, 50, 34, 48, 70, 34, 70 }).rect (58, 30, 4, 40).str ());
            mandatory ("sign-must-helmet", _("Wear Safety Helmet"), "hard hat head protection", pen ().m (24, 62).q (24, 30, 50, 28).q (76, 30, 76, 62).z ().rect (18, 62, 64, 8).str ());
            mandatory ("sign-must-goggles", _("Wear Eye Protection"), "safety goggles glasses", pen ().round (18, 40, 28, 20, 8).round (54, 40, 28, 20, 8).rect (44, 46, 12, 6).str ());
            mandatory ("sign-must-gloves", _("Wear Protective Gloves"), "gloves hand protection", pen ().round (34, 40, 32, 40, 8).rect (34, 22, 6, 22).rect (42, 18, 6, 26).rect (50, 20, 6, 24).rect (58, 26, 6, 20).str ());
            mandatory ("sign-must-ears", _("Wear Ear Protection"), "ear defenders hearing", pen ().round (20, 40, 16, 28, 6).round (64, 40, 16, 28, 6).m (28, 42).q (28, 18, 50, 18).q (72, 18, 72, 42).l (66, 42).q (66, 26, 50, 26).q (34, 26, 34, 42).z ().str ());
            mandatory ("sign-must-mask", _("Wear Respiratory Protection"), "mask respirator", pen ().m (26, 44).q (50, 30, 74, 44).q (74, 72, 50, 76).q (26, 72, 26, 44).z ().str ());
            mandatory ("sign-must-boots", _("Wear Safety Footwear"), "safety boots shoes", pen ().m (30, 24).l (50, 24).l (50, 54).l (74, 62).l (74, 76).l (30, 76).z ().str ());
            mandatory ("sign-must-wash", _("Wash Your Hands"), "hand washing hygiene", pen ().round (30, 40, 40, 22, 8).rect (44, 26, 12, 14).circle (40, 72, 3).circle (50, 76, 3).circle (60, 72, 3).str ());
            mandatory ("sign-must-vest", _("Wear High-Visibility Vest"), "hi vis vest", pen ().poly ({ 32, 22, 42, 22, 50, 34, 58, 22, 68, 22, 74, 40, 70, 78, 30, 78, 26, 40 }).str ());
            safe ("sign-first-aid", _("First Aid"), "first aid medical", pen ().rect (40, 18, 20, 64).rect (18, 40, 64, 20).str ());
            safe ("sign-exit-left", _("Emergency Exit, Left"), "emergency exit escape route left", person (52, 22, 40) + " " + pen ().poly ({ 12, 50, 30, 34, 30, 44, 46, 44, 46, 56, 30, 56, 30, 66 }).str ());
            safe ("sign-exit-right", _("Emergency Exit, Right"), "emergency exit escape route right", person (8, 22, 40) + " " + pen ().poly ({ 88, 50, 70, 34, 70, 44, 54, 44, 54, 56, 70, 56, 70, 66 }).str ());
            safe ("sign-assembly", _("Assembly Point"), "muster assembly point", person (12, 50, 26) + " " + person (37, 50, 26) + " " + person (62, 50, 26) + " " + pen ().poly ({ 50, 14, 62, 26, 54, 26, 54, 36, 46, 36, 46, 26, 38, 26 }).str ());
            safe ("sign-eyewash", _("Eyewash Station"), "eye wash emergency", pen ().ellipse (50, 40, 22, 10).circle (50, 40, 5).circle (40, 64, 3).circle (50, 70, 3).circle (60, 64, 3).str ());
            safe ("sign-emergency-phone", _("Emergency Telephone"), "emergency phone call", pen ().round (24, 24, 52, 20, 8).rect (34, 44, 32, 34).str ());
            safe ("sign-defibrillator", _("Defibrillator"), "aed defibrillator heart", pen ().m (50, 78).c (10, 50, 22, 18, 50, 36).c (78, 18, 90, 50, 50, 78).z ().str ());
            safe ("sign-safety-shower", _("Safety Shower"), "emergency shower", pen ().rect (46, 14, 8, 20).ellipse (50, 36, 18, 6).str () + " " + person (38, 46, 24));
            fire ("sign-fire-extinguisher", _("Fire Extinguisher"), "fire extinguisher", pen ().round (36, 30, 22, 50, 6).rect (42, 20, 10, 10).m (52, 22).l (68, 16).l (70, 22).l (54, 28).z ().str ());
            fire ("sign-fire-hose", _("Fire Hose Reel"), "fire hose reel", pen ().circle (46, 50, 26).str () + " " + pen ().circle (46, 50, 12).str ());
            fire ("sign-fire-alarm", _("Fire Alarm Call Point"), "fire alarm call point break glass", pen ().rect (24, 24, 52, 52).str ());
            fire ("sign-fire-phone", _("Fire Emergency Telephone"), "fire telephone", pen ().round (24, 24, 52, 20, 8).rect (34, 44, 32, 34).str ());
            fire ("sign-fire-ladder", _("Fire Ladder"), "fire escape ladder", pen ().rect (34, 14, 6, 72).rect (60, 14, 6, 72).rect (40, 24, 20, 5).rect (40, 40, 20, 5).rect (40, 56, 20, 5).rect (40, 72, 20, 5).str ());
            fire ("sign-fire-blanket", _("Fire Blanket"), "fire blanket", pen ().rect (28, 22, 44, 56).str ());
        }

        private static unowned StencilDef traffic (string kind, string name, string kw) {
            return Stencils.shape (kind, name, 70, 70, kw)
                .box (100, 100)
                .icon ()
                .defaults ("stroke:#1e1e1e;stroke-width:1;font-size:9")
                .label_below ()
                .ports_box ();
        }

        private static unowned StencilDef traffic_text (string kind, string name, string kw) {
            return Stencils.shape (kind, name, 70, 70, kw)
                .box (100, 100)
                .icon ()
                .defaults ("stroke:#1e1e1e;stroke-width:1;font-size:9")
                .ports_box ();
        }

        private static void tri_sign (string kind, string name, string kw, string glyph) {
            traffic (kind, name, kw)
                .solid (StencilKit.poly ({ 50, 4, 98, 90, 2, 90 }), "#c62828")
                .solid (StencilKit.poly ({ 50, 18, 86, 82, 14, 82 }), "#ffffff")
                .solid (glyph, "#1e1e1e");
        }

        private static void round_sign (string kind, string name, string kw, string glyph, bool blue = false) {
            var d = traffic (kind, name, kw);
            if (blue) {
                d.solid (StencilKit.circle (50, 50, 48), "#1f5fae").solid (glyph, "#ffffff");
            } else {
                d.solid (StencilKit.circle (50, 50, 48), "#c62828").solid (StencilKit.circle (50, 50, 38), "#ffffff").solid (glyph, "#1e1e1e");
            }
        }

        private static string digits (string t, double x, double y, double h) {
            var p = new TechPen ();
            double w = h * 0.55, gap = h * 0.18, sw = h * 0.14;
            for (int i = 0; i < t.length; i++) {
                double ox = x + i * (w + gap);
                char c = t[i];
                bool top = c != '1' && c != '4';
                bool mid = c != '0' && c != '1' && c != '7';
                bool bot = c != '1' && c != '4' && c != '7';
                bool tl = c == '0' || c == '4' || c == '5' || c == '6' || c == '8' || c == '9';
                bool tr = c != '5' && c != '6';
                bool bl = c == '0' || c == '2' || c == '6' || c == '8';
                bool br = c != '2';
                if (top) p.rect (ox, y, w, sw);
                if (mid) p.rect (ox, y + h / 2 - sw / 2, w, sw);
                if (bot) p.rect (ox, y + h - sw, w, sw);
                if (tl) p.rect (ox, y, sw, h / 2);
                if (tr) p.rect (ox + w - sw, y, sw, h / 2);
                if (bl) p.rect (ox, y + h / 2, sw, h / 2);
                if (br) p.rect (ox + w - sw, y + h / 2, sw, h / 2);
            }
            return p.str ();
        }

        private static void register_traffic () {
            Stencils.category ("traffic-signs", _("Traffic Signs"), "draw-shapes-symbolic", StencilGroup.PLANS);
            traffic_text ("traffic-stop", _("Stop"), "stop sign octagon")
                .solid (StencilKit.regular (8, 50, 50, 50, 50, -67.5), "#c62828")
                .ink (StencilKit.regular (8, 50, 50, 44, 44, -67.5), "#ffffff")
                .defaults ("text-color:#ffffff;bold:1;font-size:14")
                .text ("STOP")
                .label (0, 30, 100, 40);
            traffic ("traffic-yield", _("Give Way"), "yield give way triangle")
                .solid (StencilKit.poly ({ 2, 6, 98, 6, 50, 94 }), "#c62828")
                .solid (StencilKit.poly ({ 18, 16, 82, 16, 50, 76 }), "#ffffff");
            traffic ("traffic-no-entry", _("No Entry for Vehicles"), "no entry one way wrong way")
                .solid (StencilKit.circle (50, 50, 48), "#c62828")
                .solid (StencilKit.rect (18, 42, 64, 16), "#ffffff");
            foreach (string speed in new string[] { "20", "30", "50", "70", "90", "110", "130" }) {
                double h = 34;
                double total = speed.length * (h * 0.55) + (speed.length - 1) * h * 0.18;
                round_sign ("traffic-speed-" + speed, _("Speed Limit %s").printf (speed), "speed limit maximum " + speed, digits (speed, 50 - total / 2, 33, h));
            }
            round_sign ("traffic-no-overtaking", _("No Overtaking"), "no passing overtaking", pen ().round (24, 40, 22, 30, 4).round (54, 40, 22, 30, 4).str ());
            traffic ("traffic-no-parking", _("No Parking"), "no parking")
                .solid (StencilKit.circle (50, 50, 48), "#c62828")
                .solid (StencilKit.circle (50, 50, 38), "#1f5fae")
                .solid (StencilKit.poly ({ 19, 25, 25, 19, 81, 75, 75, 81 }), "#c62828");
            round_sign ("traffic-roundabout", _("Roundabout Ahead"), "roundabout circular traffic", pen ().poly ({ 50, 18, 62, 30, 54, 30, 54, 36, 46, 36, 46, 30, 38, 30 }).poly ({ 78, 62, 62, 66, 66, 58, 60, 54, 64, 47, 70, 51, 74, 44 }).poly ({ 22, 62, 26, 44, 30, 51, 36, 47, 40, 54, 34, 58, 38, 66 }).str (), true);
            round_sign ("traffic-ahead-only", _("Ahead Only"), "straight ahead only mandatory", pen ().poly ({ 50, 16, 68, 38, 56, 38, 56, 82, 44, 82, 44, 38, 32, 38 }).str (), true);
            round_sign ("traffic-turn-right", _("Turn Right"), "turn right mandatory", pen ().poly ({ 82, 46, 62, 28, 62, 40, 36, 40, 36, 82, 48, 82, 48, 52, 62, 52, 62, 64 }).str (), true);
            round_sign ("traffic-turn-left", _("Turn Left"), "turn left mandatory", pen ().poly ({ 18, 46, 38, 28, 38, 40, 64, 40, 64, 82, 52, 82, 52, 52, 38, 52, 38, 64 }).str (), true);
            round_sign ("traffic-cycle-route", _("Cycle Route"), "bicycle lane cycle path", pen ().circle (32, 62, 12).circle (68, 62, 12).str () + " " + pen ().poly ({ 32, 62, 46, 40, 68, 62, 64, 64, 46, 46, 36, 62 }).str (), true);
            tri_sign ("traffic-pedestrian", _("Pedestrian Crossing Ahead"), "pedestrian crossing zebra", person (36, 36, 28));
            tri_sign ("traffic-children", _("Children"), "school children crossing", person (28, 40, 24) + " " + person (48, 46, 20));
            tri_sign ("traffic-roadworks", _("Road Works"), "road works construction", person (30, 38, 30) + " " + pen ().poly ({ 52, 76, 70, 58, 74, 62, 58, 76 }).str ());
            tri_sign ("traffic-curve-left", _("Bend to Left"), "curve bend left", pen ().m (58, 78).l (58, 58).q (58, 46, 42, 42).l (42, 36).l (32, 46).l (42, 56).l (42, 50).q (50, 52, 50, 60).l (50, 78).z ().str ());
            tri_sign ("traffic-curve-right", _("Bend to Right"), "curve bend right", pen ().m (42, 78).l (42, 58).q (42, 46, 58, 42).l (58, 36).l (68, 46).l (58, 56).l (58, 50).q (50, 52, 50, 60).l (50, 78).z ().str ());
            tri_sign ("traffic-slippery", _("Slippery Road"), "slippery road skid", pen ().round (36, 44, 28, 16, 4).str () + " " + pen ().m (34, 76).q (42, 66, 50, 76).q (58, 66, 66, 76).l (66, 72).q (58, 62, 50, 72).q (42, 62, 34, 72).z ().str ());
            tri_sign ("traffic-lights", _("Traffic Signals Ahead"), "traffic lights signals", pen ().round (42, 34, 16, 44, 4).str ());
            tri_sign ("traffic-animals", _("Wild Animals"), "deer animals crossing", pen ().poly ({ 32, 70, 36, 56, 52, 52, 60, 40, 64, 42, 62, 54, 66, 70, 62, 70, 58, 60, 44, 62, 40, 70 }).str ());
            tri_sign ("traffic-narrows", _("Road Narrows"), "road narrows both sides", pen ().poly ({ 38, 78, 42, 54, 42, 36, 46, 36, 46, 56, 44, 78 }).poly ({ 62, 78, 58, 54, 58, 36, 54, 36, 54, 56, 56, 78 }).str ());
            traffic_text ("traffic-parking", _("Parking"), "parking area")
                .solid (StencilKit.rrect (4, 4, 92, 92, 8), "#1f5fae")
                .defaults ("text-color:#ffffff;bold:1;font-size:30")
                .text ("P")
                .label (0, 10, 100, 80);
            traffic ("traffic-hospital", _("Hospital"), "hospital medical")
                .solid (StencilKit.rrect (4, 4, 92, 92, 8), "#1f5fae")
                .solid (StencilKit.rrect (20, 20, 60, 60, 4), "#ffffff")
                .solid (pen ().rect (44, 26, 12, 48).rect (26, 44, 48, 12).str (), "#c62828");
            traffic ("traffic-dead-end", _("Dead End"), "dead end no through road")
                .solid (StencilKit.rrect (4, 4, 92, 92, 8), "#1f5fae")
                .solid (pen ().rect (44, 40, 12, 50).str (), "#ffffff")
                .solid (pen ().rect (28, 26, 44, 14).str (), "#c62828");
            traffic ("traffic-motorway", _("Motorway"), "motorway highway freeway")
                .solid (StencilKit.rrect (4, 4, 92, 92, 8), "#1f5fae")
                .solid (pen ().poly ({ 20, 84, 44, 22, 48, 22, 40, 84 }).poly ({ 80, 84, 56, 22, 52, 22, 60, 84 }).str (), "#ffffff");
        }

        private static unowned StencilDef field (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults ("fill:#5aa457;stroke:#ffffff;stroke-width:1.5;font-size:9")
                .label_below ()
                .ports_box ();
        }

        private static void register_sports () {
            Stencils.category ("sports-fields", _("Sports Fields"), "draw-shapes-symbolic", StencilGroup.PLANS);
            field ("sport-soccer", _("Soccer Field"), 210, 136, "football soccer pitch")
                .fill (StencilKit.rect (0, 0, 210, 136))
                .line (pen ().rect (6, 6, 198, 124).line (105, 6, 105, 130).circle (105, 68, 18).rect (6, 38, 32, 60).rect (172, 38, 32, 60).rect (6, 54, 11, 28).rect (193, 54, 11, 28).str ());
            field ("sport-basketball", _("Basketball Court"), 200, 107, "basketball court")
                .defaults ("fill:#d9a066;stroke:#ffffff")
                .fill (StencilKit.rect (0, 0, 200, 107))
                .line (pen ().rect (4, 4, 192, 99).line (100, 4, 100, 103).circle (100, 53.5, 14).rect (4, 37, 36, 33).rect (160, 37, 36, 33).m (4, 12).l (20, 12).a (42, 42, false, true, 20, 95).l (4, 95).m (196, 12).l (180, 12).a (42, 42, false, false, 180, 95).l (196, 95).str ());
            field ("sport-tennis", _("Tennis Court"), 220, 102, "tennis court")
                .defaults ("fill:#3a7ca5;stroke:#ffffff")
                .fill (StencilKit.rect (0, 0, 220, 102))
                .line (pen ().rect (10, 6, 200, 90).line (10, 17, 210, 17).line (10, 85, 210, 85).line (110, 6, 110, 96).line (56, 17, 56, 85).line (164, 17, 164, 85).line (56, 51, 164, 51).str ());
            field ("sport-volleyball", _("Volleyball Court"), 180, 90, "volleyball court")
                .defaults ("fill:#e08a3c;stroke:#ffffff")
                .fill (StencilKit.rect (0, 0, 180, 90))
                .line (pen ().rect (6, 6, 168, 78).line (90, 6, 90, 84).line (62, 6, 62, 84).line (118, 6, 118, 84).str ());
            field ("sport-badminton", _("Badminton Court"), 180, 84, "badminton court")
                .defaults ("fill:#3f9b6d;stroke:#ffffff")
                .fill (StencilKit.rect (0, 0, 180, 84))
                .line (pen ().rect (6, 6, 168, 72).line (6, 12, 174, 12).line (6, 72, 174, 72).line (90, 6, 90, 78).line (66, 6, 66, 78).line (114, 6, 114, 78).line (12, 6, 12, 78).line (168, 6, 168, 78).line (12, 42, 66, 42).line (114, 42, 168, 42).str ());
            field ("sport-baseball", _("Baseball Diamond"), 160, 160, "baseball softball diamond")
                .fill (pen ().m (80, 158).l (2, 80).a (110, 110, false, true, 158, 80).z ().str ())
                .line (pen ().poly ({ 80, 150, 40, 110, 80, 70, 120, 110 }).circle (80, 110, 6).str ());
            field ("sport-american-football", _("American Football Field"), 240, 106, "american football gridiron")
                .fill (StencilKit.rect (0, 0, 240, 106))
                .line (pen ().rect (4, 4, 232, 98).line (24, 4, 24, 102).line (216, 4, 216, 102).line (44, 4, 44, 102).line (64, 4, 64, 102).line (84, 4, 84, 102).line (104, 4, 104, 102).line (120, 4, 120, 102).line (136, 4, 136, 102).line (156, 4, 156, 102).line (176, 4, 176, 102).line (196, 4, 196, 102).str ());
            field ("sport-ice-hockey", _("Ice Hockey Rink"), 200, 90, "ice hockey rink")
                .defaults ("fill:#eef6fb;stroke:#c62828")
                .fill (StencilKit.rrect (0, 0, 200, 90, 26))
                .line (pen ().line (100, 0, 100, 90).line (70, 0, 70, 90).line (130, 0, 130, 90).circle (100, 45, 12).circle (40, 25, 8).circle (40, 65, 8).circle (160, 25, 8).circle (160, 65, 8).line (12, 0, 12, 90).line (188, 0, 188, 90).str ());
            field ("sport-swimming", _("Swimming Pool Lanes"), 200, 100, "swimming pool lanes")
                .defaults ("fill:#6cc3e8;stroke:#ffffff")
                .fill (StencilKit.rect (0, 0, 200, 100))
                .line (pen ().line (0, 12.5, 200, 12.5).line (0, 25, 200, 25).line (0, 37.5, 200, 37.5).line (0, 50, 200, 50).line (0, 62.5, 200, 62.5).line (0, 75, 200, 75).line (0, 87.5, 200, 87.5).str ());
            field ("sport-track", _("Running Track"), 220, 110, "athletics running track oval")
                .defaults ("fill:#c8553d;stroke:#ffffff")
                .fill (StencilKit.rrect (0, 0, 220, 110, 55))
                .solid (StencilKit.rrect (30, 30, 160, 50, 25), "#5aa457")
                .line (pen ().round (8, 8, 204, 94, 47).round (16, 16, 188, 78, 39).round (24, 24, 172, 62, 31).str ());
            field ("sport-golf-green", _("Golf Green"), 120, 90, "golf green hole flag")
                .fill (pen ().m (10, 50).q (0, 10, 50, 6).q (110, 0, 116, 44).q (120, 86, 60, 86).q (14, 88, 10, 50).z ().str ())
                .line (pen ().line (62, 50, 62, 18).str ())
                .solid (pen ().poly ({ 62, 18, 80, 24, 62, 30 }).str (), "#c62828")
                .solid (StencilKit.circle (62, 50, 3), "#1e1e1e");
            field ("sport-table-tennis", _("Table Tennis Table"), 120, 70, "ping pong table")
                .defaults ("fill:#1f5fae;stroke:#ffffff")
                .fill (StencilKit.rect (0, 0, 120, 70))
                .line (pen ().rect (3, 3, 114, 64).line (60, 0, 60, 70).line (3, 35, 117, 35).str ());
            field ("sport-pool-table", _("Pool Table"), 140, 80, "billiards pool snooker")
                .defaults ("fill:#2e7d32;stroke:#5a3a1a")
                .fill (StencilKit.rect (0, 0, 140, 80))
                .solid (pen ().circle (6, 6, 4).circle (70, 4, 4).circle (134, 6, 4).circle (6, 74, 4).circle (70, 76, 4).circle (134, 74, 4).str (), "#1e1e1e");
            field ("sport-handball", _("Handball Court"), 200, 100, "handball court")
                .defaults ("fill:#3a7ca5;stroke:#ffffff")
                .fill (StencilKit.rect (0, 0, 200, 100))
                .line (pen ().rect (4, 4, 192, 92).line (100, 4, 100, 96).m (4, 20).a (30, 30, false, true, 4, 80).m (196, 20).a (30, 30, false, false, 196, 80).str ());
            field ("sport-rugby", _("Rugby Field"), 220, 140, "rugby union league pitch")
                .fill (StencilKit.rect (0, 0, 220, 140))
                .line (pen ().rect (6, 6, 208, 128).line (24, 6, 24, 134).line (196, 6, 196, 134).line (110, 6, 110, 134).line (68, 6, 68, 134).line (152, 6, 152, 134).str ());
        }

        public static void register () {
            register_diagrams ();
            register_charts ();
            register_safety ();
            register_traffic ();
            register_sports ();
        }
    }
}
