import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import MentionablesAdmin from "discourse/plugins/discourse-mentionables/discourse/components/mentionables-admin";

function logsForPage(page, count = 100) {
  return Array.from({ length: count }, (_, index) => ({
    type: "info",
    source: `source-${page * 100 + index}`,
    message: "Imported",
    date: "2026-10-19T09:00:00Z",
  }));
}

module("Integration | Component | mentionables admin", function (hooks) {
  setupRenderingTest(hooks);

  test("keeps pagination intact after failed refresh and load-more requests", async function (assert) {
    this.data = { logs: logsForPage(0), info: { total: 1 } };
    const alert = sinon.stub(this.owner.lookup("service:dialog"), "alert");
    let failNextRequest = false;
    const requestedPages = [];

    pretender.get("/admin/plugins/mentionables/logs.json", (request) => {
      const page = Number(request.queryParams.page);
      requestedPages.push(page);
      if (failNextRequest) {
        failNextRequest = false;
        return response(500, { errors: ["Temporary failure"] });
      }
      return response({
        logs: logsForPage(page, page === 2 ? 1 : 100),
        info: { total: 1 },
      });
    });

    await render(
      <template><MentionablesAdmin @data={{this.data}} /></template>
    );
    await click(".mentionables-load-more");
    assert.dom("tbody tr").exists({ count: 200 });

    failNextRequest = true;
    await click(".mentionables-refresh");
    assert.true(alert.calledOnce, "shows the failed refresh error");
    assert.dom("tbody tr").exists({ count: 200 });

    await click(".mentionables-load-more");
    assert.dom("tbody tr").exists({ count: 201 });
    assert.dom("tbody tr:last-child td:nth-child(2)").hasText("source-200");
    assert.dom(".mentionables-load-more").doesNotExist();

    await click(".mentionables-refresh");
    assert.dom("tbody tr").exists({ count: 100 });

    failNextRequest = true;
    await click(".mentionables-load-more");
    assert.true(alert.calledTwice, "shows the failed load-more error");
    assert.dom("tbody tr").exists({ count: 100 });

    await click(".mentionables-load-more");
    assert.dom("tbody tr").exists({ count: 200 });
    assert.dom("tbody tr:last-child td:nth-child(2)").hasText("source-199");
    assert.deepEqual(requestedPages, [1, 0, 2, 0, 1, 1]);
  });
});
