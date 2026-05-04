#include "contract_market_core.h"
#include <algorithm>
#include <sstream>

namespace spacewheat { namespace market {

ContractMarketCore::ContractMarketCore() = default;

void ContractMarketCore::set_tuning(const MarketTuning& tuning) {
    tuning_ = tuning;
}

const MarketTuning& ContractMarketCore::tuning() const {
    return tuning_;
}

ContractId ContractMarketCore::next_id() {
    return next_id_++;
}

double ContractMarketCore::faction_attention(const FactionField* faction) const {
    if (!faction) return 0.35;
    return clamp01(0.35 + faction->attention * 0.45 + faction->liquidity_bias * 0.20);
}

double ContractMarketCore::standing_modifier(const FactionField* faction) const {
    if (!faction) return 0.0;
    return clamp(faction->standing, -1.0, 1.0);
}

double ContractMarketCore::scarcity_for(const ResourceBalance& balance) const {
    const double need = std::max(0.0, balance.demand);
    const double have = std::max(0.0, balance.supply);
    const double pressure = safe_div(need - have, std::max(1.0, need + have), 0.0);
    const double velocity_pressure = clamp(balance.velocity / std::max(1.0, have + need), 0.0, 1.0);
    const double scarcity = 0.5 + 0.5 * pressure + 0.15 * velocity_pressure + 0.20 * clamp01(balance.volatility);
    return clamp01(scarcity);
}

AxialField ContractMarketCore::resource_field(const Emoji& emoji, const ResourceBalance& balance) const {
    (void)emoji;
    AxialField f = AxialField::neutral();
    const double scarcity = scarcity_for(balance);
    // Axis convention inherited from the faction hypercube:
    // 0 Random/Deterministic, 3 Local/Cosmic, 4 Instant/Eternal,
    // 7 Direct/Subtle, 8 Consumptive/Providing, 10 Emergent/Imposed, 11 Scattered/Focused.
    f.nudge_axis(0, 0.35 + 0.35 * clamp01(balance.volatility), 0.8);
    f.nudge_axis(3, 0.25, 0.4);                         // resources are usually local unless routing says otherwise
    f.nudge_axis(4, 0.15 + 0.70 * scarcity, 0.7);        // scarcity creates urgency
    f.nudge_axis(7, 0.20, 0.5);                         // direct delivery language
    f.nudge_axis(8, 1.0 - scarcity, 0.9);               // scarce resources feel consumptive
    f.nudge_axis(10, 0.35 + 0.35 * scarcity, 0.5);       // high scarcity invites imposed contracts
    f.nudge_axis(11, 0.30 + 0.45 * scarcity, 0.6);       // scarce things focus attention
    return f;
}

AxialField ContractMarketCore::contract_field(const ContractIntent& intent, const MarketState& state) const {
    std::vector<AxialField> fields;
    std::vector<double> weights;

    fields.push_back(intent.intent_field);
    weights.push_back(0.35);

    fields.push_back(state.biome_field);
    weights.push_back(0.20);

    fields.push_back(state.player_field);
    weights.push_back(0.10);

    fields.push_back(state.market_biome.field);
    weights.push_back(0.12);

    if (state.has_spectral_signal) {
        fields.push_back(field_from_spectral_signal(state.spectral_signal));
        weights.push_back(0.18);
    }

    auto fit = state.factions.find(intent.faction);
    if (fit != state.factions.end()) {
        fields.push_back(fit->second.field);
        weights.push_back(0.25);
    }

    auto rit = state.resources.find(intent.resource);
    if (rit != state.resources.end()) {
        fields.push_back(resource_field(intent.resource, rit->second));
        weights.push_back(0.20);
    }

    if (!intent.reward_pole0.empty() && !intent.reward_pole1.empty()) {
        const std::string key = unordered_pair_key(intent.reward_pole0, intent.reward_pole1);
        auto iit = state.icons_by_pair.find(key);
        if (iit != state.icons_by_pair.end()) {
            fields.push_back(iit->second.field);
            weights.push_back(0.20);
        }
    }

    AxialField out = blend_fields(fields, weights);
    if (intent.kind == ContractKind::VocabularyDiscovery) {
        out.nudge_axis(1, 1.0, 0.25);  // mystical
        out.nudge_axis(5, 1.0, 0.20);  // mental
        out.nudge_axis(7, 1.0, 0.20);  // subtle
        out.nudge_axis(9, 1.0, 0.20);  // prismatic
    }
    if (intent.kind == ContractKind::CircuitFulfillment) {
        out.nudge_axis(0, 1.0, 0.25);  // deterministic
        out.nudge_axis(11, 1.0, 0.25); // focused
        out.nudge_axis(10, 1.0, 0.10); // imposed
    }
    return out;
}

double ContractMarketCore::option_risk(const ContractIntent& intent, const MarketState& state, double scarcity, double alignment) const {
    double time_risk = 0.0;
    if (intent.expiry_seconds > 0.0) {
        time_risk = clamp01(90.0 / std::max(30.0, intent.expiry_seconds));
    }
    double quantity_risk = 0.0;
    auto rit = state.resources.find(intent.resource);
    if (rit != state.resources.end()) {
        quantity_risk = clamp01(intent.quantity / std::max(1.0, rit->second.supply + 1.0));
    }
    double circuit_risk = 0.0;
    if (!intent.circuit.empty()) {
        circuit_risk = 1.0 - circuit_expectation(intent.circuit, state);
    }
    const double mismatch = 1.0 - alignment;
    double spectral_risk = 0.0;
    if (state.has_spectral_signal) {
        spectral_risk = state.spectral_signal.volatility * (1.0 - spectral_alignment(intent.intent_field, state));
    }
    return clamp01(0.35 * scarcity + 0.25 * quantity_risk + 0.20 * time_risk + 0.15 * mismatch + 0.20 * circuit_risk + 0.18 * spectral_risk);
}

double ContractMarketCore::spectral_alignment(const AxialField& field, const MarketState& state) const {
    if (!state.has_spectral_signal) return 0.5;
    return clamp01(field.kernel(field_from_spectral_signal(state.spectral_signal)) * (0.5 + 0.5 * state.spectral_signal.direction_confidence));
}

double ContractMarketCore::circuit_expectation(const std::vector<IconGate>& circuit, const MarketState& state) const {
    if (circuit.empty()) return 1.0;
    double acc = 0.0;
    for (const IconGate& gate : circuit) {
        const std::string key = unordered_pair_key(gate.pole0, gate.pole1);
        const auto it = state.icon_expectations.find(key);
        const double expectation = (it != state.icon_expectations.end()) ? clamp01(it->second) : 0.0;
        const double match = 1.0 - std::abs(expectation - clamp01(gate.required_expectation));
        acc += clamp01(match);
    }
    return clamp01(acc / static_cast<double>(circuit.size()));
}

MarketContract ContractMarketCore::quote_contract(const ContractIntent& intent, const MarketState& state) {
    MarketContract c;
    c.id = next_id();
    c.kind = intent.kind;
    c.status = ContractStatus::Quoted;
    c.faction = intent.faction;
    c.resource = intent.resource;
    c.quantity = std::max(0.0, intent.quantity);
    c.reward_pole0 = intent.reward_pole0;
    c.reward_pole1 = intent.reward_pole1;
    c.expiry_seconds = std::max(0.0, intent.expiry_seconds);
    c.created_at_seconds = state.now_seconds;
    c.strike = c.quantity;
    c.circuit = intent.circuit;
    c.field = contract_field(intent, state);

    const FactionField* faction = nullptr;
    auto fit = state.factions.find(intent.faction);
    if (fit != state.factions.end()) faction = &fit->second;

    ResourceBalance neutral;
    neutral.emoji = intent.resource;
    auto rit = state.resources.find(intent.resource);
    const ResourceBalance& rb = (rit != state.resources.end()) ? rit->second : neutral;

    c.scarcity = scarcity_for(rb);
    const double faction_match = faction ? c.field.kernel(faction->field) : 0.5;
    const double biome_match = c.field.kernel(state.biome_field);
    const double player_match = c.field.kernel(state.player_field);
    c.alignment = clamp01(0.50 * faction_match + 0.30 * biome_match + 0.20 * player_match);
    c.directional_edge = spectral_alignment(c.field, state);
    c.market_biome_liquidity = clamp01(state.market_biome.liquidity);
    c.hamiltonian_drive = faction ? clamp01(faction->hamiltonian_drive) : 0.0;
    c.risk = option_risk(intent, state, c.scarcity, c.alignment);
    if (state.has_spectral_signal) {
        c.risk = clamp01(c.risk + tuning_.spectral_volatility_weight * state.spectral_signal.volatility * (1.0 - c.directional_edge));
    }

    c.vocab_premium = 0.0;
    if (!intent.reward_pole0.empty() && !intent.reward_pole1.empty()) {
        c.vocab_premium = tuning_.vocab_pair_base_value;
    }
    if (intent.kind == ContractKind::VocabularyDiscovery) {
        c.vocab_premium = std::max(c.vocab_premium, tuning_.vocab_pair_base_value * 1.3);
    }

    const double urgency = clamp01(intent.urgency + c.scarcity * 0.5);
    const double attention = faction_attention(faction);
    const double standing = standing_modifier(faction);

    const double base_value = c.quantity * tuning_.resource_unit_value;
    const double spectral_edge_bonus = state.has_spectral_signal ? tuning_.eigen_direction_weight * c.directional_edge : 0.0;
    const double market_biome_bonus = tuning_.market_biome_weight * c.market_biome_liquidity * state.market_biome.risk_appetite;
    const double h_drive_bonus = tuning_.faction_hamiltonian_weight * c.hamiltonian_drive;

    const double option_value =
        base_value * (1.0 + tuning_.scarcity_weight * c.scarcity + tuning_.urgency_weight * urgency + spectral_edge_bonus + market_biome_bonus + h_drive_bonus)
        + c.vocab_premium;

    const double risk_charge = option_value * tuning_.risk_weight * c.risk;
    const double standing_discount = option_value * tuning_.standing_discount * std::max(0.0, standing);
    const double hostile_markup = option_value * tuning_.standing_discount * std::max(0.0, -standing);

    c.payout_value = std::max(0.0, option_value + risk_charge + hostile_markup - standing_discount);
    c.premium = std::max(0.0, c.payout_value * tuning_.quote_spread * (0.5 + c.risk));
    c.collateral = std::max(0.0, c.payout_value * tuning_.default_collateral_rate * (0.25 + c.risk));

    c.market_score = clamp01(
        tuning_.scarcity_weight * c.scarcity
        + tuning_.alignment_weight * c.alignment
        + tuning_.urgency_weight * urgency
        + 0.15 * attention
        + 0.15 * (c.vocab_premium > 0.0 ? 1.0 : 0.0)
        + tuning_.eigen_direction_weight * c.directional_edge
        + tuning_.market_biome_weight * c.market_biome_liquidity
        + tuning_.faction_hamiltonian_weight * c.hamiltonian_drive
        - tuning_.risk_weight * c.risk);

    c.explanation = build_explanation(intent, c.scarcity, c.alignment, c.risk, c.vocab_premium, c.market_score);
    if (state.has_spectral_signal) {
        c.explanation.push_back(spectral_signal_summary(state.spectral_signal));
    }
    {
        std::ostringstream ss;
        ss << "📈 market_biome_liquidity=" << c.market_biome_liquidity << " directional_edge=" << c.directional_edge;
        c.explanation.push_back(ss.str());
    }
    if (c.hamiltonian_drive > 0.0) {
        std::ostringstream ss;
        ss << "🎛 faction_hamiltonian_drive=" << c.hamiltonian_drive;
        c.explanation.push_back(ss.str());
    }
    return c;
}

std::vector<MarketContract> ContractMarketCore::generate_resource_bids(
    const MarketState& state,
    const std::vector<Emoji>& candidate_resources,
    int max_per_faction) {

    std::vector<MarketContract> offers;
    for (const auto& kv : state.factions) {
        const FactionField& faction = kv.second;
        std::vector<MarketContract> local;
        for (const Emoji& emoji : candidate_resources) {
            auto rit = state.resources.find(emoji);
            if (rit == state.resources.end()) continue;
            const double scarcity = scarcity_for(rit->second);
            if (scarcity <= 0.10 && rit->second.demand <= rit->second.supply) continue;

            ContractIntent intent;
            intent.kind = ContractKind::ResourceDelivery;
            intent.faction = faction.name;
            intent.resource = emoji;
            intent.quantity = std::max(1.0, std::ceil((rit->second.demand - rit->second.supply) * (0.25 + 0.5 * scarcity)));
            intent.expiry_seconds = 240.0 + 360.0 * (1.0 - scarcity);
            intent.urgency = scarcity;
            intent.intent_field = resource_field(emoji, rit->second);
            intent.intent_field.blend_in(faction.field, 0.35);

            MarketContract c = quote_contract(intent, state);
            if (c.market_score >= tuning_.min_contract_score) {
                local.push_back(c);
            }
        }
        local = sort_offers(local);
        const int limit = std::max(0, max_per_faction);
        for (int i = 0; i < static_cast<int>(local.size()) && i < limit; ++i) {
            offers.push_back(local[static_cast<std::size_t>(i)]);
        }
    }
    return sort_offers(offers);
}

std::vector<MarketContract> ContractMarketCore::sort_offers(std::vector<MarketContract> offers) const {
    std::sort(offers.begin(), offers.end(), [](const MarketContract& a, const MarketContract& b) {
        if (a.market_score != b.market_score) return a.market_score > b.market_score;
        return a.payout_value > b.payout_value;
    });
    return offers;
}

SettlementResult ContractMarketCore::evaluate_settlement(
    const MarketContract& contract,
    const MarketState& state,
    const std::unordered_map<Emoji, double>& player_inventory) const {

    SettlementResult r;
    const double now = state.now_seconds;
    if (contract.expiry_seconds > 0.0 && now > contract.created_at_seconds + contract.expiry_seconds) {
        r.expired = true;
        r.defaulted = true;
        r.debt_delta = contract.collateral;
        r.explanation.push_back("⏳ expired before settlement");
        return r;
    }

    if (contract.kind == ContractKind::ResourceDelivery) {
        const auto it = player_inventory.find(contract.resource);
        const double have = (it != player_inventory.end()) ? it->second : 0.0;
        r.delivered = std::min(have, contract.quantity);
        if (r.delivered + 1e-9 >= contract.quantity) {
            r.settled = true;
            r.payout_value = contract.payout_value;
            r.reputation_delta = 0.01 + 0.04 * contract.alignment + 0.02 * contract.scarcity;
            if (!contract.reward_pole0.empty() && !contract.reward_pole1.empty()) {
                r.learned_pairs.push_back(pair_key(contract.reward_pole0, contract.reward_pole1));
            }
            r.explanation.push_back("⚖ delivery obligation settled");
        } else {
            r.defaulted = true;
            r.debt_delta = contract.collateral * (1.0 - safe_div(r.delivered, contract.quantity, 0.0));
            r.explanation.push_back("🩸 delivery shortfall opened debt");
        }
        return r;
    }

    if (contract.kind == ContractKind::CircuitFulfillment) {
        const double score = circuit_expectation(contract.circuit, state);
        if (score >= 0.88) {
            r.settled = true;
            r.payout_value = contract.payout_value * score;
            r.reputation_delta = 0.03 + 0.04 * score;
            r.explanation.push_back("⚛ icon circuit proof accepted");
        } else {
            r.defaulted = true;
            r.debt_delta = contract.collateral * (1.0 - score);
            r.explanation.push_back("🧪 circuit proof below threshold");
        }
        return r;
    }

    if (contract.kind == ContractKind::VocabularyDiscovery) {
        const std::string k = unordered_pair_key(contract.reward_pole0, contract.reward_pole1);
        const auto it = state.icon_expectations.find(k);
        const double seen = (it != state.icon_expectations.end()) ? clamp01(it->second) : 0.0;
        if (seen >= 0.50) {
            r.settled = true;
            r.payout_value = contract.payout_value;
            r.reputation_delta = 0.05;
            r.learned_pairs.push_back(pair_key(contract.reward_pole0, contract.reward_pole1));
            r.explanation.push_back("🗝 vocabulary option exercised");
        } else {
            r.defaulted = true;
            r.debt_delta = contract.collateral * 0.5;
            r.explanation.push_back("🧿 faction watched an unfulfilled discovery promise");
        }
        return r;
    }

    r.defaulted = true;
    r.debt_delta = contract.collateral * 0.25;
    r.explanation.push_back("❓ unsupported contract kind");
    return r;
}

std::vector<std::string> ContractMarketCore::build_explanation(
    const ContractIntent& intent,
    double scarcity,
    double alignment,
    double risk,
    double vocab_premium,
    double score) const {

    std::vector<std::string> out;
    std::ostringstream s1;
    s1 << "📦 scarcity=" << scarcity << " for " << intent.resource;
    out.push_back(s1.str());
    std::ostringstream s2;
    s2 << "🧭 manifold_alignment=" << alignment;
    out.push_back(s2.str());
    std::ostringstream s3;
    s3 << "⏳ risk=" << risk;
    out.push_back(s3.str());
    if (vocab_premium > 0.0) {
        std::ostringstream s4;
        s4 << "🗝 vocab_premium=" << vocab_premium << " for " << intent.reward_pole0 << "/" << intent.reward_pole1;
        out.push_back(s4.str());
    }
    std::ostringstream s5;
    s5 << "📜 market_score=" << score;
    out.push_back(s5.str());
    return out;
}

} } // namespace spacewheat::market
