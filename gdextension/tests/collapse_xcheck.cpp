// Runs the collapse on real samples over many seeds and prints a hash of each result: built with
// two compilers, the two outputs must be the same line for line.
#include "overlapping_wfc.hpp"
#include "utils/array2D.hpp"
#include <cstdint>
#include <cstdio>
#include <fstream>
#include <string>

int main(int argc, char **argv) {
  const char *names[] = {"levelSample3-spikes", "crags", "institute", "crypt_crawl"};
  for (const char *name : names) {
    std::ifstream in(std::string(argv[1]) + "/" + name + ".txt");
    if (!in) { continue; }
    unsigned W, H;
    in >> W >> H;
    Array2D<int32_t> m(W, H);
    for (unsigned i = 0; i < m.height; i++) {
      for (unsigned j = 0; j < m.width; j++) {
        uint32_t v;
        in >> v;
        m.get(i, j) = (int32_t)v;
      }
    }
    const unsigned masks[] = {0u, 33u};
    for (unsigned mask : masks) {
      for (int seed = 1; seed <= 40; seed++) {
        OverlappingWFCOptions options = {false, false, 48u, 40u, 5u, false, 3u, mask};
        OverlappingWFC<int32_t> wfc(m, options, seed * 7919 + 13);
        std::optional<Array2D<int32_t>> out = wfc.run();
        uint64_t h = 1469598103934665603ull;
        if (out.has_value()) {
          for (int32_t c : out->data) {
            h = (h ^ (uint32_t)c) * 1099511628211ull;
          }
        }
        std::printf("%s mask %u seed %d: %s %016llx\n", name, mask, seed, out.has_value() ? "settled" : "failed", (unsigned long long)h);
      }
    }
  }
  return 0;
}
