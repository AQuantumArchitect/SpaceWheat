#pragma once

#include "axial_field.h"
#include "eigen_market_signal.h"
#include <cstdint>
#include <map>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

namespace spacewheat { namespace market {

using Emoji = std::string;
using FactionName = std::string;
using ContractId = std::uint64_t;

struct ResourceBalance {
    Emoji emoji;
    double supply = 0.0;      // visible liquidity in player/current biome economy
    double demand = 0.0;      // faction/system pull
    double velocity = 0.0;    // recent flow magnitude
    double volatility = 0.0;  // recent instability in supply or production
};

struct IconEdge {
    std::string name;
    Emoji pole0;
    Emoji pole1;
    FactionName faction;
    AxialField field;
    double visibility = 1.0;
    double coupling = 0.5;
};

struct FactionField {
    FactionName name;
    std::vector<Emoji> signature;
    AxialField field;
    double attention = 0.0;   // how strongly this faction is watching/offering
    double standing = 0.0;    // persistent player relation, -1..1 suggested
    double liquidity_bias = 0.0;
    double hamiltonian_drive = 0.0; // native H contribution / current eigen involvement
};

enum class ContractKind {
    ResourceDelivery = 0,
    VocabularyDiscovery = 1,
    CircuitFulfillment = 2,
    StateObservable = 3
};

enum class ContractStatus {
    Quoted = 0,
    Accepted = 1,
    Ready = 2,
    Settled = 3,
    Expired = 4,
    Defaulted = 5
};

struct IconGate {
    Emoji pole0;
    Emoji pole1;
    double theta = 0.0;
    double phase = 0.0;
    double required_expectation = 0.0;
};

struct ContractIntent {
    ContractKind kind = ContractKind::ResourceDelivery;
    FactionName faction;
    Emoji resource;           // for delivery/resource option contracts
    double quantity = 0.0;
    Emoji reward_pole0;       // vocab reward or target icon
    Emoji reward_pole1;
    double expiry_seconds = 300.0;
    double urgency = 0.0;
    double min_alignment = 0.0;
    AxialField intent_field;
    std::vector<IconGate> circuit;
};

struct MarketContract {
    ContractId id = 0;
    ContractKind kind = ContractKind::ResourceDelivery;
    ContractStatus status = ContractStatus::Quoted;
    FactionName faction;
    Emoji resource;
    double quantity = 0.0;
    Emoji reward_pole0;
    Emoji reward_pole1;
    double expiry_seconds = 300.0;
    double created_at_seconds = 0.0;
    double accepted_at_seconds = -1.0;
    double premium = 0.0;       // lock-in / upfront consideration in emoji terms
    double strike = 0.0;        // demanded delivery quantity or target threshold
    double payout_value = 0.0;  // resource-equivalent value, before vocab conversion
    double collateral = 0.0;    // debt/wound exposure on failure
    double market_score = 0.0;  // sorting score for the C panel
    double alignment = 0.0;
    double scarcity = 0.0;
    double risk = 0.0;
    double vocab_premium = 0.0;
    double directional_edge = 0.0;      // alignment with eigensolver drift/tape
    double market_biome_liquidity = 0.0;
    double hamiltonian_drive = 0.0;     // faction influence on H as seen by market
    AxialField field;
    std::vector<IconGate> circuit;
    std::vector<std::string> explanation;
};

struct MarketBiome {
    std::string name = "📈 Market Biome";
    AxialField field = AxialField::neutral();
    double liquidity = 0.5;
    double risk_appetite = 0.5;
    double quote_temperature = 0.5;
};

struct MarketState {
    std::unordered_map<Emoji, ResourceBalance> resources;
    std::unordered_map<FactionName, FactionField> factions;
    std::unordered_map<std::string, IconEdge> icons_by_pair;
    AxialField biome_field;
    AxialField player_field;
    MarketBiome market_biome;
    SpectralMarketSignal spectral_signal;
    bool has_spectral_signal = false;
    std::unordered_map<std::string, double> icon_expectations;
    double now_seconds = 0.0;
};

struct SettlementResult {
    bool settled = false;
    bool defaulted = false;
    bool expired = false;
    double delivered = 0.0;
    double payout_value = 0.0;
    double reputation_delta = 0.0;
    double debt_delta = 0.0;
    std::vector<std::string> learned_pairs;
    std::vector<std::string> explanation;
};

} } // namespace spacewheat::market
