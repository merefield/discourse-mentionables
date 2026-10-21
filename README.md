# Discourse Mentionables

Mentionables turns a table in a Discourse topic into a dataset people can mention. Its
items are searchable in the composer using `+`. Selecting a suggestion links to
the item's URL, using its name as the visible label. Autocomplete works in both
the Markdown and rich text composers.

[Source code](https://github.com/merefield-pro-extensions/discourse-mentionables)
and [issue tracker](https://github.com/merefield-pro-extensions/discourse-mentionables/issues)
require access to this private repository.

For a forum-ready introduction, see [intro-post.md](intro-post.md).

## See it in action

Type `+` in either composer to find a resource without remembering its URL:

![Mentionables autocomplete in the Markdown composer](docs/images/composer-autocomplete.png)

Inline pills keep a sentence readable. A mention on its own line uses a native
onebox, and hovering an inline pill on desktop opens a floating preview:

![Inline pills, a native onebox, and a floating preview](docs/images/onebox-preview.png)

Admins maintain the catalogue in a topic's opening post, then import it from the
Mentionables management page:

![A sample source topic with a mentionables table](docs/images/source-table.png)

![A successful import of three sample mentionables](docs/images/import-report.png)

These are screenshots of the running plugin using fictional community resources
from [test fixtures](spec/fixtures/documentation/mentionables.md). The onebox
response is a local HTML fixture; no external account is required. See
[screenshot capture instructions](docs/screenshots.md) to reproduce them.

## Install the plugin

Follow the [Discourse plugin installation guide](https://meta.discourse.org/t/install-plugins-on-a-self-hosted-site/19157).
For a standard self-hosted installation, add this command to the existing plugin
clone commands under `hooks` → `after_code` in
`/var/discourse/containers/app.yml`:

```yaml
- git clone https://github.com/merefield-pro-extensions/discourse-mentionables.git
```

Configure Git authentication with read access to this private repository as
described in the installation guide, so the container can clone it during a
rebuild. Then rebuild Discourse:

```sh
cd /var/discourse
./launcher rebuild app
```

For a hosted Discourse site, ask your hosting provider about installing custom
private plugins.

This version was tested with Discourse `2026.10.0-latest`, core commit
`5370a6c4fed981028109defb1dace786f1807791`, and Ruby 3.4.

## Set up a topic table

The base plugin imports from a Markdown table in a topic's **opening post**.
No external account, API key, or source selector is needed.

1. Create a topic for your mentionables dataset. It can be public or in a
   restricted category such as Staff.
2. Edit the opening post and use the admin-only **Insert mentionables table**
   composer button, or paste the example below. The button works in both the
   Markdown and rich text composers and inserts an empty row to fill in.
3. Add one item per row, then save the post.
4. Set `mentionables_topic_id` to the topic's numeric ID and make sure
   `mentionables_enabled` is enabled. In `/t/topic-title/123/1`, the topic ID is
   `123`; the final `1` is a post number.
5. Start an import from the Mentionables management page as described below.

The importer reads the current opening post and uses the first unquoted table
with a lowercase `url` header. Other tables, replies, quoted tables, and code
samples are ignored. Personal messages and deleted topics or opening posts
cannot be used as sources. Column headers must match the names below; each
imported column may appear only once. Unknown columns are ignored.

### Table columns

The smallest valid source is a one-column table:

```markdown
| url                      |
| ------------------------ |
| https://example.com/book |
```

Add any of these columns when you want to supply your own values:

| Column        | Purpose                                                                                                       |
| ------------- | ------------------------------------------------------------------------------------------------------------- |
| `name`        | Optional display label. If omitted, retrieve it from the destination; use the URL when no title is available. |
| `url`         | Required, unique destination URL and sync key, beginning with `http://` or `https://`.                        |
| `slug`        | Optional unique identifier used in post markdown, such as `+example-book`. Use a stable value without spaces. |
| `image_url`   | Optional image URL shown with autocomplete suggestions.                                                       |
| `description` | Optional description stored with the item.                                                                    |

```markdown
| name         | url                      | slug         | image_url                    |
| ------------ | ------------------------ | ------------ | ---------------------------- |
| Example book | https://example.com/book | example-book | https://example.com/book.png |
```

URL and image cells can contain a plain URL or a Markdown link. Text cells use
their rendered text, so emphasis is removed and escaped pipes are supported.
Entirely empty rows are skipped. The same advanced stored metadata columns as
other sources are accepted: `affiliate_snippet_1`, `affiliate_snippet_2`, and
`affiliate_snippet_3`.

**URL is the only required field.** A table containing just a lowercase `url`
column is valid. You can mix URL-only rows with rows supplying a `name`, a `slug`,
or both. Supplied values take precedence over automatic metadata retrieval.

For new URLs, a missing name is retrieved through Discourse's onebox support,
falling back to the URL itself if there is no usable title. A missing slug is
generated from the resulting name; collisions receive a suffix. For an existing
URL, an omitted slug preserves its current value even if its name changes.
Explicit slugs must be unique, at most 200 characters, begin and end with a
letter or number, and use only letters, numbers, dots, underscores, or hyphens.
Choose a shorthand such as `iss` to override an automatically generated slug.

`mentionables_onebox_fallback` additionally fills missing image and description
fields when a name is already supplied. It is off by default. Missing names are
always retrieved automatically; providing a name avoids that request. The old
`mentionables_generate_slugs` setting has been retired.

### Source visibility

**Restricting the source topic controls who can read and maintain that topic;
it does not restrict the imported dataset.** Imported names, destination URLs,
and images are available to users of mentionables, including through the site
payload. Keep private staff notes outside the table and let only trusted people
edit the source post. Normal users do not need access to the source topic to
use imported items. The source topic ID and its other contents are not exposed
by this plugin.

### Pro sources and presentation

The separately installed **Discourse Mentionables Pro Extension** adds Google
Sheets imports and the `mentionables_source` selector. It also adds `icon` and
`icon_colour` columns to both topic tables and spreadsheets, and an optional
click-to-preview interaction. A new Pro installation also defaults to topic
tables; existing configured Google imports retain their selection on upgrade.

| Feature                                                | Basic Mentionables |       With Pro extension       |
| ------------------------------------------------------ | :----------------: | :----------------------------: |
| Topic-table imports and an admin table skeleton button |        Yes         |              Yes               |
| `+` autocomplete in both composers                     |        Yes         |              Yes               |
| Inline pills and native standalone oneboxes            |        Yes         |              Yes               |
| Desktop floating previews on hover or focus            |        Yes         | Yes, in the default hover mode |
| Google Sheets imports and a source selector            |         —          |              Yes               |
| Automatic sync with the selected source every 12 hours |         —          |    Optional, off by default    |
| Optional coloured icons from either import source      |         —          |              Yes               |
| Click or tap to open previews on desktop and touch     |         —          |            Optional            |

Pro requires the base plugin to be installed alongside it.

## Import and use your data

1. Open **Admin → Plugins → Mentionables**, at
   `/admin/plugins/discourse-mentionables/mentionables`.
2. Click **Start Import**. Imports run as background jobs, so Discourse's job
   worker must be running.
3. Click **Refresh** to see updated counts and the import report. Review any
   errors before continuing.
4. Reload the browser page after the import so the composer loads the new items.
5. Open a composer and type `+` followed by part of an item's name or slug, or use the
   plus toolbar button. Select an autocomplete suggestion to insert the mention.

`mentionables_autocomplete_limit` controls the maximum number of suggestions
and defaults to five. Mentions inside code spans and code blocks are left alone.

### Search by name or slug

Autocomplete searches both the item's display name and its slug, matching any
part of either value without regard to case. A short slug provides a convenient
shorthand for a longer name.

For example, import an item with `name` set to **International Space Station**
and `slug` set to `iss`. Typing `+iss`, `+ISS`, or `+station` finds the same
record. The suggestion displays **International Space Station**; selecting it
inserts `+iss`, which renders using the full display name.

This works in both Basic Mentionables and the Pro extension, in both composers.
Each item has one slug, which is its identifier in post Markdown. Choose it
before importing and keep it stable once people are using it in posts.

### Oneboxes and floating previews

Put a mention on its own line to render the destination using Discourse's normal
onebox templates. Inline mentions stay as pills. Onebox limits, caching, supported
destinations, and layout are handled by Discourse. If the destination cannot be
oneboxed, it remains a link. Mentions in lists and quotes remain inline pills.

On desktop, hover or focus an inline pill to open a floating onebox preview.
The preview stays open while you move into it and includes an **Open original
page** link. Press Escape or click outside to dismiss it. Normal pill clicks
still open the destination. The core preview endpoint requires login; guests
see the destination link without a fetched card.

The separately installed **Discourse Mentionables Pro Extension** adds optional
`icon` and `icon_colour` table or spreadsheet columns and a
`mentionables_pro_click_to_preview` setting. That setting opens the floating
preview on click or tap, on both desktop and touch devices, instead of navigating
directly from the pill. Core onebox layouts remain unchanged.

### Import changes to your dataset

**Every import synchronizes the entire catalogue with the selected source, keyed
by URL.** Matching URLs update the existing record without changing its ID; new
URLs create records; URLs absent from the source delete their records. The URL
comparison is exact after trimming surrounding whitespace. Changing a URL
therefore replaces a record. Source selection and worksheet selection define
the whole catalogue, rather than separate collections that accumulate.

Optional fields reflect the current source: removing an image, description, or
Pro style clears it, unless automatic metadata retrieval supplies a replacement.
Omitting a slug preserves the existing one; supplying a different slug changes
it and can break previously written `+slug` references. Old datasets with repeated
URLs are consolidated to one record per URL, preferring a record matching an
explicit slug, otherwise the oldest record.

The complete source is fetched and validated before synchronization. Invalid
URLs or slugs, duplicate source URLs or explicit slugs, fetch errors, and empty
datasets leave the existing catalogue unchanged. Database changes are atomic;
imports and explicit deletion share a lock. Reports list created, updated,
unchanged, and deleted counts. **Delete all** remains available for an intentional
clear; deleting data never changes the source topic or spreadsheet.

Reload the browser after import to load the updated catalogue. Previously cooked
posts retain their rendered links until rebaked; sync does not automatically
rewrite old posts. With Pro installed, enable `mentionables_pro_sync_enabled`
to run this same import automatically every 12 hours. It defaults to off.

### Troubleshooting

- **Source topic not found:** check `mentionables_topic_id`, that the topic
  and opening post are undeleted, and that it is not a personal message.
- **No table found:** put the table in the opening post, use the lowercase `url`
  header, and keep the table outside quotes and code blocks.
- **Missing rows or fields:** check the headers, required URLs, and
  import report. Only the first matching table in the opening post is used.
  Entirely empty rows are skipped. Duplicate URLs or explicit slugs abort the
  entire import. An empty source also aborts; use Delete all to clear intentionally.
- **Import stays pending:** check that Discourse's background job worker is
  running, then refresh the management page.
- **No composer suggestions after import:** reload the browser, confirm that
  items were imported and `mentionables_enabled` is on, and check that
  `mentionables_autocomplete_limit` is greater than zero.

## Development and checks

Use Node 22 or later and pnpm 10. The flat ESLint, Prettier, and Stylelint configs
inherit from `@discourse/lint-configs`; tool versions match its peer requirements.
Ruby uses `rubocop-discourse` and Syntax Tree. The shared Discourse plugin CI
workflow runs linting, backend, frontend, and browser system tests automatically.

The base plugin has no Google SDK dependency. External source integrations and
their runtime dependencies belong in the Pro extension.

From this plugin checkout:

```sh
pnpm install --frozen-lockfile
bundle install
pnpm lint
bundle exec rubocop
bundle exec stree check Gemfile $(git ls-files '*.rb')
```

Symlink the checkout into a current Discourse installation's `plugins` directory.
From the Discourse checkout:

```sh
LOAD_PLUGINS=1 RAILS_ENV=test bin/rails db:migrate
pnpm build
LOAD_PLUGINS=1 RAILS_ENV=test bin/rails runner 'Plugin::JsManager.new.compile_js_bundle(Discourse.plugins_by_name.fetch("discourse-mentionables"))'
LOAD_PLUGINS=1 bin/rspec plugins/discourse-mentionables/spec
LOAD_PLUGINS=1 bin/qunit --standalone --target discourse-mentionables
```

System specs cover importing a staff topic table, inserting skeletons in both
composers, inspecting reports and errors, deleting
data, loading older logs, refreshing counts, publishing mentions from both
composers, preserving code spans, and disabling the feature. Request specs cover
administrator access and safe filtering. The base tests use local topic tables and require no external credentials.

### Extension hooks

Extensions can use these Discourse events without patching the importer:

| Event                              | Arguments and purpose                                                                                                                      |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `mentionables_ready`               | Base classes and hooks are available. Extensions should also handle the base already being initialized.                                    |
| `mentionables_select_source`       | Replace `selection[:source_class]` with an extension source class; the default is `Mentionables::TopicTable`.                              |
| `mentionables_import_columns`      | Append accepted header strings to the columns array.                                                                                       |
| `mentionables_prepare_import_item` | Transform the validated item hash and supplied existing/new record before synchronization, for example into nested association attributes. |
| `mentionables_preload_items`       | Append association names to eager-load for client serialization.                                                                           |
| `mentionables_serialize_item`      | Add client attributes to the attributes hash for the supplied item.                                                                        |
| `mentionables_decorate_link`       | Decorate the supplied item's inline anchor after its label is built. Standalone oneboxes use core layout.                                  |

On the frontend, use `api.registerValueTransformer` with
`mentionables-item-label` to decorate the label element (`context.item` is the
item), or `mentionables-click-to-preview` to return whether an inline pill opens
a preview on click. The base plugin registers these names before the transformer
registry is frozen.

The `mentionables-table-columns` frontend transformer extends the headers in the
admin composer skeleton. The default headers are `name`, `url`, `slug`, and
`image_url`; Pro appends `icon` and `icon_colour`.
