# How to Play SpaceWheat

SpaceWheat is a keyboard-first quantum farming game. The live control grammar
is documented in [UI/Core/KEYBOARD_GRAMMAR.md](../UI/Core/KEYBOARD_GRAMMAR.md)
and the current frame stack is described in [docs/ARCHETYPE_FRAMES.md](ARCHETYPE_FRAMES.md).

## Quick Start

1. Use `T Y U I O P` to pick a biome slot.
2. Use `Q E R F` as the primary action quartet.
3. Use `V` for vocabulary, `C` for contracts, `B` for biome inspection, `N` for the density-matrix inspector, and `M` for map/meta.
4. Use `4 5 6 7 8 9 0` to select the active archetype frame.

## The Core Loop

- `Q` reaches out or backs out, depending on the surface.
- `E` inspects, expands, or measures.
- `R` commits, adds, or pops.
- `F` advances time, pages forward, or flattens back out.

The exact meaning of each chip is surface-local, but the quartet is always the
same. `QERF` is the current action grammar.

## What You Actually Do

- In the farm and biome views, you measure emoji qubits and harvest the
  resulting credits.
- In the contract and market views, you accept, complete, and settle live
  offers.
- In the vocab and icon views, you discover and inspect the active emoji pairs
  that carry the current physics.
- In the story view, you read the relationship and arc state that emerged from
  those actions.

## First 60 Seconds

If you are new to the game:

1. Open a biome and watch the live density bubbles.
2. Use the measure/pop flow to harvest a little value.
3. Open `V` to see which emoji pairs are currently in scope.
4. Open `C` to see the live contracts that the market is offering.
5. Open `B` and `N` to inspect the current biome state and density matrix.

That is enough to start seeing the game as a set of connected physics surfaces:
biomes, icons, quests, market, and story.

## Current Runtime Model

- `IconRegistry` is the live icon atlas autoload.
- `IconRegistry` is the runtime icon type and shared lookup model.
- `StoryEngine` owns story composition and phase updates.
- `QuestManager` owns quest lifecycle.
- `MarketLattice` owns offer generation and settlement.

If a control or surface seems unclear, check the grammar and frame docs first.
Those are the current sources of truth.
