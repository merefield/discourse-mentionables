import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n, i18n as translate } from "discourse-i18n";

const PATH = "/admin/plugins/mentionables/logs.json";

export default class MentionablesAdmin extends Component {
  @tracked logs;
  @tracked info;
  @tracked loading = false;
  @tracked message;
  @tracked canLoadMore;
  #page = 0;

  constructor(owner, args) {
    super(owner, args);
    this.logs = args.data.logs;
    this.info = args.data.info;
    this.canLoadMore = args.data.logs.length === 100;
  }

  get entries() {
    return this.logs.map((log) => ({
      ...log,
      title: translate(`mentionables.log.${log.type}.title`),
      details:
        log.type === "report"
          ? Object.entries(log.message).map(([key, value]) =>
              translate(
                `mentionables.log.report.${key}`,
                Array.isArray(value)
                  ? { items: value.join(", ") }
                  : { count: value }
              )
            )
          : [
              log.type === "destroy_all"
                ? translate("mentionables.log.destroy_all.description")
                : log.message,
            ],
    }));
  }

  @action
  async refresh() {
    await this.#load(false);
  }

  @action
  async loadMore() {
    await this.#load(true);
  }

  @action
  async startImport() {
    await this.#request("POST", "import_started");
  }

  @action
  async deleteData() {
    await this.#request("DELETE", "data_deleted");
  }

  async #load(append) {
    const page = append ? this.#page + 1 : 0;
    this.loading = true;
    try {
      const data = await ajax(PATH, { data: { page } });
      this.#page = page;
      this.logs = append ? [...this.logs, ...data.logs] : data.logs;
      this.info = data.info;
      this.canLoadMore = data.logs.length === 100;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  async #request(type, message) {
    this.loading = true;
    try {
      await ajax(PATH, { type });
      this.message = translate(`mentionables.${message}`);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <section class="mentionables-admin">
      <h2>{{i18n "mentionables.title"}}</h2>
      <p class="mentionables-admin__total">{{i18n
          "mentionables.info.total"
          total=this.info.total
        }}</p>
      <div class="mentionables-admin__actions">
        <DButton
          class="mentionables-refresh"
          @action={{this.refresh}}
          @disabled={{this.loading}}
          @icon="arrows-rotate"
          @label="refresh"
        />
        <DButton
          class="mentionables-delete btn-danger"
          @action={{this.deleteData}}
          @disabled={{this.loading}}
          @icon="trash-can"
          @label="mentionables.delete_all"
        />
        <DButton
          class="mentionables-import btn-primary"
          @action={{this.startImport}}
          @disabled={{this.loading}}
          @icon="download"
          @label="mentionables.import"
        />
      </div>
      {{#if this.message}}<p
          class="mentionables-admin__message"
          role="status"
        >{{this.message}}</p>{{/if}}
      {{#if this.logs.length}}
        <table class="mentionables-admin__logs">
          <thead><tr>
              <th>{{i18n "mentionables.columns.type"}}</th><th>{{i18n
                  "mentionables.columns.source"
                }}</th><th>{{i18n "mentionables.columns.message"}}</th><th
              >{{i18n "mentionables.columns.date"}}</th>
            </tr></thead>
          <tbody>{{#each this.entries as |entry|}}
              <tr><td>{{entry.title}}</td><td>{{entry.source}}</td><td><details
                  ><summary>{{entry.title}}</summary>{{#each
                      entry.details
                      as |detail|
                    }}<p>{{detail}}</p>{{/each}}</details></td><td
                >{{entry.date}}</td></tr>
            {{/each}}</tbody>
        </table>
      {{else}}<p>{{i18n "search.no_results"}}</p>{{/if}}
      {{#if this.canLoadMore}}<DButton
          class="mentionables-load-more"
          @action={{this.loadMore}}
          @disabled={{this.loading}}
          @label="mentionables.load_more"
        />{{/if}}
    </section>
  </template>
}
