namespace Singularity.Apps.Draw {

    public class StencilsSchedule {
        public static void register () {
            timeline ();
            pert ();
        }

        private static string ticks (double x0, double x1, double y0, double y1, int count) {
            var sb = new StringBuilder ();
            for (int i = 0; i <= count; i++) {
                double x = x0 + (x1 - x0) * i / count;
                if (sb.len > 0) sb.append_c (' ');
                sb.append (StencilKit.line (x, y0, x, y1));
            }
            return sb.str;
        }

        private static void timeline () {
            Stencils.category ("timeline", _("Timelines"), "draw-shapes-symbolic", StencilGroup.SCHEDULE);
            Stencils.shape ("tl-block", _("Block Timeline"), 480, 40, "timeline bar block span")
                .box (480, 40)
                .fill (StencilKit.rect (0, 0, 480, 40))
                .line (ticks (0, 480, 28, 40, 12))
                .label (4, 2, 472, 24)
                .port (0, 20).port (480, 20);
            Stencils.shape ("tl-line", _("Line Timeline"), 480, 30, "timeline line axis ticks")
                .box (480, 30)
                .line ("M0 15 H480")
                .line (ticks (0, 480, 8, 22, 12))
                .defaults ("fill-kind:none;stroke-width:2")
                .label (0, 30, 480, 20)
                .port (0, 15).port (480, 15);
            Stencils.shape ("tl-cylinder", _("Cylindrical Timeline"), 480, 44, "timeline cylinder tube")
                .box (480, 44)
                .fill ("M12 0 H468 A12 22 0 0 1 468 44 H12 A12 22 0 0 1 12 0 Z")
                .line ("M468 0 A12 22 0 0 0 468 44")
                .label (14, 4, 440, 36)
                .port (0, 22).port (480, 22);
            Stencils.shape ("tl-ruler", _("Ruler Timeline"), 480, 36, "timeline ruler scale")
                .box (480, 36)
                .fill (StencilKit.rect (0, 0, 480, 36))
                .line (ticks (0, 480, 0, 14, 12) + " " + ticks (20, 460, 0, 7, 11))
                .label (4, 14, 472, 20)
                .port (0, 18).port (480, 18);
            Stencils.shape ("tl-arrow", _("Arrow Timeline"), 480, 50, "timeline arrow direction future")
                .box (480, 50)
                .fill (StencilKit.poly ({ 0, 10, 440, 10, 440, 0, 480, 25, 440, 50, 440, 40, 0, 40 }))
                .label (4, 12, 432, 26)
                .port (0, 25).port (480, 25);
            Stencils.shape ("tl-milestone-diamond", _("Diamond Milestone"), 24, 24, "milestone diamond event key date")
                .dark (StencilKit.poly ({ 50, 0, 100, 50, 50, 100, 0, 50 }))
                .label_below ()
                .ports_box ();
            Stencils.shape ("tl-milestone-flag", _("Flag Milestone"), 34, 60, "milestone flag goal")
                .line ("M10 0 V100")
                .fill ("M10 2 H96 L80 22 L96 42 H10 Z")
                .defaults ("fill:#e5534b;stroke:#8e1c1c")
                .label (-60, 100, 220, 26)
                .port (10, 100);
            Stencils.shape ("tl-milestone-pin", _("Pin Milestone"), 24, 60, "milestone pin event")
                .box (24, 60)
                .line ("M12 22 V60")
                .fill (StencilKit.circle (12, 11, 10))
                .label (-50, 60, 124, 18)
                .port (12, 60);
            Stencils.shape ("tl-milestone-triangle", _("Triangle Milestone"), 24, 22, "milestone triangle marker")
                .dark (StencilKit.poly ({ 50, 100, 100, 0, 0, 0 }))
                .label_below ()
                .port (50, 100).port (50, 0);
            Stencils.shape ("tl-milestone-circle", _("Circle Milestone"), 22, 22, "milestone dot event")
                .fill (StencilKit.circle (50, 50, 50))
                .dark (StencilKit.circle (50, 50, 26))
                .label_below ()
                .ports_box ();
            Stencils.shape ("tl-interval-bracket", _("Bracket Interval"), 200, 24, "interval span period bracket")
                .line ("M0 100 V20 H100 V100")
                .defaults ("fill-kind:none;stroke-width:1.5")
                .label (0, -100, 100, 100)
                .port (0, 100).port (100, 100);
            Stencils.shape ("tl-interval-block", _("Block Interval"), 200, 30, "interval span period duration")
                .fill (StencilKit.rrect (0, 0, 100, 100, 20))
                .defaults ("fill:#b7d3f4c0;stroke:#3a6ea5")
                .ports_box ();
            Stencils.shape ("tl-today", _("Today Marker"), 20, 200, "today now current date line")
                .box (20, 200)
                .line (StencilKit.dashed_line (10, 16, 10, 200, 6, 4))
                .dark (StencilKit.poly ({ 0, 0, 20, 0, 10, 16 }))
                .defaults ("stroke:#c62828;fill-kind:none;stroke-width:2")
                .text (_("Today"))
                .label (-40, -22, 100, 20)
                .port (10, 0).port (10, 200);
            Stencils.shape ("tl-phases", _("Phase Chevrons"), 480, 44, "phases stages timeline chevron")
                .box (480, 44)
                .fill (StencilKit.poly ({ 0, 0, 144, 0, 162, 22, 144, 44, 0, 44 }))
                .shade (StencilKit.poly ({ 150, 0, 306, 0, 324, 22, 306, 44, 150, 44, 168, 22 }))
                .fill (StencilKit.poly ({ 312, 0, 462, 0, 480, 22, 462, 44, 312, 44, 330, 22 }))
                .label (0, 44, 480, 20)
                .port (0, 22).port (480, 22);
            Stencils.shape ("tl-year-marker", _("Year Marker"), 60, 40, "year date marker tick")
                .line ("M50 0 V100")
                .defaults ("fill-kind:none;stroke-width:2.5;bold:1")
                .text ("2026")
                .label (-50, 100, 200, 50)
                .port (50, 0).port (50, 100);
            Stencils.shape ("tl-quarter-marker", _("Quarter Marker"), 60, 30, "quarter date marker tick")
                .line ("M50 0 V100")
                .defaults ("fill-kind:none;stroke-width:1.5")
                .text ("Q1")
                .label (-50, 100, 200, 60)
                .port (50, 0).port (50, 100);
            Stencils.shape ("tl-month-marker", _("Month Marker"), 60, 20, "month date marker tick")
                .line ("M50 0 V100")
                .defaults ("fill-kind:none;font-size:9")
                .text (_("Jan"))
                .label (-50, 100, 200, 80)
                .port (50, 0).port (50, 100);
            Stencils.shape ("tl-event-callout", _("Event Callout"), 120, 90, "event description callout timeline")
                .box (120, 90)
                .fill (StencilKit.rect (0, 0, 120, 50))
                .line ("M60 50 V82")
                .dark (StencilKit.circle (60, 84, 6))
                .label (4, 2, 112, 46)
                .port (60, 90).port (60, 0);
            Stencils.shape ("tl-span-arrow", _("Span Arrow"), 200, 20, "duration span double arrow")
                .line ("M8 50 H92")
                .dark (StencilKit.poly ({ 0, 50, 10, 10, 10, 90 }) + " " + StencilKit.poly ({ 100, 50, 90, 10, 90, 90 }))
                .defaults ("fill-kind:none")
                .label (0, -110, 100, 100)
                .port (0, 50).port (100, 50);
        }

        private static void pert () {
            Stencils.category ("calendar-pert", _("PERT, Gantt and Calendar"), "draw-shapes-symbolic", StencilGroup.SCHEDULE);
            Stencils.shape ("pert-task", _("PERT Task"), 180, 100, "pert task es ef ls lf slack")
                .box (180, 100)
                .fill (StencilKit.rect (0, 0, 180, 100))
                .line ("M0 28 H180 M0 72 H180 M60 0 V28 M120 0 V28 M60 72 V100 M120 72 V100")
                .defaults ("bold:1")
                .text (_("Task"))
                .label (4, 30, 172, 40)
                .ports_box ();
            Stencils.shape ("pert-node", _("PERT Event Node"), 70, 70, "pert event node milestone sector")
                .fill (StencilKit.circle (50, 50, 50))
                .line ("M0 50 H100 M50 50 V100")
                .label (15, 12, 70, 36)
                .ports_box ();
            Stencils.shape ("gantt-task-bar", _("Task Bar"), 160, 22, "gantt task bar duration")
                .fill (StencilKit.rrect (0, 0, 100, 100, 18))
                .defaults ("fill:#3a6ea5;stroke:#1f4e79;text-color:#ffffff;font-size:9")
                .port (0, 50).port (100, 50);
            Stencils.shape ("gantt-summary-bar", _("Summary Bar"), 240, 18, "gantt summary phase group")
                .dark (StencilKit.poly ({ 0, 0, 100, 0, 100, 100, 97, 60, 3, 60, 0, 100 }))
                .label (0, -110, 100, 100)
                .port (0, 30).port (100, 30);
            Stencils.shape ("gantt-milestone", _("Gantt Milestone"), 18, 18, "gantt milestone diamond")
                .dark (StencilKit.poly ({ 50, 0, 100, 50, 50, 100, 0, 50 }))
                .defaults ("stroke:#1e1e1e")
                .label (110, 0, 400, 100)
                .port (0, 50).port (100, 50);
            Stencils.shape ("gantt-progress-bar", _("Progress Bar"), 160, 22, "gantt progress percent complete")
                .fill (StencilKit.rrect (0, 0, 100, 100, 18))
                .solid ("M9 0 H60 V100 H9 A9 50 0 0 1 0 50 A9 50 0 0 1 9 0 Z", "@dark")
                .defaults ("fill:#b7d3f4;stroke:#1f4e79;font-size:9")
                .port (0, 50).port (100, 50);
            Stencils.shape ("gantt-baseline-bar", _("Baseline Bar"), 160, 8, "gantt baseline planned")
                .fill (StencilKit.rect (0, 0, 100, 100))
                .defaults ("fill:#bfbfbf;stroke:#7f7f7f")
                .label (0, 100, 100, 200)
                .port (0, 50).port (100, 50);
            Stencils.shape ("gantt-dependency", _("Dependency Link"), 60, 40, "gantt dependency finish start")
                .line ("M0 0 H40 V92")
                .dark (StencilKit.poly ({ 40, 100, 28, 80, 52, 80 }))
                .defaults ("fill-kind:none")
                .label (50, 0, 100, 100)
                .port (0, 0).port (40, 100);
            Stencils.shape ("gantt-row-grid", _("Gantt Row Grid"), 480, 120, "gantt grid rows columns timescale")
                .box (480, 120)
                .fill (StencilKit.rect (0, 0, 480, 120))
                .shade (StencilKit.rect (0, 0, 480, 24))
                .line ("M0 48 H480 M0 72 H480 M0 96 H480 M120 0 V120" + " " + ticks (120, 480, 0, 120, 9))
                .defaults ("halign:left;valign:top;bold:1;font-size:9")
                .text (_("Task"))
                .label (4, 4, 112, 18)
                .ports_box ();
            string week = StencilKit.rect (0, 0, 350, 70);
            Stencils.shape ("cal-week", _("Week Calendar"), 350, 70, "calendar week days")
                .box (350, 70)
                .fill (week)
                .shade (StencilKit.rect (0, 0, 350, 18))
                .line (ticks (0, 350, 0, 70, 7))
                .defaults ("halign:left;valign:top;font-size:8")
                .text (_("Mon       Tue        Wed       Thu        Fri         Sat        Sun"))
                .label (4, 2, 346, 14)
                .ports_box ();
            var month = new StringBuilder ();
            for (int r = 1; r < 6; r++) month.append (StencilKit.line (0, 18 + r * 32, 280, 18 + r * 32) + " ");
            Stencils.shape ("cal-month", _("Month Calendar"), 280, 210, "calendar month grid days")
                .box (280, 210)
                .fill (StencilKit.rect (0, 0, 280, 210))
                .shade (StencilKit.rect (0, 0, 280, 18))
                .line (month.str + ticks (0, 280, 18, 210, 7))
                .defaults ("valign:top;bold:1;font-size:9")
                .text (_("Month"))
                .label (4, 2, 272, 14)
                .ports_box ();
            Stencils.shape ("cal-day", _("Day"), 90, 90, "calendar day date")
                .box (90, 90)
                .fill (StencilKit.rect (0, 0, 90, 90))
                .shade (StencilKit.rect (0, 0, 90, 22))
                .defaults ("valign:top;bold:1")
                .text ("1")
                .label (4, 2, 82, 18)
                .ports_box ();
            Stencils.shape ("cal-event", _("Calendar Event"), 120, 26, "appointment event meeting")
                .fill (StencilKit.rrect (0, 0, 100, 100, 20))
                .solid (StencilKit.rect (0, 12, 3, 76), "@dark")
                .defaults ("fill:#e3eefb;stroke:#3a6ea5;font-size:9;halign:left")
                .label (6, 0, 92, 100)
                .port (0, 50).port (100, 50);
        }
    }
}
