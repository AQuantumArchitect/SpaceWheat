#include "eigen_market_signal.h"
#include <algorithm>
#include <cmath>
#include <sstream>

namespace spacewheat { namespace market {

SpectralMarketSignal make_spectral_signal(
    const std::vector<double>& eigenvalues,
    const std::vector<AxialField>& eigenfields,
    double liquidity_temperature) {

    SpectralMarketSignal signal;
    signal.liquidity_temperature = clamp01(liquidity_temperature);
    const std::size_t n = std::min(eigenvalues.size(), eigenfields.size());
    if (n == 0) {
        signal.explanation.push_back("🎼 no eigenspectrum supplied; market drift neutral");
        return signal;
    }

    std::vector<std::size_t> order(n);
    for (std::size_t i = 0; i < n; ++i) order[i] = i;
    std::sort(order.begin(), order.end(), [&](std::size_t a, std::size_t b) {
        return std::abs(eigenvalues[a]) > std::abs(eigenvalues[b]);
    });

    const double temp = 0.10 + 1.90 * signal.liquidity_temperature;
    double weight_sum = 0.0;
    std::vector<AxialField> fields;
    std::vector<double> weights;
    const std::size_t take = std::min<std::size_t>(4, n);
    for (std::size_t rank = 0; rank < take; ++rank) {
        const std::size_t idx = order[rank];
        const double ev = eigenvalues[idx];
        const double w = std::exp(std::abs(ev) / temp);
        SpectralMode mode;
        mode.eigenvalue = ev;
        mode.weight = w;
        mode.field = eigenfields[idx];
        mode.label = "mode_" + std::to_string(rank);
        signal.modes.push_back(mode);
        fields.push_back(mode.field);
        weights.push_back(w);
        weight_sum += w;
    }

    signal.drift_field = blend_fields(fields, weights);
    signal.dominant_eigenvalue = eigenvalues[order[0]];
    if (n > 1) {
        signal.spectral_gap = std::abs(eigenvalues[order[0]]) - std::abs(eigenvalues[order[1]]);
    } else {
        signal.spectral_gap = std::abs(eigenvalues[order[0]]);
    }
    signal.direction_confidence = clamp01(signal.spectral_gap / (std::abs(signal.dominant_eigenvalue) + 1.0));

    double mean = 0.0;
    for (double ev : eigenvalues) mean += ev;
    mean /= static_cast<double>(n);
    double var = 0.0;
    for (double ev : eigenvalues) var += (ev - mean) * (ev - mean);
    var /= static_cast<double>(n);
    signal.volatility = clamp01(std::sqrt(var) / (std::abs(mean) + 1.0));
    signal.manifold_velocity = clamp01(std::abs(signal.dominant_eigenvalue) / (1.0 + std::abs(signal.dominant_eigenvalue)));

    std::ostringstream ss;
    ss << "🎼 dominant=" << signal.dominant_eigenvalue
       << " gap=" << signal.spectral_gap
       << " confidence=" << signal.direction_confidence
       << " volatility=" << signal.volatility;
    signal.explanation.push_back(ss.str());
    (void)weight_sum;
    return signal;
}

AxialField field_from_spectral_signal(const SpectralMarketSignal& signal) {
    return signal.drift_field;
}

std::string spectral_signal_summary(const SpectralMarketSignal& signal) {
    std::ostringstream ss;
    ss << "🎼 eigen-market signal: dominant=" << signal.dominant_eigenvalue
       << " gap=" << signal.spectral_gap
       << " confidence=" << signal.direction_confidence
       << " volatility=" << signal.volatility;
    return ss.str();
}

} } // namespace spacewheat::market
