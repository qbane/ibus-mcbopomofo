static bool ibus;

string? test_model_dir(string path_base) {
  var path = Path.build_filename(path_base, "ibus-mcbopomofo", "data");
  if (FileUtils.test(path, FileTest.IS_DIR)) {
    return path;
  }
  return null;
}

// ad-hoc way to probe a valid data dir
string? probe_model_dir() {
  var userPath = Environment.get_user_data_dir();
  string? dir;
  if ((dir = test_model_dir(userPath)) != null) {
    info("Language model is found in user data dir: [%s].", dir);
    return dir;
  }

  var systemPaths = Environment.get_system_data_dirs();
  foreach (var sysPath in systemPaths) {
    debug("Trying [%s]...", sysPath);
    if ((dir = test_model_dir(sysPath)) != null) {
      info("Language model is found in one of system data dirs: [%s].", dir);
      return dir;
    }
  }

  return null;
}

SourceFunc quitSignalCallback(string signame) {
  return () => {
    warning("Received signal %s, exiting...", signame);
    IBus.quit();
    return Source.CONTINUE;
  };
}

int main(string[] args) {
  Intl.setlocale();
  Environment.set_prgname("ibus-engine-mcbpmf");
  Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
  Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");

  // from ibus-skk
  const OptionEntry[] options = {
    { "ibus", 'i', OptionFlags.NONE, OptionArg.NONE, ref ibus,
      N_("Component is executed by IBus"), null },
    { null }
  };

  try {
    var opt_context = new OptionContext ("- ibus-mcbopomofo");
    opt_context.set_help_enabled(true);
    opt_context.add_main_entries(options, null);
    opt_context.parse(ref args);
  } catch (OptionError e) {
    print("%s\n", e.message);
    return 1;
  }

  Unix.signal_add(Posix.Signal.INT, quitSignalCallback("SIGINT"));
  Unix.signal_add(Posix.Signal.TERM, quitSignalCallback("SIGTERM"));

  if (!ibus) {
    warning("Launching this program without --ibus is WIP... " +
      "Please launch this program with --ibus argument.");
  }

  string? model_path = probe_model_dir();
  if (model_path != null) {
    IBusMcBopomofo.Engine.builtin_lm_dir = model_path;
  } else {
    warning("Cannot find directory containing the built-in language model. " +
      "Please either check your XDG data directories or specify one from $XDG_DATA_HOME.");
  }

  IBus.init();
  // TODO: determine verbose argument
  IBus.set_log_handler(true);
  var bus = new IBus.Bus();

  if (!bus.is_connected()) {
    warning("Cannot connect to ibus daemon.");
    return 1;
  }

  bus.disconnected.connect(() => {
    IBus.quit();
  });

  IBusMcBopomofo.Engine.bus = bus;

  IBus.Factory factory = new IBus.Factory(bus.get_connection());

  factory.add_engine("mcbopomofo", typeof(IBusMcBopomofo.Engine));

  if (bus.request_name("org.openVanilla.McBopomofo", 0) == 0) {
    warning("Cannot obtain bus name");
    return 1;
  }

  IBus.main();

  return 0;
}
