namespace Singularity.Apps.Draw {

    public class StencilsGeneralExtra {
        private static TechPen pen () {
            return new TechPen ();
        }

        private static string glyph (string id, double x = 0, double y = 0, double size = 24) {
            var p = new TechPen (x, y, size);
            switch (id) {
                case "document": p.poly ({ 5, 2, 15, 2, 19, 6, 19, 22, 5, 22 }).poly ({ 15, 2, 15, 6, 19, 6 }, false).line (8, 11, 16, 11).line (8, 15, 16, 15).line (8, 18, 13, 18); break;
                case "calendar": p.rect (3, 5, 18, 16).line (3, 10, 21, 10).line (8, 3, 8, 7).line (16, 3, 16, 7).rect (6, 13, 3, 3).rect (11, 13, 3, 3).rect (16, 13, 3, 3); break;
                case "clock": p.circle (12, 12, 9).line (12, 12, 12, 7).line (12, 12, 16, 14); break;
                case "user": p.circle (12, 8, 4).m (4, 21).q (4, 13, 12, 13).q (20, 13, 20, 21).z (); break;
                case "users": p.circle (9, 8, 3.5).m (2, 20).q (2, 13, 9, 13).q (16, 13, 16, 20).z ().circle (17, 7, 3).m (15, 12).q (22, 12, 22, 19).l (18, 19); break;
                case "lock": p.rect (5, 10, 14, 11).m (8, 10).l (8, 7).a (4, 4, false, true, 16, 7).l (16, 10).circle (12, 15, 1.5); break;
                case "unlock": p.rect (5, 10, 14, 11).m (8, 10).l (8, 7).a (4, 4, false, true, 16, 7).circle (12, 15, 1.5); break;
                case "key": p.circle (7, 12, 4).line (11, 12, 21, 12).line (18, 12, 18, 16).line (15, 12, 15, 15); break;
                case "phone": p.m (6, 3).l (9, 3).l (11, 8).l (8.5, 10).q (11, 14, 14, 15.5).l (16, 13).l (21, 15).l (21, 18).q (21, 21, 18, 21).q (4, 20, 3, 6).q (3, 3, 6, 3).z (); break;
                case "chat": p.m (3, 5).l (21, 5).l (21, 16).l (10, 16).l (5, 20).l (6, 16).l (3, 16).z (); break;
                case "search": p.circle (10, 10, 6).line (14.5, 14.5, 21, 21); break;
                case "home": p.poly ({ 3, 11, 12, 3, 21, 11 }, false).poly ({ 5, 10, 5, 21, 19, 21, 19, 10 }, false).rect (10, 14, 4, 7); break;
                case "cart": p.m (2, 4).l (5, 4).l (8, 15).l (19, 15).l (21, 7).l (6, 7).circle (9, 19, 1.5).circle (17, 19, 1.5); break;
                case "star": p.star (12, 12, 10, 4.2, 5); break;
                case "heart": p.m (12, 20).c (2, 13, 3, 4, 8, 4).c (10, 4, 11.5, 5.5, 12, 7).c (12.5, 5.5, 14, 4, 16, 4).c (21, 4, 22, 13, 12, 20).z (); break;
                case "flag": p.line (5, 2, 5, 22).poly ({ 5, 3, 19, 3, 16, 8, 19, 13, 5, 13 }); break;
                case "bell": p.m (6, 17).l (6, 11).q (6, 5, 12, 5).q (18, 5, 18, 11).l (18, 17).l (20, 19).l (4, 19).z ().m (10, 20).q (12, 23, 14, 20).line (12, 3, 12, 5); break;
                case "camera": p.rect (3, 7, 18, 13).poly ({ 8, 7, 10, 4, 14, 4, 16, 7 }, false).circle (12, 13, 4); break;
                case "cloud": p.m (6, 19).q (2, 19, 2, 15).q (2, 11, 6, 11).q (6, 5, 12, 5).q (17, 5, 18, 10).q (22, 10, 22, 15).q (22, 19, 18, 19).z (); break;
                case "download": p.line (12, 3, 12, 15).poly ({ 7, 10, 12, 15, 17, 10 }, false).poly ({ 4, 15, 4, 20, 20, 20, 20, 15 }, false); break;
                case "upload": p.line (12, 15, 12, 3).poly ({ 7, 8, 12, 3, 17, 8 }, false).poly ({ 4, 15, 4, 20, 20, 20, 20, 15 }, false); break;
                case "folder": p.poly ({ 3, 6, 9, 6, 11, 8, 21, 8, 21, 19, 3, 19 }); break;
                case "chart": p.poly ({ 3, 3, 3, 21, 21, 21 }, false).rect (6, 13, 3, 8).rect (11, 9, 3, 12).rect (16, 5, 3, 16); break;
                case "printer": p.rect (7, 3, 10, 5).rect (3, 8, 18, 9).rect (7, 14, 10, 7); break;
                case "globe": p.circle (12, 12, 9).ellipse (12, 12, 4, 9).line (3, 12, 21, 12); break;
                case "wifi": p.arc (12, 19, 4, 225, 315).arc (12, 19, 9, 225, 315).arc (12, 19, 14, 225, 315).circle (12, 19, 1); break;
                case "battery": p.rect (2, 7, 18, 10).rect (20, 10, 2, 4).rect (4, 9, 10, 6); break;
                case "bulb": p.m (9, 17).q (9, 14, 7, 12).q (4, 8, 7, 5).q (12, 1, 17, 5).q (20, 8, 17, 12).q (15, 14, 15, 17).z ().line (9, 19, 15, 19).line (10, 21, 14, 21); break;
                case "trophy": p.poly ({ 7, 3, 17, 3, 17, 9, 12, 14, 7, 9 }).m (7, 5).q (3, 5, 4, 9).q (5, 11, 7, 10).m (17, 5).q (21, 5, 20, 9).q (19, 11, 17, 10).line (12, 14, 12, 18).rect (8, 18, 8, 3); break;
                case "rocket": p.m (12, 2).q (18, 7, 16, 16).l (8, 16).q (6, 7, 12, 2).z ().circle (12, 9, 2).poly ({ 8, 13, 4, 18, 8, 17 }).poly ({ 16, 13, 20, 18, 16, 17 }).line (10, 19, 10, 22).line (14, 19, 14, 22); break;
                case "target": p.circle (12, 12, 9).circle (12, 12, 5.5).circle (12, 12, 2); break;
                case "puzzle": p.m (4, 8).l (9, 8).q (8, 4, 11, 4).q (14, 4, 13, 8).l (18, 8).l (18, 12).q (22, 11, 22, 14).q (22, 17, 18, 16).l (18, 21).l (4, 21).z (); break;
                case "handshake": p.poly ({ 2, 10, 7, 7, 12, 9, 17, 7, 22, 10, 18, 16, 14, 18, 10, 17, 6, 15 }).line (12, 9, 9, 12).line (10, 17, 8, 14); break;
                case "money": p.rect (2, 6, 20, 12).circle (12, 12, 3).circle (5, 9, 1).circle (19, 15, 1); break;
                case "coin": p.ellipse (12, 8, 8, 3).m (4, 8).l (4, 16).a (8, 3, false, false, 20, 16).l (20, 8).m (4, 12).a (8, 3, false, false, 20, 12); break;
                case "briefcase": p.rect (2, 7, 20, 13).poly ({ 8, 7, 8, 4, 16, 4, 16, 7 }, false).line (2, 12, 22, 12); break;
                case "building": p.rect (5, 3, 14, 18).rect (8, 6, 3, 3).rect (13, 6, 3, 3).rect (8, 11, 3, 3).rect (13, 11, 3, 3).rect (10, 16, 4, 5); break;
                case "truck": p.rect (2, 6, 12, 11).poly ({ 14, 9, 19, 9, 22, 13, 22, 17, 14, 17 }).circle (6, 18, 2).circle (18, 18, 2); break;
                case "plane": p.poly ({ 12, 2, 13.5, 9, 22, 13, 22, 15, 13.5, 13, 13, 19, 16, 21, 16, 22, 12, 21, 8, 22, 8, 21, 11, 19, 10.5, 13, 2, 15, 2, 13, 10.5, 9 }); break;
                case "car": p.m (3, 13).l (5, 7).l (19, 7).l (21, 13).l (21, 18).l (3, 18).z ().line (3, 13, 21, 13).circle (7, 18, 2).circle (17, 18, 2); break;
                case "shield": p.m (12, 2).l (20, 5).l (20, 11).q (20, 18, 12, 22).q (4, 18, 4, 11).l (4, 5).z (); break;
                case "check": p.circle (12, 12, 9).poly ({ 7.5, 12, 10.5, 15, 16.5, 9 }, false); break;
                case "cross": p.circle (12, 12, 9).line (8.5, 8.5, 15.5, 15.5).line (15.5, 8.5, 8.5, 15.5); break;
                case "warning": p.poly ({ 12, 3, 22, 20, 2, 20 }).line (12, 9, 12, 14).circle (12, 17, 0.8); break;
                case "info": p.circle (12, 12, 9).line (12, 11, 12, 17).circle (12, 7.5, 0.8); break;
                case "question": p.circle (12, 12, 9).m (9, 9).q (9, 6, 12, 6).q (15, 6, 15, 9).q (15, 11, 12, 12).l (12, 14).circle (12, 17, 0.8); break;
                case "plus": p.circle (12, 12, 9).line (12, 7, 12, 17).line (7, 12, 17, 12); break;
                case "minus": p.circle (12, 12, 9).line (7, 12, 17, 12); break;
                case "play": p.circle (12, 12, 9).poly ({ 10, 8, 16, 12, 10, 16 }); break;
                case "pause": p.circle (12, 12, 9).line (10, 8, 10, 16).line (14, 8, 14, 16); break;
                case "music": p.line (9, 18, 9, 5).line (9, 5, 19, 3).line (19, 3, 19, 16).circle (7, 18, 2).circle (17, 16, 2); break;
                case "video": p.rect (2, 6, 14, 12).poly ({ 16, 10, 22, 7, 22, 17, 16, 14 }); break;
                case "image": p.rect (3, 4, 18, 16).circle (8, 9, 2).poly ({ 3, 18, 9, 12, 13, 16, 16, 13, 21, 18 }, false); break;
                case "pin": p.m (12, 22).l (6, 13).q (3, 8, 7, 4).q (12, 0, 17, 4).q (21, 8, 18, 13).z ().circle (12, 9, 2.5); break;
                case "compass": p.circle (12, 12, 9).poly ({ 12, 5, 14, 12, 12, 19, 10, 12 }); break;
                case "book": p.m (12, 6).q (7, 3, 3, 5).l (3, 19).q (7, 17, 12, 20).q (17, 17, 21, 19).l (21, 5).q (17, 3, 12, 6).l (12, 20); break;
                case "pencil": p.poly ({ 4, 20, 5, 15, 16, 4, 20, 8, 9, 19 }).line (14, 6, 18, 10); break;
                case "scissors": p.circle (6, 18, 3).circle (18, 18, 3).line (8, 16, 18, 3).line (16, 16, 6, 3); break;
                case "link": p.round (2, 9, 11, 6, 3).round (11, 9, 11, 6, 3); break;
                case "paperclip": p.m (16, 7).l (16, 17).q (16, 21, 12, 21).q (8, 21, 8, 17).l (8, 5).q (8, 2, 11, 2).q (14, 2, 14, 5).l (14, 16).q (14, 18, 12, 18).q (10, 18, 10, 16).l (10, 7); break;
                case "trash": p.line (3, 6, 21, 6).poly ({ 9, 6, 9, 3, 15, 3, 15, 6 }, false).poly ({ 5, 6, 6, 21, 18, 21, 19, 6 }, false).line (10, 10, 10, 17).line (14, 10, 14, 17); break;
                case "tag": p.poly ({ 3, 3, 12, 3, 21, 12, 12, 21, 3, 12 }).circle (7.5, 7.5, 1.5); break;
                case "gift": p.rect (3, 9, 18, 4).rect (5, 13, 14, 8).line (12, 9, 12, 21).m (12, 9).q (6, 3, 6, 7).q (7, 9, 12, 9).m (12, 9).q (18, 3, 18, 7).q (17, 9, 12, 9); break;
                case "leaf": p.m (4, 20).q (4, 4, 20, 4).q (20, 20, 4, 20).z ().line (4, 20, 14, 10); break;
                case "sun": p.circle (12, 12, 4).line (12, 2, 12, 5).line (12, 19, 12, 22).line (2, 12, 5, 12).line (19, 12, 22, 12).line (5, 5, 7, 7).line (17, 17, 19, 19).line (5, 19, 7, 17).line (17, 7, 19, 5); break;
                case "moon": p.m (15, 3).q (7, 4, 6, 12).q (7, 21, 16, 21).q (20, 20, 21, 17).q (12, 19, 11, 11).q (11, 5, 15, 3).z (); break;
                case "umbrella": p.m (2, 12).q (3, 3, 12, 3).q (21, 3, 22, 12).z ().m (12, 12).l (12, 19).q (12, 22, 9, 21); break;
                case "thermometer": p.m (10, 15).l (10, 4).a (2, 2, false, true, 14, 4).l (14, 15).a (4, 4, true, true, 10, 15).z ().line (12, 8, 12, 17); break;
                case "speaker": p.poly ({ 3, 9, 7, 9, 12, 4, 12, 20, 7, 15, 3, 15 }).arc (12, 12, 5, -45, 45).arc (12, 12, 9, -45, 45); break;
                case "microphone": p.round (9, 2, 6, 12, 3).m (5, 11).q (5, 18, 12, 18).q (19, 18, 19, 11).line (12, 18, 12, 22).line (8, 22, 16, 22); break;
                case "headphones": p.m (4, 17).l (4, 12).q (4, 4, 12, 4).q (20, 4, 20, 12).l (20, 17).rect (3, 13, 4, 7).rect (17, 13, 4, 7); break;
                case "laptop": p.rect (5, 5, 14, 10).poly ({ 2, 18, 5, 15, 19, 15, 22, 18 }); break;
                case "mobile": p.round (7, 2, 10, 20, 2).line (10, 19, 14, 19); break;
                case "monitor": p.rect (2, 4, 20, 13).line (8, 21, 16, 21).line (12, 17, 12, 21); break;
                case "keyboard": p.round (2, 7, 20, 11, 2).line (5, 10, 7, 10).line (9, 10, 11, 10).line (13, 10, 15, 10).line (17, 10, 19, 10).line (7, 14, 17, 14); break;
                case "mouse": p.round (7, 3, 10, 18, 5).line (12, 3, 12, 9); break;
                case "server": p.rect (3, 3, 18, 7).rect (3, 14, 18, 7).circle (6, 6.5, 1).circle (6, 17.5, 1); break;
                case "database": p.ellipse (12, 5, 8, 3).m (4, 5).l (4, 19).a (8, 3, false, false, 20, 19).l (20, 5).m (4, 12).a (8, 3, false, false, 20, 12); break;
                case "code": p.poly ({ 8, 6, 2, 12, 8, 18 }, false).poly ({ 16, 6, 22, 12, 16, 18 }, false).line (14, 4, 10, 20); break;
                case "terminal": p.rect (2, 4, 20, 16).poly ({ 6, 9, 9, 12, 6, 15 }, false).line (11, 15, 16, 15); break;
                case "bug": p.ellipse (12, 13, 5, 7).line (7, 10, 3, 8).line (17, 10, 21, 8).line (7, 14, 3, 14).line (17, 14, 21, 14).line (7, 18, 3, 20).line (17, 18, 21, 20).line (12, 6, 12, 20).circle (12, 5, 2.5); break;
                case "gear": p.star (12, 12, 10, 7.5, 8, -90).circle (12, 12, 3); break;
                case "wrench": p.m (14, 3).q (19, 2, 21, 7).l (17, 9).l (15, 7).l (13, 9).l (15, 11).l (13, 15).l (5, 22).l (2, 19).l (9, 11).q (10, 4, 14, 3).z (); break;
                case "hammer": p.rect (4, 4, 10, 5).line (10, 9, 10, 22).line (14, 6.5, 19, 6.5); break;
                case "cog-person": p.circle (9, 8, 3.5).m (2, 20).q (2, 13, 9, 13).q (13, 13, 14, 15).star (18, 17, 4, 2.8, 6); break;
                case "graduation": p.poly ({ 2, 9, 12, 4, 22, 9, 12, 14 }).m (6, 11).l (6, 17).q (12, 21, 18, 17).l (18, 11).line (21, 9, 21, 16); break;
                case "medical": p.rect (9, 3, 6, 18).rect (3, 9, 18, 6); break;
                case "pill": p.round (3, 8, 18, 8, 4).line (12, 8, 12, 16); break;
                case "eye": p.m (2, 12).q (12, 2, 22, 12).q (12, 22, 2, 12).z ().circle (12, 12, 3); break;
                case "hourglass": p.poly ({ 6, 2, 18, 2, 12, 12, 18, 22, 6, 22, 12, 12 }); break;
                case "infinity": p.m (12, 12).c (9, 6, 3, 7, 3, 12).c (3, 17, 9, 18, 12, 12).c (15, 6, 21, 7, 21, 12).c (21, 17, 15, 18, 12, 12).z (); break;
                case "recycle": p.poly ({ 12, 3, 16, 9, 13, 9, 13, 11, 11, 11, 11, 9, 8, 9 }).poly ({ 4, 18, 7, 12, 9, 14, 11, 13, 12, 15, 10, 16, 11, 18 }).poly ({ 20, 18, 13, 18, 14, 16, 12, 15, 13, 13, 15, 14, 17, 12 }); break;
                case "share": p.circle (6, 12, 3).circle (18, 5, 3).circle (18, 19, 3).line (9, 10.5, 15, 6.5).line (9, 13.5, 15, 17.5); break;
                case "filter": p.poly ({ 3, 4, 21, 4, 14, 12, 14, 20, 10, 18, 10, 12 }); break;
                case "sort": p.line (7, 4, 7, 20).poly ({ 4, 7, 7, 4, 10, 7 }, false).line (17, 4, 17, 20).poly ({ 14, 17, 17, 20, 20, 17 }, false); break;
                case "refresh": p.arc (12, 12, 8, -60, 240).poly ({ 18, 3, 16, 6, 20, 7 }); break;
                case "power": p.arc (12, 13, 8, -50, 230).line (12, 3, 12, 12); break;
                case "bluetooth": p.poly ({ 6, 7, 17, 17, 12, 21, 12, 3, 17, 7, 6, 17 }, false); break;
                case "qr": p.rect (3, 3, 7, 7).rect (14, 3, 7, 7).rect (3, 14, 7, 7).rect (5, 5, 3, 3).rect (16, 5, 3, 3).rect (5, 16, 3, 3).rect (14, 14, 3, 3).rect (18, 18, 3, 3); break;
                case "barcode": p.line (3, 5, 3, 19).line (5, 5, 5, 19).line (8, 5, 8, 19).line (10, 5, 10, 19).line (13, 5, 13, 19).line (16, 5, 16, 19).line (18, 5, 18, 19).line (21, 5, 21, 19); break;
                case "dollar": p.circle (12, 12, 9).m (15, 9).q (15, 7, 12, 7).q (9, 7, 9, 9.5).q (9, 12, 12, 12).q (15, 12, 15, 14.5).q (15, 17, 12, 17).q (9, 17, 9, 15).line (12, 5, 12, 19); break;
                case "euro": p.circle (12, 12, 9).m (16, 8).q (14, 6.5, 12, 7).q (8, 8, 8, 12).q (8, 16, 12, 17).q (14, 17.5, 16, 16).line (6, 11, 13, 11).line (6, 13.5, 13, 13.5); break;
                case "percent": p.circle (7, 7, 3).circle (17, 17, 3).line (19, 4, 5, 20); break;
                case "location": p.circle (12, 12, 7).circle (12, 12, 2).line (12, 2, 12, 5).line (12, 19, 12, 22).line (2, 12, 5, 12).line (19, 12, 22, 12); break;
                case "send": p.poly ({ 2, 11, 22, 3, 15, 21, 11, 13 }).line (11, 13, 22, 3); break;
                case "inbox": p.poly ({ 2, 13, 6, 4, 18, 4, 22, 13, 22, 20, 2, 20 }).poly ({ 2, 13, 8, 13, 9, 16, 15, 16, 16, 13, 22, 13 }, false); break;
                case "archive": p.rect (2, 4, 20, 5).poly ({ 4, 9, 4, 20, 20, 20, 20, 9 }, false).line (10, 13, 14, 13); break;
                case "bookmark": p.poly ({ 6, 3, 18, 3, 18, 21, 12, 16, 6, 21 }); break;
                case "crown": p.poly ({ 3, 18, 3, 7, 8, 12, 12, 5, 16, 12, 21, 7, 21, 18 }).line (3, 20, 21, 20); break;
                case "diamond-gem": p.poly ({ 6, 4, 18, 4, 22, 9, 12, 21, 2, 9 }).line (2, 9, 22, 9).poly ({ 8, 4, 12, 9, 16, 4 }, false).line (12, 9, 12, 21); break;
                case "anchor": p.circle (12, 5, 2).line (12, 7, 12, 21).line (8, 10, 16, 10).m (4, 14).q (5, 21, 12, 21).q (19, 21, 20, 14); break;
                case "fire": p.m (12, 22).c (5, 22, 4, 14, 8, 9).c (9, 12, 10, 13, 11, 13).c (10, 8, 12, 4, 15, 2).c (15, 7, 20, 10, 20, 16).c (20, 20, 17, 22, 12, 22).z (); break;
                case "water": p.m (12, 3).q (19, 12, 19, 15).q (19, 21, 12, 21).q (5, 21, 5, 15).q (5, 12, 12, 3).z (); break;
                case "snowflake": p.line (12, 2, 12, 22).line (3, 7, 21, 17).line (3, 17, 21, 7).poly ({ 9, 4, 12, 6, 15, 4 }, false).poly ({ 9, 20, 12, 18, 15, 20 }, false); break;
                case "tree": p.poly ({ 12, 2, 19, 12, 15, 12, 20, 18, 4, 18, 9, 12, 5, 12 }).line (12, 18, 12, 22); break;
                case "paw": p.ellipse (12, 16, 5, 4).circle (6, 10, 2).circle (10, 6, 2).circle (14, 6, 2).circle (18, 10, 2); break;
                default: p.circle (12, 12, 9); break;
            }
            return p.str ();
        }

        private static void register_icons () {
            Stencils.category ("icons", _("Icons and Pictograms"), "draw-shapes-symbolic", StencilGroup.GENERAL);
            string[,] list = {
                { "document", "Document Icon", "file page paper" }, { "calendar", "Calendar Icon", "date schedule month" }, { "clock", "Clock Icon", "time hour" },
                { "user", "User Icon", "person profile account" }, { "users", "Group Icon", "people team users" }, { "lock", "Lock Icon", "security locked private" },
                { "unlock", "Unlocked Icon", "open unlocked public" }, { "key", "Key Icon", "password access" }, { "phone", "Telephone Icon", "call phone" },
                { "chat", "Chat Icon", "message conversation speech" }, { "search", "Search Icon", "magnifier find" }, { "home", "Home Icon", "house start" },
                { "cart", "Shopping Cart Icon", "basket buy shop" }, { "star", "Star Icon", "favorite rating" }, { "heart", "Heart Icon", "love like favorite" },
                { "flag", "Flag Icon", "marker report goal" }, { "bell", "Bell Icon", "notification alert" }, { "camera", "Camera Icon", "photo picture" },
                { "cloud", "Cloud Icon", "cloud storage weather" }, { "download", "Download Icon", "save get" }, { "upload", "Upload Icon", "send put" },
                { "folder", "Folder Icon", "directory files" }, { "chart", "Chart Icon", "statistics graph analytics" }, { "printer", "Printer Icon", "print" },
                { "globe", "Globe Icon", "world internet web" }, { "wifi", "Wireless Icon", "wifi signal network" }, { "battery", "Battery Icon", "power charge level" },
                { "bulb", "Light Bulb Icon", "idea innovation" }, { "trophy", "Trophy Icon", "award winner cup" }, { "rocket", "Rocket Icon", "launch startup" },
                { "target", "Target Icon", "goal aim objective" }, { "puzzle", "Puzzle Icon", "solution plugin piece" }, { "handshake", "Handshake Icon", "deal partnership agreement" },
                { "money", "Banknote Icon", "money cash payment" }, { "coin", "Coins Icon", "coins savings finance" }, { "briefcase", "Briefcase Icon", "business work job" },
                { "building", "Office Building Icon", "company headquarters" }, { "truck", "Delivery Truck Icon", "shipping logistics" }, { "plane", "Airplane Icon", "flight travel" },
                { "car", "Car Icon", "vehicle automobile" }, { "shield", "Shield Icon", "protection security" }, { "check", "Check Icon", "done ok approved" },
                { "cross", "Cancel Icon", "error reject close" }, { "warning", "Warning Icon", "caution alert" }, { "info", "Information Icon", "info about help" },
                { "question", "Question Icon", "help faq unknown" }, { "plus", "Add Icon", "plus new create" }, { "minus", "Remove Icon", "minus subtract" },
                { "play", "Play Icon", "start media video" }, { "pause", "Pause Icon", "pause media" }, { "music", "Music Icon", "audio song note" },
                { "video", "Video Icon", "film movie camera" }, { "image", "Picture Icon", "image photo landscape" }, { "pin", "Map Pin Icon", "location place marker" },
                { "compass", "Compass Icon", "navigation direction" }, { "book", "Book Icon", "read manual documentation" }, { "pencil", "Pencil Icon", "edit write" },
                { "scissors", "Scissors Icon", "cut" }, { "link", "Link Icon", "chain hyperlink url" }, { "paperclip", "Attachment Icon", "paperclip attach" },
                { "trash", "Trash Icon", "delete bin remove" }, { "tag", "Tag Icon", "label price category" }, { "gift", "Gift Icon", "present reward" },
                { "leaf", "Leaf Icon", "eco nature green" }, { "sun", "Sun Icon", "weather day light" }, { "moon", "Moon Icon", "night dark" },
                { "umbrella", "Umbrella Icon", "insurance rain protection" }, { "thermometer", "Thermometer Icon", "temperature" }, { "speaker", "Speaker Icon", "volume sound audio" },
                { "microphone", "Microphone Icon", "voice record" }, { "headphones", "Headphones Icon", "audio support listen" }, { "laptop", "Laptop Icon", "notebook computer" },
                { "mobile", "Smartphone Icon", "mobile phone app" }, { "monitor", "Monitor Icon", "display screen desktop" }, { "keyboard", "Keyboard Icon", "typing input" },
                { "mouse", "Mouse Icon", "pointer input" }, { "server", "Server Icon", "hosting rack" }, { "database", "Database Icon", "data storage sql" },
                { "code", "Code Icon", "development programming" }, { "terminal", "Terminal Icon", "console command line shell" }, { "bug", "Bug Icon", "defect issue" },
                { "gear", "Settings Icon", "gear cog configuration" }, { "wrench", "Wrench Icon", "tool maintenance repair" }, { "hammer", "Hammer Icon", "build tool construction" },
                { "cog-person", "Administrator Icon", "admin operator user settings" }, { "graduation", "Graduation Icon", "education school learning" }, { "medical", "Medical Icon", "health hospital cross" },
                { "pill", "Pill Icon", "medicine drug pharmacy" }, { "eye", "Eye Icon", "view visibility watch" }, { "hourglass", "Hourglass Icon", "wait time loading" },
                { "infinity", "Infinity Icon", "endless loop unlimited" }, { "recycle", "Recycle Icon", "recycling reuse" }, { "share", "Share Icon", "social network share" },
                { "filter", "Filter Icon", "funnel filter refine" }, { "sort", "Sort Icon", "order ascending descending" }, { "refresh", "Refresh Icon", "reload sync update" },
                { "power", "Power Icon", "on off shutdown" }, { "bluetooth", "Bluetooth Icon", "bluetooth wireless" }, { "qr", "QR Code Icon", "qr code scan" },
                { "barcode", "Barcode Icon", "barcode product scan" }, { "dollar", "Dollar Icon", "currency usd money" }, { "euro", "Euro Icon", "currency eur money" },
                { "percent", "Percent Icon", "percentage discount" }, { "location", "Target Location Icon", "gps locate crosshair" }, { "send", "Send Icon", "paper plane message" },
                { "inbox", "Inbox Icon", "mail tray incoming" }, { "archive", "Archive Icon", "box storage archive" }, { "bookmark", "Bookmark Icon", "save bookmark" },
                { "crown", "Crown Icon", "premium vip king" }, { "diamond-gem", "Gem Icon", "diamond jewel value" }, { "anchor", "Anchor Icon", "marine port stable" },
                { "fire", "Fire Icon", "flame hot trending" }, { "water", "Water Drop Icon", "water drop liquid" }, { "snowflake", "Snowflake Icon", "cold winter freeze" },
                { "tree", "Tree Icon", "forest nature" }, { "paw", "Paw Icon", "pet animal" }
            };
            for (int i = 0; i < list.length[0]; i++) {
                Stencils.shape ("icon-" + list[i, 0], _(list[i, 1]), 48, 48, "icon pictogram " + list[i, 2])
                    .box (24, 24)
                    .icon ()
                    .defaults ("fill-kind:none;stroke:#1f4e79;stroke-width:1.8;font-size:9")
                    .line (glyph (list[i, 0]))
                    .label_below ()
                    .ports_box ();
            }
        }

        private static string hexagon (double cx, double cy, double r) {
            return pen ().regular (cx, cy, r, 6, -90).str ();
        }

        private static unowned StencilDef chem (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults ("fill-kind:none;stroke:#1e1e1e;stroke-width:1.5;font-size:10")
                .ports_box ();
        }

        private static void atom (string kind, string name, string symbol, string color) {
            Stencils.shape (kind, name, 44, 44, "atom element " + name.down () + " " + symbol.down ())
                .box (100, 100)
                .defaults ("fill:%s;stroke:#1e1e1e;stroke-width:1;font-size:14;bold:1;text-color:%s".printf (color, color == "#1e1e1e" || color == "#3050f8" ? "#ffffff" : "#1e1e1e"))
                .fill (StencilKit.circle (50, 50, 48))
                .text (symbol)
                .label (0, 0, 100, 100)
                .ports_box ();
        }

        private static void register_chemistry () {
            Stencils.category ("chemistry", _("Chemistry and Molecules"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            string[,] atoms = {
                { "h", "Hydrogen", "H", "#ffffff" }, { "c", "Carbon", "C", "#1e1e1e" }, { "n", "Nitrogen", "N", "#3050f8" }, { "o", "Oxygen", "O", "#ff3b30" },
                { "s", "Sulfur", "S", "#f5c518" }, { "p", "Phosphorus", "P", "#ff8000" }, { "cl", "Chlorine", "Cl", "#1ff01f" }, { "f", "Fluorine", "F", "#90e050" },
                { "na", "Sodium", "Na", "#ab5cf2" }, { "fe", "Iron", "Fe", "#e06633" }
            };
            for (int i = 0; i < atoms.length[0]; i++) atom ("chem-atom-" + atoms[i, 0], _(atoms[i, 1]), atoms[i, 2], atoms[i, 3]);
            chem ("chem-benzene", _("Benzene Ring"), 80, 80, "benzene aromatic ring")
                .line (hexagon (40, 40, 36))
                .line (pen ().circle (40, 40, 22).str ());
            chem ("chem-benzene-kekule", _("Benzene (Kekulé)"), 80, 80, "benzene kekule double bonds")
                .line (hexagon (40, 40, 36))
                .line (pen ().line (40, 10, 63, 23).line (63, 51, 40, 64).line (17, 51, 17, 23).str ());
            chem ("chem-cyclohexane", _("Cyclohexane"), 80, 80, "cyclohexane ring")
                .line (hexagon (40, 40, 36));
            chem ("chem-cyclopentane", _("Cyclopentane"), 80, 80, "cyclopentane five ring")
                .line (pen ().regular (40, 42, 34, 5, -90).str ());
            chem ("chem-naphthalene", _("Naphthalene"), 140, 80, "naphthalene fused rings")
                .line (hexagon (40, 40, 36) + " " + hexagon (102.4, 40, 36))
                .line (pen ().circle (40, 40, 22).circle (102.4, 40, 22).str ());
            chem ("chem-single-bond", _("Single Bond"), 80, 20, "single bond line")
                .line (pen ().line (0, 10, 80, 10).str ())
                .port (0, 10).port (80, 10);
            chem ("chem-double-bond", _("Double Bond"), 80, 20, "double bond")
                .line (pen ().line (0, 6, 80, 6).line (0, 14, 80, 14).str ())
                .port (0, 10).port (80, 10);
            chem ("chem-triple-bond", _("Triple Bond"), 80, 20, "triple bond")
                .line (pen ().line (0, 3, 80, 3).line (0, 10, 80, 10).line (0, 17, 80, 17).str ())
                .port (0, 10).port (80, 10);
            chem ("chem-wedge-bond", _("Wedge Bond"), 80, 20, "stereo wedge bond")
                .fill (pen ().poly ({ 0, 10, 80, 3, 80, 17 }).str ())
                .defaults ("fill:#1e1e1e")
                .port (0, 10).port (80, 10);
            chem ("chem-hash-bond", _("Hashed Bond"), 80, 20, "stereo hashed dash bond")
                .line (pen ().line (8, 9, 8, 11).line (20, 8, 20, 12).line (32, 7, 32, 13).line (44, 6, 44, 14).line (56, 5, 56, 15).line (68, 4, 68, 16).line (80, 3, 80, 17).str ())
                .port (0, 10).port (80, 10);
            chem ("chem-water", _("Water Molecule"), 120, 90, "water h2o molecule")
                .line (pen ().line (60, 30, 22, 70).line (60, 30, 98, 70).str ())
                .solid (StencilKit.circle (60, 30, 22), "#ff3b30")
                .solid (StencilKit.circle (22, 70, 14), "#e0e0e0")
                .solid (StencilKit.circle (98, 70, 14), "#e0e0e0");
            chem ("chem-co2", _("Carbon Dioxide"), 160, 50, "co2 carbon dioxide molecule")
                .line (pen ().line (30, 20, 130, 20).line (30, 30, 130, 30).str ())
                .solid (StencilKit.circle (25, 25, 20), "#ff3b30")
                .solid (StencilKit.circle (80, 25, 20), "#424242")
                .solid (StencilKit.circle (135, 25, 20), "#ff3b30");
            chem ("chem-methane", _("Methane"), 120, 120, "methane ch4 molecule")
                .line (pen ().line (60, 60, 60, 12).line (60, 60, 16, 88).line (60, 60, 104, 88).line (60, 60, 82, 74).str ())
                .solid (StencilKit.circle (60, 60, 18), "#424242")
                .solid (StencilKit.circle (60, 12, 11) + " " + StencilKit.circle (16, 88, 11) + " " + StencilKit.circle (104, 88, 11) + " " + StencilKit.circle (88, 78, 9), "#e0e0e0");
            chem ("chem-atom-model", _("Atom Model"), 120, 120, "bohr atom orbit electrons")
                .line (pen ().ellipse (60, 60, 56, 20).str ())
                .line (pen ().ellipse (60, 60, 20, 56).str ())
                .solid (StencilKit.circle (60, 60, 8), "#ff3b30")
                .solid (StencilKit.circle (116, 60, 4) + " " + StencilKit.circle (60, 4, 4), "#3050f8");
            chem ("chem-reaction-arrow", _("Reaction Arrow"), 100, 20, "reaction yields arrow")
                .line (pen ().arrow (0, 10, 100, 10, 8).str ())
                .port (0, 10).port (100, 10);
            chem ("chem-equilibrium", _("Equilibrium Arrows"), 100, 24, "equilibrium reversible reaction")
                .line (pen ().line (0, 8, 100, 8).line (100, 8, 90, 2).line (0, 16, 100, 16).line (0, 16, 10, 22).str ())
                .port (0, 12).port (100, 12);
            chem ("chem-resonance", _("Resonance Arrow"), 100, 20, "resonance double headed arrow")
                .line (pen ().arrow (10, 10, 100, 10, 8).arrow (90, 10, 0, 10, 8).str ())
                .port (0, 10).port (100, 10);
            chem ("chem-dna", _("DNA Double Helix"), 60, 160, "dna helix genetics")
                .line (pen ().m (10, 0).c (60, 40, 60, 40, 10, 80).c (-20, 120, 40, 120, 10, 160).m (50, 0).c (0, 40, 0, 40, 50, 80).c (80, 120, 20, 120, 50, 160).str ())
                .line (pen ().line (18, 12, 42, 12).line (28, 28, 32, 28).line (18, 68, 42, 68).line (18, 92, 42, 92).line (28, 108, 32, 108).line (18, 148, 42, 148).str ());
            chem ("chem-orbital-s", _("s Orbital"), 80, 80, "s orbital sphere")
                .fill (pen ().circle (40, 40, 36).str ())
                .defaults ("fill:#b7d3f4;stroke:#1f4e79");
            chem ("chem-orbital-p", _("p Orbital"), 80, 140, "p orbital dumbbell")
                .fill (pen ().m (40, 70).c (0, 40, 10, 0, 40, 0).c (70, 0, 80, 40, 40, 70).z ().m (40, 70).c (0, 100, 10, 140, 40, 140).c (70, 140, 80, 100, 40, 70).z ().str ())
                .defaults ("fill:#b7d3f4;stroke:#1f4e79");
        }

        private static unowned StencilDef geo (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults ("fill-kind:none;stroke:#1e1e1e;stroke-width:1.5;font-size:10")
                .ports_box ();
        }

        private static void register_math () {
            Stencils.category ("math-geometry", _("Mathematics and Geometry"), "draw-shapes-symbolic", StencilGroup.ENGINEERING);
            geo ("math-axes-2d", _("Cartesian Axes"), 140, 140, "x y axes coordinate plane")
                .line (pen ().arrow (0, 70, 140, 70, 6).arrow (70, 140, 70, 0, 6).str ());
            geo ("math-axes-3d", _("3D Axes"), 140, 140, "x y z axes three dimensional")
                .line (pen ().arrow (50, 90, 140, 90, 6).arrow (50, 90, 50, 0, 6).arrow (50, 90, 0, 140, 6).str ());
            geo ("math-grid", _("Coordinate Grid"), 140, 140, "graph paper grid")
                .line (StencilKit.lines ({ 0, 20, 140, 20, 0, 40, 140, 40, 0, 60, 140, 60, 0, 80, 140, 80, 0, 100, 140, 100, 0, 120, 140, 120, 20, 0, 20, 140, 40, 0, 40, 140, 60, 0, 60, 140, 80, 0, 80, 140, 100, 0, 100, 140, 120, 0, 120, 140 }))
                .defaults ("stroke:#a6a6a6;stroke-width:1");
            geo ("math-parabola", _("Parabola"), 140, 120, "parabola quadratic curve")
                .line (pen ().arrow (0, 110, 140, 110, 5).arrow (70, 120, 70, 0, 5).str ())
                .ink (pen ().m (14, 10).q (70, 210, 126, 10).str (), "#c62828");
            geo ("math-sine", _("Sine Wave"), 160, 80, "sine wave trigonometric")
                .line (pen ().arrow (0, 40, 160, 40, 5).str ())
                .ink (pen ().m (0, 40).c (20, 0, 40, 0, 50, 40).c (60, 80, 80, 80, 100, 40).c (110, 0, 130, 0, 150, 40).str (), "#1f5fae");
            geo ("math-normal", _("Normal Distribution"), 160, 90, "bell curve gaussian normal")
                .line (pen ().line (0, 86, 160, 86).str ())
                .ink (pen ().m (0, 84).c (50, 84, 60, 6, 80, 6).c (100, 6, 110, 84, 160, 84).str (), "#1f5fae");
            geo ("math-angle", _("Angle"), 100, 80, "angle degrees arc")
                .line (pen ().line (0, 76, 100, 76).line (0, 76, 80, 6).arc (0, 76, 30, -42, 0).str ());
            geo ("math-right-angle", _("Right Angle"), 80, 80, "right angle perpendicular")
                .line (pen ().line (0, 76, 80, 76).line (4, 0, 4, 80).rect (4, 62, 14, 14).str ());
            geo ("math-protractor", _("Protractor"), 160, 90, "protractor measure angle")
                .fill (pen ().m (0, 84).a (80, 80, false, true, 160, 84).z ().str ())
                .line (pen ().arc (80, 84, 64, 180, 360).line (80, 84, 80, 74).line (16, 84, 26, 84).line (144, 84, 134, 84).line (35, 39, 42, 46).line (125, 39, 118, 46).str ())
                .defaults ("fill:#e3eefb");
            geo ("math-ruler", _("Ruler"), 200, 40, "ruler measure scale")
                .fill (pen ().rect (0, 0, 200, 40).str ())
                .line (StencilKit.lines ({ 10, 0, 10, 16, 20, 0, 20, 8, 30, 0, 30, 8, 40, 0, 40, 8, 50, 0, 50, 12, 60, 0, 60, 8, 70, 0, 70, 8, 80, 0, 80, 8, 90, 0, 90, 8, 100, 0, 100, 16, 110, 0, 110, 8, 120, 0, 120, 8, 130, 0, 130, 8, 140, 0, 140, 8, 150, 0, 150, 12, 160, 0, 160, 8, 170, 0, 170, 8, 180, 0, 180, 8, 190, 0, 190, 16 }))
                .defaults ("fill:#fff6c9");
            geo ("math-compass-tool", _("Drawing Compass"), 80, 120, "compass drawing tool circle")
                .line (pen ().circle (40, 10, 6).line (36, 15, 10, 116).line (44, 15, 70, 116).line (24, 70, 56, 70).str ());
            geo ("math-vector", _("Vector"), 120, 60, "vector arrow direction magnitude")
                .line (pen ().arrow (0, 56, 120, 4, 9).str ())
                .port (0, 56).port (120, 4);
            geo ("math-cube", _("Cube Wireframe"), 100, 100, "cube 3d solid")
                .line (pen ().rect (0, 30, 70, 70).poly ({ 0, 30, 30, 0, 100, 0, 70, 30 }).poly ({ 70, 100, 100, 70, 100, 0 }, false).str ())
                .line (StencilKit.dashed_line (30, 0, 30, 70, 5, 4) + " " + StencilKit.dashed_line (30, 70, 100, 70, 5, 4) + " " + StencilKit.dashed_line (30, 70, 0, 100, 5, 4));
            geo ("math-sphere", _("Sphere Wireframe"), 100, 100, "sphere ball 3d")
                .line (pen ().circle (50, 50, 48).str ())
                .line (StencilKit.dashed_ellipse (50, 50, 48, 14, 24));
            geo ("math-cylinder", _("Cylinder Wireframe"), 80, 120, "cylinder 3d solid")
                .line (pen ().ellipse (40, 12, 38, 10).line (2, 12, 2, 108).line (78, 12, 78, 108).m (2, 108).a (38, 10, false, false, 78, 108).str ())
                .line (StencilKit.dashed_ellipse (40, 108, 38, 10, 20));
            geo ("math-cone", _("Cone Wireframe"), 100, 120, "cone 3d solid")
                .line (pen ().line (50, 0, 2, 108).line (50, 0, 98, 108).m (2, 108).a (48, 12, false, false, 98, 108).str ())
                .line (StencilKit.dashed_ellipse (50, 108, 48, 12, 20));
            geo ("math-pyramid", _("Pyramid Wireframe"), 100, 100, "pyramid 3d solid")
                .line (pen ().poly ({ 50, 0, 0, 90, 70, 100 }).line (50, 0, 100, 80).line (70, 100, 100, 80).str ())
                .line (StencilKit.dashed_line (0, 90, 30, 70, 5, 4) + " " + StencilKit.dashed_line (30, 70, 100, 80, 5, 4) + " " + StencilKit.dashed_line (30, 70, 50, 0, 5, 4));
            geo ("math-prism", _("Prism Wireframe"), 120, 100, "triangular prism 3d")
                .line (pen ().poly ({ 0, 100, 30, 40, 60, 100 }).line (30, 40, 90, 0).line (60, 100, 120, 60).line (90, 0, 120, 60).str ())
                .line (StencilKit.dashed_line (0, 100, 60, 60, 5, 4) + " " + StencilKit.dashed_line (60, 60, 120, 60, 5, 4) + " " + StencilKit.dashed_line (60, 60, 90, 0, 5, 4));
            geo ("math-torus", _("Torus"), 140, 80, "torus donut ring 3d")
                .line (pen ().ellipse (70, 40, 68, 36).m (40, 40).q (70, 60, 100, 40).m (46, 44).q (70, 28, 94, 44).str ());
            geo ("math-triangle-vertices", _("Triangle with Vertices"), 120, 100, "triangle vertices abc sides")
                .line (pen ().poly ({ 10, 90, 110, 90, 40, 10 }).str ())
                .solid (StencilKit.circle (10, 90, 3) + " " + StencilKit.circle (110, 90, 3) + " " + StencilKit.circle (40, 10, 3), "#1e1e1e");
            geo ("math-circle-radius", _("Circle with Radius"), 100, 100, "circle radius diameter")
                .line (pen ().circle (50, 50, 48).line (50, 50, 98, 50).str ())
                .solid (StencilKit.circle (50, 50, 2.5), "#1e1e1e");
            geo ("math-number-line", _("Number Line"), 220, 30, "number line integers")
                .line (pen ().arrow (0, 15, 220, 15, 6).arrow (220, 15, 0, 15, 6).str () + " " + StencilKit.lines ({ 30, 10, 30, 20, 60, 10, 60, 20, 90, 10, 90, 20, 120, 10, 120, 20, 150, 10, 150, 20, 180, 10, 180, 20 }));
            geo ("math-fraction-bar", _("Fraction Bar"), 160, 40, "fraction parts bar")
                .fill (pen ().rect (0, 0, 160, 40).str ())
                .solid (pen ().rect (0, 0, 60, 40).str (), "#5b9bd5")
                .line (StencilKit.lines ({ 20, 0, 20, 40, 40, 0, 40, 40, 60, 0, 60, 40, 80, 0, 80, 40, 100, 0, 100, 40, 120, 0, 120, 40, 140, 0, 140, 40 }));
            geo ("math-fraction-pie", _("Fraction Circle"), 100, 100, "fraction circle pie")
                .fill (pen ().circle (50, 50, 48).str ())
                .solid ("M50 50 L50 2 A48 48 0 0 1 98 50 Z", "#5b9bd5")
                .line (pen ().line (50, 2, 50, 98).line (2, 50, 98, 50).str ());
        }

        private static unowned StencilDef tel (string kind, string name, double w, double h, string kw) {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults ("fill:#dcebf7;stroke:#2f5f8f")
                .label_below ()
                .ports_box ();
        }

        private static void register_telecom () {
            Stencils.category ("telecom", _("Telecom and Security"), "draw-network-symbolic", StencilGroup.NETWORK);
            string[,] boxes = {
                { "pbx", "PBX", "pbx phone exchange", "phone" }, { "sbc", "Session Border Controller", "sbc sip voip border", "shield" }, { "voip-gw", "VoIP Gateway", "voip gateway sip", "send" },
                { "media-gw", "Media Gateway", "media gateway codec", "video" }, { "sdwan", "SD-WAN Edge", "sd-wan edge appliance", "cloud" }, { "olt", "Optical Line Terminal", "olt gpon fiber", "link" },
                { "ont", "Optical Network Terminal", "ont onu fiber", "home" }, { "dslam", "DSLAM", "dslam dsl access", "barcode" }, { "cmts", "CMTS", "cable modem termination", "server" },
                { "mux", "Multiplexer", "mux multiplexer", "sort" }, { "ids", "Intrusion Prevention", "ips ids intrusion", "eye" }, { "waf", "Web Application Firewall", "waf web firewall", "globe" },
                { "siem", "SIEM", "siem logs security monitoring", "chart" }, { "hsm", "Hardware Security Module", "hsm keys crypto", "key" }, { "nac", "Network Access Control", "nac access control", "lock" },
                { "dns", "DNS Server", "dns resolver", "search" }, { "dhcp", "DHCP Server", "dhcp addresses", "tag" }, { "ntp", "Time Server", "ntp time clock", "clock" },
                { "radius", "RADIUS Server", "radius aaa authentication", "users" }, { "mdm", "Device Management", "mdm mobile device management", "mobile" }
            };
            for (int i = 0; i < boxes.length[0]; i++) {
                tel ("tel-" + boxes[i, 0], _(boxes[i, 1]), 90, 40, boxes[i, 2])
                    .fill (pen ().round (0, 0, 90, 40, 4).str ())
                    .solid (pen ().circle (8, 8, 2).circle (16, 8, 2).str (), "#2e7d32")
                    .line (pen ().line (6, 34, 54, 34).str ())
                    .ink (glyph (boxes[i, 3], 60, 6, 26), "@stroke");
            }
            tel ("tel-fax", _("Fax Machine"), 70, 60, "fax facsimile")
                .fill (pen ().rect (0, 20, 70, 40).str ())
                .fill (pen ().rect (14, 0, 42, 22).str ())
                .line (pen ().rect (8, 30, 24, 12).str ());
            tel ("tel-pager", _("Pager"), 50, 40, "pager beeper")
                .fill (pen ().round (0, 0, 50, 40, 6).str ())
                .line (pen ().rect (6, 6, 38, 14).str ());
            tel ("tel-satellite", _("Satellite"), 90, 60, "satellite orbit space")
                .fill (pen ().rect (34, 18, 22, 24).str ())
                .line (pen ().rect (0, 22, 28, 16).rect (62, 22, 28, 16).line (28, 30, 34, 30).line (56, 30, 62, 30).line (45, 18, 45, 6).str ());
            tel ("tel-microwave-link", _("Microwave Dish"), 70, 70, "microwave link dish point to point")
                .fill (pen ().m (10, 10).q (50, 20, 30, 60).z ().str ())
                .line (pen ().line (22, 34, 50, 50).line (50, 50, 50, 70).line (36, 70, 64, 70).str ());
            tel ("tel-5g", _("5G Base Station"), 60, 90, "5g base station gnodeb cell")
                .line (pen ().line (30, 20, 10, 90).line (30, 20, 50, 90).line (16, 66, 44, 66).line (20, 50, 40, 50).arc (30, 20, 10, 200, 340).arc (30, 20, 18, 200, 340).str ());
            tel ("tel-badge-reader", _("Badge Reader"), 40, 60, "access card reader")
                .fill (pen ().round (0, 0, 40, 60, 4).str ())
                .line (pen ().rect (8, 8, 24, 16).circle (20, 42, 6).str ());
            tel ("tel-biometric", _("Fingerprint Reader"), 50, 60, "biometric fingerprint scanner")
                .fill (pen ().round (0, 0, 50, 60, 6).str ())
                .line (pen ().ellipse (25, 30, 6, 9).ellipse (25, 30, 11, 15).ellipse (25, 30, 16, 21).str ());
            tel ("tel-turnstile", _("Turnstile"), 70, 50, "turnstile gate access")
                .fill (pen ().rect (0, 10, 20, 40).rect (50, 10, 20, 40).str ())
                .line (pen ().line (20, 30, 50, 22).line (20, 30, 46, 40).str ());
            tel ("tel-dome-camera", _("Dome Camera"), 60, 40, "dome cctv camera")
                .fill (pen ().m (4, 10).a (26, 26, false, false, 56, 10).z ().str ())
                .line (pen ().rect (0, 4, 60, 6).circle (30, 22, 5).str ());
            tel ("tel-ptz-camera", _("PTZ Camera"), 60, 60, "pan tilt zoom camera")
                .fill (pen ().circle (30, 36, 22).str ())
                .line (pen ().rect (20, 0, 20, 12).line (30, 12, 30, 14).circle (30, 36, 8).str ());
            tel ("tel-alarm-panel", _("Alarm Panel"), 60, 70, "intruder alarm control panel")
                .fill (pen ().rect (0, 0, 60, 70).str ())
                .line (pen ().rect (8, 8, 44, 14).rect (10, 30, 10, 8).rect (25, 30, 10, 8).rect (40, 30, 10, 8).rect (10, 44, 10, 8).rect (25, 44, 10, 8).rect (40, 44, 10, 8).str ());
            tel ("tel-motion-sensor", _("Motion Sensor"), 50, 50, "pir motion detector")
                .fill (pen ().m (0, 0).l (50, 0).l (50, 30).q (25, 56, 0, 30).z ().str ())
                .line (pen ().arc (25, 18, 10, 20, 160).str ());
            tel ("tel-door-contact", _("Door Contact"), 60, 30, "door magnetic contact sensor")
                .fill (pen ().rect (0, 6, 34, 18).rect (38, 9, 22, 12).str ());
            tel ("tel-intercom", _("Intercom"), 50, 70, "door intercom entry phone")
                .fill (pen ().round (0, 0, 50, 70, 6).str ())
                .line (pen ().circle (25, 18, 8).rect (10, 34, 30, 10).circle (25, 56, 5).str ());
        }


        private static unowned StencilDef ui (string kind, string name, double w, double h, string kw, string style = "fill:#ffffff;stroke:#7f7f7f;stroke-width:1;font-size:10;text-color:#3a3a3a") {
            return Stencils.shape (kind, name, w, h, kw)
                .box (w, h)
                .defaults (style)
                .ports_box ();
        }

        private static void register_mobile () {
            Stencils.category ("mobile-ui", _("Mobile Interface"), "draw-shapes-symbolic", StencilGroup.SOFTWARE);
            ui ("mob-status-bar", _("Status Bar"), 360, 24, "mobile status bar battery signal")
                .fill (pen ().rect (0, 0, 360, 24).str ())
                .ink (pen ().rect (326, 8, 22, 10).rect (348, 11, 2, 4).line (300, 18, 300, 14).line (305, 18, 305, 11).line (310, 18, 310, 8).str (), "#3a3a3a")
                .text ("9:41").label (8, 0, 60, 24);
            ui ("mob-app-bar", _("App Bar"), 360, 56, "top app bar toolbar title")
                .fill (pen ().rect (0, 0, 360, 56).str ())
                .ink (pen ().line (16, 22, 34, 22).line (16, 28, 34, 28).line (16, 34, 34, 34).circle (330, 26, 8).line (336, 32, 342, 38).str (), "#3a3a3a")
                .text ("Title").label (50, 0, 240, 56);
            ui ("mob-tab-bar", _("Bottom Navigation"), 360, 64, "bottom navigation tab bar")
                .fill (pen ().rect (0, 0, 360, 64).str ())
                .ink (glyph ("home", 34, 12, 24) + " " + glyph ("search", 120, 12, 24) + " " + glyph ("heart", 206, 12, 24) + " " + glyph ("user", 292, 12, 24), "#3a6ea5");
            ui ("mob-fab", _("Floating Action Button"), 56, 56, "fab floating action button", "fill:#3a6ea5;stroke:#1f4e79;stroke-width:1")
                .fill (pen ().circle (28, 28, 27).str ())
                .ink (pen ().line (28, 18, 28, 38).line (18, 28, 38, 28).str (), "#ffffff");
            ui ("mob-list-item", _("List Item"), 360, 64, "list row item avatar")
                .fill (pen ().rect (0, 0, 360, 64).str ())
                .solid (pen ().circle (32, 32, 18).str (), "#d9d9d9")
                .ink (pen ().poly ({ 336, 24, 344, 32, 336, 40 }, false).str (), "#7f7f7f")
                .text ("List item").label (64, 0, 260, 64);
            ui ("mob-list-switch", _("Settings Row with Switch"), 360, 56, "settings toggle row")
                .fill (pen ().rect (0, 0, 360, 56).str ())
                .solid (pen ().round (300, 18, 40, 20, 10).str (), "#3a6ea5")
                .solid (pen ().circle (330, 28, 8).str (), "#ffffff")
                .text ("Setting").label (16, 0, 260, 56);
            ui ("mob-card", _("Content Card"), 320, 240, "card media content")
                .fill (pen ().round (0, 0, 320, 240, 12).str ())
                .solid (pen ().m (0, 12).a (12, 12, false, true, 12, 0).l (308, 0).a (12, 12, false, true, 320, 12).l (320, 140).l (0, 140).z ().str (), "#d9d9d9")
                .text ("Card title").label (16, 150, 288, 30);
            ui ("mob-search", _("Search Field"), 340, 44, "mobile search field")
                .fill (pen ().round (0, 0, 340, 44, 22).str ())
                .ink (glyph ("search", 12, 10, 24), "#7f7f7f")
                .text ("Search").label (44, 0, 280, 44);
            ui ("mob-chip", _("Chip"), 96, 32, "chip tag filter pill")
                .fill (pen ().round (0, 0, 96, 32, 16).str ())
                .text ("Chip").label (0, 0, 96, 32);
            ui ("mob-segmented", _("Segmented Buttons"), 300, 36, "segmented control buttons", "fill:#ffffff;stroke:#3a6ea5;stroke-width:1;font-size:10;text-color:#3a6ea5")
                .fill (pen ().round (0, 0, 300, 36, 18).str ())
                .solid (pen ().m (18, 0).l (100, 0).l (100, 36).l (18, 36).a (18, 18, false, true, 18, 0).z ().str (), "#dce8f6")
                .line (pen ().line (100, 0, 100, 36).line (200, 0, 200, 36).str ());
            ui ("mob-snackbar", _("Snackbar"), 340, 48, "snackbar message toast", "fill:#323232;stroke:#323232;stroke-width:1;font-size:10;text-color:#ffffff")
                .fill (pen ().round (0, 0, 340, 48, 6).str ())
                .text ("Message sent").label (16, 0, 240, 48);
            ui ("mob-bottom-sheet", _("Bottom Sheet"), 360, 240, "bottom sheet drawer modal")
                .fill (pen ().m (0, 240).l (0, 20).a (20, 20, false, true, 20, 0).l (340, 0).a (20, 20, false, true, 360, 20).l (360, 240).z ().str ())
                .solid (pen ().round (160, 8, 40, 5, 2.5).str (), "#bfbfbf");
            ui ("mob-dialog", _("Alert Dialog"), 280, 180, "alert dialog confirm")
                .fill (pen ().round (0, 0, 280, 180, 16).str ())
                .ink (pen ().line (0, 136, 280, 136).line (140, 136, 140, 180).str (), "#d9d9d9")
                .text ("Dialog title").label (16, 16, 248, 40);
            ui ("mob-keyboard", _("On-Screen Keyboard"), 360, 220, "virtual keyboard mobile", "fill:#d1d5db;stroke:#9ca3af;stroke-width:1")
                .fill (pen ().rect (0, 0, 360, 220).str ())
                .solid (keys (), "#ffffff");
            ui ("mob-slider", _("Mobile Slider"), 300, 30, "slider range seek")
                .solid (pen ().round (0, 13, 300, 4, 2).str (), "#d9d9d9")
                .solid (pen ().round (0, 13, 180, 4, 2).circle (180, 15, 10).str (), "#3a6ea5");
            ui ("mob-progress-ring", _("Progress Indicator"), 48, 48, "progress spinner activity")
                .ink (pen ().arc (24, 24, 20, -90, 180).str (), "#3a6ea5");
            ui ("mob-stepper", _("Quantity Stepper"), 120, 40, "stepper plus minus quantity")
                .fill (pen ().round (0, 0, 120, 40, 20).str ())
                .ink (pen ().line (16, 20, 30, 20).line (90, 20, 104, 20).line (97, 13, 97, 27).str (), "#3a3a3a")
                .text ("1").label (40, 0, 40, 40);
            ui ("mob-avatar-group", _("Avatar Group"), 120, 40, "avatars stacked people")
                .solid (pen ().circle (20, 20, 18).str (), "#5b9bd5")
                .solid (pen ().circle (50, 20, 18).str (), "#6fbf5a")
                .solid (pen ().circle (80, 20, 18).str (), "#f08a3c")
                .ink (pen ().circle (20, 20, 18).circle (50, 20, 18).circle (80, 20, 18).str (), "#ffffff");
            ui ("mob-notification", _("Notification Banner"), 340, 72, "push notification banner")
                .fill (pen ().round (0, 0, 340, 72, 16).str ())
                .solid (pen ().round (12, 16, 40, 40, 10).str (), "#3a6ea5")
                .text ("New message").label (64, 8, 260, 56);
            ui ("mob-carousel-dots", _("Page Indicator"), 80, 16, "carousel dots pager")
                .solid (pen ().circle (16, 8, 5).str (), "#3a6ea5")
                .solid (pen ().circle (40, 8, 5).circle (64, 8, 5).str (), "#d9d9d9");
            ui ("mob-swipe-row", _("Swipe Action Row"), 360, 64, "swipe delete row action", "fill:#e5534b;stroke:#e5534b;stroke-width:1;font-size:10;text-color:#ffffff")
                .fill (pen ().rect (0, 0, 360, 64).str ())
                .solid (pen ().rect (0, 0, 280, 64).str (), "#ffffff")
                .ink (glyph ("trash", 308, 20, 24), "#ffffff");
            ui ("mob-watch", _("Watch Frame"), 180, 220, "smartwatch frame wearable", "fill:#ffffff;stroke:#3a3a3a;stroke-width:3")
                .fill (pen ().rect (50, 0, 80, 220).str ())
                .fill (pen ().round (10, 30, 160, 160, 36).str ());
            ui ("mob-foldable", _("Foldable Phone Frame"), 360, 300, "foldable phone frame", "fill:#ffffff;stroke:#3a3a3a;stroke-width:3")
                .fill (pen ().round (0, 0, 360, 300, 20).str ())
                .line (StencilKit.dashed_line (180, 0, 180, 300, 6, 6));
        }

        private static string keys () {
            var p = pen ();
            for (int r = 0; r < 3; r++) {
                int count = r == 0 ? 10 : (r == 1 ? 9 : 7);
                double w = 30, gap = 6;
                double start = (360 - (count * w + (count - 1) * gap)) / 2;
                for (int i = 0; i < count; i++) p.round (start + i * (w + gap), 10 + r * 50, w, 40, 5);
            }
            p.round (90, 160, 180, 40, 5);
            return p.str ();
        }

        private static void register_agile () {
            Stencils.category ("agile", _("Agile and Kanban"), "draw-shapes-symbolic", StencilGroup.BUSINESS);
            string[,] cards = {
                { "story", "User Story Card", "#5b9bd5" }, { "task", "Task Card", "#6fbf5a" }, { "bug", "Bug Card", "#e5534b" },
                { "epic", "Epic Card", "#8a63c9" }, { "spike", "Spike Card", "#f5c518" }, { "improvement", "Improvement Card", "#35a797" }
            };
            for (int i = 0; i < cards.length[0]; i++) {
                ui ("agile-" + cards[i, 0], _(cards[i, 1]), 180, 110, "kanban card agile " + cards[i, 0])
                    .fill (pen ().round (0, 0, 180, 110, 6).str ())
                    .solid (pen ().rect (0, 0, 6, 110).str (), cards[i, 2])
                    .solid (pen ().circle (160, 90, 10).str (), "#d9d9d9")
                    .text (_(cards[i, 1]).replace (_(" Card"), "")).label (14, 6, 160, 60);
            }
            for (int k = 3; k <= 5; k++) {
                double w = k * 200;
                var cols = pen ();
                for (int i = 0; i < k; i++) cols.rect (i * 200, 0, 200, 400).rect (i * 200, 0, 200, 40);
                ui ("agile-board-%d".printf (k), _("Kanban Board, %d Columns").printf (k), w, 400, "kanban board columns workflow", "fill:#f2f2f2;stroke:#bfbfbf;stroke-width:1;font-size:12;bold:1;valign:top")
                    .fill (cols.str ())
                    .as_container ();
            }
            ui ("agile-sprint", _("Sprint Box"), 400, 200, "sprint iteration timebox", "fill:#e3eefb;stroke:#3a6ea5;stroke-width:1.5;font-size:12;bold:1;valign:top")
                .fill (pen ().round (0, 0, 400, 200, 10).str ())
                .text (_("Sprint")).label (10, 6, 380, 24)
                .as_container ();
            ui ("agile-story-points", _("Story Points Badge"), 40, 40, "estimate points badge", "fill:#3a6ea5;stroke:#1f4e79;stroke-width:1;font-size:12;bold:1;text-color:#ffffff")
                .fill (pen ().circle (20, 20, 19).str ())
                .text ("5").label (0, 0, 40, 40);
            ui ("agile-burndown", _("Burndown Chart"), 220, 140, "burndown chart sprint progress")
                .fill (pen ().rect (0, 0, 220, 140).str ())
                .ink (pen ().line (20, 120, 210, 120).line (20, 10, 20, 120).str (), "#7f7f7f")
                .ink (StencilKit.dashed_line (20, 20, 200, 120, 6, 4), "#a6a6a6")
                .ink (pen ().poly ({ 20, 20, 50, 30, 80, 32, 110, 60, 140, 70, 170, 100, 200, 112 }, false).str (), "#e5534b");
            ui ("agile-velocity", _("Velocity Chart"), 220, 140, "velocity chart sprints")
                .fill (pen ().rect (0, 0, 220, 140).str ())
                .solid (pen ().rect (30, 60, 24, 60).rect (70, 40, 24, 80).rect (110, 50, 24, 70).rect (150, 30, 24, 90).str (), "#5b9bd5")
                .ink (pen ().line (20, 120, 210, 120).str (), "#7f7f7f");
            ui ("agile-cfd", _("Cumulative Flow Diagram"), 220, 140, "cumulative flow diagram cfd")
                .fill (pen ().rect (0, 0, 220, 140).str ())
                .solid (pen ().poly ({ 20, 120, 20, 100, 200, 30, 200, 120 }).str (), "#6fbf5a")
                .solid (pen ().poly ({ 20, 100, 20, 90, 200, 10, 200, 30 }).str (), "#f5c518")
                .solid (pen ().poly ({ 20, 120, 200, 120, 200, 80 }).str (), "#5b9bd5");
            ui ("agile-wip-limit", _("WIP Limit"), 60, 30, "wip limit work in progress", "fill:#fdecea;stroke:#e5534b;stroke-width:1;font-size:11;bold:1;text-color:#c62828")
                .fill (pen ().round (0, 0, 60, 30, 15).str ())
                .text ("WIP 3").label (0, 0, 60, 30);
            ui ("agile-blocker", _("Blocker Marker"), 40, 40, "blocked impediment", "fill:#e5534b;stroke:#c62828;stroke-width:1")
                .fill (pen ().regular (20, 20, 19, 8, -67.5).str ())
                .ink (pen ().line (10, 20, 30, 20).str (), "#ffffff");
            ui ("agile-persona", _("Persona Card"), 200, 140, "persona user profile ux")
                .fill (pen ().round (0, 0, 200, 140, 8).str ())
                .solid (pen ().circle (40, 40, 24).str (), "#d9d9d9")
                .ink (pen ().line (76, 30, 180, 30).line (76, 44, 160, 44).line (16, 84, 184, 84).line (16, 98, 184, 98).line (16, 112, 140, 112).str (), "#bfbfbf");
            ui ("agile-retro", _("Retrospective Board"), 360, 240, "retro start stop continue", "fill:#ffffff;stroke:#bfbfbf;stroke-width:1;font-size:11;bold:1;valign:top")
                .fill (pen ().rect (0, 0, 360, 240).str ())
                .solid (pen ().rect (0, 0, 120, 30).str (), "#bfe3b0")
                .solid (pen ().rect (120, 0, 120, 30).str (), "#fbd3d0")
                .solid (pen ().rect (240, 0, 120, 30).str (), "#b7d3f4")
                .line (pen ().line (120, 0, 120, 240).line (240, 0, 240, 240).str ());
        }

        public static void register () {
            register_mobile ();
            register_agile ();
            register_icons ();
            register_chemistry ();
            register_math ();
            register_telecom ();
        }
    }
}
