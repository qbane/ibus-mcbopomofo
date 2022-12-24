using GLib;

// manually maintained, do edit
[CCode (cheader_filename = "api/McBopomofoApi.h")]
namespace McbpmfApi {
  [CCode (type_id = "mcbpmf_api_core_get_type()")]
  public class Core : GLib.Object {
    public Core();
    public bool load_model(string lm_path);

    public InputState get_state();
    public void set_state(owned InputState next_state);
    public void reset_state(bool full_reset = true);
    public bool handle_key(KeyDef key, out InputState next_state, out bool has_error = null);
    public bool select_candidate(int which, out InputState next_state);

    public signal void custom_phrase_added(string reading, string phrase);

    [NoAccessorMethod]
    public InputMode input_mode { set; get; }
    [NoAccessorMethod]
    public KeyboardLayout keyboard_layout { set; }
    [NoAccessorMethod]
    public bool select_cand_after_cursor { set; }
    [NoAccessorMethod]
    public bool auto_advance_cursor { set; }
    [NoAccessorMethod]
    public bool put_lcase_letters_to_buffer { set; }
    [NoAccessorMethod]
    public bool esc_clears_buffer { set; }
    [NoAccessorMethod]
    public CtrlEnterBehavior ctrl_enter_key { set; }
  }

  [Compact]
  [CCode (ref_function = "mcbpmf_api_keydef_ref" ,
          type_id = "mcbpmf_api_keydef_get_type()" ,
          unref_function = "mcbpmf_api_keydef_unref",
          cprefix = "mcbpmf_api_keydef_")]
  public class KeyDef {
    public KeyDef.ascii(char c, uchar mods);
    public KeyDef.named(int mkey, uchar mods);
  }

  [Compact]
  [CCode (ref_function = "mcbpmf_api_input_state_ref",
          type_id = "mcbpmf_api_input_state_get_type()",
          unref_function = "mcbpmf_api_input_state_unref",
          cprefix = "mcbpmf_api_state_")]
  public class InputState {
    public InputStateType get_type();
    public bool is_empty();
    public unowned string? peek_buf();
    public int peek_index();
    public unowned string? peek_tooltip();
    public GenericArray<string>? get_candidates();
  }

  [CCode (cprefix = "MCBPMF_API_INPUT_MODE_", type_id = "mcbpmf_api_input_mode_get_type()")]
  public enum InputMode {
    CLASSIC,
    PLAIN,
  }

  [CCode (cprefix = "MCBPMF_API_KEYBOARD_LAYOUT_", type_id = "mcbpmf_api_keyboard_layout_get_type()")]
  public enum KeyboardLayout {
    STANDARD,
    ETEN,
    HSU,
    ET26,
    HANYUPINYIN,
    IBM,
  }

  [CCode (cprefix = "MCBPMF_API_KEY_", type_id = "mcbpmf_api_key_modifiers_get_type()")]
  [Flags]
  public enum KeyModifiers {
    SHIFT_MASK = 1 << 0,
    CTRL_MASK = 1 << 1,
  }

  [CCode (cprefix = "MSTATE_TYPE_", type_id = "mcbpmf_api_input_state_type_get_type()")]
  public enum InputStateType {
    EMPTY,
    EIP,
    COMMITTING,
    INPUTTING,
    CANDIDATES,
    MARKING,
  }

  [CCode (cprefix = "MCBPMF_API_CTRL_ENTER_", type_id = "mcbpmf_api_ctrl_enter_behavior_get_type()")]
  public enum CtrlEnterBehavior {
    NOOP,
    OUTPUT_BPMF_READINGS,
    OUTPUT_HTML_RUBY_TEXT,
  }
}
