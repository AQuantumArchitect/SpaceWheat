#include "quantum_matrix_native.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <Eigen/Eigenvalues>
#include <unsupported/Eigen/MatrixFunctions>
#include <complex>
#include <cmath>

using namespace godot;

void QuantumMatrixNative::_bind_methods() {
    ClassDB::bind_method(D_METHOD("from_packed", "data", "dim"), &QuantumMatrixNative::from_packed);
    ClassDB::bind_method(D_METHOD("to_packed"), &QuantumMatrixNative::to_packed);
    ClassDB::bind_method(D_METHOD("get_dimension"), &QuantumMatrixNative::get_dimension);

    ClassDB::bind_method(D_METHOD("mul", "other", "dim"), &QuantumMatrixNative::mul);
    ClassDB::bind_method(D_METHOD("expm"), &QuantumMatrixNative::expm);
    ClassDB::bind_method(D_METHOD("inverse"), &QuantumMatrixNative::inverse);
    ClassDB::bind_method(D_METHOD("eigensystem"), &QuantumMatrixNative::eigensystem);

    ClassDB::bind_method(D_METHOD("add", "other", "dim"), &QuantumMatrixNative::add);
    ClassDB::bind_method(D_METHOD("sub", "other", "dim"), &QuantumMatrixNative::sub);
    ClassDB::bind_method(D_METHOD("scale", "re", "im"), &QuantumMatrixNative::scale);
    ClassDB::bind_method(D_METHOD("dagger"), &QuantumMatrixNative::dagger);
    ClassDB::bind_method(D_METHOD("commutator", "other", "dim"), &QuantumMatrixNative::commutator);

    ClassDB::bind_method(D_METHOD("trace_real"), &QuantumMatrixNative::trace_real);
    ClassDB::bind_method(D_METHOD("trace_imag"), &QuantumMatrixNative::trace_imag);
    ClassDB::bind_method(D_METHOD("is_hermitian", "tolerance"), &QuantumMatrixNative::is_hermitian);
}

QuantumMatrixNative::QuantumMatrixNative() : m_dim(0) {}
QuantumMatrixNative::~QuantumMatrixNative() {}

PackedFloat64Array QuantumMatrixNative::pack_matrix(const Eigen::MatrixXcd& mat, int dim) const {
    PackedFloat64Array packed;
    packed.resize(dim * dim * 2);
    double* ptr = packed.ptrw();

    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            ptr[idx] = mat(i, j).real();
            ptr[idx + 1] = mat(i, j).imag();
        }
    }
    return packed;
}

void QuantumMatrixNative::from_packed(const PackedFloat64Array& data, int dim) {
    m_dim = dim;
    m_matrix.resize(dim, dim);

    const double* ptr = data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            m_matrix(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }
}

PackedFloat64Array QuantumMatrixNative::to_packed() const {
    return pack_matrix(m_matrix, m_dim);
}

int QuantumMatrixNative::get_dimension() const {
    return m_dim;
}

PackedFloat64Array QuantumMatrixNative::mul(const PackedFloat64Array& other_data, int dim) const {
    // Unpack other matrix
    Eigen::MatrixXcd other(dim, dim);
    const double* ptr = other_data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            other(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }

    // Eigen matrix multiplication (SIMD optimized)
    Eigen::MatrixXcd result = m_matrix * other;

    return pack_matrix(result, dim);
}

PackedFloat64Array QuantumMatrixNative::expm() const {
    // Matrix exponential using Eigen's unsupported module
    // Uses Pade approximation with scaling-squaring internally
    Eigen::MatrixXcd result = m_matrix.exp();
    return pack_matrix(result, m_dim);
}

PackedFloat64Array QuantumMatrixNative::inverse() const {
    // LU decomposition based inverse
    Eigen::MatrixXcd result = m_matrix.inverse();
    return pack_matrix(result, m_dim);
}

Dictionary QuantumMatrixNative::eigensystem() const {
    // Use SelfAdjointEigenSolver for Hermitian matrices (faster and more stable)
    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(m_matrix);

    // Eigenvalues (real for Hermitian)
    Array eigenvalues;
    for (int i = 0; i < m_dim; i++) {
        eigenvalues.push_back(solver.eigenvalues()(i));
    }

    // Eigenvectors as packed array
    PackedFloat64Array packed_vecs = pack_matrix(solver.eigenvectors(), m_dim);

    Dictionary result;
    result["eigenvalues"] = eigenvalues;
    result["eigenvectors"] = packed_vecs;
    return result;
}

PackedFloat64Array QuantumMatrixNative::add(const PackedFloat64Array& other_data, int dim) const {
    Eigen::MatrixXcd other(dim, dim);
    const double* ptr = other_data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            other(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }

    Eigen::MatrixXcd result = m_matrix + other;
    return pack_matrix(result, dim);
}

PackedFloat64Array QuantumMatrixNative::sub(const PackedFloat64Array& other_data, int dim) const {
    Eigen::MatrixXcd other(dim, dim);
    const double* ptr = other_data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            other(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }

    Eigen::MatrixXcd result = m_matrix - other;
    return pack_matrix(result, dim);
}

PackedFloat64Array QuantumMatrixNative::scale(double re, double im) const {
    std::complex<double> scalar(re, im);
    Eigen::MatrixXcd result = m_matrix * scalar;
    return pack_matrix(result, m_dim);
}

PackedFloat64Array QuantumMatrixNative::dagger() const {
    Eigen::MatrixXcd result = m_matrix.adjoint();
    return pack_matrix(result, m_dim);
}

PackedFloat64Array QuantumMatrixNative::commutator(const PackedFloat64Array& other_data, int dim) const {
    Eigen::MatrixXcd other(dim, dim);
    const double* ptr = other_data.ptr();
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            other(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }

    // [A, B] = AB - BA
    Eigen::MatrixXcd result = m_matrix * other - other * m_matrix;
    return pack_matrix(result, dim);
}

double QuantumMatrixNative::trace_real() const {
    return m_matrix.trace().real();
}

double QuantumMatrixNative::trace_imag() const {
    return m_matrix.trace().imag();
}

bool QuantumMatrixNative::is_hermitian(double tolerance) const {
    return (m_matrix - m_matrix.adjoint()).norm() < tolerance;
}
