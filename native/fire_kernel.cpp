#include "fire_kernel.h"

#include <algorithm>
#include <cmath>
#include <limits>
#include <numeric>
#include <utility>
#include <vector>

namespace fire {
namespace {

double dot2(double x, double y, double u, double v) {
    return float(x) * float(u) + float(y) * float(v);
}

void score_slope(const double *samples, std::size_t count, double desired, double balance,
                 double span, double slope, double &best, double *out) {
    double bottom = 0.0;
    for (std::size_t i = 0; i < count; ++i) {
        bottom = std::max(bottom, samples[2 * i + 1] - samples[2 * i] * slope);
    }
    double first = std::numeric_limits<double>::infinity();
    double last = -first;
    for (std::size_t i = 0; i < count; ++i) {
        const double offset = samples[2 * i];
        if (bottom + offset * slope - samples[2 * i + 1] <= 0.016) {
            first = std::min(first, offset);
            last = std::max(last, offset);
        }
    }
    const double overhang = std::max(0.0, std::max(first - balance, balance - last) - span * 0.15);
    const double score = std::abs(slope - desired) + bottom * 0.18 + overhang * 100.0;
    if (score < best) {
        best = score;
        out[0] = slope;
        out[1] = bottom;
    }
}

} // namespace

std::size_t exchange_output_size(std::size_t node_values, std::size_t link_values) {
    if (node_values % node_width || link_values % link_width) {
        return 0;
    }
    return node_values / node_width * reading_width + 1;
}

bool exchange(const double *nodes, std::size_t node_values, const double *links,
              std::size_t link_values, double *out) {
    const auto count = node_values / node_width;
    const auto output_size = exchange_output_size(node_values, link_values);
    if (!output_size) {
        return false;
    }
    std::fill_n(out, output_size, 0.0);
    for (std::size_t index = 0; index < link_values; index += link_width) {
        const auto *link = links + index;
        if (!(link[first] >= 0 && link[second] > link[first] && link[second] < static_cast<double>(count) &&
              (link[coal] == -1 || link[coal] == link[first] || link[coal] == link[second]))) {
            return false;
        }
        const auto i = static_cast<std::size_t>(link[first]);
        const auto j = static_cast<std::size_t>(link[second]);
        const auto *a = nodes + i * node_width;
        const auto *b = nodes + j * node_width;
        auto *to_a = out + i * reading_width;
        auto *to_b = out + j * reading_width;
        const double insulated = a[insulation] * b[insulation];

        const double effective_capacity = a[fibre] && b[fibre]
            ? a[capacity] * b[capacity] / fibre_capacity : std::min(a[capacity], b[capacity]);
        double transfer = link[conductance] * insulated * effective_capacity;
        if (link[coal] >= 0) {
            const bool coal_first = link[coal] == link[first];
            const auto *source = coal_first ? a : b;
            auto *receiver = coal_first ? to_b : to_a;
            if (source[breath_strength] > 0.0) {
                const double aligned = dot2(source[breath_x], source[breath_y], link[toward_x], link[toward_y]);
                transfer *= 1.0 + source[breath_strength] * (0.28 + 0.72 * std::max(0.0, aligned));
            }
            if (link[ember_feedback] > 0.0) {
                receiver[plume] += source[ember_power] * link[ember_feedback] * insulated;
            }
        }
        const double heat = transfer * (b[temperature] - a[temperature]);
        to_a[conduction] += heat;
        to_b[conduction] -= heat;
        if (link[bed_overlap] > 0.0) {
            to_a[bed_shelter] += b[char_mass] * link[bed_overlap];
            to_b[bed_shelter] += a[char_mass] * link[bed_overlap];
        }
        if (a[flame_power] > 0.0) {
            const double lean = dot2(link[delta_x], link[delta_y], a[wind_x], a[wind_y]) * 0.18;
            to_b[plume] += a[flame_power] * std::max(0.0, link[proximity] + lean) * link[receive_second] * insulated;
        }
        if (b[flame_power] > 0.0) {
            const double lean = dot2(link[delta_x], link[delta_y], b[wind_x], b[wind_y]) * 0.18;
            to_a[plume] += b[flame_power] * std::max(0.0, link[proximity] - lean) * link[receive_first] * insulated;
        }
        if ((link[view_first] > 0.0 || link[view_second] > 0.0) &&
            (a[radiant_power] != 0.0 || b[radiant_power] != 0.0)) {
            const double from_a = a[radiant_power] * link[view_first] * b[insulation];
            const double from_b = b[radiant_power] * link[view_second] * a[insulation];
            to_a[radiation] += from_b;
            to_b[radiation] += from_a;
            out[output_size - 1] += from_a + from_b;
        }
    }
    return true;
}

bool fit(const double *samples, std::size_t values, double desired, double balance,
         double span, double *out) {
    if (values < 2 || values % 2) {
        return false;
    }
    constexpr double limit = 1.45;
    const auto count = values / 2;
    double best = std::numeric_limits<double>::infinity();
    out[0] = out[1] = 0.0;
    for (const double slope : {desired, 0.0, -limit, limit}) {
        score_slope(samples, count, desired, balance, span, slope, best, out);
    }
    for (std::size_t left = 0; left + 1 < count && samples[2 * left] <= balance; ++left) {
        for (std::size_t right = left + 1; right < count; ++right) {
            if (samples[2 * right] < balance) {
                continue;
            }
            const double slope = (samples[2 * right + 1] - samples[2 * left + 1]) /
                (samples[2 * right] - samples[2 * left]);
            if (std::abs(slope) <= limit) {
                score_slope(samples, count, desired, balance, span, slope, best, out);
            }
        }
    }
    return true;
}

bool support_floors(const double *samples, std::size_t values, const double *supports,
                    std::size_t support_values, double *out) {
    constexpr std::size_t sample_width = 6, support_width = 9;
    if (values % sample_width) {
        return false;
    }
    const auto count = values / sample_width;
    for (std::size_t i = 0; i < count; ++i) {
        out[2 * i] = samples[i * sample_width + 3];
        out[2 * i + 1] = samples[i * sample_width + 4];
    }
    for (std::size_t k = 0; k < support_values;) {
        if (support_values - k < support_width + 2) {
            return false;
        }
        const double *piece = supports + k;
        if (!(piece[8] >= 1 && piece[8] <= (support_values - k - support_width) / 2 &&
              std::isfinite(piece[5]) && piece[5] >= 0.0)) {
            return false;
        }
        const auto sections = static_cast<std::size_t>(piece[8]);
        if (piece[5] == 0.0 && sections > 1) {
            return false;
        }
        k += support_width + sections * 2;
        const float x = piece[1], y = piece[2], ax = piece[3], ay = piece[4];
        const double span = piece[5], height = piece[6], slope = piece[7];
        for (std::size_t i = 0; i < count; ++i) {
            const auto *sample = samples + i * sample_width;
            const float sx = sample[0], sy = sample[1];
            const double along = std::clamp(dot2(sx - x, sy - y, ax, ay), -span, span);
            const auto section = sections == 1 ? 0 : static_cast<std::size_t>(
                (std::clamp(along / span, -1.0, 0.999999) + 1.0) * 0.5 * sections);
            const double crown = piece[support_width + section * 2];
            if (!piece[support_width + section * 2 + 1]) {
                continue;
            }
            const double width = sample[2] + crown;
            const float dx = sx - (x + ax * float(along));
            const float dy = sy - (y + ay * float(along));
            const double gap = std::sqrt(dx * dx + dy * dy);
            if (gap > width * 0.91) {
                continue;
            }
            double top = height + slope * along + crown;
            const double ratio = gap / width;
            top -= crown * 0.55 * (ratio * ratio);
            if (!(top + sample[2] > sample[5]) && top > out[2 * i]) {
                out[2 * i] = top;
                out[2 * i + 1] = piece[0];
            }
        }
    }
    return true;
}

bool candidate_pairs(const double *geometry, std::size_t values, double *out,
                     std::size_t &output_size) {
    constexpr std::size_t width = 6;
    if (values % width) {
        return false;
    }
    const std::size_t count = values / width;
    std::vector<std::size_t> by_x(count);
    std::iota(by_x.begin(), by_x.end(), 0);
    std::sort(by_x.begin(), by_x.end(), [&](auto a, auto b) { return geometry[a * width] < geometry[b * width]; });
    std::vector<std::pair<std::size_t, std::size_t>> pairs;
    double largest = 0.0;
    for (std::size_t i = 0; i < count; ++i) {
        largest = std::max(largest, geometry[i * width + 3]);
    }
    for (std::size_t left = 0; left < count; ++left) {
        const auto i = by_x[left];
        const auto *a = geometry + i * width;
        const double bound = std::max(0.36, a[3] + largest + 0.17) + 0.00001;
        for (std::size_t right = left + 1; right < count; ++right) {
            const auto j = by_x[right];
            const auto *b = geometry + j * width;
            const double dx = b[0] - a[0];
            if (dx > bound) {
                break;
            }
            if ((a[4] != 0 && a[4] == b[4]) || std::abs(a[2] - b[2]) > 0.83) {
                continue;
            }
            const double reach = (a[5] < 0 && b[5] < 0 ? 0.36 : a[3] + b[3] + 0.17) + 0.00001;
            const double dy = b[1] - a[1];
            if (dx <= reach && std::abs(dy) <= reach && dot2(dx, dy, dx, dy) <= reach * reach) {
                pairs.emplace_back(std::min(i, j), std::max(i, j));
            }
        }
    }
    std::sort(pairs.begin(), pairs.end());
    output_size = 0;
    for (const auto &pair : pairs) {
        out[output_size++] = static_cast<double>(pair.first);
        out[output_size++] = static_cast<double>(pair.second);
    }
    return true;
}

} // namespace fire
