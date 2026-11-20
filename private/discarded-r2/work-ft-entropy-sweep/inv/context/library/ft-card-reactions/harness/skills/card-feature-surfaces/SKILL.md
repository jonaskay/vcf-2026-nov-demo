# Card feature surfaces (Fizzy)

Use this when a change gives cards a new child record or behavior, or extends a comment-level feature (reactions, etc.) to cards.
Lines marked "in this workspace" were seen in this repository. Re-check them with `grep -n` before you rely on them.
The request decides names, labels and behavior. Nothing here renames anything the request specifies.

## 1. Find the sibling first. It is the specification.
Extend the existing comment-level implementation into a card-level twin that behaves the same in every respect the request does not change.
In this workspace the comment-reaction stack consists of:
- model `app/models/reaction.rb` (`belongs_to :account, default: -> { comment.account }`, `belongs_to :comment, touch: true`, `after_create :register_card_activity`) and `app/models/comment.rb` (`has_many :reactions, -> { order(:created_at) }, dependent: :delete_all`; `scope :preloaded ... includes(reactions: :reacter)`)
- controller `app/controllers/cards/comments/reactions_controller.rb` (`wrap_parameters :reaction`, `include CardScoped`, index/new/create/destroy, turbo_stream plus json, `head :forbidden` unless the reacter is the current user)
- route `config/routes.rb` (~line 103): `resources :comments do resources :reactions, module: :comments end`, inside `resources :cards do scope module: :cards`
- views `app/views/cards/comments/reactions/*` (`_reactions`, `_reaction`, `_menu`, `new`, `index`, `create.turbo_stream`, `destroy.turbo_stream`, `*.json.jbuilder`). Turbo frame ids are `dom_id(comment, :reacting)` and `dom_id(comment, :new_reaction)`.
- JSON link `app/views/cards/comments/_comment.json.jbuilder` (`json.reactions_url ...`)
- tests `test/controllers/cards/comments/reactions_controller_test.rb`, `test/models/reaction_test.rb`, `test/controllers/api/flat_json_params_test.rb`
Before you finish, make sure the card-level change has a counterpart for every bullet: model, controller, route, views, JSON link and tests. The `url` of each reaction JSON must point to the card route for card records and to the comment route for comment records.

Comment behavior must stay as it is. Prefer adding card-level files beside the comment ones over refactoring the comment stack; if you do share partials, keep the comment frame ids, the `cards/comments/reactions/...` render paths the tests use, and the existing JSON keys.

## 2. Data model decision (state your choice in your reasoning)
Trigger: an existing child table has a required `comment_id` and must also belong to cards.
Evidence in this workspace:
- polymorphic parents are idiomatic: `app/models/concerns/eventable.rb` (`has_many :events, as: :eventable`), `concerns/mentions.rb`, `concerns/notifiable.rb`, `event.rb` (`belongs_to :eventable, polymorphic: true`)
- a dual optional-FK precedent exists too: `app/models/search/result.rb` (`belongs_to :card ... optional: true`, `belongs_to :comment ... optional: true`)
- `app/models/account/data_transfer/manifest.rb` exports `::Reaction`; `record_set.rb` handles `belongs_to` keys and polymorphic `*_type` values generically, so either design is handled.
Either design is acceptable. Their obligations differ:
- polymorphic: backfill `'Comment'` for existing rows in the migration, update every `reaction.comment` / `comment_id` caller (`grep -rn "reaction\.comment\|comment_id" app test`), add `as:` on `Comment.has_many :reactions`.
- additive (nullable `card_id` and nullable `comment_id`): validate that exactly one parent is set, keep `belongs_to :comment` working, use `default: -> { comment&.account || card&.account }`.
In both cases the activity hook must still call `card.touch_last_active_at` for card records. `app/models/card.rb` defines a `card` method; read it before you write `is_a?` branches.

## 3. Migration and schema
If the change needs a migration, run `cat /opt/harness/skills/db-migration/SKILL.md` and follow it (two schema files, `cable_schema.rb` noise, no foreign keys, uuid ids).

## 4. Where a card behavior shows up (checklist)
Card detail, in this workspace: `app/views/cards/show.html.erb` renders `cards/container` and then `cards/messages`. `_messages.html.erb` wraps its content in `if card.published?`. `app/controllers/concerns/card_scoped.rb` re-renders `cards/container` via morph after card actions, so a control placed in `_container` is re-rendered by those actions. Gate it on `card.published?` the same way the messages are gated.
- `--reaction-size` is defined only in `app/assets/stylesheets/comments.css`. Reactions rendered outside a comment need that variable defined in their new context (e.g. `card-perma.css`).

Card previews, in this workspace:
- the indicator to mirror is `app/views/cards/display/preview/_comments.html.erb` (`.card__comments` div, `icon_tag "comment"`, `<strong>count</strong>`, rendered only when there are any). It is computed live; there is no counter column, so do not add a counter-cache migration.
- previews render in TWO templates: `cards/display/_preview.html.erb` (boards/columns, `cards/index`, the pins tray, `cards/previews/index.turbo_stream.erb`) and `cards/display/_public_preview.html.erb` (published boards). Put the indicator in both.
- every CSS rule that names `.card__comments` needs the new class too, including `trays.css` (hidden in the pins tray). Run `grep -rn "card__comments" app/assets/stylesheets` and handle each hit.
- caching: previews render with `cached: true` keyed on the card, `cards/_card.json.jbuilder` uses `json.cache! card`, `My::PinsController` uses `fresh_when`. A new child that changes what a preview shows must `touch: true` the card, or counts go stale.
- preloading: `Card.preloaded` (`app/models/card.rb`) feeds the main boards. `.size` on an association that is not preloaded is a query.

API, in this workspace: `cards/_card.json.jbuilder` ends with `json.comments_url card_comments_url(card)`. A card-level resource gets the matching `*_url` key; `test/controllers/cards_controller_test.rb` ("show as JSON") asserts these URLs. `docs/api/` exists: `grep -rln reaction docs/api` and document card endpoints next to any comment ones you find.

## 5. Authorization and gating
`Cards::CommentsController` has `before_action :ensure_card_is_commentable, only: :create`. A comment-level child is reachable only through a comment that passed this gate; a card-level child is not. Reproduce the gate for card-level creation so drafts behave as they do for comments. Keep the sibling's ownership rule (`head :forbidden if Current.user != @reaction.reacter`) and its scoped lookup (`@card.reactions.find`).

## 6. Tests
- copy the structure of the sibling test file: index, new, create via turbo_stream (`assert_turbo_stream action: :replace, target: dom_id(card, :reacting)`), destroy, non-owner forbidden, JSON index/create/destroy, flat JSON params.
- integration tests have no `Current.user`. Pass `reacter: users(:david)` explicitly, or the create fails with "Reacter must exist". Model tests set `Current.session = sessions(:david)` in `setup`.
- add a detail-view assertion and a preview assertion: indicator absent at 0 and showing the number when greater than 0, in both the board column and the public column (`get public_board_column_path(board.publication.key, column)`).
- run the full suite (`bin/rails test`, ~20 s) after the schema change.
