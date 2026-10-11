# Bundled fonts

The font binaries in this directory are pinned to the upstream revisions listed
below. Orbitron is included unmodified; the Noto Sans KR files are generated
subsets.

- Orbitron: unmodified Google Fonts file
  `ofl/orbitron/Orbitron[wght].ttf` from commit
  `bd8f81ddb5c74d5c8897b36ad88b440266245103`; SHA-256
  `f42db2dd16e642258e35782916eceb1dcdbea06fb958d77ad71dc5963587e8fd`.
  Godot `FontVariation` resources select the `wght` axis at 500 and 700 using
  `TextServer.name_to_tag("wght")`'s serialized numeric tag `2003265652`.
- Noto Sans KR: upstream `notofonts/noto-cjk` commit
  `523d033d6cb47f4a80c58a35753646f5c3608a78`; static 400 and 500 instances.

Noto Sans KR contains the 2,350 KS X 1001 Hangul syllables plus the Latin,
number, punctuation, arrow, and UI symbols used by Gravity Orb. Their internal
style names are `Regular` and `Medium`. The Noto files were instanced, subset,
and name-corrected with FontTools 4.60.1. Orbitron remains byte-for-byte
identical to the Google Fonts source.

Both families are distributed under the SIL Open Font License 1.1. The
license text is included in `OFL.txt`.
