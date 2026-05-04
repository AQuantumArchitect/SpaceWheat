#pragma once

#include "axial_field.h"
#include <string>
#include <vector>

namespace spacewheat { namespace market {

// A compact projection of the native eigensolver output into market language.
// The eigensolver remains the musician; this is the ticker tape the C menu reads.
struct SpectralMode {
    double eigenvalue = 0.0;
    double weight = 0.0;
    AxialField field;
    std::string label;
};

struct SpectralMarketSignal {
    std::vector<SpectralMode> modes;
    AxialField drift_field = AxialField::neutral();
    double dominant_eigenvalue = 0.0;
    double spectral_gap = 0.0;
    double volatility = 0.0;
    double direction_confidence = 0.0;
    double manifold_velocity = 0.0;
    double liquidity_temperature = 0.5;
    std::vector<std::string> explanation;
};

SpectralMarketSignal make_spectral_signal(
    const std::vector<double>& eigenvalues,
    const std::vector<AxialField>& eigenfields,
    double liquidity_temperature = 0.5);

AxialField field_from_spectral_signal(const SpectralMarketSignal& signal);
std::string spectral_signal_summary(const SpectralMarketSignal& signal);

} } // namespace spacewheat::market
