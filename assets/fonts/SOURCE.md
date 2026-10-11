# Bundled fonts

The font binaries in this directory were generated from the Google Fonts
repository at commit `bd8f81ddb5c74d5c8897b36ad88b440266245103`.

- Orbitron: upstream `googlefonts/orbitron-vf` commit
  `f16482824e0ce4d008dee59b9b632e9ce9663359`; static 500 and 700 instances.
- Noto Sans KR: upstream `notofonts/noto-cjk` commit
  `523d033d6cb47f4a80c58a35753646f5c3608a78`; static 400 and 500 instances.

Noto Sans KR contains the 2,350 KS X 1001 Hangul syllables plus the Latin,
number, punctuation, arrow, and UI symbols used by Gravity Orb. Orbitron is
limited to Latin, numbers, and the UI punctuation it provides. The files were
instanced and subset with FontTools 4.60.1.

Both families are distributed under the SIL Open Font License 1.1. The
license text is included in `OFL.txt`.
