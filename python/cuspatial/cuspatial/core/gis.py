# COPYRIGHT 2019 NVIDIA

from cuspatial._lib.spatial import cpp_point_in_polygon_bitmap

def directed_hausdorff_distance():
    """ Compute the directed Hausdorff distances between any groupings
    of polygons.

    params
    x: x coordinates
    y: y coordinates
    count: size of each polygon
    
    Parameters
    ----------
    {params}

    returns
    DataFrame: 'min', 'max' columns of Hausdorff distances for each polygon
    """
    pass

def haversine_distance(p1_lat, p1_lon, p2_lat, p2_lon):
    """ Compute the haversine distances between an arbitrary list of lat/lon
    pairs

    params
    p1_lat: latitude of first set of coords
    p1_lon: longitude of first set of coords
    p2_lat: latitude of second set of coords
    p2_lon: longitude of second set of coords
    
    Parameters
    ----------
    {params}

    returns
    Series: distance between all pairs of lat/lon coords
    """
    pass

def lonlat_to_xy_km_coordinates(camera_latlon, lon_coords, lat_coords):
    """ Convert lonlat coordinates to km x,y coordinates based on some camera
    origin.

    params
    camera_latlon: Series - latitude and longitude of camera
    lon_coords: Series of longitude coords to convert to x
    lat_coords: Series of latitude coords to convert to y
    
    Parameters
    ----------
    {params}

    returns
    DataFrame: 'x', 'y' columns for new km positions of coords
    """
    pass

def point_in_polygon_bitmap(x_points, y_points,
        polygon_ids, polygon_end_indices, polygons_x, polygons_y):
    """ Compute from a set of points and a set of polygons which points fall
    within which polygons.

    Parameters
    ----------
    {params}
    """
    return cpp_point_in_polygon_bitmap(
        x_points, y_points,
        polygon_ids, polygon_end_indices, polygons_x, polygons_y
    )
