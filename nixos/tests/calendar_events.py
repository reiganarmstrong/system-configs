"""Integration check against a private EDS/D-Bus session, not personal accounts.

Run with the calendar helper's GI environment and isolated XDG directories.
The only argument is the path to modules/home/calendar/events.py.
"""

import datetime as dt
import importlib.util
import os
import sys
import time

import gi

gi.require_version("EDataServer", "1.2")
gi.require_version("ECal", "2.0")
gi.require_version("ICalGLib", "3.0")
from gi.repository import ECal, EDataServer, ICalGLib  # noqa: E402

assert "calendar-test-" in os.environ.get("XDG_DATA_HOME", ""), "Use isolated calendar test data"
spec = importlib.util.spec_from_file_location("calendar_events", sys.argv[1])
events = importlib.util.module_from_spec(spec)
spec.loader.exec_module(events)

registry = EDataServer.SourceRegistry.new_sync(None)
source = EDataServer.Source.new_with_uid("desktop-calendar-integration-test", None)
source.set_display_name("Calendar integration test")
source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR).set_backend_name("local")
registry.commit_source_sync(source, None)
source = registry.ref_source(source.get_uid())
client = ECal.Client.connect_sync(source, ECal.ClientSourceType.EVENTS, 3, None)

day = dt.date(2026, 11, 5)
fixtures = [
    "SUMMARY:All-day fixture\nDTSTART;VALUE=DATE:20261105\nDTEND;VALUE=DATE:20261106",
    "SUMMARY:Recurring fixture\nDTSTART:20261104T150000Z\nDTEND:20261104T160000Z\nRRULE:FREQ=DAILY;COUNT=2",
    "SUMMARY:Boundary fixture\nDTSTART:20261104T230000Z\nDTEND:20261105T000000Z",
    "SUMMARY:Floating fixture\nDTSTART:20261105T090000\nDTEND:20261105T100000",
    "SUMMARY:Zoned fixture\nDTSTART;TZID=America/New_York:20261105T130000\nDTEND;TZID=America/New_York:20261105T140000",
    "SUMMARY:Next-day fixture\nDTSTART;VALUE=DATE:20261106\nDTEND;VALUE=DATE:20261107",
]
for index, fields in enumerate(fixtures):
    text = f"BEGIN:VEVENT\nUID:desktop-fixture-{index}\nDTSTAMP:20261101T000000Z\n{fields}\nEND:VEVENT\n"
    client.create_object_sync(ICalGLib.Component.new_from_string(text), ECal.OperationFlags.NONE, None)

result = events.read_day(day)
assert not result["unavailable"], result
assert [event["title"] for event in result["events"]] == [
    "All-day fixture", "Floating fixture", "Recurring fixture", "Zoned fixture"
], result
assert result["events"][0]["allDay"], result
assert result["events"][1]["time"] == "09:00", result
assert result["events"][2]["time"] == "15:00", result
assert result["events"][3]["time"] == "18:00", result
assert [e["title"] for e in events.read_day(day + dt.timedelta(days=1))["events"]] == ["Next-day fixture"]
print("PASS: local events, recurring instances, all-day ordering, and midnight boundaries")

os.environ["TZ"] = "America/New_York"
time.tzset()
for date, hours in [(dt.date(2026, 3, 8), 23), (dt.date(2026, 11, 1), 25)]:
    start, end = events.day_bounds(date)
    assert end - start == hours * 3600, (date, start, end)
print("PASS: local-day queries across daylight-saving changes")
result = events.read_day(day)
assert [event["title"] for event in result["events"]] == [
    "All-day fixture", "Floating fixture", "Recurring fixture", "Zoned fixture"
], result
assert [e["time"] for e in result["events"][1:]] == ["09:00", "10:00", "13:00"], result
print("PASS: floating times, explicit time zones, and all-day dates in the local zone")
