# Patched Arch LTS kernel for MacBookPro11,3

`linux-lts-mbp` is Arch's official `linux-lts` package plus this repo's gmux/nouveau power-cycle patches
(`patches/kernel/0002–0015`). It installs **next to** the stock kernels; ZFSBootMenu lists it under Ctrl+K.
LTS only: mainline `linux` changes series every ~9 weeks, too often to keep the patches ported.

## Update after a new Arch kernel release

```sh
./mkpkgbuild.sh --prepare
cd linux-lts-mbp && MAKEFLAGS="-j$(nproc)" makepkg -sfC   # 1.5–3 h; -C = fresh src/, never re-patch
```

`/etc/makepkg.conf` ships without `-j`, so without `MAKEFLAGS` the build is single-threaded (10+ h). An
interrupted build resumes with `makepkg -sef` (reuses `src/`; never add `-C` then). Progress/ETA from another
terminal: `../build-progress.sh` (repo root; counts built modules against the stock kernel's).

`mkpkgbuild.sh` clones Arch's linux-lts packaging (latest tag, or pass one: `./mkpkgbuild.sh 6.18.55-1`),
renames `pkgbase` to `linux-lts-mbp`, drops the docs package, adds the patches as `mbp-*` symlinks with
checksums, verifies signatures, and with `--prepare` extracts the tree and applies every patch without
building. It stops loudly if Arch's PKGBUILD layout changed or a patch no longer applies.

## 0005 needs a per-series port

`0005` (i915 eDP DPCD retry) touches a function whose context differs between kernel series, so the
generator takes it from `patches/kernel-<major.minor>/`:

| Series | File | Notes |
|---|---|---|
| 6.18 | `patches/kernel-6.18/0005-…-6.18.patch` | adds `int ret;` (absent on 6.18) |

New LTS series → the generator errors out. Port it: run `--prepare`, edit
`drivers/gpu/drm/i915/display/intel_dp.c` in `src/linux-*/` so the single `drm_dp_read_dpcd_caps()` call in
`intel_edp_init_dpcd()` becomes the 5×/50 ms retry loop, `diff -u` it into
`patches/kernel-<series>/0005-…-<series>.patch` (keep the original header), and rerun.

## Prerequisites on this machine

- Build deps not covered by base-devel: `rust-bindgen rust-src` (`makepkg -s` installs them). Without them
  `olddefconfig` silently disables the kernel's Rust parts.
- **ZFS must come from `zfs-dkms`** (it conflicts with `zfs-linux` / `zfs-linux-lts`): the prebuilt
  modules only match Arch's stock kernels. Check `dkms status` lists zfs for every kernel before rebooting.
- dracut + ZFSBootMenu hooks create `/boot/vmlinuz-<base>-mbp` and its initramfs on install.
