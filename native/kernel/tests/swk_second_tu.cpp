// A second translation unit that includes the umbrella header. Linking it with
// swk_tests.cpp proves every function in the headers is inline (no ODR clash).
#include "swk/swk.hpp"

namespace swk_test {

// Purity of a maximally mixed 1-qubit state (0.5), evolved with an engine built in this TU.
double second_tu_purity() {
    swk::CMatrix rho = swk::CMatrix::Zero(2, 2);
    rho(0, 0) = swk::Complex(0.5, 0.0);
    rho(1, 1) = swk::Complex(0.5, 0.0);
    swk::EvolutionEngine eng;
    eng.set_dimension(2);
    eng.finalize();
    eng.evolve(rho, 0.1, 0.1);
    swk::MiScreen screen;
    (void)screen.compute(rho, 1, 0.5, true);
    return swk::purity(rho);
}

}  // namespace swk_test
