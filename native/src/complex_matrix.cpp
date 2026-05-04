#include "complex_matrix.h"

#include <algorithm>
#include <cmath>
#include <sstream>

namespace spacewheat {

ComplexMatrix::ComplexMatrix(std::size_t rows, std::size_t cols, Complex fill)
    : rows_(rows), cols_(cols), data_(rows * cols, fill) {}

ComplexMatrix ComplexMatrix::identity(std::size_t n) {
    ComplexMatrix m(n, n);
    for (std::size_t i = 0; i < n; ++i) {
        m(i, i) = Complex(1.0, 0.0);
    }
    return m;
}

ComplexMatrix ComplexMatrix::zeros(std::size_t rows, std::size_t cols) {
    return ComplexMatrix(rows, cols, Complex(0.0, 0.0));
}

Complex &ComplexMatrix::operator()(std::size_t r, std::size_t c) {
    if (r >= rows_ || c >= cols_) {
        throw std::out_of_range("ComplexMatrix index out of range");
    }
    return data_[r * cols_ + c];
}

const Complex &ComplexMatrix::operator()(std::size_t r, std::size_t c) const {
    if (r >= rows_ || c >= cols_) {
        throw std::out_of_range("ComplexMatrix index out of range");
    }
    return data_[r * cols_ + c];
}

void ComplexMatrix::check_same_shape(const ComplexMatrix &other) const {
    if (rows_ != other.rows_ || cols_ != other.cols_) {
        throw std::invalid_argument("ComplexMatrix shape mismatch");
    }
}

Complex ComplexMatrix::trace() const {
    if (rows_ != cols_) {
        throw std::invalid_argument("trace requires square matrix");
    }
    Complex t(0.0, 0.0);
    for (std::size_t i = 0; i < rows_; ++i) {
        t += (*this)(i, i);
    }
    return t;
}

double ComplexMatrix::real_trace() const {
    return trace().real();
}

double ComplexMatrix::frobenius_norm() const {
    double sum = 0.0;
    for (const Complex &z : data_) {
        sum += std::norm(z);
    }
    return std::sqrt(sum);
}

ComplexMatrix ComplexMatrix::dagger() const {
    ComplexMatrix out(cols_, rows_);
    for (std::size_t r = 0; r < rows_; ++r) {
        for (std::size_t c = 0; c < cols_; ++c) {
            out(c, r) = std::conj((*this)(r, c));
        }
    }
    return out;
}

ComplexMatrix ComplexMatrix::real_part_as_complex() const {
    ComplexMatrix out(rows_, cols_);
    for (std::size_t i = 0; i < data_.size(); ++i) {
        out.data_[i] = Complex(data_[i].real(), 0.0);
    }
    return out;
}

void ComplexMatrix::add_scaled(const ComplexMatrix &other, Complex scale_value) {
    check_same_shape(other);
    for (std::size_t i = 0; i < data_.size(); ++i) {
        data_[i] += scale_value * other.data_[i];
    }
}

void ComplexMatrix::scale(Complex s) {
    for (Complex &z : data_) {
        z *= s;
    }
}

void ComplexMatrix::enforce_hermitian(double epsilon) {
    if (rows_ != cols_) {
        throw std::invalid_argument("enforce_hermitian requires square matrix");
    }
    for (std::size_t i = 0; i < rows_; ++i) {
        (*this)(i, i) = Complex((*this)(i, i).real(), 0.0);
        for (std::size_t j = i + 1; j < cols_; ++j) {
            Complex avg = ((*this)(i, j) + std::conj((*this)(j, i))) * Complex(0.5, 0.0);
            if (std::abs(avg.real()) < epsilon && std::abs(avg.imag()) < epsilon) {
                avg = Complex(0.0, 0.0);
            }
            (*this)(i, j) = avg;
            (*this)(j, i) = std::conj(avg);
        }
    }
}

void ComplexMatrix::normalize_trace(double target_trace) {
    double t = real_trace();
    if (std::abs(t) < 1e-14) {
        return;
    }
    scale(Complex(target_trace / t, 0.0));
}

void ComplexMatrix::clamp_small(double epsilon) {
    for (Complex &z : data_) {
        double re = std::abs(z.real()) < epsilon ? 0.0 : z.real();
        double im = std::abs(z.imag()) < epsilon ? 0.0 : z.imag();
        z = Complex(re, im);
    }
}

std::vector<double> ComplexMatrix::real_diagonal() const {
    if (rows_ != cols_) {
        throw std::invalid_argument("real_diagonal requires square matrix");
    }
    std::vector<double> out(rows_, 0.0);
    for (std::size_t i = 0; i < rows_; ++i) {
        out[i] = (*this)(i, i).real();
    }
    return out;
}

std::string ComplexMatrix::shape_string() const {
    std::ostringstream oss;
    oss << rows_ << "x" << cols_;
    return oss.str();
}

ComplexMatrix operator+(ComplexMatrix lhs, const ComplexMatrix &rhs) {
    lhs.add_scaled(rhs, Complex(1.0, 0.0));
    return lhs;
}

ComplexMatrix operator-(ComplexMatrix lhs, const ComplexMatrix &rhs) {
    lhs.add_scaled(rhs, Complex(-1.0, 0.0));
    return lhs;
}

ComplexMatrix operator*(const ComplexMatrix &lhs, const ComplexMatrix &rhs) {
    if (lhs.cols() != rhs.rows()) {
        throw std::invalid_argument("ComplexMatrix multiplication shape mismatch");
    }
    ComplexMatrix out(lhs.rows(), rhs.cols());
    for (std::size_t r = 0; r < lhs.rows(); ++r) {
        for (std::size_t k = 0; k < lhs.cols(); ++k) {
            const Complex a = lhs(r, k);
            if (std::abs(a) < 1e-18) {
                continue;
            }
            for (std::size_t c = 0; c < rhs.cols(); ++c) {
                out(r, c) += a * rhs(k, c);
            }
        }
    }
    return out;
}

ComplexMatrix commutator(const ComplexMatrix &a, const ComplexMatrix &b) {
    return (a * b) - (b * a);
}

} // namespace spacewheat
