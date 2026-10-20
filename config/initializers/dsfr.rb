# `dsfr-assets` refuses to boot — `Dsfr::Assets::LicenseError`, from the
# `dsfr-assets.check_license` initializer of its railtie — until the
# application names the version of the DSFR's terms of use it has read:
# https://github.com/GouvernementFR/dsfr/blob/v1.15.3/doc/legal/cgu.md
#
# Written out rather than taken from `Dsfr::Assets::CGU_VERSION`, which would
# accept whatever a future version says without anyone having read it.
Dsfr::Assets.accepted_license_version = '1.0.1'
