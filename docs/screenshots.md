# Reproduce the documentation screenshots

The README and [intro post](../intro-post.md) use real browser screenshots from
the `Document mentionables` system spec. Its disposable test data represents a
fictional community catalogue, with three rows in
[mentionables.md](../spec/fixtures/documentation/mentionables.md) and a stubbed
[handbook destination](../spec/fixtures/documentation/handbook.html).

The scenario imports the table as an administrator, inspects the report, then
signs in as a regular member to preview the resources and use autocomplete. It
asserts the visible results before capturing each screen. The Pro extension is
disabled for this scenario so the images show the base plugin's behaviour.

Use a current Discourse development checkout with the plugin symlinked into
`plugins/discourse-mentionables`, a prepared **test** database, built frontend
assets, and Discourse's Playwright browser installed. From the Discourse root:

```sh
MENTIONABLES_SCREENSHOTS=1 LOAD_PLUGINS=1 bin/rspec plugins/discourse-mentionables/spec/system/document_mentionables_spec.rb
```

The spec writes these PNGs into this plugin's `docs/images/` directory:

- `source-table.png`: the catalogue in a topic's opening post.
- `import-report.png`: three successfully imported items.
- `onebox-preview.png`: inline mentions, a standalone onebox, and a hover preview.
- `composer-autocomplete.png`: suggestions in the Markdown composer.

Without `MENTIONABLES_SCREENSHOTS=1`, the same spec verifies the workflow without
overwriting the screenshots. It uses the test database and leaves the development
catalogue unchanged. Review regenerated images before committing them.

When publishing `intro-post.md` on a forum, upload these images with the post and
replace the relative Markdown image paths with Discourse's uploaded-image links.
Repository-relative links work when viewing the documents in the repository.
