namespace Singularity.Apps.Draw {

    public enum LayoutKind {
        TREE_DOWN,
        TREE_RIGHT,
        HIERARCHICAL,
        HIERARCHICAL_RIGHT,
        FORCE,
        CIRCLE,
        GRID
    }

    public class AutoLayout {
        private class Node {
            public Shape? shape;
            public int index;
            public double w;
            public double h;
            public double x;
            public double y;
            public int layer;
            public double order;
            public Gee.ArrayList<Node> outs = new Gee.ArrayList<Node> ();
            public Gee.ArrayList<Node> ins = new Gee.ArrayList<Node> ();
            public Gee.ArrayList<Node> children = new Gee.ArrayList<Node> ();
            public double subtree;
        }

        public double hgap = 40;
        public double vgap = 60;
        private Gee.ArrayList<Node> nodes = new Gee.ArrayList<Node> ();
        private Gee.HashMap<string, Node> by_id = new Gee.HashMap<string, Node> ();

        public static bool apply (Page page, Gee.Collection<Item> selection, LayoutKind kind, double hgap = 40, double vgap = 60) {
            var l = new AutoLayout ();
            l.hgap = hgap;
            l.vgap = vgap;
            return l.run (page, selection, kind);
        }

        private bool run (Page page, Gee.Collection<Item> selection, LayoutKind kind) {
            var shapes = new Gee.ArrayList<Shape> ();
            foreach (var it in selection) {
                var s = it as Shape;
                if (s != null && !s.is_container () && !page.item_locked (s)) shapes.add (s);
            }
            if (shapes.size == 0) {
                foreach (var it in page.items) {
                    var s = it as Shape;
                    if (s != null && !s.is_container () && !page.item_locked (s)) shapes.add (s);
                }
            }
            if (shapes.size < 2) return false;
            var origin = Rect.empty ();
            foreach (var s in shapes) origin = origin.union (s.bounds ());
            foreach (var s in shapes) {
                var n = new Node ();
                n.shape = s;
                n.index = nodes.size;
                var b = s.bounds ();
                n.w = b.w;
                n.h = b.h;
                n.x = b.cx ();
                n.y = b.cy ();
                nodes.add (n);
                by_id[s.id] = n;
            }
            var edge_keys = new Gee.HashSet<string> ();
            foreach (var c in page.connectors ()) {
                if (!by_id.has_key (c.src.item_id) || !by_id.has_key (c.dst.item_id)) continue;
                if (c.src.item_id == c.dst.item_id) continue;
                string key = c.src.item_id + ">" + c.dst.item_id;
                if (edge_keys.contains (key)) continue;
                edge_keys.add (key);
                var a = by_id[c.src.item_id];
                var b = by_id[c.dst.item_id];
                a.outs.add (b);
                b.ins.add (a);
            }
            switch (kind) {
                case LayoutKind.TREE_DOWN: tree (false); break;
                case LayoutKind.TREE_RIGHT: tree (true); break;
                case LayoutKind.HIERARCHICAL: hierarchical (false); break;
                case LayoutKind.HIERARCHICAL_RIGHT: hierarchical (true); break;
                case LayoutKind.FORCE: force (); break;
                case LayoutKind.CIRCLE: circle (); break;
                case LayoutKind.GRID: grid (); break;
            }
            var nb = Rect.empty ();
            foreach (var n in nodes) nb = nb.union (Rect (n.x - n.w / 2, n.y - n.h / 2, n.w, n.h));
            double dx = origin.x - nb.x, dy = origin.y - nb.y;
            foreach (var n in nodes) {
                var s = n.shape;
                var b = s.bounds ();
                double tx = n.x + dx - b.cx (), ty = n.y + dy - b.cy ();
                s.x += tx;
                s.y += ty;
            }
            return true;
        }

        private Gee.ArrayList<Node> roots () {
            var list = new Gee.ArrayList<Node> ();
            foreach (var n in nodes) if (n.ins.size == 0) list.add (n);
            if (list.size == 0) {
                Node best = nodes[0];
                foreach (var n in nodes) if (n.outs.size > best.outs.size) best = n;
                list.add (best);
            }
            return list;
        }

        private void tree (bool horizontal) {
            var visited = new Gee.HashSet<Node> ();
            var rs = roots ();
            var forest = new Gee.ArrayList<Node> ();
            foreach (var r in rs) {
                if (visited.contains (r)) continue;
                forest.add (r);
                build_tree (r, visited);
            }
            foreach (var n in nodes) {
                if (!visited.contains (n)) {
                    forest.add (n);
                    build_tree (n, visited);
                }
            }
            double cursor = 0;
            foreach (var r in forest) {
                measure (r, horizontal);
                place (r, cursor, 0, horizontal);
                cursor += r.subtree + hgap * 1.5;
            }
        }

        private void build_tree (Node root, Gee.HashSet<Node> visited) {
            var queue = new Gee.ArrayList<Node> ();
            queue.add (root);
            visited.add (root);
            while (queue.size > 0) {
                var n = queue.remove_at (0);
                var outs = new Gee.ArrayList<Node> ();
                outs.add_all (n.outs);
                outs.sort ((a, b) => {
                    double ka = a.shape.x, kb = b.shape.x;
                    return ka < kb ? -1 : (ka > kb ? 1 : 0);
                });
                foreach (var c in outs) {
                    if (visited.contains (c)) continue;
                    visited.add (c);
                    n.children.add (c);
                    queue.add (c);
                }
            }
        }

        private double breadth (Node n, bool horizontal) {
            return horizontal ? n.h : n.w;
        }

        private double depth_size (Node n, bool horizontal) {
            return horizontal ? n.w : n.h;
        }

        private void measure (Node n, bool horizontal) {
            double sum = 0;
            foreach (var c in n.children) {
                measure (c, horizontal);
                sum += c.subtree;
            }
            if (n.children.size > 1) sum += hgap * (n.children.size - 1);
            n.subtree = double.max (breadth (n, horizontal), sum);
        }

        private void place (Node n, double start, double level_pos, bool horizontal) {
            double center = start + n.subtree / 2;
            double child_level = level_pos + depth_size (n, horizontal) / 2 + vgap;
            double max_child_depth = 0;
            foreach (var c in n.children) max_child_depth = double.max (max_child_depth, depth_size (c, horizontal));
            if (horizontal) {
                n.x = level_pos;
                n.y = center;
            } else {
                n.x = center;
                n.y = level_pos;
            }
            double total = 0;
            foreach (var c in n.children) total += c.subtree;
            if (n.children.size > 1) total += hgap * (n.children.size - 1);
            double cur = center - total / 2;
            foreach (var c in n.children) {
                place (c, cur, child_level + max_child_depth / 2, horizontal);
                cur += c.subtree + hgap;
            }
        }

        private void hierarchical (bool horizontal) {
            var state = new Gee.HashMap<Node, int> ();
            var reversed = new Gee.HashSet<string> ();
            foreach (var n in nodes) state[n] = 0;
            foreach (var n in nodes) if (state[n] == 0) dfs_cycles (n, state, reversed);
            var outs = new Gee.HashMap<Node, Gee.ArrayList<Node>> ();
            var ins = new Gee.HashMap<Node, Gee.ArrayList<Node>> ();
            foreach (var n in nodes) {
                outs[n] = new Gee.ArrayList<Node> ();
                ins[n] = new Gee.ArrayList<Node> ();
            }
            foreach (var n in nodes) {
                foreach (var m in n.outs) {
                    string key = "%d>%d".printf (n.index, m.index);
                    if (reversed.contains (key)) {
                        outs[m].add (n);
                        ins[n].add (m);
                    } else {
                        outs[n].add (m);
                        ins[m].add (n);
                    }
                }
            }
            var order = topo (outs, ins);
            foreach (var n in order) {
                int l = 0;
                foreach (var p in ins[n]) l = int.max (l, p.layer + 1);
                n.layer = l;
            }
            int max_layer = 0;
            foreach (var n in nodes) max_layer = int.max (max_layer, n.layer);
            var layers = new Gee.ArrayList<Gee.ArrayList<Node>> ();
            for (int i = 0; i <= max_layer; i++) layers.add (new Gee.ArrayList<Node> ());
            var all_nodes = new Gee.ArrayList<Node> ();
            all_nodes.add_all (nodes);
            var down = new Gee.HashMap<Node, Gee.ArrayList<Node>> ();
            var up = new Gee.HashMap<Node, Gee.ArrayList<Node>> ();
            foreach (var n in nodes) {
                down[n] = new Gee.ArrayList<Node> ();
                up[n] = new Gee.ArrayList<Node> ();
            }
            foreach (var n in nodes) {
                foreach (var m in outs[n]) {
                    Node prev = n;
                    for (int l = n.layer + 1; l < m.layer; l++) {
                        var dummy = new Node ();
                        dummy.layer = l;
                        dummy.w = 0;
                        dummy.h = 0;
                        dummy.index = -1;
                        down[dummy] = new Gee.ArrayList<Node> ();
                        up[dummy] = new Gee.ArrayList<Node> ();
                        down[prev].add (dummy);
                        up[dummy].add (prev);
                        all_nodes.add (dummy);
                        prev = dummy;
                    }
                    down[prev].add (m);
                    up[m].add (prev);
                }
            }
            foreach (var n in all_nodes) layers[n.layer].add (n);
            foreach (var layer in layers) {
                layer.sort ((a, b) => {
                    double ka = horizontal ? a.y : a.x, kb = horizontal ? b.y : b.x;
                    return ka < kb ? -1 : (ka > kb ? 1 : 0);
                });
                for (int i = 0; i < layer.size; i++) layer[i].order = i;
            }
            for (int sweep = 0; sweep < 12; sweep++) {
                bool downward = sweep % 2 == 0;
                if (downward) {
                    for (int l = 1; l < layers.size; l++) reorder (layers[l], up);
                } else {
                    for (int l = layers.size - 2; l >= 0; l--) reorder (layers[l], down);
                }
            }
            double level = 0;
            var pos = new Gee.HashMap<Node, double?> ();
            foreach (var layer in layers) {
                double cur = 0;
                foreach (var n in layer) {
                    double b = horizontal ? n.h : n.w;
                    pos[n] = cur + b / 2;
                    cur += b + (n.index < 0 ? hgap / 3 : hgap);
                }
            }
            for (int pass = 0; pass < 8; pass++) {
                for (int l = 0; l < layers.size; l++) {
                    var layer = layers[l];
                    for (int i = 0; i < layer.size; i++) {
                        var n = layer[i];
                        var nb = new Gee.ArrayList<Node> ();
                        nb.add_all (up[n]);
                        nb.add_all (down[n]);
                        if (nb.size == 0) continue;
                        double target = 0;
                        foreach (var m in nb) target += pos[m];
                        target /= nb.size;
                        pos[n] = target;
                    }
                    for (int i = 1; i < layer.size; i++) {
                        var a = layer[i - 1];
                        var b = layer[i];
                        double min_gap = ((horizontal ? a.h : a.w) + (horizontal ? b.h : b.w)) / 2 + (a.index < 0 || b.index < 0 ? hgap / 3 : hgap);
                        if (pos[b] - pos[a] < min_gap) pos[b] = pos[a] + min_gap;
                    }
                    for (int i = layer.size - 2; i >= 0; i--) {
                        var a = layer[i];
                        var b = layer[i + 1];
                        double min_gap = ((horizontal ? a.h : a.w) + (horizontal ? b.h : b.w)) / 2 + (a.index < 0 || b.index < 0 ? hgap / 3 : hgap);
                        if (pos[b] - pos[a] < min_gap) pos[a] = pos[b] - min_gap;
                    }
                }
            }
            foreach (var layer in layers) {
                double depth = 0;
                foreach (var n in layer) depth = double.max (depth, horizontal ? n.w : n.h);
                foreach (var n in layer) {
                    if (n.index < 0) continue;
                    if (horizontal) {
                        n.x = level + depth / 2;
                        n.y = pos[n];
                    } else {
                        n.x = pos[n];
                        n.y = level + depth / 2;
                    }
                }
                level += depth + vgap;
            }
        }

        private void reorder (Gee.ArrayList<Node> layer, Gee.HashMap<Node, Gee.ArrayList<Node>> adj) {
            foreach (var n in layer) {
                var nb = adj[n];
                if (nb.size == 0) continue;
                double sum = 0;
                foreach (var m in nb) sum += m.order;
                n.order = sum / nb.size + n.order * 0.001;
            }
            layer.sort ((a, b) => a.order < b.order ? -1 : (a.order > b.order ? 1 : 0));
            for (int i = 0; i < layer.size; i++) layer[i].order = i;
        }

        private void dfs_cycles (Node n, Gee.HashMap<Node, int> state, Gee.HashSet<string> reversed) {
            state[n] = 1;
            foreach (var m in n.outs) {
                if (state[m] == 1) reversed.add ("%d>%d".printf (n.index, m.index));
                else if (state[m] == 0) dfs_cycles (m, state, reversed);
            }
            state[n] = 2;
        }

        private Gee.ArrayList<Node> topo (Gee.HashMap<Node, Gee.ArrayList<Node>> outs, Gee.HashMap<Node, Gee.ArrayList<Node>> ins) {
            var indeg = new Gee.HashMap<Node, int> ();
            foreach (var n in nodes) indeg[n] = ins[n].size;
            var queue = new Gee.ArrayList<Node> ();
            foreach (var n in nodes) if (indeg[n] == 0) queue.add (n);
            var result = new Gee.ArrayList<Node> ();
            while (queue.size > 0) {
                var n = queue.remove_at (0);
                result.add (n);
                foreach (var m in outs[n]) {
                    indeg[m] = indeg[m] - 1;
                    if (indeg[m] == 0) queue.add (m);
                }
            }
            foreach (var n in nodes) if (!result.contains (n)) result.add (n);
            return result;
        }

        private void force () {
            int n = nodes.size;
            double avg = 0;
            foreach (var nd in nodes) avg += Math.hypot (nd.w, nd.h);
            avg /= n;
            double k = avg + hgap;
            var rnd = new Rand.with_seed (42);
            for (int i = 0; i < n; i++) {
                for (int j = 0; j < i; j++) {
                    if ((nodes[i].x - nodes[j].x).abs () < 1 && (nodes[i].y - nodes[j].y).abs () < 1) {
                        nodes[i].x += rnd.double_range (-k, k);
                        nodes[i].y += rnd.double_range (-k, k);
                    }
                }
            }
            double temp = k * Math.sqrt (n);
            var dx = new double[n];
            var dy = new double[n];
            for (int iter = 0; iter < 400; iter++) {
                for (int i = 0; i < n; i++) {
                    dx[i] = 0;
                    dy[i] = 0;
                }
                for (int i = 0; i < n; i++) {
                    for (int j = i + 1; j < n; j++) {
                        double ex = nodes[i].x - nodes[j].x, ey = nodes[i].y - nodes[j].y;
                        double d = double.max (Math.hypot (ex, ey), 0.01);
                        double f = k * k / d;
                        dx[i] += ex / d * f;
                        dy[i] += ey / d * f;
                        dx[j] -= ex / d * f;
                        dy[j] -= ey / d * f;
                    }
                }
                foreach (var a in nodes) {
                    foreach (var b in a.outs) {
                        double ex = a.x - b.x, ey = a.y - b.y;
                        double d = double.max (Math.hypot (ex, ey), 0.01);
                        double f = d * d / k;
                        dx[a.index] -= ex / d * f;
                        dy[a.index] -= ey / d * f;
                        dx[b.index] += ex / d * f;
                        dy[b.index] += ey / d * f;
                    }
                }
                for (int i = 0; i < n; i++) {
                    double d = double.max (Math.hypot (dx[i], dy[i]), 0.01);
                    double step = double.min (d, temp);
                    nodes[i].x += dx[i] / d * step;
                    nodes[i].y += dy[i] / d * step;
                }
                temp = double.max (temp * 0.985, 0.5);
            }
            remove_overlaps ();
        }

        private void remove_overlaps () {
            for (int iter = 0; iter < 60; iter++) {
                bool moved = false;
                for (int i = 0; i < nodes.size; i++) {
                    for (int j = i + 1; j < nodes.size; j++) {
                        var a = nodes[i];
                        var b = nodes[j];
                        double ox = (a.w + b.w) / 2 + hgap / 2 - (a.x - b.x).abs ();
                        double oy = (a.h + b.h) / 2 + hgap / 2 - (a.y - b.y).abs ();
                        if (ox > 0 && oy > 0) {
                            moved = true;
                            if (ox < oy) {
                                double s = (a.x < b.x ? -1 : 1) * ox / 2;
                                a.x += s;
                                b.x -= s;
                            } else {
                                double s = (a.y < b.y ? -1 : 1) * oy / 2;
                                a.y += s;
                                b.y -= s;
                            }
                        }
                    }
                }
                if (!moved) break;
            }
        }

        private void circle () {
            double perim = 0;
            foreach (var n in nodes) perim += Math.hypot (n.w, n.h) + hgap;
            double r = double.max (perim / (2 * Math.PI), 60);
            var order = new Gee.ArrayList<Node> ();
            var seen = new Gee.HashSet<Node> ();
            foreach (var root in roots ()) walk_order (root, order, seen);
            foreach (var n in nodes) if (!seen.contains (n)) walk_order (n, order, seen);
            for (int i = 0; i < order.size; i++) {
                double a = -Math.PI / 2 + i * 2 * Math.PI / order.size;
                order[i].x = r * Math.cos (a);
                order[i].y = r * Math.sin (a);
            }
        }

        private void walk_order (Node n, Gee.ArrayList<Node> order, Gee.HashSet<Node> seen) {
            if (seen.contains (n)) return;
            seen.add (n);
            order.add (n);
            foreach (var m in n.outs) walk_order (m, order, seen);
        }

        private void grid () {
            int cols = (int) Math.ceil (Math.sqrt (nodes.size));
            double cw = 0, ch = 0;
            foreach (var n in nodes) {
                cw = double.max (cw, n.w);
                ch = double.max (ch, n.h);
            }
            var sorted = new Gee.ArrayList<Node> ();
            sorted.add_all (nodes);
            sorted.sort ((a, b) => {
                double ka = a.y * 10000 + a.x, kb = b.y * 10000 + b.x;
                return ka < kb ? -1 : (ka > kb ? 1 : 0);
            });
            for (int i = 0; i < sorted.size; i++) {
                sorted[i].x = (i % cols) * (cw + hgap) + cw / 2;
                sorted[i].y = (i / cols) * (ch + vgap / 1.5) + ch / 2;
            }
        }
    }
}
