#!/bin/bash
cd "$(dirname "$0")"
BASE="http://www.mallorcaverde.es"
TOPO_BASE="$BASE/imagenes/mapa-topografico-espeleo"
count=0
total=0

for f in data/*.json; do
  total=$((total + 1))
  url=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$f','utf8')).url||'')")
  if [ -z "$url" ]; then continue; fi

  # Extract the Mapa topográfico href from the main cave page
  topo_href=$(curl -s --max-time 8 "$url" | grep -i 'topogr' | grep -o 'href="[^"]*"' | head -1 | sed 's/href="//;s/"//')
  if [ -z "$topo_href" ]; then continue; fi

  # Build full URL for the topo page
  if echo "$topo_href" | grep -q '^http'; then
    topo_page="$topo_href"
  elif echo "$topo_href" | grep -q '^imagenes/'; then
    topo_page="$BASE/$topo_href"
  else
    topo_page="$BASE/$topo_href"
  fi

  # Fetch the topo page and extract the image src (skip banner)
  topo_img=$(curl -s --max-time 8 "$topo_page" | grep -i 'img.*src=' | grep -iv 'banner' | grep -o 'src="[^"]*"' | head -1 | sed 's/src="//;s/"//')
  if [ -z "$topo_img" ]; then continue; fi

  # Build full image URL (relative to topo page directory)
  topo_dir=$(echo "$topo_page" | sed 's|/[^/]*$||')
  full_topo_url="$topo_dir/$topo_img"

  fname=$(basename "$f")
  echo "$fname: $full_topo_url"

  node -e "
    const fs = require('fs');
    const data = JSON.parse(fs.readFileSync('$f', 'utf8'));
    data.topo_map = '${full_topo_url}';
    fs.writeFileSync('$f', JSON.stringify(data, null, 2));
  "
  count=$((count + 1))
done

echo ""
echo "=== Done: $count of $total caves have topo maps ==="
