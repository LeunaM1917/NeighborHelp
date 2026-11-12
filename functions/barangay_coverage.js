'use strict';
const barangays = require('./panabo_barangays.json').barangays;
const city = require('./panabo_city.json');
const byId = new Map(barangays.map(b => [b.id, b]));

function segmentDistanceSquared(point, a, b) {
  const dx = b[0] - a[0], dy = b[1] - a[1], length = dx * dx + dy * dy;
  const t = length ? Math.max(0, Math.min(1,
    ((point.longitude - a[0]) * dx + (point.latitude - a[1]) * dy) / length)) : 0;
  return (point.longitude - a[0] - t * dx) ** 2 + (point.latitude - a[1] - t * dy) ** 2;
}
function ringDistanceSquared(point, ring) {
  let distance = Infinity;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    distance = Math.min(distance, segmentDistanceSquared(point, ring[j], ring[i]));
  }
  return distance;
}
function inRing(point, ring) {
  if (ringDistanceSquared(point, ring) <= 1e-20) return true;
  let inside = false;
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i], [xj, yj] = ring[j];
    if ((yi > point.latitude) !== (yj > point.latitude)
      && point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
const inPolygon = (point, rings) => inRing(point, rings[0])
  && !rings.slice(1).some(ring => inRing(point, ring));

module.exports = function barangaysCover(ids, point) {
  if (!Array.isArray(ids) || !ids.length || ids.some(id => !byId.has(id))
    || !Number.isFinite(point?.latitude) || !Number.isFinite(point?.longitude)
    || Math.abs(point.latitude) > 90 || Math.abs(point.longitude) > 180) return false;
  const selected = new Set(ids);
  const containing = barangays.filter(b => b.polygons.some(rings => inPolygon(point, rings)));
  if (containing.length) return containing.some(b => selected.has(b.id));

  // Independent 0.005-degree simplification leaves gaps between barangays.
  // Resolve only gaps inside Panabo, never a known unselected area or hole.
  if (!city.polygons.some(rings => inPolygon(point, rings))
    || barangays.some(b => b.polygons.some(rings => rings.slice(1).some(r => inRing(point, r))))) return false;
  let nearestId, distance = Infinity;
  for (const b of barangays) {
    const candidate = Math.min(...b.polygons.map(rings => ringDistanceSquared(point, rings[0])));
    if (candidate < distance - 1e-16) { distance = candidate; nearestId = b.id; }
  }
  return distance <= city.gapToleranceDegrees ** 2 && selected.has(nearestId);
};
