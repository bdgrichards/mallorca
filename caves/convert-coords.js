const fs = require('fs');
const path = require('path');

// UTM to Lat/Lng conversion for Zone 31N (Mallorca)
function utmToLatLng(easting, northing, zone = 31) {
  const a = 6378137;
  const f = 1 / 298.257223563;
  const e = Math.sqrt(2 * f - f * f);
  const e2 = e * e / (1 - e * e);
  const k0 = 0.9996;
  const x = easting - 500000;
  const y = northing;
  const M = y / k0;
  const mu = M / (a * (1 - e * e / 4 - 3 * e * e * e * e / 64 - 5 * e * e * e * e * e * e / 256));
  const e1 = (1 - Math.sqrt(1 - e * e)) / (1 + Math.sqrt(1 - e * e));
  const phi1 = mu + (3 * e1 / 2 - 27 * e1 * e1 * e1 / 32) * Math.sin(2 * mu)
    + (21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32) * Math.sin(4 * mu)
    + (151 * e1 * e1 * e1 / 96) * Math.sin(6 * mu)
    + (1097 * e1 * e1 * e1 * e1 / 512) * Math.sin(8 * mu);
  const N1 = a / Math.sqrt(1 - e * e * Math.sin(phi1) * Math.sin(phi1));
  const T1 = Math.tan(phi1) * Math.tan(phi1);
  const C1 = e2 * Math.cos(phi1) * Math.cos(phi1);
  const R1 = a * (1 - e * e) / Math.pow(1 - e * e * Math.sin(phi1) * Math.sin(phi1), 1.5);
  const D = x / (N1 * k0);
  const lat = phi1 - (N1 * Math.tan(phi1) / R1) * (D * D / 2 - (5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * e2) * D * D * D * D / 24
    + (61 + 90 * T1 + 298 * C1 + 45 * T1 * T1 - 252 * e2 - 3 * C1 * C1) * D * D * D * D * D * D / 720);
  const lng = ((zone - 1) * 6 - 180 + 3) * Math.PI / 180
    + (D - (1 + 2 * T1 + C1) * D * D * D / 6
    + (5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * e2 + 24 * T1 * T1) * D * D * D * D * D / 120) / Math.cos(phi1);
  return { lat: lat * 180 / Math.PI, lng: lng * 180 / Math.PI };
}

const dataDir = path.join(__dirname, 'data');
const files = fs.readdirSync(dataDir).filter(f => f.endsWith('.json'));
let converted = 0, skipped = 0;

files.forEach(f => {
  const fp = path.join(dataDir, f);
  const d = JSON.parse(fs.readFileSync(fp, 'utf8'));
  const raw = d.coordinates_utm || '';
  if (!raw || raw.length < 5) { skipped++; return; }

  // Try to extract WGS84/ETRS89 coordinates first, fall back to ED50
  let easting, northing, datum;

  // Pattern: look for ETRS89 or WGS84 section
  const wgs = raw.match(/(\d[\d.,]+)\s*E\s*,?\s*(\d[\d.,]+)\s*N\s*.*(?:WGS84|ETRS89|GPS)/i);
  const ed50 = raw.match(/(\d[\d.,]+)\s*E\s*,?\s*(\d[\d.,]+)\s*N/i);

  if (wgs) {
    easting = parseFloat(wgs[1].replace(',', '.'));
    northing = parseFloat(wgs[2].replace(',', '.'));
    datum = 'WGS84/ETRS89';
  } else if (ed50) {
    easting = parseFloat(ed50[1].replace(',', '.'));
    northing = parseFloat(ed50[2].replace(',', '.'));
    datum = 'ED50';
  } else {
    skipped++;
    return;
  }

  if (isNaN(easting) || isNaN(northing) || easting < 400000 || easting > 600000 || northing < 4300000 || northing > 4500000) {
    skipped++;
    return;
  }

  const { lat, lng } = utmToLatLng(easting, northing);

  // Sanity check: Mallorca is roughly 39.2-40.0 lat, 2.3-3.5 lng
  if (lat < 39 || lat > 40.2 || lng < 2 || lng > 4) {
    console.log(`WARN: ${f} out of range: ${lat}, ${lng} (E=${easting} N=${northing} ${datum})`);
    skipped++;
    return;
  }

  d.lat = Math.round(lat * 1e6) / 1e6;
  d.lng = Math.round(lng * 1e6) / 1e6;
  fs.writeFileSync(fp, JSON.stringify(d, null, 2));
  converted++;
});

console.log(`Converted: ${converted}, Skipped: ${skipped}`);
