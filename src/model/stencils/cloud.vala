namespace Singularity.Apps.Draw {

    public class CloudService {
        public string key;
        public string name;
        public string keywords;
        public string group;
        public string glyph;

        public CloudService (string key, string name, string keywords, string group, string glyph) {
            this.key = key;
            this.name = name;
            this.keywords = keywords;
            this.group = group;
            this.glyph = glyph;
        }
    }

    public class StencilsCloud {
        private static Gee.ArrayList<CloudService> services;

        private static void add (string key, string name, string keywords, string group, string glyph) {
            services.add (new CloudService (key, name, keywords, group, glyph));
        }

        private static void fill_services () {
            services = new Gee.ArrayList<CloudService> ();
            add ("vm", _("Compute Instance"), "vm virtual machine instance ec2 server", "compute", "vm");
            add ("autoscaling", _("Autoscaling Group"), "autoscale scale set elastic", "compute", "scale");
            add ("containers", _("Container Service"), "container docker ecs registry", "compute", "container");
            add ("kubernetes", _("Kubernetes Cluster"), "kubernetes k8s eks aks gke cluster", "compute", "cluster");
            add ("function", _("Serverless Function"), "function serverless lambda faas", "compute", "bolt");
            add ("app-platform", _("App Platform"), "paas app service web app", "compute", "app");
            add ("batch", _("Batch Processing"), "batch jobs hpc", "compute", "layers");
            add ("edge", _("Edge Location"), "edge pop point of presence", "network", "edge");
            add ("cdn", _("Content Delivery Network"), "cdn cloudfront front door cache", "network", "globe");
            add ("dns", _("DNS Service"), "dns domain route53 name", "network", "dns");
            add ("load-balancer", _("Load Balancer"), "load balancer elb alb traffic", "network", "balancer");
            add ("api-gateway", _("API Gateway"), "api gateway rest endpoint management", "network", "api");
            add ("nat", _("NAT Gateway"), "nat address translation", "network", "nat");
            add ("vpn-gateway", _("VPN Gateway"), "vpn tunnel site to site", "network", "vpn");
            add ("direct-link", _("Dedicated Link"), "direct connect expressroute interconnect", "network", "link");
            add ("waf", _("Web Application Firewall"), "waf firewall security", "security", "wall");
            add ("ddos", _("DDoS Protection"), "ddos shield protection", "security", "shieldbolt");
            add ("iam", _("Identity and Access"), "iam identity access users roles entra", "security", "iam");
            add ("kms", _("Key Management"), "kms keys encryption key vault", "security", "key");
            add ("secrets", _("Secrets Manager"), "secrets passwords vault", "security", "lock");
            add ("certificate", _("Certificate Manager"), "certificate tls ssl acm", "security", "certificate");
            add ("object-storage", _("Object Storage"), "bucket blob s3 object storage", "storage", "bucket");
            add ("block-storage", _("Block Storage"), "disk volume ebs managed disk", "storage", "disk");
            add ("file-share", _("File Share"), "file share nfs smb efs files", "storage", "folder");
            add ("archive", _("Archive Storage"), "archive cold glacier", "storage", "archive");
            add ("backup", _("Backup Service"), "backup restore", "storage", "backup");
            add ("sql-db", _("Relational Database"), "sql relational rds database postgres mysql", "database", "database");
            add ("nosql", _("NoSQL Table"), "nosql key value dynamodb table", "database", "table");
            add ("document-db", _("Document Database"), "document json mongodb cosmos", "database", "document");
            add ("cache", _("In-Memory Cache"), "cache redis memcached", "database", "cache");
            add ("warehouse", _("Data Warehouse"), "warehouse redshift synapse bigquery analytics", "database", "warehouse");
            add ("data-lake", _("Data Lake"), "data lake raw storage", "database", "lake");
            add ("etl", _("Data Pipeline"), "etl pipeline glue data factory dataflow", "integration", "pipeline");
            add ("queue", _("Message Queue"), "queue sqs stream kinesis", "integration", "queue");
            add ("pubsub", _("Pub Sub Topic"), "pubsub topic sns publish subscribe", "integration", "broadcast");
            add ("event-bus", _("Event Bus"), "event bus eventbridge event grid", "integration", "bus");
            add ("notification", _("Notification Service"), "notification push alerts", "integration", "bell");
            add ("email", _("Email Service"), "email smtp ses", "integration", "mail");
            add ("workflow", _("Workflow"), "workflow state machine step functions logic apps orchestration", "integration", "workflow");
            add ("monitoring", _("Monitoring"), "monitoring metrics cloudwatch observability", "management", "pulse");
            add ("logging", _("Logging"), "logs logging log analytics", "management", "log");
            add ("tracing", _("Tracing"), "tracing distributed trace x-ray", "management", "trace");
            add ("alerting", _("Alerting"), "alerts alarm incident", "management", "alert");
            add ("iot-hub", _("IoT Hub"), "iot hub internet of things core", "iot", "hub");
            add ("iot-device", _("IoT Device"), "iot device sensor thing", "iot", "iot");
            add ("ml", _("Machine Learning"), "ml ai model sagemaker vertex", "ml", "neural");
            add ("notebook", _("Notebook"), "notebook jupyter data science", "ml", "notebook");
            add ("analytics", _("Analytics Dashboard"), "analytics bi dashboard quicksight power bi", "ml", "chart");
            add ("search", _("Search Service"), "search index opensearch", "ml", "search");
            add ("mobile-backend", _("Mobile Backend"), "mobile app backend amplify", "other", "mobile");
            add ("user", _("User"), "user client person", "other", "person");
            add ("on-premises", _("On-Premises Data Center"), "on premises datacenter corporate", "other", "building");
            add ("service", _("Generic Service"), "service generic resource", "other", "cube");
        }

        private static string aws_color (string group) {
            switch (group) {
                case "compute": return "#e8730c";
                case "network": return "#8c4fff";
                case "security": return "#dd344c";
                case "storage": return "#5d9a1f";
                case "database": return "#3b48cc";
                case "integration": return "#e7157b";
                case "management": return "#c7157b";
                case "iot": return "#2e8540";
                case "ml": return "#01a88d";
                default: return "#56616e";
            }
        }

        private static string azure_color (string group) {
            switch (group) {
                case "compute": return "#0f6cbd";
                case "network": return "#5c2d91";
                case "security": return "#a4262c";
                case "storage": return "#107c10";
                case "database": return "#004e8c";
                case "integration": return "#8a3fb0";
                case "management": return "#005b70";
                case "iot": return "#0b6a0b";
                case "ml": return "#0078d4";
                default: return "#3b4f63";
            }
        }

        private static string gcp_color (string group) {
            switch (group) {
                case "compute": return "#4285f4";
                case "network": return "#4285f4";
                case "security": return "#ea4335";
                case "storage": return "#34a853";
                case "database": return "#4285f4";
                case "integration": return "#fbbc04";
                case "management": return "#ea4335";
                case "iot": return "#34a853";
                case "ml": return "#fbbc04";
                default: return "#5f6368";
            }
        }

        private static void aws (CloudService s) {
            Stencils.shape ("aws-" + s.key, s.name, 64, 64, s.keywords + " aws amazon")
                .box (64, 64)
                .defaults ("fill:%s;stroke:none;stroke-width:1.5".printf (aws_color (s.group)))
                .fill (new TechPen ().round (0, 0, 64, 64, 6).str ())
                .ink (TechGlyphs.draw (s.glyph, 12, 12, 40), "#ffffff")
                .label_below ()
                .ports_box ();
        }

        private static void azure (CloudService s) {
            string c = azure_color (s.group);
            Stencils.shape ("az-" + s.key, s.name, 64, 64, s.keywords + " azure microsoft")
                .box (64, 64)
                .defaults ("fill:%s;stroke:%s;stroke-width:2".printf (Colors.rgb_hex (Colors.mix (c, "#ffffff", 0.86)), c))
                .solid (new TechPen ().round (2, 2, 60, 60, 12).str (), "@fill")
                .ink (TechGlyphs.draw (s.glyph, 10, 10, 44), "@stroke")
                .label_below ()
                .ports_box ();
        }

        private static void gcp (CloudService s) {
            Stencils.shape ("gcp-" + s.key, s.name, 64, 60, s.keywords + " gcp google cloud")
                .box (64, 60)
                .defaults ("fill:#ffffff;stroke:%s;stroke-width:2".printf (gcp_color (s.group)))
                .fill (new TechPen ().poly ({ 16, 2, 48, 2, 63, 30, 48, 58, 16, 58, 1, 30 }).str ())
                .ink (TechGlyphs.draw (s.glyph, 16, 14, 32), "#5f6368")
                .solid (new TechPen ().rect (16, 50, 32, 3).str (), "@stroke")
                .label_below ()
                .ports_box ();
        }

        private static void group_shape (string kind, string name, string keywords, string glyph, string style) {
            var p = new TechPen ();
            Stencils.shape (kind, name, 320, 220, keywords)
                .box (320, 220)
                .defaults ("valign:top;halign:left;font-size:10;bold:1;" + style)
                .fill (p.rect (0, 0, 320, 220).str ())
                .ink (TechGlyphs.draw (glyph, 4, 3, 20), "@stroke")
                .label (28, 2, 288, 22)
                .text (name)
                .as_container ()
                .ports_box ();
        }

        private static void groups (string prefix, string suffix, string accent, string tint) {
            group_shape (prefix + "region", _("Region"), "region geography" + suffix, "globe", "fill:%s;stroke:%s;dash:dash;stroke-width:1.5".printf ("#ffffff00", accent));
            group_shape (prefix + "zone", _("Availability Zone"), "availability zone az datacenter" + suffix, "building", "fill:#ffffff00;stroke:%s;dash:dash;stroke-width:1.2".printf (Colors.rgb_hex (Colors.mix (accent, "#ffffff", 0.3))));
            group_shape (prefix + "vpc", _("Virtual Network"), "vpc vnet virtual network" + suffix, "vpc", "fill:%s;stroke:%s;stroke-width:1.5".printf (tint, accent));
            group_shape (prefix + "subnet", _("Subnet"), "subnet private public" + suffix, "grid", "fill:%s;stroke:%s;stroke-width:1".printf (Colors.rgb_hex (Colors.mix (tint, "#ffffff", 0.4)), accent));
            group_shape (prefix + "security-group", _("Security Group"), "security group nsg firewall rules" + suffix, "shield", "fill:#ffffff00;stroke:#c62828;dash:dash;stroke-width:1.5");
        }

        public static void register () {
            fill_services ();
            Stencils.category ("cloud-aws", _("Cloud: AWS Style"), "draw-network-symbolic", StencilGroup.CLOUD);
            foreach (var s in services) aws (s);
            groups ("aws-", " aws", "#147eba", "#eef6fb");
            Stencils.category ("cloud-azure", _("Cloud: Azure Style"), "draw-network-symbolic", StencilGroup.CLOUD);
            foreach (var s in services) azure (s);
            groups ("az-", " azure", "#0f6cbd", "#eef5fc");
            Stencils.category ("cloud-gcp", _("Cloud: Google Cloud Style"), "draw-network-symbolic", StencilGroup.CLOUD);
            foreach (var s in services) gcp (s);
            groups ("gcp-", " gcp google", "#4285f4", "#f1f5fe");
        }
    }
}
