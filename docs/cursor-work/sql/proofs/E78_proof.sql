
-- E78 proof: travel key validator. Sandbox: E61 + constraint pehle, phir E75, phir E78. Har assert fail par exception.
do $$ begin
  assert public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"}}'), 'good trip';
  assert public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-26T14:00:00Z"}}'), 'exactly 72h';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-26T14:00:01Z"}}'), '72h+1s';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T14:00:00Z"}}'), 'zero length';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T23:00:00Z","arrive_at":"2026-10-23T14:00:00Z"}}'), 'reversed';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"}}'), 'empty city';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"A/../b","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"}}'), 'dotdot';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-02-30T14:00:00Z","arrive_at":"2026-03-01T14:00:00Z"}}'), 'feb 30';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00+05:00","arrive_at":"2026-10-23T23:00:00Z"}}'), 'offset time';
  assert not public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z"}}'), 'missing arrive';
  assert not public.awam_ui_extra_ok('{"travel":"Tokyo"}'), 'string';
  assert not public.awam_ui_extra_ok('{"home":{"country":"","iana":"Asia/Karachi","lat":1,"lon":1}}'), 'home without city (old hole)';
  assert public.awam_ui_extra_ok('{"home":{"city":"X","iana":"Asia/Karachi","lat":1,"lon":1}}'), 'home without country is fine (Rust allows it)';
  -- the session time zone must never change the answer
  set local timezone = 'Pacific/Kiritimati';
  assert public.awam_ui_extra_ok('{"travel":{"to_city":"Tokyo","to_zone":"Asia/Tokyo","depart_at":"2026-10-23T14:00:00Z","arrive_at":"2026-10-23T23:00:00Z"}}'), 'tz independent';
  assert public.awam_ui_extra_ok('{"clocks":["Asia/Karachi"],"home":{"city":"X","country":"","iana":"Asia/Karachi","lat":1,"lon":1}}'), 'old keys ok';
  assert not public.awam_ui_extra_ok('{"nope":1}'), 'unknown key';
  raise notice 'E78 proof ALL OK';
end $$;
