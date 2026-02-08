#!/usr/bin/env python3
import sys
import os
import numpy as np
from osgeo import gdal

gdal.UseExceptions()

def reproject_to_3857(src_path, dst_path):
    src = gdal.Open(src_path)
    nodata = src.GetRasterBand(1).GetNoDataValue()
    
    # Zoom 12 resolution (~38m) — matches 30m Copernicus DEM source
    res = 40075016.686 / (256 * 2**12)
    
    warp_opts = gdal.WarpOptions(
        dstSRS='EPSG:3857',
        resampleAlg='bilinear',
        xRes=res,
        yRes=res,
        srcNodata=nodata,
        outputType=gdal.GDT_Float32,
        creationOptions=['COMPRESS=DEFLATE', 'TILED=YES', 'BIGTIFF=YES'],
    )
    gdal.Warp(dst_path, src, options=warp_opts)

def encode_mapbox(elevation):
    # Mapbox encoding: elevation = -10000 + (R * 256 * 256 + G * 256 + B) * 0.1
    # Inverse: (elevation + 10000) * 10 = R * 65536 + G * 256 + B

    elev = np.array(elevation, copy=True, dtype=np.float32)
    mask_invalid = np.isnan(elev) | (elev < -500) | (elev > 5000)
    elev[mask_invalid] = 0.0

    elev = np.clip(elev, -10000.0, 1667721.0)

    val = np.floor((elev + 10000.0) * 10.0).astype(np.int32)

    R = ((val >> 16) & 0xFF).astype(np.uint8)
    G = ((val >> 8) & 0xFF).astype(np.uint8)
    B = (val & 0xFF).astype(np.uint8)

    return np.stack([R, G, B])

def write_rgb(rgb, reference_path, output_path):
    ref = gdal.Open(reference_path)
    driver = gdal.GetDriverByName('GTiff')
    ds = driver.Create(
        output_path,
        ref.RasterXSize,
        ref.RasterYSize,
        3,
        gdal.GDT_Byte,
        ['COMPRESS=DEFLATE', 'TILED=YES', 'INTERLEAVE=PIXEL', 'BIGTIFF=YES'],
    )
    ds.SetGeoTransform(ref.GetGeoTransform())
    ds.SetProjection(ref.GetProjection())
    for i, band_data in enumerate(rgb, start=1):
        ds.GetRasterBand(i).WriteArray(band_data)
    ds.FlushCache()

def main():
    if len(sys.argv) != 3: sys.exit(1)
    input_path, output_path = sys.argv[1], sys.argv[2]
    tmp_path = output_path + '.tmp_3857.tif'

    print(f"  Input:  {input_path}")
    print(f"  Output: {output_path}")

    print("  Reprojecting to EPSG:3857 (bilinear, zoom-12 resolution)...")
    sys.stdout.flush()
    reproject_to_3857(input_path, tmp_path)

    print("  Reading elevation data...")
    sys.stdout.flush()
    ds = gdal.Open(tmp_path)
    band = ds.GetRasterBand(1)
    elev = band.ReadAsArray().astype(np.float32)
    valid = elev[~np.isnan(elev) & (elev > -500)]
    print(f"  Size: {elev.shape[1]} x {elev.shape[0]} px, "
          f"elevation range: {valid.min():.1f} - {valid.max():.1f} m")
    ds = None

    print("  Encoding as Mapbox RGB...")
    sys.stdout.flush()
    rgb = encode_mapbox(elev)

    print("  Writing terrain-RGB GeoTIFF...")
    sys.stdout.flush()
    write_rgb(rgb, tmp_path, output_path)

    os.remove(tmp_path)
    print("  Done.")

if __name__ == '__main__':
    main()
