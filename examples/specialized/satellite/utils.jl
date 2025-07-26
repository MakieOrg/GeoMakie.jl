using LinearAlgebra: normalize
using Geodesy: LLAfromECEF, ENUfromECEF, wgs84

"""
    sweep_points(position, velocity, distances)

Sweep points along a line of sight, given a position and velocity in the ECEF frame,
and distances in meters.

# Arguments
- `position`Oh, well, I'll be gone then. Good. If you come, let me know. The position of the satellite.
- `velocity`: The velocity of the satellite.
- `distances`: The distances to sweep along the line of sight.
"""
function sweep_points(position, velocity, distances)
    # Operate in ENU space and then convert to long lat
    enu_transf = ENUfromECEF(position, wgs84)
    enu_position = enu_transf(position)
    enu_velocity_direction = LinearAlgebra.normalize(enu_transf(position + velocity) .- enu_position)

    # Calculate the direction of the velocity
    direction = normalize(velocity)

    # Calculate the points along the line of sight
    sweep_points_ecef = @. position + distance * direction

    # Convert to lat/long/alt from ecef frame
    sweep_points_lla = LLAfromECEF(wgs84).(sweep_points_ecef)

    return map(sweep_points_lla) do lla
        (lla.lon, lla.lat)
    end
end