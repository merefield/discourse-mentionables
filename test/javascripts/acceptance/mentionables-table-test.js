import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Mentionables | admin table skeleton", function (needs) {
  needs.user({ admin: true, "user_option.composition_mode": 0 });
  needs.settings({
    mentionables_enabled: true,
    mentionables_pro_enabled: false,
    default_composition_mode: 0,
    allow_uncategorized_topics: true,
  });

  test("inserts the standard columns with an empty data row", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await click("button.insert-mentionables-table");

    assert.dom(".d-editor-preview table th").exists({ count: 4 });
    assert
      .dom(".d-editor-preview table thead")
      .hasText("name url slug image_url");
    assert.dom(".d-editor-preview table tbody tr").exists({ count: 1 });
  });
});
