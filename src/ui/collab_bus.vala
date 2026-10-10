namespace Singularity.Apps.Draw {

    [DBus (name = "dev.sinty.Collab.Drawing1")]
    public class DrawCollabBus : Object {
        private unowned DrawApp app;

        public DrawCollabBus (DrawApp app) {
            this.app = app;
        }

        public void receive (string title, string payload, string from) throws Error {
            var state = LiveSession.decode_text (payload);
            if (state == null) throw new IOError.INVALID_DATA ("not a drawing");
            var w = new DrawWindow (app);
            w.present ();
            w.load_document (DrawLiveSync.document_from (state));
        }

        public void join (string session, string title, string snapshot, string role, string from) throws Error {
            var w = new DrawWindow (app);
            w.present ();
            w.new_document ();
            DrawLive.join_collab (w, session, snapshot, from);
        }
    }
}
