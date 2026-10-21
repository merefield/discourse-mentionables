import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance("Mentionables | composer", function (needs) {
  needs.user({ admin: false, "user_option.composition_mode": 0 });
  needs.settings({
    mentionables_enabled: true,
    default_composition_mode: 0,
    allow_uncategorized_topics: true,
    max_oneboxes_per_post: 5,
  });
  needs.site({
    mentionable_items: [
      {
        id: 1,
        name: "Example book",
        slug: "example-book",
        url: "https://example.com/book",
      },
    ],
  });
  let oneboxRequests;
  needs.pretender((server) => {
    oneboxRequests = [];
    server.get("/onebox", (request) => {
      oneboxRequests.push(request.queryParams);
      return [
        200,
        { "Content-Type": "text/html" },
        '<aside class="onebox"><article class="onebox-body"><h3>Book preview</h3></article></aside>',
      ];
    });
  });

  test("previews exact mention links", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Recommended reading");
    assert.dom("button.insert-mentionables-table").doesNotExist();
    await fillIn(".d-editor-input", "Read +example-book. And +unknown.");
    assert
      .dom(".d-editor-preview a.mentionable-item")
      .hasAttribute("href", "https://example.com/book")
      .hasText("Example book");
    assert.dom(".d-editor-preview span.mentionable-item").hasText("+unknown");
    assert
      .dom(".d-editor-preview p")
      .hasText("Read Example book. And +unknown.");
  });

  test("uses core oneboxes for standalone lines and pills for inline mentions", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Recommended reading");
    await fillIn(".d-editor-input", "+example-book\n\nRead +example-book.");

    assert.dom(".d-editor-preview aside.onebox h3").hasText("Book preview");
    assert.dom(".d-editor-preview a.mentionable-item").hasText("Example book");
  });

  test("keeps a cached mention onebox after composer edits", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Recommended reading");
    await fillIn(".d-editor-input", "+example-book");
    assert.dom(".d-editor-preview aside.onebox h3").hasText("Book preview");
    assert.strictEqual(oneboxRequests.length, 1);

    await fillIn(
      ".d-editor-input",
      "+example-book\n\nAn updated recommendation."
    );
    assert.dom(".d-editor-preview aside.onebox h3").hasText("Book preview");
    assert.dom(".d-editor-preview a.onebox").doesNotExist();
    assert.strictEqual(oneboxRequests.length, 1, "reuses the loaded template");
  });

  test("passes the replied-to topic to the core onebox loader", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click("#topic-footer-buttons .btn.create");
    await fillIn(".d-editor-input", "+example-book");

    assert.dom(".d-editor-preview aside.onebox h3").hasText("Book preview");
    assert.strictEqual(oneboxRequests[0].topic_id, "280");
  });

  test("restores every occurrence of a cached URL within a single onebox slot", async function (assert) {
    this.siteSettings.max_oneboxes_per_post = 1;
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Recommended reading");
    await fillIn(".d-editor-input", "+example-book\n\n+example-book");
    assert.dom(".d-editor-preview aside.onebox").exists({ count: 2 });
    const initialRequests = oneboxRequests.length;

    await fillIn(
      ".d-editor-input",
      "+example-book\n\n+example-book\n\nAn updated recommendation."
    );
    assert.dom(".d-editor-preview aside.onebox").exists({ count: 2 });
    assert.dom(".d-editor-preview a.onebox").doesNotExist();
    assert.strictEqual(
      oneboxRequests.length,
      initialRequests,
      "does not refetch after editing"
    );
  });
});

acceptance("Mentionables | restricted category oneboxes", function (needs) {
  const handbookUrl = `${window.location.origin}/t/staff-handbook/101`;
  const ordinaryUrl = `${window.location.origin}/t/staff-calendar/102`;
  let oneboxRequests;

  needs.user({ "user_option.composition_mode": 0 });
  needs.settings({
    mentionables_enabled: true,
    default_composition_mode: 0,
    allow_uncategorized_topics: true,
    enable_markdown_linkify: true,
    max_oneboxes_per_post: 2,
  });
  needs.site({
    categories: [
      {
        id: 1,
        name: "General",
        slug: "general",
        permission: 1,
      },
      {
        id: 42,
        name: "Staff resources",
        slug: "staff-resources",
        color: "0088cc",
        text_color: "ffffff",
        read_restricted: true,
        permission: 1,
      },
    ],
    mentionable_items: [
      {
        id: 1,
        name: "Staff handbook",
        slug: "staff-handbook",
        url: handbookUrl,
      },
    ],
  });
  needs.pretender((server) => {
    oneboxRequests = [];
    server.get("/onebox", (request) => {
      oneboxRequests.push(request.queryParams);
      if (request.queryParams.category_id !== "42") {
        return [403, { "Content-Type": "text/html" }, "Forbidden"];
      }
      const title =
        request.queryParams.url === handbookUrl
          ? "Staff handbook preview"
          : "Staff calendar preview";
      return [
        200,
        { "Content-Type": "text/html" },
        `<aside class="onebox"><article class="onebox-body"><h3>${title}</h3></article></aside>`,
      ];
    });
  });

  test("previews mentions and ordinary links with their restricted category", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Staff resources to keep handy");
    await selectKit(".category-chooser").expand();
    await selectKit(".category-chooser").selectRowByValue(42);
    await fillIn(".d-editor-input", `+staff-handbook\n\n${ordinaryUrl}`);

    assert.dom(".d-editor-preview aside.onebox").exists({ count: 2 });
    assert.dom(".d-editor-preview").includesText("Staff handbook preview");
    assert.dom(".d-editor-preview").includesText("Staff calendar preview");
    assert.deepEqual(
      oneboxRequests.map(({ url, category_id }) => ({ url, category_id })),
      [
        { url: handbookUrl, category_id: "42" },
        { url: ordinaryUrl, category_id: "42" },
      ]
    );
  });

  test("keeps cached mentions within the core onebox limit", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn("#reply-title", "Staff resources to keep handy");
    await selectKit(".category-chooser").expand();
    await selectKit(".category-chooser").selectRowByValue(42);
    await fillIn(".d-editor-input", `+staff-handbook\n\n${ordinaryUrl}`);
    assert.dom(".d-editor-preview aside.onebox").exists({ count: 2 });

    this.siteSettings.max_oneboxes_per_post = 1;
    await fillIn(
      ".d-editor-input",
      `+staff-handbook\n\n${ordinaryUrl}\n\nUpdated.`
    );

    assert.dom(".d-editor-preview aside.onebox").exists({ count: 1 });
    assert
      .dom(".d-editor-preview aside.onebox h3")
      .hasText("Staff calendar preview");
    assert.dom(".d-editor-preview a.onebox").hasAttribute("href", handbookUrl);
    assert.strictEqual(
      oneboxRequests.length,
      2,
      "does not fetch beyond the limit"
    );
  });
});
