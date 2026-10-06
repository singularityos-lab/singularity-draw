namespace Singularity.Apps.Draw {

    public class DataSource {
        public string id = "";
        public string name = "";
        public string kind = "csv";
        public string path = "";
        public string sheet = "";
        public string query = "";
        public string key_column = "";
        public int64 refreshed = 0;
        public CsvTable? table = null;

        public DataSource copy () {
            var d = new DataSource ();
            d.id = id;
            d.name = name;
            d.kind = kind;
            d.path = path;
            d.sheet = sheet;
            d.query = query;
            d.key_column = key_column;
            d.refreshed = refreshed;
            d.table = table;
            return d;
        }
    }

    public class DataGraphicRule {
        public string op = ">=";
        public string value = "";
        public string color = "";
        public string icon = "";

        public DataGraphicRule copy () {
            var r = new DataGraphicRule ();
            r.op = op;
            r.value = value;
            r.color = color;
            r.icon = icon;
            return r;
        }
    }

    public class DataGraphicItem {
        public string field = "";
        public string kind = "text";
        public string position = "top-right";
        public double min = 0;
        public double max = 100;
        public string color = "#3a6ea5";
        public string icon_set = "traffic";
        public Gee.ArrayList<DataGraphicRule> rules = new Gee.ArrayList<DataGraphicRule> ();

        public DataGraphicItem copy () {
            var i = new DataGraphicItem ();
            i.field = field;
            i.kind = kind;
            i.position = position;
            i.min = min;
            i.max = max;
            i.color = color;
            i.icon_set = icon_set;
            foreach (var r in rules) i.rules.add (r.copy ());
            return i;
        }
    }

    public class DataGraphic {
        public string id = "";
        public string name = "";
        public Gee.ArrayList<DataGraphicItem> items = new Gee.ArrayList<DataGraphicItem> ();

        public DataGraphic copy () {
            var g = new DataGraphic ();
            g.id = id;
            g.name = name;
            foreach (var i in items) g.items.add (i.copy ());
            return g;
        }
    }
}
