# Proton Pass CLI dmenu wrapper

## Changelog

### v0.2.0
- add numbered versioning and `-v|--version` option
- support for more secret types and fields [✔]

Primitive support for `email`, `username` and `password` fields:
each secret is displayed three times with the option to pick
one of the above fields, password comes first but fuzzel may
cache the entries so the order is not guaranteed

### early versions
- optimize performance [✔]
- introduce caching [✔]

Cache for items list implemented, stored in plaintext. Rebuilds cache
in background with each invocation but doesn't wait for it to build
to display the menu _unless_ the cache is empty (i.e. first start).

A few minor performance tweaks introduced:
  - use cached `--share-id` for Vault identification - slightly faster than vault name
  - a couple of async calls, related to cache population
