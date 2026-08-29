/* See LICENSE file for copyright and license details. */
/*
 * dwl config — parity port of the X11 dwm configuration (origin/artix,
 * dwm/config.h) onto dwl 0.8 + the `bar`, `snail` and `dwindle` patches.
 *
 * Written against the PATCHED config.def.h.  Applying the patches changes the
 * configuration structures, so this file cannot be used with stock dwl:
 *   - `colors[][3]` (uint32_t RGBA) replaces bordercolor/focuscolor/urgentcolor
 *   - `tags[]` (strings) replaces `#define TAGCOUNT`
 *   - `Button` gains a click-region field (ClkTagBar, ClkStatus, ...)
 *   - `fonts[]`, `showbar` and `topbar` appear
 * Patch order is fixed in suckless/packages.scm: bar -> snail -> dwindle.
 */

/* Browser — Brave (primary) is not packaged in Guix, so it comes from
 * Flatpak; LibreWolf (secondary) is a Guix package. */
#ifndef BROWSER_CMD
#define BROWSER_CMD "flatpak run com.brave.Browser"
#endif

#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }

/* appearance — Tokyo Night, matching dwm/config.h and dunst/foot */
static const int sloppyfocus               = 1;  /* focus follows mouse */
static const int bypass_surface_visibility = 0;
static const unsigned int borderpx         = 1;  /* border pixel of windows */
static const int showbar                   = 1;  /* 0 means no bar */
static const int topbar                    = 1;  /* 0 means bottom bar */

/* fcft builds a fallback chain from this list, in order:
 *   Iosevka           — the machine's UI/terminal face (font-iosevka)
 *   Symbols Nerd Font — the status-line glyphs (font-nerd-symbols)
 *   Noto Sans CJK JP  — the 一二三 tag labels (font-google-noto-sans-cjk)
 * Guix has no "Iosevka Nerd Font" build, hence the explicit symbol fallback. */
static const char *fonts[] = {
	"Iosevka:size=14",
	"Symbols Nerd Font Mono:size=14",
	"Noto Sans CJK JP:size=14",
};

static const float rootcolor[]     = COLOR(0x1a1b26ff);
static const float fullscreen_bg[] = COLOR(0x1a1b26ff);

/* dwm's colors[][3]: SchemeNorm = {fg, bg, border}, SchemeSel = {selfg, sel, sel} */
static uint32_t colors[][3] = {
	/*               fg          bg          border      */
	[SchemeNorm] = { 0xa9b1d6ff, 0x1a1b26ff, 0x414868ff },
	[SchemeSel]  = { 0x1a1b26ff, 0x7aa2f7ff, 0x7aa2f7ff },
	[SchemeUrg]  = { 0,          0,          0xff9e64ff },
};

/* tagging — same kanji tags as dwm/config.h */
static char *tags[] = { "一", "二", "三", "四", "五", "六", "七", "八", "九" };

/* logging */
static int log_level = WLR_ERROR;

/* Wayland matches on app_id, not the X11 (class, instance) pair. */
static const Rule rules[] = {
	/* app_id       title  tags mask  isfloating  monitor */
	{ "gimp",       NULL,  0,         1,          -1 },
	{ "Gimp",       NULL,  0,         1,          -1 },
	{ "firefox",    NULL,  1 << 8,    0,          -1 },
	{ "librewolf",  NULL,  1 << 8,    0,          -1 },
};

/* layout(s) — order and keybindings mirror dwm/config.h exactly:
 * snail is the dwl equivalent of the fibonacci patch's spiral. */
static const Layout layouts[] = {
	/* symbol         arrange function */
	{ "| Spiral |",   snail   },   /* first entry is the default */
	{ "| Title |",    tile    },
	{ "| Float |",    NULL    },   /* no layout function means floating */
	{ "| Monocle |",  monocle },
	{ "| Dwindle |",  dwindle },
};

/* monitors — the physical layout of the reference laptop, declared here
 * instead of shelling out to wlr-randr:
 *   eDP-1 (internal, 60 Hz) on the left, DP-1 (external, 180 Hz) on the right.
 * dwl picks each output's preferred mode; the trailing NULL rule covers every
 * other output, including the VM's single virtual screen. */
static const MonitorRule monrules[] = {
	/* name     mfact  nmaster scale layout       rotate/reflect               x     y */
	{ "eDP-1",  0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,  0,    0 },
	{ "DP-1",   0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,  1920, 0 },
	{ NULL,     0.55f, 1,      1,    &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL,  -1,   -1 },
};

/* keyboard — Brazilian ABNT2.  `abnt2` is an xkb MODEL, not a layout variant
 * (see `! model` in xkb/rules/base.lst); passing it as a variant silently
 * falls back to plain `br`.  There is no setxkbmap under Wayland, so this is
 * the only place the compositor learns the layout. */
static const struct xkb_rule_names xkb_rules = {
	.rules   = NULL,
	.model   = "abnt2",
	.layout  = "br",
	.variant = NULL,
	.options = NULL,
};

static const int repeat_rate = 25;
static const int repeat_delay = 600;

/* Trackpad */
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 1;
static const int natural_scrolling = 0;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

/* Super (Windows/Logo) — dwl's analogue of dwm's Mod4Mask */
#define MODKEY WLR_MODIFIER_LOGO

/* dwl reports the SHIFTED keysym, so SKEY must be what the key actually
 * produces on ABNT2.  Verified with `xmodmap -pke` on the reference machine:
 * Shift+6 is dead_diaeresis, NOT asciicircum as on a US layout.  Every other
 * digit matches US.  (Letter case is irrelevant: keybinding() compares with
 * xkb_keysym_to_lower.) */
#define TAGKEYS(KEY,SKEY,TAG) \
	{ MODKEY,                    KEY,   view,       {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL,  KEY,   toggleview, {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_SHIFT, SKEY,  tag,        {.ui = 1 << TAG} }, \
	{ MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, SKEY, toggletag, {.ui = 1 << TAG} }

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static const char *termcmd[]      = { "foot", NULL };
static const char *menucmd[]      = { "wmenu-run", NULL };
static const char *clipcmd[]      = { "dmenu-clip", NULL };
static const char *cpucmd[]       = { "dmenu-cpupower", NULL };
static const char *sessioncmd[]   = { "dmenu-session", NULL };
static const char *brightupcmd[]  = { "brightness-notify", "up", NULL };
static const char *brightdowncmd[]= { "brightness-notify", "down", NULL };
static const char *volupcmd[]     = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "+5%", NULL };
static const char *voldowncmd[]   = { "pactl", "set-sink-volume", "@DEFAULT_SINK@", "-5%", NULL };
static const char *volmutecmd[]   = { "pactl", "set-sink-mute", "@DEFAULT_SINK@", "toggle", NULL };

static const Key keys[] = {
	/* modifier                  key                 function        argument */
	{ MODKEY,                    XKB_KEY_d,          spawn,          {.v = menucmd} },
	{ MODKEY,                    XKB_KEY_Return,     spawn,          {.v = termcmd} },
	{ MODKEY,                    XKB_KEY_b,          togglebar,      {0} },
	{ MODKEY,                    XKB_KEY_j,          focusstack,     {.i = +1} },
	{ MODKEY,                    XKB_KEY_k,          focusstack,     {.i = -1} },
	{ MODKEY,                    XKB_KEY_i,          incnmaster,     {.i = +1} },
	{ MODKEY,                    XKB_KEY_p,          spawn,          {.v = cpucmd} },
	{ MODKEY,                    XKB_KEY_h,          setmfact,       {.f = -0.05f} },
	{ MODKEY,                    XKB_KEY_l,          setmfact,       {.f = +0.05f} },
	{ MODKEY,                    XKB_KEY_z,          zoom,           {0} },
	{ MODKEY,                    XKB_KEY_Tab,        view,           {0} },
	{ MODKEY,                    XKB_KEY_q,          killclient,     {0} },
	{ MODKEY,                    XKB_KEY_e,          spawn,          SHCMD("thunar") },
	{ MODKEY,                    XKB_KEY_v,          spawn,          {.v = clipcmd} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_b,          spawn,          SHCMD(BROWSER_CMD) },

	/* layouts — same letters as dwm/config.h */
	{ MODKEY,                    XKB_KEY_t,          setlayout,      {.v = &layouts[0]} },
	{ MODKEY,                    XKB_KEY_f,          setlayout,      {.v = &layouts[1]} },
	{ MODKEY,                    XKB_KEY_m,          setlayout,      {.v = &layouts[2]} },
	{ MODKEY,                    XKB_KEY_r,          setlayout,      {.v = &layouts[3]} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_r,          setlayout,      {.v = &layouts[4]} },
	{ MODKEY,                    XKB_KEY_space,      setlayout,      {0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space,      togglefloating, {0} },

	{ MODKEY,                    XKB_KEY_0,          view,           {.ui = ~0} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_parenright, tag,            {.ui = ~0} },
	{ MODKEY,                    XKB_KEY_comma,      focusmon,       {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY,                    XKB_KEY_period,     focusmon,       {.i = WLR_DIRECTION_RIGHT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_less,       tagmon,         {.i = WLR_DIRECTION_LEFT} },
	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_greater,    tagmon,         {.i = WLR_DIRECTION_RIGHT} },

	/* media & session keys */
	{ 0, XKB_KEY_XF86MonBrightnessUp,   spawn, {.v = brightupcmd} },
	{ 0, XKB_KEY_XF86MonBrightnessDown, spawn, {.v = brightdowncmd} },
	{ 0, XKB_KEY_XF86AudioRaiseVolume,  spawn, {.v = volupcmd} },
	{ 0, XKB_KEY_XF86AudioLowerVolume,  spawn, {.v = voldowncmd} },
	{ 0, XKB_KEY_XF86AudioMute,         spawn, {.v = volmutecmd} },
	/* dwm used `flameshot gui`; the Wayland equivalent is grim + slurp. */
	{ 0, XKB_KEY_Print, spawn, SHCMD("grim -g \"$(slurp -b '#1a1b26cc' -c '#7aa2f7ff' -w 2)\" - | wl-copy && notify-send -a grim -t 2000 'Screenshot' 'Saved to clipboard'") },
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_Delete, spawn, {.v = sessioncmd} },

	TAGKEYS(          XKB_KEY_1, XKB_KEY_exclam,          0),
	TAGKEYS(          XKB_KEY_2, XKB_KEY_at,              1),
	TAGKEYS(          XKB_KEY_3, XKB_KEY_numbersign,      2),
	TAGKEYS(          XKB_KEY_4, XKB_KEY_dollar,          3),
	TAGKEYS(          XKB_KEY_5, XKB_KEY_percent,         4),
	TAGKEYS(          XKB_KEY_6, XKB_KEY_dead_diaeresis,  5),
	TAGKEYS(          XKB_KEY_7, XKB_KEY_ampersand,       6),
	TAGKEYS(          XKB_KEY_8, XKB_KEY_asterisk,        7),
	TAGKEYS(          XKB_KEY_9, XKB_KEY_parenleft,       8),

	{ MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_q, quit, {0} },

	/* Ctrl-Alt-Backspace and Ctrl-Alt-Fx used to be handled by the X server */
	{ WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_Terminate_Server, quit, {0} },
#define CHVT(n) { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_XF86Switch_VT_##n, chvt, {.ui = (n)} }
	CHVT(1), CHVT(2), CHVT(3), CHVT(4),  CHVT(5),  CHVT(6),
	CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};

/* Click regions come from the bar patch and mirror dwm's button bindings. */
static const Button buttons[] = {
	{ ClkLtSymbol, 0,      BTN_LEFT,   setlayout,      {.v = &layouts[0]} },
	{ ClkLtSymbol, 0,      BTN_RIGHT,  setlayout,      {.v = &layouts[3]} },
	{ ClkTitle,    0,      BTN_MIDDLE, zoom,           {0} },
	{ ClkStatus,   0,      BTN_MIDDLE, spawn,          {.v = termcmd} },
	{ ClkClient,   MODKEY, BTN_LEFT,   moveresize,     {.ui = CurMove} },
	{ ClkClient,   MODKEY, BTN_MIDDLE, togglefloating, {0} },
	{ ClkClient,   MODKEY, BTN_RIGHT,  moveresize,     {.ui = CurResize} },
	{ ClkTagBar,   0,      BTN_LEFT,   view,           {0} },
	{ ClkTagBar,   0,      BTN_RIGHT,  toggleview,     {0} },
	{ ClkTagBar,   MODKEY, BTN_LEFT,   tag,            {0} },
	{ ClkTagBar,   MODKEY, BTN_RIGHT,  toggletag,      {0} },
};
