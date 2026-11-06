"""Read one local day from Evolution Data Server, including recurring events.

GNOME Online Accounts and EDS own authentication and synchronization. This
read-only helper never reads credentials or performs provider-specific login.
"""

import argparse
import datetime as dt
import json
import os
import signal

import gi

gi.require_version("EDataServer", "1.2")
gi.require_version("ECal", "2.0")
gi.require_version("ICalGLib", "3.0")
from gi.repository import ECal, EDataServer, GLib, ICalGLib  # noqa: E402


def day_bounds(day):
    # Resolve each local midnight separately, so DST days may be 23 or 25 hours.
    start = dt.datetime.combine(day, dt.time()).astimezone()
    end = dt.datetime.combine(day + dt.timedelta(days=1), dt.time()).astimezone()
    return int(start.timestamp()), int(end.timestamp())


def read_day(day):
    registry = EDataServer.SourceRegistry.new_sync(None)
    start, end = day_bounds(day)
    zone_name = os.environ.get("TZ") or os.environ.get("DESKTOP_CALENDAR_TIME_ZONE", "UTC")
    local_zone = ICalGLib.Timezone.get_builtin_timezone(zone_name) or ICalGLib.Timezone.get_utc_timezone()
    events, unavailable = [], []
    sources = [
        source
        for source in registry.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR)
        if source.get_enabled()
        and source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR).get_selected()
    ]
    for source in sources:
        try:
            # EDS documents (guint32)-1 as "do not wait for online". Read its
            # local cache immediately while provider synchronization continues.
            client = ECal.Client.connect_sync(source, ECal.ClientSourceType.EVENTS, GLib.MAXUINT32, None)
            client.set_default_timezone(local_zone)

            def collect(component, instance_start, instance_end, *_):
                timestamp = instance_start.as_timet_with_zone(instance_start.get_timezone() or local_zone)
                # EDS may include an event ending exactly at the query boundary.
                if instance_end.as_timet_with_zone(instance_end.get_timezone() or local_zone) <= start or timestamp >= end:
                    return True
                events.append({
                    "uid": component.get_uid() or "",
                    "title": component.get_summary() or "Untitled event",
                    "calendar": source.get_display_name(),
                    "start": timestamp,
                    "allDay": bool(instance_start.is_date()),
                    "time": dt.datetime.fromtimestamp(timestamp).strftime("%H:%M"),
                })
                return True

            client.generate_instances_sync(start, end, None, collect, None)
        except GLib.Error:
            # Avoid putting provider responses or account details in shell logs.
            unavailable.append(source.get_display_name())
    events.sort(key=lambda event: (not event["allDay"], event["start"], event["title"]))
    return {"date": day.isoformat(), "events": events, "unavailable": unavailable}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("day", type=dt.date.fromisoformat)
    args = parser.parse_args()
    # A stalled provider must not leave the widget loading indefinitely.
    signal.alarm(20)
    try:
        result = read_day(args.day)
    except GLib.Error:
        result = {"date": args.day.isoformat(), "events": [], "error": "Calendar service unavailable"}
    print(json.dumps(result))


if __name__ == "__main__":
    main()
