#include "liquid_neural_net_native.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>

using namespace godot;

void LiquidNeuralNetNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "input_size", "hidden_size", "output_size"), &LiquidNeuralNetNative::initialize);
    ClassDB::bind_method(D_METHOD("forward", "input_phases"), &LiquidNeuralNetNative::forward);
    ClassDB::bind_method(D_METHOD("reset_state"), &LiquidNeuralNetNative::reset_state);
    ClassDB::bind_method(D_METHOD("set_learning_rate", "lr"), &LiquidNeuralNetNative::set_learning_rate);
    ClassDB::bind_method(D_METHOD("set_leak", "new_leak"), &LiquidNeuralNetNative::set_leak);
    ClassDB::bind_method(D_METHOD("set_tau", "new_tau"), &LiquidNeuralNetNative::set_tau);
    ClassDB::bind_method(D_METHOD("get_hidden_state"), &LiquidNeuralNetNative::get_hidden_state);
    ClassDB::bind_method(D_METHOD("train_batch", "target_trajectory"), &LiquidNeuralNetNative::train_batch);
}

LiquidNeuralNetNative::LiquidNeuralNetNative() : lnn(nullptr) {
    // Initialize pointer is null until initialize() is called
}

LiquidNeuralNetNative::~LiquidNeuralNetNative() {
    if (lnn) {
        delete lnn;
        lnn = nullptr;
    }
}

void LiquidNeuralNetNative::initialize(int input_size, int hidden_size, int output_size) {
    // Clean up previous instance if exists
    if (lnn) {
        delete lnn;
    }

    // Create new LNN instance
    lnn = new LiquidNeuralNet(input_size, hidden_size, output_size);
}

PackedFloat64Array LiquidNeuralNetNative::forward(const PackedFloat64Array& input_phases) {
    if (!lnn) {
        return PackedFloat64Array();  // Return empty array if not initialized
    }

    // Convert PackedFloat64Array to std::vector<double>
    std::vector<double> input_vec;
    for (int i = 0; i < input_phases.size(); ++i) {
        input_vec.push_back(input_phases[i]);
    }

    // Call C++ forward pass
    std::vector<double> output_vec = lnn->forward(input_vec);

    // Convert std::vector<double> back to PackedFloat64Array
    PackedFloat64Array result;
    for (double val : output_vec) {
        result.push_back(val);
    }

    return result;
}

void LiquidNeuralNetNative::reset_state() {
    if (!lnn) return;
    lnn->reset_state();
}

void LiquidNeuralNetNative::set_learning_rate(double lr) {
    if (!lnn) return;
    lnn->set_learning_rate(lr);
}

void LiquidNeuralNetNative::set_leak(double new_leak) {
    if (!lnn) return;
    lnn->set_leak(new_leak);
}

void LiquidNeuralNetNative::set_tau(double new_tau) {
    if (!lnn) return;
    lnn->set_tau(new_tau);
}

PackedFloat64Array LiquidNeuralNetNative::get_hidden_state() const {
    if (!lnn) {
        return PackedFloat64Array();
    }

    // Get hidden state from C++ class
    std::vector<double> state_vec = lnn->get_hidden_state();

    // Convert to PackedFloat64Array
    PackedFloat64Array result;
    for (double val : state_vec) {
        result.push_back(val);
    }

    return result;
}

double LiquidNeuralNetNative::train_batch(const Array& target_trajectory) {
    if (!lnn) return 0.0;

    // Convert Godot Array of Arrays to std::vector<std::vector<double>>
    std::vector<std::vector<double>> trajectory;

    for (int i = 0; i < target_trajectory.size(); ++i) {
        Variant element = target_trajectory[i];

        // Handle both PackedFloat64Array and regular Array
        std::vector<double> target;

        if (element.get_type() == Variant::PACKED_FLOAT64_ARRAY) {
            PackedFloat64Array pfa = element;
            for (int j = 0; j < pfa.size(); ++j) {
                target.push_back(pfa[j]);
            }
        } else if (element.get_type() == Variant::ARRAY) {
            Array arr = element;
            for (int j = 0; j < arr.size(); ++j) {
                target.push_back((double)arr[j]);
            }
        }

        if (!target.empty()) {
            trajectory.push_back(target);
        }
    }

    // Call C++ training
    if (trajectory.empty()) {
        return 0.0;
    }

    return lnn->train_batch(trajectory);
}
