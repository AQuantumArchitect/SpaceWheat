#pragma once

#include "axial_manifold.h"

#include <string>
#include <unordered_map>
#include <vector>

namespace spacewheat {

struct EmojiNode {
    std::string emoji;
    double self_energy = 0.0;
    double decay = 0.0;
};

struct IconEdge {
    std::string id;
    std::string name;
    std::string pole0;
    std::string pole1;
    std::string faction;
    bool discovered = false;
    double coupling = 0.1;
    double phase = 0.0;
    double visibility = 1.0;
    AxialField field;
};

struct FactionField {
    std::string name;
    std::vector<std::string> sig;
    std::vector<double> bits;
    AxialField field;
    double attention = 1.0;
};

struct MythosEvent {
    std::string type;
    std::string pole0;
    std::string pole1;
    std::string faction;
    std::string biome;
    double strength = 1.0;
    std::unordered_map<std::string, double> channels;
};

struct FactionProjection {
    std::string name;
    double mass = 0.0;
    double overlap = 0.0;
};

} // namespace spacewheat
