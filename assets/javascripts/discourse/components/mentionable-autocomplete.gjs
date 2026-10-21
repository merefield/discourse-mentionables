import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import { mentionableLabel } from "../lib/mentionable-label.js";

export default class MentionableAutocomplete extends Component {
  @action
  select(item, index, event) {
    event.preventDefault();
    this.args.onSelect(item, index, event);
  }

  <template>
    <div class="autocomplete ac-mentionable-item">
      <ul>
        {{#each @results as |item index|}}
          <li>
            <a
              class={{if (eq index @selectedIndex) "selected"}}
              href
              {{on "click" (fn this.select item index)}}
            >
              {{#if item.image_url}}<img
                  alt=""
                  class="ac-mentionable-item-image"
                  src={{item.image_url}}
                />{{/if}}
              <span
                class="ac-mentionable-item-name"
                {{mentionableLabel item}}
              >{{item.name}}</span>
            </a>
          </li>
        {{/each}}
      </ul>
    </div>
  </template>
}
