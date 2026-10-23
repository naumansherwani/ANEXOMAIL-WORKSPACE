
-- E79 proof: market key validator. Sandbox: E61 + constraint, E75, E78, phir E79. Har assert fail par exception.
do $$ begin
  assert public.awam_ui_extra_ok('{"market":true}'), 'true';
  assert public.awam_ui_extra_ok('{"market":false}'), 'false';
  assert not public.awam_ui_extra_ok('{"market":"true"}'), 'string';
  assert not public.awam_ui_extra_ok('{"market":0}'), 'number';
  assert not public.awam_ui_extra_ok('{"market":null}'), 'null (Rust deletes the key instead)';
  assert not public.awam_ui_extra_ok('{"market":{"on":true}}'), 'object';
  assert not public.awam_ui_extra_ok('{"market":[]}'), 'array';
  assert public.awam_ui_extra_ok('{"market":true,"clocks":["Asia/Karachi","America/New_York"]}'), 'with clocks';
  assert public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"},"market":false}'), 'with travel';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"},"market":true}'), 'bad travel still rejected';
  assert not public.awam_ui_extra_ok('{"home":{"country":"","iana":"Asia/Karachi","lat":1,"lon":1},"market":true}'), 'home hole stays closed';
  set local timezone = 'Pacific/Kiritimati';
  assert public.awam_ui_extra_ok('{"market":true}'), 'tz independent';
  assert not public.awam_ui_extra_ok('{"nope":1}'), 'unknown key';
  raise notice 'E79 proof ALL OK';
end $$;
