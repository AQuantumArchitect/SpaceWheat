#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <numeric>
#include <string>
#include <vector>

namespace spacewheat { namespace market {

constexpr std::size_t AXIS_COUNT = 12;

inline double clamp01(double x) {
    if (x < 0.0) return 0.0;
    if (x > 1.0) return 1.0;
    return x;
}

inline double clamp(double x, double lo, double hi) {
    if (x < lo) return lo;
    if (x > hi) return hi;
    return x;
}

inline double safe_div(double num, double den, double fallback = 0.0) {
    if (std::abs(den) < 1e-12) return fallback;
    return num / den;
}

inline double logistic(double x) {
    if (x >= 0.0) {
        const double z = std::exp(-x);
        return 1.0 / (1.0 + z);
    }
    const double z = std::exp(x);
    return z / (1.0 + z);
}

inline double gaussian_kernel(double distance_sq, double sigma) {
    const double s = std::max(1e-9, sigma);
    return std::exp(-distance_sq / (2.0 * s * s));
}

inline std::string pair_key(const std::string& a, const std::string& b) {
    return a + "\x1f" + b;
}

inline std::string unordered_pair_key(std::string a, std::string b) {
    if (b < a) std::swap(a, b);
    return pair_key(a, b);
}

} } // namespace spacewheat::market
