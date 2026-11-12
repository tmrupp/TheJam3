#ifndef FAST_WFC_PORTABLE_HPP_
#define FAST_WFC_PORTABLE_HPP_

#include <cmath>
#include <random>

/**
 * The collapse's maths, made the same on every compiler and system
 * (docs/CODE_REVIEW.md 2.4). A level is laid out from its seed alone, and must
 * be the same level wherever the game is built. The maths library's log and
 * the standard library's uniform_real_distribution are not: each library
 * rounds, or draws, in its own way. These use only what IEEE 754 fixes exactly
 * (+, -, *, / on doubles, and frexp, which only takes a number apart), in a
 * fixed order, and the one generator the standard does fix (minstd_rand).
 * Build without fused multiply-add contraction (SConstruct: -ffp-contract=off),
 * which would round a * b + c once instead of twice.
 */
namespace portable {

/**
 * The natural logarithm of x (x > 0): x = m * 2^e with m in [sqrt(1/2),
 * sqrt(2)), log(m) = 2 * atanh((m - 1) / (m + 1)) by its series, a fixed
 * number of terms summed smallest first.
 */
inline double log(double x) noexcept {
  int e = 0;
  double m = std::frexp(x, &e); // m in [0.5, 1), exactly.
  if (m < 0.70710678118654752440) {
    m = m * 2.0;
    e -= 1;
  }
  const double s = (m - 1.0) / (m + 1.0);
  const double s2 = s * s;
  // |s| <= 0.1716, so s2 <= 0.0295: 13 terms are past a double's precision.
  double sum = 0.0;
  for (int k = 12; k >= 0; k--) {
    sum = sum * s2;
    sum = sum + 1.0 / static_cast<double>(2 * k + 1);
  }
  const double log_m = 2.0 * s * sum;
  return static_cast<double>(e) * 0.69314718055994530942 + log_m;
}

/**
 * A number in [0, top), drawn from gen with one draw: minstd_rand gives
 * 1 .. 2^31 - 2, every library alike.
 */
inline double uniform(std::minstd_rand &gen, double top) noexcept {
  const double unit = static_cast<double>(gen() - 1u) / 2147483646.0;
  return unit * top;
}

} // namespace portable

#endif // FAST_WFC_PORTABLE_HPP_
