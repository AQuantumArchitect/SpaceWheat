#pragma once

#include <complex>
#include <cstddef>
#include <stdexcept>
#include <string>
#include <vector>

namespace spacewheat {

using Complex = std::complex<double>;

class ComplexMatrix {
public:
    ComplexMatrix() = default;
    ComplexMatrix(std::size_t rows, std::size_t cols, Complex fill = Complex(0.0, 0.0));

    static ComplexMatrix identity(std::size_t n);
    static ComplexMatrix zeros(std::size_t rows, std::size_t cols);

    std::size_t rows() const { return rows_; }
    std::size_t cols() const { return cols_; }
    bool empty() const { return rows_ == 0 || cols_ == 0; }

    Complex &operator()(std::size_t r, std::size_t c);
    const Complex &operator()(std::size_t r, std::size_t c) const;

    const std::vector<Complex> &data() const { return data_; }
    std::vector<Complex> &data() { return data_; }

    Complex trace() const;
    double real_trace() const;
    double frobenius_norm() const;

    ComplexMatrix dagger() const;
    ComplexMatrix real_part_as_complex() const;

    void add_scaled(const ComplexMatrix &other, Complex scale);
    void scale(Complex s);
    void enforce_hermitian(double epsilon = 0.0);
    void normalize_trace(double target_trace = 1.0);
    void clamp_small(double epsilon = 1e-14);

    std::vector<double> real_diagonal() const;
    std::string shape_string() const;

private:
    std::size_t rows_ = 0;
    std::size_t cols_ = 0;
    std::vector<Complex> data_;

    void check_same_shape(const ComplexMatrix &other) const;
};

ComplexMatrix operator+(ComplexMatrix lhs, const ComplexMatrix &rhs);
ComplexMatrix operator-(ComplexMatrix lhs, const ComplexMatrix &rhs);
ComplexMatrix operator*(const ComplexMatrix &lhs, const ComplexMatrix &rhs);
ComplexMatrix commutator(const ComplexMatrix &a, const ComplexMatrix &b);

} // namespace spacewheat
