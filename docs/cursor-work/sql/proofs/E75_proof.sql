
-- E75 proof: home key validator. Sandbox: E61 + constraint pehle, phir E75. Har assert fail par exception.
do $$ begin
  assert public.awam_ui_extra_ok('{"home":{"city":"Lahore","country":"Pakistan","iana":"Asia/Karachi","lat":31.52,"lon":74.36}}'), 'good home';
  assert not public.awam_ui_extra_ok('{"home":{"city":"","country":"","iana":"Asia/Karachi","lat":1,"lon":1}}'), 'empty city';
  assert not public.awam_ui_extra_ok('{"home":{"city":"X","country":"","iana":"Asia/Karachi","lat":91,"lon":1}}'), 'lat 91';
  assert not public.awam_ui_extra_ok('{"home":{"city":"X","country":"","iana":"A/../b","lat":1,"lon":1}}'), 'dotdot';
  assert public.awam_ui_extra_ok('{"clocks":["Asia/Karachi"]}'), 'old keys ok';
  assert not public.awam_ui_extra_ok('{"nope":1}'), 'unknown key';
  raise notice 'E75 proof ALL OK';
end $$;
