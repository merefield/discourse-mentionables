import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import domFromString from "discourse/lib/dom-from-string";
import { decorateMentionablePreviews } from "discourse/plugins/discourse-mentionables/discourse/lib/mentionable-previews";

module("Unit | Utility | mentionable previews", function (hooks) {
  setupTest(hooks);

  test("matches the cooked destination as well as the slug", function (assert) {
    this.owner.lookup("service:site").mentionable_items = [
      { slug: "book", name: "New book", url: "https://example.com/new" },
    ];
    const element = domFromString(`<div>
      <a class="mentionable-item" data-mentionable-slug="book" href="https://example.com/old"><span>Old book</span></a>
      <a class="mentionable-item" data-mentionable-slug="book" href="https://example.com/new"><span>New book</span></a>
      <a class="mentionable-item" href="https://example.com/new"><span>Legacy book</span></a>
    </div>`)[0];
    const registrations = [];
    let destroyed = 0;
    const tooltip = {
      register(anchor, options) {
        registrations.push({ anchor, options });
        return { destroy: () => destroyed++ };
      },
    };

    const cleanup = decorateMentionablePreviews(element, null, tooltip);

    assert.deepEqual(
      registrations.map(({ anchor, options }) => ({
        href: anchor.getAttribute("href"),
        url: options.data.url,
      })),
      [
        { href: "https://example.com/new", url: "https://example.com/new" },
        { href: "https://example.com/new", url: "https://example.com/new" },
      ],
      "old cooked links never receive the replacement item's preview"
    );
    assert.dom(element.querySelector("a")).hasText("Old book");
    cleanup();
    assert.strictEqual(destroyed, 2);
  });
});
