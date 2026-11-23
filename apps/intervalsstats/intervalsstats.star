"""
Applet: Intervals Stats
Summary: Intervals.icu activity totals
Description: Shows year-to-date or all-time distance, moving time and activity count from Intervals.icu.
Author: Jaime Fordham (github.com/jaimefordham)
"""

load("encoding/base64.star", "base64")
load("http.star", "http")
load("humanize.star", "humanize")
load("render.star", "render")
load("schema.star", "schema")
load("time.star", "time")

API_URL = "https://intervals.icu/api/v1/athlete/%s/activities"
CACHE_TTL_SECONDS = 3600
METRES_PER_MILE = 1609.344

APP_TITLE = "intervals.icu"
FRAME_COUNT = 16  # first half shows the app title, second half the activity and period
FRAME_DELAY_MS = 250

# Intervals.icu dark-theme palette.
BRAND = "#dd0447"
PRIMARY = "#8b7cf6"
ACCENT = "#06b6d4"
TEXT = "#e8e8f0"
MUTED = "#9e9eb8"

DEFAULT_ATHLETE_ID = "0"
DEFAULT_GROUP = "cycling"
DEFAULT_PERIOD = "ytd"
DEFAULT_UNITS = "km"

# Intervals.icu activity types that belong to each selectable group.
ACTIVITY_GROUPS = {
    "cycling": {
        "icon": "bike",
        "label": "CYCLING",
        "noun": "rides",
        "types": [
            "Ride",
            "VirtualRide",
            "GravelRide",
            "MountainBikeRide",
            "EBikeRide",
            "EMountainBikeRide",
            "Cyclocross",
            "TrackRide",
            "Velomobile",
            "Handcycle",
        ],
    },
    "running": {
        "icon": "run",
        "label": "RUNNING",
        "noun": "runs",
        "types": ["Run", "VirtualRun", "TrailRun"],
    },
    "walking": {
        "icon": "walk",
        "label": "WALKING",
        "noun": "walks",
        "types": ["Walk", "Hike"],
    },
    "swimming": {
        "icon": "swim",
        "label": "SWIMMING",
        "noun": "swims",
        "types": ["Swim", "OpenWaterSwim"],
    },
}

def message_screen(text):
    return render.Root(
        child = render.Box(
            child = render.WrappedText(
                content = text,
                font = "tom-thumb",
                align = "center",
                width = 60,
            ),
        ),
    )

def fetch_activities(athlete_id, api_key, oldest):
    """Returns (activities, error_message). Exactly one of them is None."""
    auth = base64.encode("API_KEY:" + api_key)
    response = http.get(
        API_URL % athlete_id,
        params = {
            "oldest": oldest,
            "fields": "type,distance,moving_time",
        },
        headers = {"Authorization": "Basic " + auth},
        ttl_seconds = CACHE_TTL_SECONDS,
    )
    if response.status_code == 401 or response.status_code == 403:
        return None, "Invalid API key"
    if response.status_code != 200:
        return None, "API error %d" % response.status_code
    return response.json(), None

def summarise(activities, types):
    distance_m = 0.0
    moving_s = 0
    count = 0
    for activity in activities:
        if activity.get("type") not in types:
            continue
        count += 1
        distance_m += activity.get("distance") or 0
        moving_s += activity.get("moving_time") or 0
    return distance_m, moving_s, count

def format_distance(distance_m, units):
    if units == "mi":
        return "%s mi" % humanize.comma(int(distance_m / METRES_PER_MILE))
    return "%s km" % humanize.comma(int(distance_m / 1000))

def format_duration(moving_s):
    hours = int(moving_s / 3600)
    minutes = int((moving_s % 3600) / 60)
    return "%dh %dm" % (hours, minutes)

def sprite(pixels, width, height):
    """Draws a pixel-art image from a {(x, y): colour} dict."""
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            row.append(render.Box(width = 1, height = 1, color = pixels.get((x, y))))
        rows.append(render.Row(children = row))
    return render.Column(children = rows)

def logo_icon():
    """Small rising-bars mark used either side of the title."""
    pixels = {}
    for x, bar_height in ((0, 2), (2, 4), (4, 5)):
        for y in range(5 - bar_height, 5):
            pixels[(x, y)] = PRIMARY
    return sprite(pixels, 5, 5)

def distance_icon(frame):
    """A road whose centre dashes move along it."""
    pixels = {}
    for x in range(7):
        pixels[(x, 1)] = MUTED
        pixels[(x, 5)] = MUTED
        if (x + frame) % 4 < 2:
            pixels[(x, 3)] = ACCENT
    return sprite(pixels, 7, 7)

def time_icon(frame):
    """A clock face whose hand moves a quarter turn each step."""
    pixels = {}
    for i in range(1, 6):
        for point in ((i, 0), (i, 6), (0, i), (6, i)):
            pixels[point] = PRIMARY
    hands = (
        ((3, 2), (3, 1)),
        ((4, 3), (5, 3)),
        ((3, 4), (3, 5)),
        ((2, 3), (1, 3)),
    )
    pixels[(3, 3)] = ACCENT
    for point in hands[frame % 4]:
        pixels[point] = ACCENT
    return sprite(pixels, 7, 7)

def bike_icon(frame):
    """A bicycle whose wheel spokes alternate between + and x shapes."""
    pixels = {}
    for hub_x in (2, 10):
        left = hub_x - 2
        for i in range(1, 4):
            for point in ((left + i, 2), (left + i, 6), (left, 2 + i), (left + 4, 2 + i)):
                pixels[point] = PRIMARY
        if frame % 2 == 0:
            spokes = ((0, 1), (1, 0), (1, 1), (1, 2), (2, 1))
        else:
            spokes = ((0, 0), (0, 2), (1, 1), (2, 0), (2, 2))
        for dx, dy in spokes:
            pixels[(left + 1 + dx, 3 + dy)] = MUTED
    frame_pixels = (
        (4, 0),
        (5, 0),  # saddle
        (5, 1),
        (6, 1),
        (7, 1),
        (8, 1),  # top tube
        (5, 2),
        (5, 3),
        (5, 4),
        (6, 5),  # seat tube to bottom bracket
        (7, 4),
        (7, 3),
        (7, 2),  # down tube
        (8, 0),
        (9, 0),  # handlebar
        (2, 4),
        (10, 4),  # hubs
    )
    for point in frame_pixels:
        pixels[point] = BRAND
    return sprite(pixels, 13, 7)

def run_icon(frame):
    """A runner whose arms and legs swap each step."""
    pixels = {(4, 0): TEXT, (3, 1): TEXT, (3, 2): TEXT, (3, 3): TEXT}
    if frame % 2 == 0:
        limbs = ((4, 2), (5, 1), (2, 1), (1, 2), (4, 4), (5, 5), (2, 4), (1, 5), (0, 6))
    else:
        limbs = ((2, 2), (1, 3), (4, 3), (5, 2), (4, 4), (4, 5), (4, 6), (3, 4), (2, 5), (2, 6))
    for point in limbs:
        pixels[point] = PRIMARY
    return sprite(pixels, 7, 7)

def walk_icon(frame):
    """A walker whose legs open and close, with arms swinging."""
    pixels = {(3, 0): TEXT, (3, 1): TEXT, (3, 2): TEXT, (3, 3): TEXT}
    if frame % 2 == 0:
        limbs = ((2, 3), (4, 2), (3, 4), (2, 5), (1, 6), (4, 5), (5, 6))
    else:
        limbs = ((2, 2), (4, 3), (3, 4), (2, 5), (2, 6), (4, 5), (4, 6))
    for point in limbs:
        pixels[point] = PRIMARY
    return sprite(pixels, 7, 7)

def swim_icon(frame):
    """A swimmer's head and arm above scrolling waves."""
    pixels = {(1, 3): TEXT, (2, 3): PRIMARY, (3, 3): PRIMARY}
    arm = ((4, 2), (5, 1), (6, 2)) if frame % 2 == 0 else ((4, 3), (5, 3), (6, 3))
    for point in arm:
        pixels[point] = PRIMARY
    for x in range(7):
        if (x + frame) % 2 == 0:
            pixels[(x, 4)] = ACCENT
        else:
            pixels[(x, 5)] = ACCENT
    return sprite(pixels, 7, 7)

def activity_icon(icon, frame):
    if icon == "run":
        return run_icon(frame)
    if icon == "walk":
        return walk_icon(frame)
    if icon == "swim":
        return swim_icon(frame)
    return bike_icon(frame)

def title_row(title_parts, show_logos):
    """Draws the title from (text, colour) parts, optionally flanked by the logo."""
    children = []
    for text, colour in title_parts:
        children.append(render.Text(text, font = "tom-thumb", color = colour))
    if show_logos:
        spacer = render.Box(width = 2, height = 1)
        children = [logo_icon(), spacer] + children + [spacer, logo_icon()]
    return render.Box(width = 64, height = 7, child = render.Row(cross_align = "center", children = children))

def stat_row(icon, value):
    return render.Row(
        cross_align = "center",
        children = [
            render.Box(width = 13, height = 8, child = icon),
            render.Box(width = 3, height = 1),
            value,
        ],
    )

def render_frame(frame, icon, title, show_logos, distance_text, time_text, count_text):
    return render.Column(
        expanded = True,
        main_align = "space_between",
        children = [
            title_row(title, show_logos),
            stat_row(distance_icon(frame % 4), render.Text(distance_text, font = "tb-8", color = TEXT)),
            stat_row(time_icon(frame // 2), render.Text(time_text, font = "tom-thumb", color = TEXT)),
            stat_row(activity_icon(icon, frame), render.Text(count_text, font = "tom-thumb", color = MUTED)),
        ],
    )

def main(config):
    api_key = config.str("api_key")
    if not api_key:
        return message_screen("Set your Intervals.icu API key")

    athlete_id = config.str("athlete_id") or DEFAULT_ATHLETE_ID
    group = ACTIVITY_GROUPS.get(config.str("group", DEFAULT_GROUP), ACTIVITY_GROUPS[DEFAULT_GROUP])
    period = config.str("period", DEFAULT_PERIOD)
    units = config.str("units", DEFAULT_UNITS)

    if period == "total":
        oldest = "2000-01-01"
        period_label = "TOTAL"
    else:
        oldest = "%d-01-01" % time.now().year
        period_label = "YTD"

    activities, error = fetch_activities(athlete_id, api_key, oldest)
    if error:
        print(error)
        return message_screen(error)

    distance_m, moving_s, count = summarise(activities, group["types"])

    distance_text = format_distance(distance_m, units)
    time_text = format_duration(moving_s)
    count_text = "%d %s" % (count, group["noun"] if count != 1 else group["noun"][:-1])
    app_title = [(APP_TITLE, BRAND)]
    period_title = [(group["label"], ACCENT), (" " + period_label, MUTED)]

    frames = []
    for frame in range(FRAME_COUNT):
        showing_period = frame >= FRAME_COUNT // 2
        title = period_title if showing_period else app_title
        frames.append(render_frame(frame, group["icon"], title, not showing_period, distance_text, time_text, count_text))

    return render.Root(
        delay = FRAME_DELAY_MS,
        child = render.Animation(children = frames),
    )

def get_schema():
    group_options = [
        schema.Option(display = "Cycling", value = "cycling"),
        schema.Option(display = "Running", value = "running"),
        schema.Option(display = "Walking / Hiking", value = "walking"),
        schema.Option(display = "Swimming", value = "swimming"),
    ]
    period_options = [
        schema.Option(display = "Year to date", value = "ytd"),
        schema.Option(display = "All time", value = "total"),
    ]
    unit_options = [
        schema.Option(display = "Kilometres", value = "km"),
        schema.Option(display = "Miles", value = "mi"),
    ]
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "api_key",
                name = "API key",
                desc = "Intervals.icu Settings > Developer Settings.",
                icon = "key",
                secret = True,
            ),
            schema.Text(
                id = "athlete_id",
                name = "Athlete ID",
                desc = "Leave as 0 to use the owner of the API key.",
                icon = "user",
                default = DEFAULT_ATHLETE_ID,
            ),
            schema.Dropdown(
                id = "group",
                name = "Activity",
                desc = "Which activities to total.",
                icon = "personBiking",
                default = DEFAULT_GROUP,
                options = group_options,
            ),
            schema.Dropdown(
                id = "period",
                name = "Period",
                desc = "Year to date or all time.",
                icon = "calendar",
                default = DEFAULT_PERIOD,
                options = period_options,
            ),
            schema.Dropdown(
                id = "units",
                name = "Distance units",
                desc = "Kilometres or miles.",
                icon = "ruler",
                default = DEFAULT_UNITS,
                options = unit_options,
            ),
        ],
    )
