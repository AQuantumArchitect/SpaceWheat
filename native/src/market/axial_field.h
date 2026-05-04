#pragma once

#include "graph_math.h"
#include <array>
#include <sstream>

namespace spacewheat { namespace market {

struct AxialField {
    std::array<double, AXIS_COUNT> mu{};
    std::array<double, AXIS_COUNT> sigma{};
    std::array<double, AXIS_COUNT> weight{};
    std::array<double, AXIS_COUNT> phase{};

    AxialField() {
        for (std::size_t i = 0; i < AXIS_COUNT; ++i) {
            mu[i] = 0.5;
            sigma[i] = 0.25;
            weight[i] = 1.0;
            phase[i] = 0.0;
        }
    }

    static AxialField neutral();
    static AxialField from_bits(const std::vector<double>& bits, double sharpness = 0.22);
    static AxialField from_sparse_targets(const std::vector<int>& axis, const std::vector<double>& values);

    double distance_sq(const AxialField& other) const;
    double kernel(const AxialField& other, double global_sigma = 0.42) const;
    double masked_kernel(const AxialField& other, double global_sigma = 0.42) const;
    double phase_alignment(const AxialField& other) const;

    void blend_in(const AxialField& other, double alpha);
    void nudge_axis(std::size_t i, double target, double alpha);
    void normalize();
    std::string debug_string() const;
};

AxialField blend_fields(const std::vector<AxialField>& fields, const std::vector<double>& weights);

} } // namespace spacewheat::market
