// Gentoo-rice – Firefox user.js
// userChrome.css aktivieren
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Dunkles, kompaktes UI
user_pref("extensions.activeThemeID", "firefox-compact-dark@mozilla.org");
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("browser.theme.toolbar-theme", 0);
user_pref("browser.theme.content-theme", 0);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("browser.compactmode.show", true);
user_pref("browser.uidensity", 1);
user_pref("browser.tabs.inTitlebar", 1);
user_pref("ui.key.menuAccessKeyFocuses", false);

// Wayland / Hardwarebeschleunigung (Radeon 780M)
user_pref("widget.use-xdg-desktop-portal.file-picker", 1);
user_pref("gfx.webrender.all", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);

// Ruhiger Start
user_pref("general.smoothScroll", true);
user_pref("browser.aboutConfig.showWarning", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
