
"""
An array of selected London Tube locations in Ordnance
Survey GB coordinates.

Source: https://www.doogal.co.uk/london_stations.php

"""
tube_stations = Point2f[[531738., 180890.], [532379., 179734.],
                [531096., 181642.], [530234., 180492.],
                [531688., 181150.], [530242., 180982.],
                [531940., 179144.], [530406., 180380.],
                [529012., 180283.], [530553., 181488.],
                [531165., 179489.], [529987., 180812.],
                [532347., 180962.], [529102., 181227.],
                [529612., 180625.], [531566., 180025.],
                [529629., 179503.], [532105., 181261.],
                [530995., 180810.], [529774., 181354.],
                [528941., 179131.], [531050., 179933.],
                [530240., 179718.]]

using MakieTeX
tube_marker = CachedSVG(read(download("https://upload.wikimedia.org/wikipedia/commons/c/ca/Underground_%28no_text%29.svg"), String))

using Tyler, GeoMakie

fig = Figure()
ax = Axis(fig[1, 1])
m = Tyler.Map(Makie.BBox(-0.14, -0.1, 51.495, 51.515); figure = fig, axis = ax)
scatter!(ax, tube_stations, marker = tube_marker, color = :red, markersize = 15)
fig


def main():
    imagery = OSM()

    fig = plt.figure()
    ax = fig.add_subplot(1, 1, 1, projection=imagery.crs)
    ax.set_extent([-0.14, -0.1, 51.495, 51.515], ccrs.PlateCarree())

    # Construct concentric circles and a rectangle,
    # suitable for a London Underground logo.
    theta = np.linspace(0, 2 * np.pi, 100)
    circle_verts = np.vstack([np.sin(theta), np.cos(theta)]).T
    concentric_circle = Path.make_compound_path(Path(circle_verts[::-1]),
                                                Path(circle_verts * 0.6))

    rectangle = Path([[-1.1, -0.2], [1, -0.2], [1, 0.3], [-1.1, 0.3]])

    # Add the imagery to the map.
    ax.add_image(imagery, 14)

    # Plot the locations twice, first with the red concentric circles,
    # then with the blue rectangle.
    xs, ys = tube_locations().T
    ax.plot(xs, ys, transform=ccrs.OSGB(approx=False),
            marker=concentric_circle, color='red', markersize=9, linestyle='')
    ax.plot(xs, ys, transform=ccrs.OSGB(approx=False),
            marker=rectangle, color='blue', markersize=11, linestyle='')

    ax.set_title('London underground locations')
    plt.show()