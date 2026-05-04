#pragma once

#include "market_types.h"
#include <random>

namespace spacewheat { namespace market {

struct MarketTuning {
    double scarcity_weight = 0.45;
    double urgency_weight = 0.20;
    double alignment_weight = 0.25;
    double risk_weight = 0.20;
    double standing_discount = 0.12;
    double vocab_pair_base_value = 42.0;
    double resource_unit_value = 1.0;
    double min_contract_score = 0.05;
    double quote_spread = 0.08;
    double default_collateral_rate = 0.35;
    double eigen_direction_weight = 0.22;
    double spectral_volatility_weight = 0.18;
    double market_biome_weight = 0.16;
    double faction_hamiltonian_weight = 0.18;
};

class ContractMarketCore {
public:
    ContractMarketCore();

    void set_tuning(const MarketTuning& tuning);
    const MarketTuning& tuning() const;

    ContractId next_id();

    MarketContract quote_contract(const ContractIntent& intent, const MarketState& state);
    std::vector<MarketContract> generate_resource_bids(
        const MarketState& state,
        const std::vector<Emoji>& candidate_resources,
        int max_per_faction = 3);

    std::vector<MarketContract> sort_offers(std::vector<MarketContract> offers) const;

    SettlementResult evaluate_settlement(
        const MarketContract& contract,
        const MarketState& state,
        const std::unordered_map<Emoji, double>& player_inventory) const;

    AxialField resource_field(const Emoji& emoji, const ResourceBalance& balance) const;
    AxialField contract_field(const ContractIntent& intent, const MarketState& state) const;
    double scarcity_for(const ResourceBalance& balance) const;
    double option_risk(const ContractIntent& intent, const MarketState& state, double scarcity, double alignment) const;
    double circuit_expectation(const std::vector<IconGate>& circuit, const MarketState& state) const;
    double spectral_alignment(const AxialField& field, const MarketState& state) const;

private:
    MarketTuning tuning_;
    ContractId next_id_ = 1;

    double faction_attention(const FactionField* faction) const;
    double standing_modifier(const FactionField* faction) const;
    std::vector<std::string> build_explanation(
        const ContractIntent& intent,
        double scarcity,
        double alignment,
        double risk,
        double vocab_premium,
        double score) const;
};

} } // namespace spacewheat::market
