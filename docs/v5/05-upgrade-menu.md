# v5 · Upgrade menu refresh

Goal: the tree should be readable at a glance, without hovering, and match the cream-plate HUD.

- **Medallions:** parchment fill with a bevel band, top highlight, 2 px branch-colored pixel frame (3 px when maxed), and a hard pixel drop shadow (`UpgradeTreeStroke.draw_squircle_border`).
- **Always-visible info** under every node (`upgrade_tree_node._build_info_tag`): a level bar in the branch color, and a price tag (gold when affordable, pale when not, `MAX` when done).
- **Story-locked nodes:** icon hidden, misty "?" and "in the mist" tag; tooltip lock hint points to the find ("Hidden in the mist (~118 yd)" / "Find the Buried Picker Cart").
- **Paths:** 3 px strokes with a dark casing so they read over bright clouds; charged paths glow.
- **Tooltips:** parchment with green frame, matching the thought box.
- **Header:** `Finds n/14` chip beside the currency.
- **Fit:** opening fits the *revealed* nodes (crew subtrees are hidden until found), capped at 2× zoom.
