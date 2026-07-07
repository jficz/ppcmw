# Proton Pass CLI dmenu wrapper

## Status

early prototype, anything can change in the future

## Features

Show `dmenu`-like menu with item titles and types the password
associated with the selected one, akin to [`passmenu`](https://git.zx2c4.com/password-store/tree/contrib/dmenu/README.md).

Only considers items of type `login` and state `active`.

## Dependencies

All requirements are hardcoded:
  - Wayland and `wtype`
  - `jq`
  - `bash` v5+
  - `fuzzel`

## Configuration

Config values go to `$XDG_CONFIG_HOME/ppcmw.conf`, which defaults
to `~/.config/ppcwm.conf` which is also used as fallback
if XDG_CONFIG_HOME is not defined.

### Config params

`vault_name`: name of the vault items should be pulled from
`PAT`: personal access token

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

You can store the PAT in another password manager, like `pass`
for example and put this in your config:
```
PAT=$(pass my_pass-cli_token)
```

That's _slightly_ better.

## Future plans

- optimize performance
- possibly introduce some caching
- support for other `dmenu`-like implementations
- support for other `wtype`-like implementations
- support for non-wayland environments
- support for more secret types and fields
- support for search over more metadata, not just the title
- security review
