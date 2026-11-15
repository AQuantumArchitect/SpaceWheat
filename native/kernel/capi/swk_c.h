/* swk_c.h - plain C interface to the swk density-matrix kernel.
 *
 * Packed matrix: 2*dim*dim doubles, row-major, interleaved [re00, im00, re01, im01, ...].
 * Qubit q of n lives at bit n-1-q (most significant first). Pole 0 is north, 1 is south.
 * No exception crosses this boundary. Functions return an int status (SWK_OK == 0) unless
 * documented as a getter. Every pointer argument is null-checked (SWK_ERR_NULL_POINTER).
 */
#ifndef SWK_C_H
#define SWK_C_H

#include <stdint.h>

#if defined(_WIN32)
#  if defined(SWK_BUILDING)
#    define SWK_API __declspec(dllexport)
#  else
#    define SWK_API
#  endif
#else
#  define SWK_API __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Values 0..6 equal the numeric values of swk::Status. */
enum swk_status {
    SWK_OK = 0,
    SWK_ERR_DIMENSION_NOT_SET = 1,
    SWK_ERR_SIZE_MISMATCH = 2,
    SWK_ERR_NOT_FINALIZED = 3,
    SWK_ERR_INDEX_OUT_OF_RANGE = 4,
    SWK_ERR_INVALID_ARGUMENT = 5,
    SWK_ERR_EIGEN_FAILURE = 6,
    SWK_ERR_INTERNAL = 7,      /* a C++ exception was caught at the boundary */
    SWK_ERR_NULL_POINTER = 8   /* a required pointer argument was NULL */
};

/* Diagnostic severities passed to the callback. */
enum swk_severity { SWK_SEVERITY_WARNING = 0, SWK_SEVERITY_ERROR = 1 };

typedef struct swk_engine swk_engine;
typedef void (*swk_diagnostic_fn)(int severity, const char* msg, void* user);

SWK_API const char* swk_version(void);
SWK_API const char* swk_status_name(int status);
SWK_API int swk_bloch_stride(void);

/* Engine lifecycle. create returns NULL on failure; destroy(NULL) is a no-op. */
SWK_API swk_engine* swk_engine_create(void);
SWK_API void swk_engine_destroy(swk_engine* e);

/* Pass cb = NULL to remove. Default: none. */
SWK_API int swk_engine_set_diagnostic_callback(swk_engine* e, swk_diagnostic_fn cb, void* user);

SWK_API int swk_engine_set_dimension(swk_engine* e, int dim);
SWK_API int swk_engine_set_hamiltonian_packed(swk_engine* e, const double* data, int64_t count);
SWK_API int swk_engine_add_lindblad_triplets(swk_engine* e, const double* data, int64_t count);
SWK_API int swk_engine_clear_operators(swk_engine* e);
SWK_API int swk_engine_set_coherent(swk_engine* e, int on);
SWK_API int swk_engine_finalize(swk_engine* e);

/* Getters: return the value directly (0 for a NULL engine). */
SWK_API int swk_engine_dimension(const swk_engine* e);
SWK_API int swk_engine_lindblad_count(const swk_engine* e);
SWK_API int swk_engine_is_finalized(const swk_engine* e);
SWK_API int swk_engine_last_substep_count(const swk_engine* e);

/* rho_in and rho_out hold `count` doubles (must be 2*dim*dim); they may alias.
 * rho_out is written only on SWK_OK. max_dt <= 0 means dt. */
SWK_API int swk_engine_evolve(swk_engine* e, const double* rho_in, int64_t count, double dt,
                              double max_dt, double* rho_out);

/* Stateless functions on packed matrices. `dim` is the matrix side; `count` = 2*dim*dim. */
SWK_API int swk_purity(const double* rho, int64_t count, int dim, double* out);
SWK_API int swk_trace(const double* rho, int64_t count, int dim, double* out_re_im /* 2 doubles */);
/* out: 9 * num_qubits doubles (stride swk_bloch_stride()). */
SWK_API int swk_bloch_metrics(const double* rho, int64_t count, int num_qubits, double* out);
/* out: n(n-1)/2 doubles, upper-triangular pair order. */
SWK_API int swk_mutual_information_all(const double* rho, int64_t count, int num_qubits,
                                       double* out);
SWK_API int swk_marginal(const double* rho, int64_t count, int qubit, int num_qubits, int pole,
                         double* out);
/* In place on the packed buffer. */
SWK_API int swk_project_qubit(double* rho, int64_t count, int qubit, int num_qubits, int pole);
SWK_API int swk_drain_qubit(double* rho, int64_t count, int qubit, int num_qubits, int pole,
                            double eta);
/* Getter: returns 0 (north) when u < p_north, else 1 (south). */
SWK_API int swk_born_outcome(double p_north, double u);

#ifdef __cplusplus
}
#endif

#endif /* SWK_C_H */
