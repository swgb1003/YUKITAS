/**
 * Server-side geohash, kept in sync with `lib/core/geo/geo_cell.dart`.
 *
 * Used when projecting a request onto the public board so the coordinate
 * every signed-in user can see is a cell center, never the real address
 * (spec 06.1 / 08.4).
 */
const BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz";

/** ~1.2km x 0.6km - the blur applied to a published coordinate. */
export const PUBLIC_LOCATION_PRECISION = 6;

/** ~4.9km square - the bucket nearby-request queries are scoped to. */
export const BOARD_CELL_PRECISION = 5;

export function encodeGeohash(
  latitude: number,
  longitude: number,
  precision: number = PUBLIC_LOCATION_PRECISION,
): string {
  let latMin = -90;
  let latMax = 90;
  let lngMin = -180;
  let lngMax = 180;
  let hash = "";
  let evenBit = true;
  let bit = 0;
  let index = 0;

  while (hash.length < precision) {
    if (evenBit) {
      const mid = (lngMin + lngMax) / 2;
      if (longitude >= mid) {
        index = index * 2 + 1;
        lngMin = mid;
      } else {
        index = index * 2;
        lngMax = mid;
      }
    } else {
      const mid = (latMin + latMax) / 2;
      if (latitude >= mid) {
        index = index * 2 + 1;
        latMin = mid;
      } else {
        index = index * 2;
        latMax = mid;
      }
    }
    evenBit = !evenBit;
    if (++bit === 5) {
      hash += BASE32[index];
      bit = 0;
      index = 0;
    }
  }
  return hash;
}

export function geohashCenter(geohash: string): {
  latitude: number;
  longitude: number;
} {
  let latMin = -90;
  let latMax = 90;
  let lngMin = -180;
  let lngMax = 180;
  let evenBit = true;

  for (const char of geohash) {
    const index = BASE32.indexOf(char);
    if (index < 0) throw new Error(`Invalid geohash character: ${char}`);
    for (let mask = 16; mask > 0; mask >>= 1) {
      if (evenBit) {
        const mid = (lngMin + lngMax) / 2;
        if (index & mask) lngMin = mid;
        else lngMax = mid;
      } else {
        const mid = (latMin + latMax) / 2;
        if (index & mask) latMin = mid;
        else latMax = mid;
      }
      evenBit = !evenBit;
    }
  }
  return {
    latitude: (latMin + latMax) / 2,
    longitude: (lngMin + lngMax) / 2,
  };
}
