namespace IBusMcBopomofo {
  class BusWatcher : Object {
    public DBusConnection connection { get; construct; }
    private uint handle;

    public signal void notify_preedit(bool value);

    public BusWatcher(DBusConnection conn) {
      Object(connection: conn);

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
              this.notify_preedit(val.get_boolean());
            }
          }
        });
    }

    ~BusWatcher() {
      // XXX: will this ever be called?
      warning("bus watcher destructor is called!!");
      var conn = this.connection;
      if (!conn.closed) {
        conn.signal_unsubscribe(this.handle);
      }
      this.handle = 0;
    }
  }
}
