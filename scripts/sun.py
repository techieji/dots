#! /usr/bin/env python3
import math
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo
import os
import time

# Written by claude...
def solar_altitude_deg(lat: float, lon: float, when: datetime) -> float:
    day_of_year = when.timetuple().tm_yday
    hour_utc = when.hour + when.minute / 60 + when.second / 3600
    frac_year = 2 * math.pi / 365 * (day_of_year - 1 + (hour_utc - 12) / 24)
    eqtime = 229.18 * (0.000075 + 0.001868 * math.cos(frac_year) - 0.032077 * math.sin(frac_year) - 0.014615 * math.cos(2 * frac_year) - 0.040849 * math.sin(2 * frac_year))
    decl = 0.006918 - 0.399912 * math.cos(frac_year) + 0.070257 * math.sin(frac_year) - 0.006758 * math.cos(2 * frac_year) \
            + 0.000907 * math.sin(2 * frac_year) - 0.002697 * math.cos(3 * frac_year) + 0.00148 * math.sin(3 * frac_year)
    tst = hour_utc * 60 + (eqtime + 4 * lon)
    hour_angle_deg = tst / 4 - 180
    lat_r = math.radians(lat)
    ha_r = math.radians(hour_angle_deg)
    cos_zenith = math.sin(lat_r) * math.sin(decl) + math.cos(lat_r) * math.cos(decl) * math.cos(ha_r)
    cos_zenith = max(-1.0, min(1.0, cos_zenith))
    return math.degrees(math.asin(cos_zenith))

# Piecewise-linear altitude -> CCT (Kelvin) curve.
#
# Control points follow the real photometric curve, INCLUDING the
# post-sunset upswing: once the sun drops below the horizon, direct warm
# sunlight is gone and you're left with pure blue-shifted skylight, so CCT
# rises again through civil twilight before we floor it.
#
# Must be sorted by ascending altitude.
CURVE = [
    # --- twilight/sunset: full range, intensity lives here ---
    (-6.0, 9800.0),  # end of civil twilight: blue-hour peak
    (-5.5, 8900.0),
    (-5.0, 8000.0),
    (-4.5, 7100.0),
    (-4.0, 6300.0),
    (-3.5, 5400.0),
    (-3.0, 4500.0),
    (-2.5, 3600.0),
    (-2.0, 2800.0),
    (-1.5, 2200.0),
    (-1.0, 1700.0),
    (-0.5, 1400.0),
    (0.0, 1000.0),   # sunset/sunrise: pinned to hyprsunset's floor
    (0.5, 1400.0),
    (1.0, 1700.0),
    (1.5, 2200.0),
    (2.0, 2800.0),
    (3.0, 3600.0),
    (4.0, 4300.0),
    (5.0, 4900.0),
    (6.0, 5300.0),
    (7.0, 5500.0),
    (8.0, 5650.0),
    (9.0, 5750.0),
    (10.0, 5800.0),  # essentially settled by here
    # --- daytime: flat, physically accurate, no more range-stretching ---
    (12.0, 5850.0),
    (15.0, 5900.0),
    (20.0, 5900.0),
    (90.0, 5900.0),
]

def altitude_to_cct(altitude_deg: float) -> float:
    if altitude_deg <= CURVE[0][0]:
        return CURVE[0][1]              # Blue light at night lol
    if altitude_deg >= CURVE[-1][0]:
        return CURVE[-1][1]

    for (a0, c0), (a1, c1) in zip(CURVE, CURVE[1:]):
        if a0 <= altitude_deg <= a1:
            t = (altitude_deg - a0) / (a1 - a0)
            return c0 + t * (c1 - c0)

    raise AssertionError("unreachable")

lat, lon = 39.0, -77.3  # TODO query this!
tz = ZoneInfo('US/Eastern')

def get_color(when):
    return altitude_to_cct(solar_altitude_deg(lat, lon, when))

def should_update(last_sent_k: float, candidate_k: float, threshold_mireds: float = 10.0) -> bool:
    mired_delta = abs(1_000_000 / last_sent_k - 1_000_000 / candidate_k)
    return mired_delta >= threshold_mireds

def set_temperature(k):
    os.system(f'hyprctl hyprsunset temperature {k} > /dev/null')

def update_and_get_next(daytime):
    when = daytime.astimezone(timezone.utc)
    k_now = get_color(when)
    set_temperature(k_now)
    # Binary search
    increment = timedelta(minutes=30)
    lower = when
    upper = None
    while upper is None or upper - lower > timedelta(minutes=1):
        if should_update(k_now, get_color(when)):
            upper = when
            when -= increment
        else:
            lower = when
            when += increment
        if upper is not None: increment /= 2
    ret = upper.astimezone(tz)
    print(f'Setting temperature at {k_now}, next update at {ret}')
    return upper.astimezone(tz)

if __name__ == "__main__":
    daytime = datetime.now(tz)
    while True:
        daytime = update_and_get_next(daytime)
        time.sleep(daytime.timestamp() - datetime.now(tz).timestamp())
