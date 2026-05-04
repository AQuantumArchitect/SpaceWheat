#pragma once

#include <array>
#include <string>
#include <vector>

namespace spacewheat {

constexpr int AXIS_COUNT = 12;

struct AxisDefinition {
    std::string id;
    std::string low_label;
    std::string high_label;
    std::string low_emoji;
    std::string high_emoji;
    double weight = 1.0;
};

struct AxialField {
    std::array<double, AXIS_COUNT> mu{};
    std::array<double, AXIS_COUNT> sigma{};
    std::array<double, AXIS_COUNT> phase{};
    double mass = 1.0;

    AxialField();
};

class AxialManifold {
public:
    AxialManifold();

    const std::vector<AxisDefinition> &axes() const { return axes_; }
    void set_axis(int i, const AxisDefinition &axis);

    AxialField neutral_field(double sigma = 0.35) const;
    AxialField field_from_bits(const std::vector<double> &bits, double sigma = 0.20) const;
    AxialField field_from_sparse_biases(const std::vector<std::pair<int, double>> &biases, double sigma = 0.28) const;

    double kernel(const AxialField &a, const AxialField &b, bool phase_sensitive = true) const;
    double distance2(const AxialField &a, const AxialField &b) const;
    AxialField blend(const std::vector<AxialField> &fields, const std::vector<double> &weights) const;
    AxialField impulse_toward(const AxialField &base, const AxialField &target, double strength) const;

private:
    std::vector<AxisDefinition> axes_;

    static double clamp01(double value);
};

} // namespace spacewheat
