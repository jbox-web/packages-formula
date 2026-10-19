# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Context

This is one of the 32 `jbox-web` hard forks of the saltstack-formulas
collection; the parent directory's `CLAUDE.md` covers the shared toolchain,
CI and conventions. `origin` (`git@github.com:jbox-web/packages-formula.git`)
is the only remote.

The formula installs and removes packages listed in pillar: system packages,
remote `.deb`/`.rpm`, pip, gems, npm, snaps, downloaded archives, `go get`,
Chocolatey. It does not configure software or manage services (snapd aside).

## Commands

```bash
bundle install
bin/kitchen list                                  # 3 instances: debian-<platform>
bin/kitchen test debian-debian-13-3008-2          # one instance, end to end
bin/kitchen converge debian-debian-11-3006-27
bin/kitchen verify  debian-debian-11-3006-27
pre-commit run --all-files                        # rubocop/yamllint run on the whole tree
```

There is a single suite, `debian`, so instance names are
`debian-<platform>` (`debian-debian-13-3008-2`, `debian-debian-13-3006-27`,
`debian-debian-11-3006-27`). `kitchen.vagrant.yml` and `kitchen.windows.yml`
are upstream leftovers, not run by the CI.

## How this formula differs from the template layout

- **No `package/` / `config/` / `service/` split.** `packages/init.sls` is a
  meta-state including one flat state per package manager: `pkgs`,
  `remote_pkgs`, `pips`, `gems`, `npms`, `archives`, `snaps`, `golang`
  (`clean`, `goget`), `chocolatey`. Each can be included on its own.
- **Shorter merge chain.** `map.jinja` layers `defaults.yaml` <-
  `osfamilymap.yaml` <- `osmap.yaml` <- `osfingermap.yaml` <- `config.get('packages')`.
  There is no `osarchmap.yaml` and no `:lookup` level. `osmap.yaml` and
  `osfingermap.yaml` only carry RedHat-family values.
- **No TOFS.** No `libtofs.jinja`; the only template, `files/pip.conf`, is
  referenced as `salt://{{ tplroot }}/files/pip.conf`.
- **Mixed `map.jinja` imports.** `pips`, `gems`, `golang/*` and `_mapdata`
  derive `tplroot`; `pkgs`, `npms`, `archives`, `remote_pkgs`, `snaps` and
  `chocolatey` use the relative `"./map.jinja"`. Keep each file's existing
  form.
- **Every state is a no-op without pillar.** Each one is wrapped in
  `{% if wanted or unwanted %}` (or the equivalent), so including the
  meta-state with an empty pillar declares almost nothing. `chocolatey`
  is additionally gated on `grains['os'] == 'Windows'`.

## Cross-state coupling around `pkg_req_pkgs`

`pkgs.sls` declares the `pkg_req_pkgs` (prerequisites), `held_pkgs`,
`wanted_pkgs` and `unwanted_pkgs` IDs. `archives.sls` and `snaps.sls`
`include: .pkgs` and **`extend`** `pkg_req_pkgs` (and, for snaps,
`unwanted_pkgs`). Because `extend` replaces the list rather than appending,
both files rebuild it as `packages.pkgs.required.pkgs + <their own>`
(see the comment referencing #17 in `snaps.sls`). Renaming an ID in
`pkgs.sls` or emptying the `pkgs` pillar therefore affects those two states.

Each other manager has its own prerequisite state (`pip_req_pkgs`,
`gem_req_pkgs`, `npm_req_pkgs`, `chocolatey_req_pkgs`) fed by
`<manager>.required.pkgs`, and `<manager>.required.states` becomes both an
`include:` and an `sls` requisite. All network-bound states take
`retry: {{ packages.retry_options|json }}` (3 attempts, 60 s by default; the
test pillar sets 1).

## Salt 3008

Salt 3008 removed the `gem` module/state from core: `gems.sls` declares
nothing when `saltversioninfo[0] >= 3008`, and `gems_spec.rb` skips its
controls there. The `npm` state is gone too; `npms.sls` is not gated, and
the test pillar no longer sets `npms` (the Kitchen suite dropped the node
formula, which still pins a NodeSource version).

## Tests

- Pillar: `test/salt/pillar/debian.sls` (the other `test/salt/pillar/*.sls`
  files are upstream leftovers not wired to any suite). It still exercises
  upstream examples such as `zoom` from `zoom.us` in `remote_pkgs` and
  terminator/phantomjs/kubectl archives.
- Controls live in `test/integration/default/controls/`. Two upstream specs
  are **not run**: `golang_spec.rb` sits outside `controls/`, and
  `pips_spec.rb.old` has a non-`.rb` extension.
- `_mapdata` references: only `debian-11.yaml` and `debian-13.yaml` are
  maintained; the other files under `files/_mapdata/` are upstream ones for
  platforms no longer tested. A change to `defaults.yaml`, an `os*map.yaml`
  or `debian.sls` must be carried into both maintained dumps.
- `pkgs_spec.rb` forces `held_packages = {}` (`# FIXME`), so held packages
  are not asserted even though the pillar holds `alien` and `iotop`.
