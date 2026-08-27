# Entra ID Groups

3 security group(s) for project `proj1` in workspace `ws1`.

| Project role | Entra group |
|---|---|
| `admin` | `acme.ws1.proj1.admin` |
| `user` | `acme.ws1.proj1.user` |
| `reader` | `acme.ws1.proj1.reader` |

2 group membership(s) assigned from 4 project member(s), matched on the `email` attribute.

## ⚠️ Unresolved members

The following 2 project member(s) have no object in this directory and were **not** added to any group:

- `carol@example.com`
- `dave@example.com`

Their meshStack project roles are unaffected, but they will not inherit any access granted through these groups. Add them to the directory, or check that the lookup attribute matches how they are represented there.
