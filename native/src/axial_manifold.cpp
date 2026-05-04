#include "axial_manifold.h"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace spacewheat {

AxialField::AxialField() {
    for (int i = 0; i < AXIS_COUNT; ++i) {
        mu[i] = 0.5;
        sigma[i] = 0.35;
        phase[i] = 0.0;
    }
}

AxialManifold::AxialManifold() {
    axes_.resize(AXIS_COUNT);
    axes_[0] = {"random_deterministic", "Random", "Deterministic", "🎲", "⚙️", 1.0};
    axes_[1] = {"material_mystical", "Material", "Mystical", "🧱", "✨", 1.0};
    axes_[2] = {"common_elite", "Common", "Elite", "🍞", "👑", 1.0};
    axes_[3] = {"local_cosmic", "Local", "Cosmic", "🏡", "🌌", 1.0};
    axes_[4] = {"instant_eternal", "Instant", "Eternal", "⚡", "♾️", 1.0};
    axes_[5] = {"physical_mental", "Physical", "Mental", "🪨", "🧠", 1.0};
    axes_[6] = {"crystalline_fluid", "Crystalline", "Fluid", "💎", "💧", 1.0};
    axes_[7] = {"direct_subtle", "Direct", "Subtle", "🎯", "🕵️", 1.0};
    axes_[8] = {"consumptive_providing", "Consumptive", "Providing", "🦷", "🌾", 1.0};
    axes_[9] = {"monochrome_prismatic", "Monochrome", "Prismatic", "⬜", "🌈", 1.0};
    axes_[10] = {"emergent_imposed", "Emergent", "Imposed", "🌱", "📐", 1.0};
    axes_[11] = {"scattered_focused", "Scattered", "Focused", "🌫️", "🔍", 1.0};
}

void AxialManifold::set_axis(int i, const AxisDefinition &axis) {
    if (i < 0 || i >= AXIS_COUNT) {
        throw std::out_of_range("axis index out of range");
    }
    axes_[static_cast<std::size_t>(i)] = axis;
}

AxialField AxialManifold::neutral_field(double sigma) const {
    AxialField f;
    for (int i = 0; i < AXIS_COUNT; ++i) {
        f.mu[i] = 0.5;
        f.sigma[i] = sigma;
        f.phase[i] = 0.0;
    }
    return f;
}

AxialField AxialManifold::field_from_bits(const std::vector<double> &bits, double sigma) const {
    AxialField f = neutral_field(sigma);
    for (int i = 0; i < AXIS_COUNT && i < static_cast<int>(bits.size()); ++i) {
        f.mu[i] = clamp01(bits[static_cast<std::size_t>(i)]);
    }
    return f;
}

AxialField AxialManifold::field_from_sparse_biases(const std::vector<std::pair<int, double>> &biases, double sigma) const {
    AxialField f = neutral_field(sigma);
    for (const auto &bias : biases) {
        if (bias.first < 0 || bias.first >= AXIS_COUNT) {
            continue;
        }
        f.mu[static_cast<std::size_t>(bias.first)] = clamp01(bias.second);
    }
    return f;
}

double AxialManifold::kernel(const AxialField &a, const AxialField &b, bool phase_sensitive) const {
    double exponent = 0.0;
    double phase_factor = 0.0;
    double phase_weight = 0.0;
    for (int i = 0; i < AXIS_COUNT; ++i) {
        const double sigma = std::max(1e-6, 0.5 * (a.sigma[i] + b.sigma[i]));
        const double d = a.mu[i] - b.mu[i];
        exponent += axes_[static_cast<std::size_t>(i)].weight * d * d / (2.0 * sigma * sigma);
        if (phase_sensitive) {
            const double w = axes_[static_cast<std::size_t>(i)].weight;
            phase_factor += w * std::cos(a.phase[i] - b.phase[i]);
            phase_weight += w;
        }
    }
    const double spatial = std::exp(-exponent);
    if (!phase_sensitive || phase_weight <= 0.0) {
        return spatial * std::sqrt(std::max(0.0, a.mass * b.mass));
    }
    const double phase = 0.5 + 0.5 * (phase_factor / phase_weight);
    return spatial * phase * std::sqrt(std::max(0.0, a.mass * b.mass));
}

double AxialManifold::distance2(const AxialField &a, const AxialField &b) const {
    double d2 = 0.0;
    for (int i = 0; i < AXIS_COUNT; ++i) {
        const double d = a.mu[i] - b.mu[i];
        d2 += axes_[static_cast<std::size_t>(i)].weight * d * d;
    }
    return d2;
}

AxialField AxialManifold::blend(const std::vector<AxialField> &fields, const std::vector<double> &weights) const {
    if (fields.empty()) {
        return neutral_field();
    }
    if (fields.size() != weights.size()) {
        throw std::invalid_argument("blend fields/weights mismatch");
    }

    AxialField out;
    double total = 0.0;
    for (double w : weights) {
        total += std::max(0.0, w);
    }
    if (total <= 1e-12) {
        return neutral_field();
    }

    for (int i = 0; i < AXIS_COUNT; ++i) {
        double mu = 0.0;
        double sigma = 0.0;
        double phase_re = 0.0;
        double phase_im = 0.0;
        for (std::size_t k = 0; k < fields.size(); ++k) {
            const double w = std::max(0.0, weights[k]) / total;
            mu += w * fields[k].mu[i];
            sigma += w * fields[k].sigma[i];
            phase_re += w * std::cos(fields[k].phase[i]);
            phase_im += w * std::sin(fields[k].phase[i]);
        }
        out.mu[i] = clamp01(mu);
        out.sigma[i] = std::max(1e-4, sigma);
        out.phase[i] = std::atan2(phase_im, phase_re);
    }

    out.mass = 0.0;
    for (std::size_t k = 0; k < fields.size(); ++k) {
        out.mass += std::max(0.0, weights[k]) * fields[k].mass;
    }
    out.mass /= total;
    return out;
}

AxialField AxialManifold::impulse_toward(const AxialField &base, const AxialField &target, double strength) const {
    const double s = std::max(0.0, std::min(1.0, strength));
    AxialField out = base;
    for (int i = 0; i < AXIS_COUNT; ++i) {
        out.mu[i] = clamp01((1.0 - s) * base.mu[i] + s * target.mu[i]);
        out.sigma[i] = std::max(1e-4, (1.0 - s) * base.sigma[i] + s * target.sigma[i]);
        const double re = (1.0 - s) * std::cos(base.phase[i]) + s * std::cos(target.phase[i]);
        const double im = (1.0 - s) * std::sin(base.phase[i]) + s * std::sin(target.phase[i]);
        out.phase[i] = std::atan2(im, re);
    }
    out.mass = (1.0 - s) * base.mass + s * target.mass;
    return out;
}

double AxialManifold::clamp01(double value) {
    if (value < 0.0) {
        return 0.0;
    }
    if (value > 1.0) {
        return 1.0;
    }
    return value;
}

} // namespace spacewheat
