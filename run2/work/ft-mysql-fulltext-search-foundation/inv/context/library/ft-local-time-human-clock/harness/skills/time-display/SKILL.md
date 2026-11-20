---
name: time-display
description: Anatomy and consistency checks for changes to how Fizzy renders, caches or timezone-adjusts dates and times.
---

# Time display in Fizzy

The request (in the task text) decides the formats, the labels and which surfaces change. This skill tells you
where time already lives in this codebase and which places have to stay consistent with each other. Lines marked
"in this workspace" were read from the repository; confirm them with one `grep -n` before you edit and trust the file
if it disagrees.

## 1. Where time is rendered (in this workspace)

Display call sites found by `git grep -nE 'time_ago_in_words|distance_of_time|strftime|time_tag'`:

- `app/views/cards/comments/_comment.html.erb:18-19` (comment permalink: weekday, date and clock)
- `app/views/cards/container/_closure.html.erb:4` (closed on), `:16` (`time_ago_in_words(card.entropy.auto_clean_at)`, a FUTURE time)
- `app/views/cards/display/{common,preview,public_preview}/_meta.html.erb` (added / updated "… ago", 2 per file)
- `app/views/cards/display/common/_stamp.html.erb:6,9,19,22` (visible date AND `bridge_description:` for native)
- `app/helpers/bridge_helper.rb:25-29` `bridge_share_card_description` (strftime; read by `app/javascript/controllers/bridge/share_controller.js` through `bridgeAttribute("share-description")`)
- `app/models/user/day_timeline/column.rb:15` (column title), `app/views/events/_empty_days.html.erb:6,11` (calendar days)
- `app/views/events/day_timeline/_column.html.erb:15` (hour clock)
- `app/views/my/access_tokens/_access_token.html.erb:4`, `app/views/notifications/notification/_header.html.erb:17`,
  `app/views/searches/_result.html.erb:18`, `app/views/webhooks/_delivery.html.erb:6`
- **SaaS engine views count too:** `saas/app/views/admin/stats/show.html.erb:88` and
  `saas/app/views/my/devices/index.html.erb:17` (`time_ago_in_words … ago`). A grep limited to `app/` misses them.

Not display, leave as they are unless the request names them:
- `strftime("%Y-%m-%d")` in `app/helpers/pagination_helper.rb:54,59`, `app/views/users/_activity_timeline.html.erb:6`,
  `app/views/users/events/show.html.erb:9`: URL params and DOM ids.
- `*.json.jbuilder` `json.created_at x.utc`: API response shape.
- Mailers (`app/views/mailers/**`): no browser runs there. `distance_of_time_in_words(MagicLink::EXPIRATION_TIME)`
  is a duration, not a timestamp.

## 2. Pieces that already exist (in this workspace)

- `app/helpers/time_helper.rb` is an empty `module TimeHelper`. `User::DayTimeline::Column` already
  `include`s `TimeHelper` (column.rb:2). A server-side time tag helper belongs there, and the column can call it directly.
- `app/controllers/concerns/current_timezone.rb`: `around_action :set_current_timezone` (Time.use_zone from the
  `timezone` cookie that `timezone_cookie_controller.js` sets) and `etag { timezone_from_cookie }` at line 10.
  `test/controllers/concerns/current_timezone_test.rb` asserts that the ETag varies with the cookie. If you change the etag, change that test.
- `app/models/user/day_timeline.rb:45` builds its cache key with `Time.zone.name`, and the events controllers do
  `fresh_when @day_timeline`. The day timeline groups by `created_at.hour` (column.rb:22) and by server-side day
  boundaries, so it stays timezone-specific through its own key. Keep the `around_action` that sets the zone.
- `app/views/layouts/shared/_head.html.erb:14` emits `<meta name="timezone">`. `app/javascript/helpers/date_helpers.js`
  reads it (`getMetaContent("timezone")`), and `bubble_controller.js` uses `signedDifferenceInDays` from it for the
  entropy "Closes in N days" / "Stalled" bubble. These three move together: if the meta goes away, date_helpers must stop reading it and the bubble must still count days.
- `app/views/layouts/shared/_time_zone.html.erb` (rendered in `layouts/application.html.erb`) auto-submits the cookie
  zone to `my_timezone_path`, which stores `User::Settings#timezone_name`. `Notification::Bundle` (bundle.rb:40,
  `user.in_time_zone`) uses that zone for email. That is server-side behavior outside display. Preserve it.
- Fragment caches: `_comment.html.erb` starts with `<% cache comment do %>`, and `events/_event.html.erb` with `cache event`.
  Any time text inside a cached fragment is shared by every viewer.
- Entropy data: `app/helpers/entropy_helper.rb` passes `closesAt`, `lastActivitySpikeAt` and `updatedAt` as `iso8601`.
  `test/helpers/entropy_helper_test.rb` asserts those exact strings.
- JS: `config/importmap.rb` pins `app/javascript/helpers` under `helpers/…`, and `controllers/index.js` eager-loads every
  `*_controller.js`. A new `app/javascript/controllers/foo_bar_controller.js` is therefore `data-controller="foo-bar"` with no registration.

## 3. Artifact contract for moving rendering to the browser

Before finishing, confirm each item:

1. **Server output is timezone-neutral.** The helper emits `<time datetime="…UTC ISO8601…">` with the raw timestamp
   as fallback text and a format name in a data attribute. The test: the same helper call under two
   `Time.use_zone` blocks returns identical HTML (ActionView::TestCase in `test/helpers/time_helper_test.rb`).
2. **Calendar-day values stay calendar days.** `day_timeline.day`, `earliest` and `latest` are already days in the
   user's zone. Emit `YYYY-MM-DD` and build the JS date as `new Date(y, m - 1, d)`, because `new Date("YYYY-MM-DD")` is UTC midnight and shows the previous day west of UTC.
3. **One formatter, every surface.** HTML views, the `_stamp` `bridge_description` and the share description in
   `bridge_helper.rb` all go through the same JS formatter. Keep existing public helper names
   (`bridge_share_card_description`, `bridged_share_url_button`) and their call sites. Change what they emit, not what they are called.
4. **Relative words are computed by local calendar day** (today, then clock time; difference of 1 day, then "yesterday"/"tomorrow";
   a few days, then "N days ago"/"in N days"; older, then a short date with the year only when it differs). A future value
   such as `auto_clean_at` needs the future direction. The phrasing in the request is the specification.
5. **Casing survives CSS.** `app/assets/stylesheets/comments.css:177` gives `.comment__permalink-title` the rule
   `text-transform: capitalize` ("yesterday" would render as "Yesterday", "5 days ago" as "5 Days Ago").
   `_empty_days.html.erb` spans carry `txt-capitalize`. `cards.css:441` `.card__closed-date` and `cards.css:519`
   `.card__notification-meta` are uppercase. For each converted site, decide whether the request's literal
   wording has to show and adjust the class or rule if so.
6. **Caching claim holds.** No `Time.zone`-dependent string remains inside `cache …` fragments you touched. If the
   concern's global etag is removed, the day timeline still varies by zone via day_timeline.rb:45.
7. **Coverage grep.** `git grep -nE 'time_ago_in_words|distance_of_time|strftime' -- app saas/app` now lists only
   the section-1 exceptions.
8. **Tests.** Helper tests go in `test/helpers/` (ActionView::TestCase). Browser formatting goes in a system test under
   `test/system/` that subclasses `ApplicationSystemTestCase` (headless Chrome, `sign_in_as(users(:david))`).
   `page.driver.browser.execute_cdp("Emulation.setTimezoneOverride", timezoneId: "America/Los_Angeles")` works here. Run
   system tests by explicit path (`bin/rails test test/system/<file>.rb`) as well as `bin/rails test`. Update
   existing tests whose assertions you intentionally changed (current_timezone_test, entropy_helper_test).
