# Proton Pass CLI dmenu wrapper

## Status

alpha, anything can change in the future

## Features

Show `dmenu`-like menu with item titles and types the selected field
associated with the selected item, somewhat akin to
[`passmenu`](https://git.zx2c4.com/password-store/tree/contrib/dmenu/README.md).

Allows picking one of `password`, `username` or `email` fields.
If either `username` or `email` doesn't exist and is picked, falls back
to the other one. If neither exists, returns nothing.

Only considers items of type `login` and state `active`.

Utilizes aggressive caching to improve performance and responsiveness
as `pass-cli` is very much _not_ optimized for this kind of use case.

Without cache, each call would take up to 3s to display the menu.

See Security#Cache for details.


## Dependencies

Hardcoded requirements:
  - `jq`
  - `bash` v5+

Recommended tools:
  - Wayland and
    - `fuzzel`
    - `wtype`

If you want to use other menu or type commands, see Config params.
Tested only with `fuzzel` and `wtype`, ymmv, compatibility reports
appreciated.


## Configuration

Config values go to `$XDG_CONFIG_HOME/ppcmw.conf`, which defaults
to `~/.config/ppcwm.conf` which is also used as fallback
if XDG_CONFIG_HOME is not defined.

### Config params

`vault_name`: name of the vault items should be pulled from

`PAT`: personal access token, optional

`menu_command`: command to display the menu, defaults to
`fuzzel --dmenu --index --hide-before-typing` (no quotes).

`type_command`: command to type the selected field, defaults to `wtype` (no quotes).

### How to obtain PAT and enable access to your vault

```
pass-cli login
pass-cli pat create --name <token_name> --expiration 1y
# copy the printed PAT value to the config file

pass-cli pat access grant --vault-name <vault_name> --role viewer --personal-access-token-name <token_name>
```


## Security notes

No security checks and audits have been done (yet). Storing
your PAT in the conf file as plaintext is bad.

You don't _need_ to store PAT in your config but if you don't,
you must make sure a valid `pass-cli` session exists before
you invoke the script. If you provide the PAT, the scrip
will log in with that PAT for you if needed.

You can store the PAT in another password manager, like `pass`
for example and put this in your config:
```
PAT=$(pass my_pass-cli_token)
```

That's _slightly_ better.

### Cache

For performance reasons the script utilizes item list cache (item title
and item id pairs). This cache is plaintext and stored, together with
Vault share_id, in `$XDG_STATE_HOME/ppcmw/*`.


## Future plans

### TODO

- support for search over more metadata, not just the title;
  - security considerations: needs local cache to include the other fields
- advanced support for multiple fields, possibly via a follow-up submenu
- support for typing `username|email<TAB>password<RETURN>` to autosubmit
  web forms
- security review
