#pragma once

#include "contract_market_core.h"

#ifdef SPACEWHEAT_WITH_GODOT
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#endif

namespace spacewheat { namespace market {

class QuantumContractEngine
#ifdef SPACEWHEAT_WITH_GODOT
    : public godot::RefCounted
#endif
{
#ifdef SPACEWHEAT_WITH_GODOT
    GDCLASS(QuantumContractEngine, godot::RefCounted)
#endif

public:
    QuantumContractEngine();
    ~QuantumContractEngine();

    void clear();
    void set_time(double now_seconds);
    void set_biome_bits(const std::vector<double>& bits);
    void set_player_bits(const std::vector<double>& bits);
    void set_market_biome_bits(const std::vector<double>& bits, double liquidity, double risk_appetite, double quote_temperature);
    void set_spectral_signal(double dominant_eigenvalue, double spectral_gap, double volatility, double confidence, const std::vector<double>& direction_bits);
    void set_faction_hamiltonian_drive(const std::string& name, double drive);
    void add_faction(const std::string& name, const std::vector<double>& bits, double attention, double standing);
    void set_resource(const std::string& emoji, double supply, double demand, double velocity, double volatility);
    void add_icon(const std::string& name, const std::string& pole0, const std::string& pole1, const std::string& faction, const std::vector<double>& bits);
    void set_icon_expectation(const std::string& pole0, const std::string& pole1, double expectation);

    std::vector<MarketContract> generate_resource_bids(const std::vector<std::string>& resources, int max_per_faction);
    MarketContract quote_vocabulary_option(const std::string& faction, const std::string& pole0, const std::string& pole1, double expiry_seconds);
    MarketContract quote_circuit_contract(const std::string& faction, const std::vector<IconGate>& gates, double expiry_seconds);
    SettlementResult settle(const MarketContract& contract, const std::unordered_map<std::string, double>& inventory) const;

    const MarketState& state() const { return state_; }
    ContractMarketCore& market() { return market_; }

#ifdef SPACEWHEAT_WITH_GODOT
protected:
    static void _bind_methods();

public:
    void gd_clear();
    void gd_set_time(double now_seconds);
    void gd_set_biome_bits(godot::Array bits);
    void gd_set_player_bits(godot::Array bits);
    void gd_set_market_biome_bits(godot::Array bits, double liquidity, double risk_appetite, double quote_temperature);
    void gd_set_spectral_signal(double dominant_eigenvalue, double spectral_gap, double volatility, double confidence, godot::Array direction_bits);
    void gd_set_faction_hamiltonian_drive(godot::String name, double drive);
    void gd_add_faction(godot::String name, godot::Array bits, double attention, double standing);
    void gd_set_resource(godot::String emoji, double supply, double demand, double velocity, double volatility);
    void gd_add_icon(godot::String name, godot::String pole0, godot::String pole1, godot::String faction, godot::Array bits);
    void gd_set_icon_expectation(godot::String pole0, godot::String pole1, double expectation);
    godot::Array gd_generate_resource_bids(godot::Array resources, int max_per_faction);
    godot::Dictionary gd_quote_vocabulary_option(godot::String faction, godot::String pole0, godot::String pole1, double expiry_seconds);
#endif

private:
    ContractMarketCore market_;
    MarketState state_;

    static std::vector<double> array_to_bits(const std::vector<double>& bits);
#ifdef SPACEWHEAT_WITH_GODOT
    static std::vector<double> gd_array_to_bits(godot::Array bits);
    static godot::Dictionary contract_to_dict(const MarketContract& c);
#endif
};

} } // namespace spacewheat::market
