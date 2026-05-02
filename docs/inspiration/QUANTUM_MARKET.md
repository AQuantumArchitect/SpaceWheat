# Quantum Market — Price as Superposition

The market price is not a formula. It is a qubit.

## The Idea

A market qubit sits on the Bloch sphere between two commodities — say,
🌾 flour (north) and 💰 coins (south). The theta angle IS the exchange rate.
Measuring the market collapses it to one commodity or the other.

- θ near 0° → coins abundant, flour scarce → flour is expensive
- θ near 90° → balanced market → fair exchange
- θ near 180° → flour abundant, coins scarce → flour is cheap

## Self-Correcting Dynamics

No explicit balance tuning needed. Physics creates boom/bust naturally:

- Player sells flour → injects population into flour pole → theta decreases
  (coins become abundant, flour becomes scarce → price rises)
- Mill produces flour → theta increases (flour abundant → price falls)
- Energy/radius = market liquidity: low energy = volatile price swings

The market is just another qubit evolving under its Hamiltonian.
Factions act as Lindblad operators (drain/pump pressure) keeping the market stable.

## Guilds as Pure Quantum Forces

Guilds don't track coins or set prices. They *perceive* market state and apply
theta-pressure to stabilize supply:

- **Granary Guilds:** Drain bread energy (demand sink) → creates incentive to produce
- **Millwright's Union:** Pump flour pole when market tips far toward scarcity
- **Debt Wardens:** Drain coin pole when market gets too liquid

No economic simulation. Just Lindblad operators applying counter-pressure when
the market qubit drifts to extremes. Stability emerges from physics.

## The Bread Economy Loop

Guilds → drain bread demand → player bakes bread (kitchen) → sells to market →
coins flow → player buys fire → fire fuels kitchen → loop.

The loop is closed. Resources cycle back. No sinks that drain the game to zero.

## Implementation Path

Market qubit = a BiomeBase with a 1-qubit quantum computer.
Its Hamiltonian encodes the exchange rate dynamics.
Lindblad channels = faction "market maker" forces.
Player actions (sell/buy) = explicit Lindblad pump calls on the market qubit.
Market measurement = sampling the qubit for the current price.
