namespace IBusMcBopomofo {
  class BusWatcher : Object {
    public DBusConnection connection { get; construct; }
    public bool embed_preedit_text { get; set construct; }

    private uint handle;

    public BusWatcher(DBusConnection conn) {
      Object(connection: conn, embed_preedit_text: true);

      this.handle = conn.signal_subscribe(
        /* sender */ null,
        /* ifname */ "org.freedesktop.DBus.Properties",
        /* member */ "PropertiesChanged",
        /* objpath */ "/org/freedesktop/IBus",
        /* arg0 */ null,
        DBusSignalFlags.NONE,
        (_conn, _sender, _objpath, _ifname, _signame, args) => {
          VariantIter dict;
          // [String, dict of {string, variant}, String[]]
          args.get("(sa{sv}as)", null, out dict, null);

          string key;
          Variant val;
          while (dict.next("{sv}", out key, out val)) {
            if (key == "EmbedPreeditText") {
              this.embed_preedit_text = val.get_boolean();
              debug("embed_preedit_text is set to %s!", this.embed_preedit_text.to_string());
            }
          }
        });

      conn.call.begin(
        /* busname */ "org.freedesktop.IBus",
        /* objpath */ "/org/freedesktop/IBus",
        /* ifname */ "org.freedesktop.DBus.Properties",
        /* method */ "Get",
        new Variant("(ss)", "org.freedesktop.IBus", "EmbedPreeditText"),
        new VariantType("(v)"),
        DBusCallFlags.NONE,
        -1, null, (obj, res) => {
          try {
            Variant v;
            conn.call.end(res).get("(v)", out v);
            this.embed_preedit_text = v.get_boolean();
          } catch (Error e) {
            warning("Error getting value of EmbedPreeditText from ibus connection: %s",
              e.message);
          }
        });
    }

    public override void dispose() {
      var conn = this.connection;
      if (this.handle != 0 && !conn.closed) {
        conn.signal_unsubscribe(this.handle);
      }
      this.handle = 0;
      // TODO: if the async call is ongoing, cancel it

      base.dispose();
    }
  }
}
