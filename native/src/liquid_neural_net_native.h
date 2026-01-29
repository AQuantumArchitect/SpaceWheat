#ifndef LIQUID_NEURAL_NET_NATIVE_H
#define LIQUID_NEURAL_NET_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include "liquid_neural_net.h"

using namespace godot;

class LiquidNeuralNetNative : public RefCounted {
    GDCLASS(LiquidNeuralNetNative, RefCounted);

private:
    LiquidNeuralNet* lnn = nullptr;

protected:
    static void _bind_methods();

public:
    LiquidNeuralNetNative();
    ~LiquidNeuralNetNative();

    // Initialize network
    void initialize(int input_size, int hidden_size, int output_size);

    // Forward pass: input_phases -> phase modulation signals
    PackedFloat64Array forward(const PackedFloat64Array& input_phases);

    // Reset hidden state
    void reset_state();

    // Setters
    void set_learning_rate(double lr);
    void set_leak(double new_leak);
    void set_tau(double new_tau);

    // Getters
    PackedFloat64Array get_hidden_state() const;

    // Training
    double train_batch(const Array& target_trajectory);
};

#endif // LIQUID_NEURAL_NET_NATIVE_H
