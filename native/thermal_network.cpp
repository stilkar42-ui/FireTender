#include "fire_kernel.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <utility>
#include <vector>

namespace fire {
namespace {

// Keep vector operations rounded like a standard-precision Godot build.
struct Vec {
    float x, y, z;
    Vec operator+(Vec b) const { return {x + b.x, y + b.y, z + b.z}; }
    Vec operator-(Vec b) const { return {x - b.x, y - b.y, z - b.z}; }
    Vec operator-() const { return {-x, -y, -z}; }
    Vec operator*(float scale) const { return {x * scale, y * scale, z * scale}; }
    Vec operator/(float scale) const { return {x / scale, y / scale, z / scale}; }
    float dot(Vec b) const { return x * b.x + y * b.y + z * b.z; }
    float length_squared() const { return dot(*this); }
    float length() const { return std::sqrt(length_squared()); }
    Vec normalized() const {
        const float len = length();
        return len == 0.0f ? Vec{} : *this / len;
    }
    Vec min(Vec b) const { return {std::min(x, b.x), std::min(y, b.y), std::min(z, b.z)}; }
    Vec max(Vec b) const { return {std::max(x, b.x), std::max(y, b.y), std::max(z, b.z)}; }
    Vec abs() const { return {std::abs(x), std::abs(y), std::abs(z)}; }
};

Vec vector(const double *row) { return {float(row[0]), float(row[1]), float(row[2])}; }

double smooth(double low, double high, double value) {
    const double t = std::clamp((value - low) / (high - low), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// Segment solver adapted from Godot 4.7.2, core/math/geometry_3d.cpp.
// Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
// Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
// CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
// TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
// SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
std::pair<Vec, Vec> closest(Vec p0, Vec p1, Vec q0, Vec q1) {
    const Vec p = p1 - p0, q = q1 - q0, r = p0 - q0;
    const float a = p.dot(p), b = p.dot(q), c = q.dot(q), d = p.dot(r), e = q.dot(r);
    const float det = a * c - b * b;
    const auto edge = [](float numerator, float denominator) {
        if (numerator <= 0.0f) return 0.0f;
        return numerator >= denominator ? 1.0f : numerator / denominator;
    };
    float s = 0.0f, t = 0.0f;
    if (det <= 0.00001 || b * e <= c * d) {
        if (e <= 0.0f) {
            s = edge(-d, a);
        } else if (e >= c) {
            s = edge(b - d, a);
            t = 1.0f;
        } else {
            t = e / c;
        }
    } else if (b * e - c * d >= det) {
        if (b + e <= 0.0f) {
            s = edge(-d, a);
        } else if (b + e >= c) {
            s = edge(b - d, a);
            t = 1.0f;
        } else {
            s = 1.0f;
            t = (b + e) / c;
        }
    } else if (a * e <= b * d) {
        s = edge(-d, a);
    } else if (a * e - b * d >= det) {
        s = edge(b - d, a);
        t = 1.0f;
    } else {
        s = (b * e - c * d) / det;
        t = (a * e - b * d) / det;
    }
    return {p0 * (1 - s) + p1 * s, q0 * (1 - t) + q1 * t};
}

struct Node {
    const double *row;
    Vec center, axis, start, end;
    double span;
    double ventilation = 0.0;
    double operator[](GeometryField field) const { return field == passage ? ventilation : row[field]; }
    bool ember() const { return row[kind] < 0; }
    bool layered() const { return row[layer] != 0; }
};

struct Blocker {
    double id, radius, span, height;
    Vec center, axis, start, end, low, high;
    bool airflow, seated;
};

int cell(float coord) { return int(std::floor(double(coord) / 0.25)); }

std::uint64_t cell_key(int x, int z) {
    return (std::uint64_t(std::uint32_t(x)) << 32) | std::uint32_t(z);
}

struct Occlusion {
    std::vector<Blocker> blockers;
    std::unordered_map<std::uint64_t, std::vector<std::size_t>> cells;
    std::vector<std::uint32_t> seen;
    std::uint32_t ray = 0;

    explicit Occlusion(const double *rows, std::size_t count) : seen(count, 0) {
        blockers.reserve(count);
        for (std::size_t i = 0; i < count; ++i) {
            const auto *r = rows + i * occluder_width;
            const Vec center = vector(r + 1), axis = vector(r + 4);
            const float margin = float(r[7] + 0.0121);
            const Vec extent = axis.abs() + Vec{margin, margin, margin};
            const Vec low = center - extent, high = center + extent;
            blockers.push_back({r[0], r[7], std::max(0.0001, double(axis.length_squared())), r[2],
                center, axis, center - axis, center + axis, low, high, r[8] != 0, r[9] != 0});
            if (r[7] < 0.014 || (r[7] < 0.025 && r[8] == 0)) continue;
            for (int x = cell(low.x); x <= cell(high.x); ++x) {
                for (int z = cell(low.z); z <= cell(high.z); ++z) {
                    cells[cell_key(x, z)].push_back(i);
                }
            }
        }
    }

    double visibility(const Node &a, const Node &b, Vec direction) const {
        if (double(direction.length_squared()) < 0.012) return 1.0;
        const Vec middle = a.center + direction * 0.5f;
        const auto list = cells.find(cell_key(cell(middle.x), cell(middle.z)));
        if (list == cells.end()) return 1.0;
        for (const auto i : list->second) {
            const auto &blocker = blockers[i];
            if (blocker.radius < 0.025 || blocker.id == a[id] || blocker.id == b[id] ||
                    blocker.id == a[owner] || blocker.id == b[owner]) continue;
            const Vec offset = middle - blocker.center;
            const Vec across = offset - blocker.axis * float(std::clamp(offset.dot(blocker.axis) / blocker.span, -1.0, 1.0));
            if (across.length_squared() < blocker.radius * blocker.radius) return 0.16;
        }
        return 1.0;
    }

    bool open(Vec from, Vec to, const Node &a, const Node *b, double minimum_radius, double margin = 0.0) {
        const Vec low = from.min(to), high = from.max(to);
        ++ray; // Bounded by the input pair count.
        for (int x = cell(low.x); x <= cell(high.x); ++x) {
            for (int z = cell(low.z); z <= cell(high.z); ++z) {
                const auto list = cells.find(cell_key(x, z));
                if (list == cells.end()) continue;
                for (const auto i : list->second) {
                    if (seen[i] == ray) continue;
                    seen[i] = ray;
                    const auto &blocker = blockers[i];
                    if (!blocker.airflow || blocker.radius < minimum_radius ||
                            blocker.low.x > high.x || blocker.low.y > high.y || blocker.low.z > high.z ||
                            blocker.high.x < low.x || blocker.high.y < low.y || blocker.high.z < low.z ||
                            blocker.id == a[owner] || blocker.id == a[id] ||
                            (b && (blocker.id == (*b)[owner] || blocker.id == (*b)[id]))) continue;
                    const auto points = closest(from, to, blocker.start, blocker.end);
                    const double radius = blocker.radius + margin;
                    if ((points.first - points.second).length_squared() < radius * radius) return false;
                }
            }
        }
        return true;
    }

    double starter_passage(const Node &node) {
        bool low = false, high = false;
        for (const auto &timber : blockers) {
            const float dx = timber.center.x - node.center.x, dz = timber.center.z - node.center.z;
            if (!timber.seated || timber.radius < 0.033 || double(dx * dx + dz * dz) > 0.20) continue;
            low |= timber.height <= 0.116;
            high |= timber.height > 0.116;
            if (low && high) break;
        }
        if (!low || !high) return 0.0;
        const Vec origin{node.center.x, float(std::min(0.055, node[height] + 0.023)), node.center.z};
        double inlets = 0.0, outlets = 0.0;
        for (int i = 0; i < 8; ++i) {
            constexpr double tau = 6.28318530717958647692;
            const float angle = float(tau * i / 8.0);
            const Vec reach = Vec{std::cos(angle), 0.045f, std::sin(angle)} * 0.41f;
            if (open(origin, origin + reach, node, nullptr, 0.030, 0.012)) ++inlets;
        }
        for (const Vec offset : {Vec{}, Vec{0.073f, 0, 0}, Vec{-0.073f, 0, 0}, Vec{0, 0, 0.073f}, Vec{0, 0, -0.073f}}) {
            const Vec start = origin + offset;
            if (open(start, start + Vec{0, 0.62f, 0}, node, nullptr, 0.030, 0.008)) ++outlets;
        }
        return smooth(0.0, 2.0, inlets) * smooth(0.5, 3.0, outlets);
    }
};

double plume_reach(double rise) {
    if (rise < 0.0) return 1.0 - 0.80 * smooth(0.08, 0.60, -rise);
    return (1.0 + 0.48 * smooth(0.05, 0.28, rise)) * (1.0 - 0.82 * smooth(0.34, 0.83, rise));
}

double receiving_plume(const Node &source, const Node &target, double offset, double rise,
                       bool geometry, Occlusion &occlusion) {
    double receive = (target.layered() ? 0.0756 * target[fraction] : 0.14) * plume_reach(rise);
    if (!geometry) return receive;
    receive *= 1.72;
    if (source[passage] > 0.0 && offset <= 0.38 && rise <= 0.67 && rise >= -0.06 &&
            occlusion.open(source.center + Vec{0, 0.055f, 0}, target.center + Vec{0, 0.012f, 0},
                source, &target, 0.014)) {
        const double path = 5.0 * (1.0 - smooth(0.095, 0.40, offset)) * (1.0 - smooth(0.32, 0.67, rise));
        receive *= 1.0 + source[passage] * path;
    }
    return receive;
}

void adjust_plume(double &receive, const Node &source, const Node &target, double rise, Occlusion &occlusion) {
    if (source[passage] <= 0.0 || !source[plume_fuel]) return;
    if (!target.ember() && !target[porous] && rise >= -0.04 && rise <= 0.26) {
        const auto near = closest(source.start, source.end, target.start, target.end);
        if (occlusion.open(near.first + Vec{0, 0.025f, 0}, near.second + Vec{0, 0.014f, 0},
                source, &target, 0.031)) {
            receive *= 1.0 + 5.0 * source[passage] * (1.0 - smooth(0.035, 0.18, (near.first - near.second).length()));
        }
    }
    if (source[kind] != 6 && target[layer] < 0 && rise >= 0.015 && rise <= 0.48) {
        const Vec from{source.center.x, 0, source.center.z}, to{target.center.x, 0, target.center.z};
        const Vec a{source.axis.x, 0, source.axis.z}, b{target.axis.x, 0, target.axis.z};
        const auto near = closest(from - a, from + a, to - b, to + b);
        const double path = (1.0 - smooth(0.045, 0.23, (near.first - near.second).length())) *
            (1.0 - smooth(0.26, 0.48, rise));
        receive *= 1.0 + 13.0 * source[passage] * path;
    }
}

double jet(const Node &target, double offset, double rise) {
    if (offset > 0.17 || rise < -0.045 || rise > 0.15) return 0.0;
    return (target[kind] == 6 ? 8.0 : 2.8) * (1.0 - smooth(0.027, 0.17, offset));
}

double facing(const Node &node, float y) {
    if (node.ember()) return 0.28 + 0.72 * std::max(0.0, double(y));
    return node.layered() ? 0.28 + 0.72 * std::max(0.0, y * node[layer]) : 1.0;
}

double raw_view(const Node &source, Vec direction) {
    const Vec near = direction - source.axis * float(std::clamp(direction.dot(source.axis) / source.span, -0.85, 0.85));
    return std::min(source[porous] ? 0.56 * source[original] / source[species_mass] : 0.56,
        source[surface_weight] * 0.52 / (0.010 + near.length_squared()));
}

bool approx(float a, float b) {
    return a == b || std::abs(a - b) < std::max(0.00001f, 0.00001f * std::abs(a));
}

struct Totals {
    double load = 0.0, flame = 0.0, view = 0.0, ember = 0.0, fibre_contact = 0.0;
};

bool valid_geometry(const double *row, std::size_t width) {
    return std::all_of(row, row + width, [](double value) { return std::isfinite(value); });
}

bool inside_grid(double x, double z) {
    // Stay within a bounded grid even when a caller supplies an invalid pose.
    return std::abs(x) <= 16.0 && std::abs(z) <= 16.0;
}

bool accepted_link(const Node &a, const Node &b, std::size_t i, std::size_t j, Occlusion &occlusion,
                   Totals &total_a, Totals &total_b, double &crowd_a, double &crowd_b, double *out) {
    const Vec delta{b.center.x - a.center.x, 0, b.center.z - a.center.z};
    const double distance_sq = delta.length_squared(), distance = std::sqrt(float(distance_sq));
    const double rise = b[height] - a[height], gap = std::abs(rise);
    double reach = a[reach_size] + b[reach_size] + 0.17;
    if (a.ember() && b.ember()) {
        reach = 0.36;
    } else if (distance > 0.0) {
        const Vec heading = delta / float(distance);
        if (a.layered()) reach -= a[reach_size] * 0.12 * std::abs(float(a[axis_x]) * heading.z - float(a[axis_y]) * heading.x);
        if (b.layered()) reach -= b[reach_size] * 0.12 * std::abs(float(b[axis_x]) * heading.z - float(b[axis_y]) * heading.x);
    }
    if (distance >= reach || gap > 0.83 || (a[owner] != 0 && a[owner] == b[owner])) return false;
    const bool geometry = a[precise] || b[precise];
    const bool mixed = a.ember() != b.ember();
    const Node &bed = a.ember() ? a : b;
    const Node &fuel = a.ember() ? b : a;
    Totals &bed_totals = a.ember() ? total_a : total_b;
    const double proximity_value = 1.0 - distance / reach;
    const double contact = proximity_value * proximity_value;
    double conduct = contact * 0.43 / (1.0 + gap * gap * 14.0);
    if (geometry) {
        const auto points = closest(a.start, a.end, b.start, b.end);
        const double touch = (a.ember() ? a[reach_size] * 0.49 : a[radius]) +
            (b.ember() ? b[reach_size] * 0.49 : b[radius]);
        double solid = 1.0 + (0.045 - 1.0) * smooth(touch * 0.76, touch + 0.018, (points.first - points.second).length());
        if (a[porous] && b[porous]) solid = std::max(solid, 0.28 * std::exp(-distance_sq / 0.0072 - gap * gap / 0.0025));
        conduct *= solid;
        if ((a[passage] > 0.0 || b[passage] > 0.0) && (a.ember() || b.ember())) {
            if (bed[original] <= 0.025 && !bed[carried] && !fuel[porous] &&
                    !(approx(bed.center.x, fuel.center.x) && approx(bed.center.z, fuel.center.z))) {
                conduct *= 0.10 + (1.0 - 0.10) * smooth(0.12, 0.83, solid);
            }
        } else if (a[porous] != b[porous] && !a.ember() && !b.ember() &&
                (a[passage] > 0.0 || b[passage] > 0.0 || a[tinder] || b[tinder])) {
            conduct *= smooth(0.11, 0.78, solid);
            if (a[tinder] || b[tinder]) conduct *= 0.30;
        }
    }
    if (a.ember() || b.ember()) {
        const double layers = a[layer] + b[layer];
        conduct *= layers > 0 ? 0.12 : (layers < 0 ? 1.22 : 1.0);
        if (mixed && geometry && fuel.layered()) {
            conduct *= 1.0 + (0.095 - 1.0) * smooth(0.018, 0.061, bed[carbon]);
        }
    } else if (a.layered() && b.layered()) {
        conduct *= a[layer] != b[layer] ? 0.75 : 0.25;
    } else if (a.layered() || b.layered()) {
        conduct *= 0.52;
    }

    const double limit = conduct * (mixed ? 2.0 : 1.0);
    if (a[porous] || b[porous]) {
        const double effective = a[porous] && b[porous] ? a[heat_capacity] * b[heat_capacity] / fibre_capacity
            : std::min(a[heat_capacity], b[heat_capacity]);
        total_a.load += limit * effective / a[heat_capacity];
        total_b.load += limit * effective / b[heat_capacity];
        if (mixed) bed_totals.fibre_contact += conduct * effective;
    } else {
        total_a.load += limit;
        total_b.load += limit;
    }

    double receive_a = receiving_plume(b, a, distance, -rise, geometry, occlusion);
    double receive_b = receiving_plume(a, b, distance, rise, geometry, occlusion);
    if (geometry) {
        if ((a[tinder] || (a[porous] && a[passage] > 0.5)) && b[jet_target]) {
            receive_b *= 1.0 + jet(b, distance, rise);
        } else if ((b[tinder] || (b[porous] && b[passage] > 0.5)) && a[jet_target]) {
            receive_a *= 1.0 + jet(a, distance, -rise);
        }
        adjust_plume(receive_b, a, b, rise, occlusion);
        adjust_plume(receive_a, b, a, -rise, occlusion);
    }
    if (a[porous]) receive_a *= std::min(3.0, a[original] / a[species_mass]);
    if (b[porous]) receive_b *= std::min(3.0, b[original] / b[species_mass]);

    double feedback = 0.0;
    Vec toward{};
    if (mixed) {
        toward = a.ember() ? delta.normalized() : -delta.normalized();
        double receiving_area = (0.35 + fuel[reach_size] * 4.0) * fuel[area_scale];
        if (fuel.layered()) receiving_area *= fuel[fraction] * (fuel[layer] < 0 ? 0.57 : 0.14);
        if (fuel[porous]) receiving_area *= fuel[original] / fuel[species_mass];
        feedback = 0.34 * receiving_area * contact * (1.0 - smooth(0.08, 0.37, gap));
        if (bed[original] <= 0.025 && fuel[porous] && bed[passage] > 0.0) {
            feedback += bed[passage] * (fuel[original] / fuel[species_mass]) * contact * (1.0 - smooth(0.025, 0.095, gap));
        }
        if (geometry && fuel[layer] < 0) {
            const double lift = fuel[height] - bed[height];
            feedback *= 1.0 + 11.0 * smooth(0.04, 0.11, lift) * (1.0 - smooth(0.24, 0.47, lift));
        }
        bed_totals.ember += feedback;
    }

    double view_a = 0.0, view_b = 0.0;
    const Vec direction = b.center - a.center;
    if (double(direction.length_squared()) > 0.00000001) {
        const double visible = geometry ? occlusion.visibility(a, b, direction) : 0.20;
        const float y = direction.normalized().y;
        const double facing_a = facing(a, -y), facing_b = facing(b, y);
        view_a = raw_view(a, direction) * visible * facing_b * facing_a;
        view_b = raw_view(b, -direction) * visible * facing_a * facing_b;
        total_a.view += view_a;
        total_b.view += view_b;
    }
    const double plume = proximity_value + distance * 0.324;
    total_a.flame += plume * receive_b;
    total_b.flame += plume * receive_a;
    const double parallel = !a.ember() && !b.ember()
        ? 1.0 - std::abs(float(a[axis_x]) * float(b[axis_y]) - float(a[axis_y]) * float(b[axis_x])) * 0.38 : 1.0;
    const double shield = contact * parallel * (1.0 - smooth(0.18, 0.56, gap));
    if (!b.ember() && !b[porous]) crowd_a += shield * b[reach_size] * b[fraction] * (b.layered() ? 1.75 : 3.5);
    if (!a.ember() && !a[porous]) crowd_b += shield * a[reach_size] * a[fraction] * (a.layered() ? 1.75 : 3.5);
    if (geometry && !a.ember() && !b.ember() && !a[porous] && !b[porous] && !a.layered() && !b.layered()) {
        const double overlap = 0.72 * std::exp(-distance_sq / 0.006 - gap * gap / 0.021);
        crowd_a += overlap;
        crowd_b += overlap;
    }

    const double row[] = {double(i), double(j), conduct, proximity_value, delta.x, delta.z, receive_a, receive_b,
        mixed ? double(a.ember() ? i : j) : -1.0, toward.x, toward.z, feedback, view_a, view_b, 0.0};
    std::copy_n(row, link_width, out);
    return true;
}

} // namespace

bool build_network(const double *geometry, std::size_t values, const double *occluders,
                   std::size_t occluder_values, const double *pairs, std::size_t pair_values,
                   double *out, std::size_t &output_size) {
    if (values % geometry_width || occluder_values % occluder_width || pair_values % 2) return false;
    const std::size_t count = values / geometry_width;
    std::vector<Node> nodes;
    nodes.reserve(count);
    for (std::size_t i = 0; i < count; ++i) {
        const auto *row = geometry + i * geometry_width;
        if (!valid_geometry(row, geometry_width) || !inside_grid(row[plan_x], row[plan_y]) ||
                !inside_grid(row[heat_x], row[heat_z])) return false;
        const Vec center{float(row[plan_x]), float(row[height]), float(row[plan_y])};
        const Vec axis = vector(row + heat_x);
        nodes.push_back({row, center, axis, center - axis, center + axis, std::max(0.0001, double(axis.length_squared()))});
    }
    for (std::size_t i = 0; i < occluder_values; i += occluder_width) {
        const auto *row = occluders + i;
        if (!valid_geometry(row, occluder_width) || !inside_grid(row[1], row[3]) ||
                !inside_grid(row[4], row[6]) || !(row[7] >= 0.0 && row[7] <= 4.0)) return false;
    }
    Occlusion occlusion(occluders, occluder_values / occluder_width);
    std::vector<Totals> totals(count);
    std::fill_n(out, 1 + 2 * count, 0.0);
    auto *crowding = out + 1;
    auto *ventilation = crowding + count;
    auto *links = ventilation + count;
    for (std::size_t i = 0; i < count; ++i) {
        if (nodes[i].row[passage]) nodes[i].ventilation = occlusion.starter_passage(nodes[i]);
        ventilation[i] = nodes[i].ventilation;
    }
    std::size_t accepted = 0;
    for (std::size_t k = 0; k < pair_values; k += 2) {
        if (!(pairs[k] >= 0 && pairs[k + 1] > pairs[k] && pairs[k + 1] < double(count) &&
                pairs[k] == std::floor(pairs[k]) && pairs[k + 1] == std::floor(pairs[k + 1]))) return false;
        const auto i = std::size_t(pairs[k]), j = std::size_t(pairs[k + 1]);
        if (accepted_link(nodes[i], nodes[j], i, j, occlusion, totals[i], totals[j],
                crowding[i], crowding[j], links + accepted * link_width)) {
            ++accepted;
        }
    }
    for (std::size_t k = 0; k < accepted; ++k) {
        auto *link = links + k * link_width;
        const auto i = std::size_t(link[first]), j = std::size_t(link[second]);
        link[conductance] /= std::max(1.0, 0.5 * std::max(totals[i].load, totals[j].load));
        if (link[coal] >= 0) {
            const auto bed = std::size_t(link[coal]);
            if (nodes[i][porous] || nodes[j][porous]) {
                link[conductance] /= std::max(1.0, totals[bed].fibre_contact / (nodes[bed][heat_capacity] * 0.31));
            }
            if (link[ember_feedback] > 0.0) link[ember_feedback] /= std::max(1.0, totals[bed].ember / 0.48);
        }
        link[view_first] /= std::max(1.0, totals[i].view / 0.70);
        link[view_second] /= std::max(1.0, totals[j].view / 0.70);
        if (link[view_first] > 0.0 || link[view_second] > 0.0) ++out[0];
        link[receive_first] /= std::max(1.0, totals[j].flame / (nodes[j][tinder] ? 0.69 : 0.55));
        link[receive_second] /= std::max(1.0, totals[i].flame / (nodes[i][tinder] ? 0.69 : 0.55));
    }
    for (std::size_t i = 0; i < count; ++i) crowding[i] *= 1.0 + (0.25 - 1.0) * nodes[i][passage];
    output_size = 1 + 2 * count + accepted * link_width;
    return true;
}

} // namespace fire
