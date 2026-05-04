#include "mythos_graph_core.h"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace spacewheat {

MythosGraphCore::MythosGraphCore() {
    clear();
}

void MythosGraphCore::clear() {
    emojis_.clear();
    icons_.clear();
    factions_.clear();
    emoji_to_index_.clear();
    faction_to_index_.clear();
    pair_to_icon_.clear();
    hamiltonian_ = ComplexMatrix();
    density_ = ComplexMatrix();
    faction_density_ = ComplexMatrix();
}

int MythosGraphCore::ensure_emoji(const std::string &emoji) {
    auto it = emoji_to_index_.find(emoji);
    if (it != emoji_to_index_.end()) {
        return it->second;
    }
    const int idx = static_cast<int>(emojis_.size());
    emojis_.push_back({emoji, 0.0, 0.0});
    emoji_to_index_[emoji] = idx;
    return idx;
}

void MythosGraphCore::set_emoji_physics(const std::string &emoji, double self_energy, double decay) {
    const int idx = ensure_emoji(emoji);
    emojis_[static_cast<std::size_t>(idx)].self_energy = self_energy;
    emojis_[static_cast<std::size_t>(idx)].decay = decay;
}

int MythosGraphCore::add_icon(const IconEdge &icon) {
    ensure_emoji(icon.pole0);
    ensure_emoji(icon.pole1);
    IconEdge copy = icon;
    if (copy.id.empty()) {
        copy.id = copy.name.empty() ? pair_key(copy.pole0, copy.pole1) : copy.name;
    }
    if (copy.field.mass <= 0.0) {
        copy.field.mass = 1.0;
    }
    const int idx = static_cast<int>(icons_.size());
    icons_.push_back(copy);
    pair_to_icon_[pair_key(copy.pole0, copy.pole1)] = idx;
    pair_to_icon_[unordered_pair_key(copy.pole0, copy.pole1)] = idx;
    return idx;
}

int MythosGraphCore::add_faction(const FactionField &faction) {
    FactionField copy = faction;
    if (copy.field.mass <= 0.0) {
        copy.field = axial_.field_from_bits(copy.bits.empty() ? std::vector<double>(AXIS_COUNT, 0.5) : copy.bits);
    }
    const int idx = static_cast<int>(factions_.size());
    factions_.push_back(copy);
    faction_to_index_[copy.name] = idx;
    for (const std::string &emoji : copy.sig) {
        ensure_emoji(emoji);
    }
    initialize_faction_density_uniform();
    return idx;
}

int MythosGraphCore::emoji_index(const std::string &emoji) const {
    auto it = emoji_to_index_.find(emoji);
    return it == emoji_to_index_.end() ? -1 : it->second;
}

int MythosGraphCore::icon_index_by_pair(const std::string &pole0, const std::string &pole1) const {
    auto it = pair_to_icon_.find(pair_key(pole0, pole1));
    if (it != pair_to_icon_.end()) {
        return it->second;
    }
    it = pair_to_icon_.find(unordered_pair_key(pole0, pole1));
    return it == pair_to_icon_.end() ? -1 : it->second;
}

int MythosGraphCore::faction_index(const std::string &name) const {
    auto it = faction_to_index_.find(name);
    return it == faction_to_index_.end() ? -1 : it->second;
}

void MythosGraphCore::compose_hamiltonian_from_icons() {
    const std::size_t n = emojis_.size();
    hamiltonian_ = ComplexMatrix::zeros(n, n);
    for (std::size_t i = 0; i < n; ++i) {
        hamiltonian_(i, i) = Complex(emojis_[i].self_energy, 0.0);
    }
    for (const IconEdge &icon : icons_) {
        const int a = emoji_index(icon.pole0);
        const int b = emoji_index(icon.pole1);
        if (a < 0 || b < 0 || a == b) {
            continue;
        }
        const Complex coupling = std::polar(icon.coupling * icon.visibility, icon.phase);
        hamiltonian_(static_cast<std::size_t>(a), static_cast<std::size_t>(b)) += coupling;
        hamiltonian_(static_cast<std::size_t>(b), static_cast<std::size_t>(a)) += std::conj(coupling);
    }
    hamiltonian_.enforce_hermitian();
}

void MythosGraphCore::initialize_density_uniform() {
    const std::size_t n = emojis_.size();
    density_ = ComplexMatrix::zeros(n, n);
    if (n == 0) {
        return;
    }
    const double p = 1.0 / static_cast<double>(n);
    for (std::size_t i = 0; i < n; ++i) {
        density_(i, i) = Complex(p, 0.0);
    }
}

void MythosGraphCore::initialize_density_pure_emoji(const std::string &emoji) {
    const int idx = emoji_index(emoji);
    const std::size_t n = emojis_.size();
    density_ = ComplexMatrix::zeros(n, n);
    if (idx >= 0) {
        density_(static_cast<std::size_t>(idx), static_cast<std::size_t>(idx)) = Complex(1.0, 0.0);
    } else {
        initialize_density_uniform();
    }
}

void MythosGraphCore::step_density(double dt, double decoherence) {
    if (density_.empty() || hamiltonian_.empty()) {
        return;
    }
    // First-order von Neumann step: dρ/dt = -i[H,ρ]
    ComplexMatrix drho = commutator(hamiltonian_, density_);
    drho.scale(Complex(0.0, -1.0));
    density_.add_scaled(drho, Complex(dt, 0.0));

    // Simple diagonal dephasing/decoherence. More precise Lindblad operators can be added later.
    if (decoherence > 0.0) {
        const double decay = std::exp(-decoherence * dt);
        for (std::size_t r = 0; r < density_.rows(); ++r) {
            for (std::size_t c = 0; c < density_.cols(); ++c) {
                if (r != c) {
                    density_(r, c) *= decay;
                }
            }
        }
    }

    density_.enforce_hermitian(1e-14);
    density_.normalize_trace(1.0);
}

EigenResult MythosGraphCore::solve_hamiltonian() const {
    return HermitianEigensolver::solve(hamiltonian_);
}

void MythosGraphCore::initialize_faction_density_uniform() {
    const std::size_t n = factions_.size();
    faction_density_ = ComplexMatrix::zeros(n, n);
    if (n == 0) {
        return;
    }
    const double p = 1.0 / static_cast<double>(n);
    for (std::size_t i = 0; i < n; ++i) {
        faction_density_(i, i) = Complex(p, 0.0);
    }
}

void MythosGraphCore::apply_icon_learned(const std::string &pole0, const std::string &pole1, double strength) {
    if (factions_.empty()) {
        return;
    }
    if (faction_density_.rows() != factions_.size()) {
        initialize_faction_density_uniform();
    }

    const AxialField event_field = embed_icon_pair(pole0, pole1);
    std::vector<double> overlaps(factions_.size(), 0.0);
    double total = 0.0;
    for (std::size_t i = 0; i < factions_.size(); ++i) {
        overlaps[i] = axial_.kernel(event_field, factions_[i].field, true);
        // Direct signature match gives the local glyph graph a vote.
        const bool speaks0 = std::find(factions_[i].sig.begin(), factions_[i].sig.end(), pole0) != factions_[i].sig.end();
        const bool speaks1 = std::find(factions_[i].sig.begin(), factions_[i].sig.end(), pole1) != factions_[i].sig.end();
        if (speaks0 && speaks1) {
            overlaps[i] += 0.75;
        } else if (speaks0 || speaks1) {
            overlaps[i] += 0.20;
        }
        total += overlaps[i];
    }
    if (total <= 1e-12) {
        return;
    }

    for (std::size_t i = 0; i < factions_.size(); ++i) {
        const double wi = overlaps[i] / total;
        faction_density_(i, i) += Complex(strength * wi, 0.0);
    }

    for (std::size_t i = 0; i < factions_.size(); ++i) {
        for (std::size_t j = i + 1; j < factions_.size(); ++j) {
            const double coherence = std::sqrt(overlaps[i] * overlaps[j]) / total;
            if (coherence <= 1e-9) {
                continue;
            }
            double phase = 0.0;
            for (int axis = 0; axis < AXIS_COUNT; ++axis) {
                phase += factions_[i].field.phase[axis] - factions_[j].field.phase[axis];
            }
            phase /= static_cast<double>(AXIS_COUNT);
            const Complex kick = std::polar(strength * 0.25 * coherence, phase);
            faction_density_(i, j) += kick;
            faction_density_(j, i) += std::conj(kick);
        }
    }

    normalize_faction_density();
}

void MythosGraphCore::apply_event(const MythosEvent &event) {
    if (event.type == "icon_learned") {
        apply_icon_learned(event.pole0, event.pole1, event.strength);
    }
    // Contract/reputation/biome events should be added as graph impulses here.
}

std::vector<FactionProjection> MythosGraphCore::project_factions_for_icon(const std::string &pole0, const std::string &pole1) const {
    std::vector<FactionProjection> out;
    const AxialField field = embed_icon_pair(pole0, pole1);
    for (std::size_t i = 0; i < factions_.size(); ++i) {
        FactionProjection p;
        p.name = factions_[i].name;
        p.overlap = axial_.kernel(field, factions_[i].field, true);
        p.mass = faction_density_.empty() || i >= faction_density_.rows() ? 0.0 : faction_density_(i, i).real();
        out.push_back(p);
    }
    std::sort(out.begin(), out.end(), [](const FactionProjection &a, const FactionProjection &b) {
        return (a.overlap + a.mass) > (b.overlap + b.mass);
    });
    return out;
}

std::vector<double> MythosGraphCore::axis_marginal(int axis_index) const {
    if (axis_index < 0 || axis_index >= AXIS_COUNT) {
        throw std::out_of_range("axis index out of range");
    }
    std::vector<double> marginal(2, 0.0);
    if (factions_.empty() || faction_density_.empty()) {
        return marginal;
    }
    for (std::size_t i = 0; i < factions_.size(); ++i) {
        const double mass = faction_density_(i, i).real();
        const double bit = factions_[i].field.mu[static_cast<std::size_t>(axis_index)];
        marginal[0] += mass * (1.0 - bit);
        marginal[1] += mass * bit;
    }
    const double total = marginal[0] + marginal[1];
    if (total > 1e-12) {
        marginal[0] /= total;
        marginal[1] /= total;
    }
    return marginal;
}

double MythosGraphCore::icon_expectation(const std::string &pole0, const std::string &pole1) const {
    const int a = emoji_index(pole0);
    const int b = emoji_index(pole1);
    if (a < 0 || b < 0 || density_.empty()) {
        return 0.0;
    }
    const double pa = density_(static_cast<std::size_t>(a), static_cast<std::size_t>(a)).real();
    const double pb = density_(static_cast<std::size_t>(b), static_cast<std::size_t>(b)).real();
    const Complex coh = density_(static_cast<std::size_t>(a), static_cast<std::size_t>(b));
    return std::max(0.0, pa + pb + 2.0 * std::abs(coh));
}

AxialField MythosGraphCore::embed_icon_pair(const std::string &pole0, const std::string &pole1) const {
    const int idx = icon_index_by_pair(pole0, pole1);
    if (idx >= 0) {
        return icons_[static_cast<std::size_t>(idx)].field;
    }

    // Anonymous icon fallback: derive a neutral-ish field with small deterministic bias from glyph bytes.
    AxialField f = axial_.neutral_field(0.38);
    const std::string key = pole0 + ":" + pole1;
    std::size_t hash = std::hash<std::string>{}(key);
    for (int i = 0; i < AXIS_COUNT; ++i) {
        const double byte = static_cast<double>((hash >> ((i % 8) * 8)) & 0xff) / 255.0;
        f.mu[i] = 0.35 + 0.30 * byte;
        f.sigma[i] = 0.42;
    }
    f.mass = 0.35;
    return f;
}

std::string MythosGraphCore::pair_key(const std::string &a, const std::string &b) {
    return a + "\x1f" + b;
}

std::string MythosGraphCore::unordered_pair_key(const std::string &a, const std::string &b) {
    return a < b ? pair_key(a, b) : pair_key(b, a);
}

void MythosGraphCore::reindex_pairs() {
    pair_to_icon_.clear();
    for (std::size_t i = 0; i < icons_.size(); ++i) {
        pair_to_icon_[pair_key(icons_[i].pole0, icons_[i].pole1)] = static_cast<int>(i);
        pair_to_icon_[unordered_pair_key(icons_[i].pole0, icons_[i].pole1)] = static_cast<int>(i);
    }
}

void MythosGraphCore::normalize_faction_density() {
    faction_density_.enforce_hermitian(1e-14);
    faction_density_.normalize_trace(1.0);
}

// ====== Faction density facade primitives ======
//
// These mirror the algorithms in Core/Factions/FactionDensityMatrix.gd line-by-line.
// The GDScript file is the canonical reference; this is the computer.

int MythosGraphCore::faction_bit(std::size_t i, int axis) const {
    if (axis < 0 || axis >= AXIS_COUNT) return 0;
    if (i >= factions_.size()) return 0;
    const auto &bits = factions_[i].bits;
    if (axis >= static_cast<int>(bits.size())) return 0;
    // Stored as double; threshold at 0.5.
    return bits[static_cast<std::size_t>(axis)] >= 0.5 ? 1 : 0;
}

bool MythosGraphCore::faction_bits_agree_except(std::size_t i, std::size_t j, int axis_skip) const {
    for (int k = 0; k < AXIS_COUNT; ++k) {
        if (k == axis_skip) continue;
        if (faction_bit(i, k) != faction_bit(j, k)) return false;
    }
    return true;
}

void MythosGraphCore::faction_scale_row_col(std::size_t i, double s) {
    const std::size_t n = faction_density_.rows();
    for (std::size_t k = 0; k < n; ++k) {
        if (k == i) continue;
        faction_density_(i, k) *= s;
        faction_density_(k, i) *= s;
    }
}

void MythosGraphCore::faction_scale_off_diagonals_excluding(std::size_t i, double s) {
    const std::size_t n = faction_density_.rows();
    for (std::size_t a = 0; a < n; ++a) {
        if (a == i) continue;
        for (std::size_t b = 0; b < n; ++b) {
            if (b == i || b == a) continue;
            faction_density_(a, b) *= s;
        }
    }
}

void MythosGraphCore::faction_initialize_uniform() {
    initialize_faction_density_uniform();
}

void MythosGraphCore::faction_renormalize_trace() {
    if (factions_.empty() || faction_density_.empty()) return;
    double total = 0.0;
    const std::size_t n = faction_density_.rows();
    for (std::size_t i = 0; i < n; ++i) {
        total += faction_density_(i, i).real();
    }
    if (total <= 0.0) {
        initialize_faction_density_uniform();
        return;
    }
    const double s = 1.0 / total;
    for (std::size_t i = 0; i < n; ++i) {
        for (std::size_t j = 0; j < n; ++j) {
            faction_density_(i, j) *= s;
        }
    }
}

void MythosGraphCore::faction_pump(const std::string &name, double rate) {
    const int idx_signed = faction_index(name);
    if (idx_signed < 0 || rate == 0.0 || faction_density_.empty()) return;
    const std::size_t i = static_cast<std::size_t>(idx_signed);
    const std::size_t n = faction_density_.rows();

    double delta = DEFAULT_PUMP_SCALE * rate;
    if (delta > 1.0) delta = 1.0;
    if (delta < -1.0) delta = -1.0;

    const double current = faction_density_(i, i).real();
    const double others_sum = 1.0 - current;
    double new_i = current;
    double diag_scale = 1.0;

    if (delta > 0.0) {
        if (others_sum <= 0.0) return;
        const double take = std::min(delta, others_sum);
        new_i = current + take;
        diag_scale = (others_sum - take) / others_sum;
    } else {
        const double give = std::min(-delta, current);
        new_i = current - give;
        if (others_sum <= 0.0) {
            if (n <= 1) return;
            const double share = give / static_cast<double>(n - 1);
            faction_density_(i, i) = Complex(new_i, 0.0);
            for (std::size_t k = 0; k < n; ++k) {
                if (k != i) {
                    faction_density_(k, k) += Complex(share, 0.0);
                }
            }
            const double safe_current = std::max(current, 1e-12);
            faction_scale_row_col(i, std::sqrt(std::max(new_i / safe_current, 0.0)));
            return;
        }
        diag_scale = (others_sum + give) / others_sum;
    }

    faction_density_(i, i) = Complex(new_i, 0.0);
    for (std::size_t k = 0; k < n; ++k) {
        if (k != i) {
            faction_density_(k, k) *= diag_scale;
        }
    }
    const double safe_current = std::max(current, 1e-12);
    const double row_scale = std::sqrt(std::max(new_i / safe_current, 0.0)) * std::sqrt(std::max(diag_scale, 0.0));
    faction_scale_row_col(i, row_scale);
    const double other_scale = std::sqrt(std::max(diag_scale, 0.0));
    faction_scale_off_diagonals_excluding(i, other_scale);
}

void MythosGraphCore::faction_kick_coherence(const std::string &name_a, const std::string &name_b, double re, double im) {
    const int ia = faction_index(name_a);
    const int ib = faction_index(name_b);
    if (ia < 0 || ib < 0 || ia == ib || (re == 0.0 && im == 0.0) || faction_density_.empty()) return;
    const std::size_t i = static_cast<std::size_t>(ia);
    const std::size_t j = static_cast<std::size_t>(ib);

    const double dre = DEFAULT_COHERENCE_SCALE * re;
    const double dim = DEFAULT_COHERENCE_SCALE * im;
    Complex curr = faction_density_(i, j);
    double new_re = curr.real() + dre;
    double new_im = curr.imag() + dim;
    const double max_mag = std::sqrt(std::max(faction_density_(i, i).real(), 0.0) *
                                      std::max(faction_density_(j, j).real(), 0.0));
    const double mag = std::sqrt(new_re * new_re + new_im * new_im);
    if (mag > max_mag && mag > 0.0) {
        const double k = max_mag / mag;
        new_re *= k;
        new_im *= k;
    }
    faction_density_(i, j) = Complex(new_re, new_im);
    faction_density_(j, i) = Complex(new_re, -new_im);
}

void MythosGraphCore::faction_apply_lindblad_decay(double dt, double tau) {
    if (dt <= 0.0 || tau <= 0.0 || faction_density_.empty()) return;
    const std::size_t n = faction_density_.rows();
    if (n <= 1) return;
    const double factor = std::exp(-dt / tau);
    if (factor >= 1.0) return;
    for (std::size_t i = 0; i < n; ++i) {
        for (std::size_t j = 0; j < n; ++j) {
            if (i == j) continue;
            faction_density_(i, j) *= factor;
        }
    }
}

void MythosGraphCore::faction_apply_axis_bias(int axis_i, int bit_b, double strength) {
    if (axis_i < 0 || axis_i >= AXIS_COUNT || faction_density_.empty()) return;
    double alpha = strength;
    if (alpha <= 0.0) return;
    if (alpha > 1.0) alpha = 1.0;
    const double damp = std::sqrt(std::max(1.0 - alpha, 0.0));
    const std::size_t n = faction_density_.rows();
    std::vector<double> d(n, 0.0);
    for (std::size_t k = 0; k < n; ++k) {
        d[k] = (faction_bit(k, axis_i) == bit_b) ? 1.0 : damp;
    }
    for (std::size_t k = 0; k < n; ++k) {
        for (std::size_t l = 0; l < n; ++l) {
            const double s = d[k] * d[l];
            faction_density_(k, l) *= s;
        }
    }
    faction_renormalize_trace();
}

double MythosGraphCore::faction_get_weight(const std::string &name) const {
    const int idx = faction_index(name);
    if (idx < 0 || faction_density_.empty()) return 0.0;
    double v = faction_density_(static_cast<std::size_t>(idx), static_cast<std::size_t>(idx)).real();
    if (v < 0.0) v = 0.0;
    if (v > 1.0) v = 1.0;
    return v;
}

void MythosGraphCore::faction_get_coherence(const std::string &name_a, const std::string &name_b, double &re_out, double &im_out) const {
    re_out = 0.0;
    im_out = 0.0;
    const int ia = faction_index(name_a);
    const int ib = faction_index(name_b);
    if (ia < 0 || ib < 0 || faction_density_.empty()) return;
    const Complex c = faction_density_(static_cast<std::size_t>(ia), static_cast<std::size_t>(ib));
    re_out = c.real();
    im_out = c.imag();
}

void MythosGraphCore::faction_partial_trace_axis(int axis_i, double &r00_out, double &r11_out, double &r01_re_out, double &r01_im_out) const {
    r00_out = 0.0; r11_out = 0.0; r01_re_out = 0.0; r01_im_out = 0.0;
    if (axis_i < 0 || axis_i >= AXIS_COUNT || faction_density_.empty()) {
        r00_out = 0.5; r11_out = 0.5;
        return;
    }
    const std::size_t n = faction_density_.rows();
    for (std::size_t i = 0; i < n; ++i) {
        const int bi = faction_bit(i, axis_i);
        for (std::size_t j = 0; j < n; ++j) {
            if (!faction_bits_agree_except(i, j, axis_i)) continue;
            const int bj = faction_bit(j, axis_i);
            const Complex c = faction_density_(i, j);
            if (bi == 0 && bj == 0) {
                r00_out += c.real();
            } else if (bi == 1 && bj == 1) {
                r11_out += c.real();
            } else if (bi == 0 && bj == 1) {
                r01_re_out += c.real();
                r01_im_out += c.imag();
            }
        }
    }
}

int MythosGraphCore::faction_hamming_distance(const std::string &name_a, const std::string &name_b) const {
    const int ia = faction_index(name_a);
    const int ib = faction_index(name_b);
    if (ia < 0 || ib < 0) return -1;
    int d = 0;
    for (int k = 0; k < AXIS_COUNT; ++k) {
        if (faction_bit(static_cast<std::size_t>(ia), k) != faction_bit(static_cast<std::size_t>(ib), k)) {
            d++;
        }
    }
    return d;
}

std::vector<std::string> MythosGraphCore::factions_speaking(const std::string &emoji) const {
    std::vector<std::string> out;
    if (emoji.empty()) return out;
    for (const auto &f : factions_) {
        if (std::find(f.sig.begin(), f.sig.end(), emoji) != f.sig.end()) {
            out.push_back(f.name);
        }
    }
    return out;
}

double MythosGraphCore::faction_affinity_for_emoji(const std::string &emoji) const {
    if (emoji.empty() || faction_density_.empty()) return 0.0;
    double total = 0.0;
    for (std::size_t i = 0; i < factions_.size(); ++i) {
        const auto &f = factions_[i];
        if (std::find(f.sig.begin(), f.sig.end(), emoji) != f.sig.end()) {
            total += faction_density_(i, i).real();
        }
    }
    if (total < 0.0) total = 0.0;
    if (total > 1.0) total = 1.0;
    return total;
}

double MythosGraphCore::faction_purity() const {
    if (faction_density_.empty()) return 0.0;
    const std::size_t n = faction_density_.rows();
    double p = 0.0;
    for (std::size_t i = 0; i < n; ++i) {
        for (std::size_t j = 0; j < n; ++j) {
            const Complex c = faction_density_(i, j);
            p += c.real() * c.real() + c.imag() * c.imag();
        }
    }
    return p;
}

double MythosGraphCore::faction_diagonal_sum() const {
    if (faction_density_.empty()) return 0.0;
    double t = 0.0;
    const std::size_t n = faction_density_.rows();
    for (std::size_t i = 0; i < n; ++i) t += faction_density_(i, i).real();
    return t;
}

void MythosGraphCore::faction_serialize(std::vector<std::string> &names_out, std::vector<double> &data_out) const {
    names_out.clear();
    data_out.clear();
    for (const auto &f : factions_) names_out.push_back(f.name);
    if (faction_density_.empty()) return;
    const std::size_t n = faction_density_.rows();
    data_out.reserve(2 * n * n);
    for (std::size_t i = 0; i < n; ++i) {
        for (std::size_t j = 0; j < n; ++j) {
            const Complex c = faction_density_(i, j);
            data_out.push_back(c.real());
            data_out.push_back(c.imag());
        }
    }
}

void MythosGraphCore::faction_deserialize(const std::vector<std::string> &names_in, const std::vector<double> &data_in) {
    if (factions_.empty()) return;
    initialize_faction_density_uniform();
    for (std::size_t i = 0; i < faction_density_.rows(); ++i) {
        for (std::size_t j = 0; j < faction_density_.rows(); ++j) {
            faction_density_(i, j) = Complex(0.0, 0.0);
        }
    }
    const std::size_t n = names_in.size();
    const std::size_t expected = 2 * n * n;
    if (data_in.size() < expected) {
        initialize_faction_density_uniform();
        return;
    }
    // Map saved indices to current
    std::vector<int> remap(n, -1);
    for (std::size_t si = 0; si < n; ++si) {
        remap[si] = faction_index(names_in[si]);
    }
    for (std::size_t si = 0; si < n; ++si) {
        const int ci = remap[si];
        if (ci < 0) continue;
        for (std::size_t sj = 0; sj < n; ++sj) {
            const int cj = remap[sj];
            if (cj < 0) continue;
            const std::size_t src = 2 * (si * n + sj);
            faction_density_(static_cast<std::size_t>(ci), static_cast<std::size_t>(cj)) =
                Complex(data_in[src], data_in[src + 1]);
        }
    }
    faction_renormalize_trace();
}

bool MythosGraphCore::faction_principal_mode(double &eigenvalue_out, std::vector<double> &amplitudes_out) const {
    eigenvalue_out = 0.0;
    amplitudes_out.clear();
    if (faction_density_.empty() || faction_density_.rows() < 2) {
        return false;
    }
    // ρ is Hermitian PSD with trace 1; SelfAdjointEigenSolver works directly.
    // Eigen returns eigenvalues in ASCENDING order — the dominant mode is the
    // LAST column of eigenvectors.
    EigenResult result = HermitianEigensolver::solve(faction_density_);
    if (!result.eigenvectors_available || result.eigenvalues.empty()) {
        return false;
    }
    const std::size_t n = faction_density_.rows();
    const std::size_t dom_col = result.eigenvalues.size() - 1;
    eigenvalue_out = result.eigenvalues[dom_col];

    amplitudes_out.resize(n, 0.0);
    double total = 0.0;
    for (std::size_t i = 0; i < n; ++i) {
        const Complex z = result.eigenvectors(i, dom_col);
        const double prob = z.real() * z.real() + z.imag() * z.imag();
        amplitudes_out[i] = prob;
        total += prob;
    }
    if (total > 1e-12) {
        const double s = 1.0 / total;
        for (std::size_t i = 0; i < n; ++i) {
            amplitudes_out[i] *= s;
        }
    }
    return true;
}

void MythosGraphCore::faction_principal_axis_projection(std::vector<double> &axes_out) const {
    axes_out.assign(AXIS_COUNT, 0.5);
    double eigenvalue = 0.0;
    std::vector<double> amps;
    if (!faction_principal_mode(eigenvalue, amps)) {
        return;
    }
    // For each axis: sum amplitude * bit. Result in [0, 1] — P(axis=1 | dominant mode).
    for (int axis = 0; axis < AXIS_COUNT; ++axis) {
        double p = 0.0;
        for (std::size_t i = 0; i < amps.size() && i < factions_.size(); ++i) {
            p += amps[i] * static_cast<double>(faction_bit(i, axis));
        }
        axes_out[static_cast<std::size_t>(axis)] = std::max(0.0, std::min(1.0, p));
    }
}

} // namespace spacewheat
