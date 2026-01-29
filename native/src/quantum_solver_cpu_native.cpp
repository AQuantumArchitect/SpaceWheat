#include "quantum_solver_cpu_native.h"
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

void QuantumSolverCPUNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize", "hilbert_dim"), &QuantumSolverCPUNative::initialize);
    ClassDB::bind_method(D_METHOD("set_hamiltonian_flat", "H_flat"), &QuantumSolverCPUNative::set_hamiltonian_flat);
    ClassDB::bind_method(D_METHOD("add_lindblad_operator", "L_flat"), &QuantumSolverCPUNative::add_lindblad_operator);
    ClassDB::bind_method(D_METHOD("clear_lindblad_operators"), &QuantumSolverCPUNative::clear_lindblad_operators);
    ClassDB::bind_method(D_METHOD("evolve", "rho_flat", "dt"), &QuantumSolverCPUNative::evolve);
    ClassDB::bind_method(D_METHOD("evolve_unitary", "rho_flat", "dt"), &QuantumSolverCPUNative::evolve_unitary);
    ClassDB::bind_method(D_METHOD("evolve_lindblad", "rho_flat", "dt"), &QuantumSolverCPUNative::evolve_lindblad);
    ClassDB::bind_method(D_METHOD("expectation_value", "O_flat", "rho_flat"), &QuantumSolverCPUNative::expectation_value);
    ClassDB::bind_method(D_METHOD("purity", "rho_flat"), &QuantumSolverCPUNative::purity);
    ClassDB::bind_method(D_METHOD("trace", "rho_flat"), &QuantumSolverCPUNative::trace);
    ClassDB::bind_method(D_METHOD("normalize", "rho_flat"), &QuantumSolverCPUNative::normalize);
    ClassDB::bind_method(D_METHOD("set_pade_order", "order"), &QuantumSolverCPUNative::set_pade_order);
    ClassDB::bind_method(D_METHOD("set_multithreading", "enabled"), &QuantumSolverCPUNative::set_multithreading);
    ClassDB::bind_method(D_METHOD("get_metrics"), &QuantumSolverCPUNative::get_metrics);
}

QuantumSolverCPUNative::QuantumSolverCPUNative() : solver(nullptr) {
}

QuantumSolverCPUNative::~QuantumSolverCPUNative() {
    if (solver) {
        delete solver;
        solver = nullptr;
    }
}

void QuantumSolverCPUNative::initialize(int hilbert_dim) {
    if (solver) {
        delete solver;
    }
    solver = new QuantumSolverCPU(hilbert_dim);
}

void QuantumSolverCPUNative::set_hamiltonian_flat(const PackedFloat64Array& H_flat) {
    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return;
    }

    int dim = solver->get_metrics().hilbert_dim;
    if ((int)H_flat.size() != 2 * dim * dim) {
        ERR_PRINT("QuantumSolverCPUNative: Hamiltonian size mismatch");
        return;
    }

    // Construct MatrixXcd from flattened array
    MatrixXcd H = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = H_flat[idx++];
            double im = H_flat[idx++];
            H(i, j) = std::complex<double>(re, im);
        }
    }

    solver->set_hamiltonian(H);
}

void QuantumSolverCPUNative::add_lindblad_operator(const PackedFloat64Array& L_flat) {
    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return;
    }

    int dim = solver->get_metrics().hilbert_dim;
    if ((int)L_flat.size() != 2 * dim * dim) {
        ERR_PRINT("QuantumSolverCPUNative: Lindblad operator size mismatch");
        return;
    }

    // Construct MatrixXcd from flattened array
    MatrixXcd L = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = L_flat[idx++];
            double im = L_flat[idx++];
            L(i, j) = std::complex<double>(re, im);
        }
    }

    solver->add_lindblad_operator(L);
}

void QuantumSolverCPUNative::clear_lindblad_operators() {
    if (!solver) return;
    solver->clear_lindblad_operators();
}

PackedFloat64Array QuantumSolverCPUNative::evolve(const PackedFloat64Array& rho_flat, double dt) {
    PackedFloat64Array result;

    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return result;
    }

    int dim = solver->get_metrics().hilbert_dim;
    if ((int)rho_flat.size() != 2 * dim * dim) {
        ERR_PRINT("QuantumSolverCPUNative: Density matrix size mismatch");
        return result;
    }

    // Unpack density matrix
    MatrixXcd rho = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = rho_flat[idx++];
            double im = rho_flat[idx++];
            rho(i, j) = std::complex<double>(re, im);
        }
    }

    // Evolve
    solver->evolve(rho, dt);

    // Pack back into result array
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            result.push_back(rho(i, j).real());
            result.push_back(rho(i, j).imag());
        }
    }

    return result;
}

PackedFloat64Array QuantumSolverCPUNative::evolve_unitary(const PackedFloat64Array& rho_flat, double dt) {
    PackedFloat64Array result;

    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return result;
    }

    int dim = solver->get_metrics().hilbert_dim;
    if ((int)rho_flat.size() != 2 * dim * dim) {
        ERR_PRINT("QuantumSolverCPUNative: Density matrix size mismatch");
        return result;
    }

    // Unpack
    MatrixXcd rho = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = rho_flat[idx++];
            double im = rho_flat[idx++];
            rho(i, j) = std::complex<double>(re, im);
        }
    }

    // Evolve
    solver->evolve_unitary(rho, dt);

    // Pack back
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            result.push_back(rho(i, j).real());
            result.push_back(rho(i, j).imag());
        }
    }

    return result;
}

PackedFloat64Array QuantumSolverCPUNative::evolve_lindblad(const PackedFloat64Array& rho_flat, double dt) {
    PackedFloat64Array result;

    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return result;
    }

    int dim = solver->get_metrics().hilbert_dim;
    if ((int)rho_flat.size() != 2 * dim * dim) {
        ERR_PRINT("QuantumSolverCPUNative: Density matrix size mismatch");
        return result;
    }

    // Unpack
    MatrixXcd rho = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = rho_flat[idx++];
            double im = rho_flat[idx++];
            rho(i, j) = std::complex<double>(re, im);
        }
    }

    // Evolve
    solver->evolve_lindblad(rho, dt);

    // Pack back
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            result.push_back(rho(i, j).real());
            result.push_back(rho(i, j).imag());
        }
    }

    return result;
}

PackedFloat64Array QuantumSolverCPUNative::expectation_value(const PackedFloat64Array& O_flat, const PackedFloat64Array& rho_flat) {
    PackedFloat64Array result;

    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        result.push_back(0.0);
        result.push_back(0.0);
        return result;
    }

    int dim = solver->get_metrics().hilbert_dim;

    // Unpack operator
    MatrixXcd O = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = O_flat[idx++];
            double im = O_flat[idx++];
            O(i, j) = std::complex<double>(re, im);
        }
    }

    // Unpack density matrix
    MatrixXcd rho = MatrixXcd::Zero(dim, dim);
    idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = rho_flat[idx++];
            double im = rho_flat[idx++];
            rho(i, j) = std::complex<double>(re, im);
        }
    }

    // Compute
    auto ev = solver->expectation_value(O, rho);
    result.push_back(ev.real());
    result.push_back(ev.imag());

    return result;
}

double QuantumSolverCPUNative::purity(const PackedFloat64Array& rho_flat) {
    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return 0.0;
    }

    int dim = solver->get_metrics().hilbert_dim;

    // Unpack
    MatrixXcd rho = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = rho_flat[idx++];
            double im = rho_flat[idx++];
            rho(i, j) = std::complex<double>(re, im);
        }
    }

    return solver->purity(rho);
}

PackedFloat64Array QuantumSolverCPUNative::trace(const PackedFloat64Array& rho_flat) {
    PackedFloat64Array result;

    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        result.push_back(0.0);
        result.push_back(0.0);
        return result;
    }

    int dim = solver->get_metrics().hilbert_dim;

    // Unpack
    MatrixXcd rho = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = rho_flat[idx++];
            double im = rho_flat[idx++];
            rho(i, j) = std::complex<double>(re, im);
        }
    }

    auto tr = solver->trace(rho);
    result.push_back(tr.real());
    result.push_back(tr.imag());

    return result;
}

PackedFloat64Array QuantumSolverCPUNative::normalize(const PackedFloat64Array& rho_flat) {
    PackedFloat64Array result;

    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return result;
    }

    int dim = solver->get_metrics().hilbert_dim;

    // Unpack
    MatrixXcd rho = MatrixXcd::Zero(dim, dim);
    int idx = 0;
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            double re = rho_flat[idx++];
            double im = rho_flat[idx++];
            rho(i, j) = std::complex<double>(re, im);
        }
    }

    // Normalize
    solver->normalize(rho);

    // Pack back
    for (int i = 0; i < dim; ++i) {
        for (int j = 0; j < dim; ++j) {
            result.push_back(rho(i, j).real());
            result.push_back(rho(i, j).imag());
        }
    }

    return result;
}

void QuantumSolverCPUNative::set_pade_order(int order) {
    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return;
    }
    solver->set_pade_order(order);
}

void QuantumSolverCPUNative::set_multithreading(bool enabled) {
    if (!solver) {
        ERR_PRINT("QuantumSolverCPUNative: initialize() not called");
        return;
    }
    solver->set_multithreading(enabled);
}

Dictionary QuantumSolverCPUNative::get_metrics() {
    Dictionary result;

    if (!solver) {
        result["error"] = "Not initialized";
        return result;
    }

    const auto& metrics = solver->get_metrics();
    result["evolution_time_ms"] = metrics.evolution_time_ms;
    result["matrix_exp_time_ms"] = metrics.matrix_exp_time_ms;
    result["lindblad_time_ms"] = metrics.lindblad_time_ms;
    result["pade_iterations"] = metrics.pade_iterations;
    result["hilbert_dim"] = metrics.hilbert_dim;

    return result;
}
