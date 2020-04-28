# filter mod

This mod adds a chat filter API that can be used to register custom
chat filters. As of now a bad words filter has been implemented. There
is no default word list, and adding words to the filter list is done
through the `/word_filter` chat command, which requires `server` priv.

The `/word_filter` chat command can `add`, `remove` or `list` words. The
words are stored in `mod_storage`, which means that this mod requires
0.4.16 or above to function.

If a player triggers a filter, they are muted for 1 minute. After that,
their `shout` privilege is restored. If they leave, their `shout`
privilege is still restored, but only after the time expires, not before.

## API

### Custom filter registration

* `filter.register_filter(name, func(playername, message))`
  * Takes a name and a two-parameter function
  * `name` is the name of the filter, which is currently unused, except
    for indexing.
  * `playername` and `message` hold the name of the player and the
    message they sent, respectively.
  * `func` should return a relevant warning when triggered. e.g.
    "Watch your language!", and `nil` when message has passed the check.

### Callbacks

* `filter.register_on_violation(func(name, message, violations))`
  * `violations` is the value of the player's violation counter - which is
    incremented on a violation, and halved every 10 minutes.
  * Return `true` if you've handled the violation. No more callbacks will be
    executation, and the default behaviour (warning/mute/kick) on violation
    will be skipped.

### Methods

* `filter.import_file(path)`
  * Input bad words from a file (`path`) where each line is a new word.
* `filter.check_message(name, message)`
  * Checks message for violation. Returns `true` if bad, `false` if ok.
    If it returns true, the message is not sent `filter.on_violation` is
    called.
* `filter.on_violation(name, message)`
  * Increments violation count, runs callbacks, and punishes the players.
* `filter.mute(name, duration)`
* `filter.show_warning_formspec(name)`
