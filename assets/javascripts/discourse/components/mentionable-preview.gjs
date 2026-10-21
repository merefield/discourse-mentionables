import Component from "@glimmer/component";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { load } from "pretty-text/oneboxer";
import { ajax } from "discourse/lib/ajax";
import domFromString from "discourse/lib/dom-from-string";
import { i18n } from "discourse-i18n";

export default class MentionablePreview extends Component {
  @service currentUser;

  loadPreview = modifier((element) => {
    const link = document.createElement("a");
    link.href = this.args.data.url;
    link.textContent = this.args.data.name;
    element.append(link);

    // The core onebox endpoint requires login; guests retain the destination link.
    if (this.currentUser) {
      const cached = load({
        elem: link,
        ajax,
        topicId: this.args.data.topicId,
        categoryId: this.args.data.categoryId,
        refresh: false,
      });
      if (cached) {
        link.replaceWith(...domFromString(cached));
      }
    }
  });

  <template>
    <div class="mentionables-preview">
      <div class="mentionables-preview__onebox" {{this.loadPreview}}></div>
      <a
        class="mentionables-preview__visit"
        href={{@data.url}}
        rel="nofollow ugc noopener noreferrer"
        target="_blank"
      >{{i18n "mentionables.preview.visit"}}</a>
    </div>
  </template>
}
