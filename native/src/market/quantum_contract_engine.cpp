#include "quantum_contract_engine.h"
#include <algorithm>
#include <cmath>

namespace spacewheat { namespace market {

QuantumContractEngine::QuantumContractEngine() = default;
QuantumContractEngine::~QuantumContractEngine() = default;

void QuantumContractEngine::clear() {
    state_ = MarketState();
    market_ = ContractMarketCore();
}

void QuantumContractEngine::set_time(double now_seconds) {
    state_.now_seconds = std::max(0.0, now_seconds);
}

std::vector<double> QuantumContractEngine::array_to_bits(const std::vector<double>& bits) {
    std::vector<double> out(AXIS_COUNT, 0.5);
    for (std::size_t i = 0; i < AXIS_COUNT && i < bits.size(); ++i) {
        out[i] = clamp01(bits[i]);
    }
    return out;
}

void QuantumContractEngine::set_biome_bits(const std::vector<double>& bits) {
    state_.biome_field = AxialField::from_bits(array_to_bits(bits), 0.30);
}

void QuantumContractEngine::set_player_bits(const std::vector<double>& bits) {
    state_.player_field = AxialField::from_bits(array_to_bits(bits), 0.35);
}

void QuantumContractEngine::set_market_biome_bits(const std::vector<double>& bits, double liquidity, double risk_appetite, double quote_temperature) {
    state_.market_biome.field = AxialField::from_bits(array_to_bits(bits), 0.28);
    state_.market_biome.liquidity = clamp01(liquidity);
    state_.market_biome.risk_appetite = clamp01(risk_appetite);
    state_.market_biome.quote_temperature = clamp01(quote_temperature);
}

void QuantumContractEngine::set_spectral_signal(double dominant_eigenvalue, double spectral_gap, double volatility, double confidence, const std::vector<double>& direction_bits) {
    state_.spectral_signal = SpectralMarketSignal();
    state_.spectral_signal.dominant_eigenvalue = dominant_eigenvalue;
    state_.spectral_signal.spectral_gap = std::max(0.0, spectral_gap);
    state_.spectral_signal.volatility = clamp01(volatility);
    state_.spectral_signal.direction_confidence = clamp01(confidence);
    state_.spectral_signal.manifold_velocity = clamp01(std::abs(dominant_eigenvalue) / (1.0 + std::abs(dominant_eigenvalue)));
    state_.spectral_signal.liquidity_temperature = state_.market_biome.quote_temperature;
    state_.spectral_signal.drift_field = AxialField::from_bits(array_to_bits(direction_bits), 0.30);
    state_.spectral_signal.explanation.push_back(spectral_signal_summary(state_.spectral_signal));
    state_.has_spectral_signal = true;
}

void QuantumContractEngine::set_faction_hamiltonian_drive(const std::string& name, double drive) {
    auto it = state_.factions.find(name);
    if (it != state_.factions.end()) {
        it->second.hamiltonian_drive = clamp01(drive);
        it->second.attention = clamp01(it->second.attention + 0.25 * clamp01(drive));
    }
}

void QuantumContractEngine::add_faction(const std::string& name, const std::vector<double>& bits, double attention, double standing) {
    FactionField f;
    f.name = name;
    f.field = AxialField::from_bits(array_to_bits(bits), 0.22);
    f.attention = clamp01(attention);
    f.standing = clamp(standing, -1.0, 1.0);
    f.liquidity_bias = 0.0;
    f.hamiltonian_drive = 0.0;
    state_.factions[name] = f;
}

void QuantumContractEngine::set_resource(const std::string& emoji, double supply, double demand, double velocity, double volatility) {
    ResourceBalance rb;
    rb.emoji = emoji;
    rb.supply = std::max(0.0, supply);
    rb.demand = std::max(0.0, demand);
    rb.velocity = std::max(0.0, velocity);
    rb.volatility = clamp01(volatility);
    state_.resources[emoji] = rb;
}

void QuantumContractEngine::add_icon(const std::string& name, const std::string& pole0, const std::string& pole1, const std::string& faction, const std::vector<double>& bits) {
    IconEdge icon;
    icon.name = name;
    icon.pole0 = pole0;
    icon.pole1 = pole1;
    icon.faction = faction;
    icon.field = AxialField::from_bits(array_to_bits(bits), 0.24);
    state_.icons_by_pair[unordered_pair_key(pole0, pole1)] = icon;
}

void QuantumContractEngine::set_icon_expectation(const std::string& pole0, const std::string& pole1, double expectation) {
    state_.icon_expectations[unordered_pair_key(pole0, pole1)] = clamp01(expectation);
}

std::vector<MarketContract> QuantumContractEngine::generate_resource_bids(const std::vector<std::string>& resources, int max_per_faction) {
    return market_.generate_resource_bids(state_, resources, max_per_faction);
}

MarketContract QuantumContractEngine::quote_vocabulary_option(const std::string& faction, const std::string& pole0, const std::string& pole1, double expiry_seconds) {
    ContractIntent intent;
    intent.kind = ContractKind::VocabularyDiscovery;
    intent.faction = faction;
    intent.resource = "🗝️";
    intent.quantity = 1.0;
    intent.reward_pole0 = pole0;
    intent.reward_pole1 = pole1;
    intent.expiry_seconds = expiry_seconds;
    intent.urgency = 0.4;
    intent.intent_field = AxialField::neutral();
    intent.intent_field.nudge_axis(1, 1.0, 0.6);
    intent.intent_field.nudge_axis(5, 1.0, 0.6);
    intent.intent_field.nudge_axis(7, 1.0, 0.6);
    return market_.quote_contract(intent, state_);
}

MarketContract QuantumContractEngine::quote_circuit_contract(const std::string& faction, const std::vector<IconGate>& gates, double expiry_seconds) {
    ContractIntent intent;
    intent.kind = ContractKind::CircuitFulfillment;
    intent.faction = faction;
    intent.resource = "⚛️";
    intent.quantity = std::max(1.0, static_cast<double>(gates.size()));
    intent.expiry_seconds = expiry_seconds;
    intent.urgency = 0.5;
    intent.circuit = gates;
    intent.intent_field = AxialField::neutral();
    intent.intent_field.nudge_axis(0, 1.0, 0.7);
    intent.intent_field.nudge_axis(11, 1.0, 0.7);
    intent.intent_field.nudge_axis(10, 1.0, 0.3);
    return market_.quote_contract(intent, state_);
}

SettlementResult QuantumContractEngine::settle(const MarketContract& contract, const std::unordered_map<std::string, double>& inventory) const {
    return market_.evaluate_settlement(contract, state_, inventory);
}

#ifdef SPACEWHEAT_WITH_GODOT
using namespace godot;

void QuantumContractEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("clear"), &QuantumContractEngine::gd_clear);
    ClassDB::bind_method(D_METHOD("set_time", "now_seconds"), &QuantumContractEngine::gd_set_time);
    ClassDB::bind_method(D_METHOD("set_biome_bits", "bits"), &QuantumContractEngine::gd_set_biome_bits);
    ClassDB::bind_method(D_METHOD("set_player_bits", "bits"), &QuantumContractEngine::gd_set_player_bits);
    ClassDB::bind_method(D_METHOD("set_market_biome_bits", "bits", "liquidity", "risk_appetite", "quote_temperature"), &QuantumContractEngine::gd_set_market_biome_bits);
    ClassDB::bind_method(D_METHOD("set_spectral_signal", "dominant_eigenvalue", "spectral_gap", "volatility", "confidence", "direction_bits"), &QuantumContractEngine::gd_set_spectral_signal);
    ClassDB::bind_method(D_METHOD("set_faction_hamiltonian_drive", "name", "drive"), &QuantumContractEngine::gd_set_faction_hamiltonian_drive);
    ClassDB::bind_method(D_METHOD("add_faction", "name", "bits", "attention", "standing"), &QuantumContractEngine::gd_add_faction);
    ClassDB::bind_method(D_METHOD("set_resource", "emoji", "supply", "demand", "velocity", "volatility"), &QuantumContractEngine::gd_set_resource);
    ClassDB::bind_method(D_METHOD("add_icon", "name", "pole0", "pole1", "faction", "bits"), &QuantumContractEngine::gd_add_icon);
    ClassDB::bind_method(D_METHOD("set_icon_expectation", "pole0", "pole1", "expectation"), &QuantumContractEngine::gd_set_icon_expectation);
    ClassDB::bind_method(D_METHOD("generate_resource_bids", "resources", "max_per_faction"), &QuantumContractEngine::gd_generate_resource_bids);
    // quote_vocabulary_option binding removed: vocab is hand-crafted missions,
    // not market options. Internal C++ VocabularyDiscovery branches in
    // contract_market_core.cpp are now unreachable from GDScript and may be
    // pruned in a dedicated cleanup pass.
}

std::vector<double> QuantumContractEngine::gd_array_to_bits(Array bits) {
    std::vector<double> out(AXIS_COUNT, 0.5);
    for (int i = 0; i < bits.size() && i < static_cast<int>(AXIS_COUNT); ++i) {
        out[static_cast<std::size_t>(i)] = clamp01(static_cast<double>(bits[i]));
    }
    return out;
}

Dictionary QuantumContractEngine::contract_to_dict(const MarketContract& c) {
    Dictionary d;
    d["id"] = static_cast<int64_t>(c.id);
    d["kind"] = static_cast<int>(c.kind);
    d["status"] = static_cast<int>(c.status);
    d["faction"] = String(c.faction.c_str());
    d["resource"] = String(c.resource.c_str());
    d["quantity"] = c.quantity;
    d["reward_pole_0"] = String(c.reward_pole0.c_str());
    d["reward_pole_1"] = String(c.reward_pole1.c_str());
    d["expiry_seconds"] = c.expiry_seconds;
    d["premium"] = c.premium;
    d["strike"] = c.strike;
    d["payout_value"] = c.payout_value;
    d["collateral"] = c.collateral;
    d["market_score"] = c.market_score;
    d["alignment"] = c.alignment;
    d["scarcity"] = c.scarcity;
    d["risk"] = c.risk;
    d["vocab_premium"] = c.vocab_premium;
    d["directional_edge"] = c.directional_edge;
    d["market_biome_liquidity"] = c.market_biome_liquidity;
    d["hamiltonian_drive"] = c.hamiltonian_drive;
    Array e;
    for (const std::string& s : c.explanation) e.append(String(s.c_str()));
    d["explanation"] = e;
    return d;
}

void QuantumContractEngine::gd_clear() { clear(); }
void QuantumContractEngine::gd_set_time(double now_seconds) { set_time(now_seconds); }
void QuantumContractEngine::gd_set_biome_bits(Array bits) { set_biome_bits(gd_array_to_bits(bits)); }
void QuantumContractEngine::gd_set_player_bits(Array bits) { set_player_bits(gd_array_to_bits(bits)); }
void QuantumContractEngine::gd_set_market_biome_bits(Array bits, double liquidity, double risk_appetite, double quote_temperature) { set_market_biome_bits(gd_array_to_bits(bits), liquidity, risk_appetite, quote_temperature); }
void QuantumContractEngine::gd_set_spectral_signal(double dominant_eigenvalue, double spectral_gap, double volatility, double confidence, Array direction_bits) { set_spectral_signal(dominant_eigenvalue, spectral_gap, volatility, confidence, gd_array_to_bits(direction_bits)); }
void QuantumContractEngine::gd_set_faction_hamiltonian_drive(String name, double drive) { set_faction_hamiltonian_drive(std::string(name.utf8().get_data()), drive); }
void QuantumContractEngine::gd_add_faction(String name, Array bits, double attention, double standing) { add_faction(std::string(name.utf8().get_data()), gd_array_to_bits(bits), attention, standing); }
void QuantumContractEngine::gd_set_resource(String emoji, double supply, double demand, double velocity, double volatility) { set_resource(std::string(emoji.utf8().get_data()), supply, demand, velocity, volatility); }
void QuantumContractEngine::gd_add_icon(String name, String pole0, String pole1, String faction, Array bits) { add_icon(std::string(name.utf8().get_data()), std::string(pole0.utf8().get_data()), std::string(pole1.utf8().get_data()), std::string(faction.utf8().get_data()), gd_array_to_bits(bits)); }
void QuantumContractEngine::gd_set_icon_expectation(String pole0, String pole1, double expectation) { set_icon_expectation(std::string(pole0.utf8().get_data()), std::string(pole1.utf8().get_data()), expectation); }

Array QuantumContractEngine::gd_generate_resource_bids(Array resources, int max_per_faction) {
    std::vector<std::string> rs;
    for (int i = 0; i < resources.size(); ++i) rs.push_back(std::string(String(resources[i]).utf8().get_data()));
    std::vector<MarketContract> offers = generate_resource_bids(rs, max_per_faction);
    Array out;
    for (const MarketContract& c : offers) out.append(contract_to_dict(c));
    return out;
}

Dictionary QuantumContractEngine::gd_quote_vocabulary_option(String faction, String pole0, String pole1, double expiry_seconds) {
    return contract_to_dict(quote_vocabulary_option(std::string(faction.utf8().get_data()), std::string(pole0.utf8().get_data()), std::string(pole1.utf8().get_data()), expiry_seconds));
}
#endif

} } // namespace spacewheat::market
