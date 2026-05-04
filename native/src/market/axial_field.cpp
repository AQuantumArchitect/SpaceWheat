#include "axial_field.h"

namespace spacewheat { namespace market {

AxialField AxialField::neutral() {
    return AxialField();
}

AxialField AxialField::from_bits(const std::vector<double>& bits, double sharpness) {
    AxialField f;
    const double s = clamp(sharpness, 0.05, 1.0);
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        const double v = (i < bits.size()) ? bits[i] : 0.5;
        f.mu[i] = clamp01(v);
        f.sigma[i] = s;
        f.weight[i] = 1.0;
        f.phase[i] = 0.0;
    }
    return f;
}

AxialField AxialField::from_sparse_targets(const std::vector<int>& axes, const std::vector<double>& values) {
    AxialField f;
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        f.weight[i] = 0.0;
    }
    const std::size_t n = std::min(axes.size(), values.size());
    for (std::size_t k = 0; k < n; ++k) {
        const int ai = axes[k];
        if (ai < 0 || ai >= static_cast<int>(AXIS_COUNT)) continue;
        f.mu[static_cast<std::size_t>(ai)] = clamp01(values[k]);
        f.weight[static_cast<std::size_t>(ai)] = 1.0;
        f.sigma[static_cast<std::size_t>(ai)] = 0.18;
    }
    return f;
}

double AxialField::distance_sq(const AxialField& other) const {
    double acc = 0.0;
    double wsum = 0.0;
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        const double w = 0.5 * (weight[i] + other.weight[i]);
        if (w <= 0.0) continue;
        const double d = mu[i] - other.mu[i];
        acc += w * d * d;
        wsum += w;
    }
    return safe_div(acc, wsum, 0.0);
}

double AxialField::kernel(const AxialField& other, double global_sigma) const {
    return gaussian_kernel(distance_sq(other), global_sigma);
}

double AxialField::masked_kernel(const AxialField& other, double global_sigma) const {
    double acc = 0.0;
    double wsum = 0.0;
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        const double w = std::min(weight[i], other.weight[i]);
        if (w <= 0.0) continue;
        const double d = mu[i] - other.mu[i];
        acc += w * d * d;
        wsum += w;
    }
    if (wsum <= 0.0) return 1.0;
    return gaussian_kernel(acc / wsum, global_sigma);
}

double AxialField::phase_alignment(const AxialField& other) const {
    double acc = 0.0;
    double wsum = 0.0;
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        const double w = 0.5 * (weight[i] + other.weight[i]);
        if (w <= 0.0) continue;
        acc += w * std::cos(phase[i] - other.phase[i]);
        wsum += w;
    }
    return clamp(safe_div(acc, wsum, 1.0), -1.0, 1.0);
}

void AxialField::blend_in(const AxialField& other, double alpha) {
    const double a = clamp01(alpha);
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        const double ow = other.weight[i];
        if (ow <= 0.0) continue;
        const double local = a * ow;
        mu[i] = clamp01(mu[i] * (1.0 - local) + other.mu[i] * local);
        sigma[i] = clamp(sigma[i] * (1.0 - local) + other.sigma[i] * local, 0.03, 1.0);
        weight[i] = clamp(weight[i] + local * 0.1, 0.0, 2.0);
        phase[i] = phase[i] * (1.0 - local) + other.phase[i] * local;
    }
}

void AxialField::nudge_axis(std::size_t i, double target, double alpha) {
    if (i >= AXIS_COUNT) return;
    const double a = clamp01(alpha);
    mu[i] = clamp01(mu[i] * (1.0 - a) + clamp01(target) * a);
}

void AxialField::normalize() {
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        mu[i] = clamp01(mu[i]);
        sigma[i] = clamp(sigma[i], 0.03, 1.0);
        weight[i] = clamp(weight[i], 0.0, 2.0);
    }
}

std::string AxialField::debug_string() const {
    std::ostringstream oss;
    oss << "[";
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        if (i) oss << ",";
        oss << mu[i];
    }
    oss << "]";
    return oss.str();
}

AxialField blend_fields(const std::vector<AxialField>& fields, const std::vector<double>& weights_in) {
    AxialField out;
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        out.mu[i] = 0.0;
        out.sigma[i] = 0.0;
        out.weight[i] = 0.0;
        out.phase[i] = 0.0;
    }
    double total = 0.0;
    for (std::size_t k = 0; k < fields.size(); ++k) {
        const double wk = (k < weights_in.size()) ? std::max(0.0, weights_in[k]) : 1.0;
        if (wk <= 0.0) continue;
        total += wk;
        for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
            out.mu[i] += fields[k].mu[i] * wk;
            out.sigma[i] += fields[k].sigma[i] * wk;
            out.weight[i] += fields[k].weight[i] * wk;
            out.phase[i] += fields[k].phase[i] * wk;
        }
    }
    if (total <= 0.0) return AxialField::neutral();
    for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
        out.mu[i] /= total;
        out.sigma[i] /= total;
        out.weight[i] /= total;
        out.phase[i] /= total;
    }
    out.normalize();
    return out;
}

} } // namespace spacewheat::market
