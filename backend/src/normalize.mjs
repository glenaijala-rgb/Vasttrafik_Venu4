import { AppError } from './errors.mjs';

export function timestamp(value) {
  if (typeof value !== 'string' || !/T.*(?:Z|[+-]\d{2}:\d{2})$/.test(value)) return NaN;
  return Date.parse(value);
}

export function cancelled(d) {
  // Arrival-only cancellation must not cancel the departure at this stop.
  if (d.isDepartureCancelled === true) return true;
  if (d.isArrivalCancelled === true) return false;
  return d.isCancelled === true;
}

export function matches(d, rule, queriedDirection, onwardGids = []) {
  if (!rule.enabled || rule.direction.verificationStatus !== 'verified') return false;
  if (!rule.lineNames.includes(d.serviceJourney?.line?.name)) return false;
  const r = rule.direction;
  const stop = d.realtimeStopPoint ?? d.stopPoint;
  return (!r.allowedDirectionGids.length || r.allowedDirectionGids.includes(queriedDirection)) &&
    (!r.allowedStopPointGids.length || r.allowedStopPointGids.includes(stop?.gid)) &&
    (!r.allowedPlatforms.length || r.allowedPlatforms.includes(stop?.platform)) &&
    r.mustPassStopAreaGids.every(gid => onwardGids.includes(gid));
}

export function journeyCalls(details, departure) {
  const journey = details.serviceJourneys?.find(j => j.gid === departure.serviceJourney?.gid);
  const calls = journey?.callsOnServiceJourney;
  if (!Array.isArray(calls)) throw new AppError('UPSTREAM_UNAVAILABLE');
  // Match the actual call, not just a stop that could occur twice on a circular route.
  const indices = calls.map((c, i) => c.stopPoint?.gid === departure.stopPoint?.gid &&
    timestamp(c.plannedDepartureTime) === timestamp(departure.plannedTime) ? i : -1).filter(i => i >= 0);
  if (indices.length !== 1) throw new AppError('UPSTREAM_UNAVAILABLE');
  return { calls, index: indices[0] };
}

export function onwardStops(details, departure) {
  const { calls, index } = journeyCalls(details, departure);
  return calls.slice(index + 1).filter(c => c.isArrivalCancelled !== true &&
    (c.isCancelled !== true || c.isDepartureCancelled === true))
    .map(c => (c.realtimeStopPoint ?? c.stopPoint)?.stopArea?.gid).filter(Boolean);
}

export function withCallCancellation(details, departure) {
  const { calls, index } = journeyCalls(details, departure);
  const call = calls[index];
  return { ...departure, isCancelled: call.isCancelled,
    isArrivalCancelled: call.isArrivalCancelled, isDepartureCancelled: call.isDepartureCancelled };
}

export function normalize(d, station) {
  const planned = timestamp(d.plannedTime);
  const estimated = timestamp(d.estimatedTime);
  const actual = timestamp(d.estimatedOtherwisePlannedTime ?? d.estimatedTime ?? d.plannedTime);
  const journey = d.serviceJourney;
  if (!Number.isFinite(planned) || !Number.isFinite(actual) || !journey?.gid || !journey.line?.name || !d.stopPoint?.gid) throw new AppError('UPSTREAM_UNAVAILABLE');
  const stop = d.realtimeStopPoint ?? d.stopPoint;
  return {
    id: `${journey.gid}:${d.stopPoint.gid}:${planned}`,
    stationKey: station.key, stationLabel: station.shortLabel,
    line: journey.line.name, destination: journey.direction ?? '',
    departureTime: new Date(actual).toISOString(), plannedTime: new Date(planned).toISOString(),
    departureEpoch: Math.floor(actual / 1000),
    isRealtime: Number.isFinite(estimated), isCancelled: cancelled(d),
    delayMinutes: Math.round((actual - planned) / 60000), platform: stop?.platform ?? '',
    platformChanged: d.realtimeStopPoint != null
  };
}

export function merge(departures, now, horizon, limit) {
  const unique = new Map();
  for (const d of departures) {
    const time = timestamp(d.departureTime);
    if (time >= now && time <= now + horizon * 60000) unique.set(d.id, d);
  }
  return [...unique.values()].sort((a, b) => timestamp(a.departureTime) - timestamp(b.departureTime) || a.id.localeCompare(b.id)).slice(0, limit);
}
