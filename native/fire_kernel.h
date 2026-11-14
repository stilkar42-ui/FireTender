#pragma once

#include <cstddef>

namespace fire {

// The bridge and GDScript pack rows in this order. All accumulator fields
// use binary64. Dot products of Godot Vector2 values use binary32.
enum NodeField {
    temperature, capacity, insulation, flame_power, radiant_power, ember_power,
    char_mass, wind_x, wind_y, breath_x, breath_y, breath_strength, fibre, node_width
};

enum LinkField {
    first, second, conductance, proximity, delta_x, delta_y, receive_first, receive_second,
    coal, toward_x, toward_y, ember_feedback, view_first, view_second, bed_overlap, link_width
};

enum Reading { conduction, plume, radiation, bed_shelter, reading_width };

constexpr double fibre_capacity = 0.0065;

std::size_t exchange_output_size(std::size_t node_values, std::size_t link_values);
bool exchange(const double *nodes, std::size_t node_values, const double *links,
              std::size_t link_values, double *out);

// Each support sample contains an axis offset and the minimum centre height.
bool fit(const double *samples, std::size_t values, double desired, double balance,
         double span, double *out);

// Floors contain [plan.x, plan.y, underside, current floor, support id, ceiling].
// Supports contain [id, x, y, axis x/y, span, height, slope, section count],
// followed by one [upper crown, intact] pair for each section.
bool support_floors(const double *samples, std::size_t values, const double *supports,
                    std::size_t support_values, double *out);

// Geometry rows are [x, y, height, radius of interaction, owner, kind].
// The output consists of consecutive [first, second] pairs in index order.
bool candidate_pairs(const double *geometry, std::size_t values, double *out,
                     std::size_t &output_size);

} // namespace fire
