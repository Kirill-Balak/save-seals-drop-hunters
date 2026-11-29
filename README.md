# Save Seals, Drop Hunters!

Source and build inputs for the PICO-8 cartridge by Kirill Balak. This snapshot reproduces v125, distributed as `save_seals_drop_hunters.p8.png`. The `rewards_v*/` directories contain the Lua modules, artwork, level data, and sound inputs used by this build.

## Build

Use Python 3.12. From the repository root, install the build dependencies and build the cartridge.

```sh
python -m pip install -r requirements.txt
python -B rewards_v125/tools/build.py
```

The output is `rewards_v125/save_seals_drop_hunters_v125.p8`. Run this command from the repository root to export the release PNG with its embedded cover.

```sh
python -B rewards_v20/tools/vendor/shrinko8-main/shrinko8.py rewards_v125/save_seals_drop_hunters_v125.p8 rewards_v125/save_seals_drop_hunters.p8.png
```

| Release file | SHA-256 |
| --- | --- |
| `save_seals_drop_hunters_v125.p8` | `c3cafb55fa12fedfbee3d09545c1a10371b9632b53ec0529cb8a3a0915c43883` |
| `save_seals_drop_hunters.p8.png` | `2fa61f71071f98ebc41895ea8ccba64e028702cf2189c48dc519e53f5d66302d` |

## License and notices

The game source for this release is distributed under the GNU Affero General Public License, version 3 or later. The license for the game source does not grant rights to third-party material.

The cartridge includes the Parens-8 v5 VM by Wellspring-Labs, distributed under the GNU Affero General Public License, version 3 or later. The complete license text is in [LICENSE](LICENSE), with third-party notices in [licenses](licenses/). The Shrinko8 integration exception applies to the Shrinko8 tool. Its terms for generated cartridges are described in the [Parens-8 integration notice](licenses/Parens-8-Shrinko8-exception.txt).

The build uses Shrinko8 by thisismypassport and Lupaz8. Shrinko8's Parens-8 compiler and VM-generation source used by the build is in [parens8.lua](rewards_v66/checks/toolchain/shrinko/scripts/parens8.lua). The current music build input is [Broken Arm](rewards_v124/assets/Broken_Arm_fixed_loop_from_1_24_375s.p8).
